-- Street lamps and wall sconces (client side, nothing replicates):
--   * they burn at full strength at night and dim right down in daylight (follows the DayNight clock)
--   * glare guard: a lamp right next to your character is turned down as you get close, so your character (and
--     white hair / clothes in particular) doesn't blow out to pure white with a bloom halo under a lamp.
-- City lamps are flickered by Ambience; it multiplies its flicker by the light's "Scale" attribute that this
-- script writes. Every other lamp (the lobby) gets its Brightness set here directly.
--   * distance cull: lights further than CULL from the camera are switched off (their glow can't reach anything you
--     can see from there, and hundreds of lit lanterns across the city were a big share of the frame), and back on
--     as you come near. Only lights this script switched off are switched back on (LowEndMode keeps its own).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local DAY_LEVEL = 0.3          -- lamp strength in full daylight
local GLARE_NEAR, GLARE_FAR = 1.5, 10 -- studs from your head: full dim at NEAR, untouched past FAR
local GLARE_MIN = 0.22         -- strength left when your head is right next to the lamp

local lights = {} -- light -> {base = Brightness, ambience = bool, lamp = bool, set = last value we wrote}
-- every fixed light in the lobby and the city (fountain, carousel and so on get the glare guard too; only the lamps
-- dim in daylight). Characters, pets and effects carry their own lights and are left alone.
local function managed(d)
	if not (d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight")) then return false end
	local lobby, city = workspace:FindFirstChild("Lobby"), workspace:FindFirstChild("SunsetCity")
	return (lobby ~= nil and d:IsDescendantOf(lobby)) or (city ~= nil and d:IsDescendantOf(city))
end
local function add(d)
	if lights[d] or not managed(d) then return end
	local city = workspace:FindFirstChild("SunsetCity")
	local lamp = d.Name == "LampLight" or d:FindFirstAncestor("Lamp") ~= nil
	local info = {base = d:GetAttribute("BaseBrightness") or d.Brightness, lamp = lamp,
		ambience = city ~= nil and d:IsDescendantOf(city) and d:IsA("PointLight") and d:FindFirstAncestor("Lamp") ~= nil}
	lights[d] = info
	d:SetAttribute("BaseBrightness", info.base)
	if not info.ambience then
		-- something else (a server script, e.g. the crypt) changed the brightness: that's the new base
		d:GetPropertyChangedSignal("Brightness"):Connect(function()
			if info.set == nil or math.abs(d.Brightness - info.set) > 0.01 then info.base = d.Brightness; info.set = nil end
		end)
	end
end
for _, d in ipairs(workspace:GetDescendants()) do add(d) end
workspace.DescendantAdded:Connect(function(d) if d:IsA("Light") then task.defer(add, d) end end)
workspace.DescendantRemoving:Connect(function(d) lights[d] = nil end)

local function smooth(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
-- 1 at night, DAY_LEVEL in the middle of the day; dims after dawn, comes back up through dusk
local function dayLevel(hour)
	local up = smooth(7, 10, hour)         -- after sunrise: lamps go down
	local down = smooth(16.5, 19, hour)    -- sunset: lamps come back
	local day = up * (1 - down)
	return 1 - (1 - DAY_LEVEL) * day
end

-- 10 times a second for the lights near the camera (the glare guard needs that); every light (the day / night level
-- moves slowly) only every 2 s, with the near list rebuilt at the same time
local acc, fullAt = 0, 0
local near = {}
local NEAR = 160
local CULL, UNCULL = 330, 310 -- (a little hysteresis so a light on the edge doesn't flicker on and off)
local function lightPos(light)
	local par = light.Parent
	return par and (par:IsA("Attachment") and par.WorldPosition or (par:IsA("BasePart") and par.Position)) or nil
end
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	acc = 0
	local level = dayLevel(Lighting.ClockTime)
	local char = player.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	local headPos = head and head.Position
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	local full = os.clock() >= fullAt
	local list = lights
	if full then
		fullAt = os.clock() + 0.5
		table.clear(near)
		for light, info in pairs(lights) do
			local p = camPos and lightPos(light)
			if p then
				local d = (p - camPos).Magnitude
				if d < NEAR then near[light] = info end
				if light.Parent then
					if d > CULL and light.Enabled then
						light.Enabled = false; info.culled = true
					elseif d < UNCULL and info.culled then
						info.culled = nil; light.Enabled = true
					end
				end
			end
		end
	else
		list = near
	end
	for light, info in pairs(list) do
		if light.Parent then
			local scale = info.lamp and level or 1
			if headPos then
				local par = light.Parent
				local pos = par:IsA("Attachment") and par.WorldPosition or (par:IsA("BasePart") and par.Position)
				if pos then
					local d = (pos - headPos).Magnitude
					if d < GLARE_FAR then scale *= GLARE_MIN + (1 - GLARE_MIN) * smooth(GLARE_NEAR, GLARE_FAR, d) end
				end
			end
			scale = math.floor(scale * 100 + 0.5) / 100
			if info.ambience then
				if light:GetAttribute("Scale") ~= scale then light:SetAttribute("Scale", scale) end
			else
				local b = info.base * scale
				if math.abs(light.Brightness - b) > 0.005 then info.set = b; light.Brightness = b end
			end
		end
	end
end)
