-- NUMBER STYLES: how the digits are drawn on the LED visor. Shared by the server visor (VisorDisplay), the intro and
-- the shop / loadout card art. Every style draws one character into a 192 x 288 px canvas (one visor digit cell).
-- Characters used: 0-9, plus the faces "O" "_" "-" "X" (0__0 idle, X__X dead) and "*" (killcam mask).
-- Prices are in marks; Premium = Robux product key (Numberfall.Store), Vip = VIP gamepass.
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local RS = game:GetService("ReplicatedStorage")
local LEDFont = require(RS:WaitForChild("Numberfall"):WaitForChild("LEDFont"))

local S = {}
S.List = {
	{Id = "DotMatrix", Name = "Dot Matrix", Price = 0, Color = {255, 38, 48},
		Blurb = "The standard issue: round red LEDs on a 5 x 7 grid."},
	{Id = "Segment", Rarity = "Uncommon", Name = "Seven Segment", Price = 900, Color = {255, 84, 28},
		Blurb = "Alarm-clock digits. The unlit segments stay faintly visible."},
	{Id = "Pixel", Rarity = "Uncommon", Name = "8-Bit", Price = 900, Color = {40, 220, 255},
		Blurb = "Chunky arcade pixels with a hard drop shadow."},
	{Id = "Neon", Rarity = "Rare", Name = "Neon Sign", Price = 1350, Color = {255, 46, 156},
		Blurb = "Bent glass tubes in hot pink, broken where the glass turns."},
	{Id = "Glitch", Rarity = "Rare", Name = "Glitch", Price = 1350, Color = {235, 245, 255},
		Blurb = "A corrupted feed: split colour channels, torn slices and scanlines."},
	{Id = "Cathedral", Rarity = "Rare", Name = "Cathedral", Price = 1350, Color = {240, 226, 205},
		Blurb = "Blackletter numerals in bone white with a red edge, like an old church ledger."},
	{Id = "Nixie", Rarity = "Epic", Name = "Nixie Tube", Price = 1800, Color = {255, 128, 34},
		Blurb = "Warm orange filament behind a wire mesh, the other digits ghosting inside."},
	{Id = "Scrawl", Rarity = "Epic", Name = "Blood Scrawl", Price = 1800, Color = {225, 18, 36},
		Blurb = "Your number, written by hand. It doesn't dry."},
	{Id = "Static", Rarity = "Rare", Name = "Signal Lost", Price = 1350, Color = {236, 236, 242},
		Blurb = "A dying VHS feed: rolling static, a tracking bar and an OSD number that won't hold still."},
	{Id = "Heartbeat", Rarity = "Rare", Name = "Heartbeat", Price = 1350, Color = {255, 40, 60},
		Blurb = "Your number throbs with every beat while an EKG traces underneath. Still alive. For now."},
	{Id = "Hologram", Rarity = "Epic", Name = "Hologram", Price = 1800, Color = {90, 230, 255},
		Blurb = "Projected light: a cyan ghost of a number, scan beam sweeping, flickering on its emitter."},
	{Id = "CodeRain", Rarity = "Epic", Name = "Code Rain", Price = 1800, Color = {60, 255, 120},
		Blurb = "Streams of green code pour down the screen behind your number."},
	{Id = "Overcharge", Rarity = "Legendary", Name = "Overcharge", Price = 2400, Color = {165, 130, 255},
		Blurb = "Too much voltage: white-hot numerals with violet arcs crackling off the edges."},
	{Id = "Sakura", Rarity = "Rare", Name = "Sakura", Price = 1350, Color = {255, 150, 196},
		Blurb = "Ink numerals on washi paper under a blossoming cherry branch, petals drifting past."},
	{Id = "Racing", Rarity = "Rare", Name = "Pole Position", Price = 1350, Color = {228, 28, 44},
		Blurb = "Race-car livery: a bold italic number with a red drop, stripes and a chequered band."},
	{Id = "Chrome", Rarity = "Epic", Name = "Chrome", Price = 1800, Color = {214, 220, 232},
		Blurb = "Polished chrome numerals with a silver rim and a glint that sweeps across them."},
	{Id = "Outrun", Rarity = "Epic", Name = "Sunset Drive", Price = 1800, Color = {255, 70, 210},
		Blurb = "A striped retro sun sinking behind a neon grid road that rolls towards you."},
	{Id = "Tarot", Rarity = "Legendary", Name = "Tarot", Price = 2400, Color = {226, 182, 92},
		Blurb = "Every digit drawn as a gilded tarot card, under a crescent moon and a sky of stars."},
	-- case exclusive (CaseOnly: only from THE MARKED CASE, never sold in the shop)
	{Id = "StainedGlass", Rarity = "Legendary", CaseOnly = true, Name = "Stained Glass", Price = 2400, Color = {232, 162, 36},
		Blurb = "Case exclusive. A cathedral window lit from behind, your number set in the glass in lead."},
	{Id = "GildedNum", Name = "Gilded Numerals", Price = 99999, Vip = true, Color = {236, 190, 92},
		Blurb = "Gold-leaf serif numerals set between two diamonds. VIP only."},
	{Id = "Hellfire", Name = "Hellfire", Price = 99999, Premium = "NS_Hellfire", Color = {255, 120, 20},
		Blurb = "Numbers that burn: white-hot at the base, flames licking off the top."},
	{Id = "Sigil", Name = "Blood Sigil", Price = 99999, Premium = "NS_Sigil", Color = {255, 36, 56},
		Blurb = "Your number sealed in a ring of turning runes, pulsing like something woke up."},
}
S.Default = "DotMatrix"
-- rarity tiers set the prices (ReplicatedStorage.Numberfall.Rarity)
Rarity.Apply(S.List, "item")
S.ById = {}
for _, s in ipairs(S.List) do S.ById[s.Id] = s end

-- Everything is laid out in a 192 x 288 design canvas but placed with Scale, so it fits any 2:3 canvas:
-- the visor's SurfaceGuis and the small cells on the shop cards. Text styles shrink the SurfaceGui canvas instead of
-- using UIScale (TextLabels stop at TextSize 100, and UIScale'd text renders small on SurfaceGuis).
local W, H = 192, 288
local TEXT_CANVAS = Vector2.new(54, 81)
local SCREEN_BLACK = Color3.fromRGB(16, 9, 10)
local WHITE = Color3.new(1, 1, 1)
local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function mul(c, k) return Color3.new(c.R * k, c.G * k, c.B * k) end

-- ------------------------------------------------------------------ building blocks
-- ctx = {px = canvas height in pixels, k = 1 / SurfaceGui brightness}
local function frame(parent, x, y, w, h, color, z, round, anchor)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x / W, y / H)
	f.Size = UDim2.fromScale(w / W, h / H)
	f.BackgroundColor3 = color
	f.ZIndex = z or 1
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end
-- dark backing: hides the old segment outlines printed on the visor's screen texture
local function backing(surface, color)
	local b = Instance.new("Frame")
	b.Name = "Backing"; b.BorderSizePixel = 0; b.Position = UDim2.fromScale(0.08, 0); b.Size = UDim2.fromScale(0.84, 1)
	b.BackgroundColor3 = color or Color3.fromRGB(10, 6, 7); b.ZIndex = 0; b.Parent = surface
	return b
end
-- size: text height as a fraction of the canvas height; dx / dy: nudge as a fraction of the canvas
local function text(ctx, parent, char, font, size, color, dx, dy, z, rot)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5 + (dx or 0), 0.5 + (dy or 0))
	l.Size = UDim2.fromScale(1.4, 1)
	l.Text = char
	l.FontFace = font
	l.TextSize = math.min(100, math.floor(size * ctx.px + 0.5))
	l.TextColor3 = color
	l.Rotation = rot or 0
	l.ZIndex = z or 2
	l.Parent = parent
	return l
