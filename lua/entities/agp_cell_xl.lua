-- PowerGrid: Energy Cell (XL) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_cell_xl"
ENT.PrintName = PowerGrid.L("agp_ent_cell_xl", "Energy Cell (XL)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "storage"
ENT.AGPModel = "models/agp_power/agp_cell_xl.mdl"
ENT.AGPCapacity = 1000000000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 12, scale = 0.24, w = 420, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
