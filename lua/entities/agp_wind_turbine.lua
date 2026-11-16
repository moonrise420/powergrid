-- PowerGrid: Wind Turbine (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_wind_turbine"
ENT.PrintName = PowerGrid.L("agp_ent_wind_turbine", "Wind Turbine")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "wind"
ENT.AGPModel = "models/agp_power/agp_wind_tower.mdl"
ENT.AGPCapacity = 300000
ENT.AGPRate = 25000
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end

if CLIENT then
    -- the rotor turns in front of the nacelle; faster when the turbine produces
    function ENT:Draw()
        self:DrawModel()
        if not IsValid(self.Rotor) then
            self.Rotor = ClientsideModel("models/agp_power/agp_wind_rotor.mdl")
            if not IsValid(self.Rotor) then return end
            self.Rotor:SetNoDraw(true)
            -- (2026-11-14: the rotor model's origin was 15.5 beside its hub - the export had centred the bounding box -
            -- so the hub circled round the axle instead of sitting on it (owner: "its not mounted central"). The model's
            -- vertices were moved so the hub IS the origin; its stored bounds are those of the old centre, so wide ones here)
            self.Rotor:SetRenderBounds(Vector(-72, -72, -72), Vector(72, 72, 72))
            self.Spin = 0
        end
        self.Spin = (self.Spin + FrameTime() * (self:GetOn() and 70 or 8)) % 360
        -- AGP 2026-11-14 (owner: "the propeller of the windrad is not correctly mounted"): the height came from
        -- OBBMaxs(), the COLLISION box, which is lower than the model since the new models of 2026-11-12 - the hub hung
        -- under the nacelle. The height now comes from the model's own drawn bounds: the nacelle is its top 10.2 units,
        -- the axle runs through its middle. Along the axle (the model's X) the hub sits on the nacelle's front face
        -- (the face is at 11.3, the hub is 6.5 deep on each side of its middle).
        local a = self:GetAngles()
        a:RotateAroundAxis(a:Forward(), self.Spin)
        local _, top = self:GetModelRenderBounds()
        self.Rotor:SetPos(self:LocalToWorld(Vector(15, 0, top.z - 5.1)))
        self.Rotor:SetAngles(a)
        self.Rotor:DrawModel()
    end
    function ENT:OnRemove()
        if IsValid(self.Rotor) then self.Rotor:Remove() end
    end
end
