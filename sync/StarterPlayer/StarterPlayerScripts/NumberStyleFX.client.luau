-- Animates the number styles (Numberfall.NumberStyles tags the moving parts), on visors and in the menus.
-- Purely visual and local. Parts on a visor that isn't being drawn (screen facing away / too far) are skipped.
-- Off with Settings > Reduced motion.
--   NumberGlitch / NumberGlitchCh / NumberGlitchBlock  Glitch: torn slices, colour-channel jitter, corrupt blocks
--   NumFX_Flicker  dims for a tick or two now and then (attrs Rate, Low)
--   NumFX_Blink    hides for a moment now and then (attr Rate)          (neon buzz)
--   NumFX_Flame    height / lean wobble                                  (Hellfire)
--   NumFX_Rise     floats up and fades, then starts again (attr Speed)  (embers)
--   NumFX_Drip     runs down, then starts again (attr Period)          (Blood Scrawl)
--   NumFX_Fall     falls through the cell and wraps (attr Speed)       (Code Rain)
--   NumFX_Sweep    a band sliding down and wrapping (attr Speed)       (scan beam / tracking bar)
--   NumFX_Noise    jumps to a random spot                               (static)
--   NumFX_Pulse    beats (attr Mode "breath" for a slow swell)        (Heartbeat / Sigil glow)
--   NumFX_Trace    an EKG cover sliding off in time with the beat
--   NumFX_Arc      flashes on for a split second                        (Overcharge)
--   NumFX_Orbit    turns round an ellipse (attrs Angle, Rx, Ry, Speed) (Sigil runes)
--   NumFX_Petal    falls through the cell swaying and spinning, wraps (attrs Speed, Sway, Spin)  (Sakura blossoms)
--   NumFX_Shine    a glint (its UIGradient "Shine") sweeps across the glyph, then rests (attr Period)  (Chrome, Tarot...)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local player = game:GetService("Players").LocalPlayer
local rng = Random.new()
local STEP = 1 / 30

local TAGS = {"NumberGlitch", "NumberGlitchCh", "NumberGlitchBlock", "NumFX_Flicker", "NumFX_Blink", "NumFX_Flame", "NumFX_Rise",
	"NumFX_Drip", "NumFX_Fall", "NumFX_Sweep", "NumFX_Noise", "NumFX_Pulse", "NumFX_Trace", "NumFX_Arc", "NumFX_Orbit", "NumFX_Petal", "NumFX_Shine"}
local items = {} -- tag -> {[obj] = state}

local function transp(o)
	if o:IsA("TextLabel") then return o.TextTransparency end
	return o.BackgroundTransparency
end
local function setTransp(o, v)
	if o:IsA("TextLabel") then o.TextTransparency = v else o.BackgroundTransparency = v end
end

local function add(tag, o)
	if not o:IsA("GuiObject") then return end
	items[tag][o] = {
		sg = o:FindFirstAncestorWhichIsA("SurfaceGui"),
		pos = o.Position, size = o.Size, rot = o.Rotation, tr = transp(o),
		stroke = o:FindFirstChildOfClass("UIStroke"), strokeTr = o:FindFirstChildOfClass("UIStroke") and o:FindFirstChildOfClass("UIStroke").Transparency,
		phase = rng:NextNumber(0, 10), off = 0,
	}
end
for _, tag in ipairs(TAGS) do
	items[tag] = {} -- (not weak-keyed: Instance proxies can be collected while the Instance still exists)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(o) add(tag, o) end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(o) items[tag][o] = nil end)
	for _, o in ipairs(CollectionService:GetTagged(tag)) do add(tag, o) end
end

