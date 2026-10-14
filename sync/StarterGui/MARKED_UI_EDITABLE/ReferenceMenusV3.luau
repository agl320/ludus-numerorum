-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
local M={};M.__index=M
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local previewNames={"GLITCH","BLOOD","SAKURA","CURSED","STATIC","HOLLOW"}
local HairCatalog=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("HairCatalog"))
-- Category 1 = HAIR: styles first, then colours, 6 per page
local HAIR=1
local hairList={}
for _,s in ipairs(HairCatalog.Styles)do table.insert(hairList,{Id=s.Id,Name=s.Name,Price=s.Price,Rarity=s.Rarity,Kind="style",Gender=s.Gender})end
local MASKS=7
-- Category 2 = CLOTHING (Numberfall.Outfits): bought and equipped like hair (kind "outfit")
local CLOTHES=2
local Outfits=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Outfits"))
local outfitList={}
for _,o in ipairs(Outfits.List)do table.insert(outfitList,{Id=o.Id,Name=o.Name,Price=o.Price,Rarity=o.Rarity,Kind="outfit",Blurb=o.Blurb,CaseOnly=o.CaseOnly})end
-- the shop's clothing list: case-exclusive outfits only show once you own one
local function outfitShopList(p)
 local t={}
 for _,it in ipairs(outfitList)do if not it.CaseOnly or (p and p:GetAttribute("OwnHair_"..it.Id)==true) then table.insert(t,it) end end
 return t
end
local function outfitName(id)local o=Outfits.ById[id or ""] or Outfits.ById[Outfits.Default];return o.Name end
-- clothing colourways (Loadout > Clothing > Colours): bought per outfit, like hair colours
local colorwayList={}
for _,c in ipairs(Outfits.Colorways)do table.insert(colorwayList,{Id=c.Id,Name=c.Name,Price=c.Price,Rarity=c.Rarity,Kind="colorway",Premium=c.Premium,Vip=c.Vip})end
-- colourway entries for one outfit (cached so the selection keeps its identity); ForOutfit = the outfit they dye
local cwListFor={}
local function colorwaysFor(outfitId)
 local list=cwListFor[outfitId]
 if not list then
  list={}
  for _,c in ipairs(colorwayList)do table.insert(list,{Id=c.Id,Name=c.Name,Price=c.Price,Rarity=c.Rarity,Kind="colorway",Premium=c.Premium,Vip=c.Vip,ForOutfit=outfitId})end
  cwListFor[outfitId]=list
 end
 return list
end
local function colorwayName(id)local c=Outfits.ColorwayById[id or ""];return c and c.Name or "Original" end
-- Category 0 = NUMBER STYLES (Numberfall.NumberStyles): how your visor draws your number; bought / equipped like hair (kind "numstyle")
local NUMS=0
local ZOOM_MAX=6
-- picking something frames the preview on it: number styles -> the visor, hair / masks -> the head, clothing -> full body
local FOCUS={gearcolor=1,visor=3.2,visorcolor=3.2,trail=1,trailcolor=1,numstyle=4.6,style=3.2,color=3.2,mask=3.6,maskcolor=3.6,outfit=1,colorway=1,body=1,killfx=1,pet=1,petcolor=1}
-- (every tab opens on the whole figure; picking an item still eases in on it, scroll zooms as before)
local TAB_FOCUS={}
local NumberStyles=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("NumberStyles"))
local numList={}
for _,s in ipairs(NumberStyles.List)do table.insert(numList,{Id=s.Id,Name=s.Name,Price=s.Price,Rarity=s.Rarity,Kind="numstyle",Premium=s.Premium,Vip=s.Vip,Blurb=s.Blurb,Color=s.Color,CaseOnly=s.CaseOnly})end
-- the Shop leaves out case-exclusive number styles until you own one (they only drop from cases)
local function numShopList(p)local t={};for _,it in ipairs(numList)do if not it.CaseOnly or p:GetAttribute("OwnHair_"..it.Id)==true then table.insert(t,it)end end;return t end
local function numName(id)return NumberStyles.Get(id).Name end
local maskList={}
for _,m in ipairs(HairCatalog.Masks or {})do table.insert(maskList,{Id=m.Id,Name=m.Name,Price=m.Price,Rarity=m.Rarity,Kind="mask"})end
-- BODY TYPES (tab 6), ELIMINATION FX (tab 3) and PETS (tab 5): Numberfall.Extras, bought / equipped like hair
local NFx=game:GetService("ReplicatedStorage").Numberfall
local Extras=require(NFx:WaitForChild("Extras"))
local KillFX=require(NFx:WaitForChild("KillFX"))
local Pets=require(NFx:WaitForChild("Pets"))
local BodyType=require(NFx:WaitForChild("BodyType"))
local BODY,FXTAB,PETS=6,3,5
local function extraList(src)local t={};for _,x in ipairs(src)do table.insert(t,{Id=x.Id,Name=x.Name,Price=x.Price,Rarity=x.Rarity,Kind=x.Kind,Premium=x.Premium,Vip=x.Vip,Blurb=x.Blurb,Color=x.Color})end;return t end
local bodyList,fxList,petList=extraList(Extras.Bodies),extraList(Extras.KillFX),extraList(Extras.Pets)
local function extraName(id)local x=Extras.Get(id);return x and x.Name or "" end
local EXTRA_TAB={[BODY]=bodyList,[FXTAB]=fxList,[PETS]=petList}
-- VISOR (tab 8) and TRAIL (tab 9): the rank looks (Numberfall.RankLooks). Not bought: VIP / MOD / OWNER unlock them, so
-- the Loadout lists all four with the ones you don't have locked, and they're not in the Shop.
local RankLooks=require(NFx:WaitForChild("RankLooks"))
local VISOR,TRAIL=8,9
local visorList,trailList={},{}
for _,x in ipairs(RankLooks.Visors)do table.insert(visorList,{Id=x.Id,Name=x.Name,Price=0,Rarity=x.Id=="Standard" and "Starter" or "Exclusive",Kind="visor"})end
for _,x in ipairs(RankLooks.Trails)do table.insert(trailList,{Id=x.Id,Name=x.Name,Price=0,Rarity=x.Id=="Standard" and "Starter" or "Exclusive",Kind="trail"})end
local function rankLook(it)return it~=nil and (it.Kind=="visor" or it.Kind=="trail") end
-- the trail colours bought in the Shop / won from cases (Numberfall.TrailColors), listed under TRAIL after the rank
-- trails. Bought / equipped like hair (kind "trailcolor"); case-exclusive ones only show once you own them.
local TrailColors=require(NFx:WaitForChild("TrailColors"))
for _,t in ipairs(TrailColors.List)do table.insert(trailList,{Id=t.Id,Name=t.Name,Price=t.Price,Rarity=t.Rarity,Kind="trailcolor",CaseOnly=t.CaseOnly,Blurb=t.Blurb})end
local function trailListFor(p,shop)
 local t={}
 for _,it in ipairs(trailList)do
  if it.Kind~="trailcolor" then table.insert(t,it)
  elseif p:GetAttribute("OwnHair_"..it.Id)==true or (shop and not it.CaseOnly) then table.insert(t,it) end
 end
 return t
end
-- the standard visor's colourways (Numberfall.VisorColorways), listed under VISOR after the rank visors. Bought /
-- equipped like hair (kind "visorcolor"); case-exclusive ones only show once you own them.
local VisorColorways=require(NFx:WaitForChild("VisorColorways"))
for _,c in ipairs(VisorColorways.List)do if c.Id~=VisorColorways.Default and not c.Hidden then table.insert(visorList,{Id=c.Id,Name=c.Name.." visor",Price=c.Price,Rarity=c.Rarity,Kind="visorcolor",CaseOnly=c.CaseOnly,Blurb=c.Blurb})end end
local function visorListFor(p,shop)
 local t={}
 for _,it in ipairs(visorList)do
  if it.Kind~="visorcolor" then table.insert(t,it)
  elseif it.Price==0 or p:GetAttribute("OwnHair_"..it.Id)==true or (shop and not it.CaseOnly) then table.insert(t,it) end
 end
 return t
end
-- pet colourways for one pet (cached so the selection keeps its identity); ForPet = the pet they dye
local pcListFor={}
local function petColorsFor(petId)
 if not petId then return nil end
 local list=pcListFor[petId]
 if not list then
  list={}
  for _,c in ipairs(Extras.PetColorways)do table.insert(list,{Id=c.Id,Name=c.Name,Price=c.Price,Rarity=c.Rarity,Kind="petcolor",Premium=c.Premium,Vip=c.Vip,ForPet=petId})end
  pcListFor[petId]=list
 end
 return list
end
local function realPet(id)return id~=nil and id~=Extras.DefaultPet and Extras.Get(id)~=nil end
-- mask colourways for one mask (Loadout > Mask > COLOURS); ForMask = the mask they dye
local mcListFor={}
local function maskColorsFor(maskId)
 if not maskId then return nil end
 local list=mcListFor[maskId]
 if not list then
  list={}
  for _,c in ipairs(Extras.MaskColorways)do table.insert(list,{Id=c.Id,Name=c.Name,Price=c.Price,Rarity=c.Rarity,Kind="maskcolor",Premium=c.Premium,Vip=c.Vip,ForMask=maskId,Color=c.Color})end
  mcListFor[maskId]=list
 end
 return list
end
local function realMask(id)if not id or id==HairCatalog.DefaultMask then return false end;for _,m in ipairs(maskList)do if m.Id==id then return true end end;return false end
local function maskColorName(id)local c=Extras.MaskColorwayById[id or ""];return c and c.Name or "Original" end
-- GEAR (tab 4): the notebook / typewriter / keyboard (Numberfall.Catalog) and their colourways (Numberfall.GearColorways),
-- bought per gear item like pet colourways; ForGear = the gear they dye
local GEAR=4
local GearColorways=require(NFx:WaitForChild("GearColorways"))
local GearCatalog=require(NFx:WaitForChild("Catalog"))
local function gearItem(id)for _,it in ipairs(GearCatalog)do if it.Id==id then return it end end;return nil end
local function gearName(id)local it=gearItem(id);return it and it.Name or "gear" end
local function isGearItem(it)return type(it)=="table" and it.Kind==nil and it.Pencil~=nil end
local gcListFor={}
local function gearColorsFor(gearId)
 if not gearId then return nil end
 local list=gcListFor[gearId]
 if not list then
  list={}
  for _,c in ipairs(GearColorways.List)do table.insert(list,{Id=c.Id,Name=c.Name,Price=c.Price,Rarity=c.Rarity,Kind="gearcolor",Premium=c.Premium,Vip=c.Vip,ForGear=gearId,Body=c.Body})end
  gcListFor[gearId]=list
 end
 return list
end
-- the colourway a gear item is kept in (the one you have equipped: GearColor)
local function gearCwOf(p,id)
 if id==(p:GetAttribute("NotebookFinish") or "Classic") then return p:GetAttribute("GearColor") or GearColorways.Default end
 return p:GetAttribute("GearCw_"..id) or GearColorways.Default
end
-- Shop / Loadout tabs, in two groups: what you wear (hair, head, clothing, the number on your visor) | extras
-- (pets, elimination fx, gear). Body type isn't a tab: it's the CLASSIC / FEMININE switch on the preview.
local TAB_ORDER={1,7,2,0,"|",PETS,FXTAB,4}
-- the Loadout also has VISOR (with what you wear) and TRAIL (with the extras); the Shop doesn't sell them
local INV_ORDER={1,7,2,0,VISOR,"|",PETS,FXTAB,TRAIL,4}
for _,c in ipairs(HairCatalog.Colors)do table.insert(hairList,{Id=c.Id,Name=c.Name.." colour",Price=c.Price,Rarity=c.Rarity,Kind="color",Color=c.Color,Premium=c.Premium,Vip=c.Vip})end
-- Robux-only / VIP-only cosmetics: R$ price on the button and a Robux prompt instead of spending marks
local StoreUI=require(script.Parent:WaitForChild("MarksStoreController"))
local StoreCfg=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Store"))
-- shop prices as icons on two separate buttons: the marks sigil + marks price (buys with marks), and a green Robux
-- icon + Robux price (buys with Robux: StoreCfg.ItemProducts / RobuxFor). Laid over a button's Label (blanked while it
-- shows); the row shrinks to fit its button.
local MARKS_ICON="rbxassetid://121549460537528"
local ROBUX_ICON="rbxasset://textures/ui/common/robux.png"
local ROBUX_GREEN=Color3.fromRGB(0,176,111)
local function boost()
 -- (the TextBoost script's scale: these labels are sized here, so it skips them)
 local ps=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
 local tb=ps and ps:FindFirstChild("TextBoost")
 return tb and tb:GetAttribute("Scale") or 1
end
local function priceTag(btn,prefix,img,imgCol,amount,textCol,big)
 local label=btn:FindFirstChild("Label");local tag=btn:FindFirstChild("PriceTag")
 if not (label and amount) then if tag then tag.Visible=false end;return false end
 if not tag then
  tag=Instance.new("Frame");tag.Name="PriceTag";tag.BackgroundTransparency=1;tag.AnchorPoint=Vector2.new(.5,.5)
  tag.Position=UDim2.fromScale(.5,.5);tag.Size=UDim2.fromScale(1,1);tag.ZIndex=label.ZIndex+1;tag:SetAttribute("NoTextBoost",true)
  local list=Instance.new("UIListLayout");list.FillDirection=Enum.FillDirection.Horizontal;list.HorizontalAlignment=Enum.HorizontalAlignment.Center
  list.VerticalAlignment=Enum.VerticalAlignment.Center;list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=tag
  local scale=Instance.new("UIScale");scale.Parent=tag
  local ts=math.floor((label:GetAttribute("BaseTextSize") or label.TextSize)*boost()*(big or 1)+.5)
  list.Padding=UDim.new(0,math.floor(ts*.3+.5))
  local function text(name,order)
   local t=Instance.new("TextLabel");t.Name=name;t.LayoutOrder=order;t.BackgroundTransparency=1;t.FontFace=label.FontFace;t.TextSize=ts
   t.AutomaticSize=Enum.AutomaticSize.X;t.Size=UDim2.new(0,0,1,0);t.ZIndex=tag.ZIndex;t.Parent=tag;return t
  end
  text("Prefix",1)
  local i=Instance.new("ImageLabel");i.Name="Icon";i.LayoutOrder=2;i.BackgroundTransparency=1;i.ScaleType=Enum.ScaleType.Fit
  i.Size=UDim2.fromOffset(ts+2,ts+2);i.ZIndex=tag.ZIndex;i.Parent=tag
  text("Amount",3)
  tag.Parent=btn
  -- (shrink the whole row when it's wider than the button)
  local function fit()
   local s=scale.Scale;local natural=list.AbsoluteContentSize.X/math.max(s,.01)
   local room=btn.AbsoluteSize.X-12
   if natural>0 and room>0 then local want=math.min(1,room/natural);if math.abs(want-s)>.01 then scale.Scale=want end end
  end
  list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit);btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
 end
 tag.Prefix.Text=prefix or "";tag.Prefix.Visible=prefix~=nil;tag.Prefix.TextColor3=label.TextColor3
 tag.Icon.Image=img;tag.Icon.ImageColor3=imgCol or Color3.new(1,1,1)
 tag.Amount.Text=tostring(amount);tag.Amount.TextColor3=textCol or label.TextColor3
 tag.Visible=true
 label.Text=""
 return true
end
-- items bought for one base item (a hair colour for one hairstyle, a colourway for one outfit...) are sold for marks only
local function robuxSellable(item)
 return item and not (item.ForStyle or item.ForOutfit or item.ForMask or item.ForGear or item.ForPet or item.CaseOnly) and StoreCfg.RobuxFor(item) or nil
end
-- a button's own rect, kept the first time (the split layout is worked out from it, and put back when not for sale)
local function rect(o)
 if not o:GetAttribute("RectP") then o:SetAttribute("RectP",o.Position);o:SetAttribute("RectS",o.Size) end
 return o:GetAttribute("RectP"),o:GetAttribute("RectS")
end
-- the green Robux button: a copy of the marks button with a green outline
local function robuxButton(buy,name)
 local rb=buy:Clone();rb.Name=name
 for _,d in ipairs(rb:GetChildren())do if d.Name=="PriceTag" or d.Name=="Glow" or d.Name=="Icon" then d:Destroy() end end
 rb:SetAttribute("RectP",nil);rb:SetAttribute("RectS",nil)
 local o=rb:FindFirstChild("Outline") or rb:FindFirstChildWhichIsA("UIStroke");if o then o.Color=ROBUX_GREEN end
 rb.BackgroundColor3=Color3.fromRGB(10,30,22);rb.AutoButtonColor=true
 if rb:FindFirstChild("Label") then rb.Label.Text="" end
 rb.Visible=false;rb.Parent=buy.Parent
 return rb
end
-- lay out a priced shop button as two: marks (left) and Robux (right), sharing the space; otherwise put it back
function M:SplitPrice(buy,robuxName,item,forSale,big,nameLabel)
 local bp,bs=rect(buy)
 local np,ns;if nameLabel then np,ns=rect(nameLabel) end
 local robux=forSale and robuxSellable(item)
 local rb=buy.Parent:FindFirstChild(robuxName)
 if robux and not rb then
  rb=robuxButton(buy,robuxName)
  rb.Activated:Connect(function() self:BuyRobux(self.robuxFor and self.robuxFor[rb]) end)
 end
 self.robuxFor=self.robuxFor or {}
 if rb then self.robuxFor[rb]=robux and item or nil end
 if robux then
  -- (cards: the name moves up onto the foot of the art, so the two buttons can share the bottom row)
  local x0=nameLabel and np.X.Offset or bp.X.Offset;local right=bp.X.Offset+bs.X.Offset
  local w=math.floor((right-x0-8)/2)
  buy.Position=UDim2.fromOffset(x0,bp.Y.Offset);buy.Size=UDim2.fromOffset(w,bs.Y.Offset)
  rb.Position=UDim2.fromOffset(x0+w+8,bp.Y.Offset);rb.Size=UDim2.fromOffset(right-x0-w-8,bs.Y.Offset);rb.Visible=buy.Visible
  if nameLabel then
   nameLabel.Position=UDim2.fromOffset(np.X.Offset,np.Y.Offset-44);nameLabel.Size=UDim2.fromOffset(right-np.X.Offset,ns.Y.Offset)
   nameLabel.TextStrokeTransparency=.35;nameLabel.TextStrokeColor3=Color3.new(0,0,0);nameLabel.ZIndex=math.max(nameLabel.ZIndex,buy.ZIndex+2)
  end
 else
  buy.Position=bp;buy.Size=bs
  if rb then rb.Visible=false end
  if nameLabel then nameLabel.Position=np;nameLabel.Size=ns;nameLabel.TextStrokeTransparency=1 end
 end
 priceTag(buy,nil,MARKS_ICON,nil,forSale and item and item.Price or nil,nil,big)
 if rb then priceTag(rb,nil,ROBUX_ICON,ROBUX_GREEN,robux or nil,ROBUX_GREEN,big) end
end
-- the Robux button: its developer product (StoreCfg.ItemProducts), or coming soon when there isn't one yet
function M:BuyRobux(item)
 if not item then return end
 local id=StoreCfg.ItemProducts and StoreCfg.ItemProducts[item.Id]
 if type(id)=="number" and id>0 then
  game:GetService("MarketplaceService"):PromptProductPurchase(self.v.player,id)
 else
  self.v:Toast("Buying with Robux is coming soon. Buy it with marks for now.")
 end
end
local function priceText(item,prefix)
 if StoreUI.Locked(item) then return StoreUI.Label(item) end
 return (prefix or "")..tostring(item.Price)
end
-- the shop only sells hairstyles; colours are bought in the Loadout (Hair > Colours) for the hairstyle you're wearing
local shopHair={}
for _,it in ipairs(hairList)do if it.Kind=="style" then table.insert(shopHair,it) end end
-- hair colour entries for one hairstyle (Shop > Hair > COLOURS; cached so the selection keeps its identity).
-- ForStyle = the hairstyle they're bought for (hair colours are owned per hairstyle)
local hcListFor={}
local function hairColorsFor(styleId)
 if not styleId or styleId=="None" then return nil end
 local list=hcListFor[styleId]
 if not list then
  list={}
  for _,c in ipairs(HairCatalog.Colors)do table.insert(list,{Id=c.Id,Name=c.Name.." colour",Price=c.Price,Rarity=c.Rarity,Kind="color",Color=c.Color,Premium=c.Premium,Vip=c.Vip,ForStyle=styleId})end
  hcListFor[styleId]=list
 end
 return list
end
local function styleName(id)for _,s in ipairs(HairCatalog.Styles)do if s.Id==id then return s.Name end end;return "No hair" end
-- Card order inside a tab: free things first, then by price (cheapest first), Robux / VIP-only ones last;
-- ties keep catalogue order.
local byPrice
-- colours on a bald head show nothing: preview them on the default wolf cut instead
local function colourStyle(id)return (id==nil or id=="None") and "WolfMessy" or id end
local function hairOwned(p,item)
 if rankLook(item) then return RankLooks.Owns(p,item.Id) end
 if item.Kind=="color" and item.ForStyle and item.ForStyle~=(p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle) then
  return item.Price==0 or p:GetAttribute("OwnHc_"..item.ForStyle.."_"..item.Id)==true
 end
 if item.Kind=="colorway" and item.ForOutfit then return item.Price==0 or p:GetAttribute("OwnCw_"..item.ForOutfit.."_"..item.Id)==true end
 if item.Kind=="petcolor" then return item.Price==0 or p:GetAttribute("OwnPc_"..tostring(item.ForPet).."_"..item.Id)==true end
 if item.Kind=="maskcolor" then return (item.Price==0 and not item.Vip and not item.Premium) or p:GetAttribute("OwnMc_"..tostring(item.ForMask).."_"..item.Id)==true end
 if item.Kind=="gearcolor" then return (item.Price==0 and not item.Vip and not item.Premium) or p:GetAttribute("OwnGc_"..tostring(item.ForGear).."_"..item.Id)==true end
 return item.Price==0 or p:GetAttribute("OwnHair_"..item.Id)==true
end
function byPrice(list)
 if not list then return nil end
 local rank={}
 for i,it in ipairs(list)do rank[it]=i end
 local t=table.clone(list)
 -- rarest first (Exclusive, Legendary, Epic, Rare, Uncommon, Common, Starter), then dearest first, then catalogue order
 local Tiers=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Rarity"))
 local function tier(it)local r=Tiers.Of(it);return r and r.Rank or 0 end
 table.sort(t,function(a,b)
  local ta,tb=tier(a),tier(b);if ta~=tb then return ta>tb end
  local pa,pb=tonumber(a.Price) or 0,tonumber(b.Price) or 0;if pa~=pb then return pa>pb end
  return rank[a]<rank[b]
 end)
 return t
end
-- what you have on goes first in every Shop / Loadout list (the rest keep their order)
local function equippedFirst(list,isOn)
 if not list then return nil end
 local on,rest={},{}
 for _,it in ipairs(list)do table.insert(isOn(it) and on or rest,it)end
 for _,it in ipairs(rest)do table.insert(on,it)end
 return on
end
-- the colourway an item is kept in (what it's worn in when you put it on): its name and swatch colour; nil when
-- it's in its original colours
local function keptColour(p,item)
 if not item then return nil end
 if item.Kind=="outfit" then
  local id=(item.Id==p:GetAttribute("Outfit")) and p:GetAttribute("OutfitColor") or p:GetAttribute("OutfitCw_"..item.Id)
  local c=Outfits.ColorwayById[id or ""];if c and c.Main then return c.Name,c.Main end
 elseif item.Kind=="mask" then
  local c=Extras.MaskColorwayById[p:GetAttribute("MaskCw_"..item.Id) or ""]
  if c and type(c.Color)=="table" then return c.Name,Color3.fromRGB(c.Color[1],c.Color[2],c.Color[3]) end
  if c and typeof(c.Color)=="Color3" then return c.Name,c.Color end
 elseif item.Kind=="pet" then
  local c=Extras.PetColorwayById[p:GetAttribute("PetCw_"..item.Id) or ""];if c and c.Main then return c.Name,c.Main end
 elseif isGearItem(item) then
  local c=GearColorways.ById[gearCwOf(p,item.Id)];if c and c.Body then return c.Name,c.Body end
 elseif item.Kind=="style" and item.Id~="None" then
  local id=(item.Id==p:GetAttribute("HairStyle")) and p:GetAttribute("HairColor") or p:GetAttribute("HairCol_"..item.Id)
  if id and id~=HairCatalog.DefaultColor then for _,c in ipairs(HairCatalog.Colors)do if c.Id==id then return c.Name,Color3.fromRGB(c.Color[1],c.Color[2],c.Color[3]) end end end
 end
 return nil
end
-- a round swatch + the colourway's name in the corner of a card's art (removed when there's nothing to show)
local CHIP_FONT=Font.new("rbxasset://fonts/families/Balthazar.json",Enum.FontWeight.Bold)
-- one small pill in the bottom-right corner of the art: [● BONE]. right / bottom = that corner (card offsets).
local function colourChip(card,name,color,right,bottom)
 local pill=card:FindFirstChild("ColourChip")
 if not color then if pill then pill:Destroy() end;return end
 if not pill then
  pill=Instance.new("Frame");pill.Name="ColourChip";pill.BorderSizePixel=0;pill.AnchorPoint=Vector2.new(1,1)
  pill.BackgroundColor3=Color3.fromRGB(10,6,8);pill.BackgroundTransparency=.3;pill.AutomaticSize=Enum.AutomaticSize.X;pill.Size=UDim2.fromOffset(0,26)
  local cr=Instance.new("UICorner");cr.CornerRadius=UDim.new(1,0);cr.Parent=pill
  local st=Instance.new("UIStroke");st.Color=Color3.fromRGB(255,255,255);st.Transparency=.85;st.Thickness=1;st.Parent=pill
  local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,7);pad.PaddingRight=UDim.new(0,10);pad.Parent=pill
  local ll=Instance.new("UIListLayout");ll.FillDirection=Enum.FillDirection.Horizontal;ll.VerticalAlignment=Enum.VerticalAlignment.Center;ll.Padding=UDim.new(0,6);ll.SortOrder=Enum.SortOrder.LayoutOrder;ll.Parent=pill
  local dot=Instance.new("Frame");dot.Name="Dot";dot.BorderSizePixel=0;dot.Size=UDim2.fromOffset(13,13);dot.LayoutOrder=1;dot.Parent=pill
  local dc=Instance.new("UICorner");dc.CornerRadius=UDim.new(1,0);dc.Parent=dot
  local ds=Instance.new("UIStroke");ds.Color=Color3.fromRGB(255,255,255);ds.Transparency=.55;ds.Thickness=1;ds.Parent=dot
  local t=Instance.new("TextLabel");t.Name="Label";t.BackgroundTransparency=1;t.FontFace=CHIP_FONT;t.TextSize=15;t.TextColor3=Color3.fromRGB(226,218,214)
  t.AutomaticSize=Enum.AutomaticSize.X;t.Size=UDim2.fromOffset(0,26);t.LayoutOrder=2;t.Parent=pill
  pill.Parent=card
 end
 local z=(card.ZIndex or 1)+5
 pill.ZIndex=z;pill.Dot.ZIndex=z+1;pill.Label.ZIndex=z+1
 pill.Dot.BackgroundColor3=color;pill.Label.Text=name:upper()
 pill.Position=UDim2.fromOffset(right,bottom)
end
-- RARITY (ReplicatedStorage.Numberfall.Rarity): a pill in the top-right corner of a card's art ([◆ RARE] in the tier's
-- colour) and a soft glow + line in that colour along the bottom of the art. rect = the card's art rect.
local Rarity=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Rarity"))
local RARITY_FONT=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold)
local function rarityPill(parent,tier,name)
 local pill=parent:FindFirstChild(name or "RarityChip")
 if not tier then if pill then pill.Visible=false end;return nil end
 if not pill then
  pill=Instance.new("Frame");pill.Name=name or "RarityChip";pill.BorderSizePixel=0
  pill.BackgroundColor3=Color3.fromRGB(10,6,8);pill.BackgroundTransparency=.2;pill.AutomaticSize=Enum.AutomaticSize.X;pill.Size=UDim2.fromOffset(0,22)
  local cr=Instance.new("UICorner");cr.CornerRadius=UDim.new(0,4);cr.Parent=pill
  local st=Instance.new("UIStroke");st.Name="Edge";st.Thickness=1;st.Transparency=.25;st.Parent=pill
  local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,8);pad.PaddingRight=UDim.new(0,9);pad.Parent=pill
  local ll=Instance.new("UIListLayout");ll.FillDirection=Enum.FillDirection.Horizontal;ll.VerticalAlignment=Enum.VerticalAlignment.Center;ll.Padding=UDim.new(0,6);ll.SortOrder=Enum.SortOrder.LayoutOrder;ll.Parent=pill
  local gem=Instance.new("Frame");gem.Name="Gem";gem.BorderSizePixel=0;gem.Size=UDim2.fromOffset(7,7);gem.Rotation=45;gem.LayoutOrder=1;gem.Parent=pill
  local t=Instance.new("TextLabel");t.Name="Label";t.BackgroundTransparency=1;t.FontFace=RARITY_FONT;t.TextSize=12
  t.AutomaticSize=Enum.AutomaticSize.X;t.Size=UDim2.fromOffset(0,22);t.LayoutOrder=2;t.Parent=pill
  pill.Parent=parent
 end
 pill.Visible=true
 pill.Edge.Color=tier.Color3;pill.Gem.BackgroundColor3=tier.Color3
 pill.Label.Text=tier.Name;pill.Label.TextColor3=tier.Color3
 return pill
