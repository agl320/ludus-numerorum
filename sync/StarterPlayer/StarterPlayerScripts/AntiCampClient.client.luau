-- NO HIDING THE VISOR (client side of ServerScriptService.AntiCamp):
--   you: a countdown card while you stand facing a wall, then "your number is exposed" until you step away
--   everyone else who's exposed: their number in red over their head and an outline through walls
--   you, once exposed: a warning sound, and your own outline (in the zone's colour) and number over your head, so you
--   can see you've been revealed
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local TopNotices = require(shared:WaitForChild("TopNotices"))
local me = Players.LocalPlayer
local RED = Color3.fromRGB(255, 38, 60)
local ZONE = require(shared:WaitForChild("ZoneRules")).Color
local function exposedSound()
	local gui = me:FindFirstChild("PlayerGui")
	local snd = Instance.new("Sound")
	-- the zone's bell toll, plus a low hit under it so it reads as a warning
	snd.SoundId = "rbxassetid://77402059079473"; snd.Volume = 0.35; snd.PlaybackSpeed = 1.12
	local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = -6; eq.MidGain = 0; eq.LowGain = 3; eq.Parent = snd
	snd.Parent = gui or workspace
	snd:Play()
	snd.Ended:Once(function() snd:Destroy() end)
	task.delay(6, function() if snd.Parent then snd:Destroy() end end)
end
local wasExposed = false

local tags = {} -- character -> {gui, label, highlight}
local function untag(c)
	local t = tags[c]
	if t then t.gui:Destroy(); t.highlight:Destroy(); tags[c] = nil end
end
local function tag(c, own)
	local head = c:FindFirstChild("Head")
	if not head then return end
	local t = tags[c]
	if t and t.own ~= own then untag(c); t = nil end
	if not t then
		local color = own and ZONE or RED
		local gui = Instance.new("BillboardGui")
		gui.Name = "ExposedNumber"; gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.MaxDistance = 160
		gui.Size = UDim2.fromOffset(150, 52); gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
		local eyebrow = Instance.new("TextLabel")
		eyebrow.BackgroundTransparency = 1; eyebrow.Size = UDim2.new(1, 0, 0, 14); eyebrow.Font = Enum.Font.GothamBold
		eyebrow.TextSize = 11; eyebrow.Text = own and "YOU'RE EXPOSED" or "EXPOSED"
		eyebrow.TextColor3 = own and Color3.fromRGB(226, 206, 255) or Color3.fromRGB(255, 200, 205)
		eyebrow.TextStrokeTransparency = 0.4; eyebrow.Parent = gui
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1; label.Position = UDim2.fromOffset(0, 14); label.Size = UDim2.new(1, 0, 0, 38)
		label.Font = Enum.Font.Code; label.TextScaled = true; label.TextColor3 = color
		label.TextStrokeColor3 = Color3.new(0, 0, 0); label.TextStrokeTransparency = 0.2; label.Parent = gui
		gui.Adornee = head; gui.Parent = head
		local h = Instance.new("Highlight")
		h.Name = "ExposedOutline"; h.FillTransparency = own and 0.88 or 1; h.FillColor = color; h.OutlineColor = color; h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Adornee = c; h.Parent = c
		t = {gui = gui, label = label, highlight = h, own = own}
		tags[c] = t
	end
	if t.gui.Parent ~= head then t.gui.Adornee = head; t.gui.Parent = head end
	t.label.Text = tostring(c:GetAttribute("NumberfallCode") or "????")
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	acc = 0
	local now = workspace:GetServerTimeNow()
	local seen = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and p ~= me and c:GetAttribute("Exposed") == true and p:GetAttribute("InArena") == true then
			tag(c); seen[c] = true
		end
	end
	-- yourself, once exposed (the sound plays as it happens)
	local mine = me.Character
	local exposedNow = mine ~= nil and mine:GetAttribute("Exposed") == true and me:GetAttribute("InArena") == true
	if exposedNow then tag(mine, true); seen[mine] = true end
	if exposedNow and not wasExposed then exposedSound() end
	wasExposed = exposedNow
	for c in pairs(tags) do if not seen[c] or not c.Parent then untag(c) end end
	-- your own countdown
	local c = me.Character
	local warnAt = c and c:GetAttribute("CampWarnAt")
	local exposeAt = c and c:GetAttribute("CampExposeAt")
	if c and c:GetAttribute("Exposed") == true then
		TopNotices.Set("camp", {kind = "warn", eyebrow = "NO HIDING", text = "YOUR NUMBER IS EXPOSED  ·  STEP AWAY FROM THE WALL", order = 3})
	elseif warnAt and exposeAt and now >= warnAt then
		TopNotices.Set("camp", {kind = "warn", eyebrow = "NO HIDING", text = string.format("FACING A WALL  ·  MOVE OR BE EXPOSED IN %d", math.max(0, math.ceil(exposeAt - now))), order = 3})
	else
		TopNotices.Set("camp", nil)
	end
end)
