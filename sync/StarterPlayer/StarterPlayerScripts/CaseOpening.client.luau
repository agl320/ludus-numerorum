-- CASES: a page of the Shop (Shop > CASES), laid out like the Shop / Loadout content column (Numberfall.LoadoutStyle
-- look: Guru type, ink cards, one red stroke, the rarity chips the item cards use).
--   top    : THE MARKED CASE card (logo, light sweep, the odds as a coloured bar) | how many you have, OPEN, BUY
--   bottom : what's inside, one rarity at a time (its odds on the tab), with the Shop's card art
-- OPEN asks the server (LobbyService "OpenCase" -> ProfileService:OpenCase); the result comes back on
-- Numberfall.CaseResult, the reel spins onto it and the prize is shown. Odds and contents: Numberfall.Cases.
-- While it's open the Shop's own grid stands aside (attribute CasesOpen on the Shop, read by ReferenceMenusV3:Shop).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local NF = RS:WaitForChild("Numberfall")
local Cases = require(NF:WaitForChild("Cases"))
local Store = require(NF:WaitForChild("Store"))
local menu = NF:WaitForChild("Menu")
local caseResult = NF:WaitForChild("CaseResult", 30)
local ui = player:WaitForChild("PlayerGui"):WaitForChild("MARKED_UI_EDITABLE")
local shop = ui:WaitForChild("Shop")
local Style = require(ui:WaitForChild("LoadoutStyle"))
local Art; pcall(function() Art = require(ui:WaitForChild("LoadoutArt")) end)
local NumberStyles = require(NF:WaitForChild("NumberStyles"))
local Extras = require(NF:WaitForChild("Extras"))
local Catalog = require(NF:WaitForChild("Catalog"))
local HairCatalog = require(NF:WaitForChild("HairCatalog"))

local C = Style.Colors
local RED, DIM, INK, BONE, MUTED, FAINT, ACTIVE = C.RED, C.DIM, C.INK, C.BONE, C.MUTED, C.FAINT, C.ACTIVE
local CARD = Style.H.CARD
local FONT, BOLD = Style.H.FONT, Style.H.BOLD
local CHIP_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(236, 190, 92)
local GREEN = Color3.fromRGB(0, 176, 111)
local MARKS_ICON = "rbxassetid://121549460537528"
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
local X0, CW = Style.H.X0, Style.H.CW
local PW, PH = CW, 712 -- the page: the content column from under the tabs to the bottom bar

------------------------------------------------------------------ helpers
local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function outline(o, color, thick, radius)
	mk("UIStroke", {Name = "Outline", Color = color or DIM, Thickness = thick or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
	mk("UICorner", {CornerRadius = UDim.new(0, radius or 6)}, o)
end
local function label(parent, props)
	local base = {BackgroundTransparency = 1, TextColor3 = BONE, FontFace = FONT, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = (parent.ZIndex or 1) + 2}
	for k, v in pairs(props) do base[k] = v end
	local l = mk("TextLabel", base, parent)
	l:SetAttribute("NoTextBoost", true) -- (sized here on purpose)
	return l
end
local function well(parent, x, y, w, h)
	local f = mk("Frame", {Name = "ArtWell", BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(26, 12, 17), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		ZIndex = parent.ZIndex + 1, ClipsDescendants = true}, parent)
	mk("UICorner", {CornerRadius = UDim.new(0, 6)}, f)
	mk("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 16, 24), Color3.fromRGB(14, 7, 10))}, f)
	return f
end
local function button(parent, txt, x, y, w, h, size, primary)
	local b = mk("TextButton", {Text = "", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = parent.ZIndex + 2}, parent)
	Style.Button(b, txt, size, primary)
	b.Label:SetAttribute("NoTextBoost", true)
	local o = b:FindFirstChild("Outline")
	local base = o and o.Thickness or 1
	b.MouseEnter:Connect(function() if b.Active and o then o.Thickness = base + 1 end end)
	b.MouseLeave:Connect(function() if o then o.Thickness = base end end)
	return b
end
local function enable(b, on)
	b.Active = on
	b.BackgroundTransparency = on and (b:GetAttribute("Bt") or b.BackgroundTransparency) or 0.6
	if on then b:SetAttribute("Bt", nil) elseif b:GetAttribute("Bt") == nil then b:SetAttribute("Bt", 0) end
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("TextLabel") then d.TextTransparency = on and 0 or 0.55 end
		if d:IsA("ImageLabel") then d.ImageTransparency = on and 0 or 0.55 end
	end
end
-- the rarity chip the Shop cards use (gem + name, top-right of the art)
local function chip(parent, tier, x, y, anchorRight)
	local p = mk("Frame", {Name = "RarityChip", BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(10, 6, 8), BackgroundTransparency = 0.2, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22), AnchorPoint = Vector2.new(anchorRight and 1 or 0, 0), Position = UDim2.fromOffset(x, y), ZIndex = parent.ZIndex + 6}, parent)
	mk("UICorner", {CornerRadius = UDim.new(0, 4)}, p)
	mk("UIStroke", {Color = tier.Color3, Transparency = 0.25}, p)
	mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 9)}, p)
	mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, p)
	mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = tier.Color3, Size = UDim2.fromOffset(7, 7), Rotation = 45, LayoutOrder = 1, ZIndex = p.ZIndex + 1}, p)
	local t = label(p, {Text = tier.Name, FontFace = CHIP_FONT, TextSize = 12, TextColor3 = tier.Color3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), LayoutOrder = 2, ZIndex = p.ZIndex + 1})
	t.TextTruncate = Enum.TextTruncate.None
	return p
end
local function tierOf(entry) return Cases.TierById[entry and entry.Tier or ""] or Cases.TierById.Common end
local function rarityGlow(card, tier, x, y, w, h)
	local g = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = tier.Color3, Position = UDim2.fromOffset(x, y + h - 46), Size = UDim2.fromOffset(w, 46), ZIndex = card.ZIndex + 3}, card)
	mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.72)})}, g)
	mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = tier.Color3, Position = UDim2.fromOffset(x, y + h - 2), Size = UDim2.fromOffset(w, 2), ZIndex = card.ZIndex + 4}, card)
end

------------------------------------------------------------------ art (the Shop's own card art)
local gearById = {}
for _, g in ipairs(Catalog) do gearById[g.Id] = g end
local function drawArt(container, entry, rect)
	local k = entry.Kind
	local ok = Art ~= nil and k ~= "marks" and pcall(function()
		if k == "style" then Art.Hair(container, entry.Id, HairCatalog.DefaultColor, rect)
		elseif k == "outfit" then Art.Outfit(container, entry.Id, rect)
		elseif k == "mask" then Art.Mask(container, entry.Id, rect)
		elseif k == "pet" then Art.Pet(container, entry.Id, rect)
		elseif k == "killfx" then Art.KillFx(container, Extras.Get(entry.Id), rect)
		elseif k == "numstyle" then NumberStyles.Card(container, entry.Id, rect, "4729")
		elseif k == "visorcolor" then Art.Visor(container, "Standard", rect, nil, entry.Id)
		elseif k == "trailcolor" then Art.Trail(container, entry.Id, rect)
		elseif k == "gear" then Art.Kit(container, gearById[entry.Id], rect)
		else error("no art") end
	end)
	if not ok then
		-- marks: the sigil, gold
		local size = math.min(rect.Size.X.Offset, rect.Size.Y.Offset) * 0.5
		mk("ImageLabel", {BackgroundTransparency = 1, Image = MARKS_ICON, ImageColor3 = RED, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(rect.Position.X.Offset + rect.Size.X.Offset / 2, rect.Position.Y.Offset + rect.Size.Y.Offset / 2),
			Size = UDim2.fromOffset(size, size), ZIndex = container.ZIndex + 2}, container)
	end
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("GuiObject") and d.ZIndex <= container.ZIndex then d.ZIndex = container.ZIndex + 1 end
	end
end
local SHEET_IMG = "rbxassetid://117654350454534"
local SHEET = {numstyle = {0, 0}, killfx = {768, 0}, gear = {0, 256}, visorcolor = {768, 512}, outfit = {256, 768}}
local function drawIcon(container, entry, size)
	local t = tierOf(entry)
	local cell = SHEET[entry.Kind]
	if entry.Kind == "marks" then
		mk("ImageLabel", {BackgroundTransparency = 1, Image = MARKS_ICON, ImageColor3 = RED, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size), ZIndex = container.ZIndex + 2}, container)
	elseif cell then
		mk("ImageLabel", {BackgroundTransparency = 1, Image = SHEET_IMG, ImageRectOffset = Vector2.new(cell[1], cell[2]), ImageRectSize = Vector2.new(256, 256),
			ImageColor3 = typeof(entry.Color) == "Color3" and entry.Color or t.Color3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size), ZIndex = container.ZIndex + 2}, container)
	else
		label(container, {Text = ({style = "◆", mask = "▲", pet = "●", trailcolor = "»"})[entry.Kind] or "◆", FontFace = BOLD, TextSize = size * 0.8,
			TextColor3 = (entry.Kind == "trailcolor" and entry.Color and Color3.fromRGB(entry.Color[1], entry.Color[2], entry.Color[3])) or t.Color3,
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = container.ZIndex + 2})
	end
end

------------------------------------------------------------------ the page
local page = mk("Frame", {Name = "CasesPage", BackgroundTransparency = 1, Position = UDim2.fromOffset(X0, 200), Size = UDim2.fromOffset(PW, PH), ZIndex = 40, Visible = false}, shop)
local home = mk("Frame", {Name = "Home", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40}, page)

-- heading, like the Shop's section heading
label(home, {Text = "CASES", FontFace = BOLD, TextSize = 32, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(600, 36)})
local countLine = label(home, {Text = "", TextSize = 16, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 44), Size = UDim2.fromOffset(700, 20)})
-- PITY: how many opens until a Legendary+ / a Case Exclusive is guaranteed (Numberfall.Cases.Pity; ProfileService
-- publishes PityLegendary / PityExclusive = opens left)
local pityMeters = {}
for k, def in ipairs({{"PityLegendary", "Legendary", "LEGENDARY+"}, {"PityExclusive", "CaseExclusive", "EXCLUSIVE"}}) do
	local t = Cases.TierById[def[2]]
	local x = PW - (3 - k) * 262 + 12
	local f = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 12), Size = UDim2.fromOffset(250, 50), ZIndex = 41}, home)
	label(f, {Text = def[3] .. " PITY", FontFace = CHIP_FONT, TextSize = 12, TextColor3 = t.Color3, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(150, 18)})
	local left = label(f, {Text = "", FontFace = BOLD, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(100, 0), Size = UDim2.fromOffset(150, 18)})
	local track = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(30, 16, 22), Position = UDim2.fromOffset(0, 24), Size = UDim2.fromOffset(250, 6), ZIndex = 42}, f)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, track)
	local fill = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = t.Color3, Size = UDim2.fromScale(0, 1), ZIndex = 43}, track)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
	local sub = label(f, {Text = "", TextSize = 13, TextColor3 = FAINT, Position = UDim2.fromOffset(0, 32), Size = UDim2.fromOffset(250, 16)})
	pityMeters[k] = {attr = def[1], total = Cases.Pity[def[2]], left = left, fill = fill, sub = sub}
