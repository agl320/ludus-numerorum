-- Wall movement effects (everyone's, drawn on each client):
--  * catching a wall (hang start / a launch landing on the next building): a dust burst off the wall and a red
--    shock ring where the hands hit
--  * wall launches: a trail of afterimages (styled by rank -- Numberfall.Afterimages; dashes get theirs from AbilityFX)
-- Reads the movement attributes: own body WallHang (local), others Hanging / WallCatchAt / WallLaunchAt / DashAt
-- (mirrored by MovementService). Bots are included. Nothing beyond FX_RANGE studs from the camera.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local FX_RANGE = 170
local ACCENT = Color3.fromRGB(255, 58, 74)
local BODY = {
	Head = true, UpperTorso = true, LowerTorso = true, Torso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}

local folder = Instance.new("Folder")
folder.Name = "WallFX"
folder.Parent = workspace

local function lowEnd() return player:GetAttribute("LowEnd") == true end
local function near(pos)
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - pos).Magnitude < FX_RANGE
end

-- dust off the wall + a shock ring at the hands
local function burst(pos, normal, strength)
	if not near(pos) then return end
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency, anchor.Size = 1, Vector3.one * 0.2
	anchor.CFrame = CFrame.lookAt(pos, pos + normal)
	anchor.Parent = folder
	local at = Instance.new("Attachment")
	at.Parent = anchor
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 182, 168), Color3.fromRGB(120, 110, 104))
	dust.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
	dust.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.6)})
	dust.Lifetime = NumberRange.new(0.45, 0.8)
	dust.Speed = NumberRange.new(7, 15)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Drag = 6
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-90, 90)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Enabled = false
	dust.Parent = at
	local chips = Instance.new("ParticleEmitter")
	chips.Color = ColorSequence.new(Color3.fromRGB(150, 138, 126))
	chips.LightEmission = 0
	chips.Size = NumberSequence.new(0.18, 0.05)
	chips.Lifetime = NumberRange.new(0.35, 0.6)
	chips.Speed = NumberRange.new(14, 26)
	chips.SpreadAngle = Vector2.new(55, 55)
	chips.Acceleration = Vector3.new(0, -60, 0)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.Enabled = false
	chips.Parent = at
	local n = lowEnd() and 0.5 or 1
	dust:Emit(math.floor(12 * strength * n + 0.5))
	chips:Emit(math.floor(10 * strength * n + 0.5))
	-- the shock ring, flat on the wall
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = ACCENT
	ring.Transparency = 0.15
	ring.Size = Vector3.new(0.06, 0.8, 0.8)
	ring.CFrame = CFrame.lookAt(pos + normal * 0.08, pos + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = folder
	local s = 4.5 + 3 * strength
	TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.02, s, s), Transparency = 1}):Play()
	Debris:AddItem(ring, 0.35)
	Debris:AddItem(anchor, 1.2)
end

-- afterimages (styled by rank: ReplicatedStorage.Numberfall.Afterimages)
local Afterimages = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Afterimages"))
local function trail(character, duration) Afterimages.Trail(character, duration) end

local tracked = {}
local function track(character)
	if tracked[character] then return end
	tracked[character] = {hanging = false, catchAt = character:GetAttribute("WallCatchAt"), launchAt = character:GetAttribute("WallLaunchAt"),
		dashAt = character:GetAttribute("DashAt")}
end
local function watchPlayer(p)
	if p.Character then track(p.Character) end
	p.CharacterAdded:Connect(track)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)
for _, bot in ipairs(CollectionService:GetTagged("MarkedBot")) do track(bot) end
CollectionService:GetInstanceAddedSignal("MarkedBot"):Connect(track)

Run.Heartbeat:Connect(function()
	local mine = player.Character
	for character, st in pairs(tracked) do
		if not character.Parent then tracked[character] = nil
		else
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local hanging
				if character == mine then hanging = character:GetAttribute("WallHang") == true
				else hanging = character:GetAttribute("Hanging") == true end
				local look = root.CFrame.LookVector
				local wallNormal = -Vector3.new(look.X, 0, look.Z).Unit
				local hands = root.Position - wallNormal * 1.2 + Vector3.new(0, 1.2, 0)
				-- grabbed a wall: dust + ring (bigger when a launch lands you on it)
				local catchAt = character:GetAttribute("WallCatchAt")
				local caught = catchAt ~= st.catchAt
				st.catchAt = catchAt
				if hanging and not st.hanging then burst(hands, wallNormal, caught and 1.4 or 0.9)
				elseif caught and hanging then burst(hands, wallNormal, 1.4) end
				-- launched off a wall: a kick of dust where you left and an afterimage trail
				local launchAt = character:GetAttribute("WallLaunchAt")
				local launched = false
				if launchAt ~= st.launchAt then
					launched = true
					st.launchAt = launchAt
					if launchAt and workspace:GetServerTimeNow() - launchAt < 0.6 and os.clock() - (st.launchTrailAt or -1) > 0.5 then
						st.launchTrailAt, st.trailAt = os.clock(), os.clock()
						if st.hanging or hanging then burst(hands, wallNormal, 1) end
						trail(character, 0.42)
					end
				end
				-- (dash afterimages are drawn by AbilityFX, in step with the dash wind)
				st.hanging = hanging
			end
		end
	end
end)
