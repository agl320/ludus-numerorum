-- PETS (Shop > Pets): companions that follow their owner (StarterPlayerScripts.PetFollow) and stand next to your
-- character in the Shop / Loadout preview. Built from parts here, client side.
--   Pets.Build(id, owner, colorwayId) -> Model (PrimaryPart "Root", anchored) or nil for "No Pet"
--   Pets.Animate(model, t, speed)  wings / tail / legs / flames / rotors for time t and the owner's speed (studs/s)
--   Pets.Ground(id) -> true for pets that walk on the floor instead of flying
-- Every piece has a Role: "main" (body colour), "accent" (trim / belly / blade), "glow" (eyes, flames, lights) or
-- "fixed" (never recoloured). A pet colourway (Numberfall.Extras.PetColorways) recolours main / accent / glow.
local RS = game:GetService("ReplicatedStorage")
local NF = RS:WaitForChild("Numberfall")
local Extras = require(NF:WaitForChild("Extras"))
local Pets = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local A, V, rad = CFrame.Angles, Vector3.new, math.rad
local TAU = math.pi * 2

-- ---------------------------------------------------------------- building
local function base(p, model, name, size, color, role, props)
	p.Name = name; p.Size = size; p.Color = color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material = Enum.Material.SmoothPlastic
	if p:IsA("Part") then p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth end
	if props then for k, v in pairs(props) do p[k] = v end end
	p:SetAttribute("Role", role or "fixed")
	p.Parent = model
	return p
end
local function block(m, name, size, color, role, props) return base(Instance.new("Part"), m, name, size, color, role, props) end
local function wedge(m, name, size, color, role, props) return base(Instance.new("WedgePart"), m, name, size, color, role, props) end
local function ball(m, name, size, color, role, props)
	local p = block(m, name, size, color, role, props)
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
	return p
end
local function cyl(m, name, size, color, role, props)
	local p = block(m, name, size, color, role, props); p.Shape = Enum.PartType.Cylinder
	return p
end
local function neon(props) props = props or {}; props.Material = Enum.Material.Neon; return props end
-- where a piece sits relative to the root (rest pose); Animate re-places it every frame
local function rest(m, p, offset, tag, attrs)
	p:SetAttribute("Rest", offset)
	p.CFrame = m.PrimaryPart.CFrame * offset
	if tag then p:AddTag(tag) end
	if attrs then for k, v in pairs(attrs) do p:SetAttribute(k, v) end end
	return p
end
local function newModel(id)
	local m = Instance.new("Model"); m.Name = "Pet_" .. id
	local root = block(m, "Root", Vector3.one * 0.2, Color3.new(), "fixed", {Transparency = 1})
	root:SetAttribute("Role", nil)
	m.PrimaryPart = root
	m:SetAttribute("PetId", id)
	return m
end
local function light(parent, color, brightness, range)
	local l = Instance.new("PointLight"); l.Color = color; l.Brightness = brightness; l.Range = range; l.Shadows = false; l.Parent = parent
	l:SetAttribute("Role", "glow")
	return l
end

local BUILD = {}

-- (chibi redesign: big heads, big shiny eyes, rosy cheeks, round bodies -- the same shape language as the lobby
-- carousel ponies. Eyes are named Eye / Pupil / Shine so they blink and close when the pet naps or plays dead.)
local WHITE, BLUSH, INK = rgb(255, 255, 255), rgb(255, 143, 168), rgb(26, 20, 32)
local function cheeks(m, x, y, z, tag)
	for _, s in ipairs({-1, 1}) do
		rest(m, ball(m, "Cheek", V(0.11, 0.06, 0.03), BLUSH, "fixed", {Transparency = 0.2}), CFrame.new(s * x, y, z) * A(0, rad(s * 25), 0), tag)
	end
end

-- big cute eyes, the same on every pet: a coloured iris (glowing if `glow`), a large round pupil and two sparkles lit
-- from the same side. `s` is the side (-1 / 1), `yaw` how far the eye turns outward.
local function cuteEye(m, s, pos, w, h, iris, glow, yaw, tag)
	local rot = A(0, rad(s * (yaw or 20)), 0)
	local fwd = rot.LookVector
	rest(m, ball(m, "Eye", V(w, h, 0.05), iris, glow and "glow" or "fixed", glow and neon() or nil), CFrame.new(pos) * rot, tag)
	rest(m, ball(m, "Pupil", V(w * 0.68, h * 0.73, 0.03), INK, "fixed"), CFrame.new(pos + V(0, -h * 0.04, 0) + fwd * (0.022 * math.min(1, w / 0.12))) * rot, tag)
	rest(m, ball(m, "Shine", V(w * 0.32, w * 0.32, 0.02), WHITE, "fixed", neon()), CFrame.new(pos + V(w * 0.18, h * 0.19, 0) + fwd * (0.04 * math.min(1, w / 0.12))), tag)
	rest(m, ball(m, "Shine", V(w * 0.16, w * 0.16, 0.015), WHITE, "fixed", neon()), CFrame.new(pos + V(-w * 0.14, -h * 0.2, 0) + fwd * (0.037 * math.min(1, w / 0.12))), tag)
end