local function live(o, st)
	if st.sg then return st.sg.Enabled end
	return true
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < STEP then return end
	local step = acc
	acc = 0
	if player:GetAttribute("Setting_ReducedMotion") == true then return end
	local now = os.clock()

	-- GLITCH
	for clip, st in pairs(items.NumberGlitch) do
		if rng:NextNumber() < 0.15 and live(clip, st) then
			local inner = clip:FindFirstChild("Inner")
			if inner then
				local shift = rng:NextNumber() < 0.3 and 0 or rng:NextNumber(0.03, 0.13) * (rng:NextInteger(0, 1) == 0 and -1 or 1)
				inner.Position = UDim2.fromScale((-0.08 + shift) / 0.84, inner.Position.Y.Scale)
			end
			clip.Visible = rng:NextNumber() > 0.18
		end
	end
	for ch, st in pairs(items.NumberGlitchCh) do
		if rng:NextNumber() < 0.13 and live(ch, st) then
			local base = ch:GetAttribute("BaseX") or 0
			ch.Position = UDim2.fromScale(0.5 + base * rng:NextNumber(0.3, 2.4), st.pos.Y.Scale + rng:NextNumber(-0.02, 0.02))
		end
	end
	for b, st in pairs(items.NumberGlitchBlock) do
		if rng:NextNumber() < 0.1 and live(b, st) then
			b.Visible = rng:NextNumber() > 0.35
			b.Position = UDim2.fromScale(math.clamp(st.pos.X.Scale + rng:NextNumber(-0.08, 0.08), 0.18, 0.82), st.pos.Y.Scale)
		end
	end

	-- flicker / blink
	for o, st in pairs(items.NumFX_Flicker) do
		if live(o, st) then
			if now < st.off then
				setTransp(o, o:GetAttribute("Low") or 0.6)
			else
				setTransp(o, st.tr)
				if rng:NextNumber() < (o:GetAttribute("Rate") or 0.03) then st.off = now + rng:NextNumber(0.04, 0.12) end
			end
		end
	end
	for o, st in pairs(items.NumFX_Blink) do
		if live(o, st) then
			if now < st.off then o.Visible = false
			else
				o.Visible = true
				if rng:NextNumber() < (o:GetAttribute("Rate") or 0.01) then st.off = now + rng:NextNumber(0.05, 0.16) end
			end
		end
	end

	-- fire
	for o, st in pairs(items.NumFX_Flame) do
		if live(o, st) then
			local t = now * 7 + st.phase
			local k = 1 + 0.14 * math.sin(t) + 0.07 * math.sin(t * 2.7)
			o.Size = UDim2.new(st.size.X.Scale, st.size.X.Offset, st.size.Y.Scale * k, st.size.Y.Offset)
			o.Rotation = st.rot + 5 * math.sin(t * 0.8 + 1.3)
		end
	end
	for o, st in pairs(items.NumFX_Rise) do
		if live(o, st) then
			local sp = o:GetAttribute("Speed") or 0.3
			local p = o.Position
			local y = p.Y.Scale - sp * step
			local x = p.X.Scale + math.sin(now * 3 + st.phase) * 0.002
			if y < -0.04 then y = st.pos.Y.Scale + 0.35; x = st.pos.X.Scale end
			o.Position = UDim2.fromScale(x, y)
			o.BackgroundTransparency = math.clamp(0.2 + (st.pos.Y.Scale + 0.35 - y) * 1.6, 0.2, 1)
		end
	end

	-- blood
	for o, st in pairs(items.NumFX_Drip) do
		if live(o, st) then
			local period = o:GetAttribute("Period") or 3
			local k = ((now + st.phase) % period) / period
			k = k * k
			o.Size = UDim2.new(st.size.X.Scale, st.size.X.Offset, st.size.Y.Scale * (0.35 + 1.25 * k), st.size.Y.Offset)
		end
	end

	-- moving bands / rain / static
	for o, st in pairs(items.NumFX_Fall) do
		if live(o, st) then
			local y = o.Position.Y.Scale + (o:GetAttribute("Speed") or 0.5) * step
			if y > 1 then y = -1.3 end
			o.Position = UDim2.fromScale(o.Position.X.Scale, y)
		end
	end
	for o, st in pairs(items.NumFX_Sweep) do
		if live(o, st) then
			local y = o.Position.Y.Scale + (o:GetAttribute("Speed") or 0.4) * step
			if y > 1 then y = -o.Size.Y.Scale end
			o.Position = UDim2.fromScale(o.Position.X.Scale, y)
		end
	end
	for o, st in pairs(items.NumFX_Noise) do
		if rng:NextNumber() < 0.5 and live(o, st) then
			o.Position = UDim2.fromScale(rng:NextNumber(0, 1), rng:NextNumber(0, 1))
			o.BackgroundTransparency = rng:NextNumber(0.3, 0.9)
		end
	end

	-- heartbeat: lub-dub every 0.95 s (shared clock, so every visor beats together)
	local ph = now % 0.95
	local beat = math.exp(-(ph / 0.05) ^ 2) + 0.7 * math.exp(-((ph - 0.2) / 0.05) ^ 2)
	local breath = 0.5 + 0.5 * math.sin(now * 2.2)
	for o, st in pairs(items.NumFX_Pulse) do
		if live(o, st) then
			local i = o:GetAttribute("Mode") == "breath" and breath or math.min(beat, 1)
			setTransp(o, st.tr + (1 - st.tr) * (1 - i) * 0.85)
			if st.stroke then st.stroke.Transparency = st.strokeTr + (1 - st.strokeTr) * (1 - i) * 0.85 end
		end
	end
	for o, st in pairs(items.NumFX_Trace) do
		if live(o, st) then
			local k = math.clamp(ph / 0.7, 0, 1)
			o.Size = UDim2.new((o:GetAttribute("W") or st.size.X.Scale) * (1 - k), 0, st.size.Y.Scale, 0)
		end
	end

	-- electricity
	for o, st in pairs(items.NumFX_Arc) do
		if live(o, st) then o.Visible = rng:NextNumber() < 0.14 end
	end

	-- glints sweeping across a glyph: across in the first 35% of the period, then off the edge until the next one
	for o, st in pairs(items.NumFX_Shine) do
		if live(o, st) then
			local g = o:FindFirstChild("Shine")
			if g then
				local period = o:GetAttribute("Period") or 3.6
				local k = ((now + st.phase) % period) / period
				g.Offset = Vector2.new(math.min(k / 0.35, 1) * 2.4 - 1.2, 0)
			end
		end
	end

	-- drifting blossoms
	for o, st in pairs(items.NumFX_Petal) do
		if live(o, st) then
			local y = o.Position.Y.Scale + (o:GetAttribute("Speed") or 0.1) * step
			if y > 1.08 then y = -0.08 end
			local x = st.pos.X.Scale + math.sin(now * 1.4 + st.phase) * (o:GetAttribute("Sway") or 0.05)
			o.Position = UDim2.fromScale(x, y)
			o.Rotation = st.rot + (now + st.phase) * (o:GetAttribute("Spin") or 45)
		end
	end

	-- orbiting runes
	for o, st in pairs(items.NumFX_Orbit) do
		if live(o, st) then
			local a = (o:GetAttribute("Angle") or 0) + (o:GetAttribute("Speed") or 0.3) * now
			local rx, ry = o:GetAttribute("Rx") or 0.37, o:GetAttribute("Ry") or 0.4
			o.Position = UDim2.fromScale(0.5 + math.cos(a) * rx, 0.5 + math.sin(a) * ry)
			o.Rotation = math.deg(a) + 90
		end
	end
end)
