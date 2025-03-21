-- clientside speedtest_gui command
-- Author: utsuho
-- suggestion by ilker2445

if CLIENT then
    local speedtest_urls = {
        ["1mb"] = { "http://speedtest.tele2.net/1MB.zip" },
        ["2mb"] = { "http://speedtest.tele2.net/2MB.zip" },
        ["5mb"] = { "http://speedtest.tele2.net/5MB.zip" },
        ["10mb2"] = { "http://ipv4.download.thinkbroadband.com/10MB.zip" },
        ["100mb"] = { "https://hil-speed.hetzner.com/100MB.bin" },
        ["100mb2"] = { "http://speedtest.tele2.net/100MB.zip" },
        ["custom"] = nil,
    }

    local function start_speedtest(url, result_label, callback)
        if not IsValid(result_label) then return end

        result_label:SetText("Starting speed test... Downloading from " .. url)

        local start_time = SysTime()
        http.Fetch(url,
            function(_, len)
                if not IsValid(result_label) then return end

                local end_time = SysTime()
                local download_time = end_time - start_time
                if download_time <= 0 then
                    result_label:SetText("Error: Download time is too short to measure speed accurately.")
                    if callback then callback("Error: Download time is too short to measure speed accurately.") end
                    return
                end

                -- local speed_mbps = (len / time) * (10 ^ -6) * 8
                -- original calculation from by chat_commands_cl_cmds.lua is no longer used
                -- new calculation has more accuracy but will error on impossibly fast downloads so we check above
                local speed_mbps = (len * 8) / (download_time * 1024 * 1024)
                local result_text = string.format(
                    "speedtest_gui: Download completed in %.2f seconds. File size: %.2f MB. Speed: %.2f Mbps",
                    download_time,
                    len / (1024 * 1024),
                    speed_mbps
                )
                result_label:SetText(result_text)

                if callback then callback(result_text) end
            end,
            function(error)
                if not IsValid(result_label) then return end

                local error_text = "Speed test failed: " .. tostring(error)
                result_label:SetText(error_text)
                if callback then callback(error_text) end
            end
        )
    end

    local function open_speedtest_gui()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Speed Test")
        frame:SetSize(400, 360)
        frame:Center()
        frame:MakePopup()

        local dropdown = vgui.Create("DComboBox", frame)
        dropdown:SetPos(10, 40)
        dropdown:SetSize(380, 20)
        dropdown:SetValue("Select File Size")
        for key, urls in pairs(speedtest_urls) do
            local display_text = key:upper() .. (urls and (" - " .. urls[1]) or "")
            dropdown:AddChoice(display_text, key)
        end
        dropdown:AddChoice("Custom URL", "custom")

        local url_label = vgui.Create("DLabel", frame)
        url_label:SetPos(10, 70)
        url_label:SetSize(380, 20)
        url_label:SetText("URL: ")

        local custom_url_entry = vgui.Create("DTextEntry", frame)
        custom_url_entry:SetPos(10, 100)
        custom_url_entry:SetSize(380, 20)
        custom_url_entry:SetPlaceholderText("Enter custom URL here")
        custom_url_entry:SetVisible(false)

        local output_dropdown = vgui.Create("DComboBox", frame)
        output_dropdown:SetPos(10, 130)
        output_dropdown:SetSize(380, 20)
        output_dropdown:SetValue("Show only me")
        output_dropdown:AddChoice("Show only me")
        output_dropdown:AddChoice("Say in local")
        output_dropdown:AddChoice("Say in global")

        local start_button = vgui.Create("DButton", frame)
        start_button:SetPos(10, 160)
        start_button:SetSize(380, 30)
        start_button:SetText("Start Speed Test")

        local result_label = vgui.Create("DLabel", frame)
        result_label:SetPos(10, 200)
        result_label:SetSize(380, 60)
        result_label:SetWrap(true)
        result_label:SetText("")

        local accuracy_label = vgui.Create("DLabel", frame)
        accuracy_label:SetPos(10, 270)
        accuracy_label:SetSize(380, 40)
        accuracy_label:SetWrap(true)
        accuracy_label:SetText("Note: Download time may not be super accurate for very small files or fast connections.")

        dropdown.OnSelect = function(_, _, value, data)
            if data == "custom" then
                custom_url_entry:SetVisible(true)
                url_label:SetText("URL: (Enter custom URL below)")
            else
                custom_url_entry:SetVisible(false)
                local url = speedtest_urls[data] and speedtest_urls[data][1]
                url_label:SetText("URL: " .. (url or ""))
            end
        end

        start_button.DoClick = function()
            local selected = dropdown:GetSelected()
            local data = dropdown:GetOptionData(dropdown:GetSelectedID())
            if not selected or not data then
                result_label:SetText("Please select a file size.")
                return
            end

            local url
            if data == "custom" then
                url = custom_url_entry:GetValue()
                if url == "" then
                    result_label:SetText("Please enter a valid custom URL.")
                    return
                end
            else
                local urls = speedtest_urls[data]
                url = urls and urls[1]
            end

            if url then
                start_speedtest(url, result_label, function(result_text)
                    local output_type = output_dropdown:GetSelected()
                    if output_type == "Show only me" then
                        chat.AddText(result_text)
                    elseif output_type == "Say in local" then
                        SayLocal(result_text)
                    elseif output_type == "Say in global" then
                        Say(result_text)
                    else
                        chat.AddText("Invalid output type selected.")
                    end
                end)
            else
                result_label:SetText("Invalid selection.")
            end
        end
    end

    concommand.Add("speedtest_gui", open_speedtest_gui)
end
