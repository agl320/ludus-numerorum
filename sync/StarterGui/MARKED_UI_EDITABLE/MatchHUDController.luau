-- Drives the authored MatchHUD (StarterGui.MARKED_UI_EDITABLE.MatchHUD): layout, live values and buttons.
-- The artwork is cut from the in-game HUD reference (1672 x 941); each group is pinned to its screen edge and
-- scaled uniformly so the layout matches the reference at 16:9 and keeps its corners on wider/taller screens.
local Players = game:GetService("Players")
-- your number on the HUD is drawn in your equipped number style (Numberfall.NumberStyles), same as your visor
local NumberStyles = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NumberStyles"))

local HUD = {}
HUD.__index = HUD

local REF_W, REF_H = 1672, 941
local BONE = Color3.fromRGB(236, 228, 224)
local RED = Color3.fromRGB(255, 34, 58)
local ARROW_ELIMINATED = Color3.fromRGB(255, 34, 58)   -- arrow tint on rows where you were the one eliminated
local KEY_NAMES = {LeftShift = "LeftShift", RightShift = "RightShift", LeftControl = "LeftCtrl", RightControl = "RightCtrl", LeftAlt = "LeftAlt"}

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function aliveHumanoid(p)
	local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return p:GetAttribute("InArena") == true and h and h.Health > 0
end

function HUD.new(view)
	local gui = view.gui
	local root = gui:WaitForChild("MatchHUD")
	local self = setmetatable({view = view, gui = gui, root = root, lastText = 0}, HUD)
	self.groups = {}
	for _, g in root:GetChildren() do
		if g:IsA("Frame") and g:GetAttribute("RefX") then table.insert(self.groups, g) end
	end
	root.Visible = false

	local function show(panel) return function() view:Show(panel) end end
	root.YourNumber.Help.Activated:Connect(function() view:ToggleHelp() end)
	root.Rail.Play.Activated:Connect(show(nil))
	root.Rail.Shop.Activated:Connect(show("Shop"))
	root.Rail.Inventory.Activated:Connect(show("Inventory"))
	root.Rail.Quests.Activated:Connect(show("Quests"))
	root.Rail.Settings.Activated:Connect(show("Settings"))
	root.Rail.Credits.Activated:Connect(show("Leaderboard")) -- the people icon opens the players leaderboard
	root.SideButtons.Quests.Activated:Connect(show("Quests"))
	root.SideButtons.Community.Activated:Connect(function()
		view.player:SetAttribute("OpenCommunity", os.clock()) -- StarterPlayerScripts.CommunityCard
	end)
	root.TypePrompt.Open.Activated:Connect(function()
		if view.openEntry then view.openEntry() end
	end)
	-- touch players have no keyboard: the movement hint doubles as the run / slide buttons
	root.MoveHint.Run.Activated:Connect(function()
		if view.feel and not view.open then view.feel:SetSprint(not view.feel.sprint) end
	end)
	root.MoveHint.Slide.Activated:Connect(function()
		if view.feel and not view.open then view.feel:Slide() end
	end)
	self:BuildDock()
	self:BuildMoves()
	return self
end

-- ===== LOBBY DOCK =====
-- The lobby's left menu (once you've deployed): only what you need out here -- MAIN MENU, then SHOP / LOADOUT,
-- then PLAYERS / SETTINGS. Daily reward, quests and community live on the main menu only. One dark panel, plain
-- rows: an icon (the main menu's own icon sheet), the name, and its key as a real key cap on the right. Hover
-- slides in a red bar and a soft wash. Built in the authored Rail group (keeps its screen position / scaling).
local DOCK_INK = Color3.fromRGB(10, 6, 8)
local DOCK_LINE = Color3.fromRGB(74, 24, 36)
local DOCK_HOVER = Color3.fromRGB(120, 6, 32)
local DOCK_MUTED = Color3.fromRGB(196, 182, 186)
local DOCK_ICON = Color3.fromRGB(255, 40, 70)
local DOCK_FONT = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold)
local DOCK_MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local DOCK_SANS = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
local ICON_SHEET = "rbxassetid://104838052460312"
-- {button, label, key, icon cell on the sheet}. Once a round has started (you're in the arena) only PLAYERS and
-- SETTINGS stay: no shop, loadout or main menu mid-round (HUD:LayoutDock).
local DOCK = {
	{"Play", "MAIN MENU", "P", Vector2.new(290, 287)}, "|",
	{"Shop", "SHOP", "F2", Vector2.new(538, 287)}, {"Inventory", "LOADOUT", "I", Vector2.new(782, 287)}, "|",
	{"Credits", "PLAYERS", "TAB", Vector2.new(538, 513)}, {"Stats", "STATS", "K", Vector2.new(290, 61)}, {"Settings", "SETTINGS", "F4", Vector2.new(51, 61)},
}
local MAIN_MENU_ONLY = {Daily = true, Quests = true, Community = true}
local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o; return c end
-- a key cap like the ones in Help: dark, a thin red-brown edge and a soft top light
local function keyCap(parent, txt)
	local TS = game:GetService("TextService")
	local w = math.max(30, TS:GetTextSize(txt, 13, Enum.Font.RobotoMono, Vector2.new(200, 40)).X + 16)
	local cap = Instance.new("Frame"); cap.Name = "DockKey"; cap.BorderSizePixel = 0; cap.BackgroundColor3 = Color3.fromRGB(34, 18, 23)
	cap.AnchorPoint = Vector2.new(1, 0.5); cap.Position = UDim2.new(1, -10, 0.5, 0); cap.Size = UDim2.fromOffset(w, 24); cap.ZIndex = 8; cap.Parent = parent
	corner(cap, 4)
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(104, 44, 58); s.Thickness = 1; s.Parent = cap
	local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(165, 155, 160)); g.Parent = cap
	local l = Instance.new("TextLabel"); l.Name = "Key"; l.BackgroundTransparency = 1; l.Text = txt; l.FontFace = DOCK_MONO; l.TextSize = 13
	l.TextColor3 = BONE; l.Size = UDim2.fromScale(1, 1); l.ZIndex = 9; l.Parent = cap
	return cap, s