end
-- thickness in pixels of a 120 px tall canvas
local function stroke(ctx, obj, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Thickness = thickness * ctx.px / 120; s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = obj
	return s
end
local function gradient(obj, seq, rotation)
	local g = Instance.new("UIGradient")
	g.Color = seq; g.Rotation = rotation or 90
	g.Parent = obj
	return g
end

-- ------------------------------------------------------------------ renderers
local R = {}
local TEXT = {} -- styles drawn with fonts (they get the small canvas)

-- 1. DOT MATRIX (default): round LEDs on the 5 x 7 grid, soft halo
function R.DotMatrix(ctx, surface, char, color)
	backing(surface)
	local box = LEDFont.Box
	local pitch = math.min(box.W / (LEDFont.Cols - 1), box.H / (LEDFont.Rows - 1))
	local w, h = pitch * (LEDFont.Cols - 1), pitch * (LEDFont.Rows - 1)
	local x0, y0 = box.X + (box.W - w) / 2, box.Y + (box.H - h) / 2
	local halo = mul(SCREEN_BLACK:Lerp(color, 0.4), ctx.k)
	local core = color:Lerp(WHITE, 0.05)
	for _, d in ipairs(LEDFont.Dots(char)) do
		local x, y = x0 + d.X * w, y0 + d.Y * h
		frame(surface, x, y, pitch * 1.3, pitch * 1.3, halo, 1, true)
		frame(surface, x, y, pitch * 0.92, pitch * 0.92, core, 2, true)
	end
end

-- 2. SEVEN SEGMENT: pill segments, the unlit ones ghosted
local SEG = {
	["0"] = "abcdef", ["1"] = "bc", ["2"] = "abged", ["3"] = "abgcd", ["4"] = "fgbc", ["5"] = "afgcd",
	["6"] = "afgedc", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg", ["-"] = "g", ["_"] = "d", O = "abcdef",
}
function R.Segment(ctx, surface, char, color)
	local on = SEG[char]
	if not on then return R.DotMatrix(ctx, surface, char, color) end
	backing(surface)
	local x0, y0, w, h, t = 50, 50, 92, 188, 24
	local half = h / 2
	local L = w - t * 0.7
	local V = half - t * 0.7
	local segs = {
		a = {x0 + w / 2, y0, L, t}, g = {x0 + w / 2, y0 + half, L, t}, d = {x0 + w / 2, y0 + h, L, t},
		f = {x0, y0 + half / 2, t, V}, b = {x0 + w, y0 + half / 2, t, V},
		e = {x0, y0 + half * 1.5, t, V}, c = {x0 + w, y0 + half * 1.5, t, V},
	}
	local ghost = mul(SCREEN_BLACK:Lerp(color, 0.13), ctx.k * 1.3)
	local halo = mul(SCREEN_BLACK:Lerp(color, 0.5), ctx.k * 1.6)
	local core = color:Lerp(WHITE, 0.15)
	for name, s in pairs(segs) do
		local lit = string.find(on, name, 1, true) ~= nil
		if lit then
			frame(surface, s[1], s[2], s[3] + 10, s[4] + 10, halo, 1, true)
			frame(surface, s[1], s[2], s[3] - 4, s[4] - 4, core, 3, true)
		else
			frame(surface, s[1], s[2], s[3] - 4, s[4] - 4, ghost, 2, true)
		end
	end
end

-- 3. 8-BIT: square pixels (the LED font's 5 x 7 bitmaps) with a hard drop shadow
function R.Pixel(ctx, surface, char, color)
	local rows = LEDFont.Glyphs[char]
	if not rows then return end
	backing(surface)
	local cw, ch = 23, 27
	local x0, y0 = (W - cw * 5) / 2 - 3, (H - ch * 7) / 2 - 3
	local shadow = mul(SCREEN_BLACK:Lerp(color, 0.35), ctx.k * 1.6)
	local main = color
	local hi = color:Lerp(WHITE, 0.6)
	for r, row in ipairs(rows) do
		for c = 1, #row do
			if string.sub(row, c, c) == "1" then
				local x, y = x0 + (c - 1) * cw, y0 + (r - 1) * ch
				frame(surface, x + 6, y + 6, cw, ch, shadow, 1, nil, Vector2.zero)
				frame(surface, x, y, cw - 2, ch - 2, main, 2, nil, Vector2.zero)
				frame(surface, x, y, cw - 2, 5, hi, 3, nil, Vector2.zero)
			end
		end
	end
end

-- 4. NEON SIGN: bent glass tubes (polylines in a 0..1 box; separate polylines = the breaks in the glass)
local TUBES = {
	["0"] = {{{0.17, 0}, {0.83, 0}, {1, 0.15}, {1, 0.46}}, {{1, 0.54}, {1, 0.85}, {0.83, 1}, {0.17, 1}, {0, 0.85}, {0, 0.54}}, {{0, 0.46}, {0, 0.15}, {0.17, 0}}},
	["1"] = {{{0.22, 0.2}, {0.6, 0}}, {{0.6, 0.07}, {0.6, 0.46}}, {{0.6, 0.54}, {0.6, 1}}},
	["2"] = {{{0, 0.17}, {0.17, 0}, {0.83, 0}, {1, 0.17}, {1, 0.36}, {0.56, 0.66}}, {{0.47, 0.72}, {0, 1}, {1, 1}}},
	["3"] = {{{0, 0}, {1, 0}, {0.5, 0.38}}, {{0.42, 0.43}, {0.85, 0.43}, {1, 0.57}, {1, 0.85}, {0.85, 1}, {0, 1}}},
	["4"] = {{{0.68, 0.03}, {0, 0.68}, {1, 0.68}}, {{0.75, 0}, {0.75, 0.6}}, {{0.75, 0.76}, {0.75, 1}}},
	["5"] = {{{1, 0}, {0.07, 0}}, {{0.02, 0.06}, {0, 0.44}, {0.8, 0.42}, {1, 0.6}, {1, 0.85}, {0.85, 1}, {0, 1}}},
	["6"] = {{{0.9, 0}, {0.3, 0}, {0, 0.38}}, {{0, 0.46}, {0, 0.85}, {0.15, 1}, {0.85, 1}, {1, 0.85}, {1, 0.6}, {0.85, 0.47}, {0.07, 0.47}}},
	["7"] = {{{0, 0}, {1, 0}, {0.66, 0.56}}, {{0.61, 0.64}, {0.4, 1}}},
	["8"] = {{{0.15, 0}, {0.85, 0}, {1, 0.12}, {1, 0.36}, {0.85, 0.47}, {0.15, 0.47}, {0, 0.36}, {0, 0.12}, {0.15, 0}}, {{0.15, 0.53}, {0, 0.64}, {0, 0.88}, {0.15, 1}, {0.85, 1}, {1, 0.88}, {1, 0.64}, {0.85, 0.53}, {0.15, 0.53}}},
	["9"] = {{{0.93, 0.53}, {0.15, 0.53}, {0, 0.4}, {0, 0.15}, {0.15, 0}, {0.85, 0}, {1, 0.15}, {1, 0.62}}, {{0.97, 0.7}, {0.7, 1}, {0.1, 1}}},
	["-"] = {{{0.12, 0.5}, {0.88, 0.5}}},
	["_"] = {{{0.05, 1}, {0.95, 1}}},
	O = {{{0.2, 0.05}, {0.8, 0.05}, {1, 0.25}, {1, 0.75}, {0.8, 0.95}, {0.2, 0.95}, {0, 0.75}, {0, 0.25}, {0.2, 0.05}}},
	X = {{{0, 0.05}, {1, 0.95}}, {{1, 0.05}, {0.56, 0.45}}, {{0.44, 0.55}, {0, 0.95}}},
	["*"] = {{{0.5, 0.22}, {0.5, 0.78}}, {{0.2, 0.36}, {0.8, 0.64}}, {{0.2, 0.64}, {0.8, 0.36}}},
}
local function tube(parent, a, b, width, color, z)
	local dx, dy = b.X - a.X, b.Y - a.Y
	local f = frame(parent, (a.X + b.X) / 2, (a.Y + b.Y) / 2, math.sqrt(dx * dx + dy * dy) + width, width, color, z, true)
	f.Rotation = math.deg(math.atan2(dy, dx))
end
function R.Neon(ctx, surface, char, color)
	local lines = TUBES[char]
	if not lines then return end
	backing(surface)
	local G = {X = 50, Y = 56, W = 92, H = 176}
	local layers = {
		{36, mul(SCREEN_BLACK:Lerp(color, 0.3), ctx.k * 2)},
		{24, mul(SCREEN_BLACK:Lerp(color, 0.6), ctx.k * 2)},
		{15, color},
		{6, color:Lerp(WHITE, 0.75)},
	}
	-- one holder so the whole sign can buzz off for a moment (NumberStyleFX: NumFX_Blink)
	local tubes = Instance.new("Frame")
	tubes.Name = "Tubes"; tubes.BackgroundTransparency = 1; tubes.Size = UDim2.fromScale(1, 1); tubes.ZIndex = 1; tubes.Parent = surface
	tubes:SetAttribute("Rate", 0.012); tubes:AddTag("NumFX_Blink")
	for z, layer in ipairs(layers) do
		for _, line in ipairs(lines) do
			for i = 1, #line - 1 do
				local a = Vector2.new(G.X + line[i][1] * G.W, G.Y + line[i][2] * G.H)
				local b = Vector2.new(G.X + line[i + 1][1] * G.W, G.Y + line[i + 1][2] * G.H)
				tube(tubes, a, b, layer[1], layer[2], z)
			end
		end
	end
end

-- 5. GLITCH: a corrupted feed. Split colour channels, torn slices shoved sideways, corrupt blocks, a tear line and
-- scanlines. The slices / channels / blocks are tagged so StarterPlayerScripts.NumberGlitchFX keeps them twitching.
-- Readability: all the corruption sits BEHIND the real digit, which is drawn last, solid, with a dark outline
-- (so the number reads as clearly as every other style).
local CONDENSED_BOLD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
TEXT.Glitch = true
function R.Glitch(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(6, 6, 9))
	local rnd = Random.new((string.byte(char) or 48) * 7919)
	local size = 1.25
	local cyan, mag = Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 20, 90)
	for _, ch in ipairs({{cyan, -0.045, -0.01, 2}, {mag, 0.045, 0.01, 3}}) do
		local l = text(ctx, surface, char, CONDENSED_BOLD, size, ch[1], ch[2], ch[3], ch[4])
		l:SetAttribute("BaseX", ch[2]); l:AddTag("NumberGlitchCh")
	end
	local main = text(ctx, surface, char, CONDENSED_BOLD, size, color, 0, 0, 9)
	stroke(ctx, main, Color3.fromRGB(4, 4, 8), 1.6, 0)
	-- torn slices: bands of the digit cut out and shoved sideways, some in the split colours
	local y = 0.14
	for i = 1, 4 do
		local hgt = rnd:NextNumber(0.025, 0.06)
		y += rnd:NextNumber(0.05, 0.14)
		if y + hgt > 0.88 then break end
		local shift = rnd:NextNumber(0.04, 0.11) * (rnd:NextInteger(0, 1) == 0 and -1 or 1)
		local clip = Instance.new("Frame")
		clip.Name = "Slice"; clip.BorderSizePixel = 0; clip.ClipsDescendants = true; clip.BackgroundTransparency = 1
		clip.Position = UDim2.fromScale(0.08, y); clip.Size = UDim2.fromScale(0.84, hgt); clip.ZIndex = 4
		clip.Parent = surface
		local inner = Instance.new("Frame")
		inner.Name = "Inner"; inner.BackgroundTransparency = 1
		inner.Position = UDim2.fromScale((-0.08 + shift) / 0.84, -y / hgt); inner.Size = UDim2.fromScale(1 / 0.84, 1 / hgt); inner.ZIndex = 4
		inner.Parent = clip
		text(ctx, inner, char, CONDENSED_BOLD, size, ({color, cyan, mag})[i % 3 + 1], 0, 0, 4).TextTransparency = 0.3
		clip:AddTag("NumberGlitch")
		y += hgt
	end
	-- corrupt blocks
	for _ = 1, 5 do
		local f = frame(surface, rnd:NextNumber(34, 158), rnd:NextNumber(36, 252), rnd:NextNumber(8, 36), rnd:NextNumber(4, 14),
			({cyan, mag, WHITE})[rnd:NextInteger(1, 3)], 5)
		f.BackgroundTransparency = rnd:NextNumber(0.25, 0.7)
		f:AddTag("NumberGlitchBlock")
	end
	-- tear line
	local tear = frame(surface, W / 2, rnd:NextNumber(90, 200), W * 0.84, 2, WHITE, 6)
	tear.BackgroundTransparency = 0.35; tear:AddTag("NumberGlitchBlock")
	-- scanlines (light, so they don't cut the digit up)
	for sy = 4, H, 8 do
		local l = frame(surface, W / 2, sy, W * 0.84, 3, Color3.new(0, 0, 0), 10)
		l.BackgroundTransparency = 0.82
	end
end

-- 6. CATHEDRAL: blackletter numerals, bone white with a red edge
local GOTHIC = Font.new(Font.fromEnum(Enum.Font.GrenzeGotisch).Family, Enum.FontWeight.Bold)
TEXT.Cathedral = true
function R.Cathedral(ctx, surface, char, color)
	backing(surface)
	local l = text(ctx, surface, char, GOTHIC, 1.3, color, 0, -0.01, 3)
	stroke(ctx, l, Color3.fromRGB(150, 10, 30), 2.2, 0.15)
end

-- 7. NIXIE TUBE: glowing filament, the other cathodes ghosting behind, wire mesh in front
local NIXIE_FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Light)
TEXT.Nixie = true
function R.Nixie(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(14, 8, 5))
	local size = 1.22
	text(ctx, surface, "8", NIXIE_FONT, size, mul(SCREEN_BLACK:Lerp(color, 0.12), ctx.k * 1.3), 0, 0, 1)
	text(ctx, surface, "0", NIXIE_FONT, size, mul(SCREEN_BLACK:Lerp(color, 0.08), ctx.k * 1.3), 0, 0, 1)
	local glow = text(ctx, surface, char, NIXIE_FONT, size, mul(color, 0.8), 0, 0, 2)
	stroke(ctx, glow, color, 3.4, 0.5)
	local core = text(ctx, surface, char, NIXIE_FONT, size, color:Lerp(Color3.fromRGB(255, 236, 200), 0.6), 0, 0, 3)
	stroke(ctx, core, color, 1, 0.15)
	core:SetAttribute("Rate", 0.025); core:SetAttribute("Low", 0.35); core:AddTag("NumFX_Flicker")
	-- wire mesh
	local mesh = mul(Color3.fromRGB(70, 40, 22), ctx.k * 1.6)
	for x = 30, 162, 16 do local f = frame(surface, x, H / 2, 2, 250, mesh, 6); f.BackgroundTransparency = 0.4 end
	for y = 22, 266, 16 do local f = frame(surface, W / 2, y, 150, 2, mesh, 6); f.BackgroundTransparency = 0.4 end
end

-- 8. BLOOD SCRAWL: hand-written marker with drips
local MARKER = Font.fromEnum(Enum.Font.PermanentMarker)
TEXT.Scrawl = true
function R.Scrawl(ctx, surface, char, color)
	backing(surface)
	local seed = string.byte(char) or 48
	local l = text(ctx, surface, char, MARKER, 0.98, color, 0, -0.03, 3, ((seed % 5) - 2) * 3)
	stroke(ctx, l, Color3.fromRGB(70, 0, 8), 1.4, 0.1)
	if char == "_" or char == "-" or char == "*" then return end
	local drip = color:Lerp(Color3.fromRGB(110, 0, 12), 0.3)
	for i = 1, 2 + seed % 2 do
		local x = 64 + ((seed * 37 + i * 53) % 64)
		local len = 26 + ((seed * 13 + i * 29) % 40)
		local d = frame(surface, x, 200, 10, len, drip, 4, true, Vector2.new(0.5, 0))
		d:SetAttribute("Period", 2.5 + (seed * i) % 3); d:AddTag("NumFX_Drip")
		local blob = Instance.new("Frame")
		blob.BorderSizePixel = 0; blob.BackgroundColor3 = drip; blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.fromScale(0.5, 1); blob.Size = UDim2.fromScale(1.5, 1.5); blob.SizeConstraint = Enum.SizeConstraint.RelativeXX
		blob.ZIndex = 4; blob.Parent = d
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.5, 0); bc.Parent = blob
	end
