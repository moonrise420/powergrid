-- PowerGrid: Gravity Regulator (see agp_power_base.lua, kind "gravity")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_gravity_regulator"
ENT.PrintName = PowerGrid.L("agp_ent_gravity_regulator", "Gravity Regulator")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "gravity"
ENT.AGPModel = "models/agp_power/agp_gravity_regulator.mdl"
ENT.AGPCapacity = 100000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 6, scale = 0.07, w = 360, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
