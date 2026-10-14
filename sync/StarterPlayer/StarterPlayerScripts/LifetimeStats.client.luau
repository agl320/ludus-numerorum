-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
-- LIFETIME STATS: a full stats page (like the profile page in Rivals): your in-game look, level and XP, then every
-- lifetime number in four groups. Opened from the VIEW STATS chip on the main-menu player card (LobbyCards sets the
-- player attribute OpenStats), from STATS in the lobby courtyard's menu, or with K in the courtyard. Not in a round.
-- Other players' stats too: in the lobby courtyard, point at another player (the crosshair, or the cursor when it's
-- free) and they get a white outline with their name and @username over them (like Rivals); click (or F / gamepad X)
-- opens this page for them. The page is a compact card on the right that doesn't stop you moving: it closes with X,
-- K, Esc, a click anywhere outside it, or by walking away (from them, or from where you opened your own).
-- Values come from the profile attributes the server publishes on each Player (ProfileService: Stat<Key>, Level, XP,
-- Coins) -- player attributes replicate to everyone, so anyone's page can be shown.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

local INK = Color3.fromRGB(10, 6, 8); local TILE = Color3.fromRGB(18, 12, 14); local LINE = Color3.fromRGB(70, 26, 38)
local RED = Color3.fromRGB(255, 23, 74); local BLOOD = Color3.fromRGB(150, 0, 32); local BONE = Color3.fromRGB(240, 232, 228)
local MUTED = Color3.fromRGB(160, 144, 148); local GOLD = Color3.fromRGB(255, 196, 92)
local BAL = Font.new("rbxasset://fonts/families/Balthazar.json")
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

local function mk(class, props, parent) local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o end
local function corner(o, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 6)}, o) end
local function stroke(o, c, t) return mk("UIStroke", {Color = c, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function text(parent, props)
	local base = {BackgroundTransparency = 1, TextColor3 = BONE, FontFace = BODY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}
	for k, v in pairs(props) do base[k] = v end
	return mk("TextLabel", base, parent)
end
local function comma(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
local function duration(sec)
	sec = math.floor(tonumber(sec) or 0)
	local h, m = sec // 3600, (sec % 3600) // 60
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end
local subject = player -- whose stats the page is showing
local function stat(k) return tonumber(subject:GetAttribute("Stat" .. k)) or 0 end

local gui = mk("ScreenGui", {Name = "LifetimeStats", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Enabled = false}, player:WaitForChild("PlayerGui"))
local W, H = 860, 600
local REST = UDim2.new(1, -20, 0.5, 0) -- where the card sits (right side, out of the way)
local card = mk("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = REST, Size = UDim2.fromOffset(W, H), BackgroundColor3 = INK, Active = true}, gui)
corner(card, 10); stroke(card, Color3.fromRGB(150, 20, 46), 1.4)
local scale = mk("UIScale", {}, card)
-- compact: about 60% of the old full-screen page (never more than ~half the screen wide)
local function fit() local v = gui.AbsoluteSize; scale.Scale = math.clamp(math.min((v.X * 0.6) / W, (v.Y * 0.84) / H, 0.9), 0.4, 0.9) end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit); fit()

-- left column: your in-game look, name, level and XP
local side = mk("Frame", {Name = "Profile", BackgroundColor3 = Color3.fromRGB(22, 6, 12), Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(250, H - 32)}, card)
corner(side, 8); stroke(side, LINE)
mk("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(120, 10, 34), Color3.fromRGB(16, 6, 10)),
	Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})}, side)
text(side, {Text = "L I F E T I M E   S T A T S", FontFace = BOLD, TextSize = 11, TextColor3 = Color3.fromRGB(255, 130, 150), Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(214, 14)})
local vp = mk("ViewportFrame", {Name = "Look", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.fromOffset(250, 300),
	Ambient = Color3.fromRGB(170, 140, 145), LightColor = Color3.fromRGB(255, 232, 226), LightDirection = Vector3.new(-0.4, -0.6, -0.7)}, side)
