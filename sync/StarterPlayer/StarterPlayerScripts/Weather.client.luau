-- Weather you can see (all local; the shared clock is ReplicatedStorage.Numberfall.Weather):
--   * wind: workspace.GlobalWind follows the gusts (grass, and the drifting smoke / mist / dust motes), and thin
--     white wind streaks curl past the camera -- more of them, faster, the harder it blows. The wind sound
--     (Soundscape) and the leaves blown off the piles (LeafPiles) follow the same gusts.
--   * rain, during a shower: streaks falling around the camera (slanted by the wind), splashes on the ground under
--     you, the rain sound and, in a heavy shower, the odd roll of distant thunder with a
--     flicker of lightning. Under a roof the rain stops falling on you and the sound muffles.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Weather = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Weather"))

local me = Players.LocalPlayer
local random = Random.new()
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local RAIN_ID = "rbxassetid://9112856394"           -- Rain On Window 1 (Pro Sound Effects): a steady medium-heavy wash
local THUNDER = {"rbxassetid://9120018172", "rbxassetid://9120018216"} -- distant thunder rolls (Pro Sound Effects)

local function lowEnd() return me:GetAttribute("LowEnd") == true end
local function ns(...)
	local kps, a = {}, {...}
	for i = 1, #a, 2 do table.insert(kps, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(kps)
end
-- a constant value with a random spread per particle (drop thickness / length varies a little)
local function vary(v, spread) return NumberSequence.new({NumberSequenceKeypoint.new(0, v, spread), NumberSequenceKeypoint.new(1, v, spread)}) end

local folder = Instance.new("Folder")
folder.Name = "WeatherFX"
folder.Parent = workspace
local function anchor(size)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 1; p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.Parent = folder
	return p
end

-- the sound group the rest of the ambience plays through (follows the game's volume)
local group = SoundService:WaitForChild("Ambience", 20)

------------------------------------------------------------------ wind streaks
local streaks = {}
local MAX_STREAKS = 12
local function spawnStreak(cam, gust)
	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
	-- somewhere in front of you, a little above or below eye level, starting upwind of where it'll be seen
	local yaw = random:NextNumber(-0.9, 0.9)
	local dir = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(flatLook)
	local centre = cam.CFrame.Position + dir * random:NextNumber(12, 36) + Vector3.new(0, random:NextNumber(-3, 6), 0)
	local speed = 20 + 22 * gust
	local life = random:NextNumber(1.3, 1.9)
	local start = centre - Weather.Direction * speed * life * 0.5
	local side = Weather.Direction:Cross(Vector3.yAxis).Unit
	local p = anchor()
	p.CFrame = CFrame.new(start)
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.11, 0); a0.Parent = p
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.11, 0); a1.Parent = p
	local t = Instance.new("Trail")
	t.Attachment0 = a0; t.Attachment1 = a1; t.FaceCamera = true
	t.Lifetime = 0.8; t.MinLength = 0.05
	t.Color = ColorSequence.new(Color3.fromRGB(244, 248, 255))
	t.Transparency = ns(0, 0.3, 0.5, 0.5, 1, 1)
	t.WidthScale = ns(0, 0.2, 0.3, 1, 1, 0.1)
	t.LightEmission = 0.7; t.LightInfluence = 0.25
	t.Parent = p
	-- one lazy curl part way through (the classic wind-line loop), otherwise a gentle wave
	local curlAt = random:NextNumber(0.35, 0.6)
	local curlR = random:NextNumber(0.8, 1.6)
	local wave = random:NextNumber(0.3, 0.7)
	table.insert(streaks, {part = p, trail = t, start = start, side = side, speed = speed, life = life, born = os.clock(),
		curlAt = curlAt, curlR = curlR, wave = wave, seed = random:NextNumber(0, 10)})
end
local function stepStreaks()
	for i = #streaks, 1, -1 do
		local s = streaks[i]
		local age = os.clock() - s.born
		local k = age / s.life
		if k >= 1 then
			s.trail.Enabled = false
			Debris:AddItem(s.part, 0.7)
			table.remove(streaks, i)
		else
			local pos = s.start + Weather.Direction * s.speed * age
				+ Vector3.new(0, math.sin(age * 3 + s.seed) * s.wave, 0)
			-- the loop: a full circle in the wind's vertical plane, over a quarter of the streak's life
			local c = (k - s.curlAt) / 0.25
			if c > 0 and c < 1 then
				local ang = c * math.pi * 2
				pos += (Vector3.yAxis * math.sin(ang) - Weather.Direction * math.sin(ang * 0.5) ^ 2 * 1.2) * s.curlR
			end
			s.part.CFrame = CFrame.new(pos)
		end
	end
end

