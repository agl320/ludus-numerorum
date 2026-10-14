-- SOUNDSCAPE (client): the layer of life around the lobby and the city, on top of StarterPlayerScripts.Ambience
-- (wind, canal water, crows). Everything is quiet and positional where it has a source, and follows the
-- day / night cycle (Lighting.ClockTime, driven by DayNight):
--   * the carousel's music box, only heard near the carousel
--   * splashing fountains in the lobby square and the Town Circle
--   * birdsong by day, crickets by night
--   * the cathedral bell tolling now and then, and the odd distant dog at night
-- Volumes follow the game's sound volume (the "Ambience" SoundGroup that Ambience keeps in step with it).
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local random = Random.new()

local group = SoundService:WaitForChild("Ambience", 20)
local folder = Instance.new("Folder")
folder.Name = "Soundscape"; folder.Parent = workspace

local function anchorAt(name, pos)
	local p = Instance.new("Part")
	p.Name = name; p.Size = Vector3.new(0.2, 0.2, 0.2); p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Position = pos; p.Parent = folder
	return p
end
local function sound(id, volume, parent, minD, maxD, looped)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id; s.Volume = volume; s.Looped = looped ~= false
	s.SoundGroup = group
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = minD or 10; s.RollOffMaxDistance = maxD or 100
	s.Parent = parent or folder
	return s
end
local function smooth(a, b, x) local t = math.clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t) end
-- 1 by day, 0 at night (soft at dawn and dusk)
local function daylight()
	local h = Lighting.ClockTime
	return smooth(5.4, 7.6, h) * (1 - smooth(18.2, 19.8, h))
end

------------------------------------------------------------------ carousel music box
local CAROUSEL = Vector3.new(0, 9, -4)
do
	local lobby = workspace:FindFirstChild("Lobby")
	local car = lobby and lobby:FindFirstChild("Carousel", true)
	if car and car:IsA("Model") then CAROUSEL = car:GetPivot().Position + Vector3.new(0, 8, 0) end
end
-- a quiet rotation of music-box tunes: each fades in, plays once at a slightly different pace, fades out, then a
-- pause of silence before the next (never the same tune twice in a row)
local CAROUSEL_VOL = 0.14
local TUNES = {9043210026, 9047796475, 1840004224, 1838853276} -- Music Box 4, Music Box Lullaby, Twinkle, Sylvia Celesta
local carouselAnchor = anchorAt("CarouselMusic", CAROUSEL)
local carouselNear = 0 -- 0..1, eased by distance (set below)
local carouselTunes = {}
for i, id in ipairs(TUNES) do carouselTunes[i] = sound(id, 0, carouselAnchor, 8, 50, false) end
task.spawn(function()
	local last
	while true do
		-- wait until someone is near the carousel
		while carouselNear < 0.05 do task.wait(1) end
		local i
		repeat i = random:NextInteger(1, #carouselTunes) until i ~= last or #carouselTunes == 1
		last = i
		local s = carouselTunes[i]
		s.PlaybackSpeed = random:NextNumber(0.88, 0.98) -- slower and lower than written: wistful, not chirpy
		s.TimePosition = 0
		s.Volume = 0
		s:Play()
		local length = (s.TimeLength > 0 and s.TimeLength or 30) / s.PlaybackSpeed
		local started = os.clock()
		local FADE_IN, FADE_OUT = 4, 6
		while s.IsPlaying and os.clock() - started < length do
			local t = os.clock() - started
			local env = math.min(1, t / FADE_IN) * math.min(1, math.max(0, (length - t) / FADE_OUT))
			s.Volume = CAROUSEL_VOL * env * carouselNear
			task.wait(0.1)
		end
		s:Stop()
		task.wait(random:NextNumber(10, 28)) -- quiet between tunes
	end
end)

------------------------------------------------------------------ fountains
local fountains = {}
for _, pos in ipairs({Vector3.new(-66, 2.5, -4), Vector3.new(1305.2, 5, 131.8)}) do
	local s = sound(9120552550, 0.22, anchorAt("FountainSound", pos), 6, 50)
	s.PlaybackSpeed = 1.15
	table.insert(fountains, s)
end

------------------------------------------------------------------ birds by day, crickets by night (everywhere)
local birds = sound(9116969466, 0, SoundService, nil, nil)
local crickets = sound(9112764040, 0, SoundService, nil, nil)
local BIRDS_VOL, CRICKETS_VOL = 0.06, 0.07

------------------------------------------------------------------ wind
-- a steady bed that grows the higher you are (rooftops are windy), a swelling gust layer that follows the shared
-- wind (ReplicatedStorage.Numberfall.Weather: the same gusts that bend the wind streaks and blow the leaves, on
-- every screen; a little stronger at night), and now and then a single gust going past
local Weather = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Weather"))
local windBed = sound(5799870105, 0, SoundService)
local windGusts = sound(551546110, 0, SoundService)
windGusts.PlaybackSpeed = 0.9
local gust, gustTarget, gustNext = 0, 0, 0
task.spawn(function()
	while true do
		task.wait(random:NextNumber(22, 48))
		do
			local s = sound(139725280625973, random:NextNumber(0.08, 0.14), SoundService, nil, nil, false)
			s.PlaybackSpeed = random:NextNumber(0.75, 0.95)
			s:Play()
			game:GetService("Debris"):AddItem(s, 8)
		end
	end
end)

------------------------------------------------------------------ cathedral bell, distant dogs
local AD = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("AmbienceData"))
local bellAnchor = anchorAt("CathedralBell", AD.CathedralTop or Vector3.new(1064.8, 131, 209.5))
local function toll(count)
	for i = 1, count do
		local s = sound(9113803790, 0.5, bellAnchor, 60, 1400, false)
		s.PlaybackSpeed = 0.82 -- a big old bell
		s:Play()
		game:GetService("Debris"):AddItem(s, 8)
		task.wait(2.6)
	end
