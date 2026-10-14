-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
-- MARKED admin panel (client). Admins (ServerScriptService.AdminService decides, and re-checks every action) open it
-- with F6 or the ADMIN button at the top left (F2 is the shop). Everyone gets the announcement banner.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Numberfall")

-- announcements (everyone) ---------------------------------------------------
task.spawn(function()
	local broadcast = shared:WaitForChild("AdminBroadcast", 60)
	if not broadcast then return end
	broadcast.OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then return end
		local ok, TopNotices = pcall(require, shared:WaitForChild("TopNotices"))
		if not (ok and TopNotices and TopNotices.Push) then return end
		if kind == "Announce" then
			TopNotices.Push(tostring(data.Text), {eyebrow = (data.Global and "GLOBAL ANNOUNCEMENT  ·  " or "ANNOUNCEMENT  ·  ") .. string.upper(tostring(data.From or "")), kind = "good", duration = 9})
		elseif kind == "Event" and data.Started then
			TopNotices.Push(tostring(data.Name or "EVENT") .. " HAS STARTED", {eyebrow = "GLOBAL EVENT", kind = "good", duration = 7})
		elseif kind == "Event" then
			TopNotices.Push("The event has ended", {eyebrow = "GLOBAL EVENT", duration = 5})
		end
	end)
end)

-- the panel (admins only) ------------------------------------------------------
while player:GetAttribute("MarkedAdmin") ~= true do
	player:GetAttributeChangedSignal("MarkedAdmin"):Wait()
end
local call = shared:WaitForChild("AdminCall")

