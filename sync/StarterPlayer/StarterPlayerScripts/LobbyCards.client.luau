-- Main-menu player card + daily quests (reworked), and the LIVE EVENT badge (lobby + in match).
-- The card / quest / event pieces are SAVED in StarterGui.MARKED_UI_EDITABLE.Lobby (so the editor shows the real
-- menu and you can restyle them there): every piece has a fixed name, and mk() reuses an existing piece of that
-- name instead of building it, keeping whatever you changed in the editor. Delete a piece to have it rebuilt from
-- this script on the next run. (To rebuild the editor copy from scratch, delete the V4 pieces and run the bake.)
-- Builds new contents inside the existing Lobby.PlayerCard / Lobby.DailyQuests frames (so the menu intro motion still
-- moves them) and reads everything straight from the player's attributes. The old pieces stay, hidden (Controller
-- still writes to them). The portrait keeps the in-game avatar viewport (ReferenceMenusV3:Card).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- BAKE: run from the command bar / tooling with _G.__LobbyCardsBake = true to write the pieces into StarterGui
local BAKE = _G.__LobbyCardsBake == true
local SAMPLE = {Level = 8, LevelXP = 890, LevelGoal = 1000, Coins = 6210, StatWins = 10, StatKills = 34, StatRounds = 26,
	Quest1Title = "Eliminate 10 players", Quest1Goal = 10, Quest1Progress = 6, Quest1Reward = 140,
	Quest2Title = "Finish a round without losing a life", Quest2Goal = 1, Quest2Progress = 1, Quest2Claimed = true, Quest2Reward = 60,
	Quest3Title = "Eliminate 3 players in one round", Quest3Goal = 3, Quest3Progress = 2, Quest3Reward = 80,
	Quest4Title = "Play for 20 minutes", Quest4Goal = 1200, Quest4Progress = 1200, Quest4Id = "Play20", Quest4Reward = 50}
local player = BAKE and {DisplayName = "Player", Name = "Player", GetAttribute = function(_, k) return SAMPLE[k] end} or Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Numberfall")
local ui = BAKE and game:GetService("StarterGui"):WaitForChild("MARKED_UI_EDITABLE") or player:WaitForChild("PlayerGui"):WaitForChild("MARKED_UI_EDITABLE")
local lobby = ui:WaitForChild("Lobby")
local card = lobby:WaitForChild("PlayerCard")
local quests = lobby:WaitForChild("DailyQuests")
local menu = shared:WaitForChild("Menu")
local NumberStyles = require(shared:WaitForChild("NumberStyles"))

local INK = Color3.fromRGB(8, 6, 8)
local TILE = Color3.fromRGB(16, 11, 13)
local LINE = Color3.fromRGB(64, 30, 38)
local RED = Color3.fromRGB(255, 23, 74)
local BLOOD = Color3.fromRGB(150, 0, 32)
local DEEP = Color3.fromRGB(70, 0, 16)
local BONE = Color3.fromRGB(240, 232, 228)
local MUTED = Color3.fromRGB(178, 162, 166) -- (brighter than the panels' grey: secondary text has to read over the busy city)
local GOLD = Color3.fromRGB(236, 190, 92)
local BAL = Font.new("rbxasset://fonts/families/Balthazar.json")
local SANS = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold)
local SANSB = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)

-- every piece gets a stable name (its own, or class + count under that parent); an existing piece is reused as is
local counts = setmetatable({}, {__mode = "k"})
local function mk(class, props, parent)
	local name = props.Name
	if not name then
		counts[parent] = counts[parent] or {}
		local n = (counts[parent][class] or 0) + 1
		counts[parent][class] = n
		name = "V4" .. class .. n
	end
	local old = parent:FindFirstChild(name)
	if old and old.ClassName == class then return old end
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Name = name
	o.Parent = parent
	return o