end
function HUD:BuildDock()
	local view, rail = self.view, self.root.Rail
	local art = rail:FindFirstChild("Rail"); if art and art:IsA("ImageLabel") then art.Visible = false end
	-- main-menu-only buttons stay out of the in-match menu
	for name in pairs(MAIN_MENU_ONLY) do local b = rail:FindFirstChild(name); if b and b:IsA("GuiObject") then b.Visible = false end end
	local BW, BH, PAD, SEP = 224, 44, 8, 13
	self.dockMetrics = {BW = BW, BH = BH, PAD = PAD, SEP = SEP}
	self.dockItems = {}
	local old = rail:FindFirstChild("DockPanel"); if old then old:Destroy() end
	local oldHint = rail:FindFirstChild("DockHint"); if oldHint then oldHint:Destroy() end
	local panel = Instance.new("Frame"); panel.Name = "DockPanel"; panel.BorderSizePixel = 0; panel.BackgroundColor3 = DOCK_INK
	panel.BackgroundTransparency = 0.15; panel.Size = UDim2.fromScale(1, 1); panel.ZIndex = 4; panel.Parent = rail
	corner(panel, 10)
	local ps = Instance.new("UIStroke"); ps.Color = DOCK_LINE; ps.Thickness = 1; ps.Transparency = 0.15; ps.Parent = panel
	local pg = Instance.new("UIGradient"); pg.Rotation = 90
	pg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.12)}); pg.Parent = panel
	self.dock = {}
	local y = PAD
	for _, spec in ipairs(DOCK) do
		if spec == "|" then
			local div = Instance.new("Frame"); div.Name = "DockDivider"; div.BorderSizePixel = 0; div.BackgroundColor3 = DOCK_LINE
			div.Size = UDim2.new(1, -32, 0, 1); div.ZIndex = 5; div.Parent = panel
			table.insert(self.dockItems, {divider = div})
			continue
		end
		local b = rail:FindFirstChild(spec[1])
		if not b then b = Instance.new("TextButton"); b.Name = spec[1]; b.Text = ""; b.Parent = rail end
		if spec[1] == "Play" and not b:GetAttribute("DockWired") then
			b:SetAttribute("DockWired", true)
			b.Activated:Connect(function() if view.remote then view.remote:FireServer("Menu") end end)
		end
		-- STATS: your lifetime stats page (StarterPlayerScripts.LifetimeStats)
		if spec[1] == "Stats" and not b:GetAttribute("DockWired") then
			b:SetAttribute("DockWired", true)
			b.Activated:Connect(function() view.player:SetAttribute("OpenStats", os.clock()) end)
		end
		for _, c in ipairs(b:GetChildren()) do
			if c:IsA("GuiObject") then c.Visible = false end -- old glyphs / locked shade
			if c:IsA("UIStroke") then c.Enabled = false end
		end
		b.Visible = true; b.AutoButtonColor = false; b.Text = ""
		b.Position = UDim2.fromOffset(PAD, y); b.Size = UDim2.fromOffset(BW - PAD * 2, BH)
		b.BackgroundColor3 = DOCK_HOVER; b.BackgroundTransparency = 1; b.ZIndex = 6
		if not b:FindFirstChildOfClass("UICorner") then corner(b, 6) end
		local wash = b:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
		wash.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.85)}); wash.Parent = b
		local bar = Instance.new("Frame"); bar.Name = "DockAccent"; bar.BorderSizePixel = 0; bar.BackgroundColor3 = RED
		bar.AnchorPoint = Vector2.new(0, 0.5); bar.Position = UDim2.new(0, 0, 0.5, 0); bar.Size = UDim2.new(0, 2, 0, 0); bar.ZIndex = 8; bar.Parent = b
		corner(bar, 1)
		local icon = Instance.new("ImageLabel"); icon.Name = "DockIcon"; icon.BackgroundTransparency = 1; icon.Image = ICON_SHEET
		icon.ImageRectOffset = spec[4]; icon.ImageRectSize = Vector2.new(196, 196); icon.ImageColor3 = DOCK_ICON
		icon.AnchorPoint = Vector2.new(0.5, 0.5); icon.Position = UDim2.new(0, 26, 0.5, 0); icon.Size = UDim2.fromOffset(22, 22)
		icon.ZIndex = 8; icon.Parent = b
		local l = Instance.new("TextLabel"); l.Name = "DockLabel"; l.BackgroundTransparency = 1; l.Text = spec[2]; l.FontFace = DOCK_FONT; l.TextSize = 21
		l.TextColor3 = DOCK_MUTED; l.TextXAlignment = Enum.TextXAlignment.Left
		l.Position = UDim2.fromOffset(48, 0); l.Size = UDim2.new(1, -110, 1, 0); l.ZIndex = 8; l.Parent = b
		local cap, capStroke = keyCap(b, spec[3])
		local TS = game:GetService("TweenService")
		local quick = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local function paint(hover)
			TS:Create(b, quick, {BackgroundTransparency = hover and 0.25 or 1}):Play()
			TS:Create(bar, quick, {Size = UDim2.new(0, 2, 0, hover and 26 or 0)}):Play()
			TS:Create(l, quick, {TextColor3 = hover and BONE or DOCK_MUTED, Position = UDim2.fromOffset(hover and 52 or 48, 0)}):Play()
			TS:Create(icon, quick, {ImageColor3 = hover and BONE or DOCK_ICON}):Play()
			capStroke.Color = hover and Color3.fromRGB(255, 90, 115) or Color3.fromRGB(104, 44, 58)
		end
		b.MouseEnter:Connect(function() paint(true) end)
		b.MouseLeave:Connect(function() paint(false) end)
		paint(false)
		self.dock[spec[1]] = {button = b}
		table.insert(self.dockItems, {button = b, name = spec[1]})
	end
	-- footer: out here the mouse is on the camera, so the rows only take clicks once ALT frees it
	local foot = Instance.new("Frame"); foot.Name = "DockHint"; foot.BackgroundTransparency = 1; foot.Size = UDim2.new(1, -PAD * 2, 0, 30); foot.ZIndex = 6; foot.Parent = rail
	local fl = Instance.new("Frame"); fl.Name = "Line"; fl.BorderSizePixel = 0; fl.BackgroundColor3 = DOCK_LINE; fl.Position = UDim2.fromOffset(8, 0); fl.Size = UDim2.new(1, -16, 0, 1); fl.ZIndex = 6; fl.Parent = foot
	local fcap = keyCap(foot, "CAPS"); fcap.AnchorPoint = Vector2.new(0, 0.5); fcap.Position = UDim2.new(0, 14, 0.5, 3); fcap.Size = UDim2.fromOffset(46, 20); fcap.Key.TextSize = 11
	local ft = Instance.new("TextLabel"); ft.Name = "Text"; ft.BackgroundTransparency = 1; ft.Text = "FREE THE MOUSE TO CLICK"; ft.FontFace = DOCK_SANS; ft.TextSize = 12
	ft.TextColor3 = Color3.fromRGB(150, 136, 140); ft.TextXAlignment = Enum.TextXAlignment.Left; ft.Position = UDim2.fromOffset(68, 3); ft.Size = UDim2.new(1, -72, 1, -3); ft.ZIndex = 7; ft.Parent = foot
	self.dockHint = foot
	self.dockRound = nil
	self:LayoutDock(false)
