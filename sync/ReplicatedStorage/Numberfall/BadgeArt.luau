-- Shared art for the role / VIP badges: the painted crowns (OWNER's king's crown, VIP's coronet) and a small badge
-- builder for menus (the main-menu player card). The overhead badges are built by StarterPlayerScripts.RoleTitles;
-- the colours here match them.
local M = {}

------------------------------------------------------------------ the crowns, painted once
local AssetService = game:GetService("AssetService")
local CROWN_W, CROWN_H = 160, 100
-- shapes in a 160 x 100 canvas.
-- OWNER: a king's crown -- five points rising from a band (the middle one tallest), a pearl on every point, a crimson
-- jewel in the middle of the band with two smaller ones beside it.
local OWNER_CROWN = {
	shape = {{24, 92}, {24, 72}, {16, 30}, {42, 56}, {50, 20}, {66, 50}, {80, 8}, {94, 50}, {110, 20}, {118, 56}, {144, 30}, {136, 72}, {136, 92}},
	pearls = {{16, 28, 6.5}, {50, 18, 6.5}, {80, 7, 7}, {110, 18, 6.5}, {144, 28, 6.5}},
	apexes = {16, 50, 80, 110, 144},
	gems = {{80, 81, 8.5, 6.5, Vector3.new(196, 10, 40)}, {48, 81, 4.5, 4.5, Vector3.new(150, 6, 30)}, {112, 81, 4.5, 4.5, Vector3.new(150, 6, 30)}},
}
-- VIP: a lower, simpler coronet -- three broad points with no pearls, each tipped with a small cut diamond, and one
-- amethyst on the band. Clearly a crown, clearly not the owner's.
local VIP_CROWN = {
	shape = {{20, 92}, {20, 66}, {26, 40}, {52, 60}, {80, 26}, {108, 60}, {134, 40}, {140, 66}, {140, 92}},
	pearls = {},
	apexes = {26, 80, 134},
	gems = {
		{80, 79, 9, 7, Vector3.new(130, 50, 200)},
		{26, 41, 6, 6, Vector3.new(200, 225, 255)}, {80, 27, 7, 7, Vector3.new(200, 225, 255)}, {134, 41, 6, 6, Vector3.new(200, 225, 255)},
	},
}
local function paintCrown(spec)
	local ok, img = pcall(function() return AssetService:CreateEditableImage({Size = Vector2.new(CROWN_W, CROWN_H)}) end)
	if not ok or not img then return false end
	local W, H = CROWN_W, CROWN_H
	local shape, pearls, gems = spec.shape, spec.pearls, spec.gems
	local function inShape(x, y)
		for _, c in ipairs(pearls) do
			local dx, dy = x - c[1], y - c[2]
			if dx * dx + dy * dy <= c[3] * c[3] then return true end
		end
		for _, g in ipairs(gems) do
			local dx, dy = (x - g[1]) / g[3], (y - g[2]) / g[4]
			if dx * dx + dy * dy <= 1 then return true end
		end
		local inside, j = false, #shape
		for i = 1, #shape do
			local xi, yi, xj, yj = shape[i][1], shape[i][2], shape[j][1], shape[j][2]
			if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
			j = i
		end
		return inside
	end
	-- coverage, 3 x 3 samples a pixel (smooth edges)
	local cov = table.create(W * H, 0)
	for py = 0, H - 1 do
		for px = 0, W - 1 do
			local n = 0
			for sy = 0, 2 do for sx = 0, 2 do
				if inShape(px + (sx + 0.5) / 3, py + (sy + 0.5) / 3) then n += 1 end
			end end
			cov[py * W + px + 1] = n / 9
		end
	end
	local function covAt(x, y)
		if x < 0 or y < 0 or x >= W or y >= H then return 0 end
		return cov[y * W + x + 1]
	end
	local DARK, MID, LIGHT = Vector3.new(96, 52, 8), Vector3.new(236, 172, 56), Vector3.new(255, 242, 196)
	local function gold(l)
		l = math.clamp(l, 0, 1)
		if l < 0.6 then return DARK:Lerp(MID, l / 0.6) end
		return MID:Lerp(LIGHT, (l - 0.6) / 0.4)
	end
	local bandTop = 72
	for _, p in ipairs(shape) do if p[1] == shape[1][1] and p[2] < shape[1][2] then bandTop = p[2] end end
	local buf = buffer.create(W * H * 4)
	for py = 0, H - 1 do
		for px = 0, W - 1 do
			local a = cov[py * W + px + 1]
			local col = Vector3.zero
			if a > 0 then
				local x, y = px + 0.5, py + 0.5
				-- light from above; the band has a bright upper edge and a darker lower rim
				local l = 0.5 + 0.45 * (1 - y / H)
				if y >= bandTop then
					l = 0.62
					if y < bandTop + 3 then l = 0.95 elseif y > 87 then l = 0.42 end
				else
					-- facets: each point's left face catches the light, its right face is in shade
					local nearest, best = nil, math.huge
					for _, ax in ipairs(spec.apexes) do local d = math.abs(x - ax); if d < best then best, nearest = d, ax end end
					if nearest then l += (x < nearest) and 0.12 or -0.08 end
				end
				-- pearls: round, with a highlight up and to the left
				for _, c in ipairs(pearls) do
					local dx, dy = x - c[1], y - c[2]
					if dx * dx + dy * dy <= c[3] * c[3] then
						local hx, hy = x - (c[1] - c[3] * 0.35), y - (c[2] - c[3] * 0.35)
						l = 0.55 + 0.5 * math.clamp(1 - math.sqrt(hx * hx + hy * hy) / (c[3] * 1.1), 0, 1)
					end
				end
				col = gold(l)
				-- jewels, each in a thin gold setting
				for _, g in ipairs(gems) do
					local dx, dy = (x - g[1]) / g[3], (y - g[2]) / g[4]
					local d = dx * dx + dy * dy
					if d <= 1 then
						local hl = math.clamp(1 - math.sqrt((dx + 0.35) ^ 2 + (dy + 0.4) ^ 2), 0, 1)
						col = g[5]:Lerp(Vector3.new(255, 255, 255), hl * 0.75)
						if d > 0.72 then col = col:Lerp(Vector3.new(70, 30, 4), 0.6) end
					end
				end
				-- a dark outline: anything near the edge of the shape darkens
				local edge = 1
				for oy = -2, 2 do for ox = -2, 2 do
					if ox * ox + oy * oy <= 5 then edge = math.min(edge, covAt(px + ox, py + oy)) end
				end end
				if edge < 0.5 then col = col:Lerp(Vector3.new(58, 28, 2), 0.75 * (1 - edge * 2)) end
			end
			local o = (py * W + px) * 4
			buffer.writeu8(buf, o, math.floor(col.X + 0.5))
			buffer.writeu8(buf, o + 1, math.floor(col.Y + 0.5))
			buffer.writeu8(buf, o + 2, math.floor(col.Z + 0.5))
			buffer.writeu8(buf, o + 3, math.floor(a * 255 + 0.5))
		end
	end
	if not pcall(function() img:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), buf) end) then return false end
	return img