end
local function refreshPity()
	for _, m in ipairs(pityMeters) do
		local n = player:GetAttribute(m.attr) or m.total
		m.left.Text = n <= 1 and "NEXT OPEN" or (n .. " OPENS")
		m.fill.Size = UDim2.fromScale(math.clamp((m.total - n) / m.total, 0, 1), 1)
		m.sub.Text = n <= 1 and "GUARANTEED ON YOUR NEXT CASE" or ("GUARANTEED WITHIN " .. n)
	end
end
for _, m in ipairs(pityMeters) do player:GetAttributeChangedSignal(m.attr):Connect(refreshPity) end
refreshPity()

-- THE MARKED CASE card
local caseCard = mk("Frame", {BackgroundColor3 = CARD, Position = UDim2.fromOffset(0, 78), Size = UDim2.fromOffset(530, 300), ZIndex = 41}, home)
outline(caseCard, DIM, 1, 8)
local caseWell = well(caseCard, 10, 10, 510, 252)
local logoId = (ui:FindFirstChild("Lobby") and ui.Lobby:FindFirstChild("LogoArtwork") and ui.Lobby.LogoArtwork.Image) or ""
local halo = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = RED, Size = UDim2.fromScale(1, 1), ZIndex = caseWell.ZIndex + 1}, caseWell)
local haloGrad = mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.92), NumberSequenceKeypoint.new(1, 0.7)})}, halo)
-- THE MARKED CASE model (ReplicatedStorage.Numberfall.MarkedCase) on a slow turn
local CASE_MODEL = NF:WaitForChild("MarkedCase", 10)
local function caseViewport(parent, z, fov, dist)
	local vp = mk("ViewportFrame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Ambient = Color3.fromRGB(150, 122, 130),
		LightColor = Color3.fromRGB(255, 240, 240), LightDirection = Vector3.new(-0.6, -1, 0.9)}, parent)
	local wm = mk("WorldModel", {}, vp)
	local model = CASE_MODEL and CASE_MODEL:Clone()
	if model then model.Parent = wm end
	local cam = mk("Camera", {FieldOfView = fov or 30}, vp)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.1, -(dist or 9)), Vector3.new(0, 0.45, 0))
	vp.CurrentCamera = cam
	-- the lid's parts relative to its hinge, so it can swing open
	local lid = model and model:FindFirstChild("Lid")
	local hinge = lid and lid.PrimaryPart
	local rel = {}
	if hinge then for _, p in ipairs(lid:GetDescendants()) do if p:IsA("BasePart") then rel[p] = hinge.CFrame:ToObjectSpace(p.CFrame) end end end
	local base = model and model:GetPivot() or CFrame.new()
	local api = {vp = vp, model = model}
	-- turn: radians about Y; tilt / shake: small extra rotation; open: 0..1 (lid angle)
	function api.Pose(turn, open, shake)
		if not model then return end
		local rot = CFrame.Angles(0, turn or 0, 0) * (shake or CFrame.new())
		local pivot = base * rot
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") then
				if not p:GetAttribute("Rel") then p:SetAttribute("Rel", base:ToObjectSpace(p.CFrame)) end
				p.CFrame = pivot * p:GetAttribute("Rel")
			end
		end
		if hinge then
			local h0 = rel[hinge] and hinge or nil
			if not hinge:GetAttribute("Rel") then hinge:SetAttribute("Rel", base:ToObjectSpace(hinge.CFrame)) end
			local hcf = pivot * hinge:GetAttribute("Rel") * CFrame.Angles(-(open or 0) * math.rad(105), 0, 0)
			for p, r in pairs(rel) do p.CFrame = hcf * r end
		end
		local glow = model:FindFirstChild("InnerGlow")
		if glow then glow.Transparency = 1 - math.clamp((open or 0) * 2, 0, 1) end
	end
	api.Pose(0, 0)
	return api
end
local showcase = caseViewport(caseWell, caseWell.ZIndex + 3, 30, 9.2)
local logo = showcase.vp
local logoScale = mk("UIScale", {}, logo)

-- a slow light sweep across the card
local sweep = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = caseWell.ZIndex + 4}, caseWell)
local sweepGrad = mk("UIGradient", {Rotation = 20, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1),
	NumberSequenceKeypoint.new(0.5, 0.88), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1)}), Offset = Vector2.new(-1, 0)}, sweep)
-- the odds as one bar: every tier its share, best on the right
local bar = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 274), Size = UDim2.fromOffset(510, 14), ZIndex = 42, ClipsDescendants = true}, caseCard)
mk("UICorner", {CornerRadius = UDim.new(0, 3)}, bar)
do
	-- (rarest on the left, like the tabs under it)
	local x = 0
	for k = #Cases.Tiers, 1, -1 do
		local t = Cases.Tiers[k]
		local w = math.max(3, math.floor(510 * Cases.Chance(t.Id) + 0.5))
		if k == 1 then w = 510 - x end
		mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = t.Color3, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w - 2, 14), ZIndex = 43}, bar)
		x += w
	end
end

-- right: how many, OPEN, BUY
local side = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(554, 78), Size = UDim2.fromOffset(530, 300), ZIndex = 41}, home)
local bigCount = label(side, {Text = "0", FontFace = BOLD, TextSize = 84, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(160, 92), TextXAlignment = Enum.TextXAlignment.Left})
local bigCountL = label(side, {Text = "CASES TO OPEN", FontFace = BOLD, TextSize = 20, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 86), Size = UDim2.fromOffset(530, 24)})
local openB = button(side, "OPEN CASE", 0, 122, 318, 64, 26, true)
openB.Name = "OpenButton"
-- open several at once (LobbyService "OpenCases" -> ProfileService:OpenCases): each one rolls on its own
local open5B = button(side, "OPEN 5", 330, 122, 94, 64, 18, false); open5B.Name = "Open5"
local open10B = button(side, "OPEN 10", 436, 122, 94, 64, 18, false); open10B.Name = "Open10"
-- how a single case opens: the starfall cinematic (default) or the reel
local animB = button(side, "", 330, 26, 200, 34, 13, false); animB.Name = "AnimToggle"
local buyB = button(side, "", 0, 200, 259, 56, 20, false); buyB.Name = "BuyMarks"
local robuxB = button(side, "", 271, 200, 259, 56, 20, false); robuxB.Name = "BuyRobux"
local function priceRow(b, img, color, amount, textColor)
	local row = mk("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 30), ZIndex = b.ZIndex + 3}, b)
	mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, row)
	label(row, {Text = "BUY", FontFace = BOLD, TextSize = 20, TextColor3 = textColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 1}).TextTruncate = Enum.TextTruncate.None
	mk("ImageLabel", {BackgroundTransparency = 1, Image = img, ImageColor3 = color, Size = UDim2.fromOffset(24, 24), LayoutOrder = 2, ZIndex = row.ZIndex + 1}, row)
	label(row, {Text = tostring(amount), FontFace = BOLD, TextSize = 22, TextColor3 = textColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 3}).TextTruncate = Enum.TextTruncate.None
end
priceRow(buyB, MARKS_ICON, RED, Cases.Price, BONE)
priceRow(robuxB, ROBUX_ICON, GREEN, Store.Products.Case and Store.Products.Case.Robux or 25, GREEN)
local ro = robuxB:FindFirstChild("Outline"); if ro then ro.Color = Color3.fromRGB(0, 120, 76) end
robuxB.BackgroundColor3 = Color3.fromRGB(6, 22, 16)
local note = label(side, {Text = "+1 FREE CASE EVERY LEVEL UP", TextSize = 15, TextColor3 = FAINT, Position = UDim2.fromOffset(0, 270), Size = UDim2.fromOffset(530, 18)})

-- what's inside: a tab per rarity (with its odds), then its items
local TAB_W = (PW - 6 * 8) / 7
local tabs, tierPick, tierPage = {}, nil, 1
local grid = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 468), Size = UDim2.fromOffset(PW, 244), ZIndex = 41}, home)
label(home, {Text = "WHAT'S INSIDE", FontFace = BOLD, TextSize = 20, Position = UDim2.fromOffset(0, 392), Size = UDim2.fromOffset(300, 24)})
local setPreview
local insideNote = label(home, {Text = "CLICK ONE TO PREVIEW IT  ·  DUPLICATES PAY BACK " .. math.floor(Cases.DupRefund * 100) .. "% IN MARKS", TextSize = 15, TextColor3 = FAINT,
	TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(PW - 500, 392), Size = UDim2.fromOffset(500, 24)})
local order = {}
for i = #Cases.Tiers, 1, -1 do table.insert(order, Cases.Tiers[i]) end
local renderGrid
for i, t in ipairs(order) do
	local b = mk("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = INK, BackgroundTransparency = 0.05, Position = UDim2.fromOffset((i - 1) * (TAB_W + 8), 420),
		Size = UDim2.fromOffset(TAB_W, 40), ZIndex = 42}, home)
	outline(b, DIM, 1, 6)
	label(b, {Text = t.Id == "CaseExclusive" and "EXCLUSIVE" or t.Name, FontFace = CHIP_FONT, TextSize = 12, TextColor3 = t.Color3, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -60, 1, 0)})
	local pct = Cases.Chance(t.Id) * 100
	label(b, {Text = pct >= 10 and string.format("%d%%", math.floor(pct + 0.5)) or string.format("%.1f%%", pct), FontFace = BOLD, TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -62, 0, 0), Size = UDim2.fromOffset(52, 40)})
	local under = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = t.Color3, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, -16, 0, 2), ZIndex = 44, Visible = false}, b)
	tabs[t.Id] = {b = b, under = under}
	b.Activated:Connect(function() tierPick = t.Id; tierPage = 1; renderGrid() end)
end
local prevB = button(grid, "‹", 0, 0, 40, 244, 26, false)
local nextB = button(grid, "›", PW - 40, 0, 40, 244, 26, false)
local PER, CARD_W = 5, (PW - 2 * 52 - 4 * 12) / 5
-- trying a reward on: the Shop preview on the left wears it (ReferenceMenusV3:CasePreviewItem reads these)
local function previewing(entry)
	return entry ~= nil and shop:GetAttribute("CasePreviewId") == entry.Id and shop:GetAttribute("CasePreviewKind") == entry.Kind
end
function setPreview(entry)
	shop:SetAttribute("CasePreviewKind", entry and entry.Kind or nil)
	shop:SetAttribute("CasePreviewId", entry and entry.Id or nil)
end
local cards = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 0), Size = UDim2.fromOffset(PW - 104, 244), ZIndex = 41}, grid)
local function owns(entry)
	if entry.Kind == "marks" then return false end
	if entry.Own == "gear" then return player:GetAttribute("Own_" .. entry.Id) == true end
	return player:GetAttribute("OwnHair_" .. entry.Id) == true
