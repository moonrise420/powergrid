-- PowerGrid: Power Valve (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_power_pump"
ENT.PrintName = PowerGrid.L("agp_ent_power_pump", "Power Valve")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "pump"
ENT.AGPModel = "models/agp_power/agp_pump.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPScreen = { up = 4, scale = 0.05, w = 300, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
