-- WET GROUND (all local): when it rains the ground gets wet and puddles fill, then dry out slowly once it stops.
--   * puddles: the spots in workspace.Puddles (tag "Puddle", one to three discs each, invisible while dry) fill up --
--     darker, glassy, a little wider the wetter it gets -- with raindrop ripples on the ones near you while it's raining
--   * wet footsteps: on wet open ground every step gets a soft wet slap under the normal footfall; under a roof stays dry
--   * puddles make noise: stepping in one splashes (sound, droplets and a ring); sliding or dashing through one sprays a
--     run of splashes; landing in one makes a big splash; and after a puddle you leave a few wet footprints that fade
-- Steps come from Footsteps (Gait.OnWetStep is called at every footfall, for players and bots alike).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CS = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local NF = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local Weather = require(NF:WaitForChild("Weather"))
local Gait = require(NF:WaitForChild("Gait"))

local me = Players.LocalPlayer
local random = Random.new()
local RANGE = 70
-- only the recordings with a clear splash (several in the pack are near-silent), with their measured peak loudness so
-- each lands at an even level
local SPLASH = {9117940443, 9117940312, 9117941569, 9117940939, 9117942473, 9117942767}
local PEAK = {[9117940443] = 63, [9117940312] = 58, [9117941569] = 43, [9117940939] = 40, [9117942473] = 38, [9117942767] = 164}
local function gain(id) return math.clamp(55 / (PEAK[id] or 55), 0.35, 1.5) end
task.spawn(function()
	local list = {}
	for _, id in ipairs(SPLASH) do table.insert(list, "rbxassetid://" .. id) end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
end)
local RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local DROP = "rbxasset://textures/particles/sparkles_main.dds"
local function lowEnd() return me:GetAttribute("LowEnd") == true end
local function ns(...)
	local kps, a = {}, {...}
	for i = 1, #a, 2 do table.insert(kps, NumberSequenceKeypoint.new(a[i], a[i + 1])) end
	return NumberSequence.new(kps)
end

local group
task.spawn(function()
	local audio = SoundService:WaitForChild("NumberfallAudio", 30)
	group = audio and audio:WaitForChild("NumberfallSFX", 10)
end)

local fx = Instance.new("Folder"); fx.Name = "WetGroundFX"; fx.Parent = workspace
local function anchor(size)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 1; p.Size = size or Vector3.one * 0.2; p.Parent = fx
	return p
end

------------------------------------------------------------------ how wet it is
-- climbs over ~25 s of rain, dries over ~1.5 min after it stops
local wet = math.clamp(Weather.Rain(workspace:GetServerTimeNow()) * 1.6, 0, 1)
local level = 0 -- how full the puddles are (0 dry .. 1 full)
local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end

------------------------------------------------------------------ puddles
local puddles = {} -- part -> {pos, r, cf}
local function add(p)
	if not p:IsA("BasePart") then return end
	-- glassy and only part see-through, so the cobbles show through and it catches the lamps and sky
	p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(110, 118, 136); p.Reflectance = 0.7
	puddles[p] = {pos = p.Position, r = p:GetAttribute("R") or p.Size.Y / 2, cf = p.CFrame, shown = -1}
end
for _, p in ipairs(CS:GetTagged("Puddle")) do add(p) end
CS:GetInstanceAddedSignal("Puddle"):Connect(add)
CS:GetInstanceRemovedSignal("Puddle"):Connect(function(p) puddles[p] = nil end)

local function scaleOf(l) return 0.55 + 0.45 * l end
-- the puddle under a point, if it holds water
local function puddleAt(pos)
	if level < 0.2 then return nil end
	local k = scaleOf(level)
	for _, d in pairs(puddles) do
		local dx, dz = pos.X - d.pos.X, pos.Z - d.pos.Z
		local r = d.r * k
		if dx * dx + dz * dz < r * r and math.abs(pos.Y - d.pos.Y) < 1.6 then return d end
	end
	return nil
end
local function showPuddles()
	local k = scaleOf(level)
	for p, d in pairs(puddles) do
		if math.abs(d.shown - level) > 0.01 or (level == 0 and d.shown ~= 0) then
			d.shown = level
			if level <= 0.001 then
				p.Transparency = 1
			else
				p.Transparency = 1 - 0.5 * smooth(level * 1.3)
				p.Size = Vector3.new(p.Size.X, d.r * 2 * k, d.r * 2 * k)
			end
		end
	end
