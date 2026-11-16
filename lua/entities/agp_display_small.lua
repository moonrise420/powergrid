-- PowerGrid: Power Display (S) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_display_small"
ENT.PrintName = PowerGrid.L("agp_ent_display_small", "Power Display (S)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "display"
ENT.AGPModel = "models/agp_power/agp_display_small.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPSurface = { pos = Vector(2.05, 0, 10), w = 24, h = 14, tilt = 0 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
