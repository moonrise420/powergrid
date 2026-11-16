-- PowerGrid: Environment Probe (see agp_power_base.lua, kind "probe")
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_env_probe"
ENT.PrintName = PowerGrid.L("agp_ent_env_probe", "Environment Probe")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "probe"
ENT.AGPModel = "models/agp_power/agp_env_probe.mdl"
ENT.AGPCapacity = 0
ENT.AGPRate = 0
ENT.AGPScreen = { up = 6, scale = 0.06, w = 340, lines = 1 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
