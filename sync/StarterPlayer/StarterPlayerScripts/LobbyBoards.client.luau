-- LOBBY LEADERBOARDS (client): draws the three terrace boards (workspace.Lobby.NewSquare.Fun.Leaderboards) from the
-- lists the server publishes in ReplicatedStorage.Numberfall.LobbyBoards (ServerScriptService.LobbyLeaderboards):
--   * a podium for the top three -- avatar, the players-list medal (same art as Tab), @username, figure
--   * a scrolling list from 4th down to 1000th (only the rows in view exist, so it stays light)
--   * your own place pinned at the bottom
-- Drawn per screen in PlayerGui (a SurfaceGui in the world can't be scrolled).
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local me = Players.LocalPlayer
local NF = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local DATA = NF:WaitForChild("LobbyBoards")

local BOARDS = {
	{id = "Playtime", title = "MOST PLAYED", unit = "time"},
	{id = "Kills", title = "MOST ELIMINATIONS"},
	{id = "Marks", title = "MOST MARKS", icon = "rbxassetid://121549460537528"},
}
local PPS = 100
local ROW = 36
local FONT_TITLE = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold)
local FONT_ROW = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Regular)
local FONT_NUM = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local RED = Color3.fromRGB(255, 34, 60)
local INK = Color3.fromRGB(238, 228, 224)
local DIM = Color3.fromRGB(150, 126, 130)
local MEDAL = {Color3.fromRGB(255, 202, 86), Color3.fromRGB(214, 224, 240), Color3.fromRGB(230, 142, 84)}
local BADGE_ART = "rbxassetid://105219829380070"
local BADGE_RECT = {Vector2.new(462, 257), Vector2.new(462, 325), Vector2.new(462, 393)}
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function cs(...)
	local k, a = {}, {...}
	for i = 1, #a, 2 do table.insert(k, ColorSequenceKeypoint.new(a[i], a[i + 1])) end
	return ColorSequence.new(k)
end
local function ns(...)
	local k, a = {}, {...}
	for i = 1, #a, 2 do table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(k)
end
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function text(parent, props)
	local t = mk("TextLabel", {BackgroundTransparency = 1, TextColor3 = INK, FontFace = FONT_ROW, TextSize = 26}, parent)
	for k, v in pairs(props) do t[k] = v end
	return t
