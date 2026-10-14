local T = {}
local V, C, A = Vector3.new, CFrame.new, CFrame.Angles
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local IRON = rgb(24, 22, 22)
local PALETTES = {
	{main = rgb(212, 170, 92), mat = M.Metal, accent = rgb(120, 28, 30)},
	{main = rgb(30, 28, 30), mat = M.Metal, accent = rgb(200, 160, 90)},
	{main = rgb(122, 34, 34), mat = M.SmoothPlastic, accent = rgb(220, 180, 100)},
	{main = rgb(36, 70, 52), mat = M.SmoothPlastic, accent = rgb(220, 180, 100)},
	{main = rgb(38, 52, 92), mat = M.SmoothPlastic, accent = rgb(230, 200, 130)},
	{main = rgb(150, 112, 56), mat = M.Metal, accent = rgb(40, 34, 30)},
}
T.PALETTES = PALETTES
local function P(par, size, cf, col, mat, shape, o)
	local p = Instance.new("Part")
	p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = col; p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	if shape then p.Shape = shape end
	if o then for k, v in pairs(o) do p[k] = v end end
	p.Parent = par
	return p
end
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local function disc(par, d, t, cf, col, mat, o) return P(par, V(t, d, d), cf, col, mat, CYL, o) end
local function vcyl(par, h, d, cf, col, mat, o) return P(par, V(h, d, d), cf * A(0, 0, math.pi / 2), col, mat, CYL, o) end
local function rod(par, E, a, b, w, col, mat)
	local pa, pb = (E * C(a)).Position, (E * C(b)).Position
	return P(par, V(w, w, (pb - pa).Magnitude), CFrame.lookAt((pa + pb) / 2, pb), col, mat)
end
local EM = {}
EM.balls = function(par, E, pal)
	local gold = rgb(214, 172, 80)
	rod(par, E, V(0, 0.75, -0.75), V(0, 0.75, 0.75), 0.12, pal.main, M.Metal)
	for _, p in ipairs({V(0, 0.05, -0.55), V(0, 0.05, 0.55), V(0, -0.75, 0)}) do
		rod(par, E, V(0, 0.75, p.Z * 0.7), p + V(0, 0.32, 0), 0.06, pal.main, M.Metal)
		P(par, V(0.72, 0.72, 0.72), E * C(p), gold, M.Metal, BALL, {Reflectance = 0.15})
	end
end
EM.mortar = function(par, E, pal)
	vcyl(par, 0.75, 1.15, E * C(0, -0.45, 0), pal.main, pal.mat)
	vcyl(par, 0.14, 1.3, E * C(0, -0.08, 0), pal.accent, M.Metal)
	vcyl(par, 0.18, 0.75, E * C(0, -0.9, 0), pal.accent, M.Metal)
	P(par, V(0.22, 1.5, 0.22), E * C(0, 0.3, 0.25) * A(math.rad(-28), 0, 0), rgb(200, 190, 170), M.Marble)
	P(par, V(0.34, 0.34, 0.34), E * C(0, 0.95, 0.6), rgb(200, 190, 170), M.Marble, BALL)
end
EM.carboy = function(par, E, pal)
	P(par, V(1.15, 1.15, 1.15), E * C(0, -0.25, 0), pal.accent:Lerp(rgb(40, 140, 90), 0.6), M.Glass, BALL, {Transparency = 0.25})
	vcyl(par, 0.6, 0.35, E * C(0, 0.55, 0), pal.accent:Lerp(rgb(40, 140, 90), 0.6), M.Glass, {Transparency = 0.25})
	vcyl(par, 0.18, 0.5, E * C(0, 0.9, 0), pal.main, M.Metal)
	P(par, V(0.5, 0.5, 0.5), E * C(0, -0.25, 0), rgb(255, 120, 60), M.Neon, BALL, {Transparency = 0.35})
