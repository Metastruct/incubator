-- Quick copy of meta's !knife minigame but with weapons.
-- TODO:
-- - add stats
-- - fix inflictor
-- - add 1HP mode
-- - Challenge players
-- - environment griefing checking
-- - more maps
-- - Hoist generic checking code (cheating, already taken to other games) to minigames utilities file. CPPI but for minigames basically.
local Tag = 'fiteme'
local fitemeing = 'fitemeing'
if not pcall(require, 'landmark') then return end

local EXTRAGUNS = {"weapon_medkit", "weapon_crowbar", "weapon_slap", "weapon_fists", "weapon_squirtbottle", "weapon_popcorn", "weapon_melee_leg"}

if CLIENT then
	local col_fitemeing = Color(255, 55, 55, 255)
	local col_bracket = Color(255, 88, 88, 255)
	local col_hp = Color(111, 240, 111, 255)
	local col_HP = Color(255, 240, 240, 255)
	local col_bracket2 = col_bracket
	if util.NetworkStringToID(Tag) <= 0 then return end
	local in_highperf = _G.FITEME_HIGH_PERF_REQUESTED

	local function SetHighPerf(set)
		if set and in_highperf then return end
		if not set and not in_highperf then return end
		in_highperf = set and true or false
		_G.FITEME_HIGH_PERF_REQUESTED = in_highperf
		local _ = outfitter and outfitter.SetHighPerf and outfitter.SetHighPerf(in_highperf)
	end

	net.Receive(Tag, function()
		local pl1 = net.ReadEntity()
		local pl2 = net.ReadEntity()
		local hp1 = net.ReadInt(8)
		local weapon = net.ReadString()
		chat.AddText(col_bracket, "[", col_fitemeing, "1v1", col_bracket, "] ", pl1, col_bracket2, " (", col_hp, hp1, col_HP, " HP left", col_bracket2, ')', col_fitemeing, " defeated ", pl2, col_fitemeing, " with ", language.GetPhrase(weapon), col_fitemeing, '!')
	end)

	local pac_was_enabled
	local is_fitemeing

	hook.Add("PlayerReserved", Tag, function(pl, tag)
		if Player(pl) ~= LocalPlayer() then return end

		if tag == fitemeing then
			is_fitemeing = true
			local cvar = GetConVar("pac_enable")
			pac_was_enabled = cvar and cvar:GetBool()

			if pac_was_enabled then
				cvar:SetBool(false)
			end

			SetHighPerf(true)
		elseif is_fitemeing and tag == false then
			is_fitemeing = nil

			if pac_was_enabled then
				GetConVar("pac_enable"):SetBool(true)
			end

			pac_was_enabled = nil
			SetHighPerf(false)
		end

		print(tag)
	end)

	local last, snd, snd2, delet
	local startt

	local badhud = {
		CHudChat = true,
		NetGraph = true,
		CHudDeathNotice = true
	}

	local function HUDShouldDraw(t)
		if badhud[t] then return false end
	end

	local function HUDPaint()
		local now = RealTime()

		if delet then
			hook.Remove("HUDPaint", Tag)
		end
	end

	hook.Add("PlayerReserved", Tag, function(pl, rtype, rtype_prev)
		if not LocalPlayer():IsValid() then return end
		if pl ~= LocalPlayer() and pl ~= LocalPlayer():UserID() then return end

		if rtype == Tag then
			last = rtype
			delet = nil
			startt = RealTime()
			print"Reserved for 1v1"
			hook.Add("HUDPaint", Tag, HUDPaint)
		elseif rtype == fitemeing then
			last = rtype
			snd = CreateSound(LocalPlayer(), (table.Random{'music/hl2_song20_submix0.mp3', 'music/hl2_song12_long.mp3', 'music/hl2_song31.mp3', 'music/hl2_song4.mp3', 'music/hl2_song15.mp3', 'music/hl1_song17.mp3', 'music/hl2_song3.mp3'}))
			LocalPlayer():EmitSound'plats/elevbell1.wav'
			snd:Play()

			co(function()
				local start = SysTime()
				local sz = collectgarbage'count'

				for i = 1, 2048 do
					if collectgarbage('step', math.ceil(i ^ 2)) then
						local szd = sz - collectgarbage'count'
						Msg"[GC] "
						print(("collected %s (now at %s), took %2.4fs"):format(string.NiceSize(szd * 1000), string.NiceSize(1000 * collectgarbage'count'), SysTime() - start))

						return
					end

					if SysTime() - start > 3 then
						local szd = sz - collectgarbage'count'
						Msg"[GC] "
						print(("collected %s (now at %s), timeout 3s"):format(string.NiceSize(szd * 1000), string.NiceSize(1000 * collectgarbage'count')))

						return
					end

					co.waittick()
				end
			end)

			hook.Add("HUDShouldDraw", Tag, HUDShouldDraw)
			print"Starting fight"
		elseif last then
			if snd and snd:IsPlaying() then
				snd:FadeOut(0.5)
			end

			if last == fitemeing then
				snd2 = CreateSound(LocalPlayer(), 'ambient/levels/canals/windchine1.wav')
				snd2:Play()

				timer.Simple(2, function()
					snd2:FadeOut(2)
				end)
			end

			hook.Remove("HUDShouldDraw", Tag)
			last = nil
			print"Ending fight"
			delet = RealTime()
		end
	end)

	return
