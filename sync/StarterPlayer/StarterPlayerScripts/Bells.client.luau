-- church bells: always rocking gently on their beams, and swinging hard while the round bell tolls
-- (round start, and again with one minute left). The toll sound itself is played by Client/SoundController.
local CollectionService = game:GetService("CollectionService")
local Run = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local bells = {}
local function add(b)
	for _, e in ipairs(bells) do if e.part == b then return end end
	if b:IsA("Model") then
		-- modelled bell: its pivot sits on the headstock axis, so swing the whole model about it
		local root = b.PrimaryPart
		local base = b:GetPivot()
		table.insert(bells, {part = b, model = true, root = root, base = base, offset = root and base:ToObjectSpace(root.CFrame), phase = math.random() * 6.28, speed = 1.3 + math.random() * 0.4})
	elseif b:IsA("BasePart") then
		table.insert(bells, {part = b, base = b.CFrame, pivot = b.CFrame * CFrame.new(0, b.Size.Y * 0.62, 0), phase = math.random() * 6.28, speed = 1.6 + math.random() * 0.5})
	end
end
for _, b in ipairs(CollectionService:GetTagged("SwingBell")) do add(b) end
CollectionService:GetInstanceAddedSignal("SwingBell"):Connect(add)
CollectionService:GetInstanceRemovedSignal("SwingBell"):Connect(function(b)
	for i, e in ipairs(bells) do if e.part == b then table.remove(bells, i) break end end
end)
-- toll energy: jumps up when the bell tolls and dies away over ~10 s
local energy, lastPhase, minuteRound = 0, nil, nil
local function toll() energy = 1 end
shared:GetAttributeChangedSignal("Phase"):Connect(function()
	local phase = shared:GetAttribute("Phase")
	if phase == "Playing" and lastPhase ~= "Playing" then toll() end
	lastPhase = phase
end)
lastPhase = shared:GetAttribute("Phase")
local t = 0
local frameNo = 0
Run.Heartbeat:Connect(function(dt)
	t += dt
	if shared:GetAttribute("Phase") == "Playing" then
		local left = (shared:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()
		local round = shared:GetAttribute("RoundId")
		if left <= 60 and left > 55 and minuteRound ~= round then minuteRound = round; toll() end
	end
	energy = math.max(0, energy - dt * 0.09)
	local amp = math.rad(14) + math.rad(38) * energy
	-- (each bell is ~290 welded parts: only the ones near the camera swing every frame, mid-range ones every
	-- third frame, and far ones not at all -- nobody can see a bell rock from across the map)
	frameNo += 1
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	for _, b in ipairs(bells) do
		local d = (b.base.Position - eye).Magnitude
		if b.part.Parent and (d < 160 or (d < 380 and frameNo % 3 == 0)) then
			local speed = b.speed * (1 + energy * 0.35)
			local a = math.sin(t * speed + b.phase) * amp * (energy > 0.05 and 1 or (0.6 + 0.4 * math.sin(t * 0.13 + b.phase)))
			if b.model then
				if b.root then b.root.CFrame = b.base * CFrame.Angles(a, 0, 0) * b.offset else b.part:PivotTo(b.base * CFrame.Angles(a, 0, 0)) end
			else
				b.part.CFrame = b.pivot * CFrame.Angles(a, 0, 0) * b.pivot:ToObjectSpace(b.base)
			end
		end
	end
end)
