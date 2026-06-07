TOOL.Category = "Destruction"
TOOL.Name = "Breakable Tool"
-- Default client convars
TOOL.ClientConVar["gib1"] = ""
TOOL.ClientConVar["gib2"] = ""
TOOL.ClientConVar["gib3"] = ""
TOOL.ClientConVar["gib4"] = ""
TOOL.ClientConVar["gib5"] = ""
TOOL.ClientConVar["gib6"] = ""
TOOL.ClientConVar["gib7"] = ""
TOOL.ClientConVar["gib8"] = ""
TOOL.ClientConVar["gib9"] = ""
TOOL.ClientConVar["gib10"] = ""
TOOL.ClientConVar["gib11"] = ""
TOOL.ClientConVar["gib12"] = ""
TOOL.ClientConVar["gib13"] = ""
TOOL.ClientConVar["gib14"] = ""
TOOL.ClientConVar["gib15"] = ""
TOOL.ClientConVar["gib16"] = ""
TOOL.ClientConVar["gib17"] = ""
TOOL.ClientConVar["gib18"] = ""
TOOL.ClientConVar["gib19"] = ""
TOOL.ClientConVar["gib20"] = ""
TOOL.ClientConVar["gib21"] = ""
TOOL.ClientConVar["gib22"] = ""
TOOL.ClientConVar["gib23"] = ""
TOOL.ClientConVar["gib24"] = ""
TOOL.ClientConVar["gib25"] = ""
TOOL.ClientConVar["health"] = ""
TOOL.ClientConVar["sound"] = ""
TOOL.ClientConVar["nogibcollision"] = "" -- if set to 0 it's off, but if its set to 1 it's on

if CLIENT then
	language.Add("Tool.breakable.name", "Breakable Tool")
	language.Add("Tool.breakable.desc", "Turn props into breakable objects with gib models and a custom sound")
	language.Add("Tool.breakable.0", "Left click on a prop to make it breakable")
end

-- Spawn gibs
local function SpawnGibs(ent, gibs, noCollide)
	for _, mdl in ipairs(gibs) do
		if mdl == "" then continue end
		local gib = ents.Create("prop_physics")
		if not IsValid(gib) then continue end
		gib:SetModel(mdl)
		gib:SetPos(ent:GetPos() + VectorRand() * 10)
		gib:SetAngles(AngleRand())
		gib:Spawn()

		if tonumber(noCollide) == 1 then
			gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		end

		local phys = gib:GetPhysicsObject()

		if IsValid(phys) then
			phys:ApplyForceCenter(VectorRand() * 300 + Vector(0, 0, 100))
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

	SpawnGibs(ent, gibs, noCollide)
	ent:Remove()
end

-- Make prop breakable
local function MakeBreakable(ent, gibs, health, sound, noCollide)
	if not IsValid(ent) then return end
	ent:SetMaxHealth(health)
	ent:SetHealth(health)
	ent.BreakableGibs = gibs
	ent.BreakableSound = sound
	ent.NoGibCollision = noCollide -- Store it here

	function ent:PhysicsCollide(data, phys)
		local speed = data.Speed

		if speed > 150 then
			local newHealth = self:Health() - speed * 0.05
			self:SetHealth(newHealth)

			if newHealth <= 0 then
				BreakEntity(self)
			end
		end
	end
end