end

local allowed_weapons = {
	{"weapon_crossbow"},
	{"weapon_shotgun"},
	{"weapon_frag"},
	{"weapon_357"}
}

local fiteme_init

--TODO: Multimap
local areas = {
	{
		positions = {LMVector{207, 2773, -127, "land_rp"}, LMVector{803, 2864, -128, "land_rp"}}
	},
	{
		positions = {LMVector{-2931, -308, -123, "land_rp"}, LMVector{-2162, -308, -123, "land_rp"}}
	},
	{
		positions = {LMVector{-249, -753, -124, "land_rp"}, LMVector{-114, -1398, -124, "land_rp"}}
	},
	{
		positions = {LMVector{33, 344, 0, "land_fish2"}, LMVector{-378, 17, 0, "land_fish2"}}
	},
	{
		positions = {LMVector{-2129, 5774, 42, "land_fish1"}, LMVector{-2648, 5486, 52, "land_fish1"}}
	},
	{
		positions = {LMVector{-812, 2635, -128, "land_rp"}, LMVector{-1436, 2433, -128, "land_rp"}}
	}
}

for i = #areas, 1, -1 do
	local t = areas[i].positions
	areas[i].players = {}

	for j = #t, 1, -1 do
		local v = t[j]

		if not v:InWorld() then
			table.remove(t, j)
		end

		t[j] = v:pos()
	end

	if #t <= 1 then
		table.remove(areas, i)
		continue
	end
end

if not next(areas) then
	print"Fiteme: no areas"

	return
end

local _ = SERVER and util.AddNetworkString(Tag)

--fitemeing_areas = areas
local bad_entgroups = {
	starfall_processor = true,
	wire_dupeports = true,
	wire_explosives = true,
	wire_expressions = true,
	wire_teleporters = true
}

local function matchmaker()
	local t = player.GetReserved(Tag)
	local _ = table.shuffle and table.shuffle(t)
	local pl1, pl2 = t[1], t[2]

	if not pl1 then
		timer.Destroy(Tag)
		--MsgN"no fitemers"

		return
	end

	if not pl2 then return end
	local ok, can, reason, bad_pl = xpcall(fiteme_init, debug.traceback, pl1, pl2)

	if not ok then
		ErrorNoHalt(can .. '\n')
		reason = can
		_G.CAN_fiteme = false
		_G.CAN_fiteme_err = can
		can = false
		pl1:UnReserve(Tag)
		pl2:UnReserve(Tag)
	end

	if not can then return false, reason, bad_pl end
	assert(pl1:UnReserve(Tag))
	assert(pl2:UnReserve(Tag))
	pl1.fiteme_opponent = pl2
	pl2.fiteme_opponent = pl1
	local ok1 = pl1:Reserve(fitemeing)
	local ok2 = pl2:Reserve(fitemeing)

	if not ok1 then
		ErrorNoHaltWithStack("BUG:", pl1, pl2)
	end

	if not ok2 then
		ErrorNoHaltWithStack("BUG:", pl2, pl1)
	end
end