end

-- raindrop ripples on the few puddles nearest you
local RIPPLE_POOL = 6
local ripples = {}
for i = 1, RIPPLE_POOL do
	local a = anchor(Vector3.new(2, 0.05, 2))
	local e = Instance.new("ParticleEmitter")
	e.Texture = RING; e.Rate = 0; e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top; e.Speed = NumberRange.new(0.01)
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.Size = ns(0, 0.1, 1, 0.95); e.Transparency = ns(0, 0.3, 1, 1)
	e.Color = ColorSequence.new(Color3.fromRGB(205, 215, 230)); e.LightEmission = 0.2; e.LightInfluence = 0.8
	e.Lifetime = NumberRange.new(0.45, 0.6)
	e.Parent = a
	ripples[i] = {part = a, emitter = e}
end

------------------------------------------------------------------ splashes, droplets, footprints
local dropPart = anchor()
local drops = Instance.new("ParticleEmitter")
drops.Texture = DROP; drops.Rate = 0; drops.SpreadAngle = Vector2.new(55, 55); drops.EmissionDirection = Enum.NormalId.Top
drops.Speed = NumberRange.new(5, 10); drops.Acceleration = Vector3.new(0, -70, 0); drops.Lifetime = NumberRange.new(0.25, 0.4)
drops.Size = ns(0, 0.14, 1, 0.04); drops.Transparency = ns(0, 0.25, 1, 1)
drops.Color = ColorSequence.new(Color3.fromRGB(210, 220, 236)); drops.LightEmission = 0.2; drops.LightInfluence = 0.8
drops.Parent = dropPart
local ringPart = anchor()
local ring = ripples[1].emitter:Clone(); ring.Size = ns(0, 0.2, 1, 1.6); ring.Lifetime = NumberRange.new(0.5, 0.7); ring.Shape = Enum.ParticleEmitterShape.Box
ring.Parent = ringPart
-- a low crown of fine spray thrown out sideways, and a few fat droplets that arc up and fall back
local sheet = drops:Clone()
sheet.SpreadAngle = Vector2.new(82, 82); sheet.Speed = NumberRange.new(7, 13); sheet.Lifetime = NumberRange.new(0.18, 0.32)
sheet.Size = ns(0, 0.09, 1, 0.02); sheet.Transparency = ns(0, 0.35, 1, 1); sheet.Acceleration = Vector3.new(0, -60, 0)
sheet.Parent = dropPart
local blobs = drops:Clone()
blobs.SpreadAngle = Vector2.new(35, 35); blobs.Speed = NumberRange.new(8, 14); blobs.Lifetime = NumberRange.new(0.35, 0.5)
blobs.Size = ns(0, 0.22, 1, 0.08); blobs.Transparency = ns(0, 0.2, 1, 1); blobs.Acceleration = Vector3.new(0, -80, 0)
blobs.Parent = dropPart
local function splashFX(pos, big)
	local low = lowEnd()
	dropPart.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0))
	drops:Emit((big and 36 or 18) // (low and 2 or 1))
	sheet:Emit((big and 40 or 18) // (low and 2 or 1))
	blobs:Emit(big and 8 or 4)
	ringPart.CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0))
	ring:Emit(big and 3 or 1)
end

local function sound(root, id, vol, pitch, cut, eqLow)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id; s.Volume = vol * gain(id); s.PlaybackSpeed = pitch
	s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = 5; s.RollOffMaxDistance = 45
	s.SoundGroup = group
	local eq = Instance.new("EqualizerSoundEffect"); eq.LowGain = eqLow or 0; eq.MidGain = -1; eq.HighGain = -4; eq.Parent = s
	s.Parent = root
	s:Play()
	task.delay(cut, function()
		for _ = 1, 6 do if not s.Parent then return end; s.Volume *= 0.6; task.wait(0.03) end
		s:Destroy()
	end)
