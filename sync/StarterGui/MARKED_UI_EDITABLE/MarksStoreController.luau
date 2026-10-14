-- Shop > MARKS: Robux marks packs and the VIP pass, plus the Robux prompts for Robux-only cosmetics and the
-- REVIVE offer after you lose your last life. Product IDs / prices: ReplicatedStorage.Numberfall.Store.
-- The page itself (Store:BuildPage) is drawn on top of the old pack cards (kept hidden, their buttons unused): a
-- header with your balance, three tiered pack cards (the bigger packs glow brighter and carry MOST POPULAR / BEST
-- VALUE ribbons) and a gold VIP banner with its perks as chips.
local Players=game:GetService("Players")
local MarketplaceService=game:GetService("MarketplaceService")
local RunService=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS:WaitForChild("Numberfall"):WaitForChild("Store"))
local TopNotices=require(RS.Numberfall:WaitForChild("TopNotices"))
local GOLD=Color3.fromRGB(255,196,92)
local BONE=Color3.fromRGB(238,233,230)
local Store={};Store.__index=Store
local function commas(n)local s=tostring(math.floor(n));return (s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))end
-- live Robux prices from Roblox (falls back to the price written in the Store config)
local prices={}
local function fetchPrice(id,kind)
	if not id or id<=0 or prices[kind..id]~=nil then return end
	prices[kind..id]=false
	task.spawn(function()
		local ok,info=pcall(function()return MarketplaceService:GetProductInfo(id,kind=="pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)end)
		if ok and info and info.PriceInRobux then prices[kind..id]=info.PriceInRobux end
	end)
end
function Store.Robux(product,kind)
	if not product then return nil end
	local live=product.Id and prices[(kind or "product")..product.Id]
	return (live and live>0) and live or product.Robux
end
function Store.new(view)
	local self=setmetatable({view=view,gui=view.gui,shop=view.gui.Shop,active=false,player=view.player},Store)
	for _,p in pairs(Config.Products)do fetchPrice(p.Id,"product")end
	fetchPrice(Config.Passes.VIP.Id,"pass")
	self.shop.TabMarks.Activated:Connect(function()self:SetActive(true)end)
	local ms=self.shop.MarksStore
	ms.Title.Text="M A R K S   &   V I P"
	-- the three pack cards
	for i=1,3 do
		local card=ms["Pack"..i];local product=Config.Products["Marks"..i]
		card.Amount.Text=commas(product.Amount).." MARKS"
		card.Amount.FontFace=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold);card.Amount.TextSize=26
		local name=card:FindFirstChild("PackName") or card.Amount:Clone()
		name.Name="PackName";name.Text=string.upper(product.Name);name.TextSize=13;name.Position=card.Amount.Position+UDim2.fromOffset(0,44)
		name.TextColor3=Color3.fromRGB(176,150,152);name.FontFace=Font.new("rbxasset://fonts/families/Balthazar.json");name.Parent=card
		local tag=card:FindFirstChild("BonusTag") or Instance.new("TextLabel")
		tag.Name="BonusTag";tag.BackgroundTransparency=1;tag.Size=UDim2.new(1,-20,0,22);tag.Position=card.Amount.Position+UDim2.fromOffset(0,74)
		tag.FontFace=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold);tag.TextSize=13;tag.TextColor3=GOLD
		tag.Text=product.Tag or "";tag.Parent=card
		card.Amount.TextXAlignment=Enum.TextXAlignment.Center;name.TextXAlignment=Enum.TextXAlignment.Center;tag.TextXAlignment=Enum.TextXAlignment.Center
		card.MarksArtwork.Size=UDim2.fromOffset(58+i*14,58+i*14);card.MarksArtwork.AnchorPoint=Vector2.new(.5,0);card.MarksArtwork.Position=UDim2.new(.5,0,0,8-i*6)
		card.Buy.Activated:Connect(function()self:PromptProduct("Marks"..i)end)
	end
	-- VIP strip under the packs
	local strip=ms:FindFirstChild("VIPStrip")
	if not strip then
		local src=ms.Pack1
		strip=Instance.new("Frame");strip.Name="VIPStrip";strip.BackgroundColor3=src.BackgroundColor3;strip.BorderSizePixel=0
		strip.Position=UDim2.fromOffset(30,488);strip.Size=UDim2.fromOffset(1050,118);strip.Parent=ms
		local st=src.UIStroke:Clone();st.Color=GOLD;st.Transparency=.35;st.Parent=strip
		local t=src.Amount:Clone();t.Name="VIPTitle";t.Text="VIP";t.FontFace=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold);t.TextSize=34
		t.TextColor3=GOLD;t.TextXAlignment=Enum.TextXAlignment.Left;t.Position=UDim2.fromOffset(28,14);t.Size=UDim2.fromOffset(200,40);t.Parent=strip
		local d=src.Amount:Clone();d.Name="Perks";d.TextSize=15;d.TextWrapped=true;d.TextXAlignment=Enum.TextXAlignment.Left;d.TextYAlignment=Enum.TextYAlignment.Top
		d.Position=UDim2.fromOffset(28,58);d.Size=UDim2.fromOffset(640,50);d.TextColor3=BONE;d.Parent=strip
		d.Text=string.format("+%d%% XP and +%d%% marks from every match  /  Gilded gear, colourways, numerals, elimination FX, crow pet and dyes",math.floor((Config.VIP.XP-1)*100+.5),math.floor((Config.VIP.Marks-1)*100+.5))
		local b=src.Buy:Clone();b.Name="Buy";b.AnchorPoint=Vector2.new(1,.5);b.Position=UDim2.new(1,-24,.5,0);b.Parent=strip
	end
	strip.Buy.Activated:Connect(function()self:PromptVIP()end)
	-- server messages (purchases, revives)
	view.shared:WaitForChild("Notice").OnClientEvent:Connect(function(kind,data)
		if kind=="Store" then view:Toast(tostring(data and data.Text or ""),data and data.Kind or "good")
		elseif kind=="Revive" and data and data.UserId~=self.player.UserId then TopNotices.Push(string.upper(tostring(data.Name)).." IS BACK IN THE ROUND",{kind="info",eyebrow="REVIVED",duration=3})end
	end)
	self.player:GetAttributeChangedSignal("Coins"):Connect(function()self:Refresh()end)
	self.player:GetAttributeChangedSignal("VIP"):Connect(function()self:Refresh()end)
	self:BuildRevive()
	self:BuildPage()
	-- (a category tab closes the marks page without telling us: put back what it hid)
	self.shop.MarksStore:GetPropertyChangedSignal("Visible"):Connect(function()
		if not self.shop.MarksStore.Visible then
			self.active=false -- (hidden by a tab or by the CASES page: the marks page is closed either way)
			self:Chrome(false)
			pcall(function()self.view:Selected(self.shop.TabMarks,false)end)
		end
	end)
	self:Refresh()
	return self
