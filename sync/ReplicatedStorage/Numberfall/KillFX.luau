-- ELIMINATION EFFECTS (Shop > Elimination FX): what everyone sees where a player is eliminated, chosen by the
-- player who wrote the number (their KillEffect attribute, Numberfall.Extras). Client only.
--   KillFX.Play(id, parent, origin, opts) -> seconds until it's done
--     parent: a Folder in workspace (the real thing) or a Folder in a WorldModel inside a ViewportFrame (Shop / Loadout
--             preview)
--     opts.preview = true: no particles, lights or physics (they don't work inside a ViewportFrame); shards move by
--                    script instead of physics
--     opts.floor   = Y of the ground (default origin.Y - 2.8)
--     opts.random  = a Random
local Tween = game:GetService("TweenService")
local Run = game:GetService("RunService")
local KillFX = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function ti(t, style, dir) return TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out) end
local function tween(o, info, goal) local tw = Tween:Create(o, info, goal); tw:Play(); return tw end
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- ---------------------------------------------------------------- building blocks
local function part(ctx, size, cf, color, props)
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if props then for k, v in pairs(props) do p[k] = v end end
	p.Parent = ctx.parent
	return p
end
local function ball(ctx, d, pos, color, props)
	local p = part(ctx, Vector3.one * d, CFrame.new(pos), color, props)
	p.Shape = Enum.PartType.Ball
	return p
end
-- flat ring on the ground (a thin cylinder lying down)
local function disc(ctx, d, pos, color, props)
	local p = part(ctx, Vector3.new(0.12, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function light(ctx, pos, color, brightness, range, t)
	if ctx.preview then return end
	local a = part(ctx, Vector3.one * 0.2, CFrame.new(pos), color, {Transparency = 1})
	local l = Instance.new("PointLight"); l.Color = color; l.Brightness = brightness; l.Range = range; l.Parent = a
	tween(l, ti(t or 0.6), {Brightness = 0, Range = range * 0.3})
end
local function emitter(ctx, pos, props, count)
	if ctx.preview then return end
	local a = part(ctx, Vector3.one * 0.2, CFrame.new(pos), Color3.new(), {Transparency = 1})
	local att = Instance.new("Attachment"); att.Parent = a
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0; e.LightInfluence = 0
	for k, v in pairs(props) do e[k] = v end
	e.Parent = att
	e:Emit(count)
	return e
end
local function ns(a, b) return NumberSequence.new(a, b) end
-- per-frame animation for the length of an effect: fn(t) gets seconds since start, return false to stop early
local function animate(ctx, duration, fn)
	local t0 = os.clock()
	local conn
	conn = Run.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > duration or not ctx.parent.Parent or fn(t) == false then conn:Disconnect() end
	end)
end
-- things flying out from the centre: physics in the world, scripted arcs in a preview
local function fling(ctx, p, velocity, spin, life)
	if not ctx.preview then
		p.Anchored = false; p.CanCollide = true; p.CollisionGroup = "NumberfallBodies"
		p.AssemblyLinearVelocity = velocity; p.AssemblyAngularVelocity = spin
		task.delay(life, function() if p.Parent then tween(p, ti(0.5), {Transparency = 1, Size = p.Size * 0.3}) end end)
		return
	end
	local start = p.CFrame; local g = Vector3.new(0, -60, 0)
	animate(ctx, life + 0.5, function(t)
		local floorY = ctx.floor + p.Size.Y / 2
		local pos = start.Position + velocity * t + g * (t * t / 2)
		if pos.Y < floorY then pos = Vector3.new(pos.X, floorY, pos.Z) end
		p.CFrame = CFrame.new(pos) * start.Rotation * CFrame.Angles(spin.X * t * 0.1, spin.Y * t * 0.1, spin.Z * t * 0.1)
		if t > life then p.Transparency = math.min(1, (t - life) / 0.5) end
	end)
end
local function shockwave(ctx, color, d, t, y)
	local r = disc(ctx, 2, Vector3.new(ctx.origin.X, y or ctx.floor + 0.08, ctx.origin.Z), color, {Transparency = 0.15})
	tween(r, ti(t or 0.55, Enum.EasingStyle.Quart), {Size = Vector3.new(0.05, d or 30, d or 30), Transparency = 1})
	return r
end
local function flash(ctx, color, d)
	local core = ball(ctx, 1, ctx.origin, color, {Transparency = 0.1})
	tween(core, ti(0.3), {Size = Vector3.one * (d or 9), Transparency = 1})
end

-- ---------------------------------------------------------------- the effects
local FX = {}

-- the original: red flash, light pillar, ground shockwave, glass shards, embers and smoke
FX.FxShatter = function(ctx)
	local o, r, RED = ctx.origin, ctx.random, rgb(255, 34, 58)
	light(ctx, o, RED, 9, 26)
	flash(ctx, rgb(255, 220, 220))
	local pillar = part(ctx, Vector3.new(60, 1.6, 1.6), CFrame.new(o + Vector3.new(0, 28, 0)) * CFrame.Angles(0, 0, math.pi / 2), RED, {Shape = Enum.PartType.Cylinder, Transparency = 0.2})
	tween(pillar, ti(0.7, Enum.EasingStyle.Quint), {Size = Vector3.new(60, 0.05, 0.05), Transparency = 1})
	shockwave(ctx, RED, 30)
	local ring2 = part(ctx, Vector3.new(0.1, 1, 1), CFrame.new(o) * CFrame.Angles(r:NextNumber(-0.5, 0.5), 0, math.pi / 2 + r:NextNumber(-0.4, 0.4)), rgb(255, 200, 200), {Shape = Enum.PartType.Cylinder, Transparency = 0.3})
	tween(ring2, ti(0.45), {Size = Vector3.new(0.05, 16, 16), Transparency = 1})
	for i = 1, 14 do
		local glass = i % 3 == 0
		local s = Instance.new("WedgePart")
		s.Size = Vector3.new(0.08, r:NextNumber(0.3, 0.8), r:NextNumber(0.25, 0.6))
		s.CFrame = CFrame.new(o + Vector3.new(r:NextNumber(-0.6, 0.6), r:NextNumber(0.4, 1.6), r:NextNumber(-0.6, 0.6))) * CFrame.Angles(r:NextNumber(0, 6), r:NextNumber(0, 6), r:NextNumber(0, 6))
		s.Material = glass and Enum.Material.Glass or Enum.Material.Neon
		s.Color = glass and rgb(255, 230, 230) or RED; s.Transparency = glass and 0.3 or 0
		s.Anchored, s.CanCollide, s.CanTouch, s.CanQuery, s.CastShadow = true, false, false, false, false
		s.Parent = ctx.parent
		fling(ctx, s, Vector3.new(r:NextNumber(-1, 1), r:NextNumber(0.4, 1.3), r:NextNumber(-1, 1)).Unit * r:NextNumber(18, 34),
			Vector3.new(r:NextNumber(-20, 20), r:NextNumber(-20, 20), r:NextNumber(-20, 20)), 1.2)
	end
	emitter(ctx, o, {Texture = SPARK, Color = ColorSequence.new(rgb(255, 210, 160), RED), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0)}), Transparency = ns(0, 1),
		Lifetime = NumberRange.new(0.5, 1.2), Speed = NumberRange.new(10, 26), Drag = 3, SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -12, 0)}, 46)
	emitter(ctx, o, {Texture = SMOKE, Color = ColorSequence.new(rgb(40, 12, 16), rgb(20, 18, 22)), LightInfluence = 0.4,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)}),
		Lifetime = NumberRange.new(0.9, 1.6), Speed = NumberRange.new(3, 8), Drag = 2, SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360)}, 12)
	return 2.2
