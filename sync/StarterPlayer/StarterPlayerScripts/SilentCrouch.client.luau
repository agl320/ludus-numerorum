-- Crouching is silent: mutes the footstep sounds of any crouching character (yours and everyone else's).
-- Roblox plays character sounds on each client, so every player hears the crouch as silent.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MUTED = {Running = true, Climbing = true, Landing = true}
local tracked = {}

local function apply(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local quiet = character:GetAttribute("Crouching") == true
	for _, s in ipairs(root:GetChildren()) do
		if s:IsA("Sound") and MUTED[s.Name] then
			if s:GetAttribute("BaseVolume") == nil then s:SetAttribute("BaseVolume", s.Volume) end
			local target = quiet and 0 or s:GetAttribute("BaseVolume")
			TweenService:Create(s, TweenInfo.new(0.15), {Volume = target}):Play()
		end
	end
end

local function track(character)
	if tracked[character] then return end
	tracked[character] = true
	character:GetAttributeChangedSignal("Crouching"):Connect(function() apply(character) end)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		root.ChildAdded:Connect(function(c) if c:IsA("Sound") and MUTED[c.Name] then task.defer(apply, character) end end)
		task.delay(1, apply, character) -- RbxCharacterSounds creates the sounds a moment after spawn
	end
	character.Destroying:Connect(function() tracked[character] = nil end)
end

local function watch(p)
	if p.Character then task.spawn(track, p.Character) end
	p.CharacterAdded:Connect(function(c) task.spawn(track, c) end)
end
for _, p in ipairs(Players:GetPlayers()) do watch(p) end
Players.PlayerAdded:Connect(watch)
