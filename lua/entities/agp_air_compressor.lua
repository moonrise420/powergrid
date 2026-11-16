-- PowerGrid: Air Compressor (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_air_compressor"
ENT.PrintName = PowerGrid.L("agp_ent_air_compressor", "Air Compressor")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "compressor"
ENT.AGPModel = "models/agp_power/agp_air_compressor.mdl"
ENT.AGPCapacity = 2000
ENT.AGPRate = 50
ENT.AGPScreen = { up = 6, scale = 0.08, w = 380, lines = 2 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
