-- PowerGrid: Energy Cell (M) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_cell_medium"
ENT.PrintName = PowerGrid.L("agp_ent_cell_medium", "Energy Cell (M)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "storage"
ENT.AGPModel = "models/agp_power/agp_cell_medium.mdl"
ENT.AGPCapacity = 10000000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 6, scale = 0.1, w = 380, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