end
-- stack the dock's rows: everything in the lobby courtyard; mid-round only PLAYERS and SETTINGS
local ROUND_ROWS = {Credits = true, Settings = true}
function HUD:LayoutDock(inRound)
	if self.dockRound == inRound or not self.dockItems then return end
	self.dockRound = inRound
	local m = self.dockMetrics
	local y, lastWasRow = m.PAD, false
	local pendingDivider
	for _, it in ipairs(self.dockItems) do
		if it.divider then
			it.divider.Visible = false
			if lastWasRow then pendingDivider = it.divider end
		else
			local show = not inRound or ROUND_ROWS[it.name] == true
			it.button.Visible = show
			if show then
				-- a group break only between two visible rows
				if pendingDivider then
					pendingDivider.Visible = true; pendingDivider.Position = UDim2.fromOffset(16, y + m.SEP / 2 - 1)
					y += m.SEP; pendingDivider = nil
				end
				it.button.Position = UDim2.fromOffset(m.PAD, y)
				y += m.BH; lastWasRow = true
			end
		end
	end
	-- the ALT hint sits under the rows (keyboard only: touch taps the rows directly)
	local UIS = game:GetService("UserInputService")
	if self.dockHint then
		local show = (self.view.player:GetAttribute("InputMode") or "keyboard") == "keyboard"
		self.dockHint.Visible = show
		if show then self.dockHint.Position = UDim2.fromOffset(m.PAD, y + 4); y += 34 end
	end
	local rail = self.root.Rail
	rail.Size = UDim2.fromOffset(m.BW, y + m.PAD)
	-- mid-round the round minimap sits under your number (top-left), so the (shorter) dock moves down under the
	-- map (and its zone pill)
	local map = self.root:FindFirstChild("Minimap")
	if rail:GetAttribute("LobbyRefY") == nil then rail:SetAttribute("LobbyRefY", rail:GetAttribute("RefY")) end
	if inRound and map and map:GetAttribute("RefY") then
		rail:SetAttribute("RefY", map:GetAttribute("RefY") + map.Size.Y.Offset + 24)
	else
		rail:SetAttribute("RefY", rail:GetAttribute("LobbyRefY"))
	end
	self.scale = nil -- re-lay the HUD groups (the rail changed size / place)
end