-- TOOL LeftClick
function TOOL:LeftClick(trace)
	if CLIENT then return true end
	local ent = trace.Entity
	if not IsValid(ent) or ent:IsPlayer() then return false end

	local gibs = { self:GetClientInfo("gib1"), self:GetClientInfo("gib2"), self:GetClientInfo("gib3"), self
		:GetClientInfo("gib4"), self:GetClientInfo("gib5"), self:GetClientInfo("gib6"), self:GetClientInfo("gib7"), self
		:GetClientInfo("gib8"), self:GetClientInfo("gib9"), self:GetClientInfo("gib10"), self:GetClientInfo("gib11"),
		self:GetClientInfo("gib12"), self:GetClientInfo("gib13"), self:GetClientInfo("gib14"), self:GetClientInfo(
	"gib15"), self:GetClientInfo("gib16"), self:GetClientInfo("gib17"), self:GetClientInfo("gib18"), self:GetClientInfo(
	"gib19"), self:GetClientInfo("gib20"), self:GetClientInfo("gib21"), self:GetClientInfo("gib22"), self:GetClientInfo(
	"gib23"), self:GetClientInfo("gib24"), self:GetClientInfo("gib25") }

	local health = tonumber(self:GetClientInfo("health")) or 50
	local sound = self:GetClientInfo("sound") or ""
	local noCollide = tonumber(self:GetClientInfo("nogibcollision")) or 0 -- NEW
	MakeBreakable(ent, gibs, health, sound, noCollide)
	local ply = self:GetOwner()
	undo.Create("Breakable Prop")
	undo.AddEntity(ent)
	undo.SetPlayer(ply)
	undo.Finish()

	if SERVER then
		duplicator.StoreEntityModifier(ent, "breakable_tool", {
			gibs = gibs,
			health = health,
			sound = sound,
			noCollide = noCollide -- Add to dupe

		})
	end

	return true
end

-- Global damage hook
hook.Add("EntityTakeDamage", "BreakableToolDamage", function(ent, dmginfo)
	if not IsValid(ent) or not ent.BreakableGibs then return end
	local newHealth = ent:Health() - dmginfo:GetDamage()
	ent:SetHealth(newHealth)

	if newHealth <= 0 then
		BreakEntity(ent)
	end
end)

-- Dupe restore
if SERVER then
	duplicator.RegisterEntityModifier("breakable_tool", function(ply, ent, data)
		MakeBreakable(ent, data.gibs, data.health, data.sound, data.noCollide)
	end)
end

