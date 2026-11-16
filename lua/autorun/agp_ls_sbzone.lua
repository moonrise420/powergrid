-- PowerGrid: when Spacebuild's own life support runs, a Life Support Core keeps its area breathable through
-- Spacebuild: an invisible Spacebuild environment (like a climate regulator) sits on the core. Inside the StarCore ship
-- (or the bubble) Spacebuild sees 21 % oxygen, 20 C and normal gravity. Only registered when Spacebuild is installed.
AddCSLuaFile()

local function register()
    if scripted_ents.GetStored("agp_ls_sbzone") or not scripted_ents.GetStored("base_sb_environment") then return end
    local ENT = {}
    ENT.Type = "anim"
    ENT.Base = "base_sb_environment"
    ENT.PrintName = "AGP Life Support area"
    ENT.Spawnable = false
    ENT.AdminSpawnable = false
    ENT.DisableDuplicator = true
    ENT.DoNotDuplicate = true

    if SERVER then
        function ENT:Initialize()
            self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
            baseclass.Get("base_sb_environment").Initialize(self)
            self:SetNoDraw(true)
            self:SetNotSolid(true)
            self:SetCollisionGroup(COLLISION_GROUP_WORLD)
            local ph = self:GetPhysicsObject()
            if IsValid(ph) then ph:EnableMotion(false) end
            self:AGPSetArea(0)
        end
        -- size 0 = off (Spacebuild only puts things inside when they are closer than the size)
        function ENT:AGPSetArea(size)
            local e = self.sbenvironment
            e.size = size
            e.gravity, e.atmosphere, e.pressure, e.temperature = 1, 1, 1, 293
            e.name = "Life support"
            local unit = 5 * (self:GetVolume() / 1000)
            e.air.max = math.Round(100 * unit)
            e.air.o2per, e.air.o2 = 21, math.Round(21 * unit)
            e.air.nper, e.air.n = 78, math.Round(78 * unit)
            e.air.co2per, e.air.co2 = 0, 0
            e.air.hper, e.air.h = 0, 0
            e.air.emptyper, e.air.empty = 1, math.Round(1 * unit)
        end
        -- ship interior (TARDIS style): copy the environment at the real ship's place, keep on-board gravity
        local function num(f, env) local ok, v = pcall(f, env); return ok and tonumber(v) or 0 end
        function ENT:AGPCopyFrom(real, size)
            local e = self.sbenvironment
            e.size = size
            local space = (not IsValid(real)) or (real.IsSpace and real:IsSpace())
            e.name = "Ship interior"
            e.gravity = 1
            local unit = 5 * (self:GetVolume() / 1000)
            e.air.max = math.Round(100 * unit)
            if space then
                e.atmosphere, e.pressure, e.temperature = 0, 0, 293   -- vacuum, but the hull keeps it warm
                e.air.o2per, e.air.nper, e.air.co2per, e.air.hper, e.air.emptyper = 0, 0, 0, 0, 100
            else
                e.atmosphere = num(real.GetAtmosphere, real)
                e.pressure = real.sbenvironment and real.sbenvironment.pressure or num(real.GetPressure, real)
                e.temperature = num(real.GetTemperature, real)
                e.air.o2per = num(real.GetO2Percentage, real)
                e.air.co2per = real.GetCO2Percentage and num(real.GetCO2Percentage, real) or 0
                e.air.nper = real.GetNPercentage and num(real.GetNPercentage, real) or 0
                e.air.hper = real.GetHPercentage and num(real.GetHPercentage, real) or 0
                e.air.emptyper = math.max(0, 100 - e.air.o2per - e.air.co2per - e.air.nper - e.air.hper)
            end
            e.air.o2 = math.Round(e.air.o2per * unit); e.air.n = math.Round(e.air.nper * unit)
            e.air.co2 = math.Round(e.air.co2per * unit); e.air.h = math.Round(e.air.hper * unit)
            e.air.empty = math.Round(e.air.emptyper * unit)
        end
        -- inside = what the core keeps breathable (the ship box or the bubble), not Spacebuild's sphere
        function ENT:OnEnvironment(ent, environment, space)
            local it = self.AGPInterior
            if it then
                if not ent or ent == self or ent.IsInBrushEnv or self.sbenvironment.size <= 0 or not IsValid(it) then return end
                local p = ent.EyePos and ent:EyePos() or ent:GetPos()
                if not p:WithinAABox(it:LocalToWorld(it:OBBMins()), it:LocalToWorld(it:OBBMaxs())) then return end
                -- a Spacebuild air machine placed inside (smaller, same or higher priority) still wins
                if environment == space or environment:GetPriority() < self:GetPriority() then return self end
                if environment:GetPriority() == self:GetPriority() and (environment.GetSize and environment:GetSize() or 0) > self:GetSize() then return self end
                return
            end
            local core = self.AGPCore
            if not ent or ent == self or ent.IsInBrushEnv or self.sbenvironment.size <= 0 or not IsValid(core) then return end
            if not core:LSContains(ent.EyePos and ent:EyePos() or ent:GetPos()) then return end
            if environment == space or environment:GetPriority() <= self:GetPriority() then return self end
        end
        function ENT:Think() end
        function ENT:UpdateTransmitState() return TRANSMIT_NEVER end
    else
        function ENT:Draw() end
        function ENT:DrawTranslucent() end
    end
    scripted_ents.Register(ENT, "agp_ls_sbzone")
