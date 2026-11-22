-- PowerGrid: the network itself, used instead of Spacebuild/RD when that is not installed (or always,
-- agp_power_backend 1). PowerGrid's parts reach it through sv_bridge.lua; Ascension Gates' entities through its
-- StarGate.WireRD (AddResource, GetResource, ConsumeResource, SupplyResource ...), which hands off to AGP.Power.
--   agp_power_mode 1 = manual: parts share power only when linked (Grid Power Connector tool, power node)
--                  2 = automatic: everything welded/constrained together shares power
--                  3 = mix: both
-- A network = all parts reachable over links (and constraints in mode 2/3). Each part keeps its own storage
-- (ent.AGPRes[resource] = { max, amount }); the network adds them up.
AGP = AGP or {}
AGP.Power = AGP.Power or {}
local P = AGP.Power

P.Parts = P.Parts or {}   -- every entity with resources or links
P.Version = (P.Version or 0) + 1

-- (code review): "Off (free energy)" takes effect after a map change (the settings page says so); switched while the
-- network runs it cut every network at once (no links, no welds counted) - until then the last mode counts
local lastMode
local function mode()
    local cv = GetConVar("agp_power_mode")
    local m = cv and cv:GetInt() or 1
    if m == 0 and PowerGrid.Active then return lastMode or 1 end
    if m ~= 0 then lastMode = m end
    return m
end

-- AGP: links count in Manual (1) and Mix (3) mode only. Automatic (2) means "welded, constrained or parented together
-- shares" - links counting there too would make it the same as Mix. So in Automatic mode the Connector tool says how
-- it works there instead of "Linked N parts", the power node does not link, and no cables are drawn (links that
-- exist stay and count again after a switch to Manual / Mix).
function P.LinksUsed() local m = mode() return m == 1 or m == 3 end

local function valid(e) return IsValid(e) and P.Parts[e] end

-- AGP: a link counts only when both parts name each other (P.Link always sets both sides). The duplicator copies a
-- part's whole table, so a pasted part came with the ORIGINAL's link list: one-sided, now ignored everywhere
local function linked(a, b) return IsValid(b) and b.AGPLinks ~= nil and b.AGPLinks[a] == true end