-- CROW (and the VIP Gilded Crow): a round little crow, one big blob with a head on top, white-and-black eyes, a
-- stubby beak, a feather tuft (the gilded one wears a tiny crown instead) and wings that flap in bursts
local function crow(id, gold)
	local m = newModel(id)
	local BODY = gold and rgb(227, 176, 75) or rgb(46, 40, 54)
	local BELLY = gold and rgb(246, 216, 138) or rgb(74, 65, 87)
	local WING = gold and rgb(200, 145, 46) or rgb(36, 31, 43)
	local BEAK = gold and rgb(181, 101, 29) or rgb(242, 169, 59)
	local skin = gold and {Material = Enum.Material.Metal, Reflectance = 0.12} or nil
	rest(m, ball(m, "Body", V(0.7, 0.66, 0.74), BODY, "main", skin), CFrame.new())
	rest(m, ball(m, "Belly", V(0.42, 0.4, 0.2), BELLY, "accent"), CFrame.new(0, -0.08, -0.3))
	rest(m, ball(m, "Head", V(0.56, 0.52, 0.52), BODY, "main", skin), CFrame.new(0, 0.34, -0.18), "PetHead")
	if gold then
		rest(m, cyl(m, "Crown", V(0.06, 0.26, 0.26), rgb(255, 216, 107), "accent", {Material = Enum.Material.Metal, Reflectance = 0.2}), CFrame.new(0, 0.6, -0.16) * A(0, 0, rad(90)), "PetHead")
		for k = -1, 1 do
			rest(m, ball(m, "CrownPoint", V(0.06, k == 0 and 0.16 or 0.12, 0.06), rgb(255, 216, 107), "accent", {Material = Enum.Material.Metal}), CFrame.new(k * 0.09, 0.67 + (k == 0 and 0.03 or 0), -0.16), "PetHead")
		end
		rest(m, ball(m, "CrownGem", V(0.05, 0.05, 0.03), rgb(217, 68, 95), "glow", neon()), CFrame.new(0, 0.6, -0.29), "PetHead")
	else
		for k = -1, 1 do
			rest(m, ball(m, "Tuft", V(0.08, 0.2, 0.08), BODY, "main"), CFrame.new(k * 0.07, 0.64, -0.16) * A(0, 0, rad(-k * 22)), "PetHead")
		end
	end
	rest(m, ball(m, "Beak", V(0.12, 0.1, 0.22), BEAK, "fixed"), CFrame.new(0, 0.3, -0.5), "PetHead")
	for _, s in ipairs({-1, 1}) do
		cuteEye(m, s, V(s * 0.13, 0.395, -0.415), 0.17, 0.21, gold and rgb(120, 220, 255) or rgb(255, 72, 96), true, 28, "PetHead")
		local hinge = V(s * 0.3, 0.12, 0)
		rest(m, ball(m, "Wing", V(0.12, 0.42, 0.5), WING, "main", skin), CFrame.new(s * 0.38, 0.02, 0.04) * A(0, 0, rad(s * -10)), "PetWing", {Hinge = hinge, Side = s})
		rest(m, ball(m, "Foot", V(0.1, 0.05, 0.13), BEAK, "fixed"), CFrame.new(s * 0.1, -0.34, -0.06))
	end
	cheeks(m, 0.2, 0.3, -0.37, "PetHead")
	rest(m, ball(m, "Tail", V(0.3, 0.08, 0.34), WING, "main", skin), CFrame.new(0, -0.12, 0.42) * A(rad(-20), 0, 0))
	m:SetAttribute("Flap", 10); m:SetAttribute("Glide", true)
	return m
end
BUILD.PetCrow = function() return crow("PetCrow", false) end
BUILD.PetGilded = function() return crow("PetGilded", true) end

-- BAT: a fuzzy round ball with a lighter belly, tall pink-lined ears, big shiny eyes, two little fangs and scalloped
-- membrane wings with finger bones
BUILD.PetBat = function()
	local m = newModel("PetBat")
	local FUR, BELLY, WING, BONE = rgb(59, 42, 72), rgb(94, 73, 112), rgb(42, 29, 51), rgb(74, 54, 88)
	rest(m, ball(m, "Body", V(0.72, 0.72, 0.66), FUR, "main"), CFrame.new())
	rest(m, ball(m, "Belly", V(0.42, 0.36, 0.2), BELLY, "accent"), CFrame.new(0, -0.12, -0.27))
	for _, s in ipairs({-1, 1}) do
		rest(m, wedge(m, "Ear", V(0.06, 0.38, 0.24), FUR, "main"), CFrame.new(s * 0.19, 0.44, -0.02) * A(0, 0, rad(-s * 12)), "PetEar", {Side = s})
		rest(m, wedge(m, "EarIn", V(0.03, 0.26, 0.15), BLUSH, "fixed"), CFrame.new(s * 0.19, 0.42, -0.05) * A(0, 0, rad(-s * 12)), "PetEar", {Side = s})
		cuteEye(m, s, V(s * 0.14, 0.06, -0.31), 0.15, 0.18, rgb(255, 96, 130), true, 25)
		rest(m, wedge(m, "Fang", V(0.03, 0.06, 0.03), rgb(245, 240, 232), "fixed"), CFrame.new(s * 0.045, -0.12, -0.325) * A(rad(180), 0, 0))
		rest(m, ball(m, "Foot", V(0.1, 0.07, 0.1), BELLY, "accent"), CFrame.new(s * 0.1, -0.36, 0.02))
		local hinge = V(s * 0.28, 0.08, 0)
		for k = 1, 3 do
			local spread = (k - 2) * 26
			local w = wedge(m, "Membrane", V(0.04, 0.42, 0.62 - k * 0.08), WING, "main", {Transparency = 0.05})
			local off = CFrame.new(hinge) * A(0, 0, rad(s * (8 + k * 4))) * A(rad(spread), 0, 0) * CFrame.new(s * 0.36, -0.1, 0) * A(0, rad(s * 90), 0)
			rest(m, w, off, "PetWing", {Hinge = hinge, Side = s})
			local bone = cyl(m, "Finger", V(0.62, 0.035, 0.035), BONE, "accent")
			rest(m, bone, CFrame.new(hinge) * A(0, 0, rad(s * (8 + k * 4))) * A(rad(spread + 13), 0, 0) * CFrame.new(s * 0.33, 0.02, 0), "PetWing", {Hinge = hinge, Side = s})
		end
	end
	cheeks(m, 0.22, -0.04, -0.26)
	m:SetAttribute("Flap", 15)
	return m
end

