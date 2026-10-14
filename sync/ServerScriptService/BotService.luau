-- MATCH BOTS: when a lone player (or a very small lobby) readies up, AI fighters fill the round so nobody waits forever.
--   * MatchService asks Planned(readyHumans) how many bots would join; they count towards MinPlayers.
--   * Bots are full fighters: a visor with a number, three lives, a notebook. They roam the city, chase whoever they
--     can see, read visors that face them (taking ReadTime seconds) and write the number, exactly like a player.
--   * They're tagged MarkedBot, so the client systems (NumberView, NotebookController via BotProxy) treat them like players.
--   * Fewer bots join as more real players ready up; none at all once FILL.NoneFrom humans are in.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local FILL = {
	Fighters = 6,      -- fill the round up to this many fighters in total
	NoneFrom = 4,      -- no bots once this many real players are in
	ReadTime = {3.6, 5.2}, -- seconds a bot needs to read a visor (random per bot)
	SightRange = 75,
	WalkSpeed = 19, SprintSpeed = 27, -- (players: 24 / 32)
	SlideSpeed = 40, SlideTime = 0.8, SlideCooldown = {4, 8},
	DashSpeed = 58, DashTime = 0.18, DashCooldown = {2.5, 5}, -- (players: 1s cooldown)
	TurnRate = 9, -- how fast a bot can turn to face someone (rad/s): no instant turret snaps
}
local NAMES = {"ASH", "WREN", "SILAS", "MARA", "JUDE", "ORIN", "VESPER", "ROOK", "IVY", "COLE", "NELL", "HOLLIS", "SABLE", "CROW"}
local SKINS = {Color3.fromRGB(234, 192, 160), Color3.fromRGB(204, 142, 105), Color3.fromRGB(141, 85, 54), Color3.fromRGB(96, 59, 38),
	Color3.fromRGB(245, 205, 180), Color3.fromRGB(176, 118, 82)}

local B = {}

