-- TODO: allow petting chicken NPC
-- TODO: more sane code
-- TODO: stop fighting with PAC
-- TODO: more natural movement
-- TODO: clean up code

if SERVER then
   AddCSLuaFile()
end
local SWEP=SWEP

SWEP.Author     	= ""
SWEP.Contact      	= ""
SWEP.Purpose      	= ""
SWEP.Instructions   = ""
SWEP.PrintName      = "petpet"   
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair	= true
SWEP.DrawWeaponInfoBox = false

SWEP.SlotPos      	= 1
SWEP.Slot         	= 1

SWEP.Spawnable    	= true

SWEP.AutoSwitchTo	= false
SWEP.AutoSwitchFrom	= true
SWEP.Weight 		= 1
SWEP.IsPetPet = true
SWEP.HoldType = "normal"

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"


function SWEP:DrawHUD() 			end
function SWEP:PrintWeaponInfo() 	end

function SWEP:DrawWeaponSelection(x,y,w,t,a)

    draw.SimpleText("M","creditslogo",x+w/2,y,Color(255, 220, 0,a),TEXT_ALIGN_CENTER)
	
end

function SWEP:DrawWorldModel() 						 end
function SWEP:DrawWorldModelTranslucent() 			 end
function SWEP:CanPrimaryAttack()		return true end
function SWEP:CanSecondaryAttack()		return false end
function SWEP:Reload()					
	if SERVER then
		self:SetX(0)
		self:SetY(0)
	end
	return false

end
function SWEP:Holster()					return true  end
function SWEP:ShouldDropOnDie()			return false end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	self:DrawShadow(false)
end

-- can be executed on other clients 
function SWEP:Holster()
	if CLIENT and self:GetOwner()==LocalPlayer() then
		ctp.Disable()
	end
	return true
end

function SWEP:Think()
end

function SWEP:Deploy()
	if CLIENT and self:GetOwner()==LocalPlayer() then
		ctp.Enable()
	end
	
	return true
end

function SWEP:PreDrawViewModel( )
	return true
end


function SWEP:OnDrop()   
    if SERVER then
		self:Remove()
	end
end

-- no need to move anymore
function SWEP:GetViewModelPosition( pos, ang )
	return pos,ang
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() or SERVER then return end
	if self:GetOwner():InVehicle() then return end
	
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end 
	self.DrawCrosshair = not self.DrawCrosshair 
	self:SetNextSecondaryFire(CurTime() + 0.3) 
end


local cache = {}
local _GetChildBonesRecursive

_GetChildBonesRecursive = function(ent, bone, src)
	local t = src or {}
	table.insert(t, bone)
	local cbones = ent:GetChildBones(bone)

	for _, bone in next, cbones do
		_GetChildBonesRecursive(ent, bone, t)
	end

	return t
end

local function GetChildBonesRecursive(ent, bone)
	local mdl = ent:GetModel()
	local mdlbones = cache[mdl]

	if not mdlbones then
		mdlbones = {}
		cache[mdl] = mdlbones
	end

	local ret = mdlbones[bone]
	if ret then return ret end
	ret = _GetChildBonesRecursive(ent, bone)
	mdlbones[bone] = ret

	return ret
end

local angle_origin = Angle(0,0,0)
local kill
local BuildBonePositionsCallback = function(self)
	if kill then 
		local val = self.buildbonepos_petpet
		if not val then return end
		Msg'[MeleeBP] ' print("EMERGENCY KILL")
		self.buildbonepos_petpet = nil
		self:RemoveCallback("BuildBonePositions", val)
		local bonename = "ValveBiped.Bip01_R_UpperArm"
		local masterbone = self:LookupBone(bonename)
		
		if masterbone then
			self:ManipulateBoneAngles( masterbone, angle_origin)
		end
		
		return
	end
	
	kill=true
	local wep = self:GetActiveWeapon()
	local valid = wep:IsValid()
	
	local bonename = "ValveBiped.Bip01_R_UpperArm"
	local masterbone = self:LookupBone(bonename)
	local bonename2 = "ValveBiped.Bip01_R_Forearm"
	local bone2 = self:LookupBone(bonename2)

	if not wep.IsPetPet or not wep.GetX then
		
		local val = self.buildbonepos_petpet
		--if not val then return end
		self.buildbonepos_petpet = nil
		Msg'[PETPET] ' print("del world callback",val)
		self:RemoveCallback("BuildBonePositions", val)
		if masterbone then
			self:ManipulateBoneAngles( masterbone, angle_origin)
		end
		if bone2 then
			self:ManipulateBoneAngles( bone2, angle_origin)
		end
		
		kill=false
		return
	end
	
	if not masterbone then
		kill=false
		return
	end
	
	local ang = Angle(wep:GetX()*180,wep:GetY()*180,0)
	local a = self._lastpetpetang or ang
	ang = LerpAngle(1-FrameTime()*8,ang,a)
	self._lastpetpetang = ang
	self:ManipulateBoneAngles( masterbone, ang)

	if not bone2 then
		kill=false
		return
	end
	

	
	local ang = self:Crouching() and Angle(0,45,0) or angle_origin
	
	self:ManipulateBoneAngles( bone2, ang)



	kill=false
end

local function AddBoneCallback(self)
	local pl = self:GetOwner()

	if IsValid(pl) then
		if not pl.buildbonepos_petpet then
			pl.buildbonepos_petpet = pl:AddCallback("BuildBonePositions", BuildBonePositionsCallback) or error"?"
			Msg'[PETPET] ' print("add w callback",pl.buildbonepos_petpet)
		end
	end
end
function SWEP:GetX()
	return self:GetDTFloat(0)
end
function SWEP:SetX(v)
	return self:SetDTFloat(0,v)
end
function SWEP:GetY()
	return self:GetDTFloat(1)
end
function SWEP:SetY(v)
	return self:SetDTFloat(1,v)
end

function SWEP:Tick()
	local pl = self:GetOwner()
	if (CLIENT and pl ~= LocalPlayer()) then return end 
		
	local cmd = pl:GetCurrentCommand()
	if not cmd:KeyDown(IN_ATTACK2) then return end
		
	self:SetX(math.Clamp(self:GetX() + cmd:GetMouseX() * 0.001, -1, 1))
	self:SetY(math.Clamp(self:GetY() + cmd:GetMouseY() * 0.001, -1, 1))
end
function SWEP:FreezeMovement()
	local pl = self:GetOwner()
	if pl:KeyDown(IN_ATTACK2) or pl:KeyReleased(IN_ATTACK2) then return true end

	return false
end


function SWEP:DrawWorldModel()
	if not IsValid(self:GetOwner()) then
		return
	end
	AddBoneCallback(self)
	
end