-- BLACK CAT: round body with a pale bib, big head with a muzzle, pink-lined ears, slit-pupil eyes, whiskers, four legs
-- with paws and a long curling tail -- plus a red collar with a little gold bell
BUILD.PetCat = function()
	local m = newModel("PetCat")
	local FUR, BIB, PINK = rgb(28, 26, 32), rgb(64, 60, 70), rgb(226, 120, 140)
	rest(m, ball(m, "Body", V(0.58, 0.54, 0.96), FUR, "main"), CFrame.new(0, 0.55, 0.04))
	rest(m, ball(m, "Bib", V(0.36, 0.38, 0.3), BIB, "accent"), CFrame.new(0, 0.6, -0.4))
	rest(m, ball(m, "Head", V(0.58, 0.52, 0.52), FUR, "main"), CFrame.new(0, 0.95, -0.5), "PetHead")
	rest(m, ball(m, "Muzzle", V(0.26, 0.17, 0.14), BIB, "accent"), CFrame.new(0, 0.86, -0.75), "PetHead")
	rest(m, ball(m, "Nose", V(0.07, 0.05, 0.04), PINK, "fixed"), CFrame.new(0, 0.91, -0.81), "PetHead")
	for _, s in ipairs({-1, 1}) do
		rest(m, wedge(m, "Ear", V(0.06, 0.24, 0.2), FUR, "main"), CFrame.new(s * 0.16, 1.24, -0.5) * A(0, 0, rad(s * 12)), "PetEar", {Side = s})
		rest(m, wedge(m, "EarIn", V(0.03, 0.16, 0.12), PINK, "fixed"), CFrame.new(s * 0.16, 1.22, -0.53) * A(0, 0, rad(s * 12)), "PetEar", {Side = s})
		-- big round eyes: a glowing yellow iris, a large round pupil and two sparkles
		rest(m, ball(m, "Eye", V(0.155, 0.185, 0.05), rgb(255, 214, 60), "glow", neon()), CFrame.new(s * 0.115, 0.99, -0.735) * A(0, rad(s * 18), 0), "PetHead")
		rest(m, ball(m, "Pupil", V(0.105, 0.135, 0.03), rgb(14, 10, 16), "fixed"), CFrame.new(s * 0.112, 0.982, -0.757) * A(0, rad(s * 18), 0), "PetHead")
		rest(m, ball(m, "Shine", V(0.05, 0.05, 0.02), rgb(255, 255, 255), "fixed", neon()), CFrame.new(s * 0.115 + 0.028, 1.025, -0.775), "PetHead")
		rest(m, ball(m, "Shine", V(0.025, 0.025, 0.015), rgb(255, 255, 255), "fixed", neon()), CFrame.new(s * 0.115 - 0.022, 0.952, -0.772), "PetHead")
		for k = -1, 1 do
			rest(m, block(m, "Whisker", V(0.26, 0.012, 0.012), rgb(220, 216, 210), "fixed"), CFrame.new(s * 0.2, 0.87 + k * 0.025, -0.76) * A(0, 0, rad(s * k * 8)), "PetHead")
		end
		for _, z in ipairs({-0.32, 0.34}) do
			local step = (z < 0) == (s < 0) and 0 or math.pi
			rest(m, ball(m, "Leg", V(0.17, 0.4, 0.17), FUR, "main"), CFrame.new(s * 0.15, 0.21, z), "PetLeg", {Step = step})
			rest(m, ball(m, "Paw", V(0.17, 0.08, 0.2), BIB, "accent"), CFrame.new(s * 0.15, 0.04, z - 0.02), "PetLeg", {Step = step})
		end
	end
	rest(m, cyl(m, "Collar", V(0.06, 0.38, 0.38), rgb(217, 68, 95), "fixed"), CFrame.new(0, 0.79, -0.46) * A(rad(-30), 0, 0) * A(0, 0, rad(90)))
	rest(m, ball(m, "Bell", V(0.08, 0.08, 0.08), rgb(232, 176, 75), "fixed", {Material = Enum.Material.Metal, Reflectance = 0.2}), CFrame.new(0, 0.67, -0.6))
	for k = 1, 7 do
		local seg = ball(m, "Tail", V(0.13, 0.13, 0.2), k == 7 and BIB or FUR, k == 7 and "accent" or "main")
		local a = k / 7
		rest(m, seg, CFrame.new(0, 0.56 + a * 0.8, 0.4 + math.sin(a * 2.2) * 0.32) * A(rad(-60 * a), 0, 0), "PetTail", {TailK = k})
	end
	m:SetAttribute("Ground", true)
	return m
end

-- STRAY DOG: black and tan, a big round head with floppy ears, tan eyebrows and muzzle, a panting tongue, a red collar
-- with a gold tag, stubby legs and a wagging tail
BUILD.PetDog = function()
	local m = newModel("PetDog")
	local FUR, TAN, EAR = rgb(58, 46, 42), rgb(201, 138, 80), rgb(42, 32, 29)
	rest(m, ball(m, "Body", V(0.66, 0.54, 0.86), FUR, "main"), CFrame.new(0, 0.42, 0.1))
	rest(m, ball(m, "Chest", V(0.42, 0.42, 0.3), TAN, "accent"), CFrame.new(0, 0.42, -0.22))
	for _, s in ipairs({-1, 1}) do
		for _, z in ipairs({-0.2, 0.36}) do
			local step = (z < 0) == (s < 0) and 0 or math.pi
			rest(m, ball(m, "Leg", V(0.18, 0.3, 0.18), FUR, "main"), CFrame.new(s * 0.18, 0.17, z), "PetLeg", {Step = step})
			rest(m, ball(m, "Paw", V(0.21, 0.1, 0.24), TAN, "accent"), CFrame.new(s * 0.18, 0.05, z - 0.03), "PetLeg", {Step = step})
		end
		rest(m, ball(m, "Ear", V(0.16, 0.44, 0.26), EAR, "main"), CFrame.new(s * 0.4, 0.9, -0.22) * A(0, 0, rad(s * 16)), "PetEar", {Side = s})
		rest(m, ball(m, "Brow", V(0.1, 0.06, 0.04), TAN, "accent"), CFrame.new(s * 0.15, 1.1, -0.57), "PetHead")
		cuteEye(m, s, V(s * 0.16, 0.98, -0.6), 0.16, 0.2, rgb(214, 140, 64), false, 22, "PetHead")
	end
	rest(m, ball(m, "Head", V(0.8, 0.74, 0.74), FUR, "main"), CFrame.new(0, 0.95, -0.25), "PetHead")
	rest(m, ball(m, "Snout", V(0.38, 0.28, 0.26), TAN, "accent"), CFrame.new(0, 0.82, -0.56), "PetHead")
	rest(m, ball(m, "Nose", V(0.14, 0.1, 0.08), INK, "fixed"), CFrame.new(0, 0.9, -0.69), "PetHead")
	rest(m, ball(m, "Tongue", V(0.1, 0.03, 0.12), BLUSH, "fixed"), CFrame.new(0, 0.72, -0.64) * A(rad(-25), 0, 0), "PetHead")
	cheeks(m, 0.27, 0.86, -0.5, "PetHead")
	rest(m, cyl(m, "Collar", V(0.08, 0.54, 0.54), rgb(217, 68, 95), "fixed"), CFrame.new(0, 0.66, -0.24) * A(rad(-20), 0, 0) * A(0, 0, rad(90)))
	rest(m, cyl(m, "Tag", V(0.03, 0.1, 0.1), rgb(255, 210, 90), "glow", neon()), CFrame.new(0, 0.53, -0.47) * A(0, rad(90), 0))
	local pivot = V(0, 0.62, 0.5)
	for k = 1, 3 do
		local a = k / 3
		rest(m, ball(m, "Tail", V(0.13, 0.13, 0.26), k == 3 and TAN or FUR, k == 3 and "accent" or "main"), CFrame.new(0, 0.62 + a * 0.34, 0.52 + a * 0.2) * A(rad(-55), 0, 0), "PetWag", {Pivot = pivot})
	end
	m:SetAttribute("Ground", true)
	return m
