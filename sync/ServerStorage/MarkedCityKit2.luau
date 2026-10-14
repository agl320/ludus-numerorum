-- MarkedCityKit2: gothic / civil-engineering additions on top of MarkedCityKit
local K = require(game:GetService("ServerStorage").MarkedCityKit:Clone())
local C, A, V, M = K.C, K.A, K.V, K.M
local pi, rad, floor, max, min, abs = math.pi, math.rad, math.floor, math.max, math.min, math.abs
local rgb = K.rgb
K.gothic = {stone = rgb(96, 88, 84), stoneL = rgb(124, 114, 106), trim = rgb(146, 136, 124), roof = rgb(42, 40, 50), inner = rgb(118, 108, 100)}
K.glass = {"Bright orange", "Neon orange", "Bright red", "Crimson", "Bright orange"}

-- 4-sided pyramid roof, base centred at cf (y = base plane), half = half width
function K.pyramid(par, cf, half, h, color, mat, props)
	for k = 0, 3 do
		K.CW(par, V(half, h, half), cf * A(0, k * pi / 2, 0) * C(half / 2, h / 2, -half / 2) * A(0, pi, 0), color, mat, props)
	end
end
-- isosceles triangle in a wall plane (base centred at cf, thickness th)
function K.tri(par, cf, w, th, h, color, mat, solid)
	local f = solid and K.W or K.DW
	local a = f(par, V(th, h, w / 2), cf * C(-w / 4, h / 2, 0) * A(0, pi / 2, 0), color, mat)
	local b = f(par, V(th, h, w / 2), cf * C(w / 4, h / 2, 0) * A(0, -pi / 2, 0), color, mat)
	return a, b
end
-- pointed (lancet) window. cf: wall surface at bottom-centre of glass, outward -Z
function K.lancet(par, cf, w, h, o)
	o = o or {}
	local g = K.gothic
	local fc = o.frame or g.trim
	K.D(par, V(w + 0.8, h + 0.4, 0.3), cf * C(0, h / 2, -0.15), fc, M.Concrete)
	K.tri(par, cf * C(0, h + 0.4, -0.15), w + 0.8, 0.3, w * 0.95 + 0.4, fc, M.Concrete)
	local pane = K.D(par, V(w, h, 0.15), cf * C(0, h / 2, -0.33), nil, M.Neon)
	local t1, t2 = K.tri(par, cf * C(0, h, -0.33), w, 0.15, w * 0.95, nil, M.Neon)
	if o.solid then for _, p in ipairs({pane, t1, t2}) do p.Material = M.Wood; p.Color = rgb(40, 24, 22) end
	elseif o.dark then for _, p in ipairs({pane, t1, t2}) do p.Material = M.SmoothPlastic; p.Color = rgb(14, 12, 14) end
	else
		local col = BrickColor.new(o.color or K.pick(K.glass))
		for _, p in ipairs({pane, t1, t2}) do p.BrickColor = col; p.Transparency = o.dim or 0.35 end
		K.Ds(par, V(0.18, h + w * 0.7, 0.12), cf * C(0, (h + w * 0.7) / 2, -0.45), rgb(40, 34, 34), M.Metal)
		for y = h * 0.25, h - 0.5, h * 0.25 do K.Ds(par, V(w, 0.14, 0.12), cf * C(0, y, -0.45), rgb(40, 34, 34), M.Metal) end
		if o.mosaic then
			local cols = {rgb(170, 30, 36), rgb(220, 120, 40), rgb(110, 30, 90), rgb(40, 60, 120), rgb(200, 150, 60)}
			local nx = max(1, floor(w / 2))
			local ny = max(1, floor(h / 2))
			for r = 0, ny - 1 do for c = 0, nx - 1 do
				local p = K.Ds(par, V(w / nx - 0.1, h / ny - 0.1, 0.05), cf * C(-w / 2 + (c + 0.5) * w / nx, (r + 0.5) * h / ny, -0.52), cols[((r + c) % 5) + 1], M.Neon)
				p.Transparency = 0.15
			end end
		end
	end
	K.D(par, V(w + 1.2, 0.4, 0.8), cf * C(0, -0.2, -0.4), fc, M.Concrete)
	return pane
