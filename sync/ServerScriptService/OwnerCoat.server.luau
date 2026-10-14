-- The MARKED coat (ServerStorage.MARKED_Accessories.MarkedCoat, layered clothing) on the game owner's character
-- (ChatRole OWNER). Put back on if anything strips it while the character is alive.
local Players = game:GetService("Players")
local TEMPLATE = game:GetService("ServerStorage"):WaitForChild("MARKED_Accessories"):WaitForChild("MarkedCoat")

local function wanted(player) return player:GetAttribute("ChatRole") == "OWNER" end

local function wear(player, character)
	if not wanted(player) or player.Character ~= character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:FindFirstChild(TEMPLATE.Name) then return end
	local coat = TEMPLATE:Clone()
	humanoid:AddAccessory(coat)
	coat.AncestryChanged:Connect(function(_, parent)
		if parent == nil then task.delay(1, wear, player, character) end
	end)
end

local function watch(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		task.wait(2) -- after the spawn code has set the body and cleared the avatar's own accessories
		wear(player, character)
	end)
	player:GetAttributeChangedSignal("ChatRole"):Connect(function()
		if player.Character then wear(player, player.Character) end
	end)
	if player.Character then task.spawn(wear, player, player.Character) end
end

Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watch, p) end
