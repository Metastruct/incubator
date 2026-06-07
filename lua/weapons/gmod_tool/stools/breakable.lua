-- Adapted from https://steamcommunity.com/sharedfiles/filedetails/?id=3585832067
-- should be server safe now
-- (tries to be duplicator API compatible)
local Tag = 'breakabletool'

TOOL.Category = "Destruction"
TOOL.Name = "Breakable Tool"
TOOL.Information = {
	{ name = "left" },
	{ name = "right" }
}

local entcbs = _G.BREAKABLE_TOOL_ENTCBS or {}
_G.BREAKABLE_TOOL_ENTCBS = entcbs
local function RemoveCB(ent)
	local id = entcbs[ent]
	if id then
		entcbs[ent] = nil
		ent:RemoveCallback("PhysicsCollide", id)
		return true
	end
end

-- TOOL RightClick: undo breakable on targeted entity
function TOOL:RightClick(trace)
	if CLIENT then return true end
	local ent = trace.Entity
	if not IsValid(ent) or ent:IsPlayer() then return false end

	-- Only act on entities previously made breakable
	if not ent.BreakableGibs then return false end

	-- Clear breakable state and restore defaults
	ent.BreakableGibs = nil
	ent.BreakableSound = nil
	ent.NoGibCollision = nil
	ent.BreakableGibPreset = nil
	ent.BreakablePrecached = nil
	RemoveCB(ent)

	return true
end

-- Shared gib presets (used by server when applying breakable and by client UI)
local GibPresets = {
	["Default"] = {
		health = 50,
		sound = "physics/metal/metal_box_break2.wav",
		gibs = { "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl" }
	},
	["Wood"] = {
		health = 30,
		sound = "physics/wood/wood_crate_break4.wav",
		gibs = { "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01e.mdl", "models/gibs/wood_gib01b.mdl", "models/gibs/wood_gib01c.mdl", "models/gibs/wood_gib01d.mdl", "models/gibs/wood_gib01e.mdl" }
	},
	["Metal"] = {
		health = 50,
		sound = "physics/metal/metal_box_break2.wav",
		gibs = { "models/gibs/metal_gib1.mdl", "models/gibs/metal_gib2.mdl", "models/gibs/metal_gib3.mdl", "models/gibs/metal_gib4.mdl", "models/gibs/metal_gib1.mdl", "models/gibs/metal_gib2.mdl", "models/gibs/metal_gib3.mdl", "models/gibs/metal_gib4.mdl", "models/gibs/metal_gib1.mdl", "models/gibs/metal_gib2.mdl", "models/gibs/metal_gib3.mdl", "models/gibs/metal_gib4.mdl", "models/gibs/metal_gib1.mdl", "models/gibs/metal_gib2.mdl", "models/gibs/metal_gib3.mdl", "models/gibs/metal_gib4.mdl", "models/gibs/metal_gib1.mdl", "models/gibs/metal_gib2.mdl", "models/gibs/metal_gib3.mdl", "models/gibs/metal_gib4.mdl", "models/gibs/metal_gib1.mdl", "models/gibs/metal_gib2.mdl", "models/gibs/metal_gib3.mdl", "models/gibs/metal_gib4.mdl", "models/gibs/metal_gib4.mdl" }
	},
	["Glass"] = {
		health = 5,
		sound = "physics/glass/glass_largesheet_break1.wav",
		gibs = { "models/gibs/glass_shard01.mdl", "models/gibs/glass_shard02.mdl", "models/gibs/glass_shard03.mdl", "models/gibs/glass_shard04.mdl", "models/gibs/glass_shard01.mdl", "models/gibs/glass_shard02.mdl", "models/gibs/glass_shard03.mdl", "models/gibs/glass_shard04.mdl", "models/gibs/glass_shard01.mdl", "models/gibs/glass_shard02.mdl", "models/gibs/glass_shard03.mdl", "models/gibs/glass_shard04.mdl", "models/gibs/glass_shard01.mdl", "models/gibs/glass_shard02.mdl", "models/gibs/glass_shard03.mdl", "models/gibs/glass_shard04.mdl", "models/gibs/glass_shard01.mdl", "models/gibs/glass_shard02.mdl", "models/gibs/glass_shard03.mdl", "models/gibs/glass_shard04.mdl", "models/gibs/glass_shard01.mdl", "models/gibs/glass_shard02.mdl", "models/gibs/glass_shard03.mdl", "models/gibs/glass_shard04.mdl", "models/gibs/glass_shard04.mdl" }
	},
	["Human Gibs"] = {
		health = 50,
		sound = "physics/body/body_medium_break2.wav",
		gibs = { "models/Gibs/HGIBS.mdl", "models/Gibs/HGIBS_scapula.mdl", "models/Gibs/HGIBS_scapula.mdl", "models/Gibs/HGIBS_spine.mdl", "models/Gibs/HGIBS_spine.mdl", "models/Gibs/HGIBS_rib.mdl", "models/Gibs/HGIBS_rib.mdl", "models/Gibs/HGIBS_rib.mdl", "models/Gibs/HGIBS_rib.mdl", "models/Gibs/HGIBS_rib.mdl", "models/Gibs/HGIBS_rib.mdl", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "" }
	},
	["No Gibs or Sound"] = {
		health = 100,
		sound = "",
		gibs = {}
	},
	["Portal Turret Gibs"] = {
		health = 50,
		sound = "physics/metal/metal_box_break2.wav",
		gibs = { "models/npcs/turret/turret_fx_break_gib1.mdl", "models/npcs/turret/turret_fx_break_gib2.mdl", "models/npcs/turret/turret_fx_break_gib3.mdl", "models/npcs/turret/turret_fx_break_gib4.mdl", "models/npcs/turret/turret_fx_break_gib5.mdl", "models/npcs/turret/turret_fx_break_gib6.mdl", "models/npcs/turret/turret_fx_break_gib7.mdl", "models/npcs/turret/turret_fx_break_gib8.mdl", "models/npcs/turret/turret_fx_break_gib9.mdl", "models/npcs/turret/turret_fx_break_gib10.mdl", "models/npcs/turret/turret_fx_break_gib11.mdl", "models/npcs/turret/turret_fx_break_gib12.mdl", "models/npcs/turret/turret_fx_break_gib13.mdl", "models/npcs/turret/turret_fx_break_gib14.mdl", "models/npcs/turret/turret_fx_break_gib15.mdl", "models/npcs/turret/turret_fx_break_gib16.mdl", "models/npcs/turret/turret_fx_break_gib17.mdl", "models/npcs/turret/turret_fx_break_gib18.mdl", "models/npcs/turret/turret_fx_break_gib19.mdl", "models/npcs/turret/turret_fx_break_gib20.mdl", "models/npcs/turret/turret_fx_break_gib21.mdl", "models/npcs/turret/turret_fx_break_gib22.mdl", "models/npcs/turret/turret_fx_break_gib23.mdl", "models/npcs/turret/turret_fx_break_gib24.mdl", "models/npcs/turret/turret_fx_break_gib25.mdl" }
	}
}


