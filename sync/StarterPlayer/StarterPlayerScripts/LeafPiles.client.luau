-- Leaves (workspace.LeafPiles, tag "LeafPile"; attribute Colors = a ColorSequence sampled from the foliage of the
-- tree each pile sits under, so the leaves match it; Palette is the fallback; Drift = a wind-blown pile out in the
-- streets, not under a tree).
--  * every leaf is its own thing: anyone (players or bots) moving through leaves kicks the ones at their feet --
--    walking nudges them along, running / dashing / sliding sends them flying. A pile is just a lot of leaves.
--  * leaves stay where they land. Nothing gathers back into a pile by itself any more.
--  * the trees drop leaves: every so often one comes loose from the canopy above a pile and flutters down onto it, so
--    a kicked-apart pile slowly builds up again. Each spot keeps a limited number of leaves; past that the oldest
--    one lying out on its own fades away.
--  * the wind (ReplicatedStorage.Numberfall.Weather -- the gusts you hear) rustles leaves lying near you, carries
--    leaves in the air downwind and in a strong gust lifts a few off the top of a pile.
-- Entirely local: every screen builds and animates its own leaves, and only spots near the camera are built.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local me = Players.LocalPlayer
local KICK_RADIUS = 1.9      -- a body this close (horizontally) to a lying leaf moves it
local WALK_KICK = 6          -- slower than this nothing happens (standing, shuffling)
local RUN_KICK = 26          -- above walking speed (24): running, sprinting, dashing, sliding -- they fly
local PILE_RADIUS = 1.7
local BUILD_RANGE = 150      -- spots further than this from the camera aren't built
local DROP_RANGE = 185
local GRAVITY = 30
local TERMINAL = -5          -- leaves drift down slowly
local CAP, CAP_LOW = 40, 20  -- most leaves a spot keeps
local STIR_RANGE = 45
local PALETTES = {
	Autumn = {Color3.fromRGB(178, 72, 28), Color3.fromRGB(204, 122, 36), Color3.fromRGB(150, 46, 30), Color3.fromRGB(214, 162, 58), Color3.fromRGB(122, 66, 30)},
	Dead = {Color3.fromRGB(112, 72, 44), Color3.fromRGB(138, 92, 52), Color3.fromRGB(90, 58, 38), Color3.fromRGB(160, 110, 62), Color3.fromRGB(150, 70, 34)},
	Blossom = {Color3.fromRGB(255, 184, 198), Color3.fromRGB(240, 148, 172), Color3.fromRGB(255, 212, 222), Color3.fromRGB(226, 120, 150)},
}

local spots = {} -- marker -> state {marker, built, leaves = {rec}, flying = n, palette, petals, nextDrop}
-- rec = {part, rest = CFrame | nil (flying), v, spin, floor, t, born, home = bool (part of the original pile)}

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
local upParams = RaycastParams.new()
upParams.FilterType = Enum.RaycastFilterType.Exclude
local Weather = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Weather"))

local MESHES = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("LeafMeshes", 10)
local LEAF = MESHES and MESHES:FindFirstChild("Leaf")
local PETAL = MESHES and MESHES:FindFirstChild("Petal")

local function lowEnd() return me:GetAttribute("LowEnd") == true end

