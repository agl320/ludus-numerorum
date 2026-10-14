-- REWARDS card: the 7-day login calendar (Numberfall.DailyRewards; the server pays it in ProfileService ClaimDaily)
-- and, under it, the code box (Menu "Redeem": the server checks the code and replies with a toast) -- daily rewards
-- and codes used to be two separate buttons / popups on the main menu.
-- Pops up once per session on the main menu while today's reward is waiting (after the welcome card for new
-- players), and opens from the main menu's REWARDS button (red dot = ready) or the player attribute OpenDaily.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local menu = shared:WaitForChild("Menu")
local Daily = require(shared:WaitForChild("DailyRewards"))
local ui = player:WaitForChild("PlayerGui"):WaitForChild("MARKED_UI_EDITABLE")
local lobby = ui:WaitForChild("Lobby")

local INK = Color3.fromRGB(10, 6, 8); local TILE = Color3.fromRGB(20, 12, 15); local LINE = Color3.fromRGB(74, 26, 40)
local RED = Color3.fromRGB(255, 23, 74); local BLOOD = Color3.fromRGB(150, 0, 32); local BONE = Color3.fromRGB(240, 232, 228)
local MUTED = Color3.fromRGB(160, 144, 148); local GOLD = Color3.fromRGB(236, 190, 92); local GREEN = Color3.fromRGB(110, 210, 140)
local BAL = Font.new("rbxasset://fonts/families/Balthazar.json")
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local function mk(class, props, parent) local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o end
local function corner(o, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 6)}, o) end
local function stroke(o, c, t) return mk("UIStroke", {Color = c, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function text(parent, props)
	local base = {BackgroundTransparency = 1, TextColor3 = BONE, FontFace = BODY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center}
	for k, v in pairs(props) do base[k] = v end
	return mk("TextLabel", base, parent)
end
local function marksImage()
	local ids = ui:FindFirstChild("ArtworkAssetIds")
	local v = ids and ids:FindFirstChild("MarksIcon")
	return v and v.Value ~= "" and v.Value or "rbxassetid://121549460537528"
end
local function clock(s)
	s = math.max(0, math.floor(s))
	return string.format("%02d:%02d:%02d", s // 3600, s % 3600 // 60, s % 60)
end

local W, H = 640, 470
local gui = mk("ScreenGui", {Name = "DailyRewardCard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 41, Enabled = false}, player.PlayerGui)
local shade = mk("TextButton", {Text = "", AutoButtonColor = false, Modal = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1)}, gui)
local card = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = INK}, gui)
corner(card, 8); stroke(card, Color3.fromRGB(150, 20, 46), 1.4)
local scale = mk("UIScale", {}, card)
local function fit() local v = gui.AbsoluteSize; scale.Scale = math.clamp(math.min(v.X / 760, v.Y / 520), 0.55, 1.2) end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit); fit()
local wash = mk("Frame", {BackgroundColor3 = BLOOD, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 96)}, card)
corner(wash, 8)
mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})}, wash)
text(card, {Text = "REWARDS  ·  LOG IN EVERY DAY", FontFace = BOLD, TextSize = 11, TextColor3 = Color3.fromRGB(255, 120, 140), TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(26, 18), Size = UDim2.fromOffset(300, 14)})
text(card, {Text = "Daily Reward", FontFace = BAL, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 32), Size = UDim2.fromOffset(400, 42)})
local streakL = text(card, {Text = "", FontFace = BOLD, TextSize = 12, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
	Position = UDim2.fromOffset(26, 74), Size = UDim2.fromOffset(400, 16)})
local close = mk("TextButton", {Text = "X", FontFace = BOLD, TextSize = 13, TextColor3 = BONE, AutoButtonColor = false, BackgroundColor3 = TILE,
	Position = UDim2.new(1, -46, 0, 16), Size = UDim2.fromOffset(30, 30)}, card)
corner(close, 5); local closeStroke = stroke(close, LINE)
close.MouseEnter:Connect(function() closeStroke.Color = BONE end)
close.MouseLeave:Connect(function() closeStroke.Color = LINE end)

