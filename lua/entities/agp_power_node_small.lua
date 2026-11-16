-- PowerGrid: Power Node (S) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_power_node_small"
ENT.PrintName = PowerGrid.L("agp_ent_power_node_small", "Power Node (S)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "node"
ENT.AGPModel = "models/agp_power/agp_node_small.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPSurface = { pos = Vector(-8.88, 0, 12.2), w = 23.0, h = 13.6, tilt = 20 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