end
function renderGrid()
	for id, tb in pairs(tabs) do
		local on = id == tierPick
		tb.b.BackgroundColor3 = on and ACTIVE or INK
		tb.b.Outline.Color = on and Cases.TierById[id].Color3 or DIM
		tb.under.Visible = on
	end
	cards:ClearAllChildren()
	local list
	if tierPick == "Marks" then
		list = {{Kind = "marks", Id = "Marks", Name = Cases.MarksDrop[1] .. " – " .. Cases.MarksDrop[2] .. " MARKS", Tier = "Marks"}}
	else
		list = Cases.InTier(tierPick)
	end
	local pages = math.max(1, math.ceil(#list / PER))
	tierPage = math.clamp(tierPage, 1, pages)
	prevB.Visible = pages > 1; nextB.Visible = pages > 1
	enable(prevB, tierPage > 1); enable(nextB, tierPage < pages)
	local t = Cases.TierById[tierPick]
	local shown = math.min(PER, #list - (tierPage - 1) * PER)
	cards.Position = UDim2.fromOffset(52 + ((PW - 104) - (shown * (CARD_W + 12) - 12)) / 2, 0)
	for i = 1, PER do
		local entry = list[(tierPage - 1) * PER + i]
		if not entry then break end
		local c = mk("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = CARD, Position = UDim2.fromOffset((i - 1) * (CARD_W + 12), 0), Size = UDim2.fromOffset(CARD_W, 244), ZIndex = 42}, cards)
		outline(c, DIM, 1, 8)
		local picked = previewing(entry)
		if picked then c.Outline.Color = BONE; c.Outline.Thickness = 2 end
		c.MouseEnter:Connect(function() if not previewing(entry) then c.Outline.Color = MUTED end end)
		c.MouseLeave:Connect(function() if not previewing(entry) then c.Outline.Color = DIM end end)
		c.Activated:Connect(function()
			if previewing(entry) then setPreview(nil) else setPreview(entry) end
			renderGrid()
		end)
		if picked then
			label(c, {Text = "PREVIEWING", FontFace = CHIP_FONT, TextSize = 11, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0,
				BackgroundColor3 = BONE, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 146), Size = UDim2.fromOffset(92, 20), ZIndex = c.ZIndex + 9})
		end
		local w = well(c, 8, 8, CARD_W - 16, 166)
		drawArt(w, entry, {Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(CARD_W - 16, 166)})
		rarityGlow(c, t, 8, 8, CARD_W - 16, 166)
		chip(c, t, CARD_W - 14, 14, true)
		if owns(entry) then
			local own = label(c, {Text = "OWNED", FontFace = CHIP_FONT, TextSize = 11, TextColor3 = BONE, TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0, BackgroundColor3 = ACTIVE, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(62, 22), ZIndex = c.ZIndex + 8})
			mk("UICorner", {CornerRadius = UDim.new(1, 0)}, own)
		end
		label(c, {Text = (entry.Name or ""):upper(), FontFace = BOLD, TextSize = 18, Position = UDim2.fromOffset(12, 180), Size = UDim2.fromOffset(CARD_W - 24, 26)})
		label(c, {Text = Cases.KindName(entry.Kind), TextSize = 14, TextColor3 = MUTED, Position = UDim2.fromOffset(12, 206), Size = UDim2.fromOffset(CARD_W - 24, 20)})
	end
end
prevB.Activated:Connect(function() if prevB.Active then tierPage -= 1; renderGrid() end end)
nextB.Activated:Connect(function() if nextB.Active then tierPage += 1; renderGrid() end end)

------------------------------------------------------------------ opening: the reel, then the prize
local stage = mk("Frame", {Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Visible = false}, page)
local stageTitle = label(stage, {Text = "", FontFace = BOLD, TextSize = 32, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(600, 36)})
local stageSub = label(stage, {Text = "", TextSize = 16, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 44), Size = UDim2.fromOffset(700, 20)})
local TW, TH, GAP = 190, 260, 14
local window = mk("Frame", {BackgroundColor3 = Color3.fromRGB(12, 7, 9), BackgroundTransparency = 0.1, Position = UDim2.fromOffset(0, 150), Size = UDim2.fromOffset(PW, TH + 40),
	ClipsDescendants = true, ZIndex = 51}, stage)
outline(window, DIM, 1, 8)
local strip = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(10, TH + 40), ZIndex = 52}, window)
for _, side in ipairs({0, 1}) do
	local f = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(12, 7, 9), AnchorPoint = Vector2.new(side, 0), Position = UDim2.fromScale(side, 0),
		Size = UDim2.fromOffset(240, TH + 40), ZIndex = 70}, window)
	mk("UIGradient", {Rotation = side == 0 and 0 or 180, Transparency = NumberSequence.new(0, 1)}, f)
end
local markerLine = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = RED, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 3, 1, 0), ZIndex = 72}, window)
for _, y in ipairs({0, 1}) do
	mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = RED, Rotation = 45, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, y, 0), Size = UDim2.fromOffset(16, 16), ZIndex = 73}, window)
end
local intro = mk("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(PW / 2, 70), Size = UDim2.fromOffset(760, 460), ZIndex = 55, Visible = false}, stage)
local introCase = caseViewport(intro, 56, 30, 9.5)
-- (rings of faint red, smallest brightest: reads as a soft radial glow, not a shape)
local introFlash = mk("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(720, 320), ZIndex = 57}, intro)
local glowRings = {}
for i = 1, 8 do
	local k = i / 8
	local ring = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = RED:Lerp(Color3.fromRGB(255, 200, 210), (1 - k) * 0.5), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(k, k), ZIndex = 57 + (9 - i)}, introFlash)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
	table.insert(glowRings, ring)
end
local function flashGlow(strength)
	local v = Instance.new("NumberValue"); v.Value = strength
	local function apply() for _, r in ipairs(glowRings) do r.BackgroundTransparency = 1 - v.Value * 0.16 end end
	apply(); v.Changed:Connect(apply)
	local tw = TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {Value = 0}); tw:Play()
	tw.Completed:Connect(function() v:Destroy() end)
end
local skipL = label(stage, {Text = "CLICK TO SKIP", TextSize = 15, TextColor3 = FAINT, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 466), Size = UDim2.fromOffset(PW, 20)})

-- the prize card
local prize = mk("Frame", {BackgroundColor3 = CARD, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(PW / 2, 80), Size = UDim2.fromOffset(560, 520), ZIndex = 60, Visible = false}, stage)
outline(prize, DIM, 2, 10)
local prizeScale = mk("UIScale", {}, prize)
local prizeFlash = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 90}, prize)
mk("UICorner", {CornerRadius = UDim.new(0, 10)}, prizeFlash)
local prizeName = label(prize, {Text = "", FontFace = BOLD, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 340), Size = UDim2.fromOffset(520, 40)})
local prizeKind = label(prize, {Text = "", TextSize = 16, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 378), Size = UDim2.fromOffset(520, 20)})
local prizeStatus = label(prize, {Text = "", FontFace = BOLD, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 404), Size = UDim2.fromOffset(520, 24), RichText = true})
local againB = button(prize, "OPEN ANOTHER", 20, 448, 330, 56, 22, true)
local doneB = button(prize, "DONE", 362, 448, 178, 56, 22, false)
local prizeArt -- (rebuilt per prize)
-- OPEN 5 / OPEN 10: the results as a grid of cards (best on the left), dealt face down in their tier's colour, then turned
local WHITE3 = Color3.new(1, 1, 1)
local MGAP = 14
local MCW, MCH = math.floor((PW - 4 * MGAP) / 5), 246
local multi = mk("Frame", {Name = "Multi", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84), Size = UDim2.fromOffset(PW, MCH * 2 + MGAP), ZIndex = 60, Visible = false}, stage)
local multiBar = mk("Frame", {Name = "MultiBar", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84 + MCH * 2 + MGAP + 22), Size = UDim2.fromOffset(PW, 56), ZIndex = 60, Visible = false}, stage)
local againMB = button(multiBar, "", PW / 2 - 350, 0, 460, 56, 22, true)
local doneMB = button(multiBar, "DONE", PW / 2 + 122, 0, 228, 56, 22, false)
local revealing, multiSkip, lastMultiN = false, false, nil
local animMode = "sky" -- "sky" (the starfall) or "reel"