end
local function corner(o, r) return mk("UICorner", {CornerRadius = UDim.new(0, r or 4)}, o) end
local function stroke(o, c, t, tr) return mk("UIStroke", {Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function text(parent, props)
	local base = {BackgroundTransparency = 1, TextColor3 = BONE, FontFace = SANS, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}
	for k, v in pairs(props) do base[k] = v end
	return mk("TextLabel", base, parent)
end
local function comma(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function clock(s)
	s = math.max(0, math.floor(s))
	if s >= 86400 then return string.format("%dd %02dh", s // 86400, s % 86400 // 3600) end
	return string.format("%02d:%02d:%02d", s // 3600, s % 3600 // 60, s % 60)
end
local function marksImage()
	local ids = ui:FindFirstChild("ArtworkAssetIds")
	local v = ids and ids:FindFirstChild("MarksIcon")
	return v and v.Value ~= "" and v.Value or "rbxassetid://121549460537528"
end
local function pulse(obj, prop, a, b, t)
	local tw = TweenService:Create(obj, TweenInfo.new(t or 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {[prop] = b})
	obj[prop] = a; tw:Play()
	return tw
end

-- hide the old contents (keep the frame, its edge and texture, and the portrait)
local KEEP_CARD = {Avatar = true, Edge = true, SurfaceWear = true}
-- (the V4 pieces are this script's own, saved in the editor: never hide those)
for _, c in ipairs(card:GetChildren()) do if c:IsA("GuiObject") and not KEEP_CARD[c.Name] and not c.Name:match("^V4") then c.Visible = false end end
local KEEP_Q = {Edge = true, SurfaceWear = true}
for _, c in ipairs(quests:GetChildren()) do if c:IsA("GuiObject") and not KEEP_Q[c.Name] and not c.Name:match("^V4") then c.Visible = false end end

------------------------------------------------------------------ PLAYER CARD
card.Size = UDim2.fromOffset(365, 150)
card.ClipsDescendants = false
local edge = card:FindFirstChild("Edge"); if edge then edge.Color = Color3.fromRGB(120, 16, 38); edge.Thickness = 1 end
-- red wash from the portrait side
local wash = mk("Frame", {Name = "V4Wash", BackgroundColor3 = BLOOD, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1}, card)
mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.45, 0.88), NumberSequenceKeypoint.new(1, 1)})}, wash)
-- corner ticks
for _, c in ipairs({{0, 0}, {1, 0}, {0, 1}, {1, 1}}) do
	local ax, ay = c[1], c[2]
	mk("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(ax, ay), Position = UDim2.fromScale(ax, ay), Size = UDim2.fromOffset(14, 2), ZIndex = 7}, card)
	mk("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(ax, ay), Position = UDim2.fromScale(ax, ay), Size = UDim2.fromOffset(2, 14), ZIndex = 7}, card)
end

local avatar = card:FindFirstChild("Avatar")
if avatar then
	avatar.Position = UDim2.fromOffset(10, 10); avatar.Size = UDim2.fromOffset(112, 130); avatar.ZIndex = 4
	local aEdge = avatar:FindFirstChild("Edge"); if aEdge then aEdge.Color = Color3.fromRGB(150, 20, 46) end
	-- shade at the bottom so the level badge reads
	local shade = mk("Frame", {Name = "V4Shade", BackgroundColor3 = INK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0.42, 0), ZIndex = 20}, avatar)
	mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1)})}, shade)
end
-- level badge: a red diamond on the portrait's bottom edge
local badge = mk("Frame", {Name = "V4Level", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(66, 138),
	Size = UDim2.fromOffset(44, 44), ZIndex = 30}, card)
local diamond = mk("Frame", {BackgroundColor3 = DEEP, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30),
	Rotation = 45, ZIndex = 30}, badge)
stroke(diamond, RED, 1.5)
text(badge, {Text = "LV", FontFace = SANSB, TextSize = 10, TextColor3 = Color3.fromRGB(255, 120, 140), Size = UDim2.new(1, 0, 0, 10),
	Position = UDim2.fromOffset(0, 9), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 31})
local lvNum = text(badge, {Text = "1", FontFace = BAL, TextSize = 20, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 17),
	TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 31})