end

-- 9. GILDED NUMERALS (VIP): gold-leaf serif between two diamonds
local SERIF = Font.new(Font.fromEnum(Enum.Font.Bodoni).Family, Enum.FontWeight.Bold)
TEXT.GildedNum = true
local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 190)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(226, 172, 62)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(176, 120, 34)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 214, 120)),
})
function R.GildedNum(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(12, 9, 6))
	for _, y in ipairs({26, 262}) do
		local rule = frame(surface, W / 2, y, 110, 3, color, 1)
		rule.BackgroundTransparency = 0.35
		local d = frame(surface, W / 2, y, 16, 16, WHITE, 2)
		d.Rotation = 45
		gradient(d, GOLD, 90)
	end
	local l = text(ctx, surface, char, SERIF, 1.0, WHITE, 0, 0, 3)
	gradient(l, GOLD, 90)
	stroke(ctx, l, Color3.fromRGB(80, 50, 10), 1.2, 0.1)
end

-- 10. HELLFIRE (Robux): white-hot at the base, flames off the top
TEXT.Hellfire = true
function R.Hellfire(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(14, 5, 4))
	local seed = string.byte(char) or 48
	local flame = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(200, 20, 10))
	local fade = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.3), NumberSequenceKeypoint.new(1, 0)})
	for i = 1, 5 do
		local x = 56 + (i - 1) * 20 + ((seed * i) % 7) - 3
		local hgt = 90 + ((seed * 17 + i * 31) % 70)
		local f = frame(surface, x, 170, 24, hgt, WHITE, 1, true, Vector2.new(0.5, 1))
		f.Rotation = ((seed + i * 3) % 7 - 3) * 4
		gradient(f, flame, 90).Transparency = fade
		f:AddTag("NumFX_Flame")
	end
	local l = text(ctx, surface, char, CONDENSED_BOLD, 1.18, WHITE, 0, 0.03, 3)
	gradient(l, ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 24, 12)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 126, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 244, 190)),
	}), 90)
	stroke(ctx, l, Color3.fromRGB(90, 6, 4), 1.6, 0)
	for i = 1, 4 do
		local e = frame(surface, 54 + ((seed * 23 + i * 41) % 86), 16 + ((seed * 7 + i * 19) % 40), 6, 6, Color3.fromRGB(255, 170, 60), 4, true)
		e.BackgroundTransparency = 0.2
		e:SetAttribute("Speed", 0.25 + ((seed + i) % 4) * 0.08); e:AddTag("NumFX_Rise")
	end