local world = mk("WorldModel", {}, vp)
local cam = mk("Camera", {FieldOfView = 24}, vp); vp.CurrentCamera = cam
local face = mk("ImageLabel", {Name = "Headshot", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(125, 180),
	Size = UDim2.fromOffset(150, 150), Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150", Visible = false}, side)
local nameL = text(side, {Text = player.DisplayName, FontFace = BAL, TextSize = 34, Position = UDim2.fromOffset(18, 340), Size = UDim2.fromOffset(214, 38),
	TextTruncate = Enum.TextTruncate.AtEnd})
local handleL = text(side, {Text = "@" .. player.Name, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(18, 376), Size = UDim2.fromOffset(214, 14)})
local lvl = mk("Frame", {BackgroundColor3 = BLOOD, Position = UDim2.fromOffset(18, 402), Size = UDim2.fromOffset(214, 66)}, side)
corner(lvl, 6); stroke(lvl, Color3.fromRGB(200, 40, 70))
text(lvl, {Text = "LEVEL", FontFace = BOLD, TextSize = 11, TextColor3 = Color3.fromRGB(255, 190, 200), Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(80, 14)})
local levelL = text(lvl, {Text = "1", FontFace = BAL, TextSize = 36, Position = UDim2.fromOffset(12, 22), Size = UDim2.fromOffset(80, 40)})
local xpL = text(lvl, {Text = "0 / 300 XP", FontFace = BOLD, TextSize = 11, TextColor3 = BONE, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(90, 12), Size = UDim2.fromOffset(110, 14)})
local track = mk("Frame", {BackgroundColor3 = Color3.fromRGB(40, 6, 14), BorderSizePixel = 0, Position = UDim2.fromOffset(96, 38), Size = UDim2.fromOffset(104, 8)}, lvl)
corner(track, 4)
local fill = mk("Frame", {BackgroundColor3 = BONE, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, track)
corner(fill, 4)
local marksL = text(side, {Text = "", FontFace = BOLD, TextSize = 13, TextColor3 = GOLD, Position = UDim2.fromOffset(18, 480), Size = UDim2.fromOffset(214, 18)})
local timeL = text(side, {Text = "", FontFace = BOLD, TextSize = 13, TextColor3 = MUTED, Position = UDim2.fromOffset(18, 502), Size = UDim2.fromOffset(214, 18)})
text(side, {Text = "Bots don't count towards eliminations.", TextSize = 10, TextColor3 = Color3.fromRGB(120, 104, 108), TextWrapped = true,
	Position = UDim2.fromOffset(18, H - 32 - 40), Size = UDim2.fromOffset(214, 28)})

local close = mk("TextButton", {Text = "X", FontFace = BOLD, TextSize = 22, TextColor3 = BONE, AutoButtonColor = false, BackgroundColor3 = BLOOD,
	Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(36, 36), ZIndex = 20}, card) -- (in the header strip, clear of the stat cards below)
corner(close, 5)
local cs = stroke(close, LINE)
close.MouseEnter:Connect(function() cs.Color = BONE end)
close.MouseLeave:Connect(function() cs.Color = LINE end)

-- right: four groups of tiles
local GROUPS = {
	{"OVERVIEW", {{"Kills", "ELIMINATIONS", true}, {"Wins", "WINS", true}, {"WinRate", "WIN RATE", true}, {"KD", "ELIMS PER LIFE", true}}},
	{"COMBAT", {{"Deaths", "LIVES LOST"}, {"BestRound", "MOST IN A ROUND"}, {"Numbers", "NUMBERS WRITTEN"}, {"BotKills", "BOTS MARKED"}}},
	{"ROUNDS", {{"Rounds", "ROUNDS PLAYED"}, {"Top3", "PODIUM FINISHES"}, {"Clean", "FLAWLESS ROUNDS"}, {"BestStreak", "BEST WIN STREAK"}}},
}
local values = {}
local X0, Y0 = 284, 20
local GW = W - X0 - 16
local TW = (GW - 3 * 10) / 4
local y = Y0
for _, g in ipairs(GROUPS) do
	text(card, {Text = g[1], FontFace = BOLD, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(X0 + 2, y), Size = UDim2.fromOffset(200, 16)})
	mk("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(X0 + 2, y + 20), Size = UDim2.fromOffset(28, 2)}, card)
	y += 30
	local big = g[2][1][3] == true
	local th = big and 118 or 92
	for i, t in ipairs(g[2]) do
		local tile = mk("Frame", {Name = t[1], BackgroundColor3 = big and Color3.fromRGB(28, 8, 14) or TILE,
			Position = UDim2.fromOffset(X0 + (i - 1) * (TW + 10), y), Size = UDim2.fromOffset(TW, th)}, card)
		corner(tile, 6); stroke(tile, big and Color3.fromRGB(110, 20, 40) or LINE)
		text(tile, {Text = t[2], FontFace = BOLD, TextSize = 10, TextColor3 = MUTED, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd})
		values[t[1]] = text(tile, {Text = "0", FontFace = BAL, TextScaled = true, Position = UDim2.fromOffset(11, big and 34 or 30),
			Size = UDim2.new(1, -22, 0, big and 60 or 46), TextColor3 = big and BONE or Color3.fromRGB(226, 214, 216)})
		mk("UITextSizeConstraint", {MaxTextSize = big and 52 or 38}, values[t[1]])
	end
	y += th + 18
end
local streakL = text(card, {Text = "", FontFace = BOLD, TextSize = 12, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(X0, H - 34), Size = UDim2.fromOffset(GW, 16)})

-- their look, rebuilt each time the page opens
local function buildLook()
	world:ClearAllChildren()
	face.Image = "rbxthumb://type=AvatarHeadShot&id=" .. subject.UserId .. "&w=150&h=150"
	local ch = subject.Character
	if not (ch and ch:FindFirstChild("Head")) then face.Visible = true; return end
	local was = ch.Archivable; ch.Archivable = true
	local ok, c = pcall(function() return ch:Clone() end)
	ch.Archivable = was
	if not ok or not c then face.Visible = true; return end
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ForceField") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.LocalTransparencyModifier = 0 end
	end
	local hum = c:FindFirstChildOfClass("Humanoid"); if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	c.Parent = world
	local root = c:FindFirstChild("HumanoidRootPart")
	local base = root and CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z), 0) or c:GetPivot()
	c:PivotTo(base:Inverse() * c:GetPivot())
	local ok2, Preview = pcall(function() return require(player.PlayerGui:WaitForChild("MARKED_UI_EDITABLE"):WaitForChild("LoadoutPreview")) end)
	if ok2 and Preview and Preview.Solve then pcall(Preview.Solve, c, 2) end
	local cf, size = c:GetBoundingBox()
	local h = math.max(size.Y, 4)
	local dist = (h * 0.6) / math.tan(math.rad(12))
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.25, h * 0.08, -dist), cf.Position + Vector3.new(0, h * 0.02, 0))
	face.Visible = false
