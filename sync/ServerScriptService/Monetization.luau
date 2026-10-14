-- Robux purchases: marks packs, revives and Robux-only cosmetics (developer products), and the VIP gamepass.
-- Prices / IDs live in ReplicatedStorage.Numberfall.Store. Receipts are granted once each (ProfileService keeps the
-- PurchaseId) and only acknowledged to Roblox once the profile has saved, so a crash can't eat a purchase.
local Players=game:GetService("Players")
local MarketplaceService=game:GetService("MarketplaceService")
local RunService=game:GetService("RunService")
local M={}
local DataStoreService=game:GetService("DataStoreService")
local grants
local vipPassCheck -- set in Start: re-checks the pass / grant for one player
pcall(function()grants=DataStoreService:GetDataStore("MarkedVipGrants")end)
-- permanent VIP grants (AdminService GRANT VIP): userId -> true
function M.PermanentVip(userId)
	if not grants then return false end
	local ok,v=pcall(function()return grants:GetAsync(tostring(userId))end)
	return ok and v==true
end
function M.SetPermanentVip(userId,on)
	if not grants then return false,"DataStores aren't available (publish the place and enable Studio API access)" end
	local ok,err=pcall(function()
		if on then grants:SetAsync(tostring(userId),true) else grants:RemoveAsync(tostring(userId)) end
	end)
	if not ok then return false,tostring(err) end
	local p=Players:GetPlayerByUserId(userId)
	if p then
		p:SetAttribute("VIPPermanent",on or nil)
		if on then p:SetAttribute("VIP",true)
		elseif vipPassCheck then task.spawn(vipPassCheck,p) end
	end
	return true
