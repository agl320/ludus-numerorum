-- Clothing for the blocky R15 body: each outfit colours the body parts it covers in a fabric (cloth materials from
-- MaterialService, falling back to the base material) and adds a few modelled details (hood, collar, coat tails,
-- tie, straps...). Uncovered parts (head, hands, bare forearms) take the player's own skin tone.
-- Used by the server on real characters (ServerScriptService.Outfit) and by the menu previews (LoadoutPreview / Art).
-- Outfit(model, id, skin): apply to any R15 character model (anchored clones work too).
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local MaterialService = game:GetService("MaterialService")
local fitDetail
local O = {}

-- cloth: Roblox base material + the generated MaterialVariant (used when it exists)
local CLOTH = {
	knit = {Enum.Material.Fabric, "MARKED_Knit"},
	denim = {Enum.Material.Fabric, "MARKED_DenimFine"},
	wool = {Enum.Material.Fabric, "MARKED_Wool"},
	leather = {Enum.Material.Leather, "MARKED_Leather1"},   -- (the smooth one of the generated set: the others had a dent / heavy pebbling)
	ripstop = {Enum.Material.Fabric, "MARKED_Ripstop"},
	-- (skin, shell and rubber sit on plain map-less variants over Concrete: plain Plastic / SmoothPlastic rendered
	-- avatar body meshes flat white or grey whatever their colour -- everyone's arms looked white)
	rubber = {Enum.Material.Concrete, "MARKED_Rubber"},
	metal = {Enum.Material.Metal},
	shell = {Enum.Material.Concrete, "MARKED_Shell"},   -- clean matte technical shell (ripstop / fabric textures read as silver or lumpy on it)
	skin = {Enum.Material.Concrete, "MARKED_Skin"},
	glow = {Enum.Material.Neon},   -- lit trims (neon piping, glowing sigils)
}
O.Cloth = CLOTH

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
O.DefaultSkin = rgb(204, 160, 128)
O.Default = "StreetTee"

-- body regions -> R15 part names
local REGIONS = {
	torso = {"UpperTorso"}, waist = {"LowerTorso"},
	upperArms = {"LeftUpperArm", "RightUpperArm"}, lowerArms = {"LeftLowerArm", "RightLowerArm"}, hands = {"LeftHand", "RightHand"},
	upperLegs = {"LeftUpperLeg", "RightUpperLeg"}, lowerLegs = {"LeftLowerLeg", "RightLowerLeg"}, feet = {"LeftFoot", "RightFoot"},
}
O.BodyParts = {}
for _, list in pairs(REGIONS) do for _, n in ipairs(list) do O.BodyParts[n] = true end end
O.BodyParts.Head = true
O.Regions = REGIONS
-- body part names an outfit covers with cloth (everything else is bare skin: head, hands, bare forearms...)
function O.Covered(outfit)
	local set = {}
	for region in pairs(outfit and outfit.Wear or {}) do for _, n in ipairs(REGIONS[region] or {}) do set[n] = true end end
	return set
end

-- Details: {part = body part, size = Vector3 in multiples of that part's size, at = offset in multiples of its size
-- (front is -Z), rot = degrees, color, cloth, shape = "Block"/"Ball"/"Disc", name}
local function d(t) return t end
-- a skirt: a marker the outfit's Details carry; Outfits.Apply builds it as a flared, pleated cone of panels around
-- the hips, sized from the body it's put on (hip joints, leg and waist sizes), so it fits the classic and the
-- feminine body with no gaps. len = length in upper-leg heights (about 1.24 studs; over 1 reaches past the knee);
-- hem = colour of a band at the bottom (optional); flare = extra spread at the bottom.
-- Every skirt comes with black biker shorts underneath: snug down to just above the knee, and a seat piece under the hips.
local SHORTS = rgb(18, 18, 22)
-- bands = optional stripes across the pleats: {{fraction down from the hips, height in studs, colour}, ...}
local function O_SKIRT(main, shade, cloth, len, hem, flare, bands)
	return {
		{skirt = {main = main, shade = shade, cloth = cloth, len = len, hem = hem, flare = flare or 1, bands = bands}},
		-- (down to just above the knee; a touch wider than the sock bands so they don't flicker through)
		{part = "LeftUpperLeg", size = Vector3.new(1.055, 0.78, 1.055), at = Vector3.new(0, 0.11, 0), color = SHORTS, cloth = "knit", name = "BikerShorts"},
		{part = "RightUpperLeg", size = Vector3.new(1.055, 0.78, 1.055), at = Vector3.new(0, 0.11, 0), color = SHORTS, cloth = "knit", name = "BikerShorts"},
		{part = "LowerTorso", size = Vector3.new(1.0, 0.62, 1.0), at = Vector3.new(0, -0.2, 0), color = SHORTS, cloth = "knit", name = "BikerShorts"},
	}
end

-- ==== cleaned-up outfit details (helpers) ====
local V = Vector3.new
-- mirror a detail to the other side: "Left..." parts become "Right...", x and the Y / Z rotations flip
local function sym(t)
	local a, b = table.clone(t), table.clone(t)
	if t.part:sub(1, 4) == "Left" then b.part = "Right" .. t.part:sub(5) end
	local at, r = t.at or Vector3.zero, t.rot or Vector3.zero
	b.at = V(-at.X, at.Y, at.Z)
	b.rot = V(r.X, -r.Y, -r.Z)
	return {a, b}
end
-- flatten a list whose entries may be single details or {detail, detail} groups
local function flat(list, out)
	out = out or {}
	for _, e in ipairs(list) do
		if e.part or e.skirt then out[#out + 1] = e else flat(e, out) end
	end
	return out
end
-- a hood worn down: a panel lying over the upper back, a roll behind the neck and its sides along the shoulders
-- (blocks and a cylinder, not sphere meshes: those can't take the cloth material and read as shiny plastic blobs)
local function HOOD(main, roll, cloth)
	cloth = cloth or "knit"
	return {
		{part = "UpperTorso", size = V(0.54, 0.3, 0.1), at = V(0, 0.3, 0.55), color = main, cloth = cloth, name = "Hood", hood = true},
		{part = "UpperTorso", size = V(0.58, 0.13, 0.22), at = V(0, 0.5, 0.6), color = roll, cloth = cloth, name = "HoodRoll", shape = "Cylinder", hood = true},
		sym{part = "UpperTorso", size = V(0.09, 0.08, 0.78), at = V(-0.34, 0.54, 0.1), color = roll, cloth = cloth, name = "HoodSide", hood = true},
	}
end
-- a hood lying flat down the back: a panel that tapers to a rounded point in steps, a ribbed rim along the neck
-- and a seam down the middle (no roll: a fat cylinder across the shoulders read as a pool float, not a hood)
local function HOOD_BACK(main, rim, lining, cloth)
	cloth = cloth or "knit"
	return {
		{part = "UpperTorso", size = V(0.62, 0.3, 0.1), at = V(0, 0.33, 0.55), color = main, cloth = cloth, name = "Hood", hood = true},
		{part = "UpperTorso", size = V(0.48, 0.06, 0.1), at = V(0, 0.15, 0.55), color = main, cloth = cloth, name = "Hood", hood = true},
		{part = "UpperTorso", size = V(0.3, 0.05, 0.1), at = V(0, 0.095, 0.55), color = main, cloth = cloth, name = "Hood", hood = true},
		-- the opening along the neck: dark rim with the lining showing just inside it
		{part = "UpperTorso", size = V(0.62, 0.04, 0.11), at = V(0, 0.47, 0.552), color = rim, cloth = cloth, name = "HoodRim", hood = true},
		{part = "UpperTorso", size = V(0.58, 0.022, 0.115), at = V(0, 0.44, 0.553), color = lining or rim, cloth = cloth, name = "HoodLining", hood = true},
		{part = "UpperTorso", size = V(0.008, 0.36, 0.105), at = V(0, 0.25, 0.552), color = rim, cloth = cloth, name = "HoodSeam", hood = true},
	}
end
-- sneaker: sole, toe cap and a heel tab
local function SNEAKER(sole, toe, tab)
	local t = {
		sym{part = "LeftFoot", size = V(1.05, 0.32, 1.07), at = V(0, -0.36, 0), color = sole, cloth = "rubber", name = "Sole"},
		sym{part = "LeftFoot", size = V(0.86, 0.5, 0.05), at = V(0, 0.12, -0.51), color = toe, cloth = "rubber", name = "ToeCap"},
	}
	if tab then t[#t + 1] = sym{part = "LeftFoot", size = V(0.34, 0.7, 0.06), at = V(0, 0.15, 0.52), color = tab, cloth = "rubber", name = "HeelTab"} end
	return t
end
local RED, WHITE, STEEL, GOLD = rgb(205, 24, 48), rgb(236, 232, 226), rgb(172, 172, 178), rgb(200, 160, 64)
-- a chenille "M" letter patch (centre cx, cy in body units)
local function LETTER_M(cx, cy, color)
	return {
		{part = "UpperTorso", size = V(0.031, 0.177, 0.03), at = V(cx - 0.0515, cy, -0.508), color = color, cloth = "wool", name = "Letter"},
		{part = "UpperTorso", size = V(0.031, 0.177, 0.03), at = V(cx + 0.0515, cy, -0.508), color = color, cloth = "wool", name = "Letter"},
		{part = "UpperTorso", size = V(0.026, 0.12, 0.03), at = V(cx - 0.0258, cy + 0.035, -0.51), rot = V(0, 0, 29), color = color, cloth = "wool", name = "Letter"},
		{part = "UpperTorso", size = V(0.026, 0.12, 0.03), at = V(cx + 0.0258, cy + 0.035, -0.51), rot = V(0, 0, -29), color = color, cloth = "wool", name = "Letter"},
	}
end
local BONE = rgb(214, 204, 188)
local ROBE, ROBE_D, STOLE, ROPE = rgb(74, 64, 66), rgb(62, 54, 56), rgb(120, 18, 34), rgb(150, 124, 86)
local NAVY = rgb(36, 40, 74)

O.List = {
	{Id = "StreetTee", Name = "Street Tee", Price = 0,
		Blurb = "Washed charcoal tee, faded blue jeans and black trainers. Everyone starts here.",
		Wear = {torso = {rgb(82, 80, 86), "knit"}, upperArms = {rgb(82, 80, 86), "knit"}, waist = {rgb(84, 104, 140), "denim"},
			upperLegs = {rgb(84, 104, 140), "denim"}, lowerLegs = {rgb(84, 104, 140), "denim"}, feet = {rgb(34, 30, 32), "rubber"}},
		Details = flat{
		-- crew neck rib and sleeve hems
		{part = "UpperTorso", size = V(0.42, 0.06, 1.04), at = V(0, 0.47, 0), color = rgb(64, 62, 68), cloth = "knit", name = "Collar"},
		sym{part = "LeftUpperArm", size = V(1.06, 0.08, 1.06), at = V(0, -0.27, 0), color = rgb(70, 68, 74), cloth = "knit", name = "Cuff"},
		{part = "UpperTorso", size = V(1.03, 0.06, 1.05), at = V(0, -0.47, 0), color = rgb(70, 68, 74), cloth = "knit", name = "Hem"},
		-- small woven tag on the chest
		{part = "UpperTorso", size = V(0.09, 0.05, 0.03), at = V(-0.26, 0.22, -0.507), color = rgb(150, 18, 32), cloth = "knit", name = "Tag"},
		-- jeans: brown belt with a steel buckle, side seams, back pockets, turned-up hems
		{part = "LowerTorso", size = V(1.03, 0.3, 1.05), at = V(0, 0.28, 0), color = rgb(26, 22, 22), cloth = "leather", name = "Belt"},
		{part = "LowerTorso", size = V(0.075, 0.26, 0.05), at = V(0, 0.28, -0.53), color = STEEL, cloth = "metal", name = "Buckle"},
		sym{part = "LeftUpperLeg", size = V(0.02, 1.0, 0.06), at = V(-0.505, 0, 0), color = rgb(104, 124, 158), cloth = "denim", name = "Seam"},
		sym{part = "LeftLowerLeg", size = V(0.02, 0.84, 0.06), at = V(-0.505, 0.08, 0), color = rgb(104, 124, 158), cloth = "denim", name = "Seam"},
		sym{part = "LeftUpperLeg", size = V(0.56, 0.2, 0.03), at = V(0, 0.3, 0.505), color = rgb(64, 82, 114), cloth = "denim", name = "BackPocket"},
		sym{part = "LeftLowerLeg", size = V(1.05, 0.11, 1.05), at = V(0, -0.38, 0), color = rgb(104, 124, 158), cloth = "denim", name = "Turnup"},
		SNEAKER(rgb(232, 228, 222), rgb(48, 44, 46)),
	}},
	{Id = "BlackHoodie", Rarity = "Uncommon", Name = "MARKED Zip Hoodie", Price = 900,
		Blurb = "Black zip hoodie worn open over a white MARKED tee, red-taped sleeves, charcoal cargo joggers and chunky sneakers.",
		Wear = {torso = {rgb(30, 28, 34), "knit"}, upperArms = {rgb(30, 28, 34), "knit"}, lowerArms = {rgb(30, 28, 34), "knit"},
			waist = {rgb(80, 80, 88), "knit"}, upperLegs = {rgb(80, 80, 88), "knit"}, lowerLegs = {rgb(80, 80, 88), "knit"}, feet = {rgb(30, 28, 32), "rubber"}},
		Details = flat{
			HOOD_BACK(rgb(46, 44, 52), rgb(18, 16, 22), RED),
			{part = "UpperTorso", size = V(0.46, 0.06, 0.94), at = V(0, 0.48, -0.01), color = rgb(22, 20, 26), cloth = "knit", name = "NeckRib"},
			-- the open front: white tee with the red sigil, folded zip edges, white drawcords
			{part = "UpperTorso", size = V(0.3, 0.92, 0.04), at = V(0, 0.02, -0.508), color = WHITE, cloth = "knit", name = "Tee"},
			{part = "UpperTorso", size = V(0.16, 0.03, 0.045), at = V(0, 0.455, -0.51), color = rgb(214, 210, 204), cloth = "knit", name = "TeeNeck"},
			{part = "UpperTorso", size = V(0.1, 0, 0.03), at = V(0, 0.14, -0.53), color = RED, cloth = "knit", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.074, 0, 0.03), at = V(0, 0.14, -0.536), color = WHITE, cloth = "knit", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.14, 0.018, 0.03), at = V(0, 0.14, -0.542), color = RED, cloth = "knit", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.011, 0.16, 0.03), at = V(0, 0.14, -0.542), color = RED, cloth = "knit", name = "SigilBar"},
			sym{part = "UpperTorso", size = V(0.022, 0.94, 0.05), at = V(-0.16, 0.01, -0.515), color = rgb(22, 20, 26), cloth = "knit", name = "ZipEdge"},
			sym{part = "UpperTorso", size = V(0.007, 0.92, 0.055), at = V(-0.148, 0.01, -0.518), color = STEEL, cloth = "metal", name = "Zip"},
			{part = "UpperTorso", size = V(0.02, 0.05, 0.04), at = V(-0.148, -0.2, -0.545), color = RED, cloth = "rubber", name = "ZipPull"},
			sym{part = "UpperTorso", size = V(0.016, 0.26, 0.03), at = V(-0.19, 0.33, -0.53), color = WHITE, cloth = "knit", name = "Drawcord"},
			sym{part = "UpperTorso", size = V(0.024, 0.04, 0.04), at = V(-0.19, 0.19, -0.535), color = STEEL, cloth = "metal", name = "Aglet"},
			-- big sigil across the back
			{part = "UpperTorso", size = V(0.24, 0, 0.03), at = V(0, -0.13, 0.505), color = RED, cloth = "knit", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.18, 0, 0.03), at = V(0, -0.13, 0.512), color = rgb(30, 28, 34), cloth = "knit", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.34, 0.03, 0.03), at = V(0, -0.13, 0.52), color = RED, cloth = "knit", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.02, 0.42, 0.03), at = V(0, -0.13, 0.52), color = RED, cloth = "knit", name = "SigilBar"},
			-- red taping down the outside of the sleeves, ribbed cuffs and hem
			sym{part = "LeftUpperArm", size = V(0.03, 1.0, 0.1), at = V(-0.507, 0, 0), color = RED, cloth = "knit", name = "Tape"},
			sym{part = "LeftLowerArm", size = V(0.03, 0.8, 0.1), at = V(-0.507, 0.08, 0), color = RED, cloth = "knit", name = "Tape"},
			sym{part = "LeftLowerArm", size = V(1.05, 0.14, 1.05), at = V(0, -0.42, 0), color = rgb(22, 20, 26), cloth = "knit", name = "Cuff"},
			{part = "LowerTorso", size = V(1.04, 0.5, 1.06), at = V(0, 0.2, 0), color = rgb(22, 20, 26), cloth = "knit", name = "Hem"},
			-- cargo joggers: thigh pockets with flaps, a strap, knee panels, ribbed ankles
			sym{part = "LeftUpperLeg", size = V(0.06, 0.34, 0.5), at = V(-0.53, -0.1, 0), color = rgb(70, 70, 78), cloth = "knit", name = "Cargo"},
			sym{part = "LeftUpperLeg", size = V(0.07, 0.07, 0.52), at = V(-0.535, 0.09, 0), color = rgb(58, 58, 66), cloth = "knit", name = "CargoFlap"},
			sym{part = "LeftUpperLeg", size = V(0.075, 0.05, 0.08), at = V(-0.54, 0.05, 0), color = RED, cloth = "rubber", name = "PullTab"},
			{part = "LeftUpperLeg", size = V(1.05, 0.05, 1.05), at = V(0, 0.28, 0), color = rgb(18, 18, 22), cloth = "rubber", name = "Strap"},
			{part = "LeftUpperLeg", size = V(0.16, 0.08, 0.05), at = V(0, 0.28, -0.53), color = STEEL, cloth = "metal", name = "StrapBuckle"},
			sym{part = "LeftLowerLeg", size = V(0.8, 0.2, 0.03), at = V(0, 0.33, -0.505), color = rgb(70, 70, 78), cloth = "knit", name = "KneePanel"},
			sym{part = "LeftLowerLeg", size = V(1.05, 0.14, 1.05), at = V(0, -0.43, 0), color = rgb(30, 28, 34), cloth = "knit", name = "Ankle"},
			-- chunky sneakers: thick white sole, red heel tab
			sym{part = "LeftFoot", size = V(1.07, 0.45, 1.09), at = V(0, -0.29, 0), color = WHITE, cloth = "rubber", name = "Sole"},
			sym{part = "LeftFoot", size = V(1.075, 0.06, 1.095), at = V(0, -0.47, 0), color = rgb(30, 28, 32), cloth = "rubber", name = "Tread"},
			sym{part = "LeftFoot", size = V(0.34, 0.7, 0.06), at = V(0, 0.2, 0.52), color = RED, cloth = "rubber", name = "HeelTab"},
		}},
	{Id = "LeatherJacket", Rarity = "Rare", Name = "Biker Leather", Price = 1200,
		Blurb = "Black leather jacket over a red tee, faded jeans and boots.",
		Wear = {torso = {rgb(44, 40, 42), "leather"}, upperArms = {rgb(44, 40, 42), "leather"}, lowerArms = {rgb(44, 40, 42), "leather"},
			waist = {rgb(84, 104, 140), "denim"}, upperLegs = {rgb(84, 104, 140), "denim"}, lowerLegs = {rgb(84, 104, 140), "denim"}, feet = {rgb(28, 22, 20), "leather"}},
		Details = flat{
		-- red tee in the open front, jacket edges with steel zips, wide lapels and a collar
		{part = "UpperTorso", size = V(0.28, 0.88, 0.04), at = V(0, 0.02, -0.51), color = rgb(150, 18, 32), cloth = "knit", name = "Tee"},
		sym{part = "UpperTorso", size = V(0.012, 0.86, 0.05), at = V(-0.075, 0.01, -0.52), color = STEEL, cloth = "metal", name = "Zip"},
		{part = "UpperTorso", size = V(0.52, 0.07, 1.05), at = V(0, 0.47, 0), color = rgb(52, 48, 50), cloth = "leather", name = "Collar"},
		sym{part = "UpperTorso", size = V(0.16, 0.36, 0.05), at = V(-0.17, 0.3, -0.53), rot = V(0, 0, 18), color = rgb(54, 50, 52), cloth = "leather", name = "Lapel"},
		sym{part = "UpperTorso", size = V(0.03, 0, 0.04), at = V(-0.12, 0.17, -0.56), color = STEEL, cloth = "metal", name = "Snap", shape = "Disc"},
		-- diagonal zip pocket on the chest, belted hem with a buckle
		{part = "UpperTorso", size = V(0.01, 0.17, 0.045), at = V(0.3, 0.16, -0.515), rot = V(0, 0, -28), color = STEEL, cloth = "metal", name = "PocketZip"},
		{part = "UpperTorso", size = V(1.03, 0.08, 1.05), at = V(0, -0.46, 0), color = rgb(36, 32, 34), cloth = "leather", name = "HemBelt"},
		{part = "UpperTorso", size = V(0.07, 0.09, 0.05), at = V(-0.33, -0.46, -0.53), color = STEEL, cloth = "metal", name = "HemBuckle"},
		-- zipped cuffs
		sym{part = "LeftLowerArm", size = V(1.04, 0.07, 1.04), at = V(0, -0.44, 0), color = rgb(36, 32, 34), cloth = "leather", name = "Cuff"},
		sym{part = "LeftLowerArm", size = V(0.03, 0.26, 0.05), at = V(-0.505, -0.3, 0), color = STEEL, cloth = "metal", name = "CuffZip"},
		-- jeans: belt, side seams, turn-ups; boots
		{part = "LowerTorso", size = V(1.03, 0.3, 1.05), at = V(0, 0.28, 0), color = rgb(26, 22, 22), cloth = "leather", name = "Belt"},
		{part = "LowerTorso", size = V(0.075, 0.26, 0.05), at = V(0, 0.28, -0.53), color = STEEL, cloth = "metal", name = "Buckle"},
		sym{part = "LeftUpperLeg", size = V(0.02, 1.0, 0.06), at = V(-0.505, 0, 0), color = rgb(104, 124, 158), cloth = "denim", name = "Seam"},
		sym{part = "LeftLowerLeg", size = V(0.02, 0.84, 0.06), at = V(-0.505, 0.08, 0), color = rgb(104, 124, 158), cloth = "denim", name = "Seam"},
		sym{part = "LeftLowerLeg", size = V(1.05, 0.11, 1.05), at = V(0, -0.38, 0), color = rgb(104, 124, 158), cloth = "denim", name = "Turnup"},
		sym{part = "LeftFoot", size = V(1.05, 0.34, 1.07), at = V(0, -0.36, 0), color = rgb(14, 12, 12), cloth = "rubber", name = "Sole"},
		sym{part = "LeftFoot", size = V(1.04, 0.14, 1.04), at = V(0, 0.42, 0), color = rgb(40, 30, 26), cloth = "leather", name = "BootTop"},
	}},
	{Id = "Varsity", Rarity = "Rare", Name = "Crimson Varsity", Price = 1350,
		Blurb = "Crimson wool varsity jacket with bone leather sleeves and black jeans.",
		Wear = {torso = {rgb(150, 22, 40), "wool"}, upperArms = {rgb(234, 228, 216), "leather"}, lowerArms = {rgb(234, 228, 216), "leather"},
			waist = {rgb(32, 30, 36), "knit"}, upperLegs = {rgb(44, 44, 50), "denim"}, lowerLegs = {rgb(44, 44, 50), "denim"}, feet = {rgb(226, 222, 216), "rubber"}},
		Details = flat{
		-- striped rib collar, snap front, chenille M
		{part = "UpperTorso", size = V(0.5, 0.08, 1.06), at = V(0, 0.47, 0), color = rgb(30, 28, 34), cloth = "knit", name = "Collar"},
		{part = "UpperTorso", size = V(0.505, 0.018, 1.065), at = V(0, 0.47, 0), color = BONE, cloth = "knit", name = "CollarStripe"},
		{part = "UpperTorso", size = V(0.012, 0.9, 0.03), at = V(0, 0, -0.505), color = rgb(110, 14, 28), cloth = "wool", name = "Opening"},
		{part = "UpperTorso", size = V(0.03, 0, 0.04), at = V(0, 0.3, -0.52), color = BONE, cloth = "metal", name = "Snap", shape = "Disc"},
		{part = "UpperTorso", size = V(0.03, 0, 0.04), at = V(0, 0.1, -0.52), color = BONE, cloth = "metal", name = "Snap", shape = "Disc"},
		{part = "UpperTorso", size = V(0.03, 0, 0.04), at = V(0, -0.1, -0.52), color = BONE, cloth = "metal", name = "Snap", shape = "Disc"},
		{part = "UpperTorso", size = V(0.03, 0, 0.04), at = V(0, -0.3, -0.52), color = BONE, cloth = "metal", name = "Snap", shape = "Disc"},
		LETTER_M(-0.25, 0.16, BONE),
		-- crest on the back
		{part = "UpperTorso", size = V(0.26, 0, 0.03), at = V(0, 0.05, 0.505), color = BONE, cloth = "wool", name = "Crest", shape = "Disc"},
		{part = "UpperTorso", size = V(0.2, 0, 0.03), at = V(0, 0.05, 0.512), color = rgb(30, 28, 34), cloth = "wool", name = "CrestField", shape = "Disc"},
		{part = "UpperTorso", size = V(0.3, 0.03, 0.03), at = V(0, 0.05, 0.52), color = BONE, cloth = "wool", name = "CrestBar"},
		{part = "UpperTorso", size = V(0.018, 0.36, 0.03), at = V(0, 0.05, 0.52), color = BONE, cloth = "wool", name = "CrestBar"},
		-- striped rib cuffs and waistband
		sym{part = "LeftLowerArm", size = V(1.05, 0.14, 1.05), at = V(0, -0.42, 0), color = rgb(30, 28, 34), cloth = "knit", name = "Cuff"},
		sym{part = "LeftLowerArm", size = V(1.055, 0.02, 1.055), at = V(0, -0.4, 0), color = rgb(150, 22, 40), cloth = "knit", name = "CuffStripe"},
		{part = "LowerTorso", size = V(1.03, 0.55, 1.05), at = V(0, 0.17, 0), color = rgb(30, 28, 34), cloth = "knit", name = "Waistband"},
		{part = "LowerTorso", size = V(1.035, 0.08, 1.055), at = V(0, 0.22, 0), color = rgb(150, 22, 40), cloth = "knit", name = "WaistStripe"},
		{part = "LowerTorso", size = V(1.035, 0.08, 1.055), at = V(0, 0.06, 0), color = BONE, cloth = "knit", name = "WaistStripe"},
		-- black jeans and white sneakers
		sym{part = "LeftUpperLeg", size = V(0.02, 1.0, 0.06), at = V(-0.505, 0, 0), color = rgb(58, 58, 66), cloth = "denim", name = "Seam"},
		sym{part = "LeftLowerLeg", size = V(0.02, 0.84, 0.06), at = V(-0.505, 0.08, 0), color = rgb(58, 58, 66), cloth = "denim", name = "Seam"},
		SNEAKER(rgb(40, 38, 40), rgb(236, 232, 226), rgb(150, 22, 40)),
	}},
	{Id = "Academy", Rarity = "Uncommon", Name = "Academy Uniform", Price = 1050,
		Blurb = "Black double-breasted academy blazer with crimson piping, a gold crest and armband, striped tie, grey slacks and loafers.",
		Wear = {torso = {rgb(36, 34, 42), "wool"}, upperArms = {rgb(36, 34, 42), "wool"}, lowerArms = {rgb(36, 34, 42), "wool"},
			waist = {rgb(36, 34, 42), "wool"}, upperLegs = {rgb(84, 82, 92), "wool"}, lowerLegs = {rgb(84, 82, 92), "wool"}, feet = {rgb(24, 18, 16), "leather"}},
		Details = {
			-- shirt, collar points, striped tie
			d{part = "UpperTorso", size = Vector3.new(0.3, 0.42, 0.04), at = Vector3.new(0, 0.28, -0.51), color = rgb(238, 234, 228), cloth = "knit", name = "Shirt"},
			d{part = "UpperTorso", size = Vector3.new(0.07, 0.1, 0.05), at = Vector3.new(-0.055, 0.45, -0.525), rot = Vector3.new(0, 0, 35), color = rgb(238, 234, 228), cloth = "knit", name = "CollarPoint"},
			d{part = "UpperTorso", size = Vector3.new(0.07, 0.1, 0.05), at = Vector3.new(0.055, 0.45, -0.525), rot = Vector3.new(0, 0, -35), color = rgb(238, 234, 228), cloth = "knit", name = "CollarPoint"},
			-- tie: knot, a blade that widens towards the bottom and a pointed tip; the stripes stay inside the blade
			d{part = "UpperTorso", size = Vector3.new(0.055, 0.05, 0.06), at = Vector3.new(0, 0.435, -0.545), color = rgb(120, 10, 26), cloth = "knit", name = "TieKnot"},
			d{part = "UpperTorso", size = Vector3.new(0.045, 0.16, 0.05), at = Vector3.new(0, 0.33, -0.535), color = rgb(160, 16, 34), cloth = "knit", name = "Tie"},
			d{part = "UpperTorso", size = Vector3.new(0.062, 0.17, 0.05), at = Vector3.new(0, 0.17, -0.535), color = rgb(160, 16, 34), cloth = "knit", name = "Tie"},
			d{part = "UpperTorso", size = Vector3.new(0.032, 0.036, 0.05), at = Vector3.new(0, 0.085, -0.535), rot = Vector3.new(0, 0, 45), color = rgb(160, 16, 34), cloth = "knit", name = "TieTip"},
			d{part = "UpperTorso", size = Vector3.new(0.04, 0.014, 0.054), at = Vector3.new(0, 0.33, -0.538), rot = Vector3.new(0, 0, 25), color = rgb(26, 24, 30), cloth = "knit", name = "TieStripe"},
			d{part = "UpperTorso", size = Vector3.new(0.056, 0.014, 0.054), at = Vector3.new(0, 0.22, -0.538), rot = Vector3.new(0, 0, 25), color = rgb(26, 24, 30), cloth = "knit", name = "TieStripe"},
			d{part = "UpperTorso", size = Vector3.new(0.056, 0.014, 0.054), at = Vector3.new(0, 0.14, -0.538), rot = Vector3.new(0, 0, 25), color = rgb(26, 24, 30), cloth = "knit", name = "TieStripe"},
			-- lapels with crimson piping
			d{part = "UpperTorso", size = Vector3.new(0.14, 0.4, 0.07), at = Vector3.new(-0.2, 0.27, -0.52), rot = Vector3.new(0, 0, -20), color = rgb(44, 42, 52), cloth = "wool", name = "Lapel"},
			d{part = "UpperTorso", size = Vector3.new(0.14, 0.4, 0.07), at = Vector3.new(0.2, 0.27, -0.52), rot = Vector3.new(0, 0, 20), color = rgb(44, 42, 52), cloth = "wool", name = "Lapel"},
			d{part = "UpperTorso", size = Vector3.new(0.012, 0.42, 0.075), at = Vector3.new(-0.135, 0.27, -0.525), rot = Vector3.new(0, 0, -20), color = rgb(170, 18, 38), cloth = "knit", name = "Piping"},
			d{part = "UpperTorso", size = Vector3.new(0.012, 0.42, 0.075), at = Vector3.new(0.135, 0.27, -0.525), rot = Vector3.new(0, 0, 20), color = rgb(170, 18, 38), cloth = "knit", name = "Piping"},
			-- double-breasted gold buttons
			d{part = "UpperTorso", size = Vector3.new(0.035, 0.045, 0.05), at = Vector3.new(-0.11, -0.04, -0.52), color = rgb(200, 160, 64), cloth = "metal", name = "Button", shape = "Ball"},
			d{part = "UpperTorso", size = Vector3.new(0.035, 0.045, 0.05), at = Vector3.new(0.11, -0.04, -0.52), color = rgb(200, 160, 64), cloth = "metal", name = "Button", shape = "Ball"},
			d{part = "UpperTorso", size = Vector3.new(0.035, 0.045, 0.05), at = Vector3.new(-0.11, -0.22, -0.52), color = rgb(200, 160, 64), cloth = "metal", name = "Button", shape = "Ball"},
			d{part = "UpperTorso", size = Vector3.new(0.035, 0.045, 0.05), at = Vector3.new(0.11, -0.22, -0.52), color = rgb(200, 160, 64), cloth = "metal", name = "Button", shape = "Ball"},
			-- breast pocket: gold crest, pocket line, crimson pocket square
			d{part = "UpperTorso", size = Vector3.new(0.12, 0.012, 0.045), at = Vector3.new(-0.3, 0.33, -0.512), color = rgb(26, 24, 30), cloth = "wool", name = "PocketLine"},
			d{part = "UpperTorso", size = Vector3.new(0.07, 0.05, 0.04), at = Vector3.new(-0.3, 0.36, -0.515), color = rgb(170, 18, 38), cloth = "knit", name = "PocketSquare"},
			d{part = "UpperTorso", size = Vector3.new(0.09, 0, 0.03), at = Vector3.new(-0.3, 0.2, -0.505), color = rgb(200, 160, 64), cloth = "metal", name = "Crest", shape = "Disc"},
			d{part = "UpperTorso", size = Vector3.new(0.065, 0, 0.03), at = Vector3.new(-0.3, 0.2, -0.513), color = rgb(150, 14, 32), cloth = "knit", name = "CrestField", shape = "Disc"},
			d{part = "UpperTorso", size = Vector3.new(0.022, 0, 0.03), at = Vector3.new(-0.3, 0.2, -0.52), color = rgb(200, 160, 64), cloth = "metal", name = "CrestStar", shape = "Disc"},
			-- blazer skirt over the hips with a crimson hem
			d{part = "LowerTorso", size = Vector3.new(1.04, 1.6, 1.06), at = Vector3.new(0, -0.3, 0), color = rgb(36, 34, 42), cloth = "wool", name = "BlazerSkirt"},
			d{part = "LowerTorso", size = Vector3.new(1.045, 0.08, 1.065), at = Vector3.new(0, -1.06, 0), color = rgb(170, 18, 38), cloth = "knit", name = "HemPiping"},
			-- sleeve piping, prefect armband with gold edges
			d{part = "LeftLowerArm", size = Vector3.new(1.04, 0.05, 1.04), at = Vector3.new(0, -0.33, 0), color = rgb(170, 18, 38), cloth = "knit", name = "CuffPiping"},
			d{part = "RightLowerArm", size = Vector3.new(1.04, 0.05, 1.04), at = Vector3.new(0, -0.33, 0), color = rgb(170, 18, 38), cloth = "knit", name = "CuffPiping"},
			-- armband: snug round the middle of the upper arm (it used to sit up on the shoulder and stand off the sleeve)
			d{part = "LeftUpperArm", size = Vector3.new(1.03, 0.17, 1.03), at = Vector3.new(0, -0.06, 0), color = rgb(160, 16, 34), cloth = "knit", name = "Armband"},
			d{part = "LeftUpperArm", size = Vector3.new(1.036, 0.018, 1.036), at = Vector3.new(0, 0.025, 0), color = rgb(200, 160, 64), cloth = "metal", name = "ArmbandEdge"},
			d{part = "LeftUpperArm", size = Vector3.new(1.036, 0.018, 1.036), at = Vector3.new(0, -0.145, 0), color = rgb(200, 160, 64), cloth = "metal", name = "ArmbandEdge"},
			-- pressed slacks and loafers with a gold bit
			d{part = "LeftUpperLeg", size = Vector3.new(0.02, 0.98, 0.03), at = Vector3.new(0, 0, -0.505), color = rgb(110, 108, 118), cloth = "wool", name = "Crease"},
			d{part = "RightUpperLeg", size = Vector3.new(0.02, 0.98, 0.03), at = Vector3.new(0, 0, -0.505), color = rgb(110, 108, 118), cloth = "wool", name = "Crease"},
			d{part = "LeftLowerLeg", size = Vector3.new(0.02, 0.98, 0.03), at = Vector3.new(0, 0, -0.505), color = rgb(110, 108, 118), cloth = "wool", name = "Crease"},
			d{part = "RightLowerLeg", size = Vector3.new(0.02, 0.98, 0.03), at = Vector3.new(0, 0, -0.505), color = rgb(110, 108, 118), cloth = "wool", name = "Crease"},
			d{part = "LeftFoot", size = Vector3.new(1.04, 0.25, 1.06), at = Vector3.new(0, -0.4, 0), color = rgb(14, 12, 12), cloth = "rubber", name = "Sole"},
			d{part = "RightFoot", size = Vector3.new(1.04, 0.25, 1.06), at = Vector3.new(0, -0.4, 0), color = rgb(14, 12, 12), cloth = "rubber", name = "Sole"},
			d{part = "LeftFoot", size = Vector3.new(0.3, 0.14, 0.04), at = Vector3.new(0, 0.3, -0.5), color = rgb(200, 160, 64), cloth = "metal", name = "Bit"},
			d{part = "RightFoot", size = Vector3.new(0.3, 0.14, 0.04), at = Vector3.new(0, 0.3, -0.5), color = rgb(200, 160, 64), cloth = "metal", name = "Bit"},
		}},
	{Id = "TrenchCoat", Rarity = "Epic", Name = "Trench Coat", Price = 1500,
		Blurb = "Long belted wool trench coat, dark trousers, leather boots.",
		Wear = {torso = {rgb(124, 92, 62), "wool"}, waist = {rgb(124, 92, 62), "wool"}, upperArms = {rgb(124, 92, 62), "wool"}, lowerArms = {rgb(124, 92, 62), "wool"},
			upperLegs = {rgb(46, 44, 50), "wool"}, lowerLegs = {rgb(46, 44, 50), "wool"}, feet = {rgb(66, 44, 30), "leather"}},
		Details = flat{
		-- collar and wide lapels, storm flap, double-breasted buttons
		{part = "UpperTorso", size = V(0.56, 0.09, 1.08), at = V(0, 0.47, 0), color = rgb(92, 66, 44), cloth = "wool", name = "Collar"},
		sym{part = "UpperTorso", size = V(0.17, 0.4, 0.05), at = V(-0.19, 0.27, -0.525), rot = V(0, 0, 20), color = rgb(94, 68, 45), cloth = "wool", name = "Lapel"},
		sym{part = "UpperTorso", size = V(0.008, 0.4, 0.055), at = V(-0.148, 0.27, -0.53), rot = V(0, 0, 20), color = rgb(70, 50, 34), cloth = "wool", name = "LapelEdge"},
		{part = "UpperTorso", size = V(0.012, 0.62, 0.04), at = V(0.04, -0.19, -0.51), color = rgb(80, 58, 38), cloth = "wool", name = "Overlap"},
		{part = "UpperTorso", size = V(0.2, 0.2, 0.04), at = V(0.3, 0.3, -0.515), color = rgb(108, 79, 53), cloth = "wool", name = "StormFlap"},
		{part = "UpperTorso", size = V(0.2, 0.012, 0.045), at = V(0.3, 0.2, -0.515), color = rgb(80, 58, 38), cloth = "wool", name = "StormFlapEdge"},
		sym{part = "UpperTorso", size = V(0.04, 0, 0.04), at = V(-0.15, 0.04, -0.53), color = rgb(28, 20, 16), cloth = "leather", name = "Button", shape = "Disc"},
		sym{part = "UpperTorso", size = V(0.04, 0, 0.04), at = V(-0.15, -0.16, -0.53), color = rgb(28, 20, 16), cloth = "leather", name = "Button", shape = "Disc"},
		sym{part = "UpperTorso", size = V(0.04, 0, 0.04), at = V(-0.15, -0.36, -0.53), color = rgb(28, 20, 16), cloth = "leather", name = "Button", shape = "Disc"},
		-- epaulettes and strapped cuffs
		sym{part = "LeftUpperArm", size = V(0.36, 0.04, 1.03), at = V(0, 0.5, 0), color = rgb(110, 80, 54), cloth = "wool", name = "Epaulette"},
		sym{part = "LeftLowerArm", size = V(1.04, 0.08, 1.04), at = V(0, -0.3, 0), color = rgb(110, 80, 54), cloth = "wool", name = "CuffStrap"},
		sym{part = "LeftLowerArm", size = V(0.06, 0.08, 0.04), at = V(-0.2, -0.3, -0.525), color = rgb(28, 20, 16), cloth = "leather", name = "CuffBuckle"},
		-- belt with a steel-framed buckle and a hanging tail
		{part = "LowerTorso", size = V(1.06, 0.4, 1.1), at = V(0, 0.1, 0), color = rgb(104, 76, 50), cloth = "wool", name = "Belt"},
		{part = "LowerTorso", size = V(0.1, 0.5, 0.05), at = V(-0.06, 0.1, -0.565), color = rgb(150, 120, 70), cloth = "metal", name = "Buckle"},
		{part = "LowerTorso", size = V(0.06, 0.3, 0.06), at = V(-0.06, 0.1, -0.57), color = rgb(104, 76, 50), cloth = "wool", name = "BuckleBar"},
		{part = "LowerTorso", size = V(0.05, 1.5, 0.04), at = V(-0.12, -0.9, -0.565), color = rgb(104, 76, 50), cloth = "wool", name = "BeltTail"},
		-- long skirts of the coat: back with a vent, two fronts, closed sides
		{part = "LowerTorso", size = V(1.08, 4.4, 0.08), at = V(0, -2.6, 0.5), color = rgb(118, 86, 58), cloth = "wool", name = "Tail"},
		{part = "LowerTorso", size = V(0.01, 2.0, 0.09), at = V(0, -3.6, 0.505), color = rgb(90, 66, 44), cloth = "wool", name = "Vent"},
		sym{part = "LowerTorso", size = V(0.5, 4.2, 0.08), at = V(-0.27, -2.5, -0.53), rot = V(0, 0, -2), color = rgb(118, 86, 58), cloth = "wool", name = "Tail"},
		sym{part = "LowerTorso", size = V(0.05, 4.3, 1.04), at = V(-0.53, -2.55, 0), color = rgb(118, 86, 58), cloth = "wool", name = "TailSide"},
		sym{part = "LeftFoot", size = V(1.05, 0.3, 1.07), at = V(0, -0.37, 0), color = rgb(24, 16, 12), cloth = "rubber", name = "Sole"},
	}},
	{Id = "Techwear", Rarity = "Legendary", Name = "Night Techwear", Price = 1800,
		Blurb = "Black ripstop shell with a funnel collar and asymmetric zip, chest rig and pouches, tactical belt, holster pants and red-strapped boots.",
		Wear = {torso = {rgb(26, 26, 31), "shell"}, upperArms = {rgb(26, 26, 31), "shell"}, lowerArms = {rgb(26, 26, 31), "shell"},
			waist = {rgb(20, 20, 24), "shell"}, upperLegs = {rgb(36, 36, 42), "shell"}, lowerLegs = {rgb(36, 36, 42), "shell"}, feet = {rgb(20, 20, 22), "rubber"}},
		Details = {
			-- funnel collar and asymmetric storm flap with a red zip pull
			d{part = "UpperTorso", size = Vector3.new(0.6, 0.16, 1.16), at = Vector3.new(0, 0.55, 0), color = rgb(20, 20, 24), cloth = "shell", name = "FunnelCollar", hood = true},
			d{part = "UpperTorso", size = Vector3.new(0.12, 0.9, 0.05), at = Vector3.new(0.1, 0, -0.515), rot = Vector3.new(0, 0, 10), color = rgb(22, 22, 27), cloth = "shell", name = "StormFlap"},
			d{part = "UpperTorso", size = Vector3.new(0.012, 0.9, 0.06), at = Vector3.new(0.06, 0, -0.525), rot = Vector3.new(0, 0, 10), color = rgb(150, 150, 156), cloth = "metal", name = "Zip"},
			d{part = "UpperTorso", size = Vector3.new(0.03, 0.06, 0.07), at = Vector3.new(0.1, 0.42, -0.53), color = rgb(200, 22, 46), cloth = "rubber", name = "ZipPull"},
			-- chest rig: shoulder straps, band, buckle, two pouches with red tabs
			d{part = "UpperTorso", size = Vector3.new(0.06, 0.62, 1.06), at = Vector3.new(-0.28, 0.2, 0), color = rgb(8, 8, 10), cloth = "shell", name = "RigStrap"},
			d{part = "UpperTorso", size = Vector3.new(0.06, 0.62, 1.06), at = Vector3.new(0.28, 0.2, 0), color = rgb(8, 8, 10), cloth = "shell", name = "RigStrap"},
			d{part = "UpperTorso", size = Vector3.new(1.03, 0.1, 1.06), at = Vector3.new(0, -0.12, 0), color = rgb(8, 8, 10), cloth = "shell", name = "RigBand"},
			d{part = "UpperTorso", size = Vector3.new(0.1, 0.12, 0.08), at = Vector3.new(0, -0.12, -0.55), color = rgb(150, 150, 156), cloth = "metal", name = "RigBuckle"},
			d{part = "UpperTorso", size = Vector3.new(0.17, 0.22, 0.12), at = Vector3.new(-0.27, -0.12, -0.56), color = rgb(32, 32, 38), cloth = "shell", name = "Pouch"},
			d{part = "UpperTorso", size = Vector3.new(0.17, 0.22, 0.12), at = Vector3.new(0.27, -0.12, -0.56), color = rgb(32, 32, 38), cloth = "shell", name = "Pouch"},
			d{part = "UpperTorso", size = Vector3.new(0.05, 0.05, 0.04), at = Vector3.new(-0.27, -0.02, -0.625), color = rgb(200, 22, 46), cloth = "rubber", name = "PouchTab"},
			d{part = "UpperTorso", size = Vector3.new(0.05, 0.05, 0.04), at = Vector3.new(0.27, -0.02, -0.625), color = rgb(200, 22, 46), cloth = "rubber", name = "PouchTab"},
			-- back: slim sling pack with a red pull loop and a reflective strip
			d{part = "UpperTorso", size = Vector3.new(0.5, 0.55, 0.16), at = Vector3.new(0, 0.05, 0.58), color = rgb(30, 30, 36), cloth = "shell", name = "Pack"},
			d{part = "UpperTorso", size = Vector3.new(0.5, 0.04, 0.17), at = Vector3.new(0, 0.12, 0.585), color = rgb(200, 22, 46), cloth = "rubber", name = "PackStrip"},
			d{part = "UpperTorso", size = Vector3.new(0.08, 0.1, 0.05), at = Vector3.new(0, 0.36, 0.62), color = rgb(200, 22, 46), cloth = "rubber", name = "PackLoop"},
			-- arms: shoulder panels, red reflective band, sleeve patch, velcro cuffs (hands stay bare)
			d{part = "LeftUpperArm", size = Vector3.new(1.08, 0.22, 1.08), at = Vector3.new(0, 0.4, 0), color = rgb(20, 20, 24), cloth = "shell", name = "ShoulderPanel"},
			d{part = "RightUpperArm", size = Vector3.new(1.08, 0.22, 1.08), at = Vector3.new(0, 0.4, 0), color = rgb(20, 20, 24), cloth = "shell", name = "ShoulderPanel"},
			d{part = "LeftUpperArm", size = Vector3.new(1.05, 0.06, 1.05), at = Vector3.new(0, 0.05, 0), color = rgb(200, 22, 46), cloth = "rubber", name = "ReflectBand"},
			d{part = "RightUpperArm", size = Vector3.new(0.04, 0.22, 0.36), at = Vector3.new(0.52, 0.1, 0), color = rgb(190, 184, 176), cloth = "knit", name = "Patch"},
			d{part = "LeftLowerArm", size = Vector3.new(1.06, 0.16, 1.06), at = Vector3.new(0, -0.4, 0), color = rgb(26, 26, 31), cloth = "shell", name = "Cuff"},
			d{part = "RightLowerArm", size = Vector3.new(1.06, 0.16, 1.06), at = Vector3.new(0, -0.4, 0), color = rgb(26, 26, 31), cloth = "shell", name = "Cuff"},
			-- tactical belt with a dangling red strap
			d{part = "LowerTorso", size = Vector3.new(1.04, 0.5, 1.07), at = Vector3.new(0, 0.12, 0), color = rgb(8, 8, 10), cloth = "shell", name = "Belt"},
			d{part = "LowerTorso", size = Vector3.new(0.16, 0.45, 0.08), at = Vector3.new(0, 0.12, -0.55), color = rgb(150, 150, 156), cloth = "metal", name = "BeltBuckle"},
			d{part = "LowerTorso", size = Vector3.new(0.04, 1.4, 0.04), at = Vector3.new(0.3, -0.9, -0.55), color = rgb(200, 22, 46), cloth = "rubber", name = "HangStrap"},
			-- pants: thigh holster, cargo pocket, knee panels, red ankle straps
			d{part = "LeftUpperLeg", size = Vector3.new(0.16, 0.34, 0.5), at = Vector3.new(-0.56, -0.05, 0), color = rgb(26, 26, 31), cloth = "shell", name = "Holster"},
			d{part = "LeftUpperLeg", size = Vector3.new(1.05, 0.07, 1.05), at = Vector3.new(0, 0.1, 0), color = rgb(8, 8, 10), cloth = "shell", name = "HolsterStrap"},
			d{part = "RightUpperLeg", size = Vector3.new(0.14, 0.3, 0.46), at = Vector3.new(0.55, -0.08, 0), color = rgb(32, 32, 38), cloth = "shell", name = "Cargo"},
			d{part = "LeftLowerLeg", size = Vector3.new(0.82, 0.28, 0.06), at = Vector3.new(0, 0.33, -0.52), color = rgb(36, 36, 42), cloth = "shell", name = "KneePanel"},
			d{part = "RightLowerLeg", size = Vector3.new(0.82, 0.28, 0.06), at = Vector3.new(0, 0.33, -0.52), color = rgb(36, 36, 42), cloth = "shell", name = "KneePanel"},
			d{part = "LeftLowerLeg", size = Vector3.new(1.05, 0.07, 1.05), at = Vector3.new(0, -0.38, 0), color = rgb(200, 22, 46), cloth = "rubber", name = "AnkleStrap"},
			d{part = "RightLowerLeg", size = Vector3.new(1.05, 0.07, 1.05), at = Vector3.new(0, -0.38, 0), color = rgb(200, 22, 46), cloth = "rubber", name = "AnkleStrap"},
			-- boots: grey lug soles, toe caps
			d{part = "LeftFoot", size = Vector3.new(1.05, 0.35, 1.07), at = Vector3.new(0, -0.34, 0), color = rgb(70, 70, 76), cloth = "rubber", name = "Sole"},
			d{part = "RightFoot", size = Vector3.new(1.05, 0.35, 1.07), at = Vector3.new(0, -0.34, 0), color = rgb(70, 70, 76), cloth = "rubber", name = "Sole"},
			d{part = "LeftFoot", size = Vector3.new(0.9, 0.6, 0.1), at = Vector3.new(0, 0.1, -0.5), color = rgb(30, 30, 34), cloth = "rubber", name = "ToeCap"},
			d{part = "RightFoot", size = Vector3.new(0.9, 0.6, 0.1), at = Vector3.new(0, 0.1, -0.5), color = rgb(30, 30, 34), cloth = "rubber", name = "ToeCap"},
		}},
	{Id = "ScribeRobe", Rarity = "Epic", Name = "Scribe Robe", Price = 1650,
		Blurb = "The hooded robe of the city's stone scribes, with a rope belt.",
		Wear = {torso = {rgb(74, 64, 66), "wool"}, waist = {rgb(74, 64, 66), "wool"}, upperArms = {rgb(74, 64, 66), "wool"}, lowerArms = {rgb(74, 64, 66), "wool"},
			upperLegs = {rgb(74, 64, 66), "wool"}, lowerLegs = {rgb(74, 64, 66), "wool"}, feet = {rgb(30, 24, 22), "leather"}},
		Details = flat{
		HOOD(rgb(66, 58, 60), rgb(64, 56, 58), "wool"),
		-- crimson stole down the front
		sym{part = "UpperTorso", size = V(0.1, 1.0, 0.04), at = V(-0.16, 0, -0.51), color = STOLE, cloth = "wool", name = "Stole"},
		sym{part = "LowerTorso", size = V(0.1, 5.4, 0.05), at = V(-0.16, -3.2, -0.535), color = STOLE, cloth = "wool", name = "Stole"},
		-- rope belt, knot and two tasselled ends
		{part = "LowerTorso", size = V(1.08, 0.3, 1.1), at = V(0, 0.1, 0), color = ROPE, cloth = "knit", name = "Rope"},
		{part = "LowerTorso", size = V(0.06, 0.4, 0.06), at = V(0.18, 0.1, -0.56), color = ROPE, cloth = "knit", name = "Knot"},
		{part = "LowerTorso", size = V(0.025, 2.2, 0.04), at = V(0.16, -1.1, -0.57), color = ROPE, cloth = "knit", name = "RopeEnd"},
		{part = "LowerTorso", size = V(0.025, 1.8, 0.04), at = V(0.2, -0.9, -0.57), color = ROPE, cloth = "knit", name = "RopeEnd"},
		{part = "LowerTorso", size = V(0.04, 0.4, 0.05), at = V(0.16, -2.3, -0.57), color = STOLE, cloth = "knit", name = "Tassel"},
		{part = "LowerTorso", size = V(0.04, 0.4, 0.05), at = V(0.2, -1.9, -0.57), color = STOLE, cloth = "knit", name = "Tassel"},
		-- the robe falls closed to the ankles all round, a darker hem band
		{part = "LowerTorso", size = V(1.1, 5.6, 0.1), at = V(0, -3.3, 0.49), color = ROBE, cloth = "wool", name = "Robe"},
		{part = "LowerTorso", size = V(1.1, 5.6, 0.1), at = V(0, -3.3, -0.5), color = ROBE, cloth = "wool", name = "Robe"},
		sym{part = "LowerTorso", size = V(0.05, 5.6, 1.05), at = V(-0.54, -3.3, 0), color = ROBE, cloth = "wool", name = "RobeSide"},
		{part = "LowerTorso", size = V(1.12, 0.3, 0.11), at = V(0, -5.95, -0.505), color = ROBE_D, cloth = "wool", name = "RobeHem"},
		{part = "LowerTorso", size = V(1.12, 0.3, 0.11), at = V(0, -5.95, 0.495), color = ROBE_D, cloth = "wool", name = "RobeHem"},
		-- wide bell sleeves with a crimson edge
		sym{part = "LeftLowerArm", size = V(1.16, 0.56, 1.16), at = V(0, -0.16, 0), color = ROBE, cloth = "wool", name = "Sleeve"},
		sym{part = "LeftLowerArm", size = V(1.3, 0.2, 1.3), at = V(0, -0.4, 0), color = ROBE_D, cloth = "wool", name = "SleeveBell"},
		sym{part = "LeftLowerArm", size = V(1.32, 0.05, 1.32), at = V(0, -0.49, 0), color = STOLE, cloth = "wool", name = "SleeveEdge"},
	}},
	-- ---- skirts and dresses (the skirt is panels hung from the hips: a flared, pleated ring)
	{Id = "SailorUniform", Rarity = "Rare", Name = "Sailor Uniform", Price = 1350,
		Blurb = "White sailor blouse with a navy collar and red neckerchief, a pleated navy skirt, white knee socks and loafers.",
		Wear = {torso = {rgb(236, 232, 226), "knit"}, upperArms = {rgb(236, 232, 226), "knit"}, waist = {rgb(36, 40, 74), "wool"},
			lowerLegs = {rgb(240, 238, 234), "knit"}, feet = {rgb(24, 18, 16), "leather"}},
		Details = flat{
		-- navy sailor collar: over the shoulders, a square flap down the back, a V down the front; white stripes
		{part = "UpperTorso", size = V(0.92, 0.03, 1.02), at = V(0, 0.5, 0), color = NAVY, cloth = "wool", name = "Collar"},
		{part = "UpperTorso", size = V(0.84, 0.48, 0.03), at = V(0, 0.26, 0.512), color = NAVY, cloth = "wool", name = "CollarBack"},
		{part = "UpperTorso", size = V(0.78, 0.016, 0.035), at = V(0, 0.07, 0.515), color = WHITE, cloth = "knit", name = "CollarStripe"},
		{part = "UpperTorso", size = V(0.74, 0.016, 0.035), at = V(0, 0.1, 0.515), color = WHITE, cloth = "knit", name = "CollarStripe"},
		sym{part = "UpperTorso", size = V(0.008, 0.42, 0.035), at = V(-0.385, 0.29, 0.515), color = WHITE, cloth = "knit", name = "CollarStripe"},
		sym{part = "UpperTorso", size = V(0.008, 0.39, 0.035), at = V(-0.365, 0.305, 0.515), color = WHITE, cloth = "knit", name = "CollarStripe"},
		sym{part = "UpperTorso", size = V(0.11, 0.5, 0.03), at = V(-0.22, 0.28, -0.512), rot = V(0, 0, 46), color = NAVY, cloth = "wool", name = "CollarFront"},
		sym{part = "UpperTorso", size = V(0.008, 0.46, 0.035), at = V(-0.245, 0.25, -0.515), rot = V(0, 0, 46), color = WHITE, cloth = "knit", name = "CollarStripe"},
		sym{part = "UpperTorso", size = V(0.008, 0.46, 0.035), at = V(-0.233, 0.265, -0.515), rot = V(0, 0, 46), color = WHITE, cloth = "knit", name = "CollarStripe"},
		-- red neckerchief: knot at the bottom of the V and two tails
		{part = "UpperTorso", size = V(0.06, 0.06, 0.05), at = V(0, 0.09, -0.53), rot = V(0, 0, 45), color = rgb(176, 16, 36), cloth = "knit", name = "Knot"},
		sym{part = "UpperTorso", size = V(0.04, 0.16, 0.03), at = V(-0.03, -0.04, -0.52), rot = V(0, 0, -12), color = RED, cloth = "knit", name = "Tail"},
		-- puff sleeve bands: navy with a white stripe
		sym{part = "LeftUpperArm", size = V(1.08, 0.1, 1.08), at = V(0, -0.27, 0), color = NAVY, cloth = "wool", name = "Cuff"},
		sym{part = "LeftUpperArm", size = V(1.085, 0.018, 1.085), at = V(0, -0.27, 0), color = WHITE, cloth = "knit", name = "CuffStripe"},
		-- knee socks and loafers
		sym{part = "LeftLowerLeg", size = V(1.05, 0.1, 1.05), at = V(0, 0.42, 0), color = NAVY, cloth = "knit", name = "SockBand"},
		sym{part = "LeftFoot", size = V(1.04, 0.25, 1.06), at = V(0, -0.4, 0), color = rgb(12, 10, 10), cloth = "rubber", name = "Sole"},
		sym{part = "LeftFoot", size = V(0.7, 0.18, 0.04), at = V(0, 0.28, -0.505), color = rgb(40, 30, 26), cloth = "leather", name = "Strap"},
		O_SKIRT(NAVY, rgb(30, 33, 64), "wool", 0.95, WHITE),
	}},
	-- (redesigned in the clean style of the sailor uniform: fitted pieces and thin trims, nothing boxy standing off the body)
	{Id = "GothicDress", Rarity = "Epic", Name = "Gothic Lolita", Price = 1800,
		Blurb = "Black puff-sleeve dress with a white peter-pan collar, a crimson ribbon and lacing, a pleated skirt edged in white lace, over-knee stockings and Mary Janes.",
		Wear = {torso = {rgb(26, 22, 30), "knit"}, upperArms = {rgb(26, 22, 30), "knit"}, lowerArms = {rgb(26, 22, 30), "knit"}, waist = {rgb(26, 22, 30), "knit"},
			upperLegs = {rgb(20, 18, 22), "knit"}, lowerLegs = {rgb(20, 18, 22), "knit"}, feet = {rgb(14, 12, 14), "leather"}},
		Details = (function()
			local t = {
				-- white peter-pan collar with rounded points at the front
				d{part = "UpperTorso", size = Vector3.new(0.86, 0.09, 1.06), at = Vector3.new(0, 0.45, 0), color = rgb(238, 234, 228), cloth = "knit", name = "Collar"},
				d{part = "UpperTorso", size = Vector3.new(0.12, 0, 0.04), at = Vector3.new(-0.12, 0.37, -0.52), color = rgb(238, 234, 228), cloth = "knit", name = "CollarPoint", shape = "Disc"},
				d{part = "UpperTorso", size = Vector3.new(0.12, 0, 0.04), at = Vector3.new(0.12, 0.37, -0.52), color = rgb(238, 234, 228), cloth = "knit", name = "CollarPoint", shape = "Disc"},
				-- crimson ribbon at the throat
				d{part = "UpperTorso", size = Vector3.new(0.08, 0.07, 0.06), at = Vector3.new(0, 0.33, -0.56), color = rgb(176, 16, 36), cloth = "knit", name = "Knot"},
				d{part = "UpperTorso", size = Vector3.new(0.07, 0, 0.04), at = Vector3.new(-0.065, 0.33, -0.545), color = rgb(196, 20, 42), cloth = "knit", name = "Loop", shape = "Disc"},
				d{part = "UpperTorso", size = Vector3.new(0.07, 0, 0.04), at = Vector3.new(0.065, 0.33, -0.545), color = rgb(196, 20, 42), cloth = "knit", name = "Loop", shape = "Disc"},
				d{part = "UpperTorso", size = Vector3.new(0.05, 0.16, 0.04), at = Vector3.new(-0.035, 0.22, -0.55), rot = Vector3.new(0, 0, 14), color = rgb(176, 16, 36), cloth = "knit", name = "Tail"},
				d{part = "UpperTorso", size = Vector3.new(0.05, 0.16, 0.04), at = Vector3.new(0.035, 0.22, -0.55), rot = Vector3.new(0, 0, -14), color = rgb(176, 16, 36), cloth = "knit", name = "Tail"},
				-- bodice lacing: crimson criss-cross down the front
				d{part = "UpperTorso", size = Vector3.new(0.14, 0.02, 0.03), at = Vector3.new(0, 0.06, -0.515), rot = Vector3.new(0, 0, 32), color = rgb(176, 16, 36), cloth = "knit", name = "Lace"},
				d{part = "UpperTorso", size = Vector3.new(0.14, 0.02, 0.03), at = Vector3.new(0, 0.06, -0.515), rot = Vector3.new(0, 0, -32), color = rgb(176, 16, 36), cloth = "knit", name = "Lace"},
				d{part = "UpperTorso", size = Vector3.new(0.14, 0.02, 0.03), at = Vector3.new(0, -0.08, -0.515), rot = Vector3.new(0, 0, 32), color = rgb(176, 16, 36), cloth = "knit", name = "Lace"},
				d{part = "UpperTorso", size = Vector3.new(0.14, 0.02, 0.03), at = Vector3.new(0, -0.08, -0.515), rot = Vector3.new(0, 0, -32), color = rgb(176, 16, 36), cloth = "knit", name = "Lace"},
				d{part = "UpperTorso", size = Vector3.new(0.14, 0.02, 0.03), at = Vector3.new(0, -0.22, -0.515), rot = Vector3.new(0, 0, 32), color = rgb(176, 16, 36), cloth = "knit", name = "Lace"},
				d{part = "UpperTorso", size = Vector3.new(0.14, 0.02, 0.03), at = Vector3.new(0, -0.22, -0.515), rot = Vector3.new(0, 0, -32), color = rgb(176, 16, 36), cloth = "knit", name = "Lace"},
				-- crimson waist sash with a bow at the back
				d{part = "UpperTorso", size = Vector3.new(1.03, 0.09, 1.05), at = Vector3.new(0, -0.44, 0), color = rgb(150, 14, 32), cloth = "knit", name = "Sash"},
				d{part = "UpperTorso", size = Vector3.new(0.1, 0, 0.05), at = Vector3.new(-0.08, -0.42, 0.53), color = rgb(150, 14, 32), cloth = "knit", name = "Bow", shape = "Disc"},
				d{part = "UpperTorso", size = Vector3.new(0.1, 0, 0.05), at = Vector3.new(0.08, -0.42, 0.53), color = rgb(150, 14, 32), cloth = "knit", name = "Bow", shape = "Disc"},
				d{part = "UpperTorso", size = Vector3.new(0.05, 0.1, 0.07), at = Vector3.new(0, -0.42, 0.54), color = rgb(130, 12, 28), cloth = "knit", name = "BowKnot"},
				d{part = "UpperTorso", size = Vector3.new(0.04, 0.22, 0.04), at = Vector3.new(-0.04, -0.55, 0.53), rot = Vector3.new(0, 0, -10), color = rgb(150, 14, 32), cloth = "knit", name = "BowTail"},
				d{part = "UpperTorso", size = Vector3.new(0.04, 0.22, 0.04), at = Vector3.new(0.04, -0.55, 0.53), rot = Vector3.new(0, 0, 10), color = rgb(150, 14, 32), cloth = "knit", name = "BowTail"},
				-- puff-sleeve bands and white lace cuffs at the wrist
				d{part = "LeftUpperArm", size = Vector3.new(1.08, 0.1, 1.08), at = Vector3.new(0, -0.27, 0), color = rgb(238, 234, 228), cloth = "knit", name = "Cuff"},
				d{part = "RightUpperArm", size = Vector3.new(1.08, 0.1, 1.08), at = Vector3.new(0, -0.27, 0), color = rgb(238, 234, 228), cloth = "knit", name = "Cuff"},
				d{part = "LeftLowerArm", size = Vector3.new(1.06, 0.1, 1.06), at = Vector3.new(0, -0.43, 0), color = rgb(238, 234, 228), cloth = "knit", name = "Cuff"},
				d{part = "RightLowerArm", size = Vector3.new(1.06, 0.1, 1.06), at = Vector3.new(0, -0.43, 0), color = rgb(238, 234, 228), cloth = "knit", name = "Cuff"},
				-- over-knee stockings: a thin crimson band at the top
				d{part = "LeftUpperLeg", size = Vector3.new(1.04, 0.06, 1.04), at = Vector3.new(0, -0.08, 0), color = rgb(150, 14, 32), cloth = "knit", name = "StockingBand"},
				d{part = "RightUpperLeg", size = Vector3.new(1.04, 0.06, 1.04), at = Vector3.new(0, -0.08, 0), color = rgb(150, 14, 32), cloth = "knit", name = "StockingBand"},
				-- Mary Janes: sole and a strap over the instep
				d{part = "LeftFoot", size = Vector3.new(1.04, 0.25, 1.06), at = Vector3.new(0, -0.4, 0), color = rgb(8, 6, 8), cloth = "rubber", name = "Sole"},
				d{part = "RightFoot", size = Vector3.new(1.04, 0.25, 1.06), at = Vector3.new(0, -0.4, 0), color = rgb(8, 6, 8), cloth = "rubber", name = "Sole"},
				d{part = "LeftFoot", size = Vector3.new(1.05, 0.08, 0.3), at = Vector3.new(0, 0.12, -0.1), color = rgb(150, 14, 32), cloth = "leather", name = "Strap"},
				d{part = "RightFoot", size = Vector3.new(1.05, 0.08, 0.3), at = Vector3.new(0, 0.12, -0.1), color = rgb(150, 14, 32), cloth = "leather", name = "Strap"},
			}
			for _, p in ipairs(O_SKIRT(rgb(26, 22, 30), rgb(38, 32, 42), "knit", 0.95, rgb(238, 234, 228), 1.15)) do t[#t + 1] = p end
			return t
		end)()},
	{Id = "CropHoodieSkirt", Rarity = "Rare", Name = "Night Bomber", Price = 1350,
		Blurb = "Black bomber jacket with a red lining and a red sigil on the back, open over a white tee, wide stone cargo pants and black combat boots.",
		Wear = {torso = {rgb(26, 27, 30), "shell"}, upperArms = {rgb(26, 27, 30), "shell"}, lowerArms = {rgb(26, 27, 30), "shell"},
			waist = {rgb(178, 160, 128), "wool"}, upperLegs = {rgb(178, 160, 128), "wool"}, lowerLegs = {rgb(178, 160, 128), "wool"}, feet = {rgb(20, 20, 22), "leather"}},
		Details = flat{
			-- rib collar, the open front: white tee, red lining along the edges, steel zips
			{part = "UpperTorso", size = V(0.5, 0.08, 1.06), at = V(0, 0.47, 0), color = rgb(18, 18, 22), cloth = "knit", name = "Collar"},
			{part = "UpperTorso", size = V(0.26, 0.92, 0.04), at = V(0, 0.02, -0.508), color = WHITE, cloth = "knit", name = "Tee"},
			{part = "UpperTorso", size = V(0.14, 0.03, 0.045), at = V(0, 0.455, -0.51), color = rgb(214, 210, 204), cloth = "knit", name = "TeeNeck"},
			sym{part = "UpperTorso", size = V(0.02, 0.92, 0.05), at = V(-0.14, 0.01, -0.514), color = rgb(176, 18, 36), cloth = "knit", name = "Lining"},
			sym{part = "UpperTorso", size = V(0.007, 0.9, 0.055), at = V(-0.153, 0.01, -0.518), color = STEEL, cloth = "metal", name = "Zip"},
			-- red sigil embroidered across the back
			{part = "UpperTorso", size = V(0.26, 0, 0.03), at = V(0, 0.04, 0.505), color = RED, cloth = "knit", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.2, 0, 0.03), at = V(0, 0.04, 0.512), color = rgb(26, 27, 30), cloth = "shell", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.36, 0.03, 0.03), at = V(0, 0.04, 0.52), color = RED, cloth = "knit", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.02, 0.44, 0.03), at = V(0, 0.04, 0.52), color = RED, cloth = "knit", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.04, 0, 0.03), at = V(0, 0.04, 0.528), color = RED, cloth = "knit", name = "SigilDot", shape = "Disc"},
			-- utility pocket on the left sleeve with a red pull, rib cuffs and a rib hem with a red stripe
			{part = "LeftUpperArm", size = V(0.05, 0.26, 0.36), at = V(-0.52, 0.06, 0), color = rgb(34, 35, 38), cloth = "shell", name = "SleevePocket"},
			{part = "LeftUpperArm", size = V(0.055, 0.02, 0.3), at = V(-0.525, 0.15, 0), color = STEEL, cloth = "metal", name = "PocketZip"},
			{part = "LeftUpperArm", size = V(0.06, 0.05, 0.04), at = V(-0.53, 0.15, -0.12), color = RED, cloth = "rubber", name = "PocketPull"},
			sym{part = "LeftLowerArm", size = V(1.05, 0.16, 1.05), at = V(0, -0.41, 0), color = rgb(18, 18, 22), cloth = "knit", name = "Cuff"},
			{part = "LowerTorso", size = V(1.04, 0.55, 1.06), at = V(0, 0.19, 0), color = rgb(18, 18, 22), cloth = "knit", name = "Hem"},
			{part = "LowerTorso", size = V(1.045, 0.06, 1.065), at = V(0, 0.08, 0), color = rgb(176, 18, 36), cloth = "knit", name = "HemStripe"},
			-- wide stone cargos: deep thigh pockets, wide hems over the boots
			sym{part = "LeftUpperLeg", size = V(0.07, 0.4, 0.56), at = V(-0.54, -0.12, 0), color = rgb(164, 146, 116), cloth = "wool", name = "Cargo"},
			sym{part = "LeftUpperLeg", size = V(0.08, 0.08, 0.58), at = V(-0.545, 0.1, 0), color = rgb(150, 134, 106), cloth = "wool", name = "CargoFlap"},
			sym{part = "LeftUpperLeg", size = V(0.02, 1.0, 0.06), at = V(0, 0, -0.505), color = rgb(156, 138, 108), cloth = "wool", name = "Crease"},
			sym{part = "LeftLowerLeg", size = V(0.02, 0.9, 0.06), at = V(0, 0.05, -0.505), color = rgb(156, 138, 108), cloth = "wool", name = "Crease"},
			sym{part = "LeftLowerLeg", size = V(1.12, 0.3, 1.12), at = V(0, -0.36, 0), color = rgb(178, 160, 128), cloth = "wool", name = "WideHem"},
			-- black combat boots
			sym{part = "LeftFoot", size = V(1.07, 0.4, 1.09), at = V(0, -0.31, 0), color = rgb(14, 14, 16), cloth = "rubber", name = "Sole"},
			sym{part = "LeftFoot", size = V(0.4, 0.4, 0.04), at = V(0, 0.22, -0.51), color = rgb(40, 40, 44), cloth = "leather", name = "Tongue"},
		}},
	{Id = "SummerDress", Rarity = "Uncommon", Name = "Tartan Pinafore", Price = 1050,
		Blurb = "Black and red tartan pinafore with buckled straps over a white shirt and red ribbon, a chain at the hip, thigh-high socks and platform boots.",
		Wear = {torso = {rgb(26, 24, 30), "wool"}, upperArms = {rgb(238, 234, 228), "knit"}, lowerArms = {rgb(238, 234, 228), "knit"},
			waist = {rgb(26, 24, 30), "wool"}, lowerLegs = {rgb(20, 18, 22), "knit"}, feet = {rgb(16, 14, 16), "leather"}},
		Details = flat{
			-- white shirt in the square neckline: collar points, red ribbon bow
			{part = "UpperTorso", size = V(0.66, 0.2, 0.04), at = V(0, 0.4, -0.506), color = rgb(238, 234, 228), cloth = "knit", name = "Shirt"},
			{part = "UpperTorso", size = V(0.94, 0.02, 1.0), at = V(0, 0.5, 0), color = rgb(238, 234, 228), cloth = "knit", name = "ShirtShoulders"},
			{part = "UpperTorso", size = V(0.66, 0.2, 0.04), at = V(0, 0.4, 0.506), color = rgb(238, 234, 228), cloth = "knit", name = "Shirt"},
			sym{part = "UpperTorso", size = V(0.08, 0.1, 0.05), at = V(-0.055, 0.44, -0.522), rot = V(0, 0, 35), color = rgb(244, 240, 234), cloth = "knit", name = "CollarPoint"},
			sym{part = "UpperTorso", size = V(0.06, 0, 0.04), at = V(-0.05, 0.37, -0.54), color = rgb(176, 16, 36), cloth = "knit", name = "Bow", shape = "Disc"},
			{part = "UpperTorso", size = V(0.035, 0.05, 0.06), at = V(0, 0.37, -0.545), color = rgb(150, 12, 30), cloth = "knit", name = "BowKnot"},
			sym{part = "UpperTorso", size = V(0.03, 0.12, 0.04), at = V(-0.025, 0.29, -0.54), rot = V(0, 0, -12), color = rgb(176, 16, 36), cloth = "knit", name = "BowTail"},
			-- the pinafore's straps over the shoulders with steel rings
			sym{part = "UpperTorso", size = V(0.1, 0.21, 0.045), at = V(-0.25, 0.4, -0.51), color = rgb(26, 24, 30), cloth = "wool", name = "Strap"},
			sym{part = "UpperTorso", size = V(0.1, 0.21, 0.045), at = V(-0.25, 0.4, 0.51), color = rgb(26, 24, 30), cloth = "wool", name = "Strap"},
			sym{part = "UpperTorso", size = V(0.1, 0.03, 1.03), at = V(-0.25, 0.5, 0), color = rgb(26, 24, 30), cloth = "wool", name = "Strap"},
			sym{part = "UpperTorso", size = V(0.055, 0, 0.04), at = V(-0.25, 0.3, -0.535), color = STEEL, cloth = "metal", name = "Ring", shape = "Disc"},
			sym{part = "UpperTorso", size = V(0.03, 0, 0.04), at = V(-0.25, 0.3, -0.54), color = rgb(26, 24, 30), cloth = "wool", name = "RingHole", shape = "Disc"},
			-- tartan on the bodice: red lines across and down, a fine bone line
			sym{part = "UpperTorso", size = V(0.012, 0.68, 0.03), at = V(-0.13, -0.16, -0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			sym{part = "UpperTorso", size = V(0.012, 0.68, 0.03), at = V(-0.38, -0.16, -0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			{part = "UpperTorso", size = V(1.0, 0.02, 0.03), at = V(0, 0.08, -0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			{part = "UpperTorso", size = V(1.0, 0.02, 0.03), at = V(0, -0.22, -0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			{part = "UpperTorso", size = V(1.0, 0.008, 0.032), at = V(0, -0.07, -0.506), color = rgb(190, 182, 170), cloth = "wool", name = "Tartan"},
			sym{part = "UpperTorso", size = V(0.012, 0.68, 0.03), at = V(-0.13, -0.16, 0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			sym{part = "UpperTorso", size = V(0.012, 0.68, 0.03), at = V(-0.38, -0.16, 0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			{part = "UpperTorso", size = V(1.0, 0.02, 0.03), at = V(0, 0.08, 0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			{part = "UpperTorso", size = V(1.0, 0.02, 0.03), at = V(0, -0.22, 0.505), color = rgb(150, 20, 36), cloth = "wool", name = "Tartan"},
			{part = "UpperTorso", size = V(1.0, 0.008, 0.032), at = V(0, -0.07, 0.506), color = rgb(190, 182, 170), cloth = "wool", name = "Tartan"},
			-- belt with a buckle and a steel chain swagged at the hip
			{part = "UpperTorso", size = V(1.035, 0.07, 1.055), at = V(0, -0.46, 0), color = rgb(14, 12, 14), cloth = "leather", name = "Belt"},
			{part = "UpperTorso", size = V(0.07, 0.08, 0.05), at = V(0, -0.46, -0.535), color = STEEL, cloth = "metal", name = "Buckle"},
			{part = "UpperTorso", size = V(0.148, 0.012, 0.02), at = V(0.185, -0.55, -0.6), rot = V(0, 0, -28), color = STEEL, cloth = "metal", name = "Chain"},
			{part = "UpperTorso", size = V(0.148, 0.012, 0.02), at = V(0.315, -0.55, -0.6), rot = V(0, 0, 28), color = STEEL, cloth = "metal", name = "Chain"},
			-- shirt cuffs with a black band
			sym{part = "LeftLowerArm", size = V(1.05, 0.05, 1.05), at = V(0, -0.38, 0), color = rgb(26, 24, 30), cloth = "knit", name = "CuffBand"},
			-- thigh-high socks with a red band, platform boots
			sym{part = "LeftUpperLeg", size = V(1.03, 0.45, 1.03), at = V(0, -0.28, 0), color = rgb(20, 18, 22), cloth = "knit", name = "ThighHigh"},
			sym{part = "LeftUpperLeg", size = V(1.045, 0.04, 1.045), at = V(0, -0.07, 0), color = rgb(176, 16, 36), cloth = "knit", name = "SockBand"},
			sym{part = "LeftLowerLeg", size = V(1.05, 0.26, 1.05), at = V(0, -0.37, 0), color = rgb(16, 14, 16), cloth = "leather", name = "BootTop"},
			sym{part = "LeftLowerLeg", size = V(0.3, 0.05, 0.04), at = V(0, -0.3, -0.53), color = STEEL, cloth = "metal", name = "BootBuckle"},
			sym{part = "LeftFoot", size = V(1.07, 0.55, 1.09), at = V(0, -0.25, 0), color = rgb(10, 10, 12), cloth = "rubber", name = "Platform"},
			-- the tartan skirt: black pleats with red folds, red and bone bands across
			O_SKIRT(rgb(26, 24, 30), rgb(150, 20, 36), "wool", 0.9, nil, 1, {{0.3, 0.05, rgb(150, 20, 36)}, {0.55, 0.018, rgb(190, 182, 170)}, {0.78, 0.05, rgb(150, 20, 36)}}),
		}},
	-- ---- LEGENDARY (shop) ----
	{Id = "ExecutionerCoat", Rarity = "Legendary", Name = "Executioner", Price = 2400,
		Blurb = "Long black leather coat lined in crimson, a high collar, a buckled bandolier over an oxblood waistcoat, a studded pauldron, leather gloves and tall strapped boots.",
		Wear = {torso = {rgb(24, 22, 24), "leather"}, upperArms = {rgb(24, 22, 24), "leather"}, lowerArms = {rgb(24, 22, 24), "leather"}, hands = {rgb(14, 12, 12), "leather"},
			waist = {rgb(24, 22, 24), "leather"}, upperLegs = {rgb(36, 34, 40), "wool"}, lowerLegs = {rgb(36, 34, 40), "wool"}, feet = {rgb(14, 12, 12), "leather"}},
		Details = flat{
			-- high standing collar with a crimson top edge
			{part = "UpperTorso", size = V(0.62, 0.16, 1.12), at = V(0, 0.55, 0), color = rgb(16, 14, 16), cloth = "leather", name = "HighCollar", hood = true},
			{part = "UpperTorso", size = V(0.625, 0.025, 1.125), at = V(0, 0.62, 0), color = rgb(176, 18, 38), cloth = "leather", name = "CollarLining", hood = true},
			-- the open front: oxblood waistcoat with steel buttons, crimson lining along the coat edges, lapels
			{part = "UpperTorso", size = V(0.3, 0.9, 0.04), at = V(0, 0, -0.508), color = rgb(92, 14, 26), cloth = "wool", name = "Waistcoat"},
			{part = "UpperTorso", size = V(0.035, 0, 0.04), at = V(0, 0.2, -0.53), color = STEEL, cloth = "metal", name = "Button", shape = "Disc"},
			{part = "UpperTorso", size = V(0.035, 0, 0.04), at = V(0, 0.02, -0.53), color = STEEL, cloth = "metal", name = "Button", shape = "Disc"},
			{part = "UpperTorso", size = V(0.035, 0, 0.04), at = V(0, -0.16, -0.53), color = STEEL, cloth = "metal", name = "Button", shape = "Disc"},
			sym{part = "UpperTorso", size = V(0.025, 0.94, 0.05), at = V(-0.16, 0.01, -0.514), color = rgb(176, 18, 38), cloth = "leather", name = "Lining"},
			sym{part = "UpperTorso", size = V(0.17, 0.38, 0.05), at = V(-0.2, 0.28, -0.528), rot = V(0, 0, 18), color = rgb(32, 30, 32), cloth = "leather", name = "Lapel"},
			-- bandolier from the right shoulder to the left hip, front and back, with two steel buckles
			{part = "UpperTorso", size = V(0.07, 1.2, 0.04), at = V(0, 0, -0.56), rot = V(0, 0, -36), color = rgb(10, 10, 12), cloth = "leather", name = "Bandolier"},
			{part = "UpperTorso", size = V(0.07, 1.2, 0.04), at = V(0, 0, 0.56), rot = V(0, 0, -36), color = rgb(10, 10, 12), cloth = "leather", name = "Bandolier"},
			{part = "UpperTorso", size = V(0.07, 0.06, 0.05), at = V(0.103, 0.177, -0.585), rot = V(0, 0, -36), color = STEEL, cloth = "metal", name = "BandolierBuckle"},
			{part = "UpperTorso", size = V(0.07, 0.06, 0.05), at = V(-0.103, -0.177, -0.585), rot = V(0, 0, -36), color = STEEL, cloth = "metal", name = "BandolierBuckle"},
			-- crimson sigil across the back
			{part = "UpperTorso", size = V(0.24, 0, 0.03), at = V(0, 0.05, 0.585), color = RED, cloth = "leather", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.18, 0, 0.03), at = V(0, 0.05, 0.592), color = rgb(24, 22, 24), cloth = "leather", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.34, 0.03, 0.03), at = V(0, 0.05, 0.6), color = RED, cloth = "leather", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.02, 0.42, 0.03), at = V(0, 0.05, 0.6), color = RED, cloth = "leather", name = "SigilBar"},
			-- studded pauldron on the left shoulder with a crimson edge
			{part = "LeftUpperArm", size = V(1.14, 0.3, 1.14), at = V(0, 0.38, 0), color = rgb(32, 30, 32), cloth = "leather", name = "Pauldron"},
			{part = "LeftUpperArm", size = V(1.15, 0.04, 1.15), at = V(0, 0.24, 0), color = rgb(176, 18, 38), cloth = "leather", name = "PauldronEdge"},
			{part = "LeftUpperArm", size = V(0.1, 0.08, 0.1), at = V(-0.57, 0.38, -0.25), color = STEEL, cloth = "metal", name = "Stud", shape = "Ball"},
			{part = "LeftUpperArm", size = V(0.1, 0.08, 0.1), at = V(-0.57, 0.38, 0), color = STEEL, cloth = "metal", name = "Stud", shape = "Ball"},
			{part = "LeftUpperArm", size = V(0.1, 0.08, 0.1), at = V(-0.57, 0.38, 0.25), color = STEEL, cloth = "metal", name = "Stud", shape = "Ball"},
			-- buckled cuffs
			sym{part = "LeftLowerArm", size = V(1.06, 0.16, 1.06), at = V(0, -0.38, 0), color = rgb(14, 12, 14), cloth = "leather", name = "Cuff"},
			sym{part = "LeftLowerArm", size = V(0.2, 0.12, 0.05), at = V(0, -0.38, -0.54), color = STEEL, cloth = "metal", name = "CuffBuckle"},
			-- belt with a steel buckle
			{part = "LowerTorso", size = V(1.05, 0.36, 1.08), at = V(0, 0.16, 0), color = rgb(10, 10, 12), cloth = "leather", name = "Belt"},
			{part = "LowerTorso", size = V(0.14, 0.4, 0.05), at = V(0, 0.16, -0.56), color = STEEL, cloth = "metal", name = "Buckle"},
			-- long coat skirts: back with a crimson-lined vent, two fronts with crimson edges, closed sides
			{part = "LowerTorso", size = V(1.1, 4.6, 0.08), at = V(0, -2.7, 0.5), color = rgb(24, 22, 24), cloth = "leather", name = "Tail"},
			{part = "LowerTorso", size = V(0.014, 2.2, 0.09), at = V(0, -3.9, 0.505), color = rgb(176, 18, 38), cloth = "leather", name = "Vent"},
			sym{part = "LowerTorso", size = V(0.48, 4.4, 0.08), at = V(-0.28, -2.6, -0.53), rot = V(0, 0, -3), color = rgb(24, 22, 24), cloth = "leather", name = "Tail"},
			sym{part = "LowerTorso", size = V(0.03, 4.4, 0.085), at = V(-0.05, -2.6, -0.535), rot = V(0, 0, -3), color = rgb(176, 18, 38), cloth = "leather", name = "TailLining"},
			sym{part = "LowerTorso", size = V(0.05, 4.5, 1.04), at = V(-0.53, -2.65, 0), color = rgb(24, 22, 24), cloth = "leather", name = "TailSide"},
			-- pressed trousers, tall boots with two strapped buckles
			sym{part = "LeftUpperLeg", size = V(0.02, 0.98, 0.03), at = V(0, 0, -0.505), color = rgb(52, 50, 58), cloth = "wool", name = "Crease"},
			sym{part = "LeftLowerLeg", size = V(1.06, 0.8, 1.06), at = V(0, -0.1, 0), color = rgb(16, 14, 14), cloth = "leather", name = "BootShaft"},
			sym{part = "LeftLowerLeg", size = V(1.07, 0.06, 1.07), at = V(0, 0.15, 0), color = rgb(8, 8, 10), cloth = "leather", name = "BootStrap"},
			sym{part = "LeftLowerLeg", size = V(1.07, 0.06, 1.07), at = V(0, -0.15, 0), color = rgb(8, 8, 10), cloth = "leather", name = "BootStrap"},
			sym{part = "LeftLowerLeg", size = V(0.16, 0.09, 0.05), at = V(-0.3, 0.15, -0.54), color = STEEL, cloth = "metal", name = "BootBuckle"},
			sym{part = "LeftLowerLeg", size = V(0.16, 0.09, 0.05), at = V(-0.3, -0.15, -0.54), color = STEEL, cloth = "metal", name = "BootBuckle"},
			sym{part = "LeftFoot", size = V(1.05, 0.32, 1.07), at = V(0, -0.36, 0), color = rgb(10, 8, 8), cloth = "rubber", name = "Sole"},
		}},
	{Id = "InkRonin", Rarity = "Legendary", Name = "Ink Ronin", Price = 2400,
		Blurb = "Indigo haori with a bone collar, a crimson cord and a crest on the back, wide black hakama, an oxblood obi with a sheathed blade at the hip, bone tabi and red-strapped sandals.",
		Wear = {torso = {rgb(42, 46, 72), "wool"}, upperArms = {rgb(42, 46, 72), "wool"}, lowerArms = {rgb(42, 46, 72), "wool"},
			waist = {rgb(20, 20, 26), "wool"}, upperLegs = {rgb(20, 20, 26), "wool"}, lowerLegs = {rgb(20, 20, 26), "wool"}, feet = {BONE, "knit"}},
		Details = flat{
			-- bone under-collar crossing into a V, the fold below it, the crimson cord tying the haori
			sym{part = "UpperTorso", size = V(0.07, 0.6, 0.04), at = V(-0.12, 0.22, -0.512), rot = V(0, 0, 32), color = BONE, cloth = "knit", name = "Collar"},
			{part = "UpperTorso", size = V(0.012, 0.45, 0.03), at = V(0.03, -0.27, -0.508), color = rgb(22, 24, 34), cloth = "wool", name = "Overlap"},
			{part = "UpperTorso", size = V(0.14, 0.02, 0.03), at = V(0, -0.12, -0.525), color = RED, cloth = "knit", name = "Cord"},
			sym{part = "UpperTorso", size = V(0.045, 0, 0.04), at = V(-0.075, -0.12, -0.53), color = RED, cloth = "knit", name = "CordKnot", shape = "Disc"},
			{part = "UpperTorso", size = V(0.02, 0.12, 0.03), at = V(0, -0.2, -0.53), color = RED, cloth = "knit", name = "CordTassel"},
			-- the crest on the back: a bone ring with three dots
			{part = "UpperTorso", size = V(0.26, 0, 0.03), at = V(0, 0.15, 0.505), color = BONE, cloth = "wool", name = "Crest", shape = "Disc"},
			{part = "UpperTorso", size = V(0.21, 0, 0.03), at = V(0, 0.15, 0.512), color = rgb(42, 46, 72), cloth = "wool", name = "CrestField", shape = "Disc"},
			{part = "UpperTorso", size = V(0.06, 0, 0.03), at = V(0, 0.22, 0.52), color = BONE, cloth = "wool", name = "CrestDot", shape = "Disc"},
			{part = "UpperTorso", size = V(0.06, 0, 0.03), at = V(-0.05, 0.11, 0.52), color = BONE, cloth = "wool", name = "CrestDot", shape = "Disc"},
			{part = "UpperTorso", size = V(0.06, 0, 0.03), at = V(0.05, 0.11, 0.52), color = BONE, cloth = "wool", name = "CrestDot", shape = "Disc"},
			-- wide square haori sleeves with a crimson inner edge
			sym{part = "LeftLowerArm", size = V(1.22, 0.74, 1.22), at = V(0, -0.08, 0), color = rgb(42, 46, 72), cloth = "wool", name = "Sleeve"},
			sym{part = "LeftLowerArm", size = V(1.24, 0.04, 1.24), at = V(0, -0.44, 0), color = RED, cloth = "knit", name = "SleeveEdge"},
			-- oxblood obi with a bone cord and a knot at the front
			{part = "UpperTorso", size = V(1.04, 0.16, 1.07), at = V(0, -0.42, 0), color = rgb(110, 16, 30), cloth = "wool", name = "Obi"},
			{part = "LowerTorso", size = V(1.08, 1.0, 1.12), at = V(0, 0.1, 0), color = rgb(110, 16, 30), cloth = "wool", name = "Obi"},
			{part = "LowerTorso", size = V(1.09, 0.1, 1.13), at = V(0, 0.15, 0), color = BONE, cloth = "knit", name = "ObiCord"},
			{part = "LowerTorso", size = V(0.12, 0.3, 0.07), at = V(0.22, 0.15, -0.585), color = rgb(96, 12, 26), cloth = "wool", name = "ObiKnot"},
			{part = "LowerTorso", size = V(0.5, 0.7, 0.07), at = V(0, 0.05, 0.56), color = rgb(20, 20, 26), cloth = "wool", name = "BackBoard"},
			-- the blade at the left hip: black lacquered sheath through the obi, gold guard, wrapped hilt
			{part = "LowerTorso", size = V(0.05, 0.25, 2.6), at = V(-0.42, 0.1, 0.1), rot = V(20, 0, 0), color = rgb(14, 12, 14), cloth = "leather", name = "Sheath"},
			{part = "LowerTorso", size = V(0.12, 0, 0.04), at = V(-0.42, 1.2125, -1.12), rot = V(20, 0, 0), color = GOLD, cloth = "metal", name = "Guard", shape = "Disc"},
			{part = "LowerTorso", size = V(0.045, 0.2, 0.8), at = V(-0.42, 1.555, -1.496), rot = V(20, 0, 0), color = rgb(22, 22, 26), cloth = "knit", name = "Hilt"},
			-- wide pleated hakama
			sym{part = "LeftUpperLeg", size = V(1.16, 1.02, 1.16), at = V(0, 0, 0), color = rgb(20, 20, 26), cloth = "wool", name = "Hakama"},
			sym{part = "LeftUpperLeg", size = V(0.02, 0.98, 0.03), at = V(-0.2, 0, -0.585), color = rgb(36, 36, 46), cloth = "wool", name = "Pleat"},
			sym{part = "LeftUpperLeg", size = V(0.02, 0.98, 0.03), at = V(0.2, 0, -0.585), color = rgb(36, 36, 46), cloth = "wool", name = "Pleat"},
			sym{part = "LeftLowerLeg", size = V(1.28, 1.0, 1.28), at = V(0, 0.05, 0), color = rgb(20, 20, 26), cloth = "wool", name = "HakamaFlare"},
			sym{part = "LeftLowerLeg", size = V(0.02, 0.96, 0.03), at = V(-0.25, 0.05, -0.645), color = rgb(36, 36, 46), cloth = "wool", name = "Pleat"},
			sym{part = "LeftLowerLeg", size = V(0.02, 0.96, 0.03), at = V(0.25, 0.05, -0.645), color = rgb(36, 36, 46), cloth = "wool", name = "Pleat"},
			sym{part = "LeftLowerLeg", size = V(1.29, 0.04, 1.29), at = V(0, -0.43, 0), color = rgb(12, 12, 16), cloth = "wool", name = "HakamaHem"},
			-- bone tabi on wooden-brown sandals with crimson straps
			sym{part = "LeftFoot", size = V(1.06, 0.18, 1.1), at = V(0, -0.43, 0), color = rgb(70, 52, 36), cloth = "leather", name = "Sandal"},
			sym{part = "LeftFoot", size = V(1.07, 0.08, 0.3), at = V(0, -0.22, -0.25), color = RED, cloth = "knit", name = "SandalStrap"},
		}},
	-- ---- CASE EXCLUSIVE (CaseOnly: only from the MARKED case, never sold in the shop) ----
	{Id = "PhantomReaper", Rarity = "Legendary", CaseOnly = true, Name = "Phantom Reaper", Price = 2400,
		Blurb = "Case exclusive. A tattered grave-black cloak and mantle, a bone-stitched ribcage, a chained clasp, a ghost-lit sigil on the back and ragged strips falling to the ankles.",
		Wear = {torso = {rgb(44, 40, 48), "wool"}, upperArms = {rgb(44, 40, 48), "wool"}, lowerArms = {rgb(44, 40, 48), "wool"}, hands = {rgb(16, 16, 18), "leather"},
			waist = {rgb(44, 40, 48), "wool"}, upperLegs = {rgb(24, 24, 28), "wool"}, lowerLegs = {rgb(24, 24, 28), "wool"}, feet = {rgb(14, 14, 16), "leather"}},
		Details = flat{
			HOOD_BACK(rgb(36, 34, 40), rgb(14, 14, 18), rgb(18, 18, 22), "wool"),
			-- mantle over the shoulders with a ragged edge
			{part = "UpperTorso", size = V(1.1, 0.3, 1.12), at = V(0, 0.36, 0), color = rgb(62, 58, 66), cloth = "wool", name = "Mantle"},
			sym{part = "UpperTorso", size = V(0.06, 0.075, 0.03), at = V(-0.42, 0.21, -0.555), rot = V(0, 0, 45), color = rgb(62, 58, 66), cloth = "wool", name = "Tatter"},
			sym{part = "UpperTorso", size = V(0.06, 0.075, 0.03), at = V(-0.26, 0.21, -0.555), rot = V(0, 0, 45), color = rgb(62, 58, 66), cloth = "wool", name = "Tatter"},
			sym{part = "UpperTorso", size = V(0.06, 0.075, 0.03), at = V(-0.42, 0.21, 0.555), rot = V(0, 0, 45), color = rgb(62, 58, 66), cloth = "wool", name = "Tatter"},
			sym{part = "UpperTorso", size = V(0.06, 0.075, 0.03), at = V(-0.26, 0.21, 0.555), rot = V(0, 0, 45), color = rgb(62, 58, 66), cloth = "wool", name = "Tatter"},
			-- bone clasp at the throat with a ghost-lit gem, chains to the mantle
			{part = "UpperTorso", size = V(0.09, 0, 0.05), at = V(0, 0.4, -0.585), color = BONE, cloth = "rubber", name = "Clasp", shape = "Disc"},
			{part = "UpperTorso", size = V(0.04, 0, 0.05), at = V(0, 0.4, -0.595), color = rgb(110, 240, 220), cloth = "glow", name = "ClaspGem", shape = "Disc"},
			sym{part = "UpperTorso", size = V(0.15, 0.012, 0.02), at = V(-0.13, 0.37, -0.58), rot = V(0, 0, -10), color = STEEL, cloth = "metal", name = "Chain"},
			-- bone-stitched ribcage down the front
			{part = "UpperTorso", size = V(0.03, 0.36, 0.03), at = V(0, -0.04, -0.508), color = BONE, cloth = "knit", name = "Sternum"},
			sym{part = "UpperTorso", size = V(0.2, 0.022, 0.03), at = V(-0.13, 0.1, -0.508), rot = V(0, 0, 12), color = BONE, cloth = "knit", name = "Rib"},
			sym{part = "UpperTorso", size = V(0.2, 0.022, 0.03), at = V(-0.13, -0.03, -0.508), rot = V(0, 0, 12), color = BONE, cloth = "knit", name = "Rib"},
			sym{part = "UpperTorso", size = V(0.18, 0.022, 0.03), at = V(-0.12, -0.16, -0.508), rot = V(0, 0, 12), color = BONE, cloth = "knit", name = "Rib"},
			-- ghost-lit sigil across the back
			{part = "UpperTorso", size = V(0.26, 0, 0.03), at = V(0, -0.14, 0.505), color = rgb(110, 240, 220), cloth = "glow", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.22, 0, 0.03), at = V(0, -0.14, 0.512), color = rgb(44, 40, 48), cloth = "wool", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.34, 0.016, 0.03), at = V(0, -0.14, 0.52), color = rgb(110, 240, 220), cloth = "glow", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.016, 0.34, 0.03), at = V(0, -0.14, 0.52), color = rgb(110, 240, 220), cloth = "glow", name = "SigilBar"},
			-- tattered bell sleeves
			sym{part = "LeftLowerArm", size = V(1.2, 0.26, 1.2), at = V(0, -0.37, 0), color = rgb(62, 58, 66), cloth = "wool", name = "SleeveBell"},
			sym{part = "LeftLowerArm", size = V(0.17, 0.17, 0.05), at = V(-0.28, -0.5, -0.6), rot = V(0, 0, 45), color = rgb(62, 58, 66), cloth = "wool", name = "Tatter"},
			sym{part = "LeftLowerArm", size = V(0.17, 0.17, 0.05), at = V(0.22, -0.5, 0.6), rot = V(0, 0, 45), color = rgb(62, 58, 66), cloth = "wool", name = "Tatter"},
			-- black belt with a steel chain swagged at the front
			{part = "LowerTorso", size = V(1.08, 0.22, 1.1), at = V(0, 0.15, 0), color = rgb(14, 14, 16), cloth = "leather", name = "Belt"},
			sym{part = "LowerTorso", size = V(0.16, 0.06, 0.03), at = V(-0.1, -0.05, -0.57), rot = V(0, 0, -14), color = STEEL, cloth = "metal", name = "Chain"},
			-- the cloak falls in ragged strips of very different lengths, each torn to a point; open at the front
			{part = "LowerTorso", size = V(0.23, 4.00, 0.08), at = V(-0.44, -1.90, 0.500), rot = V(0, 0, 1.5), color = rgb(44, 40, 48), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(-0.44, -3.90, 0.500), rot = V(0, 0, 45), color = rgb(44, 40, 48), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 5.40, 0.08), at = V(-0.22, -2.60, 0.505), rot = V(0, 0, -1.0), color = rgb(34, 31, 38), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(-0.22, -5.30, 0.505), rot = V(0, 0, 45), color = rgb(34, 31, 38), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 3.60, 0.08), at = V(0.00, -1.70, 0.500), rot = V(0, 0, 0.0), color = rgb(44, 40, 48), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(0.00, -3.50, 0.500), rot = V(0, 0, 45), color = rgb(44, 40, 48), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 5.00, 0.08), at = V(0.22, -2.40, 0.505), rot = V(0, 0, 1.0), color = rgb(34, 31, 38), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(0.22, -4.90, 0.505), rot = V(0, 0, 45), color = rgb(34, 31, 38), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 4.40, 0.08), at = V(0.44, -2.10, 0.500), rot = V(0, 0, -1.5), color = rgb(44, 40, 48), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(0.44, -4.30, 0.500), rot = V(0, 0, 45), color = rgb(44, 40, 48), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 5.20, 0.08), at = V(-0.44, -2.50, -0.530), rot = V(0, 0, -1.5), color = rgb(44, 40, 48), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(-0.44, -5.10, -0.530), rot = V(0, 0, 45), color = rgb(44, 40, 48), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 4.60, 0.08), at = V(0.44, -2.20, -0.530), rot = V(0, 0, 1.5), color = rgb(44, 40, 48), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(0.44, -4.50, -0.530), rot = V(0, 0, 45), color = rgb(44, 40, 48), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 3.80, 0.08), at = V(-0.25, -1.80, -0.535), rot = V(0, 0, 1.0), color = rgb(34, 31, 38), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(-0.25, -3.70, -0.535), rot = V(0, 0, 45), color = rgb(34, 31, 38), cloth = "wool", name = "StripTip"},
			{part = "LowerTorso", size = V(0.23, 4.80, 0.08), at = V(0.25, -2.30, -0.535), rot = V(0, 0, -1.0), color = rgb(34, 31, 38), cloth = "wool", name = "Strip"},
			{part = "LowerTorso", size = V(0.15, 0.75, 0.075), at = V(0.25, -4.70, -0.535), rot = V(0, 0, 45), color = rgb(34, 31, 38), cloth = "wool", name = "StripTip"},
			sym{part = "LowerTorso", size = V(0.05, 3.8, 1.04), at = V(-0.53, -1.8, 0), color = rgb(44, 40, 48), cloth = "wool", name = "StripSide"},
			-- wrapped shins and black boots
			sym{part = "LeftLowerLeg", size = V(1.05, 0.05, 1.05), at = V(0, 0.25, 0), rot = V(0, 0, 8), color = rgb(64, 60, 66), cloth = "knit", name = "Wrap"},
			sym{part = "LeftLowerLeg", size = V(1.05, 0.05, 1.05), at = V(0, 0.05, 0), rot = V(0, 0, -8), color = rgb(64, 60, 66), cloth = "knit", name = "Wrap"},
			sym{part = "LeftLowerLeg", size = V(1.05, 0.05, 1.05), at = V(0, -0.15, 0), rot = V(0, 0, 8), color = rgb(64, 60, 66), cloth = "knit", name = "Wrap"},
			sym{part = "LeftFoot", size = V(1.05, 0.3, 1.07), at = V(0, -0.37, 0), color = rgb(10, 10, 12), cloth = "rubber", name = "Sole"},
		}},
	{Id = "CrimsonRegent", Rarity = "Legendary", CaseOnly = true, Name = "Crimson Regent", Price = 2400,
		Blurb = "Case exclusive. A floor-length crimson robe with a gold-edged shoulder cape, a gold sigil pendant and an embroidered sigil on the back, an oxblood sash with gold fringe, wide gold-cuffed sleeves and white gloves.",
		Wear = {torso = {rgb(150, 16, 34), "wool"}, upperArms = {rgb(150, 16, 34), "wool"}, lowerArms = {rgb(150, 16, 34), "wool"}, hands = {rgb(236, 232, 226), "knit"},
			waist = {rgb(150, 16, 34), "wool"}, upperLegs = {rgb(28, 24, 28), "wool"}, lowerLegs = {rgb(28, 24, 28), "wool"}, feet = {rgb(120, 12, 28), "leather"}},
		Details = flat{
			-- white collar band
			{part = "UpperTorso", size = V(0.5, 0.07, 1.06), at = V(0, 0.48, 0), color = WHITE, cloth = "knit", name = "Collar"},
			-- shoulder cape with a gold edge (over the shoulders and the tops of the arms)
			{part = "UpperTorso", size = V(1.12, 0.42, 1.14), at = V(0, 0.3, 0), color = rgb(140, 14, 32), cloth = "wool", name = "Cape"},
			{part = "UpperTorso", size = V(1.125, 0.05, 1.145), at = V(0, 0.1, 0), color = GOLD, cloth = "wool", name = "CapeEdge"},
			sym{part = "LeftUpperArm", size = V(1.12, 0.36, 1.12), at = V(0, 0.33, 0), color = rgb(140, 14, 32), cloth = "wool", name = "Cape"},
			sym{part = "LeftUpperArm", size = V(1.125, 0.04, 1.125), at = V(0, 0.15, 0), color = GOLD, cloth = "wool", name = "CapeEdge"},
			-- gold sigil pendant on two chains
			sym{part = "UpperTorso", size = V(0.012, 0.22, 0.02), at = V(-0.07, 0.29, -0.578), rot = V(0, 0, 30), color = GOLD, cloth = "metal", name = "PendantChain"},
			{part = "UpperTorso", size = V(0.1, 0, 0.04), at = V(0, 0.14, -0.585), color = GOLD, cloth = "metal", name = "Pendant", shape = "Disc"},
			{part = "UpperTorso", size = V(0.07, 0, 0.04), at = V(0, 0.14, -0.59), color = rgb(120, 10, 26), cloth = "wool", name = "PendantField", shape = "Disc"},
			{part = "UpperTorso", size = V(0.14, 0.016, 0.03), at = V(0, 0.14, -0.6), color = GOLD, cloth = "metal", name = "PendantBar"},
			{part = "UpperTorso", size = V(0.012, 0.15, 0.03), at = V(0, 0.14, -0.6), color = GOLD, cloth = "metal", name = "PendantBar"},
			-- gold buttons down the front below the cape
			{part = "UpperTorso", size = V(0.03, 0.04, 0.05), at = V(0, 0.0, -0.52), color = GOLD, cloth = "metal", name = "Button", shape = "Ball"},
			{part = "UpperTorso", size = V(0.03, 0.04, 0.05), at = V(0, -0.13, -0.52), color = GOLD, cloth = "metal", name = "Button", shape = "Ball"},
			{part = "UpperTorso", size = V(0.03, 0.04, 0.05), at = V(0, -0.26, -0.52), color = GOLD, cloth = "metal", name = "Button", shape = "Ball"},
			{part = "UpperTorso", size = V(0.03, 0.04, 0.05), at = V(0, -0.39, -0.52), color = GOLD, cloth = "metal", name = "Button", shape = "Ball"},
			-- gold sigil embroidered on the back of the cape
			{part = "UpperTorso", size = V(0.22, 0, 0.03), at = V(0, 0.28, 0.575), color = GOLD, cloth = "wool", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.17, 0, 0.03), at = V(0, 0.28, 0.582), color = rgb(140, 14, 32), cloth = "wool", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.3, 0.025, 0.03), at = V(0, 0.28, 0.59), color = GOLD, cloth = "wool", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.018, 0.26, 0.03), at = V(0, 0.28, 0.59), color = GOLD, cloth = "wool", name = "SigilBar"},
			-- wide sleeves with gold cuffs
			sym{part = "LeftLowerArm", size = V(1.18, 0.6, 1.18), at = V(0, -0.15, 0), color = rgb(150, 16, 34), cloth = "wool", name = "Sleeve"},
			sym{part = "LeftLowerArm", size = V(1.24, 0.2, 1.24), at = V(0, -0.4, 0), color = rgb(140, 14, 32), cloth = "wool", name = "SleeveBell"},
			sym{part = "LeftLowerArm", size = V(1.26, 0.05, 1.26), at = V(0, -0.49, 0), color = GOLD, cloth = "wool", name = "SleeveEdge"},
			-- oxblood sash with a gold edge and a fringed tail down the left
			{part = "LowerTorso", size = V(1.08, 0.5, 1.1), at = V(0, 0.18, 0), color = rgb(110, 10, 24), cloth = "wool", name = "Sash"},
			{part = "LowerTorso", size = V(1.085, 0.05, 1.105), at = V(0, 0.42, 0), color = GOLD, cloth = "wool", name = "SashEdge"},
			{part = "LowerTorso", size = V(0.14, 2.4, 0.05), at = V(-0.3, -1.0, -0.6), color = rgb(110, 10, 24), cloth = "wool", name = "SashTail"},
			{part = "LowerTorso", size = V(0.15, 0.4, 0.055), at = V(-0.3, -2.35, -0.605), color = GOLD, cloth = "wool", name = "Fringe"},
			-- the robe falls closed to the ankles all round: gold placket down the front, a wide gold hem
			{part = "LowerTorso", size = V(1.1, 5.6, 0.1), at = V(0, -3.3, 0.49), color = rgb(150, 16, 34), cloth = "wool", name = "Robe"},
			{part = "LowerTorso", size = V(1.1, 5.6, 0.1), at = V(0, -3.3, -0.5), color = rgb(150, 16, 34), cloth = "wool", name = "Robe"},
			sym{part = "LowerTorso", size = V(0.05, 5.6, 1.05), at = V(-0.54, -3.3, 0), color = rgb(150, 16, 34), cloth = "wool", name = "RobeSide"},
			{part = "LowerTorso", size = V(0.03, 5.6, 0.105), at = V(0, -3.3, -0.505), color = GOLD, cloth = "wool", name = "Placket"},
			{part = "LowerTorso", size = V(1.12, 0.5, 0.11), at = V(0, -5.84, -0.505), color = GOLD, cloth = "wool", name = "RobeHem"},
			{part = "LowerTorso", size = V(1.12, 0.5, 0.11), at = V(0, -5.84, 0.495), color = GOLD, cloth = "wool", name = "RobeHem"},
			sym{part = "LeftFoot", size = V(1.04, 0.25, 1.06), at = V(0, -0.4, 0), color = rgb(14, 12, 12), cloth = "rubber", name = "Sole"},
		}},
	{Id = "SigilRunner", Rarity = "Legendary", CaseOnly = true, Name = "Sigil Runner", Price = 2400,
		Blurb = "Case exclusive. Matte black shell wired with live crimson neon: a lit MARKED sigil across the back, glowing piping down the sleeves and legs, a lit buckle, a funnel collar and a long back tail.",
		Wear = {torso = {rgb(16, 16, 20), "shell"}, upperArms = {rgb(16, 16, 20), "shell"}, lowerArms = {rgb(16, 16, 20), "shell"}, hands = {rgb(10, 10, 12), "shell"},
			waist = {rgb(12, 12, 14), "shell"}, upperLegs = {rgb(22, 22, 26), "shell"}, lowerLegs = {rgb(22, 22, 26), "shell"}, feet = {rgb(14, 14, 16), "rubber"}},
		Details = flat{
			-- funnel collar with a lit top edge, a lit asymmetric zip
			{part = "UpperTorso", size = V(0.6, 0.16, 1.16), at = V(0, 0.55, 0), color = rgb(12, 12, 14), cloth = "shell", name = "FunnelCollar", hood = true},
			{part = "UpperTorso", size = V(0.605, 0.02, 1.165), at = V(0, 0.625, 0), color = rgb(255, 30, 60), cloth = "glow", name = "CollarLight", hood = true},
			{part = "UpperTorso", size = V(0.12, 0.9, 0.05), at = V(0.1, 0, -0.515), rot = V(0, 0, 10), color = rgb(12, 12, 14), cloth = "shell", name = "StormFlap"},
			{part = "UpperTorso", size = V(0.012, 0.9, 0.06), at = V(0.06, 0, -0.525), rot = V(0, 0, 10), color = rgb(255, 30, 60), cloth = "glow", name = "NeonZip"},
			-- small lit sigil on the chest
			{part = "UpperTorso", size = V(0.14, 0, 0.03), at = V(-0.27, 0.2, -0.512), color = rgb(255, 30, 60), cloth = "glow", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.11, 0, 0.03), at = V(-0.27, 0.2, -0.518), color = rgb(16, 16, 20), cloth = "shell", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.2, 0.014, 0.03), at = V(-0.27, 0.2, -0.524), color = rgb(255, 30, 60), cloth = "glow", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.01, 0.24, 0.03), at = V(-0.27, 0.2, -0.524), color = rgb(255, 30, 60), cloth = "glow", name = "SigilBar"},
			-- big lit sigil across the back
			{part = "UpperTorso", size = V(0.3, 0, 0.03), at = V(0, 0, 0.505), color = rgb(255, 30, 60), cloth = "glow", name = "SigilRing", shape = "Disc"},
			{part = "UpperTorso", size = V(0.25, 0, 0.03), at = V(0, 0, 0.512), color = rgb(16, 16, 20), cloth = "shell", name = "SigilInner", shape = "Disc"},
			{part = "UpperTorso", size = V(0.42, 0.025, 0.03), at = V(0, 0, 0.52), color = rgb(255, 30, 60), cloth = "glow", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.018, 0.52, 0.03), at = V(0, 0, 0.52), color = rgb(255, 30, 60), cloth = "glow", name = "SigilBar"},
			{part = "UpperTorso", size = V(0.05, 0, 0.03), at = V(0, 0, 0.528), color = rgb(255, 30, 60), cloth = "glow", name = "SigilDot", shape = "Disc"},
			-- shoulder panels with lit piping, lit lines down the outer sleeves, dark cuffs
			sym{part = "LeftUpperArm", size = V(1.08, 0.22, 1.08), at = V(0, 0.4, 0), color = rgb(12, 12, 14), cloth = "shell", name = "ShoulderPanel"},
			sym{part = "LeftUpperArm", size = V(1.05, 0.03, 1.05), at = V(0, 0.27, 0), color = rgb(255, 30, 60), cloth = "glow", name = "Piping"},
			sym{part = "LeftUpperArm", size = V(0.035, 0.62, 0.03), at = V(-0.32, -0.1, -0.507), color = rgb(255, 30, 60), cloth = "glow", name = "NeonLine"},
			sym{part = "LeftLowerArm", size = V(0.035, 0.66, 0.03), at = V(-0.32, 0.12, -0.507), color = rgb(255, 30, 60), cloth = "glow", name = "NeonLine"},
			sym{part = "LeftLowerArm", size = V(1.06, 0.16, 1.06), at = V(0, -0.4, 0), color = rgb(12, 12, 14), cloth = "shell", name = "Cuff"},
			-- belt with a steel buckle and a lit slit
			{part = "LowerTorso", size = V(1.04, 0.45, 1.07), at = V(0, 0.12, 0), color = rgb(8, 8, 10), cloth = "shell", name = "Belt"},
			{part = "LowerTorso", size = V(0.16, 0.42, 0.08), at = V(0, 0.12, -0.55), color = STEEL, cloth = "metal", name = "Buckle"},
			{part = "LowerTorso", size = V(0.1, 0.12, 0.09), at = V(0, 0.12, -0.555), color = rgb(255, 30, 60), cloth = "glow", name = "BuckleLight"},
			-- long back tail with a lit hem
			{part = "LowerTorso", size = V(1.08, 3.2, 0.07), at = V(0, -1.8, 0.5), color = rgb(16, 16, 20), cloth = "shell", name = "Tail"},
			{part = "LowerTorso", size = V(1.085, 0.08, 0.075), at = V(0, -3.36, 0.502), color = rgb(255, 30, 60), cloth = "glow", name = "TailLight"},
			-- trousers: lit stripes down the outer legs, knee panels; boots with a lit sole line
			sym{part = "LeftUpperLeg", size = V(0.035, 1.0, 0.03), at = V(-0.32, 0, -0.507), color = rgb(255, 30, 60), cloth = "glow", name = "NeonLine"},
			sym{part = "LeftLowerLeg", size = V(0.035, 0.2, 0.03), at = V(-0.32, 0.03, -0.525), color = rgb(255, 30, 60), cloth = "glow", name = "NeonLine"},
			sym{part = "LeftLowerLeg", size = V(0.82, 0.26, 0.06), at = V(0, 0.33, -0.52), color = rgb(30, 30, 36), cloth = "shell", name = "KneePanel"},
			sym{part = "LeftLowerLeg", size = V(1.07, 0.25, 1.07), at = V(0, -0.38, 0), color = rgb(12, 12, 14), cloth = "shell", name = "BootTop"},
			sym{part = "LeftFoot", size = V(1.06, 0.38, 1.08), at = V(0, -0.33, 0), color = rgb(20, 20, 24), cloth = "rubber", name = "Sole"},
			sym{part = "LeftFoot", size = V(1.065, 0.05, 1.085), at = V(0, -0.2, 0), color = rgb(255, 30, 60), cloth = "glow", name = "SoleLight"},
		}},
}
-- rarity tiers set the prices (ReplicatedStorage.Numberfall.Rarity)
Rarity.Apply(O.List, "item")
O.ById = {}
for _, o in ipairs(O.List) do O.ById[o.Id] = o end