end
local function rarityTag(card,item,rect)
 local tier=item and Rarity.Of(item) or nil
 local glow,line=card:FindFirstChild("RarityGlow"),card:FindFirstChild("RarityLine")
 local fancy=tier and tier.Id~="Starter"
 if not fancy then if glow then glow.Visible=false end;if line then line.Visible=false end end
 local pill=rarityPill(card,tier)
 if not tier or not rect then return end
 local ax,ay=rect.Position.X.Offset,rect.Position.Y.Offset
 local aw,ah=rect.Size.X.Offset,rect.Size.Y.Offset
 local z=(card.ZIndex or 1)
 pill.AnchorPoint=Vector2.new(1,0);pill.Position=UDim2.fromOffset(ax+aw-8,ay+8)
 pill.ZIndex=z+6;pill.Gem.ZIndex=z+7;pill.Label.ZIndex=z+7
 if not fancy then return end
 if not glow then
  glow=Instance.new("Frame");glow.Name="RarityGlow";glow.BorderSizePixel=0;glow.Active=false
  local g=Instance.new("UIGradient");g.Rotation=90
  g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.72)});g.Parent=glow
  glow.Parent=card
 end
 if not line then line=Instance.new("Frame");line.Name="RarityLine";line.BorderSizePixel=0;line.Active=false;line.Parent=card end
 glow.Visible=true;line.Visible=true
 glow.BackgroundColor3=tier.Color3;line.BackgroundColor3=tier.Color3
 glow.Position=UDim2.fromOffset(ax,ay+ah-46);glow.Size=UDim2.fromOffset(aw,46);glow.ZIndex=z+3
 line.Position=UDim2.fromOffset(ax,ay+ah-2);line.Size=UDim2.fromOffset(aw,2);line.ZIndex=z+4
end
local Art=require(script.Parent:WaitForChild("LoadoutArt"))
local Style=require(script.Parent:WaitForChild("LoadoutStyle"))
local Preview=require(script.Parent:WaitForChild("LoadoutPreview"))
local PanelStyle=require(script.Parent:WaitForChild("PanelStyle"))
local function SafeArt(fn,...)local ok,err=pcall(fn,...);if not ok then warn("[Loadout art] "..tostring(err))end end
-- The menus refresh several times a second; only rebuild a card's 3D art when what it shows actually changed
-- (rebuilding a ViewportFrame blanks it for a few frames, which made the thumbnails flash).
-- what the card mannequins wear besides the item (hair, mask, body): part of the art key so a reset redraws them
local function lookKey(p)
 return ":"..tostring(p:GetAttribute("HairStyle"))..":"..tostring(p:GetAttribute("HairColor"))..":"..tostring(p:GetAttribute("FaceMask"))..":"..tostring(p:GetAttribute("BodyType"))