local X0, CW = 136, 218
local nameL = text(card, {Text = player.DisplayName, FontFace = BAL, TextSize = 27, Position = UDim2.fromOffset(X0, 8), Size = UDim2.fromOffset(CW - 46, 30)})
local handleL = text(card, {Text = "@" .. player.Name, TextSize = 14, TextColor3 = MUTED, Position = UDim2.fromOffset(X0, 34), Size = UDim2.fromOffset(CW, 17)})
-- VIP crest
local vip = mk("Frame", {Name = "V4Vip", BackgroundColor3 = Color3.fromRGB(40, 28, 8), Position = UDim2.fromOffset(X0 + CW - 42, 12), Size = UDim2.fromOffset(40, 18),
	ZIndex = 6, Visible = false}, card)
corner(vip, 3); stroke(vip, GOLD, 1)
text(vip, {Text = "VIP", FontFace = SANSB, TextSize = 12, TextColor3 = GOLD, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7})
-- (that saved crest stays hidden: the card now shows the same badge as over the player's head -- OWNER, MOD or VIP,
-- one only, admins get their role -- built from ReplicatedStorage.Numberfall.BadgeArt, with the same light sweep)
vip.Visible = false
local BadgeArt = (not BAKE) and require(shared:WaitForChild("BadgeArt")) or nil
local crest, crestKind, crestSweeps = nil, nil, nil
local CREST_SCALE = 1.35 -- the role badge, drawn a size up on the card
local function crestFor(p)
	local role = p:GetAttribute("ChatRole")
	if role == "OWNER" or role == "MOD" then return role end
	if p:GetAttribute("VIP") == true then return "VIP" end
	return nil
end

-- chips: marks + number style
local marksChip = mk("Frame", {BackgroundColor3 = Color3.fromRGB(34, 6, 13), Position = UDim2.fromOffset(X0, 56), Size = UDim2.fromOffset(104, 26), ZIndex = 5}, card)
corner(marksChip, 4); stroke(marksChip, Color3.fromRGB(150, 20, 46), 1)
local marksIcon = mk("ImageLabel", {BackgroundTransparency = 1, Image = marksImage(), Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(20, 20), ZIndex = 6}, marksChip)
local marksL = text(marksChip, {Text = "0", FontFace = BAL, TextSize = 20, TextColor3 = Color3.fromRGB(255, 70, 100), Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -34, 1, 0)})
local styleChip = mk("Frame", {BackgroundColor3 = TILE, Position = UDim2.fromOffset(X0 + 110, 56), Size = UDim2.fromOffset(CW - 110, 26), ZIndex = 5}, card)
corner(styleChip, 4); stroke(styleChip, LINE, 1)
local styleDot = mk("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(6, 6), ZIndex = 6}, styleChip)
corner(styleDot, 3)
local styleL = text(styleChip, {Text = "DOT MATRIX", FontFace = SANSB, TextSize = 13, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -24, 1, 0)})
-- (this chip used to name your number style; it's now the STATS button that opens your lifetime stats
-- (StarterPlayerScripts.LifetimeStats, via the OpenStats attribute). Set here as well as at build time so the copy
-- saved in the editor picks it up too)
styleDot.Visible = true; styleDot.BackgroundColor3 = RED
styleL.RichText = false; styleL.Text = "VIEW STATS"; styleL.TextColor3 = BONE; styleL.TextXAlignment = Enum.TextXAlignment.Left
styleL.Position = UDim2.fromOffset(20, 0); styleL.Size = UDim2.new(1, -24, 1, 0)
local statsBtn = mk("TextButton", {Name = "V4StatsButton", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9}, styleChip)
do
	local chipStroke = styleChip:FindFirstChildOfClass("UIStroke")
	local function hover(on)
		styleChip.BackgroundColor3 = on and Color3.fromRGB(60, 6, 20) or TILE
		if chipStroke then chipStroke.Color = on and RED or LINE end
	end
	if not BAKE then
		statsBtn.MouseEnter:Connect(function() hover(true) end)
		statsBtn.MouseLeave:Connect(function() hover(false) end)
		statsBtn.Activated:Connect(function() hover(false); player:SetAttribute("OpenStats", os.clock()) end)
	end
end

