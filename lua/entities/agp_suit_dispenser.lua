-- PowerGrid: Suit Dispenser (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_suit_dispenser"
ENT.PrintName = PowerGrid.L("agp_ent_suit_dispenser", "Suit Dispenser")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "dispenser"
ENT.AGPModel = "models/agp_power/agp_suit_dispenser.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPSurface = { pos = Vector(4.6, 0, 45.5), w = 18, h = 9, tilt = 0 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