end
EM.openbook = function(par, E, pal)
	for _, s in ipairs({-1, 1}) do
		P(par, V(0.12, 1.15, 0.85), E * C(0, 0, s * 0.43) * A(math.rad(s * 8), 0, 0), pal.main, pal.mat)
		P(par, V(0.16, 1.02, 0.74), E * C(0, 0.02, s * 0.41) * A(math.rad(s * 8), 0, 0), rgb(232, 222, 196), M.SmoothPlastic)
		for k = -2, 2 do P(par, V(0.18, 0.03, 0.55), E * C(0, k * 0.17, s * 0.42) * A(math.rad(s * 8), 0, 0), rgb(120, 110, 96), M.SmoothPlastic) end
	end
	P(par, V(0.2, 0.55, 0.08), E * C(0, -0.75, 0.05), pal.accent, M.Fabric)
end
EM.stack = function(par, E, pal)
	local cols = {pal.main, pal.accent, rgb(70, 40, 30)}
	for i = 1, 3 do
		local y = -0.7 + (i - 1) * 0.42
		P(par, V(0.7, 0.36, 1.25 - i * 0.12), E * C(0, y, (i - 2) * 0.08), cols[i], M.SmoothPlastic)
		P(par, V(0.6, 0.3, 0.05), E * C(0, y, (i - 2) * 0.08 + (1.25 - i * 0.12) / 2 - 0.03), rgb(230, 220, 196), M.SmoothPlastic)
	end
end
EM.quill = function(par, E, pal)
	vcyl(par, 0.6, 0.7, E * C(0, -0.6, -0.15), rgb(20, 22, 30), M.Glass)
	vcyl(par, 0.12, 0.4, E * C(0, -0.25, -0.15), pal.main, M.Metal)
	P(par, V(0.06, 1.7, 0.36), E * C(0, 0.35, 0.18) * A(math.rad(-22), 0, 0), rgb(238, 232, 220), M.SmoothPlastic)
	P(par, V(0.07, 1.3, 0.06), E * C(0, 0.3, 0.16) * A(math.rad(-22), 0, 0), rgb(150, 140, 120), M.SmoothPlastic)
end
EM.cleaver = function(par, E, pal)
	P(par, V(0.08, 0.85, 1.3), E * C(0, 0.1, -0.15), rgb(170, 172, 176), M.Metal, nil, {Reflectance = 0.2})
	P(par, V(0.22, 0.22, 0.8), E * C(0, 0.3, 0.85), pal.main, M.Wood)
	P(par, V(0.25, 0.25, 0.25), E * C(0, -0.05, -0.55), IRON, M.Metal, BALL)
end
EM.candle = function(par, E, pal)
	vcyl(par, 1.15, 0.42, E * C(0, 0.05, 0), rgb(238, 228, 204), M.SmoothPlastic)
	vcyl(par, 0.12, 1.0, E * C(0, -0.55, 0), pal.main, pal.mat)
	P(par, V(0.12, 0.35, 0.12), E * C(0, -0.3, 0.55) * A(math.rad(60), 0, 0), pal.main, pal.mat)
	P(par, V(0.24, 0.36, 0.24), E * C(0, 0.8, 0), rgb(255, 170, 60), M.Neon, BALL)
end
EM.globe = function(par, E, pal)
	P(par, V(1.15, 1.15, 1.15), E * C(0, 0.12, 0), rgb(60, 98, 110), M.SmoothPlastic, BALL)
	disc(par, 1.32, 0.07, E * C(0, 0.12, 0), pal.main, M.Metal)
	P(par, V(1.32, 0.07, 1.32), E * C(0, 0.12, 0), pal.main, M.Metal, CYL)
	vcyl(par, 0.5, 0.15, E * C(0, -0.65, 0), pal.main, M.Metal)
	vcyl(par, 0.12, 0.7, E * C(0, -0.92, 0), pal.main, M.Metal)