end

-- ------------------------------------------------------------------ animated styles
-- These tag their moving parts; StarterPlayerScripts.NumberStyleFX animates the tags on each client.
local function clipFrame(surface, z)
	local c = Instance.new("Frame")
	c.Name = "Clip"; c.BackgroundTransparency = 1; c.ClipsDescendants = true
	c.Position = UDim2.fromScale(0.08, 0); c.Size = UDim2.fromScale(0.84, 1); c.ZIndex = z or 1; c.Parent = surface
	return c
end
-- frame in clip-space (the clip covers x 0.08..0.92 of the cell)
local function cframe(clip, x, y, w, h, color, z, anchor)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0; f.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale((x / W - 0.08) / 0.84, y / H); f.Size = UDim2.fromScale(w / W / 0.84, h / H)
	f.BackgroundColor3 = color; f.ZIndex = z or 1; f.Parent = clip
	return f
end

-- 11. SIGNAL LOST: VHS static, a rolling tracking bar, an OSD number that won't hold still
-- Readability: a tall monospace OSD face at full size (the old Arcade face had to be drawn at half height to fit
-- the cell), solid with a dark outline, above the scanlines; it only dims slightly now and then.
local OSD = Font.new(Font.fromEnum(Enum.Font.RobotoMono).Family, Enum.FontWeight.Bold)
local OSD_SIZE = 1.12
TEXT.Static = true
function R.Static(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(8, 8, 10))
	local rnd = Random.new((string.byte(char) or 48) * 977)
	local clip = clipFrame(surface, 1)
	for _ = 1, 24 do
		local g = rnd:NextInteger(60, 220)
		local f = cframe(clip, rnd:NextNumber(20, 172), rnd:NextNumber(0, H), rnd:NextNumber(4, 28), rnd:NextNumber(2, 6), Color3.fromRGB(g, g, g + 8), 1)
		f.BackgroundTransparency = rnd:NextNumber(0.3, 0.85); f:AddTag("NumFX_Noise")
	end
	local bar = cframe(clip, W / 2, 0, W, 46, Color3.fromRGB(210, 210, 220), 2, Vector2.new(0.5, 0))
	bar.BackgroundTransparency = 0.86; bar:SetAttribute("Speed", 0.22); bar:AddTag("NumFX_Sweep")
	for _, ch in ipairs({{Color3.fromRGB(255, 40, 70), 0.03}, {Color3.fromRGB(40, 150, 255), -0.03}}) do
		local l = text(ctx, surface, char, OSD, OSD_SIZE, ch[1], ch[2], 0, 3)
		l.TextTransparency = 0.45; l:SetAttribute("BaseX", ch[2]); l:AddTag("NumberGlitchCh")
	end
	for sy = 3, H, 7 do
		local l = frame(surface, W / 2, sy, W * 0.84, 2, Color3.new(0, 0, 0), 5)
		l.BackgroundTransparency = 0.6
	end
	local main = text(ctx, surface, char, OSD, OSD_SIZE, color, 0, 0, 7)
	stroke(ctx, main, Color3.fromRGB(4, 4, 8), 1.6, 0)
	main:SetAttribute("Rate", 0.02); main:SetAttribute("Low", 0.2); main:AddTag("NumFX_Flicker")
end

-- 12. HEARTBEAT: the number throbs on the beat, an EKG traces underneath
TEXT.Heartbeat = true
local EKG = {{20, 258}, {58, 258}, {68, 250}, {78, 258}, {88, 258}, {96, 232}, {105, 278}, {113, 258}, {130, 258}, {140, 251}, {152, 258}, {174, 258}}
function R.Heartbeat(ctx, surface, char, color)
	backing(surface)
	local glow = text(ctx, surface, char, CONDENSED_BOLD, 1.12, color, 0, -0.05, 2)
	glow.TextTransparency = 0.35; stroke(ctx, glow, color, 5, 0.5)
	glow:AddTag("NumFX_Pulse")
	local main = text(ctx, surface, char, CONDENSED_BOLD, 1.12, color:Lerp(WHITE, 0.25), 0, -0.05, 3)
	stroke(ctx, main, Color3.fromRGB(80, 0, 10), 1.2, 0)
	for i = 1, #EKG - 1 do
		tube(surface, Vector2.new(EKG[i][1], EKG[i][2]), Vector2.new(EKG[i + 1][1], EKG[i + 1][2]), 4, color, 4)
	end
	-- a cover that slides off left to right, so the line draws itself on every beat
	local cover = frame(surface, 178, 256, 0, 52, Color3.fromRGB(10, 6, 7), 5, nil, Vector2.new(1, 0.5))
	cover:SetAttribute("W", 162 / W); cover:AddTag("NumFX_Trace")
end

-- 13. HOLOGRAM: projected cyan light, a scan beam sweeping down, flickering on its emitter
TEXT.Hologram = true
function R.Hologram(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(3, 9, 14))
	local beam = frame(surface, W / 2, 278, 150, 262, color, 1, nil, Vector2.new(0.5, 1))
	gradient(beam, ColorSequence.new(color), 90).Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.8)})
	local pad = frame(surface, W / 2, 272, 130, 12, color, 2, true)
	pad.BackgroundTransparency = 0.25; pad:SetAttribute("Rate", 0.06); pad:SetAttribute("Low", 0.8); pad:AddTag("NumFX_Flicker")
	local ghost = text(ctx, surface, char, CONDENSED_BOLD, 1.18, color, 0.025, 0.015, 3)
	ghost.TextTransparency = 0.72; ghost:SetAttribute("BaseX", 0.025); ghost:AddTag("NumberGlitchCh")
	local main = text(ctx, surface, char, CONDENSED_BOLD, 1.18, color:Lerp(WHITE, 0.4), 0, 0, 4)
	main.TextTransparency = 0.08; stroke(ctx, main, color, 1.4, 0.3)
	main:SetAttribute("Rate", 0.035); main:SetAttribute("Low", 0.6); main:AddTag("NumFX_Flicker")
	for sy = 4, H, 6 do
		local l = frame(surface, W / 2, sy, W * 0.84, 2, Color3.new(0, 0, 0), 6)
		l.BackgroundTransparency = 0.62
	end
	local clip = clipFrame(surface, 7)
	local sweep = cframe(clip, W / 2, 0, W, 18, color, 7, Vector2.new(0.5, 0))
	sweep.BackgroundTransparency = 0.68; sweep:SetAttribute("Speed", 0.5); sweep:AddTag("NumFX_Sweep")
end

