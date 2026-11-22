-- PowerGrid: Fuel Cell (see agp_power_base.lua, kind "fuelcell"): hydrogen + oxygen -> water + a little energy, the
-- Water Splitter backwards. (hydrogen had no use, space had no water): with the Ram Scoop's hydrogen a ship in space
-- makes its own water. Model
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_fuel_cell"
ENT.PrintName = PowerGrid.L("agp_ent_fuel_cell", "Fuel Cell")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = not (PowerGrid.UnfinishedDevices and PowerGrid.UnfinishedDevices.agp_fuel_cell)   -- hidden until released (sh_config.lua)
ENT.AGPKind = "fuelcell"
ENT.AGPModel = "models/agp_power/agp_fuel_cell.mdl"
ENT.AGPCapacity = 3000       -- its own water store (and 50 000 energy, see Initialize)
ENT.AGPRate = 60             -- hydrogen a second at most
ENT.AGPScreen = { up = 6, scale = 0.08, w = 380, lines = 3 }
if ENT.Spawnable then list.Set("CAP.Entity", ENT.PrintName, ENT) end
if SERVER then AddCSLuaFile() end