end

-- black ink: a splash, blobs arcing out and landing as puddles
FX.FxInk = function(ctx)
	local o, r = ctx.origin, ctx.random
	local INK, SHEEN = rgb(5, 4, 9), rgb(70, 60, 110)
	local blob = ball(ctx, 1.4, o, INK, {Material = Enum.Material.SmoothPlastic, Reflectance = 0.04})
	tween(blob, ti(0.18), {Size = Vector3.one * 5}).Completed:Connect(function()
		tween(blob, ti(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.one * 0.2, Transparency = 1})
	end)
	shockwave(ctx, SHEEN, 18, 0.5)
	for i = 1, 12 do
		local d = r:NextNumber(0.35, 0.8)
		local drop = ball(ctx, d, o + Vector3.new(0, r:NextNumber(0, 1), 0), INK, {Material = Enum.Material.SmoothPlastic, Reflectance = 0.04})
		local dir = Vector3.new(r:NextNumber(-1, 1), 0, r:NextNumber(-1, 1)).Unit
		local v = dir * r:NextNumber(8, 16) + Vector3.new(0, r:NextNumber(10, 18), 0)
		local start = drop.Position
		local landed = false
		animate(ctx, 2.6, function(t)
			if landed then return end
			local pos = start + v * t + Vector3.new(0, -50, 0) * (t * t / 2)
			if pos.Y <= ctx.floor + 0.05 and t > 0.1 then
				landed = true
				local puddle = disc(ctx, d * 2.4, Vector3.new(pos.X, ctx.floor + 0.04 + i * 0.002, pos.Z), INK, {Material = Enum.Material.SmoothPlastic, Reflectance = 0.04})
				puddle.Size = Vector3.new(0.06, d, d)
				tween(puddle, ti(0.15), {Size = Vector3.new(0.06, d * 2.6, d * 2.6)})
				task.delay(1.6, function() if puddle.Parent then tween(puddle, ti(0.6), {Transparency = 1}) end end)
				drop:Destroy()
				return
			end
			drop.Position = pos
		end)
	end
	local splat = disc(ctx, 1, Vector3.new(o.X, ctx.floor + 0.03, o.Z), INK, {Material = Enum.Material.SmoothPlastic, Reflectance = 0.04})
	tween(splat, ti(0.3, Enum.EasingStyle.Back), {Size = Vector3.new(0.06, 6, 6)})
	task.delay(1.8, function() if splat.Parent then tween(splat, ti(0.6), {Transparency = 1}) end end)
	emitter(ctx, o, {Texture = SMOKE, Color = ColorSequence.new(INK), LightInfluence = 0.2,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4)}), Transparency = ns(0.3, 1),
		Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(4, 9), Drag = 3, SpreadAngle = Vector2.new(180, 180)}, 14)
	return 2.6
end

-- cherry blossom: a burst of petals that flutter down and drift off
FX.FxSakura = function(ctx)
	local o, r = ctx.origin, ctx.random
	local PINK, PALE = rgb(255, 150, 190), rgb(255, 214, 228)
	light(ctx, o, PINK, 5, 20)
	flash(ctx, PALE, 6)
	shockwave(ctx, PINK, 20, 0.6)
	local wind = Vector3.new(r:NextNumber(-1, 1), 0, r:NextNumber(-1, 1)).Unit * 3
	for i = 1, (ctx.preview and 34 or 46) do
		local petal = part(ctx, Vector3.new(0.32, 0.04, 0.24), CFrame.new(o), i % 3 == 0 and PALE or PINK, {Material = Enum.Material.SmoothPlastic})
		local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = petal
		local dir = Vector3.new(r:NextNumber(-1, 1), r:NextNumber(0.2, 1.4), r:NextNumber(-1, 1)).Unit * r:NextNumber(6, 13)
		local phase, spin = r:NextNumber(0, 6.28), r:NextNumber(2, 5)
		local life = r:NextNumber(2, 2.8)
		animate(ctx, life, function(t)
			local burst = dir * (1 - math.exp(-4 * t))
			local fall = Vector3.new(0, -1.6 * math.max(0, t - 0.25), 0)
			local sway = Vector3.new(math.sin(t * spin + phase) * 0.8, 0, math.cos(t * spin * 0.8 + phase) * 0.8)
			local pos = o + burst + fall + sway + wind * t
			if pos.Y < ctx.floor + 0.05 then pos = Vector3.new(pos.X, ctx.floor + 0.05, pos.Z) end
			petal.CFrame = CFrame.new(pos) * CFrame.Angles(t * spin + phase, t * 2, math.sin(t * spin) * 0.8)
			if t > life - 0.6 then petal.Transparency = (t - (life - 0.6)) / 0.6 end
		end)
	end
	return 2.8
end

