-- TUTORIAL. New players are offered a short lesson on the main menu (StarterPlayerScripts.Tutorial shows the offer;
-- Help has a button for it too). Accepting teleports them to a reserved server of this same place: there this
-- module runs the lesson instead of the normal rounds, in the Town Circle with 11 bots, and sends them back to
-- the game when it's done (or when they leave it). Finishing it the first time pays TUTORIAL_REWARD marks.
--   Steps: MOVE -> READ -> WRITE -> ON THE MOVE (3 walkers) -> HIDE YOURS (2 bots that read you) -> LAST FIVE.
-- The lesson is shown to the player through attributes (Tutorial*), drawn by StarterPlayerScripts.Tutorial.
-- Studio: teleports don't work in Studio. Set the ServerStorage attribute TestTutorial = true and press Play to
-- run this server as a tutorial server.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local T = {}
T.REWARD = 250
local STUDIO = RunService:IsStudio()

function T.IsTutorialServer()
	if STUDIO then return ServerStorage:GetAttribute("TestTutorial") == true end
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

------------------------------------------------------------------ teleports
local function sendBack(player)
	if not player or player.Parent ~= Players then return end
	player:SetAttribute("TutorialLeaving", true)
	if STUDIO then
		-- (Studio can't teleport: drop back to the main menu instead)
		player:SetAttribute("InArena", false); player:SetAttribute("InMatch", false)
		pcall(function() player:LoadCharacterAsync() end)
		return
	end
	local data = player:GetJoinData().TeleportData
	local jobId = type(data) == "table" and type(data.ReturnJobId) == "string" and data.ReturnJobId or nil
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData({FromTutorial = true})
	if jobId then opts.ServerInstanceId = jobId end -- back to the server they came from, if it's still there
	local ok = pcall(function() TeleportService:TeleportAsync(game.PlaceId, {player}, opts) end)
	if not ok and jobId then
		local o2 = Instance.new("TeleportOptions"); o2:SetTeleportData({FromTutorial = true})
		pcall(function() TeleportService:TeleportAsync(game.PlaceId, {player}, o2) end)
	end
end
-- the server they came from is full or gone: any public server
TeleportService.TeleportInitFailed:Connect(function(player, _, _, placeId, opts)
	if placeId ~= game.PlaceId or not player:GetAttribute("TutorialLeaving") then return end
	if opts and opts.ServerInstanceId ~= "" then
		local o2 = Instance.new("TeleportOptions"); o2:SetTeleportData({FromTutorial = true})
		task.wait(1)
		pcall(function() TeleportService:TeleportAsync(game.PlaceId, {player}, o2) end)
	end
end)

------------------------------------------------------------------ main servers: the offer
function T.StartOffer(shared, profiles)
	local last = {}
	shared.Menu.OnServerEvent:Connect(function(p, action)
		if action ~= "TutorialStart" and action ~= "TutorialSkip" then return end
		if os.clock() < (last[p] or 0) then return end
		last[p] = os.clock() + 3
		if action == "TutorialSkip" then profiles:MarkTutorial(p, false); return end
		if p:GetAttribute("InArena") then shared.MenuReply:FireClient(p, "Finish your round first."); return end
		profiles:MarkTutorial(p, false)
		if STUDIO then
			shared.MenuReply:FireClient(p, "The tutorial runs in its own server, so it only opens in the published game. (Studio: set ServerStorage.TestTutorial to try it.)")
			return
		end
		shared.MenuReply:FireClient(p, "Loading the tutorial…")
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local opts = Instance.new("TeleportOptions")
			opts.ReservedServerAccessCode = code
			opts:SetTeleportData({Tutorial = true, ReturnJobId = game.JobId})
			TeleportService:TeleportAsync(game.PlaceId, {p}, opts)
		end)
		if not ok then
			warn("[Tutorial] teleport failed: " .. tostring(err))
			shared.MenuReply:FireClient(p, "Couldn't open the tutorial right now. Try again in a moment.")
		end
	end)
	Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
end