------------------------------------------------------------------ sounds
-- The case's own sound kit: layered Creator Store takes (Pro Sound Effects / APM and a couple of reward stings), each
-- trimmed to the part that's wanted (Start / Duration, measured with an AudioAnalyzer) and played through the game's
-- SFX group, so the game's volume and limiter apply. {Id, Volume, Speed, Start, Duration, Delay, FadeOut}
local SFX = {
	-- a tile passing the marker: a crisp plastic click with a little metal ratchet under it
	Tick = {{Id = 15675059323, Volume = 0.34, Speed = 1.05, Duration = 0.09}, {Id = 9116785204, Volume = 0.9, Speed = 1.1, Start = 0.095, Duration = 0.05}},
	-- the case being shaken
	Rattle = {{Id = 9116797024, Volume = 1.1, Speed = 1.15, Start = 0.25, Duration = 0.9, FadeOut = 0.15}},
	-- the latch giving and the lid flying open
	Latch = {{Id = 9117022542, Volume = 0.55, Speed = 1.05, Duration = 0.3}, {Id = 15675059323, Volume = 0.3, Speed = 0.7, Duration = 0.15}},
	LidOpen = {{Id = 9120711172, Volume = 0.3, Speed = 1.2, Start = 0.15, Duration = 0.6, FadeOut = 0.2}, {Id = 130378474223829, Volume = 0.12, Speed = 0.8, Duration = 0.45, Delay = 0.05}},
	-- the reel setting off
	ReelStart = {{Id = 9120718689, Volume = 0.22, Speed = 1.1, Duration = 1.2, FadeOut = 0.4}},
	-- tension: a metal build whose hard stop lands as the reel stops (started RISER_LEAD seconds before)
	Riser = {{Id = 1837834352, Volume = 0.2, Speed = 1, Duration = 3.95, FadeOut = 0.05}},
	-- the reel landing
	Land = {{Id = 1837830050, Volume = 0.2, Speed = 1.05, Duration = 0.9, FadeOut = 0.4}, {Id = 15675059323, Volume = 0.35, Speed = 0.85, Duration = 0.12}},
	-- the prize, by tier
	Marks = {{Id = 9125509503, Volume = 0.45, Speed = 1.1, Start = 0.38, Duration = 0.6}, {Id = 134810204798705, Volume = 0.32, Speed = 1, Duration = 1.1, Delay = 0.05}},
	Common = {{Id = 130378474223829, Volume = 0.2, Speed = 1, Duration = 0.5}},
	Uncommon = {{Id = 130378474223829, Volume = 0.2, Speed = 1.12, Duration = 0.5}, {Id = 9119447936, Volume = 1.4, Speed = 1.1, Start = 0.5, Duration = 1.4, FadeOut = 0.6}},
	Rare = {{Id = 128460880879263, Volume = 0.2, Speed = 1, Duration = 2.6, FadeOut = 0.4}},
	Epic = {{Id = 128460880879263, Volume = 0.24, Speed = 1.06, Duration = 2.6, FadeOut = 0.4}, {Id = 9119447936, Volume = 1.6, Speed = 1, Start = 0.5, Duration = 2, FadeOut = 0.8}},
	Legendary = {{Id = 71806017567681, Volume = 0.26, Speed = 1, Duration = 3.4, FadeOut = 0.4}, {Id = 1837830050, Volume = 0.22, Speed = 0.95, Duration = 1.6, FadeOut = 0.8},
		{Id = 9119447936, Volume = 1.8, Speed = 1, Start = 0.5, Duration = 2.4, FadeOut = 0.8, Delay = 0.15}},
	CaseExclusive = {{Id = 71806017567681, Volume = 0.28, Speed = 0.94, Duration = 3.5, FadeOut = 0.4}, {Id = 1837830050, Volume = 0.28, Speed = 0.85, Duration = 2, FadeOut = 1},
		{Id = 9119448154, Volume = 1.8, Speed = 0.9, Start = 0.3, Duration = 3, FadeOut = 1, Delay = 0.1}},
	-- already owned: a few coins back
	Refund = {{Id = 9125509503, Volume = 0.35, Speed = 1.25, Start = 0.38, Duration = 0.5}},
	-- the starfall: a shooting star flaring into its colour
	Flare = {{Id = 9119447936, Volume = 1.5, Speed = 1.15, Start = 0.5, Duration = 1.3, FadeOut = 0.6}, {Id = 130378474223829, Volume = 0.22, Speed = 1.3, Duration = 0.5}},
}
local RISER_LEAD = 3.95
local SoundService = game:GetService("SoundService")
local sfxGroup
do
	local folder = SoundService:FindFirstChild("NumberfallAudio")
	sfxGroup = folder and folder:FindFirstChild("NumberfallSFX")
	-- load the kit up front (so the first tick isn't late)
	task.spawn(function()
		local seen, list = {}, {}
		for _, layers in pairs(SFX) do for _, l in ipairs(layers) do
			if not seen[l.Id] then seen[l.Id] = true; local p = Instance.new("Sound"); p.SoundId = "rbxassetid://" .. l.Id; p.Volume = 0; p.Parent = page; table.insert(list, p) end
		end end
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
		for _, p in ipairs(list) do p:Destroy() end
	end)
end
local rngSfx = Random.new()
-- play a kit sound; pitch multiplies every layer's speed, gain its volume. Returns the Sounds (to stop a riser early).
local function sfx(name, pitch, gain)
	local layers = SFX[name]; if not layers then return {} end
	sfxGroup = sfxGroup or (SoundService:FindFirstChild("NumberfallAudio") and SoundService.NumberfallAudio:FindFirstChild("NumberfallSFX"))
	local made = {}
	for _, l in ipairs(layers) do
		local snd = Instance.new("Sound")
		snd.SoundId = "rbxassetid://" .. l.Id
		snd.Volume = (l.Volume or 0.5) * (gain or 1)
		snd.PlaybackSpeed = (l.Speed or 1) * (pitch or 1)
		snd.SoundGroup = sfxGroup
		if l.Start or l.Duration then
			snd.PlaybackRegionsEnabled = true
			local a = l.Start or 0
			snd.PlaybackRegion = NumberRange.new(a, a + (l.Duration or 30))
		end
		snd.Parent = page
		table.insert(made, snd)
		local function go()
			if not snd.Parent then return end
			snd:Play()
			local life = (l.Duration or snd.TimeLength or 4) / math.max(snd.PlaybackSpeed, 0.1)
			if l.FadeOut and l.FadeOut > 0 then
				task.delay(math.max(0, life - l.FadeOut), function()
					if snd.Parent then TweenService:Create(snd, TweenInfo.new(l.FadeOut), {Volume = 0}):Play() end
				end)
			end
			task.delay(life + 0.3, function() snd:Destroy() end)
		end
		if l.Delay and l.Delay > 0 then task.delay(l.Delay, go) else go() end
	end
	return made
end
local function stopAll(list) for _, snd in ipairs(list or {}) do if snd.Parent then snd:Stop(); snd:Destroy() end end end

------------------------------------------------------------------ state
local isOpen, busy, spinning, skip = false, false, false, false
local hidden = {}
local function refresh()
	local n = player:GetAttribute("Cases") or 0
	local coins = player:GetAttribute("Coins") or 0
	bigCount.Text = tostring(n)
	bigCountL.Text = n == 1 and "CASE TO OPEN" or "CASES TO OPEN"
	countLine.Text = Cases.Name .. "  ·  A RANDOM COSMETIC OR MARKS"
	enable(openB, n > 0 and not busy)
	enable(open5B, n >= 5 and not busy)
	enable(open10B, n >= 10 and not busy)
	animB.Label.Text = animMode == "reel" and "ANIMATION · REEL" or "ANIMATION · STARFALL"
	if lastMultiN then
		againMB.Label.Text = n >= lastMultiN and ("OPEN " .. lastMultiN .. " MORE  (" .. n .. ")") or ("NEED " .. lastMultiN .. " CASES  (" .. n .. " LEFT)")
		enable(againMB, n >= lastMultiN and not spinning and not revealing)
	end
	enable(buyB, coins >= Cases.Price and not busy)
	enable(robuxB, not busy)
	againB.Label.Text = n > 0 and ("OPEN ANOTHER  (" .. n .. ")") or "BUY ANOTHER"
	enable(againB, (n > 0 or coins >= Cases.Price) and not spinning)
	local sb = shop:FindFirstChild("CasesButton")
	local dot = sb and sb:FindFirstChild("Count")
	if dot then dot.Visible = n > 0; dot.Text = tostring(n) end
end
for _, a in ipairs({"Cases", "Coins"}) do player:GetAttributeChangedSignal(a):Connect(refresh) end

-- the Shop's own grid / heading / paging stand aside while the page is up
local STAND_ASIDE = {"ShopStatus", "Previous", "Next", "PagerInfo", "ShopToggleStyles", "ShopToggleColours"}
local function setOpen(on)
	if on == isOpen then return end
	if spinning and not on then return end
	isOpen = on
	shop:SetAttribute("CasesOpen", on or nil)
	if on then
		-- coming from GET MARKS: close the marks page first and let its controller put its chrome back,
		-- so the stand-aside below hides (and later restores) the shop chrome once, cleanly
		local ms = shop:FindFirstChild("MarksStore")
		if ms and ms.Visible then ms.Visible = false; task.wait() end
		hidden = {}
		for _, n in ipairs(STAND_ASIDE) do local o = shop:FindFirstChild(n); if o and o.Visible then o.Visible = false; table.insert(hidden, o) end end
		for i = 0, 5 do local c = shop:FindFirstChild("Product" .. i); if c then c.Visible = false end end
		stage.Visible = false; prize.Visible = false; home.Visible = true
		tierPick = tierPick or "CaseExclusive"
		renderGrid(); refresh()
		page.Visible = true
		home.Position = UDim2.fromOffset(0, 16)
		TweenService:Create(home, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.fromOffset(0, 0)}):Play()
	else
		page.Visible = false; busy = false
		setPreview(nil)
		-- (going to GET MARKS: the marks page keeps that chrome hidden itself)
		local ms = shop:FindFirstChild("MarksStore")
		if not (ms and ms.Visible) then for _, o in ipairs(hidden) do if o.Parent then o.Visible = true end end end
		hidden = {}
	end
	-- the CASES button reads as the current tab while its page is up
	local sb = shop:FindFirstChild("CasesButton")
	if sb then
		sb.BackgroundColor3 = on and ACTIVE or INK; sb.BackgroundTransparency = on and 0 or 0.05
		local o = sb:FindFirstChild("Outline"); if o then o.Color = on and RED or DIM; o.Thickness = on and 1.4 or 1.2 end
		local l = sb:FindFirstChild("Label"); if l then l.TextColor3 = BONE end
	end
end
-- idle: the logo breathes, the halo pulses, a light sweeps across now and then
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	if not page.Visible then return end
	if not shop.Visible then setOpen(false); return end
	local t = os.clock() - t0
	logoScale.Scale = 1 + math.sin(t * 1.6) * 0.015
	showcase.Pose(math.sin(t * 0.6) * 0.45 + 0.25, 0)
	haloGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.92), NumberSequenceKeypoint.new(1, 0.68 + math.sin(t * 2) * 0.06)})
	local k = (t % 4.5) / 1.4
	sweepGrad.Offset = Vector2.new(k <= 1 and (-1 + 2 * k) or 1, 0)
end)

local function tile(entry, i, withArt)
	local t = tierOf(entry)
	local f = mk("Frame", {BackgroundColor3 = CARD, Position = UDim2.fromOffset((i - 1) * (TW + GAP), 20), Size = UDim2.fromOffset(TW, TH), ZIndex = 53}, strip)
	outline(f, t.Color3:Lerp(INK, 0.45), 1.2, 8)
	local w = well(f, 8, 8, TW - 16, 168)
	if withArt then drawArt(w, entry, {Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(TW - 16, 168)}) else drawIcon(w, entry, 84) end
	rarityGlow(f, t, 8, 8, TW - 16, 168)
	label(f, {Text = (entry.Name or ""):upper(), FontFace = BOLD, TextSize = 17, Position = UDim2.fromOffset(12, 184), Size = UDim2.fromOffset(TW - 24, 24)})
	label(f, {Text = Cases.KindName(entry.Kind), TextSize = 13, TextColor3 = MUTED, Position = UDim2.fromOffset(12, 208), Size = UDim2.fromOffset(TW - 24, 18)})
	mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = t.Color3, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 3), ZIndex = 56}, f)
	return f
end

------------------------------------------------------------------ bezier curves + the big reveal
-- cubicBezier(x1, y1, x2, y2): a CSS-style timing curve from (0,0) to (1,1); returns f(k) -> eased value (solved for
-- the curve's t by Newton steps, bisection as a fallback). y > 1 on a handle overshoots and comes back.
local function cubicBezier(x1, y1, x2, y2)
	local function bx(t) local u = 1 - t; return 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t end
	local function by(t) local u = 1 - t; return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t end
	local function dbx(t) local u = 1 - t; return 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2) end
	return function(k)
		if k <= 0 then return 0 elseif k >= 1 then return 1 end
		local t = k
		for _ = 1, 6 do
			local d = dbx(t)
			if math.abs(d) < 1e-6 then break end
			t = math.clamp(t - (bx(t) - k) / d, 0, 1)
		end
		local lo, hi = 0, 1
		for _ = 1, 14 do
			local x = bx(t)
			if math.abs(x - k) < 1e-4 then break end
			if x < k then lo = t else hi = t end
			t = (lo + hi) / 2
		end
		return by(t)
	end
end
-- a point on the quadratic bezier a -> (pulled towards c) -> b
local function quad(a, c, b, t) local u = 1 - t; return a * (u * u) + c * (2 * u * t) + b * (t * t) end
-- the reel: a quick launch and a long glide (every case); the big ones tease -- they crawl at the end, slide just past
-- the prize and settle back onto it
local REEL_EASE = cubicBezier(0.1, 0.62, 0.16, 1)
local REEL_TEASE = cubicBezier(0.08, 0.6, 0.2, 1.04)
local CARD_ARC = cubicBezier(0.22, 0.9, 0.3, 1.06)
local SPARK_EASE = cubicBezier(0.05, 0.7, 0.3, 1)
local function bigTier(tierId) return tierId == "Legendary" or tierId == "CaseExclusive" end
local function reducedMotion() return player:GetAttribute("Setting_ReducedMotion") == true end
-- the stage dims and the reel's frame pulses in the tier's colour while a big one is coming in
local dimmer = mk("Frame", {Name = "Dimmer", BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Position = UDim2.fromOffset(-X0, -400),
	Size = UDim2.new(0, PW + X0 * 2, 0, PH + 800), ZIndex = 50}, stage)