end

------------------------------------------------------------------ the page
local INK=Color3.fromRGB(12,6,9);local TILE=Color3.fromRGB(22,11,15);local LINE=Color3.fromRGB(74,26,40)
local RED=Color3.fromRGB(255,23,74);local MUTED=Color3.fromRGB(170,150,154)
local GURU=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold)
local DISPLAY=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold)
local SERIF=Font.new("rbxasset://fonts/families/Balthazar.json")
local function mk(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function round(o,r)mk("UICorner",{CornerRadius=UDim.new(0,r or 8)},o)end
local function edge(o,c,t,tr)return mk("UIStroke",{Color=c,Thickness=t or 1,Transparency=tr or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o)end
local function label(parent,props)
	local base={BackgroundTransparency=1,TextColor3=BONE,FontFace=GURU,TextSize=14,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=12}
	for k,v in pairs(props)do base[k]=v end
	return mk("TextLabel",base,parent)
end
local function marksIcon(gui)
	local ids=gui:FindFirstChild("ArtworkAssetIds");local v=ids and ids:FindFirstChild("MarksIcon")
	return v and v.Value~="" and v.Value or "rbxassetid://121549460537528"
end
-- each tier: card tint, glow colour, ribbon
local TIERS={
	{tint=Color3.fromRGB(70,10,22),glow=Color3.fromRGB(200,40,70),ribbon=nil},
	{tint=Color3.fromRGB(110,10,32),glow=Color3.fromRGB(255,40,80),ribbon={"MOST POPULAR",Color3.fromRGB(200,16,52),BONE}},
	{tint=Color3.fromRGB(110,64,18),glow=Color3.fromRGB(255,190,90),ribbon={"BEST VALUE",GOLD,Color3.fromRGB(40,18,4)}},
}
function Store:BuildPage()
	local ms=self.shop.MarksStore
	local old=ms:FindFirstChild("MarksPage");if old then old:Destroy()end
	local page=mk("Frame",{Name="MarksPage",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=10},ms)
	self.page={frame=page,packs={}}
	-- header
	label(page,{Text="SHOP  ·  MARKS",TextSize=13,TextColor3=RED,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(30,20),Size=UDim2.fromOffset(300,16)})
	label(page,{Text="Get Marks",FontFace=DISPLAY,TextSize=40,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(28,36),Size=UDim2.fromOffset(500,44)})
	label(page,{Text="Spend them on hair, outfits, number styles, pets and elimination FX.",FontFace=SERIF,TextSize=16,TextColor3=MUTED,
		TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(30,80),Size=UDim2.fromOffset(620,20)})
	local bal=mk("Frame",{Name="Balance",BackgroundColor3=TILE,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-28,0,28),Size=UDim2.fromOffset(250,62),ZIndex=11},page)
	round(bal,10);edge(bal,Color3.fromRGB(120,90,40),1.2)
	mk("ImageLabel",{BackgroundTransparency=1,Image=marksIcon(self.gui),Position=UDim2.fromOffset(14,11),Size=UDim2.fromOffset(40,40),ZIndex=12},bal)
	label(bal,{Text="YOUR MARKS",TextSize=11,TextColor3=MUTED,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(64,10),Size=UDim2.fromOffset(170,14)})
	self.page.balance=label(bal,{Text="0",TextSize=28,TextColor3=GOLD,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(62,24),Size=UDim2.fromOffset(176,30)})
	-- the three packs
	local W,GAP,X0,Y0,H=330,19,28,118,312
	for i=1,3 do
		local product=Config.Products["Marks"..i];local tier=TIERS[i]
		local card=mk("Frame",{Name="Pack"..i,BackgroundColor3=INK,Position=UDim2.fromOffset(X0+(i-1)*(W+GAP),Y0),Size=UDim2.fromOffset(W,H),ZIndex=11},page)
		round(card,12)
		local st=edge(card,tier.glow,i==3 and 1.6 or 1.2,i==1 and 0.45 or 0.15)
		mk("UIGradient",{Rotation=90,Color=ColorSequence.new(tier.tint,INK),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.65,0.2),NumberSequenceKeypoint.new(1,0)})},card)
		local pop=mk("UIScale",{},card)
		-- glow disc behind the art
		local disc=mk("Frame",{BackgroundColor3=tier.glow,BackgroundTransparency=0.82,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0,92),
			Size=UDim2.fromOffset(110+i*14,110+i*14),ZIndex=11},card)
		round(disc,999)
		mk("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,0.2)})},disc)
		local art=mk("ImageLabel",{BackgroundTransparency=1,Image=marksIcon(self.gui),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0,92),
			Size=UDim2.fromOffset(64+i*16,64+i*16),ImageColor3=i==3 and Color3.fromRGB(255,224,160) or Color3.new(1,1,1),ZIndex=12},card)
		-- a stack of coins for the bigger packs: small marks beside the big one
		for k=1,i-1 do
			mk("ImageLabel",{BackgroundTransparency=1,Image=marksIcon(self.gui),AnchorPoint=Vector2.new(0.5,0.5),
				Position=UDim2.new(0.5,(k%2==1 and -1 or 1)*(52+i*6),0,112-k*6),Size=UDim2.fromOffset(34,34),ImageTransparency=0.15,ZIndex=12},card)
		end
		label(card,{Text=commas(product.Amount),TextSize=46,TextColor3=i==3 and GOLD or BONE,Position=UDim2.fromOffset(0,156),Size=UDim2.new(1,0,0,46)})
		label(card,{Text="M A R K S",TextSize=12,TextColor3=MUTED,Position=UDim2.fromOffset(0,200),Size=UDim2.new(1,0,0,14)})
		label(card,{Text=product.Name,FontFace=SERIF,TextSize=17,TextColor3=Color3.fromRGB(200,180,182),Position=UDim2.fromOffset(0,218),Size=UDim2.new(1,0,0,20)})
		if product.Tag then
			local chip=mk("Frame",{BackgroundColor3=Color3.fromRGB(60,40,10),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,8),Size=UDim2.fromOffset(110,24),ZIndex=13},card)
			round(chip,12);edge(chip,GOLD,1,0.3)
			label(chip,{Text=product.Tag,TextSize=11,TextColor3=GOLD,Size=UDim2.fromScale(1,1),ZIndex=14})
		end
		if tier.ribbon then
			local rb=mk("Frame",{BackgroundColor3=tier.ribbon[2],AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,6,0,-8),Size=UDim2.fromOffset(118,24),ZIndex=15},card)
			round(rb,6)
			label(rb,{Text=tier.ribbon[1],TextSize=11,TextColor3=tier.ribbon[3],Size=UDim2.fromScale(1,1),ZIndex=16})
		end
		local buy=mk("TextButton",{Name="Buy",Text="",AutoButtonColor=false,BackgroundColor3=Color3.fromRGB(170,12,40),AnchorPoint=Vector2.new(0.5,1),
			Position=UDim2.new(0.5,0,1,-16),Size=UDim2.new(1,-36,0,48),ZIndex=13},card)
		round(buy,8);local bst=edge(buy,Color3.fromRGB(255,90,115),1.2)
		local bl=label(buy,{Text="",TextSize=18,Size=UDim2.fromScale(1,1),ZIndex=14})
		buy.Activated:Connect(function()self:PromptProduct("Marks"..i)end)
		local hover=false
		local function hov(on)
			hover=on
			Tween:Create(pop,TweenInfo.new(0.16,Enum.EasingStyle.Quad),{Scale=on and 1.025 or 1}):Play()
			st.Transparency=on and 0 or (i==1 and 0.45 or 0.15)
		end
		card.MouseEnter:Connect(function()hov(true)end);card.MouseLeave:Connect(function()hov(false)end)
		self.page.packs[i]={card=card,buy=buy,label=bl,stroke=bst}
	end
	-- VIP
	local vip=mk("Frame",{Name="VIP",BackgroundColor3=INK,Position=UDim2.fromOffset(28,446),Size=UDim2.new(1,-56,0,150),ZIndex=11},page)
	round(vip,12);edge(vip,GOLD,1.4,0.15)
	mk("UIGradient",{Rotation=0,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(72,44,10)),ColorSequenceKeypoint.new(0.45,Color3.fromRGB(30,14,8)),ColorSequenceKeypoint.new(1,Color3.fromRGB(46,14,58))})},vip)
	local okArt,BadgeArt=pcall(function()return require(RS.Numberfall:WaitForChild("BadgeArt"))end)
	local crown=okArt and BadgeArt.crownImage and BadgeArt.crownImage("VIP")
	if crown then
		local c=mk("ImageLabel",{BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(82,64),Size=UDim2.fromOffset(112,70),ZIndex=12},vip)
		c.ImageContent=Content.fromObject(crown)
	end
	label(vip,{Text="VIP",FontFace=DISPLAY,TextSize=34,TextColor3=GOLD,Position=UDim2.fromOffset(32,94),Size=UDim2.fromOffset(100,36)})
	label(vip,{Text="THE MARKED ELITE",TextSize=12,TextColor3=Color3.fromRGB(230,200,140),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(170,20),Size=UDim2.fromOffset(400,16)})
	label(vip,{Text="Every match pays more, and you look the part.",FontFace=SERIF,TextSize=18,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(170,38),Size=UDim2.fromOffset(500,24)})
	local perks={string.format("+%d%% XP",math.floor((Config.VIP.XP-1)*100+.5)),string.format("+%d%% MARKS",math.floor((Config.VIP.Marks-1)*100+.5)),
		"GILDED COSMETICS","VIP NAME BADGE"}
	local px=170
	for _,p in ipairs(perks)do
		local w=#p*8+34
		local chip=mk("Frame",{BackgroundColor3=Color3.fromRGB(40,24,8),Position=UDim2.fromOffset(px,80),Size=UDim2.fromOffset(w,32),ZIndex=12},vip)
		round(chip,16);edge(chip,Color3.fromRGB(160,120,50),1,0.2)
		label(chip,{Text=p,TextSize=12,TextColor3=Color3.fromRGB(245,220,160),Size=UDim2.fromScale(1,1),ZIndex=13})
		px+=w+10
	end
	local vb=mk("TextButton",{Name="Buy",Text="",AutoButtonColor=false,BackgroundColor3=Color3.fromRGB(214,160,60),AnchorPoint=Vector2.new(1,0.5),
		Position=UDim2.new(1,-26,0.5,0),Size=UDim2.fromOffset(230,56),ZIndex=12},vip)
	round(vb,8);local vst=edge(vb,Color3.fromRGB(255,232,170),1.2)
	local vl=label(vb,{Text="",TextSize=18,TextColor3=Color3.fromRGB(40,18,4),Size=UDim2.fromScale(1,1),ZIndex=13})
	vb.Activated:Connect(function()self:PromptVIP()end)
	self.page.vip={buy=vb,label=vl,stroke=vst}
