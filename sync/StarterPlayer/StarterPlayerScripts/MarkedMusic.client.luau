-- Music: one track per state, crossfaded. Tracks courtesy of APM Music through Roblox's Creator Store.
--   Menu    -> not deployed (main menu)
--   Lobby   -> deployed, waiting in the lobby courtyard
--   Match   -> in the arena (countdown + round), rotates through a playlist each round
--   Results -> end-of-round results
-- Dying muffles the music for a moment.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local player = Players.LocalPlayer
local state = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
if SoundService:FindFirstChild("MarkedMusic") then return end

local folder = Instance.new("Folder")
folder.Name = "MarkedMusic"; folder.Parent = SoundService
local group = Instance.new("SoundGroup")
group.Name = "MusicVolume"; group.Parent = folder
local muffle = Instance.new("EqualizerSoundEffect")
muffle.Name = "DeathMuffle"; muffle.LowGain = 0; muffle.MidGain = 0; muffle.HighGain = 0; muffle.Parent = group

local TRACKS = {
	Menu = {{Id = 9039353950, Volume = 0.2}},                  -- Strength of Will (dark synth drone)
	Lobby = {{Id = 9043586747, Volume = 0.2}},                 -- Remembering You (c) (sparse, quiet piano)
	Match = {                                                  -- rotates every round
		{Id = 1837840805, Volume = 0.12},                      -- Vanquish the Darkness
		{Id = 1838626086, Volume = 0.12},                      -- Hell Ride
		{Id = 9045942872, Volume = 0.13},                      -- Secret Warrior
	},
	Results = {{Id = 9040210571, Volume = 0.3}},               -- Growing Tension (c)
}
local sounds = {}
local function soundFor(def)
	local key = tostring(def.Id)
	if sounds[key] then return sounds[key] end
	local s = Instance.new("Sound")
	s.Name = "Track_" .. key; s.SoundId = "rbxassetid://" .. def.Id
	s.Volume = 0; s.Looped = true; s.SoundGroup = group; s.Parent = folder
	sounds[key] = s
	return s
end
for _, list in pairs(TRACKS) do for _, def in ipairs(list) do soundFor(def) end end

-- volume follows the SFX volume setting; MUSIC_MIX keeps the music sitting under the game sounds
local MUSIC_MIX = 0.65
local master, masterConnection
-- Settings > Audio > Music volume (applied locally by the menu Controller as LocalMusicVolume; the saved value is
-- Setting_MusicVolume until the menu has loaded)
local function syncVolume()
	local value = player:GetAttribute("LocalMusicVolume")
	if type(value) ~= "number" then value = player:GetAttribute("Setting_MusicVolume") end
	group.Volume = (type(value) == "number" and math.clamp(value, 0, 1) or 0.75) * MUSIC_MIX
end
local function bindMaster(object)
	if object.Name ~= "NumberfallSFX" or not object:IsA("SoundGroup") then return end
	if masterConnection then masterConnection:Disconnect() end
	master = object; masterConnection = object:GetPropertyChangedSignal("Volume"):Connect(syncVolume)
	syncVolume()
end
SoundService.DescendantAdded:Connect(bindMaster)
for _, object in ipairs(SoundService:GetDescendants()) do bindMaster(object) end
player:GetAttributeChangedSignal("LocalMusicVolume"):Connect(syncVolume)
player:GetAttributeChangedSignal("Setting_MusicVolume"):Connect(syncVolume)
syncVolume()

local activeKey, activeSound, matchIndex, lastRound = nil, nil, 0, nil
local fades = {}
local function fadeTo(sound, volume, time)
	if fades[sound] then fades[sound]:Cancel() end
	if volume > 0 and not sound.IsPlaying then sound:Play() end
	fades[sound] = TweenService:Create(sound, TweenInfo.new(time), {Volume = volume})
	fades[sound]:Play()
	if volume == 0 then
		task.delay(time + 0.05, function() if sound ~= activeSound and sound.Volume <= 0.001 then sound:Stop() end end)
	end
end
local function pick()
	local phase = state:GetAttribute("Phase")
	if player:GetAttribute("InMatch") ~= true then return "Menu", TRACKS.Menu[1] end
	if player:GetAttribute("InArena") ~= true then return "Lobby", TRACKS.Lobby[1] end
	if phase == "Results" then return "Results", TRACKS.Results[1] end
	local round = state:GetAttribute("RoundId") or 0
	if lastRound ~= round then lastRound = round; matchIndex = matchIndex % #TRACKS.Match + 1 end
	return "Match" .. matchIndex, TRACKS.Match[matchIndex]
end
local function update()
	local key, def = pick()
	if key == activeKey then return end
	activeKey = key
	local nextSound = soundFor(def)
	for _, s in pairs(sounds) do if s ~= nextSound then fadeTo(s, 0, 1.6) end end
	activeSound = nextSound
	fadeTo(nextSound, def.Volume, 1.6)
end
player:GetAttributeChangedSignal("InMatch"):Connect(update)
player:GetAttributeChangedSignal("InArena"):Connect(update)
state:GetAttributeChangedSignal("Phase"):Connect(update)
state:GetAttributeChangedSignal("RoundId"):Connect(update)
update()

-- muffle on death
local function watch(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.Died:Connect(function()
		if player:GetAttribute("InArena") ~= true then return end
		TweenService:Create(muffle, TweenInfo.new(0.25), {HighGain = -40, MidGain = -12}):Play()
		task.delay(2.6, function() TweenService:Create(muffle, TweenInfo.new(1.2), {HighGain = 0, MidGain = 0}):Play() end)
	end)
end
player.CharacterAdded:Connect(watch)
if player.Character then task.spawn(watch, player.Character) end

task.spawn(function()
	-- the menus / HUD artwork load first (ReplicatedFirst.PriorityPreload), then the music
	local t0 = os.clock()
	while not player:GetAttribute("UIPreloaded") and os.clock() - t0 < 12 do task.wait(0.2) end
	local assets = {}
	for _, s in pairs(sounds) do table.insert(assets, s) end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(assets, function(id, status)
			if status ~= Enum.AssetFetchStatus.Success then warn("MARKED music could not load: " .. id .. " (" .. status.Name .. ")") end
		end)
	end)
	if not ok then warn("MARKED music preload: " .. tostring(err)) end
end)