end
-- Card art (3D thumbnails in ViewportFrames) is the slow part of switching tabs / pages: building six figures in
-- one frame froze the game. So: the art a card had is kept (by what it showed and the card's size) when the card
-- moves on, and put straight back when that same thing is shown again; new art is built one card per frame.
local ART_NAMES={"HairArt","SwatchArt","NumberArt","NotebookArt","SwatchChip"}
local artCache,artOrder={},{} -- cache key -> {instances}; oldest first
local ART_CACHE_MAX=48
local artQueue={}             -- cards waiting for art: {card=,key=,fn=}
local function cacheKey(card,key) return key.."|"..card.Size.X.Offset.."x"..card.Size.Y.Offset end
local function stashArt(card)
 local old=card:GetAttribute("ArtKey");local got={}
 for _,n in ipairs(ART_NAMES)do local o=card:FindFirstChild(n);if o then o.Parent=nil;table.insert(got,o) end end
 if not old or #got==0 then for _,o in ipairs(got)do o:Destroy() end;return end
 local ck=cacheKey(card,old)
 if artCache[ck] then for _,o in ipairs(got)do o:Destroy() end;return end
 artCache[ck]=got;table.insert(artOrder,ck)
 while #artOrder>ART_CACHE_MAX do
  local gone=table.remove(artOrder,1);local list=artCache[gone];artCache[gone]=nil
  if list then for _,o in ipairs(list)do o:Destroy() end end
 end
end
game:GetService("RunService").Heartbeat:Connect(function()
 -- one card's art per frame (skipping cards that have since moved on to something else)
 while #artQueue>0 do
  local job=table.remove(artQueue,1)
  if job.card.Parent and job.card:GetAttribute("ArtKey")==job.key then
   Art.Clear(job.card)
   local ok,err=pcall(job.fn);if not ok then warn("[Loadout art] "..tostring(err)) end
   break
  end
 end
end)
local function Draw(card,key,fn)
 if card:GetAttribute("ArtKey")==key then return end
 stashArt(card);Art.Clear(card);card:SetAttribute("ArtKey",key)
 for i=#artQueue,1,-1 do if artQueue[i].card==card then table.remove(artQueue,i) end end
 local ck=cacheKey(card,key);local cached=artCache[ck]
 if cached then
  artCache[ck]=nil;table.remove(artOrder,table.find(artOrder,ck))
  for _,o in ipairs(cached)do o.Parent=card end
  return
 end
 if fn then table.insert(artQueue,{card=card,key=key,fn=fn}) end
end
local function hairEquipped(p,item)
 if item.Kind=="visor" then return RankLooks.Visor(p)==item.Id and (item.Id~="Standard" or not VisorColorways.Tinted(p:GetAttribute("VisorColor"))) end
 if item.Kind=="visorcolor" then return RankLooks.Visor(p)=="Standard" and (p:GetAttribute("VisorColor") or VisorColorways.Default)==item.Id end
 if item.Kind=="trail" or item.Kind=="trailcolor" then return RankLooks.Trail(p)==item.Id end
 if item.Kind=="color" and item.ForStyle then return (p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle)==item.ForStyle and p:GetAttribute("HairColor")==item.Id end
 if item.Kind=="mask" then return (p:GetAttribute("FaceMask") or HairCatalog.DefaultMask)==item.Id end
 if item.Kind=="petcolor" then return p:GetAttribute("Pet")==item.ForPet and (p:GetAttribute("PetColor") or Extras.DefaultPetColorway)==item.Id end
 if item.Kind=="maskcolor" then return p:GetAttribute("FaceMask")==item.ForMask and (p:GetAttribute("MaskColor") or Extras.DefaultMaskColorway)==item.Id end
 if item.Kind=="gearcolor" then return (p:GetAttribute("NotebookFinish") or "Classic")==item.ForGear and (p:GetAttribute("GearColor") or GearColorways.Default)==item.Id end
 if Extras.Field[item.Kind] then return (p:GetAttribute(Extras.Field[item.Kind]) or Extras.Default[item.Kind])==item.Id end
 if item.Kind=="outfit" then return (p:GetAttribute("Outfit") or Outfits.Default)==item.Id end
 if item.Kind=="colorway" then
  local worn=p:GetAttribute("Outfit") or Outfits.Default
  return (item.ForOutfit==nil or item.ForOutfit==worn) and (p:GetAttribute("OutfitColor") or Outfits.DefaultColorway)==item.Id
 end
 if item.Kind=="numstyle" then return (p:GetAttribute("NumberStyle") or NumberStyles.Default)==item.Id end
 return (item.Kind=="style" and (p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle) or p:GetAttribute("HairColor"))==item.Id
end
-- Colourways of something you're only previewing (picked in the Shop, not owned) can be browsed and tried on;
-- they're bought once you own the outfit / pet / mask itself. cwBase: the item a colourway dyes, and its name.
local function cwBase(item)
 if item.Kind=="colorway" and item.ForOutfit then return item.ForOutfit,outfitName(item.ForOutfit) end
 if item.Kind=="petcolor" then return item.ForPet,extraName(item.ForPet) end
 if item.Kind=="maskcolor" then local n="mask";for _,m in ipairs(maskList)do if m.Id==item.ForMask then n=m.Name end end;return item.ForMask,n end
 if item.Kind=="gearcolor" then return item.ForGear,gearName(item.ForGear) end
 if item.Kind=="color" and item.ForStyle then return item.ForStyle,styleName(item.ForStyle) end
 return nil
end
local function cwBaseOwned(p,item)
 local id=cwBase(item);if not id then return true end
 if item.Kind=="gearcolor" then local g=gearItem(id);return (g~=nil and (g.Price or 0)==0) or p:GetAttribute("Own_"..id)==true end
 if item.Kind=="colorway" then local o=Outfits.ById[id];if o and (o.Price or 0)==0 then return true end end
 return p:GetAttribute("OwnHair_"..id)==true
end
-- hair colours are owned per hairstyle: OwnHair_<colour> covers the one you wear, OwnHc_<style>_<colour> any other
local function colourOwnedFor(p,item,style)
 local worn=p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle
 if style==nil or style==worn then return hairOwned(p,item) end
 return item.Price==0 or p:GetAttribute("OwnHc_"..style.."_"..item.Id)==true
end
-- BODY switch: [ BODY | CLASSIC | FEMININE ] pill with a red slider under the body you have
local BuildBodySwitch
local SW_FONT=Font.new("rbxasset://fonts/families/Balthazar.json",Enum.FontWeight.Bold)
local SW_SEG,SW_CAP,SW_H=96,58,32
function BuildBodySwitch(parent,list)
 local sw=Instance.new("Frame");sw.Name="BodySwitch";sw.Position=UDim2.fromOffset(14,14);sw.Size=UDim2.fromOffset(SW_CAP+SW_SEG*#list+6,SW_H)
 sw.BackgroundColor3=Color3.fromRGB(12,8,10);sw.BackgroundTransparency=.12;sw.ZIndex=40
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=sw
 local st=Instance.new("UIStroke");st.Color=Color3.fromRGB(110,20,40);st.Thickness=1;st.Parent=sw
 local cap=Instance.new("TextLabel");cap.Name="Caption";cap.BackgroundTransparency=1;cap.Text="BODY";cap.FontFace=SW_FONT;cap.TextSize=13
 cap.TextColor3=Color3.fromRGB(150,134,138);cap.Size=UDim2.fromOffset(SW_CAP,SW_H);cap.ZIndex=41;cap.Parent=sw
 local div=Instance.new("Frame");div.Name="Divider";div.BorderSizePixel=0;div.BackgroundColor3=Color3.fromRGB(70,26,36);div.Position=UDim2.fromOffset(SW_CAP,7)
 div.Size=UDim2.fromOffset(1,SW_H-14);div.ZIndex=41;div.Parent=sw
 local slider=Instance.new("Frame");slider.Name="Slider";slider.BackgroundColor3=Color3.fromRGB(150,10,36);slider.Position=UDim2.fromOffset(SW_CAP+3,3)
 slider.Size=UDim2.fromOffset(SW_SEG,SW_H-6);slider.ZIndex=41;slider.Parent=sw
 local sc=Instance.new("UICorner");sc.CornerRadius=UDim.new(0,4);sc.Parent=slider
 local ss=Instance.new("UIStroke");ss.Color=Color3.fromRGB(255,70,100);ss.Thickness=1;ss.Transparency=.25;ss.Parent=slider
 local sg=Instance.new("UIGradient");sg.Rotation=90;sg.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(170,170,170));sg.Parent=slider
 for i,b in ipairs(list)do
  local seg=Instance.new("TextButton");seg.Name="Seg"..i;seg.AutoButtonColor=false;seg.BackgroundTransparency=1;seg.Text=b.Name:upper()
  seg.FontFace=SW_FONT;seg.TextSize=15;seg.TextColor3=Color3.fromRGB(150,134,138);seg.Position=UDim2.fromOffset(SW_CAP+3+(i-1)*SW_SEG,3)
  seg.Size=UDim2.fromOffset(SW_SEG,SW_H-6);seg.ZIndex=42;seg.Parent=sw
 end
 sw.Parent=parent
 return sw
end
function M:BodySwitchLook()
 for _,s in ipairs(self.bodySwitches or {self.bodySwitch})do self:BodySwitchOne(s) end
end
function M:BodySwitchOne(sw)
 if not sw or not sw.Parent then return end
 local p=self.v.player;local on=1
 for i,b in ipairs(bodyList)do
  local seg=sw:FindFirstChild("Seg"..i)
  local eq=hairEquipped(p,b);if eq then on=i end
  if seg then seg.TextColor3=eq and Color3.fromRGB(240,232,228) or Color3.fromRGB(150,134,138) end
 end
 local slider=sw:FindFirstChild("Slider");local seg=sw:FindFirstChild("Seg"..on)
 if slider and seg then
  local goal=UDim2.new(seg.Position.X.Scale,seg.Position.X.Offset,slider.Position.Y.Scale,slider.Position.Y.Offset)
  if slider.Position~=goal then game:GetService("TweenService"):Create(slider,TweenInfo.new(.18,Enum.EasingStyle.Quint),{Position=goal}):Play() end
 end
end
function M.new(v)
 local self=setmetatable({v=v,g=v.gui,category=1,selected=1,inventoryPage=1,inventoryCategory=1,models={},angle=0,targetAngle=0,questTab=0,
  zoom={Shop=1,Inventory=1},zoomT={Shop=1,Inventory=1},cams={}},M)
 local g=self.g
 pcall(function()Style.Apply(g.Inventory,g.ArtworkAssetIds.MarksIcon.Value)end)
 -- Shop / Quests / Settings / Credits share the Loadout framework
 for _,n in ipairs({"Shop","Quests","Settings","Credits","Help"})do local ok,err=pcall(PanelStyle[n],g[n]);if not ok then warn("[PanelStyle] "..n..": "..tostring(err))end end
 -- Help (H): BACK closes it; the sprint / slide key caps follow your key settings each time it opens
 do
  local hc=g.Help:FindFirstChild("Close");if hc then hc.Activated:Connect(function()v:Show("HUD")end) end
  g.Help:GetPropertyChangedSignal("Visible"):Connect(function()if g.Help.Visible then pcall(PanelStyle.HelpKeys,v.values) end end)
 end
 pcall(function()for j=1,5 do Style.Tab(g.Settings["SectionTab"..j],j==1,nil,false)end end)
 -- neater tabs: HAIR, MASK, GEAR (notebook + pen sets), then the coming-soon categories
 pcall(Style.OrderTabs,g.Inventory,"Category",INV_ORDER,548,1084,128,70,{[4]="GEAR",[2]="CLOTHING",[BODY]="BODY",[FXTAB]="ELIM FX",[PETS]="PETS",[MASKS]="HEAD",[VISOR]="VISOR",[TRAIL]="TRAIL"})
 pcall(Style.OrderTabs,g.Shop,"Tab",INV_ORDER,548,1084,128,70,{[4]="GEAR",[2]="CLOTHING",[BODY]="BODY",[FXTAB]="ELIM FX",[PETS]="PETS",[MASKS]="HEAD",[VISOR]="VISOR",[TRAIL]="TRAIL"})
 for i=0,9 do local shopTab=g.Shop:FindFirstChild("Tab"..i);if shopTab then shopTab.Activated:Connect(function()
  self.category=i;v.page=1;self.selected=nil;self.shopSel=nil;self.shopPick=nil;self.zoomT.Shop=TAB_FOCUS[i] or 1;self:PreviewLook()
  if v.marksStore then v.marksStore.active=false;g.Shop.MarksStore.Visible=false end
  self:Shop()
 end) end end
 for i=0,5 do local c=g.Shop["Product"..i]
  c.Select.Activated:Connect(function()
   local it=self:Item(i+1)
   -- double click: equip it (or take it off if it's on)
   local now=os.clock()
   if it and self.lastTap and self.lastTap.item==it and now-self.lastTap.t<.4 then self.lastTap=nil;self:QuickEquip(it,"Shop");return end
   self.lastTap={item=it,t=now}
   -- clicking the selected card again unselects it (back to what you have on)
   if it and it==self.shopSel then self.selected=nil;self.shopSel=nil;self.shopPick=nil;if it.Kind=="outfit" or it.Kind=="pet" or it.Kind=="mask" or it.Kind=="style" or isGearItem(it) then self.shopCw[self.category]=nil end;self.zoomT.Shop=TAB_FOCUS[self.category] or 1;self:Shop();self:PreviewLook();return end
   self.selected=i+1;self.shopSel=it;self.shopPick=it and it.Kind and it or nil
   if it and (it.Kind=="outfit" or it.Kind=="pet" or it.Kind=="mask" or it.Kind=="style" or isGearItem(it)) then self.shopCw[self.category]=it.Id end
   self:Focus("Shop",it);self:Shop();self:PreviewLook()
   if it and (it.Kind=="outfit" or it.Kind=="colorway") then self:OutfitFX("Shop",true) end
  end)

  c.Buy.Activated:Connect(function()self.selected=i+1;local it=self:Item(i+1);self.shopSel=it;self.shopPick=it and it.Kind and it or nil;self:Focus("Shop",it);self:PreviewLook();self:Purchase()end)
 end
 g.Shop.Selection.Purchase.Activated:Connect(function()self:Purchase()end)
  -- (the CASES page sets these: StarterPlayerScripts.CaseOpening)
  for _,a in ipairs({"CasesOpen","CasePreviewId","CasePreviewKind"})do g.Shop:GetAttributeChangedSignal(a):Connect(function()pcall(self.PreviewLook,self)end)end
 g.Shop.Selection.Equip.Activated:Connect(function()self:Purchase(true)end)
 g.Shop.Selection.Preview.Activated:Connect(function()v:Toast("Drag your character to rotate the preview.")end)
 g.Shop.Previous.Activated:Connect(function()self:Page(-1)end)
 -- Shop > Clothing / Pets / Mask: the same ITEMS / COLOURS switch as the Loadout, so colourways can be bought here too
 self.shopMode={};self.shopCw={}
 for _,pair in ipairs({{"ToggleStyles","style"},{"ToggleColours","color"}})do
  local src=g.Inventory:FindFirstChild(pair[1])
  local b=g.Shop:FindFirstChild("Shop"..pair[1]) or (src and src:Clone())
  if b then
   b.Name="Shop"..pair[1];b.Visible=false;b.Parent=g.Shop
   b.Activated:Connect(function()self.shopMode[self.category]=pair[2];v.page=1;self.selected=nil;self.shopSel=nil;self.shopPick=nil;self:Shop();self:PreviewLook()end)
  end
 end
 g.Shop.Next.Activated:Connect(function()self:Page(1)end)
 -- Loadout: tabs across the top, big cards, hair STYLES / COLOURS, try-on preview
 self.hairMode="style";self.clothMode="style";self.pose=1
 local inv=g.Inventory
 for i=0,9 do
  local tab=inv:FindFirstChild("Category"..i)
  if tab then tab.Activated:Connect(function()self.inventoryCategory=i;self.inventoryPage=1;self.invSel=nil;self.zoomT.Inventory=TAB_FOCUS[i] or 1;self:Inventory();self:PreviewLook()end) end
 end
 -- the STYLES / COLOURS toggle serves both Hair and Clothing
 inv.ToggleStyles.Activated:Connect(function()if self.inventoryCategory==CLOTHES then self.clothMode="style" elseif self.inventoryCategory==GEAR then self.gearMode="style" elseif self.inventoryCategory==PETS then self.petMode="style" elseif self.inventoryCategory==MASKS then self.maskMode="style" else self.hairMode="style" end;self.inventoryPage=1;self.invSel=nil;self:Inventory();self:PreviewLook()end)
 inv.ToggleColours.Activated:Connect(function()if self.inventoryCategory==CLOTHES then self.clothMode="color" elseif self.inventoryCategory==GEAR then self.gearMode="color" elseif self.inventoryCategory==PETS then self.petMode="color" elseif self.inventoryCategory==MASKS then self.maskMode="color" else self.hairMode="color" end;self.inventoryPage=1;self.invSel=nil;self:Inventory();self:PreviewLook()end)
 for i=0,5 do inv["Owned"..i].Select.Activated:Connect(function()
  local items=self:InvItems();local item=items and items[(self.inventoryPage-1)*6+i+1]
  if not item then return end
  -- double click: equip it (or take it off if it's on)
  local now=os.clock()
  if self.lastTap and self.lastTap.item==item and now-self.lastTap.t<.4 then self.lastTap=nil;self:QuickEquip(item,"Inventory");return end
  self.lastTap={item=item,t=now}
  -- clicking the selected card again unselects it
  if item==self.invSel then
   self.invSel=nil;if item.Kind=="style" then self.lookStyle=nil end
   self.zoomT.Inventory=TAB_FOCUS[self.inventoryCategory] or 1;self:Inventory();self:PreviewLook();return
  end
  self.invSel=item
  if item.Kind=="outfit" then self.cwOutfit=item.Id end
  if item.Kind=="pet" and realPet(item.Id) then self.cwPet=item.Id end
  if item.Kind=="mask" and realMask(item.Id) then self.cwMask=item.Id end
  if isGearItem(item) then self.cwGear=item.Id end
  self:Focus("Inventory",item)
  if item.Kind=="style" then self.lookStyle=item.Id end
  self:Inventory();self:PreviewLook()
  if item.Kind=="outfit" or item.Kind=="colorway" then self:OutfitFX("Inventory",true) end
 end)end
 -- every time the Loadout / Shop opens it starts from what you have equipped: nothing picked, no try-on, page 1
 inv:GetPropertyChangedSignal("Visible"):Connect(function()
  if not inv.Visible then return end
  self.invSel=nil;self.cwOutfit=nil;self.cwPet=nil;self.cwMask=nil;self.cwGear=nil;self.lookStyle=nil;self.tryOn=false
  self.inventoryPage=1;self.hairMode="style";self.clothMode="style";self.petMode="style";self.maskMode="style";self.gearMode="style"
  if self.hover then self.hover.Inventory=nil end
  self.zoomT.Inventory=TAB_FOCUS[self.inventoryCategory] or 1
  pcall(self.Inventory,self);pcall(self.PreviewLook,self)
 end)
 g.Shop:GetPropertyChangedSignal("Visible"):Connect(function()
  if not g.Shop.Visible then return end
  self.selected=nil;self.shopSel=nil;self.shopPick=nil;self.shopCw={};self.shopMode={};v.page=1
  if self.hover then self.hover.Shop=nil end
  self.zoomT.Shop=TAB_FOCUS[self.category] or 1
  pcall(self.Shop,self);pcall(self.PreviewLook,self)
 end)
 inv.Previous.Activated:Connect(function()self:InventoryPage(-1)end)
 inv.Next.Activated:Connect(function()self:InventoryPage(1)end)
 -- paging without the buttons: mouse wheel over the item grid, or the Left / Right arrow keys (and Q / E) while
 -- the Shop or Loadout is open
 do
  local wheelAt=0
  local function overGrid(panel,first,last)
   local a,b=panel:FindFirstChild(first),panel:FindFirstChild(last)
   if not a or not b then return false end
   local m=UIS:GetMouseLocation()-game:GetService("GuiService"):GetGuiInset()
   local p0,p1=a.AbsolutePosition,b.AbsolutePosition+b.AbsoluteSize
   return m.X>=p0.X and m.X<=p1.X and m.Y>=p0.Y and m.Y<=p1.Y
  end
  local function pageOpen(delta)
   if g.Shop.Visible and not(v.marksStore and v.marksStore.active) then self:Page(delta);return true end
   if g.Inventory.Visible then self:InventoryPage(delta);return true end
   return false
  end
  UIS.InputChanged:Connect(function(input)
   if input.UserInputType~=Enum.UserInputType.MouseWheel or os.clock()-wheelAt<.18 then return end
   local delta=input.Position.Z>0 and -1 or 1
   if g.Shop.Visible and overGrid(g.Shop,"Product0","Product5") then wheelAt=os.clock();pageOpen(delta)
   elseif g.Inventory.Visible and overGrid(g.Inventory,"Owned0","Owned5") then wheelAt=os.clock();pageOpen(delta) end
  end)
  UIS.InputBegan:Connect(function(input,gp)
   if chatTyping() then return end
   local k=input.KeyCode
   if k==Enum.KeyCode.Left or k==Enum.KeyCode.Q then pageOpen(-1)
   elseif k==Enum.KeyCode.Right or k==Enum.KeyCode.E then pageOpen(1) end
  end)
 end
 inv.SaveLoadout.Activated:Connect(function()self:InventoryAction()end)
 inv.Reset.Activated:Connect(function()
  -- one server action resets everything (several remotes in a row were dropped by the server's rate limit)
  v.remote:FireServer("ResetLoadout")
  self.invSel=nil;self.cwOutfit=nil;self.cwMask=nil;self.tryOn=false;self.lookStyle=nil;self:PreviewLook()
 end)
 inv.SidePOSE.Activated:Connect(function()
  self.blendFrom=self.currentJ or {};self.blendStart=os.clock()
  self.pose=self.pose%#Preview.Poses+1;self:PreviewLook()
 end)
 -- body type: the BODY switch in the top-left corner of the Loadout preview (free, applies straight away). It's
 -- saved in StarterGui (Inventory.CharacterPreview.BodySwitch) so it can be restyled in the editor; built if missing.
 -- The Shop preview has the same switch (Shop.CharacterPreview.BodySwitch, a copy of the Loadout one).
 local sw=inv.CharacterPreview:FindFirstChild("BodySwitch") or BuildBodySwitch(inv.CharacterPreview,bodyList)
 self.bodySwitch=sw
 local shopSw=g.Shop.CharacterPreview:FindFirstChild("BodySwitch")
 if not shopSw then shopSw=sw:Clone();shopSw.Parent=g.Shop.CharacterPreview end
 self.bodySwitches={sw,shopSw}
 for _,s in ipairs(self.bodySwitches)do
  for i,b in ipairs(bodyList)do
   local btn=s:FindFirstChild("Seg"..i)
   if btn then btn.Activated:Connect(function()
    if v.player:GetAttribute("ProfileReady")~=true then v:Toast("Profile loading…");return end
    if hairEquipped(v.player,b)then return end
    v.remote:FireServer("EquipHair",b.Id)
    self.invSel=nil;self:Inventory();self:Shop()
   end)end
  end
 end
 inv.SideRESET.Activated:Connect(function()self.zoomT.Inventory=1;self.tryOn=false;self.lookStyle=nil;self.blendFrom=self.currentJ or {};self.blendStart=os.clock();self.pose=1;self.targetAngle=0;self:PreviewLook()end)
 v.player:GetAttributeChangedSignal("NumberStyle"):Connect(function()self:PreviewLook();self:Inventory();self:Shop()end)
 for _,attr in ipairs({"HairStyle","HairColor","FaceMask","Outfit","OutfitColor","SkinTone","BodyType","Pet","KillEffect","PetColor","MaskColor"})do v.player:GetAttributeChangedSignal(attr):Connect(function()task.delay(.25,function()self:Avatar()end)end)end
 -- (two tabs: DAILY = 0, WEEKLY = 2 -- the weekly contracts use the old season slots)
  for i,tab in pairs({[0]=0,[1]=2}) do g.Quests["Tab"..i].Activated:Connect(function()self.questTab=tab;self:QuestView()end)end
 g.Quests.QuestTotal.ViewRewards.Activated:Connect(function()
  -- CLAIM ALL: the daily reward, finished daily + season contracts and reached milestones
  local p=v.player;local n=0
  local function fire(a,i) n+=1;task.delay((n-1)*.2,function()v.remote:FireServer(a,i)end) end
  if p:GetAttribute("DailyClaimed")~=true then fire("ClaimDaily") end
  for i=1,4 do if p:GetAttribute("Quest"..i.."Claimed")~=true and (p:GetAttribute("Quest"..i.."Progress")or 0)>=(p:GetAttribute("Quest"..i.."Goal")or math.huge) then fire("ClaimQuest",i) end end
  for i=1,3 do if p:GetAttribute("SeasonQuest"..i.."Claimed")~=true and (p:GetAttribute("SeasonQuest"..i.."Progress")or 0)>=(p:GetAttribute("SeasonQuest"..i.."Goal")or math.huge) then fire("ClaimSeasonQuest",i) end end
  task.delay(n*.2+.6,function()
   local comp=p:GetAttribute("SeasonCompletedQuests")or 0
   for i,goal in ipairs({3,7,12,18,24})do if comp>=goal and p:GetAttribute("SeasonMilestone"..i.."Claimed")~=true then v.remote:FireServer("ClaimSeasonMilestone",i);task.wait(.2) end end
  end)
  local comp=p:GetAttribute("SeasonCompletedQuests")or 0
  local m=false;for i,goal in ipairs({3,7,12,18,24})do if comp>=goal and p:GetAttribute("SeasonMilestone"..i.."Claimed")~=true then m=true end end
  if n==0 and not m then v:Toast("Nothing to claim right now.") end
 end)
 g.Quests.FeaturedReward.ViewSeason.Activated:Connect(function()self.questTab=2;self:QuestView()end)
 g.Settings.ApplyChanges.Activated:Connect(function()
  if v.dirty then v.settingsRemote:FireServer(v.values)else v:Toast("Preferences are up to date.")end
 end)
 for i=1,5 do g.Settings["SectionTab"..i].Activated:Connect(function()
  for j=1,5 do Style.Tab(g.Settings["SectionTab"..j],i==j,nil,false)end
  pcall(PanelStyle.SettingsTab,g.Settings,i) -- each tab is its own page
 end)end
 g.Credits.VersionPanel.PatchNotes.Activated:Connect(function()v:Show("PatchNotes")end)
 for i=1,4 do g.Credits.Socials["Social"..i].Activated:Connect(function()v:Toast("Community links will be available on the Roblox experience page.")end)end
 for _,name in ipairs({"Shop","Inventory","Quests"})do
  if name~="Shop"then g[name].Currency.Info.Activated:Connect(function()v:Show("Shop");if v.marksStore then v.marksStore:SetActive(true)end end)end
 end
 for _,name in ipairs({"Shop","Inventory"})do
  g[name].RotatePreview.Visible=false
  local vp=g[name].CharacterPreview.AvatarViewport;vp.Active=true
  vp.InputBegan:Connect(function(input)
   if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
    self.dragPreview={input=input,lastX=input.Position.X,touch=input.UserInputType==Enum.UserInputType.Touch}
   end
  end)
  -- scroll wheel over the preview zooms in toward the head
  vp.InputChanged:Connect(function(input)
   if input.UserInputType==Enum.UserInputType.MouseWheel then
    self.zoomT[name]=math.clamp((self.zoomT[name] or 1)*1.2^input.Position.Z,1,ZOOM_MAX)
   end
  end)
  local hint=g[name].CharacterPreview:FindFirstChild("DragHint")
  if hint and not hint.Text:upper():find("SCROLL") then hint.Text=hint.Text.."  ·  SCROLL TO ZOOM" end
 end
 local rotateMove=UIS.InputChanged:Connect(function(input)
  local drag=self.dragPreview
  if drag and((drag.touch and input==drag.input)or(not drag.touch and input.UserInputType==Enum.UserInputType.MouseMovement))then
   self.targetAngle+=(input.Position.X-drag.lastX)*.009;drag.lastX=input.Position.X
  end
 end)
 local rotateEnd=UIS.InputEnded:Connect(function(input)
  if self.dragPreview and(input==self.dragPreview.input or input.UserInputType==Enum.UserInputType.MouseButton1)then self.dragPreview=nil end
 end)
 local rotateStep=game:GetService("RunService").RenderStepped:Connect(function(dt)
  self.angle+=(self.targetAngle-self.angle)*(1-math.exp(-18*math.min(dt,.1)));self:Rotate()
  local hv=self.hover
  if hv and hv.button then
   local b=hv.button;local m=UIS:GetMouseLocation()-game:GetService("GuiService"):GetGuiInset()
   local over=b.Visible and b.Parent.Visible and b:FindFirstAncestorOfClass("Frame") and self.g[hv.Shop and "Shop" or "Inventory"].Visible
    and m.X>=b.AbsolutePosition.X and m.X<=b.AbsolutePosition.X+b.AbsoluteSize.X and m.Y>=b.AbsolutePosition.Y and m.Y<=b.AbsolutePosition.Y+b.AbsoluteSize.Y
   if not over then self.hover=nil;self:PreviewLook() end
  end
  -- animated pose (idle breathing, wave...), eased in over .35s after POSE / RESET
  self.animT=(self.animT or 0)+math.min(dt,.1)
  local j=Preview.Joints(self.pose or 1,self.animT)
  if self.blendFrom then
   local k=math.clamp((os.clock()-self.blendStart)/.35,0,1);k=k*k*(3-2*k)
   j=Preview.Blend(self.blendFrom,j,k);if k>=1 then self.blendFrom=nil end
  end
  self.currentJ=j
  for name,model in pairs(self.models)do
   if model.Parent and self.g[name].Visible then
    local holding=self.gearPv and self.gearPv[name]
    pcall(Preview.Solve,model,name=="Inventory" and j or Preview.Joints(1,self.animT))
    if holding then pcall(self.StepGear,self,name) end
   end
  end
  -- zoom (eased) and the number-style overlay on the visor
  for name in pairs(self.models)do
   local z,zt=self.zoom[name] or 1,self.zoomT[name] or 1
   self.zoom[name]=z+(zt-z)*(1-math.exp(-14*math.min(dt,.1)))
   if self.g[name].Visible then pcall(self.Frame,self,name);pcall(self.VisorOverlay,self,name) end
  end
  if self.cardModel and self.g.Lobby.Visible then pcall(self.CardOverlay,self) end
  pcall(self.StepExtras,self)
 end)
 g.Destroying:Connect(function()rotateMove:Disconnect();rotateEnd:Disconnect();rotateStep:Disconnect()end)
 for i=1,5 do g.Quests.Season["Milestone"..i].Activated:Connect(function()v.remote:FireServer("ClaimSeasonMilestone",i)end)end
 for _,id in ipairs(g.ArtworkAssetIds:GetChildren())do id.Changed:Connect(function()self:Artwork()end)end
 v.player.CharacterAdded:Connect(function()task.defer(function()self:Avatar()end)end)
 -- The server builds the hair and the LED visor after the character spawns (and rebuilds them on every look
 -- change), and their parts can replicate a moment after the models. Re-clone the preview whenever those parts
 -- arrive, or it shows a bald head with no visor.
 local looks={Hair=true,LEDVisor=true,FaceMask=true,Outfit=true}
 local function lookPart(d)
  local m=d.Parent
  while m and m~=v.player.Character do if looks[m.Name] then return true end;m=m.Parent end
  return looks[d.Name]==true
 end
 local function watch(char)
  if not char then return end
  local function poke(d)
   if not lookPart(d) then return end
   self.avatarSerial=(self.avatarSerial or 0)+1;local serial=self.avatarSerial
   task.delay(.3,function()if self.avatarSerial==serial and v.player.Character==char then self:Avatar()end end)
  end
  char.DescendantAdded:Connect(poke);char.DescendantRemoving:Connect(poke)
 end
 watch(v.player.Character);v.player.CharacterAdded:Connect(watch)
 self.settingEntries={}
 for _,entry in ipairs(v.rules.Items)do self.settingEntries[entry.Id]=entry
  local slider=g.Settings.Options[entry.Id]:FindFirstChild("Slider")
  if slider then slider.InputBegan:Connect(function(input)
   if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.dragSetting=entry.Id;self:SetSlider(entry.Id,input.Position.X)end
  end)end
 end
 local moved=UIS.InputChanged:Connect(function(input)if self.dragSetting and(input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch)then self:SetSlider(self.dragSetting,input.Position.X)end end)
 local released=UIS.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self.dragSetting=nil end end)
 g.Destroying:Connect(function()moved:Disconnect();released:Disconnect()end)
 v.player.CharacterAppearanceLoaded:Connect(function()self:Avatar()end)
 self:Artwork();task.defer(function()self:Avatar()end)
 return self
end
function M:Artwork()
 for _,im in ipairs(self.g:GetDescendants())do
  if im:IsA("ImageLabel")then local key=im:GetAttribute("DesignAsset")
   if key then
    local id=self.g.ArtworkAssetIds:FindFirstChild(key);im.Image=id and id.Value~=""and id.Value or im:GetAttribute("FallbackImage")or "";im.Visible=im.Image~=""
    local iconIndex=im:GetAttribute("IconIndex")
    if iconIndex then im.ImageRectSize=Vector2.new(256,256);im.ImageRectOffset=Vector2.new((iconIndex%4)*256,math.floor(iconIndex/4)*256)end
    local sprite=im:GetAttribute("AtlasSprite")
    if sprite then
     im.ImageRectSize=Vector2.new(512,512)
     im.ImageRectOffset=sprite=="panel"and Vector2.zero or sprite=="header"and Vector2.new(512,0)or sprite=="card"and Vector2.new(0,512)or Vector2.new(512,512)
     if sprite=="header"then im.ImageRectOffset=Vector2.new(512,138);im.ImageRectSize=Vector2.new(512,278)
     elseif sprite=="panel"or sprite=="card"then im.ScaleType=Enum.ScaleType.Slice;im.SliceCenter=Rect.new(122,122,390,390);im.SliceScale=.45 end
    end
   end
  end
 end
 for _,name in ipairs({"Shop","Inventory"})do local f=self.g[name].CharacterPreview;f.AvatarViewport.Visible=not f.Scene.Visible end
 self.g.Quests.Streak.RingFallback.Visible=not self.g.Quests.Streak.StreakRing.Visible
end
function M:Avatar()
 local char=self.v.player.Character;if not char then return end
 -- live servers stream the character in: wait until the body is all there (a copy taken too early had no root /
 -- missing limbs, so it couldn't be posed and sat wherever the real character was, e.g. mid-fall)
 local need={"HumanoidRootPart","Head","UpperTorso","LowerTorso","LeftUpperLeg","RightUpperLeg","LeftFoot","RightFoot"}
 for _,n in ipairs(need)do if not char:FindFirstChild(n)then
  if not self.avatarRetry then self.avatarRetry=true;task.delay(.5,function()self.avatarRetry=nil;self:Avatar()end)end
  return
 end end
 for _,name in ipairs({"Shop","Inventory"})do
  local vp=self.g[name].CharacterPreview.AvatarViewport;vp:ClearAllChildren()
  local old=char.Archivable;char.Archivable=true;local clone=char:Clone();char.Archivable=old
  for _,d in ipairs(clone:GetDescendants())do
   if d:IsA("WrapTarget")or d:IsA("BallSocketConstraint")or d:IsA("NoCollisionConstraint")or d:IsA("Script")or d:IsA("LocalScript")or d:IsA("ModuleScript")or d:IsA("ForceField")then d:Destroy()
   elseif d:IsA("BasePart")then d.Anchored=true;d.CanCollide=false;d.LocalTransparencyModifier=0 end
  end
  -- no Humanoid on preview copies: inside a ViewportFrame its appearance compositing (avatar body colours / classic
 -- clothing) paints over the limbs, so hands and arms showed grey instead of the skin tone
  local hum=clone:FindFirstChildOfClass("Humanoid");if hum then hum:Destroy() end
  for _,cl in ipairs(clone:GetChildren())do if cl:IsA("Clothing") or cl:IsA("ShirtGraphic") then cl:Destroy() end end
  for _,bc in ipairs(clone:GetChildren())do if bc:IsA("BodyColors")then bc:Destroy()end end
  -- the copy is a still figure: no live joints/forces from the real character (ragdoll sockets, the root's
  -- velocity) and everything anchored, posed by LoadoutPreview.Solve from its root
  local root=clone:FindFirstChild("HumanoidRootPart");clone.PrimaryPart=root
  for _,d in ipairs(clone:GetDescendants())do
   if d:IsA("BasePart")then d.AssemblyLinearVelocity=Vector3.zero;d.AssemblyAngularVelocity=Vector3.zero
   elseif d:IsA("BodyMover")or d:IsA("VectorForce")or d:IsA("LinearVelocity")or d:IsA("AlignPosition")or d:IsA("AlignOrientation")then d:Destroy() end
  end
  local world=Instance.new("WorldModel",vp);clone.Parent=world;clone:PivotTo(CFrame.new())
  -- near-neutral light so skin reads as the real skin tone (a pink ambient made hands look grey-pink)
  vp.Ambient=Color3.fromRGB(150,142,136);vp.LightColor=Color3.fromRGB(255,246,236);vp.LightDirection=Vector3.new(-0.4,-0.7,0.6)
  local camera=Instance.new("Camera",vp);vp.CurrentCamera=camera;camera.FieldOfView=30
  camera.CFrame=CFrame.lookAt(Vector3.new(0,0,-15),Vector3.new(0,-0.38,0))
  self.cams[name]=camera
  local hm=clone:FindFirstChild("Hair")
  clone:SetAttribute("LookStyle",hm and hm:GetAttribute("StyleId") or "None")
  clone:SetAttribute("LookColor",hm and hm:GetAttribute("ColorId") or HairCatalog.DefaultColor)
  clone:SetAttribute("LookMask",clone:FindFirstChild("FaceMask") and (clone.FaceMask:GetAttribute("MaskId") or "Scarf") or "NoMask")
  local of=clone:FindFirstChild("Outfit");clone:SetAttribute("LookOutfit",of and of:GetAttribute("OutfitId") or nil)
  self.models[name]=clone
 end
 pcall(self.Card,self,char)
 self:PreviewLook()
end
-- Main-menu player card: a head-and-shoulders portrait of your character exactly as it looks in game (hairstyle,
-- colour, scarf, the LED visor with its blinking O__O idle face) instead of the Roblox headshot.
function M:Card(char)
 local avatar=self.g.Lobby.PlayerCard:FindFirstChild("Avatar");if not avatar then return end
 local vp=avatar:FindFirstChild("InGameAvatar")
 if not vp then
  vp=Instance.new("ViewportFrame");vp.Name="InGameAvatar";vp.Size=UDim2.fromScale(1,1);vp.BorderSizePixel=0
  vp.ZIndex=avatar.ZIndex+1;vp.Parent=avatar
 end
 vp:ClearAllChildren()
 -- dark red wash behind the figure, same palette as the card
 local g=Instance.new("UIGradient");g.Rotation=90;g.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(110,110,110));g.Parent=vp
 vp.BackgroundColor3=Color3.fromRGB(52,12,22)
 local old=char.Archivable;char.Archivable=true;local clone=char:Clone();char.Archivable=old
 for _,d in ipairs(clone:GetDescendants())do
  if d:IsA("WrapTarget")or d:IsA("BallSocketConstraint")or d:IsA("NoCollisionConstraint")or d:IsA("Script")or d:IsA("LocalScript")or d:IsA("ModuleScript")or d:IsA("ForceField")or d:IsA("Sound")then d:Destroy()
  elseif d:IsA("BasePart")then d.Anchored=true;d.CanCollide=false;d.LocalTransparencyModifier=0 end
 end
 local hum=clone:FindFirstChildOfClass("Humanoid");if hum then hum:Destroy() end -- (see Avatar: Humanoid compositing greys the limbs)
 local world=Instance.new("WorldModel");world.Parent=vp;clone.Parent=world;clone:PivotTo(CFrame.new())
 pcall(Preview.Solve,clone,5)
 -- the visor face is drawn as a 2D overlay in your number style (CardOverlay); clear the clone's own screen
 pcall(Preview.Visor,clone,"    ")
 vp.Ambient=Color3.fromRGB(120,96,104);vp.LightColor=Color3.fromRGB(255,226,226);vp.LightDirection=Vector3.new(-0.5,-0.55,0.7)
 local camera=Instance.new("Camera");camera.FieldOfView=24;camera.Parent=vp;vp.CurrentCamera=camera
 local head=clone:FindFirstChild("Head")
 local focus=head and head.Position+Vector3.new(0,-0.05,0) or Vector3.new(0,1.3,0)
 -- near-front view (so the visor face reads), a touch from the side and above: head, hair and shoulders
 camera.CFrame=CFrame.lookAt(focus+Vector3.new(0.8,0.3,-6.4),focus)
 self.cardModel=clone;self.cardVp=vp;self.cardCam=camera;self.cardFace="O__O"
 self.cardSerial=(self.cardSerial or 0)+1
 local serial=self.cardSerial
 -- blink: swap the face to -__- for a moment
 task.spawn(function()
  while self.cardSerial==serial and vp.Parent do
   task.wait(2.2+math.random()*3)
   if self.cardSerial~=serial or not vp.Parent then break end
   local twice=math.random()<.25
   for _=1,twice and 2 or 1 do
    self.cardFace="-__-";task.wait(.13)
    if self.cardSerial~=serial then return end
    self.cardFace="O__O"
    if twice then task.wait(.12) end
   end
  end
 end)
end
-- re-pose both previews, light the visor and apply the hair try-on (Inventory only)
-- the case reward to try on in the Shop preview (Shop attributes CasePreviewKind / CasePreviewId), as a shop item
function M:CasePreviewItem()
 local sh=self.g.Shop
 local kind,id=sh:GetAttribute("CasePreviewKind"),sh:GetAttribute("CasePreviewId")
 if not kind or not id or kind=="marks" then return nil end
 if kind=="gear" then return gearItem(id) end
 return {Kind=kind,Id=id,Name=id}
end
function M:PreviewLook()
 local p=self.v.player
 for name,model in pairs(self.models)do if model.Parent then
  for _,d in ipairs(model:GetDescendants())do if d:IsA("BasePart")and not d.Anchored then d.Anchored=true end end
  model:PivotTo(CFrame.new())
  pcall(Preview.Solve,model,name=="Inventory" and self.pose or 1)
  -- equipped look, or the item being hovered (hair / colour / mask) on top of it
  local worn=p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle
  local style,color,mask=worn,p:GetAttribute("HairColor") or HairCatalog.DefaultColor,p:GetAttribute("FaceMask") or HairCatalog.DefaultMask
  local outfit=p:GetAttribute("Outfit") or Outfits.Default
  local cw=p:GetAttribute("OutfitColor") or Outfits.DefaultColorway
  local maskCw=p:GetAttribute("MaskColor") or Extras.DefaultMaskColorway
  local h=(self.hover and self.hover[name]) or (name=="Inventory" and self.invSel and self.invSel.Kind and self.invSel) or (name=="Shop" and self.shopPick)
  -- Shop > CASES: the reward clicked in "what's inside" (or the prize just won) is what the preview wears
  if name=="Shop" and self.g.Shop:GetAttribute("CasesOpen")==true then h=self:CasePreviewItem() end
  local num=p:GetAttribute("NumberStyle") or NumberStyles.Default
  if h and h.Kind=="numstyle" then num=h.Id end
  model:SetAttribute("LookNum",num)
  -- Loadout > Hair > COLOURS for a hairstyle you picked but don't wear: that hairstyle, in its own colour
  if name=="Inventory" and self.inventoryCategory==HAIR and self.hairMode=="color" then
   local cs=self:CwStyle()
   if cs~=worn then style=cs;color=p:GetAttribute("HairCol_"..cs) or HairCatalog.DefaultColor end
  end
  if h then
   if h.Kind=="style" then style=h.Id;if h.Id~=worn then color=p:GetAttribute("HairCol_"..h.Id) or HairCatalog.DefaultColor end
   elseif h.Kind=="color" then color=h.Id;if h.ForStyle then style=h.ForStyle end
   elseif h.Kind=="mask" then mask=h.Id;maskCw=p:GetAttribute("MaskCw_"..h.Id) or Extras.DefaultMaskColorway
   elseif h.Kind=="maskcolor" then mask=h.ForMask;maskCw=h.Id
   elseif h.Kind=="outfit" then if h.Id~=outfit then cw=p:GetAttribute("OutfitCw_"..h.Id) or Outfits.DefaultColorway end;outfit=h.Id
   elseif h.Kind=="colorway" then if h.ForOutfit and h.ForOutfit~=outfit then outfit=h.ForOutfit end;cw=h.Id end
  elseif name=="Inventory" and self.inventoryCategory==CLOTHES and self.clothMode=="color" and self.cwOutfit and self.cwOutfit~=outfit then
   outfit=self:CwOutfit();cw=p:GetAttribute("OutfitCw_"..outfit) or Outfits.DefaultColorway
  elseif name=="Inventory" and self.inventoryCategory==MASKS and self.maskMode=="color" and self:CwMask() then
   mask=self:CwMask();maskCw=p:GetAttribute("MaskCw_"..mask) or Extras.DefaultMaskColorway
  elseif name=="Shop" and self:ShopColours() and self:ShopCw(self.category) then
   local id=self:ShopCw(self.category)
   if self.category==CLOTHES and id~=outfit then outfit=id;cw=p:GetAttribute("OutfitCw_"..id) or Outfits.DefaultColorway
   elseif self.category==MASKS then mask=id;maskCw=p:GetAttribute("MaskCw_"..id) or Extras.DefaultMaskColorway
   elseif self.category==HAIR and id~=worn then style=id;color=p:GetAttribute("HairCol_"..id) or HairCatalog.DefaultColor end
  end
  -- body type (Loadout > Body): swap the clone's torso, then re-pose it (the outfit is re-dressed below)
  local bodyId=p:GetAttribute("BodyType") or Extras.DefaultBody
  if h and h.Kind=="body" then bodyId=h.Id end
  if BodyType.Current(model)~=BodyType.Id(bodyId) then
   if pcall(BodyType.Apply,model,bodyId,false) then model:SetAttribute("LookOutfit",nil);model:PivotTo(CFrame.new());pcall(Preview.Solve,model,name=="Inventory" and self.pose or 1) end
  end
  -- the pet beside you, and the elimination effect being previewed (looped by the render step)
  local petId=p:GetAttribute("Pet") or Extras.DefaultPet
  local petCw=p:GetAttribute("PetColor")
  if h and h.Kind=="pet" then petId=h.Id;petCw=p:GetAttribute("PetCw_"..h.Id)
  elseif h and h.Kind=="petcolor" then petId=h.ForPet;petCw=h.Id
  elseif name=="Shop" and self.category==PETS and self:ShopColours() and self:ShopCw(PETS) then
   petId=self:ShopCw(PETS);petCw=p:GetAttribute("PetCw_"..petId)
  elseif name=="Inventory" and self.inventoryCategory==PETS and self.petMode=="color" and self:CwPet() then
   petId=self:CwPet();petCw=p:GetAttribute("PetCw_"..petId)
  end
  pcall(self.PreviewPet,self,name,model,petId,petCw)
  -- gear: the notebook / typewriter / keyboard picked (or your own, on the GEAR tab) held in the preview's hands
  -- (a gear colourway shows that gear in that colourway; a gear item shows it in the colourway it's kept in)
  local function asGear(it)
   if type(it)~="table" then return nil end
   if it.Kind=="gearcolor" then return gearItem(it.ForGear),it.Id end
   if isGearItem(it) then return it,nil end
   return nil
  end
  local gear,gcw=asGear(self.hover and self.hover[name])
  if not gear then if name=="Shop" then gear,gcw=asGear(self.shopSel) else gear,gcw=asGear(self.invSel) end end
  if not gear and ((name=="Shop" and self.category==GEAR) or (name=="Inventory" and self.inventoryCategory==GEAR)) then
   local id=(name=="Shop" and self:ShopColours() and self:ShopCw(GEAR)) or (name=="Inventory" and self.gearMode=="color" and self:CwGear()) or (p:GetAttribute("NotebookFinish") or "Classic")
   gear=gearItem(id)
  end
  if gear and not gcw then gcw=gearCwOf(p,gear.Id) end
  pcall(self.PreviewGear,self,name,model,gear,gcw)
  self.fxPreview=self.fxPreview or {};self.fxNext=self.fxNext or {}
  local fxId=h and h.Kind=="killfx" and h.Id or nil
  if self.fxPreview[name]~=fxId then
   self.fxNext[name]=0
   -- switching effects: clear what the last one left behind
   for _,c in ipairs(model.Parent and model.Parent:GetChildren() or {})do if c.Name=="FxPreview" then c:Destroy() end end
  end
  self.fxPreview[name]=fxId
  local lookKey=outfit.."|"..cw
  if model:GetAttribute("LookOutfit")~=lookKey then pcall(Preview.Outfit,model,outfit,cw);model:SetAttribute("LookOutfit",lookKey)end
  if model:GetAttribute("LookStyle")~=style or model:GetAttribute("LookColor")~=color then pcall(Preview.Hair,model,style,color);model:SetAttribute("LookColor",color)end
  if model:GetAttribute("LookStyle")~=style then pcall(Preview.FitVisor,model,style);model:SetAttribute("LookStyle",style)end
  local maskKey=tostring(mask).."|"..tostring(maskCw)
  if model:GetAttribute("LookMask")~=maskKey then pcall(Preview.Mask,model,mask,maskCw);model:SetAttribute("LookMask",maskKey)end
  -- visor: the one picked / hovered under VISOR, else the one you wear
  local visorId=(h and h.Kind=="visor" and h.Id) or (h and h.Kind=="visorcolor" and "Standard") or RankLooks.Visor(p)
  local visorCw=(h and h.Kind=="visorcolor" and h.Id) or (h and h.Kind=="visor" and VisorColorways.Default) or p:GetAttribute("VisorColor") or VisorColorways.Default
  local visorKey=visorId.."|"..visorCw
  if model:GetAttribute("LookVisor")~=visorKey then pcall(Preview.RankVisor,model,visorId,visorCw);model:SetAttribute("LookVisor",visorKey)end
  -- trail: a dash of afterimages on a loop, in the trail picked / hovered (or yours, while on the TRAIL tab)
  local onTrailTab=(name=="Inventory" and self.inventoryCategory==TRAIL) or (name=="Shop" and self.category==TRAIL)
  local trailId=(h and (h.Kind=="trail" or h.Kind=="trailcolor") and h.Id) or (onTrailTab and RankLooks.Trail(p)) or nil
  pcall(self.PreviewTrail,self,name,model,trailId)
  -- the screen itself is drawn as a 2D overlay in the number style (VisorOverlay): clear the 3D **** dots
  pcall(Preview.Visor,model,"    ")
 end end
 local inv=self.g.Inventory
 local tag=inv.CharacterPreview:FindFirstChild("PreviewTag")
 if tag then
  local h=(self.hover and self.hover.Inventory) or (self.invSel and self.invSel.Kind and self.invSel)
  tag.Text=(h and ("PREVIEW  ·  "..h.Name:upper()) or "")..((self.pose or 1)>1 and ((h and "   " or "")..Preview.Poses[self.pose].Name) or "")
 end
 if inv:FindFirstChild("SidePOSE") then Style.Toggle(inv.SidePOSE,(self.pose or 1)>1) end
 pcall(self.BodySwitchLook,self)
 self:Rotate()
end
-- the trail being previewed: one dash of afterimages every 1.5s beside the preview character (LoadoutPreview.TrailDash)
function M:PreviewTrail(name,model,id)
 self.trailPv=self.trailPv or {}
 local cur=self.trailPv[name]
 if cur and cur.id==id and cur.model==model then return end
 if cur then cur.stop=true end
 self.trailPv[name]=nil
 local world=model.Parent
 if world then for _,c in ipairs(world:GetChildren())do if c.Name=="TrailPreview" then c:Destroy() end end end
 if not id or not world then return end
 local st={id=id,model=model};self.trailPv[name]=st
 task.spawn(function()
  task.wait(.2)
  while not st.stop and model.Parent==world and world.Parent do
   pcall(Preview.TrailDash,world,model,id)
   task.wait(1.5)
  end
 end)
end
-- GEAR: the gear itself, large, on a slowly turning stand in its own viewport laid over the character preview (the
-- character, its pet and trail are hidden while it shows). Dragging still turns it (self.angle). The notebook stands
-- up to show its cover, with its pen lying against it; typing gear sits three-quarter on.
local SHOW_ACCENT=Color3.fromRGB(255,30,62)
-- (world-aligned bounds: a model's own bounding box follows its pivot, which is turned for the showcase)
local function worldBounds(m)
 local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
 for _,p in ipairs(m:GetDescendants())do if p:IsA("BasePart") then
  local c,h=p.CFrame,p.Size/2
  for _,s in ipairs({Vector3.new(1,1,1),Vector3.new(1,1,-1),Vector3.new(1,-1,1),Vector3.new(1,-1,-1),Vector3.new(-1,1,1),Vector3.new(-1,1,-1),Vector3.new(-1,-1,1),Vector3.new(-1,-1,-1)})do
   local w=c:PointToWorldSpace(h*s);lo=lo:Min(w);hi=hi:Max(w)
  end
 end end
 if lo.X>hi.X then return Vector3.zero,Vector3.one end
 return (lo+hi)/2,hi-lo
end
function M:PreviewGear(name,model,item,cw)
 self.gearPv=self.gearPv or {}
 local cur=self.gearPv[name]
 local panel=self.g[name] and self.g[name]:FindFirstChild("CharacterPreview");if not panel then return end
 if cur and item and cur.id==item.Id and cur.cw==cw and cur.vp.Parent then return end
 if cur then cur.vp:Destroy() end
 self.gearPv[name]=nil
 local avatar=panel:FindFirstChild("AvatarViewport")
 if avatar then avatar.Visible=item==nil end
 if not item then return end
 local scene=Art.GearScene(item,cw)
 if not scene then if avatar then avatar.Visible=true end;return end
 local vp=Instance.new("ViewportFrame");vp.Name="GearShowcase";vp.Size=UDim2.fromScale(1,1);vp.BackgroundTransparency=1
 vp.BorderSizePixel=0;vp.ZIndex=3;vp.Ambient=Color3.fromRGB(132,124,124);vp.LightColor=Color3.fromRGB(255,240,228)
 vp.LightDirection=Vector3.new(-.45,-.6,.65)
 local world=Instance.new("WorldModel");world.Parent=vp
 scene.Parent=world
 -- the notebook stands up, cover to the camera, with its pen lying against the cover
 if not item.Device then
  -- (stood upright, leaning back a little: the cover is the mesh's -Y face, its long side is Z)
  local book=scene:FindFirstChild("Notebook");local pen=scene:FindFirstChild("Pen")
  if book then
   local rel=pen and book.CFrame:ToObjectSpace(pen.CFrame)
   book.CFrame=CFrame.Angles(-math.rad(78),0,0)*CFrame.Angles(math.pi,0,0)
   if pen then pen.CFrame=book.CFrame*rel end
  end
 end
 -- about 4 studs across, centred on the middle of the stand
 local _,size=worldBounds(scene)
 local k=4/math.max(size.X,size.Y,size.Z,.01)
 pcall(function() scene:ScaleTo(scene:GetScale()*k) end)
 local mid
 mid,size=worldBounds(scene)
 local base=CFrame.new(-mid)*scene:GetPivot()
 -- the stand: a dark disc with a glowing red rim, under the gear
 local r=math.max(size.X,size.Z)*.52+.25
 local function disc(dname,radius,height,color,material,y)
  local d=Instance.new("Part");d.Name=dname;d.Shape=Enum.PartType.Cylinder;d.Anchored=true;d.CastShadow=false
  d.Size=Vector3.new(height,radius*2,radius*2);d.CFrame=CFrame.new(0,y,0)*CFrame.Angles(0,0,math.pi/2)
  d.Color=color;d.Material=material;d.Parent=world;return d
 end
 local floorY=-size.Y/2-.12
 disc("Stand",r,.16,Color3.fromRGB(26,20,24),Enum.Material.SmoothPlastic,floorY-.08)
 disc("Rim",r+.05,.06,SHOW_ACCENT,Enum.Material.Neon,floorY-.03)
 disc("Top",r-.08,.07,Color3.fromRGB(40,32,36),Enum.Material.SmoothPlastic,floorY+.005)
 local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
 -- framed to fit across the (portrait) panel, looking a little down onto the stand
 local abs=panel.AbsoluteSize;local aspect=(abs.X>0 and abs.Y>0) and abs.X/abs.Y or 425/621
 local halfW=math.atan(math.tan(math.rad(15))*aspect)
 local radius=math.max(size.X,size.Z,size.Y)*.62+.35
 local dist=radius/math.tan(math.min(halfW,math.rad(15)))*1.02
 local elev=math.rad(item.Device and 28 or 14)
 cam.CFrame=CFrame.lookAt(Vector3.new(0,math.sin(elev)*dist,-math.cos(elev)*dist),Vector3.new(0,-.15,0))
 vp.Parent=panel
 self.gearPv[name]={id=item.Id,cw=cw,char=model,vp=vp,scene=scene,base=base,panel=panel,born=os.clock()}
 self:StepGear(name)
end
function M:StepGear(name)
 local g=self.gearPv and self.gearPv[name];if not g or not g.scene.Parent then return end
 local t=os.clock()-g.born
 -- (the character preview can be rebuilt underneath: keep it hidden while the gear shows)
 local av=g.panel:FindFirstChild("AvatarViewport");if av and av.Visible then av.Visible=false end
 -- a slow turntable on top of the drag angle, with a gentle float
 local turn=CFrame.new(0,math.sin(t*1.3)*.06,0)*CFrame.Angles(0,(self.angle or 0)+t*.38,0)
 g.scene:PivotTo(turn*g.base)
end
-- a pet standing next to the preview character (Numberfall.Pets); rebuilt when the pet or the preview changes
function M:PreviewPet(name,model,petId,petCw)
 self.pets=self.pets or {}
 local cur=self.pets[name]
 if cur and cur.id==petId and cur.cw==petCw and cur.model.Parent and cur.owner==model then return end
 if cur and cur.model then cur.model:Destroy() end
 self.pets[name]=nil
 local world=model.Parent;if not world then return end
 local pm=Pets.Build(petId,self.v.player,petCw)
 if pm then pm.Parent=world;self.pets[name]={id=petId,cw=petCw,model=pm,owner=model,ground=Pets.Ground(petId)} end
end
-- per frame: place / animate the preview pets and loop the previewed elimination effect
function M:StepExtras()
 local t=os.clock()
 for name,pt in pairs(self.pets or {}) do
  local model=self.models[name]
  if pt.model.Parent and model and model.Parent and pt.owner==model and self.g[name].Visible then
   local lf=model:FindFirstChild("LeftFoot");local footY=lf and (lf.Position.Y-lf.Size.Y/2) or -3
   local y=pt.ground and footY or (0.7+math.sin(t*2.2)*0.18)
   pt.model.PrimaryPart.CFrame=CFrame.Angles(0,self.angle,0)*CFrame.new(1.85,y,0.9)*CFrame.Angles(0,math.rad(-18),0)
   Pets.Animate(pt.model,t,0)
  end
 end
 for name,fxId in pairs(self.fxPreview or {}) do
  local model=self.models[name]
  if fxId and model and model.Parent and self.g[name].Visible and t>=(self.fxNext[name] or 0) then
   local folder=Instance.new("Folder");folder.Name="FxPreview";folder.Parent=model.Parent
   local root=model:FindFirstChild("HumanoidRootPart");local o=root and root.Position or Vector3.zero
   local lf=model:FindFirstChild("LeftFoot");local footY=lf and (lf.Position.Y-lf.Size.Y/2) or (o.Y-3)
   local life=KillFX.Play(fxId,folder,o,{preview=true,floor=footY})
   task.delay(life+0.4,function()folder:Destroy()end)
   self.fxNext[name]=t+math.max(2.8,life+0.8)
  end
 end
end
function M:Focus(name,item)self.zoomT[name]=item and FOCUS[item.Kind or ""] or 1 end
-- preview camera: scroll zooms from the full figure in to head-and-shoulders, then right up to the visor
function M:Frame(name)
 local cam=self.cams[name];local model=self.models[name]
 if not cam or not model or not model.Parent then return end
 local z=self.zoom[name] or 1;local t=math.clamp((z-1)/1.8,0,1);t=t*t*(3-2*t)
 local head=model:FindFirstChild("Head");local hy=head and head.Position.Y or 1.5
 local fy=-0.38+(hy+0.02+0.38)*t
 -- closer still: centre on the visor's screen (it sits a little off the middle of the face)
 local s=math.clamp((z-2.6)/2,0,1);s=s*s*(3-2*s)
 local fx=0
 if s>0 then
  local pn=Preview.VisorPanels(model)
  if pn then local c=Vector3.zero;for _,q in ipairs(pn)do c+=q[1].Position end;c/=#pn;fx=c.X*s;fy+=(c.Y-fy)*s end
 end
 cam.CFrame=CFrame.lookAt(Vector3.new(fx,fy+0.38/z,-15/z),Vector3.new(fx,fy,0))
end
-- The visor's number, in your number style (or the one you're previewing). SurfaceGuis don't render inside a
-- ViewportFrame, so each digit cell is projected to the screen and drawn on top as 2D (Numberfall.NumberStyles).
local PREVIEW_CODE="4729"
-- Draw `code` in number style `style` over the visor of `model`, as seen by `cam` inside ViewportFrame `vp`.
-- unit: menu pixels per screen pixel (the menus are UIScale'd), so text sizes stay right.
local function drawVisorOverlay(vp,cam,model,style,code,unit)
 local ov=vp:FindFirstChild("VisorOverlay")
 local panels=model and model.Parent and cam and cam.Parent==vp and Preview.VisorPanels(model)
 if not panels then if ov then ov.Visible=false end;return end
 if not ov then
  ov=Instance.new("Frame");ov.Name="VisorOverlay";ov.BackgroundTransparency=1;ov.Size=UDim2.fromScale(1,1)
  ov.ClipsDescendants=true;ov.ZIndex=vp.ZIndex+1;ov.Active=false;ov.Parent=vp
 end
 ov.Visible=true
 local size=vp.AbsoluteSize;if size.X<1 or size.Y<1 then return end
 local tanf=math.tan(math.rad(cam.FieldOfView)/2);local aspect=size.X/size.Y
 local function proj(p)
  local l=cam.CFrame:PointToObjectSpace(p);if l.Z>-0.05 then return nil end
  return Vector2.new((0.5+l.X/(-l.Z*tanf*aspect)/2)*size.X,(0.5-l.Y/(-l.Z*tanf)/2)*size.Y)
 end
 for i,pn in ipairs(panels)do
  local cf,w,h=pn[1],pn[2],pn[3]
  local cell=ov:FindFirstChild("Cell"..i)
  if not cell then cell=Instance.new("Frame");cell.Name="Cell"..i;cell.BackgroundTransparency=1;cell.ZIndex=ov.ZIndex;cell.Parent=ov end
  local ok=cf.LookVector:Dot((cam.CFrame.Position-cf.Position).Unit)>0.15
  local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
  if ok then
   for _,c in ipairs({Vector3.new(-w/2,-h/2,0),Vector3.new(w/2,-h/2,0),Vector3.new(-w/2,h/2,0),Vector3.new(w/2,h/2,0)})do
    local s=proj(cf*c);if not s then ok=false;break end
    minX,minY,maxX,maxY=math.min(minX,s.X),math.min(minY,s.Y),math.max(maxX,s.X),math.max(maxY,s.Y)
   end
  end
  cell.Visible=ok
  if ok then
   cell.Position=UDim2.fromScale(minX/size.X,minY/size.Y);cell.Size=UDim2.fromScale((maxX-minX)/size.X,(maxY-minY)/size.Y)
   local ph=(maxY-minY)*unit;local ch=string.sub(code,i,i)
   local key=style..":"..ch..":"..math.floor(ph/4)
   if cell:GetAttribute("Key")~=key then
    cell:SetAttribute("Key",key)
    NumberStyles.DrawScaled(cell,ch,style,math.max(ph,4))
    for _,d in ipairs(cell:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=ov.ZIndex end end
   end
  end
 end
end
-- what the preview visors show: your number while you have one (in a round), otherwise the idle O__O face, which
-- blinks now and then like the real visor (ServerScriptService.VisorDisplay / StarterPlayerScripts.VisorFaces)
local blinkNext,blinkShut,blinkAgain=os.clock()+2,0,false
local function previewFace(player)
 local char=player.Character
 local code=char and char:GetAttribute("NumberfallCode")
 if code then return tostring(code) end
 local now=os.clock()
 if now>=blinkNext then
  blinkShut=now+0.13
  if not blinkAgain and math.random()<0.25 then blinkAgain=true;blinkNext=now+0.3 else blinkAgain=false;blinkNext=now+2.2+math.random()*3.3 end
 end
 return now<blinkShut and "-__-" or "O__O"
end
function M:VisorOverlay(name)
 local cp=self.g[name].CharacterPreview;local vp=cp.AvatarViewport
 local model=self.models[name]
 local size=vp.AbsoluteSize.Y
 local unit=size>0 and (cp.Size.Y.Offset>0 and cp.Size.Y.Offset or size)/size or 1
 drawVisorOverlay(vp,self.cams[name],model,model and model:GetAttribute("LookNum") or NumberStyles.Default,previewFace(self.v.player),unit)
end
-- main-menu portrait: your equipped number style showing the idle O__O face (blinks)
function M:CardOverlay()
 local avatar=self.g.Lobby.PlayerCard:FindFirstChild("Avatar");local vp=self.cardVp
 if not avatar or not vp or not vp.Parent then return end
 local size=vp.AbsoluteSize.Y
 local unit=size>0 and (avatar.Size.Y.Offset>0 and avatar.Size.Y.Offset or size)/size or 1
 drawVisorOverlay(vp,self.cardCam,self.cardModel,self.v.player:GetAttribute("NumberStyle") or NumberStyles.Default,self.cardFace or "O__O",unit)
end
function M:Rotate()
 -- hop: the little jump of the clothing quick-change (OutfitFX)
 local lift=CFrame.new(0,self.hop or 0,0)
 for _,model in pairs(self.models)do if model.Parent then model:PivotTo(lift*CFrame.Angles(0,self.angle,0))end end
end
-- CLOTHING QUICK-CHANGE (only clothes get this; hair, head items, number styles... just swap)
--  full (equipping an outfit / colourway): one fast turn with a small hop that lands with a dip, a red scan ring
--  sweeping up the body and a light bar rising over the preview
--  light (trying an outfit / colourway on): just the scan ring and the light bar, no turn
local FX_RED=Color3.fromRGB(255,30,62)
local function scanRing(world,cf,size,dur)
 local ring=Instance.new("Model");ring.Name="OutfitScan"
 local r=math.max(size.X,size.Z)*.5+.35;local n=32;local parts={}
 for i=1,n do
  local a=(i/n)*math.pi*2
  local p=Instance.new("Part");p.Anchored=true;p.CanCollide=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=FX_RED
  p.Size=Vector3.new(.07,.07,2*math.pi*r/n+.02);p.Parent=ring
  parts[i]={p,a}
 end
 ring.Parent=world
 local bottom,top=cf.Position.Y-size.Y/2,cf.Position.Y+size.Y/2
 local start=os.clock()
 task.spawn(function()
  while ring.Parent do
   local k=math.clamp((os.clock()-start)/dur,0,1)
   local e=1-(1-k)^2
   local y=bottom+(top-bottom)*e
   local rr=r*(1-.15*math.sin(math.pi*k))
   for _,pa in ipairs(parts)do
    local p,a=pa[1],pa[2]
    p.CFrame=CFrame.new(cf.Position.X+math.cos(a)*rr,y,cf.Position.Z+math.sin(a)*rr)*CFrame.Angles(0,-a,0)
    p.Transparency=k<.8 and .05 or (.05+.95*(k-.8)/.2)
   end
   if k>=1 then break end
   task.wait()
  end
  ring:Destroy()
 end)
end
local function lightSweep(panel,dur)
 if not panel then return end
 local old=panel:FindFirstChild("OutfitSweep");if old then old:Destroy() end
 local holder=Instance.new("Frame");holder.Name="OutfitSweep";holder.BackgroundTransparency=1;holder.Size=UDim2.fromScale(1,1);holder.ClipsDescendants=true
 holder.ZIndex=(panel.ZIndex or 1)+8;holder.Active=false;holder.Parent=panel
 local cr=Instance.new("UICorner");cr.CornerRadius=UDim.new(0,10);cr.Parent=holder
 local bar=Instance.new("Frame");bar.BorderSizePixel=0;bar.BackgroundColor3=FX_RED;bar.Size=UDim2.new(1,0,0,90);bar.ZIndex=holder.ZIndex;bar.Parent=holder
 local g=Instance.new("UIGradient");g.Rotation=90
 g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.55,.72),NumberSequenceKeypoint.new(.6,.45),NumberSequenceKeypoint.new(1,1)});g.Parent=bar
 local edge=Instance.new("Frame");edge.BorderSizePixel=0;edge.BackgroundColor3=Color3.fromRGB(255,210,218);edge.BackgroundTransparency=.35;edge.Size=UDim2.new(1,0,0,2)
 edge.Position=UDim2.fromScale(0,.6);edge.ZIndex=holder.ZIndex+1;edge.Parent=bar
 local start=os.clock()
 task.spawn(function()
  while holder.Parent do
   local t=os.clock()-start
   local k=math.clamp(t/dur,0,1);local e=1-(1-k)^2
   bar.Position=UDim2.new(0,0,1-e*1.15,-45)
   bar.BackgroundTransparency=k<.85 and 0 or (k-.85)/.15
   if t>=dur then break end
   task.wait()
  end
  holder:Destroy()
 end)
end
function M:OutfitFX(name,light)
 local model=self.models[name];local panel=self.g[name] and self.g[name]:FindFirstChild("CharacterPreview")
 if not model or not model.Parent then return end
 local world=model.Parent
 for _,c in ipairs(world:GetChildren())do if c.Name=="OutfitScan" then c:Destroy() end end
 local cf,size=model:GetBoundingBox()
 local dur=light and .55 or .8
 scanRing(world,cf-Vector3.new(0,self.hop or 0,0),size,dur)
 lightSweep(panel,dur)
 if light or self.quickChange then return end
 -- one turn with a hop: up over the first half, a quick dip on landing, settle
 self.quickChange=true
 task.spawn(function()
  local total=math.pi*2;local start=os.clock();local done=0
  while true do
   local k=math.clamp((os.clock()-start)/dur,0,1)
   local eased=k<.5 and 4*k^3 or 1-(-2*k+2)^3/2
   self.targetAngle+=total*eased-done;done=total*eased
   self.hop=(k<.75 and .45*math.sin(math.pi*k/.75) or -.08*math.sin(math.pi*(k-.75)/.25))
   if k>=1 then break end
   task.wait()
  end
  self.hop=0;self.quickChange=false
 end)
end
function M:Page(delta)
 local list=self:ShopList()
 local pages=list and math.max(1,math.ceil(#list/6)) or 1
 -- no wrap-around: PREV stops at the first page and NEXT at the last (the pager dims them there)
 local to=math.clamp((self.v.page or 1)+delta,1,pages)
 if to==self.v.page then return end
 self.v.page=to;self:Shop()
 if self.v.menuSounds then pcall(function()self.v.menuSounds:Play("UITab")end)end
end
-- Shop listing for the current tab: things you don't own yet first (in catalogue order), owned ones at the back
local function shopOwned(p,item)return item.Kind and hairOwned(p,item) or (not item.Kind and (p:GetAttribute("Own_"..item.Id) or item.Price==0))end
local function shopEquipped(p,item)return item.Kind and hairEquipped(p,item) or (not item.Kind and (p:GetAttribute("NotebookFinish") or "Classic")==item.Id)end
-- the outfit / pet / mask the Shop's COLOURS page is for: the one you picked in the Shop (owned or only being
-- previewed), else what you have on (nil: no pet / no mask)
function M:ShopCw(cat)
 local p=self.v.player;local pick=self.shopCw and self.shopCw[cat]
 if cat==CLOTHES then
  if pick and Outfits.ById[pick] then return pick end
  return p:GetAttribute("Outfit") or Outfits.Default
 elseif cat==PETS then
  if realPet(pick) then return pick end
  local out=p:GetAttribute("Pet");return realPet(out) and out or nil
 elseif cat==MASKS then
  if realMask(pick) then return pick end
  local on=p:GetAttribute("FaceMask");return realMask(on) and on or nil
 elseif cat==GEAR then
  -- gear colours: for the gear you picked (owned or previewed), else the gear you have equipped
  if pick and gearItem(pick) then return pick end
  return p:GetAttribute("NotebookFinish") or "Classic"
 elseif cat==HAIR then
  -- hair colours: for the hairstyle you picked (owned or previewed), else the one you wear (nil: no hair)
  if pick and pick~="None" then return pick end
  local on=p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle;return on~="None" and on or nil
 end
end
function M:ShopColours()return self.shopMode and self.shopMode[self.category]=="color" and (self.category==CLOTHES or self.category==PETS or self.category==MASKS or self.category==HAIR or self.category==GEAR) end
local function shopKey(it) return tostring(it.Id)..":"..tostring(it.ForStyle or it.ForOutfit or it.ForPet or it.ForMask or it.ForGear or "") end
-- The order a Shop tab was in when you opened it stays put while the Shop is open: something you buy (or equip)
-- keeps its place instead of jumping to the back / front, and moves only after you leave the Shop.
function M:ShopList()
 local list=self:ShopListFresh()
 if not list then return list end
 -- (only while the Shop is open: when it's shut the order is worked out fresh, and the next visit starts from that)
 if not (self.g and self.g.Shop and self.g.Shop.Visible) then self.shopOrder=nil;return list end
 local key=tostring(self.category)..":"..(self:ShopColours() and ("c:"..tostring(self:ShopCw(self.category))) or "items")
 self.shopOrder=self.shopOrder or {}
 local order=self.shopOrder[key]
 if not order then
  order={};for n,it in ipairs(list)do order[shopKey(it)]=n end
  self.shopOrder[key]=order
  return list
 end
 -- (anything new to this tab goes after the ones already placed)
 local out=table.clone(list)
 local extra=#list
 local rank={}
 for n,it in ipairs(out)do rank[it]=order[shopKey(it)] or (extra+n) end
 table.sort(out,function(x,y) return rank[x]<rank[y] end)
 return out
end
function M:ShopListFresh()
 if self:ShopColours() then
  local id=self:ShopCw(self.category)
  local p=self.v.player;local function on(it)return shopEquipped(p,it)end
  if self.category==CLOTHES then return equippedFirst(byPrice(colorwaysFor(id)),on) elseif self.category==PETS then return equippedFirst(byPrice(petColorsFor(id)),on) elseif self.category==GEAR then return equippedFirst(byPrice(gearColorsFor(id)),on) elseif self.category==HAIR then return equippedFirst(byPrice(hairColorsFor(id)),on) else return equippedFirst(byPrice(maskColorsFor(id)),on) end
 end
 local src=self.category==HAIR and shopHair or self.category==NUMS and numShopList(self.v.player) or self.category==MASKS and maskList or self.category==CLOTHES and outfitShopList(self.v.player) or self.category==VISOR and visorListFor(self.v.player,true) or self.category==TRAIL and trailListFor(self.v.player,true) or EXTRA_TAB[self.category] or self.category==4 and self.v.catalog or nil
 if not src then return nil end
 local p=self.v.player;local front,back={},{}
 local sorted=byPrice(src)
 if self.category==4 then
  local dev,rest={},{}
  for _,it in ipairs(sorted)do table.insert(it.Device and dev or rest,it)end
  for _,it in ipairs(rest)do table.insert(dev,it)end
  sorted=dev
 end
 for _,it in ipairs(sorted)do table.insert(shopOwned(p,it) and back or front,it)end
 for _,it in ipairs(back)do table.insert(front,it)end
 return equippedFirst(front,function(it)return shopEquipped(p,it)end)
end
-- The Loadout only lists what you own (buying happens in the Shop). The one exception is hair colours: every
-- colour is listed for the hairstyle you're wearing (which you own), and the paid ones are bought right there.
function M:InvItems()
 local p=self.v.player
 local worn=p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle
 return equippedFirst(byPrice(self:InvItemsRaw()),function(it)
  -- hair colours here are for the hairstyle picked in STYLES: "on" only when that's the one you wear
  if it.Kind=="color" and not it.ForStyle then return self:CwStyle()==worn and p:GetAttribute("HairColor")==it.Id end
  if it.Kind then return hairEquipped(p,it) end
  return (p:GetAttribute("NotebookFinish") or "Classic")==it.Id
 end)
end
function M:InvItemsRaw()
 local c=self.inventoryCategory;local p=self.v.player
 if c==HAIR then
  local mode=self.hairMode or "style";local t={}
  for _,it in ipairs(hairList)do if it.Kind==mode and (mode=="color" or hairOwned(p,it))then table.insert(t,it)end end
  return t
 end
 if c==MASKS and self.maskMode=="color" then return maskColorsFor(self:CwMask()) end
 if c==MASKS then local t={};for _,it in ipairs(maskList)do if hairOwned(p,it)then table.insert(t,it)end end;return t end
 if c==NUMS then local t={};for _,it in ipairs(numList)do if hairOwned(p,it)then table.insert(t,it)end end;return t end
 if c==CLOTHES then
  -- colours: every colourway is listed for the outfit you're wearing; paid ones are bought right there
  if self.clothMode=="color" then return colorwaysFor(self:CwOutfit()) end
  local t={};for _,it in ipairs(outfitList)do if hairOwned(p,it)then table.insert(t,it)end end;return t
 end
 if c==PETS and self.petMode=="color" then return petColorsFor(self:CwPet()) end
 if EXTRA_TAB[c] then local t={};for _,it in ipairs(EXTRA_TAB[c])do if hairOwned(p,it)then table.insert(t,it)end end;return t end
 if c==VISOR then return visorListFor(p,false) end
 if c==TRAIL then return trailListFor(p,false) end
 if c==GEAR and self.gearMode=="color" then return gearColorsFor(self:CwGear()) end
 if c==4 then local t={};for _,it in ipairs(self.v.catalog)do if p:GetAttribute("Own_"..it.Id) or it.Price==0 then table.insert(t,it)end end;return t end
 return nil
end
-- the outfit Loadout > Clothing > COLOURWAYS is showing: the one you picked in OUTFITS, or the one you're wearing
function M:CwOutfit()
 local p=self.v.player
 if self.cwOutfit and Outfits.ById[self.cwOutfit] and hairOwned(p,{Id=self.cwOutfit,Price=(Outfits.ById[self.cwOutfit].Price),Kind="outfit"}) then return self.cwOutfit end
 return p:GetAttribute("Outfit") or Outfits.Default
end
-- the pet Loadout > Pets > COLOURS is showing: the one you picked, or the one you have out (nil: no pet)
function M:CwPet()
 local p=self.v.player
 if realPet(self.cwPet) and p:GetAttribute("OwnHair_"..self.cwPet)==true then return self.cwPet end
 local out=p:GetAttribute("Pet")
 return realPet(out) and out or nil
end
-- the hairstyle Loadout > Hair > COLOURS is for: the one you picked in STYLES, or the one you wear
function M:CwStyle()
 local p=self.v.player;local s=self.lookStyle
 if s and s~="None" and p:GetAttribute("OwnHair_"..s)==true then return s end
 return p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle
end
-- the mask Loadout > Mask > COLOURS is showing: the one you picked, or the one you wear (nil: no mask)
function M:CwMask()
 local p=self.v.player
 if realMask(self.cwMask) and p:GetAttribute("OwnHair_"..self.cwMask)==true then return self.cwMask end
 local on=p:GetAttribute("FaceMask")
 return realMask(on) and on or nil
end
-- the gear Loadout > Gear > COLOURS is showing: the one you picked, or the one you have equipped
function M:CwGear()
 local p=self.v.player
 local g=self.cwGear and gearItem(self.cwGear)
 if g and ((g.Price or 0)==0 or p:GetAttribute("Own_"..g.Id)==true) then return g.Id end
 return p:GetAttribute("NotebookFinish") or "Classic"
end
function M:InventoryPage(delta)
 local items=self:InvItems()
 local pages=items and math.max(1,math.ceil(#items/6)) or 1
 local to=math.clamp(self.inventoryPage+delta,1,pages)
 if to==self.inventoryPage then return end
 self.inventoryPage=to
 self:Inventory()
 if self.v.menuSounds then pcall(function()self.v.menuSounds:Play("UITab")end)end
end
-- is this card what you have on? (Loadout hair colours are for the hairstyle picked in STYLES)
function M:IsOn(item)
 local p=self.v.player
 if not item.Kind then return (p:GetAttribute("NotebookFinish") or "Classic")==item.Id end
 if item.Kind=="color" and not item.ForStyle then return self:CwStyle()==(p:GetAttribute("HairStyle") or HairCatalog.DefaultStyle) and p:GetAttribute("HairColor")==item.Id end
 return hairEquipped(p,item)
end
-- what taking a card off puts back: no hair / no mask / no pet, the default outfit / number style / effect, or the
-- original colours (nil: nothing to take off, e.g. a body type)
local function unequipId(item,p)
 local k=item.Kind
 if k=="style" then return "None" end
 if k=="mask" then return HairCatalog.DefaultMask end
 if k=="outfit" then return Outfits.Default end
 if k=="numstyle" then return NumberStyles.Default end
 if k=="color" then return HairCatalog.DefaultColor..(item.ForStyle and ("|"..item.ForStyle) or "") end
 if k=="colorway" then return Outfits.DefaultColorway.."|"..(item.ForOutfit or p:GetAttribute("Outfit") or Outfits.Default) end
 if k=="maskcolor" then return Extras.DefaultMaskColorway.."|"..item.ForMask end
 if k=="petcolor" then return Extras.DefaultPetColorway.."|"..item.ForPet end
 if k=="gearcolor" then return GearColorways.Default.."|"..item.ForGear end
 if k=="visorcolor" then return VisorColorways.Default end
 if k~="body" and Extras.Default[k] then return Extras.Default[k] end
 return nil
end
-- double click on a card (Shop or Loadout): put it on if you own it, take it off if it's on
function M:QuickEquip(item,where)
 local v=self.v;local p=v.player
 if not item then return end
 -- VISOR / TRAIL: put it on, or (it's on) go back to Standard
 if rankLook(item) then
  if p:GetAttribute("ProfileReady")~=true then v:Toast("Profile loading…");return end
  local id=item.Id
  if self:IsOn(item) then if id=="Standard" then v:Toast("That's already the default.");return end;id="Standard" end
  if not RankLooks.Owns(p,id) then v:Toast(RankLooks.LockText(id));return end
  v.remote:FireServer(item.Kind=="visor" and "EquipVisor" or "EquipTrail",id);return
 end
 if p:GetAttribute("ProfileReady")~=true then v:Toast("Profile loading…");return end
 if self:IsOn(item) then
  if not item.Kind then if item.Id~="Classic" then v.remote:FireServer("Equip","Classic") end;return end
  -- a trail colour comes off back to the standard trail (the best your rank unlocks)
  if item.Kind=="trailcolor" then v.remote:FireServer("EquipTrail","Standard");return end
  local id=unequipId(item,p)
  local base=id and id:match("^([^|]+)") or nil
  if not id or base==item.Id then v:Toast("That's already the default.");return end
  v.remote:FireServer("EquipHair",id);return
 end
 if where=="Shop" then
  self.shopSel=item;self.shopPick=item.Kind and item or nil;self:Purchase(true);self:Shop();self:PreviewLook()
  return
 end
 local own
 if not item.Kind then own=p:GetAttribute("Own_"..item.Id) or item.Price==0
 elseif item.Kind=="color" and not item.ForStyle then own=colourOwnedFor(p,item,self:CwStyle())
 else own=hairOwned(p,item) end
 if not own then v:Toast("Buy it first.");return end
 self.invSel=item;self:InventoryAction();self:Inventory()
end
-- primary action: equip the selection, buy it, or report it's already on
function M:InventoryAction()
 local v=self.v;local item=self.invSel
 if not item then v:Toast("Select an item first.");return end
 if v.player:GetAttribute("ProfileReady")~=true then v:Toast("Profile loading…");return end
 if rankLook(item) then
  if not RankLooks.Owns(v.player,item.Id) then v:Toast(RankLooks.LockText(item.Id));return end
  if hairEquipped(v.player,item) then v:Toast("Already equipped.");return end
  v.remote:FireServer(item.Kind=="visor" and "EquipVisor" or "EquipTrail",item.Id);return
 end
 if item.Kind then
  -- a hair colour is for the hairstyle picked in STYLES (or the one you wear)
  local cs=item.Kind=="color" and self:CwStyle() or nil
  local other=cs~=nil and cs~=(v.player:GetAttribute("HairStyle") or HairCatalog.DefaultStyle)
  local own=item.Kind=="color" and colourOwnedFor(v.player,item,cs) or hairOwned(v.player,item)
  if not other and hairEquipped(v.player,item)then v:Toast("Already equipped.");return end
  if not own and StoreUI.Locked(item) and v.marksStore then v.marksStore:PromptItem(item);return end
  local sendId=item.Id
  if other then sendId=item.Id.."|"..cs end
  if item.Kind=="colorway" and item.ForOutfit then sendId=item.Id.."|"..item.ForOutfit end
  if item.Kind=="petcolor" then sendId=item.Id.."|"..item.ForPet end
  if item.Kind=="maskcolor" then sendId=item.Id.."|"..item.ForMask end
  if item.Kind=="gearcolor" then sendId=item.Id.."|"..item.ForGear end
  v.remote:FireServer(own and "EquipHair" or "BuyHair",sendId)
 else
  local owned=v.player:GetAttribute("Own_"..item.Id)or item.Price==0
  if v.player:GetAttribute("NotebookFinish")==item.Id then v:Toast("Already equipped.");return end
  if not owned and StoreUI.Locked(item) and v.marksStore then v.marksStore:PromptItem(item);return end
  v.remote:FireServer(owned and "Equip" or "Buy",item.Id)
 end
end
-- Item(i): the card in slot i of this page. Item(): the selected item, or (nothing picked yet) what you have on.
function M:Item(index)
 local list=self:ShopList()
 if not list then return nil end
 if index then return list[(self.v.page-1)*6+index] end
 if self.shopSel then for _,it in ipairs(list)do if it==self.shopSel then return it end end end
 for _,it in ipairs(list)do if shopEquipped(self.v.player,it)then return it end end
 return nil
end
function M:Purchase(equipOnly)
 local v=self.v;local item=self:Item()
 if not item then v:Toast("This cosmetic category is coming soon.");return end
 if v.player:GetAttribute("ProfileReady")~=true then v:Toast("Profile loading…");return end
 -- VISOR / TRAIL: nothing to buy -- wear it if your rank has it; the VIP ones offer VIP
 if rankLook(item) then
  if not RankLooks.Owns(v.player,item.Id) then
   if item.Id=="VIP" and v.marksStore then v.marksStore:PromptVIP() else v:Toast(RankLooks.LockText(item.Id)) end
   return
  end
  if hairEquipped(v.player,item) then v:Toast("Already equipped.");return end
  v.remote:FireServer(item.Kind=="visor" and "EquipVisor" or "EquipTrail",item.Id);return
 end
 if item.Kind then
  if not cwBaseOwned(v.player,item) then
   -- a colourway of something you're previewing: jump back to that item (selected) so it can be bought
   local baseId,n=cwBase(item)
   self.shopMode[self.category]="style";v.page=1
   local list=self:ShopList() or {}
   for k,it in ipairs(list)do if it.Id==baseId then self.shopSel=it;self.shopPick=it;self.selected=(k-1)%6+1;v.page=math.ceil(k/6) end end
   self:Shop();self:PreviewLook()
   v:Toast("Buy the "..n.." first, then its colours unlock.");return
  end
  local owned=hairOwned(v.player,item)
  if equipOnly and not owned then v:Toast("Purchase this first.");return end
  if not owned and StoreUI.Locked(item) and v.marksStore then v.marksStore:PromptItem(item);return end
  local sendId=item.Id
  if item.Kind=="colorway" and item.ForOutfit then sendId=item.Id.."|"..item.ForOutfit
  elseif item.Kind=="petcolor" then sendId=item.Id.."|"..item.ForPet
  elseif item.Kind=="maskcolor" then sendId=item.Id.."|"..item.ForMask
  elseif item.Kind=="gearcolor" then sendId=item.Id.."|"..item.ForGear
  elseif item.Kind=="color" and item.ForStyle then sendId=item.Id.."|"..item.ForStyle end
  v.remote:FireServer(owned and "EquipHair"or "BuyHair",sendId);return
 end
 local owned=v.player:GetAttribute("Own_"..item.Id)or item.Price==0
 if equipOnly and not owned then v:Toast("Purchase this finish before equipping it.");return end
 if not owned and StoreUI.Locked(item) and v.marksStore then v.marksStore:PromptItem(item);return end
 v.remote:FireServer(owned and "Equip"or "Buy",item.Id)
end
function M:Shop()
 local g=self.g;local v=self.v
 local casesOpen=g.Shop:GetAttribute("CasesOpen")==true -- (the CASES page: StarterPlayerScripts.CaseOpening)
 local active=(v.marksStore and v.marksStore.active) or casesOpen
 g.Shop.Selection.Visible=false;g.Shop.Bundle.Visible=false;g.Shop.CatalogOutline.Visible=not active
 if active then
  for i=0,5 do g.Shop["Product"..i].Visible=false end
  -- on the CASES page no category tab is the current one (the CASES button is)
  if casesOpen then for i=0,9 do local tab=g.Shop:FindFirstChild("Tab"..i);if tab then local sub=tab:FindFirstChild("Sub");Style.Tab(tab,false,sub and sub.Text or nil,false) end end end
  return
 end
 local counts={[0]=#numShopList(v.player),[1]=#shopHair,[2]=#outfitShopList(v.player),[4]=#v.catalog,[7]=#maskList,[BODY]=#bodyList,[FXTAB]=#fxList,[PETS]=#petList,[VISOR]=#visorListFor(v.player,true),[TRAIL]=#trailListFor(v.player,true)}
 for i=0,9 do local n=counts[i];local tab=g.Shop:FindFirstChild("Tab"..i);if tab then Style.Tab(tab,i==self.category,n and (n.." ITEMS") or "SOON",n==nil) end end
 local hair=self.category==HAIR;local masks=self.category==MASKS;local clothes=self.category==CLOTHES;local nums=self.category==NUMS
 local extra=EXTRA_TAB[self.category]~=nil
 local real=self.category==4 or extra or hair or masks or clothes or nums or self.category==VISOR or self.category==TRAIL
 local list=self:ShopList()
 local pages=list and math.max(1,math.ceil(#list/6)) or 1
 v.page=math.clamp(v.page or 1,1,pages)
 g.Shop.Previous.Visible=pages>1;g.Shop.Next.Visible=pages>1
 g.Shop.Previous.Active=pages>1;g.Shop.Next.Active=pages>1
 g.Shop:SetAttribute("CurrentPage",v.page)
 g.Shop:SetAttribute("PageCount",pages)
 local canColour=self.category==CLOTHES or self.category==PETS or self.category==MASKS or hair or self.category==GEAR
 local colours=self:ShopColours()
 for _,pair in ipairs({{"ShopToggleStyles",false},{"ShopToggleColours",true}})do
  local b=g.Shop:FindFirstChild(pair[1])
  if b then
   b.Visible=canColour
   if canColour then
    pcall(Style.Toggle,b,(colours==true)==pair[2])
    local l=b:FindFirstChild("Label") or b:FindFirstChildWhichIsA("TextLabel")
    local t=pair[2] and (clothes and "COLOURWAYS" or "COLOURS") or (clothes and "OUTFITS" or self.category==PETS and "PETS" or hair and "STYLES" or self.category==GEAR and "GEAR" or "MASKS")
    if l then l.Text=t elseif b:IsA("TextButton") then b.Text=t end
   end
  end
 end
 local names=({"NUMBER STYLES","HAIR","CLOTHING","ELIMINATION FX","GEAR","PETS","BODY TYPES","MASKS","VISORS","TRAILS"})
 g.Shop.ShopStatus.Text=extra and ((self.category==BODY and "BODY TYPES" or self.category==FXTAB and "ELIMINATION FX" or "PETS").." / PAGE "..v.page.." OF "..pages) or nums and ("NUMBER STYLES / PAGE "..v.page.." OF "..pages) or clothes and ("CLOTHING / PAGE "..v.page.." OF "..pages) or hair and ("HAIRSTYLES / PAGE "..v.page.." OF "..pages) or masks and "HEAD" or real and ("GEAR / PAGE "..v.page.." OF "..pages)or names[self.category+1].." / COMING SOON"
 if self.category==VISOR or self.category==TRAIL then g.Shop.ShopStatus.Text=(self.category==VISOR and "VISORS" or "TRAILS").." / PAGE "..v.page.." OF "..pages end
 if colours then
  local id=self:ShopCw(self.category)
  local what=self.category==CLOTHES and outfitName(id) or self.category==PETS and (id and extraName(id) or "") or self.category==GEAR and (id and gearName(id) or "") or ""
  if self.category==MASKS then for _,m in ipairs(maskList)do if m.Id==id then what=m.Name end end end
  if hair and id then what=styleName(id) end
  local preview=id and ((self.category==CLOTHES and not cwBaseOwned(v.player,{Kind="colorway",ForOutfit=id})) or (self.category==GEAR and not cwBaseOwned(v.player,{Kind="gearcolor",ForGear=id})) or (self.category~=CLOTHES and self.category~=GEAR and v.player:GetAttribute("OwnHair_"..id)~=true))
  g.Shop.ShopStatus.Text=id and ((self.category==CLOTHES and "COLOURWAYS / " or hair and "HAIR COLOURS / " or "COLOURS / ")..what:upper()..(preview and " (PREVIEW)" or "").." / PAGE "..v.page.." OF "..pages)
   or (self.category==PETS and "PET COLOURS / GET A PET FIRST" or hair and "HAIR COLOURS / PICK A HAIRSTYLE FIRST" or "MASK COLOURS / GET A MASK FIRST")
 end
 for i=0,5 do
  local c=g.Shop["Product"..i];local item=self:Item(i+1);c.Visible=not real or item~=nil
  if c.Visible then
   c.ItemName.Text=item and item.Name:upper()or self.category==0 and previewNames[i+1]or names[self.category+1]
   c.PendingArt.Visible=not c.Thumbnail.Visible;c.PendingArt.Text=extra and "" or nums and "NUMBER" or clothes and "OUTFIT" or masks and "MASK" or hair and (item.Kind=="color" and "COLOUR" or (item.Gender=="F" and "HAIR  F" or "HAIR  M")) or real and (self.category==5 and "PEN"or "NOTEBOOK")or self.category==0 and ({"4729","1380","2217","3093","9064","7224"})[i+1]or "COMING SOON"
   c.PendingArt.TextSize=real and 30 or self.category==0 and 54 or 22
   local hc=v.player:GetAttribute("HairColor")
   if item and item.Kind=="style" and item.Id~=v.player:GetAttribute("HairStyle") then hc=v.player:GetAttribute("HairCol_"..item.Id) or HairCatalog.DefaultColor end
   if item and item.Kind=="body" then c.PendingArt.Visible=false;Draw(c,"body:"..item.Id..":"..tostring(v.player:GetAttribute("Outfit"))..":"..tostring(v.player:GetAttribute("SkinTone"))..lookKey(v.player),function()SafeArt(Art.Body,c,item.Id,PanelStyle.ShopArt)end)
   elseif item and item.Kind=="pet" then c.PendingArt.Visible=false;local pc=v.player:GetAttribute("PetCw_"..item.Id);Draw(c,"pet:"..item.Id..":"..tostring(pc),function()SafeArt(Art.Pet,c,item.Id,PanelStyle.ShopArt,pc)end)
   elseif item and item.Kind=="killfx" then c.PendingArt.Visible=false;Draw(c,"killfx:"..item.Id,function()SafeArt(Art.KillFx,c,item,PanelStyle.ShopArt)end)
   elseif item and item.Kind=="numstyle" then c.PendingArt.Visible=false;Draw(c,"numstyle:"..item.Id,function()SafeArt(NumberStyles.Card,c,item.Id,PanelStyle.ShopNumber,"4729")end)
   elseif item and item.Kind=="style" then c.PendingArt.Visible=false;Draw(c,"style:"..item.Id..":"..tostring(hc),function()SafeArt(Art.Hair,c,item.Id,hc,PanelStyle.ShopArt)end)
   elseif item and item.Kind=="color" and item.ForStyle then c.PendingArt.Visible=false
    -- the hairstyle in that colour, with the colour's swatch in the corner
    local a=PanelStyle.ShopArt
    Draw(c,"color:"..item.ForStyle..":"..item.Id,function()SafeArt(Art.Hair,c,item.ForStyle,item.Id,a)
     SafeArt(function()local sw=Art.Swatch(c,item.Id,{Position=UDim2.fromOffset(a.Position.X.Offset+a.Size.X.Offset-46,a.Position.Y.Offset+a.Size.Y.Offset-46),Size=UDim2.fromOffset(40,40)},true);sw.Name="SwatchChip"end)end)
   elseif item and item.Kind=="color" then c.PendingArt.Visible=false;Draw(c,"color:"..item.Id,function()SafeArt(Art.Swatch,c,item.Id,PanelStyle.ShopSwatch)end)
   elseif item and item.Kind=="mask" then c.PendingArt.Visible=false;local mc=v.player:GetAttribute("MaskCw_"..item.Id);Draw(c,"mask:"..item.Id..":"..tostring(mc),function()SafeArt(Art.Mask,c,item.Id,PanelStyle.ShopArt,mc)end)
   elseif item and item.Kind=="colorway" then c.PendingArt.Visible=false
    local a=PanelStyle.ShopArt
    Draw(c,"colorway:"..tostring(item.ForOutfit)..":"..item.Id..":"..tostring(v.player:GetAttribute("SkinTone"))..lookKey(v.player),function()SafeArt(Art.Outfit,c,item.ForOutfit,a,item.Id)
     SafeArt(Art.Colorway,c,item.ForOutfit,item.Id,{Position=UDim2.fromOffset(a.Position.X.Offset+a.Size.X.Offset-46,a.Position.Y.Offset+a.Size.Y.Offset-46),Size=UDim2.fromOffset(40,40)})end)
   elseif item and item.Kind=="petcolor" then c.PendingArt.Visible=false;Draw(c,"petcolor:"..item.ForPet..":"..item.Id,function()SafeArt(Art.Pet,c,item.ForPet,PanelStyle.ShopArt,item.Id)end)
   elseif item and item.Kind=="maskcolor" then c.PendingArt.Visible=false;Draw(c,"maskcolor:"..item.ForMask..":"..item.Id,function()SafeArt(Art.Mask,c,item.ForMask,PanelStyle.ShopArt,item.Id)end)
   elseif item and item.Kind=="outfit" then c.PendingArt.Visible=false
    local oc=(item.Id==v.player:GetAttribute("Outfit")) and v.player:GetAttribute("OutfitColor") or v.player:GetAttribute("OutfitCw_"..item.Id)
    Draw(c,"outfit:"..item.Id..":"..tostring(oc)..":"..tostring(v.player:GetAttribute("SkinTone"))..lookKey(v.player),function()SafeArt(Art.Outfit,c,item.Id,PanelStyle.ShopArt,oc)end)
   elseif item and item.Kind=="visor" then c.PendingArt.Visible=false;Draw(c,"visor:"..item.Id,function()SafeArt(Art.Visor,c,item.Id,PanelStyle.ShopArt)end)
    elseif item and item.Kind=="visorcolor" then c.PendingArt.Visible=false;Draw(c,"visorcolor:"..item.Id,function()SafeArt(Art.Visor,c,"Standard",PanelStyle.ShopArt,nil,item.Id)end)
   elseif item and (item.Kind=="trail" or item.Kind=="trailcolor") then c.PendingArt.Visible=false;Draw(c,"trail:"..item.Id,function()SafeArt(Art.Trail,c,item.Id,PanelStyle.ShopArt)end)
   elseif item and item.Kind=="gearcolor" then c.PendingArt.Visible=false;Draw(c,"gearcolor:"..item.ForGear..":"..item.Id,function()SafeArt(Art.Kit,c,gearItem(item.ForGear),PanelStyle.ShopArt,item.Id)end)
   elseif item and self.category==4 then c.PendingArt.Visible=false;local gcw=gearCwOf(v.player,item.Id);Draw(c,"kit:"..item.Id..":"..tostring(gcw),function()SafeArt(Art.Kit,c,item,PanelStyle.ShopArt,gcw)end)
   elseif self.category==0 then c.PendingArt.Visible=false;Draw(c,"num:"..c.PendingArt.Text,function()SafeArt(Art.Number,c,c.PendingArt.Text,PanelStyle.ShopNumber)end)
   else Draw(c,"none") end
   -- outfits / head items / pets / hairstyles: the colourway each one is kept in
   do local a=PanelStyle.ShopArt;local n,col=nil,nil
    if item and (item.Kind=="outfit" or item.Kind=="mask" or item.Kind=="pet" or item.Kind=="style" or isGearItem(item)) then n,col=keptColour(v.player,item) end
    colourChip(c,n,col,a.Position.X.Offset+a.Size.X.Offset-6,a.Position.Y.Offset+a.Size.Y.Offset-6)
    rarityTag(c,item,a)
   end
   local baseOwned=not item or cwBaseOwned(v.player,item)
   local owned=item and baseOwned and(item.Kind and hairOwned(v.player,item) or v.player:GetAttribute("Own_"..item.Id)or item.Price==0)
   local equipped=item and (item.Kind and hairEquipped(v.player,item) or v.player:GetAttribute("NotebookFinish")==item.Id)
   -- the same EQUIPPED tag as the Loadout cards, top-left on the art
   local tag=c:FindFirstChild("EquippedChip")
   if not tag then
    local src=g.Inventory:FindFirstChild("Owned0") and g.Inventory.Owned0:FindFirstChild("EquippedChip")
    if src then tag=src:Clone();tag.Parent=c end
   end
   if tag then
    local a=PanelStyle.ShopArt
    tag.Position=UDim2.fromOffset(a.Position.X.Offset+8,a.Position.Y.Offset+8);tag.Size=UDim2.fromOffset(104,26)
    tag.ZIndex=(c.ZIndex or 1)+6;tag.Visible=equipped==true
   end
   c.Buy.Label.Text=item and(equipped and "EQUIPPED"or not baseOwned and "BUY ITEM FIRST" or owned and "EQUIP"or rankLook(item) and RankLooks.LockText(item.Id) or StoreUI.Locked(item) and StoreUI.Label(item) or tostring(item.Price).." MARKS")or "COMING SOON"
    -- (for sale: the price as the marks icon + price and the green Robux icon + price)
    self:SplitPrice(c.Buy,"BuyRobux",item,item~=nil and c.Buy.Label.Text==tostring(item.Price).." MARKS",1.4,c:FindFirstChild("ItemName"))
   if item and item.Color then c.PendingArt.TextColor3=Color3.fromRGB(item.Color[1],item.Color[2],item.Color[3]) else c.PendingArt.TextColor3=Color3.fromRGB(238,233,230) end
   -- white ring = what you picked; red ring = what you have on; owned things sit at the back, greyed out
   local picked=item~=nil and item==self.shopSel
   c.Outline.Color=picked and Style.Colors.BONE or (equipped and Color3.fromRGB(255,23,74)) or Style.Colors.DIM
   c.Outline.Thickness=picked and 2 or equipped and 1.6 or 1
   local shade=c:FindFirstChild("OwnedShade")
   if not shade then
    shade=Instance.new("Frame");shade.Name="OwnedShade";shade.Size=UDim2.fromScale(1,1);shade.BorderSizePixel=0
    shade.BackgroundColor3=Color3.fromRGB(8,6,8);shade.BackgroundTransparency=.5;shade.ZIndex=40;shade.Active=false;shade.Parent=c
   end
   -- owned things are greyed out, except what you have on (it leads the list, bright, with its red ring)
   shade.Visible=(owned and not picked and not equipped)==true
  end
 end
 local item=self:Item()
 local detail=g.Shop.Selection
 detail:FindFirstChild("Name").Text=item and item.Name:upper()or self.category==0 and previewNames[self.selected]or names[self.category+1]
 detail.Description.Text=item and (item.Blurb or "") or "This cosmetic is not available yet."
 if item and rankLook(item) then
  local who=nil
  detail.Description.Text=item.Blurb or ""
 end
 if item and item.Kind=="color" and item.ForStyle then
  local sn=styleName(item.ForStyle)
  detail.Description.Text=item.Name.." for "..sn.."."
  if not cwBaseOwned(v.player,item) then detail.Description.Text=item.Name.." for "..sn..". Previewing: buy "..sn.." first, then its colours unlock." end
 end
 if item and (item.Kind=="colorway" or item.Kind=="petcolor" or item.Kind=="maskcolor" or item.Kind=="gearcolor") then
  local forName=item.Kind=="colorway" and outfitName(item.ForOutfit) or item.Kind=="petcolor" and extraName(item.ForPet) or item.Kind=="gearcolor" and gearName(item.ForGear) or "the mask"
  if item.Kind=="maskcolor" then for _,m in ipairs(maskList)do if m.Id==item.ForMask then forName=m.Name end end end
  detail.Description.Text=item.Name.." colourway for "..forName.."."
  if not cwBaseOwned(v.player,item) then detail.Description.Text=item.Name.." colourway for "..forName..". Previewing: buy the "..forName.." first, then its colours unlock." end
 end
 -- COLOURS page with nothing picked yet: say how it works instead of "coming soon"
 if not item and self:ShopColours() and self:ShopCw(self.category) then
  local id=self:ShopCw(self.category)
  local n=self.category==CLOTHES and outfitName(id) or self.category==PETS and extraName(id) or self.category==GEAR and gearName(id) or self.category==HAIR and styleName(id) or ""
  if self.category==MASKS then for _,m in ipairs(maskList)do if m.Id==id then n=m.Name end end end
  detail:FindFirstChild("Name").Text=(n..(self.category==CLOTHES and " COLOURWAYS" or " COLOURS")):upper()
  detail.Description.Text="Pick a colour to try it on "..(self.category==PETS and "your pet" or "your character")..". Colours are bought for each "..(self.category==CLOTHES and "outfit" or self.category==PETS and "pet" or self.category==HAIR and "hairstyle" or "item").."."
  detail.Purchase.Label.Text="PICK A COLOUR";detail.Equip.Active=false;detail.Purchase.Active=false;self:SplitPrice(detail.Purchase,"PurchaseRobux",nil,false,1.25)
  return
 end
 local eqd=item and (item.Kind and hairEquipped(v.player,item) or (not item.Kind and v.player:GetAttribute("NotebookFinish")==item.Id))
 local _,baseName=nil,nil;if item and not cwBaseOwned(v.player,item) then _,baseName=cwBase(item) end
 detail.Purchase.Label.Text=item and (eqd and "EQUIPPED" or baseName and ("BUY THE "..baseName:upper().." FIRST") or (item.Kind and hairOwned(v.player,item) or v.player:GetAttribute("Own_"..item.Id)or item.Price==0)and "EQUIP"or (rankLook(item) and (item.Id=="VIP" and "GET VIP" or RankLooks.LockText(item.Id))) or (StoreUI.Locked(item) and ("PURCHASE  "..StoreUI.Label(item)) or "PURCHASE  ✹ "..item.Price))or "COMING SOON"
 self:SplitPrice(detail.Purchase,"PurchaseRobux",item,item~=nil and detail.Purchase.Label.Text=="PURCHASE  ✹ "..item.Price,1.25)
 detail.Equip.Active=item~=nil;detail.Purchase.Active=item~=nil
 local rp=rarityPill(detail,item and Rarity.Of(item) or nil,"RarityChip")
 if rp then rp.AnchorPoint=Vector2.new(1,0);rp.Position=UDim2.new(1,-20,0,18);rp.ZIndex=(detail.ZIndex or 1)+3;rp.Gem.ZIndex=rp.ZIndex+1;rp.Label.ZIndex=rp.ZIndex+1 end
end
function M:Inventory()
 local v=self.v;local g=self.g;local inv=g.Inventory;local p=v.player;local cat=self.inventoryCategory
 local hair=cat==HAIR;local items=self:InvItems()
 local pages=items and math.max(1,math.ceil(#items/6)) or 1
 self.inventoryPage=math.clamp(self.inventoryPage,1,pages)
 inv.Previous.Visible=pages>1;inv.Next.Visible=pages>1;inv.Previous.Active=pages>1;inv.Next.Active=pages>1
 inv:SetAttribute("CurrentPage",self.inventoryPage);inv:SetAttribute("PageCount",pages)
 inv.PageStatus.Text=pages>1 and string.format("%d / %d",self.inventoryPage,pages)or ""
 -- tabs show what is equipped in each slot
 local styleId,colorId=p:GetAttribute("HairStyle")or HairCatalog.DefaultStyle,p:GetAttribute("HairColor")or HairCatalog.DefaultColor
 local sn,cn="No Hair","Ink"
 for _,s in ipairs(HairCatalog.Styles)do if s.Id==styleId then sn=s.Name end end
 for _,c in ipairs(HairCatalog.Colors)do if c.Id==colorId then cn=c.Name end end
 local finish=p:GetAttribute("NotebookFinish")or "Classic";local fn="Field notes"
 for _,it in ipairs(v.catalog)do if it.Id==finish then fn=it.Name end end
 do local gcn=GearColorways.ById[p:GetAttribute("GearColor") or ""];if gcn and gcn.Id~=GearColorways.Default then fn=fn.." · "..gcn.Name end end
 local mn="No mask";for _,m in ipairs(maskList)do if m.Id==(p:GetAttribute("FaceMask") or HairCatalog.DefaultMask) then mn=m.Name end end
 local mcn=maskColorName(p:GetAttribute("MaskColor"));if mcn~="Original" and realMask(p:GetAttribute("FaceMask")) then mn=mn.." · "..mcn end
 local cwName=colorwayName(p:GetAttribute("OutfitColor"))
 local subs={numName(p:GetAttribute("NumberStyle")):upper(),sn:upper(),(outfitName(p:GetAttribute("Outfit"))..(cwName~="Original" and (" · "..cwName) or "")):upper(),extraName(p:GetAttribute("KillEffect") or Extras.DefaultKillFx):upper(),fn:upper(),extraName(p:GetAttribute("Pet") or Extras.DefaultPet):upper(),extraName(p:GetAttribute("BodyType") or Extras.DefaultBody):upper(),mn:upper()}
 subs[VISOR+1]=RankLooks.Name(RankLooks.Visors,RankLooks.Visor(p)):upper();subs[TRAIL+1]=RankLooks.Name(RankLooks.Trails,RankLooks.Trail(p)):upper()
 for i=0,9 do local tab=inv:FindFirstChild("Category"..i);if tab then Style.Tab(tab,i==cat,subs[i+1],subs[i+1]=="SOON") end end
 -- hair colours follow the hairstyle picked in STYLES (or the one you wear); owned / equipped are per hairstyle
 local cstyle=self:CwStyle()
 local function ownIt(it)
  if it.Kind=="color" then return colourOwnedFor(p,it,cstyle) end
  return it.Kind and hairOwned(p,it) or (not it.Kind and (p:GetAttribute("Own_"..it.Id) or it.Price==0))
 end
 local function eqIt(it)
  if it.Kind=="color" then return cstyle==styleId and colorId==it.Id end
  return it.Kind and hairEquipped(p,it) or (not it.Kind and finish==it.Id)
 end
 -- heading row
 local names={"NUMBER STYLES","HAIR","CLOTHING","ELIMINATION FX","GEAR","PETS","BODY TYPE","HEAD","VISOR","TRAIL"}
 local clothes=cat==CLOTHES
 local pets=cat==PETS
 local masks=cat==MASKS
 local gear=cat==GEAR
 inv.ToggleStyles.Visible=hair or clothes or pets or masks or gear;inv.ToggleColours.Visible=hair or clothes or pets or masks or gear
 if gear then Style.Toggle(inv.ToggleStyles,self.gearMode~="color");Style.Toggle(inv.ToggleColours,self.gearMode=="color")end
 if masks then Style.Toggle(inv.ToggleStyles,self.maskMode~="color");Style.Toggle(inv.ToggleColours,self.maskMode=="color")end
 if pets then Style.Toggle(inv.ToggleStyles,self.petMode~="color");Style.Toggle(inv.ToggleColours,self.petMode=="color")end
 if hair then Style.Toggle(inv.ToggleStyles,self.hairMode=="style");Style.Toggle(inv.ToggleColours,self.hairMode=="color")end
 if clothes then Style.Toggle(inv.ToggleStyles,self.clothMode~="color");Style.Toggle(inv.ToggleColours,self.clothMode=="color")end
 local function toggleText(b,t)local l=b:FindFirstChild("Label") or b:FindFirstChildWhichIsA("TextLabel");if l then l.Text=t elseif b:IsA("TextButton")then b.Text=t end end
 toggleText(inv.ToggleStyles,clothes and "OUTFITS" or pets and "PETS" or masks and "MASKS" or gear and "GEAR" or "STYLES");toggleText(inv.ToggleColours,clothes and "COLOURWAYS" or "COLOURS")
 local owned=0
 if items then for _,it in ipairs(items)do if ownIt(it) then owned+=1 end end end
 inv.SectionHeading.Text=hair and (self.hairMode=="style" and "HAIRSTYLES" or "HAIR COLOURS") or names[cat+1]
 if hair and self.hairMode=="color" then local ln
  for _,st in ipairs(HairCatalog.Styles)do if st.Id==cstyle then ln=st.Name end end
  inv.SectionHeading.Text="HAIR COLOURS  ·  "..(ln or ""):upper()
  if cstyle=="None" then inv.SectionHeading.Text="HAIR COLOURS" end
 end
 if clothes and self.clothMode=="color" then inv.SectionHeading.Text="COLOURWAYS  ·  "..outfitName(self:CwOutfit()):upper() end
 local noPet=pets and self.petMode=="color" and not self:CwPet()
 if pets and self.petMode=="color" and not noPet then inv.SectionHeading.Text="PET COLOURS  ·  "..extraName(self:CwPet()):upper() end
 if gear and self.gearMode=="color" then inv.SectionHeading.Text="GEAR COLOURS  ·  "..gearName(self:CwGear()):upper() end
 local noMask=masks and self.maskMode=="color" and not self:CwMask()
 if masks and self.maskMode=="color" and not noMask then
  local mname="";for _,m in ipairs(maskList)do if m.Id==self:CwMask() then mname=m.Name end end
  inv.SectionHeading.Text="MASK COLOURS  ·  "..mname:upper()
 end
 inv.SectionCount.Text=items and (hair and self.hairMode=="color" and string.format("%d COLOURS  ·  %d OWNED FOR THIS HAIRSTYLE",#items,owned) or clothes and self.clothMode=="color" and string.format("%d COLOURWAYS  ·  %d OWNED FOR THIS OUTFIT",#items,owned) or masks and self.maskMode=="color" and string.format("%d COLOURS  ·  %d OWNED FOR THIS MASK",#items,owned) or gear and self.gearMode=="color" and string.format("%d COLOURS  ·  %d OWNED FOR THIS GEAR",#items,owned) or string.format("%d OWNED  ·  MORE IN THE SHOP",owned)) or (cat==0 and "PREVIEW  ·  COMING SOON" or "COMING SOON")
 if (cat==VISOR or cat==TRAIL) and items then inv.SectionCount.Text=string.format("%d OF %d UNLOCKED",owned,#items) end
 local noStyle=hair and self.hairMode=="color" and cstyle=="None"
 if noStyle then items=nil end
 local empty=(not items and cat~=0)
 inv.EmptyState.Visible=empty;inv.EmptyHint.Visible=empty
 inv.EmptyState.Text=noStyle and "EQUIP A HAIRSTYLE FIRST" or noPet and "PICK A PET FIRST" or noMask and "PICK A MASK FIRST" or names[cat+1].." ARE COMING SOON"
 inv.EmptyHint.Text=noStyle and "Colours are bought for each hairstyle." or noPet and "Colours are bought for each pet." or noMask and "Colours are bought for each mask. Buy one in the Shop." or "New cosmetics arrive with upcoming updates."
 if noStyle then inv.SectionCount.Text="COLOURS ARE BOUGHT FOR EACH HAIRSTYLE" end
 -- cards
 for i=0,5 do
  local c=inv["Owned"..i];local item=items and items[(self.inventoryPage-1)*6+i+1]
  c.Visible=item~=nil
  local nameLabel=c:FindFirstChild("Name")
  if item then
   nameLabel.Text=item.Name:upper()
   local rect=Style.CardArt
   if item.Kind=="body" then Draw(c,"body:"..item.Id..":"..tostring(p:GetAttribute("Outfit"))..":"..tostring(p:GetAttribute("SkinTone"))..lookKey(p),function()SafeArt(Art.Body,c,item.Id,rect)end)
   elseif item.Kind=="pet" then local pc=p:GetAttribute("PetCw_"..item.Id);Draw(c,"pet:"..item.Id..":"..tostring(pc),function()SafeArt(Art.Pet,c,item.Id,rect,pc)end)
   elseif item.Kind=="petcolor" then Draw(c,"petcolor:"..item.ForPet..":"..item.Id,function()SafeArt(Art.Pet,c,item.ForPet,rect,item.Id)end)
   elseif item.Kind=="killfx" then Draw(c,"killfx:"..item.Id,function()SafeArt(Art.KillFx,c,item,rect)end)
   elseif item.Kind=="numstyle" then Draw(c,"numstyle:"..item.Id,function()SafeArt(NumberStyles.Card,c,item.Id,rect,"4729")end)
   elseif item.Kind=="style" then local col=(item.Id==styleId) and colorId or p:GetAttribute("HairCol_"..item.Id) or HairCatalog.DefaultColor;Draw(c,"style:"..item.Id..":"..col,function()SafeArt(Art.Hair,c,item.Id,col,rect,1)end)
   elseif item.Kind=="mask" then local mc=p:GetAttribute("MaskCw_"..item.Id);Draw(c,"mask:"..item.Id..":"..tostring(mc),function()SafeArt(Art.Mask,c,item.Id,rect,mc)end)
   elseif item.Kind=="maskcolor" then Draw(c,"maskcolor:"..item.ForMask..":"..item.Id,function()SafeArt(Art.Mask,c,item.ForMask,rect,item.Id)end)
   elseif item.Kind=="outfit" then
    -- every outfit card shows the colourway that outfit is kept in (not just the one you wear)
    local cwo=(item.Id==p:GetAttribute("Outfit")) and p:GetAttribute("OutfitColor") or p:GetAttribute("OutfitCw_"..item.Id)
    Draw(c,"outfit:"..item.Id..":"..tostring(cwo)..":"..tostring(p:GetAttribute("SkinTone"))..lookKey(p),function()SafeArt(Art.Outfit,c,item.Id,rect,cwo)end)
   elseif item.Kind=="colorway" then
    local wearing=item.ForOutfit or p:GetAttribute("Outfit") or Outfits.Default
    Draw(c,"colorway:"..wearing..":"..item.Id..":"..tostring(p:GetAttribute("SkinTone"))..lookKey(p),function()SafeArt(Art.Outfit,c,wearing,rect,item.Id)
     SafeArt(Art.Colorway,c,wearing,item.Id,{Position=UDim2.fromOffset(288,144),Size=UDim2.fromOffset(42,42)})end)
   elseif item.Kind=="color" then local look=colourStyle(cstyle);Draw(c,"color:"..item.Id..":"..look,function()SafeArt(Art.Hair,c,look,item.Id,rect,1)
    SafeArt(function()local sw=Art.Swatch(c,item.Id,{Position=UDim2.fromOffset(288,144),Size=UDim2.fromOffset(42,42)},true);sw.Name="SwatchChip"end)end)
   elseif item.Kind=="visor" then Draw(c,"visor:"..item.Id,function()SafeArt(Art.Visor,c,item.Id,rect,1)end)
    elseif item.Kind=="visorcolor" then Draw(c,"visorcolor:"..item.Id,function()SafeArt(Art.Visor,c,"Standard",rect,1,item.Id)end)
   elseif item.Kind=="trail" or item.Kind=="trailcolor" then Draw(c,"trail:"..item.Id,function()SafeArt(Art.Trail,c,item.Id,rect)end)
   elseif item.Kind=="gearcolor" then Draw(c,"gearcolor:"..item.ForGear..":"..item.Id,function()SafeArt(Art.Kit,c,gearItem(item.ForGear),rect,item.Id)end)
   else local gcw=gearCwOf(p,item.Id);Draw(c,"kit:"..item.Id..":"..tostring(gcw),function()SafeArt(Art.Kit,c,item,rect,gcw)end)end
   local eq=eqIt(item)
   local own=ownIt(item)
   Style.Card(c,item,eq,own,self.invSel==item,rankLook(item) and not own and RankLooks.LockText(item.Id) or nil)
   -- the colourway each outfit / head item / pet / hairstyle is kept in: swatch on the art, name on the price row
   local kn,kc=nil,nil
   if item.Kind=="outfit" or item.Kind=="mask" or item.Kind=="pet" or item.Kind=="style" or isGearItem(item) then kn,kc=keptColour(p,item) end
   colourChip(c,kn,kc,c.Size.X.Offset-18,188)
   rarityTag(c,item,Style.CardArt)
   local pr=c:FindFirstChild("PriceRow");if pr and not own and not eq and StoreUI.Locked(item) then pr.Text=StoreUI.Label(item) end
  elseif cat==0 then
   nameLabel.Text=previewNames[i+1]
   Draw(c,"num:"..i,function()SafeArt(Art.Number,c,({"4729","1380","2217","3095","9064","7224"})[i+1],{Position=UDim2.fromOffset(30,30),Size=UDim2.fromOffset(290,146)})end)
   Style.Card(c,nil,false,false,false,"COMING SOON");colourChip(c,nil);rarityTag(c,nil)
  else Draw(c,"none")
  end
 end
 -- primary action label
 local sel=self.invSel;local label="EQUIP"
 if sel then
  local eq=eqIt(sel)
  local own=ownIt(sel)
  label=eq and "EQUIPPED" or own and "EQUIP" or (rankLook(sel) and RankLooks.LockText(sel.Id)) or (StoreUI.Locked(sel) and ("BUY  "..StoreUI.Label(sel)) or ("BUY  ✹ "..sel.Price))
 end
 inv.SaveLoadout.Label.Text=label
 inv.SaveLoadout.Active=sel~=nil
 inv.SaveLoadout.BackgroundTransparency=sel and 0 or .45
end
function M:Refresh()
 local v=self.v;local g=self.g;local marks=tostring(v.player:GetAttribute("Coins")or 0)
 for _,n in ipairs({"Shop","Inventory","Quests"})do g[n].Currency.Balance.Text="MARKS: "..marks end
 self:Shop();self:Inventory()
 self:QuestView()
 local p=v.player
 local streak=p:GetAttribute("DailyStreak")or 0
 g.Quests.Daily.Claim.Active=p:GetAttribute("DailyClaimed")~=true
 Style.Claimable(g.Quests.Daily.Claim,g.Quests.Daily.Claim.Active)
 g.Quests.Streak.Count.Text=tostring(streak)
 g.Quests.Streak.ResetCaption.Text=p:GetAttribute("DailyClaimed")and "COME BACK TOMORROW / 00:00 UTC"or "CLAIM TODAY TO KEEP YOUR STREAK"
 for i=1,7 do
  local dot=g.Quests.Streak["Day"..i]
  dot.BackgroundColor3=i<=((streak-1)%7+1)and streak>0 and Color3.fromRGB(180,0,38)or Color3.fromRGB(20,15,18)
 end
 g.Quests.QuestTotal.Value.Text=string.format("%s MARKS",p:GetAttribute("QuestMarksEarned")or 0)
 local completed=p:GetAttribute("SeasonCompletedQuests")or 0
 for i,goal in ipairs({3,7,12,18,24})do
  local button=g.Quests.Season["Milestone"..i]
  local claimed=p:GetAttribute("SeasonMilestone"..i.."Claimed")==true
  button.Label.Text=claimed and "✓"or tostring(goal)
  button.BackgroundColor3=completed>=goal and Color3.fromRGB(140,0,30)or Color3.fromRGB(15,12,15)
  button.Active=completed>=goal and not claimed
 end
 g.Quests.Season.Status.Text=string.format("WEEKLY CONTRACT PROGRESS  %d / 24",completed)
 pcall(PanelStyle.QuestsUpdate,g.Quests,p,self.questTab or 0)

end
-- daily rows: a HARD tag on the hard contracts, and a REROLL button (5 Robux) on the first three while they're not
-- done (LobbyService "RerollQuest" -> the Robux prompt; the receipt swaps the contract)
local REROLL_GREEN=Color3.fromRGB(0,176,111)
function M:QuestExtras(seasonal)
 local p=self.v.player;local g=self.g
 for i=1,4 do
  local row=g.Quests:FindFirstChild("Quest"..(i-1));if not row then continue end
  local daily=(not seasonal and self.questTab==0) or seasonal
  local key=(seasonal and "SeasonQuest" or "Quest")..i
  local goal=p:GetAttribute(key.."Goal") or math.huge;local progress=p:GetAttribute(key.."Progress") or 0
  local claimed=p:GetAttribute(key.."Claimed")==true
  -- HARD tag: top right of the row, in the strip above REROLL / CLAIM
  local tag=row:FindFirstChild("HardTag")
  if not tag then
   tag=Instance.new("TextLabel");tag.Name="HardTag";tag.BackgroundColor3=Color3.fromRGB(120,10,30);tag.BorderSizePixel=0
   tag.Text="HARD";tag.TextColor3=Color3.fromRGB(255,225,225);tag.FontFace=row.Title.FontFace;tag.TextSize=14
   tag.Size=UDim2.fromOffset(52,18);tag.ZIndex=row.Title.ZIndex+1;tag:SetAttribute("NoTextBoost",true)
   local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,4);c.Parent=tag
   local s=Instance.new("UIStroke");s.Color=Color3.fromRGB(255,40,70);s.Thickness=1;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=tag
   tag.Parent=row
  end
  tag.Visible=daily and row.Visible and p:GetAttribute(key.."Hard")==true
  if tag.Visible then
   local cp=row.Claim.Position
   tag.Position=UDim2.fromOffset(cp.X.Offset+row.Claim.Size.X.Offset-52,math.max(2,cp.Y.Offset-21))
  end
  -- REROLL: room is made beside CLAIM by narrowing the bar and the progress count
  local rr=row:FindFirstChild("Reroll")
  local can=daily and row.Visible and i<=3 and not claimed and progress<goal
  if not rr then
   rr=Instance.new("TextButton");rr.Name="Reroll";rr.Text="";rr.AutoButtonColor=true;rr.BackgroundColor3=Color3.fromRGB(10,30,22)
   rr.BorderSizePixel=0;rr.ZIndex=row.Claim.ZIndex;rr:SetAttribute("NoTextBoost",true)
   local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,4);c.Parent=rr
   local s=Instance.new("UIStroke");s.Color=REROLL_GREEN;s.Thickness=1.5;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=rr
   local top=Instance.new("TextLabel");top.Name="Label";top.BackgroundTransparency=1;top.Text="REROLL";top.TextColor3=Color3.fromRGB(215,245,232)
   top.FontFace=row.Title.FontFace;top.TextSize=17;top.Size=UDim2.new(1,0,0,22);top.Position=UDim2.fromOffset(0,2);top.ZIndex=rr.ZIndex+1;top.Parent=rr
   local cost=Instance.new("Frame");cost.Name="Cost";cost.BackgroundTransparency=1;cost.Size=UDim2.new(1,0,0,24);cost.Position=UDim2.fromOffset(0,23);cost.ZIndex=rr.ZIndex+1;cost.Parent=rr
   local l=Instance.new("UIListLayout");l.FillDirection=Enum.FillDirection.Horizontal;l.HorizontalAlignment=Enum.HorizontalAlignment.Center
   l.VerticalAlignment=Enum.VerticalAlignment.Center;l.Padding=UDim.new(0,4);l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=cost
   local ic=Instance.new("ImageLabel");ic.Name="Robux";ic.LayoutOrder=1;ic.BackgroundTransparency=1;ic.Image="rbxasset://textures/ui/common/robux.png"
   ic.ImageColor3=REROLL_GREEN;ic.Size=UDim2.fromOffset(20,20);ic.ZIndex=rr.ZIndex+1;ic.Parent=cost
   local n=Instance.new("TextLabel");n.Name="Amount";n.LayoutOrder=2;n.BackgroundTransparency=1;n.Text=tostring(StoreCfg.Products.Reroll and StoreCfg.Products.Reroll.Robux or 5)
   n.TextColor3=REROLL_GREEN;n.FontFace=row.Title.FontFace;n.TextSize=23;n.AutomaticSize=Enum.AutomaticSize.X;n.Size=UDim2.fromOffset(0,24);n.ZIndex=rr.ZIndex+1;n.Parent=cost
   rr.Activated:Connect(function() self.v.remote:FireServer(self.questTab==2 and "RerollWeekly" or "RerollQuest",i) end)
   rr.Parent=row
  end
  rr.Visible=can==true
  -- (the price for this tab: a daily 2, a weekly 4)
  local prod=StoreCfg.Products[seasonal and "RerollWeekly" or "Reroll"]
  local amt=rr:FindFirstChild("Cost") and rr.Cost:FindFirstChild("Amount");if amt and prod then amt.Text=tostring(prod.Robux) end
  if daily and i<=3 then
   -- (layout every time: the panel style can put the row back)
   local cp=row.Claim.Position;local cs=row.Claim.Size
   rr.Size=UDim2.fromOffset(80,cs.Y.Offset);rr.Position=UDim2.fromOffset(cp.X.Offset-88,cp.Y.Offset)
   local right=cp.X.Offset-96
   local pw=row.Progress.Size.X.Offset
   if row.Progress.Position.X.Offset+pw>right then row.Progress.Position=UDim2.fromOffset(right-pw,row.Progress.Position.Y.Offset) end
   local tr=row.Progress.Position.X.Offset-12-row.Track.Position.X.Offset
   if row.Track.Size.X.Offset>tr then row.Track.Size=UDim2.fromOffset(tr,row.Track.Size.Y.Offset);row.Fill.Size=UDim2.fromOffset(tr*math.clamp(progress/math.max(goal,1),0,1),row.Fill.Size.Y.Offset) end
   for _,n in ipairs({"Title","Description"}) do local o=row:FindFirstChild(n);if o and o.Position.X.Offset+o.Size.X.Offset>right then o.Size=UDim2.fromOffset(right-o.Position.X.Offset,o.Size.Y.Offset) end end
  end
 end
end
-- REROLL ALL (8 Robux): today's daily contracts that aren't done, in one go (in the totals card, daily tab only)
function M:RerollAllButton(seasonal)
 local qt=self.g.Quests:FindFirstChild("QuestTotal");if not qt then return end
 local b=qt:FindFirstChild("RerollAll")
 if not b then
  b=Instance.new("TextButton");b.Name="RerollAll";b.Text="";b.AutoButtonColor=true;b.BackgroundColor3=Color3.fromRGB(10,30,22);b.BorderSizePixel=0
  b.Position=UDim2.fromOffset(296,56);b.Size=UDim2.fromOffset(200,46);b.ZIndex=(qt.ZIndex or 1)+3;b:SetAttribute("NoTextBoost",true)
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,4);c.Parent=b
  local s=Instance.new("UIStroke");s.Color=REROLL_GREEN;s.Thickness=1.5;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=b
  local inner=Instance.new("Frame");inner.BackgroundTransparency=1;inner.Size=UDim2.fromScale(1,1);inner.ZIndex=b.ZIndex+1;inner.Parent=b
  local l=Instance.new("UIListLayout");l.FillDirection=Enum.FillDirection.Horizontal;l.HorizontalAlignment=Enum.HorizontalAlignment.Center
  l.VerticalAlignment=Enum.VerticalAlignment.Center;l.Padding=UDim.new(0,7);l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=inner
  local function txt(t,size,col,order)
   local x=Instance.new("TextLabel");x.BackgroundTransparency=1;x.Text=t;x.TextSize=size;x.TextColor3=col;x.FontFace=qt.Title.FontFace
   x.AutomaticSize=Enum.AutomaticSize.X;x.Size=UDim2.fromOffset(0,24);x.LayoutOrder=order;x.ZIndex=b.ZIndex+2;x.Parent=inner;return x
  end
  txt("REROLL ALL",19,Color3.fromRGB(215,245,232),1)
  local ic=Instance.new("ImageLabel");ic.BackgroundTransparency=1;ic.Image="rbxasset://textures/ui/common/robux.png";ic.ImageColor3=REROLL_GREEN
  ic.Size=UDim2.fromOffset(20,20);ic.LayoutOrder=2;ic.ZIndex=b.ZIndex+2;ic.Parent=inner
  txt(tostring(StoreCfg.Products.RerollAll and StoreCfg.Products.RerollAll.Robux or 8),22,REROLL_GREEN,3)
  b.Activated:Connect(function() self.v.remote:FireServer("RerollAllQuests") end)
  b.Parent=qt
 end
 local p=self.v.player;local any=false
 for i=1,3 do
  local goal=p:GetAttribute("Quest"..i.."Goal") or math.huge
  if p:GetAttribute("Quest"..i.."Claimed")~=true and (p:GetAttribute("Quest"..i.."Progress") or 0)<goal then any=true end
 end
 b.Visible=not seasonal and self.questTab==0 and any
end
function M:QuestView()
 local p=self.v.player;local g=self.g;local seasonal=self.questTab==2
 local available=self.questTab==0 or seasonal
 Style.Tab(g.Quests.Tab0,self.questTab==0,"",false);Style.Tab(g.Quests.Tab1,self.questTab==2,"",false)
  g.Quests.Tab2.Visible=false;g.Quests.Tab3.Visible=false
 g.Quests.Unavailable.Visible=not available
 g.Quests.Unavailable.Text=self.questTab==1 and "WEEKLY CONTRACTS COMING SOON"or "EVENT CONTRACTS COMING SOON"
 g.Quests.QuestComingSoon.Visible=false
 local titles=seasonal and {"ELIMINATE 25 PLAYERS","COMPLETE 10 ROUNDS","WRITE 50 CORRECT NUMBERS"}or {"ELIMINATE 3 PLAYERS","SURVIVE 2 ROUNDS","WRITE 5 CORRECT NUMBERS","PLAY FOR 20 MINUTES"}
 for i=1,4 do
  local row=g.Quests["Quest"..(i-1)];row.Visible=available and (not seasonal or i<=3)
  if seasonal and i==4 then continue end
  local key=(seasonal and "SeasonQuest"or "Quest")..i
  local goal=p:GetAttribute(key.."Goal")or (seasonal and ({25,10,50})[i]or ({3,2,5,1200})[i])
  local progress=p:GetAttribute(key.."Progress")or 0
  local claimed=p:GetAttribute(key.."Claimed")==true
  -- daily quests rotate every day: the server sends each one's title (Quest<i>Title)
  local title=p:GetAttribute(key.."Title")
  row.Title.Text=title and string.upper(title) or titles[i]
  local timed=not seasonal and (p:GetAttribute(key.."Id")=="Play20" or (i==4 and p:GetAttribute(key.."Id")==nil))
  row.Progress.Text=timed and string.format("%d / %d",math.floor(progress/60),math.floor(goal/60))or progress.." / "..goal
  row.Fill.Size=UDim2.fromOffset(row.Track.Size.X.Offset*math.clamp(progress/goal,0,1),8)
  row.Claim.Label.Text=claimed and "CLAIMED"or progress>=goal and "CLAIM"or "+"..tostring(p:GetAttribute(key.."Reward")or 0).." MARKS"
  row.Claim.Active=progress>=goal and not claimed
  Style.Claimable(row.Claim,row.Claim.Active)
 end
 pcall(PanelStyle.QuestsUpdate,g.Quests,p,self.questTab or 0)
 pcall(self.QuestExtras,self,seasonal)
 pcall(self.RerollAllButton,self,seasonal)
end
function M:SetSlider(id,x)
 local entry=self.settingEntries[id];local slider=self.g.Settings.Options[id].Slider
 if slider.AbsoluteSize.X<=0 then return end
 local t=math.clamp((x-slider.AbsolutePosition.X)/slider.AbsoluteSize.X,0,1)
 local index=math.floor(t*(#entry.Values-1)+.5)+1
 self.v.values[id]=entry.Values[index];self.v.dirty=true;self.v:Apply()
end
function M:Settings()
 for _,entry in ipairs(self.v.rules.Items)do
  local row=self.g.Settings.Options[entry.Id];local value=self.v.values[entry.Id]
  if type(value)=="boolean"then
   row.Value.SwitchKnob.Position=UDim2.fromOffset(value and 79 or 7,7)
   row.Value.BackgroundColor3=value and Color3.fromRGB(113,0,27)or Color3.fromRGB(18,17,19)
   row.Value.Outline.Color=value and Color3.fromRGB(255,30,65)or Color3.fromRGB(104,96,100)
   row.Value.Label.Position=UDim2.fromOffset(value and 8 or 36,0)
  elseif row:FindFirstChild("Slider")then
   local index=table.find(entry.Values,value)or 1;local x=196*(index-1)/math.max(1,#entry.Values-1)
   row.Slider.Fill.Size=UDim2.fromOffset(x,5);row.Slider.Diamond.Position=UDim2.fromOffset(x-7,8)
   row.Value.Label.Text=(entry.Id=="Volume" or entry.Id=="MusicVolume")and tostring(math.floor(value*100)).."%"or (entry.Id=="Sensitivity" and tostring(value).."x") or tostring(value)
  end
 end
end

return M