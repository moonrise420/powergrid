-- PowerGrid: space suit HUD (air / energy / coolant + where you are). Shown when life support is active
-- and something matters: bad air, a hot/cold place or a suit that is not full.
surface.CreateFont("AGPLSHud", { font = "Roboto", size = 18, weight = 700 })
surface.CreateFont("AGPLSHudSmall", { font = "Roboto", size = 15, weight = 500 })

-- units (each player picks their own; 0 = auto: Fahrenheit for the US and a few others, else Celsius)
AGP = AGP or {}
AGP.Units = AGP.Units or {}
local cvTemp = CreateClientConVar("agp_unit_temp", "0", true, false, "Ascension Gates: temperature unit (0 auto, 1 C, 2 F, 3 K)", 0, 3)
local cvGrav = CreateClientConVar("agp_unit_gravity", "0", true, false, "Ascension Gates: gravity unit (0 auto = g, 1 g, 2 m/s2, 3 ft/s2)", 0, 3)
local FAHRENHEIT = { US = true, LR = true, MM = true, BS = true, KY = true, PW = true, FM = true, MH = true }
function AGP.Units.TempMode()
    local m = cvTemp:GetInt()
    if m == 0 then m = FAHRENHEIT[system.GetCountry() or ""] and 2 or 1 end
    return m
end
function AGP.Units.Temp(c)   -- c in Celsius -> text
    local m = AGP.Units.TempMode()
    if m == 2 then return math.Round(c * 9 / 5 + 32) .. " °F" end
    if m == 3 then return math.Round(c + 273.15) .. " K" end
    return math.Round(c) .. " °C"
end
-- distance: game units -> text (1 unit = 1 inch, so 39.37 units = 1 m); 0 auto = feet for the US and a few others
local cvDist = CreateClientConVar("agp_unit_distance", "0", true, false, "Ascension Gates: distance unit (0 auto, 1 m, 2 ft, 3 game units)", 0, 3)
function AGP.Units.DistanceMode()
    local m = cvDist:GetInt()
    if m == 0 then m = FAHRENHEIT[system.GetCountry() or ""] and 2 or 1 end
    return m
end
function AGP.Units.Distance(u, short)
    local m = AGP.Units.DistanceMode()
    if m == 2 then return math.Round(u / 12) .. (short and "" or " ft") end
    if m == 3 then return math.Round(u) .. (short and "" or " u") end
    return math.Round(u * 0.0254) .. (short and "" or " m")
end
function AGP.Units.DistanceName() return ({ "m", "ft", "u" })[AGP.Units.DistanceMode()] end
-- speed: game units per second -> text in the same unit choice (metres -> km/h, feet -> mph, units -> u/s); 2026-11-15:
-- the ship HUDs used 1.905 cm per unit (25 % too low) and the Glider asked for this function before it existed
function AGP.Units.Speed(ups)
    local m = AGP.Units.DistanceMode()
    if m == 2 then return math.floor(ups * 3600 / 63360) .. " mph" end
    if m == 3 then return math.floor(ups) .. " u/s" end
    return math.floor(ups * 0.0254 * 3.6) .. " km/h"
end
function AGP.Units.Gravity(g)
    local m = cvGrav:GetInt()
    if m == 2 then return string.format("%.1f m/s²", g * 9.81) end
    if m == 3 then return string.format("%.1f ft/s²", g * 32.17) end
    return string.format("%.1f g", g)
end