-- frost: ice spikes burst out of the ground, hold, then shatter into frozen bits and mist
FX.FxFrost = function(ctx)
	local o, r = ctx.origin, ctx.random
	local ICE, DEEP = rgb(180, 230, 255), rgb(90, 170, 240)
	light(ctx, o, ICE, 6, 22)
	flash(ctx, rgb(230, 248, 255), 7)
	shockwave(ctx, ICE, 22, 0.6)
	local spikes = {}
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 2 + r:NextNumber(-0.2, 0.2)
		local dist = r:NextNumber(0.6, 2.4)
		local base = Vector3.new(o.X + math.cos(a) * dist, ctx.floor, o.Z + math.sin(a) * dist)
		local len = r:NextNumber(2.4, 4.6)
		local tilt = CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(r:NextNumber(15, 40)))
		local s = Instance.new("WedgePart")
		s.Anchored, s.CanCollide, s.CanTouch, s.CanQuery, s.CastShadow = true, false, false, false, false
		s.Material = Enum.Material.Glass; s.Transparency = 0.15; s.Color = i % 2 == 0 and ICE or DEEP
		s.Size = Vector3.new(0.5, 0.05, 0.5)
		local cf = CFrame.new(base) * tilt
		s.CFrame = cf
		s.Parent = ctx.parent
		tween(s, ti(0.18, Enum.EasingStyle.Back), {Size = Vector3.new(0.6, len, 0.6), CFrame = cf * CFrame.new(0, len / 2, 0)})
		table.insert(spikes, s)
	end
	task.delay(0.9, function()
		if not ctx.parent.Parent then return end
		for _, s in ipairs(spikes) do
			if s.Parent then
				for k = 1, 3 do
					local bit = part(ctx, Vector3.one * r:NextNumber(0.15, 0.35), s.CFrame * CFrame.new(0, r:NextNumber(-1, 1), 0), s.Color, {Material = Enum.Material.Glass, Transparency = 0.2})
					fling(ctx, bit, Vector3.new(r:NextNumber(-1, 1), r:NextNumber(0.3, 1), r:NextNumber(-1, 1)).Unit * r:NextNumber(8, 16), Vector3.new(r:NextNumber(-10, 10), r:NextNumber(-10, 10), 0), 0.9)
				end
				tween(s, ti(0.25), {Transparency = 1})
			end
		end
		emitter(ctx, o, {Texture = SMOKE, Color = ColorSequence.new(rgb(220, 240, 255)), LightEmission = 0.3,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6)}), Transparency = ns(0.5, 1),
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 6), Drag = 2, SpreadAngle = Vector2.new(180, 180)}, 14)
	end)
	emitter(ctx, o, {Texture = SPARK, Color = ColorSequence.new(rgb(240, 250, 255), ICE), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)}), Transparency = ns(0, 1),
		Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(6, 16), Drag = 2, SpreadAngle = Vector2.new(180, 180)}, 30)
	return 2.4
end

-- void: a violet singularity grows, drags everything in, then snaps shut with a flash
FX.FxVoid = function(ctx)
	local o, r = ctx.origin, ctx.random
	local VIOLET, BLACK = rgb(150, 70, 255), rgb(6, 2, 12)
	light(ctx, o, VIOLET, 7, 24, 1.2)
	local core = ball(ctx, 0.3, o, BLACK, {Material = Enum.Material.SmoothPlastic})
	local halo = ball(ctx, 0.5, o, VIOLET, {Transparency = 0.55})
	tween(core, ti(0.35, Enum.EasingStyle.Back), {Size = Vector3.one * 4})
	tween(halo, ti(0.35, Enum.EasingStyle.Back), {Size = Vector3.one * 5.2})
	local rings = {}
	for i = 1, 2 do
		local ring = part(ctx, Vector3.new(0.08, 7, 7), CFrame.new(o), VIOLET, {Shape = Enum.PartType.Cylinder, Transparency = 0.3})
		rings[i] = ring
	end
	for i = 1, 22 do
		local start = o + Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-0.6, 1), r:NextNumber(-1, 1)).Unit * r:NextNumber(5, 9)
		local bit = part(ctx, Vector3.one * r:NextNumber(0.12, 0.3), CFrame.new(start), i % 2 == 0 and VIOLET or rgb(230, 210, 255))
		local delay = r:NextNumber(0, 0.3)
		animate(ctx, 1.1, function(t)
			local k = math.clamp((t - delay) / 0.7, 0, 1)
			k = k * k
			bit.CFrame = CFrame.new(start:Lerp(o, k)) * CFrame.Angles(t * 6, t * 4, 0)
			bit.Transparency = k > 0.9 and 1 or 0
		end)
	end
	animate(ctx, 1.1, function(t)
		for i, ring in ipairs(rings) do
			ring.CFrame = CFrame.new(o) * CFrame.Angles(t * (i == 1 and 3 or -2.4), t * 2, math.pi / 2 + (i - 1) * 1.1)
			local s = math.max(0.1, 7 - t * 5)
			ring.Size = Vector3.new(0.08, s, s)
		end
	end)
	task.delay(0.85, function()
		if not ctx.parent.Parent then return end
		tween(core, ti(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = Vector3.one * 0.05})
		tween(halo, ti(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = Vector3.one * 0.05, Transparency = 1})
		for _, ring in ipairs(rings) do tween(ring, ti(0.15), {Transparency = 1}) end
		task.delay(0.18, function()
			if not ctx.parent.Parent then return end
			core.Transparency = 1
			flash(ctx, rgb(235, 220, 255), 8)
			shockwave(ctx, VIOLET, 24, 0.5, o.Y)
			light(ctx, o, rgb(235, 220, 255), 10, 26, 0.4)
		end)
	end)
	return 2
end

