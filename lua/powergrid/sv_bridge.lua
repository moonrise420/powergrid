-- PowerGrid: what every part uses to hold and move resources, and its Wire in/outputs.
--   PowerGrid.SetupEntity(ENT) gives an entity class AddResource, GetResource, ConsumeResource, SupplyResource,
--   GetUnitCapacity, GetNetworkCapacity (PowerGrid's network, or Spacebuild's Resource Distribution when that carries
--   the energy), CreateWireInputs/-Outputs, SetWire, GetWire, and keeps links and wires in dupes.
-- Other addons can use it for their own entities.
local B = {}
PowerGrid.Bridge = B

local function net() return PowerGrid.Active and AGP.Power end

-- AGP: "Off (free energy)" (agp_power_mode 0, or no network at all: neither ours nor Spacebuild's carries the
-- resources - what the settings page shows as "Off: free energy.") gave every part 0 of everything, so the Life
-- Support Core never came on, heaters / coolers said "no energy" and the compressor, water pump, splitter and suit
-- dispenser did nothing. Free means: every part has as much as it asks for, and whatever it makes is taken.
-- (Ascension Gates' entities are free then by themselves: without a network their energy checks are skipped.)
local FREE = 1e9   -- what a part sees of every resource (the screens show it as a full bar)
local function free() return not PowerGrid.Active and not PowerGrid.RD3() end
B.Free = free

function B.AddResource(self, res, max, default)
	local P = net()
	if P then return P.AddResource(self, res, max, default) end
	local RD = PowerGrid.RD3()
	if RD then return RD.AddResource(self, res, max or 0, default or 0) end
end

function B.GetResource(self, res, default)
	local P = net()
	if P then return P.GetResource(self, res, default) end
	local RD = PowerGrid.RD3()
	if RD then return RD.GetResourceAmount(self, res) or default or 0 end
	if free() then return FREE end   -- AGP
	return default or 0
end

function B.ConsumeResource(self, res, amount)
	local P = net()
	if P then return P.ConsumeResource(self, res, amount) end
	local RD = PowerGrid.RD3()
	if RD then
		local have = RD.GetResourceAmount(self, res) or 0
		local take = math.min(have, math.max(0, amount or 0))
		if take > 0 then RD.ConsumeResource(self, res, take) end
		return take
	end
	if free() then return math.max(0, amount or 0) end   -- AGP: all of it
	return 0
end

function B.SupplyResource(self, res, amount)
	local P = net()
	if P then return P.SupplyResource(self, res, amount) end
	local RD = PowerGrid.RD3()
	if RD then
		local room = (RD.GetNetworkCapacity(self, res) or 0) - (RD.GetResourceAmount(self, res) or 0)
		local give = math.min(math.max(0, room), math.max(0, amount or 0))
		if give > 0 then RD.SupplyResource(self, res, give) end
		return give
	end
	if free() then return math.max(0, amount or 0) end   -- AGP: all of it is taken
	return 0
end

function B.GetUnitCapacity(self, res, default)
	local P = net()
	if P then return P.GetUnitCapacity(self, res, default) end
	local RD = PowerGrid.RD3()
	if RD then return RD.GetUnitCapacity(self, res) or default or 0 end
	return default or 0
end

function B.GetNetworkCapacity(self, res, default)
	local P = net()
	if P then return P.GetNetworkCapacity(self, res, default) end
	local RD = PowerGrid.RD3()
	if RD then return RD.GetNetworkCapacity(self, res) or default or 0 end
	if free() then return FREE end   -- AGP: (a full bar on the screens)
	return default or 0
end

-- Wire ----------------------------------------------------------------------------------------------------------
function B.CreateWireInputs(self, ...)
	if WireLib then self.Inputs = WireLib.CreateInputs(self, { ... }) end
end

function B.CreateWireOutputs(self, ...)
	if WireLib then self.Outputs = WireLib.CreateOutputs(self, { ... }) end
end

function B.SetWire(self, key, value)
	if not (WireLib and self.Outputs and self.Outputs[key]) then return end
	if isbool(value) then value = value and 1 or 0 end
	WireLib.TriggerOutput(self, key, value)
end

function B.GetWire(self, key, default)
	local i = self.Inputs and self.Inputs[key]
	if i and i.Value ~= nil then return i.Value end
	return default or 0
end

-- removed: out of the network, Wire and Resource Distribution forget it
function B.Remove(self)
	if AGP.Power and AGP.Power.Remove then AGP.Power.Remove(self) end
	local RD = PowerGrid.RD3()
	if RD and RD.RemoveRDEntity then RD.RemoveRDEntity(self) end
	if WireLib and WireLib.Remove then WireLib.Remove(self) end
end

-- dupes: Wire connections and Resource Distribution links (PowerGrid's own links: sv_network.lua)
function B.PreEntityCopy(self)
	if WireLib and WireLib.BuildDupeInfo then
		local info = WireLib.BuildDupeInfo(self)
		if info then duplicator.StoreEntityModifier(self, "WireDupeInfo", info) end
	end
	local RD = PowerGrid.RD3()
	if RD and RD.BuildDupeInfo then RD.BuildDupeInfo(self) end
	-- AGP: our own links, as they are right now
	if net() and AGP.Power.StoreLinks then AGP.Power.StoreLinks(self) end
end

function B.PostEntityPaste(self, ply, ent, created)
	if WireLib and WireLib.ApplyDupeInfo and ent.EntityMods and ent.EntityMods.WireDupeInfo then
		WireLib.ApplyDupeInfo(ply, ent, ent.EntityMods.WireDupeInfo, function(id) return created[id] end)
	end
	local RD = PowerGrid.RD3()
	if RD and RD.ApplyDupeInfo then RD.ApplyDupeInfo(ent, created) end
	-- AGP: the paste's old index -> new entity list, so our links join exactly the new parts
	if net() and AGP.Power.DupePasted then AGP.Power.DupePasted(created) end
end

function PowerGrid.SetupEntity(ENT)
	for _, k in ipairs({ "AddResource", "GetResource", "ConsumeResource", "SupplyResource", "GetUnitCapacity", "GetNetworkCapacity",
		"CreateWireInputs", "CreateWireOutputs", "SetWire", "GetWire", "PreEntityCopy", "PostEntityPaste" }) do
		ENT[k] = B[k]
	end
end
