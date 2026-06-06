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

                local function Init()
                        if initialized then return end
                        initialized = true

                        local actbar = vgui.Create("DPanel", container)
                        actbar:Dock(TOP)
                        actbar:SetTall(28)

                        local btn = vgui.Create("DButton", actbar)
                        btn:Dock(LEFT)
                        btn:SetText("#dupes.arm")
                        btn:SetEnabled(false)
                        btn:SetWidth(130)
                        btn:SetImage("icon16/arrow_down.png")
                        btn.DoClick = function()
                                if not WSID then return end
                                btn:SetEnabled(false)
                                DownloadAndArm(WSID)
                                timer.Simple(1, function()
                                        if IsValid(btn) then btn:SetEnabled(true) end
                                end)
                        end

                        local search = vgui.Create("DTextEntry", actbar)
                        search:Dock(LEFT)
                        search:SetWide(180)
                        search:SetText("metastruct")
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

                        HTML.OnMousePressed = function(self, key)
                                if key == MOUSE_LEFT then
                                        self:RequestFocus()
                                end
                        end

                        HTML.OnFinishLoadingDocument = function(_, url)
                                local id = ExtractWSID(url)
                                if id then
                                        WSID = tonumber(id)
                                        btn:SetEnabled(true)
                                        btn:SetText(language.GetPhrase("dupes.arm") .. " #" .. WSID)
                                        lbl:SetText("Ready - dupe #" .. WSID)
                                else
                                        WSID = nil
                                        btn:SetEnabled(false)
                                        btn:SetText("#dupes.arm")
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
                        if OldPaint then return OldPaint(self, w, h) end
                end

                return container
        end, "icon16/control_repeat_blue.png", 200)
end

hook.Add("PopulateToolMenu", "wsdupe_browser", init)
