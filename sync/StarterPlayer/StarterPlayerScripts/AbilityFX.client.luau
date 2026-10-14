-- Wind effects for the movement abilities, Jett-style, on every fighter (players and bots), all local:
--   * Dash (Q / DashAt): a ring of wind bursts where you launch, a gust of streaks blows back past you and wind
--     ribbons trail off the hands and spiral along the body for the length of the dash (the body leans into it:
--     SlideAnimator's DASH pose)
--   * Double jump (AirJumpAt): an updraft -- a cloud ring kicked out under the feet, a jet of wind blown straight
--     down and ribbons spiralling up around the body
-- The sounds are unchanged (Client plays them). Fighters further than RANGE from the camera are skipped.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local me = Players.LocalPlayer
local RANGE = 160
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local WIND = Color3.fromRGB(232, 248, 255)
local WIND_DEEP = Color3.fromRGB(176, 226, 246)
-- the dash's afterimages (by rank) start on the same frame as its wind and last as long
local Afterimages = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Afterimages"))
local DASH_TIME = 0.26

local function lowEnd() return me:GetAttribute("LowEnd") == true end
local function ns(...)
	local kps, args = {}, {...}
	for i = 1, #args, 2 do table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1])) end
	return NumberSequence.new(kps)
end

local holder = Instance.new("Folder")
holder.Name = "AbilityFX"
holder.Parent = workspace

local function anchorAt(cf, size)
	local p = Instance.new("Part")
	p.Name = "FX"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 1; p.Size = size or Vector3.new(0.2, 0.2, 0.2); p.CFrame = cf
	p.Parent = holder
	return p
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false; e.LightInfluence = 0; e.LockedToPart = false
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end
-- a thin wind ribbon: a trail between two attachments a hair apart, always facing the camera
local function ribbon(parent, width, lifetime, transparency)
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, width / 2, 0); a0.Parent = parent
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -width / 2, 0); a1.Parent = parent
	local t = Instance.new("Trail")
	t.Attachment0 = a0; t.Attachment1 = a1; t.FaceCamera = true
	t.Lifetime = lifetime; t.MinLength = 0.03
	t.Color = ColorSequence.new(WIND, WIND_DEEP)
	t.Transparency = transparency or ns(0, 0.35, 0.5, 0.6, 1, 1)
	t.WidthScale = ns(0, 1, 1, 0.1)
	t.LightEmission = 0.85; t.LightInfluence = 0
	t.Parent = parent
	return t, a0, a1
end

-- running animations: each returns false when it's done
local running = {}

-- wind ribbons that orbit an axis through the body for a moment. place(t, angle) -> world position
local function spiral(count, duration, place, width, life)
	local parts = {}
	for i = 1, count do
		local p = anchorAt(CFrame.new(place(0, (i - 1) / count * math.pi * 2) or Vector3.zero))
		ribbon(p, width, life)
		parts[i] = p
	end
	local start = os.clock()
	table.insert(running, function()
		local t = (os.clock() - start) / duration
		if t >= 1 then
			for _, p in ipairs(parts) do Debris:AddItem(p, life + 0.1) end
			return false
		end
		for i, p in ipairs(parts) do
			local pos = place(t, (i - 1) / count * math.pi * 2)
			if pos then p.CFrame = CFrame.new(pos) end
		end
		return true
	end)
end

-- Q: Tailwind. Clean and quick: one ring of wind where you launch, two fine ribbons off the hands and a single
-- ribbon wrapping once round the body as you go
local function dashBurst(char, root, dir)
	-- your own dash in first person: no wind in front of the camera (the afterimages skip themselves too)
	if Afterimages.OwnFirstPerson(char) then return end
	local low = lowEnd()
	local at = root.Position
	local ringPart = anchorAt(CFrame.lookAt(at, at + dir) * CFrame.Angles(-math.pi / 2, 0, 0), Vector3.new(2, 0.2, 2))
	local ring = emitter(ringPart, {
		Texture = SMOKE, Color = ColorSequence.new(WIND), LightEmission = 0.6,
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Size = ns(0, 0.45, 1, 1.5), Transparency = ns(0, 0.55, 0.3, 0.7, 1, 1),
		Lifetime = NumberRange.new(0.22, 0.3), Speed = NumberRange.new(14, 18), Drag = 8,
		Rotation = NumberRange.new(0, 360),
	})
	ring:Emit(low and 10 or 18)
	Debris:AddItem(ringPart, 0.5)
	Afterimages.Trail(char, DASH_TIME)
	-- fine ribbons off the hands for the length of the dash
	local trails = {}
	for _, name in ipairs({"RightHand", "LeftHand", "Right Arm", "Left Arm"}) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local t, a0, a1 = ribbon(part, 0.09, Afterimages.FADE, ns(0, 0.35, 1, 1))
			table.insert(trails, {t, a0, a1})
		end
	end
	task.delay(DASH_TIME, function()
		for _, tr in ipairs(trails) do tr[1].Enabled = false end
		task.delay(Afterimages.FADE + 0.05, function() for _, tr in ipairs(trails) do for _, x in ipairs(tr) do x:Destroy() end end end)
	end)
	-- one ribbon wrapping once round the body, sliding back off it
	if not low then
		local side = dir:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
		local lift = side:Cross(dir).Unit
		spiral(1, DASH_TIME, function(t, phase)
			if not root.Parent then return nil end
			local a = phase + t * math.pi * 2
			return root.Position + (side * math.cos(a) + lift * math.sin(a)) * (1.6 - 0.4 * t) + dir * (0.8 - 2.6 * t)
		end, 0.12, Afterimages.FADE)
	end