end
EM.clock = function(par, E, pal)
	disc(par, 1.6, 0.18, E, pal.main, pal.mat)
	disc(par, 1.3, 0.24, E, rgb(236, 228, 210), M.SmoothPlastic)
	for k = 0, 11 do
		local a = k * math.pi / 6
		P(par, V(0.26, 0.04, 0.12), E * C(0, math.cos(a) * 0.52, math.sin(a) * 0.52) * A(-a, 0, 0), IRON, M.SmoothPlastic)
	end
	P(par, V(0.28, 0.42, 0.06), E * C(0, 0.17, 0.05) * A(math.rad(-20), 0, 0), IRON, M.Metal)
	P(par, V(0.28, 0.58, 0.05), E * C(0, 0.02, 0.24) * A(math.rad(-110), 0, 0), IRON, M.Metal)
	P(par, V(0.3, 0.1, 0.1), E, pal.accent, M.Metal, BALL)
end
EM.hourglass = function(par, E, pal)
	for _, s in ipairs({-1, 1}) do
		disc(par, 0.95, 0.12, E * C(0, s * 0.72, 0) * A(0, 0, math.pi / 2), pal.main, pal.mat)
		P(par, V(0.68, 0.68, 0.68), E * C(0, s * 0.33, 0), rgb(220, 220, 230), M.Glass, BALL, {Transparency = 0.4})
		P(par, V(0.1, 1.45, 0.1), E * C(0, 0, s * 0.4), pal.main, pal.mat)
	end
	P(par, V(0.4, 0.4, 0.4), E * C(0, -0.42, 0), rgb(214, 180, 110), M.Sand, BALL)
end
EM.urn = function(par, E, pal)
	P(par, V(1.0, 1.1, 1.0), E * C(0, -0.1, 0), pal.main, pal.mat, BALL)
	vcyl(par, 0.35, 0.5, E * C(0, 0.55, 0), pal.main, pal.mat)
	vcyl(par, 0.12, 0.75, E * C(0, 0.75, 0), pal.accent, M.Metal)
	vcyl(par, 0.3, 0.55, E * C(0, -0.75, 0), pal.accent, M.Metal)
	for _, s in ipairs({-1, 1}) do P(par, V(0.1, 0.5, 0.1), E * C(0, 0.25, s * 0.6) * A(math.rad(s * 25), 0, 0), pal.accent, M.Metal) end
end
EM.flowers = function(par, E, pal)
	vcyl(par, 0.6, 0.75, E * C(0, -0.65, 0), rgb(160, 80, 50), M.Slate)
	local cols = {rgb(170, 30, 40), rgb(230, 200, 70), rgb(220, 120, 160), rgb(240, 236, 220)}
	for k = 1, 6 do
		local a = (k / 6) * math.pi - math.pi / 2
		local p = V(0, 0.1 + math.cos(a) * 0.45, math.sin(a) * 0.5)
		rod(par, E, V(0, -0.4, 0), p, 0.05, rgb(50, 90, 40), M.Grass)
		P(par, V(0.34, 0.34, 0.34), E * C(p), cols[(k % 4) + 1], M.SmoothPlastic, BALL)
	end
	P(par, V(0.08, 0.35, 0.5), E * C(0, -0.25, 0.32) * A(math.rad(30), 0, 0), rgb(60, 100, 50), M.Grass)
end
EM.target = function(par, E, pal)
	local cols = {pal.main, rgb(232, 224, 206), pal.main, rgb(232, 224, 206), pal.accent}
	for i = 1, 5 do disc(par, 1.5 - (i - 1) * 0.3, 0.12 + i * 0.03, E, cols[i], M.SmoothPlastic) end
end
EM.scissors = function(par, E, pal)
	for _, s in ipairs({-1, 1}) do
		P(par, V(0.07, 0.14, 1.35), E * C(0, 0.15, 0.25) * A(math.rad(s * 18), 0, 0), rgb(180, 182, 186), M.Metal, nil, {Reflectance = 0.2})
		disc(par, 0.48, 0.1, E * C(0, s * 0.3 - 0.05, -0.62), pal.main, pal.mat)
		disc(par, 0.24, 0.12, E * C(0, s * 0.3 - 0.05, -0.62), IRON, M.SmoothPlastic)
	end
	P(par, V(0.14, 0.14, 0.14), E * C(0, 0.12, -0.15), IRON, M.Metal, BALL)
