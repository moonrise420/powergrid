-- PowerGrid: Resource Tank (XL) (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_tank_xl"
ENT.PrintName = PowerGrid.L("agp_ent_tank_xl", "Resource Tank (XL)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "tank"
ENT.AGPModel = "models/agp_power/agp_tank_xl.mdl"
ENT.AGPCapacity = 2000000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 12, scale = 0.24, w = 420, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