-- 2026-11-14 restyle, second round. Owner: "our air and so display what we did new in the bottom its to fat and high up.....
-- do it beautifuly aestetic decent in the bottom not so wide up and also narrow and not so a fat bright thing maybe even
-- glassy see threw but fitting our style....". So: a slim, quiet, see-through strip right at the bottom edge (centre, between
-- GMod's health and ammo boxes, on their baseline), thin 2 px gauge lines in muted blue / orange / teal, tiny own-drawn glyphs
-- instead of labels, and only what matters: the percent only for a gauge that drains or is low, the countdown only while it
-- runs. Three looks, client convar agp_ls_hud_style:
--   1 = one line: place / temperature / air state as one small quiet text, then three glyph + hair line + numbers
--   2 = the same with three hair-thin arcs
--   3 = minimal: three short lines and nothing else (numbers sit above their line, only when they matter)
-- Shown / hidden exactly as before (life support on, something matters), same units and language keys. Values glide, the
-- strip fades in / out, a low gauge (< 20 %) brightens slowly and calmly, red only at empty. No blur (a real blur of the
-- background needs a render target every frame: not free, so plain transparency). Everything is sized from the screen height
-- (text never below 11 px). Cheap: no tables / Colors made per frame, texts measured twice a second, fonts only when the
-- resolution changes.
--   4 = classic: the first restyle of the same day (chips + segment bars), moved down to the same bottom edge
-- (2026-11-14 owner: "can we have settings so the player can choose? i would do first version but moved down ... new 1-3 and
-- the player can choose what with default new 2" - the choice is in the PowerGrid settings menu)
local cvStyle = CreateClientConVar("agp_ls_hud_style", "2", true, false, "PowerGrid suit HUD look: 1 = one line, 2 = hair arcs, 3 = minimal, 4 = classic", 1, 4)

local KEYS = { "air", "energy", "coolant" }
local GCOL = { { 100, 158, 220 }, { 226, 165, 88 }, { 96, 192, 186 } }   -- muted blue, orange (the pack's two) and teal
local RED = { 236, 88, 72 }
local TEXT, TDIM = { 200, 212, 226 }, { 150, 165, 185 }
local TEMP_COLD, TEMP_HOT, OKC, BADC = { 130, 184, 235 }, { 232, 150, 96 }, { 120, 200, 150 }, { 232, 120, 100 }
local COUNT_RED, COUNT_AMB = { 236, 110, 92 }, { 226, 190, 120 }
local PANEL_BG, PANEL_EDGE = { 8, 16, 30 }, { 90, 130, 180 }

local L = { sc = 1, next = 0 }                     -- layout (numbers only)
local T = { name = "", status = "", temp = "", tempKey = "" }
local fh = {}                                       -- font heights
local vis, raw, cdt = { 100, 100, 100 }, { 100, 100, 100 }, { -1, -1, -1 }
local gtxt, gkey = { "", "", "" }, { -1, -1, -1 }
local S = { ok = true, temp = 20, fade = 0 }
local FA, OY = 1, 0                                 -- fade factor and slide offset of this frame
local tmp = Color(0, 0, 0, 255)
AGP.LSHudLayout = L                                 -- (read by the picture tests)

local function px(n) return math.max(1, math.floor(n * L.sc + 0.5)) end

local function makeFonts()
    local function f(name, size, weight) surface.CreateFont(name, { font = "Roboto", size = math.max(11, px(size)), weight = weight, extended = true }) end
    f("AGPLSHudL", 13, 500) f("AGPLSHudS", 12, 500)
    for _, n in ipairs({ "AGPLSHudL", "AGPLSHudS" }) do
        surface.SetFont(n)
        fh[n] = select(2, surface.GetTextSize("Ag"))
    end
end

local function tw(str, font) surface.SetFont(font) return (surface.GetTextSize(str)) end

-- drawing helpers: colours are plain numbers, alpha is multiplied by the fade of the frame
local function col(c, a)
    tmp.r, tmp.g, tmp.b, tmp.a = c[1], c[2], c[3], a * FA
    return tmp
end
local function rect(x, y, w, h, c, a) surface.SetDrawColor(c[1], c[2], c[3], a * FA) surface.DrawRect(math.floor(x), math.floor(y + OY), w, h) end
-- ax: 0 left, 1 centre, 2 right; y is the vertical middle
local function text(str, font, x, y, c, a, ax)
    surface.SetFont(font)
    if ax and ax ~= 0 then
        local w = surface.GetTextSize(str)
        x = ax == 1 and x - w / 2 or x - w
    end
    surface.SetTextColor(c[1], c[2], c[3], a * FA)
    surface.SetTextPos(math.floor(x), math.floor(y + OY - fh[font] / 2))
    surface.DrawText(str)
end
-- a rotated segment: (x, y) centre, w across the angle's direction, h along it
local function seg(x, y, w, h, ang, c, a)
    surface.SetDrawColor(c[1], c[2], c[3], a * FA)
    surface.DrawTexturedRectRotated(x, y + OY, w, h, ang)
end

-- own-drawn glyphs (thin) -------------------------------------------------------------------------------------------
local BOLT1 = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }
local BOLT2 = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }
local B1 = { { 0.42, 0 }, { 0.84, 0 }, { 0.60, 0.52 }, { 0.20, 0.52 } }
local B2 = { { 0.16, 0.47 }, { 0.70, 0.47 }, { 0.30, 1.0 } }
local function poly(dst, src, x, y, s)
    for i = 1, #src do dst[i].x, dst[i].y = x + src[i][1] * s, y + OY + src[i][2] * s end
    surface.DrawPoly(dst)
