-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
-- TUTORIAL (client).
--  * Main servers: new players get an offer on the main menu (once; Help > PLAY THE TUTORIAL any time after).
--  * Tutorial servers (ServerScriptService.TutorialService): the lesson card at the top of the screen, the warning
--    when a bot is reading your number, LEAVE TUTORIAL, and the finish screen.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = RS:WaitForChild("Numberfall")
local menu = shared:WaitForChild("Menu")
local pg = player:WaitForChild("PlayerGui")

local FONT = Font.new("rbxasset://fonts/families/Guru.json")
local BOLD = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local INK, CARD = Color3.fromRGB(9, 5, 7), Color3.fromRGB(16, 9, 12)
local RED, DIM, BONE, MUTED, FAINT, ACTIVE = Color3.fromRGB(255, 20, 60), Color3.fromRGB(96, 14, 32), Color3.fromRGB(240, 232, 228),
	Color3.fromRGB(170, 158, 160), Color3.fromRGB(105, 92, 96), Color3.fromRGB(110, 0, 28)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, c, t) return new("UIStroke", {Color = c or DIM, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function text(parent, props)
	local l = new("TextLabel", {BackgroundTransparency = 1, FontFace = props.Bold and BOLD or FONT, TextColor3 = props.Color or BONE,
		TextSize = props.Size or 18, Text = props.Text or "", TextXAlignment = props.X or Enum.TextXAlignment.Center,
		TextYAlignment = props.Y or Enum.TextYAlignment.Center, TextWrapped = props.Wrap == true,
		Position = props.Pos or UDim2.new(), Size = props.Dim or UDim2.fromScale(1, 1), AnchorPoint = props.Anchor or Vector2.zero,
		ZIndex = props.Z or 2}, parent)
	if props.Rich then l.RichText = true end
	return l
end
local function button(parent, label, primary, pos, size)
	local b = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = primary and ACTIVE or INK, Position = pos, Size = size,
		ZIndex = 3}, parent)
	corner(b, 6); stroke(b, primary and RED or DIM, primary and 1.4 or 1)
	text(b, {Text = label, Bold = true, Size = 18, Z = 4})
	b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = primary and Color3.fromRGB(150, 0, 38) or Color3.fromRGB(30, 14, 19)}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = primary and ACTIVE or INK}):Play() end)
	return b
end

local tutorialServer = shared:GetAttribute("TutorialServer") == true
if not tutorialServer then
	-- the server decides within a moment of starting; wait briefly so a tutorial server isn't mistaken for a main one
	local t0 = os.clock()
	while os.clock() - t0 < 3 and shared:GetAttribute("TutorialServer") == nil do task.wait(0.2) end
	tutorialServer = shared:GetAttribute("TutorialServer") == true
end