local revealFx -- (the current reveal's bits; cleared on the next open)
local function clearReveal()
	if revealFx then revealFx:Destroy(); revealFx = nil end
	dimmer.BackgroundTransparency = 1
	local o = window:FindFirstChild("Outline"); if o then o.Color = DIM; o.Thickness = 1 end
end
-- Legendary / Case Exclusive: the card arcs in on a bezier, light rays turn behind it, sparks burst out along curved
-- paths, the stage shakes; a Case Exclusive also gets slammed with a CASE EXCLUSIVE stamp
local function bigReveal(t, exclusive)
	clearReveal()
	revealFx = mk("Folder", {Name = "RevealFx"}, stage)
	local col = t.Color3
	local reduced = reducedMotion()
	local centre = Vector2.new(PW / 2, 80 + 150)
	-- light rays behind the card
	local rays = mk("Frame", {Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(centre.X, centre.Y),
		Size = UDim2.fromOffset(10, 10), ZIndex = 58}, stage)
	rays.Parent = revealFx
	local rayHolder = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 58}, stage)
	rayHolder.Parent = rays
	for i = 0, 11 do
		local r = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = col:Lerp(Color3.new(1, 1, 1), 0.25), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(i % 2 == 0 and 46 or 26, 1100), Rotation = i * 15, ZIndex = 58}, rayHolder)
		mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(0.58, 0.55), NumberSequenceKeypoint.new(1, 1)})}, r)
	end
	local glow = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = col, BackgroundTransparency = 0.55, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(centre.X, centre.Y), Size = UDim2.fromOffset(620, 620), ZIndex = 57}, stage)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, glow)
	mk("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1)})}, glow)
	glow.Parent = revealFx
	local raysScale = mk("UIScale", {Scale = 0.2}, rays)
	TweenService:Create(raysScale, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	local spinConn
	local t0 = os.clock()
	spinConn = RunService.RenderStepped:Connect(function()
		if not rays.Parent or not prize.Visible then spinConn:Disconnect(); return end
		local k = os.clock() - t0
		rayHolder.Rotation = k * (exclusive and 22 or 14)
		glow.BackgroundTransparency = 0.6 + math.sin(k * 3) * 0.06
	end)
	-- the card comes in along an arc (from low left, over the top, down into place), turning upright as it lands
	local start, ctrl, final = Vector2.new(PW / 2 - 460, 560), Vector2.new(PW / 2 - 300, -260), Vector2.new(PW / 2, 80)
	prize.Rotation = -14; prizeScale.Scale = 0.55
	local dur = reduced and 0.25 or 0.62
	task.spawn(function()
		local s = os.clock()
		while prize.Visible do
			local k = math.clamp((os.clock() - s) / dur, 0, 1)
			local e = CARD_ARC(k)
			local p = quad(start, ctrl, final, math.clamp(e, 0, 1))
			if e > 1 then p = final + (final - quad(start, ctrl, final, 0.98)) * (e - 1) * 6 end
			prize.Position = UDim2.fromOffset(p.X, p.Y)
			prize.Rotation = -14 * (1 - math.clamp(e, 0, 1))
			prizeScale.Scale = 0.55 + 0.45 * e
			if k >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		prize.Position = UDim2.fromOffset(final.X, final.Y); prize.Rotation = 0; prizeScale.Scale = 1
	end)
	-- sparks: out from behind the card along curved (quadratic bezier) paths, shrinking and fading
	if not reduced then
		local rng = Random.new()
		for i = 1, exclusive and 34 or 24 do
			local a = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(260, 470)
			local stop = centre + Vector2.new(math.cos(a), math.sin(a) * 0.75) * dist
			local side = Vector2.new(-math.sin(a), math.cos(a)) * rng:NextNumber(-170, 170)
			local ctl = centre + (stop - centre) * 0.45 + side
			local size = rng:NextNumber(6, 13)
			local sp = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = i % 3 == 0 and Color3.new(1, 1, 1) or col:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.4)),
				AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, Size = UDim2.fromOffset(size, size), ZIndex = 95}, stage)
			sp.Parent = revealFx
			local life = rng:NextNumber(0.75, 1.25)
			local delay = rng:NextNumber(0, 0.12)
			task.delay(delay, function()
				local s = os.clock()
				while sp.Parent do
					local k = math.clamp((os.clock() - s) / life, 0, 1)
					local p = quad(centre, ctl, stop, SPARK_EASE(k))
					sp.Position = UDim2.fromOffset(p.X, p.Y)
					sp.Size = UDim2.fromOffset(size * (1 - k * 0.8), size * (1 - k * 0.8))
					sp.BackgroundTransparency = k ^ 2
					sp.Rotation = 45 + k * 180
					if k >= 1 then break end
					RunService.RenderStepped:Wait()
				end
				if sp.Parent then sp:Destroy() end
			end)
		end
		-- the stage shakes as it lands
		task.spawn(function()
			local s, amp = os.clock(), exclusive and 14 or 9
			while os.clock() - s < 0.42 do
				local k = 1 - (os.clock() - s) / 0.42
				stage.Position = UDim2.fromOffset(rng:NextNumber(-amp, amp) * k, rng:NextNumber(-amp, amp) * k)
				RunService.RenderStepped:Wait()
			end
			stage.Position = UDim2.fromOffset(0, 0)
		end)
	end
	-- a Case Exclusive: the stamp
	if exclusive then
		local stamp = label(stage, {Text = "CASE EXCLUSIVE", FontFace = BOLD, TextSize = 64, TextColor3 = Color3.fromRGB(255, 44, 76), TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(PW / 2, 300), Size = UDim2.fromOffset(760, 80), Rotation = -8, TextTransparency = 1, ZIndex = 96})
		stamp.Parent = revealFx
		mk("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 1}, stamp)
		local sc = mk("UIScale", {Scale = 3}, stamp)
		task.delay(0.22, function()
			if not stamp.Parent then return end
			TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 1}):Play()
			TweenService:Create(stamp, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
			TweenService:Create(stamp.UIStroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
			task.delay(0.2, function() flashGlow(0.8) end)
			task.delay(1.5, function()
				if not stamp.Parent then return end
				TweenService:Create(stamp, TweenInfo.new(0.45), {TextTransparency = 1}):Play()
				TweenService:Create(stamp.UIStroke, TweenInfo.new(0.45), {Transparency = 1}):Play()
			end)
		end)
	end
end

local function showPrize(res)
	local t = tierOf(res)
	multi.Visible = false; multiBar.Visible = false
	stageTitle.Text = res.Tier == "CaseExclusive" and "CASE EXCLUSIVE!" or (res.Kind == "marks" and "MARKS" or "YOU GOT")
	stageSub.Text = res.Pity and "GUARANTEED BY PITY" or ""
	window.Visible = false; skipL.Visible = false
	if prizeArt then prizeArt:Destroy() end
	prizeArt = well(prize, 20, 20, 520, 300)
	prizeArt.ZIndex = 61
	drawArt(prizeArt, res, {Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(520, 300)})
	rarityGlow(prize, t, 20, 20, 520, 300)
	for _, c in ipairs(prize:GetChildren()) do if c.Name == "RarityChip" then c:Destroy() end end
	chip(prize, t, 532, 30, true)
	prize.Outline.Color = t.Color3
	prizeName.Text = (res.Name or ""):upper()
	prizeKind.Text = Cases.KindName(res.Kind)
	if res.Kind == "marks" then
		prizeStatus.Text = '<font color="#46c4c8">+' .. tostring(res.Amount) .. ' MARKS</font>'
	elseif res.Duplicate then
		prizeStatus.Text = 'ALREADY OWNED  ·  <font color="#46c4c8">+' .. tostring(res.Refund) .. ' MARKS</font>'
	else
		prizeStatus.Text = '<font color="#4cd670">NEW</font>  ·  IT\'S IN YOUR LOADOUT'
	end
	prize.Visible = true
	if res.Kind ~= "marks" then setPreview(res) end
	if bigTier(res.Tier) then
		bigReveal(t, res.Tier == "CaseExclusive")
	else
		prizeScale.Scale = 0.86
		TweenService:Create(prizeScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end
	prizeFlash.BackgroundColor3 = t.Color3; prizeFlash.BackgroundTransparency = 0.35
	TweenService:Create(prizeFlash, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
	sfx(res.Kind == "marks" and "Marks" or (SFX[res.Tier or ""] and res.Tier or "Common"))
	if res.Duplicate then task.delay(0.55, function() sfx("Refund") end) end
end

local function spin(res)
	setOpen(true)
	home.Visible = false; stage.Visible = true; prize.Visible = false; window.Visible = true; skipL.Visible = true
	multi.Visible = false; multiBar.Visible = false
	stageTitle.Text = "OPENING"; stageSub.Text = Cases.Name
	setPreview(nil)
	clearReveal()
	-- the case: a rattle, then the lid bursts open
	window.Visible = false; skipL.Visible = false; intro.Visible = true
	do
		local t0 = os.clock()
		local rng0 = Random.new()
		sfx("Rattle")
		while os.clock() - t0 < 1.25 do
			local k = os.clock() - t0
			local amp = k < 0.85 and (0.02 + k * 0.07) or 0
			local shake = CFrame.Angles(rng0:NextNumber(-amp, amp), 0, rng0:NextNumber(-amp, amp) * 1.4)
			local open = k > 0.85 and math.clamp((k - 0.85) / 0.25, 0, 1) or 0
			open = 1 - (1 - open) ^ 3
			introCase.Pose(0.35, open, shake)
			if k > 0.85 and not intro:GetAttribute("Flashed") then
				intro:SetAttribute("Flashed", true)
				flashGlow(1)
				sfx("Latch"); sfx("LidOpen")
			end
			RunService.RenderStepped:Wait()
		end
		intro:SetAttribute("Flashed", nil)
	end
	intro.Visible = false; window.Visible = true; skipL.Visible = true
	strip:ClearAllChildren()
	local rng = Random.new()
	local COUNT, WIN = 58, 50
	for i = 1, COUNT do
		tile(i == WIN and res or Cases.Roll(rng), i, i >= WIN - 9 and i <= WIN + 4)
	end
	local view = PW / 2
	local finalX = view - ((WIN - 1) * (TW + GAP) + TW / 2) + rng:NextNumber(-TW * 0.36, TW * 0.36)
	local startX = view - TW / 2 - (TW + GAP) * 2
	strip.Position = UDim2.fromOffset(startX, 0)
	spinning = true; skip = false; refresh()
	-- (a big one runs longer and on the teasing curve; the stage dims and the frame pulses in its colour near the end)
	local big = bigTier(res.Tier)
	local ease = big and REEL_TEASE or REEL_EASE
	local outlineW = window:FindFirstChild("Outline")
	local DUR, start, last = big and 7.4 or 6, os.clock(), nil
	local lastTick, riser = 0, nil
	sfx("ReelStart")
	while true do
		local k = math.clamp((os.clock() - start) / DUR, 0, 1)
		if skip then k = 1 end
		local e = ease(k)
		if big and not skip then
			local tension = math.clamp((k - 0.62) / 0.3, 0, 1)
			dimmer.BackgroundTransparency = 1 - tension * 0.5
			if outlineW then
				local pulse = 0.5 + 0.5 * math.sin(os.clock() * (6 + tension * 10))
				outlineW.Color = DIM:Lerp(tierOf(res).Color3, tension * (0.55 + 0.45 * pulse))
				outlineW.Thickness = 1 + tension * 2.5
			end
		end
		local x = startX + (finalX - startX) * e
		strip.Position = UDim2.fromOffset(x, 0)
		local idx = math.floor((view - x) / (TW + GAP))
		if idx ~= last then
			-- (capped so the fast start is a buzz, not a pile-up; slows to single clean clicks at the end)
			local now = os.clock()
			if last and not skip and now - lastTick > 0.032 then
				lastTick = now
				sfx("Tick", 0.96 + rngSfx:NextNumber(0, 0.08) + (1 - k) * 0.08, 0.55 + 0.45 * k)
			end
			last = idx
		end
		if not riser and not skip and (os.clock() - start) >= DUR - RISER_LEAD then riser = sfx("Riser") end
		if k >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	if skip then stopAll(riser) end
	if big then TweenService:Create(dimmer, TweenInfo.new(0.5), {BackgroundTransparency = 0.6}):Play() end
	sfx("Land")
	task.wait(skip and 0.05 or 0.45)
	spinning = false
	showPrize(res)
	refresh()
end

local openSingle, openMulti -- (the starfall + the multi-open grid are built inside a function: the script's top level is at Luau's 200-local limit)
;(function()
------------------------------------------------------------------ STARFALL: the cinematic (Genshin-style shooting stars)
-- Full screen: a night sky (milky way, twinkling stars, hills on the horizon). One shooting star per case (up to 7) comes
-- in on a cubic bezier; its colour tells the rarity -- pale: Common / Uncommon / Marks, blue: Rare, purple: Epic,
-- gold: Legendary, red: Case Exclusive. The best prize is the big star; a big one comes in purple and flares into its
-- colour mid-flight (a Case Exclusive flares gold, then red). They all meet in the middle, a white flash, the prize.
local RANK = {}
for i, t in ipairs(Cases.Tiers) do RANK[t.Id] = i end
local function tierRank(id) return RANK[id or ""] or 0 end
local METEOR_EASE = cubicBezier(0.38, 0.02, 0.72, 0.86)
local function meteorColor(tierId)
	if tierId == "Rare" or tierId == "Epic" or tierId == "Legendary" or tierId == "CaseExclusive" then return Cases.TierById[tierId].Color3 end
	return Color3.fromRGB(196, 222, 255)
end
local function bez3(P, s) local u = 1 - s; return P[1] * (u * u * u) + P[2] * (3 * u * u * s) + P[3] * (3 * u * s * s) + P[4] * (s * s * s) end

local skyGui = mk("ScreenGui", {Name = "CaseStarfall", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 250, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, player:WaitForChild("PlayerGui"))
local skyRoot = mk("Frame", {Name = "Sky", BorderSizePixel = 0, BackgroundColor3 = WHITE3, Size = UDim2.fromScale(1, 1), ZIndex = 1}, skyGui)
mk("UIGradient", {Rotation = 90, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(3, 5, 20)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(16, 18, 58)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 40, 96))})}, skyRoot)
local world = mk("Frame", {Name = "World", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 2}, skyRoot)
local worldScale = mk("UIScale", {}, world)
-- the milky way: two soft bands across the sky
for _, b in ipairs({{0.30, Color3.fromRGB(150, 140, 255), 0.84}, {0.11, Color3.fromRGB(255, 222, 250), 0.85}}) do
	local band = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = b[2], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromScale(1.8, b[1]),
		Rotation = -22, ZIndex = 2}, world)
	mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, b[3]), NumberSequenceKeypoint.new(1, 1)})}, band)
