-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
-- MARKED intro cinematic (client only). Plays the first time a player ever joins (saved in their profile as
-- IntroSeen), before the lobby menu.
-- Shows the city at dusk, the visor numbers, rooftop parkour, writing a number in the notebook
-- and an elimination, then hands the camera and UI back. Space / Esc / the Skip button skip it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local shared = ReplicatedStorage:WaitForChild("Numberfall")
local okCfg, config = pcall(require, shared:WaitForChild("Config"))
if not okCfg then config = {} end

local city = workspace:WaitForChild("SunsetCity", 30)
if not city then return end
do
	local t0 = os.clock()
	while os.clock() - t0 < 15 and not (city:FindFirstChild("Cathedral") and city:FindFirstChild("TownCircle")) do task.wait(0.25) end
end
local R = city:GetAttribute("RootCF") or CFrame.new()
local RR = R - R.Position
local function W(x, y, z) return (R * CFrame.new(x, y, z)).Position end

local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart", 10)
character:WaitForChild("LEDVisor", 6) -- the loadout (visor, hair, outfit) is dressed on by the server; the actors copy it
-- only once per player: wait for the profile, and skip if they've already seen it
do
	local t0 = os.clock()
	while player:GetAttribute("ProfileReady") ~= true and os.clock() - t0 < 10 do task.wait(0.2) end
	if player:GetAttribute("IntroSeen") == true then return end
	if shared:GetAttribute("TutorialServer") == true then return end -- (the tutorial server goes straight to the lesson)
end
-- First join: the city streams in around players (it isn't sent whole at join), so on a first join most of it isn't
-- here and the intro filmed low-detail stand-in blocks. The server keeps every place the intro films streamed in
-- for us while it plays (ServerScriptService.IntroPreload: replication focus points); this waits for those places,
-- every mesh and texture the city uses and the actors' animations, behind a short loading card.
local introFocus = shared:WaitForChild("IntroFocus", 10)
do
	local HttpService = game:GetService("HttpService")
	local ContentProvider = game:GetService("ContentProvider")
	local t0 = os.clock()
	while city:GetAttribute("IntroSpots") == nil and os.clock() - t0 < 8 do task.wait(0.2) end
	local function decode(name)
		local ok, v = pcall(function() return HttpService:JSONDecode(city:GetAttribute(name) or "[]") end)
		return ok and v or {}
	end
	local spots, ids = decode("IntroSpots"), decode("PreloadIds")
	if introFocus then introFocus:FireServer(true) end
	-- loading card (black, the intro fades in from black after it)
	local lg = Instance.new("ScreenGui")
	lg.Name = "IntroLoading"; lg.IgnoreGuiInset = true; lg.ResetOnSpawn = false; lg.DisplayOrder = 61
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = Color3.new(0, 0, 0); bg.BorderSizePixel = 0; bg.Parent = lg
	local title = Instance.new("TextLabel"); title.BackgroundTransparency = 1; title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.47); title.Size = UDim2.fromOffset(600, 30); title.Text = "T H E   L A N T E R N   C I T Y"
	title.FontFace = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold); title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(240, 230, 222); title.Parent = bg
	local track = Instance.new("Frame"); track.AnchorPoint = Vector2.new(0.5, 0.5); track.Position = UDim2.fromScale(0.5, 0.53)
	track.Size = UDim2.fromOffset(260, 2); track.BackgroundColor3 = Color3.fromRGB(60, 22, 28); track.BorderSizePixel = 0; track.Parent = bg
	local fill = Instance.new("Frame"); fill.Size = UDim2.fromScale(0, 1); fill.BackgroundColor3 = Color3.fromRGB(255, 24, 58); fill.BorderSizePixel = 0; fill.Parent = track
	local note = Instance.new("TextLabel"); note.BackgroundTransparency = 1; note.AnchorPoint = Vector2.new(0.5, 0)
	note.Position = UDim2.new(0.5, 0, 0.53, 12); note.Size = UDim2.fromOffset(400, 18); note.Text = "LOADING"
	note.FontFace = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold); note.TextSize = 12
	note.TextColor3 = Color3.fromRGB(176, 160, 164); note.Parent = bg
	lg.Parent = player:WaitForChild("PlayerGui")
	-- meshes, textures and the actors' animations
	local assetsDone = false
	task.spawn(function()
		local list = table.clone(ids)
		local anims = config.Animations or {}
		for _, key in ipairs({"Run", "Idle1", "Jump", "Fall"}) do
			if anims[key] then local an = Instance.new("Animation"); an.AnimationId = "rbxassetid://" .. anims[key]; table.insert(list, an) end
		end
		pcall(function() ContentProvider:PreloadAsync(list) end)
		assetsDone = true
	end)
	-- every filmed place, a few at a time
	local nextSpot, spotsDone = 0, 0
	for _ = 1, 6 do
		task.spawn(function()
			while true do
				nextSpot += 1
				local s = spots[nextSpot]
				if not s then break end
				pcall(function() player:RequestStreamAroundAsync((R * CFrame.new(s[1], 0, s[2])).Position, 8) end)
				spotsDone += 1
			end
		end)
	end
	local function have()
		local n = 0
		for _, d in ipairs(city:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
		return n
	end
	-- until the places are in and the city has stopped growing (it settles once they've arrived), and the assets
	-- are downloaded; 25 s at most, so a slow connection still gets the intro
	t0 = os.clock()
	local last, steadySince = have(), os.clock()
	while os.clock() - t0 < 25 do
		local n = have()
		if n ~= last then last, steadySince = n, os.clock() end
		local steady = math.clamp((os.clock() - steadySince) / 1.5, 0, 1)
		local placesIn = #spots > 0 and spotsDone / #spots or 1
		local k = placesIn * 0.55 + (assetsDone and 0.25 or 0) + (placesIn >= 1 and steady * 0.2 or 0)
		fill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
		note.Text = "LOADING  ·  " .. math.floor(math.clamp(k, 0, 1) * 100) .. "%"
		if placesIn >= 1 and assetsDone and steady >= 1 and os.clock() - t0 > 2 then break end
		task.wait(0.25)
	end
	fill.Size = UDim2.fromScale(1, 1)
	-- (the intro's own black screen is up before this goes: no flash of the lobby in between)
	task.delay(2, function() lg:Destroy() end)
end
task.wait(0.5)

local function ease(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
local function lerpCF(a, b, t) return a:Lerp(b, ease(t)) end
local function look(from, to) return CFrame.lookAt(from, to) end

local rayIgnore = {}
local function groundAt(pos, include)
	local rp = RaycastParams.new()
	if include then rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = include
	else rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = rayIgnore end
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 200, pos.Z), Vector3.new(0, -400, 0), rp)
	return hit and hit.Position.Y
end

local SEGMENTS = {
	["0"] = {{{0.17, 0}, {0.83, 0}, {1, 0.15}, {1, 0.46}}, {{1, 0.54}, {1, 0.85}, {0.83, 1}, {0.17, 1}, {0, 0.85}, {0, 0.54}}, {{0, 0.46}, {0, 0.15}, {0.17, 0}}},
	["1"] = {{{0.22, 0.2}, {0.6, 0}}, {{0.6, 0.07}, {0.6, 0.46}}, {{0.6, 0.54}, {0.6, 1}}},
	["2"] = {{{0, 0.17}, {0.17, 0}, {0.83, 0}, {1, 0.17}, {1, 0.36}, {0.56, 0.66}}, {{0.47, 0.72}, {0, 1}, {1, 1}}},
	["3"] = {{{0, 0}, {1, 0}, {0.5, 0.38}}, {{0.42, 0.43}, {0.85, 0.43}, {1, 0.57}, {1, 0.85}, {0.85, 1}, {0, 1}}},
	["4"] = {{{0.68, 0.03}, {0, 0.68}, {1, 0.68}}, {{0.75, 0}, {0.75, 0.6}}, {{0.75, 0.76}, {0.75, 1}}},
	["5"] = {{{1, 0}, {0.07, 0}}, {{0.02, 0.06}, {0, 0.44}, {0.8, 0.42}, {1, 0.6}, {1, 0.85}, {0.85, 1}, {0, 1}}},
	["6"] = {{{0.9, 0}, {0.3, 0}, {0, 0.38}}, {{0, 0.46}, {0, 0.85}, {0.15, 1}, {0.85, 1}, {1, 0.85}, {1, 0.6}, {0.85, 0.47}, {0.07, 0.47}}},
	["7"] = {{{0, 0}, {1, 0}, {0.66, 0.56}}, {{0.61, 0.64}, {0.4, 1}}},
	["8"] = {{{0.15, 0}, {0.85, 0}, {1, 0.12}, {1, 0.36}, {0.85, 0.47}, {0.15, 0.47}, {0, 0.36}, {0, 0.12}, {0.15, 0}}, {{0.15, 0.53}, {0, 0.64}, {0, 0.88}, {0.15, 1}, {0.85, 1}, {1, 0.88}, {1, 0.64}, {0.85, 0.53}, {0.15, 0.53}}},
	["9"] = {{{0.93, 0.53}, {0.15, 0.53}, {0, 0.4}, {0, 0.15}, {0.15, 0}, {0.85, 0}, {1, 0.15}, {1, 0.62}}, {{0.97, 0.7}, {0.7, 1}, {0.1, 1}}},
}
local GLYPH = {X = 47.2, Y = 54, W = 97.6, H = 180, Stroke = 8}
local RINGS = {{8, 0.05}, {6.4, 0.085}, {5, 0.14}, {3.8, 0.23}, {2.8, 0.38}, {2, 0.62}, {1.45, 1}}
local SCREEN_BLACK = Color3.fromRGB(16, 9, 10)
local LED = Color3.fromRGB(255, 38, 48)
local LEDFont = require(ReplicatedStorage:WaitForChild("Numberfall"):WaitForChild("LEDFont"))
-- the actors wear your look, so their visors use your equipped NUMBER STYLE too
local NumberStyles = require(ReplicatedStorage.Numberfall:WaitForChild("NumberStyles"))
local function drawDigit(surface, char)
	if NumberStyles then NumberStyles.Draw(surface, char, game:GetService("Players").LocalPlayer:GetAttribute("NumberStyle"), surface.Brightness) return end
	if LEDFont then LEDFont.Draw(surface, char, LED, surface.Brightness, GLYPH) return end
	surface:ClearAllChildren()
	local lines = SEGMENTS[char]
	if not lines then return end
	local k = 1 / math.max(surface.Brightness, 1)
	local layers = {}
	for _, ring in ipairs(RINGS) do
		local c = SCREEN_BLACK:Lerp(LED, ring[2])
		table.insert(layers, {GLYPH.Stroke * ring[1], Color3.new(c.R * k, c.G * k, c.B * k)})
	end
	table.insert(layers, {GLYPH.Stroke, LED:Lerp(Color3.new(1, 1, 1), 0.6)})
	for z, layer in ipairs(layers) do
		for _, line in ipairs(lines) do
			for i = 1, #line - 1 do
				local a = Vector2.new(GLYPH.X + line[i][1] * GLYPH.W, GLYPH.Y + line[i][2] * GLYPH.H)
				local b = Vector2.new(GLYPH.X + line[i + 1][1] * GLYPH.W, GLYPH.Y + line[i + 1][2] * GLYPH.H)
				local dx, dy = b.X - a.X, b.Y - a.Y
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
				f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + layer[1], layer[1])
				f.Rotation = math.deg(math.atan2(dy, dx)); f.BackgroundColor3 = layer[2]; f.ZIndex = z
				local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.5, 0); cr.Parent = f
				f.Parent = surface
			end
		end
	end