end
hook.Add("Initialize", "AGP.LS.SBZone", register)
hook.Add("InitPostEntity", "AGP.LS.SBZone", register)

if not SERVER then return end
AGP = AGP or {}
AGP.LS = AGP.LS or {}

-- called by the Life Support Core every second: on = area active
function AGP.LS.SBZone(core, on)
    if not scripted_ents.GetStored("agp_ls_sbzone") then return end
    local z = core.AGPSBZone
    if not on then
        if IsValid(z) then z:AGPSetArea(0) end
        return
    end
    if not IsValid(z) then
        z = ents.Create("agp_ls_sbzone")
        if not IsValid(z) then return end
        z:SetPos(core:GetPos())
        z:Spawn()
        z:SetParent(core)
        z.AGPCore = core
        core.AGPSBZone = z
        core:DeleteOnRemove(z)
    end
    -- size: the bubble radius, or a sphere around the whole ship (the box test above is the real check)
    local size = core.Radius or 500
    local ship = core:LSShip()
    if ship and ship.LocalMins then size = (ship.LocalMaxs - ship.LocalMins):Length() / 2 + 200 end
    z:AGPSetArea(size)   -- refreshes the air too (Spacebuild's breathing uses it up, our core pays with oxygen)
end

-- called by a ship interior every half second: its air is the air at the real ship's place, gravity always 1
function AGP.LS.SBInterior(interior, ship)
    if not scripted_ents.GetStored("agp_ls_sbzone") then return end
    local SB = CAF and CAF.GetAddon and CAF.GetAddon("Spacebuild")
    if not (SB and SB.FindEnvironmentOnPos and SB.GetStatus and SB.GetStatus()) then return end
    local z = interior.AGPSBZone
    if not IsValid(z) then
        z = ents.Create("agp_ls_sbzone")
        if not IsValid(z) then return end
        z:SetPos(interior:WorldSpaceCenter())
        z:Spawn()
        z:SetParent(interior)
        z.AGPInterior = interior
        interior.AGPSBZone = z
        interior:DeleteOnRemove(z)
    end
    local real = IsValid(ship) and SB.FindEnvironmentOnPos(ship:LocalToWorld(interior:WorldToLocal(interior:WorldSpaceCenter())))
    if real == z then real = nil end
    z:AGPCopyFrom(real, interior:BoundingRadius() + 200)
end