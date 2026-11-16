-- PowerGrid: settings, and which network runs.
--   agp_power_mode     0 = off (free energy), 1 = manual (link tool, nodes), 2 = automatic (welded parts share), 3 = mix
--   agp_power_backend  0 = use Spacebuild/RD when it is installed, 1 = always PowerGrid's own network
-- (the convar names stay as they were inside Ascension Gates, so server configs keep working)
-- Decided once at start: a change needs a map change.
local FLAGS = { FCVAR_ARCHIVE, FCVAR_REPLICATED }
local cvMode = CreateConVar("agp_power_mode", "1", FLAGS, "PowerGrid: 0 = off (free energy), 1 = manual (link tool), 2 = automatic (welded parts share), 3 = mix", 0, 3)
local cvBackend = CreateConVar("agp_power_backend", "0", FLAGS, "PowerGrid: 0 = use Spacebuild/RD when installed, 1 = always use PowerGrid's own network", 0, 1)
if SERVER and not ConVarExists("agp_blackhole_cache_everyone") then
	CreateConVar("agp_blackhole_cache_everyone", "0", { FCVAR_ARCHIVE }, "PowerGrid: 1 = every player may spawn the Black Hole Cache (default: admins only)")
end

-- Spacebuild / CAF Resource Distribution (or Environments) installed? Looked up by its tool files, so it works
-- whichever addon loads first.
local function rdInstalled()
	if Environments or Dev_Link or rd3_dev_link then return true end
	for _, f in ipairs({ "weapons/gmod_tool/environments_tool_base.lua", "weapons/gmod_tool/stools/dev_link.lua", "weapons/gmod_tool/stools/rd3_dev_link.lua" }) do
		if file.Exists(f, "LUA") then return true end
	end
	return false
end

PowerGrid.SpacebuildInstalled = rdInstalled()
-- our own network runs (else: Spacebuild's Resource Distribution, or nothing when the mode is 0)
PowerGrid.Active = cvMode:GetInt() > 0 and (not PowerGrid.SpacebuildInstalled or cvBackend:GetInt() == 1)

-- "a, b ,c" -> { "a", "b", "c" } (trimmed, empty parts left out)
function PowerGrid.Split(s, sep)
	local out = {}
	for _, part in ipairs(string.Explode(sep, tostring(s or ""))) do
		part = string.Trim(part)
		if part ~= "" then out[#out + 1] = part end
	end
	return out
end

-- CAF Resource Distribution, when it carries the energy instead of us
function PowerGrid.RD3()
	if PowerGrid.Active then return nil end
	return CAF and CAF.GetAddon and CAF.GetAddon("Resource Distribution") or nil
end

-- spawn tab: the parts in groups and order. Other addons add theirs: PowerGrid.AddSpawn(class, group, order, cmd)
-- (cmd: their own spawn command, for entities that are not Spawnable, e.g. Ascension Gates' "cap_spawnsent")
PowerGrid.Groups = {
	{ id = "generators", key = "agp_grp_generators", name = "Generators" },
	{ id = "storage", key = "agp_grp_storage", name = "Energy storage" },
	{ id = "network", key = "agp_grp_network", name = "Network" },
	{ id = "displays", key = "agp_grp_displays", name = "Displays" },
	{ id = "tanks", key = "agp_grp_tanks", name = "Resource tanks" },
	{ id = "lifesupport", key = "agp_grp_lifesupport", name = "Life support" },
	{ id = "other", key = "agp_grp_other", name = "Other" },
}
PowerGrid.Spawn = PowerGrid.Spawn or {}
PowerGrid.UnfinishedDevices = { agp_terraformer = true }   -- 2026-11-14: not finished (see notes/ls_devices_handover_2026-11-14.md); remove a class to release it
function PowerGrid.AddSpawn(class, group, order, cmd)
	if PowerGrid.UnfinishedDevices[class] then return end
	PowerGrid.Spawn[class] = { group = group or "other", order = order or 500, cmd = cmd }
end
for i, c in ipairs({ "agp_solar_small", "agp_solar_large", "agp_wind_turbine", "agp_hydro_generator", "agp_steam_turbine", "agp_fusion_reactor" }) do PowerGrid.AddSpawn(c, "generators", 100 + i) end
for i, c in ipairs({ "agp_cell_xs", "agp_cell_small", "agp_cell_medium", "agp_cell_large", "agp_cell_xl" }) do PowerGrid.AddSpawn(c, "storage", 100 + i) end
for i, c in ipairs({ "agp_power_node_xs", "agp_power_node_small", "agp_power_node_medium", "agp_power_node_large", "agp_power_pump" }) do PowerGrid.AddSpawn(c, "network", 100 + i) end
for i, c in ipairs({ "agp_display_small", "agp_display_large" }) do PowerGrid.AddSpawn(c, "displays", 100 + i) end
for i, c in ipairs({ "agp_tank_xs", "agp_tank_small", "agp_tank_medium", "agp_tank_large", "agp_tank_xl" }) do PowerGrid.AddSpawn(c, "tanks", 100 + i) end
for i, c in ipairs({ "agp_ls_core", "agp_suit_dispenser", "agp_air_compressor", "agp_water_pump", "agp_water_splitter", "agp_ram_scoop",
	"agp_ls_heater_small", "agp_ls_heater", "agp_ls_heater_large", "agp_ls_heater_xl",
	"agp_ls_cooler_small", "agp_ls_cooler", "agp_ls_cooler_large", "agp_ls_cooler_xl",
	-- 2026-11-14: the rest of what Spacebuild's life support had
	"agp_env_probe", "agp_hydroponics_small", "agp_hydroponics_large", "agp_gravity_regulator", "agp_terraformer" }) do PowerGrid.AddSpawn(c, "lifesupport", 100 + i) end