-- XP
local lvLine = text(card, {Text = "LEVEL 1", FontFace = SANSB, TextSize = 14, TextColor3 = BONE, Position = UDim2.fromOffset(X0, 88), Size = UDim2.fromOffset(110, 17)})
local xpL = text(card, {Text = "0 / 300 XP", FontFace = SANSB, TextSize = 14, TextColor3 = MUTED, Position = UDim2.fromOffset(X0 + 90, 88), Size = UDim2.fromOffset(CW - 90, 17),
	TextXAlignment = Enum.TextXAlignment.Right})
local track = mk("Frame", {BackgroundColor3 = Color3.fromRGB(26, 14, 18), Position = UDim2.fromOffset(X0, 108), Size = UDim2.fromOffset(CW, 8), ZIndex = 5}, card)
corner(track, 4); stroke(track, LINE, 1)
local fill = mk("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 6}, track)
corner(fill, 4)
mk("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(140, 0, 30), Color3.fromRGB(255, 50, 90))}, fill)
local spark = mk("Frame", {BackgroundColor3 = Color3.fromRGB(255, 200, 210), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(4, 12), ZIndex = 7}, fill)
corner(spark, 2)
for i = 1, 9 do mk("Frame", {BackgroundColor3 = INK, BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.new(i / 10, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = 8}, track) end
-- stats
local statsL = text(card, {Text = "", RichText = true, TextSize = 15, TextColor3 = MUTED, Position = UDim2.fromOffset(X0, 122), Size = UDim2.fromOffset(CW, 20)})

------------------------------------------------------------------ DAILY QUESTS
local ROWS = 4
local ROBUX_GREEN = Color3.fromRGB(0, 176, 111)
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
local STORE = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Store"))
quests.Size = UDim2.fromOffset(365, 46 + ROWS * 48 + 40) -- (+ the REROLL ALL strip under the rows)
local qEdge = quests:FindFirstChild("Edge"); if qEdge then qEdge.Color = Color3.fromRGB(120, 16, 38) end
local qWash = mk("Frame", {Name = "V4Wash", BackgroundColor3 = BLOOD, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), ZIndex = 1}, quests)
mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)})}, qWash)
local qSigil = quests:FindFirstChild("HeaderSigil")
if qSigil then qSigil.Visible = true; qSigil.Position = UDim2.fromOffset(12, 9); qSigil.ZIndex = 6 end
text(quests, {Text = "DAILY CONTRACTS", FontFace = BAL, TextSize = 19, Position = UDim2.fromOffset(42, 8), Size = UDim2.fromOffset(158, 26)})
local streakChip = mk("Frame", {BackgroundColor3 = Color3.fromRGB(34, 6, 13), Position = UDim2.fromOffset(204, 12), Size = UDim2.fromOffset(74, 18), ZIndex = 5, Visible = false}, quests)
corner(streakChip, 9); stroke(streakChip, Color3.fromRGB(150, 20, 46), 1)
local streakL = text(streakChip, {Text = "", FontFace = SANSB, TextSize = 12, TextColor3 = Color3.fromRGB(255, 120, 140), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
local resetL = text(quests, {Text = "", FontFace = MONO, TextSize = 14, TextColor3 = BONE, Position = UDim2.fromOffset(256, 18), Size = UDim2.fromOffset(98, 18),
	TextXAlignment = Enum.TextXAlignment.Right})
text(quests, {Text = "RESETS IN", FontFace = SANSB, TextSize = 11, TextColor3 = MUTED, Position = UDim2.fromOffset(256, 4), Size = UDim2.fromOffset(98, 14),
	TextXAlignment = Enum.TextXAlignment.Right})
local rule = mk("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 1), ZIndex = 5}, quests)
mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.85)})}, rule)

-- quest icons: the old rows' sheet icons (skull / clock / notebook), reused by position
local function iconFor(i)
	local old = quests:FindFirstChild("Row" .. math.min(i - 1, 2))
	if i == 4 then old = quests:FindFirstChild("Row1") end
	return old and old:FindFirstChild("Icon") and old.Icon:FindFirstChild("SheetIcon")
