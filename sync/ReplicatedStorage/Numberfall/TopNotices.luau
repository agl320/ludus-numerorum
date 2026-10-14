-- One stack of notifications at the top centre of the screen, just under the match top bar, in the MARKED style
-- (black glass card, red rules and a diamond on the top rule, Balthazar type). Everything that used to pop up at the bottom centre
-- (menu toasts, the hit / miss / eliminated banner) and the lobby / zone notices go through here.
--   TopNotices.Push(text, {eyebrow=, kind=, duration=})   short-lived card (the same text again just refreshes it)
--   TopNotices.Set(key, {eyebrow=, text=, sub=, kind=})  pinned card, kept until TopNotices.Set(key, nil)
--   TopNotices.Reserve(key, px)                          keep px free at the top of the stack (the combat banner)
--   TopNotices.Top(key)                                  screen Y where that reserved block should sit
-- kinds: info (red), good (green), bad (red), warn (zone purple), status (lobby)
-- Client only. All LocalScripts share this module, so there is a single stack.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local GuiService = game:GetService("GuiService")

local N = {}
local FONT = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Regular)
local BOLD = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Bold)
local BONE = Color3.fromRGB(238, 233, 230)
local EDGE = Color3.fromRGB(119, 26, 46)
local KINDS = {
	info = {accent = Color3.fromRGB(255, 23, 62), eyebrow = "NOTICE"},
	good = {accent = Color3.fromRGB(143, 255, 209), eyebrow = "SUCCESS"},
	bad = {accent = Color3.fromRGB(255, 23, 62), eyebrow = "ERROR"},
	warn = {accent = Color3.fromRGB(175, 110, 255), eyebrow = "WARNING"},
	status = {accent = Color3.fromRGB(255, 23, 62), eyebrow = "LOBBY"},
}
local MAX_TRANSIENT = 3
local GAP = 8

local player = Players.LocalPlayer
local gui, holder, scaler
local cards = {}      -- live cards: {frame, key, text, sub, eyebrow, kind, expires, order, height, y}
local reserves = {}   -- key -> px kept free above the cards
local serial = 0

-- "NOTICE" -> "N O T I C E" (words keep a wider gap)
local function spaced(s)
	s = string.upper(s)
	local words = {}
	for w in string.gmatch(s, "%S+") do table.insert(words, (string.gsub(w, "(.)", "%1 "):gsub("%s+$", ""))) end
	return table.concat(words, "   ")
end

local function ensure()
	if gui and gui.Parent then return end
	gui = Instance.new("ScreenGui")
	gui.Name = "TopNotices"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 22
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	holder = Instance.new("Frame")
	holder.Name = "Stack"; holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(700, 400); holder.Position = UDim2.new(0.5, 0, 0, 110)
	holder.Parent = gui
	scaler = Instance.new("UIScale"); scaler.Parent = holder
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function fade(points)
	local k = {}
	for _, p in ipairs(points) do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	local g = Instance.new("UIGradient"); g.Transparency = NumberSequence.new(k)
	return g
end

local function rule(parent, bottom, color, alpha)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0; f.BackgroundColor3 = color; f.Size = UDim2.new(1, 0, 0, 1)
	f.Position = bottom and UDim2.new(0, 0, 1, -1) or UDim2.new(0, 0, 0, 0); f.ZIndex = 3
	fade({{0, 1}, {0.22, alpha}, {0.78, alpha}, {1, 1}}).Parent = f
	f.Parent = parent
end

local function diamond(parent, pos, size, color)
	local d = Instance.new("Frame")
	d.BorderSizePixel = 0; d.BackgroundColor3 = color; d.AnchorPoint = Vector2.new(0.5, 0.5); d.Rotation = 45
	d.Size = UDim2.fromOffset(size, size); d.Position = pos; d.ZIndex = 4; d.Parent = parent
end