------------------------------------------------------------------ rain
-- (one emitter can only spawn so many drops a second, so the shower is several emitters.) The near rain only ever
-- falls BEYOND your character: one wide block that starts a few studs past them, turned with the camera. Nothing falls
-- between the camera and your model, so streaks never cross your character or fill the screen up close.
local NEAR_BOXES = {Front = 6}
local DENSITY = 3 -- drops a second per square stud of volume, at full strength
local rainBoxes = {}
for name, count in pairs(NEAR_BOXES) do
	local box = {part = anchor(Vector3.new(10, 1, 10)), emitters = {}}
	box.part.Name = "Rain" .. name
	for i = 1, count do
		local rain = Instance.new("ParticleEmitter")
		rain.Name = "Rain"; rain.Texture = SPARK; rain.Enabled = true; rain.Rate = 0
		rain.Shape = Enum.ParticleEmitterShape.Box; rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		rain.EmissionDirection = Enum.NormalId.Bottom
		rain.Orientation = Enum.ParticleOrientation.VelocityParallel
		-- (negative Squash stretches a particle along its height -- the velocity, here -- into a thin streak; the old
		-- positive value flattened every drop into a fat sideways dash)
		rain.Squash = vary(-3.4, 0)
		rain.Size = vary(0.27, 0.06)
		rain.Color = ColorSequence.new(Color3.fromRGB(196, 206, 224))
		rain.Transparency = ns(0, 0.6, 0.8, 0.66, 1, 1)
		rain.LightEmission = 0.12; rain.LightInfluence = 0.8
		rain.Lifetime = NumberRange.new(0.55, 0.75); rain.Speed = NumberRange.new(62, 74)
		rain.SpreadAngle = Vector2.new(1.5, 1.5)
		rain.Parent = box.part
		box.emitters[i] = rain
	end
	rainBoxes[name] = box
end

-- a second, wider sheet further out (longer, fainter streaks), so the rain carries on into the distance instead
-- of stopping a few studs in front of you
local RAIN_FAR = 4
local farPart = anchor(Vector3.new(110, 1, 70))
local farRains = {}
for i = 1, RAIN_FAR do
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "RainFar"; rain.Texture = SPARK; rain.Rate = 0
	rain.Shape = Enum.ParticleEmitterShape.Box; rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Squash = vary(-3.6, 0)
	rain.Size = vary(0.5, 0.08)
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 200, 220))
	rain.Transparency = ns(0, 0.66, 0.85, 0.72, 1, 1)
	rain.LightEmission = 0.1; rain.LightInfluence = 0.8
	rain.Lifetime = NumberRange.new(0.75, 0.95); rain.Speed = NumberRange.new(76, 86)
	rain.SpreadAngle = Vector2.new(1, 1)
	rain.Parent = farPart
	farRains[i] = rain
end
-- splashes on the ground around you
local splashPart = anchor(Vector3.new(46, 0.2, 46))
local splash = Instance.new("ParticleEmitter")
splash.Name = "Splash"; splash.Texture = SPARK; splash.Rate = 0
splash.Shape = Enum.ParticleEmitterShape.Box; splash.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
splash.EmissionDirection = Enum.NormalId.Top; splash.SpreadAngle = Vector2.new(40, 40)
splash.Size = ns(0, 0.22, 1, 0.02)
splash.Color = ColorSequence.new(Color3.fromRGB(220, 228, 240))
splash.Transparency = ns(0, 0.3, 1, 1)
splash.LightEmission = 0.2; splash.LightInfluence = 0.8
splash.Lifetime = NumberRange.new(0.12, 0.2); splash.Speed = NumberRange.new(3, 6)
splash.Acceleration = Vector3.new(0, -40, 0)
splash.Parent = splashPart

