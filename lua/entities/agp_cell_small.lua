-- PowerGrid: Energy Cell (S) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_cell_small"
ENT.PrintName = PowerGrid.L("agp_ent_cell_small", "Energy Cell (S)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "storage"
ENT.AGPModel = "models/agp_power/agp_cell_small.mdl"
ENT.AGPCapacity = 1000000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 5, scale = 0.07, w = 360, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
