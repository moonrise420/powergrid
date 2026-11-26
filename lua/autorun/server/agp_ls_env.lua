-- PowerGrid: AGP Life Support - environments + space suit (used when the Spacebuild gamemode is not running).
--   agp_ls_space 0 = off, 1 = space maps only (default), 2 = every map (outside ships/bubbles is vacuum)
--   agp_ls_water 1 (default) = where the space simulation is off, the suit still runs in a "water only" form Space maps
-- describe their planets with logic_case entities ("planet" / "planet2" / "cube", the Spacebuild format): radius,
-- gravity, atmosphere, temperatures (Kelvin), gas mix. Outside a planet is space: vacuum, -270 C, no gravity. Inside a
-- Life Support Core's area (the whole StarCore ship or a bubble) it is breathable, 20 C, normal gravity. The suit
-- (air / energy / coolant, 0..100) drains where you could not survive and hurts at 0. Air refills by itself in
-- breathable air; the Suit Dispenser refills everything.
--
-- API for devices (names fixed - the devices code against exactly these):
--   AGP.LS.PlanetAt(pos)                      -> planet table or nil (the smallest planet / cube environment around pos)
--   AGP.LS.ChangeGas(planet, gas, amount)     gas = "o2" | "co2" | "n" | "h" (also "oxygen" ...); amount > 0 adds (into free
--                                             air space only), < 0 takes; returns what was really moved (signed like amount)
--   AGP.LS.ConvertGas(planet, from, to, amount)  moves between two gases (plants: co2 -> o2); returns what was moved
--   AGP.LS.SetPlanetGravity(planet, g)        planet gravity (1 = normal); the pressure follows, as in Spacebuild
--   AGP.LS.SetPlanetTemperature(planet, low, high)   Kelvin; low = shade / under a roof, high = open sky (high defaults to low)
--   AGP.LS.AddGravityZone(ent, radius, g) / AGP.LS.RemoveGravityZone(ent)   artificial gravity round a device (players + props)
--   AGP.LS.Probe(pos)                         -> { name, breathable, o2, co2, n, h (percent), pressure, temperature (Kelvin),
--                                                gravity, space }
--   hook "AGP.LS.PlanetChanged"(planet)       when gas, gravity or temperature of a planet changed
-- Planet changes live in the planet tables only: a map cleanup / restart reads the map again and resets them.
AGP = AGP or {}
AGP.LS = AGP.LS or {}
local LS = AGP.LS