end
local function comma(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
local function fmt(b, v)
	if b.unit == "time" then
		local h, m = math.floor(v / 3600), math.floor(v % 3600 / 60)
		if h >= 1 then return comma(h) .. "h " .. m .. "m" end
		return m .. "m"
	end
	return comma(v)
end
local GOLD_SHEEN = cs(0, rgb(214, 150, 52), 0.4, rgb(255, 214, 120), 0.5, rgb(255, 248, 220), 0.6, rgb(255, 214, 120), 1, rgb(214, 150, 52))

------------------------------------------------------------------ one board
local boards = {}
local function build(b, screen)
	local W, H = screen.Size.X * PPS, screen.Size.Y * PPS
	local gui = mk("SurfaceGui", {Name = "LB_" .. b.id, Adornee = screen, Face = Enum.NormalId.Front, ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = PPS, LightInfluence = 0, Brightness = 1.25,
		MaxDistance = 90, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ClipsDescendants = true}, me:WaitForChild("PlayerGui"))
	local root = mk("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 255, 255), BorderSizePixel = 0}, gui)
	mk("UIGradient", {Rotation = 90, Color = cs(0, rgb(58, 10, 22), 0.35, rgb(22, 6, 12), 1, rgb(8, 4, 7))}, root)
	-- a glowing red inner border
	local edge = mk("Frame", {Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1}, root)
	mk("UIStroke", {Color = RED, Thickness = 2, Transparency = 0.25}, edge)
	-- header
	text(root, {Text = "LIFETIME  ·  TOP 1000", TextColor3 = RED, TextSize = 22, FontFace = FONT_NUM,
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 22)})
	local title = text(root, {Text = b.title, FontFace = FONT_TITLE, TextSize = 54, TextColor3 = rgb(255, 255, 255),
		Size = UDim2.new(1, -40, 0, 58), Position = UDim2.fromOffset(20, 48)})
	local sheen = mk("UIGradient", {Color = GOLD_SHEEN, Rotation = 12}, title)
	mk("UIStroke", {Color = rgb(40, 8, 14), Thickness = 2}, title)
	if b.icon then
		mk("ImageLabel", {BackgroundTransparency = 1, Image = b.icon, Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 108)}, root)
	end
	-- divider: two fading red lines and a diamond
	for s = -1, 1, 2 do
		local line = mk("Frame", {Size = UDim2.fromOffset(200, 2), AnchorPoint = Vector2.new(s < 0 and 1 or 0, 0.5),
			Position = UDim2.new(0.5, s * 14, 0, b.icon and 128 or 124), BackgroundColor3 = RED, BorderSizePixel = 0}, root)
		mk("UIGradient", {Transparency = s < 0 and ns(0, 1, 1, 0) or ns(0, 0, 1, 1)}, line)
	end
	if not b.icon then
		mk("Frame", {Size = UDim2.fromOffset(10, 10), Rotation = 45, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 124),
			BackgroundColor3 = rgb(255, 210, 110), BorderSizePixel = 0}, root)
	end

	-- podium: 2nd | 1st | 3rd
	local podium = {}
	local spots = {{1, 0.5, 112, 152}, {2, 0.19, 84, 180}, {3, 0.81, 84, 180}}
	for _, s in ipairs(spots) do
		local rank, x, av, top = s[1], s[2], s[3], s[4]
		local col = MEDAL[rank]
		local holder = mk("Frame", {Size = UDim2.fromOffset(200, 250), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, 0, 0, top),
			BackgroundTransparency = 1}, root)
		local halo
		if rank == 1 then
			halo = mk("Frame", {Size = UDim2.fromOffset(av + 26, av + 26), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -13),
				BackgroundColor3 = col, BackgroundTransparency = 0.82}, holder)
			mk("UICorner", {CornerRadius = UDim.new(1, 0)}, halo)
		end
		local ring = mk("Frame", {Size = UDim2.fromOffset(av, av), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
			BackgroundColor3 = rgb(20, 8, 12)}, holder)
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
		mk("UIStroke", {Color = col, Thickness = rank == 1 and 4 or 3}, ring)
		local avatar = mk("ImageLabel", {Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BackgroundTransparency = 1, Image = ""}, ring)
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, avatar)
		mk("ImageLabel", {BackgroundTransparency = 1, Image = BADGE_ART, ImageRectOffset = BADGE_RECT[rank], ImageRectSize = Vector2.new(46, 46),
			Size = UDim2.fromOffset(rank == 1 and 46 or 40, rank == 1 and 46 or 40), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, av), ZIndex = 3}, holder)
		local name = text(holder, {Text = "—", TextSize = rank == 1 and 30 or 25, TextColor3 = col, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, av + 22)})
		local value = text(holder, {Text = "", FontFace = FONT_NUM, TextSize = rank == 1 and 30 or 25, TextColor3 = INK,
			Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, av + 50)})
		podium[rank] = {avatar = avatar, name = name, value = value, halo = halo}
	end

	-- the list, 4th to 1000th
	local LIST_TOP, LIST_H = 402, H - 402 - 60
	text(root, {Text = "RANK", FontFace = FONT_NUM, TextSize = 18, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(80, 20), Position = UDim2.fromOffset(34, LIST_TOP - 24)})
	text(root, {Text = "PLAYER", FontFace = FONT_NUM, TextSize = 18, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(200, 20), Position = UDim2.fromOffset(110, LIST_TOP - 24)})
	text(root, {Text = "SCROLL ↕", FontFace = FONT_NUM, TextSize = 18, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(200, 20), Position = UDim2.new(1, -234, 0, LIST_TOP - 24)})
	local scroll = mk("ScrollingFrame", {Size = UDim2.new(1, -48, 0, LIST_H), Position = UDim2.fromOffset(24, LIST_TOP),
		BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, ScrollBarThickness = 8,
		ScrollBarImageColor3 = RED, CanvasSize = UDim2.fromOffset(0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never, Active = true}, root)
	local pool = {}
	for i = 1, math.ceil(LIST_H / ROW) + 2 do
		local row = mk("Frame", {Size = UDim2.new(1, -12, 0, ROW - 2), BackgroundColor3 = rgb(255, 255, 255), BorderSizePixel = 0, Visible = false}, scroll)
		local hl = mk("UIStroke", {Color = RED, Thickness = 2, Enabled = false}, row)
		local r = text(row, {Text = "", FontFace = FONT_NUM, TextSize = 24, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(70, ROW - 2), Position = UDim2.fromOffset(10, 0)})
		local n = text(row, {Text = "", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -260, 1, 0), Position = UDim2.fromOffset(86, 0)})
		local v = text(row, {Text = "", FontFace = FONT_NUM, TextSize = 24, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(160, ROW - 2), Position = UDim2.new(1, -170, 0, 0)})
		pool[i] = {row = row, rank = r, name = n, value = v, hl = hl}
	end
	-- you, pinned
	local you = mk("Frame", {Size = UDim2.new(1, -48, 0, 40), Position = UDim2.new(0, 24, 1, -52), BackgroundColor3 = rgb(70, 10, 22),
		BackgroundTransparency = 0.15, BorderSizePixel = 0}, root)
	mk("UIStroke", {Color = RED, Thickness = 2}, you)
	local youText = text(you, {Text = "", TextSize = 24, FontFace = FONT_NUM, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0),
		TextXAlignment = Enum.TextXAlignment.Left})
	local youValue = text(you, {Text = "", TextSize = 24, FontFace = FONT_NUM, TextColor3 = rgb(255, 214, 120), Size = UDim2.fromOffset(200, 40),
		Position = UDim2.new(1, -210, 0, 0), TextXAlignment = Enum.TextXAlignment.Right})

	local st = {b = b, gui = gui, screen = screen, sheen = sheen, podium = podium, scroll = scroll, pool = pool, rows = {},
		youText = youText, youValue = youValue, seed = math.random() * 3}
	local function paint()
		local rows = st.rows
		local y = scroll.CanvasPosition.Y
		local first = math.floor(y / ROW)
		for k, p in ipairs(pool) do
			local idx = first + k - 1 -- 0-based into the list after the podium
			local e = rows[idx + 4]
			if e then
				p.row.Visible = true
				p.row.Position = UDim2.fromOffset(0, idx * ROW)
				p.row.BackgroundTransparency = (idx % 2 == 0) and 0.93 or 1
				p.rank.Text = "#" .. (idx + 4)
				p.name.Text = "@" .. e[2]
				p.value.Text = fmt(b, e[3])
				p.hl.Enabled = e[1] == me.UserId
				p.name.TextColor3 = e[1] == me.UserId and rgb(255, 214, 120) or INK
			else
				p.row.Visible = false
			end
		end
	end
	st.paint = paint
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(paint)
	boards[b.id] = st
	return st
