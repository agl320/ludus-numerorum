-- RANK VISORS: VIP, MOD and OWNER wear their own visor (ServerScriptService.VisorDisplay picks it when the visor is
-- made, from ReplicatedStorage.Numberfall.NumberfallVisor.Ranks). This re-makes the visor when a player's rank changes after it was
-- put on (the VIP / ChatRole attributes can land a moment after the character spawns), keeping the screen as it was.
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local Visor = require(SSS:WaitForChild("VisorDisplay"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Config"))

local function refresh(player)
	local character = player.Character
	local visor = character and character:FindFirstChild("LEDVisor")
	if not visor then return end
	local rank = Visor.Rank(character)
	local cw = not rank and Visor.Colorway(character) or nil
	if visor:GetAttribute("VisorRank") == rank and visor:GetAttribute("VisorColor") == cw then return end
	local screen = character:FindFirstChild("NumberForehead")
	local code = character:GetAttribute("NumberfallCode") or (screen and screen:GetAttribute("Face")) or Visor.IDLE
	visor = Visor.Equip(character, Config)
	if visor and screen then Visor.Display(character, visor, code, Config) end
end

local function watch(player)
	player:GetAttributeChangedSignal("ChatRole"):Connect(function() refresh(player) end)
	player:GetAttributeChangedSignal("VIP"):Connect(function() refresh(player) end)
	-- the visor picked in Loadout > VISOR
	player:GetAttributeChangedSignal("VisorStyle"):Connect(function() refresh(player) end)
	-- and its colourway
	player:GetAttributeChangedSignal("VisorColor"):Connect(function() refresh(player) end)
	player.CharacterAdded:Connect(function(character)
		-- the visor is put on by the spawn code; check it once it's there
		local visor = character:WaitForChild("LEDVisor", 15)
		if visor then task.wait(0.5); refresh(player) end
	end)
	if player.Character then task.spawn(refresh, player) end
end

Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watch, p) end
