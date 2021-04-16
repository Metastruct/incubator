SWEP.Base = "weapon_hl2basebludgeon" -- required, credits to original creators for the base and this file

SWEP.PrintName = "Ladle"
SWEP.Category = "Sauna ladle"

SWEP.Spawnable = true

SWEP.Slot = 0
SWEP.SlotPos = 1

SWEP.HoldType = "slam"

SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/props_interiors/pot02a.mdl"

SWEP.Range = 40
SWEP.MELEE_HITWORLD = "Metal_Box.ImpactHard"
SWEP.MELEE_HIT = "Metal_Box.ImpactHard"
SWEP.SINGLE = "WeaponFrag.Roll"

SWEP.Primary.Damage = 0
SWEP.Primary.Delay = 2

if CLIENT then
    function SWEP:AddWM(owner,mdl,pos,ang,left,scale,mat,col)
        local b = "ValveBiped.Bip01_" .. (left and "L" or "R") .. "_Hand"
        if (owner:LookupBone(b) ~= nil) then
            local bnep,bnea = owner:GetBonePosition(owner:LookupBone(b))
            bnep:Add(bnea:Right() * pos.x)
            bnep:Add(bnea:Up() * pos.y)
            bnep:Add(bnea:Forward() * pos.z)
            bnea:RotateAroundAxis(bnea:Right(),ang.x)
            bnea:RotateAroundAxis(bnea:Up(),ang.y)
            bnea:RotateAroundAxis(bnea:Forward(),ang.z)
            local m = Matrix()
            m:Scale(scale)
            local ent = ClientsideModel(mdl,RENDERGROUP_OTHER)
            if not IsValid(ent) then return end

            ent:SetModel(mdl)
            ent:SetNoDraw(true)
            ent:SetPos(bnep)
            ent:SetAngles(bnea)
            ent:EnableMatrix("RenderMultiply",m)
            if mat then
                ent:SetMaterial(mat)
            end
            col = col or Color(255,255,255)
            render.SetColorModulation(col.r / 255,col.g / 255,col.b / 255)
            ent:DrawModel()
            ent:Remove()
        end
    end

    function SWEP:AddVM(vm,mdl,pos,ang,bone,scale,mat,col)
        local b = tostring(bone)
        if (vm:LookupBone(b) ~= nil) then
            local bnep,bnea = vm:GetBonePosition(vm:LookupBone(b))
            bnep:Add(bnea:Right() * pos.x)
            bnep:Add(bnea:Up() * pos.y)
            bnep:Add(bnea:Forward() * pos.z)
            bnea:RotateAroundAxis(bnea:Right(),ang.x)
            bnea:RotateAroundAxis(bnea:Up(),ang.y)
            bnea:RotateAroundAxis(bnea:Forward(),ang.z)
            local m = Matrix()
            m:Scale(scale)
            local ent = ClientsideModel(mdl,RENDERGROUP_OTHER)
            if not IsValid(ent) then return end

            ent:SetModel(mdl)
            ent:SetNoDraw(true)
            ent:SetPos(bnep)
            ent:SetAngles(bnea)
            ent:EnableMatrix("RenderMultiply",m)
            if mat then
                ent:SetMaterial(mat)
            end
            col = col or Color(255,255,255)
            render.SetColorModulation(col.r / 255,col.g / 255,col.b / 255)
            ent:DrawModel()
            ent:Remove()
        end
    end

    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()
        if not IsValid(owner) then
            self:DrawModel()
            return
        else
            self:DrawShadow(false)
            self:AddWM(owner,"models/props_interiors/pot02a.mdl",Vector(5,3,9),Angle(34,60,190),false,Vector(1,1,1),"")
        end
    end

    function SWEP:PostDrawViewModel(vm,ply,wep)
        if not IsValid(vm) then return end
        vm:SetMaterial("engine/occlusionproxy")
        self:AddVM(vm,"models/props_interiors/pot02a.mdl",Vector(5,-8,2.5),Angle(0,90,-155),"ValveBiped.Bip01_R_Hand",Vector(1,1,1),"")
    end
end

function SWEP:OnRemove()
    if CLIENT then
        local owner = self:GetOwner() or LocalPlayer()

        if IsValid(owner) then
            local vm = owner:GetViewModel() or NULL
            if IsValid(vm) then vm:SetMaterial() end
        end
    end
end

function SWEP:Holster(wep)
    self:OnRemove()
    return true
end

function SWEP:OnDrop()
    self:OnRemove()
    return true
end
