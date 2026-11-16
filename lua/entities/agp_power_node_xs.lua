-- PowerGrid: Power Node (XS) (Grid Power, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_power_node_xs"
ENT.PrintName = PowerGrid.L("agp_ent_power_node_xs", "Power Node (XS)")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "node"
ENT.AGPModel = "models/agp_power/agp_node_xs.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPSurface = { pos = Vector(-4.88, 0, 9.95), w = 15.6, h = 9.1, tilt = 20 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
