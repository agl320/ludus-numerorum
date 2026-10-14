local Res = {}
local C, A, V = CFrame.new, CFrame.Angles, Vector3.new
local M = Enum.Material
local pi = math.pi
local ROW_D = 14
local ALLEY = 7
local LANE = 10
Res.ROW_D, Res.ALLEY, Res.LANE = ROW_D, ALLEY, LANE
local function overlaps(a, list)
	for _, e in ipairs(list or {}) do
		if a[1] < e[2] and a[2] > e[1] and a[3] < e[4] and a[4] > e[3] then return true end
	end
	return false
end
local function buildRow(K, par, x0, x1, z0, z1, faceNorth, excl, rowInfo)
	local zc = (z0 + z1) / 2
	local x = x0
	local sinceGap = 0
	local houses = {}
	local nextGap = K.int(34, 50)
	local prevFloors = K.int(2, 3)
	while x < x1 - 7 do
		local w = K.int(9, 13)
		if x + w > x1 then w = x1 - x end
		if w < 7 then break end
		if sinceGap >= nextGap and x1 - x > 20 then
			local pw = K.int(5, 7)
			table.insert(rowInfo.gaps, {x, x + pw})
			x += pw
			sinceGap = 0
			nextGap = K.int(34, 50)
		else
			local rect = {x, x + w, z0, z1}
			if overlaps(rect, excl) then
				x += 2
			else
				local floors = prevFloors
				if K.chance(0.45) then floors = math.clamp(prevFloors + (K.chance(0.5) and 1 or -1), 2, 3) end
				prevFloors = floors
				local roof = K.chance(0.2) and "flat" or "gable"
				local cf = C(x + w / 2, 0, zc) * (faceNorth and A(0, pi, 0) or CFrame.identity)
				local m = K.house(par, cf, {
					w = w, d = ROW_D, floors = floors, fh = 8, roof = roof, rh = 4.8,
					style = K.pick(K.walls), shutters = K.chance(0.5), balcony = 0.22, lit = 0.32,
					quoins = K.chance(0.25), ivy = 0.12, boxes = 0.3, bay = 4.5, winW = 2.2,
					chimneys = K.chance(0.5) and {K.chance(0.5) and -1 or 1} or {},
					faces = {front = true, back = true, left = true, right = true},
					parapet = false,
				})
				m.Name = "House"
				m:SetAttribute("Residential", true)
				local top = m:GetAttribute("Top") or (1.2 + floors * 8)
				table.insert(houses, {x0 = x, x1 = x + w, top = top, roof = roof, model = m})
				x += w
				sinceGap += w
			end
		end
	end
	rowInfo.houses = houses
	return houses
end
local function houseAt(row, x)
	for _, h in ipairs(row.houses or {}) do if x >= h.x0 + 1 and x <= h.x1 - 1 then return h end end
end
Res.houseAt = houseAt
local function plank(K, par, a, b)
	local mdl = K.model("RoofBridge", par)
	K.slab(mdl, a, b, 3.2, 0.45, K.col.woodLight:Lerp(K.col.wood, 0.4), M.WoodPlanks, {Name = "Plank"})
	local dir = (b - a).Unit
	local side = dir:Cross(V(0, 1, 0)).Unit
	for s = -1, 1, 2 do
		local p = K.slab(mdl, a + side * 1.5 * s + V(0, 0.25, 0), b + side * 1.5 * s + V(0, 0.25, 0), 0.25, 0.35, K.col.woodDark, M.Wood)
		p.CanCollide = false
	end
	return mdl
end
local function shed(K, par, x, zWall, out, h)
	local mdl = K.model("Shed", par)
	local d = 3
	local zc = zWall + out * d / 2
	K.P(mdl, V(5, h, d), C(x, h / 2, zc), K.col.wood, M.WoodPlanks, {Name = "ShedWall"})
	K.W(mdl, V(5.6, 1.2, d + 0.6), C(x, h + 0.6, zc) * A(0, out > 0 and pi or 0, 0), K.col.slate2, M.Slate, {Name = "ShedRoof"})
	K.D(mdl, V(1.6, 3.2, 0.15), C(x, 1.6, zWall + out * (d + 0.06)), K.col.woodDark, M.Wood)
	return mdl
