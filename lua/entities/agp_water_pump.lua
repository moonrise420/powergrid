-- PowerGrid: Water Pump (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_water_pump"
ENT.PrintName = PowerGrid.L("agp_ent_water_pump", "Water Pump")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "waterpump"
ENT.AGPModel = "models/agp_power/agp_water_pump.mdl"
ENT.AGPCapacity = 3000
ENT.AGPRate = 80
ENT.AGPScreen = { up = 6, scale = 0.08, w = 380, lines = 2 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
