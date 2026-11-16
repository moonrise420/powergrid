-- PowerGrid: Power Node (L) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_power_node_large"
ENT.PrintName = PowerGrid.L("agp_ent_power_node_large", "Power Node (L)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "node"
ENT.AGPModel = "models/agp_power/agp_node_large.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPSurface = { pos = Vector(-26.88, 0, 13.0), w = 64.5, h = 15.2, tilt = 20 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
