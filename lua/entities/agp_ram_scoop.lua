-- PowerGrid: Ram Scoop (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_ram_scoop"
ENT.PrintName = PowerGrid.L("agp_ent_ram_scoop", "Ram Scoop")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "ramscoop"
ENT.AGPModel = "models/agp_power/agp_ram_scoop.mdl"
ENT.AGPCapacity = 3000
ENT.AGPRate = 40
ENT.AGPScreen = { up = 6, scale = 0.08, w = 380, lines = 2 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