-- thunderstrike: a jagged bolt out of the sky, a second flicker, sparks and a scorch ring
FX.FxStorm = function(ctx)
	local o, r = ctx.origin, ctx.random
	local BOLT, CORE = rgb(120, 200, 255), rgb(240, 250, 255)
	local pieces = {}
	local function bolt(from, to, width, segs, color)
		local pts = {from}
		for i = 1, segs - 1 do
			local p = from:Lerp(to, i / segs) + Vector3.new(r:NextNumber(-1.6, 1.6), 0, r:NextNumber(-1.6, 1.6))
			pts[#pts + 1] = p
		end
		pts[#pts + 1] = to
		local made = {}
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local seg = part(ctx, Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color)
			made[#made + 1] = seg; pieces[#pieces + 1] = seg
		end
		return made, pts
	end
	local top = o + Vector3.new(r:NextNumber(-3, 3), 46, r:NextNumber(-3, 3))
	local ground = Vector3.new(o.X, ctx.floor, o.Z)
	local main, pts = bolt(top, ground, 0.45, 12, CORE)
	for _, p in ipairs(pts) do if r:NextNumber() < 0.35 and p.Y > ground.Y + 6 then
		bolt(p, p + Vector3.new(r:NextNumber(-6, 6), -r:NextNumber(4, 9), r:NextNumber(-6, 6)), 0.18, 4, BOLT)
	end end
	for _, seg in ipairs(main) do
		local g = part(ctx, seg.Size + Vector3.new(0.7, 0.7, 0), seg.CFrame, BOLT, {Transparency = 0.6})
		pieces[#pieces + 1] = g
	end
	light(ctx, o, CORE, 12, 40, 0.5)
	flash(ctx, CORE, 7)
	shockwave(ctx, BOLT, 26, 0.5)
	local scorch = disc(ctx, 5, Vector3.new(o.X, ctx.floor + 0.02, o.Z), rgb(20, 22, 30), {Material = Enum.Material.SmoothPlastic, Transparency = 0.1})
	task.delay(1.6, function() if scorch.Parent then tween(scorch, ti(0.6), {Transparency = 1}) end end)
	-- flicker then fade every bolt piece
	animate(ctx, 0.7, function(t)
		local on = t < 0.08 or (t > 0.16 and t < 0.26)
		for _, p in ipairs(pieces) do
			if p.Parent then p.LocalTransparencyModifier = on and 0 or math.min(1, 0.5 + (t - 0.26) / 0.3) end
		end
		if t > 0.65 then for _, p in ipairs(pieces) do if p.Parent then p.Transparency = 1 end end end
	end)
	emitter(ctx, ground + Vector3.new(0, 0.3, 0), {Texture = SPARK, Color = ColorSequence.new(CORE, BOLT), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)}), Transparency = ns(0, 1),
		Lifetime = NumberRange.new(0.3, 0.8), Speed = NumberRange.new(14, 30), Drag = 2, SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -40, 0), EmissionDirection = Enum.NormalId.Top}, 50)
	return 2.2
end

-- data corrupt: a cloud of flickering pixel blocks and scanline slabs that scatter and blink out
FX.FxGlitch = function(ctx)
	local o, r = ctx.origin, ctx.random
	local COLS = {rgb(60, 255, 230), rgb(255, 40, 200), rgb(240, 245, 255), rgb(40, 120, 255)}
	light(ctx, o, COLS[1], 6, 20)
	local blocks = {}
	for i = 1, (ctx.preview and 30 or 40) do
		local s = r:NextNumber(0.2, 0.7)
		local p = part(ctx, Vector3.one * s, CFrame.new(o + Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-1.8, 1.8), r:NextNumber(-0.7, 0.7))), COLS[r:NextInteger(1, #COLS)])
		blocks[#blocks + 1] = {p = p, v = Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-0.3, 0.6), r:NextNumber(-1, 1)) * r:NextNumber(2, 7), start = p.Position, seed = r:NextNumber(0, 10)}
	end
	for i = 1, 5 do
		local slab = part(ctx, Vector3.new(r:NextNumber(3, 6), 0.08, 0.08), CFrame.new(o + Vector3.new(0, r:NextNumber(-2, 2), r:NextNumber(-0.5, 0.5))), COLS[i % 2 + 1], {Transparency = 0.2})
		blocks[#blocks + 1] = {p = slab, v = Vector3.new(r:NextNumber(-4, 4), 0, 0), start = slab.Position, seed = r:NextNumber(0, 10), slab = true}
	end
	animate(ctx, 1.4, function(t)
		local step = math.floor(t * 20)
		for _, b in ipairs(blocks) do
			if b.p.Parent then
				local q = math.floor(t * 10) / 10
				local jitter = ((step * 7 + math.floor(b.seed * 10)) % 5 == 0) and Vector3.new(0.4, 0, 0) or Vector3.zero
				b.p.Position = b.start + b.v * q + jitter
				local on = (step + math.floor(b.seed * 3)) % (b.slab and 3 or 4) ~= 0
				b.p.Transparency = math.min(1, (on and 0 or 1) + (t > 1 and (t - 1) / 0.4 or 0))
			end
		end
	end)
	flash(ctx, COLS[3], 5)
	shockwave(ctx, COLS[2], 18, 0.4)
	return 1.6
end

-- inferno: a column of fire, rising flame tongues and a scorched ring
FX.FxInferno = function(ctx)
	local o, r = ctx.origin, ctx.random
	local ORANGE, YELLOW, RED = rgb(255, 120, 30), rgb(255, 214, 90), rgb(220, 40, 20)
	light(ctx, o, ORANGE, 10, 30, 1.4)
	flash(ctx, YELLOW, 7)
	shockwave(ctx, ORANGE, 24, 0.55)
	local scorch = disc(ctx, 1, Vector3.new(o.X, ctx.floor + 0.03, o.Z), rgb(24, 10, 8), {Material = Enum.Material.SmoothPlastic})
	tween(scorch, ti(0.3), {Size = Vector3.new(0.06, 6.5, 6.5)})
	task.delay(2, function() if scorch.Parent then tween(scorch, ti(0.6), {Transparency = 1}) end end)
	local ember = disc(ctx, 6.8, Vector3.new(o.X, ctx.floor + 0.02, o.Z), RED, {Transparency = 0.3})
	tween(ember, ti(2.2), {Transparency = 1})
	local function tongue(base, color, size, h, t, endSize, trans)
		local p = part(ctx, size, CFrame.new(base), color, {Transparency = trans})
		local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
		tween(p, ti(t, Enum.EasingStyle.Sine), {CFrame = CFrame.new(base + h), Size = endSize, Transparency = 1})
	end
	for i = 1, (ctx.preview and 16 or 22) do
		task.delay(i * 0.05, function()
			if not ctx.parent.Parent then return end
			local x, z = r:NextNumber(-1, 1), r:NextNumber(-1, 1)
			local base = Vector3.new(o.X + x, ctx.floor + 0.5, o.Z + z)
			local h = r:NextNumber(5, 9)
			tongue(base, i % 3 == 0 and RED or ORANGE, Vector3.new(1.2, 2.2, 1.2), Vector3.new(x * 0.6, h, z * 0.6), 0.7, Vector3.new(0.2, 3.4, 0.2), 0.15)
			tongue(base, YELLOW, Vector3.new(0.6, 1.4, 0.6), Vector3.new(0, h * 0.7, 0), 0.55, Vector3.new(0.1, 2, 0.1), 0.05)
		end)
	end
	emitter(ctx, o, {Texture = FIRE, Color = ColorSequence.new(YELLOW, RED), LightEmission = 0.8,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0.5)}), Transparency = ns(0.2, 1),
		Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 6, 0)}, 40)
	emitter(ctx, o, {Texture = SPARK, Color = ColorSequence.new(YELLOW, ORANGE), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)}), Transparency = ns(0, 1),
		Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 4, 0)}, 40)
	return 2.6