end
local rows = {}
for i = 1, ROWS do
	local y = 48 + (i - 1) * 48
	local row = mk("Frame", {Name = "V4Quest" .. i, BackgroundColor3 = TILE, BackgroundTransparency = 0.05, Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(345, 42), ZIndex = 4}, quests)
	corner(row, 4)
	local rs = stroke(row, LINE, 1)
	local tile = mk("Frame", {BackgroundColor3 = Color3.fromRGB(30, 8, 14), Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(30, 30), ZIndex = 5}, row)
	corner(tile, 4); stroke(tile, Color3.fromRGB(90, 18, 34), 1)
	local icon = mk("ImageLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), ZIndex = 6}, tile)
	local src = iconFor(i)
	if src then icon.Image = src.Image; icon.ImageRectOffset = src.ImageRectOffset; icon.ImageRectSize = src.ImageRectSize; icon.ImageColor3 = src.ImageColor3 end
	local title = text(row, {Text = "", TextSize = 16, Position = UDim2.fromOffset(44, 2), Size = UDim2.fromOffset(218, 21)})
	local bar = mk("Frame", {BackgroundColor3 = Color3.fromRGB(26, 14, 18), Position = UDim2.fromOffset(44, 27), Size = UDim2.fromOffset(160, 5), ZIndex = 5}, row)
	corner(bar, 3)
	local bfill = mk("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 6}, bar)
	corner(bfill, 3)
	mk("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(140, 0, 30), Color3.fromRGB(255, 50, 90))}, bfill)
	local prog = text(row, {Text = "", FontFace = MONO, TextSize = 13, TextColor3 = Color3.fromRGB(206, 192, 196), Position = UDim2.fromOffset(208, 22), Size = UDim2.fromOffset(60, 16)})
	-- reward / collect / done
	local reward = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(268, 0), Size = UDim2.fromOffset(72, 42), ZIndex = 5}, row)
	mk("Frame", {BackgroundColor3 = LINE, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 9), Size = UDim2.fromOffset(1, 24), ZIndex = 5}, reward)
	local rIcon = mk("ImageLabel", {BackgroundTransparency = 1, Image = marksImage(), Position = UDim2.fromOffset(9, 12), Size = UDim2.fromOffset(18, 18), ZIndex = 6}, reward)
	local rL = text(reward, {Text = "", FontFace = BAL, TextSize = 21, Position = UDim2.fromOffset(29, 0), Size = UDim2.new(1, -30, 1, 0)})
	local collect = mk("TextButton", {Text = "COLLECT", FontFace = SANSB, TextSize = 13, TextColor3 = BONE, AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(170, 12, 40),
		Position = UDim2.fromOffset(4, 7), Size = UDim2.fromOffset(66, 28), ZIndex = 7, Visible = false}, reward)
	corner(collect, 4)
	stroke(collect, Color3.fromRGB(255, 90, 115), 1)
	if not BAKE then collect.MouseEnter:Connect(function() collect.BackgroundColor3 = Color3.fromRGB(205, 22, 52) end)
	collect.MouseLeave:Connect(function() collect.BackgroundColor3 = Color3.fromRGB(170, 12, 40) end)
	collect.Activated:Connect(function() menu:FireServer("ClaimQuest", i) end) end
	local done = text(reward, {Text = "DONE", FontFace = SANSB, TextSize = 14, TextColor3 = Color3.fromRGB(110, 210, 140), Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, Visible = false})
	-- REROLL (2 Robux) on the first three while they're not done: LobbyService "RerollQuest" -> the Robux prompt
	local reroll
	if i <= 3 then
		reroll = mk("TextButton", {Name = "Reroll", Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(10, 30, 22), Position = UDim2.fromOffset(212, 4),
			Size = UDim2.fromOffset(52, 34), ZIndex = 7, Visible = false}, row)
		reroll:SetAttribute("NoTextBoost", true)
		corner(reroll, 4); stroke(reroll, ROBUX_GREEN, 1)
		text(reroll, {Text = "REROLL", FontFace = SANSB, TextSize = 12, TextColor3 = Color3.fromRGB(215, 245, 232), Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 13),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8})
		mk("ImageLabel", {BackgroundTransparency = 1, Image = ROBUX_ICON, ImageColor3 = ROBUX_GREEN, Position = UDim2.fromOffset(10, 16), Size = UDim2.fromOffset(15, 15), ZIndex = 8}, reroll)
		text(reroll, {Text = tostring(STORE.Products.Reroll and STORE.Products.Reroll.Robux or 2), FontFace = SANSB, TextSize = 17, TextColor3 = ROBUX_GREEN,
			Position = UDim2.fromOffset(28, 15), Size = UDim2.fromOffset(18, 17), ZIndex = 8})
		if not BAKE then reroll.Activated:Connect(function() menu:FireServer("RerollQuest", i) end) end
	end
	-- (a long title / reward scales down to fit its box instead of being cut off)
	for _, pair in ipairs({{title, 16 * 1.3, 7}, {rL, 21 * 1.3, 12}}) do
		local l = pair[1]
		l.TextScaled = true; l.TextWrapped = false; l.TextTruncate = Enum.TextTruncate.None
		mk("UITextSizeConstraint", {MaxTextSize = math.floor(pair[2]), MinTextSize = pair[3]}, l)
	end
	rows[i] = {row = row, stroke = rs, title = title, fill = bfill, prog = prog, rIcon = rIcon, rL = rL, collect = collect, done = done, tile = tile, bar = bar, reroll = reroll}