end
local crownCache = {}
local function crownImage(which)
	which = which or "OWNER"
	if crownCache[which] == nil then crownCache[which] = paintCrown(which == "VIP" and VIP_CROWN or OWNER_CROWN) end
	return crownCache[which]
end

M.crownImage = crownImage

------------------------------------------------------------------ MOD's shield, painted once
-- a heater shield: a bright steel rim around a midnight-blue field with a silver quill across it (the people who
-- keep the rules), light from above, a dark outline. 96 x 112.
local SHIELD_W, SHIELD_H = 96, 112
local SHIELD_OUTER = {{8, 10}, {48, 3}, {88, 10}, {88, 52}, {84, 70}, {74, 86}, {62, 98}, {48, 108}, {34, 98}, {22, 86}, {12, 70}, {8, 52}}
local SHIELD_INNER = {{16, 17}, {48, 11}, {80, 17}, {80, 52}, {76, 67}, {67, 81}, {57, 91}, {48, 98}, {39, 91}, {29, 81}, {20, 67}, {16, 52}}
local function inPoly(poly, x, y)
	local inside, j = false, #poly
	for i = 1, #poly do
		local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
		if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
		j = i
	end
	return inside
end
local shieldCache
local function shieldImage()
	if shieldCache ~= nil then return shieldCache end
	local ok, img = pcall(function() return AssetService:CreateEditableImage({Size = Vector2.new(SHIELD_W, SHIELD_H)}) end)
	if not ok or not img then shieldCache = false; return false end
	local W, H = SHIELD_W, SHIELD_H
	local cov = table.create(W * H, 0)
	for py = 0, H - 1 do
		for px = 0, W - 1 do
			local n = 0
			for sy = 0, 2 do for sx = 0, 2 do
				if inPoly(SHIELD_OUTER, px + (sx + 0.5) / 3, py + (sy + 0.5) / 3) then n += 1 end
			end end
			cov[py * W + px + 1] = n / 9
		end
	end
	local function covAt(x, y)
		if x < 0 or y < 0 or x >= W or y >= H then return 0 end
		return cov[y * W + x + 1]
	end
	local DARK, MID, LIGHT = Vector3.new(36, 62, 104), Vector3.new(150, 196, 240), Vector3.new(235, 245, 255)
	local function steel(l)
		l = math.clamp(l, 0, 1)
		if l < 0.6 then return DARK:Lerp(MID, l / 0.6) end
		return MID:Lerp(LIGHT, (l - 0.6) / 0.4)
	end
	local buf = buffer.create(W * H * 4)
	for py = 0, H - 1 do
		for px = 0, W - 1 do
			local a = cov[py * W + px + 1]
			local col = Vector3.zero
			if a > 0 then
				local x, y = px + 0.5, py + 0.5
				if inPoly(SHIELD_INNER, x, y) then
					-- the field, darker toward the point
					col = Vector3.new(34, 56, 108):Lerp(Vector3.new(10, 18, 44), y / H)
					-- a soft sheen across the upper left
					col = col:Lerp(Vector3.new(70, 100, 160), math.clamp(1 - ((x - 30) ^ 2 + (y - 26) ^ 2) / 900, 0, 1) * 0.35)
					-- the quill: a feather leaning up to the right, with its nib pointing down to the left
					local dx, dy = x - 50, y - 50
					local along = dx * 0.5 - dy * 0.866
					local across = dx * 0.866 + dy * 0.5
					if (along / 31) ^ 2 + (across / 9) ^ 2 <= 1 then
						col = across < 0 and Vector3.new(232, 242, 255) or Vector3.new(184, 206, 236)
						if math.abs(across) < 1.1 and along > -29 then col = Vector3.new(112, 152, 206) end
					elseif along <= -29 and along > -44 and math.abs(across) < 2 then
						col = Vector3.new(196, 222, 252)
					end
				else
					-- the rim: steel lit from above, its left side catching the light
					col = steel(0.45 + 0.5 * (1 - y / H) + ((x < 48) and 0.1 or -0.06))
				end
				local edge = 1
				for oy = -2, 2 do for ox = -2, 2 do
					if ox * ox + oy * oy <= 5 then edge = math.min(edge, covAt(px + ox, py + oy)) end
				end end
				if edge < 0.5 then col = col:Lerp(Vector3.new(6, 14, 30), 0.75 * (1 - edge * 2)) end
			end
			local o = (py * W + px) * 4
			buffer.writeu8(buf, o, math.floor(col.X + 0.5))
			buffer.writeu8(buf, o + 1, math.floor(col.Y + 0.5))
			buffer.writeu8(buf, o + 2, math.floor(col.Z + 0.5))
			buffer.writeu8(buf, o + 3, math.floor(a * 255 + 0.5))
		end
	end
	if not pcall(function() img:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), buf) end) then shieldCache = false; return false end
	shieldCache = img
	return img
