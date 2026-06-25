-- Spectate Mode + Freecam

-- Mimics Counter-Strike spectating with delays: cycle players (left/right click), toggle freecam (reload), toggle 1st/3rd person (space).

    -- Configuration
    local spectateEnabled = false
    local spectateTargets = {}
    local currentIndex = 1
    local spectateFirstPerson = true

    -- Delay settings (in seconds)
    local firstThirdToggleDelay = 0.5
    local lastFirstThirdToggleTime = 0
    local freecamToggleDelay = 0.5
    local lastFreecamToggleTime = 0
    local playerSwitchDelay = 0.3
    local lastPlayerSwitchTime = 0

    -- Freecam state
    local freecam = { enabled = false, pos = Vector(), ang = Angle() }

    -- Store original view to restore
    local originalAngles = Angle()
    local originalPos = Vector()

    -- Movement settings
    local baseSpeed = 500
    local sprintMultiplier = 3

    -- Refresh list of players to spectate
    local function UpdateSpectateTargets()
        spectateTargets = {}
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= LocalPlayer() and IsValid(ply) then
                table.insert(spectateTargets, ply)
            end
        end
        if #spectateTargets > 0 then
            currentIndex = ((currentIndex - 1) % #spectateTargets) + 1
        else
            currentIndex = 0
        end
    end

    -- Toggle spectate mode
    local function ToggleSpectate(ply, cmd, args)
        spectateEnabled = not spectateEnabled
        local lp = LocalPlayer()
        if spectateEnabled then
            -- Enter spectate: save view, init states
            originalAngles = lp:EyeAngles()
            originalPos = lp:EyePos()
            freecam.pos = originalPos
            freecam.ang = originalAngles
            freecam.enabled = false
            spectateFirstPerson = true
            lastFirstThirdToggleTime = CurTime()
            lastFreecamToggleTime = CurTime()
            lastPlayerSwitchTime = CurTime()
            UpdateSpectateTargets()
        else
            -- Exit spectate: restore view
            lp:SetEyeAngles(originalAngles)
        end
    end
    concommand.Add("spectate_toggle", ToggleSpectate)

    -- Cycle spectate target
    local function CycleTarget(dir)
        if #spectateTargets == 0 then return end
        currentIndex = ((currentIndex - 1 + dir) % #spectateTargets) + 1
    end

    -- Handle key presses: cycle, freecam, toggle 1st/3rd with delays
    hook.Add("KeyPress", "Spectate_KeyPress", function(ply, key)
        if ply ~= LocalPlayer() or not spectateEnabled then return end
        local now = CurTime()
        if key == IN_ATTACK then
            if now - lastPlayerSwitchTime >= playerSwitchDelay then
                CycleTarget(1)
                lastPlayerSwitchTime = now
            end
        elseif key == IN_ATTACK2 then
            if now - lastPlayerSwitchTime >= playerSwitchDelay then
                CycleTarget(-1)
                lastPlayerSwitchTime = now
            end
        elseif key == IN_RELOAD then
            if now - lastFreecamToggleTime >= freecamToggleDelay then
                freecam.enabled = not freecam.enabled
                lastFreecamToggleTime = now
            end
        elseif key == IN_JUMP and not freecam.enabled then
            if now - lastFirstThirdToggleTime >= firstThirdToggleDelay then
                spectateFirstPerson = not spectateFirstPerson
                lastFirstThirdToggleTime = now
            end
        end
    end)

    -- CalcView hook for spectate/freecam
    hook.Add("CalcView", "Spectate_CalcView", function(ply, origin, angles, fov)
        if not spectateEnabled then return end

        if freecam.enabled then
            -- Freecam movement
            local speed = baseSpeed
            if input.IsKeyDown(KEY_LSHIFT) then speed = speed * sprintMultiplier end
            local dt = FrameTime()
            local mv = Vector()
            if input.IsKeyDown(KEY_W) then mv = mv + freecam.ang:Forward() end
            if input.IsKeyDown(KEY_S) then mv = mv - freecam.ang:Forward() end
            if input.IsKeyDown(KEY_D) then mv = mv + freecam.ang:Right() end
            if input.IsKeyDown(KEY_A) then mv = mv - freecam.ang:Right() end
            if input.IsKeyDown(KEY_SPACE) then mv = mv + Vector(0,0,1) end
            if input.IsKeyDown(KEY_LCONTROL) then mv = mv - Vector(0,0,1) end
            freecam.pos = freecam.pos + mv * speed * dt
            freecam.ang.r = 0
            return { origin = freecam.pos, angles = freecam.ang, fov = fov, drawviewer = false }
        else
            -- Spectating player
            local target = spectateTargets[currentIndex]
            if IsValid(target) and target:Alive() then
                if spectateFirstPerson then
                    return { origin = target:EyePos(), angles = target:EyeAngles(), fov = fov, drawviewer = false }
                else
                    -- Third-person: position behind and above, allow rotation via freecam.ang
                    local dist = 100
                    local height = 20
                    if lastFirstThirdToggleTime == CurTime() then freecam.ang = target:EyeAngles() end
                    local dir = freecam.ang:Forward()
                    local camPos = target:EyePos() - dir * dist + Vector(0,0,height)
                    return { origin = camPos, angles = freecam.ang, fov = fov, drawviewer = false }
                end
            end
        end
    end)

    -- Freecam and third-person view angles handling
    hook.Add("CreateMove", "Spectate_ViewMove", function(cmd)
        if not spectateEnabled then return end
        if freecam.enabled then
            local mx, my = cmd:GetMouseX(), cmd:GetMouseY()
            local sens = 0.022
            freecam.ang:RotateAroundAxis(Vector(0,0,1), -mx * sens)
            freecam.ang:RotateAroundAxis(freecam.ang:Right(), -my * sens)
            freecam.ang.r = 0
            cmd:SetViewAngles(freecam.ang)
            cmd:SetForwardMove(0)
            cmd:SetSideMove(0)
            cmd:SetUpMove(0)
        elseif not spectateFirstPerson then
            -- Third-person rotation
            local mx, my = cmd:GetMouseX(), cmd:GetMouseY()
            local sens = 0.022
            freecam.ang:RotateAroundAxis(Vector(0,0,1), -mx * sens)
            freecam.ang:RotateAroundAxis(freecam.ang:Right(), -my * sens)
            freecam.ang.r = 0
            cmd:SetViewAngles(freecam.ang)
        end
    end)

    -- Hide spectated player's model in first-person spectate
    hook.Add("PrePlayerDraw", "Spectate_HideTarget", function(ply)
        if spectateEnabled and not freecam.enabled and spectateFirstPerson and ply == spectateTargets[currentIndex] then
            return true
        end
    end)

    -- HUD overlay for spectate mode
    hook.Add("HUDPaint", "Spectate_HUD", function()
        if not spectateEnabled then return end
        surface.SetFont("DermaLarge")
        surface.SetTextColor(255,255,255,255)
        local status = freecam.enabled and "FREECAM" or string.format("SPECTATING: %s (%s)", (IsValid(spectateTargets[currentIndex]) and spectateTargets[currentIndex]:Nick() or "--"), spectateFirstPerson and "1st" or "3rd")
        local w,h = surface.GetTextSize(status)
        surface.SetTextPos((ScrW()-w)/2, 10)
        surface.DrawText(status)
        local instr = string.format("L/R: Next/Prev (%.1fs) | R: Toggle Freecam (%.1fs) | SPACE: 1st/3rd (%.1fs)", playerSwitchDelay, freecamToggleDelay, firstThirdToggleDelay)
        local iw, ih = surface.GetTextSize(instr)
        surface.SetTextPos((ScrW()-iw)/2, ScrH()-ih-10)
        surface.DrawText(instr)
    end)

