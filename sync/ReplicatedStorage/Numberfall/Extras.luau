-- EXTRA COSMETICS: body types, elimination effects and pets. Bought and equipped through the same profile actions
-- as hair (ProfileService:HairAction, OwnHair[id]); equipped as d.BodyType / d.KillEffect / d.Pet and published as the
-- player attributes BodyType / KillEffect / Pet. Price 0 = free. Premium = Robux product key (Numberfall.Store),
-- Vip = VIP gamepass. Visuals: Numberfall.BodyType (torso swap), Numberfall.KillFX, Numberfall.Pets.
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local X = {}

-- kind -> profile field / player attribute
X.Field = {body = "BodyType", killfx = "KillEffect", pet = "Pet"}

X.Bodies = {
	{Id = "BodyClassic", Name = "Classic", Price = 0, Parts = "Classic",
		Blurb = "The standard blocky build."},
	{Id = "BodyWoman", Name = "Feminine", Price = 0, Parts = "Woman",
		Blurb = "The Roblox woman torso: narrower shoulders and a defined waist."},
}

X.KillFX = {
	{Id = "FxShatter", Name = "Red Shatter", Price = 0, Color = {255, 34, 58},
		Blurb = "The classic: a red flash, a shockwave and the glass of their visor breaking apart."},
	{Id = "FxInk", Rarity = "Uncommon", Name = "Ink Blot", Price = 900, Color = {40, 34, 52},
		Blurb = "A burst of black ink that splashes the ground. Written off."},
	{Id = "FxSakura", Rarity = "Rare", Name = "Sakura Scatter", Price = 1350, Color = {255, 150, 190},
		Blurb = "A gust of cherry blossom petals that drifts away on the wind."},
	{Id = "FxFrost", Rarity = "Rare", Name = "Frostbite", Price = 1350, Color = {150, 220, 255},
		Blurb = "Ice spikes burst out of the ground and shatter into frozen mist."},
	{Id = "FxVoid", Rarity = "Epic", Name = "Void Collapse", Price = 1800, Color = {150, 70, 255},
		Blurb = "A violet singularity swallows everything around them, then snaps shut."},
	{Id = "FxStorm", Rarity = "Epic", Name = "Thunderstrike", Price = 1800, Color = {120, 200, 255},
		Blurb = "A bolt of lightning straight out of the sky."},
	{Id = "FxGlitch", Rarity = "Epic", Name = "Data Corrupt", Price = 1800, Color = {60, 255, 230},
		Blurb = "They get deleted: a storm of corrupted pixel blocks in cyan and magenta."},
	{Id = "FxInferno", Rarity = "Legendary", Name = "Inferno", Price = 2400, Color = {255, 120, 30},
		Blurb = "A pillar of fire and a ring of scorched ground."},
	{Id = "FxHellgate", Name = "Hellgate", Price = 99999, Premium = "FX_Hellgate", Color = {255, 40, 20},
		Blurb = "A burning sigil opens under them and chains drag them down."},
	{Id = "FxGilded", Name = "Gilded", Price = 99999, Vip = true, Color = {255, 200, 90},
		Blurb = "VIP: a fountain of gold coins and a golden shockwave."},
}

X.Pets = {
	{Id = "PetNone", Name = "No Pet", Price = 0, Blurb = "Nobody following you around."},
	{Id = "PetCrow", Rarity = "Uncommon", Name = "Crow", Price = 900, Color = {40, 36, 44},
		Blurb = "One of the city's crows took a liking to you."},
	{Id = "PetBat", Rarity = "Uncommon", Name = "Bat", Price = 1050, Color = {70, 40, 60},
		Blurb = "A little bat that flaps along beside you."},
	{Id = "PetCat", Rarity = "Rare", Name = "Black Cat", Price = 1350, Color = {28, 26, 32},
		Blurb = "Crosses your path on purpose. Yellow eyes, flicking tail."},
	{Id = "PetDog", Rarity = "Rare", Name = "Stray Dog", Price = 1350, Color = {170, 116, 66},
		Blurb = "A loyal black-and-tan stray. Floppy ears, wagging tail, never leaves your side."},
	{Id = "PetGhost", Rarity = "Rare", Name = "Ghost", Price = 1350, Color = {236, 236, 246},
		Blurb = "A sheet ghost that drifts after you and bobs on the air."},
	{Id = "PetWisp", Rarity = "Epic", Name = "Will-o'-Wisp", Price = 1800, Color = {120, 230, 255},
		Blurb = "A cold blue flame that floats at your shoulder."},
	{Id = "PetSkull", Rarity = "Epic", Name = "Lantern Skull", Price = 1800, Color = {230, 222, 205},
		Blurb = "A floating skull with a candle burning inside it."},
	{Id = "PetDrone", Rarity = "Legendary", Name = "Visor Drone", Price = 2400, Color = {255, 38, 48},
		Blurb = "A tiny drone with its own LED visor, showing your number style."},
	{Id = "PetReaper", Name = "Little Reaper", Price = 99999, Premium = "PT_Reaper", Color = {20, 18, 24},
		Blurb = "A pocket-sized reaper with a scythe twice its size."},
	{Id = "PetGilded", Name = "Gilded Crow", Price = 99999, Vip = true, Color = {214, 168, 64},
		Blurb = "VIP: a crow dipped in gold."},
}