end

-- GHOST: a sheet ghost with a soft inner glow, tattered hem, waving nub arms, blushing cheeks and an "o" mouth
BUILD.PetGhost = function()
	local m = newModel("PetGhost")
	local SHEET, BLUSH = rgb(240, 240, 250), rgb(255, 160, 190)
	rest(m, ball(m, "Head", V(0.95, 0.95, 0.95), SHEET, "main", {Transparency = 0.08}), CFrame.new(0, 0.22, 0))
	rest(m, cyl(m, "Sheet", V(0.6, 0.94, 0.94), SHEET, "main", {Transparency = 0.08}), CFrame.new(0, -0.18, 0) * A(0, 0, rad(90)))
	rest(m, ball(m, "Inner", V(0.7, 0.8, 0.7), rgb(180, 220, 255), "glow", neon({Transparency = 0.82})), CFrame.new(0, 0.05, 0), "PetPulse")
	for i = 0, 7 do
		local a = i / 8 * TAU
		local tat = wedge(m, "Tatter", V(0.2, 0.26, 0.1), SHEET, "main", {Transparency = 0.08})
		rest(m, tat, CFrame.new(math.cos(a) * 0.4, -0.55, math.sin(a) * 0.4) * A(0, -a + math.pi / 2, 0) * A(rad(180), 0, 0), "PetWave", {Wave = a})
	end
	for _, s in ipairs({-1, 1}) do
		rest(m, ball(m, "Arm", V(0.26, 0.22, 0.22), SHEET, "main", {Transparency = 0.08}), CFrame.new(s * 0.5, -0.05, -0.05), "PetArm", {Side = s})
		cuteEye(m, s, V(s * 0.17, 0.33, -0.45), 0.15, 0.21, rgb(140, 210, 255), true, 15)
		rest(m, ball(m, "Cheek", V(0.12, 0.06, 0.03), BLUSH, "accent", {Transparency = 0.25}), CFrame.new(s * 0.27, 0.18, -0.42))
	end
	rest(m, ball(m, "Mouth", V(0.1, 0.12, 0.04), rgb(22, 20, 28), "fixed"), CFrame.new(0, 0.12, -0.47))
	return m
end

-- WILL-O'-WISP: a white-hot core in a stack of flickering flame tongues, three sparks orbiting it
BUILD.PetWisp = function()
	local m = newModel("PetWisp")
	local CORE, GLOW = rgb(235, 252, 255), rgb(90, 210, 255)
	local core = rest(m, ball(m, "Core", V(0.32, 0.32, 0.32), CORE, "fixed", neon()), CFrame.new())
	for _, s in ipairs({-1, 1}) do
		cuteEye(m, s, V(s * 0.06, 0.025, -0.16), 0.075, 0.095, rgb(70, 175, 225), false, 15)
		rest(m, ball(m, "Cheek", V(0.05, 0.025, 0.015), rgb(255, 157, 178), "fixed"), CFrame.new(s * 0.09, -0.03, -0.148))
	end
	rest(m, block(m, "Smile", V(0.05, 0.012, 0.01), rgb(28, 74, 99), "fixed"), CFrame.new(0, -0.04, -0.163))
	for k = 1, 4 do
		local f = ball(m, "Flame", V(0.7 - k * 0.12, 0.7 - k * 0.08, 0.7 - k * 0.12), GLOW, "glow", neon({Transparency = 0.35 + k * 0.1}))
		rest(m, f, CFrame.new(0, k * 0.16, 0), "PetFlame", {K = k})
	end
	for k = 1, 3 do
		rest(m, ball(m, "Spark", V(0.08, 0.08, 0.08), CORE, "accent", neon()), CFrame.new(0.45, 0, 0), "PetOrbit", {Orbit = k / 3 * TAU, R = 0.45 + k * 0.05})
	end
	light(core, GLOW, 1.6, 10)
	local att = Instance.new("Attachment"); att.Parent = core
	local f = Instance.new("ParticleEmitter")
	f.Name = "Embers"; f:SetAttribute("Role", "glow")
	f.Texture = "rbxasset://textures/particles/sparkles_main.dds"; f.Color = ColorSequence.new(CORE, GLOW); f.LightEmission = 1
	f.Size = NumberSequence.new(0.18, 0); f.Transparency = NumberSequence.new(0.2, 1); f.Lifetime = NumberRange.new(0.5, 0.9)
	f.Rate = 10; f.Speed = NumberRange.new(0.6, 1.4); f.EmissionDirection = Enum.NormalId.Top; f.SpreadAngle = Vector2.new(30, 30); f.LightInfluence = 0
	f.Parent = att
	return m
end