end
M.shieldImage = shieldImage

------------------------------------------------------------------ small badges for menus
local FONT = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold)
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function cs(points)
	local k = {}
	for _, p in ipairs(points) do table.insert(k, ColorSequenceKeypoint.new(p[1], p[2])) end
	return ColorSequence.new(k)
end
local function sheen(base, mid, light)
	return cs({{0, base}, {0.38, mid}, {0.47, light}, {0.5, rgb(255, 255, 255)}, {0.53, light}, {0.62, mid}, {1, base}})
end
local GOLD_SHEEN = sheen(rgb(232, 170, 58), rgb(255, 210, 110), rgb(255, 240, 190))
local STEEL_SHEEN = sheen(rgb(120, 170, 225), rgb(170, 210, 250), rgb(225, 240, 255))
M.Styles = {
	OWNER = {text = "OWNER", width = 64, plate = cs({{0, rgb(70, 4, 16)}, {0.5, rgb(24, 2, 8)}, {1, rgb(70, 4, 16)}}), metal = GOLD_SHEEN,
		outline = rgb(40, 0, 6), crown = "OWNER", crownSize = Vector2.new(32, 20)},
	MOD = {text = "MOD", width = 46, plate = cs({{0, rgb(14, 30, 64)}, {0.5, rgb(6, 12, 30)}, {1, rgb(14, 30, 64)}}), metal = STEEL_SHEEN,
		outline = rgb(4, 10, 26), point = rgb(170, 210, 250), shield = true, shieldSize = Vector2.new(20, 23)},
	VIP = {text = "VIP", width = 44, plate = cs({{0, rgb(74, 26, 112)}, {0.5, rgb(28, 8, 48)}, {1, rgb(74, 26, 112)}}), metal = GOLD_SHEEN,
		outline = rgb(24, 4, 40), crown = "VIP", crownSize = Vector2.new(28, 18)},
}
-- builds a small badge: a frame (anchor at its bottom right) holding the plate and its crown / point. Returns the frame
-- and the gradients to sweep (M.Sweep moves them).
function M.Mini(kind, parent, zIndex)
	local st = M.Styles[kind]
	if not st then return nil end
	local z = zIndex or 6
	local H = 18
	local top = st.crown and (st.crownSize.Y - 5) or (st.shield and (st.shieldSize.Y - 6)) or (st.point and 5 or 0)
	local holder = Instance.new("Frame")
	holder.Name = "Badge"; holder.BackgroundTransparency = 1; holder.Size = UDim2.fromOffset(st.width + 4, H + top + 2)
	holder.AnchorPoint = Vector2.new(1, 0); holder.ZIndex = z
	local sweeps = {}
	local plate = Instance.new("Frame")
	plate.Name = "Plate"; plate.AnchorPoint = Vector2.new(0.5, 1); plate.Position = UDim2.new(0.5, 0, 1, -1)
	plate.Size = UDim2.fromOffset(st.width, H); plate.BackgroundColor3 = Color3.new(1, 1, 1); plate.BorderSizePixel = 0; plate.ZIndex = z
	plate.Parent = holder
	Instance.new("UICorner", plate).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("UIGradient"); fill.Color = st.plate; fill.Rotation = 90; fill.Parent = plate
	local edge = Instance.new("UIStroke"); edge.Thickness = 1.5; edge.Color = Color3.new(1, 1, 1); edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; edge.Parent = plate
	local eg = Instance.new("UIGradient"); eg.Color = st.metal; eg.Rotation = 15; eg.Parent = edge
	table.insert(sweeps, eg)
	local t = Instance.new("TextLabel")
	t.Name = "Text"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Position = UDim2.fromOffset(0, 1)
	t.Text = st.text; t.FontFace = FONT; t.TextSize = 13; t.TextColor3 = Color3.new(1, 1, 1); t.ZIndex = z + 1; t.Parent = plate
	local tg = Instance.new("UIGradient"); tg.Color = st.metal; tg.Rotation = 15; tg.Parent = t
	table.insert(sweeps, tg)
	local ts = Instance.new("UIStroke"); ts.Color = st.outline; ts.Thickness = 1; ts.Parent = t
	if st.crown then
		local img = crownImage(st.crown)
		if img then
			local c = Instance.new("ImageLabel")
			c.Name = "Crown"; c.BackgroundTransparency = 1; c.AnchorPoint = Vector2.new(0.5, 1)
			c.Position = UDim2.new(0.5, 0, 1, -H + 3); c.Size = UDim2.fromOffset(st.crownSize.X, st.crownSize.Y); c.ZIndex = z + 2
			c.ImageContent = Content.fromObject(img); c.Parent = holder
			local g = Instance.new("UIGradient")
			g.Color = cs({{0, rgb(220, 220, 220)}, {0.4, rgb(220, 220, 220)}, {0.5, rgb(255, 255, 255)}, {0.6, rgb(220, 220, 220)}, {1, rgb(220, 220, 220)}})
			g.Rotation = 15; g.Parent = c
			table.insert(sweeps, g)
		end
	elseif st.shield and shieldImage() then
		local c = Instance.new("ImageLabel")
		c.Name = "Shield"; c.BackgroundTransparency = 1; c.AnchorPoint = Vector2.new(0.5, 1)
		c.Position = UDim2.new(0.5, 0, 1, -H + 5); c.Size = UDim2.fromOffset(st.shieldSize.X, st.shieldSize.Y); c.ZIndex = z + 2
		c.ImageContent = Content.fromObject(shieldImage()); c.Parent = holder
		local g = Instance.new("UIGradient")
		g.Color = cs({{0, rgb(220, 220, 220)}, {0.4, rgb(220, 220, 220)}, {0.5, rgb(255, 255, 255)}, {0.6, rgb(220, 220, 220)}, {1, rgb(220, 220, 220)}})
		g.Rotation = 15; g.Parent = c
		table.insert(sweeps, g)
	elseif st.point then
		local d = Instance.new("Frame")
		d.Name = "Point"; d.AnchorPoint = Vector2.new(0.5, 0.5); d.Rotation = 45; d.Size = UDim2.fromOffset(6, 6)
		d.Position = UDim2.new(0.5, 0, 1, -H - 1); d.BackgroundColor3 = st.point; d.BorderSizePixel = 0; d.ZIndex = z + 2; d.Parent = holder
		local s2 = Instance.new("UIStroke"); s2.Color = st.outline; s2.Thickness = 1; s2.Parent = d
	end
	holder.Parent = parent
	return holder, sweeps