-- 14. CODE RAIN: green code pouring down behind the number
local MONO = Font.fromEnum(Enum.Font.RobotoMono)
local MONO_BOLD = Font.new(MONO.Family, Enum.FontWeight.Bold)
TEXT.CodeRain = true
function R.CodeRain(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(2, 8, 4))
	local rnd = Random.new((string.byte(char) or 48) * 131)
	local clip = clipFrame(surface, 1)
	local glyphs = "0123456789ABCDEFXZ#$%&"
	for i = 1, 6 do
		local col = Instance.new("TextLabel")
		col.BackgroundTransparency = 1; col.AnchorPoint = Vector2.new(0.5, 0)
		col.Position = UDim2.fromScale(0.08 + (i - 1) * 0.168, rnd:NextNumber(-1.3, 0)); col.Size = UDim2.fromScale(0.16, 1.3)
		local t = {}
		for j = 1, 14 do local n = rnd:NextInteger(1, #glyphs); t[j] = string.sub(glyphs, n, n) end
		col.Text = table.concat(t, "\n"); col.FontFace = MONO; col.LineHeight = 0.9
		col.TextSize = math.max(4, math.floor(0.085 * ctx.px)); col.TextYAlignment = Enum.TextYAlignment.Top
		col.TextColor3 = WHITE; col.TextTransparency = rnd:NextNumber(0.25, 0.55); col.ZIndex = 1; col.Parent = clip
		gradient(col, ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.65), color:Lerp(WHITE, 0.55)), 90)
		col:SetAttribute("Speed", rnd:NextNumber(0.35, 0.8)); col:AddTag("NumFX_Fall")
	end
	local glow = text(ctx, surface, char, MONO_BOLD, 1.05, color, 0, 0, 3)
	glow.TextTransparency = 0.45; stroke(ctx, glow, color, 4, 0.55)
	local main = text(ctx, surface, char, MONO_BOLD, 1.05, color:Lerp(WHITE, 0.6), 0, 0, 4)
	stroke(ctx, main, Color3.fromRGB(0, 22, 8), 2.2, 0)
end

-- 15. OVERCHARGE: white-hot numerals, violet arcs crackling off the edges
TEXT.Overcharge = true
function R.Overcharge(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(6, 4, 14))
	local rnd = Random.new((string.byte(char) or 48) * 389)
	local glow = text(ctx, surface, char, CONDENSED_BOLD, 1.15, color, 0, 0, 2)
	glow.TextTransparency = 0.25; stroke(ctx, glow, color, 4.5, 0.4)
	glow:SetAttribute("Rate", 0.18); glow:SetAttribute("Low", 0.75); glow:AddTag("NumFX_Flicker")
	local main = text(ctx, surface, char, CONDENSED_BOLD, 1.15, WHITE:Lerp(color, 0.12), 0, 0, 4)
	stroke(ctx, main, color, 1.2, 0.05)
	-- arcs: a few bolts around the digit, flashed on and off by NumberStyleFX (NumFX_Arc)
	for _ = 1, 6 do
		local g = Instance.new("Frame")
		g.Name = "Arc"; g.BackgroundTransparency = 1; g.Size = UDim2.fromScale(1, 1); g.ZIndex = 5; g.Visible = false; g.Parent = surface
		g:AddTag("NumFX_Arc")
		local a = rnd:NextNumber(0, math.pi * 2)
		local p = Vector2.new(96 + math.cos(a) * 46, 144 + math.sin(a) * 82)
		local q = Vector2.new(96 + math.cos(a) * 92, 144 + math.sin(a) * 136)
		local prev = p
		for k = 1, 4 do
			local mid = p:Lerp(q, k / 4)
			local n = Vector2.new(-(q - p).Unit.Y, (q - p).Unit.X)
			local pt = k < 4 and mid + n * rnd:NextNumber(-14, 14) or q
			tube(g, prev, pt, 6, color, 5)
			tube(g, prev, pt, 2, WHITE, 6)
			prev = pt
		end
	end
	for _ = 1, 5 do
		local sp = frame(surface, rnd:NextNumber(40, 152), rnd:NextNumber(30, 258), 5, 5, WHITE:Lerp(color, 0.3), 6, true)
		sp:SetAttribute("Rate", 0.3); sp:SetAttribute("Low", 1); sp:AddTag("NumFX_Flicker")
	end
end

-- 16. BLOOD SIGIL (Robux): sealed in a ring of turning runes, pulsing
local RUNES = {"Ψ", "Ω", "Δ", "Σ", "Φ", "Ξ", "Λ", "Θ", "Π", "Γ"}
local RUNE_FONT = Font.fromEnum(Enum.Font.Garamond)
TEXT.Sigil = true
function R.Sigil(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(10, 3, 5))
	for _, r in ipairs({{156, 250, 2.2, 0.25}, {128, 210, 1.1, 0.45}}) do
		local ring = frame(surface, W / 2, H / 2, r[1], r[2], color, 1, true)
		ring.BackgroundTransparency = 1
		stroke(ctx, ring, color, r[3], r[4]).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	for i, rune in ipairs(RUNES) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Size = UDim2.fromScale(0.12, 0.08)
		l.Text = rune; l.FontFace = RUNE_FONT; l.TextSize = math.max(5, math.floor(0.11 * ctx.px)); l.TextColor3 = color:Lerp(WHITE, 0.2)
		l.TextTransparency = 0; l.ZIndex = 2; l.Parent = surface
		l:SetAttribute("Angle", (i - 1) / #RUNES * math.pi * 2); l:SetAttribute("Rx", 71 / W); l:SetAttribute("Ry", 115 / H)
		l:SetAttribute("Speed", 0.35); l:AddTag("NumFX_Orbit")
		local a = l:GetAttribute("Angle")
		l.Position = UDim2.fromScale(0.5 + math.cos(a) * 71 / W, 0.5 + math.sin(a) * 115 / H)
	end
	local glow = text(ctx, surface, char, SERIF, 0.95, color, 0, 0, 3)
	glow.TextTransparency = 0.3; stroke(ctx, glow, color, 5, 0.5)
	glow:SetAttribute("Mode", "breath"); glow:AddTag("NumFX_Pulse")
	local main = text(ctx, surface, char, SERIF, 0.95, color:Lerp(WHITE, 0.2), 0, 0, 4)
	stroke(ctx, main, Color3.fromRGB(40, 0, 6), 1.6, 0)
end

-- 17. SAKURA: ink numerals on cream washi paper under a blossoming cherry branch, blossoms drifting down past them.
-- Dark ink on pale paper: the most readable style there is. The branch takes one of three shapes, picked per digit,
-- so a row of digits doesn't repeat like wallpaper. (the blossom image is the lobby sakura trees' petal texture)
local BLOSSOM = "rbxassetid://110298302788516"
-- a frame covering the screen part of the cell (x 0.08..0.92) that clips, but whose children use whole-cell coords
local function cellClip(surface, z)
	local c = Instance.new("Frame")
	c.Name = "CellClip"; c.BackgroundTransparency = 1; c.ClipsDescendants = true
	c.Position = UDim2.fromScale(0.08, 0); c.Size = UDim2.fromScale(0.84, 1); c.ZIndex = z or 1; c.Parent = surface
	local inner = Instance.new("Frame")
	inner.Name = "Inner"; inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromScale(-0.08 / 0.84, 0); inner.Size = UDim2.fromScale(1 / 0.84, 1); inner.ZIndex = z or 1; inner.Parent = c
	return inner
end
local function blossom(parent, x, y, size, rot, z, transparency)
	local b = Instance.new("ImageLabel")
	b.Name = "Blossom"; b.BackgroundTransparency = 1; b.Image = BLOSSOM; b.ImageTransparency = transparency or 0
	b.AnchorPoint = Vector2.new(0.5, 0.5); b.Position = UDim2.fromScale(x / W, y / H); b.Size = UDim2.fromScale(size / W, size / H)
	b.Rotation = rot or 0; b.ZIndex = z or 3; b.Parent = parent
	return b