-- ===== MOVES =====
-- Bottom-left: one slim bar with a segment per move -- a button cap and its name side by side: [L3] SPRINT
-- [B] SLIDE [X] DASH [LT] CROUCH [Y] NUMBER. A segment lights up red while the move is happening, and a thin line
-- under its cap refills while it's on cooldown. Only shown with a gamepad (player attribute InputMode, set by
-- StarterPlayerScripts.PadControls); touch screens get their own buttons there, and on keyboard the controls
-- live in Help (H).
local SHORT_KEYS = {LeftShift = "SHIFT", RightShift = "SHIFT", LeftControl = "CTRL", RightControl = "CTRL", LeftAlt = "ALT", Space = "SPACE", CapsLock = "CAPS"}
function HUD:BuildMoves()
	local mh = self.root.MoveHint
	for _, n in ipairs({"MoveHint", "SprintKey", "SlideKey"}) do local o = mh:FindFirstChild(n); if o then o.Visible = false end end
	local old = mh:FindFirstChild("Moves"); if old then old:Destroy() end
	local TextService = game:GetService("TextService")
	local H, PAD = 46, 6
	local specs = {{"sprint", "SPRINT", "L3"}, {"slide", "SLIDE", "B"}, {"dash", "DASH", "X"}, {"crouch", "CROUCH", "LT"}, {"type", "NUMBER", "Y"}}
	-- segment widths from the text they hold (the key cap leaves room for a longer rebound key / a cooldown count)
	local widths, total = {}, PAD
	for i, s in ipairs(specs) do
		local kw = math.max(34, TextService:GetTextSize(s[3], 14, Enum.Font.RobotoMono, Vector2.new(200, 40)).X + 16)
		local lw = TextService:GetTextSize(s[2], 17, Enum.Font.SourceSansBold, Vector2.new(200, 40)).X + 4
		widths[i] = {key = kw, label = lw, w = 10 + kw + 8 + lw + 12}
		total += widths[i].w
	end
	total += PAD
	local holder = Instance.new("Frame"); holder.Name = "Moves"; holder.BorderSizePixel = 0; holder.BackgroundColor3 = DOCK_INK
	holder.BackgroundTransparency = 0.2; holder.Position = UDim2.fromOffset(16, 135 - 14 - H); holder.Size = UDim2.fromOffset(total, H); holder.Parent = mh
	corner(holder, 9)
	local hs = Instance.new("UIStroke"); hs.Color = DOCK_LINE; hs.Thickness = 1; hs.Transparency = 0.2; hs.Parent = holder
	self.moves = {}
	local x = PAD
	for i, s in ipairs(specs) do
		local wd = widths[i]
		local seg = Instance.new("Frame"); seg.Name = s[1]; seg.BorderSizePixel = 0; seg.BackgroundColor3 = DOCK_HOVER; seg.BackgroundTransparency = 1
		seg.Position = UDim2.fromOffset(x, PAD - 1); seg.Size = UDim2.fromOffset(wd.w, H - PAD * 2 + 2); seg.ZIndex = 2; seg.Parent = holder
		corner(seg, 6)
		if i > 1 then
			local sep = Instance.new("Frame"); sep.Name = "Sep"; sep.BorderSizePixel = 0; sep.BackgroundColor3 = DOCK_LINE
			sep.Position = UDim2.fromOffset(x - 1, 10); sep.Size = UDim2.fromOffset(1, H - 20); sep.ZIndex = 2; sep.Parent = holder
		end
		local cap = Instance.new("Frame"); cap.Name = "Cap"; cap.BackgroundColor3 = Color3.fromRGB(34, 18, 23); cap.ClipsDescendants = true
		cap.AnchorPoint = Vector2.new(0, 0.5); cap.Position = UDim2.new(0, 10, 0.5, 0); cap.Size = UDim2.fromOffset(wd.key, 26); cap.ZIndex = 3; cap.Parent = seg
		corner(cap, 4)
		local caps = Instance.new("UIStroke"); caps.Color = Color3.fromRGB(104, 44, 58); caps.Thickness = 1; caps.Parent = cap
		local shine = Instance.new("UIGradient"); shine.Rotation = 90
		shine.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 164)); shine.Parent = cap
		local key = Instance.new("TextLabel"); key.Name = "Key"; key.BackgroundTransparency = 1; key.FontFace = DOCK_MONO; key.TextSize = 14
		key.Text = s[3]; key.TextColor3 = BONE; key.Size = UDim2.fromScale(1, 1); key.ZIndex = 4; key.Parent = cap
		local cool = Instance.new("Frame"); cool.Name = "Cooldown"; cool.BorderSizePixel = 0; cool.BackgroundColor3 = RED; cool.AnchorPoint = Vector2.new(0, 1)
		cool.Position = UDim2.fromScale(0, 1); cool.Size = UDim2.new(0, 0, 0, 2); cool.ZIndex = 5; cool.Parent = cap
		local lab = Instance.new("TextLabel"); lab.Name = "Label"; lab.BackgroundTransparency = 1; lab.Text = s[2]; lab.FontFace = DOCK_SANS; lab.TextSize = 17
		lab.TextColor3 = DOCK_MUTED; lab.TextXAlignment = Enum.TextXAlignment.Left
		lab.Position = UDim2.fromOffset(10 + wd.key + 8, 0); lab.Size = UDim2.new(0, wd.label, 1, 0); lab.ZIndex = 3; lab.Parent = seg
		self.moves[s[1]] = {chip = seg, cap = cap, capStroke = caps, key = key, cool = cool, label = lab}
		x += wd.w
	end
	-- the touch buttons sit over their segments
	local function over(btn, name)
		local c = self.moves[name].chip
		btn.Position = holder.Position + c.Position; btn.Size = c.Size; btn.ZIndex = 10; btn.BackgroundTransparency = 1
	end
	over(mh.Run, "sprint"); over(mh.Slide, "slide")
	-- (the old touch RUN / SLIDE buttons are replaced by StarterPlayerScripts.PadControls' touch buttons)
	local player = self.view.player
	local function refresh()
		holder.Visible = player:GetAttribute("InputMode") == "gamepad"; mh.Run.Visible = false; mh.Slide.Visible = false
	end
	refresh()
	player:GetAttributeChangedSignal("InputMode"):Connect(refresh)
end
function HUD:SetMove(name, active, cooldown)
	local m = self.moves and self.moves[name]
	if not m then return end
	m.chip.BackgroundTransparency = active and 0.35 or 1
	m.cap.BackgroundColor3 = active and Color3.fromRGB(190, 16, 46) or Color3.fromRGB(34, 18, 23)
	m.capStroke.Color = active and Color3.fromRGB(255, 110, 130) or Color3.fromRGB(104, 44, 58)
	m.label.TextColor3 = active and BONE or DOCK_MUTED
	m.cool.Size = UDim2.new(math.clamp(cooldown or 0, 0, 1), 0, 0, 2)
end

local SMALLER = {YourNumber = 0.9, Eliminations = 0.9, TopBar = 0.9}
function HUD:Layout()
	local size = self.gui.AbsoluteSize
	local w, h = size.X, size.Y
	if w <= 0 or h <= 0 then return 1 end
	local s = math.min(w / REF_W, h / REF_H)
	if s == self.scale and w == self.w and h == self.h then return s end
	self.scale, self.w, self.h = s, w, h
	for _, g in self.groups do
		local ax, ay = g.AnchorPoint.X, g.AnchorPoint.Y
		local gw, gh = g.Size.X.Offset, g.Size.Y.Offset
		local ox = (g:GetAttribute("RefX") + ax * gw - ax * REF_W) * s
		local oy = (g:GetAttribute("RefY") + ay * gh - ay * REF_H) * s
		g.Position = UDim2.new(ax, ox, ay, oy)
		-- your number, the eliminations feed and the top bar sit 10% smaller than the reference layout
		g.ResponsiveScale.Scale = s * (SMALLER[g.Name] or 1)
	end
	local lockScale = self.gui.TargetLock:FindFirstChild("ResponsiveScale")
	if lockScale then lockScale.Scale = s end
	return s
end

-- ===== KILL FEED =====
-- Right-aligned rows that slide in from the right edge, newest on top (up to 5):
--   KILLER  [✕]  VICTIM  #1234 (struck through)
-- Your own eliminations get a red row, rows where you were eliminated a dark-red one with a bright edge; the zone
-- shows as THE ZONE in violet, writing your own number as ↺. Rows fade out after Config.FeedLifetime seconds.
-- (Built inside the authored Eliminations group so it keeps its screen position / scaling; the old artwork rows
-- are hidden.)
local TweenService = game:GetService("TweenService")
local FEED_W, ROW_H, ROW_GAP, ROW_TOP = 455, 46, 6, 36
local INK = Color3.fromRGB(12, 7, 9)
local MUTED = Color3.fromRGB(168, 150, 154)
local ZONE = Color3.fromRGB(176, 120, 255)
local NAME_FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) mk("UICorner", {CornerRadius = UDim.new(0, r)}, o) end

