-- PowerGrid: gravity for loose physics props (2026-11-14, setting agp_ls_prop_gravity, default 1).
-- Where the space simulation runs: a prop in space has no gravity and no air drag, on a planet it has the planet's gravity,
-- inside one of our life support areas / ship interiors / gravity zones it has normal (or the zone's) gravity.
-- Spacebuild checks EVERY entity against every planet every second. This does not.
-- (Water-only mode: only gravity zone devices work on props, nothing else.)
--
--   * only physics props / ragdolls are followed (class list), found when they are created; nothing at all is done on a map
--     without planets (unless a gravity zone device stands there)
--   * a small batch per 0.2 s tick (at least 25 entities, or all of them in about 8 s); an entity is looked at again only when it
--     moved to another 64-unit cell, when something changed that can change its gravity (LS.Epoch: a planet's gravity, a
--     zone, a life support area switching on), or after 8 s at the latest; one that did not move costs one GetPos
--   * a constrained contraption is decided as a whole: the gravity at its heaviest part is given to every part
--   * a gravity that is not 0 and not about 1 (a moon with 0.3 g) is made by a small push on awake props 20 times a second
-- Left alone on purpose (they fly or fall by their own code):
--   * everything a StarCore ship consists of (StarCore.Cores[..].Parts: the helm turns the ship's gravity off while it flies)
--   * the Ha'tak and its parts, sg_vehicle_* ships and anything constrained to one
--   * entities with ent.IgnoreGravity = true (Spacebuild's convention; the gravity controller sets it)
--   * entities inside an event horizon (it keeps their gravity in EventHorizon.GravBuffer)
--   * everything that is not a prop (projectiles, drones ... set their own gravity): only prop_physics*, prop_ragdoll
AGP = AGP or {}
AGP.LS = AGP.LS or {}
local LS = AGP.LS

local cvProps = CreateConVar("agp_ls_prop_gravity", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "PowerGrid life support: 1 = loose props and contraptions have no gravity and no air drag in space, a planet's gravity on a planet", 0, 1)

local CLASSES = { prop_physics = true, prop_physics_multiplayer = true, prop_physics_override = true, prop_ragdoll = true }
local CELL_SCALE = 1 / 64
local RECHECK = 8        -- seconds: every entity is looked at again after this at the latest
local BATCH_MIN = 25
local TICK = 0.2
local PUSH_TICK = 0.05

local list, cursor = {}, 1
local scaled = {}        -- ent -> g: props whose gravity is a value between (a push makes it)
local touched = {}       -- every entity we changed (contraption members too), to put them back
local zonesOnly = false  -- water-only mode: only gravity zones count, no planets / space
local on = false
local shipParts = {}
local stats = LS.PropStats or { checks = 0, evals = 0, seconds = 0 }
LS.PropStats = stats

local function cellOf(pos)
    -- three integers packed in one number (cells are 64 units: +-1024 cells = +-65536 units, more than any map)
    return (math.floor(pos.x * CELL_SCALE) + 1024) * 4194304 + (math.floor(pos.y * CELL_SCALE) + 1024) * 2048 + (math.floor(pos.z * CELL_SCALE) + 1024)
end

local function eligible(ent)
    return IsValid(ent) and CLASSES[ent:GetClass()] == true
end

-- should the whole group stay as it is (ships and what they fly with)?
local function excluded(ent)
    if ent.IgnoreGravity == true or shipParts[ent] then return true end
    local c = ent:GetClass()
    if c == "agp_hatak" or c == "agp_hatak_interior" or c == "starcore" or c:sub(1, 11) == "sg_vehicle_" then return true end
    local eh = EventHorizon
    if eh and eh.GravBuffer and eh.GravBuffer[ent:EntIndex()] ~= nil then return true end
    return false
end

local function refreshShips()
    shipParts = {}
    for core in pairs(StarCore and StarCore.Cores or {}) do
        if IsValid(core) then
            shipParts[core] = true
            for _, e in ipairs(core.Parts or {}) do if IsValid(e) then shipParts[e] = true end end
        end
    end
    for _, h in ipairs(ents.FindByClass("agp_hatak")) do
        shipParts[h] = true
        for _, e in ipairs(h.Parts or {}) do if IsValid(e) then shipParts[e] = true end end
    end
end

-- set gravity flag + drag of every physics object of ent to the wanted g
local function apply(ent, g)
    local was = ent.AGPPGg or 1
    if g == was then return end
    ent.AGPPGg = g
    touched[ent] = true
    local zero = g <= 0.02
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local ph = ent:GetPhysicsObjectNum(i)
        if IsValid(ph) then
            ph:EnableGravity(not zero)
            ph:EnableDrag(not zero)
        end
    end
    if not zero and math.abs(g - 1) >= 0.05 and ent:GetClass() ~= "prop_ragdoll" then scaled[ent] = g else scaled[ent] = nil end
end

local function restore(ent)
    if ent.AGPPGg and ent.AGPPGg ~= 1 then
        ent.AGPPGg = 1
        for i = 0, ent:GetPhysicsObjectCount() - 1 do
            local ph = ent:GetPhysicsObjectNum(i)
            if IsValid(ph) then ph:EnableGravity(true) ph:EnableDrag(true) end
        end
    end
    ent.AGPPGg = nil
    -- (forget when it was last looked at: switched on again, it must be decided at once - the game test found it skipped for 8 s, 2026-11-14)
    ent.AGPPGCell, ent.AGPPGT, ent.AGPPGEpoch = nil, nil, nil
    scaled[ent] = nil
    touched[ent] = nil
end

local function restoreAll()
    for ent in pairs(touched) do if IsValid(ent) then restore(ent) end end
    touched, scaled = {}, {}
end

local function rebuild()
    list, cursor = {}, 1
    for _, ent in ipairs(ents.GetAll()) do
        if eligible(ent) then list[#list + 1] = ent end
    end
end

-- decide one entity (and its contraption)
local function evaluate(ent, now)
    stats.evals = stats.evals + 1
    local members = { ent }
    if ent:IsConstrained() then
        local all = constraint.GetAllConstrainedEntities(ent)
        if all then
            members = {}
            for _, m in pairs(all) do if IsValid(m) and not m:IsWorld() then members[#members + 1] = m end end
            if #members == 0 then members = { ent } end
        end
    end
    local skip = false
    for _, m in ipairs(members) do
        if excluded(m) then skip = true break end
    end
    -- the anchor: the heaviest member (ties: the lowest index) decides for all
    local anchor, best = ent, -1
    for _, m in ipairs(members) do
        local ph = m:GetPhysicsObject()
        local mass = IsValid(ph) and ph:GetMass() or 0
        if mass > best or (mass == best and m:EntIndex() < anchor:EntIndex()) then anchor, best = m, mass end
    end
    local g = skip and 1 or LS.GravityAt(anchor:GetPos(), zonesOnly)
    if math.abs(g - 1) < 0.05 then g = 1 end
    local epoch = LS.Epoch
    for _, m in ipairs(members) do
        if skip then restore(m) elseif IsValid(m:GetPhysicsObject()) then apply(m, g) end
        m.AGPPGCell, m.AGPPGT, m.AGPPGEpoch = cellOf(m:GetPos()), now, epoch
    end
end

local zoneSig = ""
local nextSlow, nextBatch, nextPush = 0, 0, 0
local lastPush = 0

hook.Add("OnEntityCreated", "AGP.LS.Props", function(ent)
    if on and CLASSES[ent:GetClass()] then list[#list + 1] = ent end
end)

hook.Add("Think", "AGP.LS.Props", function()
    local now = CurTime()
    if now >= nextSlow then
        nextSlow = now + 0.5
        -- on or off: our space simulation runs, the setting is on, there are planets (or a gravity zone device stands somewhere)
        local mode = LS.Mode()
        local want = cvProps:GetBool() and ((mode == 1 and #LS.Planets > 0) or (mode ~= 0 and next(LS.GravZones) ~= nil))
        zonesOnly = mode ~= 1
        if want and not on then on = true LS.Epoch = LS.Epoch + 1 rebuild()
        elseif not want and on then on = false restoreAll() list = {} end
        if on then
            refreshShips()
            -- a life support area switching on or off changes the gravity of everything inside it
            local sig = #LS.Zones .. "|" .. #LS.Interiors
            for _, z in ipairs(LS.Zones) do if IsValid(z.ent) then sig = sig .. "," .. z.ent:EntIndex() end end
            if sig ~= zoneSig then zoneSig = sig LS.Epoch = LS.Epoch + 1 end
        end
    end
    if not on then return end

    if now >= nextBatch then
        nextBatch = now + TICK
        local t0 = SysTime()
        local n = #list
        local size = math.max(BATCH_MIN, math.ceil(n / 40))
        local epoch = LS.Epoch
        local i = 0
        while i < size and n > 0 do
            i = i + 1
            if cursor > n then cursor = 1 end
            local ent = list[cursor]
            if not IsValid(ent) then
                list[cursor] = list[n]
                list[n] = nil
                n = n - 1
            else
                cursor = cursor + 1
                stats.checks = stats.checks + 1
                if IsValid(ent:GetPhysicsObject()) then
                    local cell = cellOf(ent:GetPos())
                    if ent.AGPPGCell ~= cell or ent.AGPPGEpoch ~= epoch or now - (ent.AGPPGT or 0) >= RECHECK then
                        evaluate(ent, now)
                    end
                end
            end
        end
        stats.seconds = stats.seconds + (SysTime() - t0)
    end

    -- props that should fall slower or faster than the engine makes them: a small push (20 times a second, only awake ones)
    if now >= nextPush and next(scaled) ~= nil then
        local dt = now - lastPush
        nextPush = now + PUSH_TICK
        lastPush = now
        if dt > 0.5 then dt = PUSH_TICK end
        local t0 = SysTime()
        local pull = -physenv.GetGravity().z   -- 600
        for ent, g in pairs(scaled) do
            if not IsValid(ent) then scaled[ent] = nil
            else
                local ph = ent:GetPhysicsObject()
                if IsValid(ph) and not ph:IsAsleep() and ph:IsMotionEnabled() then ph:AddVelocity(Vector(0, 0, (1 - g) * pull * dt)) end
            end
        end
        stats.seconds = stats.seconds + (SysTime() - t0)
    elseif next(scaled) == nil then
        -- (only while nothing is pushed: before, this ran on every frame between two pushes, so a push made up for one frame
        -- instead of 0.05 s and a 0.6 g moon pulled like 0.9 g - found in the game test 2026-11-14)
        lastPush = now
    end
end)

-- a map cleanup removes every prop: start the list again
hook.Add("PostCleanupMap", "AGP.LS.Props", function()
    list, cursor, scaled, touched = {}, 1, {}, {}
    if on then timer.Simple(1.5, rebuild) end
end)

-- for the self-test: how many are followed
function LS.PropCount() return #list, on end
