-- PowerGrid: Resource Tank (L) (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_tank_large"
ENT.PrintName = PowerGrid.L("agp_ent_tank_large", "Resource Tank (L)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "tank"
ENT.AGPModel = "models/agp_power/agp_tank_large.mdl"
ENT.AGPCapacity = 250000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 8, scale = 0.14, w = 400, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