-- fade a whole row (text, images and filled frames) to `fade` (0 = as built, 1 = gone)
local function fadeTo(object, fade)
	local list = object:GetDescendants(); table.insert(list, object)
	for _, o in ipairs(list) do
		local props = {}
		if o:IsA("TextLabel") then table.insert(props, "TextTransparency") end
		if o:IsA("ImageLabel") then table.insert(props, "ImageTransparency") end
		if o:IsA("GuiObject") then table.insert(props, "BackgroundTransparency") end
		if o:IsA("UIStroke") then table.insert(props, "Transparency") end
		for _, prop in ipairs(props) do
			local key = "FeedBase" .. prop
			local base = o:GetAttribute(key)
			if base == nil then base = o[prop]; o:SetAttribute(key, base) end
			o[prop] = base + (1 - base) * fade
		end
	end
end

function HUD:FeedSetup()
	if self.feedHolder then return end
	local feed = self.root.Eliminations
	for _, c in ipairs(feed:GetChildren()) do if c:IsA("GuiObject") then c.Visible = false end end
	local holder = mk("Frame", {Name = "FeedV2", BackgroundTransparency = 1, Size = UDim2.fromOffset(FEED_W, 333), ZIndex = 2}, feed)
	-- header: ELIMINATIONS with a red rule fading out to the left
	self.feedHeader = mk("TextLabel", {Name = "Header", BackgroundTransparency = 1, Text = "E L I M I N A T I O N S", FontFace = NAME_FONT, TextSize = 15,
		TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(300, 22), ZIndex = 3}, holder)
	self.feedHeader.TextSize = 17
	local rule = mk("Frame", {Name = "Rule", BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 24), Size = UDim2.fromOffset(260, 2), ZIndex = 3}, holder)
	mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})}, rule)
	self.feedRule = rule
	self.feedHolder = holder
	self.feedRows = {}
end