-- PET COLOURWAYS: bought PER PET (OwnedHair["<pet>|<colourway>"]) like clothing colourways; Original is free;
-- Robux / VIP ones are owned once and work on every pet. Main = body, Accent = trim / belly / blade, Glow = eyes,
-- flames and lights (Numberfall.Pets recolours each piece by its Role).
local function c3(r, g, b) return Color3.fromRGB(r, g, b) end
X.PetColorways = {
	{Id = "PcOriginal", Name = "Original", Price = 0},
	{Id = "PcBone", Rarity = "Common", Name = "Bone", Price = 300, Main = c3(226, 218, 204), Accent = c3(44, 38, 42), Glow = c3(255, 40, 60)},
	{Id = "PcBlood", Rarity = "Common", Name = "Blood", Price = 300, Main = c3(116, 12, 26), Accent = c3(24, 12, 14), Glow = c3(255, 150, 60)},
	{Id = "PcAsh", Rarity = "Common", Name = "Ash", Price = 300, Main = c3(120, 118, 124), Accent = c3(48, 46, 52), Glow = c3(240, 240, 255)},
	{Id = "PcMidnight", Rarity = "Uncommon", Name = "Midnight", Price = 450, Main = c3(26, 32, 66), Accent = c3(170, 180, 204), Glow = c3(80, 200, 255)},
	{Id = "PcToxic", Rarity = "Uncommon", Name = "Toxic", Price = 450, Main = c3(36, 58, 32), Accent = c3(18, 22, 16), Glow = c3(150, 255, 60)},
	{Id = "PcSakura", Rarity = "Uncommon", Name = "Sakura", Price = 450, Main = c3(240, 172, 198), Accent = c3(255, 240, 246), Glow = c3(255, 70, 140)},
	{Id = "PcSpectral", Rarity = "Epic", Name = "Spectral", Price = 600, Main = c3(190, 236, 255), Accent = c3(120, 200, 230), Glow = c3(120, 255, 230), Transparency = 0.35},
	{Id = "PcGilded", Name = "Gilded", Price = 99999, Vip = true, Main = c3(214, 168, 64), Accent = c3(70, 50, 22), Glow = c3(255, 240, 180),
		Material = Enum.Material.Metal, Reflectance = 0.15},
}
Rarity.Apply(X.PetColorways, "colour")
X.DefaultPetColorway = "PcOriginal"
X.PetColorwayById = {}
for _, c in ipairs(X.PetColorways) do c.Kind = "petcolor"; X.PetColorwayById[c.Id] = c end
function X.PetColorKey(petId, cwId) return tostring(petId) .. "|" .. tostring(cwId) end
-- MASK COLOURWAYS (Loadout > Mask > COLOURS): bought PER MASK (OwnedHair["<mask>|<colourway>"]); Original is free and
-- keeps the mask's own texture; the others dye the cloth (the folds, stitching and cross stay, from the normal map).
-- Equipped per mask as d.MaskColors[mask], published as MaskCw_<mask> and MaskColor (the mask you wear).
X.MaskColorways = {
	{Id = "McOriginal", Name = "Original", Price = 0},
	{Id = "McBone", Rarity = "Common", Name = "Bone", Price = 300, Color = {214, 204, 188}},
	{Id = "McCrimson", Rarity = "Common", Name = "Crimson", Price = 300, Color = {120, 16, 28}},
	{Id = "McAsh", Rarity = "Common", Name = "Ash", Price = 300, Color = {92, 92, 98}},
	{Id = "McMidnight", Rarity = "Uncommon", Name = "Midnight", Price = 450, Color = {24, 30, 66}},
	{Id = "McOlive", Rarity = "Uncommon", Name = "Olive Drab", Price = 450, Color = {60, 68, 40}},
	{Id = "McSakura", Rarity = "Uncommon", Name = "Sakura", Price = 450, Color = {222, 140, 172}},
	{Id = "McToxic", Rarity = "Rare", Name = "Toxic", Price = 600, Color = {64, 160, 58}},
	{Id = "McGilded", Name = "Gilded", Price = 0, Vip = true, Color = {196, 152, 64}},
}
Rarity.Apply(X.MaskColorways, "colour")
X.DefaultMaskColorway = "McOriginal"
X.MaskColorwayById = {}
for _, c in ipairs(X.MaskColorways) do c.Kind = "maskcolor"; X.MaskColorwayById[c.Id] = c end
function X.MaskColorKey(maskId, cwId) return tostring(maskId) .. "|" .. tostring(cwId) end
-- dye a mask's handle (server mask and the menu previews): swaps its textured surface for the dyeable one
-- Where a head item that came from the avatar catalog (a hood, a hat...) sits: its own HatAttachment /
-- HairAttachment meets the head's attachment of the same name (like Roblox wears accessories), scaled to the head.
-- Returns the handle's CFrame relative to the head and the size multiplier, or nil for the modelled scarf.
function X.MaskOffset(head, src)
	local a
	for _, n in ipairs({"HatAttachment", "HairAttachment", "FaceFrontAttachment"}) do a = a or src:FindFirstChild(n) end
	if not a or not a:IsA("Attachment") then return nil end
	local scale = head.Size.X / 1.2
	local ha = head:FindFirstChild(a.Name)
	local headCF = ha and ha.CFrame or CFrame.new(0, head.Size.Y / 2, 0)
	local ac = CFrame.new(a.Position * scale) * a.CFrame.Rotation
	return headCF * ac:Inverse(), scale