end
-- digit panel layout of the LED visor (same numbers as ServerScriptService.VisorDisplay)
local MESH_SIZE = Vector3.new(1.50800, 0.37181, 1.54824)
local MESH_FLIP = CFrame.Angles(0, math.pi, 0)
local CELL = Vector2.new(0.12587, 0.18880)
local SLOTS = {
	{Position = Vector3.new(0.15206, -0.01246, -0.71635), Normal = Vector3.new(0.21767, 0, -0.97602)},
	{Position = Vector3.new(0.04238, -0.01246, -0.73183), Normal = Vector3.new(0.06077, 0, -0.99815)},
	{Position = Vector3.new(-0.06839, -0.01246, -0.72976), Normal = Vector3.new(-0.09804, 0, -0.99518)},
	{Position = Vector3.new(-0.17740, -0.01246, -0.71021), Normal = Vector3.new(-0.25379, 0, -0.96726)},
}
local function buildPanels(actor)
	local visor = actor:FindFirstChild("LEDVisor")
	local handle = visor and visor:FindFirstChild("Handle")
	if not handle then return nil end
	local scale = visor:GetAttribute("VisorScale")
	if typeof(scale) == "number" then scale = Vector3.one * scale end
	if typeof(scale) ~= "Vector3" then scale = handle.Size / MESH_SIZE end
	local visorCF = handle.CFrame * MESH_FLIP:Inverse()
	local fore = Instance.new("Model"); fore.Name = "NumberForehead"; fore.Parent = actor
	for i, slot in ipairs(SLOTS) do
		local pos = slot.Position * scale
		local panel = Instance.new("Part")
		panel.Name = "Digit" .. i; panel.Size = Vector3.new(CELL.X * scale.X, CELL.Y * scale.Y, 0.01)
		panel.Transparency = 1; panel.CanCollide = false; panel.CanQuery = false; panel.CanTouch = false; panel.Massless = true; panel.CastShadow = false
		panel.CFrame = visorCF * CFrame.lookAt(pos, pos + (slot.Normal / scale).Unit)
		panel.Parent = fore
		local w = Instance.new("WeldConstraint"); w.Part0 = handle; w.Part1 = panel; w.Parent = panel
		local s = Instance.new("SurfaceGui")
		s.Name = "FrontNumber"; s.Face = Enum.NormalId.Front; s.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		s.CanvasSize = Vector2.new(192, 288); s.LightInfluence = 0; s.Brightness = 2.4; s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		s.Parent = panel
	end
	return fore
end
local function paintVisor(actor, code)
	local fore = actor:FindFirstChild("NumberForehead") or buildPanels(actor)
	if not fore then return end
	for i = 1, 4 do
		local panel = fore:FindFirstChild("Digit" .. i)
		local surface = panel and panel:FindFirstChild("FrontNumber")
		if surface then
			surface.Enabled = true; surface.MaxDistance = 400
			drawDigit(surface, string.sub(code, i, i))
		end
		local mask = panel and panel:FindFirstChild("MaskNumber")
		if mask then mask.Enabled = false end
	end
end
local function darkenVisor(actor)
	local fore = actor:FindFirstChild("NumberForehead")
	if fore then for _, s in ipairs(fore:GetDescendants()) do if s:IsA("SurfaceGui") then s.Enabled = false end end end
end

local anims = config.Animations or {}
local actors = {}
-- every actor is a copy of the player's own character: the hero exactly as they're kitted out (equipped
-- clothing, colourway, hairstyle, mask, visor); the others (recolour) get a random outfit and skin tone
local function makeActor(code, recolour)
	local ch = player.Character
	if not ch then return nil end
	local was = ch.Archivable
	ch.Archivable = true
	local a = ch:Clone()
	ch.Archivable = was
	if not a then return nil end
	for _, d in ipairs(a:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") then d:Destroy()
		elseif d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
	a.Name = "IntroActor"
	local hum = a:FindFirstChildOfClass("Humanoid")
	local root = a:FindFirstChild("HumanoidRootPart")
	if not hum or not root then a:Destroy(); return nil end -- caught mid-rebuild (e.g. the head swap on spawn)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.NameDisplayDistance = 0; hum.HealthDisplayDistance = 0
	root.Anchored = true
	if recolour then
		for _, d in ipairs(a:GetChildren()) do if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then d:Destroy() end end
		local bc = a:FindFirstChildOfClass("BodyColors") if bc then bc:Destroy() end
		for _, acc in ipairs(a:GetChildren()) do
			if acc:IsA("Accessory") then
				local h = acc:FindFirstChild("Handle")
				if h and h:IsA("MeshPart") then h.TextureID = ""; h.Color = Color3.fromRGB(34, 28, 26) end
				if h then local sm = h:FindFirstChildOfClass("SpecialMesh") if sm then sm.TextureId = ""; h.Color = Color3.fromRGB(34, 28, 26) end
					local sa = h:FindFirstChildOfClass("SurfaceAppearance") if sa then sa:Destroy() end end
			end
		end
		-- other fighters: a random outfit from the shop on a random skin tone (bare hands / head stay skin)
		local ok, Outfits = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Outfits")) end)
		if ok and Outfits then
			local skins = {Color3.fromRGB(234, 192, 160), Color3.fromRGB(204, 160, 128), Color3.fromRGB(160, 112, 80), Color3.fromRGB(118, 78, 54), Color3.fromRGB(86, 56, 40)}
			local r = Random.new()
			local list = Outfits.List
			local pick = list[r:NextInteger(2, #list)] or list[1]
			pcall(Outfits.Apply, a, pick.Id, skins[r:NextInteger(1, #skins)])
		end
	end
	a.Parent = workspace
	table.insert(rayIgnore, a)
	paintVisor(a, code)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	for name, id in pairs({Run = anims.Run, Idle = anims.Idle1, Jump = anims.Jump, Fall = anims.Fall}) do
		if id then
			local an = Instance.new("Animation"); an.AnimationId = "rbxassetid://" .. id
			local ok, tr = pcall(function() return animator:LoadAnimation(an) end)
			if ok then tracks[name] = tr end
		end
	end
	local actor = {model = a, root = root, hum = hum, tracks = tracks, playing = nil}
	function actor:play(name, speed)
		if self.playing == name then return end
		for n, tr in pairs(self.tracks) do if n ~= name and tr.IsPlaying then tr:Stop(0.15) end end
		local tr = self.tracks[name]
		if tr then tr:Play(0.15); tr:AdjustSpeed(speed or 1) end
		self.playing = name
	end
	function actor:place(cf) self.root.CFrame = cf end
	table.insert(actors, actor)
	return actor
end

local gui = Instance.new("ScreenGui")
gui.Name = "IntroCinematic"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 60
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local black = Instance.new("Frame"); black.Size = UDim2.fromScale(1, 1); black.BackgroundColor3 = Color3.new(0, 0, 0); black.BorderSizePixel = 0; black.ZIndex = 20; black.Parent = gui
local finished = false
-- ===== styling: same palette and fonts as the match UI (KillBanner / VictoryScreen) =====
local RED = Color3.fromRGB(255, 24, 58)
local BONE = Color3.fromRGB(240, 230, 222)
local PINK = Color3.fromRGB(255, 150, 160)
local INK = Color3.fromRGB(5, 2, 3)
local SERIF = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold)
local LABEL = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function spaced(s) return (s:upper():gsub(".", "%0 ")):sub(1, -2) end
local function edgeFade(o, inner) -- clear at both ends
	return new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, inner or 0), NumberSequenceKeypoint.new(1, 1)})}, o)