------------------------------------------------------------------ MAIN SERVERS: the offer
if not tutorialServer then
	local ui = pg:WaitForChild("MARKED_UI_EDITABLE", 30)
	local lobby = ui and ui:WaitForChild("Lobby", 30)
	local function start() menu:FireServer("TutorialStart") end
	-- Help > HOW TO PLAY > PLAY THE TUTORIAL
	task.spawn(function()
		local help = ui and ui:WaitForChild("Help", 30)
		while help do
			local b = help:FindFirstChild("TutorialButton", true)
			if b and b:IsA("GuiButton") then b.Activated:Connect(start); break end
			task.wait(1)
		end
	end)
	-- the one-time offer, on the main menu once the intro has finished
	local t0 = os.clock()
	while player:GetAttribute("ProfileReady") ~= true and os.clock() - t0 < 30 do task.wait(0.3) end
	if player:GetAttribute("TutorialDone") == true or player:GetAttribute("TutorialOffered") == true then return end

	if not lobby then return end
	local function onMenu()
		return lobby.Visible and player:GetAttribute("IntroPlaying") ~= true and player:GetAttribute("InMatch") ~= true
			and player:GetAttribute("InArena") ~= true
			-- (the main menu is itself the "Lobby" panel, so PanelOpen is true on it: lobby.Visible already means no
			-- other panel is up, since only one panel shows at a time)
	end
	local answered = false
	local function settled() return answered or player:GetAttribute("TutorialOffered") == true or player:GetAttribute("TutorialDone") == true end
	-- the card is modal while it's up (it blocks the menu behind it, so PLAY can't be clicked through it), and if the
	-- player leaves the menu anyway (PLAY before it appeared, a round pulling them in) it closes itself and comes back
	-- the next time they're on the menu, instead of sitting over the game where the mouse is locked and it can't be
	-- answered.
	local UIS = game:GetService("UserInputService")
	local function offer()
		local gui = new("ScreenGui", {Name = "TutorialOffer", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg)
		local shade = new("TextButton", {Text = "", AutoButtonColor = false, Active = true, BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, gui)
		local card = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(520, 258),
			BackgroundColor3 = CARD, BackgroundTransparency = 0.04, Active = true}, gui)
		corner(card, 10); stroke(card, DIM, 1)
		new("UIScale", {Scale = 1}, card)
		new("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(32, 30), Size = UDim2.fromOffset(4, 40)}, card)
		text(card, {Text = "NEW HERE?", Bold = true, Size = 38, X = Enum.TextXAlignment.Left, Pos = UDim2.fromOffset(48, 22), Dim = UDim2.fromOffset(440, 44)})
		text(card, {Text = "TUTORIAL  ·  ABOUT 3 MINUTES", Bold = true, Size = 14, Color = RED, X = Enum.TextXAlignment.Left, Pos = UDim2.fromOffset(48, 66), Dim = UDim2.fromOffset(440, 20)})
		text(card, {Text = "Learn to read a visor, write a number and keep yours hidden against 11 bots in a server of your own. You'll come straight back here after, with marks for finishing.",
			Size = 17, Color = MUTED, X = Enum.TextXAlignment.Left, Y = Enum.TextYAlignment.Top, Wrap = true, Pos = UDim2.fromOffset(32, 104), Dim = UDim2.fromOffset(456, 66)})
		local play = button(card, "PLAY TUTORIAL", true, UDim2.fromOffset(32, 182), UDim2.fromOffset(270, 50))
		local skip = button(card, "NOT NOW", false, UDim2.fromOffset(318, 182), UDim2.fromOffset(170, 50))
		local scale = card:FindFirstChildOfClass("UIScale")
		scale.Scale = 0.94; card.BackgroundTransparency = 1
		TweenService:Create(shade, TweenInfo.new(0.3), {BackgroundTransparency = 0.45}):Play()
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Scale = 1}):Play()
		TweenService:Create(card, TweenInfo.new(0.25), {BackgroundTransparency = 0.04}):Play()
		local open = true
		local conns = {}
		local function close()
			if not open then return end
			open = false
			for _, c in ipairs(conns) do c:Disconnect() end
			pcall(function() RunService:UnbindFromRenderStep("TutorialOfferMouse") end)
			TweenService:Create(shade, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
			TweenService:Create(scale, TweenInfo.new(0.2), {Scale = 0.94}):Play()
			task.delay(0.2, function() gui:Destroy() end)
		end
		local function skipIt() if not open then return end answered = true; menu:FireServer("TutorialSkip"); close() end
		play.Activated:Connect(function() if not open then return end answered = true; start(); close() end)
		skip.Activated:Connect(skipIt)
		-- Escape / B / Backspace is NOT NOW too
		table.insert(conns, UIS.InputBegan:Connect(function(input)
			if chatTyping() then return end
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Backspace then skipIt() end
		end))
		-- keep the cursor free while it's up
		RunService:BindToRenderStep("TutorialOfferMouse", Enum.RenderPriority.Last.Value + 6, function()
			UIS.MouseBehavior = Enum.MouseBehavior.Default; UIS.MouseIconEnabled = true
		end)
		-- left the menu without answering: put it away for now
		while open and gui.Parent do
			if not onMenu() or settled() then close() break end
			task.wait(0.2)
		end
	end
	while not settled() do
		while not onMenu() or settled() do
			if settled() then return end
			task.wait(0.5)
		end
		task.wait(1.2)
		-- still on the menu after the pause (they may have pressed PLAY in the meantime)
		if onMenu() and not settled() then offer() end
		task.wait(0.5)
	end
	return
end

------------------------------------------------------------------ TUTORIAL SERVERS: the lesson
local gui = new("ScreenGui", {Name = "TutorialHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg)
-- the step card (top centre, under the round bar)
local card = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(560, 128),
	BackgroundColor3 = CARD, BackgroundTransparency = 0.08}, gui)
corner(card, 10); stroke(card, DIM, 1)
local cardScale = new("UIScale", {Scale = 1}, card)
local stepLabel = text(card, {Text = "", Bold = true, Size = 13, Color = RED, X = Enum.TextXAlignment.Left, Pos = UDim2.fromOffset(24, 14), Dim = UDim2.fromOffset(300, 18)})
local count = text(card, {Text = "", Bold = true, Size = 13, Color = MUTED, X = Enum.TextXAlignment.Right, Pos = UDim2.fromOffset(236, 14), Dim = UDim2.fromOffset(300, 18)})
local title = text(card, {Text = "", Bold = true, Size = 30, X = Enum.TextXAlignment.Left, Pos = UDim2.fromOffset(24, 32), Dim = UDim2.fromOffset(512, 36)})
local body = text(card, {Text = "", Size = 16, Color = MUTED, X = Enum.TextXAlignment.Left, Y = Enum.TextYAlignment.Top, Wrap = true, Pos = UDim2.fromOffset(24, 72), Dim = UDim2.fromOffset(512, 46)})
local dots = new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.fromOffset(200, 6)}, card)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6)}, dots)
-- a bot is reading your number
local readWarn = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -190), Size = UDim2.fromOffset(380, 58),
	BackgroundColor3 = Color3.fromRGB(40, 4, 12), BackgroundTransparency = 0.1, Visible = false}, gui)
