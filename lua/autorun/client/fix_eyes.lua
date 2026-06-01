local eyes_fix = CreateClientConVar("eyes_fix", "1", true, false, "Toggle eye-fix: make other players look at you correctly")

hook.Add("PrePlayerDraw", "fix_them_eyeballs", function(ply)
    if not eyes_fix:GetBool() then return end
    if ply ~= LocalPlayer() then
        ply:SetEyeTarget(LocalPlayer():EyePos())
    end
end)