local BG = Color3.fromRGB(11, 8, 10)
local PANEL = Color3.fromRGB(19, 14, 17)
local CARD = Color3.fromRGB(27, 20, 24)
local LINE = Color3.fromRGB(58, 40, 46)
local RED = Color3.fromRGB(255, 23, 74)
local DARKRED = Color3.fromRGB(110, 0, 26)
local BONE = Color3.fromRGB(238, 233, 230)
local MUTED = Color3.fromRGB(150, 138, 142)
local GOOD = Color3.fromRGB(90, 220, 140)
local TITLE = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 6)}, o) end
local function stroke(o, c, t) return mk("UIStroke", {Color = c or LINE, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function label(parent, text, size, pos, dims, color, font, align)
	return mk("TextLabel", {BackgroundTransparency = 1, Text = text, TextSize = size, Position = pos, Size = dims, TextColor3 = color or BONE,
		FontFace = font or BODY, TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, parent)
end
local function button(parent, text, pos, dims, style)
	local b = mk("TextButton", {Text = text, TextSize = 13, FontFace = BOLD, AutoButtonColor = false, Position = pos, Size = dims,
		BackgroundColor3 = style == "danger" and DARKRED or style == "primary" and RED or CARD, TextColor3 = BONE}, parent)
	corner(b, 5)
	local s = stroke(b, (style == "danger" or style == "primary") and RED or LINE)
	b.MouseEnter:Connect(function() s.Color = BONE end)
	b.MouseLeave:Connect(function() s.Color = (style == "danger" or style == "primary") and RED or LINE end)
	return b
end
local function input(parent, placeholder, pos, dims)
	local box = mk("TextBox", {Text = "", PlaceholderText = placeholder, PlaceholderColor3 = Color3.fromRGB(110, 98, 102), TextSize = 13,
		FontFace = BODY, TextColor3 = BONE, BackgroundColor3 = BG, Position = pos, Size = dims, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, parent)
	corner(box, 5); stroke(box, LINE)
	mk("UIPadding", {PaddingLeft = UDim.new(0, 8)}, box)
	return box
end
local function section(parent, text, y)
	label(parent, text, 11, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 14), RED, BOLD)
	mk("Frame", {BackgroundColor3 = LINE, BorderSizePixel = 0, Position = UDim2.fromOffset(0, y + 17), Size = UDim2.new(1, 0, 0, 1)}, parent)
end

local gui = mk("ScreenGui", {Name = "AdminPanel", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local scale = mk("UIScale", {}, gui)
local function fit() local v = gui.AbsoluteSize; scale.Scale = math.clamp(math.min(v.X / 1000, v.Y / 640), 0.55, 1) end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit); fit()

-- toggle button
local toggle = mk("TextButton", {Text = "ADMIN", TextSize = 12, FontFace = BOLD, TextColor3 = BONE, BackgroundColor3 = DARKRED, AutoButtonColor = true,
	Position = UDim2.fromOffset(16, 70), Size = UDim2.fromOffset(64, 24)}, gui)
corner(toggle, 5); stroke(toggle, RED)

local W, H = 860, 540
local main = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = PANEL, Visible = false, Active = true}, gui)
corner(main, 10); stroke(main, RED, 1.2)
-- header
local header = mk("Frame", {BackgroundColor3 = BG, Size = UDim2.new(1, 0, 0, 52), Active = true}, main)
corner(header, 10)
mk("Frame", {BackgroundColor3 = BG, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 12)}, header)
mk("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 51), Size = UDim2.new(1, 0, 0, 1)}, header)
label(header, "MARKED", 26, UDim2.fromOffset(18, 6), UDim2.fromOffset(130, 40), BONE, TITLE)
label(header, "ADMIN", 13, UDim2.fromOffset(122, 18), UDim2.fromOffset(80, 20), RED, BOLD)
local serverInfo = label(header, "", 12, UDim2.fromOffset(200, 18), UDim2.fromOffset(560, 20), MUTED, BODY, Enum.TextXAlignment.Right)
local close = button(header, "X", UDim2.new(1, -46, 0, 11), UDim2.fromOffset(30, 30))
-- drag by the header
do
	local drag
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = {i.Position, main.Position} end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = (i.Position - drag[1]) / scale.Scale
			main.Position = drag[2] + UDim2.fromOffset(d.X, d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = nil end
	end)
end

-- status bar
local status = label(main, "Select a player on the left.", 12, UDim2.fromOffset(18, H - 30), UDim2.new(1, -36, 0, 20), MUTED)
local function say(ok, msg)
	status.Text = tostring(msg or (ok and "Done" or "Failed"))
	status.TextColor3 = ok and GOOD or RED
end
local function run(action, args, after)
	task.spawn(function()
		local ok, res, msg = pcall(function() return call:InvokeServer(action, args) end)
		if not ok then say(false, "Request failed"); return end
		say(res, msg)
		if after then after(res) end
	end)
end

-- player list (left)
local left = mk("Frame", {BackgroundColor3 = BG, Position = UDim2.fromOffset(14, 64), Size = UDim2.fromOffset(250, H - 104)}, main)
corner(left, 8); stroke(left, LINE)
label(left, "PLAYERS", 11, UDim2.fromOffset(12, 8), UDim2.fromOffset(120, 14), RED, BOLD)
local count = label(left, "", 11, UDim2.fromOffset(120, 8), UDim2.fromOffset(118, 14), MUTED, BODY, Enum.TextXAlignment.Right)
local search = input(left, "Search…", UDim2.fromOffset(10, 28), UDim2.new(1, -20, 0, 28))
local list = mk("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 62), Size = UDim2.new(1, -12, 1, -68),
	ScrollBarThickness = 4, ScrollBarImageColor3 = RED, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, left)
mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)

-- right side: tabs
local right = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(278, 64), Size = UDim2.fromOffset(W - 292, H - 104)}, main)
local tabsRow = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32)}, right)
local pages, tabButtons = {}, {}
local currentTab
local function showTab(name)
	currentTab = name
	for n, pg in pairs(pages) do pg.Visible = n == name end
	for n, b in pairs(tabButtons) do b.BackgroundColor3 = n == name and DARKRED or CARD end