end
-- rose window
function K.rose(par, cf, dia, o)
	o = o or {}
	local g = K.gothic
	K.deco(K.cyl(par, 0.5, dia + 1.4, cf * C(0, 0, -0.25) * A(0, pi / 2, 0), g.trim, M.Concrete))
	local r1 = K.deco(K.cyl(par, 0.2, dia, cf * C(0, 0, -0.55) * A(0, pi / 2, 0), nil, M.Neon)); r1.BrickColor = BrickColor.new("Bright red"); r1.Transparency = 0.25
	local n = o.spokes or 12
	for k = 0, n - 1 do local a = k * 2 * pi / n; K.Ds(par, V(0.3, dia * 0.48, 0.2), cf * C(0, 0, -0.75) * A(0, 0, a) * C(0, dia * 0.25, 0), rgb(36, 30, 30), M.Metal) end
	K.deco(K.cyl(par, 0.24, dia * 0.52, cf * C(0, 0, -0.7) * A(0, pi / 2, 0), rgb(36, 30, 30), M.Metal))
	local r2 = K.deco(K.cyl(par, 0.2, dia * 0.43, cf * C(0, 0, -0.76) * A(0, pi / 2, 0), nil, M.Neon)); r2.BrickColor = BrickColor.new("Bright orange"); r2.Transparency = 0.15
	for k = 0, n - 1 do local a = k * 2 * pi / n + pi / n; K.deco(K.ball(par, dia * 0.11, (cf * C(math.sin(a) * dia * 0.37, math.cos(a) * dia * 0.37, -0.75)).Position, rgb(36, 30, 30), M.Metal)) end
end
-- buttress with pinnacle, on wall face cf (outward -Z) at ground
function K.buttress(par, cf, h, o)
	o = o or {}
	local g = K.gothic
	local w, d = o.w or 3.2, o.d or 2.6
	K.P(par, V(w, h, d), cf * C(0, h / 2, -d / 2), g.stoneL, M.Limestone, {Name = "Buttress"})
	K.W(par, V(w, o.cap or 4, d), cf * C(0, h + (o.cap or 4) / 2, -d / 2) * A(0, pi, 0), g.stoneL, M.Limestone)
	K.P(par, V(1.4, 5, 1.4), cf * C(0, h + 2.4, -0.9), g.trim, M.Concrete)
	K.pyramid(par, cf * C(0, h + 4.9, -0.9), 0.7, 3, g.trim, M.Concrete)
end
-- arcade bay: pier + pointed arch opening, on a wall face. cf: face, outward -Z, at ground; w = bay width
function K.arch(par, cf, w, pierW, springY, topY, color, mat)
	local open = w - pierW
	local rr = open / 2
	K.P(par, V(pierW, topY, 2.2), cf * C(-w / 2 + pierW / 2, topY / 2, 1.1), color, mat, {Name = "Pier"})
	local cx = pierW / 2
	for i = 1, 10 do
		local u = -rr + (i - 0.5) * open / 10
		local y = springY + math.sqrt(max(0, rr * rr - u * u)) * 0.95 + (1 - abs(u) / rr) * rr * 0.25
		y = min(y, topY - 0.3)
		K.P(par, V(open / 10 + 0.02, topY - y, 2.0), cf * C(cx + u, y + (topY - y) / 2, 1.0), color, mat)
	end
	for k = 0, 14 do
		local t = rad(k * 180 / 14)
		local p = V(cx + math.cos(t) * (rr + 0.45), springY + math.sin(t) * (rr + 0.45), -0.15)
		K.Ds(par, V(0.78, 0.9, 0.5), cf * C(p) * A(0, 0, t + pi / 2), K.gothic.trim, M.Concrete)
	end
	K.Ds(par, V(1.0, 1.3, 0.6), cf * C(cx, springY + rr + 0.5, -0.1), K.col.stoneLight, M.Concrete)
