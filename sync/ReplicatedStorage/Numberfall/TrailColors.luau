-- TRAIL COLOURS: afterimage looks sold in the Shop (TRAIL tab) or dropped by THE MARKED CASE (CaseOnly ones).
-- Owned once (OwnedHair[id], published as OwnHair_<id>) and worn like the rank trails: picked in Loadout > TRAIL and
-- saved as d.TrailStyle / the TrailStyle attribute (Numberfall.RankLooks.Trail picks it if you own it).
-- The look (Numberfall.Afterimages): colors = the afterimages' colours in turn, transparency, dust = glitter colour,
-- dense = more afterimages, longer = trail length multiplier, material = the afterimages' material (default Neon).
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local T = {}
T.List = {
	{Id = "TrAsh", Name = "Ash", Rarity = "Common", Color = {206, 206, 214},
		Look = {colors = {rgb(140, 140, 152)}, transparency = 0.74},
		Blurb = "A pale grey blur, like smoke off a fire that just went out."},
	{Id = "TrToxic", Name = "Toxic", Rarity = "Common", Color = {130, 255, 70},
		Look = {colors = {rgb(130, 255, 70)}, transparency = 0.72},
		Blurb = "Acid green afterimages. Don't touch."},
	{Id = "TrCobalt", Name = "Cobalt", Rarity = "Uncommon", Color = {60, 130, 255},
		Look = {colors = {rgb(60, 130, 255), rgb(40, 90, 220)}, transparency = 0.7},
		Blurb = "Deep electric blue."},
	{Id = "TrSakura", Name = "Sakura", Rarity = "Uncommon", Color = {255, 150, 196},
		Look = {colors = {rgb(255, 80, 160), rgb(255, 140, 196)}, transparency = 0.7, dust = rgb(255, 190, 215)},
		Blurb = "Soft pink, with a flurry of blossom where you were."},
	{Id = "TrEmber", Name = "Ember", Rarity = "Rare", Color = {255, 120, 30},
		Look = {colors = {rgb(255, 120, 30), rgb(255, 60, 20)}, transparency = 0.68, dust = rgb(255, 196, 90)},
		Blurb = "Orange and red like hot coals, sparks thrown off behind you."},
	{Id = "TrFrost", Name = "Frostbite", Rarity = "Rare", Color = {150, 225, 255},
		Look = {colors = {rgb(80, 190, 255), rgb(160, 225, 255)}, transparency = 0.68, dust = rgb(240, 250, 255)},
		Blurb = "Ice-blue afterimages and a glitter of frost."},
	{Id = "TrSynth", Name = "Synthwave", Rarity = "Epic", Color = {255, 40, 200},
		Look = {colors = {rgb(255, 40, 200), rgb(40, 220, 255)}, transparency = 0.66, dust = rgb(255, 140, 240)},
		Blurb = "Hot pink and cyan in turn. Straight out of an 80s arcade."},
	{Id = "TrVenom", Name = "Venom", Rarity = "Epic", Color = {120, 255, 80},
		Look = {colors = {rgb(120, 255, 80), rgb(150, 50, 230)}, transparency = 0.66, dust = rgb(170, 255, 120)},
		Blurb = "Poison green and violet. Something bit you."},
	{Id = "TrPrism", Name = "Prism", Rarity = "Legendary", Color = {255, 255, 255},
		Look = {colors = {rgb(255, 60, 70), rgb(255, 160, 40), rgb(255, 236, 60), rgb(70, 255, 120), rgb(60, 170, 255), rgb(170, 80, 255)},
			transparency = 0.64, dust = rgb(255, 255, 255), dense = true},
		Blurb = "Every colour of the spectrum, one after another, in a dense sparkling trail."},
	-- case exclusives (CaseOnly: only from THE MARKED CASE, never sold in the shop)
	{Id = "TrBloodMoon", Name = "Blood Moon", Rarity = "Legendary", CaseOnly = true, Color = {200, 0, 30},
		Look = {colors = {rgb(255, 30, 40), rgb(120, 0, 16), rgb(255, 90, 60)}, transparency = 0.62, dust = rgb(255, 60, 60), dense = true, longer = 1.2},
		Blurb = "Case exclusive. A long, dense trail of blood red under a red moon."},
	{Id = "TrPhantom", Name = "Phantom", Rarity = "Legendary", CaseOnly = true, Color = {170, 220, 255},
		Look = {colors = {rgb(170, 220, 255), rgb(120, 150, 255)}, transparency = 0.15, material = Enum.Material.ForceField,
			dust = rgb(210, 236, 255), dense = true, longer = 1.2},
		Blurb = "Case exclusive. Shimmering spectral copies of you, like you left your ghost behind."},
}
Rarity.Apply(T.List, "colour")
T.ById = {}
for _, t in ipairs(T.List) do
	t.Kind = "trailcolor"
	T.ById[t.Id] = t
end
function T.Get(id) return T.ById[id or ""] end
return T