end
-- the light band crossing a badge: call with the badge's gradients and the time; it crosses once every `period` s
function M.Sweep(sweeps, now, period)
	local t = now % (period or 3.2)
	local k = math.clamp(t / 0.9, 0, 1)
	local off = -1.1 + 2.2 * (k * k * (3 - 2 * k))
	for _, g in ipairs(sweeps) do g.Offset = Vector2.new(off, 0) end
end

------------------------------------------------------------------ the full overhead title (shared)
-- The OWNER / MOD / VIP title exactly as it floats over a player's head. StarterPlayerScripts.RoleTitles puts it in a
-- BillboardGui; the lobby profile card (StarterPlayerScripts.LobbyCards) shows the very same build, scaled down, so the
-- two can never drift apart.
--   M.Title(kind, zBase) -> holder Frame (W x H px, transparent), info (for M.AnimateTitle), crownH (px above the plate)
--   M.AnimateTitle(info, now)  the light sweep, the OWNER halo breathing and its sparks twinkling
local GOLD = rgb(232, 170, 58)
local GOLD_MID = rgb(255, 210, 110)
local GOLD_LIGHT = rgb(255, 240, 190)
local STEEL = rgb(120, 170, 225)
local STEEL_MID = rgb(170, 210, 250)
local STEEL_LIGHT = rgb(225, 240, 255)
local function ns(points)
	local k = {}
	for _, p in ipairs(points) do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end