-- Ensure variants that should reuse Default gibs reference them
if GibPresets and GibPresets["Default"] and GibPresets["Wood"] then
	GibPresets["Wood"].gibs = GibPresets["Default"].gibs
end

TOOL.ClientConVar["gibpreset"] = "Default" -- choose a preset gib type
TOOL.ClientConVar["health"] = ""
TOOL.ClientConVar["sound"] = ""
TOOL.ClientConVar["nogibcollision"] = "" -- if set to 0 it's off, but if its set to 1 it's on
local Tag = "breakabletool"

if SERVER then
	util.AddNetworkString(Tag)
end

if CLIENT then
	language.Add("Tool.breakable.name", "Breakable Tool")
	language.Add("Tool.breakable.desc", "Turn props into breakable objects with gib models and a custom sound")
	language.Add("Tool.breakable.0", "Left click on a prop to make it breakable")
	language.Add("Tool.breakable.left", "Left click: Make prop breakable")
	language.Add("Tool.breakable.right", "Right click: Undo breakable and reload prop")
end

-- Spawn gibs
local function SpawnGibs(ent, gibs, noCollide)
	-- Server no longer creates gibs directly; clients handle visual gibs.
	if SERVER then return end

	for _, mdl in ipairs(gibs) do
		if mdl == "" then continue end
		local gib = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
		if not IsValid(gib) then continue end
		gib:SetPos(ent:GetPos() + VectorRand() * 10)
		gib:SetAngles(AngleRand())

		if tonumber(noCollide) == 1 then
			gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		end

		timer.Simple(20, function()
			if IsValid(gib) then
				gib:Remove()
			end
		end)
	end
end

