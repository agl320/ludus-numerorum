-- MENU SCENERY: the main menu's background is the game itself. Slow camera moves through the Lantern Court lobby and
-- the city, cross-faded through black, at the map's signature dusk (DayNight reads the MenuClock attribute while
-- you're on the menu). The city streams in around players (it isn't sent whole at join), so a city shot asks the
-- server for that area while the shot before it plays; one that hasn't arrived in time is skipped.
-- Debug: the player attributes MenuShot (index) + MenuShotT (0..1) pin one frame of one shot.
local Players = game:GetService("Players")
local V = Vector3.new
local M = {}
M.__index = M
local DUSK = 17.6
local FADE = 1.0
-- {from, look, to, lookTo, seconds, city = coordinates in the city's own frame (SunsetCity.RootCF)}
M.SHOTS = {
	{V(0, 10, -66), V(0, 14, 60), V(0, 12, -57), V(0, 16, 60), 12},
	{V(-46, 72, -168), V(0, 48, -352), V(24, 64, -196), V(0, 50, -352), 12, city = true}, -- (looks along the map at the cathedral, the skyline behind it)
	{V(66, 9, -40), V(-20, 10, 8), V(66, 10, 20), V(-20, 10, 8), 11},
	{V(110, 70, -10), V(0, 10, -100), V(78, 66, -44), V(0, 10, -110), 12, city = true},
	{V(-66, 9, -46), V(-66, 6, -4), V(-66, 11, -35), V(-66, 7, -4), 10},
	{V(30, 6, -250), V(0, 34, -340), V(18, 8, -272), V(0, 36, -340), 11, city = true},
	{V(80, 62, -96), V(0, 12, 6), V(-80, 62, -96), V(0, 12, 6), 14},
	{V(-160, 100, -160), V(0, 50, -350), V(-90, 85, -210), V(0, 45, -350), 13, city = true}, -- (high over the rooftops to the cathedral; it used to start past the city's edge and look over empty ground)
}
local function ease(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end

function M.new(view)
	local self = setmetatable({view = view, player = view.player, index = 0, ready = {}, requested = {}}, M)
	local bg = view.gui:WaitForChild("MenuBackground")
	self.bg = bg
	-- black fade between shots, under the menu itself
	-- (both are saved in the editor too, so Studio shows the menu over the live map; built here if missing)
	local fade = bg:FindFirstChild("SceneFade") or Instance.new("Frame")
	fade.Name = "SceneFade"; fade.BorderSizePixel = 0; fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.Size = UDim2.fromScale(1, 1); fade.BackgroundTransparency = 0; fade.ZIndex = 1; fade.Parent = bg
	self.fade = fade
	-- a soft dark floor so the bottom buttons read over the moving scene
	local floor = bg:FindFirstChild("SceneFloor") or Instance.new("Frame")
	floor.Name = "SceneFloor"; floor.BorderSizePixel = 0; floor.BackgroundColor3 = Color3.new(0, 0, 0)
	floor.AnchorPoint = Vector2.new(0, 1); floor.Position = UDim2.fromScale(0, 1); floor.Size = UDim2.fromScale(1, 0.35); floor.ZIndex = 1
	local g = floor:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient"); g.Rotation = 90
	g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.35)}); g.Parent = floor
	floor.Parent = bg
	self.player:GetAttributeChangedSignal("InMatch"):Connect(function() self:Sync() end)
	self:Sync()
	return self
end

-- the city's frame (city shots are written in it)
local function root()
	local city = workspace:FindFirstChild("SunsetCity")
	return city and city:GetAttribute("RootCF") or CFrame.new()
end
function M:World(shot)
	if not shot.city then return shot[1], shot[2], shot[3], shot[4] end
	local R = root()
	return (R * CFrame.new(shot[1])).Position, (R * CFrame.new(shot[2])).Position, (R * CFrame.new(shot[3])).Position, (R * CFrame.new(shot[4])).Position