end
for i, name in ipairs({"PLAYER", "MODERATION", "MATCH", "GLOBAL", "LOG"}) do
	local b = button(tabsRow, name, UDim2.fromOffset((i - 1) * 114, 0), UDim2.fromOffset(108, 30))
	tabButtons[name] = b
	pages[name] = mk("Frame", {BackgroundColor3 = BG, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), Visible = false}, right)
	corner(pages[name], 8); stroke(pages[name], LINE)
	mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12)}, pages[name])
	b.Activated:Connect(function() showTab(name) end)
end

-- selection
local players, selected = {}, nil
local function sel() return selected and players[selected] end
local targetLines = {}
local function setTargetText()
	local p = sel()
	for _, l in ipairs(targetLines) do
		if p then
			l.Text = string.format("%s  (@%s)   ·   %s marks   ·   Lv %s%s%s%s", p.DisplayName, p.Name, tostring(p.Coins), tostring(p.Level),
				p.VIP and (p.VIPPermanent and "   ·   VIP (PERMANENT)" or "   ·   VIP") or "", p.InMatch and ("   ·   lives " .. tostring(p.Lives or "-")) or "", p.Frozen and "   ·   FROZEN" or "")
			l.TextColor3 = BONE
		else
			l.Text = "No player selected"; l.TextColor3 = MUTED
		end
	end
end
local function need() if not sel() then say(false, "Select a player first"); return nil end return sel() end