end
function X.DyeMask(handle, cwId)
	local cw = X.MaskColorwayById[cwId or ""]
	if not handle then return end
	-- catalog items (textured MeshParts): Original keeps the texture, a colourway shows the mesh in that colour
	if handle:GetAttribute("FlatDye") and handle:IsA("MeshPart") then
		local tex = handle:GetAttribute("OrigTexture")
		if tex == nil then tex = handle.TextureID; handle:SetAttribute("OrigTexture", tex) end
		local dyed = cw and cw.Color
		pcall(function() handle.TextureID = dyed and "" or tex end)
		if dyed then handle.Color = Color3.fromRGB(table.unpack(cw.Color)) end
		handle:SetAttribute("Colorway", cw and cw.Id or nil)
		return
	end
	if not cw or not cw.Color then return end
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Numberfall")
	folder = folder and folder:FindFirstChild("MaskModels")
	local dye = folder and folder:FindFirstChild("DyeSurface")
	local sa = handle:FindFirstChildOfClass("SurfaceAppearance")
	if dye then
		if sa then sa:Destroy() end
		local d = dye:Clone(); d.Name = "SurfaceAppearance"; d.Parent = handle
	end
	handle.Color = Color3.fromRGB(table.unpack(cw.Color))
	handle:SetAttribute("Colorway", cw.Id)
end

X.DefaultBody, X.DefaultKillFx, X.DefaultPet = "BodyClassic", "FxShatter", "PetNone"
X.Default = {body = X.DefaultBody, killfx = X.DefaultKillFx, pet = X.DefaultPet}

-- rarity tiers set the prices (ReplicatedStorage.Numberfall.Rarity)
Rarity.Apply(X.Bodies, "item"); Rarity.Apply(X.KillFX, "item"); Rarity.Apply(X.Pets, "item")
X.ById = {}
for kind, list in pairs({body = X.Bodies, killfx = X.KillFX, pet = X.Pets}) do
	for _, item in ipairs(list) do
		item.Kind = kind
		X.ById[item.Id] = item
	end
end
function X.Get(id) return X.ById[id or ""] end
return X