end
-- cx, cy = middle, s = size in px; kind 1 air (a ring with a bubble), 2 energy (bolt), 3 coolant (snow crystal)
local function glyph(kind, cx, cy, s, c, a)
    draw.NoTexture()
    if kind == 1 then
        local r, n = s * 0.42, 12
        for i = 0, n - 1 do
            local t = i / n * math.pi * 2
            seg(cx + math.cos(t) * r, cy + math.sin(t) * r, 1.4, r * 2 * math.pi / n * 1.2, -math.deg(t), c, a)
        end
        rect(cx - 1, cy, 2, 2, c, a)
    elseif kind == 2 then
        surface.SetDrawColor(c[1], c[2], c[3], a * FA)
        poly(BOLT1, B1, cx - s * 0.5, cy - s * 0.5, s) poly(BOLT2, B2, cx - s * 0.5, cy - s * 0.5, s)
    else
        for k = 0, 2 do seg(cx, cy, s * 0.95, 1.4, k * 60, c, a) end
    end
end

-- gauges ---------------------------------------------------------------------------------------------------------------
local pulse = 0
-- colour and strength of gauge i: its own muted colour; under 20 % it brightens slowly; red only at empty
local function gstate(i)
    local v = raw[i]
    if v <= 0.5 then return RED, 255, 2 end
    if v < 20 then return GCOL[i], 150 + 105 * pulse, 1 end
    return GCOL[i], 185, 0
end

-- the numbers of gauge i: the percent only while it drains or is low, the countdown only while it runs
local function gtext(i)
    local p, t = math.Clamp(math.floor(raw[i]), 0, 100), cdt[i]
    if t < 0 and raw[i] >= 20 then return nil end
    local key = p * 100000 + t + 1
    if key ~= gkey[i] then
        gkey[i] = key
        local cd = t >= 0 and (t >= 60 and string.format("  %d:%02d", math.floor(t / 60), t % 60) or ("  " .. t .. "s")) or ""
        gtxt[i] = p .. "%" .. cd
    end
    return gtxt[i]
end
local function tcolor(i, st) return st == 2 and COUNT_RED or (cdt[i] >= 0 and cdt[i] < 20) and COUNT_RED or st == 1 and COUNT_AMB or TEXT end

local function hairline(x, y, w, frac, c, a)
    local th = L.th
    rect(x, y - th / 2, w, th, c, 55)
    local fw = math.floor(w * math.Clamp(frac, 0, 1) + 0.5)
    if fw > 0 then rect(x, y - th / 2, fw, th, c, a) end
end

local function hairarc(cx, cy, R, frac, c, a)
    local n, span = 64, 270
    local seglen = R * math.rad(span) / n * 1.6
    draw.NoTexture()
    for i = 0, n - 1 do
        local deg = 135 + (i + 0.5) / n * span
        local t = math.rad(deg)
        local x, y = cx + math.cos(t) * R, cy + math.sin(t) * R
        seg(x, y, L.th, seglen, -deg, c, math.Clamp(frac * n - i, 0, 1) > 0 and a or 45)
    end
end

-- the info text: place, temperature, air state ----------------------------------------------------------------------
local function tempColor() return S.temp < -10 and TEMP_COLD or S.temp > 37 and TEMP_HOT or TDIM end
local function infoLine(x, cy)
    text(T.name, "AGPLSHudL", x, cy, TEXT, 215, 0)
    x = x + L.iw1 + L.igap
    text(T.temp, "AGPLSHudL", x, cy, tempColor(), 215, 0)
    x = x + L.iw2 + L.igap
    text(T.status, "AGPLSHudL", x, cy, S.ok and OKC or BADC, 225, 0)
end

local function panel(x, y, w, h)
    draw.RoundedBox(3, x, y + OY, w, h, col(PANEL_BG, 100))
    surface.SetDrawColor(PANEL_EDGE[1], PANEL_EDGE[2], PANEL_EDGE[3], 70 * FA)
    surface.DrawOutlinedRect(x, y + OY, w, h, 1)
end