function HUD:FeedRow(d, me)
	local youKill = d.KillerId == me and d.VictimId ~= me
	local youDied = d.VictimId == me
	local zone = d.Killer == "THE ZONE"
	local selfHit = d.KillerId == d.VictimId and not zone
	local row = mk("Frame", {Name = "Row", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(FEED_W, ROW_H),
		BackgroundColor3 = youKill and Color3.fromRGB(120, 6, 30) or (youDied and Color3.fromRGB(46, 4, 12) or INK),
		BackgroundTransparency = youKill and 0.08 or 0.18, ZIndex = 3}, self.feedHolder)
	corner(row, 4)
	-- solid on the right, fading out to the left
	mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.25), NumberSequenceKeypoint.new(1, 0)})}, row)
	mk("Frame", {Name = "Edge", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = (youKill or youDied) and RED or (zone and ZONE or Color3.fromRGB(110, 24, 44)), ZIndex = 5}, row)
	local content = mk("Frame", {Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, 0), ZIndex = 4}, row)
	mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder}, content)
	local function name(text, color, order)
		return mk("TextLabel", {BackgroundTransparency = 1, Text = text, FontFace = NAME_FONT, TextSize = 24, TextColor3 = color,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = order, ZIndex = 5,
			TextTruncate = Enum.TextTruncate.AtEnd}, content)
	end
	local killerText = zone and "THE ZONE" or (d.KillerId == me and "YOU" or tostring(d.Killer or "?"))
	local killerColor = zone and ZONE or (d.KillerId == me and (youKill and BONE or RED) or BONE)
	name(killerText, killerColor, 1)
	-- the mark between them
	local badge = mk("Frame", {Name = "Badge", BorderSizePixel = 0, Size = UDim2.fromOffset(28, 28), LayoutOrder = 2, ZIndex = 5,
		BackgroundColor3 = zone and Color3.fromRGB(70, 34, 120) or (youKill and Color3.fromRGB(255, 236, 236) or Color3.fromRGB(150, 10, 34))}, content)
	corner(badge, 6)
	mk("UIStroke", {Color = zone and ZONE or RED, Thickness = 1, Transparency = 0.2}, badge)
	local ink = youKill and Color3.fromRGB(150, 0, 28) or BONE
	if selfHit then
		-- wrote their own number: a loop
		local ring = mk("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(14, 14), ZIndex = 6}, badge)
		corner(ring, 7)
		mk("UIStroke", {Color = ink, Thickness = 2.4}, ring)
	else
		-- a crossed-out mark, drawn with two bars (no font needed)
		for _, a in ipairs({45, -45}) do
			mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = ink, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(16, 3), Rotation = a, ZIndex = 6}, badge)
		end
	end
	local victimText = selfHit and (youDied and "YOURSELF" or "THEMSELVES") or (youDied and "YOU" or tostring(d.Victim or "?"))
	name(victimText, youDied and RED or (youKill and BONE or Color3.fromRGB(214, 200, 202)), 3)
	-- the number that was written, struck through
	if d.Code and not selfHit then
		local chip = mk("TextLabel", {BackgroundTransparency = 1, Text = "#" .. tostring(d.Code), FontFace = MONO, TextSize = 18,
			TextColor3 = youKill and Color3.fromRGB(255, 200, 206) or MUTED, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 4, ZIndex = 5}, content)
		mk("Frame", {Name = "Strike", BorderSizePixel = 0, BackgroundColor3 = youKill and BONE or RED, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), ZIndex = 6}, chip)
	end
	return row
end

function HUD:Feed(now)
	local feed = self.root.Eliminations
	feed.Visible = self.view.feedEnabled ~= false   -- Settings > KILLFEED: OFF hides the panel
	self:FeedSetup()
	local me = self.view.player.UserId
	-- a new round starts with an empty feed
	local round = self.view.shared:GetAttribute("RoundId")
	if round ~= self.feedRound then self.feedRound = round; table.clear(self.view.feed) end
	-- entries fade out after the feed lifetime (Config.FeedLifetime) and then drop off
	local life = (self.view.config and self.view.config.FeedLifetime) or 6
	for k = #self.view.feed, 1, -1 do
		if now - (self.view.feed[k].time or now) > life then table.remove(self.view.feed, k) end
	end
	local live = {}
	for i = 1, math.min(5, #self.view.feed) do
		local entry = self.view.feed[i]
		live[entry] = true
		local row = self.feedRows[entry]
		local y = ROW_TOP + (i - 1) * (ROW_H + ROW_GAP)
		if not row then
			row = self:FeedRow(entry.data, me)
			self.feedRows[entry] = row
			-- slide in from the right with a little overshoot
			row.Position = UDim2.new(1, 70, 0, y)
			row:SetAttribute("Y", y)
			TweenService:Create(row, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(1, 0, 0, y)}):Play()
		elseif row:GetAttribute("Y") ~= y then
			row:SetAttribute("Y", y)
			TweenService:Create(row, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, 0, 0, y)}):Play()
		end
		fadeTo(row, math.clamp(1 - (life - (now - (entry.time or now))) / 0.8, 0, 1))
	end
	for entry, row in pairs(self.feedRows) do
		if not live[entry] then row:Destroy(); self.feedRows[entry] = nil end
	end
	-- the header dims while the feed is empty
	local empty = next(live) == nil
	self.feedHeader.TextTransparency = empty and 0.55 or 0
	self.feedRule.BackgroundTransparency = empty and 0.6 or 0
end