function B.Start(deps)
	local shared, combat, match, forehead, ragdolls, config, movement = deps.shared, deps.combat, deps.match, deps.forehead, deps.ragdolls, deps.config, deps.movement
	local Hair = require(script.Parent:WaitForChild("Hair"))
	local Outfits = require(RS.Numberfall:WaitForChild("Outfits"))
	local HairCatalog = require(RS.Numberfall:WaitForChild("HairCatalog"))
	local ZoneRules = RS.Numberfall:FindFirstChild("ZoneRules") and require(RS.Numberfall.ZoneRules)
	local ZoneService = script.Parent:FindFirstChild("ZoneService") and require(script.Parent.ZoneService)
	local tint = Color3.fromRGB(table.unpack(config.Teams.FFA.RGB))
	local ANIMS = config.Animations or {}
	local folder = Instance.new("Folder"); folder.Name = "MatchBots"; folder.Parent = workspace

	local outfitIds = {}
	for id in pairs(Outfits.ById) do table.insert(outfitIds, id) end
	table.sort(outfitIds)
	local hairColors = {}
	for k, v in pairs(HairCatalog.Colors or {}) do table.insert(hairColors, type(k) == "string" and k or (type(v) == "table" and v.Id) or v) end

	local fighters = {}   -- id -> {id, name, index, lives, kills, deaths, out, model, ...}  (this round's bots)
	local active = false
	local outOrderBase = 0

	------------------------------------------------------------------ helpers
	local function rootOf(model) return model and model:FindFirstChild("HumanoidRootPart") end
	local function aliveModel(model)
		local h = model and model:FindFirstChildOfClass("Humanoid")
		return h and h.Health > 0 and model.Parent ~= nil
	end
	-- every fighter body currently in the round: player characters in the arena and living bots
	local function bodies()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			if p:GetAttribute("InArena") == true and aliveModel(c) then table.insert(list, c) end
		end
		for _, f in pairs(fighters) do if f.model and aliveModel(f.model) then table.insert(list, f.model) end end
		return list
	end
	local function spawnPoint()
		local spawns = {}
		for _, s in ipairs(CollectionService:GetTagged("MatchSpawn")) do
			if s:IsA("SpawnLocation") and s.Enabled and s:IsDescendantOf(workspace) then table.insert(spawns, s) end
		end
		local zoneCF
		if ZoneService and ZoneRules and ZoneService.FilterSpawns then
			local ok, list, cf = pcall(ZoneService.FilterSpawns, shared, ZoneRules, spawns)
			if ok then spawns, zoneCF = list, cf end
		end
		if zoneCF then return zoneCF end
		local others = {}
		for _, b in ipairs(bodies()) do local r = rootOf(b); if r then table.insert(others, r.Position) end end
		-- (shared with the players' spawns: never a spawn someone was just put on -- ServerScriptService.SpawnPicker)
		local best = require(game:GetService("ServerScriptService"):WaitForChild("SpawnPicker")).Pick(spawns, others)
		return best and best.CFrame or CFrame.new(1305, 1, 131)
	end

	------------------------------------------------------------------ bodies
	local function build(f)
		local desc = Instance.new("HumanoidDescription")
		local skin = SKINS[(f.index - 1) % #SKINS + 1]
		for _, k in ipairs({"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}) do desc[k] = skin end
		local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
		if not ok or not model then warn("[Bots] couldn't build a bot: " .. tostring(model)); return nil end
		model.Name = f.name
		model:SetAttribute("DisplayName", f.name)
		model:SetAttribute("BotId", f.id)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		local animate = model:FindFirstChild("Animate"); if animate then animate:Destroy() end
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.NameDisplayDistance = 0; hum.HealthDisplayDistance = 0
		hum.WalkSpeed = FILL.WalkSpeed; hum.UseJumpPower = true; hum.JumpPower = config.JumpPower or 47
		hum.BreakJointsOnDeath = false
		-- no tripping: running into a kerb, a slide burst or another body used to knock bots flat (FallingDown /
		-- Ragdoll). Their death ragdoll goes through PlatformStand (RagdollService), which this doesn't touch.
		for _, st in ipairs({Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll}) do
			pcall(function() hum:SetStateEnabled(st, false) end)
		end
		local head = model:FindFirstChild("Head")
		if head then
			local face = head:FindFirstChild("face") or Instance.new("Decal")
			face.Name = "face"; face.Face = Enum.NormalId.Front; face.Texture = "rbxasset://textures/face.png"; face.Parent = head
		end
		local at = spawnPoint()
		local look = at.LookVector
		local pos = at.Position + Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 0.5, 0)
		model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(look.X, 0, look.Z)))
		model.Parent = folder
		pcall(function() root:SetNetworkOwner(nil) end)
		pcall(function() Outfits.Apply(model, f.outfit, skin, Outfits.DefaultColorway) end)
		local record = {Character = model, Humanoid = hum, Side = "Bot" .. f.index, ColorSide = "FFA", Name = f.name, UserId = f.id, Bot = true, MatchBot = true}
		local code = combat:Register(model, record)
		forehead.Attach(model, code, tint, config)
		f.lastCode = code or f.lastCode
		if #hairColors > 0 then pcall(function() Hair.Equip(model, nil, f.hair) end) end
		-- a still copy of the dressed body for the results screen (the real one fades out after an elimination)
		task.delay(0.4, function() pcall(function()
			if not model.Parent then return end
			local RS = game:GetService("ReplicatedStorage")
			local looks = RS:FindFirstChild("BotLooks") or Instance.new("Folder")
			looks.Name = "BotLooks"; looks.Parent = RS
			local old = looks:FindFirstChild(tostring(f.id)); if old then old:Destroy() end
			model.Archivable = true
			local copy = model:Clone()
			if not copy then return end
			for _, d in ipairs(copy:GetDescendants()) do
				if d:IsA("BaseScript") or d:IsA("Constraint") or d:IsA("BillboardGui") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Trail") then d:Destroy()
				elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanTouch = false; d.CanQuery = false end
			end
			for _, k in ipairs({"NumberfallCode", "NumberfallSide", "Crouching", "Sprinting"}) do copy:SetAttribute(k, nil) end
			copy.Name = tostring(f.id)
			copy:SetAttribute("BotId", f.id); copy:SetAttribute("DisplayName", f.name)
			copy.Parent = looks
		end) end)
		model:SetAttribute("NumberfallSide", "FFA")
		CollectionService:AddTag(model, "MarkedBot")
		pcall(function() ragdolls:Prepare(model) end)
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local function load(id)
			if not id then return nil end
			local a = Instance.new("Animation"); a.AnimationId = "rbxassetid://" .. id
			local ok2, track = pcall(function() return animator:LoadAnimation(a) end)
			if ok2 and track then track.Looped = true end
			return ok2 and track or nil
		end
		f.model, f.hum, f.root, f.head = model, hum, root, head
		f.idle, f.walk, f.run = load(ANIMS.Idle1), load(ANIMS.Walk), load(ANIMS.Run)
		if f.idle then f.idle:Play() end
		-- the same movement state players have (Sprinting / SlideUntil / Crouching / DashAt... attributes and the slide
		-- ribbon), so every client draws their gait, sprint lean, slides and dashes like a player's
		if movement then pcall(function() movement:Register(model, model) end) end
		-- turning: a physics constraint eases the body round at TurnRate instead of snapping it
		local att = Instance.new("Attachment"); att.Name = "BotTurn"; att.Parent = root
		local align = Instance.new("AlignOrientation")
		align.Name = "BotTurn"; align.Mode = Enum.OrientationAlignmentMode.OneAttachment; align.Attachment0 = att
		align.MaxTorque = 1e6; align.MaxAngularVelocity = FILL.TurnRate; align.Responsiveness = 22
		align.Enabled = false; align.Parent = root
		-- bursts (slides and dashes) push the body along the ground
		local push = Instance.new("LinearVelocity")
		push.Name = "BotPush"; push.Attachment0 = att; push.RelativeTo = Enum.ActuatorRelativeTo.World
		push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		push.PrimaryTangentAxis = Vector3.xAxis; push.SecondaryTangentAxis = Vector3.zAxis
		push.MaxForce = 6e4; push.Enabled = false; push.Parent = root
		f.align, f.push = align, push
		-- stay on your feet: a light constraint keeps the body's up axis vertical (turning is left free). Knocks from
		-- kerbs, slides and other bodies used to tip bots onto their side while they kept running.
		pcall(function()
			local upAtt = Instance.new("Attachment"); upAtt.Name = "BotUp"; upAtt.Axis = Vector3.yAxis; upAtt.SecondaryAxis = Vector3.zAxis; upAtt.Parent = root
			local upright = Instance.new("AlignOrientation")
			upright.Name = "BotUpright"; upright.Mode = Enum.OrientationAlignmentMode.OneAttachment; upright.Attachment0 = upAtt
			upright.AlignType = Enum.AlignType.PrimaryAxisParallel; upright.PrimaryAxis = Vector3.yAxis
			upright.MaxTorque = 2e5; upright.Responsiveness = 40; upright.Parent = root
			f.upright = upright
		end)
		f.slideReadyAt = os.clock() + math.random(2, 5)
		f.dashReadyAt = os.clock() + 1 + math.random() * 2
		f.orbit = (math.random() < 0.5) and 1 or -1
		f.read, f.target, f.path, f.wp, f.goal = 0, nil, nil, 0, nil
		f.readTime = FILL.ReadTime[1] + math.random() * (FILL.ReadTime[2] - FILL.ReadTime[1])
		f.stuckAt, f.lastPos = os.clock(), root.Position
		local myModel = model
		hum.Died:Once(function()
			combat:Remove(myModel, myModel)
			if movement then pcall(function() movement:Remove(myModel) end) end
			if f.align then f.align.Enabled = false end
			if f.push then f.push.Enabled = false end
			if f.upright and f.upright.Parent then f.upright.Enabled = false end -- (let the body fall)
			pcall(function() ragdolls:Activate(myModel) end)
			pcall(function() forehead.Dead(myModel, config) end)
			CollectionService:RemoveTag(myModel, "MarkedBot")
			for _, tr in ipairs({f.idle, f.walk, f.run}) do if tr then tr:Stop(0.1) end end
			myModel:SetAttribute("NotebookOut", false)
			task.delay(1.4, function() for _, d in ipairs(myModel:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end end)
			task.delay(3, function()
				for _, d in ipairs(myModel:GetDescendants()) do
					if d:IsA("BasePart") then TweenService:Create(d, TweenInfo.new(1), {Transparency = 1}):Play() end
				end
				task.delay(1.1, function() myModel:Destroy() end)
			end)
			if fighters[f.id] ~= f or not active then return end
			f.deaths += 1
			f.lives -= 1
			if f.lives <= 0 then
				match.outOrder = (match.outOrder or 0) + 1
				f.out = match.outOrder
			elseif match:IsPlaying() then
				task.delay(config.RespawnSeconds or 3, function()
					if active and fighters[f.id] == f and match:IsPlaying() then build(f) end
				end)
			end
		end)
		return model
	end

	------------------------------------------------------------------ the provider MatchService talks to
	local P = {}
	function P.Planned(humans)
		if humans < 1 or humans >= FILL.NoneFrom then return 0 end
		return math.max(0, FILL.Fighters - humans)
	end
	function P.Begin(count)
		P.Clear()
		local looks = game:GetService("ReplicatedStorage"):FindFirstChild("BotLooks")
		if looks then looks:ClearAllChildren() end
		active = count > 0
		local used = {}
		for i = 1, count do
			local n
			repeat n = math.random(1, #NAMES) until not used[n] or #NAMES < count
			used[n] = true
			local id = -(1000 + i)
			local f = {id = id, index = i, name = NAMES[n], lives = config.Lives or 3, kills = 0, deaths = 0,
				outfit = outfitIds[math.random(1, #outfitIds)], hair = #hairColors > 0 and hairColors[math.random(1, #hairColors)] or nil}
			fighters[id] = f
			build(f)
		end
		shared:SetAttribute("BotCount", count)
	end
	function P.Clear()
		active = false
		shared:SetAttribute("BotBoard", "")
		for id, f in pairs(fighters) do
			if f.model then pcall(function() combat:Remove(f.model, f.model) end); f.model:Destroy() end
			fighters[id] = nil
		end
		folder:ClearAllChildren()
		shared:SetAttribute("BotCount", 0)
	end
	function P.Started() local n = 0; for _ in pairs(fighters) do n += 1 end; return n end
	function P.Standing() local n = 0; for _, f in pairs(fighters) do if f.lives > 0 then n += 1 end end; return n end
	-- ranking rows for MatchService:Finish
	function P.Entries()
		local list = {}
		for _, f in pairs(fighters) do
			table.insert(list, {bot = true, id = f.id, name = f.name, lives = f.lives, kills = f.kills, deaths = f.deaths, out = f.out,
				code = f.model and f.model.Parent and f.model:GetAttribute("NumberfallCode") or f.lastCode or "----"})
		end
		return list
	end
	-- a bot eliminated someone (Server's onKill): count it and give it a fresh number, like a player
	function P.Scored(model)
		for _, f in pairs(fighters) do
			if f.model == model then
				f.kills += 1
				local fresh = combat:Rescramble(model)
				if fresh then forehead.Attach(model, fresh, tint, config); f.lastCode = fresh end
				if f.kills >= (config.ScoreLimit or 30) then match:Finish() end
				return
			end
		end
	end
	match.bots = P

	------------------------------------------------------------------ brains
	local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function canSee(fromHead, toModel, toHead)
		rayParams.FilterDescendantsInstances = {fromHead.Parent}
		local hit = workspace:Raycast(fromHead.Position, toHead.Position - fromHead.Position, rayParams)
		return hit ~= nil and hit.Instance:IsDescendantOf(toModel)
	end
	-- face someone: the turn constraint eases the body round (the humanoid keeps walking, so bots strafe while they read)
	local function face(f, pos)
		local r = f.root
		local d = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z)
		if d.Magnitude < 0.5 then return end
		f.hum.AutoRotate = false
		f.align.CFrame = CFrame.lookAt(Vector3.zero, d.Unit)
		f.align.Enabled = true
	end
	-- stop facing: the humanoid turns with its walk again
	local function release(f)
		if f.align.Enabled then f.align.Enabled = false end
		f.hum.AutoRotate = true
	end
	local function sprint(f, on)
		if f.sprinting == on then return end
		f.sprinting = on
		f.hum.WalkSpeed = on and FILL.SprintSpeed or FILL.WalkSpeed
		if movement then pcall(function() movement:Request(f.model, "Sprint", on) end) end
	end
	-- a burst along the ground (slide or dash) that fades back into the run
	local function burst(f, dir, speed, seconds)
		f.burstUntil = os.clock() + seconds
		f.push.VectorVelocity = dir * speed
		f.push.Enabled = true
		local started = os.clock()
		task.spawn(function()
			while f.push.Parent and os.clock() < f.burstUntil do
				local t = (os.clock() - started) / seconds
				f.push.VectorVelocity = dir * (speed + (FILL.SprintSpeed - speed) * t)
				task.wait()
			end
			if f.push.Parent then f.push.Enabled = false end
		end)
	end
	local function slide(f, dir)
		if movement then pcall(function() movement:Request(f.model, "Slide", true, dir) end) end
		burst(f, dir, FILL.SlideSpeed, FILL.SlideTime)
		f.slideReadyAt = os.clock() + FILL.SlideCooldown[1] + math.random() * (FILL.SlideCooldown[2] - FILL.SlideCooldown[1])
		task.delay(FILL.SlideTime, function()
			if movement and f.model.Parent then pcall(function() movement:Request(f.model, "Slide", false) end) end
		end)
	end
	local function dash(f, dir)
		if movement then pcall(function() movement:Request(f.model, "Dash") end) end
		burst(f, dir, FILL.DashSpeed, FILL.DashTime)
		f.dashReadyAt = os.clock() + FILL.DashCooldown[1] + math.random() * (FILL.DashCooldown[2] - FILL.DashCooldown[1])
	end
	-- a double jump at the top of a jump (now and then), with the flip players see
	local function maybeAirJump(f)
		if math.random() > 0.35 then return end
		task.delay(0.32, function()
			if not f.model.Parent or f.hum.FloorMaterial ~= Enum.Material.Air then return end
			local v = f.root.AssemblyLinearVelocity
			f.root.AssemblyLinearVelocity = Vector3.new(v.X, 56, v.Z)
			if movement then pcall(function() movement:Request(f.model, "AirJump") end) end
		end)
	end
	local function notebook(f, out, digits, code)
		local m = f.model
		if m:GetAttribute("NotebookOut") ~= out then m:SetAttribute("NotebookOut", out) end
		if os.clock() < (f.noteLock or 0) then return end
		local snap = "Ready|" .. ((out and code) and code:sub(1, digits) or "")
		if m:GetAttribute("NoteSnapshot") ~= snap then m:SetAttribute("NoteSnapshot", snap) end
	end
	-- walk somewhere with the pathfinder (recomputed in the background; follows waypoints, jumps where it says)
	-- (pathfinding over the whole city is the expensive part of a bot: a route is worked out at most about once a
	-- second per bot, and a fighter it can see on open, level ground is run at directly with no route at all)
	-- does a straight run from a to b go over the canal? (then it's the bridge or the stairs, never a jump in: two bots
	-- that spot each other across the water used to dive in, climb out and do it again for ever)
	local crossRay = RaycastParams.new()
	crossRay.FilterType = Enum.RaycastFilterType.Exclude
	local function overCanal(a, b)
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = flat.Magnitude
		if len < 4 then return false end
		crossRay.FilterDescendantsInstances = bodies()
		local steps = math.clamp(math.floor(len / 5), 1, 14)
		for i = 1, steps do
			local p = a + flat * (i / (steps + 1))
			-- (long enough to reach the canal bed from a standing root: a 14-stud ray stopped a stud short of it,
			-- so the canal never counted and bots ran straight in; nothing under it at all counts as a drop too)
			local hit = workspace:Raycast(Vector3.new(p.X, a.Y + 4, p.Z), Vector3.new(0, -24, 0), crossRay)
			if not hit or hit.Position.Y < a.Y - 4.5 then return true end
		end
		return false
	end
	-- overCanal, remembered for half a second -- but re-checked straight away once either end has moved a few studs
	-- (a stale "clear" let a sprinting bot run a dozen studs straight off the towpath before the next check)
	local function crossCached(f, key, a, b, now)
		local c = f[key]
		if not c or now > c.t or (c.a - a).Magnitude > 3 or (c.b - b).Magnitude > 3 then
			c = {t = now + 0.5, a = a, b = b, v = overCanal(a, b)}
			f[key] = c
		end
		return c.v
	end
	local function goTo(f, goal, now, direct)
		if direct and crossCached(f, "directX", f.root.Position, goal, now) then direct = false end
		if direct and now > (f.noDirectUntil or 0) and math.abs(goal.Y - f.root.Position.Y) < 6 then
			f.path = nil
			f.hum:MoveTo(goal)
			return
		end
		local moved = not f.goal or (f.goal - goal).Magnitude > 8
		if (not f.path or moved or now > (f.repathAt or 0)) and now > (f.pathAt or 0) then
			f.goal = goal
			f.repathAt = now + 2.5
			if not f.computing then
				f.pathAt = now + 1.1 + math.random() * 0.4
				f.computing = true
				local from = f.root.Position
				task.spawn(function()
					-- (the canal water is off limits: workspace.SunsetCity.Canal.CanalNoPath carries the "Canal" label)
					local path = PathfindingService:CreatePath({AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6,
						Costs = {Canal = math.huge}})
					local ok = pcall(function() path:ComputeAsync(from, goal) end)
					f.computing = false
					if ok and path.Status == Enum.PathStatus.Success then
						f.path = path:GetWaypoints(); f.wp = 2
					else
						f.path = nil
					end
				end)
			end
		end
		if f.path and f.path[f.wp] then
			local w = f.path[f.wp]
			if (Vector3.new(w.Position.X, 0, w.Position.Z) - Vector3.new(f.root.Position.X, 0, f.root.Position.Z)).Magnitude < 3 then
				f.wp += 1
				w = f.path[f.wp]
			end
			if w then
				if w.Action == Enum.PathWaypointAction.Jump and f.hum.FloorMaterial ~= Enum.Material.Air then f.hum.Jump = true; maybeAirJump(f) end
				f.hum:MoveTo(w.Position)
				return
			end
		end
		-- (no path yet: head straight for it -- unless straight means into the canal, then wait for the route)
		if f.root.Position.Y > -4 and crossCached(f, "fallbackX", f.root.Position, goal, now) then f.hum:MoveTo(f.root.Position) else f.hum:MoveTo(goal) end
	end
	local function wanderGoal()
		local spawns = CollectionService:GetTagged("MatchSpawn")
		local s = spawns[math.random(1, math.max(1, #spawns))]
		local base = s and s.Position or Vector3.new(1305, 1, 131)
		return base + Vector3.new(math.random(-14, 14), 0, math.random(-14, 14))
	end
	-- the canal: a bot that drops onto the canal bed can't use the ladders and the pathfinder has no way out, so it
	-- runs to the nearest canal wall and climbs out onto the towpath (from there the stairs are an ordinary route).
	-- (a plain jump / velocity kick doesn't clear the 5-stud wall: the humanoid eats it)
	-- (the canal's no-go volume, CanalNoPath, has to be CanQuery for the pathfinder to see its "Canal" label; its
	-- PathOnly collision group keeps every raycast / overlap off it -- including groups other scripts register at runtime)
	task.spawn(function()
		local PS = game:GetService("PhysicsService")
		for _ = 1, 12 do
			pcall(function()
				if not PS:IsCollisionGroupRegistered("PathOnly") then PS:RegisterCollisionGroup("PathOnly") end
				for _, g in ipairs(PS:GetRegisteredCollisionGroups()) do
					if PS:CollisionGroupsAreCollidable("PathOnly", g.name) then PS:CollisionGroupSetCollidable("PathOnly", g.name, false) end
				end
			end)
			task.wait(5)
		end
	end)
	local canalWalls = {}
	do
		local city = workspace:FindFirstChild("SunsetCity")
		local canal = city and city:FindFirstChild("Canal")
		if canal then
			for _, p in ipairs(canal:GetChildren()) do
				if p:IsA("BasePart") and p.Name == "CanalWall" then table.insert(canalWalls, p) end
			end
		end
	end
	-- (prefer: a point it wants to reach, so it climbs out on that side rather than just the nearest one)
	local function canalExit(pos, prefer)
		if #canalWalls == 0 or pos.Y > -4 then return nil end
		local best, bestD, bestScore
		for _, w in ipairs(canalWalls) do
			local l = w.CFrame:PointToObjectSpace(pos)
			local h = w.Size / 2
			local c = w.CFrame:PointToWorldSpace(Vector3.new(math.clamp(l.X, -h.X, h.X), h.Y, math.clamp(l.Z, -h.Z, h.Z)))
			local to = Vector3.new(c.X - pos.X, 0, c.Z - pos.Z)
			local d = to.Magnitude
			local score = d
			if prefer then
				local want = Vector3.new(prefer.X - pos.X, 0, prefer.Z - pos.Z)
				if want.Magnitude > 1 and d > 0.1 and to.Unit:Dot(want.Unit) < 0 then score += 40 end
			end
			if not bestScore or score < bestScore then best, bestD, bestScore = c, d, score end
		end
		return best, bestD
	end
	local climbRay = RaycastParams.new()
	climbRay.FilterType = Enum.RaycastFilterType.Exclude
	local climbBox = OverlapParams.new()
	climbBox.FilterType = Enum.RaycastFilterType.Exclude
	climbBox.RespectCanCollide = true
	-- a clear spot on the towpath over the wall: straight over, or a little along it (stairs can be in the way)
	local function landingFor(wallTop, dir)
		local skip = bodies()
		climbRay.FilterDescendantsInstances = skip
		climbBox.FilterDescendantsInstances = skip
		local along = Vector3.yAxis:Cross(dir)
		along = along.Magnitude > 0.01 and along.Unit or Vector3.xAxis
		for _, off in ipairs({0, 4, -4, 8, -8, 12, -12, 16, -16}) do
			local land = wallTop + dir * 2.8 + along * off
			local hit = workspace:Raycast(land + Vector3.new(0, 7, 0), Vector3.new(0, -10, 0), climbRay)
			if hit and hit.Position.Y > -3.6 and hit.Position.Y < 1 and hit.Normal.Y > 0.8 then
				if #workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 3, 0)), Vector3.new(2, 4.4, 2), climbBox) == 0 then
					return hit.Position
				end
			end
		end
		return nil
	end
	-- up the wall and over onto the landing, with the climb pose (ClimbAt)
	local function climbOut(f, landing, dir)
		f.climbing = true
		if movement then pcall(function() movement:Request(f.model, "Climb") end) end
		local start = f.root.Position
		local stand = f.hum.HipHeight + f.root.Size.Y / 2 + 0.15
		local finish = landing + Vector3.new(0, stand, 0)
		-- straight up the face first, then over the top
		local peak = Vector3.new(start.X, finish.Y + 1.2, start.Z) + dir * 0.6
		local face = Vector3.new(dir.X, 0, dir.Z).Unit
		task.spawn(function()
			local t0, length = os.clock(), 0.55
			while f.model.Parent and f.root.Parent do
				local t = math.min(1, (os.clock() - t0) / length)
				local a = start:Lerp(peak, t)
				local b = peak:Lerp(finish, t)
				local pos = a:Lerp(b, t)
				f.root.CFrame = CFrame.lookAt(pos, pos + face)
				f.root.AssemblyLinearVelocity = Vector3.zero
				if t >= 1 then break end
				task.wait()
			end
			f.climbing = false
			f.canalSince = nil
			-- (out: no straight runs for a moment, and a fresh route, so it doesn't turn round and jump straight back in)
			f.noDirectUntil = os.clock() + 4; f.path = nil; f.repathAt = 0; f.pathAt = 0
			pcall(function() f.hum:ChangeState(Enum.HumanoidStateType.Running) end)
		end)
	end
	local function zoneGoal(pos)
		if not ZoneRules then return nil end
		local c = ZoneRules.Circle(shared, workspace:GetServerTimeNow())
		if c and not ZoneRules.Contains(c, pos, 8) then return ZoneRules.Centre(c, pos.Y) end
		return nil
	end

	-- the bots on the in-game players list (Tab): name, eliminations this round and lives, as one JSON attribute
	local HttpService = game:GetService("HttpService")
	local boardAt = 0
	local function publishBoard(now)
		if now < boardAt then return end
		boardAt = now + 1
		local list = {}
		for _, f in pairs(fighters) do table.insert(list, {n = f.name, k = f.kills, l = f.lives, id = f.id}) end
		table.sort(list, function(a, b) return a.id > b.id end)
		local json = #list > 0 and HttpService:JSONEncode(list) or ""
		if shared:GetAttribute("BotBoard") ~= json then shared:SetAttribute("BotBoard", json) end
	end

	local last = os.clock()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock(); local dt = now - last; last = now
			if active then publishBoard(now) end
			if not active or not match:IsPlaying() then continue end
			local everyone = bodies()
			for _, f in pairs(fighters) do
				local m = f.model
				if not m or not aliveModel(m) or not f.root then continue end
				-- tipped over anyway: stand straight back up where it is, facing the way it was going
				if f.root.CFrame.UpVector.Y < 0.75 and not m:GetAttribute("Ragdolled") then
					local look = f.root.CFrame.LookVector
					local flat = Vector3.new(look.X, 0, look.Z)
					if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
					local pos = f.root.Position + Vector3.new(0, 1, 0)
					f.root.CFrame = CFrame.lookAt(pos, pos + flat.Unit)
					f.root.AssemblyAngularVelocity = Vector3.zero
					pcall(function() f.hum:ChangeState(Enum.HumanoidStateType.Running) end)
				end
				local speed = Vector3.new(f.root.AssemblyLinearVelocity.X, 0, f.root.AssemblyLinearVelocity.Z).Magnitude
				-- animation
				local moving = speed > 1.5
				local fast = speed > 17
				if f.walk then if moving and not fast then if not f.walk.IsPlaying then f.walk:Play(0.2) end; f.walk:AdjustSpeed(math.clamp(speed / 12, 0.6, 1.5)) elseif f.walk.IsPlaying then f.walk:Stop(0.25) end end
				if f.run then if fast then if not f.run.IsPlaying then f.run:Play(0.2) end elseif f.run.IsPlaying then f.run:Stop(0.25) end end
				-- stuck? jump, then give up on this route
				if (f.root.Position - f.lastPos).Magnitude > 2 then f.lastPos = f.root.Position; f.stuckAt = now
				elseif now - f.stuckAt > 1.6 then f.hum.Jump = true; maybeAirJump(f); f.path = nil; f.repathAt = 0; f.pathAt = 0; f.noDirectUntil = now + 3; f.stuckAt = now
					if f.target == nil then f.wander = nil end end
				-- in the canal: out first (see canalExit / climbOut)
				if f.climbing then continue end
				-- (which side to climb out is picked once, on the way in, toward whoever it was after -- unless they're down
				-- here too -- and kept: re-picking every tick had two bots in the water swapping sides round each other)
				local wet = f.root.Position.Y <= -4
				if wet and not f.canalEnter then
					f.canalEnter = now
					local preferPt = f.goal
					if f.target and f.target.Parent then
						local tr0 = rootOf(f.target)
						if tr0 then preferPt = tr0.Position.Y > -4 and tr0.Position or nil end
					end
					f.canalPrefer = preferPt
				elseif not wet then
					f.canalEnter = nil
				end
				local exitPoint, exitD = canalExit(f.root.Position, f.canalPrefer)
				if exitPoint and exitD < 30 then
					release(f); sprint(f, true); notebook(f, false); f.read = 0; f.path = nil
					local dir = Vector3.new(exitPoint.X - f.root.Position.X, 0, exitPoint.Z - f.root.Position.Z)
					dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(f.root.CFrame.LookVector.X, 0, f.root.CFrame.LookVector.Z).Unit
					f.hum:MoveTo(exitPoint + dir * 3)
					-- at the wall, or stuck anywhere down there for a couple of seconds: climb out
					if not f.canalSince or (f.root.Position - f.canalPos).Magnitude > 1.5 then f.canalSince, f.canalPos = now, f.root.Position end
					if (exitD < 3.4 or now - f.canalSince > 2 or now - (f.canalEnter or now) > 4) and now > (f.climbTryAt or 0) then
						f.climbTryAt = now + 1
						local landing = landingFor(exitPoint, dir)
						if landing then climbOut(f, landing, dir) end
					end
					continue
				end
				f.canalSince = nil
				-- target: the nearest fighter it can see (keeps the current one while it's still in sight)
				local best, bestD = nil, math.huge
				for _, other in ipairs(everyone) do
					if other ~= m then
						local oh = other:FindFirstChild("Head")
						local orr = rootOf(other)
						if oh and orr and f.head then
							local d = (orr.Position - f.root.Position).Magnitude
							if other == f.target then d -= 20 end
							if d < bestD and d < FILL.SightRange and canSee(f.head, other, oh) then best, bestD = other, d end
						end
					end
				end
				if best ~= f.target then f.read = 0; f.target = best end
				local zone = zoneGoal(f.root.Position)
				local flatVel = Vector3.new(f.root.AssemblyLinearVelocity.X, 0, f.root.AssemblyLinearVelocity.Z)
				local onGround = f.hum.FloorMaterial ~= Enum.Material.Air
				local bursting = now < (f.burstUntil or 0)
				if zone then
					-- the closing zone comes first: sprint (and slide) for the safe area
					release(f); sprint(f, true)
					goTo(f, zone, now)
					if onGround and not bursting and flatVel.Magnitude > 20 then
						if now > f.dashReadyAt and math.random() < 0.12 and not crossCached(f, "burstX", f.root.Position, f.root.Position + flatVel.Unit * 30, now) then dash(f, flatVel.Unit)
						elseif now > f.slideReadyAt and math.random() < 0.15 then slide(f, flatVel.Unit) end
					end
					f.read = math.max(0, f.read - dt)
					notebook(f, false)
				elseif f.target then
					local tr, th = rootOf(f.target), f.target:FindFirstChild("Head")
					local dist = (tr.Position - f.root.Position).Magnitude
					local away = Vector3.new(f.root.Position.X - tr.Position.X, 0, f.root.Position.Z - tr.Position.Z)
					if away.Magnitude < 0.1 then away = Vector3.xAxis end
					-- how long it has been squaring up to this same target: after a while it stops circling and walks in
					-- to finish the read (two bots used to circle each other for ages with nobody dying)
					if f.engagedWith ~= f.target then f.engagedWith, f.engagedAt = f.target, now end
					local commit = dist < 24 and now - (f.engagedAt or now) > 6
					-- across the canal from them: hold the towpath edge and read from there (walking or circling in
					-- drops both into the water, they climb out, see each other again... round and round)
					-- (also when they're down in the water and it's up on the side: let them climb out, don't jump in after them)
					if dist < 40 then
						f.across = (tr.Position.Y < -4 and f.root.Position.Y > -4) or crossCached(f, "acrossX", f.root.Position, tr.Position, now)
					else
						f.across = false
					end
					if dist < 40 and f.across and (dist < 24 or tr.Position.Y < -4) then
						sprint(f, false)
						f.path = nil
						f.hum:MoveTo(f.root.Position)
						face(f, tr.Position)
					elseif dist < 40 and f.across then
						-- out of reading range across the water: the long way round (the route avoids the canal: the bridges)
						release(f); sprint(f, true)
						goTo(f, tr.Position, now)
					elseif dist < 24 and commit then
						sprint(f, false)
						f.hum:MoveTo(tr.Position + away.Unit * 6.5)
						face(f, tr.Position)
					elseif dist < 24 then
						-- in reading range: keep moving, circling round them at walking pace while facing them
						sprint(f, false)
						if now > (f.orbitFlipAt or 0) then f.orbit = -f.orbit; f.orbitFlipAt = now + 2 + math.random() * 3 end
						local ang = math.rad(28) * f.orbit
						local dir = CFrame.Angles(0, ang, 0):VectorToWorldSpace(away.Unit)
						local spot = tr.Position + dir * math.clamp(dist, 11, 16)
						-- (not round into the canal)
						if crossCached(f, "orbitX", f.root.Position, spot, now) then f.orbit = -f.orbit; f.orbitFlipAt = now + 2; spot = f.root.Position end
						f.hum:MoveTo(spot)
						face(f, tr.Position)
						if onGround and not bursting and now > f.dashReadyAt and math.random() < 0.06 then
							local side = CFrame.Angles(0, math.rad(90) * f.orbit, 0):VectorToWorldSpace(away.Unit)
							if not crossCached(f, "dodgeX", f.root.Position, f.root.Position + side * 16, now) then dash(f, side) end
						end
					else
						-- closing in: sprint, slide or dash on straight runs, look where it's running
						release(f); sprint(f, true)
						-- (it can see them: straight at them unless they're up or down a level)
						goTo(f, tr.Position + away.Unit * 13, now, true)
						local toward = -away.Unit
						local straight = flatVel.Magnitude > 18 and flatVel.Unit:Dot(toward) > 0.85
						-- (no slide or dash that would carry it off the edge into the canal)
						if onGround and not bursting and straight and not crossCached(f, "burstX", f.root.Position, f.root.Position + flatVel.Unit * 30, now) then
							if dist > 22 and now > f.dashReadyAt and math.random() < 0.2 then dash(f, flatVel.Unit)
							elseif dist > 26 and dist < 48 and now > f.slideReadyAt and math.random() < 0.12 then slide(f, flatVel.Unit) end
						end
					end
					-- reading: the target's visor has to face the bot, and the bot has to look at it
					local code = f.target:GetAttribute("NumberfallCode")
					if th and f.head and code and dist < 30 then
						local toBot = (f.head.Position - th.Position).Unit
						local shows = th.CFrame.LookVector:Dot(toBot) > (config.FrontDot or 0.05)
						local looks = f.head.CFrame.LookVector:Dot(-toBot) > 0.5
						if shows and looks then f.read = math.min(1, f.read + dt / f.readTime * (commit and 1.5 or 1))
						else f.read = math.max(0, f.read - dt * 0.6) end
					else
						f.read = math.max(0, f.read - dt * 0.6)
					end
					if f.read >= 1 and code then
						f.read = 0
						m:SetAttribute("NoteSnapshot", "Hit|" .. code); f.noteLock = os.clock() + 1.2
						combat:Submit(m, code, workspace:GetServerTimeNow())
					end
					notebook(f, f.read > 0.04 or os.clock() < (f.noteLock or 0), math.clamp(math.floor(f.read * 4.5), 0, 4), code)
				else
					release(f)
					-- roaming: a walk, with the odd sprint between spots
					if now > (f.paceAt or 0) then f.paceAt = now + 4 + math.random() * 6; f.pace = math.random() < 0.35 end
					sprint(f, f.pace == true)
					if f.pace and onGround and not bursting and flatVel.Magnitude > 20 then
						if now > f.dashReadyAt and math.random() < 0.03 and not crossCached(f, "burstX", f.root.Position, f.root.Position + flatVel.Unit * 30, now) then dash(f, flatVel.Unit)
						elseif now > f.slideReadyAt and math.random() < 0.04 then slide(f, flatVel.Unit) end
					end
					if not f.wander or (Vector3.new(f.root.Position.X, 0, f.root.Position.Z) - Vector3.new(f.wander.X, 0, f.wander.Z)).Magnitude < 6 or now > (f.wanderUntil or 0) then
						f.wander = wanderGoal(); f.wanderUntil = now + 25
					end
					goTo(f, f.wander, now)
					f.read = math.max(0, f.read - dt)
					notebook(f, false)
				end
			end
		end
	end)
	return P
end

return B
