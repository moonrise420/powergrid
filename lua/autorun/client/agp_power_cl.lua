-- PowerGrid: Grid Power cables - draws the links of the power network (agp_power_cables 0 = hidden)
local cvCables = CreateClientConVar("agp_power_cables", "1", true, false, "Ascension Gates: show PowerGrid cables")
local links = {}

-- AGP: the list holds entity numbers, looked up while drawing. It held the entities as read, and a part this
-- client did not have yet (outside its view / PVS, or still loading after joining) came as NULL and stayed NULL
-- until the next link change: no cable to it. A joining player also asks for the list once the map is loaded.
net.Receive("agp_power_links", function()
    links = {}
    for i = 1, net.ReadUInt(14) do links[i] = { net.ReadUInt(16), net.ReadUInt(16) } end
end)
hook.Add("InitPostEntity", "AGP.Power.Cables", function()
    net.Start("agp_power_links")
    net.SendToServer()
end)

-- AGP (the author's wish): the cables of your parts can be hidden from the other players too. The setting goes to
-- the server with your player info; the server leaves those cables out of the others' lists. A change asks the
-- server to send everyone a new list.
CreateClientConVar("agp_power_cables_share", "1", true, true, "Ascension Gates: other players see the cables of your parts (0 = they do not)", 0, 1)
cvars.AddChangeCallback("agp_power_cables_share", function()
    timer.Create("AGP.Power.CablesShare", 0.5, 1, function()
        net.Start("agp_power_links")
        net.WriteBool(true)
        net.SendToServer()
    end)
end, "AGP.Power.CablesShare")

local mat = Material("cable/cable2")
local glow = Material("sprites/light_glow02_add")

hook.Add("PostDrawTranslucentRenderables", "AGP.Power.Cables", function(depth, sky)
    if sky or not cvCables:GetBool() or #links == 0 then return end
    local eye = EyePos()
    local t = CurTime()
    for _, l in ipairs(links) do
        local a, b = Entity(l[1]), Entity(l[2])
        if IsValid(a) and IsValid(b) then
            local pa, pb = a:WorldSpaceCenter(), b:WorldSpaceCenter()
            if pa:DistToSqr(eye) < 4000 * 4000 or pb:DistToSqr(eye) < 4000 * 4000 then
                -- a slightly hanging cable with a soft blue power glow running along it
                -- (seen in a picture: it hung into the floor; how far it can hang is looked up every 2 seconds)
                local mid = (pa + pb) / 2
                if (l[4] or 0) < t then
                    l[4] = t + 2
                    local tr = util.TraceLine({ start = mid, endpos = mid - Vector(0, 0, 44), mask = MASK_SOLID_BRUSHONLY })
                    l[3] = tr.Hit and math.max(0, tr.Fraction * 44 - 3) * 2 or 80
                end
                mid.z = mid.z - math.min(l[3], pa:Distance(pb) * 0.08)
                render.SetMaterial(mat)
                render.StartBeam(9)
                for s = 0, 8 do
                    local f = s / 8
                    local p = (1 - f) ^ 2 * pa + 2 * (1 - f) * f * mid + f ^ 2 * pb
                    render.AddBeam(p, 2, f * 4, Color(60, 70, 80))
                end
                render.EndBeam()
                render.SetMaterial(glow)
                local f = (t * 0.6) % 1
                local p = (1 - f) ^ 2 * pa + 2 * (1 - f) * f * mid + f ^ 2 * pb
                render.DrawSprite(p, 10, 10, Color(90, 180, 255, 200))
            end
        end
    end
end)