end
local lastSplash = {}
local function splash(root, kind)
	local id = SPLASH[random:NextInteger(1, #SPLASH)]
	while id == lastSplash[root] do id = SPLASH[random:NextInteger(1, #SPLASH)] end
	lastSplash[root] = id
	-- (these play through the game's SFX group, which sits at a quarter volume, like the footsteps)
	if kind == "big" then sound(root, id, 1.1, random:NextNumber(0.85, 0.95), 1.3, 0)
	elseif kind == "puddle" then sound(root, id, 0.8, random:NextNumber(0.95, 1.1), 0.85, 0)
	elseif kind == "spray" then sound(root, id, 0.55, random:NextNumber(1.05, 1.2), 0.55, -3)
	else sound(root, id, 0.26 * math.clamp(wet, 0.4, 1), random:NextNumber(1.2, 1.4), 0.4, -6) end
	fx:SetAttribute("Splashes", (fx:GetAttribute("Splashes") or 0) + 1)
end

-- wet footprints: a short trail after you've stepped in a puddle, fading out
local PRINTS = 40
local prints, printI = {}, 0
for i = 1, PRINTS do
	local p = anchor(Vector3.new(0.45, 0.02, 0.85))
	p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(30, 32, 40); p.Reflectance = 0.25
	prints[i] = {part = p, born = -math.huge}
end
local function footprint(pos, yaw)
	printI = printI % PRINTS + 1
	local f = prints[printI]
	f.part.CFrame = CFrame.new(pos + Vector3.new(0, 0.03, 0)) * yaw
	f.part.Transparency = 0.45
	f.born = os.clock()
end

------------------------------------------------------------------ who's where
local floorParams = RaycastParams.new(); floorParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshFilter()
	local skip = {fx}
	local w = workspace:FindFirstChild("WeatherFX"); if w then table.insert(skip, w) end
	local pf = workspace:FindFirstChild("Puddles"); if pf then table.insert(skip, pf) end
	local lp = workspace:FindFirstChild("LocalPets"); if lp then table.insert(skip, lp) end
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
	floorParams.FilterDescendantsInstances = skip
end
local state = {} -- character -> {root, hum, side, prints, lastStep, air, covered, coverAt}
local function track(character, root, hum)
	local s = state[character]
	if not s or s.root ~= root then
		s = {root = root, hum = hum, side = 1, prints = 0, lastStep = 0, air = false, covered = false, coverAt = 0, sprayAt = 0}
		state[character] = s
		character.Destroying:Once(function() state[character] = nil end)
	end
	return s
end
local function footOf(s)
	local root, hum = s.root, s.hum
	return root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
end
local function covered(s, now)
	if now - s.coverAt > 0.5 then
		s.coverAt = now
		s.covered = workspace:Raycast(s.root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 80, 0), floorParams) ~= nil
	end
	return s.covered
end

Gait.OnWetStep = function(character, speed, root, hum)
	if wet < 0.12 and level < 0.2 then
		local s0 = state[character]
		if not (s0 and s0.prints > 0) then return end
	end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - root.Position).Magnitude > RANGE then return end
	local now = os.clock()
	local s = track(character, root, hum)
	s.lastStep = now
	s.side = -s.side
	fx:SetAttribute("Steps", (fx:GetAttribute("Steps") or 0) + 1)
	local foot = footOf(s)
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local yaw = flat.Magnitude > 0.05 and CFrame.lookAt(Vector3.zero, flat.Unit).Rotation or CFrame.identity
	local stepPos = foot + yaw:VectorToWorldSpace(Vector3.new(0.5 * s.side, 0, 0))
	if puddleAt(stepPos) then
		splash(root, "puddle")
		splashFX(stepPos, false)
		s.prints = 8
	elseif wet > 0.12 and not covered(s, now) then
		splash(root, "wet")
	end
	if s.prints > 0 and not lowEnd() and not puddleAt(stepPos) then
		s.prints -= 1
		footprint(stepPos, yaw)
	end
end

------------------------------------------------------------------ rain on characters
-- out in the rain, a faint fine spray where drops hit the head and shoulders (no beads on the clothes: they read as
-- stickers); it stops under cover
local TOPS = {Head = true, Torso = true, UpperTorso = true, ["Left Arm"] = true, ["Right Arm"] = true,
	LeftUpperArm = true, RightUpperArm = true}
local function dress(s, character)
	if s.drip and s.dripChar == character then return end
	s.drip, s.dripChar = {}, character
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and TOPS[part.Name] then
			local hit = Instance.new("ParticleEmitter")
			hit.Name = "RainHits"; hit.Texture = DROP; hit.Rate = 0
			hit.Shape = Enum.ParticleEmitterShape.Box; hit.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			hit.EmissionDirection = Enum.NormalId.Top; hit.SpreadAngle = Vector2.new(75, 75)
			hit.Speed = NumberRange.new(1.5, 3.5); hit.Acceleration = Vector3.new(0, -45, 0)
			hit.Lifetime = NumberRange.new(0.08, 0.16); hit.Size = ns(0, 0.06, 1, 0.01)
			hit.Transparency = ns(0, 0.55, 1, 1)
			hit.Color = ColorSequence.new(Color3.fromRGB(215, 224, 238)); hit.LightEmission = 0.1; hit.LightInfluence = 0.9
			hit.Parent = part
			table.insert(s.drip, {part = part, hit = hit, head = part.Name == "Head"})
		end
	end
end
local function drench(s, amount, isMine, eye)
	for _, d in ipairs(s.drip or {}) do
		local a = amount
		-- your own head in first person: nothing right in front of the camera
		if isMine and d.head and (d.part.Position - eye).Magnitude < 2.5 then a = 0 end
		d.hit.Rate = a * (5 + 4 * d.part.Size.X * d.part.Size.Z)
	end
end

------------------------------------------------------------------ per frame
local slow, rippleClock, filterClock = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local rain = Weather.Rain(now)
	local target = math.clamp(rain * 1.6, 0, 1)
	wet += (target - wet) * math.min(1, dt / (target > wet and 25 or 90))
	level = smooth((wet - 0.15) / 0.6)
	local clock = os.clock()

	-- footprints fade over ~7 s
	for _, f in ipairs(prints) do
		local age = clock - f.born
		if age < 8 then f.part.Transparency = 0.45 + 0.55 * math.clamp(age / 7, 0, 1) end
	end

	slow += dt
	if slow < 0.1 then return end
	local step = slow
	slow = 0
	showPuddles()
	filterClock -= step
	if filterClock <= 0 then filterClock = 2; refreshFilter() end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local eye = cam.CFrame.Position

	-- ripples: the nearest few puddles while it's raining
	rippleClock -= step
	if rippleClock <= 0 then
		rippleClock = 0.5
		local list = {}
		if rain > 0.05 and level > 0.25 and not lowEnd() then
			for p, d in pairs(puddles) do
				local dist = (d.pos - eye).Magnitude
				if dist < 50 then table.insert(list, {d = d, dist = dist}) end
			end
			table.sort(list, function(a, b) return a.dist < b.dist end)
		end
		local k = scaleOf(level)
		for i, r in ipairs(ripples) do
			local pick = list[i]
			if pick then
				local rr = pick.d.r * k * 1.3
				r.part.Size = Vector3.new(rr, 0.05, rr)
				r.part.CFrame = CFrame.new(pick.d.pos + Vector3.new(0, 0.05, 0))
				r.emitter.Rate = math.clamp(rr * rr * 1.6 * rain, 1, 14)
			else
				r.emitter.Rate = 0
			end
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and (root.Position - eye).Magnitude < RANGE then track(c, root, hum) end
	end
	-- rain on characters (players and any bots that have stepped near you)
	local clockNow = os.clock()
	for c, s in pairs(state) do
		if s.root.Parent and s.hum.Health > 0 and (s.root.Position - eye).Magnitude < 60 and rain > 0.05 and not lowEnd() then
			local open = not covered(s, clockNow)
			if open then dress(s, c) end
			drench(s, open and rain or 0, c == me.Character, eye)
		elseif s.drip then
			drench(s, 0, false, eye)
		end
	end

	-- sliding / dashing through a puddle sprays; landing in one splashes big
	if level < 0.2 then return end
	for c, s in pairs(state) do
		local root, hum = s.root, s.hum
		if root.Parent and hum.Health > 0 and (root.Position - eye).Magnitude < RANGE then
			local grounded = hum.FloorMaterial ~= Enum.Material.Air
			local foot = footOf(s)
			if grounded and s.air then
				local d = puddleAt(foot)
				if d then splash(root, "big"); splashFX(foot, true); s.prints = 8 end
			end
			s.air = not grounded
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			if grounded and speed > 14 and clock - s.lastStep > 0.45 and clock - s.sprayAt > 0.22 and puddleAt(foot) then
				s.sprayAt = clock
				splash(root, "spray")
				splashFX(foot, false)
				s.prints = 8
			end
		end
	end
end)