end
-- canal embankment: wall from ground (y 0) down to bed, with coping and a lower towpath
function K.embankment(par, x1, x2, zWall, side, o)
	-- side = +1: land is at greater z than the wall (wall faces -z toward water)
	o = o or {}
	local depth = o.depth or 8
	local pathW = o.pathW or 6
	local pathY = o.pathY or -3
	local stone = rgb(118, 108, 100)
	-- upper wall (0 -> pathY) set back by pathW, lower wall (pathY -> -depth) at zWall
	K.box(par, V(x1, pathY, zWall), V(x2, 0, zWall + side * 0.9), stone, M.Limestone, {Name = "CanalWall"})
	-- towpath slab
	K.box(par, V(x1, pathY - 0.6, zWall), V(x2, pathY, zWall - side * pathW), rgb(104, 98, 94), M.Slate, {Name = "Towpath"})
	K.box(par, V(x1, -depth, zWall - side * pathW), V(x2, pathY, zWall - side * (pathW + 0.9)), stone, M.Limestone, {Name = "CanalWall"})
	-- coping stones
	for x = x1, x2 - 4, 4.5 do
		K.D(par, V(4.4, 0.45, 1.5), C(x + 2.2, 0.2, zWall + side * 0.3), K.col.stoneLight:Lerp(K.col.stone, K.rand(0, 0.5)), M.Limestone)
		K.D(par, V(4.4, 0.4, 1.3), C(x + 2.2, pathY + 0.2, zWall - side * (pathW + 0.35)), K.col.stoneLight:Lerp(K.col.stone, K.rand(0, 0.5)), M.Limestone)
	end
	-- moss & drains on the low wall, mooring rings
	for i = 1, floor((x2 - x1) / 7) do
		local x = K.rand(x1 + 2, x2 - 2)
		K.Ds(par, V(K.rand(2, 6), K.rand(0.8, 2.4), 0.12), C(x, pathY - 2 + K.rand(-1, 0.5), zWall - side * (pathW + 0.97)), K.col.moss:Lerp(K.col.leafDark, K.rand(0, 1)), M.LeafyGrass)
	end
	for x = x1 + 10, x2 - 6, 22 do
		K.deco(K.cyl(par, 0.5, 1.6, C(x, pathY - 3.5, zWall - side * (pathW + 0.9)) * A(0, pi / 2, 0), rgb(20, 18, 18), M.Metal))
		K.deco(K.cyl(par, 0.25, 1.0, C(x + 6, pathY + 0.9, zWall - side * (pathW + 0.9)) * A(0, pi / 2, 0), K.col.iron, M.Metal))
		K.P(par, V(0.9, 2.6, 0.9), C(x + 11, pathY + 1.3, zWall - side * (pathW - 0.8)), rgb(40, 30, 26), M.Wood, {Name = "Bollard"})
	end
end
-- stairs from street down to towpath, cut into the upper wall
function K.towpathStairs(par, x, zWall, side, pathY)
	local w = 5
	K.stairs(par, V(x, 0, zWall + side * 0.5), V(x, pathY, zWall - side * 7.5), w, rgb(126, 116, 106), M.Limestone, {sides = true})
end
-- stone arch bridge across z from zA to zB (water between), centred x
function K.stoneBridge(par, x, zA, zB, W, hump, o)
	o = o or {}
	local st = rgb(142, 130, 116)
	local stD = rgb(118, 108, 98)
	local zc = (zA + zB) / 2
	local half = (zB - zA) / 2
	local function deckY(z) local t = abs(z - zc) / half; return hump * (1 - t * t) end
	local springY = o.springY or -5
	local r = (half ^ 2 + (hump - 1.2 - springY) ^ 2) / (2 * (hump - 1.2 - springY))
	local cy = hump - 1.2 - r
	for z = zA + 0.5, zB - 0.5, 1 do
		local h = cy + math.sqrt(max(0, r * r - (z - zc) ^ 2))
		local top = deckY(z) - 1.0
		if top > h then K.P(par, V(W * 2, top - h, 1.02), C(x, (top + h) / 2, z), st, M.Limestone) end
	end
	K.slab(par, V(x, 0, zA - 0.5), V(x, hump, zc), W * 2, 1.2, rgb(92, 86, 82), M.Cobblestone, {MaterialVariant = "MarkedPaving2", Name = "BridgeDeck"})
	K.slab(par, V(x, hump, zc), V(x, 0, zB + 0.5), W * 2, 1.2, rgb(92, 86, 82), M.Cobblestone, {MaterialVariant = "MarkedPaving2", Name = "BridgeDeck"})
	for _, sx in ipairs({-1, 1}) do
		for k = 0, 22 do
			local z = zA + k * (zB - zA) / 22
			local h = cy + math.sqrt(max(0, r * r - (z - zc) ^ 2))
			local ang = math.atan2(z - zc, h - cy)
			local radial = V(0, math.cos(ang), math.sin(ang))
			K.Ds(par, V(0.5, 1.3, 1.5), C(V(x + sx * (W + 0.15), cy, zc) + radial * (r + 0.55)) * A(ang, 0, 0), K.col.stoneLight, M.Concrete)
		end
		K.deco(K.slab(par, V(x + sx * (W + 0.2), -0.6, zA - 0.5), V(x + sx * (W + 0.2), hump - 0.6, zc), 0.8, 0.5, K.col.stoneLight, M.Concrete))
		K.deco(K.slab(par, V(x + sx * (W + 0.2), hump - 0.6, zc), V(x + sx * (W + 0.2), -0.6, zB + 0.5), 0.8, 0.5, K.col.stoneLight, M.Concrete))
		K.balustrade(par, V(x + sx * (W - 0.45), 0.05, zA), V(x + sx * (W - 0.45), hump, zc), 3)
		K.balustrade(par, V(x + sx * (W - 0.45), hump, zc), V(x + sx * (W - 0.45), 0.05, zB), 3)
		for _, z in ipairs({zA - 1.5, zB + 1.5}) do
			K.P(par, V(2.4, 4.5, 2.4), C(x + sx * (W + 0.4), 2.25, z), stD, M.Limestone)
			K.D(par, V(3, 0.5, 3), C(x + sx * (W + 0.4), 4.7, z), K.col.stoneLight, M.Concrete)
			K.streetLamp(par, V(x + sx * (W + 0.4), 4.95, z), 0, {h = 7})
		end
		K.P(par, V(1.6, 8, 5), C(x + sx * (W + 0.9), -4, zc), stD, M.Limestone)
	end