end

-- hellgate: a burning sigil opens under them, chains lash out of it and drag back down
FX.FxHellgate = function(ctx)
	local o, r = ctx.origin, ctx.random
	local RED, HOT, IRON = rgb(255, 40, 20), rgb(255, 170, 80), rgb(40, 36, 40)
	local fy = ctx.floor + 0.06
	light(ctx, Vector3.new(o.X, fy + 1, o.Z), RED, 9, 28, 2)
	local ring = disc(ctx, 0.5, Vector3.new(o.X, fy, o.Z), RED, {Transparency = 0.1})
	local inner = disc(ctx, 0.4, Vector3.new(o.X, fy + 0.01, o.Z), rgb(30, 4, 4), {Material = Enum.Material.SmoothPlastic})
	tween(ring, ti(0.35, Enum.EasingStyle.Back), {Size = Vector3.new(0.12, 8, 8)})
	tween(inner, ti(0.35, Enum.EasingStyle.Back), {Size = Vector3.new(0.12, 7.3, 7.3)})
	local bars = {}
	for i = 0, 4 do
		local bar = part(ctx, Vector3.new(6.6, 0.06, 0.18), CFrame.new(o.X, fy + 0.03, o.Z), RED, {Transparency = 1})
		bars[#bars + 1] = {p = bar, a = i * (math.pi * 2 / 5) * 2}
	end
	animate(ctx, 2.4, function(t)
		local spin = t * 0.9
		local fade = t > 1.9 and math.min(1, (t - 1.9) / 0.5) or 0
		for _, b in ipairs(bars) do
			b.p.CFrame = CFrame.new(o.X, fy + 0.03, o.Z) * CFrame.Angles(0, spin + b.a, 0) * CFrame.new(0, 0, 1.2)
			b.p.Transparency = t < 0.3 and 1 - t / 0.3 or fade
		end
		ring.Transparency = math.max(0.1, fade)
		inner.Transparency = fade
	end)
	for c = 1, 4 do
		local a = c / 4 * math.pi * 2 + r:NextNumber(-0.3, 0.3)
		local from = Vector3.new(o.X + math.cos(a) * 3, fy, o.Z + math.sin(a) * 3)
		local to = o + Vector3.new(math.cos(a) * 0.4, r:NextNumber(-0.8, 0.6), math.sin(a) * 0.4)
		local links = {}
		for k = 1, 8 do
			links[k] = part(ctx, Vector3.new(0.12, 0.42, 0.26), CFrame.new(from), k % 2 == 0 and IRON or rgb(70, 60, 64), {Material = Enum.Material.Metal, Transparency = 1})
		end
		animate(ctx, 2.2, function(t)
			local out = math.clamp((t - 0.25) / 0.25, 0, 1)
			local back = math.clamp((t - 1.3) / 0.5, 0, 1)
			local reach = out * (1 - back)
			for k, link in ipairs(links) do
				local f = (k / #links) * reach
				local pos = from:Lerp(to, f) + Vector3.new(0, math.sin(f * math.pi) * 1.2, 0)
				link.CFrame = CFrame.lookAt(pos, to) * CFrame.Angles(0, 0, k % 2 == 0 and math.pi / 2 or 0)
				link.Transparency = reach > 0.02 and 0 or 1
			end
		end)
	end
	emitter(ctx, Vector3.new(o.X, fy + 0.4, o.Z), {Texture = FIRE, Color = ColorSequence.new(HOT, RED), LightEmission = 0.9,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.3)}), Transparency = ns(0.2, 1),
		Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top}, 50)
	shockwave(ctx, RED, 18, 0.5, fy + 0.05)
	return 2.6
end

-- gilded: a fountain of gold coins and a golden shockwave
FX.FxGilded = function(ctx)
	local o, r = ctx.origin, ctx.random
	local GOLD, SHINE = rgb(255, 200, 90), rgb(255, 240, 190)
	light(ctx, o, GOLD, 8, 24)
	flash(ctx, SHINE, 7)
	shockwave(ctx, GOLD, 26, 0.55)
	for i = 1, (ctx.preview and 18 or 26) do
		local coin = part(ctx, Vector3.new(0.08, 0.5, 0.5), CFrame.new(o + Vector3.new(0, 0.5, 0)) * CFrame.Angles(r:NextNumber(0, 6), r:NextNumber(0, 6), 0),
			GOLD, {Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Reflectance = 0.25})
		fling(ctx, coin, Vector3.new(r:NextNumber(-1, 1), r:NextNumber(1.6, 2.6), r:NextNumber(-1, 1)).Unit * r:NextNumber(16, 26),
			Vector3.new(r:NextNumber(-25, 25), r:NextNumber(-25, 25), r:NextNumber(-25, 25)), 1.5)
	end
	emitter(ctx, o, {Texture = SPARK, Color = ColorSequence.new(SHINE, GOLD), LightEmission = 1,
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0)}), Transparency = ns(0, 1),
		Lifetime = NumberRange.new(0.6, 1.3), Speed = NumberRange.new(8, 20), Drag = 2, SpreadAngle = Vector2.new(180, 180)}, 40)
	return 2.4
end

-- ---------------------------------------------------------------- second layers
-- Extra layers on top of each effect: ground marks that linger, follow-up strikes, swirls and aftermath.
local MORE = {}
local function fadeLater(p, after, t, goal)
	task.delay(after, function() if p.Parent then tween(p, ti(t or 0.8), goal or {Transparency = 1}) end end)
