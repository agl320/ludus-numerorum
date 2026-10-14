-- First-join intro preload (server side). The city streams in around players, so on a first join most of it isn't
-- on the client and the intro cinematic (StarterPlayerScripts.IntroCinematic) filmed low-detail stand-ins, and the
-- client can't simply pull the whole city in (areas stream back out). Instead, while a player watches the intro,
-- every place it films is made a replication focus for them (Player:AddReplicationFocus), so those areas stream in
-- and stay in until the intro ends. Also listed on workspace.SunsetCity for the client:
--   IntroSpots : the filmed places (city-local x, z), so the client can wait for them before the intro starts
--   PreloadIds : every mesh and texture the city uses (downloaded up front, so nothing pops in on camera)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local city = workspace:WaitForChild("SunsetCity", 60)
if not city then return end
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local R = city:GetAttribute("RootCF") or CFrame.new()
-- (the square and its body, the cathedral, the fly-in to it, the street with the visor, the bridge and the quay,
-- the rooftop run, the town centre)
local SPOTS = {{22, -281}, {6, -355}, {-150, -170}, {-80, -215}, {-40, -290}, {4, -258}, {0, -220}, {40, -225},
	{70, -261}, {110, -261}, {150, -261}, {182, -261}, {2, -109}}
city:SetAttribute("IntroSpots", HttpService:JSONEncode(SPOTS))

local ids, seen = {}, {}
local function add(id)
	if typeof(id) == "Content" then id = id.Uri end
	if type(id) == "string" and id ~= "" and not seen[id] then seen[id] = true; table.insert(ids, id) end
end
for _, d in ipairs(city:GetDescendants()) do
	if d:IsA("MeshPart") then add(d.MeshId); add(d.TextureID)
	elseif d:IsA("SpecialMesh") then add(d.MeshId); add(d.TextureId)
	elseif d:IsA("SurfaceAppearance") then
		for _, prop in ipairs({"ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"}) do
			local ok, v = pcall(function() return d[prop] end)
			if ok then add(v) end
		end
	elseif d:IsA("Decal") then add(d.Texture) -- (Textures are Decals too)
	end
end
city:SetAttribute("PreloadIds", HttpService:JSONEncode(ids))

-- the focus points: invisible anchored markers, made the first time someone needs them
local foci
local function getFoci()
	if foci then return foci end
	foci = {}
	local folder = Instance.new("Folder")
	folder.Name = "IntroFoci"
	folder.Parent = workspace
	for _, s in ipairs(SPOTS) do
		local p = Instance.new("Part")
		p.Name = "Focus"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.Transparency = 1; p.Size = Vector3.one; p.CastShadow = false
		p.Position = (R * CFrame.new(s[1], 10, s[2])).Position
		p.Parent = folder
		table.insert(foci, p)
	end
	return foci
end
local active = {}
local function stop(player)
	if not active[player] then return end
	active[player] = nil
	for _, p in ipairs(foci or {}) do pcall(function() player:RemoveReplicationFocus(p) end) end
end
local remote = Instance.new("RemoteEvent")
remote.Name = "IntroFocus"
remote.Parent = shared
-- IntroFocus(true) as the intro loads, IntroFocus(false) when it ends or is skipped
remote.OnServerEvent:Connect(function(player, on)
	if on == true then
		if active[player] or player:GetAttribute("IntroSeen") == true then return end
		local token = {}
		active[player] = token
		for _, p in ipairs(getFoci()) do pcall(function() player:AddReplicationFocus(p) end) end
		-- (never left on: the intro is well under this. Only for this showing: a later one keeps its own)
		task.delay(150, function() if active[player] == token then stop(player) end end)
	else
		stop(player)
	end
end)
-- (marked as seen, or gone)
Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("IntroSeen"):Connect(function() if player:GetAttribute("IntroSeen") == true then stop(player) end end)
end)
Players.PlayerRemoving:Connect(function(player) active[player] = nil end)
