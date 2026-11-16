-- PowerGrid: Fusion Reactor (see agp_power_base.lua, kind "fusion")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_fusion_reactor"
ENT.PrintName = PowerGrid.L("agp_ent_fusion_reactor", "Fusion Reactor")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "fusion"
ENT.AGPModel = "models/agp_power/agp_fusion_reactor.mdl"
ENT.AGPCapacity = 3000000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 8, scale = 0.09, w = 400, lines = 3 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
