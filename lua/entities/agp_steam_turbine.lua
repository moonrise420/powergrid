-- PowerGrid: Steam Turbine (see agp_power_base.lua, kind "turbine")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_steam_turbine"
ENT.PrintName = PowerGrid.L("agp_ent_steam_turbine", "Steam Turbine")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "turbine"
ENT.AGPModel = "models/agp_power/agp_steam_turbine.mdl"
ENT.AGPCapacity = 300000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 6, scale = 0.07, w = 360, lines = 3 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
