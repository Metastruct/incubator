-- Loaded Model Browser GUI with grid preview
-- Opens via: model_browser_loaded

local function FormatSize(bytes)
    if bytes < 1024 then
        return tostring(bytes) .. " B"
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    else
        return string.format("%.1f MB", bytes / (1024 * 1024))
    end
end

local function BuildModelList()
    local seen = {}
    local list = {}

    local function AddModel(modelPath)
        if not modelPath or modelPath == "" or modelPath == "models/error.mdl" or seen[modelPath] then return end
        seen[modelPath] = true
        table.insert(list, {
            path = modelPath,
            filename = string.GetFileFromFilename(modelPath),
            size = file.Size(modelPath, "GAME") or 0,
            entCount = 0,
            physSize = 0,
        })
    end

    if util.GetLoadedModelsTable then
        local ok, raw = pcall(util.GetLoadedModelsTable)
        if ok and raw then
            for modelPath in pairs(raw) do
                AddModel(modelPath)
            end
        end
    end

    for _, ent in ipairs(ents.GetAll()) do
        local mdl = ent:GetModel()
        if mdl then AddModel(mdl) end
    end

    local okBsp, bsp = pcall(game.OpenBSP or function() end)
    if okBsp and bsp and bsp.GetStaticProps then
        local okProps, props = pcall(bsp.GetStaticProps, bsp)
        if okProps and props and props.entries then
            for _, entry in ipairs(props.entries) do
                if entry.PropType then
                    local path = "models/" .. entry.PropType
                    if not string.find(path, "%.mdl$") then
                        path = path .. ".mdl"
                    end
                    AddModel(path)
                end
            end
        end
    end

    return list
end

local function BuildEntityCounts(modelList)
    local counts = {}
    for _, ent in ipairs(ents.GetAll()) do
        local mdl = ent:GetModel()
        if mdl then
            counts[mdl] = (counts[mdl] or 0) + 1
        end
    end
    for _, info in ipairs(modelList) do
        info.entCount = counts[info.path] or 0
    end
end

local function BuildPhysicalSizes(modelList)
    for _, info in ipairs(modelList) do
        local mdlInfo = util.GetModelInfo(info.path)
        if mdlInfo and mdlInfo.HullMin and mdlInfo.HullMax then
            info.physSize = mdlInfo.HullMax:Distance(mdlInfo.HullMin)
        else
            info.physSize = 0
        end
    end
end

local function SortList(list, mode)
    if mode == "size" then
        table.sort(list, function(a, b) return a.size > b.size end)
    elseif mode == "filename" then
        table.sort(list, function(a, b) return a.filename:lower() < b.filename:lower() end)
    elseif mode == "entities" then
        table.sort(list, function(a, b) return a.entCount > b.entCount end)
    elseif mode == "physical" then
        table.sort(list, function(a, b) return a.physSize > b.physSize end)
    else
        table.sort(list, function(a, b) return a.path:lower() < b.path:lower() end)
    end
end

local CELL_SIZES = {96, 128, 256}
local BATCH_SIZE = 50

local activeFrame = nil

