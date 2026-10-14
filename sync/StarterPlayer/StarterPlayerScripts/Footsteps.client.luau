-- Footsteps: one soft footfall per step of the MARKED gait (SlideAnimator calls Gait.OnStep at each heel strike),
-- picked by the floor material underfoot. Replaces Roblox's looping run sound. Crouching stays silent.
-- Every surface uses the same recording family (Half-Life 2 footsteps) so they sit together naturally.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Gait = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Gait"))

local SETS = {
	concrete = {81623756670923, 78754179999047, 79418255155423, 112240321395589},
	tile = {135712042029119, 90507702118699, 98172042741214, 106319783012941},
	wood = {87921439933530, 89597871459985, 139932856876296, 75643573822739},
	metal = {78580994772675, 79005288283137, 98060045106272, 122668036980895},
	grass = {105277634319381, 98069158661569, 135182192451997, 116425333836106},
	dirt = {80932364310315, 130611100801821, 97480467702673, 114765760744945},
}
-- measured peak loudness of each file, so every footfall lands at an even level whichever file is picked
local PEAK = {
	[81623756670923] = 85, [78754179999047] = 114, [79418255155423] = 80, [112240321395589] = 82,
	[135712042029119] = 77, [90507702118699] = 60, [98172042741214] = 56, [106319783012941] = 40,
	[87921439933530] = 118, [89597871459985] = 163, [139932856876296] = 114, [75643573822739] = 101,
	[78580994772675] = 128, [79005288283137] = 179, [98060045106272] = 138, [122668036980895] = 143,
	[105277634319381] = 50, [98069158661569] = 43, [135182192451997] = 40, [116425333836106] = 47,
	[80932364310315] = 64, [130611100801821] = 31, [97480467702673] = 97, [114765760744945] = 104,
}
local function gain(id) return math.clamp(90 / (PEAK[id] or 90), 0.5, 2.2) end

-- kept low on purpose: footsteps should sit under everything else
local VOLUME = {concrete = 0.2, tile = 0.18, wood = 0.2, metal = 0.16, grass = 0.2, dirt = 0.2, carpet = 0.12, sand = 0.17}
local MATERIAL = {
	Wood = "wood", WoodPlanks = "wood",
	Metal = "metal", DiamondPlate = "metal", CorrodedMetal = "metal", Foil = "metal",
	Grass = "grass", LeafyGrass = "grass",
	Ground = "dirt", Mud = "dirt", Pebble = "dirt", Snow = "dirt", Sand = "sand",
	Marble = "tile", Granite = "tile", Glass = "tile", Ice = "tile", Glacier = "tile", SmoothPlastic = "tile",
	Fabric = "carpet", Carpet = "carpet", Leather = "carpet", Rubber = "carpet",
}
-- surfaces without their own recordings borrow a set, muffled
local BORROW = {carpet = "concrete", sand = "dirt"}
local MUFFLE = {carpet = -16, sand = -8}
local RANGE = 70

local camera = workspace.CurrentCamera
local group
task.spawn(function()
	local audio = SoundService:WaitForChild("NumberfallAudio", 30)
	group = audio and audio:WaitForChild("NumberfallSFX", 10)
end)

-- warm the cache so the first step on each surface isn't late
task.spawn(function()
	-- the menus / HUD artwork load first (ReplicatedFirst.PriorityPreload), then the footsteps
	local lp, t0 = game:GetService("Players").LocalPlayer, os.clock()
	while not lp:GetAttribute("UIPreloaded") and os.clock() - t0 < 12 do task.wait(0.2) end
	local list = {}
	for _, ids in pairs(SETS) do
		for _, id in ipairs(ids) do table.insert(list, "rbxassetid://" .. id) end
	end
	pcall(function() ContentProvider:PreloadAsync(list) end)
end)

local voices = {} -- character -> {root, sounds, i, last}
local function voice(character, root)
	local v = voices[character]
	if v and v.root == root and root.Parent then return v end
	v = {root = root, sounds = {}, i = 0}
	for k = 1, 2 do
		local s = Instance.new("Sound")
		s.Name = "Footstep"
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 5; s.RollOffMaxDistance = 45
		s.SoundGroup = group
		local eq = Instance.new("EqualizerSoundEffect") -- takes the click off the top end
		eq.LowGain = 0; eq.MidGain = -1; eq.HighGain = -5
		eq.Parent = s
		s.Parent = root
		v.sounds[k] = s
	end
	voices[character] = v
	character.Destroying:Once(function() voices[character] = nil end)
	return v
end

-- Roblox's landing thud sets its own volume from the fall speed, so it's turned down through a quiet sub-group instead
local landingGroup = Instance.new("SoundGroup")
landingGroup.Name = "CharacterLanding"
landingGroup.Volume = 0.3
landingGroup.Parent = SoundService
task.spawn(function()
	while not group do task.wait(0.5) end
	landingGroup.Parent = group -- nested, so the SFX volume setting still applies
end)

-- Roblox's own running loop gives way to the footfalls (BaseVolume 0 keeps SilentCrouch from restoring it)
local function silence(sound)
	if not sound:IsA("Sound") then return end
	if sound.Name == "Running" then
		sound:SetAttribute("BaseVolume", 0)
		sound.Volume = 0
	elseif sound.Name == "Landing" then
		sound.SoundGroup = landingGroup
		if not sound:FindFirstChildOfClass("EqualizerSoundEffect") then
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain = -2; eq.MidGain = -2; eq.HighGain = -8
			eq.Parent = sound
		end
	end
end
local function track(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then return end
	for _, s in ipairs(root:GetChildren()) do silence(s) end
	root.ChildAdded:Connect(silence)
end
local function watch(p)
	if p.Character then task.spawn(track, p.Character) end
	p.CharacterAdded:Connect(function(c) task.spawn(track, c) end)
end
for _, p in ipairs(Players:GetPlayers()) do watch(p) end
Players.PlayerAdded:Connect(watch)

Gait.OnStep = function(character, speed)
	if character:GetAttribute("Crouching") == true then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return end
	local material = humanoid.FloorMaterial
	if material == Enum.Material.Air then return end
	if (camera.CFrame.Position - root.Position).Magnitude > RANGE then return end
	local surface = MATERIAL[material.Name] or "concrete"
	local ids = SETS[BORROW[surface] or surface]
	local v = voice(character, root)
	local pick = ids[math.random(#ids)]
	while pick == v.last do pick = ids[math.random(#ids)] end
	v.last = pick
	v.i = v.i % #v.sounds + 1
	local s = v.sounds[v.i]
	if group and s.SoundGroup ~= group then s.SoundGroup = group end
	local eq = s:FindFirstChildOfClass("EqualizerSoundEffect")
	if eq then eq.HighGain = MUFFLE[surface] or -5 end
	s.SoundId = "rbxassetid://" .. pick
	-- light at a stroll, a little firmer at a sprint
	s.Volume = VOLUME[surface] * gain(pick) * math.clamp(0.5 + speed / 48, 0.55, 1.1) * (0.86 + math.random() * 0.28)
	-- (a wider pitch spread: the same four recordings per surface repeat far less noticeably)
	s.PlaybackSpeed = 0.93 + math.random() * 0.14
	s.TimePosition = 0
	s:Play()
	-- wet ground / puddles (StarterPlayerScripts.WetGround)
	if Gait.OnWetStep then pcall(Gait.OnWetStep, character, speed, root, humanoid) end
end