end
-- iron footbridge (flat, railed, on two stone abutments)
function K.ironBridge(par, x, zA, zB, W)
	local y = 0.4
	K.box(par, V(x - W / 2, y - 0.5, zA - 1), V(x + W / 2, y, zB + 1), rgb(40, 34, 32), M.DiamondPlate, {Name = "BridgeDeck"})
	for _, sx in ipairs({-1, 1}) do
		K.D(par, V(0.6, 1.6, zB - zA + 2), C(x + sx * (W / 2 + 0.3), y - 0.6, (zA + zB) / 2), K.col.iron, M.Metal)
		K.railing(par, V(x + sx * (W / 2 - 0.2), y, zA - 1), V(x + sx * (W / 2 - 0.2), y, zB + 1), 3, {spacing = 0.7, spikes = true})
		for _, z in ipairs({zA - 1, zB + 1}) do K.P(par, V(1.6, 3.6, 1.6), C(x + sx * (W / 2 + 0.3), y + 1.8, z), K.col.iron, M.Metal) end
	end
	for z = zA + 2, zB - 2, 6 do K.deco(K.beam(par, V(x - W / 2 - 0.3, y - 1.4, z), V(x + W / 2 + 0.3, y - 1.4, z), 0.5, K.col.iron, M.Metal)) end
end
-- spiral stair inside a square tower: corners list (local to tc), total rise, flights per turn=4
function K.spiralStairs(par, tc, inner, y0, y1, turns, color)
	local corners = {V(inner, 0, -inner), V(inner, 0, inner), V(-inner, 0, inner), V(-inner, 0, -inner)}
	local n = turns * 4
	local rise = (y1 - y0) / n
	for i = 0, n - 1 do
		local a = corners[(i % 4) + 1]; local b = corners[((i + 1) % 4) + 1]
		local d = (b - a).Unit
		local from = tc + a + d * 1.2 + V(0, y0 + i * rise, 0)
		local to = tc + b - d * 1.2 + V(0, y0 + (i + 1) * rise, 0)
		K.stairs(par, from, to, 2.6, color or rgb(104, 98, 94), M.Slate, {nose = rgb(130, 122, 116)})
		if i < n - 1 then K.P(par, V(2.6, 0.6, 2.6), C(tc + b + V(0, y0 + (i + 1) * rise - 0.3, 0)), color or rgb(104, 98, 94), M.Slate, {Name = "Landing"}) end
		local side = -(a + b) / 2; side = V(side.X, 0, side.Z).Unit
		K.deco(K.beam(par, from + side * 1.3 + V(0, 3, 0), to + side * 1.3 + V(0, 3, 0), 0.18, K.col.iron, M.Metal), true)
	end
end
function K.pendant(par, top, drop, range, bright)
	local L = K.model("Lamp", par)
	K.Ds(L, V(0.1, drop, 0.1), C(top - V(0, drop / 2, 0)), K.col.iron, M.Metal)
	local c = top - V(0, drop + 0.6, 0)
	K.Ds(L, V(0.9, 0.2, 0.9), C(c + V(0, 0.65, 0)), K.col.iron, M.Metal)
	local g = K.D(L, V(0.75, 1.1, 0.75), C(c), rgb(255, 196, 120), M.Glass, {Transparency = 0.2, Name = "Glass"})
	K.Ds(L, V(0.26, 0.55, 0.26), C(c), rgb(255, 170, 80), M.Neon)
	for _, s in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do K.Ds(L, V(0.08, 1.2, 0.08), C(c + V(s[1] * 0.38, 0, s[2] * 0.38)), K.col.iron, M.Metal) end
	K.Ds(L, V(0.85, 0.15, 0.85), C(c - V(0, 0.6, 0)), K.col.iron, M.Metal)
	local l = Instance.new("PointLight"); l.Color = rgb(255, 170, 80); l.Brightness = bright or 1.4; l.Range = range or 15; l.Shadows = false; l.Parent = g
	return L