-- the three looks ----------------------------------------------------------------------------------------------------
local function paintLine(x, y, arcs)
    local pad, cy = L.pad, y + L.h / 2
    panel(x, y, L.w, L.h)
    infoLine(x + pad, cy)
    local gx = x + pad + L.infoW + L.igap
    rect(gx - L.igap / 2, y + L.h * 0.25, 1, L.h * 0.5, PANEL_EDGE, 60)
    gx = gx + L.igap / 2
    for i = 1, 3 do
        local c, a, st = gstate(i)
        if arcs then
            local R = L.D / 2 - 1
            hairarc(gx + R + 1, cy, R, vis[i] / 100, c, a)
            glyph(i, gx + R + 1, cy, L.gs, c, a)
            gx = gx + L.D + px(5)
        else
            glyph(i, gx + L.gs / 2, cy, L.gs, c, a)
            gx = gx + L.gs + px(5)
            hairline(gx, cy, L.bl, vis[i] / 100, c, a)
            gx = gx + L.bl + px(6)
        end
        local s = gtext(i)
        if s then text(s, "AGPLSHudS", gx, cy, tcolor(i, st), 220, 0) end
        gx = gx + L.slot + L.cgap
    end
end

local function paintMin(x, y)
    local pad = L.pad
    panel(x, y, L.w, L.h)
    local gx = x + pad
    local ly, ty = y + L.h - px(9), y + px(9)
    for i = 1, 3 do
        local c, a, st = gstate(i)
        glyph(i, gx + L.gs / 2, ly, L.gs, c, a)
        local lx = gx + L.gs + px(5)
        hairline(lx, ly, L.bl, vis[i] / 100, c, a)
        local s = gtext(i)
        if s then text(s, "AGPLSHudS", lx + L.bl, ty, tcolor(i, st), 220, 2) end
        gx = gx + L.gs + px(5) + L.bl + L.cgap
    end
end

-- layout: measured twice a second (language, unit, resolution, style) ------------------------------------------------
local function relayout()
    L.next = CurTime() + 0.5
    local sc = ScrH() / 1080
    if sc ~= L.sc or not fh.AGPLSHudL then L.sc = sc makeFonts() end
    T.status = S.ok and PowerGrid.L("agp_ls_hud_breathable", "breathable") or PowerGrid.L("agp_ls_hud_noair", "no air")
    local mode = AGP.Units.TempMode()
    if T.tempKey ~= S.temp .. "/" .. mode then T.tempKey = S.temp .. "/" .. mode T.temp = AGP.Units.Temp(S.temp) end
    L.pad, L.igap, L.cgap, L.gs, L.th = px(10), px(12), px(10), px(11), math.max(2, px(2))
    L.iw1, L.iw2, L.iw3 = tw(T.name, "AGPLSHudL"), tw(T.temp, "AGPLSHudL"), tw(T.status, "AGPLSHudL")
    L.infoW = L.iw1 + L.iw2 + L.iw3 + 2 * L.igap
    L.slot = tw("100% 9:59", "AGPLSHudS")
    local style = cvStyle:GetInt()
    L.style = style
    local pad = L.pad
    local rowH = math.max(px(28), fh.AGPLSHudL + px(10))
    if style == 2 then
        L.D = px(28)
        L.h = math.max(L.D + px(10), rowH)
        L.w = 2 * pad + L.infoW + L.igap + 3 * (L.D + px(5) + L.slot) + 2 * L.cgap
    elseif style == 3 then
        L.bl = math.max(px(52), L.slot)
        L.h = math.max(px(34), fh.AGPLSHudS + px(18))
        L.w = 2 * pad + 3 * (L.gs + px(5) + L.bl) + 2 * L.cgap
    else
        L.bl = px(30)
        L.h = rowH
        L.w = 2 * pad + L.infoW + L.igap + 3 * (L.gs + px(5) + L.bl + px(6) + L.slot) + 2 * L.cgap
    end
    L.x = math.floor((ScrW() - L.w) / 2)
    L.y = ScrH() - math.floor(ScrH() * 0.015) - L.h     -- right at the bottom edge, on the baseline of GMod's health / ammo boxes
end
hook.Add("OnScreenSizeChanged", "AGP.LS.Hud", function() L.next = 0 end)

