-- PowerGrid: base of all PowerGrid parts.
--   storage  energy cells (XS..XL): hold energy
--   node     power nodes (XS..L): link everything placed on them, show the network on their display
--   display  wall displays (S/L): show the network they are linked to
--   pump     valve between networks: on = energy flows through, off = the networks are separate (Use / Wire "On")
--   solar    solar panels: energy while open sky is above them
--   wind     wind turbine: energy, more the higher it stands; the rotor turns
--   cache    black hole cache: every resource, pulls nothing in
--   tank     resource tank (XS..XL): holds one resource, E changes it while empty (skin = resource)
--   lscore   life support core: breathable area (the StarCore ship it sits on, or a bubble), makes oxygen from water
--   dispenser suit dispenser: E refills your suit (oxygen, energy, water as coolant)
--   compressor air compressor: oxygen (or nitrogen: E / Wire "Nitrogen") out of a breathable planet's air
--   heavywater heavy water extractor: water + energy -> heavy water (the fusion reactor's fuel)
--   fuelcell   fuel cell: hydrogen + oxygen -> water + a little energy (the splitter backwards; water in space)
--   waterpump  water pump: water while its intake is in water
--   heater / cooler  climate control: inside a life support area they help the core reach its target temperature
--   splitter   water splitter: water + energy -> hydrogen + oxygen (2 : 1), anywhere
--   ramscoop   ram scoop: hydrogen out of space, more the faster it flies towards its front (its mouth)
--   fusion     fusion reactor: a lot of energy from heavy water, cooled by water (makes steam), trips when uncooled
--   hydro      hydro generator: energy while it stands in water, more the deeper / the more of it is submerged
--   turbine    steam turbine: steam in, energy and water out
--   probe      environment probe: no resources, Wire outputs + info box for the air / pressure / temperature / gravity around it
--   terraformer  terraformer: energy + gases slowly turn the planet it stands on towards breathable air and a livable climate
--   plant      hydroponics (S / L): carbon dioxide + water + energy (light) -> oxygen
--   gravity    gravity regulator: artificial gravity 0..2 g in a radius (stations, props in space)
-- (the last seven are the life support devices Spacebuild had and PowerGrid lacked; devices 4..7 use the environment
-- API of lua/autorun/server/agp_ls_env.lua: AGP.LS.Probe / PlanetAt / ChangeGas / SetPlanetTemperature /
-- AddGravityZone / RemoveGravityZone - every call is guarded, so they also load and run before that API exists)
-- Works with PowerGrid's own network and with Spacebuild/RD (lua/powergrid/sv_bridge.lua).
if PowerGrid and PowerGrid.SetupEntity then PowerGrid.SetupEntity(ENT) end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.AGPNameKey = "agp_ent_power_base"
ENT.PrintName = PowerGrid.L("agp_ent_power_base", "PowerGrid part")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.AGPKind = "storage"
ENT.AGPModel = "models/agp_power/agp_cell_small.mdl"
ENT.AGPCapacity = 0          -- energy it holds (storage / cache per resource / generator buffer)
ENT.AGPRate = 0              -- generators: energy per second
ENT.AGPScreen = nil          -- floating screen above the part: { up, scale, w, lines }
ENT.AGPSurface = nil         -- screen on the model itself: { pos = local Vector (front face centre), w, h, tilt }
ENT.AGPAdminOnly = false
ENT.IsAGPPower = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Summary") -- "parts|resource=amount/max;..."
    self:NetworkVar("Bool", 0, "On")         -- pump open / generator producing
end

local function short(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.1f G", n / 1e9) end
    if n >= 1e6 then return string.format("%.1f M", n / 1e6) end
    if n >= 1e3 then return string.format("%.1f k", n / 1e3) end
    return tostring(math.floor(n))
end
ENT.Short = short

if SERVER then
    AddCSLuaFile()
    if not ConVarExists("agp_blackhole_cache_everyone") then
        CreateConVar("agp_blackhole_cache_everyone", "0", { FCVAR_ARCHIVE }, "Ascension Gates: 1 = every player may spawn the Black Hole Cache (default: admins only)")
    end
    -- admin switch for the Terraformer (it changes the planet for everybody): 1 = allowed (default), 0 = off
    if not ConVarExists("agp_terraform_allowed") then
        CreateConVar("agp_terraform_allowed", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "PowerGrid: 1 = Terraformers work, 0 = they are switched off (admin setting)", 0, 1)
    end

    function ENT:SpawnFunction(p, t, cls)
        if not t.Hit then return end
        local st = scripted_ents.GetStored(cls)
        if st and st.t.AGPAdminOnly and not (p:IsAdmin() or game.SinglePlayer()) and not GetConVar("agp_blackhole_cache_everyone"):GetBool() then
            PowerGrid.Say(p, "agp_msg_admin_only", "Only admins can spawn this.")
            return
        end
        if st and st.t.AGPKind == "terraformer" and not (PowerGrid.TerraAllowed and PowerGrid.TerraAllowed()) and not (p:IsAdmin() or game.SinglePlayer()) then
            PowerGrid.Say(p, "agp_msg_terra_off", "Terraformers are switched off on this server (admin setting).")
            return
        end
        local e = ents.Create(cls)
        e:SetPos(t.HitPos + t.HitNormal * 4)
        local ang = p:GetAimVector():Angle()
        e:SetAngles(Angle(0, (ang.y + 180) % 360, 0))
        if st and st.t.AGPKind == "display" and math.abs(t.HitNormal.z) < 0.5 then
            e:SetAngles(t.HitNormal:Angle())   -- on a wall: face away from it
        end
        e:Spawn()
        e:Activate()
        local mn = e:OBBMins()
        if st and st.t.AGPKind == "display" and math.abs(t.HitNormal.z) < 0.5 then
            -- back of the model on the wall (a fixed 3 units left the large display half inside the wall: the tool hit the wall)
            e:SetPos(t.HitPos + t.HitNormal * (0.5 - mn.x) - Vector(0, 0, (e:OBBMaxs().z - mn.z) / 2))
        else
            e:SetPos(t.HitPos - Vector(0, 0, mn.z))
        end
        return e
    end

    function ENT:Initialize()
        self:SetModel(self.AGPModel)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
        if AGP and AGP.Power then AGP.Power.Register(self) end
        local k = self.AGPKind
        if k == "storage" then
            self:AddResource("energy", self.AGPCapacity, 0)
            if self.CreateWireOutputs then self:CreateWireOutputs("Energy", "Max Energy", "Network Energy", "Network Max Energy") end
        elseif k == "solar" or k == "wind" then
            self:AddResource("energy", self.AGPCapacity, 0)
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing", "Energy per second") end
        elseif k == "pump" then
            self:SetOn(true)
            self.AGPPump, self.AGPPumpOn = true, true
            if self.CreateWireInputs then self:CreateWireInputs("On") end
            if self.CreateWireOutputs then self:CreateWireOutputs("On") end
        elseif k == "node" and PowerGrid.RD3() then
            -- Spacebuild (CAF Resource Distribution) runs: the node is a real Spacebuild node, so the Smart Link Tool and
            -- our Grid Power Connector link devices to it
            local RD = CAF.GetAddon("Resource Distribution")
            self.IsNode = true
            self.netid = RD.CreateNetwork(self)
            self:SetNWInt("netid", self.netid)
            self.range = math.Clamp(math.floor(self:BoundingRadius() * 12), 512, 4096)
            self:SetNWInt("range", self.range)
        elseif k == "display" then
            if self.CreateWireOutputs then self:CreateWireOutputs("Network Energy", "Network Max Energy") end
        elseif k == "tank" then
            self:SetTankResource(1)
        elseif k == "lscore" then
            self:AddResource("oxygen", self.AGPCapacity, 0)
            self:AddResource("carbon dioxide", self.AGPCapacity, 0)   -- what the people inside breathe out
            self.Radius = 500
            if self.CreateWireInputs then self:CreateWireInputs("On", "Radius", "Temperature") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Active", "Radius", "Ship", "Oxygen", "Temperature", "Target Temperature", "Outside Temperature", "Carbon Dioxide") end
            self.AGPWantOn = true
            self.TargetTemp = 293.15
        elseif k == "heater" or k == "cooler" then
            if self.CreateWireInputs then self:CreateWireInputs("On") end
            if self.CreateWireOutputs then self:CreateWireOutputs("On", "Working") end
            self.AGPWantOn = true
        elseif k == "compressor" or k == "waterpump" then
            self:AddResource(k == "compressor" and "oxygen" or "water", self.AGPCapacity, 0)
            -- the compressor collects oxygen or nitrogen (E / Wire "Nitrogen"); nitrogen storage is only added once it is
            -- chosen (a pasted copy brings its gas and storage along in its entity table)
            if k == "compressor" and self.CreateWireInputs then self:CreateWireInputs("Nitrogen") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing") end
        elseif k == "heavywater" then
            self:AddResource("heavy water", self.AGPCapacity, 0)
            if self.CreateWireInputs then self:CreateWireInputs("On") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing", "Heavy Water per second") end
            self.AGPWantOn = true
        elseif k == "fuelcell" then
            self:AddResource("water", self.AGPCapacity, 0)
            self:AddResource("energy", 50000, 0)
            if self.CreateWireInputs then self:CreateWireInputs("On") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing", "Energy per second", "Water per second") end
            self.AGPWantOn = true
        elseif k == "splitter" then
            self:AddResource("hydrogen", self.AGPCapacity, 0)
            self:AddResource("oxygen", self.AGPCapacity, 0)
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing") end
        elseif k == "ramscoop" then
            self:AddResource("hydrogen", self.AGPCapacity, 0)
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing", "Hydrogen per second") end
        elseif k == "fusion" then
            self:AddResource("energy", self.AGPCapacity, 0)
            self:AddResource("heavy water", 3000, 0)
            self:AddResource("water", 6000, 0)
            self:AddResource("steam", 6000, 0)
            if self.CreateWireInputs then self:CreateWireInputs("On") end
            if self.CreateWireOutputs then self:CreateWireOutputs("On", "Energy per second", "Heat", "Overheated", "Steam per second") end
            self.AGPWantOn, self.AGPHeat, self.AGPTripped = true, 20, false
        elseif k == "hydro" then
            self:AddResource("energy", self.AGPCapacity, 0)
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing", "Energy per second", "Submerged") end
        elseif k == "turbine" then
            self:AddResource("energy", self.AGPCapacity, 0)
            self:AddResource("steam", 3000, 0)
            self:AddResource("water", 3000, 0)
            if self.CreateWireInputs then self:CreateWireInputs("On") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing", "Energy per second", "Steam per second", "Water per second") end
            self.AGPWantOn = true
        elseif k == "probe" then
            -- no resources: it only reads the environment (Wire outputs + the info box)
            if self.CreateWireOutputs then
                self:CreateWireOutputs("Oxygen", "Carbon Dioxide", "Nitrogen", "Hydrogen", "Pressure", "Temperature", "Gravity", "Breathable", "In Space", "Planet [STRING]")
            end
        elseif k == "terraformer" then
            self:AddResource("energy", self.AGPCapacity, 0)
            self:AddResource("oxygen", 3000, 0)
            self:AddResource("nitrogen", 3000, 0)
            self:AddResource("carbon dioxide", 3000, 0)
            if self.CreateWireInputs then self:CreateWireInputs("On", "Strength") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Working", "Progress", "Oxygen Progress", "Temperature Progress") end
            self.AGPWantOn, self.AGPStrength, self.AGPProgress = true, 1, 0
        elseif k == "plant" then
            self:AddResource("energy", self.AGPCapacity, 0)
            self:AddResource("carbon dioxide", self.AGPCapacity, 0)
            self:AddResource("water", self.AGPCapacity, 0)
            self:AddResource("oxygen", self.AGPCapacity, 0)
            if self.CreateWireInputs then self:CreateWireInputs("On") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Producing", "Oxygen per second", "Growth") end
            self.AGPWantOn = true
        elseif k == "gravity" then
            self:AddResource("energy", self.AGPCapacity, 0)
            self.AGPRadius, self.AGPGrav = 500, 1
            if self.CreateWireInputs then self:CreateWireInputs("On", "Radius", "Gravity") end
            if self.CreateWireOutputs then self:CreateWireOutputs("Active", "Radius", "Gravity", "Energy per second") end
            self.AGPWantOn = true
        elseif k == "cache" then
            self.AGPCacheRes = {}
            local list = StarGate and StarGate.CFG and StarGate.CFG:Get("black_hole", "resources", "") or ""
            if not list:find(",", 1, true) then -- config not loaded: the Black Hole's own list
                list = "energy,oxygen,nitrogen,water,steam,heavy water,hydrogen,carbon dioxide,liquid nitrogen,hot liquid nitrogen,methane,propane,deuterium,tritium"
            end
            for _, r in ipairs(PowerGrid.Split(list, ",")) do
                if r ~= "" then
                    self.AGPCacheRes[#self.AGPCacheRes + 1] = r
                    self:AddResource(r, self.AGPCapacity, self.AGPCapacity)
                end
            end
        end
        -- AGP: with Spacebuild's Resource Distribution the parts that hold nothing themselves (heaters, coolers,
        -- suit dispenser, displays, valve) never joined it (only AddResource does that), so the Connector tool and the
        -- power node refused them ("does not use power") and they saw no energy: devices without storage now
        local rdNet = PowerGrid.RD3()
        if rdNet and not self.IsNode and table.Count(rdNet.GetEntityTable(self) or {}) == 0 then
            if rdNet.RegisterNonStorageDevice then rdNet.RegisterNonStorageDevice(self) else rdNet.AddResource(self, "energy", 0, 0) end
        end
        self:NextThink(CurTime() + 0.5)
    end

    -- energy of the network this part is in. With Spacebuild running a node IS the network (it holds nothing itself),
    -- so it asks Resource Distribution for the network's totals (before: the node showed 0 / 0)
    function ENT:NetEnergy()
        if self.IsNode and self.netid and CAF and CAF.GetAddon then
            local RD = CAF.GetAddon("Resource Distribution")
            if RD and RD.GetNetResourceAmount then
                return RD.GetNetResourceAmount(self.netid, "energy") or 0, RD.GetNetNetworkCapacity(self.netid, "energy") or 0
            end
        end
        -- any other part on a Spacebuild network: the same network totals the node shows
        if not self.IsNode and PowerGrid.RD3() then
            local RD = CAF.GetAddon("Resource Distribution")
            local t = RD and RD.GetEntityTable and RD.GetEntityTable(self)
            if t and t.network and t.network ~= 0 and RD.GetNetResourceAmount then
                return RD.GetNetResourceAmount(t.network, "energy") or 0, RD.GetNetNetworkCapacity(t.network, "energy") or 0
            end
        end
        return self:GetResource("energy"), self:GetNetworkCapacity("energy")
    end

    -- resource tanks: the resource follows the skin (0 oxygen .. 6 heavy water)
    local TANK_RES = { "oxygen", "water", "nitrogen", "hydrogen", "carbon dioxide", "steam", "heavy water" }
    ENT.TankResources = TANK_RES
    function ENT:SetTankResource(i)
        local old = self.TankRes
        if old and self.AGPRes and self.AGPRes[old] then self.AGPRes[old] = nil end
        self.TankIndex = i
        self.TankRes = TANK_RES[i]
        self:SetSkin(i - 1)
        self:AddResource(self.TankRes, self.AGPCapacity, 0)
        self:SetNWString("agp_tank_res", self.TankRes)
    end

    -- life support core: which area it keeps breathable
    -- the StarCore ship this part belongs to (looked up in StarCore's part lists, refreshed every 2 s)
    function ENT:LSShip()
        if (self.LSShipTime or 0) > CurTime() then return IsValid(self.LSShipCore) and self.LSShipCore or nil end
        self.LSShipTime, self.LSShipCore = CurTime() + 2, nil
        for core in pairs(StarCore and StarCore.Cores or {}) do
            if IsValid(core) and core.LocalMins and core.Parts then
                for _, e in ipairs(core.Parts) do if e == self then self.LSShipCore = core break end end
            end
            if self.LSShipCore then break end
        end
        return self.LSShipCore
    end
    function ENT:LSContains(pos)
        local core = self:LSShip()
        if core then
            local l = core:WorldToLocal(pos)
            local a, b = core.LocalMins, core.LocalMaxs
            return l.x >= a.x - 24 and l.x <= b.x + 24 and l.y >= a.y - 24 and l.y <= b.y + 24 and l.z >= a.z - 24 and l.z <= b.z + 120
        end
        return pos:DistToSqr(self:GetPos()) < self.Radius * self.Radius
    end
    function ENT:LSSetZone(on)
        if not (AGP and AGP.LS) then return end
        local zones = AGP.LS.Zones
        for i = #zones, 1, -1 do if zones[i].ent == self or not IsValid(zones[i].ent) then table.remove(zones, i) end end
        if on then
            local me = self
            zones[#zones + 1] = { ent = self, contains = function(pos) return me:LSContains(pos) end }
        end
        -- Spacebuild's life support running: the same area as a Spacebuild environment
        if AGP.LS.SBZone and (on or IsValid(self.AGPSBZone)) then
            AGP.LS.SBZone(self, on and AGP.LS.SpacebuildActive and AGP.LS.SpacebuildActive())
        end
        self:SetOn(on)
    end

    -- climate control of the life support core: the area takes on the outside temperature unless the core (120 K
    -- either way by itself) and the heaters / coolers inside it (S 100 K, M 200, L 400, XL 800: ENT.AGPClimReach)
    -- pull it to the target. A StarCore ship's hull insulates: it needs only 40 % of the difference, so a ship in
    -- space stays at 20 C on the core alone. A part pays ENT.AGPClimCost energy per second at full load.
    local CORE_REACH = 120
    local CLIMATE = {}
    for _, kind in ipairs({ "heater", "cooler" }) do
        for _, size in ipairs({ "_small", "", "_large", "_xl" }) do CLIMATE[#CLIMATE + 1] = "agp_ls_" .. kind .. size end
    end
    local function reach(e) return e.AGPClimReach or 200 end
    local function cost(e) return e.AGPClimCost or 800 end
    function ENT:LSClimate(active)
        local outside = AGP.LS.EnvAt(self:WorldSpaceCenter(), true).temp or 293
        self.LSOutside = outside
        if not active then self.LSZoneTemp = nil return end
        local ins = self:LSShip() and 0.4 or 1
        local need = ((self.TargetTemp or 293.15) - outside) * ins
        -- heaters / coolers in the area, switched on, with energy, not already working for another core this second
        local parts = { heater = {}, cooler = {} }
        for _, cls in ipairs(CLIMATE) do
            for _, e in ipairs(ents.FindByClass(cls)) do
                local free = e.AGPClimCore == self or (e.AGPClimTime or 0) < CurTime() - 1.5
                if free and e.AGPWantOn and self:LSContains(e:WorldSpaceCenter()) then
                    e.AGPClimCore, e.AGPClimTime, e.AGPClimLoad = self, CurTime(), 0
                    if e:GetResource("energy") >= cost(e) then table.insert(parts[e.AGPKind], e) end
                end
            end
        end
        local H, C = 0, 0
        for _, e in ipairs(parts.heater) do H = H + reach(e) end
        for _, e in ipairs(parts.cooler) do C = C + reach(e) end
        local shift = math.Clamp(need, -(CORE_REACH + C), CORE_REACH + H)
        -- what the parts have to add beyond the core: every part runs at the same load, each pays for its share
        local extra = math.abs(shift) - CORE_REACH
        local busy = shift > 0 and parts.heater or parts.cooler
        local total = shift > 0 and H or C
        if extra > 0 and total > 0 then
            local load = math.Clamp(extra / total, 0, 1)
            for _, e in ipairs(busy) do
                e.AGPClimLoad = load
                e:ConsumeResource("energy", math.ceil(cost(e) * load))
            end
        end
        local goal = outside + shift / ins
        self.LSZoneTemp = self.LSZoneTemp or outside   -- just switched on: it starts at the outside temperature
        self.LSZoneTemp = self.LSZoneTemp + (goal - self.LSZoneTemp) * 0.15
        if IsValid(self.AGPSBZone) and self.AGPSBZone.sbenvironment then
            self.AGPSBZone.sbenvironment.temperature = math.floor(self.LSZoneTemp)
        end
    end

    -- heater / cooler: what it does this second (the core sets the load), for its screen and Wire
    -- state: 0 off, 1 standby, 2 working, 3 outside a life support area, 4 no energy
    function ENT:ClimateState()
        local load = 0
        local state
        if not self.AGPWantOn then state = 0
        elseif (self.AGPClimTime or 0) < CurTime() - 1.5 or not IsValid(self.AGPClimCore) then state = 3
        elseif self:GetResource("energy") < cost(self) and (self.AGPClimLoad or 0) <= 0 then state = 4
        else
            load = math.floor((self.AGPClimLoad or 0) * 100 + 0.5)
            state = load > 0 and 2 or 1
        end
        self:SetOn(state == 2)
        self:SetNWInt("agp_clim_state", state)
        self:SetNWInt("agp_clim_load", load)
        if self.SetWire then self:SetWire("On", self.AGPWantOn and 1 or 0); self:SetWire("Working", load) end
    end

    -- the pump: E or Wire "On" opens / closes it
    function ENT:SetPumpOn(on)
        self:SetOn(on)
        self.AGPPumpOn = on
        if self.SetWire then self:SetWire("On", on and 1 or 0) end
        if AGP and AGP.Power then AGP.Power.Version = AGP.Power.Version + 1 end
        self:EmitSound(on and "buttons/button14.wav" or "buttons/button10.wav", 60)
    end
    function ENT:Use(p)
        local k = self.AGPKind
        if k == "pump" then self:SetPumpOn(self.AGPPumpOn == false)   -- by its real state, not the screen
        elseif k == "tank" then
            local r = self.AGPRes and self.AGPRes[self.TankRes]
            if r and r.amount > 0 then
                PowerGrid.Say(p, "agp_msg_tank_empty", "Empty the tank before you change what it holds.")
            else
                self:SetTankResource(self.TankIndex % #self.TankResources + 1)
                self:EmitSound("buttons/lever7.wav", 60)
            end
        elseif k == "lscore" then
            if self:LSShip() then
                self.AGPWantOn = not self.AGPWantOn
            else   -- bubble: E cycles the size, then off
                local sizes = { 300, 500, 800, 1200, 2000 }
                local nexti
                for i, r in ipairs(sizes) do if r == self.Radius then nexti = i + 1 end end
                if self.AGPWantOn and nexti and sizes[nexti] then self.Radius = sizes[nexti]
                elseif self.AGPWantOn then self.AGPWantOn = false
                else self.AGPWantOn = true; self.Radius = sizes[1] end
                if self.AGPWantOn then PowerGrid.Say(p, "agp_msg_ls_on", "Life support on, radius %d", self.Radius) else PowerGrid.Say(p, "agp_msg_ls_off", "Life support off") end
            end
            self:EmitSound("buttons/button9.wav", 60)
        elseif k == "heater" or k == "cooler" then
            self.AGPWantOn = not self.AGPWantOn
            self:ClimateState()
            self:EmitSound(self.AGPWantOn and "buttons/button14.wav" or "buttons/button10.wav", 60)
        elseif k == "compressor" then
            -- E switches what it collects: oxygen <-> nitrogen
            self:SetCompressorGas(self.AGPGas == "nitrogen" and "oxygen" or "nitrogen")
            if IsValid(p) and p:IsPlayer() then PowerGrid.Say(p, "agp_msg_comp_gas", "Now collects: %s", "agp_res_" .. self.AGPGas) end
            self:EmitSound("buttons/lever7.wav", 60)
        elseif k == "fusion" or k == "turbine" or k == "terraformer" or k == "plant" or k == "gravity" or k == "heavywater" or k == "fuelcell" then
            -- E switches the device on / off (the same as Wire "On"); a tripped reactor stays off until it has cooled
            self.AGPWantOn = not self.AGPWantOn
            self:EmitSound(self.AGPWantOn and "buttons/button14.wav" or "buttons/button10.wav", 60)
        elseif (k == "storage" or k == "display" or k == "node") and IsValid(p) and p:IsPlayer() then
            -- E: what this part holds and what its network holds
            local mine = self.AGPRes and self.AGPRes.energy
            PowerGrid.Say(p, "agp_msg_part_status", "%s: %s / %s energy - network: %s / %s", self.AGPNameKey or self.PrintName,
                short(mine and mine.amount or 0), short(mine and mine.max or 0), short(select(1, self:NetEnergy())), short(select(2, self:NetEnergy())))
            self:EmitSound("buttons/button14.wav", 55)
        elseif k == "dispenser" and IsValid(p) and AGP and AGP.LS then
            self:SetNWFloat("agp_arm", CurTime())   -- the refill arm swings out (client animation)
            if AGP.LS.Refill(p, self) then
                self:EmitSound("hl1/fvox/hiss.wav", 60, 110)
            else
                PowerGrid.Say(p, "agp_msg_disp_empty", "The dispenser has nothing to give: link it to oxygen, energy and water.")
                self:EmitSound("buttons/button10.wav", 60)
            end
        end
    end
    function ENT:TriggerInput(name, v)
        if self.AGPKind == "pump" and name == "On" then self:SetPumpOn(v ~= 0) end
        if self.AGPKind == "lscore" then
            if name == "On" then self.AGPWantOn = v ~= 0 end
            if name == "Radius" and v > 0 then self.Radius = math.Clamp(v, 100, 4000) end
            if name == "Temperature" then self.TargetTemp = math.Clamp(v, -60, 90) + 273.15 end
        end
        if (self.AGPKind == "heater" or self.AGPKind == "cooler") and name == "On" then
            self.AGPWantOn = v ~= 0
            self:ClimateState()
        end
        local k = self.AGPKind
        if (k == "fusion" or k == "turbine" or k == "terraformer" or k == "plant" or k == "gravity" or k == "heavywater" or k == "fuelcell") and name == "On" then self.AGPWantOn = v ~= 0 end
        if k == "compressor" and name == "Nitrogen" then self:SetCompressorGas(v ~= 0 and "nitrogen" or "oxygen") end
        if k == "terraformer" and name == "Strength" then self.AGPStrength = math.Clamp(v, 0, 4) end
        if k == "gravity" then
            if name == "Radius" and v > 0 then self.AGPRadius = math.Clamp(v, 50, 3000) end
            if name == "Gravity" then self.AGPGrav = math.Clamp(v, 0, 2) end
        end
    end

    -- AGP: a node linked anyone's part that touched it or stood on it, so a player could drain other players' ZPMs with
    -- a node. It takes only parts its owner may use: prop protection (CPPI) when there is one, else parts of the same
    -- owner; an admin's node any. CPPI, else the spawner (sandbox SetCreator / Ascension Gates' "Owner"). Where no owner
    -- is known on one side (single player, map parts) nothing is protected, as before.
    local function ownerOf(e)
        if e.CPPIGetOwner then
            local o = e:CPPIGetOwner()
            if IsValid(o) then return o end
        end
        local c = e.GetCreator and e:GetCreator()
        if IsValid(c) then return c end
        local o = e.Owner
        if IsValid(o) and o.IsPlayer and o:IsPlayer() then return o end
    end
    ENT.AGPOwnerOf = ownerOf
    function ENT:AGPMayLink(e)
        if game.SinglePlayer() then return true end
        local owner = ownerOf(self)
        if IsValid(owner) and owner.IsAdmin and owner:IsAdmin() then return true end
        if IsValid(owner) and e.CPPICanTool then return e:CPPICanTool(owner, "agp_power_link") == true end
        local other = ownerOf(e)
        if IsValid(owner) and IsValid(other) then return owner == other end
        return true
    end
    -- a pasted node belongs to whoever pasted it (the duplicator sets no owner; prop protection addons set their own)
    -- (code review): a copy carried the original's live links in its table - the Spacebuild air zone (the pasted core
    -- resized the ORIGINAL's air every second, the copy had none), the RD network id of a node (the copy's node fed the
    -- original's network), the gravity zone (a pasted regulator never made its own: no gravity). They are rebuilt by
    -- the part itself, so a copy leaves them behind
    local RUNTIME = { "AGPSBZone", "AGPZone", "netid", "LSShipCore", "LSShipTime", "AGPClimCore", "AGPClimTime",
        "AGPClimLoad", "AGPScoopPos", "AGPScoopT", "AGPNextShow", "AGPRDNode" }
    function ENT:OnEntityCopyTableFinish(data)
        for _, k in ipairs(RUNTIME) do data[k] = nil end
    end
    local bridgePaste = ENT.PostEntityPaste
    function ENT:PostEntityPaste(ply, ent, created)
        if self.AGPKind == "node" and IsValid(ply) and ply:IsPlayer() and not IsValid(self:GetCreator()) then self:SetCreator(ply) end
        -- Initialize made every pasted tank an oxygen tank (skin 0 and an empty oxygen store) before the copy's own
        -- resource came back: the right skin, and no stray oxygen store
        if self.AGPKind == "tank" and self.TankIndex and self.TankRes then
            self:SetSkin(self.TankIndex - 1)
            self:SetNWString("agp_tank_res", self.TankRes)
            if self.TankRes ~= "oxygen" and self.AGPRes and self.AGPRes.oxygen then self.AGPRes.oxygen = nil end
        end
        -- a pasted closed valve said "open" (Initialize switched the screen on)
        if self.AGPKind == "pump" then self:SetOn(self.AGPPumpOn ~= false) end
        -- (copying a full XL cell gave anyone billions of energy - "no"): a copy starts EMPTY. A saved game
        -- loads with its contents (gmsave pastes with DisablePropCreateEffect set). The copy gets its own tables
        -- first, so emptying it never empties the original it shared them with
        if not DisablePropCreateEffect and self.AGPRes and AGP and AGP.Power and AGP.Power.OwnTables then
            AGP.Power.OwnTables(self)
            for _, r in pairs(self.AGPRes) do if istable(r) then r.amount = 0 end end
        end
        if bridgePaste then return bridgePaste(self, ply, ent, created) end
    end

    -- a node links whatever is placed on it or touches it (ZPMs, generators, gates ...)
    function ENT:StartTouch(e)
        if self.AGPKind ~= "node" or not IsValid(e) then return end
        if e:IsPlayer() or e:IsWorld() then return end
        if not self:AGPMayLink(e) then return end   -- AGP: (see above)
        if self.IsNode and self.netid and CAF and CAF.GetAddon then   -- Spacebuild network: link it to this node
            local RD = CAF.GetAddon("Resource Distribution")
            if not RD or e.IsNode or e.AGPRDNode == self then return end
            if table.Count(RD.GetEntityTable(e) or {}) == 0 then return end
            RD.Link(e, self.netid)
            e.AGPRDNode = self
            self:EmitSound("buttons/button16.wav", 60, 110)
            return
        end
        if not (AGP and AGP.Power) then return end
        if AGP.Power.LinksUsed and not AGP.Power.LinksUsed() then return end   -- AGP: Automatic mode: links do nothing
        if not (e.AGPRes and next(e.AGPRes)) and not e.IsAGPPower then return end
        -- AGP: linked = both sides name each other (a pasted part may carry a one-sided copy of a link)
        if e.AGPLinks and e.AGPLinks[self] and self.AGPLinks and self.AGPLinks[e] then return end
        AGP.Power.Link(self, e)
        self:EmitSound("buttons/button16.wav", 60, 110)
    end

    -- a node also links everything that stands on its platform (parts spawn frozen, so they never "touch" it)
    function ENT:LinkOnTop()
        local mn, mx = self:WorldSpaceAABB()
        local top = self:LocalToWorld(Vector(0, 0, 4.6)).z
        for _, e in ipairs(ents.FindInBox(Vector(mn.x, mn.y, top - 3), Vector(mx.x, mx.y, top + 60))) do
            if e ~= self then self:StartTouch(e) end
        end
    end

    -- AGP: how much more of a resource this part's network can take (free energy: all of it). The compressor, water
    -- pump, splitter and ram scoop kept using energy / water while their output was full (the product was lost)
    function ENT:AGPRoom(res)
        if PowerGrid.Bridge and PowerGrid.Bridge.Free and PowerGrid.Bridge.Free() then return math.huge end
        return math.max(0, (self:GetNetworkCapacity(res) or 0) - (self:GetResource(res) or 0))
    end

    -- (nothing made nitrogen, the terraformer needs it): the compressor collects "oxygen" or "nitrogen". Nitrogen
    -- storage is added when nitrogen is chosen; back on oxygen, an empty nitrogen store leaves the part again
    function ENT:SetCompressorGas(gas)
        if self.AGPKind ~= "compressor" then return end
        gas = gas == "nitrogen" and "nitrogen" or "oxygen"
        self.AGPGas = gas
        local own = self.AGPRes and self.AGPRes.nitrogen
        if gas == "nitrogen" and not own then self:AddResource("nitrogen", self.AGPCapacity, 0)
        elseif gas == "oxygen" and own and own.amount <= 0 then self.AGPRes.nitrogen = nil end
        if AGP and AGP.Power and AGP.Power.Version then AGP.Power.Version = AGP.Power.Version + 1 end
    end

    -- generators: how much they make right now
    function ENT:Production()
        local up = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 4))
        if self.AGPKind == "solar" then
            local tr = util.TraceLine({ start = up, endpos = up + Vector(0, 0, 32000), filter = self, mask = MASK_SOLID })
            return tr.HitSky and self.AGPRate or 0
        elseif self.AGPKind == "wind" then
            -- free space around the top and height above the ground give wind
            local ground = util.TraceLine({ start = self:GetPos() + Vector(0, 0, 10), endpos = self:GetPos() - Vector(0, 0, 4000), filter = self, mask = MASK_SOLID_BRUSHONLY })
            local height = self:GetPos().z - ground.HitPos.z
            local open = 0
            for i = 0, 3 do
                local a = math.rad(i * 90)
                local tr = util.TraceLine({ start = up, endpos = up + Vector(math.cos(a), math.sin(a), 0) * 600, filter = self, mask = MASK_SOLID })
                open = open + tr.Fraction / 4
            end
            return math.floor(self.AGPRate * open * math.Clamp(0.6 + height / 1000, 0.6, 2))
        elseif self.AGPKind == "hydro" then
            -- how much of the body is under water (6 sample points up the model's axis); fully under: the deeper, the more
            -- (up to +50 % at 200 units under the surface). AGPForceSub is for tests (no water on the test map)
            local sub, depth = self:Submersion()
            self.AGPSubmerged = sub
            return math.floor(self.AGPRate * sub * (1 + 0.5 * math.Clamp(depth / 200, 0, 1)))
        end
        return 0
    end

    function ENT:Submersion()
        if self.AGPForceSub then return self.AGPForceSub, self.AGPForceDepth or 0 end
        local mn, mx = self:OBBMins(), self:OBBMaxs()
        local n, wet = 6, 0
        for i = 0, n - 1 do
            local p = self:LocalToWorld(Vector(0, 0, mn.z + (mx.z - mn.z) * (i + 0.5) / n))
            if bit.band(util.PointContents(p), CONTENTS_WATER) ~= 0 then wet = wet + 1 end
        end
        local depth = 0
        if wet == n then
            local top = self:LocalToWorld(Vector(0, 0, mx.z))
            for d = 25, 400, 25 do
                if bit.band(util.PointContents(top + Vector(0, 0, d)), CONTENTS_WATER) == 0 then break end
                depth = d
            end
        end
        return wet / n, depth
    end

    -- ======== the life support devices ============================================================= Numbers (per
    -- second; Spacebuild's devices were the reference for what they do, these are our own): fusion
    --   reactor 1 000 000 energy; 1 heavy water + 45 water (92 % become steam, 8 % come back as water); heat +14 per uncooled
    --                    second (-8 per cooled one), half output from 80 %, trips at 100 % until it is down to 40 % steam
    --   turbine up to 60 steam -> 1000 energy and 1 water each hydro
    --   generator 20 000 x submerged share (x up to 1.5 deep down) - in Production() above
    --   terraformer 120 000 energy x strength; 10 oxygen / 10 nitrogen a second from the network (x strength); the planet's air
    --                    changes 0.02 percent points of each gas a second (x strength), temperatures 0.5 K (x strength) towards 293 K
    --   hydroponics S 15, L 60 gas per second: 1 CO2 + 0.4 water + 600 energy -> 1 oxygen; temperature scales it
    --   gravity regulator 2000 x (radius / 500)^2 x (0.5 + 1.5 |g - 1|) energy
    local FUSION = { energy = 1000000, coolant = 45, fuel = 1, steam = 0.92, heatUp = 14, heatDown = 8, idle = 5, cold = 20, half = 80, trip = 100, reset = 40 }
    local TURBINE = { steam = 60, energy = 1000 }
    local TERRA = { energy = 120000, gas = 10, pct = 0.02, tempStep = 0.5, o2 = 21, n = 78, co2 = 1, comfort = 293, lo = 283, hi = 303 }
    local PLANT = { water = 0.4, energy = 600 }
    -- fuel cell: 2 hydrogen + 1 oxygen -> 2 water + 15 energy per water. The splitter pays 20 energy per water, so
    -- splitter + fuel cell in a circle always loses energy (no free energy)
    local FUELCELL = { energy = 15 }
    local HEAVYWATER = { water = 200, energy = 600000 }   -- per unit of heavy water (600 000 + 200 water, so a reactor nets ~400 000)
    ENT.FusionConst, ENT.TurbineConst, ENT.TerraConst, ENT.PlantConst, ENT.HeavyWaterConst = FUSION, TURBINE, TERRA, PLANT, HEAVYWATER

    -- what the environment API says about a place (AGP.LS.Probe); the older EnvAt answers what it can until that API lands
    function ENT:EnvProbe(pos)
        local ls = AGP and AGP.LS
        if not ls then return nil end
        if ls.Probe then
            local ok, r = pcall(ls.Probe, pos)
            if ok and r then return r end
        end
        local env = ls.EnvAt and ls.EnvAt(pos)
        if env then
            local air = env.breathable and true or false
            return { name = env.name or "", breathable = air, o2 = air and 21 or 0, co2 = 0, n = air and 78 or 0, h = 0, pressure = air and 1 or 0,
                temperature = env.temp or 293, gravity = env.gravity or 1, space = env.space and true or false, basic = true }
        end
    end

    local function state(self, st, out)
        self:SetNWInt("agp_st", st)
        self:SetNWFloat("agp_out", out or 0)
    end

    function ENT:ThinkFusion()
        local C = FUSION
        local heat = self.AGPHeat or C.cold
        local fuel = self:GetResource("heavy water") >= C.fuel
        -- (code review): it ran with room for 1 energy and burned a full heavy water for it; now it waits until its whole
        -- output fits (a busy base gets full value from every heavy water)
        local room = self:AGPRoom("energy") >= C.energy * (heat >= C.half and 0.5 or 1)
        local run = self.AGPWantOn and not self.AGPTripped and fuel and room
        local made, steam, st = 0, 0, 0
        if run then
            local take = self:ConsumeResource("water", math.min(C.coolant, self:GetResource("water")))
            local f = take / C.coolant
            self:ConsumeResource("heavy water", C.fuel)
            local s = math.floor(take * C.steam)
            steam = self:SupplyResource("steam", s) or s
            if take - s > 0 then self:SupplyResource("water", take - s) end   -- the 8 % that does not boil away
            made = self:SupplyResource("energy", C.energy * (heat >= C.half and 0.5 or 1)) or 0
            heat = heat + C.heatUp * (1 - f) - C.heatDown * f
            st = 1
        else
            heat = heat - C.idle
            st = (not self.AGPWantOn) and 0 or self.AGPTripped and 3 or (not fuel) and 2 or 4
        end
        heat = math.Clamp(heat, C.cold, C.trip)
        if heat >= C.trip and not self.AGPTripped then
            -- uncooled: the reactor shuts itself down (sparks, a bang) and stays off until it has cooled to 40 %
            self.AGPTripped = true
            self:EmitSound("ambient/energy/zap9.wav", 80)
            local fx = EffectData(); fx:SetOrigin(self:WorldSpaceCenter()); fx:SetMagnitude(3); fx:SetScale(2); fx:SetRadius(6)
            util.Effect("ElectricSpark", fx)
            st = 3
        elseif self.AGPTripped and heat <= C.reset then
            self.AGPTripped = false
        end
        self.AGPHeat = heat
        self:SetOn(made > 0)
        self:SetNWFloat("agp_heat", heat)
        state(self, st, made)
        if self.SetWire then
            self:SetWire("On", made > 0 and 1 or 0); self:SetWire("Energy per second", made); self:SetWire("Heat", math.Round(heat, 1))
            self:SetWire("Overheated", self.AGPTripped and 1 or 0); self:SetWire("Steam per second", steam)
        end
    end

    function ENT:ThinkTurbine()
        local C = TURBINE
        local steam = self:GetResource("steam")
        local use = 0
        if self.AGPWantOn then
            use = math.min(C.steam, math.floor(steam), math.floor(self:AGPRoom("energy") / C.energy))
        end
        local e, w = 0, 0
        if use >= 1 then
            self:ConsumeResource("steam", use)
            e = self:SupplyResource("energy", use * C.energy) or 0
            w = self:SupplyResource("water", use) or 0   -- condensed again
        end
        self:SetOn(use >= 1)
        state(self, not self.AGPWantOn and 0 or use >= 1 and 1 or steam < 1 and 2 or 3, e)
        if self.SetWire then
            self:SetWire("Producing", use >= 1 and 1 or 0); self:SetWire("Energy per second", e)
            self:SetWire("Steam per second", use); self:SetWire("Water per second", w)
        end
    end

    local function num(v) return string.format("%.4g", tonumber(v) or 0) end
    function ENT:ThinkProbe()
        local r = self:EnvProbe(self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 2))) or {}
        local c = (r.temperature or 273.15) - 273.15   -- Wire: degrees C, like the Life Support Core's outputs
        self:SetOn(true)
        self:SetNWString("agp_info", string.format("o2=%s;co2=%s;n=%s;h=%s;p=%s;t=%s;g=%s;b=%d;s=%d;nm=%s", num(r.o2), num(r.co2), num(r.n), num(r.h),
            num(r.pressure), num(c), num(r.gravity), r.breathable and 1 or 0, r.space and 1 or 0, string.sub(tostring(r.nameKey or r.name or ""), 1, 40)))
        if self.SetWire then
            self:SetWire("Oxygen", r.o2 or 0); self:SetWire("Carbon Dioxide", r.co2 or 0); self:SetWire("Nitrogen", r.n or 0)
            self:SetWire("Hydrogen", r.h or 0); self:SetWire("Pressure", r.pressure or 0); self:SetWire("Temperature", math.Round(c, 1))
            self:SetWire("Gravity", r.gravity or 0); self:SetWire("Breathable", r.breathable and 1 or 0)
            self:SetWire("In Space", r.space and 1 or 0); self:SetWire("Planet", tostring(r.name or ""))
        end
    end

    local function terraAllowed()
        local cv = GetConVar("agp_terraform_allowed")
        return not cv or cv:GetBool()
    end
    PowerGrid.TerraAllowed = terraAllowed

    function ENT:ThinkTerraformer()
        local C, ls = TERRA, AGP and AGP.LS
        local s = self.AGPStrength or 1
        local pos = self:GetPos()
        local planet = ls and ls.PlanetAt and ls.PlanetAt(pos)
        local r = self:EnvProbe(pos) or {}
        -- progress towards breathable air and a livable temperature (0..100): oxygen, nitrogen, carbon dioxide, temperature
        local pO2 = math.Clamp((r.o2 or 0) / C.o2, 0, 1)
        local pN = math.Clamp((r.n or 0) / C.n, 0, 1)
        local pC = 1 / (1 + math.max(0, (r.co2 or 0) - C.co2) / 20)
        local t = r.temperature or 293
        local pT = (t >= C.lo and t <= C.hi) and 1 or math.Clamp(1 - math.min(math.abs(t - C.lo), math.abs(t - C.hi)) / 60, 0, 1)
        self.AGPProgress = (pO2 + pN + pC + pT) / 4 * 100
        local unit = planet and planet.air and planet.air.max > 0 and planet.air.max / 100 or 0   -- planet air amount of one percent point
        local st, working = 1, false
        if not self.AGPWantOn or s <= 0 then st = 0
        elseif not terraAllowed() then st = 3
        elseif not (ls and ls.ChangeGas and ls.PlanetAt) or (ls.Mode and ls.Mode() == 0) then st = 6   -- (+ our LS off)
        elseif not planet then st = 4
        elseif unit <= 0 then st = 7
        elseif self.AGPProgress >= 99.5 and (planet.tLow or t) >= C.lo and (planet.tHigh or t) <= C.hi then st = 2
        else
            local cost = math.ceil(C.energy * s)
            if self:GetResource("energy") < cost then st = 5
            else
                self:ConsumeResource("energy", cost)
                working = true
                -- every second the planet's air changes by C.pct percent points (x strength) per gas; the gases come from the
                -- network (C.gas units a second, x strength - the planet is far too big for the real amounts to matter)
                local pp, use = C.pct * s * unit, C.gas * s
                local function give(gas, res)   -- network gas into the planet's air; what the air has no room for goes back
                    local take = self:ConsumeResource(res, use)
                    if take > 0 then
                        local want = pp * take / use
                        local moved = math.abs(ls.ChangeGas(planet, gas, want) or 0)
                        if moved < want then self:SupplyResource(res, take * (1 - moved / want)) end
                    end
                end
                -- room first: carbon dioxide out of the air into the network (what has no room is vented), hydrogen vented
                if (r.co2 or 0) > C.co2 then
                    local moved = math.abs(ls.ChangeGas(planet, "carbon dioxide", -pp) or 0)
                    if moved > 0 then self:SupplyResource("carbon dioxide", use * moved / pp) end
                end
                if (r.h or 0) > 0.5 then ls.ChangeGas(planet, "hydrogen", -pp) end
                -- (code review): too much oxygen was never taken out, so a full air of 25 % oxygen / 75 % nitrogen left no
                -- room for nitrogen and it worked (and paid) forever at 99 %; above 23 % it is vented now
                if (r.o2 or 0) > C.o2 + 2 then ls.ChangeGas(planet, "oxygen", -pp) end
                if (r.o2 or 0) < C.o2 then give("oxygen", "oxygen") end
                if (r.n or 0) < C.n then give("nitrogen", "nitrogen") end
                if ls.SetPlanetTemperature and planet.tLow and planet.tHigh then
                    local function step(v)
                        if v >= C.lo and v <= C.hi then return v end
                        return v + math.Clamp(C.comfort - v, -C.tempStep * s, C.tempStep * s)
                    end
                    local lo, hi = step(planet.tLow), step(planet.tHigh)
                    if lo ~= planet.tLow or hi ~= planet.tHigh then ls.SetPlanetTemperature(planet, lo, hi) end
                end
            end
        end
        self:SetOn(working)
        self:SetNWFloat("agp_progress", self.AGPProgress)
        self:SetNWString("agp_info", string.format("o2=%s;n=%s;co2=%s;t=%s", num(r.o2), num(r.n), num(r.co2), num(t - 273.15)))
        state(self, st, self.AGPProgress)
        if self.SetWire then
            self:SetWire("Working", working and 1 or 0); self:SetWire("Progress", math.Round(self.AGPProgress, 1))
            self:SetWire("Oxygen Progress", math.Round(pO2 * 100, 1)); self:SetWire("Temperature Progress", math.Round(pT * 100, 1))
        end
    end

    -- hydroponics: how well plants grow at a temperature (Kelvin)
    function ENT:PlantGrowth(t)
        if t < 278 or t > 318 then return 0 end
        if t < 283 or t > 308 then return 0.25 end
        if t < 288 or t > 303 then return 0.5 end
        return 1
    end

    function ENT:ThinkPlant()
        local C, ls = PLANT, AGP and AGP.LS
        local pos = self:WorldSpaceCenter()
        local env = ls and ls.EnvAt and ls.EnvAt(pos)
        local mul = self:PlantGrowth(env and env.temp or 293)
        local amount = self.AGPWantOn and math.floor(self.AGPRate * mul) or 0
        local st = (not self.AGPWantOn) and 0 or mul <= 0 and 5 or 1
        local netCO2, fromAir, total = 0, 0, 0
        if amount >= 1 then
            amount = math.min(amount, math.floor(self:AGPRoom("oxygen")))
            if amount < 1 then st = 6 end
            amount = math.min(amount, math.floor(self:GetResource("water") / C.water))
            if amount < 1 and st == 1 then st = 3 end
            amount = math.min(amount, math.floor(self:GetResource("energy") / C.energy))
            if amount < 1 and st == 1 then st = 4 end
            if amount >= 1 then
                netCO2 = math.min(amount, math.floor(self:GetResource("carbon dioxide")))
                local rest = amount - netCO2
                -- not enough carbon dioxide in the network: plants in the open air of a planet take it from the planet's air
                local planet = rest > 0 and ls and ls.PlanetAt and ls.ChangeGas and not (env and (env.zone or env.interior)) and ls.PlanetAt(pos)
                if planet then   -- (what the planet has no room for or no carbon dioxide left for is not converted)
                    fromAir = ls.ConvertGas and ls.ConvertGas(planet, "carbon dioxide", "oxygen", rest) or 0
                end
                total = netCO2 + fromAir
                if total >= 1 then
                    self:ConsumeResource("energy", C.energy * total)
                    self:ConsumeResource("water", math.ceil(C.water * total))
                    if netCO2 > 0 then
                        self:ConsumeResource("carbon dioxide", netCO2)
                        self:SupplyResource("oxygen", netCO2)
                    end
                else
                    st = 2
                end
            end
        end
        self:SetOn(total >= 1)
        self:SetNWFloat("agp_growth", mul)
        state(self, st, total)
        if self.SetWire then
            self:SetWire("Producing", total >= 1 and 1 or 0); self:SetWire("Oxygen per second", total); self:SetWire("Growth", math.Round(mul * 100))
        end
    end

    -- gravity regulator ---------------------------------------------------------------------------------------------
    function ENT:GravityCost()
        return math.floor(2000 * (self.AGPRadius / 500) ^ 2 * (0.5 + 1.5 * math.abs(self.AGPGrav - 1)) + 1e-6)
    end
    function ENT:GravityZone(on)
        local ls = AGP and AGP.LS
        if not ls then return false end
        if on then
            local z = self.AGPZone
            -- (bug hunt): the planets are read again after a map cleanup / a loaded save, which empties the zones - a
            -- regulator from the save kept its note and never made its zone again (running, paid for, no gravity)
            local kept = not ls.GravZones or ls.GravZones[self] ~= nil
            if ls.AddGravityZone and not (z and kept and z.r == self.AGPRadius and z.g == self.AGPGrav and z.api == ls.AddGravityZone) then
                ls.AddGravityZone(self, self.AGPRadius, self.AGPGrav)
                self.AGPZone = { r = self.AGPRadius, g = self.AGPGrav, api = ls.AddGravityZone }
            end
            return ls.AddGravityZone ~= nil
        elseif self.AGPZone then
            if ls.RemoveGravityZone then ls.RemoveGravityZone(self) end
            self.AGPZone = nil
        end
        return false
    end
    function ENT:ThinkGravity()
        local need = self:GravityCost()
        -- with PowerGrid's life support off (Spacebuild's runs) nothing reads the zone: no energy for nothing
        local lsOff = AGP and AGP.LS and AGP.LS.Mode and AGP.LS.Mode() == 0
        local on = self.AGPWantOn and not lsOff and self:GetResource("energy") >= need
        if on then self:ConsumeResource("energy", need) end
        local api = self:GravityZone(on)
        self:SetOn(on)
        self:SetNWFloat("agp_out", on and need or 0)
        self:SetNWFloat("agp_grav", self.AGPGrav)
        self:SetNWInt("agp_radius", self.AGPRadius)
        self:SetNWInt("agp_st", not self.AGPWantOn and 0 or lsOff and 3 or not on and 2 or api and 1 or 3)
        if self.SetWire then
            self:SetWire("Active", on and 1 or 0); self:SetWire("Radius", self.AGPRadius); self:SetWire("Gravity", self.AGPGrav)
            self:SetWire("Energy per second", on and need or 0)
        end
    end

    function ENT:Think()
        local k = self.AGPKind
        if k == "node" and (PowerGrid.Active or self.IsNode) then self:LinkOnTop() end
        if k == "cache" then
            for _, r in ipairs(self.AGPCacheRes or {}) do
                local have = (self.AGPRes and self.AGPRes[r]) and self.AGPRes[r].amount or self:GetResource(r)
                if have < self.AGPCapacity then self:SupplyResource(r, self.AGPCapacity - have) end
            end
            -- refill 10 times a second (the cache showed 500K and the node beside it 450K - the network had used
            -- 50K since the last refill a second before); screens and Wire still once a second
            if (self.AGPNextShow or 0) > CurTime() then self:NextThink(CurTime() + 0.1) return true end
            self.AGPNextShow = CurTime() + 1
        elseif k == "lscore" then
            -- runs on energy, breathes oxygen for everyone inside; low on oxygen: makes it from water
            local inside = 0
            for _, pl in ipairs(player.GetAll()) do if self:LSContains(pl:EyePos()) then inside = inside + 1 end end
            local energyNeed = 2000 + 500 * inside
            local o2Need = 5 * inside
            local o2 = self:GetResource("oxygen")
            if self.AGPWantOn and o2 < self.AGPCapacity * 0.5 and self:GetResource("water") >= 20 and self:GetResource("energy") >= 5000 then
                self:ConsumeResource("water", 20); self:ConsumeResource("energy", 5000)
                self:SupplyResource("oxygen", 40)
                o2 = o2 + 40
            end
            local ok = self.AGPWantOn and self:GetResource("energy") >= energyNeed and o2 >= o2Need
            if ok then
                self:ConsumeResource("energy", energyNeed)
                if o2Need > 0 then
                    self:ConsumeResource("oxygen", o2Need)
                    -- (the cycle must close): the oxygen breathed comes back as carbon dioxide, for the hydroponics
                    -- (Spacebuild's life support did the same); what the network has no room for is vented
                    self:SupplyResource("carbon dioxide", o2Need)
                end
            end
            self:LSSetZone(ok)
            self:LSClimate(ok)
            local K = 273.15
            self:SetNWFloat("agp_ls_temp", (self.LSZoneTemp or self.LSOutside or 293) - K)
            self:SetNWFloat("agp_ls_target", (self.TargetTemp or 293.15) - K)
            if self.SetWire then
                self:SetWire("Active", ok and 1 or 0); self:SetWire("Radius", self.Radius)
                self:SetWire("Ship", self:LSShip() and 1 or 0); self:SetWire("Oxygen", self:GetResource("oxygen"))
                self:SetWire("Carbon Dioxide", self:GetResource("carbon dioxide"))
                self:SetWire("Temperature", math.Round((self.LSZoneTemp or self.LSOutside or 293) - K, 1))
                self:SetWire("Target Temperature", math.Round((self.TargetTemp or 293.15) - K, 1))
                self:SetWire("Outside Temperature", math.Round((self.LSOutside or 293) - K, 1))
            end
        elseif k == "heater" or k == "cooler" then
            self:ClimateState()
        elseif k == "compressor" or k == "waterpump" then
            local env = AGP and AGP.LS and AGP.LS.EnvAt(self:WorldSpaceCenter())
            local can
            if k == "compressor" then can = env and env.breathable and not env.zone   -- any breathable air (not our own bubble)
            else   -- the intake pipe (left side, reaching down) or the pump itself in water
                can = bit.band(util.PointContents(self:LocalToWorld(Vector(0, -12, -22))), CONTENTS_WATER) ~= 0 or self:WaterLevel() > 0
            end
            local cost = k == "compressor" and 2000 or 1500
            local made = 0
            -- AGP: only as much as the network can still take, and energy only for that (nothing when full)
            local res = k == "compressor" and (self.AGPGas == "nitrogen" and "nitrogen" or "oxygen") or "water"
            local amount = math.min(self.AGPRate, math.floor(self:AGPRoom(res)))
            -- in the open air of a planet the compressor takes the oxygen out of that planet's air (like the plants take
            -- its carbon dioxide); no more than the air still has. Without a planet (a map's normal air) or inside a
            -- ship it compresses the air around it as before
            local ls, planet = AGP and AGP.LS, nil
            if k == "compressor" and can and ls and ls.PlanetAt and ls.ChangeGas and not env.interior then
                planet = ls.PlanetAt(self:WorldSpaceCenter())
                if planet and planet.air then amount = math.min(amount, math.floor(planet.air[res == "nitrogen" and "n" or "o2"] or 0)) end
            end
            if can and amount >= 1 and self:GetResource("energy") >= cost then
                self:ConsumeResource("energy", math.ceil(cost * amount / self.AGPRate))
                made = self:SupplyResource(res, amount) or amount
                if planet and made and made > 0 then ls.ChangeGas(planet, res, -made) end
            end
            self:SetOn(made and made > 0)
            if self.SetWire then self:SetWire("Producing", self:GetOn() and 1 or 0) end
        elseif k == "splitter" then
            -- electrolysis: every unit of water gives a unit of hydrogen and half a unit of oxygen
            local water = math.min(self.AGPRate, self:GetResource("water"))
            -- AGP: no more water than the products have room for: while one of them still fits it runs for that one
            -- (the other one's surplus is vented), with both full it stops and uses nothing
            water = math.floor(math.min(water, math.max(self:AGPRoom("hydrogen"), self:AGPRoom("oxygen") * 2)))
            local need = 20 * water
            local on = water >= 1 and self:GetResource("energy") >= need
            if on then
                self:ConsumeResource("water", water)
                self:ConsumeResource("energy", need)
                self:SupplyResource("hydrogen", water)
                self:SupplyResource("oxygen", math.floor(water / 2))
            end
            self:SetOn(on)
            if self.SetWire then self:SetWire("Producing", on and 1 or 0) end
        elseif k == "heavywater" then
            -- (a player: "how do you get heavy water?" - nothing made it): water + energy -> heavy water. 1 a second
            -- is what one fusion reactor burns; 600 000 energy for 1 that gives 1 000 000 in the reactor (200 000 netted 800 000 a
            -- second from water alone, 28 large solar panels)
            local C = HEAVYWATER
            local n = math.min(self.AGPRate, math.floor(self:AGPRoom("heavy water")))
            local on = self.AGPWantOn and n >= 1 and self:GetResource("water") >= C.water * n and self:GetResource("energy") >= C.energy * n
            if on then
                self:ConsumeResource("water", C.water * n)
                self:ConsumeResource("energy", C.energy * n)
                self:SupplyResource("heavy water", n)
            end
            self:SetOn(on)
            if self.SetWire then self:SetWire("Producing", on and 1 or 0); self:SetWire("Heavy Water per second", on and n or 0) end
        elseif k == "fuelcell" then
            -- 2 hydrogen + 1 oxygen -> 2 water + energy; only as much as the network has room for water
            local h = math.min(self.AGPRate, self:GetResource("hydrogen"), 2 * self:GetResource("oxygen"), self:AGPRoom("water"))
            h = math.floor(h / 2) * 2
            local on = self.AGPWantOn and h >= 2
            local e = 0
            if on then
                self:ConsumeResource("hydrogen", h)
                self:ConsumeResource("oxygen", h / 2)
                self:SupplyResource("water", h)
                e = self:SupplyResource("energy", FUELCELL.energy * h) or 0
            end
            self:SetOn(on)
            if self.SetWire then self:SetWire("Producing", on and 1 or 0); self:SetWire("Energy per second", e); self:SetWire("Water per second", on and h or 0) end
        elseif k == "ramscoop" then
            -- only in space; the magnetic field costs energy. A little hydrogen drifts in at rest, the rest comes with
            -- speed towards the mouth. The speed is the distance really travelled since the last check (a velocity read
            -- once a second missed most of the flight in the test; welded, parented or flown, all counts)
            local env = AGP and AGP.LS and AGP.LS.EnvAt(self:WorldSpaceCenter(), true)
            local pos, now = self:GetPos(), CurTime()
            local speed = 0
            if self.AGPScoopPos and now > self.AGPScoopT then
                speed = math.max(0, (pos - self.AGPScoopPos):Dot(self:GetForward()) / (now - self.AGPScoopT))
            end
            self.AGPScoopPos, self.AGPScoopT = pos, now
            local rate = 0
            -- AGP: the field stays off (no energy) while the network has no room for hydrogen
            local room = self:AGPRoom("hydrogen")
            if env and env.space and room >= 1 and self:GetResource("energy") >= 600 then
                rate = math.floor(math.min(self.AGPRate * (0.1 + math.min(speed, 3000) / 1000), room))
                self:ConsumeResource("energy", 600)
                self:SupplyResource("hydrogen", rate)
            end
            self:SetOn(rate > 0)
            self:SetNWFloat("agp_scoop_speed", math.min(speed, 3000))
            if self.SetWire then self:SetWire("Producing", rate > 0 and 1 or 0); self:SetWire("Hydrogen per second", rate) end
        elseif k == "solar" or k == "wind" or k == "hydro" then
            local rate = self:Production()
            if rate > 0 then self:SupplyResource("energy", rate) end
            self:SetOn(rate > 0)
            if k == "hydro" then
                self:SetNWFloat("agp_sub", self.AGPSubmerged or 0)
                self:SetNWFloat("agp_out", rate)
                if self.SetWire then self:SetWire("Submerged", math.Round((self.AGPSubmerged or 0) * 100)) end
            end
            if self.SetWire then self:SetWire("Producing", rate > 0 and 1 or 0); self:SetWire("Energy per second", rate) end
        elseif k == "fusion" then self:ThinkFusion()
        elseif k == "turbine" then self:ThinkTurbine()
        elseif k == "probe" then self:ThinkProbe()
        elseif k == "terraformer" then self:ThinkTerraformer()
        elseif k == "plant" then self:ThinkPlant()
        elseif k == "gravity" then self:ThinkGravity()
        end
        -- what the screens / tool show
        local parts, txt = 0, {}
        if PowerGrid.Active and AGP and AGP.Power then
            local sum, n = AGP.Power.Summary(self)
            parts = n
            -- (bug hunt, seen in a picture): by the alphabet alone every network with a Life Support Core showed carbon
            -- dioxide first - a cell's or node's one-line screen had no energy on it, and a cell glowed by the carbon
            -- dioxide. Now a tank shows its own resource first, everything else energy
            local first = k == "tank" and self.TankRes or "energy"
            local function add(res, v) txt[#txt + 1] = res .. "=" .. math.floor(v.amount) .. "/" .. math.floor(v.max) end
            if sum[first] then add(first, sum[first]) end
            for res, v in SortedPairs(sum) do if res ~= first then add(res, v) end end
        else
            local e, cap = self:NetEnergy()
            txt[#txt + 1] = "energy=" .. math.floor(e) .. "/" .. math.floor(cap)
        end
        self:SetSummary(parts .. "|" .. table.concat(txt, ";"))
        if self.SetWire and (k == "storage" or k == "display") then
            if k == "storage" then
                self:SetWire("Energy", self.AGPRes and self.AGPRes.energy and self.AGPRes.energy.amount or 0)
                self:SetWire("Max Energy", self.AGPCapacity)
            end
            local e, cap = self:NetEnergy()
            self:SetWire("Network Energy", e)
            self:SetWire("Network Max Energy", cap)
        end
        self:NextThink(CurTime() + (k == "cache" and 0.1 or 1))
        return true
    end

    function ENT:OnRemove()
        if self.AGPKind == "lscore" then self:LSSetZone(false) end
        if self.AGPKind == "gravity" then self:GravityZone(false) end
        if self.IsNode and CAF and CAF.GetAddon("Resource Distribution") then CAF.GetAddon("Resource Distribution").RemoveRDEntity(self) end
        if PowerGrid.Bridge then PowerGrid.Bridge.Remove(self) end
    end
end

if CLIENT then
    -- every part took its text apart twice a frame; the same text (all parts of a network) is read once now
    local parsed, parsedN = {}, 0
    local function parse(s)
        local c = parsed[s or ""]
        if c then return c.parts, c.list end
        local parts, rest = (s or ""):match("^(%d+)|(.*)$")
        local list = {}
        for res, a, m in (rest or ""):gmatch("([^=;]+)=(%d+)/(%d+)") do list[#list + 1] = { res = res, amount = tonumber(a), max = tonumber(m) } end
        if parsedN > 200 then parsed, parsedN = {}, 0 end
        parsed[s or ""], parsedN = { parts = tonumber(parts) or 0, list = list }, parsedN + 1
        return tonumber(parts) or 0, list
    end
    ENT.ParseSummary = parse

    surface.CreateFont("AGPPowerScreen", { font = "Roboto", size = 26, weight = 700 })
    surface.CreateFont("AGPPowerScreenSmall", { font = "Roboto", size = 20, weight = 500 })

    -- status / readings of the life support devices as { label, value, colour } lines (nil for the other parts)
    local function kv(str)
        local t = {}
        for key, val in (str or ""):gmatch("([%w]+)=([^;]*)") do t[key] = val end
        return t
    end
    local GREEN, GREY, ORANGE, RED, WHITE = Color(90, 220, 140), Color(170, 180, 190), Color(255, 170, 60), Color(255, 120, 80), Color(220, 230, 240)
    local function infoLines(self)
        local k = self.AGPKind
        local L = PowerGrid.L
        local st, out = self:GetNWInt("agp_st", 0), self:GetNWFloat("agp_out", 0)
        local function stat(names, ok)
            local t = names[st + 1] or "?"
            return { L("agp_pw_scr_status", "Status"), L(t[1], t[2]), (st == (ok or 1)) and GREEN or (st == 0 and GREY or ORANGE) }
        end
        local function T(key, def) return { key, def } end
        if k == "fusion" then
            local heat = self:GetNWFloat("agp_heat", 20)
            return { stat({ T("agp_pw_fu_0", "off"), T("agp_pw_fu_1", "running"), T("agp_pw_fu_2", "no heavy water"), T("agp_pw_fu_3", "overheated - cooling down"), T("agp_pw_fu_4", "energy storage full") }),
                { L("agp_pw_scr_output", "Energy per second"), short(out), WHITE },
                { L("agp_pw_scr_heat", "Heat"), string.format("%d %%", math.Round(heat)), heat >= 80 and RED or heat >= 50 and ORANGE or GREEN } }
        elseif k == "hydro" then
            local sub = self:GetNWFloat("agp_sub", 0)
            return { { L("agp_pw_scr_sub", "Submerged"), string.format("%d %%", math.Round(sub * 100)), sub > 0 and GREEN or ORANGE },
                { L("agp_pw_scr_output", "Energy per second"), short(self:GetNWFloat("agp_out", 0)), WHITE } }
        elseif k == "turbine" then
            return { stat({ T("agp_pw_fu_0", "off"), T("agp_pw_tu_1", "running"), T("agp_pw_tu_2", "no steam"), T("agp_pw_fu_4", "energy storage full") }),
                { L("agp_pw_scr_output", "Energy per second"), short(out), WHITE } }
        elseif k == "probe" then
            local v = kv(self:GetNWString("agp_info", ""))
            local c = tonumber(v.t) or 0
            local function temp(cc) return AGP.Units and AGP.Units.Temp and AGP.Units.Temp(cc) or string.format("%d C", math.Round(cc)) end
            return { { L("agp_pw_pr_place", "Place"), (v.nm and v.nm ~= "") and (AGP.LSPlaceName and AGP.LSPlaceName(v.nm) or v.nm) or "-", WHITE },
                { PowerGrid.ResName("oxygen"), (v.o2 or "0") .. " %", WHITE }, { PowerGrid.ResName("carbon dioxide"), (v.co2 or "0") .. " %", WHITE },
                { PowerGrid.ResName("nitrogen"), (v.n or "0") .. " %", WHITE }, { PowerGrid.ResName("hydrogen"), (v.h or "0") .. " %", WHITE },
                { L("agp_pw_pr_pressure", "Pressure"), v.p or "0", WHITE }, { L("agp_pw_pr_temp", "Temperature"), temp(c), WHITE },
                { L("agp_pw_pr_gravity", "Gravity"), (v.g or "0") .. " g", WHITE },
                { L("agp_pw_pr_air", "Air"), v.s == "1" and L("agp_pw_pr_space", "in space") or (v.b == "1" and L("agp_ls_hud_breathable", "breathable") or L("agp_ls_hud_noair", "no air")),
                    (v.b == "1") and GREEN or ORANGE } }
        elseif k == "terraformer" then
            return { stat({ T("agp_pw_fu_0", "off"), T("agp_pw_tf_1", "working"), T("agp_pw_tf_2", "done: the air is breathable"), T("agp_pw_tf_3", "switched off by the admin"),
                    T("agp_pw_tf_4", "not standing on a planet"), T("agp_pw_tf_5", "no energy"), T("agp_pw_tf_6", "no environment data"), T("agp_pw_tf_7", "this planet has no air to work with") }),
                { L("agp_pw_scr_progress", "Progress"), string.format("%d %%", math.Round(self:GetNWFloat("agp_progress", 0))), WHITE } }
        elseif k == "plant" then
            local g = self:GetNWFloat("agp_growth", 0)
            return { stat({ T("agp_pw_fu_0", "off"), T("agp_pw_pl_1", "growing"), T("agp_pw_pl_2", "no carbon dioxide"), T("agp_pw_pl_3", "no water"), T("agp_pw_pl_4", "no energy"),
                    T("agp_pw_pl_5", "too hot or too cold"), T("agp_pw_pl_6", "oxygen storage full") }),
                { L("agp_pw_scr_o2", "Oxygen per second"), short(out), WHITE },
                { L("agp_pw_scr_growth", "Growth"), string.format("%d %%", math.Round(g * 100)), g >= 1 and GREEN or ORANGE } }
        elseif k == "gravity" then
            return { stat({ T("agp_pw_fu_0", "off"), T("agp_pw_gr_1", "active"), T("agp_pw_fu_5", "no energy"), T("agp_pw_gr_3", "no environment data") }),
                { L("agp_pw_gr_set", "Gravity"), string.format("%.2f g", self:GetNWFloat("agp_grav", 1)), WHITE },
                { L("agp_pw_gr_radius", "Radius"), tostring(self:GetNWInt("agp_radius", 0)), WHITE },
                { L("agp_pw_scr_use", "Energy use per second"), short(out), WHITE } }
        end
    end

    -- the panel: title, parts, one bar per resource (as many as fit into h)
    local function panel(self, w, h, rounded)
        local parts, list = parse(self:GetSummary())
        local x, y = -w / 2, -h / 2
        draw.RoundedBox(rounded and 10 or 0, x, y, w, h, Color(6, 14, 26, 240))
        draw.RoundedBox(0, x, y, w, 34, Color(30, 70, 120, 255))
        draw.SimpleText(PowerGrid.L(self.AGPNameKey or "", self.PrintName), "AGPPowerScreen", x + 12, y + 3, Color(255, 255, 255))
        draw.SimpleText(parts > 0 and (parts == 1 and PowerGrid.L("agp_pw_scr_part", "%d part", parts) or PowerGrid.L("agp_pw_scr_parts", "%d parts", parts)) or "", "AGPPowerScreenSmall", x + w - 12, y + 7, Color(170, 200, 230), TEXT_ALIGN_RIGHT)
        local function temp(c) return AGP.Units and AGP.Units.Temp and AGP.Units.Temp(c) or string.format("%d C", math.Round(c)) end
        if self.AGPKind == "lscore" then
            local txt = self:GetOn() and PowerGrid.L("agp_pw_scr_lson", "breathable area active") or PowerGrid.L("agp_pw_scr_lsoff", "off / no energy or oxygen")
            local col = self:GetOn() and Color(90, 220, 140) or Color(255, 120, 80)
            if self:GetOn() then
                -- the area's temperature; blue / orange while it is uncomfortable (the suit has to heat / cool)
                local c = self:GetNWFloat("agp_ls_temp", 20)
                txt = txt .. "  ·  " .. temp(c)
                if c < -10 then col = Color(120, 190, 255) elseif c > 37 then col = Color(255, 160, 80) end
            end
            draw.SimpleText(txt, "AGPPowerScreenSmall", 0, y + 50, col, TEXT_ALIGN_CENTER)
            y, h = y + 30, h - 30   -- the status line takes the room of one bar (Draw made the screen taller)
        end
        if self.AGPKind == "heater" or self.AGPKind == "cooler" then
            local st, load = self:GetNWInt("agp_clim_state", 0), self:GetNWInt("agp_clim_load", 0)
            local txt, col
            if st == 0 then txt, col = PowerGrid.L("agp_pw_scr_clim_off", "off"), Color(170, 180, 190)
            elseif st == 1 then txt, col = PowerGrid.L("agp_pw_scr_clim_standby", "standby"), Color(90, 220, 140)
            elseif st == 2 then
                txt = self.AGPKind == "heater" and PowerGrid.L("agp_pw_scr_clim_heat", "heating %d %%", load) or PowerGrid.L("agp_pw_scr_clim_cool", "cooling %d %%", load)
                col = self.AGPKind == "heater" and Color(255, 160, 80) or Color(120, 190, 255)
            elseif st == 3 then txt, col = PowerGrid.L("agp_pw_scr_clim_nozone", "outside a life support area"), Color(255, 170, 60)
            else txt, col = PowerGrid.L("agp_pw_scr_clim_noenergy", "no energy"), Color(255, 120, 80) end
            draw.SimpleText(txt, "AGPPowerScreenSmall", 0, y + 50, col, TEXT_ALIGN_CENTER)
            y, h = y + 30, h - 30   -- the status line takes the room of one bar (Draw made the screen taller)
        end
        local info = infoLines(self)
        if info then
            -- the life support devices: status / readings as lines (label left, value right)
            for i, it in ipairs(info) do
                local ly = y + 40 + (i - 1) * 24
                draw.SimpleText(it[1], "AGPPowerScreenSmall", x + 12, ly, Color(170, 190, 215))
                draw.SimpleText(it[2], "AGPPowerScreenSmall", x + w - 12, ly, it[3] or Color(220, 230, 240), TEXT_ALIGN_RIGHT)
            end
            y, h = y + #info * 24, h - #info * 24
        end
        if self.AGPKind == "pump" then
            draw.SimpleText(self:GetOn() and PowerGrid.L("agp_pw_scr_open", "open") or PowerGrid.L("agp_pw_scr_closed", "closed"), "AGPPowerScreen", 0, y + h / 2 + 12, self:GetOn() and Color(90, 200, 255) or Color(255, 120, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end
        if #list == 0 and self.AGPKind == "probe" then return end   -- the probe holds no resources
        if #list == 0 then
            draw.SimpleText(PowerGrid.L("agp_pw_scr_notconn", "not connected"), "AGPPowerScreenSmall", x + 12, y + 44, Color(255, 170, 60))
            return
        end
        local fit = math.max(1, math.floor((h - 44) / 30))
        for i = 1, math.min(#list, fit) do
            local it = list[i]
            local ly = y + 40 + (i - 1) * 30
            local frac = it.max > 0 and math.Clamp(it.amount / it.max, 0, 1) or 0
            draw.RoundedBox(3, x + 12, ly + 21, w - 24, 6, Color(40, 50, 65))
            draw.RoundedBox(3, x + 12, ly + 21, (w - 24) * frac, 6, it.res == "energy" and Color(80, 170, 255) or Color(255, 170, 60))
            draw.SimpleText(PowerGrid.ResName(it.res), "AGPPowerScreenSmall", x + 12, ly, Color(220, 230, 240))
            draw.SimpleText(short(it.amount) .. " / " .. short(it.max), "AGPPowerScreenSmall", x + w - 12, ly, Color(220, 230, 240), TEXT_ALIGN_RIGHT)
        end
    end
    ENT.DrawPanel = panel
    -- (bug hunt, seen in a picture): a floating screen was drawn together with its part, so parts and screens BEHIND it
    -- that were drawn later covered it. The screens are drawn after all parts now, the far ones first
    local screens = {}
    hook.Add("PostDrawTranslucentRenderables", "AGP.Power.Screens", function(depth, sky)
        if depth or sky or not next(screens) then return end
        local list, eye = {}, EyePos()
        for e, s in pairs(screens) do
            if IsValid(e) then s.e, s.d = e, s.pos:DistToSqr(eye) list[#list + 1] = s end
        end
        screens = {}
        table.sort(list, function(a, b) return a.d > b.d end)
        for _, s in ipairs(list) do
            cam.Start3D2D(s.pos, s.ang, s.scale)
                panel(s.e, s.w, s.h, true)
            cam.End3D2D()
        end
    end)
    function ENT:OnRemove()
        if AGP and AGP.PowerAnimStop then AGP.PowerAnimStop(self) end
    end

    function ENT:Draw()
        if AGP and AGP.PowerAnim then AGP.PowerAnim(self) end   -- moving parts, sounds, particles (agp_power_anim.lua)
        self:DrawModel()
        if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 1500 * 1500 then return end
        local sf = self.AGPSurface
        if sf then
            -- the screen of the model itself: faces the model's front (+X), tilted back by sf.tilt degrees
            local a = self:GetAngles()
            a:RotateAroundAxis(a:Up(), 90)
            a:RotateAroundAxis(a:Forward(), 90 - (sf.tilt or 0))
            local W = 400
            local scale = sf.w / W
            cam.Start3D2D(self:LocalToWorld(sf.pos), a, scale)
                panel(self, W, sf.h / scale, false)
            cam.End3D2D()
            return
        end
        local sc = self.AGPScreen
        if not sc then return end
        local _, list = parse(self:GetSummary())
        local w = sc.w or 400
        local h = 48 + math.max(1, math.min(#list, sc.lines or 8)) * 30
        if self.AGPKind == "lscore" or self.AGPKind == "heater" or self.AGPKind == "cooler" then h = h + 30 end   -- status line
        local info = infoLines(self)
        if info then h = h + #info * 24 end
        if self.AGPKind == "probe" then h = 52 + #info * 24 end   -- no bars at all
        local pos = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + (sc.up or 12) + h * (sc.scale or 0.05) / 2))
        local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
        screens[self] = { pos = pos, ang = ang, scale = sc.scale or 0.05, w = w, h = h }
    end
end
