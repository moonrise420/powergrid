-- PowerGrid: spawn tab (parts in groups), tools tab (connector, parts tool, settings, About)
local L = PowerGrid.L

-- tools tab "PowerGrid" (its id stays "SpaceGrid": the tools and Ascension Gates' energy tools sit in it)
hook.Add("AddToolMenuTabs", "PowerGrid.Tabs", function()
	spawnmenu.AddToolTab("SpaceGrid", "PowerGrid", "icon16/lightning.png")
	spawnmenu.AddToolCategory("SpaceGrid", "Connector", " " .. L("agp_cat_connector", "Connect Power"))
	spawnmenu.AddToolCategory("SpaceGrid", "Grid Power", " " .. L("agp_cat_power", "PowerGrid"))
	spawnmenu.AddToolCategory("SpaceGrid", "Settings", " " .. L("agp_cat_settings", "Settings"))
end)

-- a part's menu icon: materials/entities/<class>.png; parts other addons add may only have the older kind
-- (materials/vgui/entities/<class>.vmt) - without this the menu showed the purple-black missing texture for them
-- (2026-11-12: the black hole power core and the ZPM analyser)
function PowerGrid.IconOf(class)
	if file.Exists("materials/entities/" .. class .. ".png", "GAME") then return "entities/" .. class .. ".png" end
	if file.Exists("materials/vgui/entities/" .. class .. ".vmt", "GAME") then return "vgui/entities/" .. class end
	return "entities/" .. class .. ".png"
end

-- spawn tab: one node per group, the parts sorted by PowerGrid.Spawn order (other addons add theirs there)
local function partsOf(group)
	local out = {}
	for class, s in pairs(PowerGrid.Spawn) do
		local st = s.group == group and scripted_ents.GetStored(class)
		if st then out[#out + 1] = { class = class, order = s.order, t = st.t, cmd = s.cmd } end
	end
	table.sort(out, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.class < b.class end)
	return out
end

hook.Add("PopulatePowerGrid", "PowerGrid.Spawn", function(content, tree)
	local first
	for _, g in ipairs(PowerGrid.Groups) do
		local list = partsOf(g.id)
		if #list > 0 then
			local node = tree:AddNode(L(g.key, g.name), "icon16/lightning.png")
			node.DoPopulate = function(self)
				if self.PropPanel then return end
				self.PropPanel = vgui.Create("ContentContainer", content)
				self.PropPanel:SetVisible(false)
				self.PropPanel:SetTriggerSpawnlistChange(false)
				for _, p in ipairs(list) do
					local icon = spawnmenu.CreateContentIcon("entity", self.PropPanel, {
						nicename = (p.t.AGPNameKey and L(p.t.AGPNameKey, p.t.PrintName)) or p.t.PrintName or p.class,
						spawnname = p.class,
						material = PowerGrid.IconOf(p.class),
						admin = p.t.AdminOnly or p.t.AGPAdminOnly, -- AGP 2026-11-08: + AGPAdminOnly (the Black Hole Cache had no admin badge)
					})
					if p.cmd and IsValid(icon) then   -- spawned by its own addon's command
						icon.DoClick = function()
							RunConsoleCommand(p.cmd, p.class)
							surface.PlaySound("ui/buttonclickrelease.wav")
						end
					end
				end
			end
			node.DoClick = function(self)
				self:DoPopulate()
				content:SwitchPanel(self.PropPanel)
			end
			first = first or node
		end
	end
	if first then first:InternalDoClick() end
end)

spawnmenu.AddCreationTab("PowerGrid", function()
	local ctrl = vgui.Create("SpawnmenuContentPanel")
	ctrl:CallPopulateHook("PopulatePowerGrid")
	return ctrl
end, "icon16/lightning.png", 60)

-- update check (GitHub releases), only on click ---------------------------------------------------------------
local function nums(v)
	local t = {}
	for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n); if #t == 3 then break end end
	return t
end
local function newer(a, b)
	local x, y = nums(a), nums(b)
	for i = 1, 3 do
		local p, q = x[i] or 0, y[i] or 0
		if p ~= q then return p > q end
	end
	return false
end
local function say(text) chat.AddText(Color(120, 200, 255), "[PowerGrid] ", color_white, text) end

-- installed from the Steam Workshop? Steam updates it then; the GitHub check is for manual installs
function PowerGrid.FromWorkshop()
	for _, a in ipairs(engine.GetAddons()) do
		if a.mounted and string.find(string.lower(a.title or ""), "powergrid", 1, true) then return true end
	end
	return false
end

function PowerGrid.CheckForUpdate()
	local repo = PowerGrid.Links.GitHub:match("github%.com/([^/]+/[^/#?]+)")
	if not repo then return end
	repo = repo:gsub("%.git$", "")
	say(L("agp_upd_checking", "Checking GitHub for a new version..."))
	http.Fetch("https://api.github.com/repos/" .. repo .. "/releases/latest", function(body, _, _, code)
		local t = code == 200 and util.JSONToTable(body or "")
		local tag = istable(t) and t.tag_name
		if not tag then say(L("agp_upd_failed", "Could not reach GitHub. Try again later.")) return end
		if newer(tag, PowerGrid.Version) then
			local msg = L("agp_upd_new", "Version %s is out (you have %s).", tag, PowerGrid.Version)
			say(msg)
			local q = Derma_Query(msg, "PowerGrid", L("agp_upd_open", "Open the download page"),
				function() gui.OpenURL(t.html_url or PowerGrid.Links.GitHub) end, L("agp_upd_later", "Later"))
			if AGP and AGP.ApplySkin then AGP.ApplySkin(q) end   -- our look (cl_skin.lua)
		else
			say(L("agp_upd_current", "You have the newest version (%s).", PowerGrid.Version))
		end
	end, function() say(L("agp_upd_failed", "Could not reach GitHub. Try again later.")) end)
end

-- About: version, links, update check, tip, licence
local function about(panel)
	panel:ClearControls()
	if panel.SetLabel then panel:SetLabel(L("agp_pg_about_title", "About PowerGrid")) end   -- the page heading (was "Label")
	panel:Help("PowerGrid " .. PowerGrid.Version)
	panel:Help(L("agp_pg_about", "Resource network and life support: energy, oxygen, water and more, for any addon. Works alone or with Spacebuild."))
	local links = PowerGrid.Links
	if links.Workshop ~= "" then panel:Button("PowerGrid (Steam Workshop)").DoClick = function() gui.OpenURL(links.Workshop) end end
	if links.GitHub ~= "" then panel:Button("PowerGrid (GitHub)").DoClick = function() gui.OpenURL(links.GitHub) end end
	if links.GitHub ~= "" and not PowerGrid.FromWorkshop() then
		panel:Button(L("agp_upd_button", "Check for updates")).DoClick = function() PowerGrid.CheckForUpdate() end
	end
	if links.Tip ~= "" then panel:Button(L("agp_btn_tip", "Support / Tip")).DoClick = function() gui.OpenURL(links.Tip) end end
	panel:Help(PowerGrid.LicenseLine or "")
end

hook.Add("PopulateToolMenu", "PowerGrid.About", function()
	spawnmenu.AddToolMenuOption("SpaceGrid", "Settings", "powergrid_about", L("agp_pg_about_title", "About PowerGrid"), "", "", about)
end)