-- look 4, "classic": the first restyle (chips for place / temperature / air, three icon + label + segment-bar cells),
-- kept in its own block with its own layout and fonts; it reads the shared values (raw, vis, cdt, S, T.name) and the fade.
local classicPaint
do
    local LKEY = { "agp_ls_hud_air", "agp_ls_hud_energy", "agp_ls_hud_coolant" }
    local LDEF = { "Air", "Energy", "Coolant" }
    local CG = { { 56, 150, 240 }, { 255, 175, 55 }, { 70, 215, 205 } }
    local CRED = { 255, 90, 70 }
    local BG, EDGE, PNL, CTEXT, ACC2 = { 14, 20, 30 }, { 44, 70, 110 }, { 24, 32, 46 }, { 225, 235, 245 }, { 255, 160, 50 }
    local CRED_T, CAMB_T, OFFC = { 255, 110, 90 }, { 255, 200, 120 }, { 40, 52, 70 }
    local CCOLD, CHOT, COK, CBAD = { 120, 190, 255 }, { 255, 140, 80 }, { 120, 230, 150 }, { 255, 110, 90 }
    local C = { sc = 0, next = 0 }
    local CT = { lab = { "", "", "" }, status = "", temp = "", tempKey = "", name = "" }
    local cfh, cdStr, cdLast, PCT = {}, { "", "", "" }, { -2, -2, -2 }, {}
    for i = 0, 100 do PCT[i] = i .. "%" end
    local cFA, cOY, cpulse, skinned = 1, 0, 1, false
    local ctmp = Color(0, 0, 0, 255)
    local function cpx(n) return math.floor(n * C.sc + 0.5) end
    local function cfonts()
        local function f(name, size, weight) surface.CreateFont(name, { font = "Roboto", size = cpx(size), weight = weight, extended = true }) end
        f("AGPLSHudCV", 21, 700) f("AGPLSHudCL", 16, 600) f("AGPLSHudCS", 14, 500) f("AGPLSHudCC", 15, 600)
        for _, n in ipairs({ "AGPLSHudCV", "AGPLSHudCL", "AGPLSHudCS", "AGPLSHudCC" }) do
            surface.SetFont(n)
            cfh[n] = select(2, surface.GetTextSize("Ag"))
        end
    end
    local function crect(x, y, w, h, c, a) surface.SetDrawColor(c[1], c[2], c[3], a * cFA) surface.DrawRect(x, y + cOY, w, h) end
    local function rbox(r, x, y, w, h, c, a)
        ctmp.r, ctmp.g, ctmp.b, ctmp.a = c[1], c[2], c[3], a * cFA
        draw.RoundedBox(r, x, y + cOY, w, h, ctmp)
    end
    local function ctext(str, font, x, y, c, a, ax)
        surface.SetFont(font)
        if ax and ax ~= 0 then
            local w = surface.GetTextSize(str)
            x = ax == 1 and x - w / 2 or x - w
        end
        surface.SetTextColor(c[1], c[2], c[3], a * cFA)
        surface.SetTextPos(math.floor(x), math.floor(y + cOY - cfh[font] / 2))
        surface.DrawText(str)
    end
    local function cseg(x, y, w, h, ang, c, a)
        surface.SetDrawColor(c[1], c[2], c[3], a * cFA)
        surface.DrawTexturedRectRotated(x, y + cOY, w, h, ang)
    end
    local CB1 = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }
    local CB2 = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }
    local function cpoly(dst, src, x, y, s)
        for i = 1, #src do dst[i].x, dst[i].y = x + src[i][1] * s, y + cOY + src[i][2] * s end
        surface.DrawPoly(dst)
    end
    local function icon(kind, cx, cy, s, c, a)
        draw.NoTexture()
        if kind == 1 then
            local r, n = s * 0.38, 14
            for i = 0, n - 1 do
                local t = i / n * math.pi * 2
                cseg(cx + math.cos(t) * r, cy + math.sin(t) * r, math.max(2, s * 0.15), r * 2 * math.pi / n * 1.15, -math.deg(t), c, a)
            end
            crect(cx - s * 0.20, cy + s * 0.08, math.max(2, s * 0.16), math.max(2, s * 0.16), c, a)
            crect(cx + s * 0.02, cy - s * 0.14, math.max(2, s * 0.12), math.max(2, s * 0.12), c, a)
        elseif kind == 2 then
            surface.SetDrawColor(c[1], c[2], c[3], a * cFA)
            local x, y = cx - s * 0.5, cy - s * 0.5
            cpoly(CB1, B1, x, y, s) cpoly(CB2, B2, x, y, s)
        else
            for k = 0, 2 do cseg(cx, cy, s * 0.95, math.max(2, s * 0.13), k * 60, c, a) end
            for k = 0, 5 do
                local t = math.rad(k * 60)
                cseg(cx + math.cos(t) * s * 0.30, cy - math.sin(t) * s * 0.30, math.max(2, s * 0.2), math.max(2, s * 0.1), math.deg(t) + 45, c, a)
            end
        end
    end
    local function cstate(i)
        local v = raw[i]
        if v <= 0.5 then return CRED, 1, 2 end
        if v < 20 then return CRED, 0.55 + 0.45 * cpulse, 1 end
        return CG[i], 1, 0
    end
    local function segbar(x, y, w, h, n, frac, c, a)
        local gap = math.max(1, math.floor(h / 4))
        local sw = (w - (n - 1) * gap) / n
        for i = 0, n - 1 do
            local sx = math.floor(x + i * (sw + gap))
            local ex = math.floor(x + i * (sw + gap) + sw)
            local f = math.Clamp(frac * n - i, 0, 1)
            crect(sx, y, ex - sx, h, OFFC, 230)
            if f > 0 then crect(sx, y, ex - sx, h, c, a * 255 * (0.35 + 0.65 * f)) end
        end
    end
    local function countdown(i, x, y)
        local t = cdt[i]
        if t < 0 then return end
        if t ~= cdLast[i] then
            cdLast[i] = t
            cdStr[i] = t >= 60 and string.format("%d:%02d", math.floor(t / 60), t % 60) or (t .. "s")
        end
        ctext(cdStr[i], "AGPLSHudCS", x, y, t < 20 and CRED_T or CAMB_T, 255, 2)
    end
    local function chip(x, y, label, c, dot, w)
        local h = C.chipH
        rbox(h / 2, x, y, w, h, PNL, 255)
        local tx = x + C.chipPad
        if dot then
            rbox(C.dot / 2, tx, y + (h - C.dot) / 2, C.dot, C.dot, dot, 255)
            tx = tx + C.dot + cpx(6)
        end
        ctext(label, "AGPLSHudCC", tx, y + h / 2, c, 255, 0)
    end
    local function crelayout()
        C.next = CurTime() + 0.5
        local sc = math.max(1, ScrH() / 1080)    -- never smaller than the 1080p size: at 720p the text must stay readable
        if sc ~= C.sc then C.sc = sc cfonts() end
        for i = 1, 3 do CT.lab[i] = PowerGrid.L(LKEY[i], LDEF[i]) end
        CT.name = T.name
        CT.status = S.ok and PowerGrid.L("agp_ls_hud_breathable", "breathable") or PowerGrid.L("agp_ls_hud_noair", "no air")
        local mode = AGP.Units.TempMode()
        if CT.tempKey ~= S.temp .. "/" .. mode then CT.tempKey = S.temp .. "/" .. mode CT.temp = AGP.Units.Temp(S.temp) end
        C.pad, C.chipH, C.chipPad, C.chipGap, C.dot, C.icon = cpx(12), cpx(24), cpx(11), cpx(6), cpx(7), cpx(19)
        C.cwName = tw(CT.name, "AGPLSHudCC") + 2 * C.chipPad + C.dot + cpx(6)
        C.cwTemp = tw(CT.temp, "AGPLSHudCC") + 2 * C.chipPad
        C.cwStat = tw(CT.status, "AGPLSHudCC") + 2 * C.chipPad + C.dot + cpx(6)
        local chipsRow = C.cwName + C.cwTemp + C.cwStat + 2 * C.chipGap
        local labW = 0
        for i = 1, 3 do labW = math.max(labW, tw(CT.lab[i], "AGPLSHudCL")) end
        C.pctW = tw("100%", "AGPLSHudCV")
        local cdW = tw("00:00", "AGPLSHudCS")
        C.line1, C.line2 = cpx(20), cpx(26)
        C.cellH = C.line1 + cpx(3) + C.line2
        C.colGap = cpx(22)
        C.cw = math.max(math.max(C.icon + cpx(7) + labW + cpx(10) + cdW, cpx(100) + cpx(8) + C.pctW), (chipsRow - 2 * C.colGap) / 3)
        C.w = math.min(2 * C.pad + 3 * C.cw + 2 * C.colGap, ScrW() - cpx(40))
        C.h = C.pad + C.chipH + cpx(9) + C.cellH + C.pad
        C.x = math.floor((ScrW() - C.w) / 2)
        C.y = ScrH() - math.floor(ScrH() * 0.015) - C.h   -- the same bottom edge as looks 1-3 (it sat higher at first)
    end
    hook.Add("OnScreenSizeChanged", "AGP.LS.HudClassic", function() C.sc = 0 C.next = 0 end)

    classicPaint = function()
        if not skinned then
            skinned = true
            local AC = AGP and AGP.Colors
            if AC then
                local function cp(dst, c) if c then dst[1], dst[2], dst[3] = c.r, c.g, c.b end end
                cp(BG, AC.bg) cp(EDGE, AC.edge) cp(PNL, AC.panel) cp(CTEXT, AC.text) cp(ACC2, AC.accent2)
            end
        end
        if CurTime() > C.next or CT.name ~= T.name then crelayout() end
        cFA = S.fade
        cOY = math.floor((1 - cFA) * cpx(12) + 0.5)
        cpulse = 0.5 + 0.5 * math.sin(CurTime() * 3.6)
        local x, y, pad = C.x, C.y, C.pad
        local r = cpx(10)
        rbox(r, x, y, C.w, C.h, EDGE, 235)
        rbox(r - 1, x + 1, y + 1, C.w - 2, C.h - 2, BG, 232)
        crect(x + r, y, cpx(54), math.max(2, cpx(2)), ACC2, 255)
        local chx, chy = x + pad, y + pad
        chip(chx, chy, CT.name, CTEXT, ACC2, C.cwName)
        chx = chx + C.cwName + C.chipGap
        chip(chx, chy, CT.temp, S.temp < -10 and CCOLD or S.temp > 37 and CHOT or CTEXT, nil, C.cwTemp)
        chx = chx + C.cwTemp + C.chipGap
        chip(chx, chy, CT.status, S.ok and COK or CBAD, S.ok and COK or CBAD, C.cwStat)
        local cy = y + pad + C.chipH + cpx(9)
        for i = 1, 3 do
            local cx = x + pad + (i - 1) * (C.cw + C.colGap)
            local c, a, st = cstate(i)
            if st > 0 then rbox(cpx(6), cx - cpx(5), cy - cpx(3), C.cw + cpx(10), C.cellH + cpx(6), CRED, st == 2 and 60 or 26 + 34 * cpulse) end
            icon(i, cx + C.icon / 2, cy + C.line1 / 2, C.icon, c, a * 255)
            ctext(CT.lab[i], "AGPLSHudCL", cx + C.icon + cpx(7), cy + C.line1 / 2, st == 2 and CRED or CTEXT, 255, 0)
            countdown(i, cx + C.cw, cy + C.line1 / 2)
            local by = cy + C.line1 + cpx(3)
            segbar(cx, by + (C.line2 - cpx(10)) / 2, C.cw - C.pctW - cpx(8), cpx(10), 16, vis[i] / 100, c, a)
            ctext(PCT[math.Clamp(math.floor(raw[i]), 0, 100)], "AGPLSHudCV", cx + C.cw, by + C.line2 / 2, st > 0 and CRED or CTEXT, 255, 2)
        end
    end
