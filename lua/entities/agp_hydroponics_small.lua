-- PowerGrid: Hydroponics (S) (see agp_power_base.lua, kind "plant")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_hydroponics_small"
ENT.PrintName = PowerGrid.L("agp_ent_hydroponics_small", "Hydroponics (S)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "plant"
ENT.AGPModel = "models/agp_power/agp_hydroponics_small.mdl"
ENT.AGPCapacity = 3000
ENT.AGPRate = 15
ENT.AGPScreen = { up = 6, scale = 0.07, w = 360, lines = 4 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
