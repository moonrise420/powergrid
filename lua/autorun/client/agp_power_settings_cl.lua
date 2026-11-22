-- PowerGrid: settings page (tools tab > PowerGrid > Settings > Grid Power)
local L = PowerGrid.L

local state, panelRef = {}, nil

local function set(name, value)
    net.Start("agp_power_set")
    net.WriteString(name)
    net.WriteInt(value, 8)
    net.SendToServer()
end

local MODES = {   -- value, text key, text, tooltip key, tooltip (one short line, shown when the mouse is over it)
    { 1, "agp_pw_mode_manual", "Manual (link tool / power node)", "agp_pw_tip_manual", "Parts share energy only when you link them (PowerGrid Connector tool or a power node)." },
    { 2, "agp_pw_mode_auto", "Automatic (welded parts share)", "agp_pw_tip_auto", "Parts welded together share their energy by themselves." },
    { 3, "agp_pw_mode_mix", "Mix (both)", "agp_pw_tip_mix", "Linked parts and welded parts both share." },
    { 0, "agp_pw_mode_off", "Off (free energy)", "agp_pw_tip_off", "No energy network: everything has power for free." },
}

local function refresh()
    local p = panelRef
    if not IsValid(p) or not IsValid(p.AGPStatus) then return end
    local now
    if state.rd then now = L("agp_pw_now_rd", "Spacebuild / RD is in use (its own tools link the parts).")
    elseif state.running then now = L("agp_pw_now_agp", "PowerGrid is running.")
    else now = L("agp_pw_now_off", "Off: free energy.") end
    p.AGPStatus:SetText(now)
    p.AGPStatus:SizeToContentsY()
    for _, b in ipairs(p.AGPModeButtons or {}) do
        b:SetText((state.mode == b.AGPValue and "● " or "○ ") .. b.AGPLabel)
        b:SetEnabled(state.admin == true)
    end
    p.AGPBackend:SetText(state.backend == 1 and L("agp_pw_backend_agp", "Always PowerGrid: on") or L("agp_pw_backend_rd", "Always PowerGrid: off"))
    p.AGPBackend:SetEnabled(state.admin == true)
    if IsValid(p.AGPCache) then
        p.AGPCache:SetText(state.cacheEveryone and L("agp_pw_cache_all", "Black Hole Energy: everyone") or L("agp_pw_cache_admin", "Black Hole Energy: admins only"))
        p.AGPCache:SetEnabled(state.admin == true)
    end
    if IsValid(p.AGPInfinite) then
        p.AGPInfinite:SetText(state.infinite and L("agp_pw_infinite_on", "Endless power sources: allowed") or L("agp_pw_infinite_off", "Endless power sources: off"))
        p.AGPInfinite:SetEnabled(state.admin == true)
    end
    if IsValid(p.AGPZPM) then
        p.AGPZPM:SetText(state.zpmOverload and L("agp_pw_zpm_on", "ZPM overload: on (a ZPM without a hub can explode)") or L("agp_pw_zpm_off", "ZPM overload: off (ZPMs never explode)"))
        p.AGPZPM:SetEnabled(state.admin == true)
    end
    if IsValid(p.AGPLSStatus) then
        local lsText
        -- say why nothing of ours runs while Spacebuild's own life support does (no two countdowns)
        if state.sbLS then lsText = L("agp_ls_now_sb", "Spacebuild's own life support runs here: ours stands back (no second suit, no second countdown). Switch Spacebuild off to use ours.")
        elseif state.lsActive then lsText = L("agp_ls_now_on", "Space simulation is running here (%d planets).", state.planets or 0)
        elseif state.lsMode == 2 then lsText = L("agp_ls_now_water", "Water-only life support is running here: air runs down only under water.")
        else lsText = L("agp_ls_now_off", "No space simulation on this map.") end
        p.AGPLSStatus:SetText(lsText)
        p.AGPLSStatus:SizeToContentsY()
        for _, b in ipairs(p.AGPSpaceButtons or {}) do
            b:SetText((state.space == b.AGPValue and "● " or "○ ") .. b.AGPLabel)
            b:SetEnabled(state.admin == true)
        end
        local function toggle(btn, on, onText, offText)
            if IsValid(btn) then btn:SetText(on and onText or offText) btn:SetEnabled(state.admin == true) end
        end
        toggle(p.AGPWater, state.water, L("agp_ls_water_on", "Water on every map: on"), L("agp_ls_water_off", "Water on every map: off"))
        toggle(p.AGPPropG, state.propGravity, L("agp_ls_propg_on", "Props in space: weightless"), L("agp_ls_propg_off", "Props in space: normal gravity"))
        toggle(p.AGPPressure, state.pressure, L("agp_ls_pressure_on", "Pressure: planets can crush"), L("agp_ls_pressure_off", "Pressure: off"))
        toggle(p.AGPStars, state.stars, L("agp_ls_stars_on", "Stars: heat, sunburn, kill zone"), L("agp_ls_stars_off", "Stars: only cold space"))
        toggle(p.AGPGasUse, state.gasUse, L("agp_ls_gasuse_on", "Breathing uses up planet air"), L("agp_ls_gasuse_off", "Breathing never uses planet air"))
        for _, b in ipairs(p.AGPNoclipButtons or {}) do
            b:SetText((state.noclip == b.AGPValue and "● " or "○ ") .. b.AGPLabel)
            b:SetEnabled(state.admin == true)
        end
        if IsValid(p.AGPReport) then
            p.AGPReport:SetText(state.report and L("agp_ls_report_on", "Gate destination report: on") or L("agp_ls_report_off", "Gate destination report: off"))
            p.AGPReport:SetEnabled(state.admin == true)
        end
    end
