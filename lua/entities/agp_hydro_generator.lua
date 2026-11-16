-- PowerGrid: Hydro Generator (see agp_power_base.lua, kind "hydro")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_hydro_generator"
ENT.PrintName = PowerGrid.L("agp_ent_hydro_generator", "Hydro Generator")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "hydro"
ENT.AGPModel = "models/agp_power/agp_hydro_generator.mdl"
ENT.AGPCapacity = 300000
ENT.AGPRate = 20000
ENT.AGPScreen = { up = 6, scale = 0.07, w = 360, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