end
-- the shop's category chrome (status line, STYLES / COLOURS toggles) is hidden while the marks page is up
function Store:Chrome(hide)
	local sh=self.shop
	self.hidden=self.hidden or {}
	for _,n in ipairs({"ShopStatus","ShopToggleStyles","ShopToggleColours"})do
		local o=sh:FindFirstChild(n)
		if o then
			if hide then
				if o.Visible then self.hidden[n]=true;o.Visible=false end
			elseif self.hidden[n] then
				self.hidden[n]=nil;o.Visible=true
			end
		end
	end
	-- no category tab lit while you're on the marks page (they're restyled when you pick one again)
	if hide then
		local ok,LS=pcall(function()return require(script.Parent:WaitForChild("LoadoutStyle",2))end)
		for i=0,9 do
			local t=sh:FindFirstChild("Tab"..i)
			if t then
				local sub=t:FindFirstChild("Sub")
				if ok and LS and LS.Tab then pcall(LS.Tab,t,false,sub and sub.Text or nil,false)
				else local bar=t:FindFirstChild("Bar");if bar then bar.Visible=false end end
			end
		end
	end
end
function Store:SetActive(active)
	self.active=active
	self.shop.MarksStore.Visible=active
	for i=0,5 do self.shop["Product"..i].Visible=not active end
	self.shop.Previous.Visible=not active;self.shop.Next.Visible=not active
	for i=0,4 do self.shop["Page"..i].Visible=false end
	self.view:Selected(self.shop.TabMarks,active)
	if not active then self.view:Selected(self.shop.Tab0,true) end
	if active then self:Refresh()else self.view:RefreshShop()end
	if self.view.redesign then self.view.redesign:Shop()end
	self:Chrome(active)