local function PrecacheGibModels(ent)
	if not SERVER or ent.BreakablePrecached then return end
	ent.BreakablePrecached = true

	local precached = {}
	for _, mdl in ipairs(ent.BreakableGibs or {}) do
		if mdl ~= "" and not precached[mdl] then
			util.PrecacheModel(mdl)
			precached[mdl] = true
		end
	end
end

-- Break entity
local function BreakEntity(ent)
	if not IsValid(ent) then return end
	local gibs = ent.BreakableGibs
	local snd = ent.BreakableSound
	local noCollide = ent.NoGibCollision -- Retrieve the stored value

	if snd and snd ~= "" then
		sound.Play(snd, ent:GetPos())
	end

	if SERVER then
		PrecacheGibModels(ent)

		net.Start(Tag, true)
		net.WriteEntity(ent)
		net.WriteString(ent.BreakableGibPreset or "Default")
		net.WriteBool(noCollide == 1)
		net.WriteVector(ent:GetPos())

		net.SendPVS(ent:GetPos())
		ent:Remove()
	else
		SpawnGibs(ent, gibs, noCollide)
	end
end

local function Entity_CollideCallback(self, data)
	local speed = data.Speed
	--TODO: ent flags probably can handle this for us...

	if speed > 150 then
		if SERVER and not self.BreakablePrecached then
			PrecacheGibModels(self)
		end

		local newHealth = self:Health() - speed * 0.05
		self:SetHealth(newHealth)

		if newHealth <= 0 then
			BreakEntity(self)
		end
	end
end
-- Make prop breakable
local function MakeBreakable(ent, gibs, health, sound, noCollide, preset)
	if not IsValid(ent) then return end
	ent:SetMaxHealth(health)
	ent:SetHealth(health)
	ent.BreakableGibs = gibs
	ent.BreakableSound = sound
	ent.NoGibCollision = noCollide -- Store it here
	ent.BreakableGibPreset = preset or "Default"
	ent.BreakablePrecached = false
	RemoveCB(ent)
	local id = ent:AddCallback("PhysicsCollide", Entity_CollideCallback)
	entcbs[ent]=id
end

hook.Add("EntityRemoved",Tag,function(ent)
	entcbs[ent]=nil
end)

-- TOOL LeftClick
function TOOL:LeftClick(trace)
	if CLIENT then return true end
	local ent = trace.Entity
	if not IsValid(ent) or ent:IsPlayer() then return false end
	local preset = self:GetClientInfo("gibpreset") or "Default"
	local presetdata = GibPresets[preset]
	local gibs = {}

	if presetdata and presetdata.gibs then
		for _, m in ipairs(presetdata.gibs) do
			table.insert(gibs, m)
		end
	end

	local health = tonumber(self:GetClientInfo("health")) or (presetdata and presetdata.health) or 50
	local sound = self:GetClientInfo("sound")

	if (not sound or sound == "") and presetdata then
		sound = presetdata.sound
	end

	local noCollide = tonumber(self:GetClientInfo("nogibcollision")) or 0 -- NEW
	MakeBreakable(ent, gibs, health, sound, noCollide, preset)
	local ply = self:GetOwner()
	undo.Create("Breakable Prop")
	undo.AddEntity(ent)
	undo.SetPlayer(ply)
	undo.Finish()

	if SERVER then
		duplicator.StoreEntityModifier(ent, "breakable_tool", {
			gibs = gibs,
			orig_gibs = gibs, -- store backwards-compatible list too
			health = health,
			sound = sound,
			noCollide = noCollide -- Add to dupe

		})
	end

	return true
end

-- Global damage hook
hook.Add("PostEntityTakeDamage", Tag, function(ent, dmginfo)
	if not SERVER or not IsValid(ent) or not ent.BreakableGibs then return end
	if not ent.BreakablePrecached then
		PrecacheGibModels(ent)
	end

	local newHealth = ent:Health() - dmginfo:GetDamage()
	ent:SetHealth(newHealth)

	if newHealth <= 0 then
		BreakEntity(ent)
	end
end)