end
-- the branch: a long bough across the top, a short spray dipping in from a corner, or a twig rising from the bottom
local function sakuraBranch(back, seed, rnd, bark, z)
	local kind = seed % 3
	local right = (seed // 3) % 2 == 0
	local function X(x) return right and (W - x) or x end
	local function seg(a, b, w) tube(back, Vector2.new(X(a[1]), a[2]), Vector2.new(X(b[1]), b[2]), w, bark, z) end
	local flowers
	if kind == 0 then
		seg({-6, 24}, {50, 42}, 12); seg({50, 42}, {100, 36}, 9); seg({100, 36}, {148, 56}, 6)
		seg({50, 42}, {74, 14}, 5); seg({100, 36}, {116, 16}, 4)
		flowers = {{30, 28, 54}, {74, 12, 42}, {92, 46, 60}, {122, 16, 38}, {148, 58, 46}}
	elseif kind == 1 then
		seg({-6, 8}, {40, 30}, 10); seg({40, 30}, {70, 62}, 6); seg({40, 30}, {84, 22}, 5)
		flowers = {{38, 26, 50}, {70, 62, 44}, {86, 20, 40}, {58, 46, 30}}
	else
		seg({-6, 290}, {40, 250}, 11); seg({40, 250}, {58, 214}, 7); seg({40, 250}, {80, 240}, 5)
		flowers = {{42, 252, 48}, {60, 212, 40}, {84, 238, 36}}
	end
	for _, f in ipairs(flowers) do
		blossom(back, X(f[1]), f[2], f[3] * rnd:NextNumber(0.9, 1.1), rnd:NextNumber(0, 360), z + 1)
	end
end
TEXT.Sakura = true
function R.Sakura(ctx, surface, char, color)
	-- paper colours are divided by the visor's brightness, so the sheet stays cream instead of glaring white
	local paper = mul(Color3.fromRGB(242, 233, 220), ctx.k)
	backing(surface, paper)
	local seed = string.byte(char) or 48
	local rnd = Random.new(seed * 271)
	local back = cellClip(surface, 1)
	-- washi: a faint blush towards the bottom and a few paper fibres
	local wash = frame(back, W / 2, H / 2, W, H, WHITE, 1)
	gradient(wash, ColorSequence.new(paper, mul(Color3.fromRGB(240, 212, 214), ctx.k)), 90)
	for _ = 1, 3 do
		local fib = frame(back, rnd:NextNumber(30, 162), rnd:NextNumber(20, 268), rnd:NextNumber(20, 40), 1.5, mul(Color3.fromRGB(206, 190, 176), ctx.k), 1)
		fib.Rotation = rnd:NextNumber(-30, 30); fib.BackgroundTransparency = 0.7
	end
	sakuraBranch(back, seed, rnd, Color3.fromRGB(62, 36, 38), 2)
	-- blossoms drifting down past the number (NumberStyleFX: NumFX_Petal -- falls, sways and spins)
	local drift = cellClip(surface, 4)
	for _ = 1, 3 do
		local b = blossom(drift, rnd:NextNumber(30, 162), rnd:NextNumber(0, H), rnd:NextNumber(22, 32), rnd:NextNumber(0, 360), 4, 0.05)
		b:SetAttribute("Speed", rnd:NextNumber(0.06, 0.11)); b:SetAttribute("Sway", rnd:NextNumber(0.03, 0.06)); b:SetAttribute("Spin", rnd:NextNumber(-80, 80))
		b:AddTag("NumFX_Petal")
	end
	-- the number, in ink: a soft bleed under a crisp stroke
	local ink = Color3.fromRGB(30, 18, 24)
	local bleed = text(ctx, surface, char, SERIF, 0.98, ink, 0.006, 0.026, 5)
	bleed.TextTransparency = 0.8
	text(ctx, surface, char, SERIF, 0.98, ink, 0, 0.02, 6)
end

-- ------------------------------------------------------------------ 2026 styles
-- shared: a heavy geometric sans (with italic) and a glint that sweeps across a glyph (NumberStyleFX: NumFX_Shine)
local MONT = Font.fromEnum(Enum.Font.Montserrat).Family
local SANS_BLACK = Font.new(MONT, Enum.FontWeight.Heavy)
local SANS_BLACK_IT = Font.new(MONT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local function shine(ctx, surface, char, font, size, dx, dy, z, period, strength, rot)
	local l = text(ctx, surface, char, font, size, WHITE, dx, dy, z, rot)
	local g = Instance.new("UIGradient")
	g.Name = "Shine"; g.Rotation = 25
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.44, 1),
		NumberSequenceKeypoint.new(0.5, strength or 0.2),
		NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(0.12, 0) -- a still glint for the shop card; NumberStyleFX sweeps it
	g.Parent = l
	l:SetAttribute("Period", period or 3.6); l:AddTag("NumFX_Shine")
	return l
end
local function seq(t)
	local k = {}
	for _, p in ipairs(t) do table.insert(k, ColorSequenceKeypoint.new(p[1], p[2])) end
	return ColorSequence.new(k)
end
local CHROME = seq({
	{0, Color3.fromRGB(250, 252, 255)}, {0.38, Color3.fromRGB(196, 204, 216)}, {0.49, Color3.fromRGB(92, 98, 112)},
	{0.53, Color3.fromRGB(46, 50, 60)}, {0.58, Color3.fromRGB(176, 184, 198)}, {0.8, Color3.fromRGB(236, 240, 248)},
	{1, Color3.fromRGB(150, 158, 172)},
})

-- CHROME: polished Y2K chrome, a silver rim, a glint sweeping across
TEXT.Chrome = true
function R.Chrome(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(8, 8, 11))
	local back = cellClip(surface, 1)
	local bg = frame(back, W / 2, H / 2, W, H, WHITE, 1)
	gradient(bg, ColorSequence.new(Color3.fromRGB(24, 26, 34), Color3.fromRGB(5, 5, 8)), 90)
	local size, dy = 0.8, 0.01
	local shadow = text(ctx, surface, char, SANS_BLACK_IT, size, Color3.new(0, 0, 0), 0.02, dy + 0.025, 2)
	shadow.TextTransparency = 0.35
	local rim = text(ctx, surface, char, SANS_BLACK_IT, size, Color3.fromRGB(210, 216, 228), 0, dy, 3)
	stroke(ctx, rim, Color3.fromRGB(214, 220, 232), 3.2, 0)
	local main = text(ctx, surface, char, SANS_BLACK_IT, size, WHITE, 0, dy, 4)
	gradient(main, CHROME, 90)
	stroke(ctx, main, Color3.fromRGB(26, 28, 36), 1.3, 0)
	shine(ctx, surface, char, SANS_BLACK_IT, size, 0, dy, 5, 3.4, 0.1)
end

-- SUNSET DRIVE: a striped retro sun sinking behind a neon grid road that scrolls towards you
TEXT.Outrun = true
local function lerpC(a, b, t) return a:Lerp(b, math.clamp(t, 0, 1)) end
function R.Outrun(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(14, 4, 28))
	local back = cellClip(surface, 1)
	local HZ = 176 -- horizon
	-- (scenery colours are divided by the visor's brightness so the sun and grid don't wash out on the visor)
	local k = ctx.k
	local skyTop, skyLow = mul(Color3.fromRGB(18, 6, 46), k), mul(Color3.fromRGB(150, 34, 120), k)
	local sky = frame(back, W / 2, HZ / 2, W, HZ, WHITE, 1)
	gradient(sky, ColorSequence.new(skyTop, skyLow), 90)
	-- the sun, cut by bands of sky
	local sun = frame(back, W / 2, 118, 132, 132, WHITE, 2, true)
	gradient(sun, ColorSequence.new(mul(Color3.fromRGB(255, 228, 96), k), mul(Color3.fromRGB(255, 50, 150), k)), 90)
	local y, h = 122, 3
	for _ = 1, 5 do
		frame(back, W / 2, y, 140, h, lerpC(skyTop, skyLow, y / HZ), 3)
		y += h + 9; h += 2
	end
	-- the ground and its grid
	local ground = frame(back, W / 2, (HZ + H) / 2, W, H - HZ, WHITE, 4)
	gradient(ground, ColorSequence.new(mul(Color3.fromRGB(26, 4, 44), k), mul(Color3.fromRGB(8, 2, 16), k)), 90)
	local neon = Color3.fromRGB(255, 70, 210)
	local grid = mul(neon, k)
	for i = -6, 6 do
		tube(back, Vector2.new(W / 2 + i * 6, HZ), Vector2.new(W / 2 + i * 44, H + 10), 2, grid, 5)
	end
	local road = Instance.new("Frame")
	road.Name = "Road"; road.BackgroundTransparency = 1; road.ClipsDescendants = true; road.ZIndex = 5
	road.Position = UDim2.fromScale(0, HZ / H); road.Size = UDim2.fromScale(1, (H - HZ) / H); road.Parent = back
	for i = 0, 4 do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0; l.BackgroundColor3 = grid; l.ZIndex = 5
		l.Position = UDim2.fromScale(0, i / 5); l.Size = UDim2.fromScale(1, 2 / (H - HZ)); l.Parent = road
		l:SetAttribute("Speed", 0.18); l:AddTag("NumFX_Sweep")
	end
	local glowLine = frame(back, W / 2, HZ, W, 3, mul(Color3.fromRGB(255, 160, 230), k), 6)
	glowLine.BackgroundTransparency = 0.1
	-- the number: chrome in cyan -> white -> pink, set low so the sun shows above it, ringed in a thick band of
	-- night-purple so it separates cleanly from the sun and the grid
	local size, dy = 0.78, 0.08
	local ring = text(ctx, surface, char, SANS_BLACK_IT, size, Color3.fromRGB(16, 0, 30), 0, dy, 7)
	stroke(ctx, ring, Color3.fromRGB(16, 0, 30), 6.5, 0)
	local main = text(ctx, surface, char, SANS_BLACK_IT, size, WHITE, 0, dy, 8)
	gradient(main, seq({{0, Color3.fromRGB(130, 244, 255)}, {0.5, WHITE}, {0.52, Color3.fromRGB(255, 150, 220)}, {1, Color3.fromRGB(255, 70, 190)}}), 90)
	stroke(ctx, main, Color3.fromRGB(34, 0, 60), 2, 0)
	shine(ctx, surface, char, SANS_BLACK_IT, size, 0, dy, 9, 4.2, 0.25)
end

-- TAROT: every digit is a gilded tarot card -- navy, a double gold border, a crescent moon, stars
TEXT.Tarot = true
function R.Tarot(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(10, 6, 12))
	local rnd = Random.new((string.byte(char) or 48) * 389)
	local gold = Color3.fromRGB(226, 182, 92)
	local card = frame(surface, W / 2, H / 2, 150, 270, WHITE, 1)
	gradient(card, ColorSequence.new(Color3.fromRGB(30, 26, 66), Color3.fromRGB(12, 10, 30)), 90)
	local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 8 * ctx.px / H); cc.Parent = card
	stroke(ctx, card, gold, 2.2, 0).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local inner = frame(surface, W / 2, H / 2, 128, 248, gold, 2)
	inner.BackgroundTransparency = 1
	stroke(ctx, inner, gold, 0.9, 0.25).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	for _, c in ipairs({{32, 20}, {160, 20}, {32, 268}, {160, 268}}) do
		local d = frame(surface, c[1], c[2], 9, 9, gold, 3); d.Rotation = 45
	end
	-- crescent moon at the top, a row of stars at the foot
	frame(surface, W / 2, 40, 26, 26, gold, 3, true)
	frame(surface, W / 2 + 7, 36, 24, 24, Color3.fromRGB(28, 24, 62), 3, true)
	for i = -1, 1 do
		local s = frame(surface, W / 2 + i * 18, 250, i == 0 and 9 or 6, i == 0 and 9 or 6, gold, 3); s.Rotation = 45
	end
	for _ = 1, 7 do
		local s = frame(surface, rnd:NextNumber(36, 156), rnd:NextNumber(62, 226), 3, 3, Color3.fromRGB(255, 236, 190), 2, true)
		s:SetAttribute("Rate", 0.05); s:SetAttribute("Low", 0.9); s:AddTag("NumFX_Flicker")
	end
	local size, dy = 0.86, 0.02
	local main = text(ctx, surface, char, SERIF, size, WHITE, 0, dy, 5)
	gradient(main, GOLD, 90)
	stroke(ctx, main, Color3.fromRGB(46, 30, 8), 1.2, 0)
	shine(ctx, surface, char, SERIF, size, 0, dy, 6, 4.8, 0.3)