end

net.Receive("agp_power_state", function()
    state.mode = net.ReadUInt(3)
    state.backend = net.ReadUInt(2)
    state.cacheEveryone = net.ReadBool()
    state.running = net.ReadBool()
    state.rd = net.ReadBool()
    state.admin = net.ReadBool()
    state.space = net.ReadUInt(2)
    state.report = net.ReadBool()
    state.lsActive = net.ReadBool()
    state.planets = net.ReadUInt(8)
    state.infinite = net.ReadBool()
    state.zpmOverload = net.ReadBool()
    state.lsMode = net.ReadUInt(2)
    state.water = net.ReadBool()
    state.propGravity = net.ReadBool()
    state.noclip = net.ReadUInt(2)
    state.pressure = net.ReadBool()
    state.stars = net.ReadBool()
    state.gasUse = net.ReadBool()
    state.sbLS = net.ReadBool()
    refresh()
end)

local function build(panel)
    panel:ClearControls()
    if panel.SetLabel then panel:SetLabel(L("agp_pw_title", "PowerGrid")) end
    panelRef = panel
    panel:Help(L("agp_pw_help", "PowerGrid is the energy network of Ascension Gates. Without Spacebuild, gates, shields, weapons and ships take their power from it: ZPMs, generators and storages feed it."))
    panel.AGPStatus = panel:Help("")
    panel.AGPStatus:SetTextColor(Color(255, 190, 80))
    panel:Help(L("agp_pw_mode", "How parts connect (server setting):"))
    panel.AGPModeButtons = {}
    for _, m in ipairs(MODES) do
        local b = panel:Button("")
        b.AGPValue, b.AGPLabel = m[1], L(m[2], m[3])
        b.DoClick = function() set("agp_power_mode", m[1]) end
        b:SetTooltip(L(m[4], m[5]))
        panel.AGPModeButtons[#panel.AGPModeButtons + 1] = b
    end
    panel.AGPBackend = panel:Button("")
    panel.AGPBackend.DoClick = function() set("agp_power_backend", state.backend == 1 and 0 or 1) end
    panel.AGPBackend:SetTooltip(L("agp_pw_tip_backend", "On: use PowerGrid even when Spacebuild is installed (after a map change)."))
    if scripted_ents.GetStored("agp_blackhole_cache") then   -- the Black Hole Cache addon is installed
        panel.AGPCache = panel:Button("")
        panel.AGPCache.DoClick = function() set("agp_blackhole_cache_everyone", state.cacheEveryone and 0 or 1) end
        panel.AGPCache:SetTooltip(L("agp_pw_tip_cache", "Who may spawn the Black Hole Energy (it holds endless resources)."))
    end
    if StarGate then   -- Ascension Gates' own power settings (endless generators, ZPMs)
        panel.AGPInfinite = panel:Button("")
        panel.AGPInfinite.DoClick = function() set("agp_allow_infinite_power", state.infinite and 0 or 1) end
        panel.AGPInfinite:SetTooltip(L("agp_pw_tip_infinite", "Allow generators that need no fuel and never run dry (Asgard ion generator, Reactor Core). Off: they cannot be spawned and the ones standing go idle."))
        panel.AGPZPM = panel:Button("")
        panel.AGPZPM.DoClick = function() set("agp_zpm_overload", state.zpmOverload and 0 or 1) end
        panel.AGPZPM:SetTooltip(L("agp_pw_tip_zpm", "On: a ZPM that is not in a hub heats up when too much energy is drawn from it at once and explodes. Off: ZPMs never explode. The Tampered ZPM is a bomb and still explodes. Admins only."))
    end
    panel:CheckBox(L("agp_pw_cables", "Show cables (only for you)"), "agp_power_cables"):SetTooltip(L("agp_pw_tip_cables", "Draw the power cables between linked parts."))
    panel:CheckBox(L("agp_pw_cables_share", "Others see my cables"), "agp_power_cables_share"):SetTooltip(L("agp_pw_tip_cables_share", "Off: other players do not see the cables of your parts (you still see them yourself)."))
    panel:CheckBox(L("agp_pw_sounds", "Machine sounds (only for you)"), "agp_power_sounds"):SetTooltip(L("agp_pw_tip_sounds", "Hum and running sounds of the power parts."))
    -- life support
    local head = panel:Help(L("agp_ls_title", "Life Support"))
    head:SetFont("DermaDefaultBold")
    panel.AGPLSStatus = panel:Help("")
    panel.AGPLSStatus:SetTextColor(Color(255, 190, 80))
    panel.AGPSpaceButtons = {}
    for _, m in ipairs({ { 1, "agp_ls_space_maps", "Space simulation: space maps only", "agp_ls_tip_maps", "No air, cold and low gravity in space - only on space maps." },
            { 2, "agp_ls_space_all", "Space simulation: every map", "agp_ls_tip_all", "Space (no air, cold, low gravity) above every map's sky." },
            { 0, "agp_ls_space_off", "Space simulation: off", "agp_ls_tip_off", "No space: air and gravity everywhere." } }) do
        local b = panel:Button("")
        b.AGPValue, b.AGPLabel = m[1], L(m[2], m[3])
        b:SetTooltip(L(m[4], m[5]))
        b.DoClick = function() set("agp_ls_space", m[1]) end
        panel.AGPSpaceButtons[#panel.AGPSpaceButtons + 1] = b
    end
    -- water on every map, props in space, noclip in space, pressure, stars, breathing (all admin settings)
    local function adminToggle(field, cvar, stateKey, tipKey, tipText)
        local b = panel:Button("")
        b.DoClick = function() set(cvar, state[stateKey] and 0 or 1) end
        b:SetTooltip(L(tipKey, tipText))
        panel[field] = b
    end
    adminToggle("AGPWater", "agp_ls_water", "water", "agp_ls_tip_water", "Where there is no space simulation (an ordinary map), the suit still runs: a head under water costs suit air. Air everywhere else, normal gravity and temperature. Stays off while Spacebuild's own life support runs (unless Always PowerGrid is on).")
    adminToggle("AGPPropG", "agp_ls_prop_gravity", "propGravity", "agp_ls_tip_propg", "Loose props and contraptions have no gravity and no air drag in space, and a planet's gravity on a planet. Ships that fly by their own code are left alone.")
    panel:Help(L("agp_ls_noclip_head", "Noclip in space (on planets and inside ships it is always free):"))
    panel.AGPNoclipButtons = {}
    for _, m in ipairs({ { 1, "agp_ls_noclip_admin", "Admins and superadmins only (Spacebuild's rule)" }, { 0, "agp_ls_noclip_free", "Everyone" },
            { 2, "agp_ls_noclip_super", "Superadmins only" }, { 3, "agp_ls_noclip_none", "Nobody" } }) do
        local b = panel:Button("")
        b.AGPValue, b.AGPLabel = m[1], L(m[2], m[3])
        b:SetTooltip(L("agp_ls_tip_noclip", "Who may fly through space in noclip. Players already flying are put back on their feet when it is space."))
        b.DoClick = function() set("agp_ls_noclip", m[1]) end
        panel.AGPNoclipButtons[#panel.AGPNoclipButtons + 1] = b
    end
    adminToggle("AGPPressure", "agp_ls_pressure", "pressure", "agp_ls_tip_pressure", "On a planet with a pressure above 1.5 the suit's air is used to cope with it and an empty suit takes crushing damage. Not inside ships or life support areas.")
    adminToggle("AGPStars", "agp_ls_stars", "stars", "agp_ls_tip_stars", "Hot zones round a star, sunburn where the sun shines on you and a deadly zone in its middle. Not inside ships or life support areas.")
    adminToggle("AGPGasUse", "agp_ls_gas_use", "gasUse", "agp_ls_tip_gasuse", "Breathing turns the oxygen of a planet into carbon dioxide. Only a very small environment ever notices; a big planet never runs out.")
    panel:Help(L("agp_ls_reset_note", "Gas, gravity and temperature that devices change on a planet are reset when the map is cleaned up or restarted."))
    panel:CheckBox(L("agp_ls_fx_me", "Planet colour and bloom (only for you)"), "agp_ls_planet_fx"):SetTooltip(L("agp_ls_tip_fx", "The colour and glow some planets of a space map have while you are inside them."))
    if StarGate then   -- the gate report needs a Stargate addon (Ascension Gates)
        panel.AGPReport = panel:Button("")
        panel.AGPReport.DoClick = function() set("agp_ls_gate_report", state.report and 0 or 1) end
        panel.AGPReport:SetTooltip(L("agp_ls_tip_report", "Before you step through a gate: air, temperature and gravity on the other side."))
        panel:CheckBox(L("agp_ls_report_me", "Show gate report (only for you)"), "agp_gate_report_show"):SetTooltip(L("agp_ls_tip_report_me", "Show that report on your screen."))
    end
    -- the suit display's look (only for you)
    local hs = panel:ComboBox(L("agp_ls_hud_style", "Suit display"), "agp_ls_hud_style")
    if AGP.StyleCombo then AGP.StyleCombo(hs) end
    hs:SetTooltip(L("agp_ls_tip_hud_style", "How your suit's air, energy and coolant are shown at the bottom of the screen (only for you)."))
    hs:AddChoice(L("agp_ls_hud_s1", "One line"), 1)
    hs:AddChoice(L("agp_ls_hud_s2", "Arcs"), 2)
    hs:AddChoice(L("agp_ls_hud_s3", "Minimal"), 3)
    hs:AddChoice(L("agp_ls_hud_s4", "Classic"), 4)
    -- units (only for you)
    local ct = panel:ComboBox(L("agp_unit_temp", "Temperature"), "agp_unit_temp")
    if AGP.StyleCombo then AGP.StyleCombo(ct) end
    ct:SetTooltip(L("agp_pw_tip_temp", "How temperatures are shown (only for you)."))
    ct:AddChoice(L("agp_unit_auto", "Auto (your country)"), 0)
    ct:AddChoice("°C  Celsius", 1); ct:AddChoice("°F  Fahrenheit", 2); ct:AddChoice("K  Kelvin", 3)
    local cg = panel:ComboBox(L("agp_unit_gravity", "Gravity"), "agp_unit_gravity")
    if AGP.StyleCombo then AGP.StyleCombo(cg) end
    cg:SetTooltip(L("agp_pw_tip_gravity", "How gravity is shown (only for you)."))
    cg:AddChoice(L("agp_unit_auto_g", "Auto (g)"), 0)
    cg:AddChoice("g", 1); cg:AddChoice("m/s²", 2); cg:AddChoice("ft/s²", 3)
    panel:Help(L("agp_pw_note", "Manual / automatic / mix change right away. Off/on and \"Always PowerGrid\" (= also when Spacebuild is installed) need a map change."))
    net.Start("agp_power_set") net.WriteString("") net.WriteInt(0, 8) net.SendToServer() -- ask for the state
end

hook.Add("PopulateToolMenu", "AGP.PowerSettings", function()
    -- SpaceGrid's own settings (power + life support) live only in the SpaceGrid tab; the Stargate settings stay in
    -- Ascension Gates > Config
    spawnmenu.AddToolMenuOption("SpaceGrid", "Settings", "agp_power_settings", L("agp_pw_title", "PowerGrid"), "", "", build)
end)