-- Dupe restore
if SERVER then
	duplicator.RegisterEntityModifier("breakable_tool", function(ply, ent, data)
		-- data may contain: gibs (array), orig_gibs (legacy array), health, sound, noCollide
		local incoming = data.orig_gibs or data.gibs or {}

		-- Helper: check if a model exists in any preset
		local function modelInPresets(mdl)
			if not mdl or mdl == "" then return false end

			for _, p in pairs(GibPresets) do
				for _, pm in ipairs(p.gibs or {}) do
					if pm == mdl then return true end
				end
			end

			return false
		end

		-- Try to find the preset with the largest overlap
		local bestPreset = nil
		local bestCount = 0

		for name, p in pairs(GibPresets) do
			local count = 0

			for _, m in ipairs(incoming) do
				if not m or m == "" then continue end

				for _, pm in ipairs(p.gibs or {}) do
					if pm == m then
						count = count + 1
						break
					end
				end
			end

			if count > bestCount then
				bestCount = count
				bestPreset = name
			end
		end

		local finalGibs = {}

		if bestCount > 0 and bestPreset and GibPresets[bestPreset] then
			for _, m in ipairs(GibPresets[bestPreset].gibs) do
				table.insert(finalGibs, m)
			end
		else
			-- Fall back to filtering incoming list to known preset models
			for _, m in ipairs(incoming) do
				if modelInPresets(m) then
					table.insert(finalGibs, m)
				end
			end

			-- If still empty, default to Default preset
			if #finalGibs == 0 and GibPresets["Default"] then
				for _, m in ipairs(GibPresets["Default"].gibs) do
					table.insert(finalGibs, m)
				end
			end
		end

		MakeBreakable(ent, finalGibs, data.health or (GibPresets["Default"] and GibPresets["Default"].health) or 50,
			data.sound or (GibPresets["Default"] and GibPresets["Default"].sound) or "", data.noCollide,
			bestPreset or "Default")
	end)
end

-- Tool panel with presets
function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Make props breakable with clientside gibs, custom health, and sound"
	})

	panel:AddControl("ComboBox", {
		Label = "Gib Preset",
		MenuButton = "0",
		Options = {
			["Default"] = {
				gibpreset = "Default"
			},
			["Wood"] = {
				gibpreset = "Wood"
			},
			["Metal"] = {
				gibpreset = "Metal"
			},
			["Glass"] = {
				gibpreset = "Glass"
			},
			["Human Gibs"] = {
				gibpreset = "Human Gibs"
			},
			["No Gibs or Sound"] = {
				gibpreset = "No Gibs or Sound"
			},
			["Portal Turret Gibs"] = {
				gibpreset = "Portal Turret Gibs"
			}
		},
		CVars = { "gibpreset" }
	})

	panel:AddControl("TextBox", {
		Label = "Break Sound Path",
		Command = "sound"
	})

	panel:AddControl("Slider", {
		Label = "Health",
		Command = "health",
		Type = "Integer",
		Min = "1",
		Max = "500"
	})

	panel:AddControl("CheckBox", {
		Label = "Disable gib collision?",
		Command = "nogibcollision"
	})
end

-- Client: receive gib broadcasts and spawn clientside gibs with a global cap
if CLIENT then
	local CLIENT_GIBS = {}
	local MAX_GIBS = 30

	net.Receive(Tag, function()
		local ent = net.ReadEntity()
		local preset = net.ReadString()
		local noCollide = net.ReadBool()
		local pos = net.ReadVector()
		local origin = IsValid(ent) and ent:GetPos() or pos

		local gibs = GibPresets[preset] and GibPresets[preset].gibs or GibPresets["Default"].gibs
		if not gibs then return end

		for _, mdl in ipairs(gibs) do
			if not mdl or mdl == "" then continue end
			local gib = ents.CreateClientProp(mdl)
			if not IsValid(gib) then continue end

			SafeRemoveEntityDelayed(gib, 20)
			gib:SetPos(origin + VectorRand() * 10)
			gib:SetAngles(AngleRand())
			gib:Spawn()
			gib:PhysicsInit(SOLID_VPHYSICS)
			gib:SetMoveType(MOVETYPE_VPHYSICS)
			gib:SetSolid(SOLID_VPHYSICS)

			if noCollide then
				gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			end

			-- try to give some movement (may not be available on client for all models)
			local phys = gib:GetPhysicsObject()

			if IsValid(phys) then
				phys:ApplyForceCenter(VectorRand() * 300 + Vector(0, 0, 100))
			end

			table.insert(CLIENT_GIBS, gib)

			-- enforce maximum
			while #CLIENT_GIBS > MAX_GIBS do
				local old = table.remove(CLIENT_GIBS, 1)

				if IsValid(old) then
					SafeRemoveEntity(old)
				end
			end
		end
	end)
end