-- the week
local TW, TH, GAP = 78, 140, 7
local x0 = (W - (7 * TW + 6 * GAP)) / 2
local tiles = {}
for i = 1, 7 do
	local big = i == 7
	local t = mk("Frame", {Name = "Day" .. i, BackgroundColor3 = TILE, Position = UDim2.fromOffset(x0 + (i - 1) * (TW + GAP), 108), Size = UDim2.fromOffset(TW, TH)}, card)
	corner(t, 6)
	local st = stroke(t, big and Color3.fromRGB(120, 90, 40) or LINE, 1)
	local dayL = text(t, {Text = "DAY " .. i, FontFace = BOLD, TextSize = 12, TextColor3 = big and GOLD or MUTED, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 14)})
	local icon = mk("ImageLabel", {BackgroundTransparency = 1, Image = marksImage(), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(big and 46 or 38, big and 46 or 38), ImageColor3 = big and Color3.fromRGB(255, 220, 150) or Color3.new(1, 1, 1)}, t)
	local amt = text(t, {Text = "+" .. Daily.Marks[i], FontFace = BAL, TextSize = big and 24 or 21, TextColor3 = big and GOLD or BONE, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 24)})
	text(t, {Text = "MARKS", FontFace = BOLD, TextSize = 9, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 117), Size = UDim2.new(1, 0, 0, 12)})
	local check = mk("Frame", {Name = "Check", BackgroundColor3 = Color3.fromRGB(14, 40, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(34, 34), Visible = false, ZIndex = 3}, t)
	corner(check, 17); stroke(check, GREEN, 1.5)
	text(check, {Text = "✓", FontFace = BOLD, TextSize = 20, TextColor3 = GREEN, Size = UDim2.fromScale(1, 1), ZIndex = 4})
	local pop = mk("UIScale", {}, t)
	tiles[i] = {frame = t, stroke = st, dayL = dayL, icon = icon, amt = amt, check = check, pop = pop, big = big}
end

local claim = mk("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(170, 12, 40), AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 268), Size = UDim2.fromOffset(300, 48)}, card)
corner(claim, 6); local claimStroke = stroke(claim, Color3.fromRGB(255, 90, 115), 1.4)
local claimL = text(claim, {Text = "CLAIM", FontFace = BOLD, TextSize = 16, Size = UDim2.fromScale(1, 1)})
local hint = text(card, {Text = "", FontFace = BODY, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 326), Size = UDim2.new(1, 0, 0, 16)})

-- codes: type one in, REDEEM (or Enter)
mk("Frame", {BackgroundColor3 = LINE, BorderSizePixel = 0, Position = UDim2.fromOffset(26, 356), Size = UDim2.new(1, -52, 0, 1)}, card)
text(card, {Text = "HAVE A CODE?", FontFace = BOLD, TextSize = 11, TextColor3 = Color3.fromRGB(255, 120, 140), TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(26, 370), Size = UDim2.fromOffset(200, 14)})
local codeNote = text(card, {Text = "Codes come from our community and updates.", FontFace = BODY, TextSize = 11, TextColor3 = MUTED,
	TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -326, 0, 370), Size = UDim2.fromOffset(300, 14)})
local box = mk("TextBox", {Name = "CodeInput", Text = "", PlaceholderText = "ENTER CODE", ClearTextOnFocus = false, FontFace = MONO, TextSize = 16,
	TextColor3 = BONE, PlaceholderColor3 = Color3.fromRGB(110, 96, 100), BackgroundColor3 = TILE, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(26, 394), Size = UDim2.new(1, -52 - 150, 0, 46)}, card)
corner(box, 6); local boxStroke = stroke(box, LINE, 1)
mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, box)
box.Focused:Connect(function() boxStroke.Color = RED end)
local redeem = mk("TextButton", {Name = "Redeem", Text = "REDEEM", FontFace = BOLD, TextSize = 14, TextColor3 = BONE, AutoButtonColor = false,
	BackgroundColor3 = Color3.fromRGB(170, 12, 40), Position = UDim2.new(1, -26 - 140, 0, 394), Size = UDim2.fromOffset(140, 46)}, card)
corner(redeem, 6); stroke(redeem, Color3.fromRGB(255, 90, 115), 1.2)
redeem.MouseEnter:Connect(function() redeem.BackgroundColor3 = Color3.fromRGB(205, 22, 52) end)
redeem.MouseLeave:Connect(function() redeem.BackgroundColor3 = Color3.fromRGB(170, 12, 40) end)
local redeemedAt = 0
local function submitCode()
	local code = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if code == "" or os.clock() - redeemedAt < 1 then return end
	redeemedAt = os.clock()
	menu:FireServer("Redeem", code)
	box.Text = ""
	codeNote.Text = "Checking…"
	task.delay(2.5, function() codeNote.Text = "Codes come from our community and updates." end)
end
redeem.Activated:Connect(submitCode)
box.FocusLost:Connect(function(enter) boxStroke.Color = LINE; if enter then submitCode() end end)
local pulse = 0

local function state()
	local claimed = player:GetAttribute("DailyClaimed") == true
	local day = player:GetAttribute("DailyDay") or 1
	return claimed, day, player:GetAttribute("DailyStreak") or 0