end

hook.Add("HUDPaint", "AGP.LS.Hud", function()
    local p = LocalPlayer()
    local want = false
    if IsValid(p) and p:GetNWBool("agp_ls_on", false) and p:Alive() then
        local air, energy, coolant = p:GetNWFloat("agp_air", 100), p:GetNWFloat("agp_energy", 100), p:GetNWFloat("agp_coolant", 100)
        local ok, temp = p:GetNWBool("agp_env_ok", true), p:GetNWInt("agp_env_temp", 20)
        if not (ok and temp > -10 and temp < 37 and air >= 99.5 and energy >= 99.5 and coolant >= 99.5) then
            want = true
            raw[1], raw[2], raw[3] = air, energy, coolant
            S.ok, S.temp = ok, temp
            local name = p:GetNWString("agp_env", "")
            if name == "Space" then name = PowerGrid.L("agp_ls_space_name", "Space") end
            if name == "" then name = PowerGrid.L("agp_ls_hud_suit", "Space suit") end
            if name ~= T.name then T.name = name L.next = 0 end
            for i = 1, 3 do cdt[i] = p:GetNWInt("agp_" .. KEYS[i] .. "_t", -1) end
        end
    end
    local dt = math.min(FrameTime(), 0.1)
    if want then
        if S.fade <= 0 then for i = 1, 3 do vis[i] = raw[i] end end   -- appears with the right values
        S.fade = math.min(1, S.fade + dt * 4)
    else
        if S.fade <= 0 then return end
        S.fade = math.max(0, S.fade - dt * 3)
    end
    -- values glide towards the real ones
    local k = math.min(1, dt * 8)
    for i = 1, 3 do
        vis[i] = vis[i] + (raw[i] - vis[i]) * k
        if math.abs(raw[i] - vis[i]) < 0.05 then vis[i] = raw[i] end
    end
    if CurTime() > L.next or L.style ~= cvStyle:GetInt() then relayout() end
    FA = S.fade
    OY = math.floor((1 - FA) * px(6) + 0.5)
    pulse = 0.5 + 0.5 * math.sin(CurTime() * 2.4)   -- one slow breath every 2.6 s
    local style = L.style
    if style == 4 then classicPaint() return end
    if style == 2 then paintLine(L.x, L.y, true) elseif style == 3 then paintMin(L.x, L.y) else paintLine(L.x, L.y, false) end
end)