local function OpenBrowser()
    if IsValid(activeFrame) then
        activeFrame:MakePopup()
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(ScrW() * 0.95, ScrH() * 0.85)
    frame:Center()
    frame:SetTitle("Loaded Model Browser")
    frame:MakePopup()
    frame:SetSizable(true)
    activeFrame = frame

    frame.OnClose = function()
        activeFrame = nil
    end

    local allModels = BuildModelList()
    BuildEntityCounts(allModels)
    BuildPhysicalSizes(allModels)
    local currentSort = "entities"
    local currentCellSize = 128
    local currentSearch = ""
    local filteredModels = {}
    local batchTimers = {}

    -- Top bar
    local topBar = vgui.Create("DPanel", frame)
    topBar:Dock(TOP)
    topBar:DockMargin(4, 4, 4, 0)
    topBar:SetTall(30)

    local sortLabel = vgui.Create("DLabel", topBar)
    sortLabel:SetText("Sort:")
    sortLabel:Dock(LEFT)
    sortLabel:DockMargin(4, 0, 4, 0)
    sortLabel:SizeToContents()

    local sortCombo = vgui.Create("DComboBox", topBar)
    sortCombo:Dock(LEFT)
    sortCombo:SetWide(100)
    sortCombo:AddChoice("Path", "path")
    sortCombo:AddChoice("Size", "size")
    sortCombo:AddChoice("Filename", "filename")
    sortCombo:AddChoice("Entities", "entities")
    sortCombo:AddChoice("Physical Size", "physical")
    sortCombo:ChooseOption("Entities", 4)

    local sizeLabel = vgui.Create("DLabel", topBar)
    sizeLabel:SetText("Size:")
    sizeLabel:Dock(LEFT)
    sizeLabel:DockMargin(12, 0, 4, 0)
    sizeLabel:SizeToContents()

    local sizeCombo = vgui.Create("DComboBox", topBar)
    sizeCombo:Dock(LEFT)
    sizeCombo:SetWide(80)
    for _, s in ipairs(CELL_SIZES) do
        sizeCombo:AddChoice(s .. "px", s)
    end
    sizeCombo:ChooseOption("128px", 2)

    local searchBox = vgui.Create("DTextEntry", topBar)
    searchBox:Dock(FILL)
    searchBox:DockMargin(4, 0, 0, 0)
    searchBox:SetPlaceholderText("Search models...")

    local countLabel = vgui.Create("DLabel", topBar)
    countLabel:Dock(RIGHT)
    countLabel:DockMargin(8, 0, 4, 0)
    countLabel:SetText("")

    -- Right panel: preview + info + copy
    local rightPanel = vgui.Create("DPanel", frame)
    rightPanel:Dock(RIGHT)
    rightPanel:DockMargin(4, 4, 4, 4)
    rightPanel:SetWide(308)

    local previewPanel = vgui.Create("DModelPanel", rightPanel)
    previewPanel:Dock(TOP)
    previewPanel:SetTall(300)
    previewPanel:DockMargin(0, 0, 0, 4)
    previewPanel:SetFOV(45)

    previewPanel.LayoutEntity = function(self, ent)
        if self.m_bAnimated then
            self:RunAnimation()
        end
        ent:SetAngles(Angle(0, RealTime() * 30, 0))
    end

    local infoScroll = vgui.Create("DScrollPanel", rightPanel)
    infoScroll:Dock(FILL)

    local infoContainer = vgui.Create("DPanel", infoScroll)
    infoContainer:Dock(TOP)
    infoContainer:DockMargin(4, 0, 4, 4)
    infoContainer:SetTall(10)
    infoContainer.Paint = function() end

    local infoRows = {}

    local function AddInfoRow(label, value)
        local row = vgui.Create("DPanel", infoContainer)
        row:Dock(TOP)
        row:SetTall(16)
        row.Paint = function() end

        local lbl = vgui.Create("DLabel", row)
        lbl:Dock(LEFT)
        lbl:SetWide(90)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetText(label .. ":")
        lbl:SetTextColor(Color(180, 200, 230))

        local val = vgui.Create("DLabel", row)
        val:Dock(FILL)
        val:SetText(value)
        val:SetTooltip(value)

        table.insert(infoRows, row)
        return val
    end

    local function ClearInfo()
        for _, row in ipairs(infoRows) do
            if IsValid(row) then row:Remove() end
        end
        infoRows = {}
    end

    local function ShowDefaultInfo()
        ClearInfo()
        AddInfoRow("Status", "Select a model")
        infoContainer:SetTall(16)
    end

    -- Left panel: scrollable grid
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(4, 4, 0, 4)

    local iconLayout = vgui.Create("DIconLayout", scroll)
    iconLayout:Dock(FILL)
    iconLayout:SetSpaceX(4)
    iconLayout:SetSpaceY(4)

    local cellPanels = {}

    local function ClearGrid()
        for _, timerName in ipairs(batchTimers) do
            timer.Remove(timerName)
        end
        batchTimers = {}
        for _, pnl in ipairs(cellPanels) do
            if IsValid(pnl) then pnl:Remove() end
        end
        cellPanels = {}
    end

    local function SelectModel(info)
        previewPanel:SetModel(info.path)

        local ent = previewPanel.Entity
        if IsValid(ent) then
            local mn, mx = ent:GetRenderBounds()
            local center = (mn + mx) / 2
            local dist = mx:Length() * 1.2
            previewPanel:SetLookAt(center)
            previewPanel:SetCamPos(center + Vector(dist, dist, dist * 0.5))
        end

        ClearInfo()

        AddInfoRow("Path", info.path)
        AddInfoRow("Size", FormatSize(info.size) .. " (" .. info.size .. " B)")
        AddInfoRow("Entities", tostring(info.entCount))
        AddInfoRow("Phys Size", string.format("%.1f units", info.physSize))

        local mdlInfo = util.GetModelInfo(info.path)
        if istable(mdlInfo) then
            AddInfoRow("ModelName", mdlInfo.ModelName or "?")
            AddInfoRow("Version", tostring(mdlInfo.Version or "?"))
            AddInfoRow("Checksum", tostring(mdlInfo.Checksum or "?"))
            AddInfoRow("SurfaceProp", mdlInfo.SurfacePropName or "?")
            AddInfoRow("StaticProp", mdlInfo.StaticProp and "Yes" or "No")

            if mdlInfo.HullMin and mdlInfo.HullMax then
                local hmin = mdlInfo.HullMin
                local hmax = mdlInfo.HullMax
                AddInfoRow("Hull", string.format(
                    "(%.0f,%.0f,%.0f) to (%.0f,%.0f,%.0f)",
                    hmin.x, hmin.y, hmin.z, hmax.x, hmax.y, hmax.z))
            end

            if mdlInfo.EyePosition then
                local eye = mdlInfo.EyePosition
                AddInfoRow("EyePos", string.format("(%.1f, %.1f, %.1f)", eye.x, eye.y, eye.z))
            end

            AddInfoRow("Bones", tostring(mdlInfo.BoneCount or 0))
            AddInfoRow("Sequences", tostring(mdlInfo.SequenceCount or 0))
            AddInfoRow("Materials", tostring(mdlInfo.MaterialCount or 0))
            AddInfoRow("Skins", tostring(mdlInfo.SkinCount or 0))
            AddInfoRow("Meshes", tostring(mdlInfo.MeshCount or 0))
            AddInfoRow("Attachments", tostring(mdlInfo.AttachmentCount or 0))
            AddInfoRow("IncludeModels", tostring(mdlInfo.IncludeModelCount or 0))
        else
            AddInfoRow("ModelInfo", "Not available")
        end

        local totalH = 0
        for _, row in ipairs(infoRows) do
            if IsValid(row) then totalH = totalH + 18 end
        end
        infoContainer:SetTall(totalH + 4)
    end

    local function CreateCell(info, cellSize)
        local cell = vgui.Create("DPanel", iconLayout)
        cell:SetSize(cellSize + 4, cellSize + 20)

        local modelPnl = vgui.Create("DModelPanel", cell)
        modelPnl:SetSize(cellSize, cellSize)
        modelPnl:SetPos(2, 2)
        modelPnl:SetModel(info.path)
        modelPnl:SetMouseInputEnabled(false)

        modelPnl.LayoutEntity = function(self, ent)
            if self.m_bAnimated then
                self:RunAnimation()
            end
            ent:SetAngles(Angle(0, RealTime() * 20, 0))
        end

        if IsValid(modelPnl.Entity) then
            local mn, mx = modelPnl.Entity:GetRenderBounds()
            local center = (mn + mx) / 2
            local dist = mx:Length() * 1.2
            modelPnl:SetLookAt(center)
            modelPnl:SetCamPos(center + Vector(dist, dist, dist * 0.5))
        end

        local nameLabel = vgui.Create("DLabel", cell)
        nameLabel:SetPos(2, cellSize + 4)
        nameLabel:SetWide(cellSize)
        nameLabel:SetText(info.filename)
        nameLabel:SetFont("DermaDefault")
        nameLabel:SetContentAlignment(5)
        nameLabel:SetTooltip(info.path .. "\n" .. FormatSize(info.size) .. " | " .. info.entCount .. " entities")

        cell:SetCursor("hand")
        cell:SetMouseInputEnabled(true)

        cell.Paint = function(self, w, h)
            if self:IsHovered() then
                draw.RoundedBox(4, 0, 0, w, h, Color(80, 130, 200, 60))
            end
        end

        cell.OnMousePressed = function(self, mcode)
            if mcode == MOUSE_LEFT then
                SelectModel(info)
            elseif mcode == MOUSE_RIGHT then
                local menu = DermaMenu()

                menu:AddOption("Copy Path", function()
                    SetClipboardText(info.path)
                end)

                menu:AddOption("Spawn", function()
                    RunConsoleCommand("gm_spawn", info.path)
                end)

                menu:AddOption("View", function()
                    local viewer = vgui.Create("LoadedModelBrowserViewer")
                    viewer:SetModelPath(info.path)
                end)

                menu:AddSpacer()

                local matching = {}
                local bestEnt = nil
                for _, ent in ipairs(ents.GetAll()) do
                    if ent:GetModel() == info.path then
                        table.insert(matching, ent)
                        if not bestEnt and ent:EntIndex() > 0 then
                            bestEnt = ent
                        end
                    end
                end

                if not bestEnt and #matching > 0 then
                    bestEnt = matching[1]
                end

                if bestEnt and bestEnt:EntIndex() > 0 then
                    local entIndex = bestEnt:EntIndex()
                    local entClass = bestEnt:GetClass()
                    menu:AddOption("Goto #" .. entIndex .. " (" .. entClass .. ")", function()
                        RunConsoleCommand("aowl", "goto", "_" .. entIndex)
                    end)
                end

                if #matching > 1 then
                    local subMenu, subPanel = menu:AddSubMenu("All Entities (" .. #matching .. ")")
                    for _, ent in ipairs(matching) do
                        local idx = ent:EntIndex()
                        local cls = ent:GetClass()
                        if idx > 0 then
                            subMenu:AddOption("#" .. idx .. " " .. cls, function()
                                RunConsoleCommand("aowl", "goto", "_" .. idx)
                            end)
                        end
                    end
                    if subPanel then subPanel:SizeToContents() end
                end

                menu:Open()
            end
        end

        return cell
    end

    local function PopulateGrid(search, sort, cellSize)
        ClearGrid()

        local searchLower = search and search:lower() or ""
        filteredModels = {}

        for _, info in ipairs(allModels) do
            if searchLower == ""
                or info.path:lower():find(searchLower, 1, true)
                or info.filename:lower():find(searchLower, 1, true)
            then
                table.insert(filteredModels, info)
            end
        end

        SortList(filteredModels, sort)
        countLabel:SetText(#filteredModels .. " / " .. #allModels)

        local total = #filteredModels
        if total == 0 then return end

        local created = 0
        local timerName = "modelbrowser_batch_" .. SysTime()

        local function CreateBatch()
            if not IsValid(frame) then
                timer.Remove(timerName)
                return
            end

            local limit = math.min(created + BATCH_SIZE, total)
            for i = created + 1, limit do
                table.insert(cellPanels, CreateCell(filteredModels[i], cellSize))
            end
            created = limit

            if created >= total then
                timer.Remove(timerName)
            end
        end

        table.insert(batchTimers, timerName)
        timer.Create(timerName, 0, 0, CreateBatch)
        CreateBatch()
    end

    sortCombo.OnSelect = function(_, _, _, data)
        currentSort = data
        PopulateGrid(currentSearch, currentSort, currentCellSize)
    end

    sizeCombo.OnSelect = function(_, _, _, data)
        currentCellSize = data
        PopulateGrid(currentSearch, currentSort, currentCellSize)
    end

    searchBox.Think = function(self)
        local val = self:GetValue()
        if val ~= currentSearch then
            currentSearch = val
            PopulateGrid(currentSearch, currentSort, currentCellSize)
        end
    end

    ShowDefaultInfo()
    PopulateGrid("", currentSort, currentCellSize)
end

concommand.Add("model_browser_loaded", function()
    OpenBrowser()
end)

concommand.Add("model_list_loaded", function(_, _, args)
    local sortMode = string.lower(args[1] or "path")
    local valid = { path = true, size = true, filename = true, entities = true, physical = true }

    if not valid[sortMode] then
        print("[ModelBrowser] Unknown sort mode: " .. sortMode)
        print("[ModelBrowser] Available modes: path, size, filename, entities, physical")
        return
    end

    local list = BuildModelList()
    BuildEntityCounts(list)
    BuildPhysicalSizes(list)
    SortList(list, sortMode)

    print("=== Loaded Models (" .. #list .. " total, sorted by " .. sortMode .. ") ===")
    for i, info in ipairs(list) do
        print(string.format("%3d. [%8s] [%3d ent] [%6.1f hull] %s", i, FormatSize(info.size), info.entCount, info.physSize, info.path))
    end
    print("=== Done ===")
end, nil, "Lists all loaded models. Args: [path|size|filename|entities]")