end
-- fade groups of plain frames in / out to their authored transparencies (no CanvasGroup: it renders text soft)
local ALPHA = {TextLabel = {"TextTransparency", "TextStrokeTransparency", "BackgroundTransparency"}, TextButton = {"TextTransparency", "BackgroundTransparency"},
	Frame = {"BackgroundTransparency"}, ImageLabel = {"ImageTransparency", "BackgroundTransparency"}, UIStroke = {"Transparency"}}
local authored = {} -- (not weak-keyed: an instance's Lua handle can be collected while the instance lives on)
local function remember(root)
	for _, d in ipairs(root:GetDescendants()) do
		local props = ALPHA[d.ClassName]
		if props and not authored[d] then
			local o = {}
			for _, p in ipairs(props) do o[p] = d[p] end
			authored[d] = o
		end
	end
end
local function reveal(root, on, dur)
	for _, d in ipairs(root:GetDescendants()) do
		local o = authored[d]
		if o then
			local goal = {}
			for p, v in pairs(o) do goal[p] = on and v or 1 end
			if dur == 0 then for p, v in pairs(goal) do d[p] = v end
			else TweenService:Create(d, TweenInfo.new(dur or 0.4, Enum.EasingStyle.Quad), goal):Play() end
		end
	end
end
local scalers = {}
local function scaledBox(parent, props)
	local f = new("Frame", props, parent)
	f.BackgroundTransparency = 1
	table.insert(scalers, new("UIScale", {}, f))
	return f
end

-- soft side vignette
for _, right in ipairs({false, true}) do
	local v = new("Frame", {Name = "Vignette", BorderSizePixel = 0, BackgroundColor3 = INK, AnchorPoint = Vector2.new(right and 1 or 0, 0),
		Position = UDim2.fromScale(right and 1 or 0, 0), Size = UDim2.fromScale(0.2, 1), ZIndex = 2}, gui)
	new("UIGradient", {Rotation = right and 180 or 0, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})}, v)
end
-- dims the city behind the title card so the tagline reads
local shade = new("Frame", {Name = "Shade", BorderSizePixel = 0, BackgroundColor3 = INK, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4}, gui)
new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 0.4)})}, shade)
-- a faint flash on every cut
local cutFlash = new("Frame", {Name = "Cut", BorderSizePixel = 0, BackgroundColor3 = BONE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3}, gui)

-- letterbox bars (they open when the intro starts) with a red hairline on the inside edge
local BAR = 0.11
local bars = {}
for _, top in ipairs({true, false}) do
	local b = new("Frame", {Name = top and "TopBar" or "BottomBar", BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 10, ClipsDescendants = true,
		AnchorPoint = Vector2.new(0, top and 0 or 1), Position = UDim2.fromScale(0, top and 0 or 1), Size = UDim2.fromScale(1, 0)}, gui)
	local hair = new("Frame", {Name = "Hairline", BorderSizePixel = 0, BackgroundColor3 = RED, BackgroundTransparency = 0.25, ZIndex = 11,
		AnchorPoint = Vector2.new(0, top and 1 or 0), Position = UDim2.fromScale(0, top and 1 or 0), Size = UDim2.new(1, 0, 0, 1)}, b)
	edgeFade(hair, 0)
	bars[top and "top" or "bottom"] = b
end
-- how far through the intro we are, along the top bar's edge
local progress = new("Frame", {Name = "Progress", BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1), Size = UDim2.new(0, 0, 0, 2), ZIndex = 12}, bars.top)
-- top left: the brand
local brand = scaledBox(bars.top, {Name = "Brand", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 40, 0.5, 0), Size = UDim2.fromOffset(460, 30), ZIndex = 12})
new("Frame", {Name = "Dot", BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(8, 8), Rotation = 45, ZIndex = 12}, brand)
new("TextLabel", {BackgroundTransparency = 1, RichText = true, FontFace = LABEL, TextSize = 15, TextColor3 = BONE, TextXAlignment = Enum.TextXAlignment.Left,
	Text = spaced("marked") .. '    <font color="#8C7678">/    ' .. spaced("the lantern city") .. '</font>',
	Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), ZIndex = 12}, brand)
-- top right: chapter counter
local counterBox = scaledBox(bars.top, {Name = "Chapter", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0), Size = UDim2.fromOffset(260, 30), ZIndex = 12})
local counter = new("TextLabel", {BackgroundTransparency = 1, Text = "", RichText = true, FontFace = MONO, TextSize = 18, TextColor3 = BONE,
	TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1), ZIndex = 12}, counterBox)
-- bottom left: the caption as a lower third (chapter tag, spaced eyebrow, serif line typed on)
local lower = scaledBox(bars.bottom, {Name = "Caption", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 40, 0.5, 0), Size = UDim2.fromOffset(1000, 66), ZIndex = 12})
local accent = new("Frame", {Name = "Accent", BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(4, 58), ZIndex = 12}, lower)
local tag = new("Frame", {Name = "Tag", BorderSizePixel = 0, BackgroundColor3 = RED, Position = UDim2.fromOffset(18, 2), Size = UDim2.fromOffset(40, 20), ZIndex = 12}, lower)
new("UICorner", {CornerRadius = UDim.new(0, 3)}, tag)
local tagText = new("TextLabel", {BackgroundTransparency = 1, Text = "01", FontFace = MONO, TextSize = 14, TextColor3 = INK, Size = UDim2.fromScale(1, 1), ZIndex = 13}, tag)
local eyebrow = new("TextLabel", {BackgroundTransparency = 1, Text = "", FontFace = LABEL, TextSize = 14, TextColor3 = PINK, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(70, 2), Size = UDim2.fromOffset(600, 20), ZIndex = 12}, lower)
local captionLine = new("TextLabel", {BackgroundTransparency = 1, Text = "", RichText = true, FontFace = SERIF, TextSize = 32, TextColor3 = BONE, TextXAlignment = Enum.TextXAlignment.Left,
	TextStrokeColor3 = INK, TextStrokeTransparency = 0.6, Position = UDim2.fromOffset(18, 26), Size = UDim2.new(1, -18, 0, 38), ZIndex = 12}, lower)
-- bottom right: skip, as a key cap
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local KEY_W = touchOnly and 44 or 84
local skip = new("TextButton", {Name = "Skip", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -40, 0.5, 0), Size = UDim2.fromOffset(KEY_W + 80, 40), ZIndex = 14}, bars.bottom)
table.insert(scalers, new("UIScale", {}, skip))
local key = new("Frame", {Name = "Key", BackgroundColor3 = Color3.fromRGB(22, 12, 14), BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(KEY_W, 30), ZIndex = 14}, skip)
new("UICorner", {CornerRadius = UDim.new(0, 4)}, key)
local keyStroke = new("UIStroke", {Color = BONE, Thickness = 1, Transparency = 0.55}, key)
new("TextLabel", {BackgroundTransparency = 1, Text = touchOnly and "TAP" or "SPACE", FontFace = MONO, TextSize = 13, TextColor3 = BONE, Size = UDim2.fromScale(1, 1), ZIndex = 15}, key)
local skipLabel = new("TextLabel", {BackgroundTransparency = 1, Text = spaced("skip"), FontFace = LABEL, TextSize = 16, TextColor3 = BONE, TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(KEY_W + 12, 0), Size = UDim2.new(1, -(KEY_W + 12), 1, 0), ZIndex = 14}, skip)
local function hover(on)
	TweenService:Create(keyStroke, TweenInfo.new(0.15), {Color = on and RED or BONE, Transparency = on and 0 or 0.55}):Play()
	TweenService:Create(skipLabel, TweenInfo.new(0.15), {TextColor3 = on and RED or BONE}):Play()
end
skip.MouseEnter:Connect(function() hover(true) end)
skip.MouseLeave:Connect(function() hover(false) end)

