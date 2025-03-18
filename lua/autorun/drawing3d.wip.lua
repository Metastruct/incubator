local Tag = 'draw3d'
module(Tag, package.seeall)

if SERVER then
	function on_chunk_update()
	end

	return
end

local palette = {}
local _palette = [[000000
005500
00aa00
00ff00
0000ff
0055ff
00aaff
00ffff
ff0000
ff5500
ffaa00
ffff00
ff00ff
ff55ff
ffaaff
ffffff]]

for hexcode in _palette:gmatch("[^\r\n]+") do
	local r, g, b = hexcode:match("^(..)(..)(..)$")
	r = tonumber(r, 16)
	g = tonumber(g, 16)
	b = tonumber(b, 16)

	table.insert(palette, {r, g, b})
end

_palette = nil

local function get_color(i)
	local c = palette[(i - 1) % (#palette) + 1]

	return c[1], c[2], c[3]
end

local meshes = {}
_G.MMM = meshes
local pl_meshes = {}
local mesh_n = 1
local drawpos_want, drawpos_last
local mat = Material("editor/wireframe")
local want_color_index = 1

local function increment_color()
	want_color_index = 1 + (want_color_index) % (#palette)
end

local function dec_color()
	want_color_index = 1 + (want_color_index - 2) % (#palette)
end

dec_color()

local function CANDRAW()
	local me=LocalPlayer()
	if not me:KeyDown(IN_RELOAD) then return end
	local wep = me:GetActiveWeapon()
	return wep:IsValid() and wep:GetClass() == "weapon_physcannon"
end

hook.Add("InputMouseApply", Tag, function(cmd)
	local delta = cmd:GetMouseWheel()
	if delta == 0 then return end
	if not CANDRAW() then return end

	if delta > 0 then
		increment_color()
	elseif delta < 0 then
		dec_color()
	end
end)

--chat.AddText(color_white,"Chosen color: ",want_color_index,": ",Color(get_color(want_color_index)),"XX",color_white," - next: ",Color(get_color(want_color_index+1)),"XX")
local clear
local buff = {} -- pos1,pos2,pos3 of draw line. TODO: break a line how?
local MAX_BUFF = 128
hook.Add("Think", Tag, function() end)

hook.Add("KeyPress", Tag, function(pl, key)
	if key ~= IN_USE then return end
	if not IsFirstTimePredicted() then return end
	if not CANDRAW() then return end
	increment_color()
	chat.AddText(color_white, "Chosen color: ", want_color_index, ": ", Color(get_color(want_color_index)), "XX", color_white, " - next: ", Color(get_color(want_color_index + 1)), "XX")
end)

hook.Add("HUDPaint", Tag, function()
	local can_draw = CANDRAW()
	if not can_draw then return end
	local sw, sh = ScrW(), ScrH()
	surface.SetDrawColor(get_color(want_color_index))
	surface.DrawRect(sw * .5 - 16, sh * .5 - 128, 16, 16)
end)

hook.Add("Tick", Tag, function()
	local pl = LocalPlayer()
	if not pl:IsValid() then return end 
		
	local tr = pl:GetEyeTrace()
	drawpos_want = pl:KeyDown(IN_SPEED) and tr.HitPos + tr.HitNormal * 1 or pl:GetAimVector() * 48 + pl:GetShootPos()

	if not drawpos_last then
		drawpos_last = drawpos_want

		return
	end

	local can_draw = CANDRAW()

	if not can_draw then
		clear = true

		return
	end

	if drawpos_last:DistToSqr(drawpos_want) < 128 then return end
	local data = meshes[mesh_n]

	if #buff >= MAX_BUFF or not data or clear then
		clear = false
		mesh_n = mesh_n + 1
		buff = {}

		data = {Mesh(), buff}

		meshes[mesh_n] = data
	end

	local vertex_id = #buff + 1
	buff[vertex_id] = drawpos_want + Vector(.01, .01, .01)
	if #buff <= 1 then return end

	if #buff == 2 then
		local msg = {}

		for k, v in pairs(buff) do
			msg[k * 2 - 1] = want_color_index
			msg[k * 2] = v
		end

		draw3d.send(mesh_n, msg)
		print("draw3d.send() NEW: mesh_n=", mesh_n, "vertex_id=", vertex_id, "pos=", drawpos_want, "#buff=", #buff)
	else
		local msg = {
			[vertex_id] = {want_color_index, drawpos_want}
		}

		draw3d.send(mesh_n, nil, msg)
	end

	--do return end
	local m = Mesh()

	if data[1]:IsValid() then
		data[1]:Destroy()
	end

	data[1] = m
	--	for i = 2, #buff do
	--		local prev = buff[i - 1]
	--		local pos = buff[i]
	--		assert(isvector(pos))
	--		assert(isvector(prev))
	--	end
	mesh.Begin(m, MATERIAL_LINES, #buff - 1)
	local prev_pos

	for i = 2, #buff do
		local prev = buff[i - 1]
		local pos = buff[i]
		local r, g, b = 255, 111, 111
		local rr, gg, bb = 255, 111, 111
		mesh.Color(r, g, b, 0.5)
		mesh.Position(prev)
		mesh.AdvanceVertex() -- TODO: is this needed?
		mesh.Color(rr, gg, bb, 0.5)
		mesh.Position(pos)
		mesh.AdvanceVertex()
	end

	mesh.End()
end)

local vec_bad = Vector(-1, 1, 2)

function on_chunk_update(aid, chunk_pos, chunk)
	local t = pl_meshes[aid]

	if not t then
		t = {}
		pl_meshes[aid] = t
	end

	local verts = assert(chunk._verts)

	--print("on_chunk_update()","pl=",want_player(aid),"chunk_pos=",chunk_pos,"#chunk._verts=",#chunk._verts/2)
	if not t[chunk_pos] then
		print("new chunk", want_player(aid), "chunk_pos=", chunk_pos)
	end

	if t[chunk_pos] and t[chunk_pos]:IsValid() then
		t[chunk_pos]:Destroy()
	end

	local m = Mesh()

	for i = 3, #verts, 2 do
		local n = (i + 1) / 2
		local prev = verts[i - 1]
		local pos = verts[i + 1]
		--print("VERT: c=",chunk_pos," n=",n,"pos=",pos)
		if not prev or not pos then continue end
		assert(isvector(prev))
		assert(isvector(pos))
	end

	mesh.Begin(m, MATERIAL_LINES, #verts / 2 - 1)

	-- [[
	for i = 3, #verts, 2 do
		local col_prev = verts[i - 2]
		local col_cur = verts[i]
		local prev = verts[i - 1]
		local pos = verts[i + 1]
		if not prev or not pos then continue end
		if prev == vec_bad or pos == vec_bad then continue end
		local r, g, b = get_color(col_prev or 0)
		local rr, gg, bb = get_color(col_cur or 0)
		mesh.Color(r, g, b, 1)
		mesh.Position(prev)
		mesh.AdvanceVertex()
		mesh.Color(rr, gg, bb, 1)
		mesh.Position(pos)
		mesh.AdvanceVertex()
	end

	mesh.End()
	--]]
	t[chunk_pos] = m
end

hook.Add("PostDrawOpaqueRenderables", Tag, function(a, b)
	if not drawpos_last or not drawpos_want then return end
	render.SetMaterial(mat)
	local last_data

	for _, data in pairs(meshes) do
		last_data = data
	end

	local m = last_data and last_data[1]

	if m and m:IsValid() then
		m:Draw()
	end

	for pl, meshes in pairs(pl_meshes) do
		for mesh_id, m in pairs(meshes) do
			--local m = data[1]
			if m:IsValid() then
				m:Draw()
			end
		end
	end
end)
