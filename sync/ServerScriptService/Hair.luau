-- Hairstyles on real characters. Placement/tint come from ReplicatedStorage.Numberfall.HairFit (shared with
-- the menu thumbnails). Worn as a plain Model welded to the head (no legacy HeadWeld).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS:WaitForChild("Numberfall"):WaitForChild("HairCatalog"))
local Fit=require(RS.Numberfall:WaitForChild("HairFit"))
local Hair={}

function Hair.Unequip(character)
	local m=character:FindFirstChild("Hair");if m then m:Destroy() end
end

function Hair.Equip(character,styleId,colorId)
	local head=character:FindFirstChild("Head");if not head then return nil end
	local player=Players:GetPlayerFromCharacter(character)
	styleId=styleId or (player and player:GetAttribute("HairStyle")) or Catalog.DefaultStyle
	colorId=colorId or (player and player:GetAttribute("HairColor")) or Catalog.DefaultColor
	-- the visor sits on top of the bangs: tell VisorDisplay how much to widen its ring for this style
	character:SetAttribute("VisorPad",(styleId~="None" and Fit.VisorPad[styleId]) or 0)
	if styleId=="None" or not Fit.Template(styleId) or not Fit.Template(styleId):FindFirstChild("Handle") then Hair.Unequip(character);return nil end
	local existing=character:FindFirstChild("Hair")
	if existing and existing:GetAttribute("StyleId")==styleId then
		local h=existing:FindFirstChild("Handle");if h then Fit.Tint(h,colorId) end
		existing:SetAttribute("ColorId",colorId);Fit.ApplyTuck(character);return existing
	end
	Hair.Unequip(character)
	local handle,offset,resolved=Fit.Build(head,styleId,colorId);if not handle then return nil end
	local model=Instance.new("Model");model.Name="Hair"
	model:SetAttribute("StyleId",resolved);model:SetAttribute("ColorId",colorId)
	handle.Parent=model;model.PrimaryPart=handle
	local weld=Instance.new("Weld");weld.Name="HairWeld";weld.Part0,weld.Part1=head,handle;weld.C0=offset;weld.Parent=handle
	model.Parent=character
	Fit.ApplyTuck(character) -- tucked in under a hood, if one is worn
	return model
end
return Hair
