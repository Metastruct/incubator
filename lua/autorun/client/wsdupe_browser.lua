local WSID = nil
local HTML = nil

local function ExtractWSID(url)
        if not url then return nil end
        return url:match("sharedfiles/filedetails/?%?id=(%d+)") or url:match("workshop/filedetails/?%?id=(%d+)")
end

local function DownloadAndArm(id)
        if hook.Run("DupeArmWorkshop", id) == false then return end

        local res, msg = hook.Run("CanArmDupe", LocalPlayer())
        if res == false then
                LocalPlayer():ChatPrint(msg or "Refusing to download Workshop dupe, server has blocked usage of the Duplicator tool!")
                return
        end

        MsgN("Downloading Workshop Dupe #" .. id .. "...")
        steamworks.DownloadUGC(id, function(name)
                MsgN("Finished - arming dupe!")
                RunConsoleCommand("dupe_arm", name)
        end)
end

local function init()
        if _G.NO_DUPES then return end
        spawnmenu.AddCreationTab("#steam_workshop", function()
                local container = vgui.Create("DPanel")
                container:SetSize(1, 1)

                local initialized = false
                local lastPaintTime = 0
                local focusHeld = false

                local function Init()
                        if initialized then return end
                        initialized = true

                        local actbar = vgui.Create("DPanel", container)
                        actbar:Dock(TOP)
                        actbar:SetTall(28)

                        local btn = vgui.Create("DButton", actbar)
                        btn:Dock(LEFT)
                        btn:SetText("#vgui_close")
                        btn:SetEnabled(true)
                        btn:SetWidth(130)
                        btn:SetImage("icon16/stop.png")

                        local oldBtnPaint = btn.Paint
                        btn.Paint = function(self, w, h)
                                if oldBtnPaint then oldBtnPaint(self, w, h) end
                                if WSID then
                                        local pulse = 0.5 + 0.5 * math.sin(RealTime() * 4)
                                        surface.SetDrawColor(100 + 155 * pulse, 180 + 75 * pulse, 100 + 80 * pulse, 120)
                                        surface.DrawRect(0, 0, w, h)
                                else
                                        surface.SetDrawColor(220, 160, 160, 120)
                                        surface.DrawRect(0, 0, w, h)
                                end
                        end

                        btn.DoClick = function()
                                if g_SpawnMenu and g_SpawnMenu.Close then g_SpawnMenu:Close() end
                                if WSID then
                                        btn:SetEnabled(false)
                                        DownloadAndArm(WSID)
                                        timer.Simple(1, function()
                                                if IsValid(btn) then btn:SetEnabled(true) end
                                        end)
                                end
                        end

                        local searchLbl = vgui.Create("DLabel", actbar)
                        searchLbl:Dock(LEFT)
                        searchLbl:SetText("#searchbar_placeholder")
                        searchLbl:SetTextColor(Color(180, 180, 180))
                        searchLbl:DockMargin(4, 0, 4, 0)
                        searchLbl:SizeToContents()

                        local search = vgui.Create("DTextEntry", actbar)
                        search:Dock(LEFT)
                        search:SetWide(180)
                        search:SetPlaceholderText("Search workshop...")
                        search:SetUpdateOnType(false)
                        search.OnEnter = function(self)
                                local q = tostring(self:GetValue()):urlencode()
                                local surl = "https://steamcommunity.com/workshop/browse/?appid=4000&browsesort=textsearch&section=readytouseitems&p=1&num_per_page=30&days=365&searchtext=" .. q .. "&requiredtags%5B%5D=Dupe"
                                HTML:OpenURL(surl)
                        end

                        local lbl = vgui.Create("DLabel", actbar)
                        lbl:Dock(FILL)
                        lbl:SetText("Browse workshop and click Load This Dupe")
                        lbl:SetTextColor(Color(180, 180, 180))
                        lbl:DockMargin(8, 0, 0, 0)

                        local nav = vgui.Create("DHTMLControls", container)
                        nav:Dock(TOP)
                        nav:SetTall(28)

                        HTML = vgui.Create("DHTML", container)
                        HTML:Dock(FILL)
                        nav:SetHTML(HTML)

                        HTML.OnFinishLoadingDocument = function(_, url)
                                local id = ExtractWSID(url)
                                if id then
                                        WSID = tonumber(id)
                                        btn:SetEnabled(true)
                                        btn:SetText("Deploy")
                                        btn:SetImage("icon16/page_paste.png")
                                        lbl:SetText("Ready - dupe #" .. WSID)
                                else
                                        WSID = nil
                                        btn:SetText("Close")
                                        btn:SetImage("icon16/stop.png")
                                        lbl:SetText("Navigate to a workshop item page")
                                end
                        end

                        local q = tostring(search:GetValue()):urlencode()
                        local homeurl = "https://steamcommunity.com/workshop/browse/?appid=4000&browsesort=textsearch&section=readytouseitems&p=1&num_per_page=30&days=365&searchtext=" .. q .. "&requiredtags%5B%5D=Dupe"
                        nav.HomeURL = homeurl
                        HTML:OpenURL(homeurl)
                end

                local OldPaint = container.Paint
                container.Paint = function(self, w, h)
                        Init()
                        if OldPaint then OldPaint(self, w, h) end

                        local t = RealTime()
                        if lastPaintTime == 0 or t - lastPaintTime > 0.5 then
                                print("wsdupe: OnTextEntryGetFocus called, focusHeld=true")
                                hook.Run("OnTextEntryGetFocus", HTML)
                                focusHeld = true
                        end
                        lastPaintTime = t
                end

                container.Think = function(self)
                        if focusHeld and RealTime() - lastPaintTime > 0.2 then
                                print("wsdupe: KillFocus called")
                                focusHeld = false
                                if HTML and HTML.KillFocus then HTML:KillFocus() end
                        end
                end

                return container
        end, "icon16/control_repeat_blue.png", 200)
end

hook.Add("PopulateToolMenu", "wsdupe_browser", init)