end
function K.candle(par, p, h)
	K.vcyl(par, h, 0.35, p + V(0, h / 2, 0), rgb(230, 222, 200), M.SmoothPlastic, {CanCollide = false, CanQuery = false, CastShadow = false})
	return K.Ds(par, V(0.16, 0.4, 0.16), C(p + V(0, h + 0.25, 0)), rgb(255, 180, 90), M.Neon)
end
function K.chandelier(par, c, dropTo, radius, lights)
	K.Ds(par, V(0.12, dropTo, 0.12), C(c + V(0, dropTo / 2 + 0.5, 0)), K.col.iron, M.Metal)
	K.deco(K.cyl(par, 0.3, radius * 2, C(c) * A(0, 0, pi / 2), K.col.iron, M.Metal), true)
	K.deco(K.cyl(par, 0.3, radius, C(c + V(0, 1.5, 0)) * A(0, 0, pi / 2), K.col.iron, M.Metal), true)
	for k = 0, lights - 1 do local a = k * 2 * pi / lights; K.candle(par, c + V(math.cos(a) * radius * 0.92, 0.15, math.sin(a) * radius * 0.92), 0.8) end
	local g = K.D(par, V(0.2, 0.2, 0.2), C(c + V(0, 0.8, 0)), K.col.leaf, M.SmoothPlastic, {Transparency = 1, Name = "Glass"})
	local l = Instance.new("PointLight"); l.Color = rgb(255, 170, 90); l.Brightness = 1.6; l.Range = 36; l.Shadows = false; l.Parent = g