-- LANTERN SKULL: a little Victorian street lantern -- iron frame, gold trim, a domed cap with a ring to hang it by, warm
-- amber glass -- with a cute round skull floating inside it, ember eyes glowing, jaw chattering
BUILD.PetSkull = function()
	local m = newModel("PetSkull")
	local IRON, GOLD, GLASS, BONE, EMBER = rgb(43, 37, 48), rgb(200, 150, 62), rgb(255, 179, 71), rgb(239, 230, 210), rgb(255, 196, 77)
	local iron = {Material = Enum.Material.Metal, Reflectance = 0.08}
	local gold = {Material = Enum.Material.Metal, Reflectance = 0.2}
	rest(m, block(m, "Base", V(0.62, 0.06, 0.62), IRON, "main", iron), CFrame.new(0, -0.42, 0))
	rest(m, block(m, "BaseTrim", V(0.68, 0.04, 0.68), GOLD, "accent", gold), CFrame.new(0, -0.465, 0))
	rest(m, ball(m, "Foot", V(0.3, 0.1, 0.3), IRON, "main", iron), CFrame.new(0, -0.5, 0))
	rest(m, block(m, "Top", V(0.62, 0.06, 0.62), IRON, "main", iron), CFrame.new(0, 0.42, 0))
	rest(m, block(m, "TopTrim", V(0.68, 0.04, 0.68), GOLD, "accent", gold), CFrame.new(0, 0.38, 0))
	rest(m, ball(m, "Dome", V(0.62, 0.32, 0.62), IRON, "main", iron), CFrame.new(0, 0.48, 0))
	rest(m, ball(m, "Finial", V(0.1, 0.1, 0.1), GOLD, "accent", gold), CFrame.new(0, 0.66, 0))
	for k = 0, 7 do
		local a = k / 8 * TAU
		rest(m, ball(m, "Ring", V(0.045, 0.045, 0.045), GOLD, "accent", gold), CFrame.new(math.cos(a) * 0.09, 0.8 + math.sin(a) * 0.09, 0))
	end
	for _, x in ipairs({-1, 1}) do for _, z in ipairs({-1, 1}) do
		rest(m, block(m, "Post", V(0.05, 0.84, 0.05), IRON, "main", iron), CFrame.new(x * 0.29, 0, z * 0.29))
	end end
	-- amber glass on all four sides (the front a little clearer so the face shows)
	for i, spec in ipairs({{0, -0.29, 0.86}, {0, 0.29, 0.72}, {-0.29, 0, 0.72}, {0.29, 0, 0.72}}) do
		local p = block(m, "Glass", V(spec[1] == 0 and 0.54 or 0.02, 0.78, spec[1] == 0 and 0.02 or 0.54), GLASS, "glow", {Material = Enum.Material.SmoothPlastic, Transparency = spec[3] + 0.06})
		rest(m, p, CFrame.new(spec[1], 0, spec[2]))
	end
	local glow = rest(m, ball(m, "Glow", V(0.46, 0.56, 0.46), GLASS, "glow", neon({Transparency = 0.86})), CFrame.new(0, 0, 0), "PetPulse")
	light(glow, GLASS, 1.4, 9)
	-- the skull inside
	rest(m, ball(m, "Cranium", V(0.36, 0.33, 0.34), BONE, "main"), CFrame.new(0, 0.03, 0), "PetScythe")
	rest(m, ball(m, "Jaw", V(0.24, 0.12, 0.2), BONE, "main"), CFrame.new(0, -0.12, -0.03), "PetJaw")
	for k = -1, 1 do
		rest(m, block(m, "Tooth", V(0.035, 0.035, 0.02), WHITE, "fixed"), CFrame.new(k * 0.045, -0.085, -0.13), "PetJaw")
	end
	for _, sd in ipairs({-1, 1}) do
		rest(m, ball(m, "Socket", V(0.1, 0.11, 0.03), INK, "fixed"), CFrame.new(sd * 0.075, 0.04, -0.162) * A(0, rad(sd * 20), 0), "PetScythe")
		cuteEye(m, sd, V(sd * 0.075, 0.035, -0.17), 0.08, 0.09, EMBER, true, 20, "PetScythe")
		rest(m, ball(m, "Cheek", V(0.06, 0.035, 0.02), BLUSH, "fixed", {Transparency = 0.3}), CFrame.new(sd * 0.12, -0.03, -0.145) * A(0, rad(sd * 30), 0), "PetScythe")
	end
	rest(m, wedge(m, "Nose", V(0.04, 0.04, 0.02), INK, "fixed"), CFrame.new(0, -0.02, -0.17) * A(rad(180), 0, 0), "PetScythe")
	return m
end

-- VISOR DRONE: a round little bot -- the game's LED visor wrapped round its face (your number style, blinking), a
-- propeller cap on top, two antenna ears (one blinking), rosy cheeks and a red thruster glow underneath
BUILD.PetDrone = function(owner)
	local NumberStyles = require(NF:WaitForChild("NumberStyles"))
	local m = newModel("PetDrone")
	local SHELL, TRIM, DARK, RED = rgb(52, 50, 62), rgb(84, 82, 96), rgb(14, 10, 16), rgb(255, 38, 48)
	local shell = {Material = Enum.Material.SmoothPlastic, Reflectance = 0.12}
	rest(m, ball(m, "Body", V(0.72, 0.68, 0.68), SHELL, "main", shell), CFrame.new())
	rest(m, cyl(m, "Band", V(0.22, 0.73, 0.71), DARK, "fixed"), CFrame.new(0, 0.05, 0) * A(0, 0, rad(90)))
	rest(m, cyl(m, "Belt", V(0.05, 0.72, 0.7), TRIM, "accent", shell), CFrame.new(0, -0.14, 0) * A(0, 0, rad(90)))
	local screen = rest(m, block(m, "Screen", V(0.44, 0.16, 0.02), DARK, "fixed"), CFrame.new(0, 0.05, -0.36))
	local sg = Instance.new("SurfaceGui"); sg.Name = "Face"; sg.Face = Enum.NormalId.Front; sg.LightInfluence = 0; sg.Brightness = 2
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize; sg.CanvasSize = Vector2.new(264, 96); sg.Parent = screen
	-- the face is drawn in the owner's number style (blinking), and the style's colour tints the propeller
	for _, face in ipairs({"O__O", "-__-"}) do
		local holder = Instance.new("Frame"); holder.Name = face == "O__O" and "Open" or "Shut"; holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1); holder.Visible = face == "O__O"; holder.Parent = sg
		for i = 1, 4 do
			local cell = Instance.new("Frame"); cell.BackgroundTransparency = 1
			cell.Size = UDim2.fromOffset(64, 96); cell.Position = UDim2.fromOffset((i - 1) * 66, 0); cell.Parent = holder
			pcall(NumberStyles.DrawScaled, cell, face:sub(i, i), owner and owner:GetAttribute("NumberStyle") or NumberStyles.Default, 96)
		end
	end
	m:SetAttribute("Blink", true)
	local styleId = owner and owner:GetAttribute("NumberStyle") or NumberStyles.Default
	local styleDef = NumberStyles.ById and NumberStyles.ById[styleId]
	local sc = styleDef and styleDef.Color
	local PROP = sc and rgb(sc[1], sc[2], sc[3]) or RED
	for _, sd in ipairs({-1, 1}) do
		rest(m, ball(m, "Cap", V(0.08, 0.2, 0.2), RED, "glow", neon()), CFrame.new(sd * 0.365, 0.05, 0))
		rest(m, ball(m, "Cheek", V(0.1, 0.05, 0.03), BLUSH, "fixed", {Transparency = 0.2}), CFrame.new(sd * 0.19, -0.09, -0.3) * A(0, rad(sd * 30), 0))
	end
	-- the propeller on top: a short mast, a hub, and three rounded blades in the owner's number-style colour that
	-- spin slowly enough to read as blades (Spin = radians a second, see Animate)
	rest(m, cyl(m, "Stem", V(0.2, 0.06, 0.06), TRIM, "accent", shell), CFrame.new(0, 0.42, 0) * A(0, 0, rad(90)))
	rest(m, ball(m, "Hub", V(0.14, 0.1, 0.14), PROP, "fixed", neon()), CFrame.new(0, 0.53, 0), "PetRotor", {Spin = 9, Axis = true})
	for k = 0, 2 do
		local blade = ball(m, "Blade", V(0.03, 0.48, 0.17), PROP, "fixed", {Material = Enum.Material.SmoothPlastic, Reflectance = 0.1})
		local off = CFrame.new(0, 0.53, 0) * A(0, k / 3 * TAU, 0) * CFrame.new(0.25, 0, 0) * A(rad(14), 0, 0) * A(0, 0, rad(90))
		rest(m, blade, off, "PetRotor", {Spin = 9, Axis = true})
	end
	-- thruster glow
	local jet = rest(m, ball(m, "Thruster", V(0.18, 0.07, 0.18), RED, "glow", neon({Transparency = 0.25})), CFrame.new(0, -0.35, 0))
	light(jet, RED, 0.8, 6)
	m:SetAttribute("Tilt", true)
	return m
