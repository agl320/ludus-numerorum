-- Players tab (StarterGui.MARKED_UI_EDITABLE.Leaderboard): everyone in this server (and the round's bots) ranked by this match's eliminations,
-- marks as the tie-break. The window, nav buttons, rank badges and marks icons are painted art (Window.ArtLeft /
-- ArtRight); only avatars, names and numbers are live. Values come from the profile attributes the server
-- publishes (StatKills, Coins).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Board = {}
Board.__index = Board
local BONE = Color3.fromRGB(239, 233, 230)
local DIM = Color3.fromRGB(112, 96, 96)
local ROWS = 12 -- a full server (12). The painted 10-row table is covered by Window.BodyCover; rows, rank badges
-- (cropped from the art) and marks icons are live so each row can hide its icon
-- painted art (upload MarkedLeaderboardL.png / MarkedLeaderboardR.png and put the ids here or on the ImageLabels)
local ART_LEFT = "rbxassetid://105219829380070"
local ART_RIGHT = "rbxassetid://105063136170634"

local function commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Board.new(view)
	local panel = view.gui:WaitForChild("Leaderboard")
	local window = panel:WaitForChild("Window")
	local self = setmetatable({view = view, panel = panel, window = window, avatars = {}, nextRefresh = 0, shown = false}, Board)
	if ART_LEFT ~= "" then window.ArtLeft.Image = ART_LEFT end
	if ART_RIGHT ~= "" then window.ArtRight.Image = ART_RIGHT end
	local nav = window.Nav
	nav.Players.Activated:Connect(function() self.nextRefresh = 0 end)
	nav.Quests.Activated:Connect(function() view:Show("Quests") end)
	nav.Shop.Activated:Connect(function() view:Show("Shop") end)
	nav.Settings.Activated:Connect(function() view:Show("Settings") end)
	window.Close.Activated:Connect(function() view.peek = false; view:Show("HUD") end)
	-- painted buttons light up softly under the mouse
	for _, button in ipairs({nav.Quests, nav.Shop, nav.Settings, window.Close}) do
		if view.Locked and view.Locked[button.Name] then
			-- temporarily locked menu: the painted button is shaded dark and doesn't light up
			button:SetAttribute("Locked", true)
			button.BackgroundColor3 = Color3.fromRGB(10, 8, 9); button.BackgroundTransparency = 0.4
		else
			button.MouseEnter:Connect(function() button.BackgroundTransparency = 0.88 end)
			button.MouseLeave:Connect(function() button.BackgroundTransparency = 1 end)
		end
	end
	-- the world behind the window goes soft while it's open
	self.blur = Instance.new("BlurEffect")
	self.blur.Name = "LeaderboardBlur"; self.blur.Size = 0; self.blur.Enabled = false
	self.blur.Parent = Lighting
	local function soon() self.nextRefresh = 0 end
	Players.PlayerAdded:Connect(function(p) self:Prefetch({p}); soon() end)
	Players.PlayerRemoving:Connect(function(p) self.avatars[p.UserId] = nil; soon() end)
	-- load the painted window art and everyone's headshots in the background now, so Tab opens instantly
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({window.ArtLeft, window.ArtRight}) end)
	end)
	self:Prefetch(Players:GetPlayers())
	self:Refresh()
	return self
end

local function thumb(userId) return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=100&h=100" end
function Board:Avatar(userId, image)
	if image:GetAttribute("UserId") == userId and image.Image ~= "" then return end
	image:SetAttribute("UserId", userId)
	image.Image = thumb(userId)
	self.avatars[userId] = true
end
-- warm the engine's image cache before the board is ever opened
function Board:Prefetch(players)
	local list = {}
	for _, p in ipairs(players) do
		if p.UserId > 0 and not self.avatars[p.UserId] then
			self.avatars[p.UserId] = true
			local img = Instance.new("ImageLabel"); img.Image = thumb(p.UserId)
			table.insert(list, img)
		end
	end
	if #list > 0 then task.spawn(function() pcall(function() ContentProvider:PreloadAsync(list) end) end) end
end

-- the in-game look as the row's picture: a copy of their character (visor, hair, outfit), framed upright on the head.
-- Cached per player / bot (not per row, so re-ranking never re-clones) and only ever taken from a living, upright
-- body: while someone is dead or ragdolled their last good portrait stays, and it goes grey once they're out.
-- Falls back to the Roblox headshot when no body has been seen yet (far away / streamed out).
local STRIP = {LuaSourceContainer = true, Sound = true, BillboardGui = true, SurfaceGui = true, ForceField = true,
	ParticleEmitter = true, Trail = true, Beam = true, Light = true, Highlight = true, Constraint = true, JointInstance = false}
local function standing(char)
	local head = char and char.Parent and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (head and hum and root) then return false end
	if hum.Health <= 0 or char:GetAttribute("Ragdolled") then return false end
	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then return false end
	return root.CFrame.UpVector.Y > 0.85 and head.CFrame.UpVector.Y > 0.7
end