local FLAGS = { FCVAR_ARCHIVE, FCVAR_REPLICATED }
local cvSpace = CreateConVar("agp_ls_space", "1", FLAGS, "Ascension Gates life support: 0 = off, 1 = space maps only, 2 = every map", 0, 2)
local cvWater = CreateConVar("agp_ls_water", "1", FLAGS, "PowerGrid life support: 1 = where the space simulation is off, a head under water still costs suit air", 0, 1)
local cvPressure = CreateConVar("agp_ls_pressure", "1", FLAGS, "PowerGrid life support: 1 = planets with a pressure above 1.5 crush (suit air, then damage)", 0, 1)
local cvStars = CreateConVar("agp_ls_stars", "1", FLAGS, "PowerGrid life support: 1 = star heat zones, sunburn and the kill zone", 0, 1)
local cvGasUse = CreateConVar("agp_ls_gas_use", "1", FLAGS, "PowerGrid life support: 1 = breathing uses up the oxygen of a planet (only small ones notice)", 0, 1)
-- The new rules (water, pressure, stars, gas use, noclip 1, prop gravity) are ON by default since their game tests passed (suites
-- lsenv_* / lsenv_mix): without Spacebuild ours behaves like Spacebuild out of the box; with Spacebuild's life support running
-- (and agp_ls_backend 0) none of them runs (LS.SpacebuildLSRuns). Spacebuild's own default for noclip is 1. noclip
-- in space (Spacebuild: SB_NoClip / SB_PlanetNoClipOnly / SB_AdminSpaceNoclip / SB_SuperAdminSpaceNoclip, all 1 out of the box) 0 =
--   free everywhere, 1 = in space only admins and superadmins (Spacebuild's default), 2 = only superadmins, 3 = nobody
local cvNoclip = CreateConVar("agp_ls_noclip", "1", FLAGS, "PowerGrid life support: noclip in space - 0 = free, 1 = admins only, 2 = superadmins only, 3 = nobody", 0, 3)
-- a player in a seat breathes like one on foot - the ship's life support (a Life Support Core, a sealed ship) or the
-- suit. Before, a seat in open space always had air (GMod moves a seated player as noclip, the suit skipped him).
--
local cvSeats = CreateConVar("agp_ls_seats", "1", FLAGS, "PowerGrid life support: 1 = in space a player in a seat needs air like on foot (ship life support or suit), 0 = seats always have air", 0, 1)

LS.Planets = LS.Planets or {}
LS.Stars = LS.Stars or {}
LS.Zones = LS.Zones or {}   -- Life Support Cores register here: { ent = core, contains = function(pos) }
-- ship interiors kept apart from the flying hull (TARDIS style) register here: { ent = interior, contains(pos),
-- outside(pos) = the same spot on the real ship }. Inside, it is the air of wherever the ship really is (planet air,
-- a Life Support Core's area around the ship, or vacuum in space), but always with the ship's own gravity.
LS.Interiors = LS.Interiors or {}
LS.GravZones = LS.GravZones or {}   -- ent -> { ent, r, r2, g }  (AddGravityZone)
LS.Trees = LS.Trees or {}           -- sb_dev_tree entries: { pos, rate }
LS.FX = LS.FX or {}                 -- planet_color / planet_bloom for the clients
LS.Epoch = LS.Epoch or 0            -- counts everything that can change what gravity a place has (the props re-check on it)

local KELVIN = 273.15

-- Spacebuild running? Then its own environments and suits are used and ours stays off
-- Spacebuild's own life support running (its gamemode, or its CAF addons active in Sandbox)? Then its environments
-- and suits are used and ours stays off - unless agp_ls_backend is 1 ("always AGP life support").
local cvBackend = CreateConVar("agp_ls_backend", "0", FLAGS, "Ascension Gates life support: 0 = Spacebuild's when it runs, 1 = always AGP", 0, 1)
function LS.SpacebuildActive()
    if cvBackend:GetBool() then return false end
    if GAMEMODE and (GAMEMODE.IsSpacebuildDerived or GAMEMODE.IsSpaceBuildDerived) then return true end
    local sb = CAF and CAF.GetAddon and CAF.GetAddon("Spacebuild")
    return sb ~= nil and sb.GetStatus ~= nil and sb.GetStatus() == true
end

-- CAF's Life Support addon runs on EVERY map (it needs only Resource Distribution) and has its own under-water rule:
-- with it running (and agp_ls_backend 0) our "water only" form stays off, so there is one countdown, not two
function LS.CAFLifeSupportRuns()
    if cvBackend:GetBool() then return false end
    local ls = CAF and CAF.GetAddon and CAF.GetAddon("Life Support")
    return ls ~= nil and ls.GetStatus ~= nil and ls.GetStatus() == true
end

-- THE one answer to "does Spacebuild's own life support run?" (its gamemode - GM.SPACEBUILD -, CAF's Spacebuild addon on a
-- planet map, or CAF's Life Support addon, which runs on every map). While it runs and agp_ls_backend is 0, nothing of ours
-- runs: no suit, no countdown, no HUD, no water rule, no prop gravity, no noclip rule, no planet colours. LS.SBOverride (true /
-- false) lets the self-test answer for a run (the Spacebuild-free branch; nil = really ask).
--
function LS.SpacebuildLSRuns()
    if LS.SBOverride ~= nil then return LS.SBOverride end
    if GAMEMODE and (GAMEMODE.IsSpacebuildDerived or GAMEMODE.IsSpaceBuildDerived or GAMEMODE.SPACEBUILD) then return true end
    for _, name in ipairs({ "Spacebuild", "Life Support" }) do
        local a = CAF and CAF.GetAddon and CAF.GetAddon(name)
        if a ~= nil and a.GetStatus ~= nil and a.GetStatus() == true then return true end
    end
    return false
end

-- what our life support does right now: 0 = nothing, 1 = full (planets, space, stars ...), 2 = water only
function LS.Mode()
    if not cvBackend:GetBool() and LS.SpacebuildLSRuns() then return 0 end
    -- nothing before the map's planets were read (1 s after the map start): CAF starts its addons in that second, so ours
    -- never runs a first second beside Spacebuild's
    if not LS.Ready then return 0 end
    local m = cvSpace:GetInt()
    if m == 2 or (m == 1 and #LS.Planets > 0) then return 1 end
    if cvWater:GetBool() then return 2 end   -- (CAF's Life Support running already returned 0 above)
    return 0
end

-- the full space simulation (what "active" always meant)
function LS.Active() return LS.Mode() == 1 end

-- read the planets while the map spawns its entities
local pending = {}
LS.PendingCases = pending   -- AGP: (the self-test takes its test planet out of it again)
hook.Add("EntityKeyValue", "AGP.LS.Planets", function(ent, key, value)
    if ent:GetClass() ~= "logic_case" then return end
    pending[ent] = pending[ent] or {}
    pending[ent][key:lower()] = value
end)

local function num(v, d) return tonumber(v) or d end

-- AGP: a map cleanup spawns the map's logic_case entities anew (their key values arrive again) while the removed
-- ones stayed in `pending`: every planet was listed twice after a cleanup (the old one at its saved origin). One
-- entry per map entity now (same key values = the same entity of the map): the live one wins and the removed one is
-- dropped; a removed one is only used when nothing live replaced it (as before)
local function samePlanetKey(kv)
    return table.concat({ kv.hammerid or "", kv.case01 or "", kv.origin or "", kv.case02 or "", kv.targetname or "" }, "|")
end

local function dropReplaced()
    local best = {}
    for ent, kv in pairs(pending) do
        local key = samePlanetKey(kv)
        local had = best[key]
        if had == nil or (not IsValid(had) and IsValid(ent)) then best[key] = ent end
    end
    local keep = {}
    for _, ent in pairs(best) do keep[ent] = true end
    for _, ent in ipairs(table.GetKeys(pending)) do
        if not keep[ent] then pending[ent] = nil end
    end
end

-- the air of an environment (Spacebuild: base_sb_environment CreateEnvironment). Amounts, not percent: a gas is
-- percent * 5 * (volume / 1000) * atmosphere, the volume counted the way Spacebuild counts it (4/3 pi r * r - the radius
-- squared, not cubed: a planet of radius 4000 holds 3.5 million units per percent, a station of radius 60 only 75),
-- so a breath is nothing to a planet and a lot to a small room
local function volumeOf(p) return (4 / 3) * math.pi * p.radius * p.radius end

local GAS = { o2 = "o2", oxygen = "o2", co2 = "co2", ["carbon dioxide"] = "co2", carbon_dioxide = "co2", carbondioxide = "co2",
    n = "n", nitrogen = "n", n2 = "n", h = "h", hydrogen = "h", h2 = "h" }
local function gasKey(g) return type(g) == "string" and GAS[g:lower()] or nil end

local function initAir(p, o2, co2, n, h)
    o2 = math.Clamp(o2 or 0, 0, 100)
    co2 = math.Clamp(co2 or 0, 0, 100 - o2)
    n = math.Clamp(n or 0, 0, 100 - o2 - co2)
    h = math.Clamp(h or 0, 0, 100 - o2 - co2 - n)
    local unit = 5 * (volumeOf(p) / 1000) * math.Clamp(p.atmosphere, 0, 1)
    p.air = { o2 = o2 * unit, co2 = co2 * unit, n = n * unit, h = h * unit, empty = math.max(0, 100 - o2 - co2 - n - h) * unit,
        max = 100 * unit }
end

-- the pressure you feel: Spacebuild takes up to three quarters of it away where the air is thin (free space in the mix)
function LS.PlanetPressure(p)
    local a = p.air
    local emptyPct = (a and a.max > 0) and (a.empty / a.max * 100) or 0
    return p.pressure - ((emptyPct / 100) * p.pressure * 0.75)
end

-- percent from amounts + breathable; returns true when breathable flipped
local function recompute(p)
    local a = p.air
    if a.max > 0 then
        p.o2, p.co2, p.n, p.h = a.o2 / a.max * 100, a.co2 / a.max * 100, a.n / a.max * 100, a.h / a.max * 100
    else
        p.o2, p.co2, p.n, p.h = 0, 0, 0, 0
    end
    local was = p.breathable
    -- (a tiny tolerance: 10 % of the map is 9.9999999999 after amount / max * 100 - Endgame in sb_gooniverse_v4 was 'no air' for that)
    p.breathable = p.o2 >= 9.9999 and p.atmosphere > 0.2 and p.pressure > 0.2
    return was ~= nil and was ~= p.breathable
end

-- tell the world: the hook always for a forced change (devices), for breathing only when it is worth a word
local function announce(p, force)
    local flipped = recompute(p)
    local last = p.lastAnnounced
    local big = force or flipped or not last or math.abs(p.o2 - last.o2) >= 0.1 or math.abs(p.co2 - last.co2) >= 0.1
        or math.abs(p.n - last.n) >= 0.1 or math.abs(p.h - last.h) >= 0.1
    if big then
        p.lastAnnounced = { o2 = p.o2, co2 = p.co2, n = p.n, h = p.h }
        hook.Run("AGP.LS.PlanetChanged", p)
    end
end

local function parseNums(s)
    local t = {}
    for w in string.gmatch(s or "", "%S+") do t[#t + 1] = tonumber(w) or 0 end
    return t
end

local function starSize(s) return s.size end

-- Spacebuild's star heat zones (base_sb_star1 / star2 GetTemperature): hot in the middle, cooler outwards, nothing
-- beyond the star's size
local function starTemp(s, d)
    local size = s.size
    if s.kind == "star2" then
        if d < size / 6 then return s.t1
        elseif d < size / 3 then return s.t2
        elseif d < size / 2 then return s.t3
        elseif d < size * 2 / 3 then return s.t3 / 2
        elseif s.t3 / 4 <= 14 then return 14 end
        return s.t3 / 4
    end
    local t = s.t1
    if d < size / 6 then return t
    elseif d < size / 3 then return t * 2 / 3
    elseif d < size / 2 then return t / 3
    elseif d < size * 2 / 3 then return t / 6
    elseif t / 12 <= 14 then return 14 end
    return t / 12
end

function LS.ReadPlanets()
    LS.Planets, LS.Stars, LS.Trees, LS.FX = {}, {}, {}, {}
    LS.GravZones = {}
    LS.Epoch = LS.Epoch + 1
    dropReplaced()   -- AGP
    local colors, blooms = {}, {}
    local list = {}
    for ent, kv in pairs(pending) do
        local kind = (kv.case01 or ""):lower()
        local pos = IsValid(ent) and ent:GetPos() or Vector(unpack(PowerGrid.Split(kv.origin or "0 0 0", " ")))
        if kind == "planet2" or kind == "cube" then
            local flags = num(kv.case08, 0)
            local p = { kind = kind, cube = kind == "cube", pos = pos, radius = num(kv.case02, 0), gravity = num(kv.case03, 1), atmosphere = num(kv.case04, 1),
                pressure = num(kv.case05, 1), tLow = num(kv.case06, 288), tHigh = num(kv.case07, 288), o2 = num(kv.case09, 0),
                name = kv.case13 or kv.targetname or "Planet", flags = flags,
                -- Spacebuild planet2 / cube: flag 1 = unstable, flag 2 = sunburn (base_sb_planet2/init.lua:48-52)
                unstable = flags % 2 >= 1 and flags <= 7, sunburn = flags % 4 >= 2 and flags <= 7,
                colorId = kv.case15 ~= "" and kv.case15 or nil, bloomId = kv.case16 ~= "" and kv.case16 or nil }
            if p.name == "" then p.name = kind == "cube" and "Cube Environment" or "Planet" end
            -- a negative pressure means "from atmosphere and gravity", as in Spacebuild (base_sb_environment):
            -- sb_binarysystem has -1 on all 5 planets, so none was breathable (Europa with 21 % oxygen included)
            if p.pressure < 0 then p.pressure = math.Round(p.atmosphere * p.gravity) end
            initAir(p, p.o2, num(kv.case10, 0), num(kv.case11, 0), num(kv.case12, 0))
            list[#list + 1] = p
        elseif kind == "planet" then
            if num(kv.case15, 0) ~= 1 then   -- case15 = 1: switched off by the map (Spacebuild skips it)
                local flags = num(kv.case16, 0)
                local p = { kind = "planet", pos = pos, radius = num(kv.case02, 0), gravity = num(kv.case03, 1), atmosphere = num(kv.case04, 1),
                    pressure = num(kv.case04, 1), tLow = num(kv.case05, 288), tHigh = num(kv.case06, 288), name = kv.targetname or "Planet",
                    flags = flags, unstable = flags % 4 >= 2 and flags <= 7, sunburn = false,   -- (flag 4 = sunburn in the map editor's text, but Spacebuild's reader never sets it)
                    colorId = kv.case07 ~= "" and kv.case07 or nil, bloomId = kv.case08 ~= "" and kv.case08 or nil }
                local habitat = (flags % 2 >= 1 and flags <= 7) or (p.atmosphere >= 0.5 and p.tLow > 240 and p.tHigh < 330)
                p.habitat = habitat
                p.o2 = habitat and 21 or 0
                -- Spacebuild's two ready-made atmospheres: "Earth" and "Venus"
                if habitat then initAir(p, 21, 0.45, 78, 0.55) else initAir(p, 0, 96.5, 3.5, 0) end
                list[#list + 1] = p
            end
        elseif kind == "star" then
            local r = num(kv.case02, 0)
            LS.Stars[#LS.Stars + 1] = { kind = "star", pos = pos, radius = r, size = r * 2, t1 = 100000, name = "Star" }
        elseif kind == "star2" then
            local r = num(kv.case02, 0)
            LS.Stars[#LS.Stars + 1] = { kind = "star2", pos = pos, radius = r, size = r, t1 = num(kv.case03, 0), t2 = num(kv.case04, 0),
                t3 = num(kv.case05, 0), name = (kv.case06 and kv.case06 ~= "") and kv.case06 or "Star" }
        elseif kind == "planet_color" then
            local add, mul = parseNums(kv.case02), parseNums(kv.case03)
            colors[kv.case16 or ""] = { add[1] or 0, add[2] or 0, add[3] or 0, mul[1] or 0, mul[2] or 0, mul[3] or 0,
                num(kv.case04, 0), num(kv.case05, 1), num(kv.case06, 1) }
        elseif kind == "planet_bloom" then
            local col, size = parseNums(kv.case02), parseNums(kv.case03)
            blooms[kv.case16 or ""] = { col[1] or 1, col[2] or 1, col[3] or 1, size[1] or 5, size[2] or 5, num(kv.case04, 1), num(kv.case05, 0),
                num(kv.case06, 1), num(kv.case07, 1) }
        elseif kind == "sb_dev_tree" then
            LS.Trees[#LS.Trees + 1] = { pos = pos, rate = num(kv.case02, 0) }
        end
    end
    table.sort(list, function(a, b) return a.radius < b.radius end) -- small ones (stations inside planets) first
    LS.Planets = list
    for i, p in ipairs(list) do
        p.id = i
        recompute(p)
        local c, b = p.colorId and colors[p.colorId], p.bloomId and blooms[p.bloomId]
        if c or b then LS.FX[#LS.FX + 1] = { pos = p.pos, radius = p.radius, cube = p.cube, color = c, bloom = b } end
    end
    -- the sun of maps without a star entry: the env_sun's direction (only used for sunburn)
    LS.SunDir = nil
    local sun = ents.FindByClass("env_sun")[1]
    if IsValid(sun) then LS.SunDir = sun:GetAngles():Forward() end
    LS.Ready = true
    MsgN("[Ascension Gates] Life support: " .. #LS.Planets .. " planets on " .. game.GetMap() .. (LS.Active() and " (space simulation on)" or (LS.Mode() == 2 and " (water only)" or " (space simulation off)"))
        .. (LS.SpacebuildLSRuns() and " - Spacebuild's life support runs" .. (cvBackend:GetBool() and " (agp_ls_backend 1: ours too)" or ", ours stands back") or ""))
    if LS.SendFX then LS.SendFX() end
end
hook.Add("InitPostEntity", "AGP.LS.Planets", function() timer.Simple(1, LS.ReadPlanets) end)
hook.Add("PostCleanupMap", "AGP.LS.Planets", function() timer.Simple(1, LS.ReadPlanets) end)

-- a small environment of your own (a room, a station, a test): fields pos, radius (the half edge for cube = true) and
-- optional gravity, atmosphere, pressure, tLow, tHigh, o2, co2, n, h (percent), name, sunburn. It joins the planets: the
-- same rules (suit, gas, gravity of props). Returns the planet table; remove it with LS.RemovePlanet.
function LS.AddPlanet(f)
    -- a planet without a place or size broke every environment check after it (162 errors a test run)
    if not (istable(f) and isvector(f.pos) and isnumber(f.radius) and f.radius > 0) then return nil end
    -- (numbers given as text broke the checks the same way: everything through tonumber)
    local tLow = tonumber(f.tLow) or 288
    local p = { kind = f.cube and "cube" or "planet2", cube = f.cube == true, pos = f.pos, radius = f.radius, gravity = tonumber(f.gravity) or 1,
        atmosphere = tonumber(f.atmosphere) or 1, pressure = tonumber(f.pressure) or 1, tLow = tLow, tHigh = tonumber(f.tHigh) or tLow,
        name = f.name or "Environment", sunburn = f.sunburn == true, unstable = false, flags = 0 }
    initAir(p, tonumber(f.o2) or 21, tonumber(f.co2) or 0, tonumber(f.n) or 78, tonumber(f.h) or 0)
    recompute(p)
    p.o2Start = p.o2
    LS.Planets[#LS.Planets + 1] = p
    table.sort(LS.Planets, function(x, y) return x.radius < y.radius end)
    for i, q in ipairs(LS.Planets) do q.id = i end
    LS.Epoch = LS.Epoch + 1
    return p
end

function LS.RemovePlanet(p)
    for i, q in ipairs(LS.Planets) do
        if q == p then table.remove(LS.Planets, i) LS.Epoch = LS.Epoch + 1 return true end
    end
    return false
end

-- is a point inside a planet (a ball) or a cube environment (a box: the radius is the half edge)
local function inside(p, pos)
    if p.cube then
        local c, r = p.pos, p.radius
        return pos.x < c.x + r and pos.x > c.x - r and pos.y < c.y + r and pos.y > c.y - r and pos.z < c.z + r and pos.z > c.z - r
    end
    return pos:DistToSqr(p.pos) < p.radius * p.radius
end

function LS.PlanetAt(pos)
    for _, p in ipairs(LS.Planets) do
        if inside(p, pos) then return p end
    end
    return nil
end

-- planets: devices change them (all announce through the hook)
function LS.ChangeGas(planet, gas, amount)
    local key = gasKey(gas)
    amount = tonumber(amount)
    if not (planet and planet.air and key and amount) or amount == 0 then return 0 end
    local a = planet.air
    local moved
    if amount > 0 then
        moved = math.min(amount, a.empty)       -- gas needs free room (Spacebuild: the "empty" air)
        a.empty, a[key] = a.empty - moved, a[key] + moved
    else
        moved = -math.min(-amount, a[key])
        a[key], a.empty = a[key] + moved, a.empty - moved
    end
    if moved ~= 0 then announce(planet, true) end
    return moved
end

function LS.ConvertGas(planet, from, to, amount)
    local f, t = gasKey(from), gasKey(to)
    amount = tonumber(amount)
    if not (planet and planet.air and f and t and amount) or f == t or amount <= 0 then return 0 end
    local a = planet.air
    local moved = math.min(amount, a[f])
    if moved <= 0 then return 0 end
    a[f], a[t] = a[f] - moved, a[t] + moved
    announce(planet, true)
    return moved
end

-- breathing in a planet's air: oxygen becomes carbon dioxide (Spacebuild: Convert(O2, CO2, ...)); only a small
-- environment ever notices
function LS.Breathe(planet, amount)
    if not (planet and planet.air) or amount <= 0 then return 0 end
    local a = planet.air
    -- a big planet (over 5 million units of air: a radius of about 1500 and up) is endless: its oxygen is never used up. Else a planet
    -- the map sets at exactly 10 % oxygen (Endgame) would turn unbreathable after a few breaths
    if a.max > 5e6 then return 0 end
    local moved = math.min(amount, a.o2)
    if moved <= 0 then return 0 end
    a.o2, a.co2 = a.o2 - moved, a.co2 + moved
    announce(planet, false)
    return moved
end

function LS.SetPlanetGravity(planet, g)
    g = tonumber(g)
    if not planet or not g then return end
    g = math.max(g, 0)
    -- Spacebuild (ChangeGravity): the pressure follows the gravity; with a zero on either side it stays as it is
    if planet.gravity > 0 and g > 0 then planet.pressure = planet.pressure * (g / planet.gravity) end
    planet.gravity = g
    LS.Epoch = LS.Epoch + 1
    announce(planet, true)
end

function LS.SetPlanetTemperature(planet, low, high)
    low = tonumber(low)
    if not planet or not low then return end
    planet.tLow, planet.tHigh = low, tonumber(high) or low
    announce(planet, true)
end

-- artificial gravity round a device: players and props inside the radius feel g (1 = normal)
function LS.AddGravityZone(ent, radius, g)
    radius, g = tonumber(radius), tonumber(g)
    if not IsValid(ent) or not radius or not g or radius <= 0 then return false end
    LS.GravZones[ent] = { ent = ent, r = radius, r2 = radius * radius, g = math.max(g, 0) }
    LS.Epoch = LS.Epoch + 1
    return true
end

function LS.RemoveGravityZone(ent)
    if LS.GravZones[ent] then LS.GravZones[ent] = nil LS.Epoch = LS.Epoch + 1 end
end

-- the gravity of the smallest zone round pos (nil = none)
local function gravZoneAt(pos)
    local best, bestR
    for ent, z in pairs(LS.GravZones) do
        if not IsValid(ent) then LS.GravZones[ent] = nil LS.Epoch = LS.Epoch + 1
        elseif (not bestR or z.r < bestR) and pos:DistToSqr(ent:GetPos()) < z.r2 then best, bestR = z.g, z.r end
    end
    return best
end

local function shallow(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- the environment at a position: { name, breathable, gravity, temp (Kelvin), space, zone, planet, star, open, interior }
-- noZones: skip our life support areas (what it is like outside them; the climate control of the core uses it)
local function envAt(pos, noZones)
    for _, z in ipairs(noZones and {} or LS.Zones) do
        if IsValid(z.ent) and z.contains(pos) then
            return { name = z.ent.PrintName or "Life support", nameKey = z.ent.AGPNameKey, breathable = true, gravity = 1, temp = z.ent.LSZoneTemp or 293, space = false, zone = z.ent }
        end
    end
    for i = #LS.Interiors, 1, -1 do
        local it = LS.Interiors[i]
        if not IsValid(it.ent) then table.remove(LS.Interiors, i)
        elseif it.contains(pos) then
            local own = it.inside and it.inside(pos)   -- the ship's own life support (running: air, 20 C, gravity)
            if own then return own end
            local real = it.outside(pos)
            if real then
                local env = shallow(LS.EnvAt(real, noZones))
                env.gravity = 1   -- artificial gravity on board
                env.interior = it.ent
                return env
            end
        end
    end
    for _, p in ipairs(LS.Planets) do
        if inside(p, pos) then
            -- day side / night side: in the open sky it is the warm value, under a roof the cold one
            local tr = util.TraceLine({ start = pos + Vector(0, 0, 40), endpos = pos + Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY })
            return { name = p.name, breathable = p.breathable, gravity = p.gravity, temp = tr.HitSky and p.tHigh or p.tLow, space = false, planet = p, open = tr.HitSky }
        end
    end
    if #LS.Planets == 0 and cvSpace:GetInt() < 2 then
        return { name = "", breathable = true, gravity = 1, temp = 293, space = false }
    end
    -- space: cold, unless inside a star's heat zones (Spacebuild: hot in the middle, cooler outwards, nothing beyond its size)
    local temp, star = 3, nil
    if #LS.Stars > 0 and cvStars:GetBool() then
        for _, s in ipairs(LS.Stars) do
            local d = pos:Distance(s.pos)
            if d < starSize(s) then
                local t = starTemp(s, d)
                if t > temp then temp, star = t, s end
            end
        end
    end
    return { name = "Space", breathable = false, gravity = 0, temp = temp, space = true, star = star }
end

function LS.EnvAt(pos, noZones)
    local env = envAt(pos, noZones)
    if not noZones and next(LS.GravZones) then
        local g = gravZoneAt(pos)
        if g then env = shallow(env) env.gravity = g env.gravZone = true end
    end
    return env
end

-- only the gravity of a place, cheap (no sky trace): the props ask this a lot
function LS.GravityAt(pos, zonesOnly)   -- zonesOnly: the space simulation is off, only our areas / zones count
    if next(LS.GravZones) then
        local g = gravZoneAt(pos)
        if g then return g end
    end
    for _, z in ipairs(LS.Zones) do
        if IsValid(z.ent) and z.contains(pos) then return 1 end
    end
    for i = #LS.Interiors, 1, -1 do
        local it = LS.Interiors[i]
        if IsValid(it.ent) and it.contains(pos) then return 1 end
    end
    if zonesOnly then return 1 end
    for _, p in ipairs(LS.Planets) do
        if inside(p, pos) then return p.gravity end
    end
    if #LS.Planets == 0 and cvSpace:GetInt() < 2 then return 1 end
    return 0
end

-- for a probe device: what is the air, pressure, temperature and gravity at pos
-- (percent, Kelvin; a life support area and a plain map without planets have an Earth-like mix, space has none)
function LS.Probe(pos)
    local env = LS.EnvAt(pos)
    local r = { name = env.name or "", nameKey = env.nameKey, breathable = env.breathable == true, temperature = env.temp or 293, gravity = env.gravity or 1,
        space = env.space == true, o2 = 0, co2 = 0, n = 0, h = 0, pressure = 0 }
    if env.planet then
        local p = env.planet
        r.o2, r.co2, r.n, r.h = p.o2, p.co2, p.n, p.h
        r.pressure = LS.PlanetPressure(p)
    elseif not env.space then
        if env.breathable then r.o2, r.n, r.pressure = 21, 78, 1 else r.pressure = 1 end
    end
    return r
end

-- the suit ------------------------------------------------------------------------------------------------------
-- crush = Spacebuild's pressure rule (lifesupport.lua:433-460) scaled: its suit has 200 and ticks once a second, ours has
-- 100 and ticks every half second (air use over 1.5 pressure: pressure/5 of 200 a second = pressure/10 of 100 a second);
-- its damage is 50 per pressure over the limit a second, ours 30 (our empty-suit damage is 6 where Spacebuild's is 10: the
-- same 0.6 softening)
local RATE = { airDrain = 1.0, airRefill = 6, hurt = 6, energyCold = 1.2, coolantHot = 1.2, crushAir = 0.1, crushHurt = 30,
    burnHurt = 5, killTemp = 10000, crushLimit = 1.5 }

function LS.Suit(p)
    p.AGPSuit = p.AGPSuit or { air = 100, energy = 100, coolant = 100 }
    return p.AGPSuit
end

local function sync(p, s, env, drain, airOK, wet, mode)
    -- countdown: seconds until each one is empty at the current drain (-1 = not draining)
    for key, per in pairs(drain) do
        p:SetNWInt("agp_" .. key .. "_t", per > 0 and math.floor(s[key] / per) or -1)
    end
    p:SetNWFloat("agp_air", s.air)
    p:SetNWFloat("agp_energy", s.energy)
    p:SetNWFloat("agp_coolant", s.coolant)
    p:SetNWString("agp_env", env.nameKey or env.name or "")   -- (the key of a part's name, for the player's language): "ok" is
    -- whether you can breathe right now: a head under water is no good air, whatever the place is
    p:SetNWBool("agp_env_ok", airOK)
    p:SetNWInt("agp_env_temp", math.floor((env.temp or 293) - KELVIN + 0.5))   -- (rounded: 293 K showed as 19 C)
    p:SetNWBool("agp_ls_on", true)
    -- for the HUD's place line: 1 = full simulation, 2 = water only; wet = head under water; the air and pressure and
    -- gravity of the place (percent / pressure / g)
    p:SetNWInt("agp_ls_mode", mode)
    p:SetNWBool("agp_wet", wet)
    p:SetNWFloat("agp_env_grav", env.gravity or 1)
    local pl = env.planet
    if pl then
        p:SetNWFloat("agp_env_press", LS.PlanetPressure(pl))
        p:SetNWFloat("agp_env_o2", pl.o2); p:SetNWFloat("agp_env_co2", pl.co2); p:SetNWFloat("agp_env_n", pl.n); p:SetNWFloat("agp_env_h", pl.h)
    elseif env.space then
        p:SetNWFloat("agp_env_press", 0)
        p:SetNWFloat("agp_env_o2", 0); p:SetNWFloat("agp_env_co2", 0); p:SetNWFloat("agp_env_n", 0); p:SetNWFloat("agp_env_h", 0)
    else
        p:SetNWFloat("agp_env_press", 1)
        p:SetNWFloat("agp_env_o2", 21); p:SetNWFloat("agp_env_co2", 0); p:SetNWFloat("agp_env_n", 78); p:SetNWFloat("agp_env_h", 0)
    end
end

-- the sun as seen from pos: a star's position (the nearest), or far away along the env_sun's direction
local function sunTarget(pos)
    local best, bd
    for _, s in ipairs(LS.Stars) do
        local d = pos:DistToSqr(s.pos)
        if not bd or d < bd then best, bd = s.pos, d end
    end
    if best then return best end
    if LS.SunDir then return pos + LS.SunDir * 65536 end
end

-- a free line from the eyes to the sun (a hull, a roof or a prop in between shades)
local function sunlit(p, target)
    local tr = util.TraceLine({ start = p:EyePos(), endpos = target, mask = MASK_SOLID, filter = p })
    return tr.Fraction >= 1 or tr.HitSky
end

-- the weather of one player for one 0.5 s tick; `mode` 1 = the full simulation, 2 = water only
local WATER_ENV = { name = "", breathable = true, gravity = 1, temp = 293, space = false }
local function suitTick(p, mode, dt)
    local s = LS.Suit(p)
    local env
    if mode == 1 then env = LS.EnvAt(p:EyePos())
    else
        env = WATER_ENV
        if next(LS.GravZones) then
            local g = gravZoneAt(p:EyePos())
            if g then env = shallow(WATER_ENV) env.gravity = g end
        end
    end
    local drain = { air = 0, energy = 0, coolant = 0 }   -- per second
    local wet = p:WaterLevel() >= 3
    local shielded   -- asked once, when something wants it
    local function isShielded()
        if shielded == nil then shielded = (env.zone or env.interior) and true or hook.Run("AGP.LS.PlayerSealed", p) == true end
        return shielded
    end
    -- breathing: air drains where the air is not breathable (or under water), refills where it is
    -- AGP:: a player in a sealed ship breathes ship air under water. Asked through a hook so PowerGrid needs no
    -- ascension_gates (AGP.LS.PlayerSealed, see agp_ship_shield.lua). The same in space and in bad air: the pilot
    -- of a small sealed ship saw the countdown run there too (display only, pilots take no damage, but they
    -- stepped out with an empty suit) - asked, no objection. NOT aboard a ship that has its own life support and
    -- has it switched off (env.interior: the Ha'tak's deliberate "no air on board").
    --
    local sealed = (wet or not env.breathable) and (env.breathable or not env.interior)
        and hook.Run("AGP.LS.PlayerSealed", p) == true
    local airOK = sealed or (env.breathable and not wet)
    local planet = env.planet

    if mode == 1 then
        -- stars: the kill zone and sunburn (nothing in a ship / a life support area)
        if cvStars:GetBool() and (env.temp or 0) > RATE.killTemp and not isShielded() then   -- over 10000 K: the kill zone
            p:KillSilent()
            return
        end
        if cvStars:GetBool() and (env.star or (planet and planet.sunburn and env.open)) and not isShielded() then
            local sun = env.star and env.star.pos or sunTarget(p:EyePos())
            if sun and sunlit(p, sun) then
                local d = DamageInfo()
                d:SetDamage(RATE.burnHurt * dt)
                d:SetDamageType(DMG_BURN)
                d:SetAttacker(game.GetWorld()); d:SetInflictor(game.GetWorld())
                p:TakeDamageInfo(d)
                if (p.AGPLSBurnSound or 0) < CurTime() then p.AGPLSBurnSound = CurTime() + 1 p:EmitSound("HL2Player.BurnPain") end
            end
        end
        -- pressure: the suit's air copes with it, with the air gone it crushes (nothing in a ship / a life support area)
        if cvPressure:GetBool() and planet and not isShielded() then
            local over = LS.PlanetPressure(planet) - RATE.crushLimit
            if over > 0 then
                local need = over * RATE.crushAir * dt
                local dmg = 0
                if s.air <= 0 then dmg = RATE.crushHurt * over * dt
                elseif s.air < need then dmg = (s.air / need) * (over + 1) * RATE.crushHurt * dt s.air = 0
                else s.air = s.air - need end
                if dmg > 0 then
                    local d = DamageInfo()
                    d:SetDamage(dmg)
                    d:SetDamageType(DMG_CRUSH)
                    d:SetAttacker(game.GetWorld()); d:SetInflictor(game.GetWorld())
                    p:TakeDamageInfo(d)
                    if not p:Alive() then return end
                end
            end
        end
    end

    if airOK then
        local before = s.air
        s.air = math.min(100, s.air + RATE.airRefill * dt)
        -- the air of a planet is used up by breathing (its oxygen turns into carbon dioxide): 5 a second, plus what the
        -- suit took in (Spacebuild units: 2 per suit percent). Not the ship's air (our core pays for that)
        if planet and not env.interior and not wet and not sealed and cvGasUse:GetBool() then
            LS.Breathe(planet, 5 * dt + (s.air - before) * 2)
        end
    else
        s.air = math.max(0, s.air - RATE.airDrain * dt)
        drain.air = RATE.airDrain
    end
    -- temperature: cold costs suit energy (heating), heat costs coolant
    local t = sealed and 293 or (env.temp or 293)   -- (a sealed cabin is warm: no cold / heat drain either)
    if t < 263 then
        drain.energy = RATE.energyCold * math.Clamp((263 - t) / 100, 0.3, 3)
        s.energy = math.max(0, s.energy - drain.energy * dt)
    elseif t > 310 then
        drain.coolant = RATE.coolantHot * math.Clamp((t - 310) / 100, 0.3, 3)
        s.coolant = math.max(0, s.coolant - drain.coolant * dt)
    end
    -- empty suit: damage
    local hurt = (s.air <= 0 and 1 or 0) + ((s.energy <= 0 and t < 263) and 1 or 0) + ((s.coolant <= 0 and t > 310) and 1 or 0)
    if hurt > 0 then
        local d = DamageInfo()
        d:SetDamage(RATE.hurt * hurt * dt)
        d:SetDamageType(s.air <= 0 and DMG_DROWN or (t < 263 and DMG_FREEZE or DMG_BURN))
        d:SetAttacker(game.GetWorld()); d:SetInflictor(game.GetWorld())
        p:TakeDamageInfo(d)
    end
    -- gravity (0 means "default" in GMod, so a tiny value for space). Water only: the map's own gravity stays, only a
    -- gravity zone (a device) changes it
    if mode == 1 or env.gravZone then
        p:SetGravity(math.max(env.gravity or 1, 0.0001))
        p.AGPLSGrav = true
    elseif p.AGPLSGrav then
        p:SetGravity(1)
        p.AGPLSGrav = nil
    end
    sync(p, s, env, drain, airOK, wet, mode)
end

-- noclip in space (Spacebuild's three rules, one setting): who may be in noclip where there is no planet
local function noclipAllowed(p)
    local m = cvNoclip:GetInt()
    if m <= 0 then return true end
    if m == 1 then return p:IsAdmin() or p:IsSuperAdmin() end
    if m == 2 then return p:IsSuperAdmin() end
    return false
end

-- only where the full simulation runs on a map with planets (Spacebuild: SB_InSpace); inside our areas and on planets noclip is free
local function noclipRuleOn() return LS.Mode() == 1 and #LS.Planets > 0 and cvNoclip:GetInt() > 0 end
function LS.NoclipBlocked(p)
    return noclipRuleOn() and not noclipAllowed(p) and LS.EnvAt(p:GetPos()).space == true
end

hook.Add("PlayerNoClip", "AGP.LS.Noclip", function(p, on)
    if on and LS.NoclipBlocked(p) then return false end
end)

local nextTick, lastMode = 0, nil
hook.Add("Think", "AGP.LS.Suit", function()
    if CurTime() < nextTick then return end
    nextTick = CurTime() + 0.5
    local mode = LS.Mode()
    -- Spacebuild starting / stopping (or a setting) changed what runs: the planet colours follow (none while it is not ours)
    if lastMode ~= nil and mode ~= lastMode and (mode == 1 or lastMode == 1) and LS.SendFX then LS.SendFX() end
    lastMode = mode
    for _, p in ipairs(player.GetAll()) do
        if mode == 0 then
            if p.AGPLSWasOn then
                p.AGPLSWasOn = nil
                if p.AGPLSGrav then p:SetGravity(1) p.AGPLSGrav = nil end
                p:SetNWBool("agp_ls_on", false)
            end
        elseif p:Alive() then
            local seated = p:InVehicle()
            -- already flying when it became space (not a seated player - in a seat GMod reports noclip too)
            if not seated and p:GetMoveType() == MOVETYPE_NOCLIP and LS.NoclipBlocked(p) then p:SetMoveType(MOVETYPE_WALK) end
            if p:GetMoveType() ~= MOVETYPE_NOCLIP or (seated and mode == 1 and cvSeats:GetBool()) then
                p.AGPLSWasOn, p.AGPLSIdle = true, nil
                suitTick(p, mode, 0.5)
            elseif p.AGPLSWasOn and not p.AGPLSIdle then
                -- (bug hunt): the suit does not run in noclip, but the last countdown stayed on the screen, frozen
                p.AGPLSIdle = true
                for _, key in ipairs({ "air", "energy", "coolant" }) do p:SetNWInt("agp_" .. key .. "_t", -1) end
            end
        end
    end
end)

hook.Add("PlayerSpawn", "AGP.LS.Suit", function(p)
    p.AGPSuit = { air = 100, energy = 100, coolant = 100 }
end)

-- sb_dev_tree (a tree of the map): turns carbon dioxide into oxygen, `rate` units a second, in the planet it stands in
-- (Spacebuild: nature_dev_tree; no map of this Workshop collection has one, so this is only code-tested)
timer.Create("AGP.LS.Trees", 1, 0, function()
    if #LS.Trees == 0 or LS.Mode() ~= 1 then return end
    for _, t in ipairs(LS.Trees) do
        local p = t.rate > 0 and LS.PlanetAt(t.pos)
        if p then
            local left = t.rate - LS.ConvertGas(p, "co2", "o2", t.rate)
            if left > 0 and p.o2 < 10 then left = left - LS.ConvertGas(p, "n", "o2", left) end
            if left > 0 and p.o2 < 10 then LS.ConvertGas(p, "h", "o2", left) end
        end
    end
end)

-- refill (Suit Dispenser): takes oxygen / energy / water from the network of `from`
function LS.Refill(p, from)
    local s = LS.Suit(p)
    local got = false
    for key, res in pairs({ air = "oxygen", energy = "energy", coolant = "water" }) do
        local need = 100 - s[key]
        if need > 0.5 and IsValid(from) and from.GetResource then
            local cost = need * 100   -- 100 units of a resource per suit percent
            local have = from:GetResource(res)
            local take = math.min(cost, have)
            if take > 0 then
                from:ConsumeResource(res, take)
                s[key] = s[key] + take / 100
                got = true
            end
        end
    end
    return got
end

-- planet colour and bloom for the clients (planet_color / planet_bloom of the map): only where our simulation runs
util.AddNetworkString("agp_ls_fx")
function LS.SendFX(ply)
    local list = LS.Mode() == 1 and LS.FX or {}
    net.Start("agp_ls_fx")
    net.WriteUInt(#list, 8)
    for _, f in ipairs(list) do
        net.WriteVector(f.pos)
        net.WriteFloat(f.radius)
        net.WriteBool(f.cube == true)
        net.WriteBool(f.color ~= nil)
        if f.color then for i = 1, 9 do net.WriteFloat(f.color[i]) end end
        net.WriteBool(f.bloom ~= nil)
        if f.bloom then for i = 1, 9 do net.WriteFloat(f.bloom[i]) end end
    end
    if ply then net.Send(ply) else net.Broadcast() end
end
hook.Add("PlayerInitialSpawn", "AGP.LS.FX", function(p) timer.Simple(5, function() if IsValid(p) then LS.SendFX(p) end end) end)
for _, name in ipairs({ "agp_ls_space", "agp_ls_backend", "agp_ls_water" }) do
    cvars.AddChangeCallback(name, function() timer.Simple(0.2, function() LS.SendFX() end) end, "AGP.LS.FX")
end

-- Stargate tie-in: when a gate dials, everyone near it gets a report of the other side (like sending a MALP first)
util.AddNetworkString("agp_ls_gate")
local cvReport = CreateConVar("agp_ls_gate_report", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Ascension Gates life support: report of the other side when a gate dials (0 = off)", 0, 1)
hook.Add("StarGate.Dial", "AGP.LS.GateReport", function(gate, target)
    if not cvReport:GetBool() or not LS.Active() or not IsValid(gate) or not IsValid(target) then return end
    local env = LS.EnvAt(target:GetPos() + target:GetForward() * 90)
    local recv = {}
    for _, p in ipairs(player.GetAll()) do
        if p:GetPos():DistToSqr(gate:GetPos()) < 1500 * 1500 then recv[#recv + 1] = p end
    end
    if #recv == 0 then return end
    LS.LastReport = CurTime()
    net.Start("agp_ls_gate")
    net.WriteString(env.nameKey or env.name ~= "" and env.name or (target.GetGateName and target:GetGateName() or "") or "")
    net.WriteBool(env.breathable == true)
    net.WriteInt(math.floor((env.temp or 293) - KELVIN), 16)
    net.WriteFloat(env.gravity or 1)
    net.WriteBool(env.space == true)
    net.Send(recv)
end)

-- a StarCore ship with a running Life Support Core aboard is closed: whoever is inside it (in a seat or standing in it)
-- breathes ship air under water, like in our sealed Ascension Gates ships (AGP.LS.PlayerSealed, agp_ship_shield.lua) and
-- SpaceGrid hulls. A core without a ship (a bubble) stays open to water. Also keeps the engine's own drowning off those
-- players.
function LS.InCoreShip(ply)
    if not IsValid(ply) then return false end
    local pos = ply:EyePos()
    for _, z in ipairs(LS.Zones) do
        local e = z.ent
        if IsValid(e) and e.LSShip and e:LSShip() and z.contains(pos) then return true end
    end
    return false
end
hook.Add("AGP.LS.PlayerSealed", "PowerGrid.CoreShipSealed", function(ply)
    if LS.InCoreShip(ply) then return true end
end)
hook.Add("EntityTakeDamage", "PowerGrid.CoreShipNoDrown", function(ply, dmg)
    if not (IsValid(ply) and ply:IsPlayer() and dmg:IsDamageType(DMG_DROWN)) then return end
    if ply:WaterLevel() >= 3 and LS.InCoreShip(ply) then return true end
end)
