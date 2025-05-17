-- Trigger via !speedtestgui, /speedtestgui or .speedtestgui in chat

if CLIENT then

    local function OpenSpeedTest()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("In-Game Speedtest")
        frame:SetSize(800, 600)
        frame:Center()
        frame:MakePopup()

        local html = vgui.Create("DHTML", frame)
        html:Dock(FILL)

        html:AddFunction("GModSpeedTest", "sendResult", function(download, upload, ping)
            local msg = string.format(
                "Speedtest complete! Download: %.2f Mbps | Upload: %.2f Mbps | Ping: %d ms",
                download, upload, ping
            )
            chat.AddText(Color(100, 200, 100), msg)
            RunConsoleCommand("say", msg)
            frame:Close()
        end)

        html:OpenURL("https://ilker2445.uk/librespeed/index.html")
    end

    concommand.Add("speedtest_open", OpenSpeedTest)

    hook.Add("OnPlayerChat", "SpeedTest_ChatCommand", function(ply, text, teamChat, isDead)
        if ply ~= LocalPlayer() then return end
        text = tostring(text or "")
        local cmd = text:Trim():lower()

        if cmd == "!speedtestgui"
        or cmd == "/speedtestgui"
        or cmd == ".speedtestgui" then
            OpenSpeedTest()
            return true
        end
    end)

end