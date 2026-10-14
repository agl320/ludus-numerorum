-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
-- Lobby ready button. Shown while you've pressed Play (InMatch) and are waiting in the lobby (not InArena).
-- Only players who are READY get sent into the next match. Toggle with the button or the R key.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local remote = shared:WaitForChild("Menu")

local RED = Color3.fromRGB(255, 34, 58)
local DEEP = Color3.fromRGB(118, 12, 28)
local INK = Color3.fromRGB(14, 10, 12)
local BONE = Color3.fromRGB(238, 233, 230)
local MUTED = Color3.fromRGB(160, 146, 146)
local BAL = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Regular)
local GOTHAM = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local gui = mk("ScreenGui", {Name = "ReadyUI", ResetOnSpawn = false, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local scale = mk("UIScale", {}, gui)

local root = mk("Frame", {Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(300, 92), Visible = false}, gui)

local button = mk("TextButton", {Name = "Button", AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(300, 64), BackgroundColor3 = INK, BackgroundTransparency = 0.12}, root)
mk("UICorner", {CornerRadius = UDim.new(0, 4)}, button)
local stroke = mk("UIStroke", {Color = RED, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, button)
local title = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 32),
	FontFace = BAL, TextSize = 30, TextColor3 = BONE, Text = "R E A D Y   U P", ZIndex = 2}, button)
local hint = mk("TextLabel", {Name = "Hint", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 14),
	FontFace = GOTHAM, TextSize = 11, TextColor3 = MUTED, Text = "PRESS R", ZIndex = 2}, button)
-- two red corner ticks to match the menu buttons
for i, pos in ipairs({UDim2.fromOffset(6, 6), UDim2.new(1, -6, 1, -6)}) do
	local a = Vector2.new(i == 1 and 0 or 1, i == 1 and 0 or 1)
	mk("Frame", {Name = "TickH" .. i, AnchorPoint = a, Position = pos, Size = UDim2.fromOffset(14, 2), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 2}, button)
	mk("Frame", {Name = "TickV" .. i, AnchorPoint = a, Position = pos, Size = UDim2.fromOffset(2, 14), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 2}, button)
end

local hovering = false
local lastSend = 0
local function isReady() return player:GetAttribute("Ready") == true end

-- the key to press depends on the device in use (InputMode, set by PadControls)
local function keyName()
	local mode = player:GetAttribute("InputMode")
	return mode == "gamepad" and "PRESS Y" or (mode == "touch" and "TAP" or "PRESS R")
end
local function paint()
	local ready = isReady()
	local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
	TweenService:Create(button, info, {BackgroundColor3 = ready and DEEP or INK, BackgroundTransparency = ready and 0.05 or 0.12}):Play()
	stroke.Color = ready and BONE or (hovering and Color3.fromRGB(255, 90, 105) or RED)
	title.Text = ready and "R E A D Y" or "R E A D Y   U P"
	hint.Text = ready and (keyName() .. " TO CANCEL") or keyName()
	hint.TextColor3 = ready and BONE or MUTED
end

local function canToggle()
	return player:GetAttribute("InMatch") == true and player:GetAttribute("InArena") ~= true and shared:GetAttribute("Phase") ~= "Countdown"
end

local function toggle()
	if not canToggle() or os.clock() - lastSend < 0.35 then return end
	lastSend = os.clock()
	remote:FireServer("Ready", not isReady())
end

button.Activated:Connect(toggle)
button.MouseEnter:Connect(function() hovering = true; paint() end)
button.MouseLeave:Connect(function() hovering = false; paint() end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or chatTyping() or (input.KeyCode ~= Enum.KeyCode.R and input.KeyCode ~= Enum.KeyCode.ButtonY) then return end
	if not root.Visible then return end
	toggle()
end)
player:GetAttributeChangedSignal("Ready"):Connect(paint)
player:GetAttributeChangedSignal("InputMode"):Connect(paint)
paint()

local last = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - last < 0.15 then return end
	last = now
	local ui = player.PlayerGui:FindFirstChild("MARKED_UI_EDITABLE")
	local show = canToggle() and not (ui and ui:GetAttribute("PanelOpen") == true) and not player:GetAttribute("IntroPlaying")
		and not player:GetAttribute("Killcam") -- spectating: the spectator bar sits where this button is
	root.Visible = show
	if not show then return end
	local cam = workspace.CurrentCamera
	local h = cam and cam.ViewportSize.Y or 900
	scale.Scale = math.clamp(h / 900, 0.7, 1)

end)
