-- PowerGrid: Power Display (L) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_display_large"
ENT.PrintName = PowerGrid.L("agp_ent_display_large", "Power Display (L)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "display"
ENT.AGPModel = "models/agp_power/agp_display_large.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPSurface = { pos = Vector(2.05, 0, 19), w = 56, h = 32, tilt = 0 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
