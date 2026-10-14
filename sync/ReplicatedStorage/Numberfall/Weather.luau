-- Weather shared by every screen: the wind (direction and gust strength) and showers of rain. Everything comes from
-- server time plus three attributes on the Numberfall state object (written by ServerScriptService.WeatherService),
-- so every player sees and hears the same gusts and showers with no extra network traffic:
--   RainStartsAt / RainEndsAt (server time)  a shower: it builds over RAMP seconds and eases off again at the end
--   RainStrength (0-1)                        how hard it rains at its peak
-- Used by: StarterPlayerScripts.Weather (wind streaks, rain, GlobalWind), Soundscape (the wind gust sound),
-- LeafPiles (leaves blown off the piles in gusts).
local W = {}
local state = script.Parent

-- the city's prevailing wind (Ambience's chimney smoke, canal mist and dust motes drift this way too)
W.Direction = Vector3.new(-0.74, 0, -0.67).Unit
W.RAMP = 20

-- 0..1: how hard it's raining right now
function W.Rain(now)
	local s, e = state:GetAttribute("RainStartsAt"), state:GetAttribute("RainEndsAt")
	if not s or not e or now < s or now > e then return 0 end
	local k = math.min((now - s) / W.RAMP, (e - now) / W.RAMP, 1)
	return math.clamp(k, 0, 1) * (state:GetAttribute("RainStrength") or 1)
end

-- 0..1: the wind right now -- a slow swell over half a minute or so with sharper gusts riding on it (stronger in rain)
function W.Gust(now)
	local slow = math.clamp(0.5 + math.noise(now * 0.03, 0.37) * 1.4, 0, 1)
	local fast = math.clamp(math.noise(now * 0.21, 7.13) * 2.4, 0, 1)
	return math.clamp(slow * 0.5 + fast * 0.65 + W.Rain(now) * 0.3, 0, 1)
end

-- the wind as a vector (studs/s), e.g. for workspace.GlobalWind
function W.Wind(now)
	return W.Direction * (5 + 25 * W.Gust(now))
end

return W