local function is_eligible(pl)
	if pl:GetActiveItem() then return false, 'wearing an item' end
	if _G.CAN_fiteme == false then return false, 'game disabled' end
	if hook.Run("CanMinigame", Tag, pl) == false then return false, 'blocked' end
	if pl.IsTabbedOut and pl:IsTabbedOut() then return false, 'tabbed' end
	if pl.IsAFK and pl:IsAFK() then return false, 'afk' end
	if MTA and MTA.IsWanted(pl) then return false, 'wanted' end

	if pacx then
		if pacx.GetPlayerSize and pacx.GetPlayerSize(pl) ~= 1 then return false, 'pac3' end
	end

	if math.abs(pl:GetModelScale() - 1) > 0.01 then return false, 'player resized' end
	if pl.pac_mutations and pl.pac_mutations.size then return false, 'pac3' end --TODO: whitelist?
	--[[
                for id, outfits in pairs(pace.Parts) do
                        local owner = pac.ReverseHash(id, "Player")

                        if owner:IsValid() and owner:IsPlayer() and owner.GetPos and id ~= pac.Hash(ply) then
]]
	if pl.pac_movement then return false, 'pac3' end
	if pl.IsBanned and pl:IsBanned() then return false, 'banned' end
	if pl.GetCoins and pl:GetCoins() < 100 then return false, 'You need 100 coins to play' end
	if pl:GetLaggedMovementValue() ~= 1 then return false, 'speedhack' end
	if pl:GetNoDraw() then return false, 'not drawing' end
	if not pl:Alive() then return false, 'not alive' end
	if not pl:IsSolid() then return false, 'not solid' end
	if pl:GetGravity() ~= 1 and pl:GetGravity() ~= 0 then return false, 'gravity' end
	if pl.GetGravityFactor and pl:GetGravityFactor() ~= 1 then return false, 'gravity' end
	if pl:GetParent():IsValid() then return false, 'parented' end
	if pl:GetColor().a < 255 then return false, 'camouflage player color' end
	if pl:GetMaterial() ~= "" then return false, 'camouflage material' end
	if pl:GetRenderMode() ~= 0 then return false, 'camouflage' end

	for i = 0, 31 do
		if pl:GetSubMaterial(i) ~= "" then return false, 'camouflage material' end
	end

	for k, v in next, bad_entgroups do
		if pl:GetCount(k) > 0 then return false, 'blacklisted entity spawned' end
	end

	return true
end

local function cmd_fiteme(pl)
	local reserved = pl:IsReserved()

	if reserved then
		if reserved == Tag then
			pl:ChatPrint"Removed from queue"
			pl:UnReserve()

			return
		elseif reserved == fitemeing then
			return false, 'you need to kill the other one to leave'
		end

		return false, 'you are already doing something else'
	end

	local ret, err = is_eligible(pl)
	if ret == false then return ret, err end
	assert(pl:Reserve(Tag))
	--pl:ChatPrint"Joined queue"
	pl:EmitSound'ui/trade_ready.wav'

	if not timer.Exists(Tag) then
		timer.Create(Tag, 1, 0, matchmaker)
	end
end

timer.Simple(1, function()
	if aowl then
		aowl.AddCommand({"fiteme", "1v1", "1vs1", "duel"}, "Register yourself for a game of \'fiteme\''", cmd_fiteme, "players", false, nil, 3)
	end
end)

timer.Create(Tag, 0.3, 0, matchmaker)

local function okarea(area, filter)
	for _, pos in next, area.positions do
		pos = pos + Vector(0, 0, 30)

		local trr = util.TraceHull{
			start = pos,
			endpos = pos,
			mins = Vector(-16, -16, 0),
			maxs = Vector(16, 16, 30),
			mask = MASK_PLAYERSOLID,
			filter = filter
		}

		if trr.Hit then return false, trr end
	end

	return true
end

local function getarea(filter)
	--if pl then
	--	for n,candidate in next,areas do
	--		if candidate.reserved then
	--			for i=1,128 do
	--				if not candidate[i] then break end
	--				if candidate[i] == pl then return candidate end
	--			end
	--		end
	--	end
	--	return
	--end
	table.shuffle(areas)

	for n, candidate in next, areas do
		local ok, dat = okarea(candidate, filter)
		if not candidate.reserved and ok then return candidate end
	end

	return false, 'none free'
end

--mg_fiteme_getarea=getarea
local vector_origin = vector_origin