end
function K.statue(par, name, pos, height, yaw, noCollide)
	local src = game:GetService("ServerStorage").MarkedNature:FindFirstChild(name)
	local s = src:Clone()
	for _, d in ipairs(s:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = not noCollide; d.CanQuery = not noCollide; d.CanTouch = false end end
	local cf, size = s:GetBoundingBox()
	s:ScaleTo(s:GetScale() * height / size.Y)
	s:PivotTo(CFrame.new(s:GetPivot().Position) * A(0, yaw or 0, 0))
	cf, size = s:GetBoundingBox()
	s:PivotTo(s:GetPivot() + ((K.R * C(pos + V(0, size.Y / 2, 0))).Position - cf.Position))
	s.Parent = par
	return s
end



------------------------------------------------------------------ NATURE v3 (leaf cards, our own textures)
local NAT = {}
K.NAT = NAT
function NAT.tex(name)
	local store = game:GetService("ServerStorage"):FindFirstChild("MarkedNature")
	return (store and store:GetAttribute("Tex_" .. name)) or ""
end
NAT.bark = {rgb(41, 34, 29), rgb(35, 29, 27), rgb(46, 39, 34), rgb(31, 27, 25)}
local WHITE = rgb(255, 255, 255)
local function nofx(p, shadow) p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = shadow == true; return p end
local function rawCard(par, tex, cf, w, h, tint)
	local p = K.P(par, V(w, h, 0.05), cf, WHITE, M.Fabric)
	p.Transparency = 1
	nofx(p, false)
	p.Name = "Leaves"
	for _, f in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local d = Instance.new("Decal")
		d.Texture = tex
		d.Face = f
		d.Color3 = tint or WHITE
		d.Parent = p
	end
	return p
end
local function card(par, tex, base, up, face, w, h, tint)
	up = up.Unit
	local right = up:Cross(face)
	if right.Magnitude < 0.05 then right = up:Cross(Vector3.xAxis) end
	right = right.Unit
	return rawCard(par, tex, CFrame.fromMatrix(base + up * (h * 0.5), right, up), w, h, tint)
end
NAT.card = card
NAT.rawCard = rawCard
local function seg(par, a, b, r0, r1, col, collide)
	local len = (b - a).Magnitude
	if len < 0.05 then return end
	local rr = (r0 + r1) / 2
	local p = K.cyl(par, len + math.min(rr, len) * 0.6, rr * 2, CFrame.lookAt((a + b) / 2, b) * A(0, pi / 2, 0), col, M.Slate, {CanCollide = collide == true, CanQuery = collide == true, CanTouch = false})
	p.CastShadow = rr > 0.18
	p.Name = "Bark"
	if r0 > 0.3 then
		local k = K.ball(par, r0 * 2.02, a, col, M.Slate)
		k.CanCollide = false; k.CanQuery = false; k.CanTouch = false; k.Name = "Bark"
	end
	return p
end
NAT.seg = seg
local function randDir(rng)
	local d = V(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	return d.Magnitude > 0.01 and d.Unit or V(1, 0, 0)
end
local function grow(par, p, dir, len, r, depth, o, rng, tips, trunk)
	local bend = (dir + V(rng:NextNumber(-o.wander, o.wander), rng:NextNumber(-o.wander * 0.3, o.wander * 0.6), rng:NextNumber(-o.wander, o.wander))).Unit
	local rEnd = r * o.taper
	local a1 = p + dir * len * 0.34
	local d2 = (dir + bend).Unit
	local a2 = a1 + d2 * len * 0.33
	local q = a2 + bend * len * 0.33
	seg(par, p, a1, r, r + (rEnd - r) * 0.34, o.bark, trunk)
	seg(par, a1, a2, r + (rEnd - r) * 0.34, r + (rEnd - r) * 0.67, o.bark, false)
	seg(par, a2, q, r + (rEnd - r) * 0.67, rEnd, o.bark, false)
	if depth <= 0 then table.insert(tips, {q, bend, len, true}) return end
	if depth <= o.leafFrom then table.insert(tips, {a2, d2, len * 0.8}) end
	local kids = rng:NextInteger(o.kids[1], o.kids[2])
	local spin = rng:NextNumber(0, 2 * pi)
	local side = bend:Cross(math.abs(bend.Y) < 0.95 and V(0, 1, 0) or V(1, 0, 0)).Unit
	local side2 = bend:Cross(side).Unit
	for k = 1, kids do
		local a = spin + k * 2 * pi / kids + rng:NextNumber(-0.4, 0.4)
		local spread = rng:NextNumber(o.spread[1], o.spread[2])
		local d = (bend * math.cos(spread) + (side * math.cos(a) + side2 * math.sin(a)) * math.sin(spread)).Unit
		d = (d + V(0, o.upBias, 0)).Unit
		grow(par, q, d, len * rng:NextNumber(o.shrink[1], o.shrink[2]), rEnd * 0.85, depth - 1, o, rng, tips, false)
	end
end
NAT.SPEC = {
	Oak = {h = 8, r = 1.3, depth = 3, kids = {2, 3}, spread = {0.5, 0.9}, shrink = {0.66, 0.8}, taper = 0.62, wander = 0.18, upBias = 0.1, leafFrom = 2, tex = "leaf_oak", card = 8.5, per = 3, inner = rgb(28, 36, 22)},
	Crimson = {h = 6.5, r = 1.05, depth = 3, kids = {2, 3}, spread = {0.55, 0.95}, shrink = {0.64, 0.78}, taper = 0.6, wander = 0.2, upBias = 0.16, leafFrom = 2, tex = "leaf_crimson", card = 7.5, per = 3, inner = rgb(52, 14, 18)},
	Autumn = {h = 7.5, r = 1.2, depth = 3, kids = {2, 3}, spread = {0.5, 0.9}, shrink = {0.66, 0.8}, taper = 0.62, wander = 0.2, upBias = 0.1, leafFrom = 2, tex = "leaf_autumn", card = 8, per = 3, inner = rgb(70, 36, 18)},
	Linden = {h = 9, r = 1.15, depth = 3, kids = {2, 3}, spread = {0.35, 0.7}, shrink = {0.66, 0.8}, taper = 0.62, wander = 0.14, upBias = 0.3, leafFrom = 2, tex = "leaf_dark", card = 8, per = 3, inner = rgb(22, 30, 20)},
	Dead = {h = 7.5, r = 1.05, depth = 4, kids = {2, 3}, spread = {0.5, 0.95}, shrink = {0.6, 0.76}, taper = 0.58, wander = 0.32, upBias = 0.22, leafFrom = -1, tex = "twigs", card = 5, per = 1},
	Willow = {h = 7, r = 1.3, depth = 3, kids = {2, 3}, spread = {0.75, 1.15}, shrink = {0.62, 0.76}, taper = 0.6, wander = 0.16, upBias = 0.12, leafFrom = 1, tex = "willow", card = 6, per = 2},
}
local function canopyCards(T, o, tips, s, rng, centre)
	local tex = NAT.tex(o.tex)
	for i, tip in ipairs(tips) do
		local out = (tip[1] - centre)
		out = out.Magnitude > 0.1 and out.Unit or V(0, 1, 0)
		for j = 1, o.per do
			local up = (out * 0.8 + V(0, 0.75, 0) + randDir(rng) * 0.55).Unit
			local face = randDir(rng)
			local w = o.card * s * rng:NextNumber(0.8, 1.2)
			local tint = WHITE:Lerp(rgb(150, 150, 150), rng:NextNumber(0, 0.35))
			card(T, tex, tip[1] - up * w * 0.25, up, face, w, w, tint)
		end
	end
end
function K.ftree(par, kind, pos, s, seed)
	s = s or 1
	local rng = Random.new(seed or K.int(1, 1e7))
	local T = K.model("Tree", par); T:SetAttribute("Kind", kind)
	local bark = NAT.bark[rng:NextInteger(1, #NAT.bark)]
	if kind == "Pine" or kind == "Cypress" then
		local h = (kind == "Pine" and 30 or 24) * s
		local tilt = V(rng:NextNumber(-0.03, 0.03), 1, rng:NextNumber(-0.03, 0.03)).Unit
		seg(T, pos - V(0, 0.5, 0), pos + tilt * h * 0.5, 1.0 * s, 0.65 * s, bark, true)
		seg(T, pos + tilt * h * 0.5, pos + tilt * h, 0.65 * s, 0.12 * s, bark, false)
		for k = 1, 5 do local a = k * 2 * pi / 5 + rng:NextNumber(0, 0.6) seg(T, pos + V(0, 0.9 * s, 0), pos + V(math.cos(a) * 2 * s, -0.2, math.sin(a) * 2 * s), 0.6 * s, 0.2 * s, bark, false) end
		local tex = NAT.tex("pine")
		local whorls = kind == "Pine" and 11 or 13
		for i = 1, whorls do
			local t = (i - 1) / (whorls - 1)
			local y = h * ((kind == "Pine" and 0.22 or 0.08) + (kind == "Pine" and 0.76 or 0.88) * t)
			local reach = (kind == "Pine" and (8.5 - 7.2 * t) or (4.4 - 3.2 * t)) * s * rng:NextNumber(0.88, 1.1)
			local n = kind == "Pine" and math.max(4, math.floor(8 - t * 4)) or 7
			local spin = rng:NextNumber(0, 2 * pi)
			local at = pos + tilt * y
			for k = 1, n do
				local a = spin + k * 2 * pi / n + rng:NextNumber(-0.2, 0.2)
				local d = V(math.cos(a), -0.28 - 0.25 * (1 - t), math.sin(a)).Unit
				seg(T, at, at + d * reach * 0.85, 0.22 * s, 0.06 * s, bark, false)
				local across = d:Cross(V(0, 1, 0)).Unit
				local sp = reach * 1.05
				for j = 0, 1 do
					local roll = j == 0 and 0.3 or -1.25
					local upv = across * math.cos(roll) + V(0, 1, 0) * math.sin(roll)
					upv = (upv - d * upv:Dot(d)).Unit
					local hh = (kind == "Pine" and 3.8 or 2.8) * s
					rawCard(T, tex, CFrame.fromMatrix(at + d * sp * 0.5, d, upv), sp, hh, WHITE:Lerp(rgb(160, 160, 160), rng:NextNumber(0, 0.3)))
				end
			end
		end
		local top = pos + tilt * h
		for j = 1, 3 do card(T, tex, top - V(0, 3 * s, 0), V(0, 1, 0), V(math.cos(j * 2.1), 0, math.sin(j * 2.1)), 2.6 * s, 4.2 * s) end
		T.WorldPivot = K.R * C(pos)
		return T
	end
	local o = NAT.SPEC[kind] or NAT.SPEC.Oak
	o.bark = bark
	local tips = {}
	local r0 = o.r * s
	for k = 1, 5 do
		local a = k * 2 * pi / 5 + rng:NextNumber(-0.3, 0.3)
		seg(T, pos + V(0, 0.9 * s, 0), pos + V(math.cos(a) * 1.9 * s, -0.45, math.sin(a) * 1.9 * s), r0 * 0.55, r0 * 0.22, bark, false)
	end
	grow(T, pos - V(0, 0.4, 0), V(rng:NextNumber(-0.06, 0.06), 1, rng:NextNumber(-0.06, 0.06)).Unit, o.h * s, r0, o.depth, o, rng, tips, true)
	local centre = Vector3.zero
	for _, t in ipairs(tips) do centre += t[1] end
	centre = centre / math.max(1, #tips) - V(0, 2 * s, 0)
	if kind == "Willow" then
		local tex = NAT.tex("willow")
		local leaf = NAT.tex("leaf_dark")
		for _, tip in ipairs(tips) do
			local out = tip[1] - centre
			out = V(out.X, 0, out.Z)
			out = out.Magnitude > 0.1 and out.Unit or V(1, 0, 0)
			card(T, leaf, tip[1] - V(0, 1.2 * s, 0), (V(0, 1, 0) + out * 0.6 + randDir(rng) * 0.3).Unit, randDir(rng), 6 * s, 5.5 * s, rgb(205, 215, 170))
			for j = 1, 4 do
				local hgt = rng:NextNumber(6, 13) * s
				local topP = tip[1] + out * rng:NextNumber(0, 2.5) * s + V(rng:NextNumber(-1.8, 1.8) * s, rng:NextNumber(-1.5, 1.2) * s, rng:NextNumber(-1.8, 1.8) * s)
				local face = (out + V(rng:NextNumber(-0.9, 0.9), 0, rng:NextNumber(-0.9, 0.9))).Unit
				card(T, tex, topP - V(0, hgt, 0), V(rng:NextNumber(-0.05, 0.05), 1, rng:NextNumber(-0.05, 0.05)), face, rng:NextNumber(2.2, 3.4) * s, hgt, WHITE:Lerp(rgb(160, 160, 150), rng:NextNumber(0, 0.4)))
			end
		end
	else
		canopyCards(T, o, tips, s, rng, centre)
	end
	T.WorldPivot = K.R * C(pos)
	return T
end
function K.fbush(par, pos, s, seed, kind)
	local rng = Random.new(seed or K.int(1, 1e7))
	local B = K.model("Bush", par)
	s = s or 1
	kind = kind or "leaf_box"
	local tex = NAT.tex(kind)
	nofx(K.ball(B, 2.2 * s, pos + V(0, 0.9 * s, 0), rgb(26, 36, 24), M.LeafyGrass), true)
	for i = 1, 7 do
		local a = i * 2 * pi / 7 + rng:NextNumber(-0.3, 0.3)
		local out = V(math.cos(a), 0, math.sin(a))
		local up = (out * 0.65 + V(0, 1, 0)).Unit
		local w = rng:NextNumber(3.6, 4.6) * s
		card(B, tex, pos + out * 0.2 * s - V(0, 0.2, 0), up, out:Cross(V(0, 1, 0)), w, w * 0.85, WHITE:Lerp(rgb(170, 170, 170), rng:NextNumber(0, 0.3)))
	end
	for i = 1, 2 do card(B, tex, pos, V(0, 1, 0), V(math.cos(i * 1.6), 0, math.sin(i * 1.6)), 3.6 * s, 3.2 * s) end
	B.WorldPivot = K.R * C(pos)
	return B
end
function K.ffern(par, pos, s, seed)
	local rng = Random.new(seed or K.int(1, 1e7))
	local F = K.model("Bush", par)
	s = s or 1
	local tex = NAT.tex("fern")
	for i = 1, 8 do
		local a = i * 2 * pi / 8 + rng:NextNumber(-0.25, 0.25)
		local out = V(math.cos(a), 0, math.sin(a))
		local up = (out * rng:NextNumber(0.8, 1.4) + V(0, 1, 0)).Unit
		local h = rng:NextNumber(2.6, 3.6) * s
		card(F, tex, pos, up, V(0, 1, 0):Cross(out) + V(0, 0.3, 0), h * 0.75, h, WHITE:Lerp(rgb(170, 170, 170), rng:NextNumber(0, 0.3)))
	end
	F.WorldPivot = K.R * C(pos)
	return F
end
function K.fgrass(par, pos, s, seed, dry)
	local rng = Random.new(seed or K.int(1, 1e7))
	local G = K.model("Bush", par)
	s = s or 1
	local tex = NAT.tex(dry and "grass_dry" or "grass")
	for i = 1, 3 do
		local a = i * pi / 3 + rng:NextNumber(-0.2, 0.2)
		card(G, tex, pos - V(0, 0.1, 0), V(rng:NextNumber(-0.1, 0.1), 1, rng:NextNumber(-0.1, 0.1)), V(math.cos(a), 0, math.sin(a)), 2.4 * s, 1.8 * s, WHITE:Lerp(rgb(170, 170, 170), rng:NextNumber(0, 0.3)))
	end
	G.WorldPivot = K.R * C(pos)
	return G
end

return K
