-- Hairstyles and hair colours. Ids match ServerStorage.MARKED_Hair.<Id> templates.
-- Price 0 = free (default unlock). Gender is a tag for the shop filter only; anyone can wear anything.
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local styles={
    {Id="None",        Name="No Hair",        Gender="", Price=0},
    {Id="WolfMessy",   Name="Messy Crop",       Gender="M",Price=0},
    {Id="WolfLayered", Name="Long Layers",   Gender="F",Price=0},
    {Id="WolfShag",Rarity="Uncommon",    Name="Shaggy",           Gender="M",Price=750},
    {Id="WolfFluff",Rarity="Rare",   Name="Fluffy",    Gender="M",Price=1050},
    {Id="WolfStorm",Rarity="Epic",   Name="Spiky",          Gender="M",Price=1500},
    {Id="WolfSweep",Rarity="Uncommon",   Name="Side Part",     Gender="M",Price=750},
    {Id="WolfShoulder",Rarity="Rare",Name="Shoulder Length",  Gender="F",Price=1050},
    {Id="WolfPony",Rarity="Epic",    Name="Ponytail", Gender="F",Price=1500},
    {Id="WolfBob",Rarity="Uncommon",     Name="Bob",     Gender="F",Price=750},
    {Id="EmoSidePony",Rarity="Rare", Name="Emo Side Ponytail", Gender="F",Price=1050},
}
-- retired hairstyles: anyone who bought one gets the marks back on their next join (ProfileService), and their
-- colours for it too
local retired={GirlPigtails=750,GirlBraids=1050,GirlBraidBun=1050,GirlSpaceBuns=1500,GirlWavy=1500}
local colors={
    {Id="Ink",     Name="Ink",      Color={18,14,16},   Price=0},
    {Id="Ash",     Name="Ash",      Color={60,58,62},   Price=0},
    -- paid colours are bought per hairstyle, in the Loadout (Hair > Colours), not in the shop
    {Id="Espresso",Rarity="Common",Name="Espresso", Color={58,34,24},   Price=300},
    {Id="Auburn",Rarity="Uncommon",  Name="Auburn",   Color={120,42,30},  Price=450},
    {Id="Blood",Rarity="Rare",   Name="Blood",    Color={150,12,28},  Price=600},
    {Id="Bone",Rarity="Uncommon",    Name="Bone",     Color={214,206,196},Price=450},
    {Id="Violet",Rarity="Rare",  Name="Violet",   Color={88,40,120},  Price=600},
    {Id="Cobalt",Rarity="Rare",  Name="Cobalt",   Color={34,56,130},  Price=600},
    {Id="Platinum",Name="Platinum", Color={232,228,216},Price=99999,Premium="HC_Platinum"},
    {Id="Ember",   Name="Ember",    Color={214,72,24},  Price=99999,Premium="HC_Ember"},
}
-- rarity tiers set the prices (ReplicatedStorage.Numberfall.Rarity)
Rarity.Apply(styles,"item")
-- Face masks (worn under the visor). The default look is no hair, no mask: just the visor.
local masks={
    {Id="NoMask",  Name="No mask",  Price=0},
    {Id="Scarf",Rarity="Uncommon",   Name="Scarf",    Price=900},
}
Rarity.Apply(masks,"item");Rarity.Apply(colors,"colour")
return {Styles=styles,Colors=colors,Masks=masks,Retired=retired,DefaultStyle="None",DefaultColor="Ink",DefaultMask="NoMask"}
