-- PowerGrid: Life Support Core (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_ls_core"
ENT.PrintName = PowerGrid.L("agp_ent_ls_core", "Life Support Core")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "lscore"
ENT.AGPModel = "models/agp_power/agp_ls_core.mdl"
ENT.AGPCapacity = 5000
ENT.AGPRate = 0
ENT.AGPScreen = { up = 8, scale = 0.12, w = 440, lines = 4 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