corner(readWarn, 8); local warnStroke = stroke(readWarn, RED, 1.4)
text(readWarn, {Text = "A BOT IS READING YOUR NUMBER", Bold = true, Size = 18, Pos = UDim2.fromOffset(0, 6), Dim = UDim2.new(1, 0, 0, 24)})
local track = new("Frame", {BackgroundColor3 = Color3.fromRGB(60, 20, 28), BorderSizePixel = 0, Position = UDim2.new(0, 20, 0, 38), Size = UDim2.new(1, -40, 0, 8)}, readWarn)
corner(track, 4)
local fill = new("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, track)
corner(fill, 4)
-- leave
local leave = button(gui, "LEAVE TUTORIAL", false, UDim2.new(1, -230, 0, 132), UDim2.fromOffset(200, 42))
leave.AnchorPoint = Vector2.zero
text(gui, {Text = "CAPS LOCK frees the mouse", Size = 13, Color = FAINT, X = Enum.TextXAlignment.Right, Pos = UDim2.new(1, -230, 0, 178), Dim = UDim2.fromOffset(200, 18)})
leave.Activated:Connect(function() menu:FireServer("TutorialLeave") end)
-- finish screen
local done = new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 10}, gui)
local doneCard = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 270),
	BackgroundColor3 = CARD, ZIndex = 11}, done)
corner(doneCard, 10); stroke(doneCard, RED, 1.4)
text(doneCard, {Text = "TUTORIAL COMPLETE", Bold = true, Size = 40, Pos = UDim2.fromOffset(0, 30), Dim = UDim2.new(1, 0, 0, 48), Z = 12})
local doneReward = text(doneCard, {Text = "", Bold = true, Size = 24, Color = RED, Pos = UDim2.fromOffset(0, 90), Dim = UDim2.new(1, 0, 0, 30), Z = 12})
text(doneCard, {Text = "Read their number. Hide yours. Good luck out there.", Size = 17, Color = MUTED, Pos = UDim2.fromOffset(0, 132), Dim = UDim2.new(1, 0, 0, 24), Z = 12})
local doneBack = text(doneCard, {Text = "", Bold = true, Size = 15, Color = FAINT, Pos = UDim2.fromOffset(0, 206), Dim = UDim2.new(1, 0, 0, 22), Z = 12})

local lastStep
local function render()
	local id = player:GetAttribute("TutorialStep")
	local i = player:GetAttribute("TutorialStepIndex") or 0
	local n = player:GetAttribute("TutorialStepCount") or 6
	card.Visible = id ~= nil and id ~= "DONE"
	stepLabel.Text = string.format("TUTORIAL  ·  STEP %d OF %d", math.min(i, n), n)
	title.Text = player:GetAttribute("TutorialTitle") or ""
	body.Text = player:GetAttribute("TutorialText") or ""
	local marked, total = player:GetAttribute("TutorialMarked") or 0, player:GetAttribute("TutorialTotal") or 11
	count.Text = string.format("BOTS MARKED  %d / %d", marked, total)
	for _, c in ipairs(dots:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	for k = 1, n do
		local d = new("Frame", {BackgroundColor3 = k < i and RED or (k == i and BONE or DIM), BorderSizePixel = 0, Size = UDim2.fromOffset(k == i and 26 or 14, 6)}, dots)
		corner(d, 3)
	end
	if id ~= lastStep then
		lastStep = id
		cardScale.Scale = 1.06
		TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end
	if id == "DONE" and not done.Visible then
		done.Visible = true
		local reward = player:GetAttribute("TutorialReward") or 0
		doneReward.Text = reward > 0 and ("+" .. reward .. " MARKS") or "ALREADY COMPLETED"
		TweenService:Create(done, TweenInfo.new(0.5), {BackgroundTransparency = 0.35}):Play()
		leave.Visible = false
		task.spawn(function()
			for t = 8, 1, -1 do doneBack.Text = "BACK TO MARKED IN " .. t; task.wait(1) end
			doneBack.Text = "TELEPORTING…"
		end)
	end
end
for _, a in ipairs({"TutorialStep", "TutorialStepIndex", "TutorialTitle", "TutorialText", "TutorialMarked", "TutorialTotal", "TutorialReward"}) do
	player:GetAttributeChangedSignal(a):Connect(render)
end
render()
-- the step card sits under the round's top bar, and the top notices (NEW NUMBER, zone warnings...) stack under the
-- card instead of on top of it (it used to sit at a fixed height, over the bar and the notices)
local TopNotices = require(shared:WaitForChild("TopNotices"))
RunService.RenderStepped:Connect(function()
	if card.Visible then
		TopNotices.Reserve("0Tutorial", 128 + 22)
		card.Position = UDim2.new(0.5, 0, 0, TopNotices.Top("0Tutorial"))
	else
		TopNotices.Reserve("0Tutorial", nil)
	end
	local r = player:GetAttribute("TutorialRead") or 0
	readWarn.Visible = r > 0.02 and player:GetAttribute("TutorialStep") ~= "DONE"
	if readWarn.Visible then
		fill.Size = UDim2.fromScale(math.clamp(r, 0, 1), 1)
		warnStroke.Transparency = 0.5 - 0.5 * math.abs(math.sin(os.clock() * 6))
	end
end)