end
local function refresh()
	local claimed, day, streak = state()
	for i, t in ipairs(tiles) do
		local done = i < day or (i == day and claimed)
		local today = i == day and not claimed
		t.check.Visible = done
		t.icon.ImageTransparency = done and 0.75 or (i > day and 0.35 or 0)
		t.amt.TextTransparency = done and 0.5 or 0
		t.frame.BackgroundColor3 = today and Color3.fromRGB(70, 6, 22) or (done and Color3.fromRGB(16, 12, 13) or TILE)
		t.stroke.Color = today and RED or (t.big and Color3.fromRGB(120, 90, 40) or LINE)
		t.stroke.Thickness = today and 2 or 1
		t.dayL.Text = today and "TODAY" or ("DAY " .. i)
		t.dayL.TextColor3 = today and BONE or (t.big and GOLD or MUTED)
	end
	local mark = Daily.Marks[day] or 0
	if claimed then
		claimL.Text = "CLAIMED  ·  COME BACK TOMORROW"
		claim.BackgroundColor3 = TILE; claimStroke.Color = LINE; claimL.TextColor3 = MUTED
	else
		claimL.Text = "CLAIM  +" .. mark .. " MARKS"
		claim.BackgroundColor3 = Color3.fromRGB(170, 12, 40); claimStroke.Color = Color3.fromRGB(255, 90, 115); claimL.TextColor3 = BONE
	end
	streakL.Text = streak > 0 and string.format('STREAK  <font color="#ff4a6e">%d DAY%s</font>   ·   DAY %d OF 7', streak, streak == 1 and "" or "S", day)
		or string.format("DAY %d OF 7", day)
	-- the lobby button's red dot
	local b = lobby:FindFirstChild("DailyReward")
	if b and b:FindFirstChild("ReadyDot") then b.ReadyDot.Visible = player:GetAttribute("ProfileReady") == true and not claimed end
end
for _, a in ipairs({"DailyClaimed", "DailyDay", "DailyStreak", "ProfileReady"}) do
	player:GetAttributeChangedSignal(a):Connect(refresh)
end
refresh()

-- claimed: the tile pops and the button settles
player:GetAttributeChangedSignal("DailyClaimed"):Connect(function()
	if player:GetAttribute("DailyClaimed") ~= true or not gui.Enabled then return end
	local t = tiles[player:GetAttribute("DailyDay") or 1]
	if t then
		t.pop.Scale = 1.18
		TweenService:Create(t.pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
end)

local function open()
	refresh()
	gui.Enabled = true
	card.Position = UDim2.new(0.5, 0, 0.5, 24)
	TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quint), {Position = UDim2.fromScale(0.5, 0.5)}):Play()
end
local function shut() gui.Enabled = false; box.Text = ""; if box:IsFocused() then box:ReleaseFocus() end end
close.Activated:Connect(shut)
shade.Activated:Connect(shut)
local busy = 0
claim.Activated:Connect(function()
	if player:GetAttribute("DailyClaimed") == true then shut(); return end
	if os.clock() - busy < 1.5 then return end
	busy = os.clock()
	claimL.Text = "CLAIMING…"
	menu:FireServer("ClaimDaily")
end)
claim.MouseEnter:Connect(function() if player:GetAttribute("DailyClaimed") ~= true then claim.BackgroundColor3 = Color3.fromRGB(205, 22, 52) end end)
claim.MouseLeave:Connect(refresh)

-- countdown + the CLAIM button breathing while there's a reward waiting
RunService.Heartbeat:Connect(function(dt)
	if not gui.Enabled then return end
	local claimed = player:GetAttribute("DailyClaimed") == true
	local left = 86400 - math.floor(workspace:GetServerTimeNow()) % 86400
	hint.Text = claimed and ("NEXT REWARD IN " .. clock(left)) or ("MISS A DAY AND THE WEEK STARTS OVER  ·  RESETS IN " .. clock(left))
	if not claimed then
		pulse += dt * 3
		claimStroke.Thickness = 1.4 + (math.sin(pulse) * 0.5 + 0.5) * 1.6
	else
		claimStroke.Thickness = 1.4
	end
end)

-- the main menu's DAILY REWARD button, and anything else that sets OpenDaily
local button = lobby:WaitForChild("DailyReward", 10)
if button then button.Activated:Connect(open) end
player:GetAttributeChangedSignal("OpenCodes"):Connect(function() open(); task.defer(function() box:CaptureFocus() end) end)
player:GetAttributeChangedSignal("OpenDaily"):Connect(open)

-- pop up once per session on the main menu while today's reward is waiting
task.spawn(function()
	while player:GetAttribute("ProfileReady") ~= true do player:GetAttributeChangedSignal("ProfileReady"):Wait() end
	task.wait(2)
	while true do
		local community = player.PlayerGui:FindFirstChild("CommunityCard")
		local welcomePending = player:GetAttribute("CommunitySeen") ~= true
		local onMenu = lobby.Visible and player:GetAttribute("IntroPlaying") ~= true and player:GetAttribute("InMatch") ~= true
		if player:GetAttribute("DailyClaimed") == true then return end
		if onMenu and not (community and community.Enabled) and not welcomePending then break end
		task.wait(1)
	end
	task.wait(0.6)
	if player:GetAttribute("DailyClaimed") ~= true and not gui.Enabled then open() end
end)