local rows = {}
local refresh
local eventInfo
local function drawList()
	local q = string.lower(search.Text or "")
	for _, r in pairs(rows) do r:Destroy() end
	rows = {}
	local ids = {}
	for id in pairs(players) do table.insert(ids, id) end
	table.sort(ids, function(a, b) return players[a].DisplayName:lower() < players[b].DisplayName:lower() end)
	for i, id in ipairs(ids) do
		local p = players[id]
		if q == "" or p.Name:lower():find(q, 1, true) or p.DisplayName:lower():find(q, 1, true) then
			local r = mk("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = id == selected and DARKRED or CARD, Size = UDim2.new(1, -4, 0, 44), LayoutOrder = i}, list)
			corner(r, 6); stroke(r, id == selected and RED or LINE)
			local img = mk("ImageLabel", {BackgroundColor3 = BG, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(32, 32)}, r)
			corner(img, 16)
			task.spawn(function()
				local ok, url = pcall(function() return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
				if ok and img.Parent then img.Image = url end
			end)
			label(r, p.DisplayName .. (p.Admin and "  ·  ADMIN" or ""), 13, UDim2.fromOffset(46, 5), UDim2.new(1, -50, 0, 18), BONE, BOLD)
			label(r, "@" .. p.Name .. "   ·   " .. tostring(p.Coins) .. " marks" .. (p.InMatch and "   · in match" or ""), 11, UDim2.fromOffset(46, 23), UDim2.new(1, -50, 0, 16), MUTED)
			r.Activated:Connect(function() selected = id; drawList(); setTargetText() end)
			rows[id] = r
		end
	end
	count.Text = #ids .. " IN SERVER"
end
search:GetPropertyChangedSignal("Text"):Connect(drawList)

refresh = function()
	local ok, res, list2 = pcall(function() return call:InvokeServer("Players") end)
	if ok and res and type(list2) == "table" then
		players = {}
		for _, p in ipairs(list2) do players[p.UserId] = p end
		if selected and not players[selected] then selected = nil end
		drawList(); setTargetText()
	end
	local ok2, res2, st = pcall(function() return call:InvokeServer("State") end)
	if ok2 and res2 and type(st) == "table" then
		if eventInfo then
			local e = st.Event
			eventInfo.Text = e and string.format("LIVE:  %s   ·   marks x%s   ·   XP x%s   ·   %dh %dm left", tostring(e.Name), tostring(e.Marks), tostring(e.XP),
				math.floor(e.Left / 3600), math.floor(e.Left % 3600 / 60)) or "No global event running."
			eventInfo.TextColor3 = e and GOOD or MUTED
		end
		serverInfo.Text = string.format("SERVER %s   ·   %d PLAYERS   ·   %s%s   ·   ROUND %d", tostring(st.Server), st.Players, string.upper(tostring(st.Phase)),
			st.Phase == "Warmup" and (st.LobbyLeft and ("  " .. st.LobbyLeft .. "s") or "") or ("  " .. st.Left .. "s"), st.Round)
	end
end

-- PLAYER tab -------------------------------------------------------------------
do
	local pg = pages.PLAYER
	table.insert(targetLines, label(pg, "", 13, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), BONE, BOLD))

	section(pg, "MARKS & XP", 30)
	local amount = input(pg, "Amount (e.g. 1000)", UDim2.fromOffset(0, 56), UDim2.fromOffset(170, 30))
	button(pg, "GIVE MARKS", UDim2.fromOffset(178, 56), UDim2.fromOffset(104, 30), "primary").Activated:Connect(function()
		local p = need(); if p then run("Marks", {UserId = p.UserId, Amount = tonumber(amount.Text)}, refresh) end end)
	button(pg, "TAKE MARKS", UDim2.fromOffset(288, 56), UDim2.fromOffset(104, 30)).Activated:Connect(function()
		local p = need(); if p then run("Marks", {UserId = p.UserId, Amount = -(tonumber(amount.Text) or 0)}, refresh) end end)
	button(pg, "GIVE XP", UDim2.fromOffset(398, 56), UDim2.fromOffset(90, 30)).Activated:Connect(function()
		local p = need(); if p then run("XP", {UserId = p.UserId, Amount = tonumber(amount.Text)}, refresh) end end)
	local quick = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 26)}, pg)
	for i, n in ipairs({500, 1000, 5000, 10000, 50000}) do
		button(quick, "+" .. (n >= 1000 and (n / 1000) .. "K" or tostring(n)) .. " MARKS", UDim2.fromOffset((i - 1) * 108, 0), UDim2.fromOffset(100, 26)).Activated:Connect(function()
			local p = need(); if p then run("Marks", {UserId = p.UserId, Amount = n}, refresh) end end)
	end

	section(pg, "COSMETICS", 130)
	local item = input(pg, "Item id  (Hellfire, Sigil, Obsidian, CwPhantom, WolfShag, Platinum…)", UDim2.fromOffset(0, 156), UDim2.fromOffset(330, 30))
	button(pg, "GRANT", UDim2.fromOffset(338, 156), UDim2.fromOffset(74, 30), "primary").Activated:Connect(function()
		local p = need(); if p then run("Grant", {UserId = p.UserId, Item = item.Text}) end end)
	button(pg, "REVOKE", UDim2.fromOffset(418, 156), UDim2.fromOffset(74, 30)).Activated:Connect(function()
		local p = need(); if p then run("Revoke", {UserId = p.UserId, Item = item.Text}) end end)
	button(pg, "VIP (SERVER)", UDim2.fromOffset(0, 194), UDim2.fromOffset(118, 28)).Activated:Connect(function()
		local p = need(); if p then run("VIP", {UserId = p.UserId}, refresh) end end)
	-- permanent VIP: the selected player, or type a UserId (works for players who aren't in this server)
	local vipId = input(pg, "or UserId", UDim2.fromOffset(124, 194), UDim2.fromOffset(84, 28))
	local function vipTarget() local id = tonumber(vipId.Text); if id then return id end local p = need(); return p and p.UserId end
	button(pg, "GIVE PERM VIP", UDim2.fromOffset(214, 194), UDim2.fromOffset(106, 28), "primary").Activated:Connect(function()
		local id = vipTarget(); if id then run("VIPPermanent", {UserId = id, On = true}, refresh) end end)
	button(pg, "REMOVE PERM VIP", UDim2.fromOffset(326, 194), UDim2.fromOffset(118, 28), "danger").Activated:Connect(function()
		local id = vipTarget(); if id then run("VIPPermanent", {UserId = id, On = false}, refresh) end end)
	button(pg, "REPLAY INTRO", UDim2.fromOffset(450, 194), UDim2.fromOffset(90, 28)).Activated:Connect(function()
		local p = need(); if p then run("ResetIntro", {UserId = p.UserId}) end end)

	section(pg, "IN THE WORLD", 236)
	local acts = {{"GO TO", "Goto"}, {"BRING", "Bring"}, {"FREEZE", "Freeze"}, {"REFILL LIVES", "Lives"}, {"RESPAWN", "Respawn"}, {"KILL", "Kill", "danger"}}
	for i, a in ipairs(acts) do
		button(pg, a[1], UDim2.fromOffset(((i - 1) % 3) * 140, 262 + math.floor((i - 1) / 3) * 36), UDim2.fromOffset(132, 30), a[3]).Activated:Connect(function()
			local p = need(); if p then run(a[2], {UserId = p.UserId}, refresh) end end)
	end
	-- spectate is local: it just points your camera at them
	local spectating
	local spec = button(pg, "SPECTATE", UDim2.fromOffset(420, 262), UDim2.fromOffset(110, 66))
	spec.Activated:Connect(function()
		local cam = workspace.CurrentCamera
		if spectating then
			spectating = nil; spec.Text = "SPECTATE"
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h then cam.CameraSubject = h end
			say(true, "Stopped spectating")
			return
		end
		local p = need(); if not p then return end
		local plr = Players:GetPlayerByUserId(p.UserId)
		local h = plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if not h then say(false, "No character to watch"); return end
		spectating = plr; spec.Text = "STOP\nSPECTATING"
		cam.CameraType = Enum.CameraType.Custom; cam.CameraSubject = h
		say(true, "Spectating " .. p.DisplayName)
	end)
end

-- MODERATION tab ---------------------------------------------------------------
do
	local pg = pages.MODERATION
	table.insert(targetLines, label(pg, "", 13, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), BONE, BOLD))
	section(pg, "KICK / BAN THE SELECTED PLAYER", 30)
	local reason = input(pg, "Reason (shown to the player)", UDim2.fromOffset(0, 56), UDim2.new(1, 0, 0, 30))
	button(pg, "KICK", UDim2.fromOffset(0, 94), UDim2.fromOffset(110, 30), "danger").Activated:Connect(function()
		local p = need(); if p then run("Kick", {UserId = p.UserId, Reason = reason.Text}, refresh) end end)
	local hours = 24
	local durButtons = {}
	local function pick(h) hours = h; for k, b in pairs(durButtons) do b.BackgroundColor3 = k == h and DARKRED or CARD end end
	for i, d in ipairs({{1, "1 HOUR"}, {24, "1 DAY"}, {168, "7 DAYS"}, {0, "PERMANENT"}}) do
		local b = button(pg, d[2], UDim2.fromOffset(122 + (i - 1) * 92, 94), UDim2.fromOffset(86, 30))
		durButtons[d[1]] = b
		b.Activated:Connect(function() pick(d[1]) end)
	end
	pick(24)
	local confirmAt = 0
	local ban = button(pg, "BAN", UDim2.fromOffset(494, 94), UDim2.new(1, -494, 0, 30), "danger")
	ban.Activated:Connect(function()
		local p = need(); if not p then return end
		if os.clock() > confirmAt then
			confirmAt = os.clock() + 3; ban.Text = "CONFIRM BAN?"
			task.delay(3, function() if os.clock() >= confirmAt then ban.Text = "BAN" end end)
			return
		end
		confirmAt = 0; ban.Text = "BAN"
		run("Ban", {UserId = p.UserId, Hours = hours, Reason = reason.Text}, refresh)
	end)
	label(pg, "Bans use Roblox's ban system: they cover every server of the game, including alt accounts.", 11,
		UDim2.fromOffset(0, 130), UDim2.new(1, 0, 0, 16), MUTED)

	section(pg, "UNBAN", 164)
	local uid = input(pg, "UserId", UDim2.fromOffset(0, 190), UDim2.fromOffset(200, 30))
	button(pg, "UNBAN", UDim2.fromOffset(208, 190), UDim2.fromOffset(100, 30), "primary").Activated:Connect(function()
		run("Unban", {UserId = tonumber(uid.Text)}) end)
	label(pg, "A UserId is the number in their profile link: roblox.com/users/<UserId>/profile", 11, UDim2.fromOffset(0, 226), UDim2.new(1, 0, 0, 16), MUTED)
