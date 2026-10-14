local B = {}
local V, C, A = Vector3.new, CFrame.new, CFrame.Angles
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local BRONZE = rgb(126, 90, 50)
local BRONZE_L = rgb(150, 112, 64)
local BRONZE_D = rgb(84, 60, 36)
local INNER = rgb(58, 40, 24)
local CAVITY = rgb(16, 11, 8)
local IRON = rgb(30, 27, 27)
local OAK = rgb(66, 44, 30)
local PROFILE = {
	{0.00, 1.00}, {0.03, 1.00}, {0.06, 0.985}, {0.09, 0.95}, {0.12, 0.90}, {0.15, 0.85}, {0.19, 0.795},
	{0.24, 0.74}, {0.30, 0.69}, {0.37, 0.65}, {0.45, 0.62}, {0.55, 0.60}, {0.65, 0.59}, {0.75, 0.585},
	{0.83, 0.58}, {0.88, 0.565}, {0.92, 0.54}, {0.95, 0.50}, {0.975, 0.44}, {0.99, 0.37}, {1.00, 0.30},
}
local function radiusAt(y)
	for i = 1, #PROFILE - 1 do
		local a, b = PROFILE[i], PROFILE[i + 1]
		if y >= a[1] and y <= b[1] then
			local t = (y - a[1]) / (b[1] - a[1]); t = t * t * (3 - 2 * t)
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return PROFILE[#PROFILE][2]
end
-- wall thickness as a fraction of lip radius: thick at the sound bow, thinner at the waist
local function thickAt(y) if y < 0.04 then return 0.17 end if y < 0.2 then return 0.17 - (y - 0.04) * 0.45 end return 0.10 end
local function P(par, size, cf, col, mat, o)
	local p = Instance.new("Part")
	p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = col; p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	if o and o.shape then p.Shape = o.shape end
	if o and o.noshadow then p.CastShadow = false end
	if o and o.name then p.Name = o.name end
	if o and o.refl then p.Reflectance = o.refl end
	p.Parent = par
	return p
end
local function vcyl(par, h, r, cf, col, mat, o)
	o = o or {}; o.shape = Enum.PartType.Cylinder
	return P(par, V(h, r * 2, r * 2), cf * A(0, 0, math.pi / 2), col, mat, o)
end
B.CAV = 0.46 -- the shell is open (hollow) from the lip up to this height fraction
function B.build(parent, pivot, D, name, opt)
	opt = opt or {}
	local m = Instance.new("Model"); m.Name = name or "ChurchBell"
	local Rl = D / 2
	local H = D * 0.86
	local head = 0.5 * Rl
	local topY = -head * 0.5 - 0.05
	local lipY = topY - H
	local function L(y) return pivot * C(0, lipY + y * H, 0) end
	local SEGS = opt.segs or 20
	local CAV = B.CAV
	-- hollow lower shell: tilted wall plates following the flare
	local y = 0
	while y < CAV - 1e-4 do
		local step = (y < 0.2) and 0.04 or 0.065
		local y2 = math.min(CAV, y + step)
		local r0, r1 = radiusAt(y) * Rl, radiusAt(y2) * Rl
		local th = thickAt((y + y2) / 2) * Rl
		local h = (y2 - y) * H
		local slope = math.atan2(r0 - r1, h) -- plate leans inward going up
		local rm = (r0 + r1) / 2 - th / 2
		local len = math.sqrt(h * h + (r0 - r1) ^ 2) + 0.02
		local w = 2 * ((r0 + r1) / 2) * math.tan(math.pi / SEGS) + 0.04
		for k = 0, SEGS - 1 do
			local a = (k + 0.5) * 2 * math.pi / SEGS
			local cf = L((y + y2) / 2) * A(0, a, 0) * C(0, 0, -rm) * A(-slope, 0, 0)
			local col = BRONZE:Lerp(BRONZE_D, math.clamp((0.25 - y) * 0.8, 0, 0.3))
			P(m, V(w, len, th), cf, col, M.Metal, {refl = 0.04, name = "Shell"})
			-- darker inner skin so the inside reads as hollow
		end
		y = y2
	end
	-- rolled lip (thick ring at the mouth)
	for k = 0, SEGS - 1 do
		local a = (k + 0.5) * 2 * math.pi / SEGS
		local w = 2 * Rl * 1.02 * math.tan(math.pi / SEGS) + 0.04
		P(m, V(w, 0.035 * H, 0.2 * Rl), L(0.018) * A(0, a, 0) * C(0, 0, -(Rl * 1.0 - 0.1 * Rl)), BRONZE_D, M.Metal)
	end
	-- cavity roof seen from below, and a solid upper body above it
	vcyl(m, 0.02, (radiusAt(CAV) - thickAt(CAV)) * Rl + 0.02, L(CAV - 0.003), CAVITY, M.SmoothPlastic, {noshadow = true, name = "CavityRoof"})
	y = CAV
	while y < 1 - 1e-4 do
		local step = (y > 0.88) and 0.02 or 0.045
		local y2 = math.min(1, y + step)
		local mid = (y + y2) / 2
		vcyl(m, (y2 - y) * H + 0.01, radiusAt(mid) * Rl, L(mid), BRONZE, M.Metal, {name = "Body", refl = 0.04})
		y = y2
	end
	-- raised mouldings
	for _, yb in ipairs({0.135, 0.165}) do
		for k = 0, SEGS - 1 do
			local a = (k + 0.5) * 2 * math.pi / SEGS
			local r = radiusAt(yb) * Rl
			P(m, V(2 * r * math.tan(math.pi / SEGS) + 0.05, 0.014 * H + 0.02, 0.05 * Rl), L(yb) * A(0, a, 0) * C(0, 0, -(r + 0.01 * Rl)), BRONZE_L, M.Metal, {noshadow = true})
		end
	end
	for _, yb in ipairs({0.79, 0.83, 0.875}) do vcyl(m, 0.012 * H + 0.02, radiusAt(yb) * Rl + 0.035 * Rl, L(yb), BRONZE_L, M.Metal, {noshadow = true}) end
	vcyl(m, 0.035 * H, radiusAt(0.81) * Rl + 0.02 * Rl, L(0.81), BRONZE_L:Lerp(BRONZE, 0.4), M.Metal, {noshadow = true})
	-- clapper hanging inside the cavity
	vcyl(m, (CAV - 0.12) * H, Rl * 0.05, L((CAV + 0.12) / 2), IRON, M.Metal, {name = "ClapperRod"})
	P(m, V(Rl * 0.34, Rl * 0.34, Rl * 0.34), L(0.1), IRON, M.Metal, {shape = Enum.PartType.Ball, name = "Clapper"})
	vcyl(m, 0.05 * H, Rl * 0.12, L(0.17), IRON, M.Metal)
	-- crown plate and canons
	vcyl(m, 0.03 * H, radiusAt(1) * Rl * 1.05, L(1.0), BRONZE_D, M.Metal)
	local cr = radiusAt(1) * Rl * 0.65
	local lh = 0.18 * Rl
	for k = 0, 3 do
		local cfk = L(1.0) * A(0, k * math.pi / 2 + math.pi / 4, 0)
		P(m, V(0.12 * Rl, lh, 0.12 * Rl), cfk * C(cr, lh / 2, 0), BRONZE_D, M.Metal, {noshadow = true})
		P(m, V(0.12 * Rl, lh, 0.12 * Rl), cfk * C(cr * 0.35, lh / 2, 0), BRONZE_D, M.Metal, {noshadow = true})
		P(m, V(cr * 0.75, 0.1 * Rl, 0.12 * Rl), cfk * C(cr * 0.675, lh, 0), BRONZE_D, M.Metal, {noshadow = true})
	end
	-- oak headstock, iron straps, gudgeons
	local hsL = opt.hsL or Rl * 2.7
	P(m, V(hsL, head, head * 0.9), pivot, OAK, M.Wood, {name = "Headstock"})
	P(m, V(hsL * 0.7, head * 0.25, head * 0.95), pivot * C(0, head * 0.62, 0), OAK:Lerp(Color3.new(0, 0, 0), 0.2), M.Wood)
	for _, s in ipairs({-1, 1}) do
		local x = s * cr * 0.8
		P(m, V(0.09 * Rl, head + 0.3 * Rl, head * 0.95 + 0.06), pivot * C(x, -0.1 * Rl, 0), IRON, M.Metal, {noshadow = true})
		P(m, V(0.09 * Rl, 0.08 * Rl, head + 0.1), pivot * C(x, head / 2 + 0.03, 0), IRON, M.Metal, {noshadow = true})
		P(m, V(0.4, 0.16 * Rl, 0.16 * Rl), pivot * C(s * (hsL / 2 + 0.2), 0, 0), IRON, M.Metal, {shape = Enum.PartType.Cylinder, name = "Gudgeon"})
		P(m, V(0.1 * Rl, head * 1.05, head * 1.0), pivot * C(s * (hsL / 2 - 0.08 * Rl), 0, 0), IRON, M.Metal, {noshadow = true})
	end
	m.WorldPivot = pivot
	m.Parent = parent
	return m
end
return B
