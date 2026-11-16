-- PowerGrid: the colour and bloom of a planet (the map's planet_color / planet_bloom entries, as Spacebuild shows them):
-- while you are inside such a planet the screen gets its colour change and bloom. Client setting agp_ls_planet_fx (1 = on).
-- The server sends the list (agp_ls_fx) only where our space simulation runs.
local cvFX = CreateClientConVar("agp_ls_planet_fx", "1", true, false, "PowerGrid: planet colour and bloom while you are inside a planet (0 = off)", 0, 1)

local planets = {}
local current, nextCheck = nil, 0

net.Receive("agp_ls_fx", function()
    planets = {}
    for _ = 1, net.ReadUInt(8) do
        local p = { pos = net.ReadVector(), radius = net.ReadFloat(), cube = net.ReadBool() }
        if net.ReadBool() then
            local c = {}
            for i = 1, 9 do c[i] = net.ReadFloat() end
            p.color = {
                ["$pp_colour_addr"] = c[1], ["$pp_colour_addg"] = c[2], ["$pp_colour_addb"] = c[3],
                ["$pp_colour_mulr"] = c[4], ["$pp_colour_mulg"] = c[5], ["$pp_colour_mulb"] = c[6],
                ["$pp_colour_brightness"] = c[7], ["$pp_colour_contrast"] = c[8], ["$pp_colour_colour"] = c[9],
            }
        end
        if net.ReadBool() then
            local b = {}
            for i = 1, 9 do b[i] = net.ReadFloat() end
            p.bloom = b
        end
        planets[#planets + 1] = p
    end
    current = nil
    nextCheck = 0
end)

local function insidePlanet(p, pos)
    if p.cube then
        local c, r = p.pos, p.radius
        return pos.x < c.x + r and pos.x > c.x - r and pos.y < c.y + r and pos.y > c.y - r and pos.z < c.z + r and pos.z > c.z - r
    end
    return pos:DistToSqr(p.pos) < p.radius * p.radius
end

-- which planet am I in (the smallest first: the server sends them smallest first); twice a second
local function update()
    local now = CurTime()
    if now < nextCheck then return end
    nextCheck = now + 0.5
    current = nil
    if #planets == 0 or not cvFX:GetBool() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local pos = ply:GetPos()
    for _, p in ipairs(planets) do
        if (p.color or p.bloom) and insidePlanet(p, pos) then current = p return end
    end
end

hook.Add("RenderScreenspaceEffects", "AGP.LS.PlanetFX", function()
    if #planets == 0 then return end
    update()
    local p = current
    if not p then return end
    if p.color then DrawColorModify(p.color) end
    if p.bloom then
        local b = p.bloom   -- colour r g b, size x y, passes, darken, multiply, colour (saturation)
        DrawBloom(b[7], b[8], b[4], b[5], b[6], b[9], b[1], b[2], b[3])
    end
end)

-- for the self-test: the planet whose effect is on right now
AGP = AGP or {}
AGP.LSPlanetFXCurrent = function() return current end