end
local function setButton(b,text,enabled)
	b.Label.Text=text;b.Active=enabled;b.Selectable=enabled;b.AutoButtonColor=false
	b.BackgroundTransparency=enabled and 0 or .4
end
function Store:Refresh()
	local ms=self.shop.MarksStore
	ms.Balance.Text="YOUR MARKS: "..commas(self.player:GetAttribute("Coins")or 0)
	if self.active then self.shop.ShopStatus.Text="MARKS PACKS  /  VIP" end
	for i=1,3 do
		local p=Config.Products["Marks"..i]
		setButton(ms["Pack"..i].Buy,p.Id>0 and ("R$ "..Store.Robux(p)) or "COMING SOON",p.Id>0)
	end
	local strip=ms:FindFirstChild("VIPStrip")
	if strip then
		local vip=self.player:GetAttribute("VIP")==true
		setButton(strip.Buy,vip and "VIP ACTIVE" or Config.Passes.VIP.Id>0 and ("GET VIP  R$ "..Store.Robux(Config.Passes.VIP,"pass")) or "COMING SOON",not vip and Config.Passes.VIP.Id>0)
	end
	-- the redesigned page (the old cards stay hidden underneath)
	for _,n in ipairs({"Title","Balance","Pack1","Pack2","Pack3","VIPStrip"})do local o=ms:FindFirstChild(n);if o then o.Visible=false end end
	local pg=self.page
	if pg then
		pg.balance.Text=commas(self.player:GetAttribute("Coins")or 0)
		for i=1,3 do
			local p=Config.Products["Marks"..i];local ui=pg.packs[i]
			local on=p.Id>0
			ui.label.Text=on and ("\u{E002} "..Store.Robux(p)) or "COMING SOON"
			if on then ui.label.Text="R$ "..Store.Robux(p) end
			ui.buy.BackgroundColor3=on and Color3.fromRGB(170,12,40) or Color3.fromRGB(34,16,22)
			ui.stroke.Color=on and Color3.fromRGB(255,90,115) or LINE
			ui.label.TextColor3=on and BONE or MUTED
			ui.buy.Active=on;ui.buy.AutoButtonColor=false
		end
		local vip=self.player:GetAttribute("VIP")==true
		local on=Config.Passes.VIP.Id>0
		local v=pg.vip
		v.label.Text=vip and "VIP ACTIVE  ✓" or on and ("GET VIP  ·  R$ "..Store.Robux(Config.Passes.VIP,"pass")) or "COMING SOON"
		v.buy.BackgroundColor3=vip and Color3.fromRGB(40,70,40) or on and Color3.fromRGB(214,160,60) or Color3.fromRGB(46,30,14)
		v.label.TextColor3=vip and Color3.fromRGB(170,240,170) or on and Color3.fromRGB(40,18,4) or Color3.fromRGB(200,170,120)
		v.stroke.Color=vip and Color3.fromRGB(110,210,140) or Color3.fromRGB(255,232,170)
	end
