-- Lobby belfry bell: press E at the top of the scaffold to ring it once.
-- 30 s cooldown per player; only players in the lobby hear the toll.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local ev = shared:WaitForChild("LobbyBell")
local prompt = workspace:WaitForChild("Lobby"):WaitForChild("NewSquare"):WaitForChild("Fun"):WaitForChild("BelfryClimb"):WaitForChild("BellPrompt"):WaitForChild("ProximityPrompt")
local COOLDOWN = 30
local last = {}
prompt.Triggered:Connect(function(player)
	if player:GetAttribute("InArena") == true then return end
	local now = os.clock()
	if last[player] and now - last[player] < COOLDOWN then return end
	last[player] = now
	for _, other in ipairs(Players:GetPlayers()) do
		if other:GetAttribute("InArena") ~= true then ev:FireClient(other) end
	end
end)
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