end
function M.Start(profiles,match,shared)
	local Store=require(shared:WaitForChild("Store"))
	match.vip=Store.VIP
	local byId={}
	for key,p in pairs(Store.Products)do if p.Id and p.Id>0 then byId[p.Id]=key end end
	-- shop items sold for Robux (the green button beside the marks price): Numberfall.Store.ItemProducts
	local itemProducts={}
	for itemId,id in pairs(Store.ItemProducts or {})do
		if type(id)=="number" and id>0 then byId[id]="Item:"..itemId;itemProducts["Item:"..itemId]={Id=id,Kind="Item",Item=itemId,Name=itemId} end
	end
	local function notify(p,text,kind)shared.Notice:FireClient(p,"Store",{Text=text,Kind=kind or "good"})end

	------------------------------------------------------------------ VIP
	local vipId=Store.Passes.VIP.Id
	local function unlockVip(p)
		local d=profiles:Data(p);if not d then return end
		for _,item in ipairs(Store.VIP.Items)do profiles:Unlock(d,item)end
		profiles:Publish(p)
	end
	-- VIP items belong to the pass: without it (refunded, or a Studio test) they're taken back
	local function revokeVip(p)
		local d=profiles:Data(p);if not d then return end
		local changed=false
		for _,item in ipairs(Store.VIP.Items)do if profiles:Lock(d,item)then changed=true end end
		if changed then
			profiles:Publish(p)
			if p.Character and profiles.onHairChanged then profiles.onHairChanged(p,p.Character) end
		end
	end
	local function sync(p)
		if not p:GetAttribute("ProfileReady") then return end
		if p:GetAttribute("VIP")==true then unlockVip(p) else revokeVip(p) end
	end
	local function checkVip(p)
		local owns=false
		if vipId>0 then
			local ok,res=pcall(function()return MarketplaceService:UserOwnsGamePassAsync(p.UserId,vipId)end)
			owns=ok and res==true
		end
		-- permanent VIP given from the admin panel (kept in its own DataStore, so it works on every server and for
		-- players who aren't online when it's given)
		local granted=M.PermanentVip(p.UserId)
		p:SetAttribute("VIPPermanent",granted or nil)
		owns=owns or granted
		-- the game's owner and every admin (ChatRole OWNER / MOD, set by AdminService) always have VIP perks, in Studio
		-- tests too (their overhead badge stays the role one: StarterPlayerScripts.RoleTitles)
		if game.CreatorType==Enum.CreatorType.User and p.UserId==game.CreatorId then owns=true end
		if p:GetAttribute("ChatRole")=="OWNER" or p:GetAttribute("ChatRole")=="MOD" then owns=true end
		-- (Studio testing: set the player attribute VIP=true by hand to try the perks)
		p:SetAttribute("VIP",owns)
	end
	vipPassCheck=checkVip
	local function watch(p)
		p:GetAttributeChangedSignal("ProfileReady"):Connect(function()sync(p)end)
		p:GetAttributeChangedSignal("VIP"):Connect(function()sync(p)end)
		-- (the admin role can arrive after the first check: look again when it does)
		p:GetAttributeChangedSignal("ChatRole"):Connect(function()task.spawn(checkVip,p)end)
		task.spawn(function()checkVip(p);sync(p)end)
	end
	Players.PlayerAdded:Connect(watch)
	for _,p in ipairs(Players:GetPlayers())do watch(p)end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p,passId,bought)
		if bought and passId==vipId and vipId>0 then
			p:SetAttribute("VIP",true)
			notify(p,"VIP unlocked  /  +50% XP, +25% marks, Gilded set")
		end
	end)

	------------------------------------------------------------------ revive
	local used={} -- userId -> round the revive was used in
	Players.PlayerRemoving:Connect(function(p)used[p.UserId]=nil end)
	local function eligible(p)
		return match:IsPlaying() and match.participants[p.UserId]==true and (p:GetAttribute("Lives") or 0)<=0
			and used[p.UserId]~=match.roundId and #match:Standing()>=1
			and workspace:GetServerTimeNow()<=(p:GetAttribute("ReviveUntil") or 0)+20
	end
	-- offered right after losing the last life, while the round goes on
	match.onLastLife=function(p)
		if Store.Products.Revive.Id<=0 and not RunService:IsStudio() then return end
		if used[p.UserId]==match.roundId then return end
		task.defer(function()
			if match:IsPlaying() and #match:Standing()>=2 then
				p:SetAttribute("ReviveUntil",workspace:GetServerTimeNow()+Store.ReviveWindow)
			end
		end)
	end
	local function revive(p)
		used[p.UserId]=match.roundId
		p:SetAttribute("ReviveUntil",nil)
		p:SetAttribute("Lives",1);p:SetAttribute("OutAt",nil)
		match.outRank[p.UserId]=nil
		p:SetAttribute("InArena",true)
		task.spawn(function()pcall(function()p:LoadCharacterAsync()end)end)
		shared.Notice:FireAllClients("Revive",{UserId=p.UserId,Name=p.DisplayName})
	end
	M.Revive=revive;M.CanRevive=eligible

	------------------------------------------------------------------ receipts
	MarketplaceService.ProcessReceipt=function(receipt)
		local p=Players:GetPlayerByUserId(receipt.PlayerId)
		if not p then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local key=byId[receipt.ProductId]
		local product=key and (Store.Products[key] or itemProducts[key])
		if not product then
			warn("[Monetization] unknown developer product "..tostring(receipt.ProductId).." (add its Id in Numberfall.Store)")
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- wait for the profile (it can still be loading right after joining)
		local t0=os.clock()
		while not profiles:Data(p) and os.clock()-t0<15 and p.Parent do task.wait(.25) end
		local d=profiles:Data(p)
		if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
		-- a session-only profile (DataStores were down when they joined) can't keep anything: leave the receipt pending
		-- so Roblox retries it on their next visit, instead of granting marks that vanish when they leave
		-- (Studio test profiles are session-only by design, so they still grant there)
		if not d.Persistent and not RunService:IsStudio() then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local message,doRevive
		local result=profiles:GrantReceipt(p,receipt.PurchaseId,function(data)
			if product.Kind=="Marks" then
				data.Coins+=product.Amount;message="+"..product.Amount.." marks added"
			elseif product.Kind=="Item" then
				profiles:Unlock(data,product.Item);message=product.Name.." unlocked"
			elseif product.Kind=="Reroll" or product.Kind=="RerollAll" or product.Kind=="RerollWeekly" then
				-- (what they picked before the prompt; if it doesn't match this product, the product decides)
				local pick=profiles.rerollPick[p]
				local kind=product.Kind=="RerollAll" and "all" or product.Kind=="RerollWeekly" and "weekly" or "daily"
				if type(pick)~="table" or pick.kind~=kind then pick={kind=kind} end
				message=profiles:ApplyReroll(data,pick)
				profiles.rerollPick[p]=nil
			elseif product.Kind=="Case" then
				profiles:AddCases(data,1);message="+1 case  ·  open it in Shop > CASES"
			elseif product.Kind=="Revive" then
				if eligible(p) then doRevive=true;message="Revived  /  back in with 1 life"
				else data.Coins+=Store.ReviveRefundMarks;message="The round moved on  /  revive refunded as +"..Store.ReviveRefundMarks.." marks" end
			end
		end)
		if result==nil then return Enum.ProductPurchaseDecision.NotProcessedYet end
		-- acknowledge only once it's saved
		if d.Persistent then
			local saved=profiles:Save(p,false)
			if not saved then return Enum.ProductPurchaseDecision.NotProcessedYet end
		end
		if result=="granted" then
			if doRevive then revive(p) end
			if message then notify(p,message) end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end
return M
