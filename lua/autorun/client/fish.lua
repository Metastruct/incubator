-- WARNING: VIBED
-- 
-- fish.lua — client-side aquarium fish (prototype)
-- Purely client side. Fish are ClientsideModel entities steered by a boids
-- flock + soft box-bounds + util.TraceLine obstacle probes (probes are the
-- "expensive" part; you asked for it).
--
-- Commands:
--   aquarium_spawn [n]   spawn/replace the school (default 12)
--   aquarium_kill        remove all fish + hooks
--   aquarium_reload      re-compile this file from disk (hot reload)
--   aquarium_info        print config + state
-- Auto: fish are removed after 10s of no simulation (player far from the tank)
-- and respawn when the player is back near the tank (checked every 0.2s while
-- the "lua_trigger" hook reports the player inside the lobby).
local Tag = 'aquarium' -- use for all hooks

-- Gate on the landmark system: the tank coordinates are LMVectors relative to
-- the "arcade" landmark, so without it the config cannot resolve.
pcall(require, "landmark")

if not LMVector or not landmark.get("arcade") then
	return
end

-- Master switch: 0 prevents fish from spawning (and drops any alive).
local aquarium_enabled = CreateConVar("aquarium_enabled", "1", FCVAR_ARCHIVE, "Master switch for the aquarium fish")

local function FishEnabled()
	local cv = GetConVar("aquarium_enabled")
	return not cv or cv:GetBool()
end

