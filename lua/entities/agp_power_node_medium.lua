-- PowerGrid: Power Node (M) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_power_node_medium"
ENT.PrintName = PowerGrid.L("agp_ent_power_node_medium", "Power Node (M)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "node"
ENT.AGPModel = "models/agp_power/agp_node_medium.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPSurface = { pos = Vector(-16.88, 0, 13.0), w = 40.8, h = 15.2, tilt = 20 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