end

-- MATCH tab --------------------------------------------------------------------
do
	local pg = pages.MATCH
	section(pg, "ROUND", 0)
	local acts = {{"SKIP LOBBY WAIT", "SkipLobby"}, {"SKIP COUNTDOWN", "SkipCountdown"}, {"END ROUND", "EndRound", "danger"}}
	for i, a in ipairs(acts) do
		button(pg, a[1], UDim2.fromOffset((i - 1) * 176, 26), UDim2.fromOffset(168, 32), a[3]).Activated:Connect(function() run(a[2], {}, refresh) end)
	end
	for i, s in ipairs({-60, -30, 30, 60, 120}) do
		button(pg, (s > 0 and "+" or "") .. s .. "s", UDim2.fromOffset((i - 1) * 76, 66), UDim2.fromOffset(70, 28)).Activated:Connect(function()
			run("AddTime", {Seconds = s}, refresh) end)
	end
	label(pg, "Round time (only while a round is being played).", 11, UDim2.fromOffset(390, 72), UDim2.fromOffset(250, 16), MUTED)

	section(pg, "ANNOUNCE TO EVERYONE IN THIS SERVER", 114)
	local msg = input(pg, "Message (filtered by Roblox before it's shown)", UDim2.fromOffset(0, 140), UDim2.new(1, -110, 0, 32))
	button(pg, "SEND", UDim2.new(1, -100, 0, 140), UDim2.fromOffset(100, 32), "primary").Activated:Connect(function()
		run("Announce", {Text = msg.Text}, function(ok) if ok then msg.Text = "" end end) end)

	section(pg, "WEATHER (THIS SERVER)", 190)
	button(pg, "RAIN 3 MIN", UDim2.fromOffset(0, 216), UDim2.fromOffset(168, 32), "primary").Activated:Connect(function()
		run("Weather", {Mode = "Rain", Minutes = 3}) end)
	button(pg, "RAIN 10 MIN", UDim2.fromOffset(176, 216), UDim2.fromOffset(168, 32)).Activated:Connect(function()
		run("Weather", {Mode = "Rain", Minutes = 10}) end)
	button(pg, "CLEAR SKIES", UDim2.fromOffset(352, 216), UDim2.fromOffset(168, 32)).Activated:Connect(function()
		run("Weather", {Mode = "Clear"}) end)