------------------------------------------------------------------ tutorial servers: the lesson
local NAMES = {"ASH", "WREN", "SILAS", "MARA", "JUDE", "ORIN", "VESPER", "ROOK", "IVY", "COLE", "NELL"}
local SKINS = {Color3.fromRGB(234, 192, 160), Color3.fromRGB(204, 142, 105), Color3.fromRGB(141, 85, 54), Color3.fromRGB(96, 59, 38),
	Color3.fromRGB(245, 205, 180), Color3.fromRGB(176, 118, 82)}
local CENTRE = Vector3.new(1305.18, 0, 131.76) -- the Town Circle (its ring road is clear from r 36 to r 50)
local RING_MIN, RING_MAX = 38, 47
local function ringPoint(angleDeg, r) local a = math.rad(angleDeg); return CENTRE + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r) end
local function angleOf(p) local d = p - CENTRE; return math.deg(math.atan2(d.Z, d.X)) end

local STEPS = {
	{Id = "MOVE", Title = "MOVE", Text = "WASD to move, hold SHIFT to sprint, SPACE to jump. Run to the red beacon."},
	{Id = "READ", Title = "READ", Text = "Every visor shows a four-digit number. Walk up to the bot and look at its visor."},
	{Id = "WRITE", Title = "WRITE", Text = "Press E (or just start typing), type the number you see and press ENTER to mark them."},
	{Id = "MOVING", Title = "ON THE MOVE", Text = "Targets move. Chase these three down and mark them all."},
	{Id = "HIDE", Title = "HIDE YOURS", Text = "These two read numbers too: watch their notebooks come out. If you can see their visor, they can see yours, so mark them first."},
	{Id = "LAST", Title = "LAST FIVE", Text = "Five left, and they come for you one at a time. Sprint, slide, come at them from the side: mark them all."},
	{Id = "DONE", Title = "TUTORIAL COMPLETE", Text = "You're ready. Taking you back to MARKED…"},
}