fiteme_init = function(pl1, pl2)
	local t = {pl1, pl2}

	local function players()
		local i = 0

		return function()
			i = i + 1
			if t[i] then return t[i], t[i - 1] or t[i + 1] end
		end
	end

	for pl, _ in players() do
		local eligible, reason = is_eligible(pl)
		print("is_eligible", pl, "bad=", bad)
		if eligible == false then return false, reason or "is_eligible", pl end
	end

	local area, reason = getarea(t)
	if not area then return nil, reason end
	area.reserved = true
	local pos1 = area.positions[1]
	local pos2 = area.positions[2]

	local function check_cheat()
		for i = 1, 5 do
			co.sleep(math.Rand(1, 2))
			local bad, badtype

			local function setbad(pl)
				if not bad then
					bad = pl

					return
				end

				-- both are bad, something is broken.
				if bad ~= true then
					print("cheat checking bug or env changed")
					bad = true
				end
			end

			for pl, _ in players() do
				if not pl:IsValid() then continue end
				if pl:IsReserved() ~= fitemeing then return end

				if pl:GetActiveItem() then
					setbad(pl)
					continue
				end

				if pl:GetLaggedMovementValue() > 1 then
					setbad(pl)
					continue
				end

				if pl:GetJumpPower() ~= 200 then
					setbad(pl)
					continue
				end
			end

			if bad and bad ~= true then
				bad:Kill()
				PrintMessage(3, tostring(bad) .. ' tried to cheat in 1v1')
			end
		end
		--print"Ending cheats checking"
	end

	co(check_cheat)
	local chosen_weapon = table.Random(allowed_weapons)[1]

	for pl, _ in players() do
		pl:ExitVehicle()
		pl:SetVelocity(vector_origin)
		local _ = pl.Revive and pl:Revive()
		local _ = pl.PreventMoving and pl:PreventMoving(5.5)
		pl:SetHealth(100)
		pl:SetArmor(0)
		pl:SetJumpPower(200) -- can't know default jump power

		if pl.GetSuperJumpMultiplier then
			pl.SetSuperJumpMultiplier_mg_fiteme = pl:GetSuperJumpMultiplier()
			pl:SetSuperJumpMultiplier(1)
		end

		pl.fiteme_chosen_weapon = chosen_weapon

		for _, gun in pairs(EXTRAGUNS) do
			pl:Give(gun)
		end

		pl:Give(chosen_weapon)
		pl:SelectWeapon(chosen_weapon)
		local _ = pl.SetFlying and pl:SetFlying(false)

		-- Does not always select (????)
		co(function()
			co.sleep(0.1)
			if not pl:IsValid() then return end
			pl:SelectWeapon(chosen_weapon)
		end)

		pl.fiteme_oldpos = pl:Alive() and pl:GetPos()
		pl.fiteme_area = area
		local _ = pl.PayCoins and pl:PayCoins(100, Tag)
	end

	pl1:SetPos(pos1)
	pl2:SetPos(pos2)

	local origpositions = {
		[pl1] = pos1,
		[pl2] = pos2
	}

	local MAXD = 1500 ^ 2

	co(function()
		for i = 1, 1024 do
			co.sleep(0.5)

			for pl, pos in next, origpositions do
				if pl:IsReserved() ~= fitemeing then
					print(pl, "no longer dist checking")

					return
				end

				if pl:GetPos():DistToSqr(pos1) > MAXD then
					pl:Kill()
					PrintMessage(3, tostring(pl) .. ' left the area')

					return
				end
			end
		end

		print"Ending dist checking"
	end)

	for pl1, pl2 in players() do
		pl1:UnStuck()
		pl1:SetLocalVelocity(Vector(0, 0, 0))
		pl1:LookAt(pl2)
	end

	return true
end

local lastmsg = 0

local function WantPlay(pl)
	if RealTime() - lastmsg > 60 then
		lastmsg = RealTime()
		local msg = ("%s wants to duel with guns, type !duel to join"):format(tostring(pl:Name()))
		PrintMessage(3, msg)

		return true
	end
end

