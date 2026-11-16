-- PowerGrid: Resource Tank (S) (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_tank_small"
ENT.PrintName = PowerGrid.L("agp_ent_tank_small", "Resource Tank (S)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "tank"
ENT.AGPModel = "models/agp_power/agp_tank_small.mdl"
ENT.AGPCapacity = 10000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 5, scale = 0.07, w = 360, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