local function fit()
	local v = gui.AbsoluteSize
	if v.X < 1 then v = camera.ViewportSize end
	local s = math.clamp(math.min(v.X / 1600, v.Y / 860), 0.55, 1.15)
	for _, sc in ipairs(scalers) do sc.Scale = s end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()
remember(bars.top); remember(bars.bottom)
reveal(lower, false, 0)
-- title card: the brand block from the main menu (logo + "SEE THEIR NUMBER. HIDE YOURS."), cloned so it is identical
local title = Instance.new("Frame") -- (a plain Frame: a CanvasGroup made the logo and tagline soft)
title.Name = "Brand"; title.BackgroundTransparency = 1; title.AnchorPoint = Vector2.new(0.5, 0.5); title.Position = UDim2.fromScale(0.5, 0.4)
title.Size = UDim2.fromScale(0.62, 0.5); title.ZIndex = 12; title.Parent = gui
local logoScale = Instance.new("UIScale"); logoScale.Parent = title
do
	local menu = player.PlayerGui:WaitForChild("MARKED_UI_EDITABLE", 20)
	local credits = menu and menu:FindFirstChild("Credits")
	local srcLogo = credits and credits:FindFirstChild("BrandLogo")
	local srcTag = credits and credits:FindFirstChild("BrandTagline")
	local l = srcLogo and srcLogo:Clone() or Instance.new("ImageLabel")
	l.Name = "Logo"; l.Visible = true; l.BackgroundTransparency = 1; l.Image = srcLogo and srcLogo.Image or "rbxassetid://72644667381599"
	l.ScaleType = Enum.ScaleType.Fit; l.AnchorPoint = Vector2.new(0.5, 0); l.Position = UDim2.fromScale(0.5, 0)
	l.Size = UDim2.fromScale(1, 0.78); l.Parent = title
	for _, c in ipairs(l:GetChildren()) do if c:IsA("UIAspectRatioConstraint") or c:IsA("UISizeConstraint") then c:Destroy() end end
	local t = srcTag and srcTag:Clone() or Instance.new("TextLabel")
	t.Name = "Tagline"; t.Visible = true; t.BackgroundTransparency = 1
	if not srcTag then t.RichText = true; t.FontFace = Font.new("rbxasset://fonts/families/Guru.json"); t.TextColor3 = Color3.fromRGB(239, 233, 230)
		t.Text = 'SEE THEIR NUMBER. <font color="#ff174a">HIDE YOURS.</font>' end
	t.TextXAlignment = Enum.TextXAlignment.Center; t.TextScaled = true
	t.AnchorPoint = Vector2.new(0.5, 0); t.Position = UDim2.fromScale(0.5, 0.82); t.Size = UDim2.fromScale(0.78, 0.11); t.Parent = title
	for _, c in ipairs(t:GetChildren()) do if c:IsA("UITextSizeConstraint") then c:Destroy() end end
	for _, d in ipairs(title:GetDescendants()) do if d:IsA("LuaSourceContainer") then d:Destroy() end end
	logoScale.Scale = 0.96
	-- a red rule under the tagline that draws out with the title
	local rule = new("Frame", {Name = "Rule", BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.955), Size = UDim2.new(0, 0, 0, 2), ZIndex = 12}, title)
	edgeFade(rule, 0)
end
local logoBase = logoScale.Scale
remember(title); reveal(title, false, 0)

-- captions: [word] is drawn in red; each line is a chapter in the counter
local captionSerial, chapterN, CHAPTERS = 0, 0, 8
local function say(text, name)
	captionSerial += 1; chapterN += 1
	local my, n = captionSerial, chapterN
	counter.Text = string.format('%02d  <font color="#8C7678">/ %02d</font>', n, CHAPTERS)
	reveal(lower, false, 0.18)
	task.delay(0.22, function()
		if my ~= captionSerial or finished then return end
		tagText.Text = string.format("%02d", n)
		eyebrow.Text = spaced(name or "")
		local rich = text:gsub("%[(.-)%]", '<font color="#FF183A">%1</font>')
		local plain = text:gsub("[%[%]]", "")
		captionLine.Text = rich
		captionLine.MaxVisibleGraphemes = 0
		accent.Size = UDim2.fromOffset(4, 0)
		lower.Position = UDim2.new(0, 16, 0.5, 0)
		reveal(lower, true, 0.3)
		TweenService:Create(lower, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 40, 0.5, 0)}):Play()
		TweenService:Create(accent, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {Size = UDim2.fromOffset(4, 58)}):Play()
		local count = utf8.len(plain) or #plain
		task.spawn(function() -- typed on
			task.wait(0.12)
			for i = 1, count do
				if my ~= captionSerial or finished then return end
				captionLine.MaxVisibleGraphemes = i
				task.wait(0.024)
			end
			if my == captionSerial then captionLine.MaxVisibleGraphemes = -1 end
		end)
	end)
end
local function hideCaption(dur) captionSerial += 1; reveal(lower, false, dur or 0.3) end
local function fade(toBlack, dur)
	TweenService:Create(black, TweenInfo.new(dur or 0.8), {BackgroundTransparency = toBlack and 0 or 1}):Play()
end
local function sound(id, vol, speed)
	if not id then return end
	local s = Instance.new("Sound"); s.SoundId = "rbxassetid://" .. tostring(id); s.Volume = vol or 0.5; s.PlaybackSpeed = speed or 1
	s.Parent = gui; s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	return s
end
local SND = config.Sounds or {}
local function layerId(key) local s = SND[key]; return s and s.Layers and s.Layers[1] and s.Layers[1].Id end
-- a whole cue from the game's sound config, layer for layer, as SoundController plays it in a match
-- ("Round" = the cathedral bell tolling three times when a match starts). Played from SoundService so the last
-- toll can ring out after the intro closes.
local function cue(key)
	local def = SND[key]
	if not def or not def.Layers then return end
	for _, layer in ipairs(def.Layers) do
		task.delay(layer.Delay or 0, function()
			local s = Instance.new("Sound")
			s.Name = "IntroBell"; s.SoundId = layer.Id and ("rbxassetid://" .. tostring(layer.Id)) or ("rbxasset://sounds/" .. tostring(layer.File))
			s.Volume = layer.FadeIn and 0 or (layer.Volume or 0.5)
			s.PlaybackSpeed = layer.Speed or 1
			if layer.Reverb then
				local r = Instance.new("ReverbSoundEffect")
				r.DecayTime, r.Density, r.Diffusion, r.DryLevel, r.WetLevel = 2.4, 1, 1, -4, layer.Reverb
				r.Parent = s
			end
			if layer.Bass or layer.Treble then
				local eq = Instance.new("EqualizerSoundEffect")
				eq.LowGain, eq.HighGain = layer.Bass or 0, layer.Treble or 0
				eq.Parent = s
			end
			s.Parent = game:GetService("SoundService")
			local function start()
				if layer.Start then s.TimePosition = layer.Start end
				s:Play()
				if layer.FadeIn then TweenService:Create(s, TweenInfo.new(layer.FadeIn, Enum.EasingStyle.Sine), {Volume = layer.Volume or 0.5}):Play() end
				task.delay(layer.Duration or 0.5, function()
					if s.Parent then TweenService:Create(s, TweenInfo.new(layer.FadeOut or 0.07), {Volume = 0}):Play() end
				end)
			end
			if s.IsLoaded then start() else s.Loaded:Once(start) end
			game:GetService("Debris"):AddItem(s, (layer.Duration or 0.5) + (layer.FadeOut or 0.07) + 2)
		end)
	end
end

local hidden = {}
local function hideUI()
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then g.Enabled = false; table.insert(hidden, g) end
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
end
local function restoreUI()
	for _, g in ipairs(hidden) do if g.Parent then g.Enabled = true end end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
end

local camCF = camera.CFrame
local prevType = camera.CameraType
local prevFov = camera.FieldOfView
local camFov = 70

local fxOverlay
local plain = RaycastParams.new()
plain.FilterType = Enum.RaycastFilterType.Include
plain.FilterDescendantsInstances = {city}
local function localY(x, z)
	local hit = workspace:Raycast(W(x, 250, z), Vector3.new(0, -400, 0), plain)
	return hit and R:PointToObjectSpace(hit.Position).Y or 0
end

-- bodies: lying on the back with the limbs thrown out (no physics, so it always reads the same)
local SPRAWL = {
	LeftShoulder = CFrame.Angles(0.25, 0, -1.25), RightShoulder = CFrame.Angles(-0.15, 0, 1.0),
	LeftElbow = CFrame.Angles(0.5, 0, 0), RightElbow = CFrame.Angles(0.95, 0, 0),
	LeftHip = CFrame.Angles(0, 0, -0.22), RightHip = CFrame.Angles(0.2, 0, 0.3),
	RightKnee = CFrame.Angles(-0.45, 0, 0), Neck = CFrame.Angles(0, 0.7, 0.1),
}
local function sprawl(actor, w)
	if not actor.joints then
		actor.joints = {}
		for _, d in ipairs(actor.model:GetDescendants()) do
			if (d:IsA("AnimationConstraint") or d:IsA("Motor6D")) and SPRAWL[d.Name] then actor.joints[d.Name] = d end
		end
	end
	for name, j in pairs(actor.joints) do if j.Parent then j.Transform = CFrame.identity:Lerp(SPRAWL[name], w) end end
