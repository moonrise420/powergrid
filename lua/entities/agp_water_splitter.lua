-- PowerGrid: Water Splitter (Grid Power / life support, see agp_power_base.lua)
ENT.Type = "anim"
ENT.Base = "agp_power_base"
ENT.AGPNameKey = "agp_ent_water_splitter"
ENT.PrintName = PowerGrid.L("agp_ent_water_splitter", "Water Splitter")
ENT.Author = "moonrise420"
ENT.Category = "PowerGrid"
ENT.Spawnable = true
ENT.AGPKind = "splitter"
ENT.AGPModel = "models/agp_power/agp_water_splitter.mdl"
ENT.AGPCapacity = 3000
ENT.AGPRate = 60
ENT.AGPScreen = { up = 6, scale = 0.08, w = 380, lines = 3 }
list.Set("CAP.Entity", ENT.PrintName, ENT)
if SERVER then AddCSLuaFile() end