hook.Add("PlayerReserved", Tag, function(pl, tag, prev)
	if tag == Tag then
		if not WantPlay(pl) then
			pl:ChatPrint"Waiting for someone else..."
		end
	elseif tag == fitemeing then
		pl:ChatPrint(("Battle started against %s..."):format(tostring(pl.fiteme_opponent)))
		Msg"[1v1] "
		print(pl, "battle with", pl.fiteme_opponent)

		if not pl.fiteme_opponent or not pl.fiteme_opponent:IsValid() then
			pl:UnReserve()
			print("No opponent??", pl, pl.fiteme_opponent)

			return
		end

		assert(pl.fiteme_opponent)
		pl:SetAllowNoclip(false, Tag)
		pl:SetAllowBuild(false, Tag)
		pl:RestrictFly(true, Tag)
		local _ = pl.SetFlying and pl:SetFlying(false)

		local guns = {assert(pl.fiteme_chosen_weapon, 'no fiteme_chosen_weapon')}

		for _, gun in pairs(EXTRAGUNS) do
			table.insert(guns, gun)
		end

		pl:RestrictGuns(guns, Tag, true)
		pl:SetWalkSpeed(150)
		pl:SetRunSpeed(190)
	elseif prev == Tag then
		assert(not tag)
	elseif prev == fitemeing then
		--Msg"[fiteme] "
		--print(pl, "Left waiting")
		assert(not tag)
		--Msg"[fiteme] "
		--print(pl, "Left battle")
		pl.fiteme_opponent = nil
		pl.fiteme_area.reserved = false
		pl.fiteme_area = nil
		pl:RestrictFly(false, Tag)
		pl:SetAllowNoclip(true, Tag)
		pl:SetAllowBuild(true, Tag)
		pl:RestrictGuns(false, Tag, true)

		if pl.SetSuperJumpMultiplier_mg_fiteme then
			local mul = pl:GetSuperJumpMultiplier()

			if mul == 1 then
				--print("Resetting superjump to original", pl, pl.SetSuperJumpMultiplier_mg_fiteme)
				pl:SetSuperJumpMultiplier(pl.SetSuperJumpMultiplier_mg_fiteme)
			else
				--print("Not restting superjump", pl, mul)
			end
		end

		co(function()
			co.sleep(1)
			if not pl:IsValid() then return end
			if pl:IsReserved() then return end

			if not pl:Alive() then
				pl:Revive()
			else
				pl:SetHealth(pl:GetMaxHealth() > 100 and 100 or pl:GetMaxHealth())
			end

			if pl.fiteme_oldpos and util.IsInWorld(pl.fiteme_oldpos) then
				pl:SetPos(pl.fiteme_oldpos)
				pl.fiteme_oldpos = nil

				if pl:UnStuck() == false then
					pl:Spawn()
				end
			end

			player_manager.OnPlayerSpawn(pl)
		end)
	end
end)

hook.Add("FindUseEntity", Tag, function(pl1, pl2)
	if pl1:IsReserved() == fitemeing then end -- todo?
end)

hook.Add("PlayerShouldTakeDamage", Tag, function(pl1, pl2)
	if pl1:IsReserved() == fitemeing then
		-- cannot kill anyone but your opponent
		return pl1.fiteme_opponent == pl2
	elseif pl2:IsPlayer() and pl2 ~= pl1 and pl2:IsReserved() == fitemeing then
		-- don't allow fitemeing anything else
		return pl2.fiteme_opponent == pl1 or pl1.fiteme_opponent == pl2
	end
end)

local function endfiteme(pl1, has_winner, inflictor)
	if pl1:IsReserved() == fitemeing then
		local pl2 = pl1.fiteme_opponent
		pl1:UnReserve()

		if IsValid(pl2) then
			if pl2:IsReserved() == fitemeing then
				pl2:UnReserve()
			else
				print(pl2, "INVALID RESERVE??", pl2:IsReserved())
			end

			local _ = pl2.GiveCoins and pl2:GiveCoins(has_winner and 160 or 90, Tag)

			if has_winner then
				if IsValid(pl1) then
					timer.Simple(2.8, function()
						if not pl1:IsValid() then return end
						pl1:EmitSound((table.Random{'vo/k_lab2/al_notime.wav', 'vo/k_lab2/kl_notallhopeless_b.wav', 'vo/k_lab/ba_pushinit.wav', 'vo/k_lab/ba_whoops.wav', 'vo/k_lab/kl_ohdear.wav', 'vo/citadel/br_failing11.wav', 'vo/citadel/br_mock04.wav', 'vo/citadel/br_mock06.wav', 'vo/citadel/br_mock07.wav', 'vo/citadel/br_ohshit.wav', 'vo/citadel/br_mock05.wav', 'vo/citadel/br_no.wav', 'vo/citadel/br_youfool.wav'}))
					end)
				end

				if math.random() < 1 / 50 then
					pl2:EmitSound'vo/citadel/gman_exit04.wav'
				else
					timer.Simple(1.5, function()
						if not pl2:IsValid() then return end
						pl2:EmitSound((table.Random{'vo/k_lab2/al_wemadeit.wav', 'vo/k_lab/kl_excellent.wav', 'vo/citadel/al_yes.wav', 'vo/coast/bugbait/vbaittrain_great.wav', 'vo/coast/bugbait/vbaittrain_gotit.wav', 'vo/coast/bugbait/vbaittrain_fine.wav', 'vo/eli_lab/al_allright01.wav', 'vo/eli_lab/al_laugh01.wav', 'vo/eli_lab/al_sweet.wav', 'vo/citadel/br_bidder_a.wav', 'vo/coast/odessa/nlo_cub_thatsthat.wav', 'vo/k_lab2/ba_goodnews.wav', 'vo/k_lab2/al_goodboy.wav'}))
					end)
				end
			end
		end

		local msg = ("[1v1] %s won against %s%s"):format(tostring(pl2), tostring(pl1), has_winner and "" or " (no winner???)")
		print(msg)

		if has_winner then
			if IsValid(pl1) and IsValid(pl2) then
				net.Start(Tag)
				net.WriteEntity(pl2)
				net.WriteEntity(pl1)
				net.WriteInt(pl2:Health(), 8)
				--TODO: add all inflictors
				net.WriteString(IsValid(inflictor) and inflictor:GetClass() or pl2.fiteme_chosen_weapon or "#unknown")
				net.Broadcast()
			else
				PrintMessage(3, msg)
			end
		end
	end
