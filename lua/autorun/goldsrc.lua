local Player = FindMetaTable("Player")

function Player:GetDuckProgress()
    local normal = self:GetViewOffset()[3]
    local ducked = self:GetViewOffsetDucked()[3]
    local current = self:GetCurrentViewOffset()[3]
    return 1 - (current - ducked) / (normal - ducked)
end


local playerTrace = { collisiongroup = COLLISION_GROUP_PLAYER }
local function tracePlayerHull(ply, start, endpos)
    playerTrace.start = start
    playerTrace.endpos = endpos
    playerTrace.mins, playerTrace.maxs = ply:GetCollisionBounds()
    playerTrace.filter = ply
    return util.TraceHull(playerTrace)
end



CreateClientConVar("goldsrc_unduck", "1", true, true, "Toggles the fast midair unduck behaviour", 0, 1 )

hook.Add("SetupMove", "GoldSrcUnduck", function(ply, mv, cmd)
    if ply:GetInfoNum("goldsrc_unduck", 1) == 0 then return end
    if ply:GetMoveType() ~= MOVETYPE_WALK then return end

    if not ply:OnGround() then
        ply.fastUnDuckAirTime = CurTime()

        if mv:KeyReleased(IN_DUCK) then
            local hullMin, hullMax = ply:GetHull()
            local hullDuckMin, hullDuckMax = ply:GetHullDuck()
            local maxSnapDistance = hullMax[3] - hullDuckMax[3]
            local origin = mv:GetOrigin()
            local traceResult = tracePlayerHull(ply, origin, origin - Vector(0, 0, maxSnapDistance))
            if traceResult.Hit then
                mv:SetOrigin(traceResult.HitPos)

                -- (Let's boost the player here too)
                if ply:GetInfoNum("goldsrc_gstrafe_boost", 1) > 0 then
                    local velocity = mv:GetVelocity()
                    local bonus = 50 + velocity:Length()^0.8 * 0.5
                    local direction = velocity:GetNormalized()
                    direction[3] = 0
                    mv:SetVelocity(velocity + direction * bonus)
                end
            end
        end
    end

    -- If player is in the air or was in the air at most 0.05 seconds ago
    -- We should make him unduck fast
    local shouldFastUnDuck = CurTime() - (ply.fastUnDuckAirTime or 0) < 0.05

    -- Toggle normal unduck
    if ply.fastUnDuck and not shouldFastUnDuck then
        if ply.normalUnDuckSpeed then
            ply:SetUnDuckSpeed(ply.normalUnDuckSpeed)
        end
        ply.fastUnDuck = false
    end

    -- Toggle fast unduck
    if not ply.fastUnDuck and shouldFastUnDuck then
        ply.normalUnDuckSpeed = ply:GetUnDuckSpeed()
        ply:SetUnDuckSpeed(0)
        ply.fastUnDuck = true
    end
end)


CreateClientConVar("goldsrc_gstrafe", "0", true, true, "Toggles the small jump when tapping duck (groundstrafing)", 0, 1 )
CreateClientConVar("goldsrc_gstrafe_boost", "1", true, true, "Toggles the speed boost when groundstrafing", 0, 1 )

hook.Add("SetupMove", "GoldSrcGStrafe", function(ply, mv, cmd)
    if ply:GetInfoNum("goldsrc_gstrafe", 1) == 0 then return end
    if ply:GetMoveType() ~= MOVETYPE_WALK then return end
    if not ply:OnGround() then return end

    if not mv:KeyReleased(IN_DUCK) then return end
    -- Runs on a successful unduck when on ground and in progress of ducking

    local heightMultiplier = 1 - ply:GetDuckProgress()
    if heightMultiplier <= 0 then return end

    local normalOffset = ply:GetViewOffset()[3]
    local duckedOffset = ply:GetViewOffsetDucked()[3]
    local offsetDifference = normalOffset - duckedOffset

    local hopHeight = 32 * heightMultiplier + offsetDifference
    
    local origin = mv:GetOrigin()
    local traceResult = tracePlayerHull(ply, origin, origin + Vector(0, 0, hopHeight))
    local move = traceResult.HitPos - origin

    mv:SetOrigin(origin + move)
    ply:SetGroundEntity(nil)
    
    if ply:GetInfoNum("goldsrc_gstrafe_boost", 1) > 0 then
        local velocity = mv:GetVelocity()
        local bonus = 50 + velocity:Length()^0.8 * 0.5
        local direction = velocity:GetNormalized()
        direction[3] = 0
        mv:SetVelocity(velocity + direction * bonus)
    end
end)

