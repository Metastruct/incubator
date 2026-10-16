hook.Remove("Think", "MetaPets_Think")
hook.Remove("PostDrawTranslucentRenderables", "MetaPets_DrawHeadcrab")
hook.Remove("PlayerBindPress", "MetaPets_Interact")
hook.Remove("HUDPaint", "MetaPets_HUD")
hook.Remove("Think", "MetaPets_CrateOpening")
hook.Remove("Think", "MetaPets_PetPress")
hook.Remove("PostDrawTranslucentRenderables", "MetaPets_DrawCrateLabels")
concommand.Remove("metapets_menu")

if IsValid(MetaPetsMenu) then MetaPetsMenu:Remove() end
if IsValid(MetaPetsInteractionMenu) then MetaPetsInteractionMenu:Remove() end
if IsValid(MetaPetsPetModel) then MetaPetsPetModel:Remove() end
if crateProps then for _, crate in ipairs(crateProps) do if IsValid(crate.model) then crate.model:Remove() end end end
if revealProps then for _, reveal in ipairs(revealProps) do if IsValid(reveal.model) then reveal.model:Remove() end end end
if pressModels then for _, item in ipairs(pressModels) do if IsValid(item.model) then item.model:Remove() end end end

MetaPetsPetModel = nil

MetaPetsData = {
    owned = {},
    active = nil,
    stats = {},
    crates = { wood = 2, silver = 0, gold = 0 },
    items = {}
}

local nextPetUID = 0
local crateOpening = nil
local crateProps = {}
local revealProps = {}
local pressSequence = nil
local pressModels = {}

local paintColours = {
    { name = "Red", colour = Color(220, 65, 65) },
    { name = "Blue", colour = Color(65, 125, 235) },
    { name = "Green", colour = Color(75, 195, 105) },
    { name = "Purple", colour = Color(155, 75, 220) },
    { name = "Pink", colour = Color(240, 115, 175) },
    { name = "Orange", colour = Color(240, 145, 55) },
    { name = "Yellow", colour = Color(245, 220, 75) },
    { name = "Cyan", colour = Color(70, 220, 220) },
    { name = "White", colour = Color(235, 235, 235) },
    { name = "Black", colour = Color(45, 45, 45) }
}

local crateTiers = {
    wood = { name = "Wooden Crate", model = "models/props_lab/kennel_physics.mdl", material = "models/mspropp/lobby_woodwall001a", tint = Color(170, 125, 78), speciesWeights = { headcrab=32, pigeon=23, seagull=18, crow=10, monk=5, goldengman=1, poisonheadcrab=2, rollermine=3, minidog=3, minivort=3 } },
    silver = { name = "Silver Crate", model = "models/props_lab/kennel_physics.mdl", material = "models/shadertest/shader2", tint = Color(185, 195, 210), speciesWeights = { headcrab=18, pigeon=18, seagull=20, crow=15, monk=10, goldengman=4, poisonheadcrab=4, rollermine=4, minidog=4, minivort=3 } },
    gold = { name = "Gold Crate", model = "models/props_lab/kennel_physics.mdl", material = "models/player/shared/gold_player", tint = Color(245, 185, 45), speciesWeights = { headcrab=8, pigeon=12, seagull=16, crow=17, monk=16, goldengman=10, poisonheadcrab=6, rollermine=5, minidog=5, minivort=5 } }
}

local crateTierOrder = { "wood", "silver", "gold" }
local shinyMaterial = "models/player/shared/gold_player"

local function getCrateModel(tier)
    local cfg = crateTiers[tier]
    if cfg and util.IsValidModel(cfg.model) then return cfg.model end
    return "models/props_lab/kennel_physics.mdl"
end

local function applyCrateAppearance(entity, tier)
    if not IsValid(entity) then return end
    local cfg = crateTiers[tier]
    if not cfg then return end
    entity:SetMaterial(cfg.material or "")
    entity:SetColor(cfg.tint)
    entity:SetRenderMode(RENDERMODE_TRANSCOLOR)
end

local rarityInfo = {
    Common = { colour = Color(190, 190, 190) },
    Uncommon = { colour = Color(100, 210, 120) },
    Rare = { colour = Color(90, 160, 255) },
    Epic = { colour = Color(190, 110, 255) },
    Legendary = { colour = Color(255, 190, 65) }
}

local pets = {
    {
        id = "headcrab",
        name = "Headcrab",
        model = "models/headcrabclassic.mdl",
        rarity = "Common"
    },
    {
        id = "pigeon",
        name = "Pigeon",
        model = "models/pigeon.mdl",
        rarity = "Common"
    },
    {
        id = "seagull",
        name = "Seagull",
        model = "models/seagull.mdl",
        rarity = "Uncommon"
    },
    {
        id = "crow",
        name = "Crow",
        model = "models/crow.mdl",
        rarity = "Rare"
    },
    {
        id = "monk",
        name = "Father Grigori",
        model = "models/monk.mdl",
        scale = 0.35,
        rarity = "Epic"
    },
    {
        id = "goldengman",
        name = "Golden G-Man",
        model = "models/player/gman_high.mdl",
        gold = true,
        rarity = "Legendary"
    },
    {
        id = "poisonheadcrab",
        name = "Poison Headcrab",
        model = "models/headcrabblack.mdl",
        rarity = "Epic"
    },
    {
        id = "rollermine",
        name = "Rollermine",
        model = "models/roller.mdl",
        scale = 0.65,
        rarity = "Rare"
    },
    {
        id = "minidog",
        name = "Mini Dog",
        model = "models/dog.mdl",
        scale = 0.25,
        rarity = "Legendary"
    },
    {
        id = "minivort",
        name = "Mini Vortigaunt",
        model = "models/vortigaunt.mdl",
        scale = 0.35,
        rarity = "Rare"
    }
}

local petPosition
local petYaw = 0
local nextWander = 0
local isCarried = false
local currentSequence
local petMoving = false
local petMoveSpeed = 0
local normalPetScale = 1
local carryPetScale = 0.65
local isFlying = false
local flyingSide = math.random(0, 1) == 0 and -1 or 1
local nextStatsUpdate = CurTime() + 60
local nextPassiveXP = CurTime() + 45
local manuallyPutDown = false

local getPetStats

local function getSpeciesInfo(id)
    for _, pet in ipairs(pets) do
        if pet.id == id then return pet end
    end