end

-- POLE POSITION: a race car's number -- livery stripes, a chequered band, a bold italic numeral with a red drop
TEXT.Racing = true
function R.Racing(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(26, 26, 30))
	local back = cellClip(surface, 1)
	local bg = frame(back, W / 2, H / 2, W, H, WHITE, 1)
	gradient(bg, ColorSequence.new(Color3.fromRGB(46, 46, 52), Color3.fromRGB(18, 18, 22)), 90)
	local red = Color3.fromRGB(228, 28, 44)
	local s1 = frame(back, 120, H / 2, 40, H + 60, red, 2); s1.Rotation = 12
	local s2 = frame(back, 150, H / 2, 10, H + 60, WHITE, 2); s2.Rotation = 12
	for i = 0, 13 do for r = 0, 1 do
		if (i + r) % 2 == 0 then frame(back, 6 + i * 13, 6 + r * 13, 13, 13, WHITE, 3, nil, Vector2.new(0, 0)) end
	end end
	local band = frame(back, W / 2, 13, W, 26, Color3.new(0, 0, 0), 2)
	band.BackgroundTransparency = 0.2
	local size, dy = 0.8, 0.05
	local drop = text(ctx, surface, char, SANS_BLACK_IT, size, red, 0.035, dy + 0.025, 4)
	stroke(ctx, drop, red, 2.4, 0)
	local main = text(ctx, surface, char, SANS_BLACK_IT, size, WHITE, 0, dy, 5)
	stroke(ctx, main, Color3.fromRGB(10, 10, 12), 2.4, 0)
end

-- STAINED GLASS: a cathedral window lit from behind, the number set in the glass in lead
TEXT.StainedGlass = true
function R.StainedGlass(ctx, surface, char, color)
	backing(surface, Color3.fromRGB(10, 6, 10))
	local seed = string.byte(char) or 48
	local rnd = Random.new(seed * 577)
	local stone = Color3.fromRGB(70, 60, 66)
	local lead = Color3.fromRGB(14, 9, 12)
	local L, R2, TOP, BOT = 30, 162, 84, 274 -- the window: an arch on a rectangle
	local cx, rr = W / 2, (R2 - L) / 2
	local halo = frame(surface, cx, H / 2, 184, 280, mul(Color3.fromRGB(255, 190, 120), ctx.k), 1, true)
	halo.BackgroundTransparency = 0.9; halo:SetAttribute("Mode", "breath"); halo:AddTag("NumFX_Pulse")
	frame(surface, cx, TOP, (rr + 8) * 2, (rr + 8) * 2, stone, 2, true)
	frame(surface, cx, (TOP + BOT) / 2 + 4, (rr + 8) * 2, BOT - TOP + 8, stone, 2)
	frame(surface, cx, TOP, rr * 2, rr * 2, lead, 3, true)
	frame(surface, cx, (TOP + BOT) / 2, rr * 2, BOT - TOP, lead, 3)
	local glass = {
		Color3.fromRGB(196, 24, 46), Color3.fromRGB(34, 78, 200), Color3.fromRGB(232, 162, 36),
		Color3.fromRGB(40, 150, 92), Color3.fromRGB(120, 46, 170), Color3.fromRGB(26, 140, 190),
	}
	-- dim: the panes behind the number are deep, darker glass so the pale number stands out against them
	local function pane(x, y, w, h, i, round, dim)
		local c = glass[(i + seed) % #glass + 1]
		if dim then c = c:Lerp(Color3.fromRGB(8, 6, 18), 0.55) end
		c = mul(c, ctx.k)
		local p = frame(surface, x, y, w, h, WHITE, 4, round)
		gradient(p, ColorSequence.new(c:Lerp(WHITE, dim and 0.12 or 0.35), c), 90)
	end
	pane(cx, TOP, rr * 2 - 8, rr * 2 - 8, 2, true)
	for k = 0, 5 do
		local a = math.rad(180 + k * 36)
		tube(surface, Vector2.new(cx, TOP), Vector2.new(cx + math.cos(a) * rr, TOP + math.sin(a) * rr), 4, lead, 5)
	end
	frame(surface, cx, TOP, 26, 26, lead, 5, true)
	local hub = frame(surface, cx, TOP, 18, 18, WHITE, 6, true)
	gradient(hub, ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(240, 170, 40)), 90)
	local cols, rows = 3, 4
	local pw, ph = (rr * 2 - 4) / cols, (BOT - TOP - 4) / rows
	for r = 0, rows - 1 do for c = 0, cols - 1 do
		pane(L + 2 + pw * (c + 0.5), TOP + 2 + ph * (r + 0.5), pw - 5, ph - 5, r * 2 + c + rnd:NextInteger(0, 5), false, true)
	end end
	-- the number: bright pale-gold glass, ringed in a thick band of lead so it separates cleanly from the panes
	local size, dy = 0.9, 0.08
	local ring = text(ctx, surface, char, SERIF, size, lead, 0, dy, 7)
	stroke(ctx, ring, lead, 7, 0)
	local main = text(ctx, surface, char, SERIF, size, WHITE, 0, dy, 8)
	gradient(main, ColorSequence.new(Color3.fromRGB(255, 255, 248), Color3.fromRGB(255, 226, 160)), 90)
	stroke(ctx, main, Color3.fromRGB(120, 84, 30), 0.8, 0)
	shine(ctx, surface, char, SERIF, size, 0, dy, 9, 5.2, 0.35)
