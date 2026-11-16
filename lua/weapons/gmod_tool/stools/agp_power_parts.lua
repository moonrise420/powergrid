-- PowerGrid: Grid Power Parts (SpaceGrid tab) - spawns every Grid Power part from one tool, like Spacebuild's
-- device tools. Pick the part in the picture grid, left click places it (welded to what you aim at, if wanted).
-- Right click: the same part again, turned 90 degrees. Reload: pick the part you aim at.
TOOL.Tab = "SpaceGrid"
TOOL.Category = "Grid Power"
TOOL.Name = "#tool.agp_power_parts.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar["class"] = "agp_cell_small"
TOOL.ClientConVar["weld"] = "1"
TOOL.ClientConVar["nocollide"] = "1"

-- the parts, in groups: PowerGrid's spawn list (sh_config.lua), with what other addons added (their names and icons
-- come from the entities)
local function groups()
    local out = {}
    for _, g in ipairs(PowerGrid.Groups) do
        local list = {}
        for cls, sp in pairs(PowerGrid.Spawn) do
            if sp.group == g.id and scripted_ents.GetStored(cls) then list[#list + 1] = { cls, sp.order } end
        end
        table.sort(list, function(x, y) if x[2] ~= y[2] then return x[2] < y[2] end return x[1] < y[1] end)
        local classes = {}
        for i, x in ipairs(list) do classes[i] = x[1] end
        if #classes > 0 then out[#out + 1] = { g.key, g.name, classes } end
    end
    return out
end
local function allowed(cls) return PowerGrid.Spawn[cls] ~= nil and scripted_ents.GetStored(cls) ~= nil end

local function L(k, d) return PowerGrid.L(k, d) end

if CLIENT then
    -- at load and again whenever the player changes the language (hook from powergrid/sh_texts.lua)
    local function addNames()
        language.Add("tool.agp_power_parts.name", L("agp_tool_parts_name", "PowerGrid Parts"))
        language.Add("tool.agp_power_parts.desc", L("agp_tool_parts_desc", "Place energy cells, generators, nodes, tanks and life support"))
        language.Add("tool.agp_power_parts.left", L("agp_tool_parts_left", "Place the chosen part"))
        language.Add("tool.agp_power_parts.right", L("agp_tool_parts_right", "Place it turned by 90 degrees"))
        language.Add("tool.agp_power_parts.reload", L("agp_tool_parts_reload", "Choose the part you aim at"))
    end
    addNames()
    hook.Add("PowerGrid.LanguageChanged", "agp_power_parts.names", addNames)
end
TOOL.Information = { { name = "left" }, { name = "right" }, { name = "reload" } }

function TOOL:Place(tr, turn)
    if (CLIENT) then return true end
    local ply = self:GetOwner()
    local cls = self:GetClientInfo("class")
    if (not allowed(cls) or not tr.Hit) then return false end
    if (IsValid(tr.Entity) and tr.Entity:IsPlayer()) then return false end
    if (StarGate and StarGate.NotSpawnable and StarGate.NotSpawnable(cls, ply)) then return false end
    if (not gamemode.Call("PlayerSpawnSENT", ply, cls)) then return false end
    local st = scripted_ents.Get(cls)
    local e = st and st.SpawnFunction and st:SpawnFunction(ply, tr, cls)
    if (not IsValid(e)) then return false end
    if (turn) then e:SetAngles(e:GetAngles() + Angle(0, 90, 0)) end
    if (e.CPPISetOwner) then e:CPPISetOwner(ply) end
    gamemode.Call("PlayerSpawnedSENT", ply, e)
    undo.Create("SENT"); undo.AddEntity(e)
    local hit = tr.Entity
    if (IsValid(hit) and not hit:IsWorld() and self:GetClientNumber("weld") == 1) then
        local w = constraint.Weld(e, hit, 0, tr.PhysicsBone or 0, 0, self:GetClientNumber("nocollide") == 1)
        if (IsValid(w)) then undo.AddEntity(w) end
    end
    undo.SetPlayer(ply); undo.SetCustomUndoText("Undone " .. (e.PrintName or cls)); undo.Finish()
    ply:AddCleanup("sents", e)
    return true
end

function TOOL:LeftClick(tr) return self:Place(tr, false) end
function TOOL:RightClick(tr) return self:Place(tr, true) end

function TOOL:Reload(tr)
    local e = tr.Entity
    if (not IsValid(e) or not allowed(e:GetClass())) then return false end
    if (SERVER) then self:GetOwner():ConCommand("agp_power_parts_class " .. e:GetClass()) end
    return true
end

if CLIENT then
    -- ghost of the chosen part where it would land
    function TOOL:Think()
        local cls = self:GetClientInfo("class")
        local st = scripted_ents.GetStored(cls)
        local mdl = st and st.t.AGPModel
        if (not mdl) then self:ReleaseGhostEntity() return end
        if (not IsValid(self.GhostEntity) or self.GhostEntity:GetModel() ~= mdl) then
            self:MakeGhostEntity(mdl, vector_origin, angle_zero)
        end
        local g = self.GhostEntity
        if (not IsValid(g)) then return end
        local tr = self:GetOwner():GetEyeTrace()
        if (not tr.Hit) then g:SetNoDraw(true) return end
        g:SetNoDraw(false)
        g:SetAngles(Angle(0, (self:GetOwner():GetAimVector():Angle().y + 180) % 360, 0))
        g:SetPos(tr.HitPos - Vector(0, 0, g:OBBMins().z))
    end
end

function TOOL.BuildCPanel(panel)
    panel:Help(L("agp_tool_parts_help", "Pick a part, then left click where it should stand. On a ship it is welded to what you aim at. Link the parts with the PowerGrid Connector tool (or set PowerGrid to automatic)."))
    for _, g in ipairs(groups()) do
        local head = panel:Help(L(g[1], g[2]))
        head:SetFont("DermaDefaultBold")
        local grid = vgui.Create("DIconLayout")
        grid:SetSpaceX(4); grid:SetSpaceY(4)
        for _, cls in ipairs(g[3]) do
            local st = scripted_ents.GetStored(cls)
            local name = st and (st.t.AGPNameKey and L(st.t.AGPNameKey, st.t.PrintName) or st.t.PrintName) or cls
            local b = grid:Add("DImageButton")
            b:SetSize(64, 64)
            b:SetImage(PowerGrid.IconOf and PowerGrid.IconOf(cls) or ("entities/" .. cls .. ".png"))
            b:SetTooltip(name)
            b.DoClick = function() RunConsoleCommand("agp_power_parts_class", cls); surface.PlaySound("ui/buttonclickrelease.wav") end
            b.PaintOver = function(self2, w, h)
                if (GetConVarString("agp_power_parts_class") == cls) then
                    surface.SetDrawColor(235, 190, 90, 255); surface.DrawOutlinedRect(0, 0, w, h, 3)
                end
            end
        end
        panel:AddItem(grid)
    end
    panel:CheckBox(L("agp_tool_parts_weld", "Weld to what I aim at (ships, props)"), "agp_power_parts_weld")
    panel:CheckBox(L("agp_tool_parts_nocollide", "No collision with it"), "agp_power_parts_nocollide")
end