end
local function stopAnims(actor)
	for _, tr in pairs(actor.tracks) do tr:Stop(0) end
	actor.playing = "none"
end
local function lyingCF(groundPos, headDir)
	local d = Vector3.new(headDir.X, 0, headDir.Z).Unit
	local z = -Vector3.yAxis
	return CFrame.fromMatrix(groundPos + Vector3.new(0, 0.62, 0), d:Cross(z), d, z)
end
-- falling backwards from a standing pose, pivoting at the heels
local function fallCF(standCF, groundY, theta)
	local pivot = Vector3.new(standCF.X, groundY + 0.62, standCF.Z)
	local rel = CFrame.new(pivot):Inverse() * standCF
	return CFrame.new(pivot) * CFrame.fromAxisAngle(standCF.RightVector, theta) * rel
end
local function corpse(actor)
	paintVisor(actor.model, "X__X") -- the dead face, like a real corpse in a round
	CollectionService:AddTag(actor.model, "Corpse") -- the city's crows gather and land on it (Ambience)
end
local function caw(vol)
	local ids = {130700387062990, 75610222559518} -- (5829815715 is left out: low quality)
	sound(ids[math.random(1, #ids)], vol or 0.35, 0.95 + math.random() * 0.1)
end

-- the city's own elimination effects (shockwave, light pillar, shards, embers, the number breaking apart, the body burning)
local fx
local function eliminationFX(actor, code)
	local ok, Effects = pcall(require, player.PlayerScripts:FindFirstChild("EliminationEffects"))
	if not ok or not Effects then return end
	local soundStub = {PlayAt = function() sound(layerId("WorldKill"), 0.6) end, Play = function(_, key) sound(layerId(key), 0.6) end}
	local ok2, made = pcall(Effects.new, player, (config.Feel and config) or {Feel = {EffectRange = 180, MaxBursts = 8}}, nil, soundStub, nil, {})
	if not ok2 then return end
	fx = made
	fxOverlay = fx.overlay
	if fx.overlay then fx.overlay.DisplayOrder = 61 end
	fx.BurnBody = function()
		local model = actor.model
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor = Color3.fromRGB(255, 34, 58), Color3.fromRGB(255, 200, 190)
		h.FillTransparency, h.OutlineTransparency = 0.15, 0
		h.DepthMode = Enum.HighlightDepthMode.Occluded; h.Parent = model
		TweenService:Create(h, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FillTransparency = 1, OutlineTransparency = 1}):Play()
		local n = 0
		for _, limb in ipairs(model:GetChildren()) do
			if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" and n < 8 then
				n += 1
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 34, 58))
				e.LightEmission = 1; e.LightInfluence = 0
				e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
				e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
				e.Lifetime = NumberRange.new(0.5, 1.1); e.Rate = 30; e.Speed = NumberRange.new(1, 3); e.Acceleration = Vector3.new(0, 7, 0)
				e.SpreadAngle = Vector2.new(180, 180); e.Parent = limb
				task.delay(1.6, function() if e.Parent then e.Enabled = false end end)
			end
		end
	end
	local torso = actor.model:FindFirstChild("UpperTorso") or actor.root
	local info = {Position = torso.Position, Code = code, KillerId = -1, VictimId = -2, Victim = "", Killer = ""}
	pcall(function() fx:WorldBurst(info) end)
	pcall(function() fx:Pulse(1) end)
	pcall(function() fx:Callout("MARKED", "#" .. code) end)
	sound(layerId("Kill"), 0.55)
end