local function newLeaf(state, rng)
	local base = state.palette[rng:NextInteger(1, #state.palette)]
	local h, s, v = base:ToHSV()
	local color = Color3.fromHSV(h, s, math.clamp(v * rng:NextNumber(0.85, 1.12), 0, 1))
	local template = state.petals and PETAL or LEAF
	local leaf
	if template then
		leaf = template:Clone()
		local k = state.petals and rng:NextNumber(0.45, 0.6) / template.Size.Z or rng:NextNumber(0.75, 1.05) / template.Size.X
		leaf.Size = Vector3.new(template.Size.X * k, math.min(template.Size.Y * k, 0.05), template.Size.Z * k)
	else
		leaf = Instance.new("Part")
		leaf.Size = Vector3.new(0.8, 0.05, 0.45)
		local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = leaf
	end
	leaf.Name = "Leaf"; leaf.Anchored = true; leaf.CanCollide = false; leaf.CanQuery = false; leaf.CanTouch = false
	leaf.CastShadow = false; leaf.Material = Enum.Material.SmoothPlastic; leaf.Color = color
	return leaf
end

local function build(state)
	local marker = state.marker
	local rng = Random.new(math.floor(marker.Position.X * 7 + marker.Position.Z * 13))
	local palette = PALETTES[marker:GetAttribute("Palette") or "Autumn"] or PALETTES.Autumn
	local seq = marker:GetAttribute("Colors")
	if typeof(seq) == "ColorSequence" then
		palette = {}
		for _, k in ipairs(seq.Keypoints) do table.insert(palette, k.Value) end
	end
	state.palette = palette
	state.petals = marker:GetAttribute("Palette") == "Blossom"
	local holder = Instance.new("Folder")
	holder.Name = "Leaves"
	state.leaves = {}
	state.flying = 0
	local n = lowEnd() and 14 or 26
	for _ = 1, n do
		local leaf = newLeaf(state, rng)
		-- a low mound: denser and higher in the middle
		local a = rng:NextNumber(0, math.pi * 2)
		local r = PILE_RADIUS * math.sqrt(rng:NextNumber())
		local h = 0.04 + 0.45 * (1 - (r / PILE_RADIUS) ^ 2) * rng:NextNumber(0.55, 1)
		local cf = marker.CFrame * CFrame.new(math.cos(a) * r, h, math.sin(a) * r)
			* CFrame.Angles(rng:NextNumber(-0.45, 0.45), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.45, 0.45))
		leaf.CFrame = cf
		leaf.Parent = holder
		table.insert(state.leaves, {part = leaf, rest = cf, born = 0, home = true})
	end
	holder.Parent = marker
	state.holder = holder
	state.built = true
	state.nextDrop = os.clock() + math.random() * 6
end

local function unbuild(state)
	if state.holder then state.holder:Destroy() end
	state.holder = nil; state.leaves = nil; state.flying = 0
	state.built = false
end

-- send one lying leaf into the air
local rng = Random.new()
local function launch(state, rec, vel, from, up)
	local leaf = rec.part
	local out = Vector3.new(leaf.Position.X - from.X, 0, leaf.Position.Z - from.Z)
	out = out.Magnitude > 0.05 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
	local push = Vector3.new(vel.X, 0, vel.Z)
	rec.v = push + out * rng:NextNumber(2, 6) + Vector3.new(0, up, 0)
	rec.spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-6, 6), rng:NextNumber(-9, 9))
	rec.floor = nil
	rec.t = 0
	if rec.rest then rec.rest = nil; state.flying += 1 end
	rec.home = false
end

local function settle(state, rec, at)
	local cf = CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		* CFrame.Angles(math.random() * 0.16 - 0.08, 0, math.random() * 0.16 - 0.08)
	rec.part.CFrame = cf
	if not rec.rest then state.flying = math.max(0, state.flying - 1) end
	rec.rest = cf
	rec.v = nil
end

-- too many leaves at one spot: the oldest one lying out on its own fades away
local function trim(state)
	local cap = lowEnd() and CAP_LOW or CAP
	while #state.leaves > cap do
		local mp = state.marker.Position
		local pick, best = nil, nil
		for i, rec in ipairs(state.leaves) do
			if rec.rest then
				local d = (rec.part.Position - mp).Magnitude
				local score = d * 2 - rec.born * 0.01 -- (far out and old first)
				if not best or score > best then best, pick = score, i end
			end
		end
		if not pick then break end
		local rec = table.remove(state.leaves, pick)
		local part = rec.part
		TweenService:Create(part, TweenInfo.new(1.2), {Transparency = 1}):Play()
		task.delay(1.3, function() part:Destroy() end)
	end
end