end
-- ask the server to stream a city shot's area in; lobby shots are always there. Asked again every time the shot comes
-- round (a city area streams back out a while after you've looked away), along the camera's path and its view.
function M:Prefetch(i, force)
	local shot = M.SHOTS[i]
	if not shot or not shot.city then self.ready[i] = true return end
	if not force and self.requested[i] and os.clock() - self.requested[i] < 20 then return end
	self.requested[i] = os.clock()
	local a, b, c, d = self:World(shot)
	task.spawn(function()
		local done = 0
		-- (at street level: a request around a high camera only loaded the rooftops near it, the streets below stayed
		-- empty -- chimney smoke floating over bare ground)
		local y = root().Position.Y
		local function ground(v) return Vector3.new(v.X, y, v.Z) end
		local look = (b + d) / 2
		local spots = {}
		for _, v in ipairs({a, c, (a + c) / 2, b, d, look, ((a + c) / 2):Lerp(look, 0.33), ((a + c) / 2):Lerp(look, 0.66)}) do
			table.insert(spots, ground(v))
		end
		for _, p in ipairs(spots) do
			task.spawn(function() pcall(function() self.player:RequestStreamAroundAsync(p, 8) end); done += 1 end)
		end
		local t0 = os.clock()
		while done < #spots and os.clock() - t0 < 9 do task.wait(0.1) end
		self.ready[i] = true
	end)
end

function M:Sync()
	local onMenu = self.player:GetAttribute("InMatch") ~= true
	self.player:SetAttribute("MenuClock", onMenu and DUSK or nil)
	self.bg.ImageTransparency = onMenu and 1 or 0
	-- the colour grading made for the painted background darkens the live scene too much
	for _, n in ipairs({"ReferenceGradeX", "ReferenceGradeY"}) do local f = self.bg:FindFirstChild(n); if f then f.Visible = not onMenu end end
	self.fade.Visible = onMenu; self.bg.SceneFloor.Visible = onMenu
	if onMenu then self.index = 0; self.started = nil; self:Prefetch(1); self:Prefetch(2) end
end

-- a city shot only plays once the city is actually there where it looks (asking for the area to stream in isn't
-- the same as it having arrived: on a fresh join it played over bare ground and spawn pads)
function M:Loaded(i)
	local shot = M.SHOTS[i]
	if not shot or not shot.city then return true end
	local _, b, _, d = self:World(shot)
	local y = root().Position.Y
	local at = Vector3.new((b.X + d.X) / 2, y, (b.Z + d.Z) / 2)
	local ok, parts = pcall(function() return workspace:GetPartBoundsInRadius(at, 45) end)
	return ok and #parts >= 80
end
function M:Next()
	local n = #M.SHOTS
	-- the next shot in order; a city shot whose area isn't in yet is held on black for a moment (the city streams in
	-- and out, and can be mid-flicker right as the shot comes up) and skipped only if it still hasn't arrived
	local i = self.index % n + 1
	if not self.waiting then self:Prefetch(i, true) end -- (once, not every frame of the wait)
	if M.SHOTS[i].city and not self:Loaded(i) then
		self.waiting = self.waiting or {i = i, since = os.clock()}
		if os.clock() - self.waiting.since < 3 then self.fade.BackgroundTransparency = 0; return false end
		-- still empty: skip it (and every other city shot that isn't in) this time round
		self.waiting = nil
		for _ = 1, n do
			i = i % n + 1
			if not M.SHOTS[i].city or self:Loaded(i) then break end
		end
	end
	self.waiting = nil
	self.index = i
	self.started = os.clock()
	self:Prefetch(self.index % n + 1)
	return true
end

-- called every frame by the menu Controller while you're on the main menu
function M:Step()
	local cam = workspace.CurrentCamera
	if not cam then return end
	if self.player:GetAttribute("MenuClock") == nil then self:Sync() end
	local pin = self.player:GetAttribute("MenuShot")
	local shot, k
	if pin and M.SHOTS[pin] then
		shot, k = M.SHOTS[pin], self.player:GetAttribute("MenuShotT") or 0.5
		self:Prefetch(pin)
		self.fade.BackgroundTransparency = 1
	else
		if not self.started or os.clock() - self.started >= M.SHOTS[math.max(1, self.index)][5] then
			if not self:Next() then return end
		end
		shot = M.SHOTS[self.index]
		local t = os.clock() - self.started
		k = t / shot[5]
		-- (the city streams back out a while after it was asked for: the next shot is fetched late, just before it's
		-- needed, and a city shot keeps asking while it plays so it can't empty out mid-shot)
		local nextI = self.index % #M.SHOTS + 1
		if shot[5] - t < 7 and self.lateFetch ~= self.started then
			self.lateFetch = self.started
			self:Prefetch(nextI, true)
		end
		if shot.city and os.clock() - (self.keepAlive or 0) > 3 then
			self.keepAlive = os.clock()
			local _, b, _, d = self:World(shot)
			local at = Vector3.new((b.X + d.X) / 2, root().Position.Y, (b.Z + d.Z) / 2)
			task.spawn(function() pcall(function() self.player:RequestStreamAroundAsync(at, 4) end) end)
		end
		-- fade in from black, hold, fade out to black
		local edge = math.min(t, shot[5] - t)
		self.fade.BackgroundTransparency = math.clamp(edge / FADE, 0, 1)
	end
	local a, b, c, d = self:World(shot)
	local e = ease(k)
	local pos, look = a:Lerp(c, e), b:Lerp(d, e)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(pos, look)
	cam.FieldOfView = 58
end

return M