local rainSound = Instance.new("Sound")
rainSound.Name = "Rain"; rainSound.SoundId = RAIN_ID; rainSound.Looped = true; rainSound.Volume = 0
rainSound.SoundGroup = group
local muffle = Instance.new("EqualizerSoundEffect")
muffle.LowGain = 0; muffle.MidGain = -2; muffle.HighGain = -6; muffle.Parent = rainSound
rainSound.Parent = SoundService

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "RainGrade"; grade.Enabled = false; grade.Parent = Lighting
local flash = 0
local nextThunder = os.clock() + random:NextNumber(15, 35)
local function thunder()
	local s = Instance.new("Sound")
	s.SoundId = THUNDER[random:NextInteger(1, #THUNDER)]
	s.Volume = random:NextNumber(0.25, 0.4); s.PlaybackSpeed = random:NextNumber(0.85, 1)
	s.SoundGroup = group
	s.Parent = SoundService
	-- the flicker comes first; the rumble follows a moment later (it's far off)
	flash = 1
	task.delay(random:NextNumber(0.6, 1.8), function() s:Play(); Debris:AddItem(s, 10) end)
end

local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Exclude

------------------------------------------------------------------ per frame
local streakClock, roofClock, covered, ground = 0, 0, false, nil
local sheltered = 0
RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local gust = Weather.Gust(now)
	local wet = Weather.Rain(now)
	workspace.GlobalWind = Weather.Wind(now)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local eye = cam.CFrame.Position

	-- wind streaks: a couple a second in a breeze, several in a gust
	if me:GetAttribute("LocalReducedMotion") ~= true then
		streakClock -= dt
		if streakClock <= 0 and #streaks < (lowEnd() and 4 or MAX_STREAKS) then
			spawnStreak(cam, gust)
			streakClock = 1 / ((1.2 + 4 * gust ^ 1.2) * (lowEnd() and 0.5 or 1))
		end
	end
	stepStreaks()

	-- roof over your head? (and the ground under you, for the splashes) a few times a second
	roofClock -= dt
	if roofClock <= 0 then
		roofClock = 0.25
		local skip = {folder}
		if me.Character then table.insert(skip, me.Character) end
		roofParams.FilterDescendantsInstances = skip
		covered = workspace:Raycast(eye, Vector3.new(0, 80, 0), roofParams) ~= nil
		local hit = workspace:Raycast(eye + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), roofParams)
		ground = hit and hit.Position or nil
	end
	sheltered += ((covered and 1 or 0) - sheltered) * math.min(1, dt * 4)

	-- rain
	local falling = wet * (1 - sheltered)
	local scale = lowEnd() and 0.35 or 1
	local w = Weather.Wind(now)
	-- the near volumes sit above you (and a little upwind, so the slanted streaks land where they're aimed): a block
	-- starting just past your character, and a strip either side of the lane up to it
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
	local side = flat:Cross(Vector3.yAxis).Unit
	local reach = math.clamp((eye - cam.Focus.Position).Magnitude, 0, 30) + 5 -- camera to just past your character
	local up = Vector3.new(0, 24, 0) - w * 0.25
	local yaw = CFrame.lookAt(Vector3.zero, flat).Rotation
	local function place(box, centre, width, depth)
		box.part.Size = Vector3.new(width, 1, depth)
		box.part.CFrame = CFrame.new(centre + up) * yaw
		local total = DENSITY * width * depth * falling
		local active = math.max(1, math.ceil(#box.emitters * scale))
		for i, rain in ipairs(box.emitters) do
			rain.Acceleration = w * 1.1
			rain.Rate = i <= active and total * scale / active or 0
		end
	end
	place(rainBoxes.Front, eye + flat * (reach + 17), 56, 30)
	-- the far sheet keeps falling out there even while you're under cover
	farPart.CFrame = CFrame.new(eye + flat * (reach + 32 + 35) + Vector3.new(0, 36, 0) - w * 0.3) * yaw
	for i, rain in ipairs(farRains) do
		rain.Acceleration = w * 1.1
		rain.Rate = (i <= math.ceil(RAIN_FAR * scale)) and 600 * wet or 0
	end
	if ground then
		local f = cam.Focus.Position
		splashPart.CFrame = CFrame.new(Vector3.new(f.X, ground.Y + 0.1, f.Z) + flat * 14)
		splash.Rate = 260 * falling * scale
	else
		splash.Rate = 0
	end
	local vol = 0.85 * wet * (1 - 0.45 * sheltered)
	rainSound.Volume += (vol - rainSound.Volume) * math.min(1, dt * 2)
	muffle.HighGain = -6 - 12 * sheltered
	if rainSound.Volume > 0.003 then
		if not rainSound.IsPlaying then rainSound:Play() end
	elseif rainSound.IsPlaying then
		rainSound:Stop()
	end
	-- a cooler, greyer light in the rain, and the lightning flicker
	if wet > 0.6 and os.clock() > nextThunder then
		nextThunder = os.clock() + random:NextNumber(25, 70)
		thunder()
	end
	flash = math.max(0, flash - dt * 5)
	local lightning = flash > 0 and (math.sin(flash * 40) > -0.2 and flash or 0) or 0
	-- (the rain no longer greys or darkens the picture -- that dimmed the lamps, the carousel and the overhead titles
	-- with it; the wet look comes from the rain, the puddles and the droplets instead. Only the lightning flicker is left.)
	grade.Enabled = lightning > 0
	if grade.Enabled then
		grade.Brightness = 0.22 * lightning
		grade.Contrast = 0
		grade.Saturation = 0
		grade.TintColor = Color3.new(1, 1, 1)
	end
end)

-- the drifting smoke, canal mist and dust motes (Ambience) are pushed by the wind too
local function windy(e) if e:IsA("ParticleEmitter") then pcall(function() e.WindAffectsDrift = true end) end end
task.spawn(function()
	local amb = workspace:WaitForChild("Ambience", 30)
	if not amb then return end
	for _, d in ipairs(amb:GetDescendants()) do windy(d) end
	amb.DescendantAdded:Connect(windy)
end)