end

local function fill(st)
	local ok, rows = pcall(function() return Http:JSONDecode(DATA[st.b.id].Value) end)
	if not ok or type(rows) ~= "table" then rows = {} end
	st.rows = rows
	for rank = 1, 3 do
		local p, e = st.podium[rank], rows[rank]
		p.name.Text = e and ("@" .. e[2]) or "—"
		p.value.Text = e and fmt(st.b, e[3]) or ""
		local img = e and ("rbxthumb://type=AvatarHeadShot&id=" .. e[1] .. "&w=150&h=150") or ""
		if p.avatar.Image ~= img then p.avatar.Image = img end
	end
	st.scroll.CanvasSize = UDim2.fromOffset(0, math.max(0, #rows - 3) * ROW)
	st.paint()
	-- your place
	local mine
	for i, e in ipairs(rows) do if e[1] == me.UserId then mine = i; break end end
	if mine then
		st.youText.Text = "YOU   #" .. mine .. "   @" .. me.Name
		st.youValue.Text = fmt(st.b, rows[mine][3])
	else
		st.youText.Text = "YOU   @" .. me.Name .. "   ·   NOT IN THE TOP 1000 YET"
		st.youValue.Text = ""
	end
end

------------------------------------------------------------------ hook up (the boards may stream in later)
local function boardModel(id)
	local lobby = workspace:FindFirstChild("Lobby")
	local f = lobby and lobby:FindFirstChild("NewSquare")
	f = f and f:FindFirstChild("Fun")
	f = f and f:FindFirstChild("Leaderboards")
	local m = f and f:FindFirstChild(id)
	return m and m:FindFirstChild("Screen")
end
task.spawn(function()
	while true do
		for _, b in ipairs(BOARDS) do
			local screen = boardModel(b.id)
			local st = boards[b.id]
			if screen and (not st or st.screen ~= screen) then
				if st then st.gui:Destroy() end
				st = build(b, screen)
				fill(st)
				local v = DATA:WaitForChild(b.id)
				v.Changed:Connect(function() if boards[b.id] == st then fill(st) end end)
			end
		end
		task.wait(3)
	end
end)

-- the title's light sweep and the champion's halo breathing, only while you're near the boards
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local now = os.clock()
	for _, st in pairs(boards) do
		if st.screen.Parent and (cam.CFrame.Position - st.screen.Position).Magnitude < 90 then
			local t = ((now + st.seed) % 3.4) / 1.1
			st.sheen.Offset = Vector2.new(t < 1 and (-1.1 + 2.2 * t) or 1.1, 0)
			local halo = st.podium[1].halo
			if halo then halo.BackgroundTransparency = 0.72 + 0.16 * math.sin(now * 2.4) end
		end
	end
end)