end

-- LITTLE REAPER: hooded cloak with a tattered hem, bony hands on a scythe with a curved blade, red eyes in the dark
BUILD.PetReaper = function()
	local m = newModel("PetReaper")
	local ROBE, RIM, VOID, BONE, BLADE = rgb(20, 18, 24), rgb(60, 14, 24), rgb(4, 2, 6), rgb(226, 218, 200), rgb(200, 204, 214)
	local robe = block(m, "Robe", V(0.8, 1, 0.8), ROBE, "main", {Material = Enum.Material.SmoothPlastic})
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.FileMesh; mesh.MeshId = "rbxassetid://1033714"
	mesh.Scale = V(0.42, 1.05, 0.42); mesh.Parent = robe
	rest(m, robe, CFrame.new(0, -0.12, 0))
	for i = 0, 6 do
		local a = i / 7 * TAU
		rest(m, wedge(m, "Tatter", V(0.16, 0.2, 0.08), ROBE, "main", {Material = Enum.Material.SmoothPlastic}),
			CFrame.new(math.cos(a) * 0.38, -0.66, math.sin(a) * 0.38) * A(0, -a + math.pi / 2, 0) * A(rad(180), 0, 0), "PetWave", {Wave = a})
	end
	rest(m, ball(m, "Hood", V(0.64, 0.68, 0.64), ROBE, "main", {Material = Enum.Material.SmoothPlastic}), CFrame.new(0, 0.44, 0.02), "PetHead")
	-- crimson lining showing at the hood's edge
	rest(m, ball(m, "HoodLining", V(0.5, 0.52, 0.12), RIM, "accent", {Material = Enum.Material.SmoothPlastic}), CFrame.new(0, 0.42, -0.22), "PetHead")
	rest(m, ball(m, "Face", V(0.42, 0.44, 0.1), VOID, "fixed"), CFrame.new(0, 0.41, -0.27), "PetHead")
	for _, s in ipairs({-1, 1}) do
		cuteEye(m, s, V(s * 0.085, 0.44, -0.33), 0.11, 0.13, rgb(255, 40, 56), true, 15, "PetHead")
		rest(m, ball(m, "Cheek", V(0.07, 0.035, 0.02), BLUSH, "fixed", {Transparency = 0.2}), CFrame.new(s * 0.15, 0.37, -0.325) * A(0, rad(s * 20), 0), "PetHead")
		rest(m, ball(m, "Sleeve", V(0.22, 0.36, 0.22), ROBE, "main", {Material = Enum.Material.SmoothPlastic}), CFrame.new(s * 0.32, 0.08, -0.08) * A(rad(-30), 0, rad(s * 12)))
		rest(m, ball(m, "Hand", V(0.1, 0.1, 0.1), BONE, "fixed"), CFrame.new(s * 0.36, -0.08, -0.22), "PetScythe")
	end
	-- scythe held upright at the right side: a long snath, and at its top a curved blade sweeping forward and down
	local top = V(0.44, 1.05, -0.2)
	rest(m, cyl(m, "Snath", V(1.7, 0.06, 0.06), rgb(70, 46, 30), "fixed", {Material = Enum.Material.Wood}), CFrame.new(0.44, 0.2, -0.2) * A(0, 0, rad(90)), "PetScythe")
	rest(m, cyl(m, "Collar", V(0.08, 0.09, 0.09), rgb(120, 110, 100), "fixed", {Material = Enum.Material.Metal}), CFrame.new(top) * A(0, 0, rad(90)), "PetScythe")
	local pos, ang = top, 0
	for k = 1, 4 do
		local len, h = 0.26, 0.15 - k * 0.025
		ang += rad(14)
		local dir = V(0, -math.sin(ang), -math.cos(ang))
		local center = pos + dir * (len / 2)
		local seg = block(m, "Blade", V(0.03, h, len), BLADE, "accent", {Material = Enum.Material.Metal, Reflectance = 0.25})
		rest(m, seg, CFrame.new(center) * A(-ang, 0, 0) * CFrame.new(0, h / 2 - 0.02, 0), "PetScythe")
		pos += dir * len
	end
	rest(m, wedge(m, "BladeTip", V(0.03, 0.06, 0.14), BLADE, "accent", {Material = Enum.Material.Metal, Reflectance = 0.25}),
		CFrame.new(pos + V(0, 0.01, -0.04)) * A(-(ang + rad(14)), 0, 0) * A(0, rad(180), 0), "PetScythe")
	rest(m, ball(m, "Glow", V(0.5, 0.5, 0.5), rgb(255, 30, 40), "glow", neon({Transparency = 0.92})), CFrame.new(0, 0.4, -0.1))
	return m
end

-- ---------------------------------------------------------------- colourways
local function recolor(model, cwId)
	local cw = Extras.PetColorwayById and Extras.PetColorwayById[cwId or ""]
	if not cw or not cw.Main then return end
	for _, d in ipairs(model:GetDescendants()) do
		local role = d:GetAttribute("Role")
		local col = role == "main" and cw.Main or role == "accent" and cw.Accent or role == "glow" and cw.Glow or nil
		if col then
			if d:IsA("BasePart") then
				d.Color = col
				if role == "main" and cw.Material then d.Material = cw.Material; d.Reflectance = cw.Reflectance or 0 end
				if role == "main" and cw.Transparency then d.Transparency = math.max(d.Transparency, cw.Transparency) end
				if d:IsA("MeshPart") and d.TextureID ~= "" then pcall(function() d.TextureID = "" end) end
			elseif d:IsA("Light") then d.Color = col
			elseif d:IsA("ParticleEmitter") then d.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(col, 0.4), col) end
		end
	end
