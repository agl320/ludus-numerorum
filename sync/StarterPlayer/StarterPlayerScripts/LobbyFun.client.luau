-- Lobby belfry bell (client): one toll per ring, heard only in the lobby; prompt shows the 30 s cooldown.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local ev = shared:WaitForChild("LobbyBell")
local climb = workspace:WaitForChild("Lobby"):WaitForChild("NewSquare"):WaitForChild("Fun"):WaitForChild("BelfryClimb")
local anchor = climb:WaitForChild("BellPrompt")
local prompt = anchor:WaitForChild("ProximityPrompt")
local COOLDOWN = 30

ev.OnClientEvent:Connect(function()
	if player:GetAttribute("InArena") == true then return end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://77402059079473"; s.Volume = 0.85; s.PlaybackSpeed = 0.95
	s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = 30; s.RollOffMaxDistance = 600
	s.Parent = anchor
	s:Play()
	task.delay(2.6, function() -- one strike only: fade before the sample repeats
		TweenService:Create(s, TweenInfo.new(0.6), {Volume = 0}):Play()
		task.delay(0.7, function() s:Destroy() end)
	end)
end)

local cooling = false
prompt.Triggered:Connect(function()
	if cooling then return end
	cooling = true
	for t = COOLDOWN, 1, -1 do
		prompt.ActionText = "Ring again in " .. t .. "s"
		task.wait(1)
	end
	prompt.ActionText = "Ring Bell"
	cooling = false
end)

------------------------------------------------------------------ CAROUSEL
-- spins the canopy and sends the horses round, bobbing on their poles (client-side only)
local RunService = game:GetService("RunService")
local carousel = climb.Parent:WaitForChild("Carousel")
local spinRoot = carousel:WaitForChild("Spinner"):WaitForChild("SpinRoot")
local centre = CFrame.new(spinRoot.Position)
local rootRel = centre:ToObjectSpace(spinRoot.CFrame)
local horses = {}
for _, h in ipairs(carousel:WaitForChild("Horses"):GetChildren()) do
	if h.PrimaryPart then
		table.insert(horses, {part = h.PrimaryPart, rel = centre:ToObjectSpace(h.PrimaryPart.CFrame), phase = (h:GetAttribute("Angle") or 0) * 2})
	end
end
-- the spin runs off the server clock so every client's horses are in the same place: a rider on your screen
-- is on the same horse on everyone else's
local function clock() return workspace:GetServerTimeNow() end
-- RIDING: jump onto a horse and you sit on it and go round with it; jump again to hop off. The horses only move on
-- the client, so the rider is carried by setting their root each frame (that position replicates as usual).
local UIS = game:GetService("UserInputService")
local riding -- {horse=entry, hum=, root=}
local cooldown = 0
-- above the horse's back, root height when seated; set back along the horse (-X) so the rider sits behind the pole
-- (it stands 0.58 forward of the horse's middle and used to pass through the rider's chest)
local SADDLE = CFrame.new(-0.62, 1.035 + 1.55, 0)
for _, h in ipairs(horses) do h.model = h.part.Parent end
local function dismount(hop)
	local r = riding
	if not r then return end
	riding = nil
	cooldown = os.clock() + 0.7
	if r.hum.Parent then
		r.hum.Sit = false
		if hop and r.root.Parent then
			local side = r.horse.part.CFrame.ZVector
			r.root.CFrame = r.root.CFrame + side * 2.6 + Vector3.new(0, 0.6, 0)
			r.root.AssemblyLinearVelocity = side * 10 + Vector3.new(0, 28, 0)
		end
		r.hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end
UIS.JumpRequest:Connect(function()
	if riding then dismount(true) end
end)
-- the round starting (or anything taking you out of the lobby) gets you off the horse first, standing, so the
-- teleport into the arena isn't pulled back to the carousel and you don't arrive still sitting
for _, attr in ipairs({"InMatch", "InArena", "IntroPlaying"}) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if riding and player:GetAttribute(attr) == true then dismount(false) end
	end)
end
player.CharacterAdded:Connect(function() if riding then riding = nil end end)
local function tryMount()
	if riding or os.clock() < cooldown then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) or hum.Health <= 0 or hum.Sit then return end
	-- (anyone above a horse's back got there by jumping: walking past, your root is well below it)
	for _, h in ipairs(horses) do
		local rel = h.part.CFrame:PointToObjectSpace(root.Position)
		if math.abs(rel.X) < 2.6 and math.abs(rel.Z) < 2.2 and rel.Y > 0.4 and rel.Y < 5 then
			riding = {horse = h, hum = hum, root = root}
			hum.Sit = true
			return
		end
	end
end
RunService.RenderStepped:Connect(function()
	if player:GetAttribute("InArena") == true then if riding then dismount(false) end return end
	local cam = workspace.CurrentCamera
	if not riding and cam and (cam.CFrame.Position - centre.Position).Magnitude > 250 then return end
	local t = clock()
	-- (wrap the angle here: the server clock is ~1.8e9 s, far past what a CFrame angle keeps precisely)
	local rot = centre * CFrame.Angles(0, -((t * 0.35) % (math.pi * 2)), 0)
	spinRoot.CFrame = rot * rootRel
	for _, h in ipairs(horses) do
		-- a gallop: rising nose-up, coming down nose-down
		local ph = (t * 1.6) % (math.pi * 2) + h.phase
		h.part.CFrame = rot * CFrame.new(0, math.sin(ph) * 0.6, 0) * h.rel * CFrame.Angles(0, 0, math.cos(ph) * 0.07)
	end
	if riding then
		local r = riding
		if not (r.root.Parent and r.hum.Parent) or r.hum.Health <= 0 or not r.hum.Sit then dismount(false) return end
		-- something else moved the character (the round's teleport, a respawn): let go instead of dragging it back
		if r.lastPos and (r.root.Position - r.lastPos).Magnitude > 4 then dismount(false) return end
		local cf = r.horse.part.CFrame * SADDLE
		r.root.CFrame = CFrame.lookAt(cf.Position, cf.Position + r.horse.part.CFrame.XVector)
		r.lastPos = r.root.Position
		r.root.AssemblyLinearVelocity = Vector3.zero
		r.root.AssemblyAngularVelocity = Vector3.zero
	else
		tryMount()
	end
end)

------------------------------------------------------------------ LOBBY LIGHT
-- the lobby square sits in the same dusk as the city; lift the exposure a little while you're in it
local Lighting = game:GetService("Lighting")
local LOBBY_EXPOSURE, ARENA_EXPOSURE = 0.55, Lighting.ExposureCompensation
local function applyLight()
	local inLobby = player:GetAttribute("InArena") ~= true and player:GetAttribute("IntroPlaying") ~= true
	-- (exposure is set by StarterPlayerScripts.DayNight, which adds the lobby lift itself)
	local _ = inLobby and LOBBY_EXPOSURE or ARENA_EXPOSURE
end
player:GetAttributeChangedSignal("InArena"):Connect(applyLight)
player:GetAttributeChangedSignal("IntroPlaying"):Connect(applyLight)
applyLight()
