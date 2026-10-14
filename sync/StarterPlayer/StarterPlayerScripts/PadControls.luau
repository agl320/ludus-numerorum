-- Touch (phones / tablets) and gamepad (console, controllers) controls.
--  * Input mode: the last device used ("keyboard", "touch" or "gamepad"), shown as the player attribute InputMode
--    so the HUD, Help and the ready button can label themselves for it.
--  * Touch: round action buttons fanned around Roblox's jump button (RUN, SLIDE, DASH, DUCK and # to write a
--    number). While writing, a keypad takes their place: 0-9, erase and mark.
--  * Gamepad: L3 sprint, B slide (hold), X dash, LT crouch (hold), Y write a number, D-pad up Help, D-pad down
--    players, D-pad right first / third person. Writing uses a number dial: the right stick (or D-pad left / right)
--    picks a digit, RB / RT writes it (and marks once all four are in), LB erases, Y or B puts it away.
--  * Menus with a gamepad: Roblox's menu selection is switched on, and the main button of any menu that opens is
--    selected for you, so A presses it straight away.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CAS = game:GetService("ContextActionService")
local Run = game:GetService("RunService")

local Pad = {}
Pad.__index = Pad

local INK = Color3.fromRGB(14, 9, 11)
local KEY = Color3.fromRGB(34, 18, 23)
local LINE = Color3.fromRGB(104, 44, 58)
local HOT = Color3.fromRGB(190, 16, 46)
local HOT_LINE = Color3.fromRGB(255, 110, 130)
local BONE = Color3.fromRGB(238, 230, 226)
local MUTED = Color3.fromRGB(176, 160, 164)
local SANS = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function round(o, r) mk("UICorner", {CornerRadius = r or UDim.new(1, 0)}, o) end

-- the device the player is using right now
function Pad.Mode()
	-- testing in Studio: set the player attribute ForceInputMode to "touch" / "gamepad" to see those controls
	local forced = Players.LocalPlayer and Players.LocalPlayer:GetAttribute("ForceInputMode")
	if forced == "touch" or forced == "gamepad" or forced == "keyboard" then return forced end
	local last = UIS:GetLastInputType()
	if last.Name:match("^Gamepad") then return "gamepad" end
	if last == Enum.UserInputType.Touch then return "touch" end
	if last == Enum.UserInputType.Keyboard or last.Name:match("^Mouse") then return "keyboard" end
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then return "touch" end
	if UIS.GamepadEnabled and not UIS.KeyboardEnabled then return "gamepad" end
	return "keyboard"
end

-- panels that take over the screen (the rest -- number entry, Help, a held players list -- are overlays you keep
-- moving under)
local LIGHT = {Entry = true, Help = true}
local FIRST_BUTTON = {Lobby = "Deploy", Results = "Again", Settings = "Close", Credits = "Close", PatchNotes = "Close"}

function Pad.new(o)
	local self = setmetatable(o, Pad)
	self.player = self.player or Players.LocalPlayer
	self.dialDigit = 0
	self.buttons = {}
	local pg = self.player:WaitForChild("PlayerGui")
	self:BuildTouch(pg)
	self:BuildDial(pg)
	self:SetMode(Pad.Mode())
	UIS.LastInputTypeChanged:Connect(function() self:SetMode(Pad.Mode()) end)
	self.player:GetAttributeChangedSignal("ForceInputMode"):Connect(function() self:SetMode(Pad.Mode()) end)
	UIS.InputBegan:Connect(function(io, processed) self:Began(io, processed) end)
	UIS.InputEnded:Connect(function(io) self:Ended(io) end)
	local acc = 0
	Run.RenderStepped:Connect(function(dt)
		self:Step()
		acc += dt
		if acc > 0.25 then acc = 0; self:AutoSelect() end
	end)
	return self
end