function HUD:Step(input, shared, char, now)
	local view = self.view
	local deployed = view.player:GetAttribute("InMatch") == true
	local blocked = view.presentation and view.presentation:BlocksInput()
	local a = view.active
	-- while you are dead and spectating, keep the eliminations feed up so you can see who got you
	local dead = blocked and view.presentation.mode == "death"
	self.root.Visible = deployed and ((not blocked and (a == nil or a == "Entry")) or dead)
	if dead ~= self.deadView then
		self.deadView = dead
		for _, g in self.groups do g.Visible = not dead or g.Name == "Eliminations" end
	end
	-- the menu dock (left): the full menu in the lobby courtyard, just PLAYERS / SETTINGS once the round has started
	-- (lobby courtyard only: mid-round the PLAYERS / SETTINGS rows and the ALT hint stay out of the way -- Tab and
	-- F4 still open them)
	local inArena = view.player:GetAttribute("InArena") == true
	local showRail = not dead and not inArena
	if self.root.Rail.Visible ~= showRail then self.root.Rail.Visible = showRail end
	self:LayoutDock(inArena)
	-- the round minimap sits in the bottom-left corner (above the gamepad move bar with a controller; touch keeps
	-- it top-left, out from under the thumbstick)
	do
		local mode = view.player:GetAttribute("InputMode") or "keyboard"
		local key = (inArena and mode ~= "touch") and mode or "top"
		local map = self.root:FindFirstChild("Minimap")
		if map and self.mapKey ~= key then
			self.mapKey = key
			if map:GetAttribute("TopRefY") == nil then map:SetAttribute("TopRefY", map:GetAttribute("RefY")) end
			if key == "top" then
				map.AnchorPoint = Vector2.zero
				map:SetAttribute("RefY", map:GetAttribute("TopRefY"))
			else
				map.AnchorPoint = Vector2.new(0, 1)
				map:SetAttribute("RefY", key == "gamepad" and 610 or 711)
			end
			self.scale = nil
		end
	end
	-- TYPE A NUMBER (bottom right) only means something in a round: hidden in the lobby courtyard
	-- (keyboard only: touch has its own # button and the gamepad bar shows [Y] NUMBER)
	local typing = view.player:GetAttribute("InArena") == true and not dead and (view.player:GetAttribute("InputMode") or "keyboard") == "keyboard"
	if self.dockMode ~= view.player:GetAttribute("InputMode") then self.dockMode = view.player:GetAttribute("InputMode"); self.dockRound = nil end
	if self.root.TypePrompt.Visible ~= typing then self.root.TypePrompt.Visible = typing end
	-- (the right-hand QUESTS / COMMUNITY buttons now live in the lobby dock on the left)
	if self.root.SideButtons.Visible then self.root.SideButtons.Visible = false end
	self:Layout()
	if not self.root.Visible then return end
	if dead then
		if now - self.lastText >= 0.1 then self.lastText = now; self:Feed(now) end
		return
	end

	-- movement keys update every frame (slide cooldown counts down smoothly)
	local move = view.move or {}
	if self.moves then
		local cd = move.cooldown or 0
		self.moves.slide.key.Text = (cd > 0 and not move.sliding) and string.format("%.1f", cd) or "B"
		self:SetMove("type", view.active == "Entry", 0)
		self:SetMove("sprint", move.running == true, 0)
		self:SetMove("slide", move.sliding == true, cd > 0 and math.clamp(cd / 1.2, 0, 1) or 0)
		local pk = view.feel and view.feel.parkour
		local t = os.clock()
		local dashing = pk and t < (pk.dashUntil or 0)
		local dashCd = pk and math.max(0, (pk.dashReadyAt or 0) - t) or 0
		self:SetMove("dash", dashing == true, dashCd > 0 and math.clamp(dashCd / ((pk.cfg and pk.cfg.DashCooldown) or 1), 0, 1) or 0)
		self:SetMove("crouch", char ~= nil and char:GetAttribute("Crouching") == true, 0)
	end
	if self.dock and self.dock.Daily and self.dock.Daily.dot then
		self.dock.Daily.dot.Visible = view.player:GetAttribute("ProfileReady") == true and view.player:GetAttribute("DailyClaimed") ~= true
	end

	-- no number yet (lobby / waiting): YOUR NUMBER shows the visor's 0__0 face, blinking with your visor
	local idle = not (char and char:GetAttribute("NumberfallCode"))
	if idle then
		local open = true
		local anchor = char and char:FindFirstChild("NumberForehead")
		local panel = anchor and anchor:FindFirstChild("Digit1")
		local gui = panel and panel:FindFirstChild("FrontNumber")
		local eye = gui and gui:FindFirstChild("Open")
		if eye then open = eye.Visible
		else
			-- no visor to follow: blink on our own clock
			self.blinkAt = self.blinkAt or (now + 3)
			if now >= self.blinkAt + 0.14 then self.blinkAt = now + 2.2 + math.random() * 3 end
			open = now < self.blinkAt
		end
		local face = open and "O__O" or "-__-"
		local numStyle = NumberStyles.Of(view.player)
		local yours = self.root.YourNumber
		-- (the size is part of the key too: the HUD rescales with the window)
		local key = face .. "|" .. tostring(numStyle) .. "|" .. tostring(yours.Digit1.AbsoluteSize)
		if key ~= self.idleFace then
			self.idleFace = key
			for i = 1, 4 do
				local c = string.sub(face, i, i)
				yours["Digit" .. i].Text = c
				yours["DigitGlow" .. i].Text = c
				yours["DigitGlow" .. i].Visible = false
				NumberStyles.Skin(yours["Digit" .. i], numStyle, c, {fill = 0.96})
			end
		end
	else
		self.idleFace = nil
	end

	if now - self.lastText < 0.1 then return end
	self.lastText = now
	local phase = shared:GetAttribute("Phase") or "Warmup"
	local top = self.root.TopBar
	local lobbyLeft = (shared:GetAttribute("LobbyUntil") or 0) - now
	top.TimeValue.Text = phase == "Warmup" and (lobbyLeft > 0 and clock(math.ceil(lobbyLeft)) or "--:--") or clock(math.ceil((shared:GetAttribute("EndsAt") or now) - now))
	local alive, inMatch = 0, 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InArena") == true then inMatch += 1 end
		if aliveHumanoid(p) then alive += 1 end
	end
	-- bots filling the round (ServerScriptService.BotService) count as fighters too
	local bots = workspace:FindFirstChild("MatchBots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			local h = m:FindFirstChildOfClass("Humanoid")
			if h then inMatch += 1; if h.Health > 0 then alive += 1 end end
		end
	end
	top.AliveValue.Text = tostring(alive)
	local written = char and char:GetAttribute("NumbersWritten") or 0
	top.NumbersValue.Text = written .. " / " .. math.max(inMatch - 1, written)
	top.MarksValue.Text = tostring(view.player:GetAttribute("Coins") or 0)

	local code = tostring(char and char:GetAttribute("NumberfallCode") or "----")
	local yours = self.root.YourNumber
	do
		local livesFrame = yours:FindFirstChild("Lives")
		if livesFrame then
			local lives = view.player:GetAttribute("Lives")
			local playing = (shared:GetAttribute("Phase") == "Playing") and view.player:GetAttribute("InArena") == true and lives ~= nil
			-- (tucked away while the players list is open: it would sit on the list's PLAYERS wing)
			livesFrame.Visible = playing and view.active ~= "Leaderboard"
			-- a small chip on the HELP row, right of the button, inside the panel art: dark, thin red edge, three
			-- health crosses (+): lit red with a soft glow while you have them, a dark empty cross once lost, with a pop
			-- when one goes
			-- (10 + 3 pips of 18 with 8 between + 10 = 90: inside the 90 chip)
			if not livesFrame:GetAttribute("PlateCross") then
				livesFrame:SetAttribute("Plate3", true); livesFrame:SetAttribute("PlateCross", true)
				for _, c in ipairs(livesFrame:GetChildren()) do
					if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIPadding") or c.Name == "Tag" then c:Destroy() end
				end
				livesFrame.Size = UDim2.fromOffset(90, 46)
				livesFrame.Position = UDim2.fromOffset(282, 225)
				livesFrame.BackgroundColor3 = Color3.fromRGB(12, 5, 8); livesFrame.BackgroundTransparency = 0.12; livesFrame.BorderSizePixel = 0
				local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 4); corner.Parent = livesFrame
				local edge = Instance.new("UIStroke"); edge.Color = Color3.fromRGB(255, 24, 58); edge.Thickness = 1.2; edge.Transparency = 0.45
				edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; edge.Parent = livesFrame
				local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10); pad.Parent = livesFrame
				local layout = livesFrame:FindFirstChildOfClass("UIListLayout")
				if layout then
					layout.FillDirection = Enum.FillDirection.Horizontal; layout.VerticalAlignment = Enum.VerticalAlignment.Center
					layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 8)
				end
				for i = 1, 3 do
					local slot = livesFrame:FindFirstChild("Life" .. i)
					if slot then
						slot.Text = ""; slot.BackgroundTransparency = 1; slot.Size = UDim2.fromOffset(18, 30); slot.LayoutOrder = i
						for _, c in ipairs(slot:GetChildren()) do c:Destroy() end
						-- a + made of two bars, drawn twice: a lighter edge cross, the fill cross inset on top
						local function plus(name, len, thick, color, z, parent)
							local holder = Instance.new("Frame")
							holder.Name = name; holder.AnchorPoint = Vector2.new(0.5, 0.5); holder.Position = UDim2.fromScale(0.5, 0.5)
							holder.Size = UDim2.fromOffset(len, len); holder.BackgroundTransparency = 1; holder.ZIndex = z; holder.Parent = parent
							for _, dims in ipairs({{len, thick}, {thick, len}}) do
								local bar = Instance.new("Frame")
								bar.Name = "Bar"; bar.AnchorPoint = Vector2.new(0.5, 0.5); bar.Position = UDim2.fromScale(0.5, 0.5)
								bar.Size = UDim2.fromOffset(dims[1], dims[2]); bar.BorderSizePixel = 0; bar.BackgroundColor3 = color; bar.ZIndex = z
								local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 1); bc.Parent = bar
								bar.Parent = holder
							end
							return holder
						end
						local z = slot.ZIndex
						plus("Glow", 24, 10, Color3.fromRGB(255, 24, 58), z, slot)
						for _, bar in ipairs(slot.Glow:GetChildren()) do if bar:IsA("Frame") then bar.BackgroundTransparency = 0.8 end end
						plus("Edge", 18, 7, Color3.fromRGB(255, 120, 136), z + 1, slot)
						plus("Pip", 15, 4, Color3.fromRGB(255, 34, 58), z + 2, slot)
						Instance.new("UIScale").Parent = slot
					end
				end
			end
			if playing then
				if self.lastLives and lives < self.lastLives then
					local lost = livesFrame:FindFirstChild("Life" .. (lives + 1))
					local sc = lost and lost:FindFirstChildOfClass("UIScale")
					if sc then sc.Scale = 1.9; TweenService:Create(sc, TweenInfo.new(0.55, Enum.EasingStyle.Back), {Scale = 1}):Play() end
				end
				self.lastLives = lives
				for i = 1, 3 do
					local slot = livesFrame:FindFirstChild("Life" .. i)
					local pip = slot and slot:FindFirstChild("Pip")
					if pip then
						local has = i <= lives
						-- have it: bright red cross on a pale edge, glowing; lost: a dark, empty cross
						for _, bar in ipairs(pip:GetChildren()) do
							if bar:IsA("Frame") then bar.BackgroundColor3 = has and Color3.fromRGB(255, 34, 58) or Color3.fromRGB(26, 10, 14) end
						end
						for _, bar in ipairs(slot.Edge:GetChildren()) do
							if bar:IsA("Frame") then bar.BackgroundColor3 = has and Color3.fromRGB(255, 120, 136) or Color3.fromRGB(110, 62, 70) end
						end
						slot.Glow.Visible = has
					end
				end
			else
				self.lastLives = nil
			end
		end
	end
	local numStyle = NumberStyles.Of(view.player)
	for i = 1, idle and 0 or 4 do
		local c = string.sub(code, i, i)
		yours["Digit" .. i].Text = c
		yours["DigitGlow" .. i].Text = c
		yours["DigitGlow" .. i].Visible = false
		NumberStyles.Skin(yours["Digit" .. i], numStyle, c ~= "" and c or "-", {fill = 0.96})
	end

	self:Feed(now)

	local p, claimable = view.player, false
	for qi = 1, 4 do
		local goal = p:GetAttribute("Quest" .. qi .. "Goal") or ({3, 2, 5, 1200})[qi]
		if not p:GetAttribute("Quest" .. qi .. "Claimed") and (p:GetAttribute("Quest" .. qi .. "Progress") or 0) >= goal then claimable = true end
	end
	self.root.SideButtons.QuestBadge.Visible = claimable and not (self.view.Locked and self.view.Locked.Quests)
end

return HUD
