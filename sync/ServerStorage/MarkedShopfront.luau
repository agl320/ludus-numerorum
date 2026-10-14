local S = {}
local V, C, A = Vector3.new, CFrame.new, CFrame.Angles
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local GOLD = rgb(226, 186, 108)
local rng = Random.new(77)
local function rand(a, b) return a + rng:NextNumber() * (b - a) end
local function pick(t) return t[rng:NextInteger(1, #t)] end
local function P(par, size, cf, col, mat, o)
	local p = Instance.new(o and o.cls or "Part")
	p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = col; p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	local solid = o and o.cc
	p.CanCollide = solid or false; p.CanQuery = solid or false; p.CanTouch = false
	if o and o.noshadow then p.CastShadow = false end
	if o and o.shape then p.Shape = o.shape end
	if o and o.tr then p.Transparency = o.tr end
	if o and o.refl then p.Reflectance = o.refl end
	if o and o.mv then p.MaterialVariant = o.mv end
	if o and o.name then p.Name = o.name end
	p.Parent = par
	return p
end
local function signGui(part, face, text, board, sub, ppsMul)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 25 * (ppsMul or 1)
	sg.LightInfluence = 0.1; sg.Brightness = 1.6; sg.Parent = part
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = board; bg.BorderSizePixel = 0; bg.Parent = sg
	local inner = Instance.new("Frame"); inner.AnchorPoint = Vector2.new(0.5, 0.5); inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -14, 1, -14); inner.BackgroundTransparency = 1; inner.Parent = bg
	local st = Instance.new("UIStroke"); st.Color = GOLD; st.Thickness = 3; st.Parent = inner
	local gr = Instance.new("UIGradient"); gr.Rotation = 90
	gr.Color = ColorSequence.new(board:Lerp(Color3.new(1, 1, 1), 0.08), board:Lerp(Color3.new(0, 0, 0), 0.35)); gr.Parent = bg
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.TextScaled = true
	t.Font = Enum.Font.Bodoni; t.Text = text; t.TextColor3 = GOLD
	t.TextStrokeColor3 = rgb(40, 22, 8); t.TextStrokeTransparency = 0.35
	if sub then
		t.Size = UDim2.fromScale(0.86, 0.5); t.Position = UDim2.fromScale(0.07, 0.14)
		local s2 = Instance.new("TextLabel"); s2.BackgroundTransparency = 1; s2.TextScaled = true; s2.Font = Enum.Font.Garamond
		s2.Text = sub; s2.TextColor3 = GOLD:Lerp(Color3.new(1, 1, 1), 0.1); s2.Size = UDim2.fromScale(0.7, 0.2); s2.Position = UDim2.fromScale(0.15, 0.66); s2.Parent = bg
	else
		t.Size = UDim2.fromScale(0.9, 0.66); t.Position = UDim2.fromScale(0.05, 0.17)
	end
	local tg = Instance.new("UIGradient"); tg.Rotation = 90
	tg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 230, 160)), ColorSequenceKeypoint.new(0.55, GOLD), ColorSequenceKeypoint.new(1, rgb(150, 100, 40))}); tg.Parent = t
	t.Parent = bg
	return sg
end
local function kindOf(name)
	local n = name:upper()
	if n:find("BOOK") or n:find("INK") or n:find("PRINT") or n:find("QUILL") or n:find("PAPER") or n:find("STATION") then return "books" end
	if n:find("APOTHE") or n:find("CHEMIST") or n:find("TONIC") or n:find("REMED") or n:find("HERB") or n:find("PHARM") then return "jars" end
	if n:find("BAKE") or n:find("BREAD") or n:find("PATIS") or n:find("CAKE") or n:find("TEA") or n:find("CAFE") or n:find("COFFEE") then return "bakery" end
	if n:find("HAT") or n:find("TAILOR") or n:find("CLOTH") or n:find("MILLIN") or n:find("HABER") or n:find("DRAPER") then return "hats" end
	if n:find("CLOCK") or n:find("WATCH") or n:find("JEWEL") or n:find("HOROL") or n:find("SILVER") then return "clocks" end
	if n:find("WINE") or n:find("SPIRIT") or n:find("TAVERN") or n:find("INN") or n:find("ALE") or n:find("BREW") or n:find("GIN") then return "bottles" end
	if n:find("CANDLE") or n:find("LAMP") or n:find("OIL") then return "candles" end
	return pick({"books", "jars", "bottles", "clocks", "hats", "candles", "bakery"})
