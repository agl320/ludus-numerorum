local Rarity = require(script.Parent:WaitForChild("Rarity"))
local items={
    {Id="Classic",Name="Field notes",Price=0,Color={107,78,53},Pencil={221,171,48}},
    -- (the other notebook finishes were retired: colourways (Numberfall.GearColorways) recolour the gear instead;
    -- their marks are refunded on load: ProfileService RETIRED_GEAR)
    -- typing gear: Device swaps the notebook and pen for a machine (StarterPlayerScripts.NotebookModel DEVICES).
    -- Color = the body, Pencil = the trim / glow (and the keyboard's screen text)
    {Id="Typewriter",Rarity="Legendary",Name="Typewriter",Device="Typewriter",Color={46,52,48},Pencil={196,160,92},
        Blurb="A field typewriter with brass trim. Your numbers clack onto the sheet in type."},
    {Id="Keyboard",Rarity="Epic",Name="Keyboard",Device="Keyboard",Color={28,28,34},Pencil={70,255,150},
        Blurb="A backlit keyboard with a pop-up screen. Your numbers glow on it in green code."},
}

-- rarity tiers set the prices (ReplicatedStorage.Numberfall.Rarity)
Rarity.Apply(items,"item")
return items