end
task.spawn(function()
	task.wait(random:NextNumber(30, 70))
	while true do
		toll(random:NextInteger(1, 3))
		task.wait(random:NextNumber(110, 200))
	end
end)
local dogAnchor = anchorAt("DistantDog", Vector3.new(0, -500, 0))
task.spawn(function()
	while true do
		task.wait(random:NextNumber(35, 80))
		if daylight() < 0.3 then
			local cam = workspace.CurrentCamera
			if cam then
				local a = random:NextNumber(0, math.pi * 2)
				dogAnchor.Position = cam.CFrame.Position + Vector3.new(math.cos(a) * 110, 6, math.sin(a) * 110)
				for _ = 1, random:NextInteger(1, 3) do
					local s = sound(9113955093, 0.18, dogAnchor, 20, 260, false)
					s.PlaybackSpeed = random:NextNumber(0.85, 0.95)
					s:Play()
					game:GetService("Debris"):AddItem(s, 3)
					task.wait(random:NextNumber(0.5, 0.9))
				end
			end
		end
	end
end)

------------------------------------------------------------------ keep it all in step (and only play what's near)
local acc = 0
Run.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	local cam = workspace.CurrentCamera
	local here = cam and cam.CFrame.Position or Vector3.zero
	local day = daylight()
	local function fadeTo(s, vol)
		s.Volume += (vol - s.Volume) * 0.25
		if vol > 0.001 and not s.IsPlaying then s:Play() elseif vol <= 0.001 and s.Volume < 0.002 and s.IsPlaying then s:Pause() end
	end
	-- wind: height above the street (the lobby square and the city both sit near y 0) and the gust swell
	gust = Weather.Gust(workspace:GetServerTimeNow())
	local high = math.clamp((here.Y - 18) / 60, 0, 1)
	fadeTo(windBed, (0.06 + 0.13 * high) * (0.75 + 0.5 * gust))
	fadeTo(windGusts, (0.01 + 0.07 * gust ^ 1.4) * (1 + 0.5 * (1 - day)) * (0.6 + 0.6 * high))
	fadeTo(birds, BIRDS_VOL * day)
	fadeTo(crickets, CRICKETS_VOL * (1 - day))
	-- the carousel only turns in the lobby: its music plays while you're near it
	local nearCarousel = (here - CAROUSEL).Magnitude < 80 and player:GetAttribute("InArena") ~= true
	carouselNear += ((nearCarousel and 1 or 0) - carouselNear) * 0.2
	for _, f in ipairs(fountains) do
		fadeTo(f, (here - f.Parent.Position).Magnitude < 90 and 0.22 or 0)
	end
end)