end
-- REROLL ALL (8 Robux): every daily contract that isn't done yet, in one go
local rerollAll = mk("TextButton", {Name = "RerollAll", Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(10, 30, 22),
	Position = UDim2.fromOffset(10, 48 + ROWS * 48), Size = UDim2.fromOffset(345, 32), ZIndex = 5}, quests)
rerollAll:SetAttribute("NoTextBoost", true)
corner(rerollAll, 4); stroke(rerollAll, ROBUX_GREEN, 1)
do
	local inner = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6}, rerollAll)
	mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, inner)
	text(inner, {Text = "REROLL ALL CONTRACTS", FontFace = SANSB, TextSize = 15, TextColor3 = Color3.fromRGB(215, 245, 232), AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20), LayoutOrder = 1, ZIndex = 7})
	mk("ImageLabel", {BackgroundTransparency = 1, Image = ROBUX_ICON, ImageColor3 = ROBUX_GREEN, Size = UDim2.fromOffset(17, 17), LayoutOrder = 2, ZIndex = 7}, inner)
	text(inner, {Text = tostring(STORE.Products.RerollAll and STORE.Products.RerollAll.Robux or 8), FontFace = SANSB, TextSize = 18, TextColor3 = ROBUX_GREEN,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 3, ZIndex = 7})
end
if not BAKE then rerollAll.Activated:Connect(function() menu:FireServer("RerollAllQuests") end) end

------------------------------------------------------------------ LIVE EVENT badge
local function eventLeft()
	local ends = shared:GetAttribute("EventEndsAt") or 0
	return ends - workspace:GetServerTimeNow()
end
local function eventLine()
	local bits = {}
	local m, x = shared:GetAttribute("EventMarks") or 1, shared:GetAttribute("EventXP") or 1
	if m > 1 then table.insert(bits, m .. "x MARKS") end
	if x > 1 then table.insert(bits, x .. "x XP") end
	return table.concat(bits, "  ·  ")