local function build(spec)
	local kind = KINDS[spec.kind or "info"] or KINDS.info
	local accent = spec.accent or kind.accent
	local eyebrow = spec.eyebrow ~= false and spaced(spec.eyebrow or kind.eyebrow) or nil
	local big = spec.sub ~= nil
	local textSize = big and 30 or 21
	local body = tostring(spec.text or "")
	local wText = TextService:GetTextSize(body, textSize, Enum.Font.Fantasy, Vector2.new(1000, 100)).X
	local wSub = big and TextService:GetTextSize(tostring(spec.sub), 16, Enum.Font.Fantasy, Vector2.new(1000, 100)).X or 0
	local width = math.clamp(math.max(wText, wSub) + 130, 360, 660)
	local textY = eyebrow and 21 or 9
	local height = textY + textSize + 8 + (big and 20 or 0)

	local card = Instance.new("CanvasGroup")
	card.Name = "Card"; card.BackgroundTransparency = 1; card.Size = UDim2.fromOffset(width, height)
	card.AnchorPoint = Vector2.new(0.5, 0); card.GroupTransparency = 1
	-- black glass that fades out at both ends
	local glass = Instance.new("Frame")
	glass.Name = "Glass"; glass.BorderSizePixel = 0; glass.Size = UDim2.fromScale(1, 1)
	glass.BackgroundColor3 = Color3.fromRGB(11, 6, 9); glass.BackgroundTransparency = 0.05; glass.ZIndex = 1
	fade({{0, 1}, {0.16, 0}, {0.84, 0}, {1, 1}}).Parent = glass
	glass.Parent = card
	-- a faint glow of the accent colour rising from the top rule
	local wash = Instance.new("Frame")
	wash.Name = "Wash"; wash.BorderSizePixel = 0; wash.Size = UDim2.fromScale(1, 1); wash.BackgroundColor3 = accent; wash.ZIndex = 2
	local wg = fade({{0, 0.8}, {0.6, 1}, {1, 1}}); wg.Rotation = 90; wg.Parent = wash
	wash.Parent = card
	rule(card, false, accent, 0)
	rule(card, true, EDGE, 0.1)
	diamond(card, UDim2.new(0.5, 0, 0, 0), 7, accent)
	if eyebrow then
		local e = Instance.new("TextLabel")
		e.Name = "Eyebrow"; e.BackgroundTransparency = 1; e.FontFace = BOLD; e.TextSize = 13; e.TextColor3 = accent
		e.Text = eyebrow; e.Size = UDim2.new(1, 0, 0, 14); e.Position = UDim2.fromOffset(0, 6); e.ZIndex = 5; e.Parent = card
	end
	local t = Instance.new("TextLabel")
	t.Name = "Text"; t.BackgroundTransparency = 1; t.FontFace = big and BOLD or FONT; t.TextSize = textSize; t.TextColor3 = BONE
	t.Text = body; t.Size = UDim2.new(1, -70, 0, textSize + 2); t.Position = UDim2.fromOffset(35, textY); t.ZIndex = 5
	t.TextTruncate = Enum.TextTruncate.AtEnd; t.Parent = card
	-- (no diamonds bracketing the message any more: cleaner without them; only an opt-in spec.flanks keeps them)
	if spec.flanks then
		local half = math.min(wText, width - 90) / 2 + 17
		for _, side in ipairs({-1, 1}) do
			diamond(card, UDim2.new(0.5, side * half, 0, textY + (textSize + 2) / 2), 5, accent)
		end
	end
	if big then
		local s = Instance.new("TextLabel")
		s.Name = "Sub"; s.BackgroundTransparency = 1; s.FontFace = FONT; s.TextSize = 16; s.TextColor3 = Color3.fromRGB(200, 190, 186)
		s.Text = tostring(spec.sub); s.Size = UDim2.new(1, -40, 0, 18); s.Position = UDim2.fromOffset(20, textY + textSize + 4); s.ZIndex = 5
		s.Parent = card
	end
	return card, height
end

