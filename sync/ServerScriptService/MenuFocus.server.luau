-- Main-menu city shots (StarterGui.MARKED_UI_EDITABLE.MenuScenery) without the hitch.
-- The menu camera flies over parts of the city, which streams in around players. Asking for an area every time its
-- shot came round meant tens of thousands of parts streamed back in (and out again after) on every cut: a half-second
-- freeze each time. Instead, while a player is on the menu (not InMatch), every place a city shot films is a
-- replication focus for them (Player:AddReplicationFocus), so it streams in once and stays in. Removed for matches.
local Players = game:GetService("Players")
local city = workspace:WaitForChild("SunsetCity", 60)
if not city then return end
local ok, Scenery = pcall(require, game:GetService("StarterGui"):WaitForChild("MARKED_UI_EDITABLE"):WaitForChild("MenuScenery"))
if not ok or type(Scenery) ~= "table" or not Scenery.SHOTS then return end
local R = city:GetAttribute("RootCF") or CFrame.new()

-- one focus per filmed spot (the camera's path and where it looks), at street level; spots close together share one
local spots = {}
local function addSpot(v)
	local w = (R * CFrame.new(v.X, 10, v.Z)).Position
	for _, s in ipairs(spots) do if (s - w).Magnitude < 70 then return end end
	table.insert(spots, w)
end
for _, shot in ipairs(Scenery.SHOTS) do
	if shot.city then
		addSpot((shot[1] + shot[3]) / 2)
		addSpot((shot[2] + shot[4]) / 2)
	end
end

local foci
local function getFoci()
	if foci then return foci end
	foci = {}
	local folder = Instance.new("Folder")
	folder.Name = "MenuFoci"
	folder.Parent = workspace
	for _, w in ipairs(spots) do
		local p = Instance.new("Part")
		p.Name = "Focus"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.Transparency = 1; p.Size = Vector3.one; p.CastShadow = false; p.Position = w
		p.Parent = folder
		table.insert(foci, p)
	end
	return foci
end

local on = {}
local function set(player, want)
	if (on[player] == true) == want then return end
	on[player] = want or nil
	for _, p in ipairs(getFoci()) do
		pcall(function()
			if want then player:AddReplicationFocus(p) else player:RemoveReplicationFocus(p) end
		end)
	end
end
local function sync(player)
	if not player.Parent then return end
	set(player, player:GetAttribute("InMatch") ~= true)
end
local function added(player)
	player:GetAttributeChangedSignal("InMatch"):Connect(function() sync(player) end)
	sync(player)
end
Players.PlayerAdded:Connect(added)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(added, p) end
Players.PlayerRemoving:Connect(function(player) on[player] = nil end)
