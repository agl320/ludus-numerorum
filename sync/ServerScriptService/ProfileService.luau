-- Unpublished/offline Studio sessions must still be able to deploy and use the shop.
local available,Store=pcall(function()return game:GetService("DataStoreService"):GetDataStore("NumberfallProfiles_v1")end)
if not available then Store=nil end
local Http=game:GetService("HttpService")
local HairCatalog=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("HairCatalog"))
local HairStyles,HairColors,HairMasks={},{},{}
for _,s in ipairs(HairCatalog.Styles)do HairStyles[s.Id]=s end
for _,c in ipairs(HairCatalog.Colors)do HairColors[c.Id]=c end
for _,m in ipairs(HairCatalog.Masks)do HairMasks[m.Id]=m end
-- clothing (Numberfall.Outfits) is bought / equipped through the same hair actions (kind "outfit")
local Outfits=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("Outfits"))
local HairOutfits={}
for _,o in ipairs(Outfits.List)do HairOutfits[o.Id]=o end
-- NUMBER STYLES (how the visor draws your digits): owned once (OwnedHair[id]), equipped as d.NumberStyle
local NumberStyles=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("NumberStyles"))
local NumStyles=NumberStyles.ById
-- BODY TYPES, ELIMINATION EFFECTS and PETS (Numberfall.Extras): owned once (OwnedHair[id]), equipped as d.BodyType /
-- d.KillEffect / d.Pet (Extras.Field), published as the attributes of the same names
local Extras=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("Extras"))
-- pet colourways: bought PER PET (OwnedHair["<pet>|<colourway>"]); Original is free; Robux / VIP ones work on every pet
local PetCw=Extras.PetColorwayById
local function ownsPetColor(d,cwId,petId)
    local c=PetCw[cwId];if not c then return false end
    if c.Price==0 then return true end
    if c.Premium or c.Vip then return d.OwnedHair[cwId]==true end
    return petId~=nil and d.OwnedHair[Extras.PetColorKey(petId,cwId)]==true
end
local function realPet(id)local x=Extras.ById[id or ""];return x and x.Kind=="pet" and id~=Extras.DefaultPet end
-- mask colourways: bought PER MASK (OwnedHair["<mask>|<colourway>"]); Original is free; VIP ones work on every mask
local MaskCw=Extras.MaskColorwayById
local function ownsMaskColor(d,cwId,maskId)
    local c=MaskCw[cwId];if not c then return false end
    if c.Vip or c.Premium then return d.OwnedHair[cwId]==true end
    if c.Price==0 then return true end
    return maskId~=nil and d.OwnedHair[Extras.MaskColorKey(maskId,cwId)]==true
end
local function realMask(id)return HairMasks[id or ""]~=nil and id~=HairCatalog.DefaultMask end
-- gear colourways (Numberfall.GearColorways): bought PER GEAR item (OwnedHair["<gear>|<colourway>"]); Original is free;
-- the VIP one is owned once and works on every gear item. Equipped per gear as d.GearColors[gear].
local GearColorways=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("GearColorways"))
local GearCw=GearColorways.ById
local function ownsGearColor(d,cwId,gearId)
    local c=GearCw[cwId];if not c then return false end
    if c.Price==0 and not c.Vip and not c.Premium then return true end
    if c.Premium or c.Vip then return d.OwnedHair[cwId]==true end
    return gearId~=nil and d.OwnedHair[GearColorways.Key(gearId,cwId)]==true
end
-- standard visor colourways (Numberfall.VisorColorways): owned once (OwnedHair[id]); Original is free; CaseOnly ones
-- only drop from cases. Equipped as d.VisorColor.
local VisorColorways=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("VisorColorways"))
local VisorCw=VisorColorways.ById
local function ownsVisorColor(d,id)
    local c=VisorCw[id or ""];if not c then return false end
    if c.Price==0 and not c.CaseOnly then return true end
    return d.OwnedHair[id]==true
end
-- TRAIL COLOURS (Numberfall.TrailColors): afterimage looks owned once (OwnedHair[id]); CaseOnly ones only drop from
-- cases. Worn like the rank trails: d.TrailStyle (Loadout > TRAIL, Numberfall.RankLooks).
local TrailColors=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("TrailColors"))
local TrailCw=TrailColors.ById
local function ownsTrailColor(d,id)
    return TrailCw[id or ""]~=nil and d.OwnedHair[id]==true
end
-- CASES (Numberfall.Cases): d.Cases unopened, bought with marks / Robux or earned on level up
local Cases=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("Cases"))
local caseRng=Random.new()
-- the notebook finishes retired when gear got colourways: their marks go back to whoever bought them
local RETIRED_GEAR={Graphite=450,Cobalt=900,Cherry=900,Moss=1350,Mint=1350,Amber=1800,Violet=1800,Obsidian=0,BloodMoon=0,Gilded=0}
local function extraEquipped(d,kind)
    local field=Extras.Field[kind];local v=d[field];local it=Extras.ById[v or ""]
    return it and it.Kind==kind and v or Extras.Default[kind]
end
-- clothing colourways: bought PER OUTFIT, OwnedHair["<outfit>|<colourway>"] (like hair colours); Original is free
local Colorways=Outfits.ColorwayById
local function ownsColorway(d,cwId,outfitId)
    local c=Colorways[cwId];if not c then return false end
    if c.Price==0 then return true end
    -- Robux / VIP colourways are owned once and work on every outfit
    if c.Premium or c.Vip then return d.OwnedHair[cwId]==true end
    outfitId=outfitId or d.Outfit
    return outfitId~=nil and d.OwnedHair[Outfits.ColorwayKey(outfitId,cwId)]==true
end
-- Hair colours are bought PER HAIRSTYLE: OwnedHair["<style>|<colour>"]. Free colours (price 0) work on every style.
local function colourKey(styleId,id) return tostring(styleId).."|"..id end
local function ownsHair(d,id,styleId)
    local c=HairColors[id]
    if c then
        if c.Price==0 then return true end
        -- Robux hair colours are owned once and work on every hairstyle
        if c.Premium or c.Vip then return d.OwnedHair[id]==true end
        styleId=styleId or d.HairStyle
        return styleId~=nil and styleId~="None" and d.OwnedHair[colourKey(styleId,id)]==true
    end
    local s=HairStyles[id] or HairMasks[id] or HairOutfits[id] or NumStyles[id] or Extras.ById[id];return s and (s.Price==0 or d.OwnedHair[id]==true)
end
local DailyRewards=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("DailyRewards"))
local Profiles={}
Profiles.__index=Profiles
-- Levels: each level needs more XP than the last, and the steps grow (made harder: Lv.2 at 500 XP, Lv.3 at 1,179,
-- Lv.5 at 3,106, Lv.10 at 11,616, Lv.20 at 47,861 -- about twice the old curve). Level comes from total XP,
-- so the new curve applies to everyone's existing XP too.
local function needFor(level)
    local n=level-1
    return math.floor(500+n*175+n*n*4)
end
local function levelFor(xp)
    local level,need=1,needFor(1)
    while xp>=need and level<500 do xp-=need;level+=1;need=needFor(level) end
    return level,xp,need
end
Profiles.LevelFor=levelFor
-- Round rewards on top of the per-elimination reward
local ROUND_XP,WIN_XP,WIN_MARKS=40,150,50
-- VIP gamepass: more XP and marks from matches (Numberfall.Store.VIP; the VIP attribute is set by Monetization)
local StoreConfig=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("Store"))
-- Global events (ServerScriptService.GlobalEvents, started from the admin panel) multiply them on top, e.g. 2x MARKS
local NF=game:GetService("ReplicatedStorage").Numberfall
local function eventMult()
    if (NF:GetAttribute("EventEndsAt") or 0)>workspace:GetServerTimeNow() then
        return NF:GetAttribute("EventXP") or 1,NF:GetAttribute("EventMarks") or 1
    end
    return 1,1
end
Profiles.EventMult=eventMult
local function boost(p,xp,marks)
    local vx,vm=1,1
    if p:GetAttribute("VIP")==true then vx,vm=StoreConfig.VIP.XP,StoreConfig.VIP.Marks end
    local ex,em=eventMult()
    return math.floor(xp*vx*ex+.5),math.floor(marks*vm*em+.5)