function Pad:SetMode(mode)
	if mode == self.mode then return end
	self.mode = mode
	self.player:SetAttribute("InputMode", mode)
	-- Roblox's menu selection (the \ key / select button): wanted with a gamepad, in the way with a keyboard
	pcall(function() GuiService.AutoSelectGuiEnabled = mode == "gamepad" end)
	if mode ~= "gamepad" then
		self:SetPadSlide(false)
		if self.padCrouch then self.padCrouch = false; self.parkour:SetCrouch(false) end
	end
end

-- ===== state helpers =====
function Pad:Alive()
	local c = self.player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
function Pad:InMatch() return self.player:GetAttribute("InMatch") == true end
function Pad:InArena() return self.player:GetAttribute("InArena") == true end
function Pad:Blocked()
	local hud = self.hud
	return (hud.presentation and hud.presentation:BlocksInput()) or self.player:GetAttribute("IntroPlaying") == true
end
-- free to move / use moves: in the lobby courtyard or a round, no big menu up
function Pad:Playing()
	local hud = self.hud
	return self:InMatch() and self:Alive() and not self:Blocked()
		and (not hud.open or LIGHT[hud.active] == true or (hud.active == "Leaderboard" and hud.peek == true))
end
function Pad:Writing() return self.hud.active == "Entry" end

-- ===== actions (shared by touch and gamepad) =====
function Pad:Sprint() if self:Playing() then self.feel:SetSprint(not self.feel.sprint) end end
function Pad:Slide() if self:Playing() then self.feel:Slide() end end
function Pad:Dash() if self:Playing() then self.parkour:RequestDash() end end
function Pad:Crouch(on)
	if on and not self:Playing() then return end
	self.parkour:SetCrouch(on)
end
function Pad:Write()
	-- (in the lobby too: the gear comes out as a scratch pad there)
	if not self:InMatch() then return end
	if self.hud.openEntry then self.hud.openEntry() end
end
-- turn your gear over to look at it (Y on a keyboard)
function Pad:Inspect() if self:Playing() and self.inspect then self.inspect() end end
function Pad:SetPadSlide(on) if self.parkour then self.parkour.padSlideHeld = on == true end end

-- ===== TOUCH =====
local TOUCH_ACTIONS = {
	{"Sprint", "RUN"}, {"Slide", "SLIDE"}, {"Dash", "DASH"}, {"Crouch", "DUCK"}, {"Write", "#"}, {"Inspect", "LOOK"},
}
function Pad:BuildTouch(pg)
	local gui = mk("ScreenGui", {Name = "TouchControls", ResetOnSpawn = false, DisplayOrder = 4, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, pg)
	self.touchGui = gui
	for _, spec in ipairs(TOUCH_ACTIONS) do
		local name, text = spec[1], spec[2]
		local b = mk("TextButton", {Name = name, AutoButtonColor = false, Text = "", BackgroundColor3 = INK, BackgroundTransparency = 0.25,
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 60), Selectable = false}, gui)
		round(b)
		local stroke = mk("UIStroke", {Color = LINE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, b)
		local label = mk("TextLabel", {Name = "Label", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = text,
			FontFace = name == "Write" and MONO or SANS, TextScaled = true, TextColor3 = BONE}, b)
		mk("UITextSizeConstraint", {MaxTextSize = name == "Write" and 34 or 17, MinTextSize = 8}, label)
		mk("UIPadding", {PaddingLeft = UDim.new(0.14, 0), PaddingRight = UDim.new(0.14, 0), PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0)}, label)
		b.InputBegan:Connect(function(io)
			if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if name == "Sprint" then self:Sprint()
			elseif name == "Slide" then self:Slide()
			elseif name == "Dash" then self:Dash()
			elseif name == "Crouch" then self:Crouch(not self.parkour.crouchHeld)
			elseif name == "Write" then self:Write()
			elseif name == "Inspect" then self:Inspect() end
		end)
		self.buttons[name] = {button = b, stroke = stroke, label = label}
	end
	-- keypad (while writing a number)
	local pad = mk("Frame", {Name = "Keypad", BackgroundColor3 = INK, BackgroundTransparency = 0.3, AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(170, 226), Visible = false}, gui)
	round(pad, UDim.new(0, 10))
	mk("UIStroke", {Color = LINE, Thickness = 1}, pad)
	self.keypad = pad
	self.keys = {}
	local order = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"}
	for i, k in ipairs(order) do
		local key = mk("TextButton", {Name = "Key" .. k, AutoButtonColor = false, Text = k == "<" and "⌫" or (k == "OK" and "✓" or k),
			FontFace = k:match("%d") and MONO or SANS, TextScaled = true, TextColor3 = BONE, BackgroundColor3 = KEY, Selectable = false}, pad)
		round(key, UDim.new(0, 8))
		local ks = mk("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, key)
		mk("UIPadding", {PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0)}, key)
		key.InputBegan:Connect(function(io)
			if io.UserInputType ~= Enum.UserInputType.Touch and io.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			key.BackgroundColor3 = HOT
			task.delay(0.08, function() key.BackgroundColor3 = KEY end)
			if k == "<" then self.erase()
			elseif k == "OK" then self.confirm()
			else self.typeDigit(k) end
		end)
		self.keys[i] = {button = key, stroke = ks, key = k}
	end
