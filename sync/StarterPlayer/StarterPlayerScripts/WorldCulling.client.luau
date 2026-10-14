-- Performance (this screen only): what you can't see isn't drawn.
--   * the lobby is unloaded on your screen while you're in a round. It's a Persistent model (always streamed) 1,200
--     studs from the city -- 12,000+ parts and its own lamps that were being drawn behind the arena the whole time.
--     It comes back the moment you leave the arena (or wander near it).
--   * lamp LOD: only the street lamps near you are real lights. Further out the light is off and the lamp's glass
--     goes solid (2,600 see-through neon panes were being blended every frame); a lit lantern reads the same from there.
--   * auto quality: if this device can't hold about 36 fps (two checks in a row, never while the map is still
--     streaming in), shadows switch off on this screen (and a few fewer lamps are lit) until it's back over 48 for 15 s. Low End Mode (Settings) still does more on top.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local me = Players.LocalPlayer

------------------------------------------------------------------ the lobby during a round
local lobby = workspace:WaitForChild("Lobby", 30)
local lobbyCentre = lobby and lobby:GetPivot().Position
local lobbyHidden = false
local FAR_FROM_LOBBY = 450
local function wantLobby()
	if me:GetAttribute("InArena") ~= true then return true end
	local char = me.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	-- (anything near the lobby -- your body or the camera -- keeps it)
	if root and lobbyCentre and (root.Position - lobbyCentre).Magnitude < FAR_FROM_LOBBY then return true end
	if cam and lobbyCentre and (cam.CFrame.Position - lobbyCentre).Magnitude < FAR_FROM_LOBBY then return true end
	return false
end
local function syncLobby()
	if not lobby then return end
	local want = wantLobby()
	if want and lobbyHidden then
		lobbyHidden = false
		lobby.Parent = workspace
	elseif not want and not lobbyHidden then
		lobbyHidden = true
		lobby.Parent = nil
	end
end
-- back straight away when you're sent out of the arena (before your body lands there)
me:GetAttributeChangedSignal("InArena"):Connect(syncLobby)
me.CharacterAdded:Connect(function() task.defer(syncLobby) end)

------------------------------------------------------------------ lamp LOD
local lamps = {} -- lamp model -> {lights = {}, panes = {pane = base transparency}, pos = Vector3, lit = bool}
local function lampOf(light)
	return light:FindFirstAncestor("Lamp")
end
local function addLight(light)
	if not light:IsA("Light") then return end
	local model = lampOf(light)
	if not model then return end
	local entry = lamps[model]
	if not entry then
		entry = {lights = {}, panes = {}, lit = true}
		lamps[model] = entry
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Pane" and d.Transparency > 0 and d.Transparency < 1 then
				entry.panes[d] = d:GetAttribute("BaseTransparency") or d.Transparency
				d:SetAttribute("BaseTransparency", entry.panes[d])
			end
		end
		local ok, pivot = pcall(function() return model:GetPivot().Position end)
		entry.pos = ok and pivot or nil
	end
	entry.lights[light] = true
end
local function scan(root)
	for _, d in ipairs(root:GetDescendants()) do if d:IsA("Light") then addLight(d) end end
end
for _, name in ipairs({"Lobby", "SunsetCity"}) do
	local r = workspace:FindFirstChild(name)
	if r then scan(r) end
end
-- (streamed in later, or the lobby coming back)
workspace.DescendantAdded:Connect(function(d) if d:IsA("Light") then task.defer(addLight, d) end end)
local function setLit(entry, lit)
	entry.lit = lit
	for light in pairs(entry.lights) do
		if light.Parent then light.Enabled = lit end
	end
	for pane, base in pairs(entry.panes) do
		if pane.Parent then pane.Transparency = lit and base or 0 end
	end
end

------------------------------------------------------------------ auto quality
local frames, frameTime, windowStart = 0, 0, os.clock()
local reduced = false
local goodSince = nil
local shadowsBefore = nil
local badWindows = 0
-- (no judging while the world is still streaming in: the first seconds after joining, and the moments after being
-- sent into or out of the arena, always dip -- that used to switch the lighting down for the whole round)
local settleUntil = os.clock() + 25
me:GetAttributeChangedSignal("InArena"):Connect(function() settleUntil = math.max(settleUntil, os.clock() + 12) end)
RunService.RenderStepped:Connect(function(dt)
	frames += 1
	frameTime += dt
end)
local function quality()
	local now = os.clock()
	if now - windowStart < 6 or frames == 0 then return end
	local fps = frames / frameTime
	frames, frameTime, windowStart = 0, 0, now
	local lowEnd = me:GetAttribute("LowEnd") == true
	if now < settleUntil then badWindows = 0; return end
	-- (two slow windows in a row -- 12 s -- before anything is turned down)
	if not reduced and fps < 36 and not lowEnd then badWindows += 1 else badWindows = 0 end
	if not reduced and badWindows >= 2 then
		reduced = true; goodSince = nil; badWindows = 0
		shadowsBefore = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
	elseif reduced then
		if fps > 48 then
			goodSince = goodSince or now
			if now - goodSince > 15 then
				reduced = false
				if shadowsBefore ~= nil and not lowEnd then Lighting.GlobalShadows = shadowsBefore end
			end
		else
			goodSince = nil
		end
	end
end

------------------------------------------------------------------ twice a second
-- (lamps light up well before you reach them: they used to pop on only once you were nearly underneath)
local LIT_RANGE, LIT_MAX = 300, 120
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 then return end
	acc = 0
	syncLobby()
	quality()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local eye = cam.CFrame.Position
	local low = reduced or me:GetAttribute("LowEnd") == true
	-- (turned down, the streets still keep most of their lamps: dark streets read as broken lighting)
	local range, cap = low and 180 or LIT_RANGE, low and 55 or LIT_MAX
	-- the nearest lamps within range get lit, up to the cap
	local near = {}
	for model, entry in pairs(lamps) do
		if not model.Parent or not model:IsDescendantOf(workspace) then
			-- (streamed out / the lobby put away: forget until it comes back)
			if not model.Parent then lamps[model] = nil end
		elseif entry.pos then
			local d = (entry.pos - eye).Magnitude
			if d < range then table.insert(near, {entry, d}) elseif entry.lit then setLit(entry, false) end
		end
	end
	table.sort(near, function(a, b) return a[2] < b[2] end)
	for i, item in ipairs(near) do
		local want = i <= cap
		if item[1].lit ~= want then setLit(item[1], want) end
	end
end)