end
-- thin lines radiating across the ground from the centre (cracks, scorch, frost veins)
local function groundLines(ctx, n, len, color, width, life, mat)
	local o, r = ctx.origin, ctx.random
	for i = 1, n do
		local a = i / n * math.pi * 2 + r:NextNumber(-0.25, 0.25)
		local l = len * r:NextNumber(0.6, 1)
		local mid = Vector3.new(o.X + math.cos(a) * l / 2, ctx.floor + 0.05, o.Z + math.sin(a) * l / 2)
		local crack = part(ctx, Vector3.new(0.1, 0.04, width), CFrame.new(mid) * CFrame.Angles(0, -a, 0), color, {Material = mat or Enum.Material.Neon})
		tween(crack, ti(0.18), {Size = Vector3.new(l, 0.04, width)})
		fadeLater(crack, life or 1.6, 0.9)
	end
end
MORE.FxShatter = function(ctx)
	groundLines(ctx, 9, 6, Color3.fromRGB(150, 10, 26), 0.1, 1.8)
	-- a second, slower ring and a red mist hanging over the spot
	task.delay(0.12, function() if ctx.parent.Parent then shockwave(ctx, Color3.fromRGB(255, 120, 130), 18, 0.8) end end)
end
MORE.FxInk = function(ctx)
	local o, r = ctx.origin, ctx.random
	-- ink tendrils whip up out of the splash and fall back
	for i = 1, 7 do
		local a = r:NextNumber(0, math.pi * 2)
		local base = Vector3.new(o.X + math.cos(a) * 0.6, ctx.floor, o.Z + math.sin(a) * 0.6)
		local h = r:NextNumber(2.5, 4.5)
		local tip = part(ctx, Vector3.new(0.18, 0.1, 0.18), CFrame.new(base), Color3.fromRGB(5, 4, 9), {Material = Enum.Material.SmoothPlastic})
		local lean = CFrame.Angles(math.cos(a) * 0.35, 0, -math.sin(a) * 0.35)
		tween(tip, ti(0.25, Enum.EasingStyle.Quad), {Size = Vector3.new(0.12, h, 0.12), CFrame = CFrame.new(base) * lean * CFrame.new(0, h / 2, 0)})
		task.delay(0.3 + i * 0.03, function() if tip.Parent then tween(tip, ti(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.new(0.05, 0.1, 0.05), CFrame = CFrame.new(base), Transparency = 1}) end end)
	end
	groundLines(ctx, 6, 4, Color3.fromRGB(5, 4, 9), 0.18, 2.2, Enum.Material.SmoothPlastic)
end
MORE.FxSakura = function(ctx)
	local o, r = ctx.origin, ctx.random
	-- a spiral of petals winds up around the body before the burst drifts off
	for i = 1, 22 do
		local petal = part(ctx, Vector3.new(0.3, 0.04, 0.22), CFrame.new(o), i % 2 == 0 and Color3.fromRGB(255, 214, 228) or Color3.fromRGB(255, 150, 190), {Material = Enum.Material.SmoothPlastic})
		local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = petal
		local a0, rad0 = i / 22 * math.pi * 2, r:NextNumber(1, 1.6)
		animate(ctx, 1.6, function(t)
			local a = a0 + t * 6
			local rr = rad0 + t * 1.2
			petal.CFrame = CFrame.new(o + Vector3.new(math.cos(a) * rr, -2 + t * 3.2, math.sin(a) * rr)) * CFrame.Angles(t * 5, a, t * 3)
			petal.Transparency = t > 1.2 and (t - 1.2) / 0.4 or 0
		end)
	end
	-- petals settle on the ground for a moment
	for i = 1, 12 do
		local p = part(ctx, Vector3.new(0.28, 0.03, 0.2), CFrame.new(o.X + r:NextNumber(-2.5, 2.5), ctx.floor + 0.04, o.Z + r:NextNumber(-2.5, 2.5)) * CFrame.Angles(0, r:NextNumber(0, 6), 0),
			Color3.fromRGB(255, 170, 200), {Material = Enum.Material.SmoothPlastic, Transparency = 1})
		local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
		task.delay(0.6 + i * 0.05, function() if p.Parent then tween(p, ti(0.3), {Transparency = 0}) end end)
		fadeLater(p, 2.2, 0.6)
	end
end
MORE.FxFrost = function(ctx)
	local o = ctx.origin
	local patch = disc(ctx, 1, Vector3.new(o.X, ctx.floor + 0.035, o.Z), Color3.fromRGB(220, 240, 255), {Material = Enum.Material.Ice, Transparency = 0.2})
	tween(patch, ti(0.35), {Size = Vector3.new(0.06, 7, 7)})
	fadeLater(patch, 2, 0.8)
	groundLines(ctx, 10, 5, Color3.fromRGB(200, 240, 255), 0.07, 2)
end
MORE.FxVoid = function(ctx)
	local o, r = ctx.origin, ctx.random
	-- space bends: thin rings collapse inward one after another
	for k = 1, 4 do
		task.delay(k * 0.12, function()
			if not ctx.parent.Parent then return end
			local ring = part(ctx, Vector3.new(0.05, 9, 9), CFrame.new(o) * CFrame.Angles(r:NextNumber(-1, 1), r:NextNumber(0, 6), math.pi / 2), Color3.fromRGB(200, 150, 255), {Shape = Enum.PartType.Cylinder, Transparency = 0.5})
			tween(ring, ti(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.new(0.05, 0.2, 0.2), Transparency = 0.9})
		end)
	end
	-- a dark scar left on the ground
	task.delay(1.05, function()
		if not ctx.parent.Parent then return end
		local scar = disc(ctx, 0.5, Vector3.new(o.X, ctx.floor + 0.03, o.Z), Color3.fromRGB(14, 4, 24), {Material = Enum.Material.SmoothPlastic})
		tween(scar, ti(0.2), {Size = Vector3.new(0.06, 4, 4)})
		fadeLater(scar, 1.4, 0.8)
		groundLines(ctx, 7, 4.5, Color3.fromRGB(150, 70, 255), 0.06, 1.4)
	end)