end
-- the stars (and a few bright ones with a four-point glint)
local stars = {}
do
	local rng = Random.new(7)
	for _ = 1, 170 do
		local s = rng:NextNumber() < 0.85 and rng:NextInteger(1, 2) or 3
		local f = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = WHITE3:Lerp(Color3.fromRGB(170, 200, 255), rng:NextNumber(0, 0.6)), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(-0.05, 1.05), rng:NextNumber(0, 1) ^ 1.4 * 0.85), Size = UDim2.fromOffset(s, s), ZIndex = 3}, world)
		if s >= 3 then mk("UICorner", {CornerRadius = UDim.new(1, 0)}, f) end
		table.insert(stars, {f = f, base = rng:NextNumber(0, 0.4), amp = rng:NextNumber(0.15, 0.55), speed = rng:NextNumber(1.2, 4), phase = rng:NextNumber(0, 6.28)})
	end
	for _ = 1, 14 do
		local g = mk("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rng:NextNumber(0.03, 0.97), rng:NextNumber(0.03, 0.6)),
			Size = UDim2.fromOffset(24, 24), ZIndex = 3}, world)
		local len = rng:NextNumber(12, 24)
		for _, sz in ipairs({{len, 1}, {1, len}}) do
			local arm = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = WHITE3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(sz[1], sz[2]), ZIndex = 3}, g)
			mk("UIGradient", {Rotation = sz[1] > sz[2] and 0 or 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)})}, arm)
		end
		local dot = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = WHITE3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), ZIndex = 4}, g)
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, dot)
		table.insert(stars, {scale = mk("UIScale", {}, g), speed = rng:NextNumber(0.8, 2), phase = rng:NextNumber(0, 6.28)})
	end
end
-- the horizon glow and the hills
local horizon = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(150, 110, 230), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.45), ZIndex = 4}, skyRoot)
mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.55)})}, horizon)
local hills = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, ClipsDescendants = true}, skyRoot)
-- {x, diameter (x screen width), top (x screen height up from the bottom), colour, z}: big circles sunk below the
-- bottom edge read as gentle domes; the far range (lit by the horizon) first
for _, h in ipairs({
	{0.1, 0.9, 0.2, Color3.fromRGB(32, 25, 64), 5}, {0.55, 1.2, 0.17, Color3.fromRGB(32, 25, 64), 5}, {0.98, 0.8, 0.22, Color3.fromRGB(32, 25, 64), 5},
	{-0.05, 0.8, 0.12, Color3.fromRGB(9, 8, 22), 6}, {0.36, 1.1, 0.09, Color3.fromRGB(9, 8, 22), 6}, {0.78, 0.9, 0.13, Color3.fromRGB(9, 8, 22), 6},
}) do
	local f = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = h[4], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(h[1], 1 - h[3]), Size = UDim2.fromScale(h[2], h[2]),
		SizeConstraint = Enum.SizeConstraint.RelativeXX, ZIndex = h[5]}, hills)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, f)
end
local tint = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = WHITE3, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1}, skyRoot)
mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0)})}, tint)
local fx = mk("Frame", {Name = "Fx", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10}, skyRoot)
local fade = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40}, skyGui)
local flash = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = WHITE3, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50}, skyGui)
local skyHit = mk("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60}, skyGui)
local skyHint = mk("TextLabel", {BackgroundTransparency = 1, Text = "CLICK TO SKIP", FontFace = FONT, TextSize = 15, TextColor3 = Color3.fromRGB(200, 205, 235), TextTransparency = 0.35,
	TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -22), Size = UDim2.fromOffset(300, 20), ZIndex = 61}, skyGui)
skyHint:SetAttribute("NoTextBoost", true)

-- a shooting star: a head (core + glow rings) and a tail of capsules laid along the path behind it
local TAIL = 26
local function newMeteor(size, span)
	local m = {size = size, span = span, segs = {}, rings = {}, boost = 1}
	m.holder = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10}, fx)
	m.glows = {}
	for i = 1, TAIL do
		local g = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE3, Visible = false, ZIndex = 9}, m.holder)
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, g)
		m.glows[i] = g
		local s = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE3, Visible = false, ZIndex = 10}, m.holder)
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, s)
		m.segs[i] = s
	end
	for i = 1, 4 do
		local r = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE3, BackgroundTransparency = 1, ZIndex = 11}, m.holder)
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, r)
		m.rings[i] = r
	end
	m.core = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE3, Visible = false, ZIndex = 12}, m.holder)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, m.core)
	return m
end
local function drawMeteor(m, s, col)
	local P, b = m.path, m.boost
	local head = bez3(P, s)
	local prev = head
	for i = 1, TAIL do
		local seg = m.segs[i]
		local ss = s - m.span * i / TAIL
		local gl = m.glows[i]
		if ss < 0 then
			seg.Visible = false; gl.Visible = false
		else
			local p = bez3(P, ss)
			local d = prev - p
			local a = i / TAIL
			local th = math.max(1, m.size * 0.85 * b * (1 - a) ^ 1.3)
			seg.Visible = true
			seg.Position = UDim2.fromOffset((p.X + prev.X) / 2, (p.Y + prev.Y) / 2)
			seg.Size = UDim2.fromOffset(d.Magnitude + th, th)
			seg.Rotation = math.deg(math.atan2(d.Y, d.X))
			seg.BackgroundColor3 = WHITE3:Lerp(col, math.min(1, a * 2.5))
			seg.BackgroundTransparency = 0.05 + 0.95 * a ^ 0.9
			local gth = th * 3.2 + 4
			gl.Visible = true
			gl.Position = seg.Position; gl.Rotation = seg.Rotation
			gl.Size = UDim2.fromOffset(d.Magnitude + gth * 0.5, gth)
			gl.BackgroundColor3 = col
			gl.BackgroundTransparency = 0.72 + 0.28 * a ^ 0.7
			prev = p
		end
	end
	m.core.Visible = true
	m.core.Position = UDim2.fromOffset(head.X, head.Y)
	m.core.Size = UDim2.fromOffset(m.size * b, m.size * b)
	for i, r in ipairs(m.rings) do
		local sz = m.size * b * (1.6 + i * 1.25)
		r.Position = m.core.Position; r.Size = UDim2.fromOffset(sz, sz)
		r.BackgroundColor3 = col; r.BackgroundTransparency = 0.45 + i * 0.12
	end
	m.head = head
end
-- glitter shed by a star (drifts down and fades)
local glitRng = Random.new()
local function glitter(pos, col, size, spread)
	local f = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE3:Lerp(col, glitRng:NextNumber(0.2, 0.8)), Rotation = 45,
		Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size, size), ZIndex = 9}, fx)
	local life = glitRng:NextNumber(0.5, 0.9)
	TweenService:Create(f, TweenInfo.new(life, Enum.EasingStyle.Quad), {Position = UDim2.fromOffset(pos.X + glitRng:NextNumber(-spread, spread), pos.Y + glitRng:NextNumber(-spread * 0.3, spread)),
		Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}):Play()
	task.delay(life + 0.05, function() f:Destroy() end)