end

-- double jump: Updraft. A clean ring of air rushing out flat under the feet and two fine ribbons spiralling up
-- round the body as it rises
local function updraft(char, root, hum)
	if Afterimages.OwnFirstPerson(char) then return end
	local low = lowEnd()
	local feet = root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y / 2 - 0.2, 0)
	local base = anchorAt(CFrame.new(feet), Vector3.new(1.8, 0.2, 1.8))
	local ring = emitter(base, {
		Texture = SMOKE, Color = ColorSequence.new(WIND), LightEmission = 0.55,
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Size = ns(0, 0.6, 1, 2.2), Transparency = ns(0, 0.5, 0.35, 0.68, 1, 1),
		Lifetime = NumberRange.new(0.3, 0.42), Speed = NumberRange.new(16, 21), Drag = 7,
		Rotation = NumberRange.new(0, 360),
	})
	ring:Emit(low and 12 or 22)
	Debris:AddItem(base, 0.7)
	local h = hum.HipHeight + root.Size.Y / 2
	spiral(2, 0.36, function(t, phase)
		if not root.Parent then return nil end
		local a = phase + t * math.pi * 2.6
		local r = 1.9 - 0.7 * t
		return root.Position + Vector3.new(math.cos(a) * r, -h + (h + 2.6) * t, math.sin(a) * r)
	end, 0.13, 0.2)
end

-- watch every fighter's DashAt / AirJumpAt (the owner sets them locally and the server mirrors them a moment
-- later: each fires once)
local seen = setmetatable({}, {__mode = "k"})
local pending = {}
local function fighters()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
	for _, m in ipairs(CollectionService:GetTagged("MarkedBot")) do table.insert(list, m) end
	return list
end

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position
	-- dashes waiting a frame for their velocity
	for i = #pending, 1, -1 do
		local job = pending[i]
		job.frames -= 1
		if job.frames < 0 then
			table.remove(pending, i)
			if job.root.Parent then
				local v = job.root.AssemblyLinearVelocity
				local flat = Vector3.new(v.X, 0, v.Z)
				local look = job.root.CFrame.LookVector
				local dir = flat.Magnitude > 12 and flat.Unit or Vector3.new(look.X, 0, look.Z).Unit
				dashBurst(job.char, job.root, dir)
			end
		end
	end
	for _, char in ipairs(fighters()) do
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if root and hum then
			local s = seen[char]
			if not s then
				s = {dash = char:GetAttribute("DashAt"), air = char:GetAttribute("AirJumpAt"), dashFx = 0, airFx = 0}
				seen[char] = s
			else
				local near = eye and (root.Position - eye).Magnitude < RANGE and hum.Health > 0
				local dash = char:GetAttribute("DashAt")
				if dash ~= s.dash then
					s.dash = dash
					if near and dash and now - dash < 0.5 and os.clock() - s.dashFx > 0.45 then
						s.dashFx = os.clock()
						table.insert(pending, {char = char, root = root, frames = 0})
					end
				end
				local air = char:GetAttribute("AirJumpAt")
				if air ~= s.air then
					s.air = air
					if near and air and now - air < 0.5 and os.clock() - s.airFx > 0.6 then
						s.airFx = os.clock()
						updraft(char, root, hum)
					end
				end
			end
		end
	end
end)

RunService.RenderStepped:Connect(function()
	for i = #running, 1, -1 do
		local ok, keep = pcall(running[i])
		if not ok or not keep then table.remove(running, i) end
	end
end)
