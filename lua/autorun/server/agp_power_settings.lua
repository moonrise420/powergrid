-- PowerGrid: Grid Power settings page (server side). Admins (or the single player) change the server settings.
util.AddNetworkString("agp_power_state")
util.AddNetworkString("agp_power_set")

local SETTINGS = {
    agp_power_mode = { min = 0, max = 3 },
    agp_power_backend = { min = 0, max = 1 },
    agp_blackhole_cache_everyone = { min = 0, max = 1 },
    agp_allow_infinite_power = { min = 0, max = 1 },
    agp_zpm_overload = { min = 0, max = 1 },
    agp_ls_space = { min = 0, max = 2 },
    agp_ls_gate_report = { min = 0, max = 1 },
    agp_ls_backend = { min = 0, max = 1 },
    agp_ls_water = { min = 0, max = 1 },
    agp_ls_prop_gravity = { min = 0, max = 1 },
    agp_ls_noclip = { min = 0, max = 3 },
    agp_ls_pressure = { min = 0, max = 1 },
    agp_ls_stars = { min = 0, max = 1 },
    agp_ls_gas_use = { min = 0, max = 1 },
}

local function allowed(p) return IsValid(p) and (p:IsAdmin() or game.SinglePlayer()) end

local function sendState(p)
    local function get(n) local cv = GetConVar(n) return cv and cv:GetInt() or 0 end
    net.Start("agp_power_state")
    net.WriteUInt(get("agp_power_mode"), 3)
    net.WriteUInt(get("agp_power_backend"), 2)
    net.WriteBool(get("agp_blackhole_cache_everyone") == 1)
    net.WriteBool(PowerGrid.Active == true)   -- running right now
    net.WriteBool(PowerGrid.RD3() ~= nil) -- Spacebuild/RD in use
    net.WriteBool(allowed(p))
    net.WriteUInt(get("agp_ls_space"), 2)
    net.WriteBool(get("agp_ls_gate_report") == 1)
    net.WriteBool(AGP and AGP.LS and AGP.LS.Active and AGP.LS.Active() or false)
    net.WriteUInt(AGP and AGP.LS and #AGP.LS.Planets or 0, 8)
    net.WriteBool(get("agp_allow_infinite_power") == 1)
    net.WriteBool(get("agp_zpm_overload") == 1)
    -- 2026-11-14: what runs here (0 nothing, 1 full space simulation, 2 water only) and the new life support settings
    net.WriteUInt(AGP and AGP.LS and AGP.LS.Mode and AGP.LS.Mode() or 0, 2)
    net.WriteBool(get("agp_ls_water") == 1)
    net.WriteBool(get("agp_ls_prop_gravity") == 1)
    net.WriteUInt(get("agp_ls_noclip"), 2)
    net.WriteBool(get("agp_ls_pressure") == 1)
    net.WriteBool(get("agp_ls_stars") == 1)
    net.WriteBool(get("agp_ls_gas_use") == 1)
    -- Spacebuild's own life support runs and ours stands back (agp_ls_backend 0)
    net.WriteBool(get("agp_ls_backend") ~= 1 and AGP and AGP.LS and AGP.LS.SpacebuildLSRuns and AGP.LS.SpacebuildLSRuns() or false)
    net.Send(p)
end

net.Receive("agp_power_set", function(_, p)
    local name = net.ReadString()
    local value = net.ReadInt(8)
    local s = SETTINGS[name]
    if s and allowed(p) then
        RunConsoleCommand(name, tostring(math.Clamp(value, s.min, s.max)))
    end
    timer.Simple(0.3, function() if IsValid(p) then sendState(p) end end)
end)
