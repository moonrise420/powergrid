-- PowerGrid: Solar Panel (S) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_solar_small"
ENT.PrintName = PowerGrid.L("agp_ent_solar_small", "Solar Panel (S)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "solar"
ENT.AGPModel = "models/agp_power/agp_solar_small.mdl"
ENT.AGPCapacity = 50000
ENT.AGPRate = 4000
ENT.AGPScreen = { up = 4, scale = 0.06, w = 360, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