end

-- ------------------------------------------------------------------ API
function S.Get(styleId) return S.ById[styleId or ""] or S.ById[S.Default] end
function S.Color(styleId) return rgb(S.Get(styleId).Color) end
function S.IsText(styleId) return TEXT[S.Get(styleId).Id] == true end
-- the SurfaceGui canvas a style draws on (text styles use a small canvas so their numerals fill the cell)
function S.Canvas(styleId) return TEXT[S.Get(styleId).Id] and TEXT_CANVAS or Vector2.new(W, H) end
-- Draw one character into `surface`: a visor SurfaceGui (its CanvasSize is set here), or any 2:3 GuiObject
-- (pass its pixel height as px). brightness: the SurfaceGui's Brightness; glows are scaled by it so they don't blow out.
-- (trial) the faces without their "__" mouth: 0__0 / -__- / X__X show just the eyes, the middle cells left unlit.
-- Set true to bring the mouth back (LEDFont has the same switch for the plain dot font).
S.FACE_MOUTH = false
function S.Draw(surface, char, styleId, brightness, px)
	if char == "_" and not S.FACE_MOUTH then char = " " end
	surface:ClearAllChildren()
	local style = S.Get(styleId)
	if surface:IsA("SurfaceGui") then
		surface.CanvasSize = TEXT[style.Id] and TEXT_CANVAS or Vector2.new(W, H)
		px = surface.CanvasSize.Y
	end
	local ctx = {px = px or H, k = 1 / math.max(brightness or 1, 1)}
	local ok, err = pcall(R[style.Id] or R.DotMatrix, ctx, surface, char, rgb(style.Color))
	if not ok then
		warn("[NumberStyles] " .. style.Id .. ": " .. tostring(err))
		surface:ClearAllChildren()
		if surface:IsA("SurfaceGui") then surface.CanvasSize = Vector2.new(W, H) end
		R.DotMatrix(ctx, surface, char, rgb(S.ById[S.Default].Color))
	end
end
-- Draw into a 2D frame `px` tall (any shape: a squashed frame reads as the cell turning away). Text styles draw
-- small and are scaled up, since TextSize stops at 100.
function S.DrawScaled(frame, char, styleId, px)
	frame:ClearAllChildren()
	local dh = TEXT[S.Get(styleId).Id] and math.min(px, 76) or px
	if dh >= px - 0.5 then S.Draw(frame, char, styleId, 1, px) return end
	local inner = Instance.new("Frame")
	inner.Name = "Scaled"; inner.BackgroundTransparency = 1; inner.Size = UDim2.fromScale(dh / px, dh / px); inner.ZIndex = frame.ZIndex
	inner.Parent = frame
	S.Draw(inner, char, styleId, 1, dh)
	local us = Instance.new("UIScale"); us.Scale = px / dh; us.Parent = inner
end
-- 2D card art: `code` across a strip of visor cells, fitted into rect (shop / loadout cards)
function S.Card(container, styleId, rect, code, z)
	code = code or "4729"
	local holder = Instance.new("Frame")
	holder.Name = "NumberArt"; holder.BackgroundTransparency = 1
	holder.Position = rect.Position; holder.Size = rect.Size; holder.ZIndex = z or ((container.ZIndex or 1) + 2)
	local rw, rh = rect.Size.X.Offset, rect.Size.Y.Offset
	local n = #code
	local step = 0.84 -- neighbouring cells overlap their dark side margins
	local ch = math.min(rh, rw / ((W / H) * (step * (n - 1) + 1)))
	local cw = ch * W / H
	local total = cw * (step * (n - 1) + 1)
	local screen = Instance.new("Frame")
	screen.BorderSizePixel = 0; screen.BackgroundColor3 = Color3.fromRGB(10, 6, 7); screen.ZIndex = holder.ZIndex
	screen.AnchorPoint = Vector2.new(0.5, 0.5); screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.fromOffset(total * 0.92, ch)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = screen
	screen.Parent = holder
	-- text styles: draw small and scale up (TextSize stops at 100; UIScale is fine on screen GUIs)
	local dh = TEXT[S.Get(styleId).Id] and math.min(ch, 76) or ch
	for i = 1, n do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1; cell.Size = UDim2.fromOffset(dh * W / H, dh)
		cell.Position = UDim2.fromOffset((rw - total) / 2 + (i - 1) * cw * step, (rh - ch) / 2)
		cell.ZIndex = holder.ZIndex + 1
		cell.Parent = holder
		S.Draw(cell, string.sub(code, i, i), styleId, 1, dh)
		if dh < ch then local us = Instance.new("UIScale"); us.Scale = ch / dh; us.Parent = cell end
		for _, d in ipairs(cell:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += holder.ZIndex + 1 end end
	end
	holder.Parent = container
	return holder
end
-- ---- styled number labels (HUD, intro lock-on, banners, results...)
-- Skin(label, styleId [, text]): draws the label's characters in a number style laid over the label. The label's own
-- text is hidden (not cleared), so the code that writes .Text keeps working: call Skin again after changing it.
-- Only redraws when the text, style or size changed. Unskin(label) puts the plain text back.
local function scaleOf(o)
	local k = 1
	while o and not o:IsA("LayerCollector") do
		local us = o:FindFirstChildOfClass("UIScale"); if us then k *= us.Scale end
		o = o.Parent
	end
	return k
end
local function hideText(label)
	if label:GetAttribute("SkinT") == nil then label:SetAttribute("SkinT", label.TextTransparency) end
	label.TextTransparency = 1
	for _, st in ipairs(label:GetChildren()) do
		if st:IsA("UIStroke") and st.Enabled then st:SetAttribute("SkinOff", true); st.Enabled = false end
	end
end
function S.Unskin(label)
	local h = label:FindFirstChild("NumberSkin"); if h then h:Destroy() end
	local t = label:GetAttribute("SkinT")
	if t ~= nil then label.TextTransparency = t; label:SetAttribute("SkinT", nil) end
	for _, st in ipairs(label:GetChildren()) do
		if st:IsA("UIStroke") and st:GetAttribute("SkinOff") then st.Enabled = true; st:SetAttribute("SkinOff", nil) end
	end
end
-- opts: {fill = 0..1 share of the label's height the digits use (default .92), step = cell spacing (default .86),
--        align = "center" | "left" | "right"}
function S.Skin(label, styleId, text, opts)
	text = tostring(text or label.Text or "")
	opts = opts or {}
	local style = S.Get(styleId)
	local k = scaleOf(label)
	local size = label.AbsoluteSize / math.max(k, 1e-3)
	if size.Y < 1 then size = Vector2.new(label.Size.X.Offset, label.Size.Y.Offset) end
	local n = math.max(#text, 1)
	local step = opts.step or 0.86
	local fill = opts.fill or 0.92
	local ch = math.min(size.Y * fill, size.X / ((W / H) * (step * (n - 1) + 1)))
	local key = style.Id .. "|" .. text .. "|" .. math.floor(ch) .. "|" .. math.floor(size.X)
	local holder = label:FindFirstChild("NumberSkin")
	hideText(label)
	if holder and holder:GetAttribute("Key") == key then return holder end
	if holder then holder:Destroy() end
	holder = Instance.new("Frame")
	holder.Name = "NumberSkin"; holder.BackgroundTransparency = 1; holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = label.ZIndex; holder.Active = false
	holder:SetAttribute("Key", key)
	if ch >= 2 and size.X >= 1 then
		local cw = ch * W / H
		local total = cw * (step * (n - 1) + 1)
		local x0 = opts.align == "left" and 0 or opts.align == "right" and (size.X - total) or (size.X - total) / 2
		for i = 1, #text do
			local c = string.sub(text, i, i)
			if c ~= " " then
				local cell = Instance.new("Frame")
				cell.Name = "Cell" .. i; cell.BackgroundTransparency = 1; cell.ZIndex = label.ZIndex
				cell.Position = UDim2.fromScale((x0 + (i - 1) * cw * step) / size.X, (size.Y - ch) / 2 / size.Y)
				cell.Size = UDim2.fromScale(cw / size.X, ch / size.Y)
				cell.Parent = holder
				S.DrawScaled(cell, c, style.Id, ch)
				for _, d in ipairs(cell:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += label.ZIndex end end
			end
		end
	end
	holder.Parent = label
	return holder
end
-- a player's number style (players without one / unknown: the default)
function S.Of(player)
	return player and player:GetAttribute("NumberStyle") or S.Default
end
return S