-- AGP: a linked part carries its links in its dupe info ("agp_power_links": its own EntIndex and those of its
-- partners), written whenever its links change, so every copy and save has them - for our parts and for
-- Ascension Gates' entities alike (only our parts get a call when they are copied)
local function storeLinks(e)
    if not IsValid(e) then return end
    duplicator.ClearEntityModifier(e, "agp_power_links")
    local ids = {}
    for o in pairs(e.AGPLinks or {}) do if linked(e, o) then ids[#ids + 1] = o:EntIndex() end end
    if #ids > 0 then duplicator.StoreEntityModifier(e, "agp_power_links", { id = e:EntIndex(), links = ids }) end
end
P.StoreLinks = storeLinks

-- links ----------------------------------------------------------------------------------------------------------
util.AddNetworkString("agp_power_links")

-- AGP (the author's wish): a player can hide the cables of their parts from the other players
-- (agp_power_cables_share 0, sent with their player info). Each player gets the list without the cables at a part
-- whose owner hides them; the cables of their own parts always come. Owner as for linking: CPPI, else the spawner.
local function partOwner(e)
    if e.CPPIGetOwner then
        local o = e:CPPIGetOwner()
        if IsValid(o) then return o end
    end
    local c = e.GetCreator and e:GetCreator()
    if IsValid(c) then return c end
    local o = e.Owner
    if IsValid(o) and o.IsPlayer and o:IsPlayer() then return o end
end
local function hidingOwner(e)
    local o = partOwner(e)
    -- only a real player's explicit "0" hides (a bot has no player info: GetInfoNum gave 0, which hid every bot's cables)
    if IsValid(o) and o:IsPlayer() and not o:IsBot() and o:GetInfo("agp_power_cables_share") == "0" then return o end
end
-- the cables one player gets to see, out of the full list of linked pairs
function P.CableListFor(viewer, pairsList)
    local list, hiding = {}, {}
    local function ok(e)
        if hiding[e] == nil then hiding[e] = hidingOwner(e) or false end
        return hiding[e] == false or hiding[e] == viewer
    end
    for _, pr in ipairs(pairsList) do
        if ok(pr[1]) and ok(pr[2]) then list[#list + 1] = pr end
    end
    return list
end

-- clients draw the links as cables: send the whole list (small) when it changes
local function sendLinks(target)
    local pairsList, seen = {}, {}
    for e in pairs(P.LinksUsed() and P.Parts or {}) do   -- AGP: Automatic mode: links do nothing, no cables
        if IsValid(e) and e.AGPLinks then
            for o in pairs(e.AGPLinks) do
                if linked(e, o) then   -- AGP: (was IsValid: a pasted ship drew cables to the original)
                    local a, b = e:EntIndex(), o:EntIndex()
                    local key = math.min(a, b) .. ":" .. math.max(a, b)
                    if not seen[key] then seen[key] = true; pairsList[#pairsList + 1] = { e, o } end
                end
            end
        end
    end
    P.LastCablePairs = pairsList
    local function send(ply)
        local list = P.CableListFor(ply, pairsList)
        net.Start("agp_power_links")
        net.WriteUInt(#list, 14)
        -- AGP: entity numbers (the client looks them up while drawing, so parts outside its PVS get their cable when
        -- they come into view; with WriteEntity they arrived as NULL and stayed that way)
        for _, pr in ipairs(list) do net.WriteUInt(pr[1]:EntIndex(), 16); net.WriteUInt(pr[2]:EntIndex(), 16) end
        net.Send(ply)
    end
    if target then send(target) else for _, ply in ipairs(player.GetHumans()) do send(ply) end end
end
P.SendLinks = sendLinks
hook.Add("PlayerInitialSpawn", "AGP.Power.Links", function(p) timer.Simple(3, function() if IsValid(p) then sendLinks(p) end end) end)
-- AGP: a joining client also asks for the list once its map is loaded (the 3 s timer can come before its Lua is
-- ready on a slow join: the message was lost); at most every 2 s per player
net.Receive("agp_power_links", function(_, ply)
    -- AGP: true = the player switched "Others see my cables": everyone gets a new list (at most one send every half
    -- second, however often it is asked)
    if net.ReadBool() then
        if not timer.Exists("AGP.Power.SendLinks") then timer.Create("AGP.Power.SendLinks", 0.5, 1, function() sendLinks() end) end
        return
    end
    if not IsValid(ply) or (ply.AGPPowerLinksAsked or 0) > CurTime() then return end
    ply.AGPPowerLinksAsked = CurTime() + 2
    sendLinks(ply)
end)

local function touch()
    P.Version = P.Version + 1
    timer.Create("AGP.Power.SendLinks", 0.2, 1, function() sendLinks() end)
end
-- AGP: the mode is read live: a switch rebuilds the networks at once and shows / hides the cables
cvars.AddChangeCallback("agp_power_mode", function() touch() end, "AGP.Power.Mode")

-- AGP: a pasted part can arrive with the ORIGINAL's tables: GMod's duplicator merges the entity table shallowly,
-- so a part that had no storage / link list of its own yet got the original's by reference. Copy and original
-- then shared one storage (the copy drained the original's energy - audit test) and one link list. Every table is
-- noted with the part it belongs to; a part found holding another live part's table gets its own copy.
local owner = setmetatable({}, { __mode = "kv" })
local function ownTable(e, key)
    local t = e[key]
    if not t then return end
    local o = owner[t]
    if o ~= e then
        if o ~= nil and IsValid(o) then t = table.Copy(t); e[key] = t end
        owner[t] = e
    end
end
P.OwnTables = function(e)
    ownTable(e, "AGPRes"); ownTable(e, "AGPLinks")
    -- the stored resources inside too (a part that had none of a resource yet got the original's entry itself)
    for _, k in ipairs(table.GetKeys(e.AGPRes or {})) do
        local r = e.AGPRes[k]
        if istable(r) then
            local o = owner[r]
            if o ~= e then
                if o ~= nil and IsValid(o) then r = table.Copy(r); e.AGPRes[k] = r end
                owner[r] = e
            end
        end
    end
end

-- AGP: a pasted part checks its tables right after the duplicator filled it in (the networks are cached for a second,
-- so the check in P.Network alone came too late: the copy's ZPM still drained the original's)
hook.Add("OnEntityCreated", "AGP.Power.OwnTables", function(e)
    timer.Simple(0, function()
        if IsValid(e) and (e.AGPRes or e.AGPLinks) then P.OwnTables(e) end
    end)
end)

function P.Register(e)
    if not IsValid(e) then return end
    P.Parts[e] = true
    e.AGPRes = e.AGPRes or {}
    e.AGPLinks = e.AGPLinks or {}
    P.OwnTables(e)
end

function P.Link(a, b)
    if not IsValid(a) or not IsValid(b) or a == b then return false end
    P.Register(a); P.Register(b)
    a.AGPLinks[b] = true
    b.AGPLinks[a] = true
    storeLinks(a); storeLinks(b)   -- AGP: dupe info
    touch()
    return true
end

function P.Unlink(a, b)
    if valid(a) and a.AGPLinks then a.AGPLinks[b] = nil; storeLinks(a) end   -- AGP: dupe info
    if valid(b) and b.AGPLinks then b.AGPLinks[a] = nil; storeLinks(b) end
    touch()
end

-- AGP: a part that is removed leaves the dupe info alone (its own and its partners'): the duplicator tool keeps the
-- copied tables by reference, so copy - remove the ship - paste lost the links otherwise. An outdated index left
-- behind never links a stranger: a paste links only parts that both name each other
local function unlinkAll(e, removing)
    if not valid(e) then return end
    for o in pairs(e.AGPLinks or {}) do
        if IsValid(o) and o.AGPLinks then
            o.AGPLinks[e] = nil
            if not removing then storeLinks(o) end
        end
    end
    e.AGPLinks = {}
    if not removing then storeLinks(e) end
    touch()
end

function P.UnlinkAll(e) unlinkAll(e, false) end

function P.Remove(e)
    if not P.Parts[e] then return end
    unlinkAll(e, true)
    P.Parts[e] = nil
    touch()
end
hook.Add("EntityRemoved", "AGP.Power.Remove", function(e) if P.Parts[e] then P.Remove(e) end end)

-- networks -------------------------------------------------------------------------------------------------------
-- cached per part for a short time (parts call Get/Consume every think); links/removals invalidate at once
local cache = {}

-- AGP: the walk itself, also for P.Connected: { ents = parts with resources, all = everything it reached }
local function walk(e)
    local c = cache[e]
    if c and c.version == P.Version and c.time > CurTime() - 1 then return c end
    local m = mode()
    local ents, seen, queue = {}, { [e] = true }, { e }
    local head = 1
    while head <= #queue do
        local x = queue[head]; head = head + 1
        if IsValid(x) then
            P.OwnTables(x)   -- AGP: never a storage shared with a copy
            ents[#ents + 1] = x
            local nb = {}
            -- a closed pump/valve separates the networks: nothing flows through it
            local closed = x.AGPPump and not x.AGPPumpOn
            if not closed and (m == 1 or m == 3) then for o in pairs(x.AGPLinks or {}) do if linked(x, o) then nb[#nb + 1] = o end end end   -- AGP: both sides
            if not closed and (m == 2 or m == 3) then
                -- (code review): only the parts directly constrained to this one - GetAllConstrainedEntities gave the whole
                -- contraption, so a closed valve between two welded halves separated nothing
                for _, c in ipairs(constraint.GetTable(x) or {}) do
                    for _, en in pairs(c.Entity or {}) do
                        local o = en.Entity
                        if IsValid(o) and o ~= x then nb[#nb + 1] = o end
                    end
                end
                if IsValid(x:GetParent()) then nb[#nb + 1] = x:GetParent() end
                for _, ch in ipairs(x:GetChildren()) do nb[#nb + 1] = ch end
            end
            for _, o in ipairs(nb) do
                if IsValid(o) and not seen[o] then seen[o] = true; queue[#queue + 1] = o end
            end
            if #queue > 4000 then break end
        end
    end
    local list = {}
    for _, x in ipairs(ents) do if x.AGPRes and next(x.AGPRes) then list[#list + 1] = x end end
    local t = { version = P.Version, time = CurTime(), ents = list, all = ents }
    for _, x in ipairs(ents) do cache[x] = t end
    return t
end

function P.Network(e) return walk(e).ents end
hook.Add("EntityRemoved", "AGP.Power.CacheDrop", function(e) cache[e] = nil end)   -- the cache kept removed parts

-- the RD-style functions (sv_bridge.lua, and Ascension Gates' StarGate.WireRD) -------------------------------------------------------
function P.AddResource(self, res, max, default)
    local e = isentity(self) and self or self.Entity   -- AGP: a pasted copy's self.Entity can be the original
    P.Register(e)
    local r = e.AGPRes[res]
    if r then
        r.max = max or 0
        r.amount = math.min(r.amount, r.max)
    else
        e.AGPRes[res] = { max = max or 0, amount = math.min(default or 0, max or 0) }
        P.OwnTables(e)   -- AGP: the new entry belongs to this part from the start
    end
    touch()
end

function P.GetResource(self, res, default)
    local e = isentity(self) and self or self.Entity   -- AGP: a pasted copy's self.Entity can be the original
    if not P.Parts[e] then return default or 0 end
    local sum = 0
    for _, x in ipairs(P.Network(e)) do
        local r = x.AGPRes[res]
        if r then sum = sum + r.amount end
    end
    return sum
end

function P.GetUnitCapacity(self, res, default)
    local e = isentity(self) and self or self.Entity   -- AGP: a pasted copy's self.Entity can be the original
    local r = e.AGPRes and e.AGPRes[res]
    return r and r.max or (default or 0)
end

function P.GetNetworkCapacity(self, res, default)
    local e = isentity(self) and self or self.Entity   -- AGP: a pasted copy's self.Entity can be the original
    if not P.Parts[e] then return default or 0 end
    local sum = 0
    for _, x in ipairs(P.Network(e)) do
        local r = x.AGPRes[res]
        if r then sum = sum + r.max end
    end
    return sum
end

-- take from the network: own storage first, then the others. Returns what was really taken.
function P.ConsumeResource(self, res, amount)
    local e = isentity(self) and self or self.Entity   -- AGP: a pasted copy's self.Entity can be the original
    amount = math.max(0, amount or 0)
    if amount <= 0 or not P.Parts[e] then return 0 end
    local left = amount
    local own = e.AGPRes[res]
    if own and own.amount > 0 then
        local t = math.min(own.amount, left); own.amount = own.amount - t; left = left - t
    end
    if left > 0 then
        for _, x in ipairs(P.Network(e)) do
            local r = x ~= e and x.AGPRes[res]
            if r and r.amount > 0 then
                local t = math.min(r.amount, left); r.amount = r.amount - t; left = left - t
                if left <= 0 then break end
            end
        end
    end
    return amount - left
end

-- put into the network: own storage first, then the others (up to their capacity). Returns what fit.
function P.SupplyResource(self, res, amount)
    local e = isentity(self) and self or self.Entity   -- AGP: a pasted copy's self.Entity can be the original
    amount = math.max(0, amount or 0)
    if amount <= 0 then return 0 end
    P.Register(e)
    local left = amount
    local own = e.AGPRes[res]
    if own then
        local t = math.min(own.max - own.amount, left)
        if t > 0 then own.amount = own.amount + t; left = left - t end
    end
    if left > 0 then
        for _, x in ipairs(P.Network(e)) do
            local r = x ~= e and x.AGPRes[res]
            if r then
                local t = math.min(r.max - r.amount, left)
                if t > 0 then r.amount = r.amount + t; left = left - t end
                if left <= 0 then break end
            end
        end
    end
    return amount - left
end

-- connected = shares a network with at least one other part (generators only produce when connected)
function P.Connected(e)
    if not P.Parts[e] then return false end
    local m = mode()
    if m == 1 or m == 3 then   -- AGP: a link both sides name (not one copied along with a pasted part)
        for o in pairs(e.AGPLinks or {}) do if linked(e, o) then return true end end
    end
    if m == 2 or m == 3 then
        -- AGP: parented counts like welded (only constraints were checked: a ZPM, naquadah generator, ion generator
        -- or power cell PARENTED to a ship stayed "disconnected", a naquadah bottle never ran). The same walk as the
        -- network (constraints, parent, children), cached with it
        for _, o in ipairs(walk(e).all) do
            if o ~= e and P.Parts[o] then return true end
        end
    end
    return false
end

-- everything in a network, for screens and the tool: { [resource] = { amount, max } }, parts count
function P.Summary(e)
    local out, n = {}, 0
    if not IsValid(e) then return out, 0 end
    P.Register(e)
    for _, x in ipairs(P.Network(e)) do
        n = n + 1
        for res, r in pairs(x.AGPRes) do
            local o = out[res] or { amount = 0, max = 0 }
            o.amount = o.amount + r.amount
            o.max = o.max + r.max
            out[res] = o
        end
    end
    return out, n
end

-- duplicator: keep links in dupes and saves ---------------------------------------------------------------------
-- AGP: there is no "PostEntityCopy" hook (the duplicator only calls an entity's own PreEntityCopy /
-- PostEntityCopy methods), so the links never reached a dupe or a save, and a paste in the same session kept the
-- copied link list pointing at the ORIGINAL ship (the copy drained it, cables ran between the ships). Now the links
-- travel as dupe info (storeLinks, at the top) and a paste links the NEW parts with each other: old index -> the new
-- entity of the same paste. Partners that were not copied stay unlinked. The GMod duplicator, game saves (they use it)
-- and AdvDupe2 all apply the modifiers of one paste in one go; the links are made a tick later, when all are known.
local pending, pasteMaps = {}, {}

local function restoreLinks()
    local list, maps = pending, pasteMaps
    pending, pasteMaps = {}, {}
    local byPaste, entry = {}, {}
    for _, d in ipairs(list) do
        if IsValid(d.ent) then
            entry[d.ent] = d
            if d.id then
                byPaste[d.key] = byPaste[d.key] or {}
                byPaste[d.key][d.id] = d.ent
            end
        end
    end
    for _, d in ipairs(list) do
        local e = d.ent
        if IsValid(e) and d.id then
            -- the paste's own list (CreatedEntities, handed over by our parts' PostEntityPaste) when there is one,
            -- else the one put together from this paste's modifiers (a paste without any PowerGrid part)
            local map = byPaste[d.key]
            for m in pairs(maps) do
                if m[d.id] == e or m[tostring(d.id)] == e then map = m break end
            end
            for id in pairs(d.links) do
                local o = map[id] or map[tostring(id)]
                local od = IsValid(o) and o ~= e and entry[o]
                -- both name each other (an outdated index of a removed partner never links a stranger)
                if od and od.links[d.id] then P.Link(e, o) end
            end
        end
    end
    -- the dupe info with the new indexes (also for parts whose partners were not pasted)
    for _, d in ipairs(list) do if IsValid(d.ent) then storeLinks(d.ent) end end
    touch()
end

-- our parts call this from PostEntityPaste (sv_bridge.lua) with the duplicator's CreatedEntities
function P.DupePasted(created)
    if not (PowerGrid.Active and istable(created)) then return end
    pasteMaps[created] = true
    timer.Create("AGP.Power.DupeLinks", 0, 1, restoreLinks)   -- (also when nothing was linked: the list is let go)
end

duplicator.RegisterEntityModifier("agp_power_links", function(ply, e, data)
    if not (PowerGrid.Active and IsValid(e) and istable(data)) then return end
    P.Register(e)
    -- a new part: drop what the copy brought along (the original's link list)
    for o in pairs(e.AGPLinks) do
        if not linked(e, o) then e.AGPLinks[o] = nil end
    end
    local links = {}
    for _, id in ipairs(istable(data.links) and data.links or {}) do
        if tonumber(id) then links[tonumber(id)] = true end
    end
    pending[#pending + 1] = { ent = e, id = tonumber(data.id), links = links,
        key = (IsValid(ply) and ply:EntIndex() or 0) .. ":" .. engine.TickCount() }
    timer.Create("AGP.Power.DupeLinks", 0, 1, restoreLinks)
    touch()
end)