-- a red X over an eliminated fighter's portrait (the portrait itself stays, greyed)
local function outMark(frame)
	local mark = frame:FindFirstChild("OutMark")
	if mark then return mark end
	mark = Instance.new("Frame")
	mark.Name = "OutMark"; mark.BackgroundTransparency = 1; mark.Size = UDim2.fromScale(1, 1); mark.ZIndex = frame.Avatar.ZIndex + 5
	mark.ClipsDescendants = false; mark.Visible = false
	for _, angle in ipairs({45, -45}) do
		local bar = Instance.new("Frame")
		bar.Name = "Bar"; bar.AnchorPoint = Vector2.new(0.5, 0.5); bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(0.62, 0, 0, 5); bar.Rotation = angle; bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.fromRGB(255, 34, 58); bar.ZIndex = mark.ZIndex
		local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(40, 0, 8); st.Thickness = 1.5; st.Parent = bar
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 2); c.Parent = bar
		bar.Parent = mark
	end
	mark.Parent = frame
	return mark
end

function Board:Portrait(row, char, userId, key, out)
	local frame = row.AvatarFrame
	self.cache = self.cache or {}
	local entry = key and self.cache[key]
	outMark(frame).Visible = out == true
	-- (once someone is out their last portrait from the round is kept -- it isn't swapped for their lobby body)
	if key and not (out and entry) and standing(char) and (not entry or entry.char ~= char) then
		local vp = self:BuildPortrait(frame, char)
		if vp then
			if entry and entry.vp then entry.vp:Destroy() end
			entry = {vp = vp, char = char}
			self.cache[key] = entry
		end
	end
	if entry then entry.seen = self.refreshId end
	-- this row only shows its own entity's portrait
	for _, c in ipairs(frame:GetChildren()) do
		if c.Name == "Portrait" and (not entry or c ~= entry.vp) then c.Parent = nil end
	end
	if entry and entry.vp then
		entry.vp.Parent = frame
		entry.vp.ImageColor3 = out and Color3.fromRGB(150, 140, 143) or Color3.new(1, 1, 1) -- (dimmed, still recognisable under the X)
		frame.Avatar.Visible = false
	else
		frame.Avatar.Visible = userId ~= nil and userId > 0
		if userId and userId > 0 then self:Avatar(userId, frame.Avatar) end
	end
end

function Board:BuildPortrait(frame, char)
	local was = char.Archivable
	char.Archivable = true
	local ok, copy = pcall(function() return char:Clone() end)
	char.Archivable = was
	if not ok or not copy then return nil end
	for _, d in ipairs(copy:GetDescendants()) do
		local drop = false
		for class in pairs(STRIP) do if STRIP[class] and d:IsA(class) then drop = true break end end
		if drop then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.LocalTransparencyModifier = 0 end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Portrait"
	vp.BackgroundColor3 = Color3.fromRGB(24, 12, 16); vp.BackgroundTransparency = 0; vp.BorderSizePixel = 0
	vp.Size = UDim2.fromScale(1, 1); vp.ZIndex = frame.Avatar.ZIndex
	vp.Ambient = Color3.fromRGB(170, 140, 145); vp.LightColor = Color3.fromRGB(255, 230, 225); vp.LightDirection = Vector3.new(-0.4, -0.5, -0.8)
	local corner = frame:FindFirstChildOfClass("UICorner") or frame.Avatar:FindFirstChildOfClass("UICorner")
	if corner then corner:Clone().Parent = vp end
	local world = Instance.new("WorldModel"); world.Parent = vp
	copy.Parent = world
	local cam = Instance.new("Camera"); cam.FieldOfView = 28; cam.Parent = vp
	vp.CurrentCamera = cam
	local h = copy:FindFirstChild("Head")
	local r = copy:FindFirstChild("HumanoidRootPart")
	if h then
		-- face-on and level: the body's heading, the world's up
		local fwd = ((r or h).CFrame.LookVector * Vector3.new(1, 0, 1))
		fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
		local at = h.Position + Vector3.new(0, -0.15, 0)
		cam.CFrame = CFrame.lookAt(at + fwd * 2.9 + Vector3.new(0, 0.25, 0), at)
	end
	return vp
end

function Board:Refresh()
	self.refreshId = (self.refreshId or 0) + 1
	local me = self.view.player
	local rows = self.window.Rows
	local shared = self.view.shared
	-- one list: players and the bots filling the round (ServerScriptService.BotService publishes them as BotBoard).
	-- Ranked by eliminations in THIS match (RoundKills), fighters in the round before anyone waiting in the lobby.
	local entries = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local fighting = p:GetAttribute("InArena") == true
		-- out of lives this round (a player who's out is back in the lobby, so InArena can't be the test)
		local out = shared:GetAttribute("Phase") == "Playing" and p:GetAttribute("InMatch") == true and (p:GetAttribute("Lives") or 1) <= 0
		table.insert(entries, {player = p, name = p.DisplayName, kills = p:GetAttribute("RoundKills") or 0,
			fighting = fighting, out = out, lobby = not fighting and not out, char = p.Character, userId = p.UserId})
	end
	do
		local raw = shared:GetAttribute("BotBoard")
		if type(raw) == "string" and raw ~= "" then
			local ok, decoded = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
			if ok and type(decoded) == "table" then
				local folder = workspace:FindFirstChild("MatchBots")
				for _, b in ipairs(decoded) do
					table.insert(entries, {bot = true, name = tostring(b.n or "BOT"), kills = b.k or 0, out = (b.l or 1) <= 0,
						fighting = true, char = folder and folder:FindFirstChild(tostring(b.n))})
				end
			end
		end
	end
	-- in the round first, then those knocked out of it, and everyone waiting in the lobby always last
	local function group(e) return e.lobby and 3 or (e.fighting and 1 or 2) end
	table.sort(entries, function(a, b)
		if group(a) ~= group(b) then return group(a) < group(b) end
		if a.kills ~= b.kills then return a.kills > b.kills end
		if (a.bot == true) ~= (b.bot == true) then return not a.bot end
		return a.name:lower() < b.name:lower()
	end)
	for i = 1, ROWS do
		local row = rows["Row" .. i]
		local e = entries[i]
		if e then
			local dim = e.out
			local c = dim and DIM or BONE
			row.PlayerName.TextColor3 = c; row.Eliminations.TextColor3 = c
			row.AvatarFrame.BackgroundTransparency = 0
			row.PlayerName.Text = e.name .. (e.out and "  ·  OUT" or e.lobby and "  ·  LOBBY" or "")
			row.Eliminations.Text = commas(e.kills)
			if e.bot then
				row.Currency.Text = "BOT"; row.Currency.TextColor3 = DIM
			else
				row.Currency.Text = commas(e.player:GetAttribute("Coins") or 0); row.Currency.TextColor3 = c
			end
			-- the marks icon only next to a real player's marks
			if row:FindFirstChild("CurrencyIcon") then row.CurrencyIcon.Visible = not e.bot end
			if row:FindFirstChild("Rank") then row.Rank.TextColor3 = c end
			-- your own row gets a thin red outline (first place is already highlighted in the art)
			row.SelfOutline.Enabled = e.player == me and i ~= 1
			-- out of lives this round (a player who's out is back in the lobby, so InArena can't be the test)
			local out = e.out == true
			self:Portrait(row, e.char, e.userId, e.bot and ("bot:" .. e.name) or ("p:" .. tostring(e.userId)), out)
		else
			-- empty places stay on the board as dim placeholders so it always reads as a full server
			row.PlayerName.TextColor3 = DIM; row.Eliminations.TextColor3 = DIM; row.Currency.TextColor3 = DIM
			row.PlayerName.Text = "—"; row.Eliminations.Text = "—"; row.Currency.Text = "—"
			if row:FindFirstChild("CurrencyIcon") then row.CurrencyIcon.Visible = false end
			if row:FindFirstChild("Rank") then row.Rank.TextColor3 = DIM end
			row.SelfOutline.Enabled = false
			row.AvatarFrame.BackgroundTransparency = 0.5
			self:Portrait(row, nil, nil, nil, false)
			row.AvatarFrame.Avatar.Visible = false
		end
	end
	self.window.Empty.Visible = #entries == 0
	-- forget portraits of people who left / bots from an old round
	for key, entry in pairs(self.cache or {}) do
		if entry.seen ~= self.refreshId then
			if entry.vp then entry.vp:Destroy() end
			self.cache[key] = nil
		end
	end
end

function Board:Warm()
	self.cache = self.cache or {}
	local holder = self.window and self.window:FindFirstChild("Rows")
	local frame = holder and holder:FindFirstChild("Row1") and holder.Row1.AvatarFrame
	if not frame then return end
	local function warm(key, char)
		local entry = self.cache[key]
		if standing(char) and (not entry or entry.char ~= char) then
			local vp = self:BuildPortrait(frame, char)
			if vp then
				vp.Parent = nil
				if entry and entry.vp then entry.vp:Destroy() end
				self.cache[key] = {vp = vp, char = char, seen = self.refreshId}
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InArena") == true and p.Character then warm("p:" .. tostring(p.UserId), p.Character) end
	end
	local folder = workspace:FindFirstChild("MatchBots")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Model") then warm("bot:" .. m.Name, m) end
		end
	end
end

function Board:Step()
	local visible = self.panel.Visible
	if visible ~= self.shown then
		self.shown = visible
		if visible then self.blur.Enabled = true; self:Refresh(); self.nextRefresh = os.clock() + 1 end
		local tween = TweenService:Create(self.blur, TweenInfo.new(visible and 0.18 or 0.14), {Size = visible and (self.view.peek and 10 or 14) or 0})
		tween:Play()
		if not visible then tween.Completed:Connect(function() if not self.shown then self.blur.Enabled = false end end) end
	end
	if not visible then
		-- keep a portrait of every fighter on hand while the list is closed too, so someone eliminated before you
		-- opened it still shows their portrait (with the X) instead of an empty frame
		if os.clock() >= (self.nextWarm or 0) then
			self.nextWarm = os.clock() + 2.5
			self:Warm()
		end
		return
	end
	if os.clock() >= self.nextRefresh then
		self.nextRefresh = os.clock() + 1
		self:Refresh()
	end
end

return Board