-- COLOURWAYS: every outfit can be re-dyed. Like hair colours they are bought per outfit
-- (OwnedHair["<outfit>|<colourway>"]); "Original" is free. A colourway gives three colours:
--   Main   replaces the outfit's main garment colour (its torso), and every shade close to it moves with it
--   Legs   the same for the trousers / lower half
--   Accent replaces the red trims (sigils, piping, straps, tabs)
-- Everything else (metal, white soles, skin) keeps its colour.
O.Colorways = {
	{Id = "CwOriginal", Name = "Original", Price = 0},
	{Id = "CwBone", Rarity = "Common", Name = "Bone", Price = 450, Main = rgb(214, 206, 192), Legs = rgb(66, 62, 68), Accent = rgb(36, 36, 42)},
	{Id = "CwCrimson", Rarity = "Uncommon", Name = "Crimson", Price = 450, Main = rgb(124, 16, 32), Legs = rgb(32, 30, 34), Accent = rgb(236, 232, 226)},
	{Id = "CwOlive", Rarity = "Uncommon", Name = "Olive Drab", Price = 450, Main = rgb(74, 80, 50), Legs = rgb(54, 50, 42), Accent = rgb(220, 150, 40)},
	{Id = "CwMidnight", Rarity = "Uncommon", Name = "Midnight", Price = 450, Main = rgb(28, 36, 72), Legs = rgb(34, 38, 54), Accent = rgb(80, 170, 235)},
	{Id = "CwAsh", Rarity = "Common", Name = "Ash", Price = 450, Main = rgb(128, 126, 132), Legs = rgb(42, 40, 46), Accent = rgb(255, 40, 70)},
	{Id = "CwSakura", Rarity = "Rare", Name = "Sakura", Price = 600, Main = rgb(232, 170, 186), Legs = rgb(236, 230, 226), Accent = rgb(120, 30, 60)},
	{Id = "CwPhantom", Name = "Phantom", Price = 99999, Premium = "CW_Phantom", Main = rgb(18, 18, 22), Legs = rgb(10, 10, 12), Accent = rgb(120, 240, 210)},
	{Id = "CwGilded", Name = "Gilded", Price = 99999, Vip = true, Main = rgb(168, 128, 48), Legs = rgb(30, 26, 22), Accent = rgb(255, 230, 160)},
}
Rarity.Apply(O.Colorways, "colour")
O.DefaultColorway = "CwOriginal"
O.ColorwayById = {}
for _, c in ipairs(O.Colorways) do O.ColorwayById[c.Id] = c end
function O.ColorwayKey(outfitId, cwId) return tostring(outfitId) .. "|" .. tostring(cwId) end

