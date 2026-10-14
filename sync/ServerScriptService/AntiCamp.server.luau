-- NO HIDING THE VISOR: in a round, standing still with your face to a wall or into a corner (so nobody can read your
-- number) starts a countdown; run it out and you're EXPOSED -- everyone sees your number over your head and an outline
-- through walls -- until you step away. Clients show it (StarterPlayerScripts.AntiCampClient).
-- Character attributes: CampWarnAt / CampExposeAt (server time, while you're facing a wall), Exposed (bool).
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")

local WARN_AFTER = 2     -- seconds facing a wall before the countdown shows
local EXPOSE_AFTER = 8   -- seconds facing a wall until you're exposed
local REACH = 3          -- a wall this close in front of your face hides the visor (studs)
local STILL = 6          -- moving slower than this counts as standing there (studs/s)
local LEAVE = 0.6        -- seconds away from the wall before the countdown resets
local KEEP = 3           -- seconds you stay exposed after you've moved away

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local function refreshFilter()
	local skip = {}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
	for _, n in ipairs({"MatchBots", "Afterimages", "AbilityFX"}) do local f = workspace:FindFirstChild(n); if f then table.insert(skip, f) end end
	params.FilterDescendantsInstances = skip
end

-- is there a wall right in front of the face (straight ahead, or either side of it for corners)?
local function facingWall(head)
	local look = head.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.2 then return false end
	flat = flat.Unit
	for _, deg in ipairs({0, 35, -35}) do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(flat) * REACH
		if workspace:Raycast(head.Position, dir, params) then return true end
	end
	return false
end

local state = {} -- character -> {since, lastAt, exposedUntil}
local function clear(character)
	state[character] = nil
	character:SetAttribute("CampWarnAt", nil); character:SetAttribute("CampExposeAt", nil); character:SetAttribute("Exposed", nil)
end

local tick = 0
while true do
	task.wait(0.25)
	tick += 1
	if tick % 8 == 1 then refreshFilter() end
	local now = workspace:GetServerTimeNow()
	local playing = shared:GetAttribute("Phase") == "Playing"
	for _, player in ipairs(Players:GetPlayers()) do
		local c = player.Character
		local head = c and c:FindFirstChild("Head")
		local root = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if c and (not playing or not player:GetAttribute("InArena") or not (head and root and hum) or hum.Health <= 0) then
			if state[c] then clear(c) end
		elseif c then
			local v = root.AssemblyLinearVelocity
			local still = Vector3.new(v.X, 0, v.Z).Magnitude < STILL
			local grounded = hum.FloorMaterial ~= Enum.Material.Air
			local busy = c:GetAttribute("Hanging") == true or c:GetAttribute("Climbing") == true or c:GetAttribute("Ragdolled") == true
			local camping = still and grounded and not busy and facingWall(head)
			local s = state[c] or {}
			state[c] = s
			if camping then
				s.lastAt = now
				if not s.since then
					s.since = now
					c:SetAttribute("CampWarnAt", now + WARN_AFTER)
					c:SetAttribute("CampExposeAt", now + EXPOSE_AFTER)
				elseif now - s.since >= EXPOSE_AFTER then
					s.exposedUntil = math.huge
					if not c:GetAttribute("Exposed") then c:SetAttribute("Exposed", true) end
				end
			elseif s.since and now - (s.lastAt or 0) > LEAVE then
				s.since = nil
				c:SetAttribute("CampWarnAt", nil); c:SetAttribute("CampExposeAt", nil)
				if s.exposedUntil == math.huge then s.exposedUntil = now + KEEP end
			end
			if s.exposedUntil and s.exposedUntil ~= math.huge and now >= s.exposedUntil then
				s.exposedUntil = nil
				c:SetAttribute("Exposed", nil)
			end
		end
	end
	for c in pairs(state) do if not c.Parent then state[c] = nil end end
end