end

-- floor pets: hip height (legs fold about it), body centre height / radius (for lying on its side), neck pivot
local GROUND_DIMS = {
	PetCat = {HipY = 0.38, BodyY = 0.55, BodyR = 0.28, Neck = V(0, 0.85, -0.42)},
	PetDog = {HipY = 0.32, BodyY = 0.42, BodyR = 0.33, Neck = V(0, 0.7, -0.3)},
}
function Pets.Build(id, owner, cwId)
	local fn = BUILD[id or ""]
	if not fn then return nil end
	local ok, m = pcall(fn, owner)
	if not ok then warn("[Pets] " .. tostring(id) .. ": " .. tostring(m)); return nil end
	pcall(recolor, m, cwId)
	m:SetAttribute("Colorway", cwId or "PcOriginal")
	local dims = GROUND_DIMS[id]
	if dims then for k, v in pairs(dims) do m:SetAttribute(k, v) end end
	-- how far the root sits above the pet's lowest point, and half its width (for landing / lying down)
	pcall(function()
		local cf, size = m:GetBoundingBox()
		m:SetAttribute("Bottom", m.PrimaryPart.Position.Y - (cf.Position.Y - size.Y / 2))
		m:SetAttribute("HalfW", math.clamp(size.X / 2, 0.2, 0.7))
	end)
	return m
end
function Pets.Ground(id) return id == "PetCat" or id == "PetDog" end

-- little things a pet does now and then while its owner stands about (PetFollow picks one: pose.fidget, pose.fp 0..1)
local FIDGETS = {
	PetCat = {"stretch", "tilt", "hop", "groom", "groom"},
	PetDog = {"tilt", "hop", "sniff", "stretch", "chase"},
	PetDrone = {"spin", "bob", "scan"},
	flyer = {"spin", "bob", "wobble", "flip"},
}
function Pets.Fidgets(id) return FIDGETS[id] or FIDGETS.flyer end
Pets.FIDGET_TIME = 1.6

-- the owner is down: eyes, flames and lights go dim
function Pets.SetDim(model, dim)
	if model:GetAttribute("Dim") == dim then return end
	model:SetAttribute("Dim", dim)
	for _, d in ipairs(model:GetDescendants()) do
		if d:GetAttribute("Role") == "glow" then
			if d:IsA("BasePart") then
				if d:GetAttribute("BaseT") == nil then d:SetAttribute("BaseT", d.Transparency) end
				d.Transparency = dim and math.max(d:GetAttribute("BaseT"), 0.8) or d:GetAttribute("BaseT")
			elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Enabled = not dim
			end
		end
	end
end

-- ---------------------------------------------------------------- animation
local I = CFrame.identity
local NOPOSE = {}
local function around(pos, rot) return CFrame.new(pos) * rot * CFrame.new(-pos) end
local function bell(x) x = math.clamp(x, 0, 1); return math.sin(x * math.pi) end
local function smooth(x) x = math.clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local SHUT = {Eye = true, Pupil = true, Shine = true}