local function clamp255(x) return math.clamp(x, 0, 1) end
local function dist(a, b) return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2) * 255 end
local function lum(c) return c.R * .3 + c.G * .59 + c.B * .11 end
local function isAccent(c) return c.R * 255 >= 130 and c.G * 255 < 75 and c.B * 255 < 85 end
-- returns a function old colour -> new colour for this outfit and colourway
function O.ColorMap(outfit, cwId)
	local cw = O.ColorwayById[cwId or ""]
	if not cw or not cw.Main then return function(c) return c end end
	local oldMain = outfit.Wear.torso and outfit.Wear.torso[1] or rgb(80, 80, 80)
	local legsSpec = outfit.Wear.upperLegs or outfit.Wear.lowerLegs or outfit.Wear.torso
	local oldLegs = legsSpec and legsSpec[1] or oldMain
	local function shift(c, from, to)
		return Color3.new(clamp255(c.R + to.R - from.R), clamp255(c.G + to.G - from.G), clamp255(c.B + to.B - from.B))
	end
	local mainIsRed = isAccent(oldMain)
	return function(c)
		local dm0, dl0 = dist(c, oldMain), dist(c, oldLegs)
		if dm0 < 14 and dm0 <= dl0 then return shift(c, oldMain, cw.Main) end
		if dl0 < 14 then return shift(c, oldLegs, cw.Legs) end
		-- a red garment (Crimson Varsity): its red trims follow the garment, not the accent
		if isAccent(c) and not (mainIsRed and dm0 < 60) then
			-- keep the trim's own shading relative to a typical red trim
			local k = math.clamp(lum(c) / lum(rgb(200, 22, 46)), .6, 1.4)
			return Color3.new(clamp255(cw.Accent.R * k), clamp255(cw.Accent.G * k), clamp255(cw.Accent.B * k))
		end
		local dm, dl = dist(c, oldMain), dist(c, oldLegs)
		if dm <= dl and dm < 60 then return shift(c, oldMain, cw.Main) end
		if dl < 60 then return shift(c, oldLegs, cw.Legs) end
		return c
	end