end
S.kindOf = kindOf
local GOODS = {}
GOODS.books = function(par, cf, w)
	local x = -w / 2 + 0.15
	local cols = {rgb(110, 30, 28), rgb(30, 50, 40), rgb(40, 40, 70), rgb(120, 90, 50), rgb(70, 40, 30), rgb(150, 130, 100)}
	while x < w / 2 - 0.2 do
		local bw = rand(0.16, 0.26); local bh = rand(0.55, 0.85)
		P(par, V(bw, bh, rand(0.35, 0.45)), cf * C(x + bw / 2, bh / 2, 0), pick(cols), M.SmoothPlastic, {noshadow = true})
		x += bw + 0.03
	end
end
GOODS.jars = function(par, cf, w)
	for x = -w / 2 + 0.35, w / 2 - 0.35, 0.62 do
		local h = rand(0.5, 0.8)
		P(par, V(h, 0.42, 0.42), cf * C(x, h / 2, 0) * A(0, 0, math.pi / 2), pick({rgb(60, 110, 70), rgb(140, 90, 40), rgb(70, 90, 140), rgb(170, 60, 50)}), M.Glass, {shape = Enum.PartType.Cylinder, tr = 0.15, noshadow = true})
		P(par, V(0.1, 0.46, 0.46), cf * C(x, h + 0.04, 0) * A(0, 0, math.pi / 2), rgb(60, 44, 30), M.Wood, {shape = Enum.PartType.Cylinder, noshadow = true})
	end
end
GOODS.bottles = function(par, cf, w)
	for x = -w / 2 + 0.25, w / 2 - 0.25, 0.42 do
		local h = rand(0.6, 0.85)
		local col = pick({rgb(30, 60, 30), rgb(90, 50, 20), rgb(40, 20, 24), rgb(20, 40, 50)})
		P(par, V(h, 0.3, 0.3), cf * C(x, h / 2, 0) * A(0, 0, math.pi / 2), col, M.Glass, {shape = Enum.PartType.Cylinder, tr = 0.1, noshadow = true})
		P(par, V(0.3, 0.12, 0.12), cf * C(x, h + 0.15, 0) * A(0, 0, math.pi / 2), col, M.Glass, {shape = Enum.PartType.Cylinder, noshadow = true})
	end
end
GOODS.bakery = function(par, cf, w)
	for x = -w / 2 + 0.4, w / 2 - 0.4, 0.75 do
		P(par, V(0.06, 0.6, 0.6), cf * C(x, 0.03, 0) * A(0, 0, math.pi / 2), rgb(200, 196, 186), M.SmoothPlastic, {shape = Enum.PartType.Cylinder, noshadow = true})
		local k = rng:NextInteger(1, 3)
		if k == 1 then P(par, V(0.62, 0.32, 0.36), cf * C(x, 0.2, 0), rgb(168, 104, 52), M.SmoothPlastic, {noshadow = true})
		elseif k == 2 then P(par, V(0.46, 0.4, 0.46), cf * C(x, 0.22, 0), rgb(150, 86, 44), M.SmoothPlastic, {shape = Enum.PartType.Ball, noshadow = true})
		else P(par, V(0.3, 0.5, 0.5), cf * C(x, 0.18, 0) * A(0, 0, math.pi / 2), rgb(120, 50, 60), M.SmoothPlastic, {shape = Enum.PartType.Cylinder, noshadow = true}) end
	end
end
GOODS.hats = function(par, cf, w)
	for x = -w / 2 + 0.5, w / 2 - 0.5, 1.0 do
		local col = pick({rgb(24, 22, 24), rgb(70, 50, 40), rgb(50, 54, 60), rgb(90, 30, 34)})
		P(par, V(0.7, 0.1, 0.1), cf * C(x, 0.35, 0) * A(0, 0, math.pi / 2), rgb(60, 44, 30), M.Wood, {noshadow = true})
		P(par, V(0.06, 0.8, 0.8), cf * C(x, 0.72, 0) * A(0, 0, math.pi / 2), col, M.Fabric, {shape = Enum.PartType.Cylinder, noshadow = true})
		P(par, V(0.5, 0.5, 0.5), cf * C(x, 1.0, 0) * A(0, 0, math.pi / 2), col, M.Fabric, {shape = Enum.PartType.Cylinder, noshadow = true})
	end