end
MORE.FxStorm = function(ctx)
	local o, r = ctx.origin, ctx.random
	-- two more strikes close by, and electric arcs crawling over the spot
	for k = 1, 2 do
		task.delay(0.18 * k, function()
			if not ctx.parent.Parent then return end
			local x, z = r:NextNumber(-3, 3), r:NextNumber(-3, 3)
			local from, to = Vector3.new(o.X + x, o.Y + 40, o.Z + z), Vector3.new(o.X + x * 0.6, ctx.floor, o.Z + z * 0.6)
			local prev = from
			for i = 1, 8 do
				local p = from:Lerp(to, i / 8) + (i < 8 and Vector3.new(r:NextNumber(-1.2, 1.2), 0, r:NextNumber(-1.2, 1.2)) or Vector3.zero)
				local seg = part(ctx, Vector3.new(0.22, 0.22, (p - prev).Magnitude), CFrame.lookAt((p + prev) / 2, p), Color3.fromRGB(200, 235, 255))
				tween(seg, ti(0.25), {Transparency = 1})
				prev = p
			end
		end)
	end
	animate(ctx, 0.9, function(t)
		if math.floor(t * 20) % 2 == 0 then
			local a = r:NextNumber(0, math.pi * 2)
			local s = o + Vector3.new(math.cos(a) * r:NextNumber(0.3, 1.2), r:NextNumber(-2, 1.5), math.sin(a) * r:NextNumber(0.3, 1.2))
			local e = s + Vector3.new(r:NextNumber(-0.8, 0.8), r:NextNumber(-0.8, 0.8), r:NextNumber(-0.8, 0.8))
			local arc = part(ctx, Vector3.new(0.06, 0.06, (e - s).Magnitude), CFrame.lookAt((s + e) / 2, e), Color3.fromRGB(150, 220, 255))
			tween(arc, ti(0.12), {Transparency = 1})
			game:GetService("Debris"):AddItem(arc, 0.2)
		end
	end)
	groundLines(ctx, 8, 5, Color3.fromRGB(120, 200, 255), 0.06, 1.2)
end
MORE.FxGlitch = function(ctx)
	local o = ctx.origin
	-- a wireframe box flickers around the body and collapses into a line
	local edges = {}
	local w, h = 2.6, 5.4
	for _, e in ipairs({{0, h / 2, w / 2, w, 0.06, 0.06}, {0, -h / 2, w / 2, w, 0.06, 0.06}, {0, h / 2, -w / 2, w, 0.06, 0.06}, {0, -h / 2, -w / 2, w, 0.06, 0.06},
		{w / 2, 0, w / 2, 0.06, h, 0.06}, {-w / 2, 0, w / 2, 0.06, h, 0.06}, {w / 2, 0, -w / 2, 0.06, h, 0.06}, {-w / 2, 0, -w / 2, 0.06, h, 0.06}}) do
		local p = part(ctx, Vector3.new(e[4], e[5], e[6]), CFrame.new(o + Vector3.new(e[1], e[2] - 0.4, e[3])), Color3.fromRGB(60, 255, 230))
		edges[#edges + 1] = p
	end
	animate(ctx, 1, function(t)
		local on = math.floor(t * 16) % 3 ~= 0
		for i, p in ipairs(edges) do
			p.Transparency = on and (t > 0.6 and (t - 0.6) / 0.4 or 0) or 1
			p.Color = (math.floor(t * 10 + i) % 2 == 0) and Color3.fromRGB(60, 255, 230) or Color3.fromRGB(255, 40, 200)
		end
	end)
end
MORE.FxInferno = function(ctx)
	local o, r = ctx.origin, ctx.random
	-- a ring of flame races outward across the ground
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local f = part(ctx, Vector3.new(0.5, 1.2, 0.5), CFrame.new(o.X, ctx.floor + 0.5, o.Z), i % 2 == 0 and Color3.fromRGB(255, 120, 30) or Color3.fromRGB(255, 214, 90), {Transparency = 0.15})
		local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = f
		local dist = r:NextNumber(3.5, 4.5)
		tween(f, ti(0.6, Enum.EasingStyle.Quad), {CFrame = CFrame.new(o.X + math.cos(a) * dist, ctx.floor + 0.8, o.Z + math.sin(a) * dist), Size = Vector3.new(0.2, 2, 0.2), Transparency = 1})
	end
	groundLines(ctx, 10, 4, Color3.fromRGB(40, 14, 8), 0.14, 2.2, Enum.Material.SmoothPlastic)
end
MORE.FxHellgate = function(ctx)
	local o, r = ctx.origin, ctx.random
	-- black spikes rise around the sigil's rim and sink back
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local base = Vector3.new(o.X + math.cos(a) * 4.2, ctx.floor, o.Z + math.sin(a) * 4.2)
		local spike = Instance.new("WedgePart")
		spike.Anchored, spike.CanCollide, spike.CanTouch, spike.CanQuery, spike.CastShadow = true, false, false, false, false
		spike.Material = Enum.Material.SmoothPlastic; spike.Color = Color3.fromRGB(20, 6, 8); spike.Size = Vector3.new(0.3, 0.1, 0.4)
		local cf = CFrame.new(base) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(-15), 0, 0)
		spike.CFrame = cf; spike.Parent = ctx.parent
		local h = r:NextNumber(1.6, 2.6)
		task.delay(0.25 + i * 0.02, function()
			if not spike.Parent then return end
			tween(spike, ti(0.2, Enum.EasingStyle.Back), {Size = Vector3.new(0.3, h, 0.4), CFrame = cf * CFrame.new(0, h / 2, 0)})
			task.delay(1.3, function() if spike.Parent then tween(spike, ti(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.new(0.3, 0.1, 0.4), CFrame = cf, Transparency = 1}) end end)
		end)
	end
end
MORE.FxGilded = function(ctx)
	local o = ctx.origin
	-- a golden halo spins above them and a pillar of light
	local halo = part(ctx, Vector3.new(0.12, 2.2, 2.2), CFrame.new(o + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 220, 120), {Shape = Enum.PartType.Cylinder, Transparency = 0.1})
	local inner = part(ctx, Vector3.new(0.13, 1.7, 1.7), halo.CFrame, Color3.fromRGB(40, 30, 10), {Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Transparency = 1})
	animate(ctx, 1.8, function(t)
		local cf = CFrame.new(o + Vector3.new(0, 3.4 + t * 0.6, 0)) * CFrame.Angles(0, t * 4, math.pi / 2)
		halo.CFrame = cf; inner.CFrame = cf
		halo.Transparency = t > 1.2 and 0.1 + (t - 1.2) / 0.6 * 0.9 or 0.1
	end)
	local pillar = part(ctx, Vector3.new(40, 2.4, 2.4), CFrame.new(o + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 230, 160), {Shape = Enum.PartType.Cylinder, Transparency = 0.5})
	tween(pillar, ti(0.9, Enum.EasingStyle.Quint), {Size = Vector3.new(40, 0.05, 0.05), Transparency = 1})
	groundLines(ctx, 12, 5, Color3.fromRGB(255, 200, 90), 0.08, 1.6)
