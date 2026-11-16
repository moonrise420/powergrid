-- PowerGrid: texts in the player's language (lua/powergrid/lang/<code>.lua, English as fallback).
--   PowerGrid.L(key, fallback, ...)     the text, formatted with the arguments
--   PowerGrid.ResName(res)              a resource's name ("carbon dioxide" -> key agp_res_carbon_dioxide)
--   PowerGrid.Say(ply, key, fallback, ...)   a chat line for this one player, in his language
--   PowerGrid.Hint(ply, key, fallback, ...)  the same, only the first time this session (how-to hints)
local cache = {}
local function load(code)
	if cache[code] == nil then
		local path = "powergrid/lang/" .. code .. ".lua"
		cache[code] = file.Exists(path, "LUA") and include(path) or false
	end
	return cache[code]
end

local function current()
	if SERVER then return "en" end
	-- with Ascension Gates installed: the language the player chose for it (sg_language, which starts as GMod's
	-- language), so all our addons speak one language; without it: GMod's own language
	local sg = GetConVar("sg_language")
	local cv = (sg and sg:GetString() ~= "") and sg or GetConVar("gmod_language")
	local code = string.lower(cv and cv:GetString() or "en")
	if load(code) then return code end
	code = code:match("^(%a+)") or "en"   -- "pt-br" -> "pt", "sv" -> our "sv-se"
	if load(code) then return code end
	for _, f in ipairs(file.Find("powergrid/lang/" .. code .. "-*.lua", "LUA")) do return f:sub(1, -5) end
	return "en"
end

local lang, langAt = nil, 0
function PowerGrid.L(key, fallback, ...)
	if CurTime() > langAt then lang, langAt = current(), CurTime() + 2 end
	local t = load(lang) or {}
	local text = t[key] or (load("en") or {})[key] or fallback or key
	if select("#", ...) > 0 then
		local ok, s = pcall(string.format, text, ...)
		if ok then return s end
	end
	return text
end

function PowerGrid.ResName(res)
	return PowerGrid.L("agp_res_" .. tostring(res):gsub("[^%w]+", "_"), res)
end

if SERVER then
	util.AddNetworkString("powergrid_say")
	function PowerGrid.Say(ply, key, fallback, ...)
		if not IsValid(ply) then return end
		local args = { ... }
		net.Start("powergrid_say")
		net.WriteString(key); net.WriteString(fallback or key)
		net.WriteUInt(#args, 4)
		for _, a in ipairs(args) do net.WriteString(tostring(a)) end
		net.Send(ply)
	end

	function PowerGrid.FirstTime(ply, key)
		if not IsValid(ply) then return false end
		ply.PowerGridHints = ply.PowerGridHints or {}
		if ply.PowerGridHints[key] then return false end
		ply.PowerGridHints[key] = true
		return true
	end

	function PowerGrid.Hint(ply, key, fallback, ...)
		if PowerGrid.FirstTime(ply, key) then PowerGrid.Say(ply, key, fallback, ...) end
	end
else
	net.Receive("powergrid_say", function()
		local key, fallback = net.ReadString(), net.ReadString()
		local args = {}
		for i = 1, net.ReadUInt(4) do
			local a = net.ReadString()
			args[i] = tonumber(a) or PowerGrid.L(a, a)   -- arguments may be keys themselves (part names)
		end
		chat.AddText(Color(120, 200, 255), "[PowerGrid] ", Color(230, 235, 240), PowerGrid.L(key, fallback, unpack(args)))
	end)

	-- the player changed the language: forget the cached one and tell everything that put texts into GMod once
	-- (tool names via language.Add ...) to do it again: hook "PowerGrid.LanguageChanged"
	local function changed()
		timer.Simple(0.3, function()
			langAt = 0
			hook.Run("PowerGrid.LanguageChanged")
		end)
	end
	cvars.AddChangeCallback("sg_language", changed, "PowerGrid.LangChanged")
	cvars.AddChangeCallback("gmod_language", changed, "PowerGrid.LangChanged")
end
