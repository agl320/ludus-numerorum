-- RARITY TIERS for every cosmetic. Each item in the catalogs (Catalog, HairCatalog, Outfits, NumberStyles, Extras) names
-- its tier (Rarity = "Rare" ...) and its price in marks comes from the tier, so every tier costs more than the one
-- below it. Free starter items stay free (STARTER); Robux / VIP items are EXCLUSIVE and keep their store price.
--   Rarity.Apply(list, "item" | "colour")  -- sets item.Price, item.Rarity and item.RarityColor (called by the catalogs)
--   Rarity.Of(item) -> tier table {Id, Name, Color (Color3), Rank} or nil
local R = {}

R.Order = {"Starter", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Exclusive"}
R.Tiers = {
	Starter   = {Name = "STARTER",   Color = {150, 140, 144}},
	Common    = {Name = "COMMON",    Color = {196, 190, 192}},
	Uncommon  = {Name = "UNCOMMON",  Color = {76, 214, 112}},
	Rare      = {Name = "RARE",      Color = {64, 150, 255}},
	Epic      = {Name = "EPIC",      Color = {178, 86, 255}},
	Legendary = {Name = "LEGENDARY", Color = {255, 178, 46}},
	Exclusive = {Name = "EXCLUSIVE", Color = {255, 44, 76}},
}
-- marks per tier: whole items (hairstyles, outfits, masks, pets, elimination effects, number styles, notebooks) and
-- colours (hair colours and the outfit / pet / mask colourways, bought per item)
R.Prices = {
	item   = {Common = 450, Uncommon = 900, Rare = 1350, Epic = 1800, Legendary = 2400},
	colour = {Common = 300, Uncommon = 450, Rare = 600, Epic = 800, Legendary = 1100},
}
for i, id in ipairs(R.Order) do
	local t = R.Tiers[id]
	t.Id = id; t.Rank = i
	t.Color3 = Color3.fromRGB(t.Color[1], t.Color[2], t.Color[3])
end

function R.Apply(list, class)
	local prices = R.Prices[class or "item"] or R.Prices.item
	for _, item in ipairs(list) do
		if item.Premium or item.Vip then
			item.Rarity = "Exclusive"
		elseif (tonumber(item.Price) or 0) == 0 and not (item.Rarity and prices[item.Rarity]) then
			item.Rarity = "Starter"
		else
			if not prices[item.Rarity or ""] then item.Rarity = "Common" end
			item.Price = prices[item.Rarity]
		end
		item.RarityColor = R.Tiers[item.Rarity].Color
	end
	return list
end

function R.Of(item)
	return item and R.Tiers[item.Rarity or ""] or nil
end

return R
