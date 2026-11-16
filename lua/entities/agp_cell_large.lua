-- PowerGrid: Energy Cell (L) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_cell_large"
ENT.PrintName = PowerGrid.L("agp_ent_cell_large", "Energy Cell (L)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "storage"
ENT.AGPModel = "models/agp_power/agp_cell_large.mdl"
ENT.AGPCapacity = 100000000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 8, scale = 0.14, w = 400, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