end
local function makeBadge(parent, width, big)
	local h = big and 50 or 34
	local b = mk("Frame", {Name = "LiveEventBadge", BackgroundColor3 = INK, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(width, h), ZIndex = 20, Visible = false}, parent)
	corner(b, 5); stroke(b, RED, 1)
	local glow = mk("Frame", {BackgroundColor3 = BLOOD, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 20}, b)
	corner(glow, 5)
	mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1)})}, glow)
	local cx = big and 20 or 14
	local dot = mk("Frame", {BackgroundColor3 = RED, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, h / 2), Size = UDim2.fromOffset(big and 10 or 8, big and 10 or 8), ZIndex = 22}, b)
	corner(dot, 5)
	local x0 = big and 38 or 26
	if big then
		-- LIVE EVENT · 2x MARKS · 1.5x XP / big name / ENDS IN + timer on the right
		local top = text(b, {Text = "LIVE EVENT", FontFace = SANSB, TextSize = 13, TextColor3 = RED, Position = UDim2.fromOffset(x0, 4), Size = UDim2.fromOffset(210, 16), ZIndex = 22, RichText = true})
		local name = text(b, {Text = "", FontFace = BAL, TextScaled = true, Position = UDim2.fromOffset(x0, 19), Size = UDim2.new(1, -x0 - 104, 0, 26), ZIndex = 22})
		mk("UITextSizeConstraint", {MaxTextSize = 24, MinTextSize = 13}, name)
		text(b, {Text = "ENDS IN", FontFace = SANSB, TextSize = 12, TextColor3 = MUTED, Position = UDim2.new(1, -104, 0, 5), Size = UDim2.fromOffset(94, 14),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22})
		local timer = text(b, {Text = "", FontFace = MONO, TextSize = 19, Position = UDim2.new(1, -104, 0, 20), Size = UDim2.fromOffset(94, 24),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22})
		return {frame = b, name = name, top = top, timer = timer}
	end
	text(b, {Text = "LIVE EVENT", FontFace = SANSB, TextSize = 11, TextColor3 = RED, Position = UDim2.fromOffset(x0, 1), Size = UDim2.fromOffset(80, 13), ZIndex = 22})
	local name = text(b, {Text = "", FontFace = BAL, TextSize = 16, Position = UDim2.fromOffset(x0, 13), Size = UDim2.new(1, -118, 0, 18), ZIndex = 22})
	local mult = text(b, {Text = "", FontFace = SANSB, TextSize = 11, TextColor3 = Color3.fromRGB(255, 140, 160), Position = UDim2.new(1, -96, 0, 2), Size = UDim2.fromOffset(88, 12),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22})
	local timer = text(b, {Text = "", FontFace = MONO, TextSize = 14, Position = UDim2.new(1, -96, 0, 13), Size = UDim2.fromOffset(88, 18),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22})
	return {frame = b, name = name, mult = mult, timer = timer}
end
-- lobby: under the daily quests, same width as the cards
local lobbyBadge = makeBadge(lobby, 365, true)
lobbyBadge.frame.Position = UDim2.fromOffset(quests.Position.X.Offset, quests.Position.Y.Offset + quests.Size.Y.Offset + 20)
-- in a match: small, top right
local hudBadge
if not BAKE then
	local hudGui = mk("ScreenGui", {Name = "LiveEventHUD", ResetOnSpawn = false, DisplayOrder = 5, IgnoreGuiInset = true}, player.PlayerGui)
	hudBadge = makeBadge(hudGui, 250)
	hudBadge.frame.AnchorPoint = Vector2.new(1, 0)
	hudBadge.frame.Position = UDim2.new(1, -14, 0, 58)
end