end
EM.spool = function(par, E, pal)
	vcyl(par, 0.9, 0.7, E, pal.accent:Lerp(rgb(150, 30, 50), 0.5), M.Fabric)
	for _, s in ipairs({-1, 1}) do vcyl(par, 0.14, 1.05, E * C(0, s * 0.52, 0), pal.main, M.Wood) end
	P(par, V(0.05, 1.5, 0.05), E * C(0, 0, 0.62) * A(math.rad(15), 0, 0), rgb(190, 190, 196), M.Metal)
end
EM.tophat = function(par, E, pal)
	vcyl(par, 1.0, 0.9, E * C(0, 0.15, 0), rgb(22, 20, 22), M.Fabric)
	vcyl(par, 0.08, 1.55, E * C(0, -0.38, 0), rgb(22, 20, 22), M.Fabric)
	vcyl(par, 0.18, 0.93, E * C(0, -0.22, 0), pal.accent, M.Fabric)
end
EM.key = function(par, E, pal)
	disc(par, 0.8, 0.14, E * C(0, 0, -0.65), pal.main, M.Metal)
	disc(par, 0.38, 0.16, E * C(0, 0, -0.65), rgb(30, 26, 26), M.SmoothPlastic)
	P(par, V(0.16, 0.16, 1.5), E * C(0, 0, 0.35), pal.main, M.Metal)
	P(par, V(0.14, 0.42, 0.14), E * C(0, -0.25, 0.95), pal.main, M.Metal)
	P(par, V(0.14, 0.3, 0.14), E * C(0, -0.19, 0.72), pal.main, M.Metal)
end
EM.teapot = function(par, E, pal)
	P(par, V(1.15, 0.95, 1.15), E * C(0, -0.1, 0), pal.main, pal.mat, BALL)
	P(par, V(0.14, 0.14, 0.75), E * C(0, 0.0, 0.68) * A(math.rad(35), 0, 0), pal.main, pal.mat)
	for k = 0, 4 do local a = -math.pi / 2 + k * math.pi / 4
		P(par, V(0.12, 0.12, 0.2), E * C(0, -0.1 + math.sin(a) * 0.32, -0.58 - math.cos(a) * 0.22), pal.main, pal.mat) end
	vcyl(par, 0.12, 0.6, E * C(0, 0.38, 0), pal.accent, M.Metal)
	P(par, V(0.2, 0.2, 0.2), E * C(0, 0.5, 0), pal.accent, M.Metal, BALL)
end
EM.pipe = function(par, E, pal)
	vcyl(par, 0.65, 0.48, E * C(0, 0.05, -0.45), rgb(92, 52, 30), M.Wood)
	vcyl(par, 0.1, 0.4, E * C(0, 0.36, -0.45), rgb(30, 20, 16), M.SmoothPlastic)
	P(par, V(0.12, 0.12, 1.25), E * C(0, -0.15, 0.25) * A(math.rad(-10), 0, 0), rgb(36, 26, 22), M.SmoothPlastic)
	P(par, V(0.08, 0.5, 0.5), E * C(0, 0.75, -0.3), rgb(200, 196, 190), M.SmoothPlastic, CYL, {Transparency = 0.5})
end
EM.grapes = function(par, E, pal)
	local purple = rgb(70, 30, 70)
	local rows = {3, 3, 2, 2, 1}
	for i, n in ipairs(rows) do for k = 1, n do
		P(par, V(0.34, 0.34, 0.34), E * C(0, 0.35 - i * 0.24, (k - (n + 1) / 2) * 0.3), purple, M.SmoothPlastic, BALL)
	end end
	P(par, V(0.08, 0.55, 0.7), E * C(0, 0.55, 0.28) * A(math.rad(-25), 0, 0), rgb(60, 100, 50), M.Grass)
	P(par, V(0.08, 0.4, 0.08), E * C(0, 0.55, 0), rgb(70, 50, 30), M.Wood)