end

local function getPetInfo(id)
    if not id then return nil end
    local owned = MetaPetsData.owned[id]
    if owned then
        local species = getSpeciesInfo(owned.speciesId)
        if not species then return nil end
        local result = table.Copy(species)
        result.uid = owned.uid
        result.speciesId = owned.speciesId
        result.variation = owned.variation
        result.paintName = owned.paintName
        result.paintColor = owned.paintColor
        result.shiny = owned.shiny
        result.special = owned.special
        return result
    end
    return getSpeciesInfo(id)
end

local function getOwnedPetIDs()
    local ids = {}
    for id in pairs(MetaPetsData.owned) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function addOwnedPet(speciesId, variation, paint, special)
    local species = getSpeciesInfo(speciesId)
    if not species then return end
    nextPetUID = nextPetUID + 1
    local uid = "pet_" .. nextPetUID
    local painted = variation == "painted" or variation == "shiny_painted"
    local shiny = variation == "shiny" or variation == "shiny_painted"
    MetaPetsData.owned[uid] = {
        uid = uid, speciesId = speciesId, variation = variation,
        paintName = painted and paint.name or nil,
        paintColor = painted and paint.colour or nil,
        shiny = shiny, special = special
    }
    getPetStats(uid)
    return uid
end

getPetStats = function(id)
    if not MetaPetsData.stats[id] then
        MetaPetsData.stats[id] = {
            happiness = 75,
            hunger = 20,
            level = 1,
            xp = 0,
            neglect = 0,
            care = 50
        }
    end

    return MetaPetsData.stats[id]
end

local function addPetXP(id, amount)
    local stats = getPetStats(id)
    stats.xp = stats.xp + amount

    while stats.xp >= stats.level * 100 do
        stats.xp = stats.xp - stats.level * 100
        stats.level = stats.level + 1
        stats.happiness = math.min(100, stats.happiness + 5)

        local pet = getPetInfo(id)

        notification.AddLegacy(
            (pet and pet.name or "Your pet")
                .. " reached level " .. stats.level .. "!",
            NOTIFY_GENERIC,
            3
        )
    end
end

local function feedPet(id)
    local stats = getPetStats(id)

    stats.hunger = math.max(0, stats.hunger - 35)
    stats.happiness = math.min(100, stats.happiness + 5)
    stats.neglect = math.max(0, (stats.neglect or 0) - 2)
    stats.care = math.min(100, (stats.care or 50) + 2)

    addPetXP(id, 10)
    surface.PlaySound("buttons/button14.wav")
end

local function petPet(id)
    local stats = getPetStats(id)

    stats.happiness = math.min(100, stats.happiness + 12)
    stats.care = math.min(100, (stats.care or 50) + 1)

    addPetXP(id, 5)
    surface.PlaySound("buttons/button15.wav")
end

local function getMood(stats)
    if stats.hunger >= 85 then return "Starving" end
    if stats.happiness <= 20 then return "Miserable" end
    if stats.hunger >= 65 then return "Hungry" end
    if stats.happiness >= 80 then return "Happy" end
    if stats.happiness >= 50 then return "Content" end
    return "Unhappy"
end

local function getRarity(pet)
    return rarityInfo[pet and pet.rarity or "Common"]
        or rarityInfo.Common
end

local function getStatLabel(stats)
    return string.format(
        "Happiness: %d%%   Hunger: %d%%\nLevel: %d   XP: %d/%d\nMood: %s   Care: %d%%",
        math.floor(stats.happiness),
        math.floor(stats.hunger),
        stats.level,
        stats.xp,
        stats.level * 100,
        getMood(stats),
        math.floor(stats.care or 50)
    )
end

local function isBirdPet(pet)
    return pet and (
        pet.id == "pigeon"
        or pet.id == "seagull"
        or pet.id == "crow"
        or pet.id == "monk"
    )
end

local function playerIsFlying(ply)
    if not IsValid(ply) then return false end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return true end
    if ply:InVehicle() then return true end

    return ply:GetVelocity().z > 120
end

local function getPlayer()
    local ply = LocalPlayer()

    if not IsValid(ply) or not ply:Alive() then
        return
    end

    return ply
end

local function getPet()
    if IsValid(MetaPetsPetModel) then
        return MetaPetsPetModel
    end
end

local function findSequence(entity, names)
    for _, name in ipairs(names) do
        local sequence = entity:LookupSequence(name)

        if sequence and sequence >= 0 then
            return sequence
        end
    end
end

local function animateGrigoriFlap(entity, active)
    if not IsValid(entity) then return end

    local leftArm = entity:LookupBone("ValveBiped.Bip01_L_UpperArm")
    local rightArm = entity:LookupBone("ValveBiped.Bip01_R_UpperArm")
    local leftForearm = entity:LookupBone("ValveBiped.Bip01_L_Forearm")
    local rightForearm = entity:LookupBone("ValveBiped.Bip01_R_Forearm")

    if not active then
        if leftArm then
            entity:ManipulateBoneAngles(leftArm, angle_zero)
        end
        if rightArm then
            entity:ManipulateBoneAngles(rightArm, angle_zero)
        end
        if leftForearm then
            entity:ManipulateBoneAngles(leftForearm, angle_zero)
        end
        if rightForearm then
            entity:ManipulateBoneAngles(rightForearm, angle_zero)
        end
        return
    end

    local flap = math.sin(CurTime() * 18) * 48
    local tuck = math.cos(CurTime() * 18) * 18

    if leftArm then
        entity:ManipulateBoneAngles(leftArm, Angle(flap, 0, -flap))
    end

    if rightArm then
        entity:ManipulateBoneAngles(rightArm, Angle(-flap, 0, flap))
    end

    if leftForearm then
        entity:ManipulateBoneAngles(leftForearm, Angle(-tuck, 0, -12))
    end

    if rightForearm then
        entity:ManipulateBoneAngles(rightForearm, Angle(tuck, 0, 12))
    end
end