end

local function refresh()
	local p = subject
	local kills, deaths, wins, rounds = stat("Kills"), stat("Deaths"), stat("Wins"), stat("Rounds")
	nameL.Text = p.DisplayName; handleL.Text = "@" .. p.Name
	values.Kills.Text = comma(kills)
	values.Wins.Text = comma(wins)
	values.WinRate.Text = (rounds > 0 and math.clamp(math.floor(wins / rounds * 100 + 0.5), 0, 100) or 0) .. "%"
	values.KD.Text = string.format("%.2f", kills / math.max(1, deaths))
	values.Deaths.Text = comma(deaths)
	values.BestRound.Text = comma(stat("BestRound"))
	values.Numbers.Text = comma(stat("Numbers"))
	values.BotKills.Text = comma(stat("BotKills"))
	values.Rounds.Text = comma(rounds)
	values.Top3.Text = comma(stat("Top3"))
	values.Clean.Text = comma(stat("Clean"))
	values.BestStreak.Text = comma(stat("BestStreak"))
	streakL.Text = stat("WinStreak") > 0 and ("CURRENT WIN STREAK  ·  " .. stat("WinStreak")) or ""
	local level = p:GetAttribute("Level") or 1
	local into, goal = p:GetAttribute("LevelXP") or 0, math.max(1, p:GetAttribute("LevelGoal") or 300)
	levelL.Text = tostring(level)
	xpL.Text = comma(into) .. " / " .. comma(goal) .. " XP"
	fill.Size = UDim2.fromScale(math.clamp(into / goal, 0, 1), 1)
	marksL.Text = comma(p:GetAttribute("Coins") or 0) .. " MARKS"
	timeL.Text = "TIME PLAYED  ·  " .. duration(stat("PlaySeconds"))