-- pose (optional, from PetFollow): sit / lie / dead weights 0..1, sleep (eyes shut while lying), fidget + fp
function Pets.Animate(model, t, speed, pose)
	local root = model.PrimaryPart; if not root then return end
	pose = pose or NOPOSE
	local sit, lie, dead = pose.sit or 0, pose.lie or 0, pose.dead or 0
	local still = math.max(sit, lie, dead)
	local live = 1 - dead
	local fid, fp = pose.fidget, pose.fp or 0
	local env = fid and bell(fp) or 0
	local ground = model:GetAttribute("Ground")
	local base = root.CFrame
	local flapRate = model:GetAttribute("Flap") or 10
	local walking = (speed or 0) > 2 and still < 0.5
	-- crows flap in bursts and glide in between; the rest flap all the time; landed pets fold up
	local flapAmp = 1
	if model:GetAttribute("Glide") then
		local cycle = (t * 0.35) % 1
		flapAmp = (walking or cycle < 0.5) and 1 or 0.25
	end
	if fid == "flip" or fid == "spin" then flapAmp = 1.3 end
	flapAmp *= 1 - math.max(lie, dead)
	local headYaw = (math.sin(t * 0.7) * 0.35 + math.sin(t * 2.3) * 0.08) * live * (1 - lie * 0.6)
	local blinkShut = (t % 3.4) < 0.12
	local shut = math.max(pose.sleep and lie or 0, dead > 0.5 and 1 or 0, (blinkShut and ground) and 1 or 0)
	local tilt = model:GetAttribute("Tilt") and walking
	local hipY = model:GetAttribute("HipY") or 0.4
	local neck = model:GetAttribute("Neck")

	-- whole-body pose
	local body = I
	if ground then
		local bodyY = model:GetAttribute("BodyY") or 0.55
		local bodyR = model:GetAttribute("BodyR") or 0.28
		if fid == "hop" then body = CFrame.new(0, math.abs(math.sin(fp * TAU)) * 0.3, 0)
		elseif fid == "stretch" then body = around(V(0, 0, -0.45), A(rad(-16 * env), 0, 0)) * CFrame.new(0, -0.08 * env, 0)
		elseif fid == "chase" then body = A(0, smooth(fp) * TAU, 0)
		end
		-- sit: rear down, chest up; lie: belly on the floor; dead: flopped on its side, legs out
		if sit > 0 then body = body:Lerp(CFrame.new(0, -0.2, 0) * around(V(0, 0, 0.4), A(rad(18), 0, 0)), sit) end
		if lie > 0 then body = body:Lerp(CFrame.new(0, -hipY * 0.8, 0), lie) end
		if dead > 0 then body = body:Lerp(CFrame.new(0, bodyR, 0) * A(0, 0, rad(90)) * CFrame.new(0, -bodyY, 0), dead) end
	else
		if fid == "spin" then body = A(0, smooth(fp) * TAU, 0)
		elseif fid == "flip" then body = CFrame.new(0, env * 0.3, 0) * around(V(0, 0.1, 0), A(-smooth(fp) * TAU, 0, 0))
		elseif fid == "bob" then body = CFrame.new(0, env * 0.35, 0)
		elseif fid == "wobble" then body = A(0, 0, math.sin(fp * TAU * 2) * 0.4 * env)
		elseif fid == "scan" then body = A(0, math.sin(fp * TAU) * 0.9 * env, 0)
		end
		-- landed: a slow breath; dead: on its side on the floor (PetFollow puts the root at the right height)
		if still > 0 then body = body:Lerp(CFrame.new(0, math.sin(t * 1.6) * 0.015, 0), math.max(lie, dead) * 0.8) end
		if dead > 0 then body = body:Lerp(A(0, 0, rad(90)), dead) end
	end

	for _, p in ipairs(model:GetChildren()) do
		local r = p:GetAttribute("Rest")
		if r then
			local cf = r
			if p:HasTag("PetWing") then
				local hinge = p:GetAttribute("Hinge"); local side = p:GetAttribute("Side") or 1
				local flap = (math.sin(t * flapRate) * rad(40)) * flapAmp + rad(12) * (1 - math.max(lie, dead))
				local hc = CFrame.new(hinge)
				cf = hc * A(0, 0, -side * flap) * hc:Inverse() * r
			elseif p:HasTag("PetWag") then
				local pv = CFrame.new(p:GetAttribute("Pivot") or Vector3.zero)
				local happy = walking or fid ~= nil
				local wag = math.sin(t * (happy and 16 or 9 - lie * 5)) * rad(happy and 32 or 24) * live * (1 - lie * 0.6)
				cf = pv * A(0, wag, 0) * pv:Inverse() * r
			elseif p:HasTag("PetTail") then
				local k = p:GetAttribute("TailK") or 1
				cf = CFrame.new(math.sin(t * (2.2 - lie) - k * 0.45) * 0.035 * k * live, 0, 0) * r
			elseif p:HasTag("PetLeg") then
				local pos = r.Position
				local front = pos.Z < 0
				local swing = walking and math.sin(t * 13 + (p:GetAttribute("Step") or 0)) * rad(32) or 0
				local fold
				if front then fold = sit * rad(-18) + lie * rad(78) + dead * rad(28)
				else fold = sit * rad(85) + lie * rad(78) + dead * rad(-28) end
				if fid == "stretch" and front then fold += rad(40) * env end
				if fid == "groom" and front and pos.X < 0 then fold += rad(100) * env end
				cf = around(V(pos.X, hipY, pos.Z), A(swing * (1 - still) + fold, 0, 0)) * r
			elseif p:HasTag("PetHead") or p:HasTag("PetEar") then
				if neck then
					-- floor pets turn the whole head about the neck: look around, nod off, sniff, tilt, groom
					local pitch = -lie * rad(14) + sit * rad(8)
					local yaw = headYaw * (walking and 0.3 or 1)
					local roll = 0
					if fid == "sniff" then pitch += -rad(30) * env + math.sin(t * 22) * rad(3) * env
					elseif fid == "tilt" then roll = rad(24) * env * ((math.floor(t) % 2 == 0) and 1 or -1)
					elseif fid == "groom" then pitch += -rad(26) * env; yaw += 0.6 * env
					elseif fid == "stretch" then pitch += rad(14) * env end
					cf = around(neck, A(pitch * live, yaw, roll * live)) * r
				else
					local pivot = CFrame.new(0, r.Position.Y, r.Position.Z + 0.1)
					cf = pivot * A(0, headYaw * (walking and 0.3 or 1), 0) * pivot:Inverse() * r
				end
				if p:HasTag("PetEar") and (t % 4.1) < 0.15 and live > 0.5 then cf = cf * A(0, 0, rad(18 * (p:GetAttribute("Side") or 1))) end
			elseif p:HasTag("PetWave") then
				cf = CFrame.new(0, math.sin(t * 5 + (p:GetAttribute("Wave") or 0)) * 0.05 * live, 0) * r
			elseif p:HasTag("PetArm") then
				cf = CFrame.new(0, math.sin(t * 3 + (p:GetAttribute("Side") or 1)) * 0.07 * live, 0) * r
			elseif p:HasTag("PetPulse") then
				cf = r * CFrame.new(0, math.sin(t * 6 + p.Size.X * 10) * 0.015 * live, 0)
			elseif p:HasTag("PetFlame") then
				local k = p:GetAttribute("K") or 1
				local w = math.sin(t * 13 + k * 1.7) * 0.03 * k
				cf = CFrame.new(w, math.sin(t * 9 + k) * 0.02, w * 0.5) * r
			elseif p:HasTag("PetOrbit") then
				local a = (p:GetAttribute("Orbit") or 0) + t * (2.6 - still * 1.6)
				local rr = (p:GetAttribute("R") or 0.5) * (1 - dead * 0.7)
				cf = CFrame.new(math.cos(a) * rr, math.sin(a * 1.7) * 0.2 * live + 0.1, math.sin(a) * rr)
			elseif p:HasTag("PetRotor") then
				local spin = (t * (p:GetAttribute("Spin") or 40) * (1 - 0.85 * math.max(lie, dead))) % TAU
				if p:GetAttribute("Axis") then
					local c = CFrame.new(0, r.Position.Y, 0)
					cf = c * A(0, spin, 0) * c:Inverse() * r
				else
					cf = r * A(spin, 0, 0)
				end
			elseif p:HasTag("PetJaw") then
				cf = CFrame.new(0, -math.max(0, math.sin(t * 7)) * math.max(0, math.sin(t * 0.9)) * 0.06 * live, 0) * r
			elseif p:HasTag("PetScythe") then
				cf = CFrame.new(0, math.sin(t * 1.4) * 0.03 * live, 0) * r
			elseif p:HasTag("PetBeacon") then
				p.Transparency = (dead < 0.5 and (t % 1.2) < 0.15) and 0 or 0.7
			end
			if shut > 0 and SHUT[p.Name] then cf = cf * CFrame.new(0, 0, 0.07 * shut) end
			if tilt then cf = A(rad(-10), 0, 0) * cf end
			p.CFrame = base * body * cf
		end
	end
	if model:GetAttribute("Blink") then
		local screen = model:FindFirstChild("Screen")
		local face = screen and screen:FindFirstChild("Face")
		if face then
			local closed = blinkShut or dead > 0.5 or (pose.sleep and lie > 0.5)
			face.Open.Visible = not closed; face.Shut.Visible = closed
		end
	end
end
return Pets
