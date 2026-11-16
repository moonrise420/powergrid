-- PowerGrid: Terraformer (see agp_power_base.lua, kind "terraformer")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_terraformer"
ENT.PrintName = PowerGrid.L("agp_ent_terraformer", "Terraformer")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = not (PowerGrid.UnfinishedDevices and PowerGrid.UnfinishedDevices.agp_terraformer)   -- hidden until released (sh_config.lua)
ENT.AGPKind = "terraformer"
ENT.AGPModel = "models/agp_power/agp_terraformer.mdl"
ENT.AGPCapacity = 500000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 8, scale = 0.1, w = 400, lines = 4 }
if ENT.Spawnable then list.Set("CAP.Entity", ENT.PrintName, ENT) end
if SERVER then AddCSLuaFile() end