end

local function dress(part, color, clothKey)
	local c = CLOTH[clothKey or "skin"] or CLOTH.skin
	part.Color = color
	part.Material = c[1]
	local variant = c[2]
	part.MaterialVariant = (variant and MaterialService:FindFirstChild(variant, true)) and variant or ""
end
O.Dress = dress

-- build a skirt (see O_SKIRT) onto `model`'s LowerTorso, recoloured through `map`, into `holder`
local SKIRT_PANELS = 20
local function buildSkirt(model, spec, holder, map)
	local lt = model:FindFirstChild("LowerTorso"); if not lt or not lt:IsA("BasePart") then return end
	-- Fitted to the body it's on: the waist ring hugs the LowerTorso, a short hip band widens it to just clear the
	-- thighs (the real leg boxes, measured in the hips' space, corners included), then the pleats fall from there.
	-- The rings are rounded squares (superellipses), the shape of the blocky body, so they hug it without bulging.
	local ltHalf = lt.Size / 2
	local X, zMin, zMax, legTop = 0, -ltHalf.Z, ltHalf.Z, -ltHalf.Y
	for _, n in ipairs({"LeftUpperLeg", "RightUpperLeg"}) do
		local leg = model:FindFirstChild(n)
		if leg and leg:IsA("BasePart") then
			-- the leg's REST placement (hip attachments), not its current CFrame: built mid-animation (idle sway,
			-- a stride, the menu pose) the posed legs splayed the measurement and the whole skirt came out huge
			local side = n:sub(1, -9) -- "Left" / "Right"
			local a0, a1 = lt:FindFirstChild(side .. "HipRigAttachment"), leg:FindFirstChild(side .. "HipRigAttachment")
			local rel = (a0 and a1) and (a0.CFrame * a1.CFrame:Inverse()) or lt.CFrame:ToObjectSpace(leg.CFrame)
			local h = leg.Size / 2
			for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
				local p = rel * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
				X = math.max(X, math.abs(p.X)); zMin = math.min(zMin, p.Z); zMax = math.max(zMax, p.Z)
				if sy == 1 then legTop = math.max(legTop, p.Y) end
			end end end
		end
	end
	local zc = (zMin + zMax) / 2
	local Z = (zMax - zMin) / 2
	-- later layers (an overskirt) sit a little further out
	local layer = 0
	for _, c in ipairs(holder:GetChildren()) do if c.Name == "SkirtWaist" then layer += 1 end end
	layer = math.floor(layer / SKIRT_PANELS + 0.5) -- (each skirt has SKIRT_PANELS waist pieces)
	local pad = 0.04 + layer * 0.035
	local topY = ltHalf.Y
	-- (the hip band reaches its full width by the tops of the thighs, so their corners are always inside the cloth,
	-- but tapers over at least 0.2 studs above that instead of jumping straight out under the waist)
	legTop = math.clamp(legTop, -ltHalf.Y, topY - 0.2)
	-- a superellipse |x/a|^n + |z/b|^n = 1 encloses the box corners (X, Z) when a = X * 2^(1/n)
	-- a boxy ring (n = 8) at the hips keeps the skirt close to the body; the hem rounds off a little (n = 4)
	local N1, N2 = 8, 4
	local k1, k2 = 2 ^ (1 / N1), 2 ^ (1 / N2)
	local waist = {a = ltHalf.X + 0.03 + layer * 0.02, b = ltHalf.Z + 0.03 + layer * 0.02, n = N1, y = topY}
	local hips = {a = math.max(waist.a, X * k1 + pad), b = math.max(waist.b, Z * k1 + pad), n = N1, y = legTop}
	local len = math.max(0.3, spec.len * 1.24 - (topY - legTop))
	-- a gentle A-line: a little wider at the hem, never less than what the rounder hem needs to clear the legs
	-- (a real A-line: wide enough at the hem that an ordinary stride moves inside it instead of shoving the cloth)
	local spread = (0.1 + len * 0.16) * spec.flare
	local hem = {a = math.max(hips.a + spread, X * k2 + pad), b = math.max(hips.b + spread * 0.8, Z * k2 + pad), n = N2, y = legTop - len}
	local function pt(r, t)
		local c, si = math.cos(t), math.sin(t)
		local e = 2 / r.n
		local x = r.a * (c >= 0 and 1 or -1) * math.abs(c) ^ e
		local z = r.b * (si >= 0 and 1 or -1) * math.abs(si) ^ e
		return Vector3.new(x, r.y, zc + z)
	end
	-- panel boundaries spaced evenly along the hem, with a panel centred at the front (an even angle step bunched the
	-- panels into the rounded corners and left two wide flat panels across the front and the back)
	local T = {}
	do
		local S = 720
		local acc, prev = {[0] = 0}, pt(hem, 0)
		for k = 1, S do local q = pt(hem, k / S * math.pi * 2); acc[k] = acc[k - 1] + (q - prev).Magnitude; prev = q end
		local total = acc[S]
		local seg = total / SKIRT_PANELS
		local function tAt(s)
			s = s % total
			local k = 1
			while k < S and acc[k] < s do k += 1 end
			local f = (s - acc[k - 1]) / math.max(acc[k] - acc[k - 1], 1e-6)
			return (k - 1 + f) / S * math.pi * 2
		end
		local off = 0
		for i = 0, SKIRT_PANELS do
			local t = tAt(total * 0.75 + (i + 0.5) * seg)
			if i > 0 and t + off < T[i] then off += math.pi * 2 end
			T[i + 1] = t + off
		end
	end
	local function band(r0, r1, name, sway, hemColor, striped)
		for i = 0, SKIRT_PANELS - 1 do
			local t0, t1 = T[i + 1], T[i + 2]
			local p00, p01, p10, p11 = pt(r0, t0), pt(r0, t1), pt(r1, t0), pt(r1, t1)
			-- every column of the skirt swings open as one piece from the waist ring (SkirtSway): a hinge at the hips
			-- sat level with the hip joints, so a thigh raised to the front (a jump) came up through the cloth
			local hingeAt = (pt(waist, t0) + pt(waist, t1)) / 2
			local topMid, botMid = (p00 + p01) / 2, (p10 + p11) / 2
			local tangent = ((p01 - p00) + (p11 - p10)).Unit
			local up = (topMid - botMid)
			local h = up.Magnitude
			up = (up - tangent * up:Dot(tangent)).Unit
			local width = math.max((p01 - p00).Magnitude, (p11 - p10).Magnitude) * 1.14
			-- the panel's outward normal, so it sits just outside the curve (not on the chord, which cuts corners)
			local outward = tangent:Cross(up)
			local mid = (topMid + botMid) / 2
			if outward:Dot(Vector3.new(mid.X, 0, mid.Z - zc)) < 0 then outward = -outward end
			local center = mid + outward * 0.03
			-- the panel's +Z faces out (offsets in its frame push the pleat faces and the hem outwards)
			if tangent:Cross(up):Dot(outward) < 0 then tangent = -tangent end
			local cf = CFrame.fromMatrix(center, tangent, up)
			local function panel(pname, size, offset, color)
				local p = Instance.new("Part")
				p.Name = pname; p.Size = size
				p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
				p.Anchored = lt.Anchored
				if not armBand then p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth end
				O.Dress(p, map(color), spec.cloth)
				local c = cf * offset
				p.CFrame = lt.CFrame * c
				local w = Instance.new("Weld"); w.Name = "OutfitWeld"; w.Part0 = lt; w.Part1 = p; w.C0 = c; w.Parent = p
				if sway then
					-- for StarterPlayerScripts.SkirtSway: the panel's frame on the hips, its height, this piece's offset on
					-- it and its direction round the waist, so the panel can swing out of the way of the legs; the hinge
					-- (on the waist ring, in the panel's frame) and how far the panel's bottom hangs below it
					p:SetAttribute("SkirtCF", cf); p:SetAttribute("SkirtH", h); p:SetAttribute("SkirtOff", offset)
					p:SetAttribute("SkirtAngle", ((t0 + t1) / 2) % (math.pi * 2))
					local hinge = cf:PointToObjectSpace(hingeAt + outward * 0.03)
					p:SetAttribute("SkirtHinge", hinge)
					p:SetAttribute("SkirtReach", math.max(0.1, hinge.Y + h / 2))
				end
				p.Parent = holder
			end
			if striped then
				-- box pleats: a darker underlay with a narrower face panel standing a little proud of it, so every fold
				-- reads as a crisp stripe between the faces (alternating whole panels overlapped and looked see-through)
				-- (the underlay keeps the identity offset: SkirtSway reads each column's shape from that piece)
				panel(name, Vector3.new(width, h + 0.04, 0.05), CFrame.identity, spec.shade)
				panel(name, Vector3.new(width * 0.66, h + 0.04, 0.05), CFrame.new(0, 0, 0.032), spec.main)
			else
				panel(name, Vector3.new(width, h + 0.04, 0.06), CFrame.identity, spec.main)
			end
			if hemColor then panel("Hem", Vector3.new(width + 0.01, 0.12, 0.1), CFrame.new(0, -h / 2 + 0.06, 0.018), hemColor) end
			if striped and spec.bands then
				for _, b in ipairs(spec.bands) do panel("SkirtBand", Vector3.new(width + 0.01, b[2], 0.1), CFrame.new(0, h / 2 - b[1] * h, 0.018), b[3]) end
			end
		end
	end
	band(waist, hips, "SkirtWaist", true, nil, false)
	band(hips, hem, "Skirt", true, spec.hem, true)
end
O.BuildSkirt = buildSkirt

-- Apply outfit `id` (default StreetTee) to `model`, with uncovered skin in `skin`, dyed in colourway `cwId`.
-- ---------------------------------------------------------------- body shapes
-- Details are placed on a body part's bounding box. The Roblox woman torso is curved (a neck stub on top, the
-- shoulders well below the box top, a narrow waist), so on it details are fitted to the measured surface instead:
-- each row is {y, front z, back z, half width} at the template size (Numberfall.BodyParts.Woman).
local PROFILE = {
	BodyWoman = {
		UpperTorso = {size = Vector3.new(1.2664, 1.8028, 0.8454), top = 0.55, bottom = -0.86, rows = {
			{0.55, -0.31, 0.39, 0.60}, {0.5, -0.35, 0.41, 0.63}, {0.4, -0.41, 0.42, 0.63}, {0.3, -0.42, 0.42, 0.63},
			{0.2, -0.42, 0.42, 0.63}, {0.1, -0.41, 0.41, 0.63}, {0, -0.39, 0.40, 0.62}, {-0.1, -0.37, 0.38, 0.61},
			{-0.2, -0.35, 0.37, 0.60}, {-0.3, -0.33, 0.36, 0.59}, {-0.4, -0.31, 0.35, 0.57}, {-0.5, -0.30, 0.33, 0.56},
			{-0.6, -0.29, 0.32, 0.55}, {-0.7, -0.27, 0.31, 0.53}, {-0.86, -0.26, 0.27, 0.52}}},
		LowerTorso = {size = Vector3.new(1.3204, 0.4081, 0.7214), top = 0.12, bottom = -0.2, rows = {
			{0.12, -0.28, 0.29, 0.55}, {0.05, -0.32, 0.31, 0.58}, {0, -0.35, 0.33, 0.61}, {-0.1, -0.35, 0.35, 0.64}, {-0.2, -0.36, 0.35, 0.64}}},
	},
}
local function profileRow(prof, y)
	local rows = prof.rows
	if y >= rows[1][1] then return rows[1][2], rows[1][3], rows[1][4] end
	for i = 1, #rows - 1 do
		local a, b = rows[i], rows[i + 1]
		if y <= a[1] and y >= b[1] then
			local t = (a[1] - y) / math.max(a[1] - b[1], 1e-4)
			return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
		end
	end
	local r = rows[#rows]
	return r[2], r[3], r[4]
end
-- size and position (body space) of a detail on a curved body part; nil position = the plain box placement
function fitDetail(body, det, size)
	local shape = PROFILE[body:GetAttribute("BodyType") or ""]
	local prof = shape and shape[body.Name]
	if not prof then return size, nil end
	local k = body.Size / prof.size
	local at = det.at or Vector3.zero
	local top, bottom = prof.top * k.Y, prof.bottom * k.Y
	local y = bottom + (at.Y + 0.5) * (top - bottom)
	-- long pieces that hang below the part (coat tails, robes, a blazer skirt) keep their real length and drop:
	-- squeezing them into the curved surface's height made them vanish into the legs on the feminine body
	local hanging = body.Name == "LowerTorso" and (at.Y - det.size.Y / 2) < -0.75
	if hanging then y = at.Y * body.Size.Y end
	local front, back, half = profileRow(prof, hanging and prof.bottom or y / k.Y)
	front, back, half = front * k.Z, back * k.Z, half * k.X
	local sx = half * 2 / body.Size.X
	local sz = (back - front) / body.Size.Z
	local x
	if math.abs(at.X) >= 0.45 then x = math.sign(at.X) * (half + (math.abs(at.X) - 0.5) * body.Size.X)
	else x = at.X * body.Size.X * sx end
	local z
	if at.Z <= -0.45 then z = front + (at.Z + 0.5) * body.Size.Z
	elseif at.Z >= 0.45 then z = back + (at.Z - 0.5) * body.Size.Z
	else z = (front + back) / 2 + at.Z * body.Size.Z * sz end
	local sy = hanging and 1 or (top - bottom) / body.Size.Y
	if hanging then
		-- hanging pieces wrap the legs, not the narrow waist: as wide as the legs' outer edges and just clear of
		-- their front / back (the feminine legs stick out past the lower torso's box)
		local model = body.Parent
		local l, r = model and model:FindFirstChild("LeftUpperLeg"), model and model:FindFirstChild("RightUpperLeg")
		if l and r and l:IsA("BasePart") and r:IsA("BasePart") then
			local lx = body.CFrame:PointToObjectSpace(l.Position).X
			local rx = body.CFrame:PointToObjectSpace(r.Position).X
			local span = math.abs(rx - lx) + math.max(l.Size.X, r.Size.X) + 0.06
			local depth = math.max(l.Size.Z, r.Size.Z) / 2 + 0.05
			local w = span * det.size.X / 1.1
			x = at.X * span
			if at.Z < 0 then z = math.min(z, -depth) elseif at.Z > 0 then z = math.max(z, depth) end
			-- a piece wrapped all the way round (a blazer skirt) is as deep as the legs; a flat panel keeps its thickness
			local d = math.abs(at.Z) < 0.45 and (depth * 2 + 0.04) * math.min(det.size.Z, 1.1) or size.Z * sz
			return Vector3.new(w, size.Y, d), Vector3.new(x, y, z)
		end
	end
	if det.shape == "Disc" then return Vector3.new(size.X * sz, size.Y * sx, size.Z * sx), Vector3.new(x, y, z) end
	return Vector3.new(size.X * sx, size.Y * sy, size.Z * sz), Vector3.new(x, y, z)
end

local ARM_PARTS = {LeftUpperArm = true, RightUpperArm = true, LeftLowerArm = true, RightLowerArm = true}
function O.Apply(model, id, skin, cwId)
	local outfit = O.ById[id or ""] or O.ById[O.Default]
	skin = typeof(skin) == "Color3" and skin or O.DefaultSkin
	local map = O.ColorMap(outfit, cwId)
	-- every body part starts as skin, then the outfit covers its regions
	for name in pairs(O.BodyParts) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			-- avatar body meshes can carry their own texture / SurfaceAppearance (gloves, painted skin): strip them so
			-- the outfit colour and the skin tone are what shows
			if p:IsA("MeshPart") and p.TextureID ~= "" then pcall(function() p.TextureID = "" end) end
			local sa = p:FindFirstChildOfClass("SurfaceAppearance"); if sa then sa:Destroy() end
			dress(p, skin, "skin")
		end
	end
	for region, spec in pairs(outfit.Wear) do
		for _, n in ipairs(REGIONS[region] or {}) do
			local p = model:FindFirstChild(n)
			if p and p:IsA("BasePart") then dress(p, map(spec[1]), spec[2]) end
		end
	end
	-- details
	for _, n in ipairs({"Outfit", "OutfitHood"}) do local old = model:FindFirstChild(n); if old then old:Destroy() end end
	local holder = Instance.new("Model"); holder.Name = "Outfit"
	local hood = Instance.new("Model"); hood.Name = "OutfitHood"   -- near the head: hidden with it in first person
	for _, det in ipairs(outfit.Details or {}) do
		local body = det.part and model:FindFirstChild(det.part)
		if det.skirt then
			buildSkirt(model, det.skirt, holder, map)
		elseif body and body:IsA("BasePart") then
			-- thin bands round an arm (cuffs, sleeve hems, piping, armbands) are a short slice of the arm's own mesh,
			-- a little wider: they follow its rounded edges, so they read as a hem instead of a box standing off the
			-- sleeve (too wide) or vanishing into it (too tight)
			local armBand = ARM_PARTS[det.part] and body:IsA("MeshPart") and (det.shape == nil or det.shape == "Block")
				and det.size.Y <= 0.2 and det.size.X > 1 and det.size.X < 1.12
			local p
			if armBand then
				p = body:Clone(); p:ClearAllChildren()
				for k in pairs(p:GetAttributes()) do p:SetAttribute(k, nil) end
				p.Transparency = 0; p.TextureID = ""
			else
				p = Instance.new("Part")
			end
			p.Name = det.name or "Detail"
			if not armBand then p.Shape = det.shape == "Ball" and Enum.PartType.Ball or det.shape == "Cylinder" and Enum.PartType.Cylinder or Enum.PartType.Block end
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			p.Anchored = body.Anchored
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			local size = body.Size * det.size
			-- arm bands: the overhang trimmed to 60% (stacked bands keep their order: a gold edge still sits over its
			-- armband); wide bell cuffs and sleeves are plain parts and keep their size
			if armBand then
				size = Vector3.new(body.Size.X * (1 + (det.size.X - 1) * 0.6), size.Y, body.Size.Z * (1 + (det.size.Z - 1) * 0.6))
			end
			if not armBand and p.Shape == Enum.PartType.Ball then p.Shape = Enum.PartType.Block end -- rounded via a mesh below
			local extra = CFrame.identity
			if det.shape == "Disc" then
				-- flat round badge: a cylinder turned to face along Z; diameter from the body part's width
				local diam = body.Size.X * det.size.X
				p.Shape = Enum.PartType.Cylinder
				size = Vector3.new(body.Size.Z * det.size.Z, diam, diam)
				extra = CFrame.Angles(0, math.rad(90), 0)
			end
			local fitPos
			size, fitPos = fitDetail(body, det, size)
			p.Size = size
			if det.shape == "Ball" then
				local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
			end
			dress(p, map(det.color), det.cloth)
			local r = det.rot or Vector3.zero
			local offset = CFrame.new(fitPos or body.Size * (det.at or Vector3.zero)) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z)) * extra
			p.CFrame = body.CFrame * offset
			local w = Instance.new("Weld"); w.Name = "OutfitWeld"; w.Part0 = body; w.Part1 = p; w.C0 = offset; w.Parent = p
			p.Parent = det.hood and hood or holder
		end
	end
	holder:SetAttribute("OutfitId", outfit.Id)
	holder:SetAttribute("Colorway", O.ColorwayById[cwId or ""] and cwId or O.DefaultColorway)
	holder.Parent = model
	if #hood:GetChildren() > 0 then hood.Parent = model else hood:Destroy() end
	return outfit
end

return O
