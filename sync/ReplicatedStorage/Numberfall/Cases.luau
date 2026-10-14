-- CASES: "THE MARKED CASE". Bought with marks (Price) or Robux (Numberfall.Store.Products.Case), and one is earned
-- free with every level up. Opening one (ServerScriptService.ProfileService:OpenCase) rolls a tier by Weight, then an
-- item of that tier at random from the shop's own cosmetics, or marks. Case-exclusive items (CaseOnly in their
-- catalog, e.g. VisorColorways) aren't sold anywhere else. Something you already own pays back DupRefund of its price.
-- Shared by the server (the roll) and the case screen (StarterPlayerScripts.CaseOpening: contents, odds, the reel).
local NF = script.Parent
local Rarity = require(NF:WaitForChild("Rarity"))
local C = {}
C.Name = "THE MARKED CASE"
C.Price = 750            -- marks
C.DupRefund = 0.4        -- an item you already own: this share of its price back as marks
C.MarksDrop = {150, 450} -- the marks prize, rounded to 10s
C.FreePerLevel = 1       -- cases earned per level up
-- PITY: opens in a row without one before it's guaranteed. Legendary counts any Legendary or Case Exclusive;
-- a Case Exclusive resets both. (ProfileService keeps the counts per player: d.CasePity = {L = .., X = ..})
C.Pity = {Legendary = 40, CaseExclusive = 100}
-- tiers, best last. Weight = chance out of the total (100)
C.Tiers = {
	{Id = "Marks", Name = "MARKS", Weight = 30, Color = {70, 196, 200}},
	{Id = "Common", Name = "COMMON", Weight = 14},
	{Id = "Uncommon", Name = "UNCOMMON", Weight = 28},
	{Id = "Rare", Name = "RARE", Weight = 17},
	{Id = "Epic", Name = "EPIC", Weight = 8},
	{Id = "Legendary", Name = "LEGENDARY", Weight = 2.2},
	{Id = "CaseExclusive", Name = "CASE EXCLUSIVE", Weight = 0.8, Color = {255, 44, 76}},
}
C.TierById = {}
local total = 0
for _, t in ipairs(C.Tiers) do
	local rt = Rarity.Tiers[t.Id]
	t.Color = t.Color or (rt and rt.Color) or {200, 200, 200}
	t.Color3 = Color3.fromRGB(t.Color[1], t.Color[2], t.Color[3])
	C.TierById[t.Id] = t
	total += t.Weight
end
C.TotalWeight = total

-- every cosmetic that can drop: {Id, Name, Kind, Rarity, Price, Tier, Own = "hair" (OwnedHair) | "gear" (Owned)}
-- (only things sold for marks, plus the case exclusives: no free starters, no Robux / VIP items, no per-item colours)
local pool
function C.Pool()
	if pool then return pool end
	pool = {}
	local function add(it, kind, own)
		if not it or it.Premium or it.Vip or it.Hidden then return end
		if it.CaseOnly then
			table.insert(pool, {Id = it.Id, Name = it.Name, Kind = kind, Rarity = it.Rarity, Price = it.Price or 0, Tier = "CaseExclusive", Own = own, Color = it.Color})
			return
		end
		if (tonumber(it.Price) or 0) <= 0 or not C.TierById[it.Rarity or ""] then return end
		table.insert(pool, {Id = it.Id, Name = it.Name, Kind = kind, Rarity = it.Rarity, Price = it.Price, Tier = it.Rarity, Own = own, Color = it.Color})
	end
	local HairCatalog = require(NF:WaitForChild("HairCatalog"))
	for _, s in ipairs(HairCatalog.Styles) do add(s, "style", "hair") end
	for _, m in ipairs(HairCatalog.Masks or {}) do add(m, "mask", "hair") end
	for _, o in ipairs(require(NF:WaitForChild("Outfits")).List) do add(o, "outfit", "hair") end
	for _, n in ipairs(require(NF:WaitForChild("NumberStyles")).List) do add(n, "numstyle", "hair") end
	local Extras = require(NF:WaitForChild("Extras"))
	for _, x in ipairs(Extras.Pets) do add(x, "pet", "hair") end
	for _, x in ipairs(Extras.KillFX) do add(x, "killfx", "hair") end
	for _, v in ipairs(require(NF:WaitForChild("VisorColorways")).List) do
		add({Id = v.Id, Name = v.Name .. " visor", Price = v.Price, Rarity = v.Rarity, CaseOnly = v.CaseOnly, Color = v.Color, Hidden = v.Hidden}, "visorcolor", "hair")
	end
	for _, t in ipairs(require(NF:WaitForChild("TrailColors")).List) do add({Id = t.Id, Name = t.Name .. " trail", Price = t.Price, Rarity = t.Rarity, CaseOnly = t.CaseOnly, Color = t.Color}, "trailcolor", "hair") end
	for _, g in ipairs(require(NF:WaitForChild("Catalog"))) do add(g, "gear", "gear") end
	return pool
end
function C.InTier(tierId)
	local t = {}
	for _, it in ipairs(C.Pool()) do if it.Tier == tierId then table.insert(t, it) end end
	return t
end
-- the chance of a tier (0..1), counting only tiers that have something in them
function C.Chance(tierId)
	local t = C.TierById[tierId]
	if not t then return 0 end
	return t.Weight / C.TotalWeight
end
function C.KindName(kind)
	return ({style = "HAIRSTYLE", mask = "HEAD", outfit = "CLOTHING", numstyle = "NUMBER STYLE", pet = "PET", killfx = "ELIM FX",
		visorcolor = "VISOR COLOUR", trailcolor = "TRAIL", gear = "GEAR", marks = "MARKS"})[kind or ""] or "ITEM"
end
-- one roll: the tier, then the item (rng: a Random). Returns the pool entry, or {Kind = "marks", Amount = n}
-- (force: a tier id to roll inside, for the pity)
function C.Roll(rng, force)
	rng = rng or Random.new()
	local x = rng:NextNumber() * C.TotalWeight
	local tier = C.Tiers[1]
	for _, t in ipairs(C.Tiers) do
		if x < t.Weight then tier = t; break end
		x -= t.Weight
	end
	if force and C.TierById[force] and #C.InTier(force) > 0 then tier = C.TierById[force] end
	if tier.Id ~= "Marks" then
		local list = C.InTier(tier.Id)
		if #list > 0 then return list[rng:NextInteger(1, #list)] end
	end
	local amount = math.floor(rng:NextInteger(C.MarksDrop[1], C.MarksDrop[2]) / 10 + 0.5) * 10
	return {Kind = "marks", Id = "Marks", Name = amount .. " MARKS", Amount = amount, Tier = "Marks"}
end
return C
