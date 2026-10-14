-- Server: dresses characters in their equipped outfit (player attribute Outfit, bought in the Shop) and gives the
-- uncovered body (head, hands, bare arms) the player's own Roblox skin tone (player attribute SkinTone).
local Players = game:GetService("Players")
local Outfits = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Outfits"))
local Outfit = {}

function Outfit.Equip(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	local id = player:GetAttribute("Outfit") or Outfits.Default
	local cw = player:GetAttribute("OutfitColor") or Outfits.DefaultColorway
	local skin = player:GetAttribute("SkinTone")
	local holder = character:FindFirstChild("Outfit")
	-- already wearing exactly this: only make sure the bare skin (hands, head, uncovered arms) is still the skin tone
	if holder and holder:GetAttribute("OutfitId") == id and holder:GetAttribute("Colorway") == cw and character:GetAttribute("SkinApplied") == tostring(skin) then
		Outfit.Skin(character)
		return
	end
	Outfits.Apply(character, id, skin, cw)
	character:SetAttribute("SkinApplied", tostring(skin))
	Outfit.Guard(character)
end

-- The hands (and head) always show the player's skin tone. Roblox can repaint body colours after spawn
-- (appearance / HumanoidDescription loading) and can even swap the body part instances; if that happens, put the
-- skin tone straight back.
local SKIN_PARTS = {LeftHand = true, RightHand = true, Head = true}
local function skinOf(character)
	local player = Players:GetPlayerFromCharacter(character)
	local skin = player and player:GetAttribute("SkinTone")
	return typeof(skin) == "Color3" and skin or Outfits.DefaultSkin
end
-- repaint every bare body part (not covered by the outfit) in the skin tone
function Outfit.Skin(character)
	local skin = skinOf(character)
	local player = Players:GetPlayerFromCharacter(character)
	local outfit = Outfits.ById[(player and player:GetAttribute("Outfit")) or ""] or Outfits.ById[Outfits.Default]
	local covered = Outfits.Covered and Outfits.Covered(outfit) or {}
	for name in pairs(Outfits.BodyParts) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") and not covered[name] then
			if part.Color ~= skin then part.Color = skin end
			if part:IsA("MeshPart") and part.TextureID ~= "" then part.TextureID = "" end
			local sa = part:FindFirstChildOfClass("SurfaceAppearance"); if sa then sa:Destroy() end
		end
	end
end
local function guardPart(character, part)
	if not part:IsA("BasePart") or not SKIN_PARTS[part.Name] or part:GetAttribute("SkinGuarded") then return end
	part:SetAttribute("SkinGuarded", true)
	part:GetPropertyChangedSignal("Color"):Connect(function()
		local skin = skinOf(character)
		if part.Color ~= skin then task.defer(function() if part.Parent then part.Color = skin end end) end
	end)
	local skin = skinOf(character)
	if part.Color ~= skin then part.Color = skin end
end
function Outfit.Guard(character)
	if character:GetAttribute("SkinGuard") then return end
	character:SetAttribute("SkinGuard", true)
	for _, part in ipairs(character:GetChildren()) do guardPart(character, part) end
	-- replaced hands / head (avatar appearance loading) get guarded too
	character.ChildAdded:Connect(function(child) task.defer(function() if child.Parent == character then guardPart(character, child) end end) end)
	-- a BodyColors object would fight the outfit colours: remove any that appears
	local function noBodyColors(child) if child:IsA("BodyColors") then task.defer(function() child:Destroy() end) end end
	for _, c in ipairs(character:GetChildren()) do noBodyColors(c) end
	character.ChildAdded:Connect(noBodyColors)
end

-- The avatar's skin tone. Dynamic (animated) heads bake the skin into the head's texture and leave the head colour
-- at Roblox's default grey, so the arms are checked first; any part still at a Roblox default grey/white is skipped
-- (falling back to a natural default skin tone rather than painting grey hands).
local DEFAULT_GREYS = {Color3.fromRGB(163, 162, 165), Color3.fromRGB(242, 243, 243), Color3.fromRGB(248, 248, 248), Color3.fromRGB(161, 165, 162),
	Color3.fromRGB(99, 95, 98), Color3.fromRGB(27, 42, 53), Color3.fromRGB(17, 17, 17)}
local function isDefaultGrey(c)
	for _, g in ipairs(DEFAULT_GREYS) do
		if math.abs(c.R - g.R) + math.abs(c.G - g.G) + math.abs(c.B - g.B) < 0.03 then return true end
	end
	-- any near-neutral grey (no warmth at all) isn't a skin tone either
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	return mx - mn < 0.02
end
function Outfit.PickSkin(desc)
	for _, key in ipairs({"LeftArmColor", "RightArmColor", "HeadColor", "TorsoColor", "LeftLegColor"}) do
		local ok, c = pcall(function() return desc[key] end)
		if ok and typeof(c) == "Color3" and not isDefaultGrey(c) then return c end
	end
	return Outfits.DefaultSkin
end
-- Read the player's skin tone from their Roblox avatar once per session.
function Outfit.LoadSkin(player)
	task.spawn(function()
		local ok, desc
		for attempt = 1, 3 do
			ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId)) end)
			if ok and desc then break end
			task.wait(attempt * 2)
		end
		if not player.Parent then return end
		if ok and desc then player:SetAttribute("SkinTone", Outfit.PickSkin(desc)) end
		if player.Character then Outfit.Equip(player.Character) end
	end)
end

return Outfit
