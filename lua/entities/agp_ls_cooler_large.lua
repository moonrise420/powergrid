-- PowerGrid: Life Support Cooler (L) (Grid Power / climate control, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_ls_cooler_large"
ENT.PrintName = PowerGrid.L("agp_ent_ls_cooler_large", "Life Support Cooler (L)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "cooler"
ENT.AGPModel = "models/agp_power/agp_ls_cooler_large.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPClimReach = 400     -- degrees it can move the life support area's temperature
ENT.AGPClimCost = 1600     -- energy per second at full load
ENT.AGPScreen = { up = 6, scale = 0.1, w = 380, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