------------------------------------------------------------------ refresh
local function refresh()
	local p = player
	-- card
	nameL.Text = p.DisplayName
	handleL.Text = "@" .. p.Name
	vip.Visible = false
	if BadgeArt then
		local kind = crestFor(p)
		if kind ~= crestKind then
			if crest then crest:Destroy(); crest = nil; crestSweeps = nil end
			crestKind = kind
			if kind then
				crest, crestSweeps = BadgeArt.Mini(kind, card, 8)
				if crest then
					crest.Position = UDim2.fromOffset(X0 + CW, 1)
					local sc = Instance.new("UIScale"); sc.Scale = CREST_SCALE; sc.Parent = crest
				end
			end
		end
		-- (the name gives way to a wider badge)
		local w = crest and crest.Size.X.Offset * CREST_SCALE or 0
		nameL.Size = UDim2.fromOffset(CW - math.max(46, w + 6), 30)
	end
	marksL.Text = comma(p:GetAttribute("Coins") or 0)
	marksIcon.Image = marksImage()
	local level = p:GetAttribute("Level") or 1
	local into, goal = p:GetAttribute("LevelXP") or 0, math.max(1, p:GetAttribute("LevelGoal") or 300)
	lvNum.Text = tostring(level)
	lvLine.Text = "LEVEL " .. level .. "  →  " .. (level + 1)
	xpL.Text = comma(into) .. " / " .. comma(goal) .. " XP"
	fill.Size = UDim2.fromScale(math.clamp(into / goal, 0.02, 1), 1)
	local function stat(n, label) return string.format('<font color="#f0e8e4">%s</font> %s', comma(p:GetAttribute(n) or 0), label) end
	statsL.Text = stat("StatWins", "WINS") .. "   ·   " .. stat("StatKills", "ELIMS") .. "   ·   " .. stat("StatRounds", "ROUNDS")
	-- quests
	local streak = p:GetAttribute("DailyStreak") or 0
	streakChip.Visible = streak > 0
	streakL.Text = "STREAK  " .. streak
	resetL.Text = clock(86400 - math.floor(workspace:GetServerTimeNow()) % 86400)
	local anyReroll = false
	for i, r in ipairs(rows) do
		local title = p:GetAttribute("Quest" .. i .. "Title")
		r.row.Visible = title ~= nil
		if title then
			local goal2 = math.max(1, p:GetAttribute("Quest" .. i .. "Goal") or 1)
			local prog = math.min(p:GetAttribute("Quest" .. i .. "Progress") or 0, goal2)
			local claimed = p:GetAttribute("Quest" .. i .. "Claimed") == true
			local timed = p:GetAttribute("Quest" .. i .. "Id") == "Play20"
			local ready = prog >= goal2 and not claimed
			r.title.Text = title
			r.title.TextColor3 = claimed and MUTED or BONE
			r.fill.Size = UDim2.fromScale(math.clamp(prog / goal2, 0, 1), 1)
			r.prog.Text = timed and string.format("%d/%dm", prog // 60, goal2 // 60) or (prog .. " / " .. goal2)
			r.collect.Visible = ready
			r.done.Visible = claimed
			r.rIcon.Visible = not ready and not claimed
			r.rL.Visible = not ready and not claimed
			r.rL.Text = "+" .. tostring(p:GetAttribute("Quest" .. i .. "Reward") or 0)
			r.rIcon.Image = marksImage()
			r.stroke.Color = ready and RED or LINE
			r.row.BackgroundTransparency = claimed and 0.45 or 0.05
			r.tile.BackgroundTransparency = claimed and 0.5 or 0
			-- (with REROLL showing, the title / bar / count make room for it)
			local canReroll = r.reroll ~= nil and not claimed and not ready
			if r.reroll then r.reroll.Visible = canReroll end
			r.title.Size = UDim2.fromOffset(canReroll and 166 or 218, 21)
			r.bar.Size = UDim2.fromOffset(canReroll and 118 or 160, 5)
			r.prog.Position = UDim2.fromOffset(canReroll and 164 or 208, 22)

			r.prog.Size = UDim2.fromOffset(canReroll and 46 or 60, 16)
			anyReroll = anyReroll or canReroll
		end
	end
	rerollAll.Visible = anyReroll
	-- event
	local left = eventLeft()
	local live = left > 0
	local inMatch = p:GetAttribute("InMatch") == true
	if BAKE then live, left = true, 20 * 3600 + 45 * 60 end
	for _, b in ipairs({lobbyBadge, hudBadge or lobbyBadge}) do
		if live then
			b.name.Text = tostring(shared:GetAttribute("EventName") or "EVENT")
			if b.mult then b.mult.Text = eventLine() end
			if b.top then b.top.Text = 'LIVE EVENT   <font color="#ff8ca0">' .. eventLine() .. '</font>' end
			b.timer.Text = clock(left)
		end
	end
	lobbyBadge.frame.Visible = live
	if hudBadge then hudBadge.frame.Visible = live and inMatch end
end

if BAKE then
	refresh()
	if lobbyBadge.name.Text == "EVENT" then lobbyBadge.name.Text = "2X EVENT" end
	return
end
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 then return end
	acc = 0
	refresh()
end)
-- the crest's light sweep (only while the card is on screen)
local sweepAcc = 0
RunService.RenderStepped:Connect(function(dt)
	sweepAcc += dt
	if sweepAcc < 1 / 30 then return end
	sweepAcc = 0
	if crestSweeps and lobby.Visible and card.Visible then BadgeArt.Sweep(crestSweeps, os.clock(), 3.2) end
end)
refresh()