M.Titles = {
	OWNER = {
		text = "OWNER", width = 150, height = 36, textSize = 24,
		plate = cs({{0, rgb(70, 4, 16)}, {0.5, rgb(24, 2, 8)}, {1, rgb(70, 4, 16)}}),
		metal = sheen(GOLD, GOLD_MID, GOLD_LIGHT), frameThickness = 2.5, textOutline = rgb(40, 0, 6),
		crown = true, halo = GOLD_MID, lines = GOLD_MID, lineLength = 44, sparks = 6, sweepEvery = 2.6, accent = rgb(255, 40, 64),
	},
	MOD = {
		text = "MOD", width = 96, height = 28, textSize = 18,
		plate = cs({{0, rgb(14, 30, 64)}, {0.5, rgb(6, 12, 30)}, {1, rgb(14, 30, 64)}}),
		metal = sheen(STEEL, STEEL_MID, STEEL_LIGHT), frameThickness = 2, textOutline = rgb(4, 10, 26),
		shield = true, point = STEEL_MID, lines = STEEL_MID, lineLength = 30, sweepEvery = 3.6,
	},
	VIP = {
		text = "VIP", width = 84, height = 28, textSize = 18,
		plate = cs({{0, rgb(74, 26, 112)}, {0.5, rgb(28, 8, 48)}, {1, rgb(74, 26, 112)}}),
		metal = sheen(GOLD, GOLD_MID, GOLD_LIGHT), frameThickness = 2, textOutline = rgb(24, 4, 40),
		lines = GOLD_MID, lineLength = 22, plainLines = true, smallCrown = true, sweepEvery = 3.2,
	},
}
function M.Title(kind, zBase)
	local b = M.Titles[kind]
	if not b then return nil end
	local Z = zBase or 0
	local function frame(parent, name, size, pos, color, z)
		local f = Instance.new("Frame")
		f.Name = name; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Size = size; f.Position = pos
		f.BackgroundColor3 = color or Color3.new(1, 1, 1); f.BorderSizePixel = 0; f.ZIndex = (z or 1) + Z
		f.Parent = parent
		return f
	end
	local function diamond(parent, name, px, pos, color, z)
		local d = frame(parent, name, UDim2.fromOffset(px, px), pos, color, z)
		d.Rotation = 45
		return d
	end
	local function lightBand()
		return cs({{0, rgb(214, 214, 214)}, {0.4, rgb(214, 214, 214)}, {0.5, rgb(255, 255, 255)}, {0.6, rgb(214, 214, 214)}, {1, rgb(214, 214, 214)}})
	end
	local lineLen = b.lineLength or 0
	local crownH = b.crown and 28 or (b.smallCrown and 20 or (b.shield and 38 or (b.point and 12 or 0)))
	local W = b.width + 2 * (lineLen + 14)
	local H = b.height + crownH + 10
	local gui = Instance.new("Frame")
	gui.Name = "RoleTitle"; gui.BackgroundTransparency = 1; gui.Size = UDim2.fromOffset(W, H); gui.ZIndex = 1 + Z
	local info = {sweeps = {}, sparks = {}, period = b.sweepEvery, seed = math.random() * 10}
	local cy = crownH + 5 + b.height / 2
	local centre = UDim2.new(0.5, 0, 0, cy)
	if b.halo then
		local ring = frame(gui, "Halo", UDim2.fromOffset(b.width + 10, b.height + 10), centre, Color3.new(), 1)
		ring.BackgroundTransparency = 1
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke"); s.Color = b.halo; s.Thickness = 3; s.Transparency = 0.6; s.Parent = ring
		info.halo = s
	end
	local plate = frame(gui, "Plate", UDim2.fromOffset(b.width, b.height), centre, Color3.new(1, 1, 1), 3)
	Instance.new("UICorner", plate).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("UIGradient"); fill.Color = b.plate; fill.Rotation = 90; fill.Parent = plate
	local edge = Instance.new("UIStroke")
	edge.Thickness = b.frameThickness; edge.Color = Color3.new(1, 1, 1); edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; edge.Parent = plate
	local edgeG = Instance.new("UIGradient"); edgeG.Color = b.metal; edgeG.Rotation = 15; edgeG.Parent = edge
	table.insert(info.sweeps, edgeG)
	local inner = frame(plate, "Inner", UDim2.new(1, -8, 1, -8), UDim2.fromScale(0.5, 0.5), Color3.new(), 3)
	inner.BackgroundTransparency = 1
	Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)
	local innerS = Instance.new("UIStroke"); innerS.Thickness = 1; innerS.Color = Color3.new(1, 1, 1); innerS.Transparency = 0.55; innerS.Parent = inner
	local innerG = Instance.new("UIGradient"); innerG.Color = b.metal; innerG.Parent = innerS
	local t = Instance.new("TextLabel")
	t.Name = "Text"; t.AnchorPoint = Vector2.new(0.5, 0.5); t.Position = UDim2.fromScale(0.5, 0.52); t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1; t.Text = b.text; t.FontFace = FONT; t.TextSize = b.textSize; t.TextColor3 = Color3.new(1, 1, 1)
	t.ZIndex = 5 + Z; t.Parent = plate
	local tg = Instance.new("UIGradient"); tg.Color = b.metal; tg.Rotation = 15; tg.Parent = t
	table.insert(info.sweeps, tg)
	local ts = Instance.new("UIStroke"); ts.Color = b.textOutline; ts.Thickness = 1.5; ts.Parent = t
	if b.lines then
		for side = -1, 1, 2 do
			local x = side * (b.width / 2 + 6 + b.lineLength / 2)
			local line = frame(gui, "Line", UDim2.fromOffset(b.lineLength, 2), UDim2.new(0.5, x, 0, cy), b.lines, 2)
			local fade = Instance.new("UIGradient")
			fade.Transparency = side < 0 and ns({{0, 1}, {1, 0}}) or ns({{0, 0}, {1, 1}})
			fade.Parent = line
			if not b.plainLines then
				diamond(gui, "Tip", 6, UDim2.new(0.5, side * (b.width / 2 + 5), 0, cy), b.lines, 4)
				diamond(gui, "Tip", 4, UDim2.new(0.5, side * (b.width / 2 + 10 + b.lineLength), 0, cy), b.lines, 4)
			end
		end
	end
	local top = cy - b.height / 2
	if b.smallCrown then
		local img = crownImage("VIP")
		if img then
			local c = Instance.new("ImageLabel")
			c.Name = "Crown"; c.BackgroundTransparency = 1; c.AnchorPoint = Vector2.new(0.5, 1)
			c.Position = UDim2.new(0.5, 0, 0, top + 5); c.Size = UDim2.fromOffset(40, 25); c.ZIndex = 6 + Z
			c.ImageContent = Content.fromObject(img); c.Parent = gui
			local g = Instance.new("UIGradient")
			g.Color = cs({{0, rgb(220, 220, 220)}, {0.4, rgb(220, 220, 220)}, {0.5, rgb(255, 255, 255)}, {0.6, rgb(220, 220, 220)}, {1, rgb(220, 220, 220)}})
			g.Rotation = 15; g.Parent = c
			table.insert(info.sweeps, g)
		else
			diamond(gui, "Crown", 9, UDim2.new(0.5, 0, 0, top - 3), GOLD_MID, 6)
		end
	end
	local shieldImg = b.shield and shieldImage()
	if shieldImg then
		local c = Instance.new("ImageLabel")
		c.Name = "Shield"; c.BackgroundTransparency = 1; c.AnchorPoint = Vector2.new(0.5, 1)
		c.Position = UDim2.new(0.5, 0, 0, top + 8); c.Size = UDim2.fromOffset(38, 44); c.ZIndex = 6 + Z
		c.ImageContent = Content.fromObject(shieldImg); c.Parent = gui
		local g = Instance.new("UIGradient"); g.Color = lightBand(); g.Rotation = 15; g.Parent = c
		table.insert(info.sweeps, g)
	end
	if b.point and not shieldImg then
		local p = diamond(gui, "Point", 9, UDim2.new(0.5, 0, 0, top - 3), b.point, 6)
		local s = Instance.new("UIStroke"); s.Color = rgb(4, 10, 26); s.Thickness = 1; s.Parent = p
	end
	if b.crown then
		local img = crownImage()
		if img then
			local c = Instance.new("ImageLabel")
			c.Name = "Crown"; c.BackgroundTransparency = 1; c.AnchorPoint = Vector2.new(0.5, 1)
			c.Position = UDim2.new(0.5, 0, 0, top + 6); c.Size = UDim2.fromOffset(58, 36); c.ZIndex = 6 + Z
			c.ImageContent = Content.fromObject(img); c.ResampleMode = Enum.ResamplerMode.Default
			c.Parent = gui
			local g = Instance.new("UIGradient"); g.Color = lightBand(); g.Rotation = 15; g.Parent = c
			table.insert(info.sweeps, g)
		else
			local crown = Instance.new("Frame")
			crown.Name = "Crown"; crown.BackgroundTransparency = 1; crown.AnchorPoint = Vector2.new(0.5, 1)
			crown.Position = UDim2.new(0.5, 0, 0, top + 4); crown.Size = UDim2.fromOffset(50, 32); crown.ZIndex = 6 + Z; crown.Parent = gui
			local function metal(f)
				local g = Instance.new("UIGradient"); g.Color = b.metal; g.Rotation = 15; g.Parent = f
				table.insert(info.sweeps, g)
				local st = Instance.new("UIStroke"); st.Color = rgb(60, 30, 0); st.Thickness = 1; st.Parent = f
			end
			local band = frame(crown, "Band", UDim2.fromOffset(40, 9), UDim2.new(0.5, 0, 1, -5), Color3.new(1, 1, 1), 7)
			Instance.new("UICorner", band).CornerRadius = UDim.new(0, 2)
			metal(band)
			for i, spec in ipairs({{-15, 12, 20}, {0, 15, 14}, {15, 12, 20}}) do
				metal(diamond(crown, "Peak" .. i, spec[2], UDim2.new(0.5, spec[1], 0, spec[3]), Color3.new(1, 1, 1), 6))
			end
			diamond(crown, "Jewel", 6, UDim2.new(0.5, 0, 1, -5), b.accent, 9)
		end
	end
	for i = 1, (b.sparks or 0) do
		local side = i % 2 == 0 and 1 or -1
		local x = side * (b.width / 2 - 8 + ((i * 37) % 30))
		local y = cy + ((i % 3) - 1) * (b.height / 2 + 4)
		local s = diamond(gui, "Spark", 4, UDim2.new(0.5, x, 0, y), GOLD_LIGHT, 9)
		s.BackgroundTransparency = 1
		table.insert(info.sparks, s)
	end
	return gui, info, crownH
end
function M.AnimateTitle(info, now)
	local t = (now + info.seed) % info.period
	local k = math.clamp(t / 0.9, 0, 1)
	local off = -1.1 + 2.2 * (k * k * (3 - 2 * k))
	for _, g in ipairs(info.sweeps) do g.Offset = Vector2.new(off, 0) end
	if info.halo then
		local breathe = 0.5 + 0.5 * math.sin((now + info.seed) * 2.4)
		info.halo.Transparency = 0.45 + 0.4 * (1 - breathe)
		info.halo.Thickness = 2 + 2 * breathe
	end
	for i, s in ipairs(info.sparks) do
		local w = math.sin((now + info.seed) * 3.1 + i * 1.7)
		local on = math.max(0, w) ^ 3
		s.BackgroundTransparency = 1 - on
		s.Size = UDim2.fromOffset(2 + 4 * on, 2 + 4 * on)
	end
end

return M
