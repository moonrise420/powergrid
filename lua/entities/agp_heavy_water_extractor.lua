-- PowerGrid: Heavy Water Extractor (see agp_power_base.lua, kind "heavywater"): water + energy -> heavy water, the fuel of
-- the Fusion Reactor.: own model (centrifuge bone "rotor")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_heavy_water_extractor"
ENT.PrintName = PowerGrid.L("agp_ent_heavy_water_extractor", "Heavy Water Extractor")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = not (PowerGrid.UnfinishedDevices and PowerGrid.UnfinishedDevices.agp_heavy_water_extractor)   -- hidden until released (sh_config.lua)
ENT.AGPKind = "heavywater"
ENT.AGPModel = "models/agp_power/agp_heavy_water_extractor.mdl"
ENT.AGPCapacity = 3000
ENT.AGPRate = 1
ENT.AGPScreen = { up = 6, scale = 0.08, w = 380, lines = 3 }
if ENT.Spawnable then list.Set("CAP.Entity", ENT.PrintName, ENT) end
if SERVER then AddCSLuaFile() end