end
local function washing(K, par, a, b)
	local mdl = K.model("WashingLine", par)
	local line = K.beam(mdl, a, b, 0.06, K.col.iron, M.Metal)
	line.CanCollide = false; line.CanQuery = false
	local n = math.floor((b - a).Magnitude / 1.6)
	local cols = {K.rgb(150, 140, 126), K.rgb(110, 30, 34), K.rgb(70, 74, 84), K.rgb(180, 170, 150), K.rgb(52, 48, 50)}
	local dir = (b - a).Unit
	for i = 1, n do
		if K.chance(0.7) then
			local p = a:Lerp(b, (i - 0.5) / n)
			local hgt = K.rand(1.0, 2.0)
			local c = K.P(mdl, V(K.rand(0.8, 1.3), hgt, 0.06), CFrame.lookAt(p - V(0, hgt / 2, 0), p - V(0, hgt / 2, 0) + dir:Cross(V(0, 1, 0))), K.pick(cols), M.Fabric)
			c.CanCollide = false; c.CanQuery = false; c.CastShadow = false
		end
	end
	return mdl
end
function Res.build(K, par, rect, o)
	o = o or {}
	local x0, x1, z0, z1 = rect[1], rect[2], rect[3], rect[4]
	local blocks = {}
	local z = z1
	while z - (ROW_D * 2 + ALLEY) >= z0 - 0.1 do
		local A_ = {gaps = {}}
		local B_ = {gaps = {}}
		local aTop, aBot = z, z - ROW_D
		local bTop, bBot = aBot - ALLEY, aBot - ALLEY - ROW_D
		buildRow(K, par, x0, x1, aBot, aTop, true, o.excl, A_)
		buildRow(K, par, x0, x1, bBot, bTop, false, o.excl, B_)
		table.insert(blocks, {A = A_, B = B_, alleyZ0 = bTop, alleyZ1 = aBot, laneZ = bBot - LANE / 2})
		z = bBot - LANE
	end
	if z - ROW_D >= z0 - 0.1 then
		local A_ = {gaps = {}}
		buildRow(K, par, x0, x1, z - ROW_D, z, true, o.excl, A_)
	end
	local props = K.model("AlleyProps", par)
	for _, b in ipairs(blocks) do
		local zA, zB = b.alleyZ1, b.alleyZ0
		local x = x0 + K.rand(8, 16)
		while x < x1 - 6 do
			local ha, hb = houseAt(b.A, x), houseAt(b.B, x)
			if ha and hb then
				local ya = (ha.roof == "flat") and ha.top + 0.35 or ha.top + 0.9
				local yb = (hb.roof == "flat") and hb.top + 0.35 or hb.top + 0.9
				plank(K, props, V(x, ya, zA + 1.2), V(x, yb, zB - 1.2))
			end
			x += K.rand(20, 30)
		end
		x = x0 + K.rand(4, 10)
		local side = 1
		while x < x1 - 4 do
			local row = side > 0 and b.A or b.B
			local h = houseAt(row, x)
			if h then
				local zw = side > 0 and (zA - 0.55) or (zB + 0.55)
				if K.chance(0.55) then
					K.truss(props, V(x, 0, zw), h.top + 0.4, side > 0 and 0 or math.pi, K.col.iron)
				else
					shed(K, props, x, side > 0 and zA or zB, side > 0 and -1 or 1, K.rand(4.5, 6))
				end
			end
			side = -side
			x += K.rand(12, 18)
		end
		for i = 1, math.floor((x1 - x0) / 14) do
			local cx = K.rand(x0 + 3, x1 - 3)
			local nearA = K.chance(0.5)
			local cz = nearA and (zA - 1.6) or (zB + 1.6)
			local r = K.rng:NextNumber()
			if r < 0.35 then K.crateStack(props, C(cx, 0, cz) * A(0, K.rand(-0.3, 0.3), 0))
			elseif r < 0.6 then K.barrel(props, V(cx, 0, cz))
			end
		end
		for i = 1, math.floor((x1 - x0) / 26) do
			local lx = K.rand(x0 + 4, x1 - 4)
			local ha, hb = houseAt(b.A, lx), houseAt(b.B, lx)
			if ha and hb then
				local y = math.min(ha.top, hb.top) - K.rand(3, 6)
				washing(K, props, V(lx, y, zA - 0.2), V(lx + K.rand(-3, 3), y, zB + 0.2))
			end
		end
		if o.lamps ~= false then
			local lx = x0 + 10
			local s = 1
			while lx < x1 - 6 do
				K.streetLamp(props, V(lx, 0, b.laneZ + s * (LANE / 2 - 1)), s > 0 and pi or 0, {})
				lx += K.rand(26, 34)
				s = -s
			end
		end
	end
	return blocks
end
return Res