end

hook.Add("DoPlayerDeath", Tag, function(pl1, attacker, dmg)
	if pl1:IsReserved() ~= fitemeing then return end
	local inflictor = dmg:GetInflictor()

	--PrintTable{
	--	"death",
	--	pl1 = pl1,
	--	attacker = attacker,
	--	pl2 = pl1.fiteme_opponent,
	--	inflictor = inflictor
	--}
	if (IsValid(inflictor) and inflictor == attacker and (inflictor:IsPlayer() or inflictor:IsNPC())) then
		inflictor = inflictor:GetActiveWeapon()

		if (not IsValid(inflictor)) then
			inflictor = attacker
		end
	end

	local has_winner = attacker == pl1.fiteme_opponent or attacker == pl1
	local ok_attacker = dmg:GetInflictor() == dmg:GetAttacker()
	local has_inflictor = dmg:GetInflictor():IsValid()
	ok_attacker = ok_attacker or not has_inflictor

	--ok_attacker = ok_attacker or (has_inflictor and (dmg:GetInflictor():GetClass():find"^weapon_.*owbar"))
	--ok_attacker = ok_attacker or (has_inflictor and (dmg:GetInflictor():GetClass():find"_fiteme"))
	if not ok_attacker then
		print("ok_attacker=", ok_attacker, "(IGNORED, TODO)")
		--has_winner = false
	end

	endfiteme(pl1, has_winner, inflictor)
end)

hook.Add("PlayerSilentDeath", Tag, function(pl1)
	endfiteme(pl1, false)
end)

hook.Add("PlayerDisconnected", Tag, function(pl1)
	endfiteme(pl1, false)
end)

hook.Add("FindUseEntity", Tag, function(pl) end) --if pl:IsReserved() == fitemeing then return NULL end

hook.Add("PrePACConfigApply", Tag, function(pl)
	if pl.IsReserved and pl:IsReserved() == fitemeing then return false, 'in minigame' end
end)

hook.Add("Watt.CanPerformAction", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false end
end)

hook.Add("CanPlyUseMSItems", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false end
end)

hook.Add("CanPlyGoto", Tag, function(pl, line, ent)
	if pl:IsReserved() == fitemeing then return false end

	if isentity(line) then
		ent = line
	end

	if isentity(ent) and IsValid(ent) and ent:IsPlayer() and ent:IsReserved() == fitemeing then return false, 'playing fitemeing minigame' end
end)

hook.Add("CanPlyTeleport", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false end
end)

hook.Add("CanPlayerEnterVehicle", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false end
end)

hook.Add("CanSSJump", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false end
end)

hook.Add("CanPlayerHax", Tag, function(pl)
	if pl:IsReserved() == fitemeing then
		pl:ChatPrint("#ms_cant_hax_while_fitemeing")

		return false
	end
end)

hook.Add("CanPlayerTimescale", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false end
end)

hook.Add("CanPlayerSpectate", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false, "cannot spectate in fiteme" end
end)

hook.Add("CanPlayerRagdoll", Tag, function(pl)
	if pl:IsReserved() == fitemeing then return false, "cannot ragdoll in fiteme" end
end)