local function retire(c)
	if c.leaving then return end
	c.leaving = true
	local tw = TweenService:Create(c.frame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
	tw.Completed:Once(function()
		c.frame:Destroy()
		local i = table.find(cards, c); if i then table.remove(cards, i) end
	end)
	tw:Play()
end

local function add(spec, key, duration, order)
	ensure()
	serial += 1
	local frame, height = build(spec)
	local c = {frame = frame, key = key, text = spec.text, sub = spec.sub, eyebrow = spec.eyebrow, kind = spec.kind,
		expires = duration and os.clock() + duration, order = order or (100000 + serial), height = height}
	frame.Parent = holder
	TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
	table.insert(cards, c)
	return c
end

function N.Push(text, opts)
	opts = opts or {}
	text = tostring(text or "")
	if text == "" then return end
	local duration = opts.duration or 3
	for _, c in ipairs(cards) do
		if not c.key and not c.leaving and c.text == text then c.expires = os.clock() + duration; return end
	end
	local live = {}
	for _, c in ipairs(cards) do if not c.key and not c.leaving then table.insert(live, c) end end
	table.sort(live, function(a, b) return a.order < b.order end)
	for i = 1, #live - MAX_TRANSIENT + 1 do retire(live[i]) end
	add({text = text, eyebrow = opts.eyebrow, kind = opts.kind, accent = opts.accent}, nil, duration)
end

function N.Set(key, spec)
	local existing
	for _, c in ipairs(cards) do if c.key == key and not c.leaving then existing = c end end
	if not spec then if existing then retire(existing) end return end
	if existing and existing.text == spec.text and existing.sub == spec.sub and existing.eyebrow == spec.eyebrow and existing.kind == spec.kind then return end
	if existing then
		-- same card, new words: swap the contents in place (no fade)
		local frame, height = build(spec)
		frame.GroupTransparency = 0
		frame.Position = existing.frame.Position
		frame.Parent = holder
		existing.frame:Destroy()
		existing.frame, existing.height = frame, height
		existing.text, existing.sub, existing.eyebrow, existing.kind = spec.text, spec.sub, spec.eyebrow, spec.kind
		return
	end
	add(spec, key, nil, (spec.order or 0) + 1)
end

function N.Reserve(key, px)
	reserves[key] = (px and px > 0) and px or nil
end

-- screen Y (from the very top of the screen) where the stack starts: under the match top bar when it is showing
local function base()
	local pg = player:FindFirstChild("PlayerGui")
	local ui = pg and pg:FindFirstChild("MARKED_UI_EDITABLE")
	local hud = ui and ui:FindFirstChild("MatchHUD")
	local bar = hud and hud:FindFirstChild("TopBar")
	local inset = GuiService:GetGuiInset().Y
	if ui and ui.Enabled and hud and hud.Visible and bar and bar.Visible then
		return bar.AbsolutePosition.Y + inset + bar.AbsoluteSize.Y * 0.74
	end
	return inset + 14
end
N.Base = base
function N.Scale() return scaler and scaler.Scale or 1 end
function N.Top(key)
	local y = base()
	local keys = {}
	for k in pairs(reserves) do table.insert(keys, k) end
	table.sort(keys)
	for _, k in ipairs(keys) do
		if k == key then return y end
		y += reserves[k] + GAP
	end
	return y
end

RunService.RenderStepped:Connect(function()
	if not gui or not gui.Parent then return end
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1400, 800)
	local s = math.clamp(vp.X / 1400, 0.62, 1)
	scaler.Scale = s
	local reserved = 0
	for _, px in pairs(reserves) do reserved += px + GAP end
	holder.Position = UDim2.new(0.5, 0, 0, base() + reserved)
	table.sort(cards, function(a, b) return a.order < b.order end)
	local now = os.clock()
	local y = 0
	for _, c in ipairs(cards) do
		if c.expires and now > c.expires then retire(c) end
		c.y = c.y and (c.y + (y - c.y) * 0.25) or (y - 10)   -- slide into place
		c.frame.Position = UDim2.new(0.5, 0, 0, c.y)
		if not c.leaving then y += c.height + GAP end
	end
end)

return N