end

-- GLOBAL tab (every server) ------------------------------------------------------
do
	local pg = pages.GLOBAL
	section(pg, "ANNOUNCE TO EVERY SERVER", 0)
	local msg = input(pg, "Message for every player in every server (filtered)", UDim2.fromOffset(0, 26), UDim2.new(1, -130, 0, 32))
	button(pg, "SEND TO ALL", UDim2.new(1, -120, 0, 26), UDim2.fromOffset(120, 32), "primary").Activated:Connect(function()
		run("GlobalAnnounce", {Text = msg.Text}, function(ok) if ok then msg.Text = "" end end) end)

	section(pg, "GLOBAL EVENT  ·  REWARD MULTIPLIERS ON EVERY SERVER", 76)
	eventInfo = label(pg, "No global event running.", 12, UDim2.fromOffset(0, 100), UDim2.new(1, 0, 0, 18), MUTED, BOLD)
	local name = input(pg, "Event name  (e.g. DOUBLE MARKS WEEKEND)", UDim2.fromOffset(0, 124), UDim2.new(1, 0, 0, 30))
	local choice = {Marks = 2, XP = 1, Hours = 24}
	local function picker(title, key, options, y, suffix)
		label(pg, title, 11, UDim2.fromOffset(0, y + 7), UDim2.fromOffset(80, 14), MUTED, BOLD)
		local bs = {}
		local function paint() for v, b in pairs(bs) do b.BackgroundColor3 = choice[key] == v and DARKRED or CARD end end
		for i, v in ipairs(options) do
			local b = button(pg, (suffix == "x" and (v .. "x")) or v[2], UDim2.fromOffset(84 + (i - 1) * 78, y), UDim2.fromOffset(72, 28))
			local val = suffix == "x" and v or v[1]
			bs[val] = b
			b.Activated:Connect(function() choice[key] = val; paint() end)
		end
		paint()
	end
	picker("MARKS", "Marks", {1, 1.5, 2, 3}, 162, "x")
	picker("XP", "XP", {1, 1.5, 2, 3}, 196, "x")
	picker("LASTS", "Hours", {{1, "1 HOUR"}, {6, "6 HOURS"}, {24, "1 DAY"}, {72, "3 DAYS"}, {168, "7 DAYS"}}, 230)
	button(pg, "START EVENT", UDim2.fromOffset(0, 272), UDim2.fromOffset(160, 32), "primary").Activated:Connect(function()
		run("StartEvent", {Name = name.Text, Marks = choice.Marks, XP = choice.XP, Hours = choice.Hours}, refresh) end)
	button(pg, "END EVENT", UDim2.fromOffset(168, 272), UDim2.fromOffset(130, 32), "danger").Activated:Connect(function()
		run("EndEvent", {}, refresh) end)
	label(pg, "Applies to match and elimination rewards, stacks with VIP. Servers that start later pick the event up too.", 11,
		UDim2.fromOffset(0, 312), UDim2.new(1, 0, 0, 16), MUTED)
