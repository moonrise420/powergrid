-- Ascension Gates / SpaceGrid: Grid Power Connector - links parts to one power network, like Spacebuild's Smart Link
-- Tool. Works with our own power network (Grid Power) and with Spacebuild/RD (CAF) when that runs.
--   Left click: select parts (as many as you like, they turn blue).
--   Right click on a part or a power node: link all selected parts to it.
--   Reload: clear the selection; with nothing selected, Reload on a part removes all its links (Grid Power) or shows
--   what its network holds.
TOOL.Tab = "SpaceGrid"
TOOL.Category = "Connector"
TOOL.Name = "#tool.agp_power_link.name"
TOOL.Command = nil
TOOL.ConfigName = ""

local function L(k, d) return PowerGrid.L(k, d) end
if CLIENT then
    -- at load and again whenever the player changes the language (hook from powergrid/sh_texts.lua)
    local function addNames()
        language.Add("tool.agp_power_link.name", L("agp_tool_link_name", "PowerGrid Connector"))
        language.Add("tool.agp_power_link.desc", L("agp_tool_link_desc", "Connect parts to one power network"))
        language.Add("tool.agp_power_link.left", L("agp_tool_link_left", "Select a part (as many as you like)"))
        language.Add("tool.agp_power_link.right", L("agp_tool_link_right", "Link all selected parts to this part or power node"))
        language.Add("tool.agp_power_link.reload", L("agp_tool_link_reload", "Clear the selection / remove a part's links"))
    end
    addNames()
    hook.Add("PowerGrid.LanguageChanged", "agp_power_link.names", addNames)
end
TOOL.Information = { { name = "left" }, { name = "right" }, { name = "reload" } }

local function say(ply, key, fallback, ...) PowerGrid.Say(ply, key, fallback, ...) end

-- the selection is shown with a blue outline on the selecting player's screen (it was a colour, and ZPMs and other
-- parts set their own colour every tick, so they never looked selected)
if SERVER then
    util.AddNetworkString("agp_link_sel")
    function TOOL:SendSel()
        local ply = self:GetOwner()
        if not IsValid(ply) then return end
        local list = {}
        for e in pairs(self.Sel or {}) do if IsValid(e) then list[#list + 1] = e end end
        net.Start("agp_link_sel")
        net.WriteUInt(#list, 10)
        for _, e in ipairs(list) do net.WriteEntity(e) end
        net.Send(ply)
    end
else
    local sel = {}
    net.Receive("agp_link_sel", function()
        sel = {}
        for i = 1, net.ReadUInt(10) do sel[#sel + 1] = net.ReadEntity() end
    end)
    hook.Add("PreDrawHalos", "AGP.LinkSelection", function()
        if #sel == 0 then return end
        local list = {}
        for _, e in ipairs(sel) do if IsValid(e) then list[#list + 1] = e end end
        if #list > 0 then halo.Add(list, Color(80, 160, 255), 3, 3, 2, true, true) end
    end)
end
local function name(e) return e.AGPNameKey or e.PrintName or e:GetClass() end

-- the network in use: our Grid Power, or Spacebuild's Resource Distribution (CAF)
local function rd() return PowerGrid.RD3() and CAF.GetAddon("Resource Distribution") end
local function linkable(e)
    if not IsValid(e) or e:IsPlayer() or e:IsWorld() then return false end
    local R = rd()
    if R then return e.IsNode or table.Count(R.GetEntityTable(e) or {}) > 0 end
    return PowerGrid.Active and AGP.Power.Parts[e] ~= nil or e.IsAGPPower or (e.AGPRes and next(e.AGPRes)) or e.HasRD
end

-- AGP 2026-11-08: in Automatic power mode links do nothing (parts share through welds, constraints and parents); the tool
-- said "Linked N parts" and drew cables anyway. Now it says how Automatic mode works and links nothing
local function automatic(ply)
    if rd() or not (PowerGrid.Active and AGP.Power.LinksUsed) or AGP.Power.LinksUsed() then return false end
    say(ply, "agp_msg_link_auto", "Automatic power mode: parts share power when they are welded, constrained or parented together - links are not used here (they work in Manual and Mix mode).")
    return true
end

function TOOL:LeftClick(tr)
    local e = tr.Entity
    if not IsValid(e) or e:IsPlayer() then return false end
    if CLIENT then return true end
    local ply = self:GetOwner()
    if automatic(ply) then return false end   -- AGP 2026-11-08
    if not linkable(e) then say(ply, "agp_msg_link_nopower", "This part does not use power.") return false end
    self.Sel = self.Sel or {}
    if self.Sel[e] then   -- clicked again: deselect
        self.Sel[e] = nil; self:SendSel()
        return true
    end
    self.Sel[e] = true
    self:SendSel()
    return true
end

function TOOL:RightClick(tr)
    local target = tr.Entity
    if not IsValid(target) then return false end
    if CLIENT then return true end
    local ply = self:GetOwner()
    if automatic(ply) then self.Sel = {}; self:SendSel() return false end   -- AGP 2026-11-08
    if not self.Sel or not next(self.Sel) then say(ply, "agp_msg_link_none", "Select parts first (left click).") return false end
    local R = rd()
    local n = 0
    for e in pairs(self.Sel) do
        if IsValid(e) and e ~= target then
            if R then
                if not target.IsNode then say(ply, "agp_msg_link_nonode", "Spacebuild runs here: link to a power node.") break end
                if e.IsNode then R.linkNodes(e.netid, target.netid) else R.Link(e, target.netid) end
                n = n + 1
            elseif PowerGrid.Active and AGP.Power.Link(e, target) then
                n = n + 1
            end
        end
    end
    self.Sel = {}
    self:SendSel()
    if n > 0 then say(ply, "agp_msg_link_done_n", "Linked %d parts to %s.", n, name(target)) end
    return n > 0
end

function TOOL:Reload(tr)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if self.Sel and next(self.Sel) then
        self.Sel = {}
        self:SendSel()
        return true
    end
    local e = tr.Entity
    if not IsValid(e) then return false end
    if rd() then
        if not e.IsNode and table.Count(rd().GetEntityTable(e) or {}) > 0 then rd().Unlink(e); say(ply, "agp_msg_link_removed", "All links of %s removed.", name(e)) end
        return true
    end
    if not (PowerGrid.Active and AGP.Power.Parts[e]) then return false end
    if ply:KeyDown(IN_SPEED) then   -- Shift + Reload: what the network holds
        local sum, n = AGP.Power.Summary(e)
        local t = {}
        for res, v in SortedPairs(sum) do t[#t + 1] = res .. " " .. math.floor(v.amount) .. "/" .. math.floor(v.max) end
        say(ply, "agp_msg_link_summary", "%d parts: %s", n, #t > 0 and table.concat(t, ", ") or "agp_msg_link_nothing")
    else
        AGP.Power.UnlinkAll(e)
        say(ply, "agp_msg_link_removed", "All links of %s removed.", name(e))
    end
    return true
end

function TOOL:Holster()
    if SERVER and self.Sel then
        self.Sel = {}
        self:SendSel()
    end
end

function TOOL.BuildCPanel(panel)
    panel:Help(L("agp_tool_link_help", "Left click the parts to connect (they turn blue), then right click the part or power node they should link to. Reload clears the selection; Reload on a part removes its links, Shift + Reload shows what its network holds. With Spacebuild running, link to a power node (ours or Spacebuild's)."))
    panel:CheckBox(L("agp_pw_cables", "Show cables (only for you)"), "agp_power_cables")
    panel:CheckBox(L("agp_pw_cables_share", "Others see my cables"), "agp_power_cables_share")
end