end

-- ---------------------------------------------------------------- what happens to the body
-- Each effect also marks the eliminated body for a couple of seconds: a tinted outline plus its own particles on
-- the limbs (fire, frost mist, petals, sparks, ink...). Works on any character model (the kept corpse included).
local BODY = {
	FxShatter = {fill = rgb(255, 34, 58), edge = rgb(255, 200, 190), tex = SPARK, col = {rgb(255, 120, 60), rgb(255, 34, 58)}, up = 7},
	FxInk = {fill = rgb(6, 4, 10), edge = rgb(90, 80, 130), fillT = 0.05, tex = SMOKE, col = {rgb(10, 8, 14), rgb(30, 24, 40)}, up = -2, size = 0.6},
	FxSakura = {fill = rgb(255, 150, 190), edge = rgb(255, 230, 240), tex = SPARK, col = {rgb(255, 214, 228), rgb(255, 120, 170)}, up = 1, petals = true},
	FxFrost = {fill = rgb(150, 220, 255), edge = rgb(240, 250, 255), fillT = 0.25, tex = SMOKE, col = {rgb(230, 245, 255), rgb(160, 210, 240)}, up = 1.5, size = 0.7},
	FxVoid = {fill = rgb(40, 0, 70), edge = rgb(170, 90, 255), fillT = 0.1, tex = SPARK, col = {rgb(200, 150, 255), rgb(90, 30, 160)}, up = 12},
	FxStorm = {fill = rgb(120, 200, 255), edge = rgb(255, 255, 255), tex = SPARK, col = {rgb(255, 255, 255), rgb(120, 200, 255)}, up = 0, flicker = true, speed = 6},
	FxGlitch = {fill = rgb(60, 255, 230), edge = rgb(255, 40, 200), tex = SPARK, col = {rgb(60, 255, 230), rgb(255, 40, 200)}, up = 0, flicker = true, glitch = true},
	FxInferno = {fill = rgb(255, 110, 20), edge = rgb(255, 220, 120), tex = FIRE, col = {rgb(255, 214, 90), rgb(220, 40, 20)}, up = 9, size = 1.1},
	FxHellgate = {fill = rgb(160, 10, 10), edge = rgb(255, 120, 60), tex = FIRE, col = {rgb(255, 170, 80), rgb(160, 10, 10)}, up = -6, size = 1},
	FxGilded = {fill = rgb(255, 200, 90), edge = rgb(255, 245, 210), tex = SPARK, col = {rgb(255, 245, 210), rgb(255, 190, 60)}, up = 3},
}
function KillFX.Body(id, character, duration)
	local b = BODY[id or ""] or BODY.FxShatter
	duration = duration or 1.8
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = b.fill, b.edge
	h.FillTransparency, h.OutlineTransparency = b.fillT or 0.15, 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = character
	if b.flicker then
		-- electric / corrupted: the outline stutters and (glitch) swaps colours
		local t0 = os.clock()
		local conn
		conn = Run.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t > duration or not h.Parent then conn:Disconnect(); return end
			local on = math.floor(t * 18) % 3 ~= 0
			h.FillTransparency = on and (0.15 + t / duration * 0.85) or 1
			if b.glitch then h.FillColor = (math.floor(t * 12) % 2 == 0) and b.fill or b.edge end
		end)
	else
		tween(h, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {FillTransparency = 1, OutlineTransparency = 1})
	end
	game:GetService("Debris"):AddItem(h, duration + 0.2)
	local count = 0
	for _, limb in ipairs(character:GetChildren()) do
		if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" and limb.Transparency < 1 and count < 9 then
			count += 1
			local e = Instance.new("ParticleEmitter")
			e.Texture = b.petals and "rbxasset://textures/particles/sparkles_main.dds" or b.tex
			e.Color = ColorSequence.new(b.col[1], b.col[2])
			e.LightEmission = (b.tex == SMOKE) and 0.2 or 1; e.LightInfluence = 0
			local s = (b.size or 0.4)
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, s), NumberSequenceKeypoint.new(1, b.tex == SMOKE and s * 2.5 or 0)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, b.tex == SMOKE and 0.5 or 0.1), NumberSequenceKeypoint.new(1, 1)})
			e.Lifetime = NumberRange.new(0.5, 1.1); e.Rate = b.tex == FIRE and 22 or 26
			e.Speed = NumberRange.new(b.speed or 1, (b.speed or 1) + 2); e.Acceleration = Vector3.new(0, b.up or 5, 0)
			e.SpreadAngle = Vector2.new(180, 180); e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-90, 90)
			if b.petals then e.Drag = 1.5 end
			e.Parent = limb
			task.delay(duration * 0.85, function() if e.Parent then e.Enabled = false end end)
			game:GetService("Debris"):AddItem(e, duration + 1.5)
		end
	end
end

KillFX.Effects = FX
function KillFX.Has(id) return FX[id or ""] ~= nil end
function KillFX.Play(id, parent, origin, opts)
	opts = opts or {}
	local ctx = {parent = parent, origin = origin, preview = opts.preview == true, random = opts.random or Random.new(),
		floor = opts.floor or (origin.Y - 2.8)}
	local fn = FX[id or ""] or FX.FxShatter
	local ok, dur = pcall(fn, ctx)
	local more = MORE[id or ""] or (not FX[id or ""] and MORE.FxShatter)
	if ok and more then local ok2, err = pcall(more, ctx); if not ok2 then warn("[KillFX] " .. tostring(id) .. " (layer 2): " .. tostring(err)) end end
	if not ok then warn("[KillFX] " .. tostring(id) .. ": " .. tostring(dur)); return 0 end
	-- the second layer leaves marks on the ground for up to ~3s
	return math.max(dur or 2, more and 3.2 or 0)
end
return KillFX
