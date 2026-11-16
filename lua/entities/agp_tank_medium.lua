-- PowerGrid: Resource Tank (M) (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_tank_medium"
ENT.PrintName = PowerGrid.L("agp_ent_tank_medium", "Resource Tank (M)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "tank"
ENT.AGPModel = "models/agp_power/agp_tank_medium.mdl"
ENT.AGPCapacity = 50000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 6, scale = 0.1, w = 380, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
