local Tag = 'avoid_players'
if SERVER then return end
local cl_move_avoid_players_test = CreateClientConVar('cl_move_avoid_players_test', '1', true, false, 'When enabled, automatically steers the player around other players that block their movement path. Moving forward nudges right, moving backward nudges left, so opposing players naturally go to opposite sides.')
local cl_move_avoid_notify = CreateClientConVar('cl_move_avoid_notify', '1', true, false, 'Show a chat notification the first time player avoidance triggers.')
local AVOID_DIST = 5
local HULL_W = 16
local HULL_H = 32
local NUDGE_STRONG = 0.7
local firstAvoid = true
-- Reusable objects to avoid per-tick allocation
local tr = {}
local ang = Angle()
local startOffset = Vector(0, 0, 32) -- trace from midsection to avoid floor/step clipping
local traceMins = Vector(-HULL_W, -HULL_W, 0)
local traceMaxs = Vector(HULL_W, HULL_W, HULL_H)

local traceData = {
	mins = traceMins,
	maxs = traceMaxs,
	mask = MASK_PLAYERSOLID,
	output = tr
}

hook.Add('CreateMove', Tag, function(cmd)
	local fwd = cmd:GetForwardMove()
	local sid = cmd:GetSideMove()
	if fwd == 0 and sid == 0 then return end
	
	if not cl_move_avoid_players_test:GetBool() then return end
	local me = LocalPlayer()
	if not me:IsValid() or not me:Alive() then return end
	if me:GetMoveType() ~= MOVETYPE_WALK or me:GetParent():IsValid() then return end
	
	-- Reuse pre-allocated angle, just update yaw
	local viewAng = cmd:GetViewAngles()
	ang.p = 0
	ang.y = viewAng.y
	ang.r = 0
	local fwdDir = ang:Forward()
	local rightDir = ang:Right()
	local moveDir = fwdDir * fwd + rightDir * sid
	local moveLen = moveDir:Length()
	if moveLen < 1 then return end
	moveDir:Normalize()
	local pos = me:GetPos()
	local startPos = pos + startOffset
	traceData.start = startPos
	traceData.endpos = startPos + moveDir * AVOID_DIST
	traceData.filter = me
	util.TraceHull(traceData)
	local ply = tr.Entity
	if not tr.Hit then return end

	if not ply:IsValid() or (not ply:IsPlayer() and not ply:IsNPC()) then return end
	if ply:GetMoveType() ~= MOVETYPE_WALK or ply:GetParent():IsValid() then return end

	if firstAvoid then
		firstAvoid = false

		if cl_move_avoid_notify:GetBool() then
			chat.AddText(Color(130, 200, 255), '[Avoid] ', color_white, 'Nudging around players/NPCs. Disable with cl_move_avoid_players_test 0, notification with cl_move_avoid_notify 0')
			surface.PlaySound('buttons/lightswitch2.wav')
		end
	end

	-- Nudge movement direction toward right-perpendicular
	local rx, ry = moveDir.y, -moveDir.x
	moveDir.x = moveDir.x + rx * NUDGE_STRONG
	moveDir.y = moveDir.y + ry * NUDGE_STRONG
	moveDir.z = 0
	moveDir:Normalize()
	local side = moveDir:Dot(rightDir) * moveLen
	--print(side)
	cmd:SetForwardMove(moveDir:Dot(fwdDir) * moveLen)
	cmd:SetSideMove(side)
end)