-- Tool panel with presets
function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Make props breakable with 25 gibs, custom health, and sound"
	})

	-- Preset system setup
	local preset_cvars = { "breakable_health", "breakable_sound", "breakable_nogibcollision" }

	for i = 1, 25 do
		table.insert(preset_cvars, "breakable_gib" .. i)
	end

	panel:AddControl("ComboBox", {
		Label = "Presets",
		MenuButton = "1",
		Folder = "breakable_tool",
		Options = {
			["Default"] = {
				breakable_health = "50",
				breakable_sound = "physics/metal/metal_box_break2.wav",
				breakable_gib1 = "models/gibs/wood_gib01b.mdl",
				breakable_gib2 = "models/gibs/wood_gib01c.mdl",
				breakable_gib3 = "models/gibs/wood_gib01d.mdl",
				breakable_gib4 = "models/gibs/wood_gib01e.mdl",
				breakable_gib5 = "models/gibs/wood_gib01b.mdl",
				breakable_gib6 = "models/gibs/wood_gib01c.mdl",
				breakable_gib7 = "models/gibs/wood_gib01d.mdl",
				breakable_gib8 = "models/gibs/wood_gib01e.mdl",
				breakable_gib9 = "models/gibs/wood_gib01b.mdl",
				breakable_gib10 = "models/gibs/wood_gib01c.mdl",
				breakable_gib11 = "models/gibs/wood_gib01d.mdl",
				breakable_gib12 = "models/gibs/wood_gib01e.mdl",
				breakable_gib13 = "models/gibs/wood_gib01b.mdl",
				breakable_gib14 = "models/gibs/wood_gib01c.mdl",
				breakable_gib15 = "models/gibs/wood_gib01d.mdl",
				breakable_gib16 = "models/gibs/wood_gib01e.mdl",
				breakable_gib17 = "models/gibs/wood_gib01b.mdl",
				breakable_gib18 = "models/gibs/wood_gib01c.mdl",
				breakable_gib19 = "models/gibs/wood_gib01d.mdl",
				breakable_gib20 = "models/gibs/wood_gib01e.mdl",
				breakable_gib21 = "models/gibs/wood_gib01e.mdl",
				breakable_gib22 = "models/gibs/wood_gib01b.mdl",
				breakable_gib23 = "models/gibs/wood_gib01c.mdl",
				breakable_gib24 = "models/gibs/wood_gib01d.mdl",
				breakable_gib25 = "models/gibs/wood_gib01e.mdl"
			},
			["Wood"] = {
				breakable_health = "30",
				breakable_sound = "physics/wood/wood_crate_break4.wav",
				breakable_gib1 = "models/gibs/wood_gib01b.mdl",
				breakable_gib2 = "models/gibs/wood_gib01c.mdl",
				breakable_gib3 = "models/gibs/wood_gib01d.mdl",
				breakable_gib4 = "models/gibs/wood_gib01e.mdl",
				breakable_gib5 = "models/gibs/wood_gib01b.mdl",
				breakable_gib6 = "models/gibs/wood_gib01c.mdl",
				breakable_gib7 = "models/gibs/wood_gib01d.mdl",
				breakable_gib8 = "models/gibs/wood_gib01e.mdl",
				breakable_gib9 = "models/gibs/wood_gib01b.mdl",
				breakable_gib10 = "models/gibs/wood_gib01c.mdl",
				breakable_gib11 = "models/gibs/wood_gib01d.mdl",
				breakable_gib12 = "models/gibs/wood_gib01e.mdl",
				breakable_gib13 = "models/gibs/wood_gib01b.mdl",
				breakable_gib14 = "models/gibs/wood_gib01c.mdl",
				breakable_gib15 = "models/gibs/wood_gib01d.mdl",
				breakable_gib16 = "models/gibs/wood_gib01e.mdl",
				breakable_gib17 = "models/gibs/wood_gib01b.mdl",
				breakable_gib18 = "models/gibs/wood_gib01c.mdl",
				breakable_gib19 = "models/gibs/wood_gib01d.mdl",
				breakable_gib20 = "models/gibs/wood_gib01e.mdl",
				breakable_gib21 = "models/gibs/wood_gib01e.mdl",
				breakable_gib22 = "models/gibs/wood_gib01b.mdl",
				breakable_gib23 = "models/gibs/wood_gib01c.mdl",
				breakable_gib24 = "models/gibs/wood_gib01d.mdl",
				breakable_gib25 = "models/gibs/wood_gib01e.mdl"
			},
			["Metal"] = {
				breakable_health = "50",
				breakable_sound = "physics/metal/metal_box_break2.wav",
				breakable_gib1 = "models/gibs/metal_gib1.mdl",
				breakable_gib2 = "models/gibs/metal_gib2.mdl",
				breakable_gib3 = "models/gibs/metal_gib3.mdl",
				breakable_gib4 = "models/gibs/metal_gib4.mdl",
				breakable_gib5 = "models/gibs/metal_gib1.mdl",
				breakable_gib6 = "models/gibs/metal_gib2.mdl",
				breakable_gib7 = "models/gibs/metal_gib3.mdl",
				breakable_gib8 = "models/gibs/metal_gib4.mdl",
				breakable_gib9 = "models/gibs/metal_gib1.mdl",
				breakable_gib10 = "models/gibs/metal_gib2.mdl",
				breakable_gib11 = "models/gibs/metal_gib3.mdl",
				breakable_gib12 = "models/gibs/metal_gib4.mdl",
				breakable_gib13 = "models/gibs/metal_gib1.mdl",
				breakable_gib14 = "models/gibs/metal_gib2.mdl",
				breakable_gib15 = "models/gibs/metal_gib3.mdl",
				breakable_gib16 = "models/gibs/metal_gib4.mdl",
				breakable_gib17 = "models/gibs/metal_gib1.mdl",
				breakable_gib18 = "models/gibs/metal_gib2.mdl",
				breakable_gib19 = "models/gibs/metal_gib3.mdl",
				breakable_gib20 = "models/gibs/metal_gib4.mdl",
				breakable_gib21 = "models/gibs/metal_gib1.mdl",
				breakable_gib22 = "models/gibs/metal_gib2.mdl",
				breakable_gib23 = "models/gibs/metal_gib3.mdl",
				breakable_gib24 = "models/gibs/metal_gib4.mdl",
				breakable_gib25 = "models/gibs/metal_gib4.mdl"
			},
			["Glass"] = {
				breakable_health = "5",
				breakable_sound = "physics/glass/glass_largesheet_break1.wav",
				breakable_gib1 = "models/gibs/glass_shard01.mdl",
				breakable_gib2 = "models/gibs/glass_shard02.mdl",
				breakable_gib3 = "models/gibs/glass_shard03.mdl",
				breakable_gib4 = "models/gibs/glass_shard04.mdl",
				breakable_gib5 = "models/gibs/glass_shard01.mdl",
				breakable_gib6 = "models/gibs/glass_shard02.mdl",
				breakable_gib7 = "models/gibs/glass_shard03.mdl",
				breakable_gib8 = "models/gibs/glass_shard04.mdl",
				breakable_gib9 = "models/gibs/glass_shard01.mdl",
				breakable_gib10 = "models/gibs/glass_shard02.mdl",
				breakable_gib11 = "models/gibs/glass_shard03.mdl",
				breakable_gib12 = "models/gibs/glass_shard04.mdl",
				breakable_gib13 = "models/gibs/glass_shard01.mdl",
				breakable_gib14 = "models/gibs/glass_shard02.mdl",
				breakable_gib15 = "models/gibs/glass_shard03.mdl",
				breakable_gib16 = "models/gibs/glass_shard04.mdl",
				breakable_gib17 = "models/gibs/glass_shard01.mdl",
				breakable_gib18 = "models/gibs/glass_shard02.mdl",
				breakable_gib19 = "models/gibs/glass_shard03.mdl",
				breakable_gib20 = "models/gibs/glass_shard04.mdl",
				breakable_gib21 = "models/gibs/glass_shard01.mdl",
				breakable_gib22 = "models/gibs/glass_shard02.mdl",
				breakable_gib23 = "models/gibs/glass_shard03.mdl",
				breakable_gib24 = "models/gibs/glass_shard04.mdl",
				breakable_gib25 = "models/gibs/glass_shard04.mdl"
			},
			["Human Gibs"] = {
				breakable_health = "50",
				breakable_sound = "physics/body/body_medium_break2.wav",
				breakable_gib1 = "models/Gibs/HGIBS.mdl",
				breakable_gib2 = "models/Gibs/HGIBS_scapula.mdl",
				breakable_gib3 = "models/Gibs/HGIBS_scapula.mdl",
				breakable_gib4 = "models/Gibs/HGIBS_spine.mdl",
				breakable_gib5 = "models/Gibs/HGIBS_spine.mdl",
				breakable_gib6 = "models/Gibs/HGIBS_rib.mdl",
				breakable_gib7 = "models/Gibs/HGIBS_rib.mdl",
				breakable_gib8 = "models/Gibs/HGIBS_rib.mdl",
				breakable_gib9 = "models/Gibs/HGIBS_rib.mdl",
				breakable_gib10 = "models/Gibs/HGIBS_rib.mdl",
				breakable_gib11 = "models/Gibs/HGIBS_rib.mdl",
				breakable_gib12 = "models/Gibs/HGIBS_rib.mdl",
				breakable_gib13 = "",
				breakable_gib14 = "",
				breakable_gib15 = "",
				breakable_gib16 = "",
				breakable_gib17 = "",
				breakable_gib18 = "",
				breakable_gib19 = "",
				breakable_gib20 = "",
				breakable_gib21 = "",
				breakable_gib22 = "",
				breakable_gib23 = "",
				breakable_gib24 = "",
				breakable_gib25 = ""
			},
			["No Gibs or Sound"] = {
				breakable_health = "100",
				breakable_sound = "",
				breakable_gib1 = "",
				breakable_gib2 = "",
				breakable_gib3 = "",
				breakable_gib4 = "",
				breakable_gib5 = "",
				breakable_gib6 = "",
				breakable_gib7 = "",
				breakable_gib8 = "",
				breakable_gib9 = "",
				breakable_gib10 = "",
				breakable_gib11 = "",
				breakable_gib12 = "",
				breakable_gib13 = "",
				breakable_gib14 = "",
				breakable_gib15 = "",
				breakable_gib16 = "",
				breakable_gib17 = "",
				breakable_gib18 = "",
				breakable_gib19 = "",
				breakable_gib20 = "",
				breakable_gib21 = "",
				breakable_gib22 = "",
				breakable_gib23 = "",
				breakable_gib24 = "",
				breakable_gib25 = ""
			},
			["Portal Turret Gibs"] = {
				breakable_health = "50",
				breakable_sound = "physics/metal/metal_box_break2.wav",
				breakable_gib1 = "models/npcs/turret/turret_fx_break_gib1.mdl",
				breakable_gib2 = "models/npcs/turret/turret_fx_break_gib2.mdl",
				breakable_gib3 = "models/npcs/turret/turret_fx_break_gib3.mdl",
				breakable_gib4 = "models/npcs/turret/turret_fx_break_gib4.mdl",
				breakable_gib5 = "models/npcs/turret/turret_fx_break_gib5.mdl",
				breakable_gib6 = "models/npcs/turret/turret_fx_break_gib6.mdl",
				breakable_gib7 = "models/npcs/turret/turret_fx_break_gib7.mdl",
				breakable_gib8 = "models/npcs/turret/turret_fx_break_gib8.mdl",
				breakable_gib9 = "models/npcs/turret/turret_fx_break_gib9.mdl",
				breakable_gib10 = "models/npcs/turret/turret_fx_break_gib10.mdl",
				breakable_gib11 = "models/npcs/turret/turret_fx_break_gib11.mdl",
				breakable_gib12 = "models/npcs/turret/turret_fx_break_gib12.mdl",
				breakable_gib13 = "models/npcs/turret/turret_fx_break_gib13.mdl",
				breakable_gib14 = "models/npcs/turret/turret_fx_break_gib14.mdl",
				breakable_gib15 = "models/npcs/turret/turret_fx_break_gib15.mdl",
				breakable_gib16 = "models/npcs/turret/turret_fx_break_gib16.mdl",
				breakable_gib17 = "models/npcs/turret/turret_fx_break_gib17.mdl",
				breakable_gib18 = "models/npcs/turret/turret_fx_break_gib18.mdl",
				breakable_gib19 = "models/npcs/turret/turret_fx_break_gib19.mdl",
				breakable_gib20 = "models/npcs/turret/turret_fx_break_gib20.mdl",
				breakable_gib21 = "models/npcs/turret/turret_fx_break_gib21.mdl",
				breakable_gib22 = "models/npcs/turret/turret_fx_break_gib22.mdl",
				breakable_gib23 = "models/npcs/turret/turret_fx_break_gib23.mdl",
				breakable_gib24 = "models/npcs/turret/turret_fx_break_gib24.mdl",
				breakable_gib25 = "models/npcs/turret/turret_fx_break_gib25.mdl"
			}
		},
		CVars = preset_cvars
	})

	for i = 1, 25 do
		panel:AddControl("TextBox", {
			Label = "Gib " .. i,
			Command = "breakable_gib" .. i
		})
	end

	panel:AddControl("TextBox", {
		Label = "Break Sound Path",
		Command = "breakable_sound"
	})

	panel:AddControl("Slider", {
		Label = "Health",
		Command = "breakable_health",
		Type = "Integer",
		Min = "1",
		Max = "500"
	})

	panel:AddControl("CheckBox", {
		Label = "Disable gib collision?",
		Command = "breakable_nogibcollision"
	})
end