end

-- where Roblox's touch jump button is (centre, size), or where it will be
function Pad:JumpButton(view)
	local pg = self.player:FindFirstChild("PlayerGui")
	local tg = pg and pg:FindFirstChild("TouchGui")
	local frame = tg and tg:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump.AbsoluteSize.X > 0 then
		local inset = GuiService:GetGuiInset()
		local c = jump.AbsolutePosition + jump.AbsoluteSize / 2 + (tg.IgnoreGuiInset and Vector2.zero or inset)
		return c, jump.AbsoluteSize.X
	end
	local small = math.min(view.X, view.Y) <= 500
	local size = small and 70 or 120
	local pos = small and Vector2.new(view.X - 95, view.Y - 90) or Vector2.new(view.X - 170, view.Y - 210)
	return pos + Vector2.new(size, size) / 2, size
end

function Pad:LayoutTouch()
	local cam = workspace.CurrentCamera
	local view = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local key = tostring(view)
	if self.touchKey == key and os.clock() - (self.touchAt or 0) < 1 then return end
	self.touchKey, self.touchAt = key, os.clock()
	local c, js = self:JumpButton(view)
	local b = math.clamp(math.floor(js * 0.8), 50, 84)
	-- a fan around the jump button: slide to its left, dash up-left, run above, duck further left, # up-left of them
	local spots = {
		Slide = c + Vector2.new(-js * 1.15, js * 0.12),
		Dash = c + Vector2.new(-js * 0.98, -js * 0.98),
		Sprint = c + Vector2.new(0, -js * 1.28),
		Crouch = c + Vector2.new(-js * 2.12, js * 0.16),
		Write = c + Vector2.new(-js * 2.0, -js * 1.2),
		Inspect = c + Vector2.new(-js * 2.95, -js * 0.55),
	}
	for name, at in pairs(spots) do
		local it = self.buttons[name]
		local size = name == "Write" and math.floor(b * 1.12) or name == "Inspect" and math.floor(b * 0.86) or b
		it.button.Size = UDim2.fromOffset(size, size)
		it.button.Position = UDim2.fromOffset(at.X, at.Y)
	end
	-- keypad: left of the jump button, bottoms lined up
	local k = math.clamp(math.floor(js * 0.62), 40, 64)
	local gap = math.max(5, math.floor(k * 0.12))
	local padW, padH = k * 3 + gap * 4, k * 4 + gap * 5
	local maxH = view.Y - 16 - b
	if padH > maxH then
		k = math.floor((maxH - gap * 5) / 4); padW, padH = k * 3 + gap * 4, k * 4 + gap * 5
	end
	local bottom = math.min(view.Y - 8, c.Y + js * 0.5)
	self.keypad.Size = UDim2.fromOffset(padW, padH)
	self.keypad.Position = UDim2.fromOffset(c.X - js * 0.7, bottom)
	for i, it in ipairs(self.keys) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		it.button.Size = UDim2.fromOffset(k, k)
		it.button.Position = UDim2.fromOffset(gap + col * (k + gap), gap + row * (k + gap))
	end
	-- the # button (now an X to put it away) sits above the keypad while writing
	self.writeOpenSpot = Vector2.new(c.X - js * 0.7 - padW / 2, math.max(b * 0.6, bottom - padH - b * 0.62))
	self.writeSpot = spots.Write