local function setPetAnimation(moving)
    local entity = getPet()
    if not IsValid(entity) then return end

    local pet = getPetInfo(MetaPetsData.active)
    if not pet then return end

    local grigoriFlying = pet.id == "monk" and isFlying

    animateGrigoriFlap(entity, grigoriFlying)

    local choices

    if isFlying and not grigoriFlying then
        choices = {
            "fly", "fly_all", "Fly01", "fly_loop", "bird_fly",
            "flap", "Flap", "flying", "hover", "idle_fly"
        }
    elseif grigoriFlying then
        choices = {
            "idle_all", "idle", "Idle01", "idle_unarmed"
        }
    elseif moving then
        choices = {
            "walk_all", "walk", "WalkUnarmed",
            "run_all", "run", "RunUnarmed", "move"
        }
    else
        choices = {
            "idle_all", "idle", "Idle01", "idle_unarmed"
        }
    end

    local sequence = findSequence(entity, choices)

    if not sequence then
        local activity

        if isFlying then
            activity = ACT_FLY
        else
            activity = moving and ACT_WALK or ACT_IDLE
        end

        sequence = entity:SelectWeightedSequence(activity)
    end

    if sequence and sequence >= 0 and sequence ~= currentSequence then
        currentSequence = sequence
        entity:ResetSequence(sequence)
        entity:SetCycle(0)
        entity:SetPlaybackRate(1)
    end

    entity:FrameAdvance(FrameTime())
end

local function removePetModel()
    if IsValid(MetaPetsPetModel) then
        MetaPetsPetModel:Remove()
    end

    MetaPetsPetModel = nil
    petPosition = nil
    currentSequence = nil
    petMoving = false
    petMoveSpeed = 0
    isCarried = false
    isFlying = false
    manuallyPutDown = false
end

local function createPetModel(pet)
    removePetModel()
    if not pet then return end

    local modelPath = pet.model
    local entity = ClientsideModel(modelPath, RENDERGROUP_OPAQUE)

    if not IsValid(entity) then
        notification.AddLegacy(
            "Couldn't load " .. pet.name .. "'s model.",
            NOTIFY_ERROR,
            4
        )
        return
    end

    MetaPetsPetModel = entity
    entity:SetNoDraw(true)

    normalPetScale = pet.scale or 1
    entity:SetModelScale(normalPetScale, 0)

    if pet.gold then
        entity:SetColor(Color(255, 205, 75))
        entity:SetMaterial("models/debug/debugwhite")
    elseif pet.paintColor then
        entity:SetColor(pet.paintColor)
        entity:SetMaterial("models/debug/debugwhite")
    else
        entity:SetColor(color_white)
        entity:SetMaterial("")
    end
    if pet.shiny or pet.gold then entity:SetMaterial("models/player/shared/gold_player") end

    local ply = getPlayer()

    if IsValid(ply) then
        petPosition = ply:GetPos() - ply:GetForward() * 75
        petYaw = ply:EyeAngles().y
    end

    currentSequence = nil
    petMoveSpeed = 0
    setPetAnimation(false)
end

local function setActivePet(id)
    if id and not MetaPetsData.owned[id] then return end

    MetaPetsData.active = id
    isCarried = false
    isFlying = false
    manuallyPutDown = false
    flyingSide = math.random(0, 1) == 0 and -1 or 1

    if id then
        createPetModel(getPetInfo(id))
    else
        removePetModel()
    end
end

local function createButton(parent, label, x, y, w, h, callback)
    local button = vgui.Create("DButton", parent)

    button:SetPos(x, y)
    button:SetSize(w, h)
    button:SetText(label)
    button.DoClick = callback

    return button
end

local function createPreview(parent, pet, x, y, w, h)
    local preview = vgui.Create("DModelPanel", parent)

    preview:SetPos(x, y)
    preview:SetSize(w, h)
    preview:SetModel(pet.model)
    preview:SetFOV(35)
    preview:SetAnimated(true)

    preview.LayoutEntity = function(self, entity)
        if not IsValid(entity) then return end

        entity:SetAngles(Angle(0, RealTime() * 12 % 360, 0))

        if pet.scale then
            entity:SetModelScale(pet.scale, 0)
        end

        if pet.gold then
            entity:SetColor(Color(255, 205, 75))
            entity:SetMaterial("models/debug/debugwhite")
        elseif pet.paintColor then
            entity:SetColor(pet.paintColor)
            entity:SetMaterial("models/debug/debugwhite")
        else
            entity:SetColor(color_white)
            entity:SetMaterial("")
        end
        if pet.shiny or pet.gold then entity:SetMaterial("models/player/shared/gold_player") end

        self:RunAnimation()
    end

    local entity = preview:GetEntity()

    if IsValid(entity) then
        local mins, maxs = entity:GetRenderBounds()
        local centre = (mins + maxs) * 0.5
        local size = maxs:Distance(mins)

        preview:SetLookAt(centre)
        preview:SetCamPos(centre + Vector(size, size, size * 0.6))
    end

    return preview
end

local function placePetOnGround(ply)
    local entity = getPet()
    if not IsValid(entity) or not IsValid(ply) then return end

    local forward = Angle(0, ply:EyeAngles().y, 0):Forward()
    local desired = ply:GetPos() + forward * 55

    local trace = util.TraceLine({
        start = desired + Vector(0, 0, 80),
        endpos = desired - Vector(0, 0, 160),
        filter = { ply, entity },
        mask = MASK_SOLID
    })

    if trace.Hit then
        local mins = entity:GetRenderBounds()
        petPosition = trace.HitPos - Vector(0, 0, mins.z)
    else
        petPosition = desired
    end

    petYaw = ply:EyeAngles().y
    entity:SetPos(petPosition)
    entity:SetAngles(Angle(0, petYaw, 0))
    entity:SetModelScale(normalPetScale, 0)

    isCarried = false
    isFlying = false
    manuallyPutDown = true
    petMoving = false
    petMoveSpeed = 0
    currentSequence = nil

    setPetAnimation(false)
end