function T.RunTutorial(deps)
	local shared, combat, match, forehead, ragdolls, movement, profiles, config =
		deps.shared, deps.combat, deps.match, deps.forehead, deps.ragdolls, deps.movement, deps.profiles, deps.config
	local Hair = require(script.Parent:WaitForChild("Hair"))
	local Outfits = require(RS.Numberfall:WaitForChild("Outfits"))
	local HairCatalog = require(RS.Numberfall:WaitForChild("HairCatalog"))
	local tint = Color3.fromRGB(table.unpack(config.Teams.FFA.RGB))
	shared:SetAttribute("TutorialServer", true)
	shared:SetAttribute("Mode", "TUTORIAL")
	match:SetPhase("Playing", 3600)
	shared:SetAttribute("RoundId", 1)
	shared:SetAttribute("RoundStartedAt", workspace:GetServerTimeNow())

	local folder = Instance.new("Folder"); folder.Name = "TutorialBots"; folder.Parent = workspace
	local bots = {}
	local student -- the player taking the lesson
	local stepIndex = 0
	local marked = 0
	local TOTAL = 11

	-- outfits a bot can wear, and hair colours
	local outfitIds = {}
	for id in pairs(Outfits.ById) do table.insert(outfitIds, id) end
	table.sort(outfitIds)
	local hairColors = {}
	for k, v in pairs(HairCatalog.Colors or {}) do table.insert(hairColors, type(k) == "string" and k or (type(v) == "table" and v.Id) or v) end

	------------------------------------------------ the beacon (step 1)
	local beacon
	local function makeBeacon(pos)
		local m = Instance.new("Model"); m.Name = "TutorialBeacon"
		local ring = Instance.new("Part"); ring.Name = "Ring"; ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 9, 9); ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.Neon; ring.Color = Color3.fromRGB(255, 30, 60); ring.Transparency = 0.25
		local beam = Instance.new("Part"); beam.Name = "Beam"; beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(40, 3, 3); beam.CFrame = CFrame.new(pos + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Material = Enum.Material.Neon; beam.Color = Color3.fromRGB(255, 40, 70); beam.Transparency = 0.7
		for _, p in ipairs({ring, beam}) do p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Parent = m end
		local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 40, 70); light.Range = 18; light.Brightness = 2; light.Parent = ring
		m.Parent = workspace
		return m
	end

	------------------------------------------------ bots
	local ANIMS = config.Animations or {}
	local function newBot(index, cf, mode)
		local desc = Instance.new("HumanoidDescription")
		local skin = SKINS[(index - 1) % #SKINS + 1]
		for _, k in ipairs({"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor"}) do desc[k] = skin end
		local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
		if not ok or not model then warn("[Tutorial] couldn't build a bot: " .. tostring(model)); return nil end
		local name = NAMES[index] or ("BOT " .. index)
		model.Name = name
		model:SetAttribute("DisplayName", name)
		model:SetAttribute("BotId", -index)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		local animate = model:FindFirstChild("Animate"); if animate then animate:Destroy() end
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.NameDisplayDistance = 0; hum.HealthDisplayDistance = 0
		hum.WalkSpeed = 0; hum.UseJumpPower = true; hum.JumpPower = 0
		hum.BreakJointsOnDeath = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		local head = model:FindFirstChild("Head")
		if head then
			local face = head:FindFirstChild("face") or Instance.new("Decal")
			face.Name = "face"; face.Face = Enum.NormalId.Front; face.Texture = "rbxasset://textures/face.png"; face.Parent = head
		end
		model:PivotTo(cf + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0))
		model.Parent = folder
		pcall(function() root:SetNetworkOwner(nil) end)
		-- look: an outfit, the visor with its number, hair in a random colour
		pcall(function() Outfits.Apply(model, outfitIds[(index * 5) % #outfitIds + 1], skin, Outfits.DefaultColorway) end)
		local record = {Character = model, Humanoid = hum, Side = "Bot" .. index, ColorSide = "FFA", Name = name, UserId = -index, Bot = true}
		local code = combat:Register(model, record)
		forehead.Attach(model, code, tint, config)
		if #hairColors > 0 then pcall(function() Hair.Equip(model, nil, hairColors[(index * 3) % #hairColors + 1]) end) end
		model:SetAttribute("NumberfallSide", "FFA")
		CollectionService:AddTag(model, "MarkedBot")
		pcall(function() ragdolls:Prepare(model) end)
		-- animations (played on the server: they replicate to everyone)
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local function load(id)
			if not id then return nil end
			local a = Instance.new("Animation"); a.AnimationId = "rbxassetid://" .. id
			local ok2, track = pcall(function() return animator:LoadAnimation(a) end)
			return ok2 and track or nil
		end
		local bot = {index = index, model = model, hum = hum, root = root, head = head, mode = mode, read = 0,
			idle = load(ANIMS.Idle1), walk = load(ANIMS.Walk), run = load(ANIMS.Run), target = nil, retargetAt = 0, alive = true}
		if bot.idle then bot.idle.Looped = true; bot.idle:Play() end
		if bot.walk then bot.walk.Looped = true end
		if bot.run then bot.run.Looped = true end
		hum.Died:Once(function()
			bot.alive = false
			combat:Remove(model, model)
			pcall(function() ragdolls:Activate(model) end)
			pcall(function() forehead.Dead(model, config) end)
			CollectionService:RemoveTag(model, "MarkedBot")
			for _, tr in ipairs({bot.idle, bot.walk, bot.run}) do if tr then tr:Stop(0.1) end end
			model:SetAttribute("NotebookOut", false)
			-- once the body has dropped, hold it still (so it can't slide or sink while it fades)
			task.delay(1.4, function()
				for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
			end)
			task.delay(3, function()
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("BasePart") then
						game:GetService("TweenService"):Create(d, TweenInfo.new(1), {Transparency = 1}):Play()
					end
				end
				task.delay(1.1, function() model:Destroy() end)
			end)
		end)
		bots[model] = bot
		return bot
	end

	------------------------------------------------ the lesson's state, shown to the player
	local function publish()
		if not student then return end
		local s = STEPS[stepIndex]
		student:SetAttribute("TutorialStep", s and s.Id or nil)
		student:SetAttribute("TutorialStepIndex", stepIndex)
		student:SetAttribute("TutorialStepCount", #STEPS - 1)
		student:SetAttribute("TutorialTitle", s and s.Title or nil)
		student:SetAttribute("TutorialText", s and s.Text or nil)
		student:SetAttribute("TutorialMarked", marked)
		student:SetAttribute("TutorialTotal", TOTAL)
	end
	local stepBots = {}
	local function aliveCount(list) local n = 0; for _, b in ipairs(list) do if b.alive then n += 1 end end; return n end
	local function spawnGroup(fromIndex, count, mode, startAngle, spread)
		local list = {}
		for i = 0, count - 1 do
			local a = startAngle + i * spread
			local pos = ringPoint(a, (RING_MIN + RING_MAX) / 2 + (i % 2 == 0 and -3 or 3))
			local studentRoot = student and student.Character and student.Character:FindFirstChild("HumanoidRootPart")
			local lookAt = studentRoot and Vector3.new(studentRoot.Position.X, 0, studentRoot.Position.Z) or CENTRE
			local b = newBot(fromIndex + i, CFrame.lookAt(pos, lookAt), mode)
			if b then table.insert(list, b) end
		end
		return list
	end

	local function studentRoot()
		local c = student and student.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and h and h.Health > 0 then return r, c, h end
		return nil
	end

	local function goStep(i)
		stepIndex = i
		local s = STEPS[i]
		if s.Id == "MOVE" then
			beacon = makeBeacon(ringPoint(36, 43))
		elseif s.Id == "READ" then
			if beacon then beacon:Destroy(); beacon = nil end
			stepBots = spawnGroup(1, 1, "idle", 52, 0)
		elseif s.Id == "MOVING" then
			stepBots = spawnGroup(2, 3, "wander", 100, 40)
		elseif s.Id == "HIDE" then
			stepBots = spawnGroup(5, 2, "hunt", 200, 60)
		elseif s.Id == "LAST" then
			stepBots = spawnGroup(7, 5, "hunt", 280, 50)
		elseif s.Id == "DONE" then
			local reward = profiles:MarkTutorial(student, true, T.REWARD) or 0
			student:SetAttribute("TutorialReward", reward)
			student:SetAttribute("TutorialRead", 0)
			local who = student
			task.delay(9, function() sendBack(who) end)
		end
		publish()
	end

	------------------------------------------------ the student
	local function placeStudent(character)
		local hum = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not hum or not root then return end
		-- after CharacterService has dressed them and settled them on a match spawn (it marks the character with
		-- NumberfallSide once it has, and pivots once more on the next Heartbeat)
		local t0 = os.clock()
		while character.Parent and character:GetAttribute("NumberfallSide") == nil and os.clock() - t0 < 8 do task.wait(0.05) end
		RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait()
		if character.Parent == nil then return end
		-- first spawn: the start of the ring; later (after being marked): somewhere quiet on the ring
		local angle = stepIndex <= 1 and 0 or (angleOf(root.Position) + 180)
		local pos = ringPoint(stepIndex <= 1 and 0 or angle, 43) + Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 0.2, 0)
		local ahead = ringPoint((stepIndex <= 1 and 0 or angle) + 20, 43)
		pcall(function() student:RequestStreamAroundAsync(pos, 5) end)
		character:PivotTo(CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)))
		student:SetAttribute("Lives", 3)
	end
	local function join(p)
		if student and student.Parent == Players then return end
		student = p
		local t0 = os.clock()
		while p.Parent == Players and p:GetAttribute("ProfileReady") ~= true and os.clock() - t0 < 12 do task.wait(0.2) end
		if p.Parent ~= Players then return end
		p:SetAttribute("MatchEnteredAt", workspace:GetServerTimeNow())
		p:SetAttribute("RoundNumbers", 0)
		p:SetAttribute("InMatch", true)
		p:SetAttribute("Ready", true)
		p:SetAttribute("InArena", true)
		p:SetAttribute("Lives", 3)
		match.participants[p.UserId] = true
		p.CharacterAdded:Connect(function(c) task.spawn(placeStudent, c) end)
		pcall(function() p:LoadCharacterAsync() end)
		-- leaving the arena (main menu key, etc.) ends the tutorial
		p:GetAttributeChangedSignal("InMatch"):Connect(function()
			if p:GetAttribute("InMatch") ~= true and not p:GetAttribute("TutorialLeaving") then sendBack(p) end
		end)
		if stepIndex == 0 then goStep(1) else publish() end
	end
	Players.PlayerAdded:Connect(function(p) task.spawn(join, p) end)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(join, p) end
	shared.Menu.OnServerEvent:Connect(function(p, action)
		if action == "TutorialLeave" then sendBack(p) end
	end)
	-- the reserved server shuts down once its player has gone
	Players.PlayerRemoving:Connect(function(p) if p == student then student = nil end end)

	------------------------------------------------ the loop
	-- seconds a bot needs to read your visor (one bot hunts you at a time: the closest one; the rest wander)
	local readTime = {HIDE = 5.5, LAST = 4.5}
	local hunter -- the bot currently after the student
	local graceUntil = 0 -- a breather after being marked
	-- the bot's notebook (drawn by every client's NotebookController, like a player's): out while it reads you,
	-- the digits of your number appearing as it gets closer to reading it all
	local function notebook(bot, out, digits, code)
		local m = bot.model
		if m:GetAttribute("NotebookOut") ~= out then m:SetAttribute("NotebookOut", out) end
		if os.clock() < (bot.noteLock or 0) then return end
		local snap = "Ready|" .. ((out and code) and code:sub(1, digits) or "")
		if m:GetAttribute("NoteSnapshot") ~= snap then m:SetAttribute("NoteSnapshot", snap) end
	end
	local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local function canSee(fromHead, toChar, toHead)
		rayParams.FilterDescendantsInstances = {fromHead.Parent, folder}
		local hit = workspace:Raycast(fromHead.Position, toHead.Position - fromHead.Position, rayParams)
		return hit and hit.Instance:IsDescendantOf(toChar)
	end
	local function face(bot, pos)
		local r = bot.root
		local flat = Vector3.new(pos.X, r.Position.Y, pos.Z)
		if (flat - r.Position).Magnitude < 0.5 then return end
		bot.hum.AutoRotate = false
		r.CFrame = r.CFrame:Lerp(CFrame.lookAt(r.Position, flat), 0.35)
	end
	local function wander(bot, now)
		local pos = bot.root.Position
		if not bot.target or (Vector3.new(pos.X, 0, pos.Z) - bot.target).Magnitude < 3 or now > bot.retargetAt then
			local a = angleOf(pos) + (math.random() < 0.5 and -1 or 1) * math.random(20, 50)
			bot.target = ringPoint(a, math.random(RING_MIN, RING_MAX))
			bot.retargetAt = now + 6
		end
		bot.hum.AutoRotate = true
		bot.hum:MoveTo(bot.target)
	end
	local last = os.clock()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last; last = now
		local sRoot, sChar, sHum = studentRoot()
		local sHead = sChar and sChar:FindFirstChild("Head")
		local s = STEPS[stepIndex]
		local maxRead = 0
		local sCode = sChar and sChar:GetAttribute("NumberfallCode")
		-- pick the hunter: the closest living hunt bot (the current one keeps the job unless another is much closer)
		do
			local best, bestD = nil, math.huge
			for _, bot in pairs(bots) do
				if bot.alive and bot.mode == "hunt" and sRoot then
					local d = (bot.root.Position - sRoot.Position).Magnitude
					if bot == hunter then d -= 15 end
					if d < bestD then best, bestD = bot, d end
				end
			end
			if hunter ~= best then if hunter then hunter.read = 0 end; hunter = best end
		end
		for model, bot in pairs(bots) do
			if not bot.alive or not model.Parent then bots[model] = nil; continue end
			local speed = Vector3.new(bot.root.AssemblyLinearVelocity.X, 0, bot.root.AssemblyLinearVelocity.Z).Magnitude
			-- animation
			if bot.walk then
				if speed > 1 then
					if not bot.walk.IsPlaying then bot.walk:Play(0.2) end
					bot.walk:AdjustSpeed(math.clamp(speed / 12, 0.6, 1.6))
				elseif bot.walk.IsPlaying then bot.walk:Stop(0.25) end
			end
			if bot.mode == "idle" then
				bot.hum.WalkSpeed = 0
				if sRoot then face(bot, sRoot.Position) end
			elseif bot.mode == "wander" or (bot.mode == "hunt" and bot ~= hunter) then
				bot.hum.WalkSpeed = 9
				wander(bot, now)
				bot.read = 0
				notebook(bot, false)
			elseif bot.mode == "hunt" then
				bot.hum.WalkSpeed = 10
				local dist = sRoot and (sRoot.Position - bot.root.Position).Magnitude or math.huge
				local sees = sRoot and sHead and bot.head and dist < 70 and canSee(bot.head, sChar, sHead)
				if sees and dist < 17 then
					bot.hum:MoveTo(bot.root.Position)
					face(bot, sRoot.Position)
				elseif sees then
					local dir = (bot.root.Position - sRoot.Position)
					local goal = sRoot.Position + Vector3.new(dir.X, 0, dir.Z).Unit * 13
					bot.hum.AutoRotate = true
					bot.hum:MoveTo(goal)
				else
					wander(bot, now)
				end
				-- reading the student's visor
				local rt = s and readTime[s.Id]
				if rt and sees and dist < 28 and sHead and bot.head and now > graceUntil then
					local toBot = (bot.head.Position - sHead.Position).Unit
					local studentShows = sHead.CFrame.LookVector:Dot(toBot) > (config.FrontDot or 0.05)
					local botLooks = bot.head.CFrame.LookVector:Dot(-toBot) > 0.5
					if studentShows and botLooks then bot.read = math.min(1, bot.read + dt / rt)
					else bot.read = math.max(0, bot.read - dt * 0.6) end
				else
					bot.read = math.max(0, bot.read - dt * 0.6)
				end
				if bot.read >= 1 and sChar then
					-- the bot writes the student's number
					bot.read = 0
					for _, other in pairs(bots) do other.read = 0 end
					graceUntil = now + 5
					if sCode then
						model:SetAttribute("NoteSnapshot", "Hit|" .. sCode); bot.noteLock = os.clock() + 1.2
						combat:Submit(model, sCode, workspace:GetServerTimeNow())
					end
				end
				notebook(bot, bot.read > 0.04 or os.clock() < (bot.noteLock or 0), math.clamp(math.floor(bot.read * 4.5), 0, 4), sCode)
				maxRead = math.max(maxRead, bot.read)
			end
		end
		if student then
			local shown = math.floor(maxRead * 20 + 0.5) / 20
			if student:GetAttribute("TutorialRead") ~= shown then student:SetAttribute("TutorialRead", shown) end
			if (student:GetAttribute("Lives") or 3) < 3 and sHum then student:SetAttribute("Lives", 3) end
		end
		-- step progress
		if s and student then
			if s.Id == "MOVE" then
				if sRoot and beacon and (Vector3.new(sRoot.Position.X, 0, sRoot.Position.Z) - ringPoint(36, 43)).Magnitude < 7 then goStep(2) end
			elseif s.Id == "READ" then
				local b = stepBots[1]
				if b and b.alive and sRoot and sHead and b.head then
					local d = (b.head.Position - sHead.Position)
					local cam = sHead.CFrame.LookVector
					if d.Magnitude < 24 and cam:Dot(d.Unit) > 0.6 then
						b.seen = (b.seen or 0) + dt
						if b.seen > 0.8 then goStep(3) end
					end
				elseif b and not b.alive then goStep(4) end
			else
				local before = marked
				local dead = 0
				for _, b in ipairs(stepBots) do if not b.alive then dead += 1 end end
				local done = ({WRITE = 0, MOVING = 1, HIDE = 4, LAST = 6})[s.Id]
				if done then
					marked = done + dead
					if marked ~= before then publish() end
					if aliveCount(stepBots) == 0 and #stepBots > 0 then
						task.wait(1.2)
						goStep(stepIndex + 1)
					end
				end
			end
		end
		-- keep the round clock from running out
		if match.endsAt - workspace:GetServerTimeNow() < 600 then match:SetPhase("Playing", 3600) end
	end
end

return T
