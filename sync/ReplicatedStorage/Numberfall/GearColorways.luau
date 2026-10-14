-- GEAR COLOURWAYS: recolour the gear you write with. Bought PER GEAR item, like pet colourways:
-- OwnedHair["<gear>|<colourway>"]; Original is free; the VIP one is owned once and works on every gear item.
-- Equipped per gear as d.GearColors[gear], published as GearCw_<gear>, and GearColor (the colourway of the gear you
-- have equipped). What a colourway changes (PaintPart, by the part's name in Numberfall.NotebookAssets):
--   notebook   the cover's tint (the page gets a clean ruled sheet over it: StarterPlayerScripts.NotebookModel)
--   typewriter the housing, as solid enamel (the black carriage, platen and keys stay)
--   keyboard   the case as solid enamel, and the keycaps' tint (Keys)
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local G = {}
local function c3(r, g, b) return Color3.fromRGB(r, g, b) end
G.Default = "GcOriginal"
G.List = {
	{Id = "GcOriginal", Name = "Original", Price = 0},
	{Id = "GcOxblood", Name = "Oxblood", Rarity = "Common", Body = c3(118, 24, 34)},
	{Id = "GcMidnight", Name = "Midnight", Rarity = "Common", Body = c3(30, 44, 92)},
	{Id = "GcForest", Name = "Forest", Rarity = "Uncommon", Body = c3(40, 82, 54)},
	{Id = "GcIvory", Name = "Ivory", Rarity = "Uncommon", Body = c3(226, 218, 198), Keys = c3(96, 94, 102)},
	{Id = "GcSeaGlass", Name = "Sea glass", Rarity = "Rare", Body = c3(62, 148, 134)},
	{Id = "GcPlum", Name = "Plum", Rarity = "Rare", Body = c3(92, 44, 118)},
	{Id = "GcGilded", Name = "Gilded", Price = 99999, Vip = true, Body = c3(196, 152, 64), Keys = c3(255, 242, 205), Metal = true},
}
Rarity.Apply(G.List, "colour")
G.ById = {}
for _, c in ipairs(G.List) do c.Kind = "gearcolor"; G.ById[c.Id] = c end
function G.Key(gearId, cwId) return tostring(gearId) .. "|" .. tostring(cwId) end
function G.Tinted(cwId) return G.ById[cwId or ""] ~= nil and cwId ~= G.Default end
-- the cover's tint: the colourway's hue at the texture's own brightness (multiplying a dark texture by a dark colour
-- went black)
local function hue(c) local m = math.max(c.R, c.G, c.B, 1e-3); return Color3.new(c.R / m, c.G / m, c.B / m) end
-- dye one part of a gear model (a fresh copy from NotebookAssets, or the held notebook's cover) for a colourway
function G.PaintPart(part, name, cwId)
	local c = G.ById[cwId or ""]
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if name == "Notebook" then
		if sa then sa.Color = (c and c.Body and c.Id ~= G.Default) and hue(c.Body) or Color3.new(1, 1, 1) end
		return
	end
	if not c or c.Id == G.Default then return end
	if (name == "Typewriter housing" or name == "Keyboard enclosure") and c.Body then
		-- black lacquer can't be tinted (a tint multiplies it): swap the texture for solid enamel in the colour
		if sa then sa:Destroy() end
		part.Color = c.Body
		part.Material = c.Metal and Enum.Material.Metal or Enum.Material.SmoothPlastic
		part.Reflectance = c.Metal and 0.22 or 0.08
	elseif (name:find("^Keyboard key row") or name == "Keyboard bottom keys") and c.Keys and sa then
		sa.Color = c.Keys
	end
end
return G