end
local WATCHED = {"StatKills", "StatDeaths", "StatWins", "StatRounds", "StatBestRound", "StatTop3", "StatClean", "StatBestStreak", "StatWinStreak",
	"StatBotKills", "StatPlaySeconds", "StatNumbers", "Level", "XP", "LevelXP", "Coins"}
local watching = {}
local function watch(p)
	for _, c in ipairs(watching) do c:Disconnect() end
	table.clear(watching)
	for _, a in ipairs(WATCHED) do
		table.insert(watching, p:GetAttributeChangedSignal(a):Connect(function() if gui.Enabled then refresh() end end))
	end
end
watch(player)

local function canOpen() return player:GetAttribute("InArena") ~= true end
local openedAt -- where you stood when it opened (walk away from it to close)
local function myRoot() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function open(who)
	if not canOpen() then return end
	who = (who and who.Parent) and who or player
	if who ~= subject then subject = who; watch(who) end
	refresh(); buildLook()
	local r = myRoot(); openedAt = r and r.Position
	gui.Enabled = true
	card.Position = REST + UDim2.fromOffset(60, 0)
	TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quint), {Position = REST}):Play()
	if player:GetAttribute("InputMode") == "gamepad" then pcall(function() game:GetService("GuiService").SelectedObject = close end) end
end
local function shut()
	if not gui.Enabled then return end
	gui.Enabled = false
	world:ClearAllChildren()
	local gs = game:GetService("GuiService")
	if gs.SelectedObject and gs.SelectedObject:IsDescendantOf(gui) then gs.SelectedObject = nil end
end
close.Activated:Connect(shut)
player:GetAttributeChangedSignal("OpenStats"):Connect(function() if gui.Enabled and subject == player then shut() else open(player) end end)
-- (the lobby courtyard keeps it; a round closes it)
player:GetAttributeChangedSignal("InArena"):Connect(function() if player:GetAttribute("InArena") then shut() end end)
-- Esc (the Roblox menu) closes it too
pcall(function() game:GetService("GuiService").MenuOpened:Connect(shut) end)

------------------------------------------------------------------ hovering other players in the lobby (Rivals style)
-- A white outline and a name tag on whoever you're pointing at; click to open their stats.
local Run = game:GetService("RunService")
local outline = Instance.new("Highlight")
outline.Name = "StatsHover"
outline.FillColor = Color3.new(1, 1, 1)
outline.FillTransparency = 1
outline.OutlineColor = Color3.new(1, 1, 1)
outline.OutlineTransparency = 1
outline.DepthMode = Enum.HighlightDepthMode.Occluded
outline.Enabled = false
outline.Parent = workspace.CurrentCamera or workspace
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() if workspace.CurrentCamera then outline.Parent = workspace.CurrentCamera end end)
local tag = mk("BillboardGui", {Name = "StatsHoverTag", AlwaysOnTop = true, LightInfluence = 0, Size = UDim2.fromOffset(240, 58),
	StudsOffset = Vector3.zero, MaxDistance = 90, Enabled = false, ResetOnSpawn = false}, player:WaitForChild("PlayerGui"))
local tagName = text(tag, {Text = "", FontFace = BOLD, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 22),
	TextStrokeTransparency = 0.55})
local tagUser = text(tag, {Text = "", TextSize = 12, TextColor3 = Color3.fromRGB(215, 205, 208), TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 15), TextStrokeTransparency = 0.6})
local tagHint = text(tag, {Text = "CLICK  ·  VIEW STATS", FontFace = BOLD, TextSize = 10, TextColor3 = Color3.fromRGB(255, 140, 160),
	TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 39), Size = UDim2.new(1, 0, 0, 13), TextStrokeTransparency = 0.6})

local function alive(p)
	local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