local function openInteractionMenu()
    if IsValid(MetaPetsInteractionMenu) then
        MetaPetsInteractionMenu:Remove()
        return
    end

    local frame = vgui.Create("DFrame")
    MetaPetsInteractionMenu = frame

    frame:SetSkin("dark_meta")
    frame:SetSize(250, 190)
    frame:SetTitle("Your Pet")
    frame:Center()
    frame:MakePopup()

    createButton(
        frame,
        isCarried and "Put Down" or "Pick Up",
        15, 40, 220, 32,
        function()
            local ply = getPlayer()
            local entity = getPet()

            if not IsValid(ply) or not IsValid(entity) then
                frame:Close()
                return
            end

            if isCarried then
                placePetOnGround(ply)
            else
                isCarried = true
                manuallyPutDown = false
                isFlying = false
                entity:SetModelScale(normalPetScale * carryPetScale, 0)
            end

            frame:Close()
        end
    )

    createButton(frame, "Pet", 15, 80, 220, 32, function()
        local id = MetaPetsData.active

        if id then
            petPet(id)
            notification.AddLegacy(
                "Your pet looks happier!",
                NOTIFY_HINT,
                3
            )
        end

        frame:Close()
    end)

    createButton(frame, "Feed", 15, 120, 220, 32, function()
        local id = MetaPetsData.active

        if id then
            feedPet(id)
            notification.AddLegacy(
                "Your pet has been fed!",
                NOTIFY_HINT,
                3
            )
        end

        frame:Close()
    end)
end