end
GOODS.clocks = function(par, cf, w)
	for x = -w / 2 + 0.45, w / 2 - 0.45, 0.9 do
		local d = rand(0.55, 0.75)
		P(par, V(0.12, d, d), cf * C(x, d / 2 + 0.05, 0) * A(0, math.pi / 2, 0), rgb(150, 112, 50), M.Metal, {shape = Enum.PartType.Cylinder, noshadow = true})
		P(par, V(0.04, d * 0.82, d * 0.82), cf * C(x, d / 2 + 0.05, -0.08) * A(0, math.pi / 2, 0), rgb(236, 228, 210), M.SmoothPlastic, {shape = Enum.PartType.Cylinder, noshadow = true})
	end
end
GOODS.candles = function(par, cf, w)
	for x = -w / 2 + 0.25, w / 2 - 0.25, 0.4 do
		local h = rand(0.4, 0.9)
		P(par, V(h, 0.18, 0.18), cf * C(x, h / 2, 0) * A(0, 0, math.pi / 2), pick({rgb(230, 222, 200), rgb(170, 40, 40), rgb(210, 190, 120)}), M.SmoothPlastic, {shape = Enum.PartType.Cylinder, noshadow = true})
	end
end
S.GOODS = GOODS
function S.build(par, F, SW, FH, name, o)
	o = o or {}
	local m = Instance.new("Model"); m.Name = "Shopfront"; m.Parent = par
	m:SetAttribute("ShopName", name)
	local paint = o.paint or pick({rgb(28, 46, 38), rgb(58, 22, 24), rgb(26, 32, 50), rgb(30, 26, 26), rgb(62, 46, 32)})
	local paintD = paint:Lerp(Color3.new(0, 0, 0), 0.3)
	local board = paint:Lerp(Color3.new(0, 0, 0), 0.2)
	local brass = rgb(150, 112, 56)
	local pil = 0.8
	local fasciaB = FH - 2.0
	local IW = SW - 2 * pil
	for s = -1, 1, 2 do
		local x = s * (SW / 2 - pil / 2)
		P(m, V(pil + 0.24, 0.9, 1.3), F * C(x, 0.45, -0.62), paintD, M.Wood, {cc = true})
		P(m, V(pil, fasciaB - 0.9, 1.05), F * C(x, 0.9 + (fasciaB - 0.9) / 2, -0.52), paint, M.Wood, {cc = true})
		for k = -1, 1, 2 do P(m, V(0.09, fasciaB - 1.6, 0.06), F * C(x + k * 0.18, 0.9 + (fasciaB - 0.9) / 2, -1.06), paintD, M.Wood, {noshadow = true}) end
		P(m, V(pil + 0.3, 0.35, 1.3), F * C(x, fasciaB - 0.17, -0.62), brass, M.Metal)
		P(m, V(pil + 0.05, 1.7, 1.25), F * C(x, fasciaB + 0.85, -0.66), paintD, M.Wood)
		P(m, V(pil + 0.05, 0.62, 0.62), F * C(x, fasciaB + 0.25, -1.2), paintD, M.Wood, {shape = Enum.PartType.Cylinder})
		P(m, V(pil + 0.1, 0.18, 0.18), F * C(x, fasciaB + 1.55, -1.3), brass, M.Metal, {noshadow = true})
	end
	local fb = P(m, V(IW, 1.62, 0.28), F * C(0, fasciaB + 0.81, -0.98), board, M.Wood, {name = "Fascia"})
	signGui(fb, Enum.NormalId.Front, name, board, nil, 1)
	P(m, V(IW, 0.16, 0.42), F * C(0, fasciaB + 0.02, -1.0), brass, M.Metal, {noshadow = true})
	P(m, V(IW, 0.16, 0.42), F * C(0, fasciaB + 1.64, -1.0), brass, M.Metal, {noshadow = true})
	P(m, V(SW + 0.5, 0.42, 1.65), F * C(0, fasciaB + 1.93, -0.78), paintD, M.Wood, {cc = true})
	P(m, V(SW + 0.75, 0.16, 1.85), F * C(0, fasciaB + 2.22, -0.85), rgb(48, 48, 52), M.Metal)
	for x = -SW / 2 + 0.5, SW / 2 - 0.4, 0.7 do P(m, V(0.22, 0.2, 0.3), F * C(x, fasciaB + 1.66, -1.5), paintD, M.Wood, {noshadow = true}) end
	P(m, V(IW, fasciaB, 0.05), F * C(0, fasciaB / 2, -0.06), rgb(112, 70, 36), M.Neon, {noshadow = true, name = "ShopGlow"})
	local doorW = 2.6
	local DH = fasciaB - 1.0
	for s = -1, 1, 2 do P(m, V(0.16, fasciaB, 0.85), F * C(s * (doorW / 2 + 0.08), fasciaB / 2, -0.58), paintD, M.Wood, {cc = true}) end
	local leafCF = F * C(0, DH / 2, -0.3)
	P(m, V(doorW, DH * 0.45, 0.16), leafCF * C(0, -DH * 0.275, 0), paint, M.Wood, {cc = true})
	P(m, V(doorW, DH * 0.55, 0.06), leafCF * C(0, DH * 0.225, 0), rgb(200, 190, 170), M.Glass, {tr = 0.6, refl = 0.08, cc = true})
	for _, x in ipairs({-doorW / 2 + 0.1, doorW / 2 - 0.1, 0}) do P(m, V(0.18, DH * 0.55, 0.2), leafCF * C(x, DH * 0.225, 0), paint, M.Wood, {noshadow = true}) end
	P(m, V(doorW, 0.18, 0.2), leafCF * C(0, DH / 2 - 0.09, 0), paint, M.Wood, {noshadow = true})
	P(m, V(doorW - 0.6, DH * 0.3, 0.06), leafCF * C(0, -DH * 0.28, -0.1), paintD, M.Wood, {noshadow = true})
	P(m, V(0.1, 0.5, 0.1), leafCF * C(doorW / 2 - 0.35, -0.1, -0.15), brass, M.Metal, {noshadow = true})
	P(m, V(doorW + 0.32, 0.2, 0.9), F * C(0, DH + 0.1, -0.58), paintD, M.Wood)
	local tr = P(m, V(doorW, 0.75, 0.06), F * C(0, DH + 0.58, -0.32), rgb(30, 22, 16), M.Wood)
	do
		local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 30; sg.LightInfluence = 0.1; sg.Brightness = 1.5; sg.Parent = tr
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(0.8, 0.7); t.Position = UDim2.fromScale(0.1, 0.15)
		t.TextScaled = true; t.Font = Enum.Font.Garamond; t.TextColor3 = GOLD; t.Text = "No. " .. tostring(rng:NextInteger(2, 98)); t.Parent = sg
	end
	P(m, V(doorW + 0.2, 0.1, 0.95), F * C(0, 0.05, -0.55), rgb(150, 140, 126), M.Slate, {cc = true})
	local kind = o.kind or kindOf(name)
	local a = doorW / 2 + 0.16
	local b = IW / 2
	local ww = b - a
	local gTop = fasciaB - 0.12
	local gBot = 1.62
	local gh = gTop - gBot
	for s = -1, 1, 2 do
		local wx = s * (a + b) / 2
		P(m, V(ww, 1.5, 0.95), F * C(wx, 0.75, -0.55), paint, M.Wood, {cc = true})
		for k = -1, 1, 2 do P(m, V(ww / 2 - 0.35, 0.85, 0.06), F * C(wx + k * ww / 4, 0.75, -1.05), paintD, M.Wood, {noshadow = true}) end
		P(m, V(ww + 0.05, 0.16, 1.12), F * C(wx, 1.55, -0.62), brass, M.Metal)
		P(m, V(ww, gh, 0.06), F * C(wx, gBot + gh / 2, -0.88), rgb(190, 196, 204), M.Glass, {tr = 0.62, refl = 0.1, cc = true})
		P(m, V(ww, 0.2, 0.26), F * C(wx, gTop + 0.02, -0.9), paint, M.Wood, {noshadow = true})
		local nb = math.max(1, math.floor(ww / 2.1))
		for i = 1, nb - 1 do P(m, V(0.12, gh, 0.16), F * C(wx - ww / 2 + i * ww / nb, gBot + gh / 2, -0.92), paint, M.Wood, {noshadow = true}) end
		P(m, V(ww, 0.12, 0.16), F * C(wx, gBot + gh * 0.8, -0.92), paint, M.Wood, {noshadow = true})
		P(m, V(ww - 0.1, 0.1, 0.7), F * C(wx, gBot + 0.05, -0.45), rgb(70, 44, 30), M.Wood, {noshadow = true})
		local shelfY = gBot + gh * 0.42
		P(m, V(ww - 0.2, 0.1, 0.5), F * C(wx, shelfY, -0.35), rgb(70, 44, 30), M.Wood, {noshadow = true})
		GOODS[kind](m, F * C(wx, gBot + 0.1, -0.5), (ww - 0.4) / 3)
		GOODS[kind](m, F * C(wx, shelfY + 0.05, -0.38), (ww - 0.5) / 3)
	end
	if o.hanging ~= false then
		local hx = (o.hangSide or 1) * (SW / 2 - 0.45)
		local hy = FH + 2.3
		local iron = rgb(24, 22, 22)
		local arm = 2.9
		P(m, V(0.5, 0.9, 0.12), F * C(hx, hy - 0.2, -0.06), iron, M.Metal)
		P(m, V(0.12, 0.12, arm), F * C(hx, hy, -arm / 2 - 0.05), iron, M.Metal, {noshadow = true})
		local bl = math.sqrt(1.3 ^ 2 + 1.8 ^ 2)
		P(m, V(0.09, 0.09, bl), F * C(hx, hy - 0.65, -0.95) * A(math.atan2(1.3, 1.8), 0, 0), iron, M.Metal, {noshadow = true})
		P(m, V(0.08, 0.5, 0.5), F * C(hx, hy - 0.35, -1.55), iron, M.Metal, {shape = Enum.PartType.Cylinder, noshadow = true})
		P(m, V(0.2, 0.2, 0.2), F * C(hx, hy, -arm - 0.1), iron, M.Metal, {shape = Enum.PartType.Ball, noshadow = true})
		local bw, bh = 2.3, 1.5
		local bz = -0.55 - bw / 2 - 0.3
		for k = -1, 1, 2 do P(m, V(0.05, 0.35, 0.05), F * C(hx, hy - 0.22, bz + k * (bw / 2 - 0.2)), iron, M.Metal, {noshadow = true}) end
		local hb = P(m, V(0.14, bh, bw), F * C(hx, hy - 0.4 - bh / 2, bz), board, M.Wood, {name = "HangingSign"})
		P(m, V(0.2, 0.1, bw + 0.1), F * C(hx, hy - 0.4, bz), iron, M.Metal, {noshadow = true})
		local sub = ({books = "BOOKS & PRINTS", jars = "REMEDIES", bottles = "WINES & SPIRITS", bakery = "FRESH DAILY", hats = "OUTFITTERS", clocks = "CLOCKS & WATCHES", candles = "CANDLES & OIL"})[kind]
		signGui(hb, Enum.NormalId.Left, name, board, sub, 0.9)
		signGui(hb, Enum.NormalId.Right, name, board, sub, 0.9)
	end
	if o.awning then
		local col = o.awningColor or rgb(90, 30, 32)
		P(m, V(IW - 0.2, 0.08, 2.4), F * C(0, fasciaB - 0.55, -2.05) * A(math.rad(-18), 0, 0), col, M.Fabric)
		P(m, V(IW - 0.2, 0.5, 0.06), F * C(0, fasciaB - 1.15, -3.2), col, M.Fabric, {noshadow = true})
		for s = -1, 1, 2 do P(m, V(0.06, 0.06, 2.5), F * C(s * (IW / 2 - 0.2), fasciaB - 0.6, -2.0) * A(math.rad(-18), 0, 0), rgb(24, 22, 22), M.Metal, {noshadow = true}) end
	end
	return m
end
return S