end

-- LOG tab ------------------------------------------------------------------------
local logList
do
	local pg = pages.LOG
	label(pg, "ADMIN ACTIONS ON THIS SERVER (newest first)", 11, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14), RED, BOLD)
	logList = mk("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 1, -30),
		ScrollBarThickness = 4, ScrollBarImageColor3 = RED, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, pg)
	mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, logList)
end
local function loadLog()
	task.spawn(function()
		local ok, res, lines = pcall(function() return call:InvokeServer("Log") end)
		if not (ok and res and type(lines) == "table") then return end
		for _, c in ipairs(logList:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
		for i, l in ipairs(lines) do
			label(logList, l, 12, UDim2.new(), UDim2.new(1, -8, 0, 18), i == 1 and BONE or MUTED).LayoutOrder = i
		end
		if #lines == 0 then label(logList, "Nothing yet.", 12, UDim2.new(), UDim2.new(1, 0, 0, 18), MUTED) end
	end)
end
tabButtons.LOG.Activated:Connect(loadLog)

showTab("PLAYER")
setTargetText()

-- open / close ---------------------------------------------------------------------
local open = false
local function setOpen(v)
	open = v
	main.Visible = v
	if v then
		main.Size = UDim2.fromOffset(W * 0.96, H * 0.96)
		TweenService:Create(main, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {Size = UDim2.fromOffset(W, H)}):Play()
		task.spawn(refresh)
		if currentTab == "LOG" then loadLog() end
	end
end
toggle.Activated:Connect(function() setOpen(not open) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.F6 and not chatTyping() then setOpen(not open) end
end)
-- keep the list fresh while it's open
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		if open then refresh() end
	end
end)
