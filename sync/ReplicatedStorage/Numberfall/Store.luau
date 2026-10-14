-- MARKED Robux store. Paste the IDs from the Creator Hub (Monetization > Developer Products / Passes) into Id.
-- Id = 0 means "not set up yet": the button shows COMING SOON and nothing can be bought.
-- Robux = the price shown until the real price loads from Roblox (keep it the same as on the Creator Hub).
local S={}
S.Products={
	-- marks packs (the three cards in Shop > MARKS)
	Marks1={Id=0,Kind="Marks",Amount=1000,Robux=99,Name="Pocket of Marks"},
	Marks2={Id=0,Kind="Marks",Amount=2750,Robux=249,Name="Satchel of Marks",Tag="+10% BONUS"},
	Marks3={Id=0,Kind="Marks",Amount=6000,Robux=499,Name="Vault of Marks",Tag="+20% BONUS"},
	-- back into the round with one life after losing all three (once per round)
	Revive={Id=0,Kind="Revive",Robux=9,Name="Revive"},
	-- contract rerolls (Contracts menu and the main menu's contracts card): one daily, all of today's dailies, one weekly
	Reroll={Id=0,Kind="Reroll",Robux=2,Name="Daily contract reroll"},
	RerollAll={Id=0,Kind="RerollAll",Robux=8,Name="Reroll all daily contracts"},
	RerollWeekly={Id=0,Kind="RerollWeekly",Robux=4,Name="Weekly contract reroll"},
	-- one MARKED case (Numberfall.Cases; Shop > CASES)
	Case={Id=0,Kind="Case",Robux=25,Name="The Marked Case"},
	-- Robux-only cosmetics (they also show in the Shop with an R$ price)
	CW_Phantom={Id=0,Kind="Item",Item="CwPhantom",Robux=249,Name="Phantom colourway (all outfits)"},
	HC_Platinum={Id=0,Kind="Item",Item="Platinum",Robux=149,Name="Platinum hair colour (all hairstyles)"},
	HC_Ember={Id=0,Kind="Item",Item="Ember",Robux=149,Name="Ember hair colour (all hairstyles)"},
	NS_Hellfire={Id=0,Kind="Item",Item="Hellfire",Robux=249,Name="Hellfire number style"},
	NS_Sigil={Id=0,Kind="Item",Item="Sigil",Robux=249,Name="Blood Sigil number style"},
	FX_Hellgate={Id=0,Kind="Item",Item="FxHellgate",Robux=249,Name="Hellgate elimination effect"},
	PT_Reaper={Id=0,Kind="Item",Item="PetReaper",Robux=299,Name="Little Reaper pet"},
}
S.Passes={
	VIP={Id=0,Robux=299,Name="VIP"},
}
-- VIP perks
S.VIP={XP=1.5,Marks=1.25,Items={"GcGilded","CwGilded","GildedNum","FxGilded","PetGilded","PcGilded","McGilded"}}
-- a revive bought when it can no longer be used (the round ended) is paid back as marks
S.ReviveRefundMarks=150
S.RevivesPerRound=1
S.ReviveWindow=12 -- seconds after losing your last life
-- the Robux price of a shop item (the green Robux button beside its marks price): its marks price at RobuxPerMark,
-- rounded to the nearest RobuxStep and never under RobuxMin. 300 marks = 10 R$, 900 = 30, 1350 = 45, 1800 = 60,
-- 2400 = 80. An item can set its own with Robux = <price> in its catalog entry.
-- To sell an item for Robux, add a developer product for it to ItemProducts: ItemProducts.<ItemId> = <product id>.
-- (Its price on the Creator Hub should match. Until then its Robux button says COMING SOON.)
S.RobuxPerMark=1/30
S.RobuxStep=5
S.RobuxMin=10
S.ItemProducts={
	-- Fluffy = 0,
}
function S.RobuxFor(item)
	if not item or (item.Price or 0)<=0 then return nil end
	if item.Robux then return item.Robux end
	return math.max(S.RobuxMin,math.floor(item.Price*S.RobuxPerMark/S.RobuxStep+.5)*S.RobuxStep)
end
function S.ByItem(itemId)
	for key,p in pairs(S.Products)do if p.Kind=="Item" and p.Item==itemId then return key,p end end
end
return S
