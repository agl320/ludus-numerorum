local K = {}
local rad, pi, floor, max, min, abs, sqrt = math.rad, math.pi, math.floor, math.max, math.min, math.abs, math.sqrt
local C, A, V = CFrame.new, CFrame.Angles, Vector3.new
local M = Enum.Material
K.C, K.A, K.V, K.M, K.rad = C, A, V, M, rad
local R = CFrame.new()
local root
K.rng = Random.new(2026)

function K.init(model, rootCF, seed)
	root = model; R = rootCF; K.R = R; K.root = model
	K.rng = Random.new(seed or 2026)
end
function K.seed(s) K.rng = Random.new(s) end
function K.rand(a, b) return K.rng:NextNumber(a, b) end
function K.int(a, b) return K.rng:NextInteger(a, b) end
function K.chance(p) return K.rng:NextNumber() < p end
function K.pick(t) return t[K.rng:NextInteger(1, #t)] end
function K.rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local rgb = K.rgb

K.col = {
	iron = rgb(26, 23, 24), ironHi = rgb(44, 40, 40), brass = rgb(150, 116, 60),
	stone = rgb(112, 102, 94), stoneDark = rgb(74, 68, 66), stoneLight = rgb(150, 140, 128),
	trim = rgb(172, 160, 144), cream = rgb(196, 180, 156),
	slate = rgb(44, 42, 52), slate2 = rgb(58, 52, 60), roofRed = rgb(92, 50, 44),
	wood = rgb(66, 44, 32), woodDark = rgb(38, 26, 22), woodLight = rgb(112, 82, 58),
	glass = rgb(26, 26, 34), soil = rgb(56, 40, 30),
	leaf = rgb(58, 74, 40), leafDark = rgb(36, 50, 30), grass = rgb(70, 82, 46), moss = rgb(74, 86, 52),
	blood = rgb(130, 22, 30), petal = rgb(170, 34, 44),
}
K.walls = {
	{mat = M.Brick, color = rgb(124, 62, 50)}, {mat = M.Brick, color = rgb(100, 52, 46)}, {mat = M.Brick, color = rgb(88, 70, 64)},
	{mat = M.Plaster, color = rgb(184, 166, 142)}, {mat = M.Plaster, color = rgb(148, 120, 110)}, {mat = M.Plaster, color = rgb(118, 112, 122)},
	{mat = M.Plaster, color = rgb(160, 140, 104)}, {mat = M.Limestone, color = rgb(150, 138, 122)}, {mat = M.Limestone, color = rgb(116, 108, 102)},
}
K.shopColors = {rgb(40, 52, 46), rgb(60, 28, 30), rgb(30, 34, 50), rgb(46, 34, 26), rgb(24, 24, 26)}
K.awnings = {
	{rgb(120, 26, 32), rgb(196, 176, 150)}, {rgb(36, 54, 44), rgb(186, 170, 140)}, {rgb(60, 36, 64), rgb(190, 174, 150)},
	{rgb(110, 60, 30), rgb(40, 30, 26)}, {rgb(30, 36, 60), rgb(180, 168, 150)},
}
K.flowers = {rgb(176, 30, 44), rgb(220, 210, 200), rgb(120, 60, 150), rgb(210, 90, 120), rgb(230, 150, 60), rgb(150, 20, 40)}
K.SHOPS = {"APOTHECARY", "BOOKBINDER", "INK & QUILL", "TAILOR", "BAKERY", "PAWNBROKER", "CLOCKMAKER", "THE CROW'S REST", "CANDLEMAKER",
	"CARTOGRAPHER", "FLORIST", "PRINTING HOUSE", "HATTER", "TOBACCONIST", "CHEMIST", "STATIONER", "LOCKSMITH", "UNDERTAKER", "TEA ROOM", "CURIOSITIES"}

local function apply(p, props) if props then for k, v in pairs(props) do p[k] = v end end end
local function finish(p, size, cf, color, mat, props, par)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size; p.CFrame = R * cf; p.Color = color or K.col.stone
	p.Material = mat or M.SmoothPlastic
	apply(p, props)
	p.Parent = par
	return p
end
function K.P(par, size, cf, color, mat, props) return finish(Instance.new("Part"), size, cf, color, mat, props, par) end
function K.W(par, size, cf, color, mat, props) return finish(Instance.new("WedgePart"), size, cf, color, mat, props, par) end
function K.CW(par, size, cf, color, mat, props) return finish(Instance.new("CornerWedgePart"), size, cf, color, mat, props, par) end
function K.deco(p, noShadow)
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	if noShadow then p.CastShadow = false end
	return p
end
function K.D(par, size, cf, color, mat, props) return K.deco(K.P(par, size, cf, color, mat, props)) end
function K.Ds(par, size, cf, color, mat, props) return K.deco(K.P(par, size, cf, color, mat, props), true) end
function K.DW(par, size, cf, color, mat, props) return K.deco(K.W(par, size, cf, color, mat, props)) end
function K.cyl(par, len, dia, cf, color, mat, props)
	local p = Instance.new("Part"); p.Shape = Enum.PartType.Cylinder
	return finish(p, V(len, dia, dia), cf, color, mat, props, par)
end
function K.vcyl(par, h, dia, pos, color, mat, props) return K.cyl(par, h, dia, C(pos) * A(0, 0, pi / 2), color, mat, props) end
function K.ball(par, dia, pos, color, mat, props)
	local p = Instance.new("Part"); p.Shape = Enum.PartType.Ball
	return finish(p, V(dia, dia, dia), C(pos), color, mat, props, par)
end
function K.model(name, par) local m = Instance.new("Model"); m.Name = name; m.Parent = par or root; return m end
function K.box(par, a, b, color, mat, props)
	local mn, mx = a:Min(b), a:Max(b)
	return K.P(par, mx - mn, C((mn + mx) / 2), color, mat, props)
end
function K.slab(par, a, b, width, thick, color, mat, props)
	thick = thick or 1
	local cf = CFrame.lookAt((a + b) / 2, b)
	return K.P(par, V(width, thick, (b - a).Magnitude), cf * C(0, -thick / 2, 0), color, mat, props)
end
function K.beam(par, a, b, t, color, mat, props)
	local cf = CFrame.lookAt((a + b) / 2, b)
	return K.P(par, V(t, t, (b - a).Magnitude), cf, color, mat, props)
end
function K.ramp(par, from, to, width, color, mat, props)
	if to.Y < from.Y then from, to = to, from end
	local flat = V(to.X - from.X, 0, to.Z - from.Z)
	local dir = flat.Unit
	local rise = to.Y - from.Y
	local mid = V((from.X + to.X) / 2, from.Y + rise / 2, (from.Z + to.Z) / 2)
	return K.W(par, V(width, rise, flat.Magnitude), CFrame.lookAt(mid, mid - dir), color, mat, props)
end
function K.stairs(par, from, to, width, color, mat, o)
	o = o or {}
	if to.Y < from.Y then from, to = to, from end
	local S = K.model("Stairs", par)
	local flat = V(to.X - from.X, 0, to.Z - from.Z)
	local len, dir = flat.Magnitude, flat.Unit
	local rise = to.Y - from.Y
	local n = max(2, math.ceil(rise / 0.85))
	local run = len / n
	local look = CFrame.lookAt(V(), dir)
	local baseY = o.baseY or from.Y
	for i = 1, n do
		local top = from.Y + i * rise / n
		local c = from + dir * ((i - 0.5) * run)
		local h = top - baseY
		K.D(S, V(width, h, run + 0.03), C(c.X, baseY + h / 2, c.Z) * look, color, mat)
		if o.nosing ~= false then K.Ds(S, V(width + 0.12, 0.16, 0.3), C(c.X, top - 0.08, c.Z) * look * C(0, 0, run / 2 - 0.1), o.nose or K.col.stoneLight, M.Limestone) end
	end
	local col = K.ramp(S, from, to, width, color, mat, {Transparency = 1, Name = "StairCollider", CastShadow = false})
	if o.sides then
		for s = -1, 1, 2 do
			local off = V(-dir.Z, 0, dir.X) * (width / 2 + 0.35) * s
			K.ramp(S, from + off, to + off, 0.7, o.sideColor or K.col.stoneDark, M.Limestone)
		end
	end
	return S, col
end
function K.truss(par, pos, h, yaw, color)
	-- builds an iron rung ladder (rungs along local X, wall side +Z)
	local m = K.model("Ladder", par)
	local base = R * C(pos) * A(0, yaw or 0, 0)
	local col = color or K.col.iron
	local w = 1.9
	local function p(size, cf, name, collide)
		local x = Instance.new("Part"); x.Anchored = true; x.Size = size; x.CFrame = cf; x.Color = col; x.Material = M.Metal
		x.TopSurface = Enum.SurfaceType.Smooth; x.BottomSurface = Enum.SurfaceType.Smooth; x.Name = name; x.CanCollide = collide ~= false; x.Parent = m
		return x
	end
	for s = -1, 1, 2 do p(V(0.22, h + 0.6, 0.3), base * C(s * w / 2, (h + 0.6) / 2, 0), "Rail") end
	for s = -1, 1, 2 do p(V(0.18, 1.4, 0.18), base * C(s * w / 2, h + 0.6, 0.35) * A(rad(-35), 0, 0), "Grip", false) end
	local y = 0.9
	while y < h + 0.2 do p(V(w, 0.18, 0.18), base * C(0, y, 0), "Rung"); y += 1.0 end
	for by = 2, h, 6 do for s = -1, 1, 2 do p(V(0.16, 0.16, 0.9), base * C(s * w / 2, by, 0.5), "Bracket", false) end end
	return m
end

function K.railing(par, a, b, h, o)
	o = o or {}
	local col = o.color or K.col.iron
	local len = (b - a).Magnitude
	if len < 0.2 then return end
	local u = (b - a).Unit
	local cfm = CFrame.lookAt((a + b) / 2, b)
	K.D(par, V(o.rail or 0.22, 0.22, len + 0.2), cfm * C(0, h, 0), col, o.mat or M.Metal)
	K.Ds(par, V(0.14, 0.14, len), cfm * C(0, 0.4, 0), col, o.mat or M.Metal)
	local sp = o.spacing or 0.8
	local n = max(1, floor(len / sp + 0.5))
	for i = 0, n do
		local p = a + u * (len * i / n)
		local post = (i == 0 or i == n) and 0.24 or (o.post or 0.1)
		K.Ds(par, V(post, h, post), C(p.X, p.Y + h / 2, p.Z) * (cfm - cfm.Position), col, o.mat or M.Metal)
		if o.spikes and i % 2 == 0 then K.Ds(par, V(0.22, 0.5, 0.22), C(p.X, p.Y + h + 0.25, p.Z) * A(0, pi / 4, 0), col, M.Metal) end
	end
	if o.collide ~= false then
		K.P(par, V(0.5, h + (o.extra or 0.6), len), cfm * C(0, (h + (o.extra or 0.6)) / 2, 0), col, M.Metal, {Transparency = 1, CastShadow = false, Name = "RailCollider"})
	end
end
function K.balustrade(par, a, b, h, o)
	o = o or {}
	local col = o.color or K.col.stoneLight
	local len = (b - a).Magnitude
	local u = (b - a).Unit
	local cfm = CFrame.lookAt((a + b) / 2, b)
	K.P(par, V(0.9, 0.35, len + 0.6), cfm * C(0, h - 0.17, 0), col, M.Limestone)
	K.P(par, V(0.8, 0.4, len), cfm * C(0, 0.2, 0), col, M.Limestone)
	local n = max(1, floor(len / 0.75))
	for i = 1, n do
		local p = a + u * (len * (i - 0.5) / n)
		K.vcyl(par, h - 0.75, 0.42, V(p.X, p.Y + 0.4 + (h - 0.75) / 2, p.Z), col, M.Limestone, {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
	end
	for _, p in ipairs({a, b}) do K.P(par, V(1.1, h + 0.2, 1.1), C(p.X, p.Y + (h + 0.2) / 2, p.Z) * (cfm - cfm.Position), col, M.Limestone) end
	K.P(par, V(0.6, h, len), cfm * C(0, h / 2, 0), col, M.Limestone, {Transparency = 1, CastShadow = false, Name = "RailCollider"})
end
function K.sign(par, cf, w, h, text, o)
	o = o or {}
	local b = K.D(par, V(w, h, 0.25), cf * C(0, 0, -0.13), o.color or K.col.woodDark, M.Wood)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 36
	sg.LightInfluence = 0.6; sg.Brightness = 1.2; sg.Parent = b
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.84); t.Position = UDim2.fromScale(0, 0.08); t.BackgroundTransparency = 1; t.Text = text
	t.TextScaled = true; t.Font = o.font or Enum.Font.Fondamento; t.TextColor3 = o.textColor or rgb(222, 184, 112)
	t.Parent = sg
	K.D(par, V(w + 0.3, 0.18, 0.4), cf * C(0, h / 2 + 0.05, -0.15), K.col.brass, M.Metal)
	K.D(par, V(w + 0.3, 0.18, 0.4), cf * C(0, -h / 2 - 0.05, -0.15), K.col.brass, M.Metal)
	return b
end
function K.flowerBox(par, cf, w)
	K.D(par, V(w, 0.75, 0.8), cf * C(0, -0.38, -0.42), K.col.woodDark, M.WoodPlanks)
	local n = max(2, floor(w / 0.6))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * w / n
		K.ball(par, K.rand(0.7, 1.0), (cf * C(x, 0.2, -0.45)).Position, K.rng:NextNumber() < 0.5 and K.col.leaf or K.col.leafDark, M.LeafyGrass, {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
		if K.chance(0.7) then K.ball(par, K.rand(0.3, 0.45), (cf * C(x + K.rand(-0.2, 0.2), 0.6, -0.6)).Position, K.pick(K.flowers), M.SmoothPlastic, {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}) end
	end
	for i = 1, 2 do K.Ds(par, V(K.rand(0.6, 1.2), K.rand(0.8, 1.6), 0.25), cf * C(K.rand(-w / 2, w / 2), -1, -0.85), K.col.leafDark, M.LeafyGrass) end
end
function K.ivy(par, cf, w, h)
	local n = floor(w * h / 9) + 4
	for i = 1, n do
		local t = K.rng:NextNumber() ^ 1.4
		local y = t * h
		local spread = w / 2 * (1 - t * 0.6)
		local s = V(K.rand(1.0, 2.8), K.rand(1.0, 3.0), K.rand(0.18, 0.4))
		local c = K.col.leafDark:Lerp(K.col.leaf, K.rand(0, 1))
		K.Ds(par, s, cf * C(K.rand(-spread, spread), y, -s.Z / 2 - K.rand(0, 0.12)) * A(0, 0, K.rand(-0.6, 0.6)), c, M.LeafyGrass)
	end
end
local function meshClone(name, cf, height)
	local src = game:GetService("ServerStorage").MarkedNature:FindFirstChild(name)
	local m = src:Clone()
	local _, s = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / s.Y)
	m:PivotTo(R * cf)
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true; d.CanTouch = false; d.CollisionFidelity = Enum.CollisionFidelity.Box end end
	return m
end
local function glow(par, cf, size, range, bright)
	local g = K.D(par, size, cf, rgb(255, 184, 104), M.Neon, {Name = "Glass", Transparency = 0.25, CastShadow = false})
	local l = Instance.new("PointLight"); l.Color = rgb(255, 170, 80); l.Brightness = bright; l.Range = range; l.Shadows = false; l.Parent = g
	return g
end
local function lampClone(name, cf, height)
	local src = game:GetService("ServerStorage").MarkedNature:FindFirstChild(name)
	local m = src:Clone()
	if height then local mp = m:FindFirstChildWhichIsA("MeshPart", true); m:ScaleTo(m:GetScale() * height / mp.Size.Y) end
	m:PivotTo(R * cf)
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
	return m
end
K.LIT = true
function K.lantern(par, cf, o) -- cf: wall surface, outward -Z
	o = o or {}
	local L = K.model("Lamp", par)
	local s = game:GetService("ServerStorage").MarkedNature.MarkedSconce:Clone()
	s:ScaleTo(1.2)
	local w = R * cf
	s:PivotTo(CFrame.lookAt(w.Position, w.Position - w.LookVector))
	s.Parent = L
	return L
end
function K.streetLamp(par, pos, yaw, o)
	o = o or {}
	local L = K.model("Lamp", par)
	local p = game:GetService("ServerStorage").MarkedNature.MarkedLampPost:Clone()
	if o.h then p:ScaleTo(o.h / 10) end
	p:PivotTo(R * C(pos) * A(0, yaw or 0, 0))
	p.Parent = L
	return L
end
function K.window(par, cf, w, h, o)
	o = o or {}
	local fc = o.frame or K.col.trim
	local fm = o.frameMat or M.Concrete
	if o.simple then
		K.D(par, V(w + 0.6, h + 0.6, 0.22), cf * C(0, 0, -0.11), fc, fm)
		local g = K.Ds(par, V(w, h, 0.08), cf * C(0, 0, -0.27), K.col.glass, M.Glass, {Reflectance = 0.28})
		if o.lit then g.Material = M.Neon; g.BrickColor = BrickColor.new(K.chance(0.6) and "Bright orange" or "Neon orange"); g.Transparency = 0.3; g.Reflectance = 0 end
		K.Ds(par, V(0.14, h, 0.08), cf * C(0, 0, -0.33), K.rgb(40, 30, 26), M.SmoothPlastic)
		K.Ds(par, V(w, 0.14, 0.08), cf * C(0, h * 0.15, -0.33), K.rgb(40, 30, 26), M.SmoothPlastic)
		K.D(par, V(w + 0.9, 0.3, 0.6), cf * C(0, -h / 2 - 0.4, -0.3), fc, fm)
		return g
	end
	-- architrave, dark reveal (fakes the wall depth), glass, georgian glazing bars
	K.D(par, V(w + 0.7, h + 0.7, 0.22), cf * C(0, 0, -0.11), fc, fm)
	local g
	if o.lit then
		g = K.Ds(par, V(w, h, 0.08), cf * C(0, 0, -0.3), nil, M.Neon)
		g.BrickColor = BrickColor.new(o.litColor or (K.chance(0.6) and "Bright orange" or "Neon orange"))
		g.Transparency = o.dim or 0.28
		if K.chance(0.6) then
			local side = K.chance(0.5) and -1 or 1
			K.Ds(par, V(w * 0.34, h, 0.04), cf * C(side * w * 0.33, 0, -0.35), K.pick({rgb(110, 24, 30), rgb(60, 40, 70), rgb(140, 110, 80), rgb(40, 50, 44)}), M.Fabric)
		end
	else
		g = K.Ds(par, V(w, h, 0.08), cf * C(0, 0, -0.3), K.col.glass, M.Glass, {Reflectance = 0.28})
	end
	if o.arch then
		K.deco(K.cyl(par, 0.22, w + 0.7, cf * C(0, h / 2, -0.11) * A(0, pi / 2, 0), fc, fm), true)
		local d2 = K.deco(K.cyl(par, 0.08, w, cf * C(0, h / 2, -0.3) * A(0, pi / 2, 0), g.Color, g.Material, {Reflectance = g.Reflectance, Transparency = g.Transparency}), true)
		if o.lit then d2.BrickColor = g.BrickColor end
	end
	local mc = o.mullion or rgb(222, 214, 200)
	if o.lit then mc = K.rgb(40, 28, 24) end
	K.Ds(par, V(0.14, h, 0.08), cf * C(0, 0, -0.36), mc, M.SmoothPlastic)
	K.Ds(par, V(w, 0.2, 0.1), cf * C(0, 0, -0.37), mc, M.SmoothPlastic)
	K.D(par, V(w + 1.0, 0.3, 0.7), cf * C(0, -h / 2 - 0.42, -0.35), o.sill or fc, fm)
	if not o.arch and o.lintel ~= false then
		K.D(par, V(w + 1.2, 0.5, 0.36), cf * C(0, h / 2 + 0.6, -0.18), o.sill or fc, fm)
		if o.key then K.Ds(par, V(0.7, 0.9, 0.5), cf * C(0, h / 2 + 0.6, -0.25), o.sill or fc, fm) end
	end
	if o.shutters then
		local sc = o.shutterColor or K.col.woodDark
		for s = -1, 1, 2 do
			K.Ds(par, V(w / 2 + 0.05, h + 0.3, 0.14), cf * C(s * (w * 0.75 + 0.5), 0, -0.1), sc, M.WoodPlanks)
		end
	end
	if o.box then K.flowerBox(par, cf * C(0, -h / 2 - 0.55, -0.3), w + 0.6) end
	return g
end
function K.door(par, cf, w, h, o)
	o = o or {}
	local fc = o.frame or K.col.trim
	local dc = o.color or K.pick({rgb(40, 24, 22), rgb(28, 40, 34), rgb(64, 20, 24), rgb(30, 30, 40), rgb(56, 40, 28)})
	K.D(par, V(w, h, 0.3), cf * C(0, h / 2, -0.12), dc, M.Wood)
	for s = -1, 1, 2 do
		K.Ds(par, V(w * 0.36, h * 0.34, 0.08), cf * C(s * w * 0.22, h * 0.26, -0.3), dc:Lerp(Color3.new(0, 0, 0), 0.2), M.Wood)
		K.Ds(par, V(w * 0.36, h * 0.3, 0.08), cf * C(s * w * 0.22, h * 0.66, -0.3), dc:Lerp(Color3.new(0, 0, 0), 0.2), M.Wood)
		K.D(par, V(0.6, h + 0.4, 0.5), cf * C(s * (w / 2 + 0.3), (h + 0.4) / 2, -0.25), fc, M.Limestone)
	end
	K.D(par, V(w + 0.9, 1.45, 0.32), cf * C(0, h + 0.62, -0.08), fc, M.Limestone, {Name = "Transom"})
	local fl = K.Ds(par, V(w - 0.3, 0.85, 0.08), cf * C(0, h + 0.6, -0.21), nil, M.Neon, {Name = "TransomGlass"})
	fl.BrickColor = BrickColor.new("Bright orange"); fl.Transparency = 0.35
	for i = -1, 1, 2 do K.Ds(par, V(0.12, 0.85, 0.12), cf * C(i * (w - 0.3) / 6, h + 0.6, -0.24), K.col.iron, M.Metal) end
	K.Ds(par, V(w + 1.6, 0.45, 0.6), cf * C(0, h + 1.55, -0.3), fc, M.Limestone)
	K.deco(K.ball(par, 0.22, (cf * C(w * 0.3, h * 0.48, -0.36)).Position, K.col.brass, M.Metal), true)
	local sy = o.stepY or 0
	local rise = (cf.Position.Y - sy)
	if rise > 0.2 then
		local n = max(1, math.ceil(rise / 0.6))
		for i = 1, n do
			local top = sy + rise * (n - i + 1) / n
			K.P(par, V(w + 1.6 + (i - 1) * 0.6, top - sy, 0.9 * i), cf * C(0, -rise + (top - sy) / 2, -0.45 * i), K.col.stoneLight, M.Limestone)
		end
	end
	if o.lantern then K.lantern(par, cf * C(w / 2 + 1.1, h * 0.72, 0)) end
end
function K.awning(par, cf, w, depth, colors)
	colors = colors or K.pick(K.awnings)
	local drop = depth * 0.42
	local n = max(3, floor(w / 2.2 + 0.5)); if n % 2 == 0 then n += 1 end
	local sw = w / n
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * sw
		local col = colors[(i % 2) + 1]
		K.deco(K.slab(par, (cf * C(x, 0, 0)).Position, (cf * C(x, -drop, -depth)).Position, sw + 0.02, 0.12, col, M.Fabric), true)
		K.Ds(par, V(sw + 0.02, 0.6, 0.08), cf * C(x, -drop - 0.26, -depth), col, M.Fabric)
	end
	K.slab(par, cf.Position, (cf * C(0, -drop, -depth)).Position, w, 0.3, colors[1], M.Fabric, {Transparency = 1, Name = "AwningCollider"})
	for s = -1, 1, 2 do K.deco(K.beam(par, (cf * C(s * (w / 2 - 0.2), -drop - 1.2, 0)).Position, (cf * C(s * (w / 2 - 0.2), -drop, -depth + 0.2)).Position, 0.12, K.col.iron, M.Metal), true) end
end
function K.balcony(par, cf, w, depth, o)
	o = o or {}
	K.P(par, V(w, 0.45, depth), cf * C(0, -0.22, -depth / 2), o.color or K.col.stoneLight, M.Limestone)
	K.D(par, V(w + 0.2, 0.2, depth + 0.1), cf * C(0, -0.5, -depth / 2), o.color or K.col.stoneLight, M.Limestone)
	for s = -1, 1, 2 do
		K.DW(par, V(0.45, 1.2, depth - 0.3), cf * C(s * (w / 2 - 0.5), -1.05, -(depth - 0.3) / 2) * A(0, 0, pi), o.color or K.col.stoneLight, M.Limestone)
	end
	local fl = (cf * C(-w / 2 + 0.15, 0, -depth + 0.15)).Position
	local fr = (cf * C(w / 2 - 0.15, 0, -depth + 0.15)).Position
	K.railing(par, fl, fr, 2.6, {spacing = 1.0, extra = 0.2})
	K.railing(par, (cf * C(-w / 2 + 0.15, 0, 0)).Position, fl, 2.6, {spacing = 1.0, extra = 0.2, collide = false})
	K.railing(par, (cf * C(w / 2 - 0.15, 0, 0)).Position, fr, 2.6, {spacing = 1.0, extra = 0.2, collide = false})
	if o.plants ~= false and K.chance(0.6) then
		for i = 1, K.int(1, 2) do
			local x = K.rand(-w / 2 + 0.8, w / 2 - 0.8)
			K.vcyl(par, 0.9, 0.9, (cf * C(x, 0.45, -depth + 0.7)).Position, rgb(140, 72, 50), M.Slate, {CanCollide = false, CanQuery = false})
			K.ball(par, 1.3, (cf * C(x, 1.3, -depth + 0.7)).Position, K.col.leaf, M.LeafyGrass, {CanCollide = false, CanQuery = false, CanTouch = false})
		end
	end
end
function K.chimney(par, cf, h, w)
	w = w or 2.4
	K.P(par, V(w, h, w * 0.85), cf * C(0, h / 2, 0), K.pick({rgb(104, 54, 46), rgb(90, 60, 52), rgb(116, 64, 50)}), M.Brick, {Name = "Chimney"})
	K.D(par, V(w + 0.5, 0.35, w * 0.85 + 0.5), cf * C(0, h - 0.9, 0), K.col.stone, M.Limestone)
	K.D(par, V(w + 0.6, 0.4, w * 0.85 + 0.6), cf * C(0, h + 0.2, 0), K.col.stone, M.Limestone)
	for s = -1, 1, 2 do K.deco(K.vcyl(par, 1.1, 0.62, (cf * C(s * w * 0.24, h + 0.95, 0)).Position, rgb(146, 78, 56), M.Slate)) end
end

local nature = game:GetService("ServerStorage"):FindFirstChild("MarkedNature")
function K.tree(par, kind, pos, scale, yaw, o)
	o = o or {}
	local src = nature:FindFirstChild(kind)
	if not src then warn("no tree " .. kind) return end
	local t = src:Clone()
	t.Name = o.name or "Tree"
	if scale and abs(scale - 1) > 0.01 then t:ScaleTo(scale) end
	t:PivotTo(R * C(pos) * A(0, yaw or K.rand(0, pi * 2), 0))
	if o.tint then
		for _, d in ipairs(t:GetDescendants()) do if d:IsA("MeshPart") and d.Name:lower():find("lea") then d.Color = o.tint end end
	end
	for _, d in ipairs(t:GetDescendants()) do
		if d:IsA("BasePart") and o.noCollide then d.CanCollide = false end
	end
	t.Parent = par
	return t
end
function K.bush(par, kind, pos, scale, yaw)
	return K.tree(par, kind, pos, scale, yaw, {name = "Bush", noCollide = true})
end
local BUSHES = {"Bush10", "Bush11", "Bush12", "Bush13", "Bush8"}
local FERNS = {"Fern1", "Fern2", "Fern3", "Fern4", "Fern6"}
function K.shrub(par, pos, s) return K.bush(par, K.pick(BUSHES), pos, s or K.rand(0.22, 0.34)) end
function K.fern(par, pos, s) return K.bush(par, K.pick(FERNS), pos, s or K.rand(0.35, 0.55)) end
function K.hedge(par, a, b, h, t, o)
	o = o or {}
	t = t or 2.2
	local cfm = CFrame.lookAt((a + b) / 2, b)
	local len = (b - a).Magnitude
	local col = o.color or K.col.leafDark
	K.P(par, V(t, h - t / 2, len), cfm * C(0, (h - t / 2) / 2, 0), col, M.LeafyGrass)
	K.cyl(par, len, t, cfm * C(0, h - t / 2, 0) * A(0, pi / 2, 0), col, M.LeafyGrass)
	local n = floor(len / 3)
	for i = 1, n do
		local z = -len / 2 + (i - 0.5) * len / n + K.rand(-0.8, 0.8)
		K.ball(par, K.rand(t * 0.75, t * 1.05), (cfm * C(K.rand(-0.3, 0.3), h - t * 0.45 + K.rand(-0.2, 0.3), z)).Position, col:Lerp(K.col.leaf, K.rand(0, 0.5)), M.LeafyGrass, {CanCollide = false, CanQuery = false, CanTouch = false})
	end
end
function K.flowerBed(par, cf, w, d, o)
	o = o or {}
	local m = K.model("FlowerBed", par)
	local eh = o.edge or 0.6
	K.P(m, V(w, eh - 0.1, d), cf * C(0, (eh - 0.1) / 2, 0), K.col.soil, M.Ground)
	for _, e in ipairs({{0, d / 2, w + 0.5, 0.5}, {0, -d / 2, w + 0.5, 0.5}}) do K.P(m, V(e[3], eh, e[4]), cf * C(e[1], eh / 2, e[2]), K.col.stoneLight, M.Limestone) end
	for _, e in ipairs({{w / 2, 0}, {-w / 2, 0}}) do K.P(m, V(0.5, eh, d), cf * C(e[1], eh / 2, e[2]), K.col.stoneLight, M.Limestone) end
	local n = floor(w * d / 2.4)
	local palette = o.colors or {K.pick(K.flowers), K.pick(K.flowers)}
	for i = 1, n do
		local x, z = K.rand(-w / 2 + 0.5, w / 2 - 0.5), K.rand(-d / 2 + 0.5, d / 2 - 0.5)
		K.ball(m, K.rand(0.8, 1.3), (cf * C(x, eh + 0.1, z)).Position, K.col.leaf:Lerp(K.col.leafDark, K.rand(0, 1)), M.LeafyGrass, {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
		if K.chance(0.8) then K.ball(m, K.rand(0.35, 0.55), (cf * C(x + K.rand(-0.3, 0.3), eh + 0.6, z + K.rand(-0.3, 0.3))).Position, palette[K.int(1, #palette)], M.SmoothPlastic, {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}) end
	end
	return m
end
function K.lawn(par, cf, w, d, o)
	o = o or {}
	local top = o.top or 0.2
	return K.P(par, V(w, 1 + top, d), cf * C(0, (top - 1) / 2, 0), o.color or K.col.grass, M.Grass, {Name = "Lawn"})
end
function K.petals(par, center, radius, n, y)
	for i = 1, n do
		local a, r = K.rand(0, pi * 2), radius * sqrt(K.rng:NextNumber())
		K.Ds(par, V(K.rand(0.3, 0.6), 0.05, K.rand(0.3, 0.6)), C(center + V(math.cos(a) * r, (y or 0) + 0.04, math.sin(a) * r)) * A(0, K.rand(0, pi), 0), K.col.petal:Lerp(rgb(200, 90, 110), K.rand(0, 0.5)), M.SmoothPlastic)
	end
end

function K.bench(par, cf)
	local m = meshClone("BenchMesh", cf, 2.6)
	local mp = m:FindFirstChildWhichIsA("MeshPart", true)
	m:ScaleTo(m:GetScale() * 5.2 / mp.Size.X)
	m:PivotTo(R * cf)
	m.Name = "Bench"; m.Parent = par
	return m
end
function K.barrel(par, pos, o)
	o = o or {}
	local m = K.model("Barrel", par)
	local h = o.h or 3
	K.vcyl(m, h, 2.2, pos + V(0, h / 2, 0), K.col.woodLight:Lerp(K.col.wood, K.rand(0, 1)), M.WoodPlanks)
	for _, y in ipairs({0.4, h - 0.4}) do K.deco(K.vcyl(m, 0.22, 2.3, pos + V(0, y, 0), K.col.iron, M.Metal)) end
	return m
end
function K.crate(par, cf, s)
	s = s or 2.6
	local m = K.model("Crate", par)
	K.P(m, V(s, s, s), cf * C(0, s / 2, 0), K.col.woodLight:Lerp(K.col.wood, K.rand(0, 0.6)), M.WoodPlanks)
	for _, z in ipairs({-1, 1}) do
		K.Ds(m, V(s + 0.06, 0.3, 0.12), cf * C(0, 0.2, z * s / 2), K.col.wood, M.Wood)
		K.Ds(m, V(s + 0.06, 0.3, 0.12), cf * C(0, s - 0.2, z * s / 2), K.col.wood, M.Wood)
		K.Ds(m, V(0.3, s * 1.3, 0.12), cf * C(0, s / 2, z * s / 2) * A(0, 0, pi / 4), K.col.wood, M.Wood)
	end
	return m
end
function K.crateStack(par, cf)
	local m = K.model("Crates", par)
	K.crate(m, cf * C(-1.4, 0, 0) * A(0, K.rand(-0.2, 0.2), 0), 2.6)
	K.crate(m, cf * C(1.4, 0, 0.2) * A(0, K.rand(-0.2, 0.2), 0), 2.6)
	if K.chance(0.7) then K.crate(m, cf * C(0, 2.6, 0) * A(0, K.rand(-0.4, 0.4), 0), 2.4) end
	return m
end
function K.cart(par, cf)
	local m = K.model("Cart", par)
	K.P(m, V(4, 0.4, 6.5), cf * C(0, 2.2, 0), K.col.woodLight, M.WoodPlanks)
	for s = -1, 1, 2 do
		K.P(m, V(0.3, 1.4, 6.5), cf * C(s * 1.9, 3.1, 0), K.col.wood, M.WoodPlanks)
		K.cyl(m, 0.35, 3.6, cf * C(s * 2.25, 1.8, 0.8), K.col.wood, M.Wood)
		K.deco(K.cyl(m, 0.4, 1, cf * C(s * 2.3, 1.8, 0.8), K.col.iron, M.Metal))
	end
	K.P(m, V(4.2, 1.4, 0.3), cf * C(0, 3.1, 3.2), K.col.wood, M.WoodPlanks)
	for s = -1, 1, 2 do K.D(m, V(0.25, 0.25, 4), cf * C(s * 0.8, 2.0, -5) * A(rad(-14), 0, 0), K.col.wood, M.Wood) end
	for i = 1, 4 do K.ball(m, K.rand(0.8, 1.1), (cf * C(K.rand(-1.2, 1.2), 3.0, K.rand(-2.4, 2.4))).Position, K.pick({rgb(150, 40, 40), rgb(170, 120, 50), rgb(90, 110, 50)}), M.SmoothPlastic, {CanCollide = false}) end
	K.barrel(m, (cf * C(0.6, 2.4, 1.6)).Position, {h = 2.2})
	return m
end
function K.stall(par, cf, w, o)
	o = o or {}
	local m = K.model("Stall", par)
	w = w or 8
	local d = 4.5
	local cols = o.colors or K.pick(K.awnings)
	for _, s in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do K.P(m, V(0.4, s[2] < 0 and 6.6 or 7.6, 0.4), cf * C(s[1] * (w / 2 - 0.2), (s[2] < 0 and 6.6 or 7.6) / 2, s[2] * (d / 2 - 0.2)), K.col.wood, M.Wood) end
	K.P(m, V(w, 2.6, 0.3), cf * C(0, 1.3, -d / 2 + 0.6), K.col.woodLight, M.WoodPlanks)
	K.P(m, V(w, 0.3, 2.2), cf * C(0, 2.75, -d / 2 + 1.4), K.col.woodLight, M.WoodPlanks)
	local n = max(4, floor(w / 1.2))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * w / n
		K.deco(K.slab(m, (cf * C(x, 7.7, d / 2 + 0.3)).Position, (cf * C(x, 6.5, -d / 2 - 1)).Position, w / n + 0.02, 0.12, cols[(i % 2) + 1], M.Fabric), true)
		K.Ds(m, V(w / n + 0.02, 0.6, 0.08), cf * C(x, 6.25, -d / 2 - 1), cols[(i % 2) + 1], M.Fabric)
	end
	K.slab(m, (cf * C(0, 7.7, d / 2 + 0.3)).Position, (cf * C(0, 6.5, -d / 2 - 1)).Position, w, 0.3, cols[1], M.Fabric, {Transparency = 1, Name = "AwningCollider"})
	local goods = o.goods or {rgb(150, 40, 40), rgb(190, 140, 60), rgb(90, 110, 50), rgb(120, 70, 110), rgb(200, 190, 170)}
	for i = 1, floor(w * 1.2) do
		K.ball(m, K.rand(0.45, 0.75), (cf * C(K.rand(-w / 2 + 0.6, w / 2 - 0.6), 3.2, -d / 2 + K.rand(0.6, 2.2))).Position, K.pick(goods), M.SmoothPlastic, {CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
	end
	K.crate(m, cf * C(w / 2 - 1.3, 0, d / 2 + 1.6) * A(0, K.rand(-0.3, 0.3), 0), 2)
	K.barrel(m, (cf * C(-w / 2 + 1.2, 0, d / 2 + 1.4)).Position, {h = 2.6})
	if o.sign then K.sign(m, cf * C(0, 5.6, -d / 2 - 0.9), w * 0.6, 0.9, o.sign) end
	return m
end
function K.gravestone(par, cf, kind)
	local m = K.model("Grave", par)
	local c = K.col.stone:Lerp(K.col.stoneDark, K.rand(0, 1))
	kind = kind or K.int(1, 4)
	if kind == 1 then
		K.P(m, V(2.2, 3.2, 0.5), cf * C(0, 1.6, 0), c, M.Limestone)
		K.deco(K.cyl(m, 0.5, 2.2, cf * C(0, 3.2, 0) * A(0, pi / 2, 0), c, M.Limestone))
	elseif kind == 2 then
		K.P(m, V(0.6, 4.4, 0.6), cf * C(0, 2.2, 0), c, M.Limestone)
		K.P(m, V(2.6, 0.6, 0.6), cf * C(0, 3.3, 0), c, M.Limestone)
	elseif kind == 3 then
		K.P(m, V(2.6, 2.4, 0.6), cf * C(0, 1.2, 0), c, M.Limestone)
		K.DW(m, V(2.6, 0.9, 0.3), cf * C(0, 2.85, -0.15), c, M.Limestone)
		K.DW(m, V(2.6, 0.9, 0.3), cf * C(0, 2.85, 0.15) * A(0, pi, 0), c, M.Limestone)
	else
		K.P(m, V(1.6, 4.5, 1.6), cf * C(0, 2.25, 0), c, M.Limestone)
		K.P(m, V(2.2, 0.5, 2.2), cf * C(0, 0.25, 0), c, M.Limestone)
		K.DW(m, V(1.6, 1.4, 0.8), cf * C(0, 5.2, -0.4), c, M.Limestone)
		K.DW(m, V(1.6, 1.4, 0.8), cf * C(0, 5.2, 0.4) * A(0, pi, 0), c, M.Limestone)
	end
	K.D(m, V(2.4, 0.3, 4.2), cf * C(0, 0.12, -2.4), K.col.soil:Lerp(K.col.moss, 0.4), M.Ground)
	m:PivotTo(m:GetPivot() * A(K.rand(-0.06, 0.06), 0, K.rand(-0.08, 0.08)))
	return m
end
function K.spawn(par, name, pos, yaw)
	local s = Instance.new("SpawnLocation")
	s.Name = name; s.Anchored = true; s.Size = V(6, 0.4, 6); s.CFrame = R * C(pos + V(0, 0.2, 0)) * A(0, yaw or 0, 0)
	s.Neutral = true; s.Duration = 0; s.Enabled = true
	s.Color = rgb(52, 46, 48); s.Material = M.Slate; s.TopSurface = Enum.SurfaceType.Smooth
	for _, d in ipairs(s:GetChildren()) do d:Destroy() end
	s.Parent = par
	game:GetService("CollectionService"):AddTag(s, "MatchSpawn")
	local f = R * C(pos + V(0, 0.42, 0)) * A(0, yaw or 0, 0)
	for _, c in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
		local p = Instance.new("Part"); p.Anchored = true; p.Size = V(0.9, 0.04, 0.9); p.Material = M.Neon; p.Color = rgb(150, 20, 30)
		p.CFrame = f * C(c[1] * 2.5, 0, c[2] * 2.5) * A(0, pi / 4, 0); K.deco(p, true); p.Parent = s
	end
	return s
end

function K.house(par, cf, o)
	local m = K.model(o.name or "House", par)
	local w, d = o.w, o.d
	local floors = o.floors or 3
	local fh = o.fh or 9
	local style = o.style or K.pick(K.walls)
	local trim = o.trim or (style.mat == M.Brick and K.col.trim or style.color:Lerp(Color3.new(1, 1, 1), 0.18))
	local base = o.base or 0
	local plinth = 1.2
	local H = plinth + floors * fh
	local faces = o.faces or {front = true, back = true, left = true, right = true}
	local roofCol = o.roofColor or K.pick({K.col.slate, K.col.slate2, rgb(40, 40, 46), K.col.roofRed})
	local roof = o.roof or "gable"
	local lit = o.lit or 0.28
	cf = cf * C(0, base, 0)
	m:SetAttribute("Top", base + H)
	K.P(m, V(w, H, d), cf * C(0, H / 2, 0), style.color, style.mat, {Name = "Wall"})
	K.D(m, V(w + 0.4, plinth + 0.3, d + 0.4), cf * C(0, (plinth + 0.3) / 2, 0), K.col.stoneDark, M.Limestone)
	for i = 1, floors - 1 do
		K.D(m, V(w + 0.45, 0.42, d + 0.45), cf * C(0, plinth + i * fh - 0.25, 0), trim, M.Concrete)
	end
	if style.mat ~= M.Brick and o.rustic ~= false then
		for y = plinth + 1.1, plinth + fh - 0.8, 2.2 do K.Ds(m, V(w + 0.06, 0.1, d + 0.06), cf * C(0, y, 0), style.color:Lerp(Color3.new(0, 0, 0), 0.35), M.SmoothPlastic) end
	end
	local faceList = {}
	if faces.front then table.insert(faceList, {cf * C(0, 0, -d / 2), w, "front"}) end
	if faces.back then table.insert(faceList, {cf * C(0, 0, d / 2) * A(0, pi, 0), w, "back"}) end
	if faces.left then table.insert(faceList, {cf * C(-w / 2, 0, 0) * A(0, pi / 2, 0), d, "left"}) end
	if faces.right then table.insert(faceList, {cf * C(w / 2, 0, 0) * A(0, -pi / 2, 0), d, "right"}) end
	if o.quoins then
		local corners = {}
		if faces.front then table.insert(corners, {-1, -1}); table.insert(corners, {1, -1}) end
		if faces.back then table.insert(corners, {-1, 1}); table.insert(corners, {1, 1}) end
		for _, c in ipairs(corners) do
			local i = 0
			for y = plinth + 0.7, H - 1, 2.6 do
				i += 1
				local q = (i % 2 == 0) and 2.0 or 1.3
				K.Ds(m, V(q, 2.4, q), cf * C(c[1] * (w / 2 + 0.16 - q / 2), y, c[2] * (d / 2 + 0.16 - q / 2)), trim, M.Limestone)
			end
		end
	end
	local shutterColor = o.shutterColor or K.pick({rgb(40, 52, 46), rgb(60, 28, 30), rgb(36, 36, 48), rgb(70, 60, 50)})
	for fi, F in ipairs(faceList) do
		local fcf, fw, kind = F[1], F[2], F[3]
		local isMain = kind == "front" or (o.mainFaces and o.mainFaces[kind])
		local bay = o.bay or 5
		local nb = max(1, floor((fw - 1) / bay))
		local span = fw / nb
		local doorBay = (kind == "front" and o.door ~= false and not o.shop) and (o.doorBay or math.ceil(nb / 2)) or nil
		if kind ~= "front" and o.sideDoor and kind == o.sideDoor then doorBay = math.ceil(nb / 2) end
		local ww = min(o.winW or 2.6, span - 1.6)
		local balconyFloors = {}
		if isMain and o.balcony then
			for f = 2, floors do balconyFloors[f] = K.chance(o.balcony) end
		end
		if o.pilasters and isMain then
			for b = 0, nb do
				local x = -fw / 2 + b * span
				x = math.clamp(x, -fw / 2 + 0.45, fw / 2 - 0.45)
				K.Ds(m, V(0.9, H - plinth - 0.4, 0.3), fcf * C(x, plinth + (H - plinth) / 2, -0.15), trim, M.Limestone)
				K.Ds(m, V(1.3, 0.5, 0.5), fcf * C(x, H - 0.6, -0.25), trim, M.Limestone)
			end
		end
		for f = 1, floors do
			local yb = plinth + (f - 1) * fh
			if f == 1 and kind == "front" and o.shop then
				K.shopfront(m, fcf, fw, yb, fh, o)
			else
				local balc = balconyFloors[f]
				local balcBays = {}
				if balc then
					if nb >= 3 and K.chance(0.5) then
						balcBays.all = true
						K.balcony(m, fcf * C(0, yb, 0), fw - 1.2, 1.8)
					else
						local bb = K.int(1, nb); balcBays[bb] = true
						K.balcony(m, fcf * C(-fw / 2 + (bb - 0.5) * span, yb, 0), min(span - 0.6, 6), 1.7)
					end
				end
				for b = 1, nb do
					local x = -fw / 2 + (b - 0.5) * span
					if f == 1 and b == doorBay then
						K.door(m, fcf * C(x, plinth, 0), min(3.2, span - 1.6), 6.4, {frame = trim, lantern = o.lanterns ~= false and K.chance(0.5), stepY = base})
					elseif balcBays.all or balcBays[b] then
						local wh = fh * 0.74
						K.window(m, fcf * C(x, yb + 0.15 + wh / 2, 0), ww, wh, {lit = K.chance(lit), frame = trim, lintel = true, key = o.keys, shutters = o.shutters, shutterColor = shutterColor})
					else
						local wh = (f == 1) and fh * 0.52 or fh * 0.56
						local wy = yb + fh * 0.5 + 0.2
						K.window(m, fcf * C(x, wy, 0), ww, wh, {simple = not isMain, lit = K.chance(lit), frame = trim, key = o.keys, arch = (o.arched == true and f == 1) or (o.arched == "top" and f == floors),
							shutters = o.shutters and isMain, shutterColor = shutterColor, box = isMain and f > 1 and K.chance(o.boxes or 0.25)})
					end
				end
			end
		end
		if isMain and o.ivy and K.chance(o.ivy) then
			K.ivy(m, fcf * C(K.rand(-fw / 2 + 2, fw / 2 - 2), 0, 0), K.rand(4, 8), K.rand(8, H * 0.85))
		end
		if isMain and K.chance(0.6) then
			local x = (K.chance(0.5) and -1 or 1) * (fw / 2 - 0.4)
			K.deco(K.vcyl(m, H, 0.32, (fcf * C(x, H / 2, -0.3)).Position, K.col.iron, M.Metal), true)
		end
		if kind == "front" and o.signText and not o.shop then
			K.sign(m, fcf * C(0, plinth + fh - 1.1, -0.1), min(fw - 3, 9), 1.2, o.signText)
		end
	end
	local top = H
	if roof == "gable" then
		local ov = 0.9
		local rh = o.rh or min(d * 0.42, 9)
		local slope = rh / (d / 2)
		for s = -1, 1, 2 do
			local a = (cf * C(0, H - ov * slope, s * (d / 2 + ov))).Position
			local b = (cf * C(0, H + rh, 0)).Position
			K.slab(m, a, b, w + 1.4, 0.55, roofCol, M.Slate, {MaterialVariant = "MarkedSlateRoof", Name = "Roof"})
			K.deco(K.cyl(m, w + 1.2, 0.36, cf * C(0, H - ov * slope - 0.35, s * (d / 2 + ov - 0.1)), K.col.iron, M.Metal), true)
		end
		for _, sx in ipairs({-1, 1}) do
			K.W(m, V(0.5, rh, d / 2), cf * C(sx * (w / 2 - 0.25), H + rh / 2 - 0.5, -d / 4), style.color, style.mat)
			K.W(m, V(0.5, rh, d / 2), cf * C(sx * (w / 2 - 0.25), H + rh / 2 - 0.5, d / 4) * A(0, pi, 0), style.color, style.mat)
			for s = -1, 1, 2 do
				K.deco(K.slab(m, (cf * C(sx * (w / 2 + 0.55), H - ov * slope - 0.15, s * (d / 2 + ov))).Position, (cf * C(sx * (w / 2 + 0.55), H + rh - 0.15, 0)).Position, 0.3, 0.7, K.col.woodDark, M.Wood), true)
			end
		end
		K.D(m, V(w + 1.6, 0.45, 0.8), cf * C(0, H + rh + 0.05, 0), roofCol:Lerp(Color3.new(0, 0, 0), 0.25), M.Slate, {Name = "Ridge"})
		for _, sx in ipairs(o.chimneys or {-1, 1}) do
			K.chimney(m, cf * C(sx * (w / 2 - 1.8), H + rh - 1.6, K.rand(-0.6, 0.6)), K.rand(4.2, 6))
		end
		if K.chance(0.5) then
			local zf = (d / 4) * (K.chance(0.5) and -1 or 1)
			K.Ds(m, V(2, 0.2, 2.6), cf * C(K.rand(-w / 4, w / 4), H + rh / 2 + 0.15, zf) * A((zf < 0 and 1 or -1) * math.atan(slope), 0, 0), K.col.glass, M.Glass, {Reflectance = 0.3})
		end
		top = H + rh
	elseif roof == "mansard" then
		local mh, ins = o.mh or 6.4, 2.6
		K.D(m, V(w + 1.2, 0.8, d + 1.2), cf * C(0, H + 0.1, 0), trim, M.Concrete)
		for _, F in ipairs(faceList) do
			for x = -F[2] / 2 + 0.8, F[2] / 2 - 0.8, 3.2 do K.Ds(m, V(0.4, 0.5, 0.55), F[1] * C(x, H - 0.55, -0.25), trim, M.Concrete) end
		end
		for s = -1, 1, 2 do
			K.slab(m, (cf * C(0, H + 0.5, s * (d / 2 + 0.2))).Position, (cf * C(0, H + mh, s * (d / 2 - ins))).Position, w + 0.3, 0.6, roofCol, M.Slate, {MaterialVariant = "MarkedSlateRoof", Name = "Roof"})
		end
		for _, sx in ipairs({-1, 1}) do
			K.P(m, V(0.6, mh, d - 2 * ins + 0.1), cf * C(sx * (w / 2 - 0.3), H + mh / 2, 0), roofCol, M.Slate, {MaterialVariant = "MarkedSlateRoof"})
			K.W(m, V(0.6, mh, ins), cf * C(sx * (w / 2 - 0.3), H + mh / 2, -d / 2 + ins / 2), roofCol, M.Slate, {MaterialVariant = "MarkedSlateRoof"})
			K.W(m, V(0.6, mh, ins), cf * C(sx * (w / 2 - 0.3), H + mh / 2, d / 2 - ins / 2) * A(0, pi, 0), roofCol, M.Slate, {MaterialVariant = "MarkedSlateRoof"})
		end
		K.P(m, V(w, 0.5, d - 2 * ins + 0.3), cf * C(0, H + mh + 0.25, 0), roofCol:Lerp(Color3.new(0, 0, 0), 0.2), M.Slate, {Name = "RoofDeck"})
		for s = -1, 1, 2 do K.D(m, V(w + 0.2, 0.4, 0.6), cf * C(0, H + mh + 0.55, s * (d / 2 - ins)), K.col.iron, M.Metal, {Name = "Ridge"}) end
		for _, F in ipairs(faceList) do
			if F[3] == "front" or F[3] == "back" then
				local fcf, fw = F[1], F[2]
				local nb = max(1, floor((fw - 1) / (o.bay or 5)))
				local span = fw / nb
				for b = 1, nb do
					if K.chance(o.dormers or 0.8) then
						local x = -fw / 2 + (b - 0.5) * span
						K.P(m, V(3, 4.4, 2.6), fcf * C(x, H + 2.6, 1.5), style.color, style.mat)
						K.window(m, fcf * C(x, H + 2.9, 0.2), 1.8, 2.4, {lit = K.chance(lit), frame = trim, lintel = false})
						K.deco(K.cyl(m, 2.8, 3.4, fcf * C(x, H + 4.8, 1.5) * A(0, pi / 2, 0), roofCol, M.Slate))
					end
				end
			end
		end
		for _, sx in ipairs(o.chimneys or {-1, 1}) do K.chimney(m, cf * C(sx * (w / 2 - 1.6), H + mh, 0), K.rand(3.6, 5)) end
		top = H + mh + 0.5
	elseif roof == "flat" then
		K.D(m, V(w + 1.2, 0.8, d + 1.2), cf * C(0, H - 0.5, 0), trim, M.Concrete)
		for _, F in ipairs(faceList) do
			for x = -F[2] / 2 + 0.8, F[2] / 2 - 0.8, 3.2 do K.Ds(m, V(0.4, 0.5, 0.55), F[1] * C(x, H - 1.15, -0.25), trim, M.Concrete) end
		end
		K.D(m, V(w + 0.7, 0.4, d + 0.7), cf * C(0, H - 1.1, 0), trim, M.Limestone)
		local ph = o.parapet or 2.4
		local t = 0.6
		K.P(m, V(w, ph, t), cf * C(0, H + ph / 2, -d / 2 + t / 2), style.color, style.mat)
		K.P(m, V(w, ph, t), cf * C(0, H + ph / 2, d / 2 - t / 2), style.color, style.mat)
		K.P(m, V(t, ph, d - 2 * t), cf * C(-w / 2 + t / 2, H + ph / 2, 0), style.color, style.mat)
		K.P(m, V(t, ph, d - 2 * t), cf * C(w / 2 - t / 2, H + ph / 2, 0), style.color, style.mat)
		K.D(m, V(w + 0.3, 0.3, 1.0), cf * C(0, H + ph + 0.15, -d / 2 + 0.3), trim, M.Limestone, {Name = "Ridge"})
		K.D(m, V(w + 0.3, 0.3, 1.0), cf * C(0, H + ph + 0.15, d / 2 - 0.3), trim, M.Limestone)
		K.D(m, V(1.0, 0.3, d), cf * C(-w / 2 + 0.3, H + ph + 0.15, 0), trim, M.Limestone)
		K.D(m, V(1.0, 0.3, d), cf * C(w / 2 - 0.3, H + ph + 0.15, 0), trim, M.Limestone)
		K.D(m, V(w - 1.2, 0.1, d - 1.2), cf * C(0, H + 0.05, 0), rgb(54, 50, 52), M.Asphalt)
		K.roofProps(m, cf * C(0, H, 0), w, d, o)
		top = H + ph
	end
	m:SetAttribute("RoofTop", base + top)
	return m
end
function K.shopfront(m, fcf, fw, yb, fh, o)
	local sw = fw - 1.4
	local wood = o.shopColor or K.pick(K.shopColors)
	local fasciaY = yb + fh - 1.5
	K.D(m, V(sw + 0.6, fh - 0.3, 0.3), fcf * C(0, yb + (fh - 0.3) / 2, -0.15), wood, M.Wood)
	for s = -1, 1, 2 do K.D(m, V(0.8, fh - 0.2, 0.6), fcf * C(s * (sw / 2), yb + (fh - 0.2) / 2, -0.3), wood:Lerp(Color3.new(0, 0, 0), 0.25), M.Wood) end
	local doorW = 3
	local panelW = (sw - doorW - 1.4) / 2
	local gh = fh - 4.6
	for s = -1, 1, 2 do
		local x = s * (doorW / 2 + 0.5 + panelW / 2)
		K.D(m, V(panelW, 1.6, 0.4), fcf * C(x, yb + 0.8, -0.4), wood, M.Wood)
		local g = K.D(m, V(panelW, gh, 0.12), fcf * C(x, yb + 1.6 + gh / 2, -0.38), nil, M.Neon)
		g.BrickColor = BrickColor.new("Bright orange"); g.Transparency = 0.42
		local n = max(1, floor(panelW / 1.6))
		for i = 1, n - 1 do K.Ds(m, V(0.14, gh, 0.14), fcf * C(x - panelW / 2 + i * panelW / n, yb + 1.6 + gh / 2, -0.48), wood, M.Wood) end
		K.Ds(m, V(panelW, 0.14, 0.14), fcf * C(x, yb + 1.6 + gh * 0.78, -0.48), wood, M.Wood)
		for i = 1, 3 do K.Ds(m, V(K.rand(0.4, 0.9), K.rand(0.6, 1.4), 0.3), fcf * C(x + K.rand(-panelW / 2 + 0.5, panelW / 2 - 0.5), yb + 2.2, -0.2), rgb(30, 20, 18), M.SmoothPlastic) end
	end
	K.D(m, V(doorW, 6.2, 0.2), fcf * C(0, yb + 3.1, -0.2), wood:Lerp(Color3.new(0, 0, 0), 0.35), M.Wood)
	local dg = K.D(m, V(doorW - 0.8, 2.6, 0.1), fcf * C(0, yb + 4.4, -0.33), nil, M.Neon)
	dg.BrickColor = BrickColor.new("Bright orange"); dg.Transparency = 0.45
	K.D(m, V(doorW + 1.2, yb + 0.35, 1.2), fcf * C(0, (yb + 0.35) / 2, -0.6), K.col.stoneLight, M.Limestone)
	K.sign(m, fcf * C(0, fasciaY, -0.32), sw - 1.2, 1.35, o.signText or K.SHOPS[K.int(1, #K.SHOPS)], {color = wood})
	K.D(m, V(sw + 0.9, 0.4, 0.9), fcf * C(0, yb + fh - 0.5, -0.45), wood:Lerp(Color3.new(0, 0, 0), 0.3), M.Wood)
	if o.awning ~= false then K.awning(m, fcf * C(0, fasciaY - 1.0, -0.5), sw - 0.4, 3.4) end
	if o.lanterns ~= false then K.lantern(m, fcf * C(sw / 2 + 0.2, fasciaY - 0.2, -0.3)) end
end
function K.roofProps(m, cf, w, d, o)
	local n = K.int(1, 3)
	for i = 1, n do
		local x, z = K.rand(-w / 2 + 2.5, w / 2 - 2.5), K.rand(-d / 2 + 2.5, d / 2 - 2.5)
		local r = K.int(1, 6)
		if r == 1 then K.chimney(m, cf * C(x, 0, z), K.rand(3.5, 5))
		elseif r == 2 then
			K.P(m, V(2.4, 1.2, 2.4), cf * C(x, 0.6, z), K.col.woodDark, M.WoodPlanks)
			K.D(m, V(2.6, 0.2, 2.6), cf * C(x, 1.3, z) * A(rad(-20), 0, 0), K.col.iron, M.Metal)
		elseif r == 3 then
			for _, s in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do K.P(m, V(0.3, 3, 0.3), cf * C(x + s[1] * 1.3, 1.5, z + s[2] * 1.3), K.col.iron, M.Metal) end
			K.vcyl(m, 3.4, 4, (cf * C(x, 4.7, z)).Position, K.col.woodLight, M.WoodPlanks)
			K.deco(K.vcyl(m, 0.2, 4.1, (cf * C(x, 3.9, z)).Position, K.col.iron, M.Metal))
			K.deco(K.vcyl(m, 0.2, 4.1, (cf * C(x, 5.6, z)).Position, K.col.iron, M.Metal))
		elseif r == 4 then
			K.crateStack(m, cf * C(x, 0, z) * A(0, K.rand(0, pi), 0))
		elseif r == 5 then
			for j = 1, 2 do
				local px, pz = x + K.rand(-1.5, 1.5), z + K.rand(-1.5, 1.5)
				K.vcyl(m, 1.4, 1.6, (cf * C(px, 0.7, pz)).Position, rgb(140, 72, 50), M.Slate)
				K.ball(m, K.rand(1.8, 2.4), (cf * C(px, 2.0, pz)).Position, K.col.leaf:Lerp(K.col.leafDark, K.rand(0, 1)), M.LeafyGrass, {CanCollide = false, CanQuery = false, CanTouch = false})
			end
		else
			K.P(m, V(3, 0.8, 4), cf * C(x, 0.4, z), K.col.iron, M.Metal)
			K.D(m, V(2.6, 0.2, 3.6), cf * C(x, 0.85, z), K.col.glass, M.Glass, {Reflectance = 0.3})
		end
	end
end

function K.cleanupHidden(container)
	local walls = {}
	for _, d in ipairs(container:GetDescendants()) do if d:IsA("BasePart") and d.Name == "Wall" then table.insert(walls, d) end end
	local params = OverlapParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = walls
	local removed = 0
	for _, house in ipairs(container:GetDescendants()) do
		if house:IsA("Model") and (house.Name == "House" or house.Name == "CircusHouse" or house.Name == "GateHouse") then
			local own = house:FindFirstChild("Wall")
			for _, p in ipairs(house:GetDescendants()) do
				if p:IsA("BasePart") and p ~= own and p.Name ~= "Wall" and p.Parent then
					local hits = workspace:GetPartBoundsInBox(p.CFrame, p.Size * 0.35, params)
					for _, h in ipairs(hits) do if h ~= own then p:Destroy(); removed += 1; break end end
				end
			end
		end
	end
	return removed
end

return K