-- a leaf comes loose from the tree above a spot and falls onto it
local function dropFromTree(state)
	local marker = state.marker
	local mp = marker.Position
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0, 4.5)
	local start = mp + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
	-- under the canopy: just below whatever's overhead (the tree's foliage), else a fixed height
	upParams.FilterDescendantsInstances = {state.holder}
	local hit = workspace:Raycast(start, Vector3.new(0, 26, 0), upParams)
	local y = hit and math.max(hit.Position.Y - 0.4, mp.Y + 3) or mp.Y + rng:NextNumber(8, 12)
	local leaf = newLeaf(state, rng)
	leaf.CFrame = CFrame.new(start.X, y, start.Z) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
	leaf.Transparency = 1
	leaf.Parent = state.holder
	TweenService:Create(leaf, TweenInfo.new(0.5), {Transparency = 0}):Play()
	local rec = {part = leaf, rest = nil, born = os.clock(), home = false,
		v = Vector3.new(rng:NextNumber(-1.5, 1.5), -1, rng:NextNumber(-1.5, 1.5)),
		spin = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-4, 4), rng:NextNumber(-5, 5)), t = 0}
	table.insert(state.leaves, rec)
	state.flying += 1
	trim(state)
end

-- everyone who can kick leaves: players and the round's bots
local function roots()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then table.insert(list, r) end
	end
	local bots = workspace:FindFirstChild("MatchBots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			local r = b:FindFirstChild("HumanoidRootPart")
			if r then table.insert(list, r) end
		end
	end
	return list
end

-- horizontal speed of each body: its physics velocity, or how far it actually moved since the last check (other
-- players' bodies replicate in steps), ignoring teleport-sized jumps
local lastPos = setmetatable({}, {__mode = "k"})
local function speedOf(root, dt)
	local v = root.AssemblyLinearVelocity
	local speed = math.sqrt(v.X * v.X + v.Z * v.Z)
	local p = root.Position
	local last = lastPos[root]
	lastPos[root] = p
	if last and dt > 0 then
		local moved = math.sqrt((p.X - last.X) ^ 2 + (p.Z - last.Z) ^ 2) / dt
		if moved < 120 and moved > speed then speed = moved end
	end
	return speed
end

local checkAcc, rangeAcc, stirAcc = 0, 1, 0
RunService.Heartbeat:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local gust = Weather.Gust(now)
	local wind = Weather.Wind(now)
	local cam = workspace.CurrentCamera
	local at = cam and cam.CFrame.Position
	-- the wind rustling lying leaves near you (20 times a second), now and then blowing a few off the top of a pile
	stirAcc += dt
	if stirAcc >= 1 / 20 then
		local step = stirAcc
		stirAcc = 0
		local parts, frames = {}, {}
		local amp = 0.04 + 0.32 * gust * gust
		for marker, state in pairs(spots) do
			if state.built and at and (marker.Position - at).Magnitude < STIR_RANGE then
				for i, rec in ipairs(state.leaves) do
					if rec.rest then
						local f = 5 + (i % 5) * 1.3
						local a = math.sin(clock * f + i * 1.7) * amp
						local b = math.cos(clock * (f * 0.8) + i) * amp * 0.6
						table.insert(parts, rec.part)
						table.insert(frames, rec.rest * CFrame.new(0, math.abs(a) * 0.12, 0) * CFrame.Angles(a, 0, b))
					end
				end
				if gust > 0.7 and math.random() < step * 0.06 * (gust - 0.6) * 10 then
					local count = math.random(3, 6)
					for _ = 1, count do
						local rec = state.leaves[math.random(1, #state.leaves)]
						if rec and rec.rest then launch(state, rec, wind * 0.5, marker.Position - Weather.Direction * 2, rng:NextNumber(3, 7)) end
					end
				end
			end
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
	end
	-- build / drop spots by distance to the camera; trees shed a leaf now and then
	rangeAcc += dt
	if rangeAcc >= 0.5 then
		rangeAcc = 0
		if at then
			for marker, state in pairs(spots) do
				local d = (marker.Position - at).Magnitude
				if not state.built and d < BUILD_RANGE then build(state)
				elseif state.built and d > DROP_RANGE and state.flying == 0 then unbuild(state) end
				if state.built and not marker:GetAttribute("Drift") and clock >= (state.nextDrop or 0) and d < 110 then
					state.nextDrop = clock + rng:NextNumber(3, 9) * (lowEnd() and 2 or 1)
					dropFromTree(state)
				end
			end
		end
	end
	-- anyone moving through leaves kicks the ones at their feet
	checkAcc += dt
	if checkAcc >= 0.05 then
		local step = checkAcc
		checkAcc = 0
		local list = roots()
		local speeds = {}
		for _, root in ipairs(list) do speeds[root] = speedOf(root, step) end
		for marker, state in pairs(spots) do
			if state.built then
				local mp = marker.Position
				for _, root in ipairs(list) do
					local speed = speeds[root]
					local rp = root.Position
					local dm = rp - mp
					-- (a quick reject: leaves of a spot don't wander far from it)
					if speed >= WALK_KICK and dm.Y > -2 and dm.Y < 6 and dm.X * dm.X + dm.Z * dm.Z < 30 * 30 then
						local v = root.AssemblyLinearVelocity
						local flat = Vector3.new(v.X, 0, v.Z)
						local running = speed >= RUN_KICK
						for _, rec in ipairs(state.leaves) do
							if rec.rest then
								local lp = rec.part.Position
								local dx, dz = lp.X - rp.X, lp.Z - rp.Z
								local dy = rp.Y - lp.Y
								if dy > -1 and dy < 5 and dx * dx + dz * dz < KICK_RADIUS * KICK_RADIUS then
									if running then
										launch(state, rec, flat * rng:NextNumber(0.2, 0.45), rp, rng:NextNumber(7, 15))
									else
										-- walking: a little skip along the ground, the way you're going
										launch(state, rec, flat * rng:NextNumber(0.35, 0.6), rp, rng:NextNumber(2, 4.5))
									end
								end
							end
						end
					end
				end
			end
		end
	end
	-- leaves in the air
	for _, state in pairs(spots) do
		if state.built and state.flying > 0 then
			local drag = math.exp(-1.8 * dt)
			for i, rec in ipairs(state.leaves) do
				if not rec.rest and rec.v then
					local leaf = rec.part
					rec.t = (rec.t or 0) + dt
					local v = rec.v
					local vy = math.max(v.Y - GRAVITY * dt, TERMINAL)
					v = Vector3.new(v.X * drag + wind.X * 0.9 * dt, vy, v.Z * drag + wind.Z * 0.9 * dt)
					rec.v = v
					local sway = vy < 0 and Vector3.new(math.sin(rec.t * 5 + i) * 2.2, 0, math.cos(rec.t * 4 + i * 1.7) * 2.2) or Vector3.zero
					local p = leaf.Position + (v + sway) * dt
					if vy < 0 and not rec.floor then
						-- the ground under this leaf, found once as it starts to come down
						local skip = {state.holder}
						for _, r in ipairs(roots()) do table.insert(skip, r.Parent) end
						floorParams.FilterDescendantsInstances = skip
						local hit = workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, -40, 0), floorParams)
						rec.floor = (hit and hit.Position.Y or state.marker.Position.Y) + 0.03
					end
					if rec.floor and p.Y <= rec.floor then
						settle(state, rec, Vector3.new(p.X, rec.floor, p.Z))
					elseif rec.t > 9 then
						settle(state, rec, Vector3.new(p.X, rec.floor or state.marker.Position.Y + 0.03, p.Z))
					else
						local s = rec.spin * dt
						leaf.CFrame = (leaf.CFrame - leaf.Position + p) * CFrame.Angles(s.X, s.Y, s.Z)
					end
				end
			end
		end
	end
end)

local function added(marker)
	if not marker:IsA("BasePart") or spots[marker] then return end
	spots[marker] = {marker = marker, built = false, flying = 0}
end
local function removed(marker)
	local state = spots[marker]
	if state then unbuild(state); spots[marker] = nil end
end
CollectionService:GetInstanceAddedSignal("LeafPile"):Connect(added)
CollectionService:GetInstanceRemovedSignal("LeafPile"):Connect(removed)
for _, m in ipairs(CollectionService:GetTagged("LeafPile")) do added(m) end

-- switching low-end mode rebuilds the spots with fewer (or more) leaves
me:GetAttributeChangedSignal("LowEnd"):Connect(function()
	for _, state in pairs(spots) do if state.built then unbuild(state) end end
end)