end
local function ringBurst(pos, col, from, to, life, thick)
	local r = mk("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(from, from), ZIndex = 13}, fx)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, r)
	local st = mk("UIStroke", {Color = col, Thickness = thick or 4}, r)
	TweenService:Create(r, TweenInfo.new(life, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(to, to)}):Play()
	TweenService:Create(st, TweenInfo.new(life, Enum.EasingStyle.Quad), {Transparency = 1, Thickness = 1}):Play()
	task.delay(life + 0.05, function() r:Destroy() end)
end

local skySkip, skyRunning = false, false
skyHit.Activated:Connect(function() if skyRunning then skySkip = true end end)
-- runs the cinematic for these results; calls onImpact() under the white flash, then fades the sky away
local function starfall(list, onImpact)
	skyRunning, skySkip = true, false
	local reduced = reducedMotion()
	local best = list[1]
	for _, r in ipairs(list) do if tierRank(r.Tier) > tierRank(best.Tier) then best = r end end
	local big, exclusive = bigTier(best.Tier), best.Tier == "CaseExclusive"
	fx:ClearAllChildren()
	tint.BackgroundTransparency = 1; flash.BackgroundTransparency = 1; fade.BackgroundTransparency = 0
	skyRoot.Visible = true; skyHit.Visible = true; skyHint.Visible = true
	worldScale.Scale = 1; world.Position = UDim2.fromScale(0.5, 0.5)
	skyGui.Enabled = true
	RunService.RenderStepped:Wait()
	local W, H = skyGui.AbsoluteSize.X, skyGui.AbsoluteSize.Y
	local C = Vector2.new(W * 0.5, H * 0.46)
	local T_IN = reduced and 0.15 or 0.45
	local START = T_IN + 0.1
	local FLIGHT = reduced and 1.4 or (big and 3.2 or 2.4)
	local IMPACT = START + FLIGHT
	TweenService:Create(fade, TweenInfo.new(T_IN), {BackgroundTransparency = 1}):Play()
	-- the riser's hard stop lands on the impact
	SFX.SkyRiser = {{Id = 1837834352, Volume = 0.2, Speed = 1, Start = math.max(0, 3.95 - IMPACT), Duration = math.min(3.95, IMPACT), FadeOut = 0.05}}
	local riser = sfx("SkyRiser")
	local rng = Random.new()
	local meteors = {}
	-- the others (smaller, each in its own colour), landing just before the main one
	local others, taken = {}, false
	for _, r in ipairs(list) do if r == best and not taken then taken = true else table.insert(others, r) end end
	table.sort(others, function(a, b) return tierRank(a.Tier) > tierRank(b.Tier) end)
	for j = 1, math.min(#others, 6) do
		local m = newMeteor(rng:NextNumber(6, 9), rng:NextNumber(0.2, 0.3))
		local P0 = rng:NextNumber() < 0.6 and Vector2.new(rng:NextNumber(W * 0.3, W * 1.05), -H * 0.08) or Vector2.new(W * 1.06, rng:NextNumber(H * 0.02, H * 0.4))
		local tgt = C + Vector2.new(rng:NextNumber(-60, 60), rng:NextNumber(-30, 30))
		local d = tgt - P0
		local bend = Vector2.new(-d.Y, d.X).Unit * d.Magnitude * rng:NextNumber(-0.2, 0.2)
		m.path = {P0, P0 + d * 0.33 + bend, P0 + d * 0.66 + bend, tgt}
		m.t0 = START + rng:NextNumber(0.05, 0.8) * (reduced and 0.4 or 1)
		m.dur = math.max(0.6, IMPACT - 0.15 - rng:NextNumber(0, 0.45) - m.t0)
		m.col = meteorColor(others[j].Tier); m.target = m.col; m.flares = {}
		table.insert(meteors, m)
	end
	-- the main star: the best prize
	local main = newMeteor(#list > 1 and 20 or 18, 0.46)
	main.main = true
	main.path = {Vector2.new(W * 1.06, -H * 0.04), Vector2.new(W * 0.72, H * 0.0), Vector2.new(W * 0.64, H * 0.34), C}
	main.t0, main.dur = START, FLIGHT
	main.col = big and meteorColor("Epic") or meteorColor(best.Tier)
	main.target = main.col
	main.flares = {}
	if exclusive then main.flares = {{0.4, meteorColor("Legendary")}, {0.68, meteorColor("CaseExclusive")}}
	elseif big then main.flares = {{0.56, meteorColor("Legendary")}} end
	table.insert(meteors, main)
	-- where they meet: a glow that builds as they close in
	local nexus = {}
	for i = 1, 5 do
		local r = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(C.X, C.Y), BackgroundColor3 = WHITE3, BackgroundTransparency = 1, ZIndex = 8}, fx)
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, r)
		nexus[i] = r
	end
	local t0, last, shakeUntil = os.clock(), os.clock(), 0
	while not skySkip do
		local now = os.clock()
		local t, dt = now - t0, now - last
		last = now
		for _, s in ipairs(stars) do
			local v = math.sin(t * s.speed + s.phase)
			if s.f then s.f.BackgroundTransparency = s.base + s.amp * (0.5 + 0.5 * v) else s.scale.Scale = 0.55 + 0.45 * v end
		end
		if not reduced then worldScale.Scale = 1 + 0.07 * math.clamp(t / IMPACT, 0, 1) end
		if t < shakeUntil then
			local a = (shakeUntil - t) * 22
			world.Position = UDim2.new(0.5, rng:NextNumber(-a, a), 0.5, rng:NextNumber(-a, a))
		else
			world.Position = UDim2.fromScale(0.5, 0.5)
		end
		local p = math.clamp((t - (IMPACT - 1.3)) / 1.3, 0, 1)
		for i, r in ipairs(nexus) do
			local sz = (30 + 300 * p) * (0.35 + i * 0.22)
			r.Size = UDim2.fromOffset(sz, sz)
			r.BackgroundColor3 = WHITE3:Lerp(main.col, i / 5)
			r.BackgroundTransparency = 1 - p * p * (0.5 - i * 0.07)
		end
		for _, m in ipairs(meteors) do
			local k = (t - m.t0) / m.dur
			if k >= 0 and not m.done then
				if k >= 1 then
					m.done = true; m.holder.Visible = false
					if not m.main then ringBurst(m.path[4], m.col, 8, 110, 0.55, 3) end
				else
					for _, f in ipairs(m.flares) do
						if not f.done and k >= f[1] and m.head then
							f.done = true
							m.target = f[2]; m.boost = 2.6
							ringBurst(m.head, f[2], 24, 360, 0.75, 6)
							for _ = 1, 14 do glitter(m.head, f[2], rng:NextNumber(5, 11), 90) end
							tint.BackgroundColor3 = f[2]; tint.BackgroundTransparency = 0.6
							TweenService:Create(tint, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.82}):Play()
							if not reduced then shakeUntil = t + 0.35 end
							sfx("Flare")
						end
					end
					m.col = m.col:Lerp(m.target, math.min(1, dt * 7))
					m.boost = 1 + (m.boost - 1) * math.exp(-dt * 5)
					drawMeteor(m, METEOR_EASE(k), m.col)
					if t - (m.lastG or 0) > (m.main and 0.022 or 0.05) then
						m.lastG = t
						glitter(m.head, m.col, rng:NextNumber(3, 6) * (m.main and 1.4 or 1), 40)
					end
				end
			end
		end
		if main.done then break end
		RunService.RenderStepped:Wait()
	end
	if skySkip then stopAll(riser) end
	-- the flash, and the prize under it
	flash.BackgroundColor3 = WHITE3:Lerp(meteorColor(best.Tier), 0.12)
	TweenService:Create(flash, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
	sfx("Land")
	task.wait(0.14)
	skyRoot.Visible = false; skyHit.Visible = false; skyHint.Visible = false
	fx:ClearAllChildren()
	skyRunning = false
	onImpact()
	TweenService:Create(flash, TweenInfo.new(reduced and 0.25 or 0.65, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
	task.delay(0.7, function() if not skyRunning then skyGui.Enabled = false end end)
end

------------------------------------------------------------------ OPEN 5 / OPEN 10: the results grid
-- sparks out from a point along curved (quadratic bezier) paths
local function burstAt(parent, centre, col, count, z, reach)
	local rng = Random.new()
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local stop = centre + Vector2.new(math.cos(a), math.sin(a)) * rng:NextNumber(reach * 0.5, reach)
		local ctl = centre + (stop - centre) * 0.45 + Vector2.new(-math.sin(a), math.cos(a)) * rng:NextNumber(-reach * 0.35, reach * 0.35)
		local size = rng:NextNumber(5, 10)
		local sp = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = i % 3 == 0 and WHITE3 or col:Lerp(WHITE3, rng:NextNumber(0, 0.4)), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(centre.X, centre.Y), ZIndex = z}, parent)
		local life = rng:NextNumber(0.6, 1)
		task.spawn(function()
			local s = os.clock()
			while sp.Parent do
				local k = math.clamp((os.clock() - s) / life, 0, 1)
				local p = quad(centre, ctl, stop, SPARK_EASE(k))
				sp.Position = UDim2.fromOffset(p.X, p.Y)
				sp.Size = UDim2.fromOffset(size * (1 - k * 0.8), size * (1 - k * 0.8))
				sp.BackgroundTransparency = k ^ 2
				if k >= 1 then break end
				RunService.RenderStepped:Wait()
			end
			if sp.Parent then sp:Destroy() end
		end)
	end
end
local multiCards = {}
local function markPicked()
	for _, c in ipairs(multiCards) do
		local o = c.card:FindFirstChild("Outline")
		if o then local on = previewing(c.res); o.Color = on and BONE or c.tier.Color3; o.Thickness = on and 2.5 or 1.5 end
	end
end
local function multiCard(res, i, n)
	local t = tierOf(res)
	local row, col = (i - 1) // 5, (i - 1) % 5
	local inRow = math.min(5, n - row * 5)
	local x0 = (PW - (inRow * (MCW + MGAP) - MGAP)) / 2
	local y0 = n <= 5 and 110 or 0
	local cx, cy = x0 + col * (MCW + MGAP) + MCW / 2, y0 + row * (MCH + MGAP) + MCH / 2
	local holder = mk("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(MCW, MCH), ZIndex = 61}, multi)
	local scale = mk("UIScale", {Scale = 0}, holder)
	local aura = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = t.Color3, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 26, 1, 26), ZIndex = 61}, holder)
	mk("UICorner", {CornerRadius = UDim.new(0, 16)}, aura)
	local c = mk("TextButton", {Text = "", AutoButtonColor = false, BackgroundColor3 = CARD, Size = UDim2.fromScale(1, 1), ZIndex = 62}, holder)
	outline(c, t.Color3:Lerp(INK, 0.35), 1.5, 8)
	local w = well(c, 8, 8, MCW - 16, 150)
	drawArt(w, res, {Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(MCW - 16, 150)})
	rarityGlow(c, t, 8, 8, MCW - 16, 150)
	chip(c, t, MCW - 14, 14, true)
	label(c, {Text = (res.Name or ""):upper(), FontFace = BOLD, TextSize = 16, Position = UDim2.fromOffset(12, 164), Size = UDim2.fromOffset(MCW - 24, 22)})
	label(c, {Text = Cases.KindName(res.Kind), TextSize = 13, TextColor3 = MUTED, Position = UDim2.fromOffset(12, 186), Size = UDim2.fromOffset(MCW - 24, 18)})
	local st
	if res.Kind == "marks" then st = '<font color="#46c4c8">+' .. tostring(res.Amount) .. ' MARKS</font>'
	elseif res.Duplicate then st = 'OWNED  ·  <font color="#46c4c8">+' .. tostring(res.Refund) .. ' MARKS</font>'
	else st = '<font color="#4cd670">NEW</font>' end
	label(c, {Text = st, RichText = true, FontFace = BOLD, TextSize = 14, Position = UDim2.fromOffset(12, 212), Size = UDim2.fromOffset(MCW - 24, 22)})
	if res.Pity then
		local pt = label(c, {Text = "PITY", FontFace = CHIP_FONT, TextSize = 11, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0,
			BackgroundColor3 = t.Color3, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(44, 22), ZIndex = c.ZIndex + 8})
		mk("UICorner", {CornerRadius = UDim.new(1, 0)}, pt)
	end
	c.Activated:Connect(function()
		if revealing then multiSkip = true; return end
		if res.Kind == "marks" then return end
		if previewing(res) then setPreview(nil) else setPreview(res) end
		markPicked()
	end)
	local flashF = mk("Frame", {BorderSizePixel = 0, BackgroundColor3 = WHITE3, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 118}, holder)
	mk("UICorner", {CornerRadius = UDim.new(0, 8)}, flashF)
	-- the back: the tier's colour and the marks sigil
	local cover = mk("TextButton", {Name = "Cover", Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = WHITE3, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 120}, holder)
	mk("UICorner", {CornerRadius = UDim.new(0, 8)}, cover)
	mk("UIGradient", {Rotation = 90, Color = ColorSequence.new(t.Color3:Lerp(WHITE3, 0.18), t.Color3:Lerp(Color3.new(0, 0, 0), 0.6))}, cover)
	mk("UIStroke", {Color = t.Color3:Lerp(WHITE3, 0.45), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, cover)
	mk("ImageLabel", {BackgroundTransparency = 1, Image = MARKS_ICON, ImageColor3 = WHITE3, ImageTransparency = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(72, 72), ZIndex = 121}, cover)
	cover.Activated:Connect(function() if revealing then multiSkip = true end end)
	return {holder = holder, scale = scale, card = c, cover = cover, flash = flashF, aura = aura, tier = t, res = res, centre = Vector2.new(cx, cy)}
end
local function turn(c, fast)
	local d = fast and 0.06 or 0.2
	TweenService:Create(c.cover, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.fromScale(0, 1)}):Play()
	task.delay(d, function() if c.cover.Parent then c.cover:Destroy() end end)
	c.flash.BackgroundColor3 = WHITE3:Lerp(c.tier.Color3, 0.35); c.flash.BackgroundTransparency = fast and 0.7 or 0.2
	TweenService:Create(c.flash, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
	if bigTier(c.res.Tier) then
		c.aura.BackgroundTransparency = 0.3
		TweenService:Create(c.aura, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.72}):Play()
	end
	local o = c.card:FindFirstChild("Outline"); if o then o.Color = c.tier.Color3 end