-- rooftop run: along the ridge of a terraced row in the east quarter, a leap over an alley, a drop to a lower roof
-- and a vault back up. Heights come from the roofs themselves.
local ROOF_Z, ROOF_X0, ROOF_X1 = -261, 68, 182
local RIGHT = R:VectorToWorldSpace(Vector3.xAxis)
local ridge, gapA, gapB = {}, nil, nil
-- the chimneys around the run (on the ridge and the roofs either side): hidden while he runs, so they don't block
-- the camera and he doesn't have to hop over them (shot 4); ridgeStacks = the ones on the run line itself
local runChimneys, ridgeStacks = {}, {}
for _, d in ipairs(city:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "Chimney" then
		local l = R:PointToObjectSpace(d.Position)
		if l.X > ROOF_X0 - 14 and l.X < ROOF_X1 + 14 and math.abs(l.Z - ROOF_Z) < 30 then
			table.insert(runChimneys, d)
			-- its pots (separate small parts on top of the stack) go with it
			for _, pot in ipairs(d.Parent:GetChildren()) do
				if pot ~= d and pot:IsA("BasePart") and pot.Size.Magnitude < d.Size.Magnitude then
					local q = d.CFrame:PointToObjectSpace(pot.Position)
					local h = d.Size / 2
					if math.abs(q.X) < h.X + 0.6 and math.abs(q.Z) < h.Z + 0.6 and q.Y > 0 and q.Y < h.Y + 3 then table.insert(runChimneys, pot) end
				end
			end
		end
	end
end
local function showRunChimneys(on)
	for _, c in ipairs(runChimneys) do if c.Parent then c.LocalTransparencyModifier = on and 0 or 1 end end
end
do
	-- chimney stacks standing on the run line: local x span and top
	local stacks = {}
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Chimney" then
			local l = R:PointToObjectSpace(d.Position)
			if l.X > ROOF_X0 - 6 and l.X < ROOF_X1 + 6 and math.abs(l.Z - ROOF_Z) < 5 then
				local cf, h = R:ToObjectSpace(d.CFrame), d.Size / 2
				local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
				for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
					local p = cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz); mn = mn:Min(p); mx = mx:Max(p)
				end end end
				if mn.Z < ROOF_Z + 1.3 and mx.Z > ROOF_Z - 1.3 then table.insert(stacks, {x0 = mn.X, x1 = mx.X, top = mx.Y}) end
			end
		end
	end
	-- the roofs themselves (rays pass through chimneys), across the body's width
	local function roofY(x)
		local best = 0
		for _, dz in ipairs({-0.8, 0, 0.8}) do
			local from, v = W(x, 250, ROOF_Z + dz), 0
			for _ = 1, 4 do
				local hit = workspace:Raycast(from, Vector3.new(0, -400, 0), plain)
				if not hit then break end
				if hit.Instance.Name ~= "Chimney" then v = R:PointToObjectSpace(hit.Position).Y; break end
				from = hit.Position - Vector3.new(0, 0.05, 0)
			end
			best = math.max(best, v)
		end
		return best
	end
	local raw = {}
	for x = ROOF_X0, ROOF_X1 do raw[#raw + 1] = roofY(x) end
	local med = {}
	for i = 1, #raw do -- median of 5 steps over vents and pots
		local w = {}
		for k = math.max(1, i - 2), math.min(#raw, i + 2) do w[#w + 1] = raw[k] end
		table.sort(w); med[i] = w[math.ceil(#w / 2)]
	end
	-- the alley: a long leap across it
	local y, air = {}, {}
	local i = 1
	while i <= #med do
		if med[i] >= 15 then y[i] = med[i]; i += 1
		else
			local s = i
			while i <= #med and med[i] < 15 do i += 1 end
			local a, b = math.max(1, s - 3), math.min(#med, i + 2)
			local ya = med[a] >= 15 and med[a] or (med[b] or 25)
			local yb = med[b] and med[b] >= 15 and med[b] or ya
			local hgt = 4 + math.abs(yb - ya) * 0.5
			for k = a, b do
				local u = (k - a) / math.max(1, b - a)
				y[k] = ya + (yb - ya) * u + 4 * hgt * u * (1 - u); air[k] = true
			end
			if not gapA then gapA, gapB = ROOF_X0 + a - 1, ROOF_X0 + b - 1 end
			i = b + 1
		end
	end
	-- what his feet must clear at each step: the roof (the chimneys on the line are hidden while he runs)
	local need = {}
	for k = 1, #med do need[k] = y[k] or med[k] end
	ridgeStacks = stacks
	-- short dips between houses are bridged (he hops across instead of dropping into the gap and straight back
	-- out, which jolted): a closing over 5 steps either side fills any notch narrower than ~10 studs
	do
		local W5, up, closed = 5, {}, {}
		for k = 1, #need do
			local v = -math.huge
			for j = math.max(1, k - W5), math.min(#need, k + W5) do v = math.max(v, need[j]) end
			up[k] = v
		end
		for k = 1, #need do
			local v = math.huge
			for j = math.max(1, k - W5), math.min(#need, k + W5) do v = math.min(v, up[j]) end
			closed[k] = math.max(need[k], v)
		end
		need = closed
	end
	-- a parabolic envelope over all of it: he springs up before a higher roof and arcs down after it, so he hops
	-- up steps instead of running through them
	local C = 0.3
	for k = 1, #med do
		local v = need[k]
		for j = math.max(1, k - 9), math.min(#med, k + 9) do v = math.max(v, need[j] - C * (j - k) ^ 2) end
		ridge[k] = {y = v, air = air[k] or v > med[k] + 0.7}
	end
	gapA, gapB = gapA or 114, gapB or 120
	-- in the air: steady over a few steps either side, so the run / jump animation doesn't flicker on small bumps
	for k = 1, #ridge do
		local a = false
		for j = math.max(1, k - 3), math.min(#ridge, k + 3) do if ridge[j].air then a = true end end
		ridge[k].airS = a
	end
end
-- distance along the run against time: a sprint that drops into slow motion over the alley
local runTimes = {}
do
	local s, v, t = 0, 0, 0
	local len = ROOF_X1 - ROOF_X0
	while s < len and t < 20 do
		local x = ROOF_X1 - s -- (he runs west along the ridge, toward the middle of town)
		local slow = (x > gapA - 2 and x < gapB + 3) and 0.32 or 1
		v = math.min(23, v + 46 / 60)
		s = math.min(len, s + v * slow / 60); t += 1 / 60
		runTimes[#runTimes + 1] = s
	end
end
local RUN_TIME = #runTimes / 60
local function runAt(tau)
	-- (blended between the 60 Hz samples: stepping from one to the next made him judder at higher frame rates)
	local fi = math.clamp(tau * 60 + 1, 1, #runTimes)
	local i0 = math.floor(fi)
	local s0, s1 = runTimes[i0] or 0, runTimes[math.min(i0 + 1, #runTimes)] or 0
	local s = s0 + (s1 - s0) * (fi - i0)
	local x = ROOF_X1 - s
	local f = 1 + (x - ROOF_X0)
	local i = math.clamp(math.floor(f), 1, #ridge - 1)
	local u = math.clamp(f - i, 0, 1)
	local y = ridge[i].y + (ridge[i + 1].y - ridge[i].y) * u
	local pos = W(x, y + 3, ROOF_Z)
	return CFrame.lookAt(pos, pos - RIGHT), ridge[math.clamp(math.floor(f + 0.5), 1, #ridge)].airS, x
end

local shots = {}
local A, B, H
-- the ending looks west from the rooftops at the town centre (north) and the cathedral (south) together: aimed
-- between them, from high up behind the ridge
local TOWN_VIEW = W(4, 32, -236)
local TOWN_WIDE_EYE = W(146, 86, -258)
local cath = city:FindFirstChild("Cathedral")
local cathTop = cath and select(1, cath:GetBoundingBox()).Position or W(0, 60, -350)

-- ===== camera helpers =====
-- keep the lens in front of any wall between it and the subject
local function clear(eye, target)
	local d = eye - target
	if d.Magnitude < 0.05 then return eye end
	local from = target
	for _ = 1, 4 do
		local hit = workspace:Raycast(from, eye - from, plain)
		if not hit then return eye end
		-- (anything hidden for the shot, like the run's chimneys, doesn't count)
		if hit.Instance.LocalTransparencyModifier < 1 then return hit.Position - d.Unit * 0.6 end
		from = hit.Position + d.Unit * 0.05
		if (eye - from):Dot(d) <= 0 then return eye end
	end
	return eye
end
-- the lens's offset from a moving subject, eased: tracking stays tight, but when a wall pushes the lens in it glides
-- instead of jumping (reset on each new camera set-up)
local easedEye = {}
local function smoothEye(setup, subject, eye)
	local now, off = os.clock(), eye - subject
	if easedEye.setup ~= setup or not easedEye.off then
		easedEye.setup, easedEye.off, easedEye.at = setup, off, now
		return eye
	end
	local dt = math.clamp(now - easedEye.at, 0, 0.1)
	easedEye.at = now
	easedEye.off = easedEye.off:Lerp(off, 1 - math.exp(-dt * 6))
	return subject + easedEye.off
end
-- a little handheld drift
local function sway(cf, amt)
	local c = os.clock()
	return cf * CFrame.Angles(math.sin(c * 1.3) * amt, math.sin(c * 0.9 + 1) * amt * 1.4, math.sin(c * 0.7 + 2) * amt * 0.5)
end
-- offset in the city's own axes (x east, z south)
local function offL(p, x, y, z) return p + R:VectorToWorldSpace(Vector3.new(x, 0, z)) + Vector3.new(0, y, 0) end
-- log-space zoom so a long lens move feels even
local function zoom(a, b, k) return math.exp(math.log(a) + (math.log(b) - math.log(a)) * k) end

-- the read: red corner brackets that lock onto a head, with their number under it
local reticle = new("Frame", {Name = "Reticle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(100, 100), Visible = false, ZIndex = 6}, gui)
local reticleLines = {}
for _, c in ipairs({{0, 0}, {1, 0}, {0, 1}, {1, 1}}) do
	local corner = new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(20, 20), ZIndex = 6}, reticle)
	table.insert(reticleLines, new("Frame", {BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.new(1, 0, 0, 2), ZIndex = 6}, corner))
	table.insert(reticleLines, new("Frame", {BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.new(0, 2, 1, 0), ZIndex = 6}, corner))
end
local reticleText = new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.fromOffset(260, 24),
	FontFace = MONO, TextSize = 20, TextColor3 = RED, TextStrokeColor3 = INK, TextStrokeTransparency = 0.35, Text = "", ZIndex = 6}, reticle)
local function lockOn(actor, alpha, text)
	if not actor or not actor.model.Parent or (alpha or 0) <= 0 then reticle.Visible = false return end
	local head = (actor.model:FindFirstChild("Head") or actor.root).Position
	local c, onScreen = camera:WorldToViewportPoint(head)
	if not onScreen then reticle.Visible = false return end
	local top = camera:WorldToViewportPoint(head + camera.CFrame.UpVector * 1.25)
	local size = math.clamp(math.abs(c.Y - top.Y) * 1.6, 48, 380) * (1 + (1 - alpha) * 0.9) -- closes in as it locks
	reticle.Visible = true
	reticle.Position = UDim2.fromOffset(c.X, c.Y)
	reticle.Size = UDim2.fromOffset(size, size)
	for _, l in ipairs(reticleLines) do l.BackgroundTransparency = 1 - alpha end
	reticleText.TextTransparency = 1 - alpha
	reticleText.TextStrokeTransparency = 1 - alpha * 0.65
	reticleText.Text = text or ""
end

-- 1. the hook: a body on the cathedral square under the angel, X__X on his visor, crows coming down on it
local BODY = Vector3.new(22, 0, -281)
local HOOK_WIDE_EYE, HOOK_WIDE_AT = W(30.5, 1.6, -265), W(17, 7.5, -287)
-- he lies with his head toward the cathedral, so the shot can crane straight up off his visor and pull back
local HOOK_HEAD_DIR = R:VectorToWorldSpace(Vector3.new(-13.5, 0, -22)).Unit
table.insert(shots, {dur = 7, start = function()
	H = makeActor("7310", true)
	if H then
		stopAnims(H)
		local p = W(BODY.X, 0, BODY.Z)
		local g = groundAt(p) or p.Y
		H:place(lyingCF(Vector3.new(p.X, g, p.Z), HOOK_HEAD_DIR))
		sprawl(H, 1)
		corpse(H)
		-- a low warm pool of lamplight so the body reads in the dusk
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 150, 105); glow.Range = 12; glow.Brightness = 0.8; glow.Shadows = true
		glow.Parent = H.root
	end
	sound(layerId("Round"), 0.16, 0.8)
	task.delay(0.6, function() if not finished then caw(0.4) end end)
	task.delay(3.4, function() if not finished then caw(0.3) end end)
	say("He let someone see his [number].", "the rule")
end, update = function()
	if H then sprawl(H, 1) end
end, cam = function(t)
	local wide = look(HOOK_WIDE_EYE, HOOK_WIDE_AT)
	if not H then return wide, 55 end
	local head = (H.model:FindFirstChild("Head") or H.root).Position
	-- straight down on the dead visor (X__X), sinking slowly; then a long low pull back across the cobbles
	-- as the angel and the cathedral portal rise up behind him
	local d = HOOK_HEAD_DIR
	local k = ease((t - 0.36) / 0.64)
	local eye = (head - d * 0.5 + Vector3.new(0, 3.9 - 0.6 * math.min(t / 0.36, 1), 0)):Lerp(HOOK_WIDE_EYE, k)
	local at = head:Lerp(HOOK_WIDE_AT, k)
	local up = d:Lerp(Vector3.yAxis, k)
	return sway(CFrame.lookAt(eye, at, up.Unit), 0.003), 32 + 23 * k
end})

-- 2. welcome
table.insert(shots, {dur = 5, start = function()
	if H and H.model then H.model:Destroy(); H = nil end
	say("Welcome to the [Lantern City].", "the city")
end, cam = function(t)
	local a = look(W(-150, 95, -170), cathTop)
	local b = look(W(-80, 80, -215), cathTop + Vector3.new(0, -10, 0))
	return lerpCF(a, b, t), 70
end})

-- 3. the visor: close on the glowing number, easing out to a portrait against the lit houses and clock tower
local VISOR_SPOT = Vector3.new(4, 0, -258)
table.insert(shots, {dur = 5.5, start = function()
	A = makeActor("4817")
	if A then
		local p = W(VISOR_SPOT.X, 0, VISOR_SPOT.Z)
		p = Vector3.new(p.X, (groundAt(p) or p.Y) + 3, p.Z)
		local face = W(VISOR_SPOT.X, 0, VISOR_SPOT.Z - 12)
		A:place(CFrame.lookAt(p, Vector3.new(face.X, p.Y, face.Z))); A:play("Idle")
	end
	say("Everyone wears a visor with a [secret number].", "the visor")
end, cam = function(t)
	if not A then return look(W(0, 20, -240), W(VISOR_SPOT.X, 3, VISOR_SPOT.Z)), 50 end
	local head = A.root.Position + Vector3.new(0, 1.55, 0)
	local L, Rt = A.root.CFrame.LookVector, A.root.CFrame.RightVector
	local e = ease(t)
	local dir = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-20 + 34 * e)) * L
	local eye = head + dir * (1.7 + 2.6 * e) + Vector3.new(0, -0.1 - 0.15 * e, 0)
	return sway(look(eye, head - Rt * (0.75 * e)), 0.003), 30 + 14 * e
end})

-- 4. rooftops: profile against the skyline, the leap from the alley floor, then running at us
table.insert(shots, {dur = RUN_TIME + 1.2, start = function()
	-- (comes after the mark: clear the quay before the run)
	if B and B.model then B.model:Destroy(); B = nil end
	if fx and fx.overlay then fx.overlay:Destroy() end
	lockOn(nil)
	if A then A:play("Run", 1.4) end
	showRunChimneys(false)
	say("Run, climb and [leap] across the rooftops.", "the rooftops")
end, update = function(t)
	if not A then return end
	local tau = t * (RUN_TIME + 1.2)
	local cf, air = runAt(tau)
	A:place(cf)
	if tau >= RUN_TIME then A:play("Idle") else A:play(air and "Jump" or "Run", air and 1 or 1.4) end
end, cam = function(t)
	if not A then return camera.CFrame end
	local tau = t * (RUN_TIME + 1.2)
	local cf, _, x = runAt(tau)
	local p = cf.Position
	if x > gapB + 6 then
		-- side on and level with him: his profile running across the sunset skyline
		return look(smoothEye("profile", p, clear(offL(p, 2, 2.2, 12), p)), p - RIGHT * 4 + Vector3.new(0, 0.2, 0)), 50
	elseif x > gapA - 5 then
		-- from the alley floor, looking up as he flies over against the sky
		return look(W((gapA + gapB) / 2, 5, ROOF_Z + 13), p), 62
	end
	-- three-quarter front, from up over the street: running at us along the ridge (it was down among the roofs)
	local chest = p + Vector3.new(0, 1, 0)
	return look(smoothEye("front", chest, clear(offL(p, -8, 3.5, 10), chest)), chest + RIGHT * 1.2), 46
end})

-- 5. the read: from the bridge, over his shoulder down the canal; the lens closes in on a visor on the quay
local BRIDGE, QUAY = Vector3.new(2, 0, -222), Vector3.new(46, 0, -245)
table.insert(shots, {dur = 5, start = function()
	B = makeActor("2093", true)
	local pa = W(BRIDGE.X, localY(BRIDGE.X, BRIDGE.Z) + 3, BRIDGE.Z)
	local pb = W(QUAY.X, 0, QUAY.Z)
	pb = Vector3.new(pb.X, (groundAt(pb) or pb.Y) + 3, pb.Z)
	if A then A:place(CFrame.lookAt(pa, Vector3.new(pb.X, pa.Y, pb.Z))); A:play("Idle") end
	if B then B:place(CFrame.lookAt(pb, Vector3.new(pa.X, pb.Y, pa.Z))); B:play("Idle") end
	say("Spot another player and [read] their number.", "the read")
end, cam = function(t)
	if not (A and B) then return camera.CFrame end
	local head = B.root.Position + Vector3.new(0, 1.55, 0)
	local m = ease(t / 0.4)
	local eye = (A.root.CFrame * CFrame.new(2.4 - 0.4 * m, 2.2, 5 - 1.2 * m)).Position
	local z = ease((t - 0.36) / 0.4)
	local at = (B.root.Position + Vector3.new(0, 1, 0)):Lerp(head, z)
	return sway(look(eye, at), 0.0015 + 0.002 * z), zoom(50, 7, z)
end, after = function(t)
	lockOn(B, math.clamp((t - 0.62) / 0.15, 0, 1), t > 0.82 and "#2093" or "READING")
end})

-- 6. the notebook: still down the lens on their visor while the number is written
local entry
table.insert(shots, {dur = 5, noCut = true, start = function()
	say("Write it in your notebook to [mark] them.", "the notebook")
	local src = player.PlayerGui:FindFirstChild("MARKED_UI_EDITABLE")
	src = src and src:FindFirstChild("Entry")
	if src then
		entry = src:Clone()
		entry.Visible = true; entry.AnchorPoint = Vector2.new(0.5, 0.5); entry.Position = UDim2.fromScale(0.27, 0.5)
		for _, d in ipairs(entry:GetDescendants()) do if d:IsA("LuaSourceContainer") then d:Destroy() end end
		for _, n in ipairs({"SuccessMark", "ErrorMark", "ErrorGlitch"}) do local x = entry:FindFirstChild(n) if x then x.Visible = false end end
		for i = 0, 3 do local d = entry:FindFirstChild("Digit" .. i); local v = d and d:FindFirstChild("Value"); if v then v.Text = "_" end end
		local fb = entry:FindFirstChild("Feedback") if fb then fb.Text = "" end
		entry.Parent = gui
		local scale = entry:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", entry)
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Scale = math.min(0.85, camera.ViewportSize.Y / 820)}):Play()
		local code = "2093"
		task.spawn(function()
			task.wait(0.7)
			for i = 0, 3 do
				if finished then return end
				local d = entry and entry:FindFirstChild("Digit" .. i); local v = d and d:FindFirstChild("Value")
				if v then v.Text = string.sub(code, i + 1, i + 1) end
				sound(layerId("Digit"), 0.5, 1)
				task.wait(0.55)
			end
			sound(layerId("Submit"), 0.6, 1)
			local ok = entry and entry:FindFirstChild("SuccessMark") if ok then ok.Visible = true end
		end)
	end
end, cam = function(t)
	if not (A and B) then return camera.CFrame end
	local head = B.root.Position + Vector3.new(0, 1.55, 0)
	local eye = (A.root.CFrame * CFrame.new(2.0, 2.2, 3.8)).Position
	-- slide them over to the right third so the notebook has the left of the frame
	local shift = A.root.CFrame.RightVector * (-1.6 * ease(t / 0.3))
	return sway(look(eye, head + shift), 0.0035), 7 - 1.2 * ease(t)
end, after = function(t)
	lockOn(B, 1, t > 0.75 and "#2093  MARKED" or "#2093")
end})

-- 7. marked: the visor dies, the real elimination effects, he falls; the camera swings round behind the body
-- to the bridge, where the one who wrote it is still standing (then he runs: shot 4 plays after this one)
local fallFrom, fallGround, tagged
table.insert(shots, {dur = 5.5, start = function()
	if entry then entry:Destroy(); entry = nil end
	lockOn(nil)
	say("[One less] in the city.", "the mark")
	tagged = false
	if B then
		fallFrom = B.root.CFrame
		fallGround = (groundAt(B.root.Position) or (B.root.Position.Y - 3))
		stopAnims(B)
		darkenVisor(B.model)
		eliminationFX(B, "2093")
	end
end, update = function(t)
	if not B or not fallFrom then return end
	local tau = t * 5.5
	local k = math.min(1, tau / 0.62)
	local theta = (math.pi / 2) * k * k
	if tau > 0.62 then theta = math.pi / 2 + 0.06 * math.sin((tau - 0.62) * 16) * math.exp(-(tau - 0.62) * 7) end
	B:place(fallCF(fallFrom, fallGround, theta))
	sprawl(B, math.min(1, tau / 0.75))
	if tau > 1.1 and not tagged then tagged = true; corpse(B); caw(0.35) end
end, cam = function(t)
	if not fallFrom then return camera.CFrame end
	local p = fallFrom.Position
	local fwd, right = fallFrom.LookVector, fallFrom.RightVector
	local k = ease((t - 0.2) / 0.8)
	-- orbit from in front of him, up and over the street side, down low behind his head
	local th = 0.35 + (math.pi - 0.3 - 0.35) * k
	local dir = fwd * math.cos(th) + right * math.sin(th)
	local eye = p + dir * (6.6 + 4.4 * k) + Vector3.new(0, 0.4 * k + 3.5 * math.sin(math.pi * k), 0)
	-- stay on the body, then lift to the bridge where the one who wrote it is standing
	local body = (p + Vector3.new(0, 0.5, 0)):Lerp(p - fwd * 2 + Vector3.new(0, -2.4, 0), math.min(1, k * 1.6))
	local at = body:Lerp(p + fwd * 30 + Vector3.new(0, -2, 0), ease((k - 0.45) / 0.55))
	return sway(look(clear(eye, p), at), 0.002), 50 - 6 * k
end})

-- 8. keep yours hidden: low and in front of him on the ridge, against the red sky
table.insert(shots, {dur = 6, start = function()
	if B and B.model then B.model:Destroy(); B = nil end
	if fx and fx.overlay then fx.overlay:Destroy() end
	showRunChimneys(true)
	-- back on the ridge where the run ended, looking out toward the town centre and the cathedral (clear of chimneys)
	local k = 5
	for _ = 1, 60 do
		local x, blocked = ROOF_X0 + k - 1, false
		for _, st in ipairs(ridgeStacks) do if x > st.x0 - 2 and x < st.x1 + 2 then blocked = true end end
		if not blocked then break end
		k += 1
	end
	k = math.clamp(k, 1, #ridge)
	local p = W(ROOF_X0 + k - 1, ridge[k].y + 3, ROOF_Z)
	local out = (TOWN_VIEW - p) * Vector3.new(1, 0, 1)
	out = out.Magnitude > 0.1 and out.Unit or -RIGHT
	if A then A:place(CFrame.lookAt(p, p + out)); A:play("Idle") end
	say("Keep yours [hidden]. Be the last one standing.", "the last one")
end, cam = function(t)
	if not A then return camera.CFrame end
	local P = A.root.Position
	local L, Rt = A.root.CFrame.LookVector, A.root.CFrame.RightVector
	local e = ease(t)
	local eye = P + L * (9 - 2 * e) + Rt * (1.5 + 0.9 * e) + Vector3.new(0, -1.6 + 0.4 * e, 0)
	return look(clear(eye, P + Vector3.new(0, 1.5, 0)), P + Vector3.new(0, 2.2, 0) + Rt * (2.6 - 0.3 * e)), 45 - 4 * e
end})

-- 9. title card
table.insert(shots, {dur = 8, noCut = true, start = function()
	hideCaption(0.4)
	-- the letterbox eases open for the title
	for _, b in pairs(bars) do
		reveal(b, false, 0.5)
		TweenService:Create(b, TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {Size = UDim2.fromScale(1, 0.045)}):Play()
	end
	task.delay(0.6, function()
		if finished then return end
		reveal(title, true, 1.6)
		TweenService:Create(shade, TweenInfo.new(1.6, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.35}):Play()
		local rule = title:FindFirstChild("Rule")
		if rule then TweenService:Create(rule, TweenInfo.new(1.8, Enum.EasingStyle.Quint), {Size = UDim2.new(0.34, 0, 0, 2)}):Play() end
		TweenService:Create(logoScale, TweenInfo.new(6, Enum.EasingStyle.Sine), {Scale = logoBase * 1.07}):Play()
	end)
	-- the bell tolls for the title, the same three tolls as when a match starts
	task.delay(0.6, function() if not finished then cue("Round") end end)
end, cam = function(t)
	if not A then
		return lerpCF(look(W(150, 70, -261), TOWN_VIEW), look(TOWN_WIDE_EYE, TOWN_VIEW), t), 62
	end
	-- carries on from the hero shot: swings round behind him, then cranes up and back over his shoulder to the
	-- town centre and the cathedral he's looking out at, with MARKED and the tagline in the sky above
	local P = A.root.Position
	local L, Rt = A.root.CFrame.LookVector, A.root.CFrame.RightVector
	local k1 = ease(t / 0.4)
	local th = 0.33 + (2.9 - 0.33) * k1
	local dir = L * math.cos(th) + Rt * math.sin(th)
	local close = clear(P + dir * (7.4 + 1.1 * k1) + Vector3.new(0, -1.2 + 3 * k1, 0), P + Vector3.new(0, 1.5, 0))
	local closeAt = (P + Vector3.new(0, 2.2, 0) + Rt * 2.3):Lerp(P + (TOWN_VIEW - P).Unit * 30 + Vector3.new(0, 3, 0), k1)
	local k2 = ease((t - 0.3) / 0.6)
	return look(close:Lerp(TOWN_WIDE_EYE, k2), closeAt:Lerp(TOWN_VIEW, k2)), 41 + 21 * k2
end})

-- Running order, so the hero moves through the city instead of jumping around it: the square, the city, his visor
-- in the street, then a few steps on to the bridge (read, write, the mark on the quay), then his escape over the
-- rooftops, which start just east of the quay, ending on the ridge for the last line and the title.
do
	local order = {1, 2, 3, 5, 6, 7, 4, 8, 9}
	local ordered = {}
	for i, k in ipairs(order) do ordered[i] = shots[k] end
	shots = ordered
end

local function cleanup()
	if finished then return end
	finished = true
	player:SetAttribute("IntroPlaying", nil)
	-- watched (or skipped): don't play it again on later joins
	pcall(function() shared:WaitForChild("Menu", 5):FireServer("IntroSeen") end)
	if introFocus then introFocus:FireServer(false) end
	showRunChimneys(true)
	RunService:UnbindFromRenderStep("IntroCinematic")
	for _, a in ipairs(actors) do if a.model then a.model:Destroy() end end
	if entry then entry:Destroy() end
	if fxOverlay then fxOverlay:Destroy() end
	camera.CameraType = prevType
	camera.FieldOfView = prevFov
	reticle.Visible = false
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
	restoreUI()
	-- (the title card, letterbox and captions go at once: they used to stay up over the main menu while the black
	-- faded out, until the whole intro screen was removed)
	for _, c in ipairs(gui:GetChildren()) do
		if c:IsA("GuiObject") and c ~= black then c.Visible = false end
	end
	TweenService:Create(black, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()
	task.delay(0.9, function() gui:Destroy() end)
end

local function skipNow()
	if finished then return end
	fade(true, 0.35)
	task.delay(0.4, cleanup)
end
skip.Activated:Connect(skipNow)
UserInputService.InputBegan:Connect(function(input)
	if chatTyping() then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then skipNow() end
end)

player:SetAttribute("IntroPlaying", true)
gui.Parent = player.PlayerGui
hideUI()
camera.CameraType = Enum.CameraType.Scriptable

local shotIndex, shotStart = 0, 0
local current
local clock = 0
local function nextShot()
	shotIndex += 1
	current = shots[shotIndex]
	player:SetAttribute("IntroShot", current and shotIndex or nil)
	shotStart = clock
	if current and shotIndex > 1 and not current.noCut then -- a faint flash on the cut
		cutFlash.BackgroundTransparency = 0.86
		TweenService:Create(cutFlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
	end
	if current and current.start then current.start() end
	-- keep what this shot and the next one film streamed in (an area streams back out a while after it was loaded)
	for k = shotIndex, shotIndex + 1 do
		local s = shots[k]
		if s and s.cam then
			for _, t in ipairs({0, 0.5, 1}) do
				local ok, cf = pcall(s.cam, t)
				if ok and typeof(cf) == "CFrame" then
					-- (at street level, under the camera and out along where it looks)
					for _, ahead in ipairs({0, 50, 110}) do
						local q = cf.Position + cf.LookVector * ahead
						q = Vector3.new(q.X, R.Position.Y, q.Z)
						task.spawn(function() pcall(function() player:RequestStreamAroundAsync(q, 4) end) end)
					end
				end
			end
		end
	end
end
local startsAt, TOTAL_DUR = {}, 0
for i, s in ipairs(shots) do startsAt[i] = TOTAL_DUR; TOTAL_DUR += s.dur end
RunService:BindToRenderStep("IntroCinematic", Enum.RenderPriority.Camera.Value + 10, function(dt)
	if finished then return end
	-- (studio testing: the IntroTimeScale attribute slows or pauses the cut)
	clock += dt * (player:GetAttribute("IntroTimeScale") or 1)
	if not current or clock - shotStart >= current.dur then
		nextShot()
		if not current then
			fade(true, 0.8)
			task.delay(0.9, cleanup)
			return
		end
	end
	local t = (clock - shotStart) / current.dur
	progress.Size = UDim2.new(math.clamp(((startsAt[shotIndex] or 0) + clock - shotStart) / TOTAL_DUR, 0, 1), 0, 0, 2)
	if current.update then current.update(t) end
	local ok, cf, fov = pcall(current.cam, t)
	if ok and cf then camCF = cf; camFov = fov or 70 end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camCF
	camera.FieldOfView = camFov
	if current.after then pcall(current.after, t) end -- (screen-space overlays that follow the camera)
end)
fade(false, 1.6)
for _, b in pairs(bars) do TweenService:Create(b, TweenInfo.new(1.2, Enum.EasingStyle.Quint), {Size = UDim2.fromScale(1, BAR)}):Play() end