local function inCourtyard() return player:GetAttribute("InMatch") == true and player:GetAttribute("InArena") ~= true and alive(player) end
local hovered
local fadeTween
local function setHover(p)
	if p == hovered then return end
	hovered = p

	if fadeTween then fadeTween:Cancel() end
	if p then
		outline.Adornee = p.Character
		outline.Enabled = true
		outline.OutlineTransparency = 1
		outline.FillTransparency = 1
		fadeTween = TweenService:Create(outline, TweenInfo.new(0.12), {OutlineTransparency = 0.55, FillTransparency = 0.96})
		fadeTween:Play()
		-- on the middle of their body (clear of the overhead name / rank title above the head)
		tag.Adornee = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso") or p.Character:FindFirstChild("HumanoidRootPart")
		tagName.Text = p.DisplayName
		tagUser.Text = "@" .. p.Name
		tagHint.Text = player:GetAttribute("InputMode") == "gamepad" and "X  ·  VIEW STATS" or "CLICK  ·  VIEW STATS"
		tag.Enabled = true
	else
		outline.Enabled = false
		outline.Adornee = nil
		tag.Enabled = false
		tag.Adornee = nil
	end
end
-- who's under the crosshair / cursor (walls block it)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local bodyParams = RaycastParams.new()
bodyParams.FilterType = Enum.RaycastFilterType.Include
local function pick()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local point
	if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then point = camera.ViewportSize / 2
	else point = UIS:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset() end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local bodies, owners = {}, {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p:GetAttribute("InArena") ~= true and alive(p) then
			table.insert(bodies, p.Character); owners[p.Character] = p
		end
	end
	if #bodies == 0 then return nil end
	bodyParams.FilterDescendantsInstances = bodies
	local hit = workspace:Spherecast(ray.Origin, 0.9, ray.Direction * 90, bodyParams)
	if not hit then return nil end
	-- something solid in the way?
	rayParams.FilterDescendantsInstances = {player.Character, table.unpack(bodies)}
	local wall = workspace:Raycast(ray.Origin, ray.Direction * hit.Distance, rayParams)
	if wall and wall.Distance < hit.Distance - 1 then return nil end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model and not owners[model] do model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model") end
	return model and owners[model] or nil
end
local acc = 0
Run.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then return end
	acc = 0
	if not inCourtyard() then setHover(nil)
	else
		local ok, p = pcall(pick)
		setHover(ok and p or nil)
	end
	-- walking away closes the page: from the player you're looking at, or from where you opened your own
	if gui.Enabled and player:GetAttribute("InMatch") == true then
		local r = myRoot()
		if r then
			if subject ~= player then
				local other = subject.Character and subject.Character:FindFirstChild("HumanoidRootPart")
				if not other or (other.Position - r.Position).Magnitude > 24 or subject:GetAttribute("InArena") == true then shut() end
			elseif openedAt and (r.Position - openedAt).Magnitude > 16 then
				shut()
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(p)
	if hovered == p then setHover(nil) end
	if subject == p and gui.Enabled then shut() end
end)
local function overCard(pos)
	local a, sz = card.AbsolutePosition, card.AbsoluteSize
	return pos.X >= a.X and pos.X <= a.X + sz.X and pos.Y >= a.Y and pos.Y <= a.Y + sz.Y
end
-- K in the lobby courtyard; click / F / gamepad X on a hovered player; B or a click outside closes
UIS.InputBegan:Connect(function(io, processed)
	if chatTyping() then return end
	local click = io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch
	if io.KeyCode == Enum.KeyCode.K and not processed and player:GetAttribute("InMatch") == true and canOpen() then
		if gui.Enabled and subject == player then shut() else open(player) end
	elseif io.KeyCode == Enum.KeyCode.ButtonB and gui.Enabled then
		shut()
	elseif hovered and not processed and (click or io.KeyCode == Enum.KeyCode.F or io.KeyCode == Enum.KeyCode.ButtonX) then
		if gui.Enabled and subject == hovered then shut() else open(hovered) end
	elseif click and gui.Enabled and not overCard(Vector2.new(io.Position.X, io.Position.Y)) then
		shut()
	end
end)