end
local function showMulti(list)
	local n = #list
	lastMultiN = n
	multi:ClearAllChildren()
	multi.Visible = true; multiBar.Visible = true; prize.Visible = false; window.Visible = false; skipL.Visible = false
	stageTitle.Text = n .. " CASES"; stageSub.Text = "CLICK TO SKIP"
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b) return tierRank(a.Tier) > tierRank(b.Tier) end)
	local cards = {}
	multiCards = cards
	for i, res in ipairs(sorted) do cards[i] = multiCard(res, i, n) end
	revealing, multiSkip = true, false
	refresh()
	task.spawn(function()
		-- dealt face down, left to right
		for i, c in ipairs(cards) do
			TweenService:Create(c.scale, TweenInfo.new(multiSkip and 0.05 or 0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			if not multiSkip then sfx("Tick", 0.9 + i * 0.035, 0.9); task.wait(0.055) end
		end
		if not multiSkip then task.wait(0.4) end
		-- turned from the right, so the best (on the left) comes last
		for i = n, 1, -1 do
			if cards ~= multiCards then return end
			local c = cards[i]
			local big = bigTier(c.res.Tier)
			if big and not multiSkip then
				TweenService:Create(c.scale, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Scale = 1.07}):Play()
				task.wait(0.42)
			end
			turn(c, multiSkip)
			if big then TweenService:Create(c.scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end
			if not multiSkip then
				if big then
					sfx(c.res.Tier)
					burstAt(multi, c.centre, c.tier.Color3, c.res.Tier == "CaseExclusive" and 30 or 22, 130, 230)
					task.wait(0.55)
				elseif tierRank(c.res.Tier) >= tierRank("Rare") then
					sfx(c.res.Tier, 1, 0.6); task.wait(0.24)
				else
					sfx("Common", 1 + (n - i) * 0.03, 0.75); task.wait(0.13)
				end
			end
		end
		if cards ~= multiCards then return end
		revealing = false
		-- the tally
		local newN, dupN, marks, pity = 0, 0, 0, false
		for _, r in ipairs(list) do
			if r.Kind == "marks" then marks += r.Amount or 0
			elseif r.Duplicate then dupN += 1; marks += r.Refund or 0
			elseif r.New then newN += 1 end
			if r.Pity then pity = true end
		end
		stageTitle.Text = n .. " CASES OPENED"
		stageSub.Text = newN .. " NEW  ·  " .. dupN .. (dupN == 1 and " DUPLICATE" or " DUPLICATES") .. "  ·  +" .. marks .. " MARKS" .. (pity and "  ·  PITY HIT" or "") .. "  ·  CLICK ONE TO TRY IT ON"
		-- the best thing that isn't marks goes on the preview
		for _, c in ipairs(cards) do if c.res.Kind ~= "marks" then setPreview(c.res); break end end
		markPicked()
		if marks > 0 then task.delay(0.15, function() sfx("Refund") end) end
		refresh()
	end)
end
local function stageFor()
	setOpen(true)
	home.Visible = false; stage.Visible = true; prize.Visible = false; window.Visible = false; intro.Visible = false; skipL.Visible = false
	multi.Visible = false; multiBar.Visible = false
	stageTitle.Text = ""; stageSub.Text = ""
	setPreview(nil); clearReveal()
end
-- one case: the starfall (or the reel, if that's picked), then the prize
function openSingle(res)
	if animMode == "reel" then spin(res); return end
	stageFor()
	spinning = true; refresh()
	starfall({res}, function()
		spinning = false
		showPrize(res)
		refresh()
	end)
end
-- 5 / 10 cases: the starfall, then the grid
function openMulti(list)
	stageFor()
	spinning = true; refresh()
	starfall(list, function()
		spinning = false
		showMulti(list)
		refresh()
	end)
end
UIS.InputBegan:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.Space then return end
	if skyRunning then skySkip = true end
	if revealing then multiSkip = true end
end)
end)()

local timeoutToken
local function requestOpen()
	if busy then return end
	if (player:GetAttribute("Cases") or 0) < 1 then return end
	busy = true; refresh()
	menu:FireServer("OpenCase")
	local token = {}
	timeoutToken = token
	task.delay(6, function() if timeoutToken == token and busy and not spinning then busy = false; refresh() end end)
end
local function requestMulti(n)
	if busy then return end
	if (player:GetAttribute("Cases") or 0) < n then return end
	busy = true; refresh()
	menu:FireServer("OpenCases", n)
	local token = {}
	timeoutToken = token
	task.delay(6, function() if timeoutToken == token and busy and not spinning then busy = false; refresh() end end)
end
if caseResult then
	caseResult.OnClientEvent:Connect(function(res)
		timeoutToken = nil
		if type(res) ~= "table" then busy = false; refresh(); return end
		if not shop.Visible then busy = false; refresh(); return end
		if res.Multi then
			if type(res.Results) == "table" and #res.Results > 0 then openMulti(res.Results) else busy = false; refresh() end
		else
			openSingle(res)
		end
	end)
end
local function backHome()
	if spinning then return end
	clearReveal()
	multiSkip = true
	stage.Visible = false; prize.Visible = false; multi.Visible = false; multiBar.Visible = false; home.Visible = true; busy = false
	renderGrid(); refresh()
end
openB.Activated:Connect(function() if openB.Active then requestOpen() end end)
open5B.Activated:Connect(function() if open5B.Active then requestMulti(5) end end)
open10B.Activated:Connect(function() if open10B.Active then requestMulti(10) end end)
animB.Activated:Connect(function() animMode = animMode == "reel" and "sky" or "reel"; refresh() end)
againMB.Activated:Connect(function()
	if spinning or revealing or not againMB.Active or not lastMultiN then return end
	busy = false
	requestMulti(lastMultiN)
end)
doneMB.Activated:Connect(backHome)
againB.Activated:Connect(function()
	if spinning or not againB.Active then return end
	busy = false
	if (player:GetAttribute("Cases") or 0) > 0 then requestOpen() else menu:FireServer("BuyCase"); backHome() end
end)
doneB.Activated:Connect(backHome)
buyB.Activated:Connect(function() if buyB.Active then menu:FireServer("BuyCase") end end)
robuxB.Activated:Connect(function() if robuxB.Active then menu:FireServer("BuyCaseRobux") end end)
window.InputBegan:Connect(function(input)
	if spinning and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then skip = true end
end)
UIS.InputBegan:Connect(function(input)
	if not page.Visible then return end
	if input.KeyCode == Enum.KeyCode.Space and spinning then skip = true end
end)

------------------------------------------------------------------ the Shop's CASES button (left of GET MARKS)
local function shopButton()
	local marks = shop:WaitForChild("TabMarks", 30); if not marks then return end
	task.wait(1) -- (after the Shop's own styling has placed GET MARKS)
	local b = shop:FindFirstChild("CasesButton")
	if not b then
		b = marks:Clone(); b.Name = "CasesButton"
		for _, c in ipairs(b:GetChildren()) do if c:IsA("UIScale") then c:Destroy() end end
		b.Parent = shop
	end
	local function place()
		b.AnchorPoint = marks.AnchorPoint
		b.Position = marks.Position - UDim2.fromOffset(marks.Size.X.Offset + 12, 0)
		b.Size = marks.Size
		b.Visible = marks.Visible
	end
	place()
	for _, prop in ipairs({"Position", "Size", "AnchorPoint", "Visible"}) do marks:GetPropertyChangedSignal(prop):Connect(place) end
	task.delay(2, place)
	local l = b:FindFirstChild("Label"); if l then l.Text = "CASES" end
	if b:IsA("TextButton") then b.Text = "" end
	local count = b:FindFirstChild("Count") or mk("TextLabel", {Name = "Count", BackgroundColor3 = RED, TextColor3 = BONE, FontFace = CHIP_FONT, TextSize = 12,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(22, 22), ZIndex = (b.ZIndex or 1) + 5, Text = "0"}, b)
	count:SetAttribute("NoTextBoost", true)
	if not count:FindFirstChildOfClass("UICorner") then mk("UICorner", {CornerRadius = UDim.new(1, 0)}, count) end
	b.Activated:Connect(function() setOpen(not isOpen) end)
	-- a category tab or GET MARKS takes the page down again
	marks.Activated:Connect(function() setOpen(false) end)
	for _, c in ipairs(shop:GetChildren()) do
		if c:IsA("GuiButton") and c.Name:match("^Tab%d+$") then c.Activated:Connect(function() setOpen(false) end) end
	end
	refresh()
end
task.spawn(shopButton)
refresh()
