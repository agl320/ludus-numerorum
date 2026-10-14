-- Day / night cycle. Every client runs the same clock from the server time, so everyone sees the same time of day with
-- nothing sent over the network. The lighting moves through dawn -> day -> dusk (the original MARKED look) -> night,
-- and at night the red sunset skybox is swapped for a dark sky with stars and the moon (ReplicatedStorage.Numberfall.NightSky).
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local NF = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")

local CYCLE_MINUTES = 10      -- one full day (24 game hours) in real minutes
local START_HOUR = 17.5       -- the time of day at server time 0 (so the cycle lines up the same on every server)

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local cc = Lighting:FindFirstChild("ColorCorrection")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local daySky = Lighting:FindFirstChild("MarkedSky") or Lighting:FindFirstChildOfClass("Sky")
local nightSky = NF:WaitForChild("NightSky"):Clone()

local function c(r, g, b) return Color3.fromRGB(r, g, b) end
-- looks: Br = Brightness, Amb / Out = Ambient / OutdoorAmbient, Exp = ExposureCompensation, AC / AD = atmosphere colour /
-- decay, Den / Haze = atmosphere density / haze, Tint / Sat = colour correction, Bloom = bloom intensity
-- (ambient raised across the board: the low sun leaves most streets in building shadow, which read near-black)
-- (night lifted: a moonlit blue you can still play in, not near-black streets)
-- (lifted again: players found the night too dark to see the map)
-- (colour kept: less bloom and a little less exposure / desaturation -- skin and light clothes were blowing out to
-- white and darker ones washing out to grey, arms most of all since they catch the most light)
-- (lifted a third time: brighter ambient + exposure, and a lighter, thinner night fog so streets and the distance
-- don't fall off to black -- still a moonlit blue)
local NIGHT = {Br = 2.1, Amb = c(126, 128, 160), Out = c(166, 170, 206), Exp = 0.42, AC = c(84, 90, 128), AD = c(40, 38, 70), Den = 0.33, Haze = 1.0, Tint = c(218, 226, 255), Sat = -0.08, Bloom = 0.42}
local DAWN = {Br = 2.6, Amb = c(100, 92, 104), Out = c(164, 150, 164), Exp = 0.18, AC = c(200, 150, 140), AD = c(130, 70, 80), Den = 0.34, Haze = 2, Tint = c(255, 240, 234), Sat = 0, Bloom = 0.32}
local DAY = {Br = 2.9, Amb = c(100, 98, 108), Out = c(166, 164, 174), Exp = 0.12, AC = c(190, 165, 160), AD = c(120, 80, 90), Den = 0.28, Haze = 1.4, Tint = c(255, 250, 248), Sat = 0.04, Bloom = 0.26}
local DUSK = {Br = 2.6, Amb = c(98, 98, 112), Out = c(156, 156, 174), Exp = 0.18, AC = c(176, 142, 140), AD = c(104, 58, 74), Den = 0.32, Haze = 1.8, Tint = c(246, 246, 255), Sat = 0.02, Bloom = 0.32}
local KEYS = {{0, NIGHT}, {4.6, NIGHT}, {6.2, DAWN}, {9, DAY}, {15, DAY}, {17.5, DUSK}, {19.4, NIGHT}, {24, NIGHT}}
local NIGHT_SKY_FROM, NIGHT_SKY_TO = 19.2, 5.2 -- (swapped while it's darkest, so the change isn't noticed)

local function lerp(a, b, t)
	if typeof(a) == "Color3" then return a:Lerp(b, t) end
	return a + (b - a) * t
end
local function look(hour)
	for i = 1, #KEYS - 1 do
		local k0, k1 = KEYS[i], KEYS[i + 1]
		if hour >= k0[1] and hour <= k1[1] then
			local t = (hour - k0[1]) / math.max(k1[1] - k0[1], 1e-3)
			t = t * t * (3 - 2 * t)
			local out = {}
			for key, v in pairs(k0[2]) do out[key] = lerp(v, k1[2][key], t) end
			return out
		end
	end
	return NIGHT
end

local skyIsNight = nil
local lobbyBoost = 0
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	acc = 0
	-- the main menu films the map at its signature dusk (MenuScenery sets MenuClock while you're on the menu)
	local hour = game:GetService("Players").LocalPlayer:GetAttribute("MenuClock") or (START_HOUR + workspace:GetServerTimeNow() / (CYCLE_MINUTES * 60) * 24) % 24
	Lighting.ClockTime = hour
	local l = look(hour)
	-- the lobby square (and the menu filming it) gets a little extra exposure (was a tween in LobbyFun that this
	-- loop overwrote every tick)
	local p = game:GetService("Players").LocalPlayer
	local lobbyTarget = (p:GetAttribute("InArena") ~= true and p:GetAttribute("IntroPlaying") ~= true) and 0.3 or 0
	lobbyBoost += (lobbyTarget - lobbyBoost) * 0.15
	-- low end mode switches off most map lights and all shadows: lift the ambient to make up for them
	if p:GetAttribute("LowEnd") == true then
		l.Amb = l.Amb:Lerp(Color3.new(1, 1, 1), 0.12); l.Out = l.Out:Lerp(Color3.new(1, 1, 1), 0.1); l.Exp += 0.15
	end
	Lighting.Brightness = l.Br; Lighting.Ambient = l.Amb; Lighting.OutdoorAmbient = l.Out; Lighting.ExposureCompensation = l.Exp + lobbyBoost
	if atmo then atmo.Color = l.AC; atmo.Decay = l.AD; atmo.Density = l.Den; atmo.Haze = l.Haze end
	if cc then cc.TintColor = l.Tint; cc.Saturation = l.Sat end
	if bloom then bloom.Intensity = l.Bloom; bloom.Threshold = 1.45 end -- (only real light sources glow, not lit skin)
	local night = hour >= NIGHT_SKY_FROM or hour < NIGHT_SKY_TO
	if night ~= skyIsNight then
		skyIsNight = night
		if daySky then daySky.Parent = night and nil or Lighting end
		nightSky.Parent = night and Lighting or nil
	end
end)
