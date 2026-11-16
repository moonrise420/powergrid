-- PowerGrid: Solar Panel (L) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_solar_large"
ENT.PrintName = PowerGrid.L("agp_ent_solar_large", "Solar Panel (L)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "solar"
ENT.AGPModel = "models/agp_power/agp_solar_large.mdl"
ENT.AGPCapacity = 300000
ENT.AGPRate = 30000
ENT.AGPScreen = { up = 6, scale = 0.1, w = 380, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