-- destination report when a gate near you dials (Stargate tie-in)
local report
local cvShow = CreateClientConVar("agp_gate_report_show", "1", true, false, "Ascension Gates: show the destination report when a gate near you dials")
-- show a report: { name, ok, temp (C), grav (g), space }
function AGP.ShowGateReport(r)
    r.t = CurTime()
    report = r
end
net.Receive("agp_ls_gate", function()
    if not cvShow:GetBool() then return end
    AGP.ShowGateReport({ name = net.ReadString(), ok = net.ReadBool(), temp = net.ReadInt(16), grav = net.ReadFloat(), space = net.ReadBool() })
end)
hook.Add("HUDPaint", "AGP.LS.GateReport", function()
    if not report or CurTime() - report.t > 9 then return end
    local a = math.Clamp((9 - (CurTime() - report.t)) * 255, 0, 255)
    local danger = not report.ok or report.temp < -10 or report.temp > 45
    local title = PowerGrid.L("agp_ls_rep_title", "Destination report")
    local place = (report.name == "Space" and PowerGrid.L("agp_ls_space_name", "Space")) or (report.name ~= "" and report.name) or PowerGrid.L("agp_ls_rep_unknown", "unknown world")
    local line1 = report.space and PowerGrid.L("agp_ls_rep_vacuum", "Vacuum (space)") or (report.ok and PowerGrid.L("agp_ls_rep_air", "Breathable atmosphere") or PowerGrid.L("agp_ls_rep_noair", "No breathable air"))
    local line2 = AGP.Units.Temp(report.temp) .. "   ·   " .. PowerGrid.L("agp_ls_rep_gravity", "gravity") .. " " .. AGP.Units.Gravity(report.grav)
    local line3 = danger and PowerGrid.L("agp_ls_rep_danger", "Suit needed - check air, energy and coolant!") or PowerGrid.L("agp_ls_rep_safe", "Safe to go through")
    surface.SetFont("AGPLSHud")
    local need = math.max(surface.GetTextSize(title) + surface.GetTextSize(place) + 40, surface.GetTextSize(line1) + 24)
    surface.SetFont("AGPLSHudSmall")
    need = math.max(need, surface.GetTextSize(line2) + 24, surface.GetTextSize(line3) + 24)
    local w, h = math.max(360, need), 118
    local x, y = ScrW() / 2 - w / 2, 120
    draw.RoundedBox(8, x, y, w, h, Color(6, 14, 26, math.min(220, a)))
    draw.RoundedBoxEx(8, x, y, w, 30, Color(30, 70, 120, math.min(255, a)), true, true, false, false)
    draw.SimpleText(title, "AGPLSHud", x + 12, y + 5, Color(255, 255, 255, a))
    draw.SimpleText(place, "AGPLSHud", x + w - 12, y + 5, Color(255, 200, 90, a), TEXT_ALIGN_RIGHT)
    draw.SimpleText(line1, "AGPLSHud", x + 12, y + 40, report.ok and Color(120, 230, 150, a) or Color(255, 110, 90, a))
    draw.SimpleText(line2, "AGPLSHudSmall", x + 12, y + 64, Color(220, 230, 240, a))
    draw.SimpleText(line3, "AGPLSHudSmall", x + 12, y + 88, danger and Color(255, 170, 60, a) or Color(160, 200, 230, a))
end)
