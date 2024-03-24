-- TODO:
--  - Allow changing pitch
--  - no bell models
--  - allow changing sound
--  - fix PlayFile LRU logic
--  - set mass
--
-- https://github.com/Vurv78/WebAudio
-- "models/props/de_inferno/bell_largeb.mdl"
-- https://raw.githubusercontent.com/Metastruct/garrysmod-chatsounds/master/sound/chatsounds/autoadd/lisa_the_painful/bell.ogg

local Tag = 'sent_bell'
local bell_sound = 'ambient/alarms/warningbell1.wav'
local bell_sound_2 = 'hourly-notification-bells-fc2a1882.mp3'

if file.Exists("sound/" .. bell_sound_2, 'GAME') then
	bell_sound = bell_sound_2
end

--sound.PlayFile("sound/"..bell_sound,"",print)
if SERVER then
	AddCSLuaFile()
end

ENT.Base = "base_anim"
ENT.PrintName = "Bell"
ENT.Author = "Python1320"
ENT.Information = "A bell"
ENT.Category = "Fun + Games"
ENT.Editable = false
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SpawnFunction(ply, tr, ClassName)
	if not tr.Hit then return end
	local SpawnPos = tr.HitPos + tr.HitNormal * 36
	local ent = ents.Create(ClassName)
	ent:SetPos(SpawnPos)
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:Initialize()
	if SERVER then
		self:SetUseType(SIMPLE_USE)
		self:SetModel("models/props_phx/games/chess/black_pawn.mdl")
		self:SetMaterial('models/player/shared/gold_player')
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:AddEFlags(EFL_NO_THINK_FUNCTION)
		local phys = self:GetPhysicsObject()

		if phys:IsValid() then
			--phys:AddGameFlag(FVPHYSICS_HEAVY_OBJECT)
			--phys:AddGameFlag(FVPHYSICS_NO_NPC_IMPACT_DMG)
			phys:SetMaterial("metal")
			phys:Wake()
		end
	else
	end
end

if CLIENT then
	local bells = {}

	local function add(snd, ent)
		assert(IsValid(snd))
		assert(IsValid(ent))

		local newinfo = {snd, ent, {}}

		table.insert(bells, newinfo)
	end

	local function getoldest(self)
		local oldest, oldest_time = false, 0

		for i = #bells, 1, -1 do
			local bell = bells[i]

			if bell ~= true then
				local snd, ent = unpack(bell)

				if not snd:IsValid() then
					table.remove(bells, i)
				end

				local play_time = snd:GetTime() or 99999

				if play_time > 0.2 and play_time > oldest_time then
					oldest_time = play_time
					oldest = i
				end
			end
		end

		return oldest and bells[oldest], oldest_time
	end

	local function PlayLRUBell(self)
		local bell = getoldest(self)

		if not bell and #bells < 6 then
			self.bellsnd = false
			print("new sound", self, bell_sound)
			table.insert(bells, true)

			sound.PlayFile("sound/" .. bell_sound, "3d mono noblock", function(snd, err, errcode)
				if not snd then
					ErrorNoHalt(bell_sound, " -> ", err, " ", errcode, "\n")

					return
				end

				if not self:IsValid() then
					snd:Stop()
				end

				add(snd, self)
				self.bellsnd = snd
				snd:SetPos(self:GetPos())
			end)

			return
		end

		local snd = bell and bell[1]
		if not snd then return end
		snd:SetPos(self:GetPos())
		snd:SetTime(0)
		snd:Play()
		local off = ((self:EntIndex() * 2777) % 100) / 100
		off = off * 0.30 - 0.15
		snd:SetPlaybackRate(1 + off + math.Rand(-0.01, 0.01))
		bell[3] = self

		return bell
	end

	function ENT:Draw()
		self:DrawModel()
	end

	net.Receive(Tag, function()
		local self = net.ReadEntity()
		if not self:IsValid() or not self.Bell then return end
		self:Bell()
	end)

	function ENT:Bell()
		if EyePos():DistToSqr(self:GetPos()) > 4096 ^ 2 then return end
		self.bellsnd = PlayLRUBell(self)
	end

	function ENT:Think()
		local bell = self.bellsnd
		if not bell then return end

		if bell[3] ~= self then
			self.bellsnd = false
		end

		local snd = bell[1]

		if IsValid(snd) then
			snd:SetPos(self:GetPos())
		end
	end

	function ENT:OnRemove()
		if #ents.FindByClass(self:GetClass()) <= 1 then
			print("purging bell sounds")

			for k, v in pairs(bells) do
				local snd = v ~= true and v and v[1]

				if v then
					timer.Simple(3, function()
						if IsValid(snd) then
							snd:Stop()
						end
					end)
				end

				bells[k] = nil
			end
		end
	end
else
	util.AddNetworkString(Tag)

	function ENT:OnTakeDamage(dmginfo)
		if (dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_BULLET)) then
			self:Bell()
		end

		self:TakePhysicsDamage(dmginfo)
	end

	function ENT:Use(activator, caller)
		if self:IsPlayerHolding() then return end

		if IsValid(activator) and activator:IsPlayer() then
			activator:PickupObject(self)
		end
	end

	function ENT:Bell(todo)
		net.Start(Tag, true)
		net.WriteEntity(self)
		net.SendPVS(self:GetPos())
	end
end