local MODELS       = {
	{
		mdl = "models/props/de_inferno/goldfish.mdl",
		yaw_offset = 0
	}, -- verify nose direction visually
	{
		mdl = "models/props/cs_militia/fishriver01.mdl",
		yaw_offset = 0,
		-- color variants sampled from the reference fish the user built near the
		-- arcade; one is picked per fish at spawn. goldfish stays uncolored
		-- (its material doesn't tint via SetColor), so it has no colors table.
		colors = {
			Color(255, 159, 159),
			Color(159, 174, 255),
			Color(159, 255, 166),
			Color(253, 255, 154)
		}
	}
}

local CFG          = {
	n_boids = 12,
	max_speed = 130,
	min_speed = 45,
	max_force = 260, -- acceleration limit (units/s^2)
	turn_rate = 340, -- deg/s max yaw/pitch change
	neighbor_r = 90,
	sep_r = 34,
	sep_w = 1.7,
	ali_w = 1.0,
	coh_w = 0.8, -- looser school so individuals don't all slosh together
	wall_margin = 24,
	wall_w = 150,
	probe_len = 48,  -- halved
	probe_angle = 0.55, -- rad, side probe spread
	probe_w = 300,
	bob_amp = 1.6,
	bob_freq = 3.2,
	bank_roll = 0.5,
	max_roll = 45,
	step = 1 / 30,
	-- behavior variety (per-fish state machine)
	rest_chance = 0.35,
	dart_chance = 0.25,
	rest_min = 1.2,
	rest_max = 4.0,
	dart_min = 0.4,
	dart_max = 1.1,
	cruise_min = 2.0,
	cruise_max = 6.0,
	wander_w = 0.5, -- individual wander bias (breaks the school's groupthink)
	wander_j = 26, -- wander point jitter, units/s
	-- periodic safe-spot visits (per-fish: every 20-40s, attracted for 2-3s)
	home_min = 20,
	home_max = 40,
	home_visit_min = 2,
	home_visit_max = 3,
	-- crowbar-hit sound trigger for the alert
	sound_alert_dur = 3, -- seconds the sound-triggered alert stays on (resets per hit)
	alert_exit_max = 4, -- when the alert clears, each fish lingers 0..this many s
	idle_remove = 10, -- seconds without simulation before ClientsideModels are removed
	presence_range = 1500, -- how close the player must be to a tank to respawn/simulate it
	-- player-eye attraction (curiosity)
	attr_range = 320, -- attraction range from the local player's eye
	attr_min = 60,    -- keep-out radius: never get closer than this
	attr_w = 3.0,     -- attraction strength
	attr_repel = 2.5, -- keep-out strength
	attr_stare = 8,   -- seconds of staring before losing interest
	attr_bored_min = 1.5,
	attr_bored_max = 3
}

local aquariums    = {} -- one boid-swarm per tank (multi-aquarium)
local think_hooked = false
local sound_hooked = false
local in_lobby     = false -- last known "lobby" trigger state (from lua_trigger)
local presence_t   = 0 -- 0.2s accumulator for the proximity respawn poll (see Think)
-- Reused trace buffers (zero-alloc pattern)
local trace_res    = {}
local tmppos       = Vector()
local tmpvel       = Vector()
local tmpang       = Angle()
local setpos       = Vector() -- reused for ent:SetPos
local setang       = Angle() -- reused for ent:SetAngles
-- Boid storage (flat, zero-alloc):
--   [1..3] pos        [4..6] pitch,yaw,roll   [7..9] vel
--   [10] model index  [11] ClientsideModel entity
local BOID         = {}
BOID.__index       = BOID

-- NOTE: these return SHARED temp objects (zero-alloc). Read-only, don't store them.
function BOID:GetPos()
	tmppos.x = self[1]
	tmppos.y = self[2]
	tmppos.z = self[3]

	return tmppos
end

function BOID:GetVelocity()
	tmpvel.x = self[7]
	tmpvel.y = self[8]
	tmpvel.z = self[9]

	return tmpvel
end

function BOID:GetAngle()
	tmpang.p, tmpang.y, tmpang.r = self[4], self[5], self[6]

	return tmpang
end

local function NewBoid(modelIdx)
	local model = MODELS[modelIdx]
	local b = setmetatable({}, BOID)
	b[1], b[2], b[3] = 0, 0, 0
	b[4], b[5], b[6] = 0, 0, 0
	b[7], b[8], b[9] = 0, 0, 0
	b[10] = modelIdx
	local ent = ClientsideModel(model.mdl)

	if IsValid(ent) then
		-- global registry (survives module re-runs) so orphans stay removable
		-- without tagging by model/name (other addons may share those)
		local reg = _G.aquarium_ents

		if not reg then
			reg = {}
			_G.aquarium_ents = reg
		end

		table.insert(reg, ent)
	end

	b[11] = ent
	b.phase = math.random() * math.pi * 2

	return b
end

local function Norm(x, y, z)
	local l = math.sqrt(x * x + y * y + z * z)
	if l < 0.0001 then return 0, 0, 0, 0 end

	return x / l, y / l, z / l, l
end

-- One fixed-step simulation pass for the whole school.
local function SimulateTick(aq, dt)
	local boids = aq.boids
	local n = #boids
	local cfg = CFG
	local mins, maxs = aq.mins, aq.maxs
	local time = CurTime()
	local sep_r = cfg.sep_r
	local sep_r2 = sep_r * sep_r
	local nbr_r = cfg.neighbor_r
	local nbr_r2 = nbr_r * nbr_r
	local ca, sa = math.cos(cfg.probe_angle), math.sin(cfg.probe_angle)
	local tr = aq.tr
	local p0, p1 = aq.p0, aq.p1
	local eye = nil
	local lp = LocalPlayer()

	if IsValid(lp) and lp.EyePos then
		eye = lp:EyePos()
	end

	for i = 1, n do
		local b = boids[i]
		local px, py, pz = b[1], b[2], b[3]
		local vx, vy, vz = b[7], b[8], b[9]

		-- per-fish alert state: after the aquarium alert clears, each fish
		-- lingers at its nesting spot 0..alert_exit_max seconds (staggered)
		-- before returning to normal, so they never all leave at once
		local alerting = aq.alert

		if not aq.alert and (b.alert_exit or 0) > 0 then
			b.alert_exit = b.alert_exit - dt

			if b.alert_exit > 0 then
				alerting = true
			end
		end

		local maxForce = cfg.max_force * (alerting and 3 or 1)
		local steerMul = alerting and 2 or 1

		-- --- behavior state machine: cruise / rest / dart / home -------------
		-- (frozen while alert: fish seek their nesting spots instead)
		if not alerting then
			if b.mode == "home" then
				-- visiting the safe spot; leave when the visit ends
				b.mode_t = b.mode_t - dt

				if b.mode_t <= 0 then
					b.mode = "cruise"
					b.mode_t = math.Rand(cfg.cruise_min, cfg.cruise_max)
					b.home_t = math.Rand(cfg.home_min, cfg.home_max)
				end
			else
				b.home_t = b.home_t - dt

				if b.home_t <= 0 and b.mode == "cruise" then
					b.mode = "home"
					b.mode_t = math.Rand(cfg.home_visit_min, cfg.home_visit_max)
				else
					b.mode_t = b.mode_t - dt

					if b.mode_t <= 0 then
						if b.mode == "cruise" then
							local r = math.random()

							if r < cfg.rest_chance then
								b.mode = "rest"
								b.mode_t = math.Rand(cfg.rest_min, cfg.rest_max)
							elseif r < cfg.rest_chance + cfg.dart_chance then
								b.mode = "dart"
								b.mode_t = math.Rand(cfg.dart_min, cfg.dart_max)
								b.tx = math.Rand(mins.x + 8, maxs.x - 8)
								b.ty = math.Rand(mins.y + 8, maxs.y - 8)
								b.tz = math.Rand(mins.z + 8, maxs.z - 8)
							else
								b.mode_t = math.Rand(cfg.cruise_min, cfg.cruise_max)
							end
						else
							b.mode = "cruise"
							b.mode_t = math.Rand(cfg.cruise_min, cfg.cruise_max)
						end
					end
				end
			end
		end

		-- wander point: slow random walk inside the tank
		b.wx = math.Clamp(b.wx + math.Rand(-cfg.wander_j, cfg.wander_j) * dt, mins.x + 10, maxs.x - 10)
		b.wy = math.Clamp(b.wy + math.Rand(-cfg.wander_j, cfg.wander_j) * dt, mins.y + 10, maxs.y - 10)
		b.wz = math.Clamp(b.wz + math.Rand(-cfg.wander_j, cfg.wander_j) * dt, mins.z + 10, maxs.z - 10)
		local wdx, wdy, wdz = Norm(b.wx - px, b.wy - py, b.wz - pz)
		-- --- flocking: separation / alignment / cohesion --------------------
		local sx, sy, sz = 0, 0, 0
		local ax, ay, az = 0, 0, 0
		local cx, cy, cz = 0, 0, 0
		local sn, an = 0, 0

		for j = 1, n do
			if j ~= i then
				local o = boids[j]
				local dx, dy, dz = px - o[1], py - o[2], pz - o[3]
				local d2 = dx * dx + dy * dy + dz * dz

				if d2 < sep_r2 and d2 > 0.01 then
					local d = math.sqrt(d2)
					local w = (sep_r - d) / sep_r
					sx = sx + dx / d * w
					sy = sy + dy / d * w
					sz = sz + dz / d * w
					sn = sn + 1
				end

				if d2 < nbr_r2 then
					ax = ax + o[7]
					ay = ay + o[8]
					az = az + o[9]
					cx = cx + o[1]
					cy = cy + o[2]
					cz = cz + o[3]
					an = an + 1
				end
			end
		end

		-- heading + right vector from current velocity
		local spd = math.sqrt(vx * vx + vy * vy + vz * vz)

		if spd < 0.01 then
			spd = 0.01
		end

		local ux, uy, uz = vx / spd, vy / spd, vz / spd
		local rlx, rly, rlz = Norm(uy, -ux, 0) -- right = cross( fwd, worldUp )
		-- --- obstacle probes (util.TraceLine, reused buffers) --------------
		local ox, oy, oz = 0, 0, 0
		local nxn, nyn, nzn = 0, 0, 0
		p0.x, p0.y, p0.z = px, py, pz
		tr.start = p0
		local probe_len = cfg.probe_len
		p1.x, p1.y, p1.z = px + ux * probe_len, py + uy * probe_len, pz + uz * probe_len
		tr.endpos = p1
		util.TraceLine(tr)

		if trace_res.Hit then
			local t = (probe_len - trace_res.Fraction * probe_len) / probe_len
			ox = ox + trace_res.HitNormal.x * t * cfg.probe_w
			oy = oy + trace_res.HitNormal.y * t * cfg.probe_w
			oz = oz + trace_res.HitNormal.z * t * cfg.probe_w
			nxn = nxn + trace_res.HitNormal.x * t
			nyn = nyn + trace_res.HitNormal.y * t
			nzn = nzn + trace_res.HitNormal.z * t
		end

		local sdx, sdy, sdz = ux * ca + rlx * sa, uy * ca + rly * sa, uz * ca + rlz * sa
		p1.x, p1.y, p1.z = px + sdx * probe_len, py + sdy * probe_len, pz + sdz * probe_len
		tr.endpos = p1
		util.TraceLine(tr)

		if trace_res.Hit then
			local t = (probe_len - trace_res.Fraction * probe_len) / probe_len
			ox = ox + trace_res.HitNormal.x * t * cfg.probe_w
			oy = oy + trace_res.HitNormal.y * t * cfg.probe_w
			oz = oz + trace_res.HitNormal.z * t * cfg.probe_w
			nxn = nxn + trace_res.HitNormal.x * t
			nyn = nyn + trace_res.HitNormal.y * t
			nzn = nzn + trace_res.HitNormal.z * t
		end

		local sdx2, sdy2, sdz2 = ux * ca - rlx * sa, uy * ca - rly * sa, uz * ca - rlz * sa
		p1.x, p1.y, p1.z = px + sdx2 * probe_len, py + sdy2 * probe_len, pz + sdz2 * probe_len
		tr.endpos = p1
		util.TraceLine(tr)

		if trace_res.Hit then
			local t = (probe_len - trace_res.Fraction * probe_len) / probe_len
			ox = ox + trace_res.HitNormal.x * t * cfg.probe_w
			oy = oy + trace_res.HitNormal.y * t * cfg.probe_w
			oz = oz + trace_res.HitNormal.z * t * cfg.probe_w
			nxn = nxn + trace_res.HitNormal.x * t
			nyn = nyn + trace_res.HitNormal.y * t
			nzn = nzn + trace_res.HitNormal.z * t
		end

		-- --- soft box bounds ----------------------------------------------
		local bx, by, bz = 0, 0, 0
		local margin = cfg.wall_margin

		if px < mins.x + margin then
			bx = bx + cfg.wall_w * (1 - (px - mins.x) / margin)
		end

		if px > maxs.x - margin then
			bx = bx - cfg.wall_w * (1 - (maxs.x - px) / margin)
		end

		if py < mins.y + margin then
			by = by + cfg.wall_w * (1 - (py - mins.y) / margin)
		end

		if py > maxs.y - margin then
			by = by - cfg.wall_w * (1 - (maxs.y - py) / margin)
		end

		if pz < mins.z + margin then
			bz = bz + cfg.wall_w * (1 - (pz - mins.z) / margin)
		end

		if pz > maxs.z - margin then
			bz = bz - cfg.wall_w * (1 - (maxs.z - pz) / margin)
		end

		-- --- attraction to the local player's eye --------------------------
		local attrX, attrY, attrZ = 0, 0, 0

		if not alerting and b.mode ~= "dart" and b.mode ~= "home" and eye and b.bored_t <= 0 then
			local dx, dy, dz = eye.x - px, eye.y - py, eye.z - pz
			local d = math.sqrt(dx * dx + dy * dy + dz * dz)

			if d < cfg.attr_range then
				if d > cfg.attr_min then
					local f = cfg.attr_w * (0.4 + 0.6 * (1 - d / cfg.attr_range))
					attrX, attrY, attrZ = dx / d * f, dy / d * f, dz / d * f
				else
					attrX, attrY, attrZ = -dx / d * cfg.attr_repel, -dy / d * cfg.attr_repel, -dz / d * cfg.attr_repel
				end

				b.curious_t = b.curious_t + dt

				if b.curious_t >= cfg.attr_stare then
					b.curious_t = 0
					b.bored_t = math.Rand(cfg.attr_bored_min, cfg.attr_bored_max)
				end
			else
				b.curious_t = 0
			end
		end

		if b.bored_t > 0 then
			b.bored_t = b.bored_t - dt
		end

		-- --- desired velocity by behavior mode -----------------------------
		local desX, desY, desZ
		local target_speed

		if alerting then
			-- seek the nearest nesting spot; hover around it once there
			local bd, spx, spy, spz = 1e30, 0, 0, 0

			for j = 1, #aq.nesting do
				local sp = aq.nesting[j].pos
				local dx, dy, dz = sp.x - px, sp.y - py, sp.z - pz
				local d2 = dx * dx + dy * dy + dz * dz

				if d2 < bd then
					bd = d2
					spx, spy, spz = sp.x, sp.y, sp.z
				end
			end

			spz = math.max(spz, mins.z + 15) -- hover above the floor, never dive at the nest
			local d = math.sqrt(bd)
			b.mill = d <= 60

			if d > 60 then
				desX, desY, desZ = (spx - px) / d, (spy - py) / d, (spz - pz) / d
				target_speed = math.max(b.speed * 1.6, cfg.max_speed * 1.3)
			else
				-- mill: orbit the nest on a calm ring (tangent heading + radial
				-- ring correction, all smooth functions of position)
				local rx, ry = px - spx, py - spy
				local r = math.sqrt(rx * rx + ry * ry)

				if r < 1 then
					rx, ry, r = 1, 0, 1
				end

				local tanX, tanY = -ry / r, rx / r
				local radial = math.Clamp(1 - (r - 30) / 30, -1, 1)
				desX = tanX + rx / r * radial * 0.8
				desY = tanY + ry / r * radial * 0.8
				desZ = (mins.z + 15 - pz) * 0.5
				target_speed = b.speed * 0.5
			end
		elseif b.mode == "home" then
			-- calm visit to the nearest safe spot: seek it, then orbit it
			local bd, spx, spy, spz = 1e30, 0, 0, 0

			for j = 1, #aq.nesting do
				local sp = aq.nesting[j].pos
				local dx, dy, dz = sp.x - px, sp.y - py, sp.z - pz
				local d2 = dx * dx + dy * dy + dz * dz

				if d2 < bd then
					bd = d2
					spx, spy, spz = sp.x, sp.y, sp.z
				end
			end

			spz = math.max(spz, mins.z + 15)
			local d = math.sqrt(bd)

			if d > 60 then
				desX, desY, desZ = (spx - px) / d, (spy - py) / d, (spz - pz) / d
				target_speed = b.speed
			else
				local rx, ry = px - spx, py - spy
				local r = math.sqrt(rx * rx + ry * ry)

				if r < 1 then
					rx, ry, r = 1, 0, 1
				end

				local tanX, tanY = -ry / r, rx / r
				local radial = math.Clamp(1 - (r - 30) / 30, -1, 1)
				desX = tanX + rx / r * radial * 0.8
				desY = tanY + ry / r * radial * 0.8
				desZ = (mins.z + 15 - pz) * 0.5
				target_speed = b.speed * 0.5
			end
		elseif b.mode == "rest" then
			desX, desY, desZ = wdx * cfg.wander_w * 0.3 + attrX, wdy * cfg.wander_w * 0.3 + attrY,
				wdz * cfg.wander_w * 0.3 + attrZ
			target_speed = cfg.min_speed * 0.3
		elseif b.mode == "dart" then
			desX, desY, desZ = b.tx - px, b.ty - py, b.tz - pz
			target_speed = b.speed * 1.4
		else
			local dSepX, dSepY, dSepZ = Norm(sx, sy, sz)
			local dAliX, dAliY, dAliZ
			local dCohX, dCohY, dCohZ

			if an > 0 then
				dAliX, dAliY, dAliZ = Norm(ax / an, ay / an, az / an)
				dCohX, dCohY, dCohZ = Norm(cx / an - px, cy / an - py, cz / an - pz)
			else
				dAliX, dAliY, dAliZ = 0, 0, 0
				dCohX, dCohY, dCohZ = 0, 0, 0
			end

			desX = dSepX * cfg.sep_w + dAliX * cfg.ali_w + dCohX * cfg.coh_w + wdx * cfg.wander_w + attrX
			desY = dSepY * cfg.sep_w + dAliY * cfg.ali_w + dCohY * cfg.coh_w + wdy * cfg.wander_w + attrY
			desZ = dSepZ * cfg.sep_w + dAliZ * cfg.ali_w + dCohZ * cfg.coh_w + wdz * cfg.wander_w + attrZ
			target_speed = b.speed
		end

		desX, desY, desZ = Norm(desX, desY, desZ)
		desX, desY, desZ = desX * target_speed, desY * target_speed, desZ * target_speed
		-- steer toward desired, accel-limited (gain amplifies the panic burst)
		local stX, stY, stZ = (desX - vx) * steerMul, (desY - vy) * steerMul, (desZ - vz) * steerMul
		local stl = math.sqrt(stX * stX + stY * stY + stZ * stZ)

		if stl > maxForce then
			stX, stY, stZ = stX / stl * maxForce, stY / stl * maxForce, stZ / stl * maxForce
		end

		vx, vy, vz = vx + stX * dt, vy + stY * dt, vz + stZ * dt
		-- obstacle + bounds act as direct repulsion forces on velocity, damped,
		-- so fish settle against surfaces instead of oscillating on them
		vx = vx + (ox + bx) * dt
		vy = vy + (oy + by) * dt
		vz = vz + (oz + bz) * dt
		local nl = math.sqrt(nxn * nxn + nyn * nyn + nzn * nzn)

		if nl > 0.01 then
			nxn, nyn, nzn = nxn / nl, nyn / nl, nzn / nl
			local vn = vx * nxn + vy * nyn + vz * nzn

			if vn < 0 then
				local d = 1 - math.exp(-12 * dt)
				vx = vx - nxn * vn * d
				vy = vy - nyn * vn * d
				vz = vz - nzn * vn * d
			end
		end

		local lim_min, lim_max

		if alerting then
			lim_min, lim_max = 4, cfg.max_speed * 1.6 -- allow both the dash and the calm mill
		elseif b.mode == "home" then
			lim_min, lim_max = 4, cfg.max_speed -- calm seek + slow orbit at the safe spot
		elseif b.mode == "rest" then
			lim_min, lim_max = 4, cfg.min_speed * 0.35
		elseif b.mode == "dart" then
			lim_min, lim_max = cfg.min_speed * 0.8, cfg.max_speed * 1.5
		else
			lim_min, lim_max = cfg.min_speed, cfg.max_speed
		end

		local nspd = math.sqrt(vx * vx + vy * vy + vz * vz)

		if nspd > lim_max then
			vx, vy, vz = vx / nspd * lim_max, vy / nspd * lim_max, vz / nspd * lim_max
		elseif nspd < lim_min then
			if nspd < 0.01 then
				vx, vy, vz = ux * lim_min, uy * lim_min, uz * lim_min
			else
				vx, vy, vz = vx / nspd * lim_min, vy / nspd * lim_min, vz / nspd * lim_min
			end

			nspd = lim_min
		end

		-- integrate + hard clamp (safety net: bounce off walls so fish never pin)
		px, py, pz = px + vx * dt, py + vy * dt, pz + vz * dt

		if px <= mins.x then
			px = mins.x

			if vx < 0 then
				vx = -vx * 0.8
			end
		elseif px >= maxs.x then
			px = maxs.x

			if vx > 0 then
				vx = -vx * 0.8
			end
		end

		if py <= mins.y then
			py = mins.y

			if vy < 0 then
				vy = -vy * 0.8
			end
		elseif py >= maxs.y then
			py = maxs.y

			if vy > 0 then
				vy = -vy * 0.8
			end
		end

		if pz <= mins.z then
			pz = mins.z

			if vz < 0 then
				vz = -vz * 0.8
			end
		elseif pz >= maxs.z then
			pz = maxs.z

			if vz > 0 then
				vz = -vz * 0.8
			end
		end

		b[1], b[2], b[3] = px, py, pz
		b[7], b[8], b[9] = vx, vy, vz
		-- --- orientation ----------------------------------------------------
		local model = MODELS[b[10]]
		local yawT = math.deg(math.atan2(vy, vx)) + model.yaw_offset
		b.pf = b.pf + (math.Clamp(vz / nspd, -1, 1) - b.pf) * (1 - math.exp(-dt * 3))
		local pitchT = -math.deg(math.asin(b.pf))
		local turnMul = alerting and (b.mill and 0.4 or 1.4) or
		(b.mode == "dart" and 1.6 or (b.mode == "rest" and 0.5 or 1))
		local maxTurn = cfg.turn_rate * dt * turnMul
		local ny = b[5] + math.Clamp(math.AngleDifference(yawT, b[5]), -maxTurn, maxTurn)
		local np = b[4] + math.Clamp(math.AngleDifference(pitchT, b[4]), -maxTurn, maxTurn)
		local rollT = math.Clamp(-math.AngleDifference(ny, b[5]) / dt * cfg.bank_roll, -cfg.max_roll, cfg.max_roll)
		b.rf = b.rf + (rollT - b.rf) * (1 - math.exp(-dt * 3))
		local nr = math.Approach(b[6], b.rf, 260 * dt)
		b[4], b[5], b[6] = np, ny, nr
		local ent = b[11]

		if IsValid(ent) then
			local bobMult = alerting and 0 or (b.mode == "rest" and 2.2 or 1)
			local bobFreq = cfg.bob_freq * (b.mode == "rest" and 0.6 or 1)
			local bob = math.sin(time * bobFreq + b.phase) * cfg.bob_amp * bobMult * math.min(1, nspd / 35)
			setpos.x, setpos.y, setpos.z = px, py, pz + bob
			ent:SetPos(setpos)
			setang.p, setang.y, setang.r = np, ny, nr
			ent:SetAngles(setang)
		end
	end
end

local function MakeTrace(aq)
	return {
		start = Vector(),
		endpos = Vector(),
		filter = function(ent) return not aq.fishSet[ent] end,
		mask = MASK_SHOT,
		output = trace_res
	}
end

local function RemoveAquariumBoids(aq)
	local reg = _G.aquarium_ents

	for _, b in ipairs(aq.boids) do
		local e = b[11]

		if IsValid(e) then
			e:Remove()
		end

		aq.fishSet[e] = nil

		if reg then
			for i = #reg, 1, -1 do
				if reg[i] == e then
					table.remove(reg, i)

					break
				end
			end
		end
	end

	aq.boids = {}
	aq.fishSet = {}
	aq.live = false
end

-- forward decls: SpawnBoids/SpawnAquarium are defined further down, but the
-- Think closure above them must reference them as upvalues, not globals
local SpawnBoids
local SpawnAquarium

local function RegisterThink()
	if think_hooked then return end
	think_hooked = true

	hook.Add("Think", Tag, function()
		local lp = LocalPlayer()
		local now = CurTime()
		local enabled = FishEnabled()

		-- master switch: while off, no fish are allowed to stay alive
		if not enabled and #aquariums > 0 then
			local removed = false

			for _, aq in ipairs(aquariums) do
				if aq.live and #aq.boids > 0 then
					RemoveAquariumBoids(aq)
					removed = true
				end
			end

			if removed then
				print("aquarium: disabled (aquarium_enabled 0)")
			end
		end

		-- every 0.2s: while enabled, in the lobby and near a tank, respawn
		-- anything the idle remover dropped (lua_trigger only fires on state
		-- change, so the trigger handler alone never brings them back)
		presence_t = presence_t + FrameTime()

		if presence_t >= 0.2 then
			presence_t = 0

			if enabled and in_lobby and IsValid(lp) then
				local pr2 = CFG.presence_range * CFG.presence_range

				if #aquariums == 0 then
					SpawnAquarium(CFG.n_boids)
				else
					for _, aq in ipairs(aquariums) do
						if not aq.live and lp:GetPos():DistToSqr(aq.center) <= pr2 then
							SpawnBoids(aq, CFG.n_boids)
							print("aquarium: respawned on proximity")
						end
					end
				end
			end
		end

		for _, aq in ipairs(aquariums) do
			if aq.alert_from_sound and now - aq.alert_sound_t > CFG.sound_alert_dur then
				aq.alert = false
				aq.alert_from_sound = false

				-- stagger the return: each fish lingers 0..alert_exit_max
				-- seconds at its nesting spot before leaving
				for _, b in ipairs(aq.boids) do
					b.alert_exit = math.Rand(0, CFG.alert_exit_max)
				end
			end

			-- idle cleanup: not simulated for a while -> drop the ClientsideModels
			if aq.live and #aq.boids > 0 and now - aq.lastSim > CFG.idle_remove then
				RemoveAquariumBoids(aq)
				print("aquarium: removed fish (idle " .. CFG.idle_remove .. "s)")
			end

			if #aq.boids > 0 and IsValid(lp) and lp:GetPos():DistToSqr(aq.center) <= CFG.presence_range * CFG.presence_range then
				aq.acc = aq.acc + FrameTime()
				local step = CFG.step
				local steps = 0

				while aq.acc >= step and steps < 6 do
					SimulateTick(aq, step)
					aq.acc = aq.acc - step
					steps = steps + 1
				end

				if steps == 6 then
					aq.acc = 0
				end

				aq.lastSim = now
			else
				aq.acc = 0 -- too far to care: don't simulate, no catch-up burst on return
			end
		end
	end)
end

local function RegisterSound()
	if sound_hooked then return end
	sound_hooked = true

	hook.Add("EntityEmitSound", Tag, function(data)
		-- crowbar melee script sound isn't emitted here for non-local players,
		-- so key off the impact sound, which does carry a Pos
		if not data or data.OriginalSoundName ~= "glass.bulletimpact" then return end
		local pos = data.Pos
		if not pos then return end

		for _, aq in ipairs(aquariums) do
			-- cheap early-out: within 1000u of the center before the specific check
			if pos:DistToSqr(aq.center) > 1000 * 1000 then
				goto next_aq
			end

			-- specific: within 500u of center, mins, or maxs
			if pos:DistToSqr(aq.center) > 500 * 500 and pos:DistToSqr(aq.mins) > 500 * 500 and pos:DistToSqr(aq.maxs) > 500 * 500 then
				goto next_aq
			end

			aq.alert = true
			aq.alert_from_sound = true
			aq.alert_sound_t = CurTime() -- every hit resets the 3s window

			for _, b in ipairs(aq.boids) do
				b.curious_t = 0
				b.bored_t = 0
				b.alert_exit = 0 -- cancel any pending staggered exit
			end

			::next_aq::
		end
	end)
end

local function KillAquarium()
	-- remove every fish we created, even ones orphaned by a manual re-run of
	-- this file (module locals reset). Tracked in a global registry: clientside
	-- entities can't be tagged by model/name reliably, and other addons may
	-- legitimately use the same models.
	local reg = _G.aquarium_ents

	if reg then
		for _, e in ipairs(reg) do
			if IsValid(e) then
				e:Remove()
			end
		end
	end

	_G.aquarium_ents = nil

	for _, aq in ipairs(aquariums) do
		for _, b in ipairs(aq.boids) do
			if IsValid(b[11]) then
				b[11]:Remove()
			end
		end
	end

	table.Empty(aquariums)
	_G.aquarium = nil
	_G.aquariums = nil

	if think_hooked then
		hook.Remove("Think", Tag)
		think_hooked = false
	end

	if sound_hooked then
		hook.Remove("EntityEmitSound", Tag)
		sound_hooked = false
	end
end

-- Tank coordinates are LMVectors relative to the "arcade" landmark. LMVector
-- can return nil for an offset that doesn't resolve, so a pass below drops any
-- tank (or nesting spot) whose offsets came back nil, then turns the survivors
-- into plain world Vectors. The gameplay code never calls :ToWorld() itself.
local TANKS = {
	{
		mins = LMVector { -56, -592, 32, "arcade" },
		maxs = LMVector { -175, 385, 109, "arcade" },
		nesting = {
			{ range = 32, pos = LMVector { -131, 57, 52, "arcade" } },
			{ range = 32, pos = LMVector { -131, -229, 50, "arcade" } },
			{ range = 32, pos = LMVector { -110, -469, 53, "arcade" } },
			{ range = 32, pos = LMVector { -136, -562, 56, "arcade" } },
			{ range = 32, pos = LMVector { -139, 325, 50, "arcade" } }
		}
	},
	{
		mins = LMVector { -598, -63, -263, "arcade" },
		maxs = LMVector { -494, 329, -168, "arcade" },
		nesting = {
			{ range = 32, pos = LMVector { -530, 167, -240, "arcade" } },
			{ range = 32, pos = LMVector { -517, 59, -241, "arcade" } },
			{ range = 32, pos = LMVector { -541, 302, -242, "arcade" } }
		}
	}
}

for i = #TANKS, 1, -1 do
	local tank = TANKS[i]

	if tank.mins and tank.maxs then
		tank.mins = tank.mins:ToWorld()
		tank.maxs = tank.maxs:ToWorld()

		for j = #tank.nesting, 1, -1 do
			if tank.nesting[j].pos then
				tank.nesting[j].pos = tank.nesting[j].pos:ToWorld()
			else
				table.remove(tank.nesting, j)
			end
		end
	else
		table.remove(TANKS, i)
	end
end

SpawnBoids = function(aq, n)
	local lo, hi = aq.mins, aq.maxs
	local margin = CFG.wall_margin

	for i = 1, n do
		local modelIdx = math.random(#MODELS)
		local b = NewBoid(modelIdx)
		local px = math.Rand(lo.x + margin, hi.x - margin)
		local py = math.Rand(lo.y + margin, hi.y - margin)
		local pz = math.Rand(lo.z + margin, hi.z - margin)
		b[1], b[2], b[3] = px, py, pz
		-- behavior state init (staggered so the school never moves in sync)
		b.mode = "cruise"
		b.mode_t = math.Rand(0, CFG.cruise_max)
		b.wx, b.wy, b.wz = px, py, pz
		b.tx, b.ty, b.tz = px, py, pz
		b.curious_t = 0
		b.bored_t = 0
		b.alert_exit = 0
		b.speed = math.Rand(CFG.min_speed, CFG.max_speed)
		b.home_t = math.Rand(CFG.home_min, CFG.home_max)
		b.pf = 0 -- low-passed vertical velocity ratio for pitch
		b.rf = 0 -- low-passed roll target
		local yaw = math.random() * 360
		local spd = b.speed
		b[7] = math.cos(math.rad(yaw)) * spd
		b[8] = math.sin(math.rad(yaw)) * spd
		b[9] = 0
		b[4], b[5], b[6] = 0, yaw, 0
		local ent = b[11]

		if not IsValid(ent) then
			print("aquarium: failed to create ClientsideModel for " .. MODELS[modelIdx].mdl)
		else
			local s = math.Rand(0.5, 1.4)
			local sy = math.Rand(0.5, 1.4) * 2 -- y (width) varies independently, up to 2x wider
			b.scale = s
			b.scale_y = sy
			local mat = Matrix()
			mat:Scale(Vector(s, sy, s))
			ent:EnableMatrix("RenderMultiply", mat)

			local colors = MODELS[modelIdx].colors

			if colors then
				ent:SetColor(colors[math.random(#colors)])
			end

			setpos.x, setpos.y, setpos.z = px, py, pz
			ent:SetPos(setpos)
			setang.p, setang.y, setang.r = 0, yaw + MODELS[modelIdx].yaw_offset, 0
			ent:SetAngles(setang)
			table.insert(aq.boids, b)
			aq.fishSet[ent] = true
		end
	end

	aq.live = #aq.boids > 0
	aq.lastSim = CurTime()
end

SpawnAquarium = function(n)
	if not FishEnabled() then return end
	KillAquarium()

	for _, tank in ipairs(TANKS) do
		local mins, maxs = tank.mins, tank.maxs
		local lo = Vector(math.min(mins.x, maxs.x), math.min(mins.y, maxs.y), math.min(mins.z, maxs.z))
		local hi = Vector(math.max(mins.x, maxs.x), math.max(mins.y, maxs.y), math.max(mins.z, maxs.z))
		local nesting = {}

		for j, spot in ipairs(tank.nesting) do
			nesting[j] = {
				pos = spot.pos,
				range = spot.range or 32
			}
		end

		local aq = {
			boids = {},
			mins = lo,
			maxs = hi,
			center = (lo + hi) * 0.5,
			fishSet = {},
			p0 = Vector(),
			p1 = Vector(),
			nesting = nesting,
			acc = 0,
			alert = false,
			alert_from_sound = false,
			alert_sound_t = 0,
			live = false,
			lastSim = 0
		}

		aq.tr = MakeTrace(aq)
		table.insert(aquariums, aq)
		SpawnBoids(aq, n)
		print(string.format("aquarium: %d fish, box %s .. %s", #aq.boids, tostring(lo), tostring(hi)))
	end

	_G.aquariums = aquariums
	_G.aquarium = aquariums[1]
	RegisterThink()
	RegisterSound()
end

-- the server reports lobby-trigger state to the client via this hook; fish
-- live only while the player is inside the lobby trigger
hook.Add("lua_trigger", Tag, function(trigger, insideit)
	if trigger ~= "lobby" then return end
	in_lobby = insideit

	if insideit then
		if #aquariums == 0 then
			SpawnAquarium(CFG.n_boids)

			return
		end

		local spawned = false

		for _, aq in ipairs(aquariums) do
			if not aq.live then
				SpawnBoids(aq, CFG.n_boids)
				spawned = true
			end
		end

		if spawned then
			print("aquarium: spawned on lua_trigger")
		end
	else
		local removed = false

		for _, aq in ipairs(aquariums) do
			if aq.live and #aq.boids > 0 then
				RemoveAquariumBoids(aq)
				removed = true
			end
		end

		if removed then
			print("aquarium: removed on lua_trigger")
		end
	end
end)

concommand.Add("aquarium_spawn", function(_, _, args)
	local n = tonumber(args[1]) or CFG.n_boids
	SpawnAquarium(math.Clamp(n, 1, 200))
end)

concommand.Add("aquarium_kill", function()
	KillAquarium()
	print("aquarium: killed")
end)

concommand.Add("aquarium_alert", function(_, _, args)
	if #aquariums == 0 then
		print("aquarium: no active aquarium")

		return
	end

	local want = args[1] and tobool(args[1]) or nil

	for _, aq in ipairs(aquariums) do
		if want == nil then
			aq.alert = not aq.alert
		else
			aq.alert = want
		end

		aq.alert_from_sound = false -- manual control overrides the sound trigger
		aq.alert_sound_t = 0

		if aq.alert then
			for _, b in ipairs(aq.boids) do
				b.curious_t = 0
				b.bored_t = 0
				b.alert_exit = 0
			end
		else
			-- same stagger as the sound alert clearing
			for _, b in ipairs(aq.boids) do
				b.alert_exit = math.Rand(0, CFG.alert_exit_max)
			end
		end
	end

	print("aquarium: alert set")
end)

concommand.Add("aquarium_info", function()
	if #aquariums == 0 then
		print("aquarium: no active aquarium")

		return
	end

	for ai, aq in ipairs(aquariums) do
		print(string.format("aquarium %d: %d fish, box %s .. %s", ai, #aq.boids, tostring(aq.mins), tostring(aq.maxs)))

		for i, b in ipairs(aq.boids) do
			print(string.format("  #%d pos(%s) vel(%s) speed=%.0f", i, tostring(b:GetPos()), tostring(b:GetVelocity()),
				b:GetVelocity():Length()))
		end
	end
end)

concommand.Add("aquarium_reload", function()
	KillAquarium()
	local src = file.Read("lua/autorun/client/fish.lua", "GAME")

	if not src then
		print("aquarium: cannot read lua/autorun/client/fish.lua")

		return
	end

	local fn, err = CompileString(src, "aquarium_reload")

	if not fn then
		print("aquarium reload error: " .. tostring(err))

		return
	end

	local ok, e = pcall(fn)

	if not ok then
		print("aquarium reload failed: " .. tostring(e))

		return
	end

	print("aquarium: reloaded")
end)

RegisterThink()
