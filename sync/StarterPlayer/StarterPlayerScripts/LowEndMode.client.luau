-- LOW END MODE (Settings > Gameplay, always on for phones / tablets / consoles; the player attribute LowEnd is set by the
-- menu Controller). Everything here is local to this client and is undone when the mode is switched off:
--   * no global shadows, no bloom / sun rays / depth of field
--   * map lights off (lamps, candles, braziers, windows) except a handful that matter for play, and no light shadows
--   * map particles, fire and smoke off (falling leaves, chimneys, braziers)
--   * other scripts read the attribute too: StainedGlassLOD (simpler windows sooner), VisorFaces (no blinking),
--     Ambience (fewer crows / leaves), MenuMotion (no menu embers)
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

local saved = {}          -- instance -> {prop = original value}
local active = false
local KEEP = {CryptPad = true}   -- lights that tell you something (the crypt circle)

local function remember(inst, prop, value)
	saved[inst] = saved[inst] or {}
	if saved[inst][prop] == nil then saved[inst][prop] = inst[prop] end
	inst[prop] = value
end

-- effects that already scale themselves down in low end mode (rain: Weather; dash / updraft: AbilityFX)
local OWN_SCALING = {"WeatherFX", "AbilityFX"}
local function inCharacter(inst)
	-- the camera's own effects (speed lines) and anything on a character stay
	local cam = workspace.CurrentCamera
	if cam and inst:IsDescendantOf(cam) then return true end
	for _, name in ipairs(OWN_SCALING) do
		local f = workspace:FindFirstChild(name)
		if f and inst:IsDescendantOf(f) then return true end
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then return true end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function reduce(inst)
	if inst:IsA("Light") then
		if inCharacter(inst) then return end
		if KEEP[inst.Parent and inst.Parent.Name or ""] then remember(inst, "Shadows", false) return end
		-- street lamps stay lit (without shadows): with them off the streets were pitch black at night
		if inst:FindFirstAncestor("Lamp") or inst.Name == "LampLight" then remember(inst, "Shadows", false) return end
		remember(inst, "Enabled", false)
	elseif inst:IsA("ParticleEmitter") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
		if inCharacter(inst) then return end
		remember(inst, "Enabled", false)
	elseif inst:IsA("SurfaceGui") then
		-- map signs / screens drawn at any distance: only draw them up close (the stained glass has its own LOD)
		if inCharacter(inst) or inst:GetAttribute("StainedGlassLOD") or inst.MaxDistance > 0 then return end
		if inst.Parent and inst.Parent:IsA("BasePart") and game:GetService("CollectionService"):HasTag(inst.Parent, "StainedGlass") then return end
		remember(inst, "MaxDistance", 120)
	end
end

local addedConn
local function apply(on)
	if on == active then return end
	active = on
	if on then
		remember(Lighting, "GlobalShadows", false)
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then remember(e, "Enabled", false) end
		end
		local list = workspace:GetDescendants()
		for i, d in ipairs(list) do
			reduce(d)
			if i % 4000 == 0 then task.wait() end
		end
		-- things the map adds later (ambience emitters, streamed parts)
		addedConn = workspace.DescendantAdded:Connect(function(d)
			-- later lights anywhere; later particles only on the map (elimination bursts keep playing)
			local map = workspace:FindFirstChild("SunsetCity")
			if active and (d:IsA("Light") or ((d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke")) and map and d:IsDescendantOf(map))) then
				task.defer(function() if active and d.Parent and not inCharacter(d) then reduce(d) end end)
			end
		end)
	else
		if addedConn then addedConn:Disconnect(); addedConn = nil end
		for inst, props in pairs(saved) do
			if inst.Parent or inst == Lighting then
				for prop, value in pairs(props) do pcall(function() inst[prop] = value end) end
			end
		end
		table.clear(saved)
	end
end

player:GetAttributeChangedSignal("LowEnd"):Connect(function() apply(player:GetAttribute("LowEnd") == true) end)
apply(player:GetAttribute("LowEnd") == true)