local function openMenu()
    if IsValid(MetaPetsMenu) then
        MetaPetsMenu:Remove()
    end

    local frame = vgui.Create("DFrame")
    MetaPetsMenu = frame

    frame:SetSkin("dark_meta")
    frame:SetSize(850, 560)
    frame:Center()
    frame:SetTitle("MetaPets - Your Companion Collection")
    frame:MakePopup()

    local sidebar = vgui.Create("DPanel", frame)
    sidebar:SetPos(14, 80)
    sidebar:SetSize(180, 465)
    sidebar:SetSkin("dark_meta")

    local content = vgui.Create("DPanel", frame)
    content:SetPos(208, 80)
    content:SetSize(628, 465)
    content:SetSkin("dark_meta")

    local currentTab = "pets"

    local function drawContent()
        if not IsValid(content) then return end
        content:Clear()
        local showingActivePet = currentTab == "pets" and MetaPetsData.active ~= nil
        local heading = vgui.Create("DLabel", content)
        heading:SetPos(18, 12)
        heading:SetFont("Trebuchet18")
        heading:SetText(currentTab == "shop" and "Pet Shop" or (showingActivePet and "Your Pet" or "My Pets"))
        heading:SizeToContents()

        local demoNotice = vgui.Create("DLabel", content)
        demoNotice:SetPos(18, 34)
        demoNotice:SetSize(580, 14)
        demoNotice:SetFont("DermaDefault")
        demoNotice:SetTextColor(Color(255, 205, 105))
        demoNotice:SetText("DEMO: Pets, crates, stats and progress are temporary and will not save.")

        if currentTab == "shop" then
            local odds = vgui.Create("DButton", content)
            odds:SetPos(450, 8); odds:SetSize(150, 28); odds:SetText("View crate odds")
            odds.DoClick = function()
                local f = vgui.Create("DFrame")
                f:SetSkin("dark_meta"); f:SetSize(520, 300); f:Center(); f:SetTitle("Unboxing odds"); f:MakePopup()
                local variations = vgui.Create("DLabel", f)
                variations:SetPos(20, 52)
                variations:SetSize(470, 200)
                variations:SetFont("Trebuchet18")
                variations:SetWrap(true)
                variations:SetText("Normal, 89.00%\n\nPainted, 10.00%\n\nShiny, 0.99%\n\nShiny + Painted, 0.01%")
            end
            local list = vgui.Create("DScrollPanel", content); list:SetPos(14,64); list:SetSize(600,386)
            for _, tier in ipairs(crateTierOrder) do
                local cfg = crateTiers[tier]
                local card = vgui.Create("DPanel", list); card:Dock(TOP); card:DockMargin(0,0,0,8); card:SetTall(88); card:SetSkin("dark_meta")
                local crateIcon = vgui.Create("DModelPanel", card); crateIcon:SetPos(8,4); crateIcon:SetSize(78,78); crateIcon:SetModel(getCrateModel(tier)); crateIcon:SetFOV(38); crateIcon:SetAnimated(false)
                crateIcon:SetCamPos(Vector(65,65,40)); crateIcon:SetLookAt(Vector(0,0,18))
                crateIcon.LayoutEntity = function(self, ent)
                    if IsValid(ent) then
                        ent:SetAngles(Angle(0, RealTime()*8%360, 0))
                        applyCrateAppearance(ent, tier)
                    end
                end
                local label = vgui.Create("DLabel", card); label:SetPos(92,14); label:SetFont("DermaDefaultBold"); label:SetText(cfg.name); label:SizeToContents()
                local count = vgui.Create("DLabel", card); count:SetPos(92,40); count:SetText("Owned: INFINITE  |  Demo mode"); count:SizeToContents()
                createButton(card, "Buy", 350, 12, 100, 32, function()
                    notification.AddLegacy("Crate purchases need server-side economy integration.", NOTIFY_HINT, 4)
                end)
                createButton(card, "Open", 460, 12, 110, 32, function()
                    if false then notification.AddLegacy("You don't have this crate.", NOTIFY_ERROR, 3); return end
                    local ply = getPlayer(); if not IsValid(ply) then return end
                    local pos = ply:GetPos() + ply:GetForward() * 65
                    local tr = util.TraceLine({start=pos+Vector(0,0,80), endpos=pos-Vector(0,0,180), filter=ply, mask=MASK_SOLID})
                    if tr.Hit then pos = tr.HitPos end
                    local prop = ClientsideModel(getCrateModel(tier), RENDERGROUP_OPAQUE)
                    if IsValid(prop) then
                        prop:SetAngles(Angle(0, ply:EyeAngles().y, 0))
                        applyCrateAppearance(prop, tier)
                        local mins = prop:OBBMins()
                        pos.z = pos.z - mins.z
                        prop:SetPos(pos)
                        crateProps[#crateProps+1] = {model=prop, pos=pos, started=CurTime(), tier=tier, owner=ply:Nick(), state="opening"}
                    end
                    local total = 0
                    for _, weight in pairs(cfg.speciesWeights) do total = total + weight end
                    local pick = math.Rand(0, total)
                    local running = 0
                    local speciesId
                    for id, weight in pairs(cfg.speciesWeights) do
                        running = running + weight
                        if pick <= running then speciesId = id break end
                    end
                    local variationRoll = math.Rand(0, 1)
                    local variation = variationRoll < 0.0001 and "shiny_painted"
                        or (variationRoll < 0.01 and "shiny"
                        or (variationRoll < 0.11 and "painted" or "normal"))
                    local paint = table.Random(paintColours)
                    crateOpening = {finish=CurTime()+3.2, speciesId=speciesId, variation=variation, paint=paint, tier=tier, pos=pos, yaw=ply:EyeAngles().y, owner=ply:Nick()}
                    if IsValid(MetaPetsMenu) then MetaPetsMenu:Close() end
                    surface.PlaySound("physics/wood/wood_crate_impact_hard3.wav")
                    notification.AddLegacy("The crate is opening...", NOTIFY_HINT, 3)
                    drawContent()
                end)
            end
            return
        end

        if showingActivePet then
            local pet = getPetInfo(MetaPetsData.active)
            if not pet or not MetaPetsData.owned[pet.uid] then setActivePet(nil); drawContent(); return end
            local card = vgui.Create("DPanel", content); card:SetPos(14,48); card:SetSize(600,250); card:SetSkin("dark_meta")
            createPreview(card, pet, 12,12,170,220)
            local name = vgui.Create("DLabel", card); name:SetPos(200,24); name:SetFont("Trebuchet24"); name:SetText(pet.name .. (pet.variation and pet.variation ~= "normal" and " - " .. pet.variation or "")); name:SizeToContents()
            local rarity = vgui.Create("DLabel", card); rarity:SetPos(202,52); rarity:SetText(pet.rarity); rarity:SetTextColor(getRarity(pet).colour); rarity:SizeToContents()
            local statsLabel = vgui.Create("DLabel", card); statsLabel:SetPos(200,75); statsLabel:SetSize(365,70); statsLabel:SetWrap(true); statsLabel:SetText(getStatLabel(getPetStats(pet.uid)))
            statsLabel.Think = function(self) local t=getStatLabel(getPetStats(pet.uid)); if self:GetText()~=t then self:SetText(t) end end
            local status = vgui.Create("DLabel", card); status:SetPos(200,160); status:SetSize(365,30); status:SetText("This is your active companion.")
            createButton(content,"Return to My Pets",14,318,220,38,function() setActivePet(nil); drawContent() end)
            return
        end

        local search = vgui.Create("DTextEntry", content)
        search:SetPos(14,54); search:SetSize(285,28); search:SetPlaceholderText("Search your pets...")
        local selectedForPress = MetaPetsSelectedForPress or {}
        MetaPetsSelectedForPress = selectedForPress
        local pressButton = vgui.Create("DButton", content)
        pressButton:SetPos(310,54); pressButton:SetSize(304,28); pressButton:SetText("Hydraulic Press: combine 3 pets for a crate")
        pressButton.DoClick = function()
            local chosen, chosenPets = {}, {}
            for uid, yes in pairs(selectedForPress) do
                if yes and MetaPetsData.owned[uid] then chosen[#chosen+1]=uid; chosenPets[#chosenPets+1]=getPetInfo(uid) end
            end
            if #chosen ~= 3 then notification.AddLegacy("Select exactly 3 pets to combine into a crate.", NOTIFY_ERROR, 3); return end
            local rarityScore = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
            local totalScore = 0
            for _, pet in ipairs(chosenPets) do
                totalScore = totalScore + (pet and rarityScore[pet.rarity] or 1)
            end
            local averageScore = totalScore / #chosenPets
            local targetTier = averageScore >= 3.5 and "gold" or (averageScore >= 2.0 and "silver" or "wood")
            local ply = getPlayer()
            if not IsValid(ply) then return end
            local base = ply:GetPos() + ply:GetForward()*75
            local tr=util.TraceLine({start=base+Vector(0,0,90),endpos=base-Vector(0,0,100),filter=ply,mask=MASK_SOLID})
            if tr.Hit then base=tr.HitPos end
            for _, uid in ipairs(chosen) do
                MetaPetsData.owned[uid] = nil; MetaPetsData.stats[uid] = nil
                if MetaPetsData.active == uid then setActivePet(nil) end
            end
            selectedForPress = {}; MetaPetsSelectedForPress = selectedForPress
            pressSequence={started=CurTime(),finish=CurTime()+3.0,pos=base,tier=targetTier,owner=ply:Nick()}
            for i,pet in ipairs(chosenPets) do
                local mdl = ClientsideModel(pet.model, RENDERGROUP_OPAQUE)
                if IsValid(mdl) then
                    mdl:SetAngles(Angle(0,0,0))
                    if pet.scale then mdl:SetModelScale(pet.scale,0) end
                    local mins = mdl:OBBMins()
                    mdl:SetPos(base + Vector((i-2)*24,0, -mins.z * (pet.scale or 1) + 1))
                    pressModels[#pressModels+1]={model=mdl,index=i,base=base,originalScale=pet.scale or 1}
                end
            end
            local press = ClientsideModel("models/props_c17/TrapPropeller_Engine.mdl", RENDERGROUP_OPAQUE)
            if IsValid(press) then
                press:SetAngles(Angle(0,ply:EyeAngles().y,0))
                local mins = press:OBBMins()
                press:SetPos(base + Vector(0,0,85 - mins.z))
                pressModels[#pressModels+1]={model=press,pressHead=true,base=base}
            end
            if IsValid(MetaPetsMenu) then MetaPetsMenu:Close() end
            surface.PlaySound("physics/metal/metal_box_impact_hard3.wav")
            notification.AddLegacy("Hydraulic press started!", NOTIFY_HINT, 3)
        end

        local list = vgui.Create("DScrollPanel", content)
        list:SetPos(14,89); list:SetSize(600,361)
        local function rebuildPets()
            if not IsValid(list) then return end
            list:Clear()
            local shown = 0
            local query = IsValid(search) and string.Trim(string.lower(search:GetValue())) or ""
            for _, uid in ipairs(getOwnedPetIDs()) do
                local pet = getPetInfo(uid)
                if pet and (query == "" or string.find(string.lower(pet.name .. " " .. pet.rarity .. " " .. uid), query, 1, true)) then
                    shown = shown + 1
                    local card = vgui.Create("DPanel", list)
                    card:Dock(TOP); card:DockMargin(0,0,0,8); card:SetTall(100); card:SetSkin("dark_meta")
                    createPreview(card,pet,4,3,94,94)
                    local selectPet = vgui.Create("DCheckBoxLabel", card)
                    selectPet:SetPos(565,8); selectPet:SetText(""); selectPet:SetValue(selectedForPress[uid] and 1 or 0); selectPet:SizeToContents()
                    selectPet.OnChange = function(_, value) selectedForPress[uid] = value and true or nil end
                    local name = vgui.Create("DLabel",card)
                    name:SetPos(108,18); name:SetFont("DermaDefaultBold")
                    name:SetText(pet.name .. (pet.variation ~= "normal" and " - " .. string.upper(pet.variation:gsub("_"," + ")) or "")); name:SizeToContents()
                    local stats = getPetStats(uid)
                    local rarity = vgui.Create("DLabel",card)
                    rarity:SetPos(108,40); rarity:SetText(pet.rarity .. " | LVL " .. stats.level)
                    rarity:SetTextColor(getRarity(pet).colour); rarity:SizeToContents()
                    local xp = vgui.Create("DLabel", card)
                    xp:SetPos(108,62); xp:SetText("XP: " .. stats.xp .. " | " .. (stats.hunger >= 70 and "Hungry" or "Fed")); xp:SizeToContents()
                    createButton(card,MetaPetsData.active==uid and "Active" or "Use Pet",430,34,125,32,function() setActivePet(uid); drawContent() end)
                end
            end
            if shown == 0 then
                local empty = vgui.Create("DLabel", list)
                if #getOwnedPetIDs() == 0 then
                    empty:SetText("No pets here! Open a crate to get your first pet.")
                else
                    empty:SetText("No pets match your search.")
                end
                empty:Dock(TOP)
                empty:DockMargin(8, 12, 0, 0)
                empty:SizeToContents()
            end
        end
        search.OnChange = rebuildPets
        rebuildPets()
    end

    createButton(sidebar, "My Pets", 10, 14, 160, 38, function()
        currentTab = "pets"
        drawContent()
    end)

    createButton(sidebar, "Pet Shop", 10, 60, 160, 38, function()
        currentTab = "shop"
        drawContent()
    end)

    local note = vgui.Create("DLabel", sidebar)
    note:SetPos(12, 350)
    note:SetSize(156, 100)
    note:SetWrap(true)
    note:SetText(
        "Prototype\nCrate purchases require server-side economy integration."
    )

    drawContent()
end

hook.Add("Think", "MetaPets_PetPress", function()
    if not pressSequence then return end
    local elapsed = CurTime() - pressSequence.started
    local frac = math.Clamp(elapsed / 3, 0, 1)
    for i = #pressModels, 1, -1 do
        local item = pressModels[i]
        if not IsValid(item.model) then table.remove(pressModels,i) else
            if item.pressHead then
                local mins = item.model:OBBMins()
                item.model:SetPos(item.base + Vector(0,0,85 - mins.z - math.sin(math.min(frac*1.4,1)*math.pi/2)*52))
            else
                local shrink = 1 - math.Clamp((frac-0.25)/0.45,0,1)*0.88
                item.model:SetModelScale(math.max(0.08,shrink),0)
                item.model:SetPos(item.base + Vector((item.index-2)*24,0,12*shrink))
            end
        end
    end
    if elapsed >= 2.2 and not pressSequence.crateSpawned then
        pressSequence.crateSpawned = true
        local cfg=crateTiers[pressSequence.tier]
        local crate=ClientsideModel(getCrateModel(pressSequence.tier),RENDERGROUP_OPAQUE)
        if IsValid(crate) then
            crate:SetAngles(Angle(0,0,0)); applyCrateAppearance(crate, pressSequence.tier)
            local mins = crate:OBBMins()
            local cratePos = pressSequence.pos - Vector(0,0,mins.z)
            crate:SetPos(cratePos)
            crateProps[#crateProps+1]={model=crate,pos=cratePos,started=CurTime(),tier=pressSequence.tier,owner=pressSequence.owner,state="press"}
        end
        surface.PlaySound("physics/metal/metal_box_impact_hard3.wav")
    end
    if elapsed >= 3 then
        MetaPetsData.crates[pressSequence.tier]=(MetaPetsData.crates[pressSequence.tier] or 0)+1
        for _,item in ipairs(pressModels) do if IsValid(item.model) then item.model:Remove() end end
        pressModels={}; pressSequence=nil
        notification.AddLegacy("The press made a crate!",NOTIFY_GENERIC,4)
    end
end)

hook.Add("Think", "MetaPets_CrateOpening", function()
    for i = #crateProps, 1, -1 do
        local crate = crateProps[i]
        if not IsValid(crate.model) then
            table.remove(crateProps, i)
        else
            local elapsed = CurTime() - crate.started
            local bob = math.sin(CurTime() * 5) * 1.5
            crate.model:SetPos(crate.pos + Vector(0, 0, bob))
            crate.model:SetAngles(Angle(math.sin(CurTime() * 18) * 3, crate.model:GetAngles().y + FrameTime() * 45, math.cos(CurTime() * 16) * 3))
            if elapsed > 3.2 then
                crate.model:Remove()
                table.remove(crateProps, i)
            end
        end
    end

    for i = #revealProps, 1, -1 do
        local reveal = revealProps[i]
        if not IsValid(reveal.model) or CurTime() >= reveal.finish then
            if IsValid(reveal.model) then reveal.model:Remove() end
            table.remove(revealProps, i)
        else
            local elapsed = CurTime() - reveal.started
            local rise = math.min(elapsed * 30, 26)
            reveal.model:SetPos(reveal.pos + Vector(0, 0, rise))
            reveal.model:SetAngles(Angle(0, (elapsed * 150) % 360, 0))
        end
    end

    if crateOpening and CurTime() >= crateOpening.finish then
        local result = crateOpening
        crateOpening = nil

        for i = #crateProps, 1, -1 do
            local crate = crateProps[i]
            if crate.owner == result.owner and crate.state == "opening" then
                if IsValid(crate.model) then crate.model:Remove() end
                table.remove(crateProps, i)
            end
        end

        local uid = addOwnedPet(result.speciesId, result.variation, result.paint, nil)
        local pet = getPetInfo(uid)
        local petName = pet and pet.name or result.speciesId
        local variantName = result.variation == "normal" and "Normal" or string.upper(result.variation:gsub("_", " + "))
        local ownerName = result.owner or (IsValid(getPlayer()) and getPlayer():Nick()) or "A player"

        local rarityColour = getRarity(pet).colour
        chat.AddText(Color(120, 210, 255), "[MetaPets] ", color_white, ownerName .. " unboxed ", rarityColour, petName, color_white, "!")
        surface.PlaySound("buttons/button14.wav")
        notification.AddLegacy("You unboxed: " .. petName .. " (" .. variantName .. ")", NOTIFY_GENERIC, 5)

        local modelPath = pet and pet.model or "models/seagull.mdl"
        local revealModel = ClientsideModel(modelPath, RENDERGROUP_OPAQUE)
        if IsValid(revealModel) then
            revealModel:SetNoDraw(false)
            revealModel:SetAngles(Angle(0, result.yaw or 0, 0))
            if pet and pet.scale then revealModel:SetModelScale(pet.scale, 0) end
            if result.variation == "painted" or result.variation == "shiny_painted" then
                revealModel:SetColor(result.paint and result.paint.colour or color_white)
                revealModel:SetMaterial("models/debug/debugwhite")
            elseif pet and pet.gold then
                revealModel:SetColor(Color(255, 205, 75))
                revealModel:SetMaterial("models/debug/debugwhite")
            else
                revealModel:SetColor(color_white)
                revealModel:SetMaterial("")
            end
            if result.variation == "shiny" or result.variation == "shiny_painted" or (pet and pet.gold) then
                revealModel:SetMaterial("models/player/shared/gold_player")
            end
            local mins = revealModel:OBBMins()
            local revealPos = result.pos or (IsValid(getPlayer()) and getPlayer():GetPos() + getPlayer():GetForward() * 65) or vector_origin
            revealPos = Vector(revealPos.x, revealPos.y, revealPos.z - mins.z)
            revealModel:SetPos(revealPos)
            revealProps[#revealProps + 1] = {
                model = revealModel,
                pos = revealPos,
                started = CurTime(),
                finish = CurTime() + 5,
                owner = ownerName,
                petName = petName,
                variant = variantName,
                rarity = pet and pet.rarity or "Common",
                rarityColour = getRarity(pet).colour
            }
        end

        timer.Simple(5.2, function()
            if isfunction(openMenu) then openMenu() end
        end)
    end
end)

hook.Add("PostDrawTranslucentRenderables", "MetaPets_DrawCrateLabels", function()
    local viewer = LocalPlayer()
    if not IsValid(viewer) then return end

    for _, crate in ipairs(crateProps) do
        if IsValid(crate.model) and crate.state ~= "press" then
            local _, maxs = crate.model:GetRenderBounds()
            local pos = crate.model:GetPos() + Vector(0, 0, math.max(38, maxs.z + 18))
            local ang = viewer:EyeAngles()
            ang:RotateAroundAxis(ang:Forward(), 90)
            ang:RotateAroundAxis(ang:Right(), 90)
            cam.Start3D2D(pos, ang, 0.22)
                draw.SimpleTextOutlined(crate.owner .. " is unboxing...", "Trebuchet24", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
            cam.End3D2D()
        end
    end

    for _, reveal in ipairs(revealProps) do
        if IsValid(reveal.model) then
            local _, maxs = reveal.model:GetRenderBounds()
            local pos = reveal.model:GetPos() + Vector(0, 0, math.max(36, maxs.z + 18))
            local ang = viewer:EyeAngles()
            ang:RotateAroundAxis(ang:Forward(), 90)
            ang:RotateAroundAxis(ang:Right(), 90)
            cam.Start3D2D(pos, ang, 0.2)
                draw.SimpleTextOutlined(reveal.owner .. " unboxed " .. reveal.petName .. "!", "Trebuchet24", 0, 0, reveal.rarityColour or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
                draw.SimpleTextOutlined(reveal.rarity .. " - " .. reveal.variant, "DermaDefaultBold", 0, 30, reveal.rarityColour or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            cam.End3D2D()
        end
    end
end)

concommand.Add("metapets_menu", openMenu)

hook.Add("Think", "MetaPets_Think", function()
    local ply = getPlayer()

    if not IsValid(ply) then
        removePetModel()
        return
    end

    local pet = getPetInfo(MetaPetsData.active)

    if not pet or not MetaPetsData.owned[MetaPetsData.active] then
        if IsValid(MetaPetsPetModel) then
            removePetModel()
        end
        return
    end

    local entity = getPet()

    if not IsValid(entity) then
        createPetModel(pet)

        if isCarried and IsValid(MetaPetsPetModel) then
            MetaPetsPetModel:SetModelScale(normalPetScale * carryPetScale, 0)
        end

        return
    end

    if CurTime() >= nextStatsUpdate then
        nextStatsUpdate = CurTime() + 60

        for id in pairs(MetaPetsData.owned) do
            local stats = getPetStats(id)

            stats.hunger = math.min(100, stats.hunger + 4)

            local neglected = stats.hunger >= 70

            stats.happiness = math.max(
                0,
                stats.happiness - (neglected and 5 or 2)
            )

            if neglected then
                stats.neglect = (stats.neglect or 0) + 1
                stats.care = math.max(0, (stats.care or 50) - 1)
            else
                stats.neglect = math.max(0, (stats.neglect or 0) - 0.5)
                stats.care = math.min(100, (stats.care or 50) + 0.25)
            end
        end
    end

    if CurTime() >= nextPassiveXP then
        nextPassiveXP = CurTime() + 45
        addPetXP(MetaPetsData.active, 2)
    end

    local playerPos = ply:GetPos()
    local verticalGap = math.abs(
        (petPosition and petPosition.z or playerPos.z) - playerPos.z
    )
    local bird = isBirdPet(pet)

    if not bird and not isCarried and not manuallyPutDown
        and (verticalGap > 220 or playerIsFlying(ply)) then
        isCarried = true
        entity:SetModelScale(normalPetScale * carryPetScale, 0)
    end

    if isCarried then
        local eyePos = ply:EyePos()
        local eyeAngles = ply:EyeAngles()
        local forward = eyeAngles:Forward()
        local right = eyeAngles:Right()
        local up = eyeAngles:Up()
        local carryPos = eyePos + forward * 32 + right * 18 - up * 12

        entity:SetPos(carryPos)
        entity:SetAngles(Angle(0, eyeAngles.y, 0))

        isFlying = false
        setPetAnimation(false)

        return
    end

    if not petPosition then
        petPosition = playerPos - ply:GetForward() * 75
        petMoveSpeed = 0
    end

    verticalGap = math.abs(petPosition.z - playerPos.z)

    local wasFlying = isFlying
    isFlying = bird and (playerIsFlying(ply) or verticalGap > 120)

    local moving

    if isFlying then
        local forward = ply:EyeAngles():Forward()
        local flatForward = Vector(forward.x, forward.y, 0)

        if flatForward:LengthSqr() > 0.001 then
            flatForward:Normalize()
        else
            flatForward = ply:GetForward()
        end

        local flatRight = Angle(0, ply:EyeAngles().y, 0):Right()

        local targetPos = playerPos
            - flatForward * 25
            + flatRight * (flyingSide * 35)
            + Vector(0, 0, 35)

        local distance = petPosition:Distance(targetPos)
        moving = distance > 18

        local targetSpeed = math.Clamp(
            160 + math.max(0, distance - 18) * 2,
            160,
            900
        )

        petMoveSpeed = math.Approach(
            petMoveSpeed,
            moving and targetSpeed or 0,
            700 * FrameTime()
        )

        if moving then
            local direction = (targetPos - petPosition):GetNormalized()

            petPosition = petPosition
                + direction * math.min(petMoveSpeed * FrameTime(), distance)

            petYaw = direction:Angle().y
        end
    else
        local distance = petPosition:Distance(playerPos)
        moving = distance > 65

        if moving then
            local targetSpeed = math.Clamp(
                90 + math.max(0, distance - 65) * 1.8,
                90,
                650
            )

            petMoveSpeed = math.Approach(
                petMoveSpeed,
                targetSpeed,
                500 * FrameTime()
            )

            local direction = (playerPos - petPosition):GetNormalized()
            local step = math.min(
                petMoveSpeed * FrameTime(),
                math.max(0, distance - 55)
            )

            petPosition = petPosition + direction * step
            petYaw = direction:Angle().y
        else
            petMoveSpeed = math.Approach(
                petMoveSpeed,
                0,
                600 * FrameTime()
            )

            if CurTime() > nextWander then
                nextWander = CurTime() + math.Rand(2, 5)
                petYaw = petYaw + math.Rand(-90, 90)

                local direction = Angle(0, petYaw, 0):Forward()

                local trace = util.TraceLine({
                    start = petPosition + Vector(0, 0, 24),
                    endpos = petPosition + direction * 35 - Vector(0, 0, 80),
                    filter = ply,
                    mask = MASK_SOLID
                })

                if trace.Hit and not manuallyPutDown then
                    petPosition = trace.HitPos
                end
            end
        end

        local ground = util.TraceLine({
            start = petPosition + Vector(0, 0, 40),
            endpos = petPosition - Vector(0, 0, 100),
            filter = { ply, entity },
            mask = MASK_SOLID
        })

        if ground.Hit and not manuallyPutDown then
            local mins = entity:GetRenderBounds()
            petPosition.z = ground.HitPos.z - mins.z
        end
    end

    if moving ~= petMoving or isFlying ~= wasFlying then
        petMoving = moving
        currentSequence = nil
    end

    entity:SetPlaybackRate(
        isFlying and 1.5 or math.Clamp(petMoveSpeed / 140, 0.8, 3.5)
    )

    setPetAnimation(moving)

    entity:SetPos(petPosition)
    entity:SetAngles(Angle(0, petYaw, 0))
end)

hook.Add("PostDrawTranslucentRenderables", "MetaPets_DrawHeadcrab", function()
    local entity = getPet()

    if IsValid(entity) then
        entity:DrawModel()
    end
end)

local function isAimingAtPlayer(ply)
    if not IsValid(ply) then return false end

    local trace = ply:GetEyeTrace()
    return trace and IsValid(trace.Entity) and trace.Entity:IsPlayer() and trace.Entity ~= ply
end

local function isLookingAtPet(ply)
    local pet = getPet()
    if not IsValid(ply) or not IsValid(pet) or not petPosition then return false end

    local startPos = ply:EyePos()
    local direction = ply:GetAimVector()
    local toPet = petPosition - startPos
    local distanceAlongAim = toPet:Dot(direction)

    if distanceAlongAim < 0 or distanceAlongAim > 180 then return false end

    local closestPoint = startPos + direction * distanceAlongAim
    return closestPoint:Distance(petPosition) <= 42
end

hook.Add("PlayerBindPress", "MetaPets_Interact", function(ply, bind, pressed)
    if not pressed or not bind:lower():find("use", 1, true) then
        return
    end

    if not IsValid(getPet()) or not MetaPetsData.active then
        return
    end

    local player = getPlayer()
    if not IsValid(player) then return end

    if isAimingAtPlayer(player) then
        return
    end

    if isCarried or isLookingAtPet(player) then
        openInteractionMenu()
        return true
    end
end)

hook.Add("HUDPaint", "MetaPets_HUD", function()
    local ply = getPlayer()

    if not IsValid(ply) then return end
    if isAimingAtPlayer(ply) then return end

    if isCarried then
        draw.SimpleTextOutlined(
            "E - Interact with your pet",
            "DermaDefaultBold",
            ScrW() / 2,
            ScrH() / 2 + 42,
            color_white,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP,
            1,
            color_black
        )
        return
    end

    if not isLookingAtPet(ply) then return end

    local pet = getPetInfo(MetaPetsData.active)
    local stats = pet and getPetStats(MetaPetsData.active)

    if pet and stats then
        local statusText = string.format(
            "[%s] [LVL %d] [%s] [%s]",
            pet.name,
            stats.level,
            stats.hunger >= 70 and "HUNGRY" or "FED",
            string.upper(getMood(stats))
        )

        draw.SimpleTextOutlined(
            statusText,
            "DermaDefaultBold",
            ScrW() / 2,
            ScrH() / 2 + 18,
            getRarity(pet).colour,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP,
            1,
            color_black
        )
    end

    draw.SimpleTextOutlined(
        "E - Interact",
        "DermaDefaultBold",
        ScrW() / 2,
        ScrH() / 2 + 42,
        color_white,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP,
        1,
        color_black
    )
end)

function MetaPets_AddActivityXP(amount)
    if MetaPetsData.active then addPetXP(MetaPetsData.active, math.max(0, tonumber(amount) or 0)) end
end

print("[MetaPets] Loaded. Run metapets_menu to open the menu.")