end
function Store:PromptProduct(key)
	local p=Config.Products[key]
	if not p or p.Id<=0 then self.view:Toast("Coming soon");return end
	MarketplaceService:PromptProductPurchase(self.player,p.Id)
end
function Store:PromptVIP()
	if self.player:GetAttribute("VIP")==true then self.view:Toast("VIP is already active.");return end
	local id=Config.Passes.VIP.Id
	if id<=0 then self.view:Toast("Coming soon");return end
	MarketplaceService:PromptGamePassPurchase(self.player,id)
end
-- Robux-only / VIP-only cosmetics (shop + loadout use these)
function Store.Locked(item)return item and (item.Premium~=nil or item.Vip==true) end
function Store.Label(item)
	if item.Vip then return "VIP ONLY" end
	local p=Config.Products[item.Premium]
	return p and p.Id>0 and ("R$ "..Store.Robux(p)) or "R$ SOON"
end
function Store:PromptItem(item)
	if item.Vip then self:PromptVIP() else self:PromptProduct(item.Premium) end
end
------------------------------------------------------------------ revive offer
function Store:BuildRevive()
	local gui=Instance.new("ScreenGui");gui.Name="ReviveOffer";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=26;gui.Enabled=false
	gui.Parent=self.player:WaitForChild("PlayerGui")
	local scale=Instance.new("UIScale");scale.Parent=gui
	local function fit()local v=gui.AbsoluteSize;scale.Scale=math.clamp(math.min(v.X/1600,v.Y/860),.6,1.15)end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit);fit()
	local card=Instance.new("Frame");card.Name="Card";card.AnchorPoint=Vector2.new(.5,1);card.Size=UDim2.fromOffset(420,150)
	card.BackgroundColor3=Color3.fromRGB(10,4,6);card.BackgroundTransparency=.06;card.BorderSizePixel=0;card.Parent=gui
	local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=card
	local s=Instance.new("UIStroke");s.Color=Color3.fromRGB(255,24,58);s.Thickness=1.5;s.Transparency=.15;s.Parent=card
	local function label(text,font,size,color,pos,sz)
		local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text;l.FontFace=font;l.TextSize=size;l.TextColor3=color
		l.Position=pos;l.Size=sz;l.Parent=card;return l
	end
	label("O U T   O F   L I V E S",Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold),14,Color3.fromRGB(255,150,160),UDim2.fromOffset(0,12),UDim2.new(1,0,0,18))
	label("REVIVE",Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold),40,BONE,UDim2.fromOffset(0,30),UDim2.new(1,0,0,44))
	label("Back into this round with one life",Font.new("rbxasset://fonts/families/Balthazar.json"),15,Color3.fromRGB(176,150,152),UDim2.fromOffset(0,72),UDim2.new(1,0,0,20))
	local b=Instance.new("TextButton");b.Name="Buy";b.AnchorPoint=Vector2.new(.5,0);b.Position=UDim2.new(.5,0,0,100);b.Size=UDim2.fromOffset(220,36)
	b.BackgroundColor3=Color3.fromRGB(170,10,40);b.AutoButtonColor=true;b.TextColor3=BONE;b.FontFace=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold);b.TextSize=17;b.Modal=true;b.Parent=card
	local bc=Instance.new("UICorner");bc.CornerRadius=UDim.new(0,4);bc.Parent=b
	local x=Instance.new("TextButton");x.Name="Close";x.BackgroundTransparency=1;x.Text="✕";x.TextColor3=Color3.fromRGB(176,150,152);x.TextSize=18
	x.AnchorPoint=Vector2.new(1,0);x.Position=UDim2.new(1,-8,0,6);x.Size=UDim2.fromOffset(26,26);x.Parent=card
	local bar=Instance.new("Frame");bar.Name="Timer";bar.BorderSizePixel=0;bar.BackgroundColor3=Color3.fromRGB(255,24,58);bar.AnchorPoint=Vector2.new(0,1)
	bar.Position=UDim2.fromScale(0,1);bar.Size=UDim2.new(1,0,0,3);bar.Parent=card
	self.revive={gui=gui,card=card,bar=bar,button=b,scale=scale}
	b.Activated:Connect(function()self:PromptProduct("Revive")end)
	x.Activated:Connect(function()self.reviveDismissed=self.player:GetAttribute("ReviveUntil")end)
	RunService.RenderStepped:Connect(function()self:StepRevive()end)
end
function Store:StepRevive()
	local r=self.revive;if not r then return end
	local untilT=self.player:GetAttribute("ReviveUntil")
	local now=workspace:GetServerTimeNow()
	local show=untilT~=nil and now<untilT and self.reviveDismissed~=untilT and (self.player:GetAttribute("Lives") or 0)<=0
		and self.view.shared:GetAttribute("Phase")=="Playing"
	r.gui.Enabled=show
	if not show then return end
	local v=r.gui.AbsoluteSize/r.scale.Scale
	r.card.Position=UDim2.fromOffset(v.X/2,v.Y-110)
	r.bar.Size=UDim2.new(math.clamp((untilT-now)/Config.ReviveWindow,0,1),0,0,3)
	local p=Config.Products.Revive
	r.button.Text=p.Id>0 and ("REVIVE  R$ "..Store.Robux(p)) or "COMING SOON"
end
return Store
