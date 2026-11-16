-- PowerGrid: Life Support Heater (S) (Grid Power / climate control, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_ls_heater_small"
ENT.PrintName = PowerGrid.L("agp_ent_ls_heater_small", "Life Support Heater (S)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "heater"
ENT.AGPModel = "models/agp_power/agp_ls_heater_small.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPClimReach = 100     -- degrees it can move the life support area's temperature
ENT.AGPClimCost = 400     -- energy per second at full load
ENT.AGPScreen = { up = 6, scale = 0.07, w = 380, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
