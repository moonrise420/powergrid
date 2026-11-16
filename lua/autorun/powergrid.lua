-- PowerGrid: resource network (energy, oxygen, water ...) and life support for any addon. Loader.
-- Works alone; with Spacebuild/CAF installed it can use Resource Distribution instead (setting "backend").
PowerGrid = PowerGrid or {}
PowerGrid.Version = "1.0.0" -- numbers first: the update check compares them with the GitHub release tag
AGP = AGP or {}                           -- the network keeps its first name (AGP.Power, AGP.LS) for saves and other addons

-- our own links: fill in once they exist (empty = no button)
PowerGrid.Links = {
	GitHub = "https://github.com/moonrise420/powergrid",
	Workshop = "https://steamcommunity.com/sharedfiles/filedetails/?id=3840679072",
	Tip = "https://www.paypal.me/soulridejourney", -- a tip / donation page (Ko-fi, PayPal.me, ...): the About panel shows a "Support / Tip" button
}

local shared = { "sh_texts.lua", "sh_config.lua", "sh_license.lua" }
local server = { "sv_bridge.lua", "sv_network.lua" }
local client = { "cl_skin.lua", "cl_menu.lua" }

for _, f in ipairs(shared) do
	if SERVER then AddCSLuaFile("powergrid/" .. f) end
	include("powergrid/" .. f)
end
for _, f in ipairs(client) do
	if SERVER then AddCSLuaFile("powergrid/" .. f) else include("powergrid/" .. f) end
end
if SERVER then
	for _, f in ipairs(server) do include("powergrid/" .. f) end
	for _, f in ipairs(file.Find("powergrid/lang/*.lua", "LUA")) do AddCSLuaFile("powergrid/lang/" .. f) end
end