end
EM.wheat = function(par, E, pal)
	local gold = rgb(200, 160, 70)
	for k = -3, 3 do
		local a = k * 0.12
		P(par, V(0.05, 1.6, 0.05), E * A(a, 0, 0), gold, M.SmoothPlastic)
		P(par, V(0.14, 0.38, 0.14), E * A(a, 0, 0) * C(0, 0.85, 0), gold, M.SmoothPlastic, BALL)
	end
	P(par, V(0.22, 0.14, 0.42), E * C(0, -0.05, 0), pal.accent, M.Fabric)
end
local TRADES = {
	APOTHECARY = {"mortar", "carboy"}, CHEMIST = {"carboy", "mortar"}, ANTIQUES = {"urn", "hourglass"}, BAKER = {"wheat"},
	BOOKBINDER = {"stack", "openbook"}, BOOKSELLER = {"openbook", "stack"}, BUTCHER = {"cleaver"}, CANDLEMAKER = {"candle"},
	CARTOGRAPHER = {"globe"}, CHANDLER = {"candle"}, CLOCKMAKER = {"clock"}, CURIOSITIES = {"hourglass", "urn", "key"},
	FLORIST = {"flowers"}, GUNSMITH = {"target"}, HABERDASHER = {"spool", "scissors"}, HATTER = {"tophat"},
	["INK & QUILL"] = {"quill"}, LOCKSMITH = {"key"}, PAWNBROKER = {"balls"}, PRINTER = {"quill", "stack"},
	["PRINTING HOUSE"] = {"openbook", "quill", "stack"}, STATIONER = {"quill", "openbook"}, TAILOR = {"scissors", "spool"},
	["TEA ROOM"] = {"teapot"}, TOBACCONIST = {"pipe"}, ["WINE MERCHANT"] = {"grapes"},
}
T.TRADES = TRADES
local function hoop(par, E, r, col)
	local n = 14
	for k = 0, n - 1 do
		local a1, a2 = k * 2 * math.pi / n, (k + 1) * 2 * math.pi / n
		rod(par, E, V(0, math.cos(a1) * r, math.sin(a1) * r), V(0, math.cos(a2) * r, math.sin(a2) * r), 0.09, col, M.Metal)
	end
end
function T.place(par, F, SW, fasciaB, side, trade, variant)
	local m = Instance.new("Model"); m.Name = "TradeSign"; m.Parent = par
	local list = TRADES[trade] or {"key"}
	local kind = list[((variant - 1) % #list) + 1]
	local pal = PALETTES[((variant - 1 + #trade) % #PALETTES) + 1]
	local withHoop = (variant % 2 == 0)
	local hx = side * (SW / 2 - 0.4)
	local armY = fasciaB + 1.15
	local z0, z1 = -1.32, -4.1
	P(m, V(0.5, 1.2, 0.1), F * C(hx, armY - 0.3, z0), IRON, M.Metal)
	local a = (F * C(hx, armY, z0)).Position
	local b = (F * C(hx, armY, z1)).Position
	P(m, V(0.12, 0.12, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), IRON, M.Metal)
	local c = (F * C(hx, armY - 0.85, z0)).Position
	local d = (F * C(hx, armY, z0 - 1.6)).Position
	P(m, V(0.09, 0.09, (d - c).Magnitude), CFrame.lookAt((c + d) / 2, d), IRON, M.Metal)
	for _, sc in ipairs({{z0 - 0.55, armY - 0.35, 0.45}, {z0 - 1.25, armY + 0.22, 0.32}}) do
		P(m, V(0.07, sc[3], sc[3]), F * C(hx, sc[2], sc[1]), IRON, M.Metal, CYL)
	end
	P(m, V(0.2, 0.2, 0.2), F * C(hx, armY, z1 - 0.08), IRON, M.Metal, BALL)
	local ez = -2.85
	local ey = armY - 1.32
	for _, dz in ipairs({-0.45, 0.45}) do P(m, V(0.05, 0.3, 0.05), F * C(hx, armY - 0.2, ez + dz), IRON, M.Metal) end
	local E = F * C(hx, ey, ez)
	if withHoop then hoop(m, E, 1.05, (pal.main == rgb(30, 28, 30)) and rgb(200, 160, 90) or IRON) end
	EM[kind](m, E, pal)
	m:SetAttribute("Emblem", kind)
	return m
end
return T
