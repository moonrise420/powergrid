-- PowerGrid: Hydroponics (L) (see agp_power_base.lua, kind "plant")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_hydroponics_large"
ENT.PrintName = PowerGrid.L("agp_ent_hydroponics_large", "Hydroponics (L)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "plant"
ENT.AGPModel = "models/agp_power/agp_hydroponics_large.mdl"
ENT.AGPCapacity = 12000
ENT.AGPRate = 60
ENT.AGPScreen = { up = 6, scale = 0.1, w = 400, lines = 4 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
