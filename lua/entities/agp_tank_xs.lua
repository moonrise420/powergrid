-- PowerGrid: Resource Tank (XS) (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_tank_xs"
ENT.PrintName = PowerGrid.L("agp_ent_tank_xs", "Resource Tank (XS)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "tank"
ENT.AGPModel = "models/agp_power/agp_tank_xs.mdl"
ENT.AGPCapacity = 2000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 4, scale = 0.05, w = 340, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