end
Profiles.Boost=boost
-- Robux-only and VIP-only items can't be bought with marks
local function lockedItem(item)return item and (item.Premium~=nil or item.Vip==true) end
-- lifetime stats (published as Stat<Key>; the VIEW STATS card shows them): BestRound = most eliminations in one round,
-- WinStreak / BestStreak = rounds won in a row, Top3 = podium finishes, Clean = rounds without losing a life,
-- PlaySeconds = time in the game, BotKills = bots marked (kept apart: they don't count as eliminations)
local STAT_KEYS={"Kills","Deaths","Wins","Rounds","Numbers","BestRound","WinStreak","BestStreak","Top3","Clean","PlaySeconds","BotKills"}
local function cleanStats(s)
    s=type(s)=="table" and s or {}
    for _,k in ipairs(STAT_KEYS) do s[k]=math.max(0,math.floor(tonumber(s[k]) or 0)) end
    return s
end
function Profiles.new(players,catalog,settingsRules,rewards)
    local self=setmetatable({players=players,settingsRules=settingsRules,rewards=rewards or {Coins=25,XP=75},catalog={},data={},saving={},token=Http:GenerateGUID(false)},Profiles)
    for _,item in ipairs(catalog) do self.catalog[item.Id]=item end
    local function add(p) self:WatchSlides(p);task.spawn(function() self:Load(p) end) end
    players.PlayerAdded:Connect(add)
    players.PlayerRemoving:Connect(function(p) self:Save(p,true);self.data[p]=nil end)
    for _,p in ipairs(players:GetPlayers()) do add(p) end
    task.spawn(function() while task.wait(60) do for p in pairs(self.data) do task.spawn(function() self:Save(p,false) end) end end end)
    task.spawn(function()
        while task.wait(15)do
            for player,d in pairs(self.data)do
                local now=os.clock();local elapsed=math.max(0,math.floor(now-(d.PlayClock or now)))
                d.PlayClock=now
                if d.Stats then d.Stats.PlaySeconds=(d.Stats.PlaySeconds or 0)+elapsed end
                self:Track(player,"time",elapsed)
                self:Publish(player)
            end
        end
    end)
    game:BindToClose(function()
        local remaining=0
        for p in pairs(self.data) do remaining=remaining+1;task.spawn(function()self:Save(p,true);remaining=remaining-1 end)end
        local untilTime=os.clock()+25
        while remaining>0 and os.clock()<untilTime do task.wait(.1)end
    end)
    return self
end
-- DAILY QUESTS: every day (UTC) the server picks 3 quests from this pool, one per group, the same for everyone.
-- Slot 4 is always "play for 20 minutes". Event names are fired through Profiles:Track (see Reward, RoundComplete,
-- WatchSlides). Best=true means progress is the best single-round value, not a running total.
local QUESTS={
    -- eliminations
    Kill3={Group=1,Title="Eliminate 3 players",Event="kill",Goal=3,Reward=50},
    Kill6={Group=1,Title="Eliminate 6 players",Event="kill",Goal=6,Reward=90},
    Kill10={Group=1,Title="Eliminate 10 players",Event="kill",Goal=10,Reward=140},
    Write5={Group=1,Title="Write 5 correct numbers",Event="kill",Goal=5,Reward=70},
    -- rounds
    Rounds2={Group=2,Title="Finish 2 rounds",Event="round",Goal=2,Reward=30},
    Rounds4={Group=2,Title="Finish 4 rounds",Event="round",Goal=4,Reward=60},
    Win1={Group=2,Title="Win a round",Event="win",Goal=1,Reward=120},
    Top3={Group=2,Title="Place top 3 in 2 rounds",Event="top3",Goal=2,Reward=70},
    Clean1={Group=2,Title="Finish a round without losing a life",Event="clean",Goal=1,Reward=100},
    -- skill / style
    Multi3={Group=3,Title="Eliminate 3 players in one round",Event="roundKills",Best=true,Goal=3,Reward=80},
    Multi5={Group=3,Title="Eliminate 5 players in one round",Event="roundKills",Best=true,Goal=5,Reward=150},
    Double1={Group=3,Title="Get a double elimination",Event="double",Goal=1,Reward=90},
    Slide30={Group=3,Title="Slide 30 times in the city",Event="slide",Goal=30,Reward=40},
    Marks300={Group=3,Title="Earn 300 marks in matches",Event="marks",Goal=300,Reward=60},
    -- HARD contracts (Hard=true: tagged HARD in the menu, bigger rewards); they rotate in with the others and can
    -- also come up from a reroll
    Kill15={Group=1,Hard=true,Title="Eliminate 15 players",Event="kill",Goal=15,Reward=220},
    Write20={Group=1,Hard=true,Title="Write 20 correct numbers",Event="kill",Goal=20,Reward=280},
    Win3={Group=2,Hard=true,Title="Win 3 rounds",Event="win",Goal=3,Reward=320},
    Clean3={Group=2,Hard=true,Title="Finish 3 rounds without losing a life",Event="clean",Goal=3,Reward=260},
    Top5={Group=2,Hard=true,Title="Place top 3 in 5 rounds",Event="top3",Goal=5,Reward=200},
    Multi8={Group=3,Hard=true,Title="Eliminate 8 players in one round",Event="roundKills",Best=true,Goal=8,Reward=300},
    Double3={Group=3,Hard=true,Title="Get 3 double eliminations",Event="double",Goal=3,Reward=250},
    Marks1000={Group=3,Hard=true,Title="Earn 1000 marks in matches",Event="marks",Goal=1000,Reward=200},
    -- slot 4
    Play20={Group=4,Title="Play for 20 minutes",Event="time",Goal=1200,Reward=100},
}
local LEGACY_IDS={"Kill3","Rounds2","Write5","Play20"} -- what the fixed quests were before the rotation
local DOUBLE_WINDOW=10 -- seconds between two eliminations for a double
-- each group cycles through all of its quests in a shuffled order before any repeats (never the same two days running)
local GROUPS={{},{},{}}
for id,q in pairs(QUESTS) do if q.Group<=3 then table.insert(GROUPS[q.Group],id) end end
for _,g in ipairs(GROUPS) do table.sort(g) end
local function cycleOrder(g,gi,cycle)
    local order=table.clone(g)
    local rng=Random.new(cycle*7919+gi*1013+17)
    for i=#order,2,-1 do local j=rng:NextInteger(1,i);order[i],order[j]=order[j],order[i] end
    return order
end
local function questsFor(day)
    local ids={}
    for gi,g in ipairs(GROUPS) do
        local cycle=math.floor(day/#g)
        local order=cycleOrder(g,gi,cycle)
        local prev=cycleOrder(g,gi,cycle-1)
        if #order>1 and order[1]==prev[#prev] then order[1],order[2]=order[2],order[1] end
        ids[gi]=order[day%#g+1]
    end
    ids[4]="Play20"
    return ids
end
local function questAt(daily,i) return QUESTS[daily.Ids and daily.Ids[i]] or QUESTS[LEGACY_IDS[i]] end
-- REROLL (5 Robux: Numberfall.Store.Products.Reroll): swaps one of today's first three contracts for another from the
-- same group (never one already on today's list), with fresh progress. Not for a claimed one or the 20 minutes.
-- d = the profile data; index 1..3. Returns true / false and the message to show.
Profiles.rerollPick={} -- player -> what they asked to reroll before the Robux prompt: {kind="daily"|"all"|"weekly", index=}
function Profiles:CanReroll(d,index)
    local daily=self:EnsureDaily(d)
    if type(index)~="number" or index%1~=0 or index<1 or index>3 then return false,"That contract can't be rerolled" end
    if daily.Claimed[index] then return false,"That contract is already claimed" end
    if daily.Progress[index]>=questAt(daily,index).Goal then return false,"That contract is done: claim it instead" end
    return true
end
function Profiles:RerollQuestData(d,index)
    local daily=self:EnsureDaily(d)
    local ok=self:CanReroll(d,index)
    if not ok then
        -- (paid but no longer valid, e.g. claimed in the meantime: the first contract that can still be rerolled)
        index=nil
        for i=1,3 do if self:CanReroll(d,i) then index=i;break end end
        if not index then d.Coins+=50;return false,"No contract left to reroll  /  +50 marks instead" end
    end
    local group=questAt(daily,index).Group or index
    local taken={}
    for i=1,4 do taken[daily.Ids[i]]=true end
    local pool={}
    for id,q in pairs(QUESTS) do if q.Group==group and not taken[id] then table.insert(pool,id) end end
    if #pool==0 then d.Coins+=50;return false,"No other contracts to roll  /  +50 marks instead" end
    table.sort(pool)
    local id=pool[Random.new():NextInteger(1,#pool)]
    daily.Ids[index]=id;daily.Progress[index]=0;daily.Claimed[index]=false
    daily.Rerolls=(tonumber(daily.Rerolls) or 0)+1
    return true,"New contract: "..QUESTS[id].Title..(QUESTS[id].Hard and "  (HARD)" or "")
end
-- REROLL ALL (8 Robux): every daily contract that can still be rerolled, at once
function Profiles:CanRerollAll(d)
    for i=1,3 do if self:CanReroll(d,i) then return true end end
    return false,"Nothing to reroll: today's contracts are done"
end
function Profiles:RerollAllData(d)
    local n=0
    for i=1,3 do if self:CanReroll(d,i) then self:RerollQuestData(d,i);n+=1 end end
    if n==0 then d.Coins+=150;return false,"Nothing left to reroll  /  +150 marks instead" end
    return true,"Rerolled "..n.." daily contract"..(n==1 and "" or "s")
end
-- WEEKLY reroll (4 Robux): one weekly contract for another from the same slot
function Profiles:CanRerollWeekly(d,index)
    local s=self:EnsureSeason(d)
    if type(index)~="number" or index%1~=0 or index<1 or index>3 then return false,"That contract can't be rerolled" end
    if s.Claimed[index] then return false,"That contract is already claimed" end
    if s.Progress[index]>=Profiles.WeeklyAt(s,index).Goal then return false,"That contract is done: claim it instead" end
    return true
end
function Profiles:RerollWeeklyData(d,index)
    local s=self:EnsureSeason(d)
    if not self:CanRerollWeekly(d,index) then
        index=nil
        for i=1,3 do if self:CanRerollWeekly(d,i) then index=i;break end end
        if not index then d.Coins+=100;return false,"No weekly contract left to reroll  /  +100 marks instead" end
    end
    local taken={}
    for i=1,3 do taken[s.Ids[i]]=true end
    local pool={}
    for id,q in pairs(Profiles.Weekly) do if q.Slot==index and not taken[id] then table.insert(pool,id) end end
    if #pool==0 then d.Coins+=100;return false,"No other weekly contracts to roll  /  +100 marks instead" end
    table.sort(pool)
    local id=pool[Random.new():NextInteger(1,#pool)]
    s.Ids[index]=id;s.Progress[index]=0;s.Claimed[index]=false
    return true,"New weekly contract: "..Profiles.Weekly[id].Title..(Profiles.Weekly[id].Hard and "  (HARD)" or "")
end
-- one paid reroll (what = profiles.rerollPick entry); returns the message
function Profiles:ApplyReroll(d,what)
    what=type(what)=="table" and what or {kind="daily"}
    if what.kind=="all" then return select(2,self:RerollAllData(d))
    elseif what.kind=="weekly" then return select(2,self:RerollWeeklyData(d,what.index))
    else return select(2,self:RerollQuestData(d,what.index)) end
end
Profiles.Quests=QUESTS
Profiles.QuestsFor=questsFor
-- WEEKLY contracts: three a week, one per slot, from this pool (rerollable for 4 Robux: Store.Products.RerollWeekly).
-- Tracked through Profiles:Track like the dailies. WEEKLY_DEFAULT is the set every week starts with.
local WEEKLY={
    W_Kill25={Slot=1,Title="Eliminate 25 players",Event="kill",Goal=25,Reward=200},
    W_Kill40={Slot=1,Hard=true,Title="Eliminate 40 players",Event="kill",Goal=40,Reward=320},
    W_Double5={Slot=1,Hard=true,Title="Get 5 double eliminations",Event="double",Goal=5,Reward=300},
    W_Rounds10={Slot=2,Title="Complete 10 rounds",Event="round",Goal=10,Reward=150},
    W_Win5={Slot=2,Hard=true,Title="Win 5 rounds",Event="win",Goal=5,Reward=350},
    W_Top10={Slot=2,Title="Place top 3 in 10 rounds",Event="top3",Goal=10,Reward=250},
    W_Write50={Slot=3,Title="Write 50 correct numbers",Event="kill",Goal=50,Reward=250},
    W_Marks3000={Slot=3,Title="Earn 3000 marks in matches",Event="marks",Goal=3000,Reward=250},
    W_Multi6={Slot=3,Hard=true,Title="Eliminate 6 players in one round",Event="roundKills",Best=true,Goal=6,Reward=300},
}
local WEEKLY_DEFAULT={"W_Kill25","W_Rounds10","W_Write50"}
local function weeklyAt(s,i) return WEEKLY[s.Ids and s.Ids[i]] or WEEKLY[WEEKLY_DEFAULT[i]] end
Profiles.Weekly=WEEKLY;Profiles.WeeklyAt=weeklyAt
local MILESTONE_GOALS={3,7,12,18,24} -- daily contracts finished this week
local MILESTONE_REWARDS={100,150,200,250,500}
function Profiles:EnsureSeason(d)
 -- WEEKLY contracts (they used to run for the whole season): a fresh set every Monday 00:00 UTC
 -- (os.time day 0 was a Thursday, so day 4 is the first Monday)
 local week=math.floor((math.floor(os.time()/86400)-4)/7)
 if type(d.Season)~="table"or d.Season.Id~=week then d.Season={Id=week,Ids=table.clone(WEEKLY_DEFAULT),Progress={0,0,0},Claimed={},Milestones={},Completed=0}end
 local s=d.Season
 s.Ids=type(s.Ids)=="table" and s.Ids or table.clone(WEEKLY_DEFAULT)
 for i=1,3 do if not WEEKLY[s.Ids[i]] then s.Ids[i]=WEEKLY_DEFAULT[i] end end
 s.Progress=type(s.Progress)=="table"and s.Progress or {}
 s.Claimed=type(s.Claimed)=="table"and s.Claimed or {}
 s.Milestones=type(s.Milestones)=="table"and s.Milestones or {}
 s.Completed=math.max(0,math.floor(tonumber(s.Completed)or 0))
 for i=1,3 do s.Progress[i]=math.clamp(math.floor(tonumber(s.Progress[i])or 0),0,weeklyAt(s,i).Goal);s.Claimed[i]=s.Claimed[i]==true end
 for i=1,5 do s.Milestones[i]=s.Milestones[i]==true end
 return s
end
function Profiles:EnsureDaily(d)
    local day=math.floor(os.time()/86400)
    if type(d.Daily)~="table" or d.Daily.Day~=day then d.Daily={Day=day,V=2,Ids=questsFor(day),Progress={0,0,0,0},Claimed={false,false,false,false}} end
    -- a save from before the rotation (no V=2) switches to today's rotating quests straight away (fresh progress)
    if d.Daily.V~=2 or type(d.Daily.Ids)~="table" then
        d.Daily.V=2 d.Daily.Ids=questsFor(day);d.Daily.Progress={0,0,0,d.Daily.Progress and d.Daily.Progress[4] or 0};d.Daily.Claimed={false,false,false,d.Daily.Claimed and d.Daily.Claimed[4]==true} end
    for i=1,4 do if not QUESTS[d.Daily.Ids[i]] then d.Daily.Ids[i]=questsFor(day)[i] end end
    d.Daily.Progress=type(d.Daily.Progress)=="table" and d.Daily.Progress or {}
    d.Daily.Claimed=type(d.Daily.Claimed)=="table" and d.Daily.Claimed or {}
    for i=1,4 do
        d.Daily.Progress[i]=math.clamp(math.floor(tonumber(d.Daily.Progress[i]) or 0),0,questAt(d.Daily,i).Goal)
        d.Daily.Claimed[i]=d.Daily.Claimed[i]==true
    end
    return d.Daily
end
-- advance every daily quest listening to `event` (Best quests keep the highest single value instead)
function Profiles:Track(p,event,amount)
    local d=self.data[p];if not d then return end
    local daily=self:EnsureDaily(d)
    local changed=false
    for i=1,4 do
        local q=questAt(daily,i)
        if q.Event==event and not daily.Claimed[i] then
            local value=q.Best and math.max(daily.Progress[i],amount) or daily.Progress[i]+amount
            value=math.min(q.Goal,value)
            if value~=daily.Progress[i] then daily.Progress[i]=value;changed=true end
        end
    end
    local season=self:EnsureSeason(d)
    for i=1,3 do
        local q=weeklyAt(season,i)
        if q.Event==event and not season.Claimed[i] then
            local value=q.Best and math.max(season.Progress[i],amount) or season.Progress[i]+amount
            value=math.min(q.Goal,value)
            if value~=season.Progress[i] then season.Progress[i]=value;changed=true end
        end
    end
    return changed
end
-- slides are simulated by the client; the server mirrors each one as a new SlideUntil on the character
function Profiles:WatchSlides(p)
    local function watch(character)
        local last=0
        character:GetAttributeChangedSignal("SlideUntil"):Connect(function()
            local untilTime=character:GetAttribute("SlideUntil") or 0
            local now=workspace:GetServerTimeNow()
            if untilTime>now and now-last>0.6 and p:GetAttribute("InArena") then
                last=now
                if self:Track(p,"slide",1) then self:Publish(p) end
            end
        end)
    end
    p.CharacterAdded:Connect(watch)
    if p.Character then watch(p.Character) end
end
function Profiles:Claim(p,action,index)
    local d=self.data[p];if not d then return "Profile loading…" end
    local daily=self:EnsureDaily(d)
    if action=="ClaimDaily" then
        if d.LastDailyClaim==daily.Day then return "Daily reward already claimed" end
        local consecutive=d.LastDailyClaim==daily.Day-1
        d.DailyStreak=consecutive and (math.max(0,tonumber(d.DailyStreak)or 0)+1)or 1
        d.LastDailyClaim=daily.Day
        -- 7-day login calendar (Numberfall.DailyRewards): day 1..7 of the week you're on
        local day=DailyRewards.DayFor(d.DailyStreak)
        local marks=DailyRewards.Marks[day]
        d.Coins=d.Coins+marks
        self:Publish(p)
        task.spawn(function() self:Save(p,false) end)
        return "+"..marks.." marks  ·  daily reward, day "..day
    elseif action=="ClaimQuest" then
        if type(index)~="number" or index%1~=0 or index<1 or index>4 then return "Unknown contract" end
        if daily.Claimed[index] then return "Contract reward already claimed" end
        local q=questAt(daily,index)
        if daily.Progress[index]<q.Goal then return "Complete this contract first" end
        daily.Claimed[index]=true;d.Coins=d.Coins+q.Reward
        d.QuestMarksEarned=(tonumber(d.QuestMarksEarned)or 0)+q.Reward
        local season=self:EnsureSeason(d);season.Completed+=1
    elseif action=="ClaimSeasonQuest"or action=="ClaimSeasonMilestone"then
        local season=self:EnsureSeason(d);local milestone=action=="ClaimSeasonMilestone"
        local goals=milestone and MILESTONE_GOALS or {weeklyAt(season,1).Goal,weeklyAt(season,2).Goal,weeklyAt(season,3).Goal}
        local rewards=milestone and MILESTONE_REWARDS or {weeklyAt(season,1).Reward,weeklyAt(season,2).Reward,weeklyAt(season,3).Reward}
        local claimed=milestone and season.Milestones or season.Claimed
        if type(index)~="number"or index%1~=0 or index<1 or index>#goals then return "Unknown reward"end
        if claimed[index]then return "Reward already claimed"end
        local progress=milestone and season.Completed or season.Progress[index]
        if progress<goals[index]then return "Complete this objective first"end
        claimed[index]=true;d.Coins+=rewards[index]
        d.QuestMarksEarned=(tonumber(d.QuestMarksEarned)or 0)+rewards[index]
    else return "Unknown claim" end
    self:Publish(p);return "Marks added to your balance"
end
function Profiles:RoundComplete(p,won)
    local d=self.data[p];if not d then return end
    d.Stats.Rounds+=1
    local xp,marks=ROUND_XP,0
    -- (a round won against nothing but bots pays the smaller bot win bonus: MatchService sets ResultVsBots)
    if won then d.Stats.Wins+=1;xp+=WIN_XP;marks+=(p:GetAttribute("ResultVsBots")==true and (self.rewards.BotWinCoins or 20) or WIN_MARKS) end
    -- streaks, best round, podiums, clean rounds
    d.Stats.WinStreak=won and (d.Stats.WinStreak or 0)+1 or 0
    d.Stats.BestStreak=math.max(d.Stats.BestStreak or 0,d.Stats.WinStreak)
    d.Stats.BestRound=math.max(d.Stats.BestRound or 0,tonumber(p:GetAttribute("RoundKills")) or 0)
    local podium=p:GetAttribute("ResultPlace")
    if type(podium)=="number" and podium>=1 and podium<=3 then d.Stats.Top3=(d.Stats.Top3 or 0)+1 end
    if (p:GetAttribute("ResultDeaths") or 0)==0 and p:GetAttribute("ResultRound")~=nil then d.Stats.Clean=(d.Stats.Clean or 0)+1 end
    xp,marks=boost(p,xp,marks)
    d.XP+=xp;d.Coins+=marks
    p:SetAttribute("ResultXP",(p:GetAttribute("ResultXP") or 0)+xp)
    p:SetAttribute("ResultCoins",(p:GetAttribute("ResultCoins") or 0)+marks)
    task.spawn(function() self:Save(p,false) end)
    self:Track(p,"round",1)
    if won then self:Track(p,"win",1) end
    local place=p:GetAttribute("ResultPlace")
    if type(place)=="number" and place>=1 and place<=3 then self:Track(p,"top3",1) end
    if (p:GetAttribute("ResultDeaths") or 0)==0 and p:GetAttribute("ResultRound")~=nil then self:Track(p,"clean",1) end
    if marks>0 then self:Track(p,"marks",marks) end
    self:Publish(p)
end
function Profiles:Publish(p)
    local d=self.data[p];if not d or not p.Parent then return end
    local daily=self:EnsureDaily(d)
    for i=1,4 do
        local q=questAt(daily,i)
        p:SetAttribute("Quest"..i.."Progress",daily.Progress[i]);p:SetAttribute("Quest"..i.."Goal",q.Goal)
        p:SetAttribute("Quest"..i.."Reward",q.Reward);p:SetAttribute("Quest"..i.."Claimed",daily.Claimed[i])
        p:SetAttribute("Quest"..i.."Title",q.Title);p:SetAttribute("Quest"..i.."Id",daily.Ids[i]);p:SetAttribute("Quest"..i.."Hard",q.Hard==true)
    end
    local season=self:EnsureSeason(d)
    for i=1,3 do
        local w=weeklyAt(season,i)
        p:SetAttribute("SeasonQuest"..i.."Progress",season.Progress[i]);p:SetAttribute("SeasonQuest"..i.."Goal",w.Goal)
        p:SetAttribute("SeasonQuest"..i.."Reward",w.Reward);p:SetAttribute("SeasonQuest"..i.."Claimed",season.Claimed[i])
        p:SetAttribute("SeasonQuest"..i.."Title",w.Title);p:SetAttribute("SeasonQuest"..i.."Id",season.Ids[i]);p:SetAttribute("SeasonQuest"..i.."Hard",w.Hard==true)
    end
    for i=1,5 do p:SetAttribute("SeasonMilestone"..i.."Claimed",season.Milestones[i])end
    p:SetAttribute("SeasonCompletedQuests",season.Completed)
    p:SetAttribute("QuestMarksEarned",tonumber(d.QuestMarksEarned)or 0)
    p:SetAttribute("DailyStreak",d.LastDailyClaim and d.LastDailyClaim>=daily.Day-1 and (tonumber(d.DailyStreak)or 0)or 0)
    p:SetAttribute("DailyClaimed",d.LastDailyClaim==daily.Day)
    -- the calendar day to show: today's if already claimed, else the one you'd claim now (a missed day starts over)
    do
        local streak=math.max(0,tonumber(d.DailyStreak)or 0)
        local claimedToday=d.LastDailyClaim==daily.Day
        local alive=d.LastDailyClaim==daily.Day-1
        p:SetAttribute("DailyDay",claimedToday and DailyRewards.DayFor(streak) or (alive and DailyRewards.DayFor(streak+1) or 1))
    end
    p:SetAttribute("Coins",d.Coins);p:SetAttribute("XP",d.XP)
    local level,into,need=levelFor(d.XP)
    p:SetAttribute("Level",level);p:SetAttribute("LevelXP",into);p:SetAttribute("LevelGoal",need)
    for _,k in ipairs(STAT_KEYS) do p:SetAttribute("Stat"..k,d.Stats[k]) end
    local board=p:FindFirstChild("leaderstats")
    if board then
        local value=board:FindFirstChild("Level")
        if not value then value=Instance.new("IntValue");value.Name="Level";value.Parent=board end
        value.Value=level
    end
    if self.notice and d.LastLevel and level>d.LastLevel then self.notice:FireClient(p,"LevelUp",{Level=level}) end
    -- every level up earns a free case
    if d.LastLevel and level>d.LastLevel then
        local n=(level-d.LastLevel)*Cases.FreePerLevel
        d.Cases=(tonumber(d.Cases) or 0)+n
        if self.notice then self.notice:FireClient(p,"Store",{Text="LEVEL UP  ·  +"..n.." FREE CASE"..(n>1 and "S" or ""),Kind="good"}) end
    end
    p:SetAttribute("Cases",math.max(0,math.floor(tonumber(d.Cases) or 0)))
    do local pity=type(d.CasePity)=="table" and d.CasePity or {}
        p:SetAttribute("PityLegendary",math.max(1,Cases.Pity.Legendary-(tonumber(pity.L) or 0)))
        p:SetAttribute("PityExclusive",math.max(1,Cases.Pity.CaseExclusive-(tonumber(pity.X) or 0)))
    end
    d.LastLevel=level
    p:SetAttribute("NotebookFinish",d.Equipped)
    p:SetAttribute("HairStyle",d.HairStyle);p:SetAttribute("HairColor",d.HairColor);p:SetAttribute("FaceMask",d.FaceMask or HairCatalog.DefaultMask)
    p:SetAttribute("Outfit",d.Outfit or Outfits.Default)
    -- Loadout > VISOR / TRAIL picks (nil = the best one your rank unlocks: Numberfall.RankLooks)
    p:SetAttribute("VisorStyle",d.VisorStyle);p:SetAttribute("TrailStyle",d.TrailStyle)
    for id in pairs(TrailCw) do p:SetAttribute("OwnHair_"..id,ownsTrailColor(d,id)) end
    for id in pairs(VisorCw) do p:SetAttribute("OwnHair_"..id,ownsVisorColor(d,id)==true) end
    p:SetAttribute("VisorColor",(d.VisorColor and ownsVisorColor(d,d.VisorColor)) and d.VisorColor or VisorColorways.Default)
    d.OutfitColors=d.OutfitColors or {}
    local cw=d.OutfitColors[d.Outfit or Outfits.Default]
    p:SetAttribute("OutfitColor",(cw and ownsColorway(d,cw)) and cw or Outfits.DefaultColorway)
    for id in pairs(Colorways) do p:SetAttribute("OwnHair_"..id,ownsColorway(d,id)==true)end
    -- per outfit: which colourways you own for it and which one it's dyed in (the Loadout lists any outfit's)
    for oid in pairs(HairOutfits) do
        for cid in pairs(Colorways) do p:SetAttribute("OwnCw_"..oid.."_"..cid,ownsColorway(d,cid,oid)==true) end
        local oc=d.OutfitColors[oid]
        p:SetAttribute("OutfitCw_"..oid,(oc and ownsColorway(d,oc,oid)) and oc or Outfits.DefaultColorway)
    end
    for id in pairs(HairOutfits) do p:SetAttribute("OwnHair_"..id,ownsHair(d,id)==true)end
    for id in pairs(HairStyles) do p:SetAttribute("OwnHair_"..id,ownsHair(d,id)==true)end
    for id in pairs(HairColors) do p:SetAttribute("OwnHair_"..id,ownsHair(d,id)==true)end
    -- per hairstyle: which colours you own for it and the colour it's kept in (Loadout > Hair > COLOURS for a
    -- hairstyle you picked but aren't wearing)
    d.StyleColors=d.StyleColors or {}
    for sid in pairs(HairStyles) do if sid~="None" then
        for cid in pairs(HairColors) do p:SetAttribute("OwnHc_"..sid.."_"..cid,ownsHair(d,cid,sid)==true) end
        local keep=d.StyleColors[sid]
        p:SetAttribute("HairCol_"..sid,(keep and ownsHair(d,keep,sid)) and keep or HairCatalog.DefaultColor)
    end end
    for id in pairs(HairMasks) do p:SetAttribute("OwnHair_"..id,ownsHair(d,id)==true)end
    for id in pairs(NumStyles) do p:SetAttribute("OwnHair_"..id,ownsHair(d,id)==true)end
    p:SetAttribute("NumberStyle",(NumStyles[d.NumberStyle] and ownsHair(d,d.NumberStyle)) and d.NumberStyle or NumberStyles.Default)
    for id in pairs(Extras.ById) do p:SetAttribute("OwnHair_"..id,ownsHair(d,id)==true)end
    for kind,field in pairs(Extras.Field) do
        local v=extraEquipped(d,kind)
        p:SetAttribute(field,ownsHair(d,v) and v or Extras.Default[kind])
    end
    -- pet colourways: which you own for each pet, what each pet is dyed, and the colour of the pet you have out
    d.PetColors=d.PetColors or {}
    for _,pet in ipairs(Extras.Pets) do if realPet(pet.Id) then
        for cid in pairs(PetCw) do p:SetAttribute("OwnPc_"..pet.Id.."_"..cid,ownsPetColor(d,cid,pet.Id)==true) end
        local pc=d.PetColors[pet.Id]
        p:SetAttribute("PetCw_"..pet.Id,(pc and ownsPetColor(d,pc,pet.Id)) and pc or Extras.DefaultPetColorway)
    end end
    for cid in pairs(PetCw) do p:SetAttribute("OwnHair_"..cid,(PetCw[cid].Premium or PetCw[cid].Vip) and d.OwnedHair[cid]==true or PetCw[cid].Price==0) end
    -- mask colourways: owned per mask, each mask's dye, and the dye of the mask you wear
    d.MaskColors=d.MaskColors or {}
    for mid in pairs(HairMasks) do if realMask(mid) then
        for cid in pairs(MaskCw) do p:SetAttribute("OwnMc_"..mid.."_"..cid,ownsMaskColor(d,cid,mid)==true) end
        local mc=d.MaskColors[mid]
        p:SetAttribute("MaskCw_"..mid,(mc and ownsMaskColor(d,mc,mid)) and mc or Extras.DefaultMaskColorway)
    end end
    local maskNow=d.FaceMask or HairCatalog.DefaultMask
    p:SetAttribute("MaskColor",realMask(maskNow) and p:GetAttribute("MaskCw_"..maskNow) or Extras.DefaultMaskColorway)
    local petNow=p:GetAttribute("Pet")
    p:SetAttribute("PetColor",realPet(petNow) and p:GetAttribute("PetCw_"..petNow) or Extras.DefaultPetColorway)
    for id in pairs(self.catalog) do p:SetAttribute("Own_"..id,d.Owned[id]==true)end
    d.GearColors=d.GearColors or {}
    for gid in pairs(self.catalog) do
        for cid in pairs(GearCw) do p:SetAttribute("OwnGc_"..gid.."_"..cid,ownsGearColor(d,cid,gid)==true) end
        local gc=d.GearColors[gid]
        p:SetAttribute("GearCw_"..gid,(gc and ownsGearColor(d,gc,gid)) and gc or GearColorways.Default)
    end
    for cid in pairs(GearCw) do if GearCw[cid].Vip or GearCw[cid].Premium then p:SetAttribute("OwnHair_"..cid,d.OwnedHair[cid]==true) end end
    p:SetAttribute("GearColor",p:GetAttribute("GearCw_"..tostring(d.Equipped)) or GearColorways.Default)
    p:SetAttribute("IntroSeen",d.IntroSeen==true)
    p:SetAttribute("GroupRewarded",d.GroupReward==true)
    p:SetAttribute("CommunitySeen",d.CommunitySeen==true)
    p:SetAttribute("TutorialOffered",d.TutorialOffered==true);p:SetAttribute("TutorialDone",d.TutorialDone==true)
    p:SetAttribute("ProfileStorage",d.Persistent and "Saved" or "Session only")
    if self.settingsRules then for key,value in pairs(d.Settings)do p:SetAttribute("Setting_"..key,value)end end
    p:SetAttribute("ProfileReady",true)
end
function Profiles:Load(p)
    local defaults={Coins=150,XP=0,Owned={Classic=true},Equipped="Classic",Stats={},HairStyle=HairCatalog.DefaultStyle,HairColor=HairCatalog.DefaultColor,OwnedHair={},StyleColors={},FaceMask=HairCatalog.DefaultMask}
    local ok,data,acquired=false,nil,false
    if Store then
        -- A player hopping servers can arrive before the old server has released the profile. Retry for ~25s,
        -- then take it over (the old server's lease would have kept it for up to 3 minutes after a crash).
        for attempt=1,6 do
            if not p.Parent then return end
            local steal=attempt==6
            local busy=false
            acquired=false
            ok,data=pcall(function()return Store:UpdateAsync("u"..p.UserId,function(old)
                if old and old.Session and old.Session~=self.token and (old.Lease or 0)>os.time() and not steal then busy=true;return nil end
                local d=old or defaults;d.Session=self.token;d.Lease=os.time()+180;acquired=true;return d
            end)end)
            if ok and acquired then break end
            if not ok then
                -- Studio without "Enable Studio Access to API Services": no point retrying, play session-only
                if tostring(data):find("StudioAccessToApisNotAllowed") or tostring(data):find("API access") then break end
                warn("Numberfall profile load failed for "..p.UserId.." (attempt "..attempt.."): "..tostring(data))
            end
            task.wait(busy and 5 or math.min(8,2^attempt))
        end
    end
    local d=ok and acquired and data or defaults
    d.Coins=math.max(0,tonumber(d.Coins) or 150);d.XP=math.max(0,tonumber(d.XP) or 0)
    d.Owned=type(d.Owned)=="table" and d.Owned or {};d.Owned.Classic=true
    d.Stats=cleanStats(d.Stats)
    d.Redeemed=type(d.Redeemed)=="table" and d.Redeemed or {}
    d.Receipts=type(d.Receipts)=="table" and d.Receipts or {}
    for rid,marks in pairs(RETIRED_GEAR) do
        if not self.catalog[rid] and d.Owned[rid] then
            d.Owned[rid]=nil
            if marks>0 then d.Coins=(d.Coins or 0)+marks end
        end
    end
    d.GearColors=type(d.GearColors)=="table" and d.GearColors or {}
    if not self.catalog[d.Equipped] or not d.Owned[d.Equipped] then d.Equipped="Classic"end
    d.OwnedHair=type(d.OwnedHair)=="table" and d.OwnedHair or {}
    -- retired hairstyles (HairCatalog.Retired): refund the style and any colours bought for it, once
    for rid,price in pairs(HairCatalog.Retired or {}) do
        if d.OwnedHair[rid]==true then d.OwnedHair[rid]=nil;d.Coins+=price end
        for key,v in pairs(table.clone(d.OwnedHair)) do
            local s,c=tostring(key):match("^([^|]+)|(.+)$")
            if s==rid and v==true then d.OwnedHair[key]=nil;local col=HairColors[c];if col and not col.Premium and not col.Vip then d.Coins+=col.Price end end
        end
        if d.StyleColors and d.StyleColors[rid] then d.StyleColors[rid]=nil end
    end
    if not HairStyles[d.HairStyle] or not ownsHair(d,d.HairStyle) then d.HairStyle=HairCatalog.DefaultStyle end
    d.StyleColors=type(d.StyleColors)=="table" and d.StyleColors or {}
    -- old saves owned colours for every style: keep each one, but only for the hairstyle worn now
    for id,v in pairs(table.clone(d.OwnedHair)) do
        if HairColors[id] and v==true and not (HairColors[id].Premium or HairColors[id].Vip) then
            if d.HairStyle and d.HairStyle~="None" then d.OwnedHair[colourKey(d.HairStyle,id)]=true end
            d.OwnedHair[id]=nil
        end
    end
    if not HairColors[d.HairColor] or not ownsHair(d,d.HairColor) then d.HairColor=HairCatalog.DefaultColor end
    if d.HairStyle and d.HairStyle~="None" and d.StyleColors[d.HairStyle]==nil then d.StyleColors[d.HairStyle]=d.HairColor end
    if not HairMasks[d.FaceMask] or not ownsHair(d,d.FaceMask) then d.FaceMask=HairCatalog.DefaultMask end
    if not HairOutfits[d.Outfit] or not ownsHair(d,d.Outfit) then d.Outfit=Outfits.Default end
    if not NumStyles[d.NumberStyle] or not ownsHair(d,d.NumberStyle) then d.NumberStyle=NumberStyles.Default end
    for kind,field in pairs(Extras.Field) do
        local v=extraEquipped(d,kind)
        d[field]=ownsHair(d,v) and v or Extras.Default[kind]
    end
    d.OutfitColors=type(d.OutfitColors)=="table" and d.OutfitColors or {}
    d.PetColors=type(d.PetColors)=="table" and d.PetColors or {}
    d.MaskColors=type(d.MaskColors)=="table" and d.MaskColors or {}
    do local RankLooks=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("RankLooks"))
        if not RankLooks.Valid(d.VisorStyle) then d.VisorStyle=nil end
        if not RankLooks.ValidTrail(d.TrailStyle) or (TrailCw[d.TrailStyle] and not ownsTrailColor(d,d.TrailStyle)) then d.TrailStyle=nil end
    end
    if d.VisorColor~=nil and not ownsVisorColor(d,d.VisorColor) then d.VisorColor=nil end
    d.Cases=math.max(0,math.floor(tonumber(d.Cases) or 0))
    if self.settingsRules then d.Settings=self.settingsRules.Sanitize(d.Settings)end
    d.Persistent=ok and acquired and data~=nil
    self.data[p]=d
    if not p.Parent then self:Save(p,true);self.data[p]=nil;return end
    self:Publish(p)
end
function Profiles:Save(p,release)
    while self.saving[p] do task.wait(.1)end
    local d=self.data[p];if not d or not d.Persistent then return end
    self.saving[p]=true
    local daily=self:EnsureDaily(d)
    local snapshot={Coins=d.Coins,XP=d.XP,Owned=table.clone(d.Owned),Equipped=d.Equipped,GearColors=d.GearColors and table.clone(d.GearColors),Settings=d.Settings and table.clone(d.Settings),
        Daily={Day=daily.Day,V=2,Ids=table.clone(daily.Ids),Progress=table.clone(daily.Progress),Claimed=table.clone(daily.Claimed)},LastDailyClaim=d.LastDailyClaim,
        DailyStreak=d.DailyStreak,QuestMarksEarned=d.QuestMarksEarned,
        Season={Id=self:EnsureSeason(d).Id,Ids=table.clone(d.Season.Ids),Progress=table.clone(d.Season.Progress),Claimed=table.clone(d.Season.Claimed),Milestones=table.clone(d.Season.Milestones),Completed=d.Season.Completed},
        Stats=table.clone(d.Stats),Redeemed=table.clone(d.Redeemed or {}),Receipts=table.clone(d.Receipts or {}),
        HairStyle=d.HairStyle,HairColor=d.HairColor,FaceMask=d.FaceMask,Outfit=d.Outfit,NumberStyle=d.NumberStyle,BodyType=d.BodyType,KillEffect=d.KillEffect,Pet=d.Pet,VisorStyle=d.VisorStyle,TrailStyle=d.TrailStyle,VisorColor=d.VisorColor,Cases=d.Cases,CasePity=type(d.CasePity)=="table" and table.clone(d.CasePity) or nil,IntroSeen=d.IntroSeen==true or nil,TutorialOffered=d.TutorialOffered==true or nil,TutorialDone=d.TutorialDone==true or nil,GroupReward=d.GroupReward==true or nil,CommunitySeen=d.CommunitySeen==true or nil,StyleColors=table.clone(d.StyleColors or {}),OutfitColors=table.clone(d.OutfitColors or {}),PetColors=table.clone(d.PetColors or {}),MaskColors=table.clone(d.MaskColors or {}),OwnedHair=table.clone(d.OwnedHair or {}),
        Session=not release and self.token or nil,Lease=not release and os.time()+180 or 0}
    local owns,ok=false,false
    for attempt=1,3 do
        ok=pcall(function()Store:UpdateAsync("u"..p.UserId,function(old)
            if not old or old.Session~=self.token then owns=false;return nil end
            owns=true;return snapshot
        end)end)
        if ok then break end
        if attempt<3 then task.wait(attempt*2) end
    end
    self.saving[p]=nil
    if ok and owns then d.SavedAt=os.time() end
    if not ok or not owns then
        d.Persistent=false;self:Publish(p)
        warn("Numberfall profile save unavailable for "..p.UserId.."; session marked unsaved")
    end
    return ok and owns
end
-- Robux purchases (ServerScriptService.Monetization). Each receipt is granted once: its PurchaseId is kept in the
-- profile (last 100). Returns "granted", "duplicate" or nil (profile not ready).
function Profiles:GrantReceipt(p,purchaseId,grant)
    local d=self.data[p];if not d then return nil end
    d.Receipts=d.Receipts or {}
    for _,id in ipairs(d.Receipts)do if id==purchaseId then return "duplicate" end end
    grant(d)
    table.insert(d.Receipts,purchaseId)
    while #d.Receipts>100 do table.remove(d.Receipts,1) end
    self:Publish(p)
    return "granted"
end
-- unlock a Robux / VIP cosmetic for good (notebook set, colourway or hair colour)
function Profiles:Unlock(d,itemId)
    if self.catalog[itemId] then d.Owned[itemId]=true;return true
    elseif Colorways[itemId] or HairColors[itemId] or HairStyles[itemId] or HairMasks[itemId] or HairOutfits[itemId] or NumStyles[itemId] or Extras.ById[itemId] or PetCw[itemId] or MaskCw[itemId] or GearCw[itemId] or VisorCw[itemId] or TrailCw[itemId] then d.OwnedHair[itemId]=true;return true end
    return false
end
-- take a VIP cosmetic back (pass no longer owned); falls back to the default if it was equipped
function Profiles:Lock(d,itemId)
    if self.catalog[itemId] then
        if d.Owned[itemId] then d.Owned[itemId]=nil;if d.Equipped==itemId then d.Equipped="Classic" end;return true end
    elseif d.OwnedHair[itemId] then
        d.OwnedHair[itemId]=nil
        if d.NumberStyle==itemId then d.NumberStyle=NumberStyles.Default end
        if d.HairColor==itemId then d.HairColor=HairCatalog.DefaultColor end
        for _,field in pairs(Extras.Field) do if d[field]==itemId then d[field]=nil end end
        if PetCw[itemId] and d.PetColors then for pet,pc in pairs(d.PetColors) do if pc==itemId then d.PetColors[pet]=nil end end end
        if MaskCw[itemId] and d.MaskColors then for m,mc in pairs(d.MaskColors) do if mc==itemId then d.MaskColors[m]=nil end end end
        if GearCw[itemId] and d.GearColors then for g,gc in pairs(d.GearColors) do if gc==itemId then d.GearColors[g]=nil end end end
        if d.VisorColor==itemId then d.VisorColor=nil end
        if d.TrailStyle==itemId then d.TrailStyle=nil end
        return true
    end
    return false
end
function Profiles:Data(p)return self.data[p] end
-- the join cinematic plays once per player: the client reports it finished / skipped
function Profiles:MarkIntro(p)
    local d=self.data[p];if not d or d.IntroSeen then return end
    d.IntroSeen=true
    p:SetAttribute("IntroSeen",true)
    task.spawn(function() self:Save(p,false) end)
end
function Profiles:Redeem(p,raw)
    local d=self.data[p];if not d then return "Profile loading…" end
    if type(raw)~="string" or #raw>40 then return "Invalid code" end
    local key=raw:upper():gsub("%s","")
    local ok,list=pcall(require,script.Parent:WaitForChild("Codes"))
    local entry=ok and type(list)=="table" and list[key]
    if type(entry)~="table" then return "Invalid code" end
    if entry.Expires and os.time()>entry.Expires then return "This code has expired" end
    d.Redeemed=d.Redeemed or {}
    if d.Redeemed[key] then return "Code already redeemed" end
    d.Redeemed[key]=true
    local marks=math.max(0,math.floor(tonumber(entry.Marks) or 0))
    d.Coins=d.Coins+marks
    self:Publish(p)
    task.spawn(function() self:Save(p) end)
    return "Code redeemed  ·  +"..marks.." marks"
end
function Profiles:Action(p,action,id)
    local d=self.data[p];local item=self.catalog[id]
    if not d then return "Profile loading…"end
    if not item then return "Unknown item"end
    if action=="Buy" then
        if d.Owned[id] then return "Already owned"end
        if lockedItem(item) then return item.Vip and "VIP only" or "Robux only" end
        if d.Coins<item.Price then return "Not enough coins"end
        d.Coins=d.Coins-item.Price;d.Owned[id]=true
    elseif action=="Equip" then
        if not d.Owned[id] then return "Item not owned"end
        d.Equipped=id
    else return "Unknown action"end
    self:Publish(p)
    return action=="Buy" and "Added to locker" or "Equipped"
end
function Profiles:HairAction(p,action,id)
    local d=self.data[p];if not d then return "Profile loading…"end
    local style,color,mask,outfit=HairStyles[id],HairColors[id],HairMasks[id],HairOutfits[id]
    d.StyleColors=d.StyleColors or {}
    d.OutfitColors=d.OutfitColors or {}
    -- standard visor colourway: equipping one also puts the standard visor back on (RankVisors re-makes the visor)
    if type(id)=="string" and VisorCw[id] then
        local c=VisorCw[id]
        if action=="BuyHair" then
            if ownsVisorColor(d,id) then return "Already owned" end
            if c.Hidden then return "Not available" end
            if c.CaseOnly then return "Case exclusive" end
            if lockedItem(c) then return c.Vip and "VIP only" or "Robux only" end
            if d.Coins<c.Price then return "Not enough marks" end
            d.Coins-=c.Price;d.OwnedHair[id]=true
        elseif action=="EquipHair" then
            if not ownsVisorColor(d,id) then return "Not owned" end
            d.VisorColor=id~=VisorColorways.Default and id or nil
            if id~=VisorColorways.Default then d.VisorStyle="Standard" end
        else return "Unknown action" end
        self:Publish(p)
        task.spawn(function() self:Save(p,false) end)
        return action=="BuyHair" and "Added to locker" or "Equipped"
    end
    -- trail colour: bought here, worn as the trail (same as Loadout > TRAIL's EquipTrail)
    if type(id)=="string" and TrailCw[id] then
        local c=TrailCw[id]
        if action=="BuyHair" then
            if ownsTrailColor(d,id) then return "Already owned" end
            if c.CaseOnly then return "Case exclusive" end
            if lockedItem(c) then return c.Vip and "VIP only" or "Robux only" end
            if d.Coins<c.Price then return "Not enough marks" end
            d.Coins-=c.Price;d.OwnedHair[id]=true
        elseif action=="EquipHair" then
            if not ownsTrailColor(d,id) then return "Not owned" end
            d.TrailStyle=id
        else return "Unknown action" end
        self:Publish(p)
        task.spawn(function() self:Save(p,false) end)
        return action=="BuyHair" and "Added to locker" or "Trail equipped"
    end
    -- clothing colourway for the outfit being worn
    -- "<pet colourway>|<pet>": a pet's colourway (Loadout > Pets > COLOURS); equipping it also puts that pet out
    -- "<mask colourway>|<mask>": a mask's colourway (Loadout > Mask > COLOURS); equipping it also puts that mask on
    if type(id)=="string" and id:find("|",1,true) then
        local mc,mid=id:match("^([^|]+)|(.+)$")
        if mc and MaskCw[mc] and realMask(mid) then
            local c=MaskCw[mc]
            d.MaskColors=d.MaskColors or {}
            if not ownsHair(d,mid) then return "Buy the mask first" end
            if action=="BuyHair" then
                if ownsMaskColor(d,mc,mid) then return "Already owned" end
                if lockedItem(c) then return c.Vip and "VIP only" or "Robux only" end
                if d.Coins<c.Price then return "Not enough marks" end
                d.Coins-=c.Price
                d.OwnedHair[Extras.MaskColorKey(mid,mc)]=true
            elseif action=="EquipHair" then
                if not ownsMaskColor(d,mc,mid) then return "Not owned" end
                d.MaskColors[mid]=mc;d.FaceMask=mid
            else return "Unknown action" end
            self:Publish(p)
            if action=="EquipHair" and p.Character and self.onHairChanged then self.onHairChanged(p,p.Character) end
            task.spawn(function() self:Save(p,false) end)
            return action=="BuyHair" and "Added to locker" or "Equipped"
        end
    end
    if type(id)=="string" and id:find("|",1,true) then
        local pc,pet=id:match("^([^|]+)|(.+)$")
        if pc and PetCw[pc] and realPet(pet) then
            local c=PetCw[pc]
            d.PetColors=d.PetColors or {}
            if not ownsHair(d,pet) then return "Buy the pet first" end
            if action=="BuyHair" then
                if ownsPetColor(d,pc,pet) then return "Already owned" end
                if lockedItem(c) then return c.Vip and "VIP only" or "Robux only" end
                if d.Coins<c.Price then return "Not enough marks" end
                d.Coins-=c.Price
                d.OwnedHair[Extras.PetColorKey(pet,pc)]=true
            elseif action=="EquipHair" then
                if not ownsPetColor(d,pc,pet) then return "Not owned" end
                d.PetColors[pet]=pc;d.Pet=pet
            else return "Unknown action" end
            self:Publish(p)
            task.spawn(function() self:Save(p,false) end)
            return action=="BuyHair" and "Added to locker" or "Equipped"
        end
    end
    -- "<gear colourway>|<gear>": a gear item's colourway (Shop / Loadout > Gear > COLOURS); equipping it also equips that gear
    if type(id)=="string" and id:find("|",1,true) then
        local gc,gear=id:match("^([^|]+)|(.+)$")
        local g=gear and self.catalog[gear]
        if gc and GearCw[gc] and g then
            local c=GearCw[gc]
            d.GearColors=d.GearColors or {}
            if not (d.Owned[gear] or (g.Price or 0)==0) then return "Buy it first" end
            if action=="BuyHair" then
                if ownsGearColor(d,gc,gear) then return "Already owned" end
                if lockedItem(c) then return c.Vip and "VIP only" or "Robux only" end
                if d.Coins<c.Price then return "Not enough marks" end
                d.Coins-=c.Price
                d.OwnedHair[GearColorways.Key(gear,gc)]=true
            elseif action=="EquipHair" then
                if not ownsGearColor(d,gc,gear) then return "Not owned" end
                d.GearColors[gear]=gc;d.Equipped=gear
            else return "Unknown action" end
            self:Publish(p)
            task.spawn(function() self:Save(p,false) end)
            return action=="BuyHair" and "Added to locker" or "Equipped"
        end
    end
    -- "<hair colour>|<hairstyle>": a colour for a hairstyle picked in the Loadout (not necessarily the one you're
    -- wearing); equipping it also puts that hairstyle on
    if type(id)=="string" and id:find("|",1,true) then
        local hc,hs=id:match("^([^|]+)|(.+)$")
        if hc and HairColors[hc] and HairStyles[hs] and hs~="None" then
            local c=HairColors[hc]
            if not ownsHair(d,hs) then return "Buy the hairstyle first" end
            if action=="BuyHair" then
                if ownsHair(d,hc,hs) then return "Already owned" end
                if lockedItem(c) then return c.Vip and "VIP only" or "Robux only" end
                if d.Coins<c.Price then return "Not enough marks" end
                d.Coins-=c.Price
                d.OwnedHair[colourKey(hs,hc)]=true
            elseif action=="EquipHair" then
                if not ownsHair(d,hc,hs) then return "Not owned" end
                d.HairStyle=hs;d.HairColor=hc;d.StyleColors[hs]=hc
            else return "Unknown action" end
            self:Publish(p)
            if action=="EquipHair" and p.Character and self.onHairChanged then self.onHairChanged(p,p.Character) end
            task.spawn(function() self:Save(p,false) end)
            return action=="BuyHair" and "Added to locker" or "Equipped"
        end
    end
    -- "<colourway>|<outfit>": a colourway for an outfit picked in the Loadout (not necessarily the one you're wearing)
    local targetOutfit
    if type(id)=="string" and id:find("|",1,true) then
        local c,o=id:match("^([^|]+)|(.+)$")
        if c and Colorways[c] and HairOutfits[o] then id,targetOutfit=c,o else return "Unknown colourway" end
    end
    local cw=Colorways[id]
    if cw then
        local wearing=targetOutfit or d.Outfit or Outfits.Default
        if targetOutfit and not ownsHair(d,targetOutfit) then return "Buy the outfit first" end
        if action=="BuyHair" then
            if ownsColorway(d,id,wearing) then return "Already owned" end
            if lockedItem(cw) then return cw.Vip and "VIP only" or "Robux only" end
            if d.Coins<cw.Price then return "Not enough marks" end
            d.Coins-=cw.Price
            d.OwnedHair[Outfits.ColorwayKey(wearing,id)]=true
        elseif action=="EquipHair" then
            if not ownsColorway(d,id,wearing) then return "Not owned" end
            d.OutfitColors[wearing]=id
            if targetOutfit then d.Outfit=targetOutfit end -- equipping a colourway puts that outfit on
        else return "Unknown action" end
        self:Publish(p)
        if action=="EquipHair" and p.Character and self.onHairChanged then self.onHairChanged(p,p.Character) end
        task.spawn(function() self:Save(p,false) end)
        return action=="BuyHair" and "Added to locker" or "Equipped"
    end
    local numstyle=NumStyles[id]
    local extra=Extras.ById[id]
    local item=style or color or mask or outfit or numstyle or extra
    if not item then return "Unknown hairstyle"end
    if color and (d.HairStyle==nil or d.HairStyle=="None") then return "Equip a hairstyle first" end
    if action=="BuyHair" then
        if ownsHair(d,id) then return "Already owned"end
        if item.CaseOnly then return "Case exclusive" end
        if lockedItem(item) then return item.Vip and "VIP only" or "Robux only" end
        if d.Coins<item.Price then return "Not enough marks"end
        d.Coins=d.Coins-item.Price
        if color then d.OwnedHair[colourKey(d.HairStyle,id)]=true else d.OwnedHair[id]=true end
    elseif action=="EquipHair" then
        if not ownsHair(d,id) then return "Not owned"end
        if style then
            -- each hairstyle keeps its own colour; one it doesn't own falls back to Ink
            d.HairStyle=id
            local keep=d.StyleColors[id]
            d.HairColor=(keep and ownsHair(d,keep,id)) and keep or HairCatalog.DefaultColor
        elseif color then d.HairColor=id;d.StyleColors[d.HairStyle]=id
        elseif outfit then d.Outfit=id
        elseif numstyle then d.NumberStyle=id
        elseif extra then d[Extras.Field[extra.Kind]]=id
        else d.FaceMask=id end
    else return "Unknown action"end
    self:Publish(p)
    if action=="EquipHair" and p.Character and self.onHairChanged then self.onHairChanged(p,p.Character) end
    task.spawn(function() self:Save(p,false) end)
    return action=="BuyHair" and "Added to locker" or "Equipped"
end
-- COMMUNITY: joining the MARKED group pays GROUP_REWARD marks once per account (checked fresh with GroupService, so a
-- just-joined group counts straight away). CommunitySeen = the welcome card was shown (it isn't shown again).
local GROUP_ID,GROUP_REWARD=638378027,1000
Profiles.GroupId,Profiles.GroupReward=GROUP_ID,GROUP_REWARD
-- Loadout > VISOR / TRAIL: wear one your rank unlocks (Numberfall.RankLooks); nothing is bought
function Profiles:LookAction(p,action,id)
    local d=self.data[p];if not d then return "Profile loading…" end
    local RankLooks=require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("RankLooks"))
    if not (action=="EquipVisor" and RankLooks.Valid(id) or action~="EquipVisor" and RankLooks.ValidTrail(id)) then return "Unknown style" end
    if TrailCw[id] then if not ownsTrailColor(d,id) then return "Not owned" end
    elseif not RankLooks.Owns(p,id) then return RankLooks.LockText(id) end
    if action=="EquipVisor" then
        d.VisorStyle=id
        if id=="Standard" then d.VisorColor=nil end -- Standard = the original visor, no colourway
    else d.TrailStyle=id end
    self:Publish(p)
    task.spawn(function() self:Save(p,false) end)
    return action=="EquipVisor" and "Visor equipped" or "Trail equipped"
end
-- CASES: buy one with marks, add some (Robux receipt), open one. OpenCase returns what came out:
-- {Kind, Id, Name, Tier, Rarity, New = true | Duplicate = true + Refund, Amount (marks)}, or nil + why
function Profiles:BuyCase(p)
    local d=self.data[p];if not d then return "Profile loading…" end
    if d.Coins<Cases.Price then return "Not enough marks" end
    d.Coins-=Cases.Price;d.Cases=(tonumber(d.Cases) or 0)+1
    self:Publish(p)
    task.spawn(function() self:Save(p,false) end)
    return "Case added  ·  "..d.Cases.." to open"
end
function Profiles:AddCases(d,n) d.Cases=(tonumber(d.Cases) or 0)+(n or 1) end
-- one roll on a profile: takes a case, rolls it (pity counts every open), grants it or refunds a duplicate.
-- Returns {Kind, Id, Name, Tier, Rarity, Pity, New = true | Duplicate = true + Refund, Amount (marks)}
local function rollCase(d)
    d.Cases-=1
    -- pity: this open counts towards both guarantees; a full counter forces that tier
    local pity=type(d.CasePity)=="table" and d.CasePity or {}
    pity.L=(tonumber(pity.L) or 0)+1;pity.X=(tonumber(pity.X) or 0)+1
    local force=(pity.X>=Cases.Pity.CaseExclusive and "CaseExclusive") or (pity.L>=Cases.Pity.Legendary and "Legendary") or nil
    local it=Cases.Roll(caseRng,force)
    if it.Tier=="CaseExclusive" then pity.L=0;pity.X=0 elseif it.Tier=="Legendary" then pity.L=0 end
    d.CasePity=pity
    local res={Kind=it.Kind,Id=it.Id,Name=it.Name,Tier=it.Tier,Rarity=it.Rarity,Pity=force~=nil,Color=it.Color}
    if it.Kind=="marks" then
        d.Coins+=it.Amount;res.Amount=it.Amount
    else
        local owned=(it.Own=="gear" and d.Owned[it.Id]==true) or (it.Own~="gear" and d.OwnedHair[it.Id]==true)
        if owned then
            local refund=math.max(10,math.floor((it.Price or 0)*Cases.DupRefund/10+.5)*10)
            d.Coins+=refund;res.Duplicate=true;res.Refund=refund
        else
            if it.Own=="gear" then d.Owned[it.Id]=true else d.OwnedHair[it.Id]=true end
            res.New=true
        end
    end
    return res
end
function Profiles:OpenCase(p)
    local d=self.data[p];if not d then return nil,"Profile loading…" end
    if (tonumber(d.Cases) or 0)<1 then return nil,"No cases to open" end
    local res=rollCase(d)
    -- (saved now; shown once the reel has stopped, so the marks counter doesn't give the prize away)
    p:SetAttribute("Cases",math.max(0,math.floor(d.Cases)))
    task.spawn(function() self:Save(p,false) end)
    task.delay(6.8,function() if p.Parent then self:Publish(p) end end)
    return res
end
-- open several at once (Shop > CASES: OPEN x5 / x10): each rolls on its own, exactly like n single opens.
-- Returns {Multi = true, Results = {res, ...}}
Profiles.MultiOpen={5,10}
function Profiles:OpenCases(p,n)
    local d=self.data[p];if not d then return nil,"Profile loading…" end
    n=math.floor(tonumber(n) or 0)
    if n~=5 and n~=10 then return nil,"Open 5 or 10 at once" end
    if (tonumber(d.Cases) or 0)<n then return nil,"You need "..n.." cases for that" end
    local list={}
    for _=1,n do table.insert(list,rollCase(d)) end
    p:SetAttribute("Cases",math.max(0,math.floor(d.Cases)))
    task.spawn(function() self:Save(p,false) end)
    task.delay(8,function() if p.Parent then self:Publish(p) end end)
    return {Multi=true,Results=list}
end
function Profiles:ClaimGroupReward(p)
    local d=self.data[p];if not d then return "Profile loading…" end
    if d.GroupReward then return "Group reward already claimed" end
    local inGroup=false
    local ok,groups=pcall(function()return game:GetService("GroupService"):GetGroupsAsync(p.UserId)end)
    if ok and type(groups)=="table" then for _,g in ipairs(groups)do if g.Id==GROUP_ID then inGroup=true end end end
    if not inGroup then local ok2,res=pcall(function()return p:IsInGroup(GROUP_ID)end);inGroup=ok2 and res==true end
    if not inGroup then return "Join the group first, then claim" end
    d.GroupReward=true;d.Coins+=GROUP_REWARD
    self:Publish(p)
    task.spawn(function() self:Save(p,false) end)
    return "+"..GROUP_REWARD.." marks  ·  thanks for joining the group!"
end
function Profiles:MarkCommunitySeen(p)
    local d=self.data[p];if not d or d.CommunitySeen then return end
    d.CommunitySeen=true;p:SetAttribute("CommunitySeen",true)
    task.spawn(function() self:Save(p,false) end)
end
-- TUTORIAL (ServerScriptService.TutorialService): offered once on the main menu; finishing it pays `reward` the first time
function Profiles:MarkTutorial(p,finished,reward)
    local d=self.data[p];if not d then return 0 end
    local paid=0
    d.TutorialOffered=true
    if finished and not d.TutorialDone then
        d.TutorialDone=true
        paid=math.max(0,math.floor(tonumber(reward) or 0))
        d.Coins+=paid
    end
    p:SetAttribute("TutorialOffered",true);p:SetAttribute("TutorialDone",d.TutorialDone==true)
    self:Publish(p)
    task.spawn(function() self:Save(p,false) end)
    return paid
end
-- Loadout > RESET TO DEFAULT: the whole look back to the starting one in one go (owned items stay owned)
function Profiles:ResetLook(p)
    local d=self.data[p];if not d then return "Profile loading…" end
    d.HairStyle=HairCatalog.DefaultStyle;d.HairColor=HairCatalog.DefaultColor;d.FaceMask=HairCatalog.DefaultMask
    d.Outfit=Outfits.Default;d.OutfitColors=d.OutfitColors or {};d.OutfitColors[Outfits.Default]=nil
    d.NumberStyle=NumberStyles.Default;d.Equipped="Classic";d.GearColors={}
    for kind,field in pairs(Extras.Field) do d[field]=Extras.Default[kind] end
    d.VisorStyle=nil;d.TrailStyle=nil;d.VisorColor=nil -- back to the best your rank unlocks
    self:Publish(p)
    if p.Character and self.onHairChanged then self.onHairChanged(p,p.Character) end
    task.spawn(function() self:Save(p,false) end)
    return "Loadout reset to the default look"
end
function Profiles:Reward(p)
    local d=self.data[p];if not d then return end
    self:Track(p,"kill",1)
    self:Track(p,"roundKills",p:GetAttribute("RoundNumbers") or 1)
    self:Track(p,"marks",self.rewards.Coins)
    -- double elimination: two within DOUBLE_WINDOW seconds
    local now=os.clock()
    if d.LastKillAt and now-d.LastKillAt<=DOUBLE_WINDOW then self:Track(p,"double",1);d.LastKillAt=nil else d.LastKillAt=now end
    d.Stats.Kills+=1;d.Stats.Numbers+=1
    local xp,marks=boost(p,self.rewards.XP,self.rewards.Coins)
    d.Coins=d.Coins+marks;d.XP=d.XP+xp;self:Publish(p)
end
-- marking a match bot (BotService): the marks and XP, but it doesn't count as an elimination (no stats, daily or
-- season progress)
-- n: bots this player has marked this round (MatchService:Score); past Rewards.BotCoinsCap they pay XP but no marks
function Profiles:RewardBotKill(p,n)
    local d=self.data[p];if not d then return end
    -- (a bot is worth far less than a player: Config Rewards.BotXP / BotCoins)
    local coins=self.rewards.BotCoins or 4
    if n and n>(self.rewards.BotCoinsCap or math.huge) then coins=0 end
    local xp,marks=boost(p,self.rewards.BotXP or 20,coins)
    d.Coins=d.Coins+marks;d.XP=d.XP+xp
    d.Stats.BotKills=(d.Stats.BotKills or 0)+1
    self:Track(p,"marks",marks)
    self:Publish(p)
end
function Profiles:Died(p)
    local d=self.data[p];if not d then return end
    d.Stats.Deaths+=1;self:Publish(p)
end
function Profiles:SetSettings(p,raw)
    local d=self.data[p];if not d or not self.settingsRules or type(raw)~="table" then return false end
    d.Settings=self.settingsRules.Sanitize(raw);self:Publish(p);return true
end
return Profiles