end

local function paint(it, on)
	it.button.BackgroundColor3 = on and HOT or INK
	it.button.BackgroundTransparency = on and 0.1 or 0.25
	it.stroke.Color = on and HOT_LINE or LINE
end

function Pad:StepTouch()
	local show = self.mode == "touch" and self:Playing()
	self.touchGui.Enabled = show
	if not show then return end
	self:LayoutTouch()
	local writing = self:Writing() and self:InMatch()
	local p = self.parkour
	for name, it in pairs(self.buttons) do
		if name == "Write" then
			it.button.Visible = self:InMatch()
			it.label.Text = writing and "✕" or "#"
			local at = writing and self.writeOpenSpot or self.writeSpot
			if at then it.button.Position = UDim2.fromOffset(at.X, at.Y) end
			paint(it, writing)
		else
			it.button.Visible = not writing
		end
	end
	paint(self.buttons.Sprint, self.feel.sprint)
	paint(self.buttons.Slide, p and p.sliding)
	paint(self.buttons.Dash, p and os.clock() < (p.dashUntil or 0))
	paint(self.buttons.Crouch, p and p.crouchHeld)
	-- cooldowns dim the button
	local dashCd = p and math.max(0, (p.dashReadyAt or 0) - os.clock()) or 0
	self.buttons.Dash.label.TextTransparency = dashCd > 0 and 0.55 or 0
	self.keypad.Visible = writing
	if writing then
		local full = #(self.input.buffer or "") == 4
		local ok = self.keys[12]
		ok.button.BackgroundColor3 = full and HOT or KEY
		ok.stroke.Color = full and HOT_LINE or LINE
	end
end

-- ===== GAMEPAD: the number dial =====
function Pad:BuildDial(pg)
	local gui = mk("ScreenGui", {Name = "NumberDial", ResetOnSpawn = false, DisplayOrder = 5, Enabled = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg)
	self.dialGui = gui
	local root = mk("Frame", {Name = "Dial", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(236, 270)}, gui)
	self.dial = root
	self.dialScale = mk("UIScale", {}, root)
	local ring = mk("Frame", {Name = "Ring", BackgroundColor3 = INK, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(236, 236)}, root)
	round(ring)
	mk("UIStroke", {Color = LINE, Thickness = 1.5}, ring)
	self.cells = {}
	for d = 0, 9 do
		local a = math.rad(d * 36)
		local x, y = 118 + math.sin(a) * 88, 118 - math.cos(a) * 88
		local cell = mk("TextLabel", {Name = "D" .. d, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = KEY, Text = tostring(d), FontFace = MONO, TextSize = 24, TextColor3 = BONE}, ring)
		round(cell)
		local s = mk("UIStroke", {Color = LINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, cell)
		self.cells[d] = {cell = cell, stroke = s}
	end
	-- centre: what RB does right now
	self.dialCentre = mk("TextLabel", {Name = "Centre", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(118, 118),
		Size = UDim2.fromOffset(110, 58), BackgroundTransparency = 1, Text = "RB\nWRITE", FontFace = SANS, TextSize = 18,
		TextColor3 = BONE}, ring)
	mk("TextLabel", {Name = "Legend", BackgroundTransparency = 1, Position = UDim2.fromOffset(-40, 242), Size = UDim2.fromOffset(316, 22),
		Text = "R STICK pick   ·   RB write   ·   LB erase   ·   Y close", FontFace = SANS, TextSize = 14, TextColor3 = MUTED}, root)
end

function Pad:DialOpen() return self.dialBound == true end

function Pad:SetDial(d)
	d = d % 10
	if d == self.dialDigit then return end
	self.dialDigit = d
	if self.sound then pcall(function() self.sound:Play("UITab", 1.1) end) end
end

function Pad:BindDial(on)
	if on == (self.dialBound == true) then return end
	self.dialBound = on
	if on then
		-- the right stick picks digits instead of turning the camera while the dial is up
		CAS:BindActionAtPriority("MarkedNumberDial", function(_, state, io)
			if io.KeyCode == Enum.KeyCode.Thumbstick2 then
				local v = Vector2.new(io.Position.X, io.Position.Y)
				if v.Magnitude > 0.55 then
					local deg = math.deg(math.atan2(v.X, v.Y)) % 360
					self:SetDial(math.floor((deg + 18) / 36) % 10)
				end
			elseif state == Enum.UserInputState.Begin then
				if io.KeyCode == Enum.KeyCode.DPadLeft then self:SetDial(self.dialDigit - 1)
				elseif io.KeyCode == Enum.KeyCode.DPadRight then self:SetDial(self.dialDigit + 1) end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.Thumbstick2, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)
	else
		CAS:UnbindAction("MarkedNumberDial")
	end
end

function Pad:StepDial()
	local show = self.mode == "gamepad" and self:Writing() and self:InMatch() and self:Playing()
	self:BindDial(show)
	self.dialGui.Enabled = show
	if not show then return end
	local view = self.dialGui.AbsoluteSize
	if view.Y <= 0 then return end
	local s = math.clamp(view.Y / 1080, 0.65, 1.25)
	self.dialScale.Scale = s
	-- right of the number entry card (docked bottom centre)
	local entry = self.hud.gui:FindFirstChild("Entry")
	local right = entry and entry.AbsoluteSize.X > 0 and (entry.AbsolutePosition.X + entry.AbsoluteSize.X) or view.X / 2 + 140
	self.dial.Position = UDim2.fromOffset(right + 24 * s + 118 * s, view.Y - 26 * s - 135 * s)
	for d, it in pairs(self.cells) do
		local on = d == self.dialDigit
		it.cell.BackgroundColor3 = on and HOT or KEY
		it.stroke.Color = on and HOT_LINE or LINE
		it.cell.TextSize = on and 28 or 24
	end
	local full = #(self.input.buffer or "") == 4
	-- (a full line in the lobby is only written down: no marks there)
	self.dialCentre.Text = full and (self:InArena() and "RB\nMARK" or "RB\nWRITE") or ("RB\nWRITE " .. self.dialDigit)
	self.dialCentre.TextColor3 = full and Color3.fromRGB(255, 120, 136) or BONE
end

-- ===== GAMEPAD: buttons =====
function Pad:Began(io, processed)
	if io.UserInputType.Name:match("^Gamepad") == nil then return end
	local k = io.KeyCode
	local hud = self.hud
	-- B: back out of a menu first; otherwise put the number away, otherwise slide
	if k == Enum.KeyCode.ButtonB then
		if hud.open and hud.active ~= "Lobby" and not LIGHT[hud.active] then hud:Show("HUD"); return end
		if hud.active == "Help" then hud:Show("HUD"); return end
		if processed then return end
		if self:Writing() then self:Write(); return end
		self:SetPadSlide(true); self:Slide(); return
	end
	if processed then return end
	if self:DialOpen() then
		if k == Enum.KeyCode.ButtonR1 or k == Enum.KeyCode.ButtonR2 then
			if #(self.input.buffer or "") >= 4 then self.confirm() else self.typeDigit(tostring(self.dialDigit)) end
			return
		elseif k == Enum.KeyCode.ButtonL1 then self.erase(); return
		elseif k == Enum.KeyCode.ButtonY then self:Write(); return end
	end
	if k == Enum.KeyCode.ButtonY then self:Write()
	elseif k == Enum.KeyCode.ButtonL3 then self:Sprint()
	elseif k == Enum.KeyCode.ButtonX then self:Dash()
	elseif k == Enum.KeyCode.ButtonL2 then self.padCrouch = true; self:Crouch(true)
	elseif k == Enum.KeyCode.DPadUp then
		if self:InMatch() and (hud.active == nil or hud.active == "Help") then hud:ToggleHelp() end
	elseif k == Enum.KeyCode.DPadDown then
		if not self:InMatch() then return end
		if hud.active == "Leaderboard" then hud:Show("HUD")
		elseif hud.active == nil then hud.peek = false; hud:Show("Leaderboard") end
	elseif k == Enum.KeyCode.DPadRight then
		if self.toggleCamera and self:Playing() then self.toggleCamera() end
	elseif k == Enum.KeyCode.DPadLeft then
		self:Inspect() -- (while writing, the dial takes D-pad left / right instead)
	end
end

function Pad:Ended(io)
	local k = io.KeyCode
	if k == Enum.KeyCode.ButtonB then self:SetPadSlide(false)
	elseif k == Enum.KeyCode.ButtonL2 and self.padCrouch then self.padCrouch = false; self.parkour:SetCrouch(false) end
end

-- with a gamepad, select the main button of whatever menu / card is up so A works straight away
local OVERLAYS = {"VictoryScreen", "DailyRewardCard", "CommunityCard"}
local function shownIn(d, container)
	local p = d.Parent
	while p and p ~= container do
		if p:IsA("GuiObject") and not p.Visible then return false end
		p = p.Parent
	end
	return true
end
local function firstButton(container, preferred)
	if preferred then
		local b = container:FindFirstChild(preferred, true)
		if b and b:IsA("GuiButton") and b.Visible and b.AbsoluteSize.X > 0 and shownIn(b, container) then return b end
	end
	local best, bestY, bestX
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("GuiButton") and d.Selectable and d.Visible and d.AbsoluteSize.X > 4 and d.AbsoluteSize.Y > 4 and shownIn(d, container) then
			local pos = d.AbsolutePosition
			if not best or pos.Y < bestY - 4 or (math.abs(pos.Y - bestY) <= 4 and pos.X < bestX) then best, bestY, bestX = d, pos.Y, pos.X end
		end
	end
	return best
end
local function within(obj, container) return obj ~= nil and container ~= nil and obj:IsDescendantOf(container) end

function Pad:AutoSelect()
	if self.mode ~= "gamepad" then return end
	if self.player:GetAttribute("IntroPlaying") then return end
	local current = GuiService.SelectedObject
	local pg = self.player:FindFirstChild("PlayerGui")
	if not pg then return end
	-- cards drawn over everything first
	for _, name in ipairs(OVERLAYS) do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			if not within(current, g) or not current.Visible then
				local b = firstButton(g)
				if b then GuiService.SelectedObject = b end
			end
			return
		end
	end
	local hud = self.hud
	local panel = hud.active and not LIGHT[hud.active] and not (hud.active == "Leaderboard" and hud.peek) and hud.gui:FindFirstChild(hud.active)
	if panel and panel.Visible then
		if not within(current, panel) or not current.Visible then
			local b = firstButton(panel, FIRST_BUTTON[hud.active])
			if b then GuiService.SelectedObject = b end
		end
	elseif current and current:IsDescendantOf(hud.gui) then
		-- the menu closed: hand the controller back to the character
		GuiService.SelectedObject = nil
	end
end

function Pad:Step()
	self:StepTouch()
	self:StepDial()
	-- a held LT only counts while you can actually move
	if self.padCrouch and not self:Playing() then self.padCrouch = false; self.parkour:SetCrouch(false) end
end

return Pad
