-- Gives the Shop, Quests, Settings and Credits menus the same framework as the Loadout (LoadoutStyle):
-- brand mark top-left, clean title with a red accent bar + subtitle, marks top-right, tabs across the top,
-- large single-stroke cards, BACK bottom-left and the actions bottom-right. Only geometry and styling change;
-- every authored element keeps its name, so the menu code keeps working. Idempotent (attribute Styled).
local Style=require(script.Parent:WaitForChild("LoadoutStyle"))
local H=Style.H
local C=Style.Colors
local stroke,text,label,place,strip=H.stroke,H.text,H.label,H.place,H.strip
local FONT,BOLD,CARD=H.FONT,H.BOLD,H.CARD
local X0,CW=H.X0,H.CW
local BAR_Y=860
local PS={}
local function hide(o) if o then o.Visible=false end end
local function noArt(o) if o then o:SetAttribute("DesignAsset",nil);o.Image="";o.Visible=false end end
local function clean(f) for _,n in ipairs({"Glow","SurfaceGradient","TopShine","ReferenceTexture","OrnamentAtlas","ThornBorder"})do local c=f:FindFirstChild(n);if c then c:Destroy() end end end
local function panel(f,trans)
 clean(f);f.BackgroundColor3=CARD;f.BackgroundTransparency=trans or 0;f.BorderSizePixel=0;stroke(f,C.DIM,1,8)
end
local function tl(l,size,color,x,font,wrap)
 if not l then return end
 text(l,size,color,x,font);if wrap then l.TextWrapped=true;l.TextTruncate=Enum.TextTruncate.None;l.TextYAlignment=Enum.TextYAlignment.Top end
end
local function tabs(p,prefix,first,last,x,w,y,h,names)
 local n=last-first+1;local tw=(w-8*(n-1))/n
 for i=first,last do
  local b=p:FindFirstChild(prefix..i);if b then
   strip(b);b.AutoButtonColor=false;b.Visible=true
   for _,c in ipairs(b:GetChildren())do if c.Name=="ReferenceIcon" or c.Name=="CategoryIcon" then c:Destroy() end end
   place(b,x+(i-first)*(tw+8),y,tw,h);b.BackgroundColor3=C.INK;b.BackgroundTransparency=.05;stroke(b,C.DIM,1,6)
   local l=b.Label;place(l,6,h>60 and 10 or 0,tw-12,h>60 and 28 or h);text(l,20,C.BONE,Enum.TextXAlignment.Center,BOLD);l.ZIndex=b.ZIndex+2
   if names and names[i-first+1] then l.Text=names[i-first+1] end
   label(b,"Sub","",14,UDim2.fromOffset(6,39),UDim2.fromOffset(tw-12,20),C.MUTED,Enum.TextXAlignment.Center,FONT,b.ZIndex+2).Visible=h>60
   local bar=b:FindFirstChild("Bar") or Instance.new("Frame");bar.Name="Bar";bar.BorderSizePixel=0;bar.BackgroundColor3=C.RED;bar.AnchorPoint=Vector2.new(.5,1)
   bar.Position=UDim2.new(.5,0,1,-1);bar.Size=UDim2.new(1,-24,0,3);bar.ZIndex=b.ZIndex+2;bar.Visible=false;bar.Parent=b
  end
 end
end
PS.Tabs=tabs

-- shared header / backdrop / BACK
local function chrome(p,title,subtitle)
 if p:GetAttribute("Styled") then return false end
 p:SetAttribute("Styled",true)
 local back=Instance.new("Frame");back.Name="Backdrop";back.BackgroundColor3=C.INK;back.BackgroundTransparency=.12;back.BorderSizePixel=0
 back.Position=UDim2.fromOffset(-3000,-3000);back.Size=UDim2.fromOffset(9000,9000);back.ZIndex=0;back.Parent=p
 local vg=Instance.new("UIGradient");vg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(44,6,15)),ColorSequenceKeypoint.new(.5,C.INK),ColorSequenceKeypoint.new(1,Color3.fromRGB(26,4,10))});vg.Rotation=90;vg.Parent=back
 for _,d in ipairs(p:GetDescendants())do
  if d.Name=="OrnamentAtlas" or d.Name=="ThornBorder" or d.Name=="ThornHeader" or d.Name=="ReferenceTexture" or d.Name=="TopShine" then d:Destroy()
  elseif d.Name=="Glow" and d:IsA("GuiObject") then d.Visible=false end
 end
 for _,n in ipairs({"Header","Distress","BrandTagline","RotatePreview","CatalogOutline","TeamPanel"})do hide(p:FindFirstChild(n)) end
 if p:FindFirstChild("Outline") then p.Outline.Enabled=false end
 p.BackgroundTransparency=1
 local logo=p:FindFirstChild("BrandLogo");if logo then place(logo,40,22,250,90);logo.ZIndex=4 end
 local tp=p.TitlePlate;place(tp,X0,26,720,96);tp.BackgroundTransparency=1;if tp:FindFirstChild("Outline")then tp.Outline.Enabled=false end
 local accent=tp:FindFirstChild("Accent") or Instance.new("Frame");accent.Name="Accent";accent.BorderSizePixel=0;accent.BackgroundColor3=C.RED;place(accent,0,8,5,50);accent.ZIndex=6;accent.Parent=tp
 local t=tp.Title;place(t,20,0,700,64);text(t,56,C.BONE,Enum.TextXAlignment.Left,BOLD);t.Text=title;t.ZIndex=6
 local sub=p:FindFirstChild("Subtitle") or Instance.new("TextLabel");sub.Name="Subtitle";sub.Parent=p;sub.Visible=true;sub.ZIndex=6
 place(sub,X0+20,84,760,24);text(sub,18,C.MUTED,Enum.TextXAlignment.Left);sub.Text=subtitle
 local cur=p:FindFirstChild("Currency")
 if cur and cur:FindFirstChild("Balance") then place(cur,1392,40,240,52);cur.BackgroundColor3=C.INK;cur.BackgroundTransparency=.05;stroke(cur,C.RED,1.4,6)
  if cur:FindFirstChild("Sigil")then cur.Sigil.Visible=false end
  if cur:FindFirstChild("MarksArtwork")then place(cur.MarksArtwork,14,12,28,28)end
  place(cur.Balance,50,0,150,52);text(cur.Balance,22,C.BONE,Enum.TextXAlignment.Left,BOLD)
  if cur:FindFirstChild("Info")then place(cur.Info,202,12,28,28);PS.CenterPlus(cur.Info)end
 end
 local ver=p:FindFirstChild("Version");if ver then place(ver,1432,8,200,24);text(ver,11,C.FAINT,Enum.TextXAlignment.Right) end
 local cl=p:FindFirstChild("Close");if cl then place(cl,40,BAR_Y,170,52);Style.Button(cl,"←  BACK",20,false) end
 return true
end
PS.Chrome=chrome

local function preview(p)
 local cp=p:FindFirstChild("CharacterPreview");if not cp then return end
 place(cp,40,128,468,708);strip(cp);cp.BackgroundColor3=Color3.fromRGB(14,7,10);cp.BackgroundTransparency=.15;stroke(cp,C.DIM,1,10)
 local pg=cp:FindFirstChild("PreviewGlow") or Instance.new("UIGradient");pg.Name="PreviewGlow";pg.Rotation=90
 pg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(20,8,12)),ColorSequenceKeypoint.new(.7,Color3.fromRGB(52,10,22)),ColorSequenceKeypoint.new(1,Color3.fromRGB(20,6,10))});pg.Parent=cp
 noArt(cp:FindFirstChild("Scene"))
 cp.AvatarViewport.Position=UDim2.fromOffset(0,0);cp.AvatarViewport.Size=UDim2.fromScale(1,1);cp.AvatarViewport.BackgroundTransparency=1;cp.AvatarViewport.ZIndex=cp.ZIndex+2
 hide(cp:FindFirstChild("Hint"))
 local dh=cp:FindFirstChild("DragHint");if dh then dh.Visible=true;place(dh,0,680,468,24);text(dh,15,C.FAINT,Enum.TextXAlignment.Center);dh.Text="DRAG TO ROTATE";dh.ZIndex=cp.ZIndex+4 end
end

-- ================= SHOP =================
PS.ShopArt={Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(330,186)}
PS.ShopSwatch={Position=UDim2.fromOffset(105,30),Size=UDim2.fromOffset(140,140)}
PS.ShopNumber={Position=UDim2.fromOffset(24,24),Size=UDim2.fromOffset(302,158)}
function PS.Shop(p)
 if not chrome(p,"SHOP","SPEND YOUR MARKS.") then return end
 preview(p)
 tabs(p,"Tab",0,9,X0,CW,128,70,{"NUMBER STYLE","HAIR","AURA","ELIM FX","NOTEBOOK","PEN","BUNDLE","MASK","VISOR","TRAIL"})
 for i=0,4 do hide(p:FindFirstChild("Page"..i)) end
 local co=p:FindFirstChild("CatalogOutline")
 if co then co.BackgroundTransparency=1;for _,d in ipairs(co:GetDescendants())do if d:IsA("UIStroke") then d.Enabled=false elseif d:IsA("GuiObject") then d.Visible=false end end end
 local tm=p:FindFirstChild("TabMarks");if tm then place(tm,1222,40,160,52);Style.Button(tm,"GET MARKS",17,false) end
 local st=p.ShopStatus;place(st,X0,214,CW,34);text(st,22,C.BONE,Enum.TextXAlignment.Left,BOLD);st.ZIndex=6
 for i=0,5 do
  local c=p["Product"..i];local col,row=i%3,i//3
  place(c,X0+col*367,270+row*282,350,266);panel(c);c.ZIndex=4
  hide(c:FindFirstChild("Thumbnail"));hide(c:FindFirstChild("Divider"));hide(c:FindFirstChild("Artwork"))
  local well=c:FindFirstChild("ArtWell") or Instance.new("Frame");well.Name="ArtWell";well.BorderSizePixel=0;well.BackgroundColor3=Color3.fromRGB(26,12,17);well.ZIndex=c.ZIndex+1
  place(well,10,10,330,186);well.Parent=c;local wc=well:FindFirstChild("UICorner") or Instance.new("UICorner");wc.CornerRadius=UDim.new(0,6);wc.Parent=well
  local wg=well:FindFirstChild("UIGradient") or Instance.new("UIGradient");wg.Rotation=90;wg.Color=ColorSequence.new(Color3.fromRGB(46,16,24),Color3.fromRGB(14,7,10));wg.Parent=well
  local pa=c.PendingArt;place(pa,10,10,330,186);pa.ZIndex=c.ZIndex+2
  local n=c.ItemName;place(n,16,214,184,40);text(n,20,C.BONE,Enum.TextXAlignment.Left,BOLD);n.ZIndex=c.ZIndex+3
  local b=c.Buy;place(b,206,214,130,40);Style.Button(b,b.Label.Text,14,false);b.ZIndex=c.ZIndex+12;b.Label.ZIndex=b.ZIndex+2;hide(b:FindFirstChild("Icon"))
  local sel=c.Select;place(sel,0,0,350,266);sel.ZIndex=c.ZIndex+10;sel.BackgroundTransparency=1;sel.Text=""
  for _,d in ipairs(sel:GetDescendants())do if d:IsA("UIStroke") then d.Enabled=false elseif d:IsA("GuiObject") then d.Visible=false end end
 end
 local s=p.Selection;place(s,X0,676,640,160);panel(s)
 tl(s:FindFirstChild("Name"),26,C.BONE,Enum.TextXAlignment.Left,BOLD);place(s:FindFirstChild("Name"),20,12,600,34)
 tl(s.Description,15,C.MUTED,Enum.TextXAlignment.Left,FONT,true);place(s.Description,20,50,600,44)
 place(s.Purchase,20,100,240,46);Style.Button(s.Purchase,s.Purchase.Label.Text,17,true)
 s.Equip.Visible=false
 hide(s:FindFirstChild("Preview"))
 local bd=p.Bundle;place(bd,X0+656,676,428,160);panel(bd)
 if bd:FindFirstChild("Banner") then place(bd.Banner,0,0,428,160);bd.Banner.ScaleType=Enum.ScaleType.Crop;bd.Banner.ImageTransparency=.35
  local bc=bd.Banner:FindFirstChild("UICorner") or Instance.new("UICorner");bc.CornerRadius=UDim.new(0,8);bc.Parent=bd.Banner end
 tl(bd.Title,13,C.MUTED,Enum.TextXAlignment.Left,BOLD);place(bd.Title,18,12,390,20)
 tl(bd:FindFirstChild("Name"),24,C.BONE,Enum.TextXAlignment.Left,BOLD);place(bd:FindFirstChild("Name"),18,96,390,30)
 tl(bd.Status,14,C.RED,Enum.TextXAlignment.Left,BOLD);place(bd.Status,18,126,390,22)
 -- no detail box or featured bundle under the grid: the cards fill the page like the Loadout
 s.Visible=false;bd.Visible=false
 local ms=p.MarksStore;place(ms,X0,214,CW,622);panel(ms)
 hide(ms:FindFirstChild("Title"))
 if ms:FindFirstChild("Balance") then place(ms.Balance,24,20,600,30);text(ms.Balance,18,C.MUTED,Enum.TextXAlignment.Left,BOLD) end
 for k=1,3 do local pk=ms:FindFirstChild("Pack"..k);if pk then
  place(pk,20+(k-1)*355,70,334,325);panel(pk)
  local b=pk:FindFirstChild("Buy");if b then place(b,16,265,302,44);Style.Button(b,"COMING SOON",15,false) end
 end end
 -- paging: wide PREV / NEXT pills with a page counter and dots between them (LoadoutStyle.Pager)
 Style.Pager(p,X0+CW/2)
end

-- ================= CONTRACTS (Quests panel) =================
-- Left: the daily streak card (ring, the 7-day reward calendar, the countdown to new contracts, today's progress)
-- with the daily reward claim under it. Middle: the contract rows for the selected tab. Right: the season card
-- with its milestone track. Bottom: marks earned + CLAIM ALL, and the featured season reward.
-- PS.QuestsUpdate(p, player, tab) fills the parts that change (ReferenceMenusV3 calls it from Refresh / QuestView).
local GOLD,GOLD_LINE=Color3.fromRGB(232,196,120),Color3.fromRGB(120,90,40)
local TILE=Color3.fromRGB(22,11,15)
local DAILY_MARKS={100,150,200,300,400,500,900}
pcall(function() DAILY_MARKS=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall",5):WaitForChild("DailyRewards",5)).Marks end)
local QUEST_INFO={
 Kill3="Mark other players by writing their number.",Kill6="Mark other players by writing their number.",Kill10="Mark other players by writing their number.",
 Write5="Write the right number on someone's visor.",
 Rounds2="Play rounds through to the end, in any mode.",Rounds4="Play rounds through to the end, in any mode.",
 Win1="Be the last one standing.",Top3="Finish a round in the top 3.",Clean1="Reach the end of a round without being marked.",
 Multi3="All in a single round.",Multi5="All in a single round.",Double1="Two eliminations within 10 seconds.",
 Slide30="Slide while you sprint through the city.",Marks300="Marks from eliminations, placings and wins.",
 Play20="Total time in game today.",
 Kill15="A long hunt: mark 15 players today.",Write20="Write 20 correct numbers on other players' visors.",
 Win3="Be the last one standing, three times.",Clean3="Three rounds to the end without being marked once.",
 Top5="Finish in the top 3 in five rounds.",Multi8="Eight eliminations, all in a single round.",
 Double3="Three doubles: two eliminations within 10 seconds each.",Marks1000="Marks from eliminations, placings and wins.",
}
local SEASON_INFO={"Eliminations across the week.","Rounds played to the end this week.","Correct numbers written this week."}
local WEEKLY_INFO={
 W_Kill25="Eliminations across the week.",W_Kill40="A big hunt: 40 eliminations this week.",W_Double5="Two eliminations within 10 seconds, five times.",
 W_Rounds10="Rounds played to the end this week.",W_Win5="Be the last one standing, five times this week.",W_Top10="Finish in the top 3 in ten rounds.",
 W_Write50="Correct numbers written this week.",W_Marks3000="Marks from eliminations, placings and wins.",W_Multi6="Six eliminations, all in a single round.",
}
local SOON_INFO={[1]={"WEEKLY CONTRACTS","Bigger goals that run from Monday to Sunday, with bigger rewards."},
 [3]={"EVENT CONTRACTS","Limited-time contracts for special events and holidays."}}
local MILESTONES={3,7,12,18,24} -- daily contracts finished this week (resets Monday 00:00 UTC)
local function clock(secs)
 return string.format("%02d:%02d:%02d",secs//3600,(secs%3600)//60,secs%60)
end
function PS.Quests(p)
 if not chrome(p,"CONTRACTS","COMPLETE CONTRACTS TO EARN MARKS.  NEW DAILIES EVERY DAY, WEEKLIES EVERY MONDAY.") then return end
 -- two tabs: DAILY and WEEKLY (the weekly contracts are what used to be the season's; there are no event contracts)
 tabs(p,"Tab",0,1,X0,CW,128,70,{"DAILY","WEEKLY"})
 hide(p:FindFirstChild("Tab2"));hide(p:FindFirstChild("Tab3"))
 -- ---------- left column: streak card ----------
 local s=p.Streak;place(s,40,128,468,628);panel(s,.1)
 tl(s.Title,20,C.BONE,Enum.TextXAlignment.Center,BOLD);place(s.Title,20,18,428,30);s.Title.Text="DAILY STREAK"
 place(s.StreakRing,132,54,204,204);place(s.RingFallback,154,76,160,160)
 tl(s.Count,64,C.BONE,Enum.TextXAlignment.Center,BOLD);place(s.Count,159,104,150,75)
 tl(s.DaysCaption,16,C.MUTED,Enum.TextXAlignment.Center,BOLD);place(s.DaysCaption,154,174,160,30);s.DaysCaption.Text="DAYS"
 for i=1,7 do hide(s:FindFirstChild("Day"..i)) end
 hide(s:FindFirstChild("RewardArt"))
 -- the 7-day reward calendar
 local cal=Instance.new("Frame");cal.Name="Calendar";cal.BackgroundTransparency=1;place(cal,20,280,428,84);cal.ZIndex=s.ZIndex+1;cal.Parent=s
 local tw=(428-6*6)/7
 for i=1,7 do
  local t=Instance.new("Frame");t.Name="Tile"..i;t.BackgroundColor3=TILE;t.BorderSizePixel=0;place(t,(i-1)*(tw+6),0,tw,84);t.ZIndex=cal.ZIndex+1;t.Parent=cal
  stroke(t,i==7 and GOLD_LINE or C.DIM,1,6)
  label(t,"Day","DAY "..i,12,UDim2.fromOffset(0,8),UDim2.new(1,0,0,16),i==7 and GOLD or C.MUTED,Enum.TextXAlignment.Center,BOLD,t.ZIndex+1)
  label(t,"Amount",tostring(DAILY_MARKS[i] or 0),21,UDim2.fromOffset(0,28),UDim2.new(1,0,0,26),i==7 and GOLD or C.BONE,Enum.TextXAlignment.Center,BOLD,t.ZIndex+1)
  label(t,"State","MARKS",11,UDim2.fromOffset(0,58),UDim2.new(1,0,0,16),C.FAINT,Enum.TextXAlignment.Center,BOLD,t.ZIndex+1)
 end
 tl(s.NextReward,17,C.BONE,Enum.TextXAlignment.Center,BOLD);place(s.NextReward,20,378,428,26)
 tl(s.ResetCaption,13,C.MUTED,Enum.TextXAlignment.Center);place(s.ResetCaption,20,404,428,22)
 local rule=Instance.new("Frame");rule.Name="Rule";rule.BorderSizePixel=0;rule.BackgroundColor3=C.DIM;place(rule,40,446,388,1);rule.ZIndex=s.ZIndex+1;rule.Parent=s
 -- countdown to the next set of contracts
 label(s,"ResetsHeading","NEW CONTRACTS IN",14,UDim2.fromOffset(20,464),UDim2.fromOffset(428,20),C.MUTED,Enum.TextXAlignment.Center,BOLD,s.ZIndex+2)
 label(s,"ResetsIn","--:--:--",42,UDim2.fromOffset(20,486),UDim2.fromOffset(428,50),C.BONE,Enum.TextXAlignment.Center,BOLD,s.ZIndex+2)
 -- today's progress (one segment per daily contract)
 label(s,"TodayLabel","",14,UDim2.fromOffset(20,548),UDim2.fromOffset(428,20),C.MUTED,Enum.TextXAlignment.Center,BOLD,s.ZIndex+2)
 local sw=(388-3*8)/4
 for i=1,4 do
  local seg=Instance.new("Frame");seg.Name="Seg"..i;seg.BorderSizePixel=0;seg.BackgroundColor3=Color3.fromRGB(40,22,28);place(seg,40+(i-1)*(sw+8),580,sw,8);seg.ZIndex=s.ZIndex+2;seg.Parent=s
  local sc=Instance.new("UICorner");sc.CornerRadius=UDim.new(1,0);sc.Parent=seg
 end
 local d=p.Daily;place(d,40,772,468,64);d.BackgroundTransparency=1;if d:FindFirstChild("Outline") then d.Outline.Enabled=false end
 place(d.Claim,0,0,468,64);Style.Button(d.Claim,d.Claim.Label.Text,18,true)
 -- ---------- contract rows ----------
 for i=0,3 do local r=p:FindFirstChild("Quest"..i);if r then
  place(r,X0,214+i*108,700,96);panel(r)
  local bdp=r:FindFirstChild("Backdrop");if bdp then bdp:Destroy() end
  hide(r:FindFirstChild("RewardSigil"));hide(r:FindFirstChild("RewardDivider"));hide(r:FindFirstChild("MarksArtwork"))
  if r:FindFirstChild("Icon") then place(r.Icon,22,27,42,42) end
  tl(r.Title,20,C.BONE,Enum.TextXAlignment.Left,BOLD);place(r.Title,84,12,430,28)
  if r:FindFirstChild("Description") then tl(r.Description,14,C.MUTED,Enum.TextXAlignment.Left);place(r.Description,84,40,430,20) end
  place(r.Track,84,70,330,8);r.Track.BackgroundColor3=Color3.fromRGB(40,22,28);r.Track.BorderSizePixel=0
  place(r.Fill,84,70,0,8);r.Fill.BackgroundColor3=C.RED;r.Fill.BorderSizePixel=0;r.Fill.ZIndex=r.Track.ZIndex+1
  for _,b in ipairs({r.Track,r.Fill})do local bc=b:FindFirstChild("UICorner") or Instance.new("UICorner");bc.CornerRadius=UDim.new(1,0);bc.Parent=b end
  tl(r.Progress,14,C.MUTED,Enum.TextXAlignment.Left,BOLD);place(r.Progress,426,62,100,24)
  place(r.Claim,540,24,144,48);Style.Button(r.Claim,r.Claim.Label.Text,15,true)
 end end
 hide(p:FindFirstChild("QuestComingSoon"))
 -- weekly / event: a card saying what's coming
 local un=p:FindFirstChild("Unavailable")
 if un then
  place(un,X0,214,700,420);clean(un);un.BackgroundColor3=CARD;un.BackgroundTransparency=0;un.BorderSizePixel=0;stroke(un,C.DIM,1,8)
  text(un,34,C.BONE,Enum.TextXAlignment.Center,BOLD);un.TextYAlignment=Enum.TextYAlignment.Center
  local pad=un:FindFirstChild("UIPadding") or Instance.new("UIPadding");pad.PaddingBottom=UDim.new(0,70);pad.Parent=un
  local soon=label(un,"Sub","",17,UDim2.new(.5,-260,.5,30),UDim2.fromOffset(520,56),C.MUTED,Enum.TextXAlignment.Center,FONT,un.ZIndex+1)
  soon.TextWrapped=true;soon.TextYAlignment=Enum.TextYAlignment.Top
  local pill=Instance.new("Frame");pill.Name="SoonPill";pill.BackgroundColor3=Color3.fromRGB(70,0,18);pill.BorderSizePixel=0
  pill.Position=UDim2.new(.5,-70,.5,-80);pill.Size=UDim2.fromOffset(140,30);pill.ZIndex=un.ZIndex+1;pill.Parent=un;stroke(pill,C.RED,1,15)
  label(pill,"Label","COMING SOON",13,UDim2.new(),UDim2.fromScale(1,1),C.BONE,Enum.TextXAlignment.Center,BOLD,pill.ZIndex+1)
 end
 -- ---------- season card ----------
 local se=p.Season;place(se,1264,214,368,420);panel(se)
 if se:FindFirstChild("Poster") then place(se.Poster,8,8,352,228);se.Poster.ScaleType=Enum.ScaleType.Crop;se.Poster.ImageTransparency=.25
  local pc=se.Poster:FindFirstChild("UICorner") or Instance.new("UICorner");pc.CornerRadius=UDim.new(0,6);pc.Parent=se.Poster end
 tl(se.Heading,15,C.RED,Enum.TextXAlignment.Left,BOLD);place(se.Heading,22,18,320,24);se.Heading.Text="THIS WEEK"
 se.SeasonName.Text="WEEKLY CONTRACTS"
 if se:FindFirstChild("Title") then se.Title.Text="WEEKLY" end
 tl(se.SeasonName,32,C.BONE,Enum.TextXAlignment.Left,BOLD);place(se.SeasonName,22,42,320,40)
 tl(se.Status,13,C.MUTED,Enum.TextXAlignment.Center,BOLD);place(se.Status,12,248,344,24)
 local track=Instance.new("Frame");track.Name="MilestoneTrack";track.BorderSizePixel=0;track.BackgroundColor3=Color3.fromRGB(40,22,28);place(track,48,312,272,4);track.ZIndex=se.ZIndex+1;track.Parent=se
 local tf=Instance.new("Frame");tf.Name="Fill";tf.BorderSizePixel=0;tf.BackgroundColor3=C.RED;tf.Size=UDim2.fromScale(0,1);tf.ZIndex=track.ZIndex+1;tf.Parent=track
 for i=1,5 do local b=se:FindFirstChild("Milestone"..i);if b then
  place(b,26+(i-1)*68,292,44,44);clean(b);b.AutoButtonColor=false;stroke(b,C.DIM,1.2,22);b.ZIndex=se.ZIndex+3
  if b:FindFirstChild("Label") then text(b.Label,15,C.BONE,Enum.TextXAlignment.Center,BOLD);b.Label.ZIndex=b.ZIndex+1 end
  if b:FindFirstChild("Reward") then place(b.Reward,-8,50,60,18);text(b.Reward,12,C.MUTED,Enum.TextXAlignment.Center,BOLD) end
 end end
 label(se,"Hint","",13,UDim2.fromOffset(12,384),UDim2.fromOffset(344,20),C.FAINT,Enum.TextXAlignment.Center,BOLD,se.ZIndex+2)
 -- ---------- totals + featured ----------
 local qt=p.QuestTotal;place(qt,X0,652,520,184);panel(qt)
 tl(qt.Title,15,C.MUTED,Enum.TextXAlignment.Left,BOLD);place(qt.Title,24,18,470,24);qt.Title.Text="TOTAL MARKS EARNED FROM CONTRACTS"
 tl(qt.Value,44,C.BONE,Enum.TextXAlignment.Left,BOLD);place(qt.Value,24,50,470,60)
 place(qt.ViewRewards,24,120,200,46);Style.Button(qt.ViewRewards,"CLAIM ALL",16,true)
 label(qt,"Ready","",15,UDim2.fromOffset(240,120),UDim2.fromOffset(260,46),C.MUTED,Enum.TextXAlignment.Left,BOLD,qt.ZIndex+2)
 local fr=p.FeaturedReward;place(fr,X0+536,652,548,184);panel(fr)
 if fr:FindFirstChild("Art") then place(fr.Art,250,0,298,184);fr.Art.ScaleType=Enum.ScaleType.Crop
  local ac=fr.Art:FindFirstChild("UICorner") or Instance.new("UICorner");ac.CornerRadius=UDim.new(0,8);ac.Parent=fr.Art end
 tl(fr.Title,13,C.MUTED,Enum.TextXAlignment.Left,BOLD);place(fr.Title,22,16,260,20);fr.Title.Text="FEATURED REWARD"
 tl(fr:FindFirstChild("Name"),24,C.RED,Enum.TextXAlignment.Left,BOLD);place(fr:FindFirstChild("Name"),22,40,260,30)
 tl(fr.Description,14,C.MUTED,Enum.TextXAlignment.Left,FONT,true);place(fr.Description,22,74,214,42)
 fr.Description.Text="Finish weekly contracts and reach milestones for up to 1,600 bonus marks, every week."
 if fr:FindFirstChild("Name") then fr:FindFirstChild("Name").Text="WEEKLY REWARDS" end
 place(fr.ViewSeason,22,124,200,44);Style.Button(fr.ViewSeason,"VIEW WEEKLY",16,false)
 -- the countdown ticks while the page is open
 task.spawn(function()
  while p.Parent do
   if p.Visible then
    local left=86400-os.time()%86400
    local l=s:FindFirstChild("ResetsIn");if l then l.Text=clock(left) end
   end
   task.wait(1)
  end
 end)
end
-- the parts of the page that follow your progress
function PS.QuestsUpdate(p,pl,tab)
 if not p:GetAttribute("Styled") then return end
 tab=tab or 0
 local s=p.Streak
 local claimed=pl:GetAttribute("DailyClaimed")==true
 local day=pl:GetAttribute("DailyDay") or 1
 local cal=s:FindFirstChild("Calendar")
 if cal then for i=1,7 do local t=cal:FindFirstChild("Tile"..i);if t then
  local done=i<day or (i==day and claimed);local today=i==day and not claimed
  t.BackgroundColor3=today and Color3.fromRGB(70,6,22) or done and Color3.fromRGB(16,12,13) or TILE
  local st=t:FindFirstChildOfClass("UIStroke");if st then st.Color=today and C.RED or (i==7 and GOLD_LINE or C.DIM);st.Thickness=today and 2 or 1 end
  t.Day.Text=today and "TODAY" or ("DAY "..i);t.Day.TextColor3=today and C.BONE or (i==7 and GOLD or C.MUTED)
  t.Amount.TextTransparency=done and .6 or 0
  t.State.Text=done and "✓ CLAIMED" or "MARKS";t.State.TextColor3=done and C.RED or C.FAINT;t.State.TextSize=done and 10 or 11
 end end end
 local nextDay=claimed and (day%7+1) or day
 s.NextReward.Text=(claimed and "TOMORROW  ·  +" or "TODAY  ·  +")..tostring(DAILY_MARKS[nextDay] or 0).." MARKS"
 -- what's ready to claim, and today's progress
 local ready=claimed and 0 or (DAILY_MARKS[day] or 0)
 local done=0
 for i=1,4 do
  local goal=pl:GetAttribute("Quest"..i.."Goal") or math.huge;local pr=pl:GetAttribute("Quest"..i.."Progress") or 0
  local c=pl:GetAttribute("Quest"..i.."Claimed")==true
  if pr>=goal then done+=1 end
  if pr>=goal and not c then ready+=pl:GetAttribute("Quest"..i.."Reward") or 0 end
  local seg=s:FindFirstChild("Seg"..i);if seg then seg.BackgroundColor3=(pr>=goal) and C.RED or Color3.fromRGB(40,22,28) end
 end
 local tlab=s:FindFirstChild("TodayLabel");if tlab then tlab.Text=done==4 and "ALL 4 DAILY CONTRACTS DONE" or string.format("%d OF 4 DAILY CONTRACTS DONE",done) end
 for i=1,3 do
  local goal=pl:GetAttribute("SeasonQuest"..i.."Goal") or math.huge
  if (pl:GetAttribute("SeasonQuest"..i.."Progress") or 0)>=goal and pl:GetAttribute("SeasonQuest"..i.."Claimed")~=true then ready+=pl:GetAttribute("SeasonQuest"..i.."Reward") or 0 end
 end
 local comp=pl:GetAttribute("SeasonCompletedQuests") or 0
 local mrew={100,150,200,250,500}
 local nextM
 for i,g in ipairs(MILESTONES)do
  local mc=pl:GetAttribute("SeasonMilestone"..i.."Claimed")==true
  if comp>=g and not mc then ready+=mrew[i] end
  if comp<g and not nextM then nextM=i end
  local b=p.Season:FindFirstChild("Milestone"..i)
  if b then local st=b:FindFirstChildOfClass("UIStroke");if st then st.Color=(comp>=g and not mc) and C.RED or C.DIM;st.Thickness=(comp>=g and not mc) and 2 or 1.2 end end
 end
 local qt=p.QuestTotal
 local rl=qt:FindFirstChild("Ready");if rl then rl.Text=ready>0 and ("+"..ready.." MARKS READY") or "NOTHING TO CLAIM";rl.TextColor3=ready>0 and C.BONE or C.FAINT end
 qt.ViewRewards.Active=ready>0;pcall(Style.Claimable,qt.ViewRewards,ready>0)
 -- season milestone track: each milestone sits an equal step apart
 local track=p.Season:FindFirstChild("MilestoneTrack")
 if track then
  local f=0
  for i,g in ipairs(MILESTONES)do
   local prev=MILESTONES[i-1] or 0
   if comp>=g then f=(i-1)/4 else if i>1 and comp>prev then f=(i-2)/4+(comp-prev)/(g-prev)/4 end;break end
  end
  track.Fill.Size=UDim2.fromScale(math.clamp(f,0,1),1)
 end
 local hint=p.Season:FindFirstChild("Hint")
 if hint then
  local claimable=false;for i,g in ipairs(MILESTONES)do if comp>=g and pl:GetAttribute("SeasonMilestone"..i.."Claimed")~=true then claimable=true end end
  hint.Text=claimable and "CLICK A LIT MILESTONE TO CLAIM IT" or (nextM and string.format("NEXT MILESTONE AT %d CONTRACTS  ·  +%d",MILESTONES[nextM],mrew[nextM]) or "EVERY MILESTONE CLAIMED")
  hint.TextColor3=claimable and C.BONE or C.FAINT
 end
 -- row descriptions + finished rows
 for i=1,4 do
  local r=p:FindFirstChild("Quest"..(i-1))
  if r and r.Visible then
   local key=(tab==2 and "SeasonQuest" or "Quest")..i
   local info=tab==2 and (WEEKLY_INFO[pl:GetAttribute(key.."Id") or ""] or SEASON_INFO[i]) or QUEST_INFO[pl:GetAttribute(key.."Id") or ""]
   if info and r:FindFirstChild("Description") then r.Description.Text=info end
   local c=pl:GetAttribute(key.."Claimed")==true
   r.Title.TextColor3=c and C.MUTED or C.BONE
   r.BackgroundTransparency=c and .35 or 0
   if c then r.Claim.Label.Text="✓  CLAIMED" end
  end
 end
 -- the row icons: the same white icons as the main menu's contracts card (skull / clock / eye / clock)
 local SHEET="rbxassetid://104838052460312"
 local RECTS={Vector2.new(290,61),Vector2.new(782,61),Vector2.new(538,61),Vector2.new(782,61)}
 for i=1,4 do
  local r=p:FindFirstChild("Quest"..(i-1));local box=r and r:FindFirstChild("Icon")
  if box then
   if box:IsA("ImageLabel") or box:IsA("ImageButton") then box.ImageTransparency=1 end
   for _,d in ipairs(box:GetDescendants()) do if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Name~="SheetIcon" then d.Visible=false end end
   local si=box:FindFirstChild("SheetIcon") or Instance.new("ImageLabel")
   si.Name="SheetIcon";si.BackgroundTransparency=1;si.Image=SHEET;si.ImageRectOffset=RECTS[i];si.ImageRectSize=Vector2.new(196,196)
   si.ImageColor3=Color3.fromRGB(240,235,232);si.AnchorPoint=Vector2.new(.5,.5);si.Position=UDim2.fromScale(.5,.5);si.Size=UDim2.fromScale(.86,.86)
   si.ZIndex=box.ZIndex+3;si.Visible=true;si.Parent=box
  end
 end
 -- weekly / event
 local un=p:FindFirstChild("Unavailable")
 if un and SOON_INFO[tab] then un.Text=SOON_INFO[tab][1];if un:FindFirstChild("Sub") then un.Sub.Text=SOON_INFO[tab][2] end end
end

-- ================= SETTINGS =================
-- Five tabs. The left card lists the selected tab's settings (one row each: name + hint on the left, the control on
-- the right); the right card says what the page is for and, on CONTROLS, lists the keys that can't be rebound.
-- PS.SettingsTab(p, i) switches pages (ReferenceMenusV3 calls it from the tabs).
local SETTINGS_TABS={
 {"GAMEPLAY",{"Sensitivity","SprintMode","JumpBuffer","Killfeed"},"How MARKED plays: mouse look, how sprinting works and what's on screen during a round."},
 {"AUDIO",{"Volume","MusicVolume","TypingSounds"},"Sound effects and music are set separately. Typing sounds are the clicks while you write a number."},
 {"GRAPHICS",{"LowEnd","ShowStats"},"Low end mode turns off shadows, most lights and effects for a smoother game. It's always on for phones, tablets and consoles."},
 {"CONTROLS",{"SprintKey","SlideKey"},"Pick your sprint and slide keys. Everything else is fixed:"},
 {"ACCESSIBILITY",{"ReducedMotion","Flashes","Captions"},"Calmer camera, no red flashes when someone is marked, and captions for important sounds."},
}
local SETTING_NOTES={
 GAMEPLAY={{"Mouse sensitivity","How fast the camera turns with the mouse."},{"Sprint mode","Hold the sprint key, tap it to toggle, or always run."},
  {"Jump buffering","A jump pressed just before you land still happens."},{"Elimination feed","The list of eliminations in the top right during a round."}},
 AUDIO={{"Sound volume","Footsteps, the city, marks and every other sound effect."},{"Music volume","The menu, lobby and round music."},
  {"Typing sounds","The clicks while you write someone's number."}},
 GRAPHICS={{"Low end mode","No shadows, fewer lights and effects. Use it if the game stutters."},{"Performance stats","FPS, frame time and ping in the top left corner."}},
 ACCESSIBILITY={{"Reduce camera motion","Less camera shake, bob and tilt, and calmer menus."},{"Elimination flashes","The red flash on screen when someone is marked."},
  {"Sound captions","Short captions for important sounds."}},
}
local FIXED_KEYS={{"WASD","Move"},{"SPACE","Jump"},{"Q","Dash"},{"CTRL","Crouch"},{"E","Type a number"},{"ENTER","Mark them"},{"B","First / third person"},{"CAPS","Free the mouse"},{"H","Help"}}
local ROW_X,ROW_Y,ROW_W,ROW_H,ROW_GAP=56,272,748,68,12
local function settingRow(r)
 clean(r);r.BackgroundColor3=Color3.fromRGB(22,11,15);r.BackgroundTransparency=.1;stroke(r,C.DIM,1,6);r.ZIndex=6
 for _,c in ipairs(r:GetDescendants())do if c:IsA("GuiObject") then c.ZIndex=math.max(c.ZIndex,7) end end
 if r:FindFirstChild("Label") then place(r.Label,20,9,420,28);text(r.Label,19,C.BONE,Enum.TextXAlignment.Left,BOLD) end
 if r:FindFirstChild("Hint") then place(r.Hint,20,37,420,22);text(r.Hint,14,C.MUTED,Enum.TextXAlignment.Left) end
 local v=r:FindFirstChild("Value")
 if v then
  local w,h=v.Size.X.Offset,v.Size.Y.Offset
  if r:FindFirstChild("Slider") then w,h=82,38 elseif v:FindFirstChild("SwitchKnob") then w,h=114,38 else w,h=150,40 end
  v.AnchorPoint=Vector2.new(1,.5);v.Position=UDim2.new(1,-16,.5,0);v.Size=UDim2.fromOffset(w,h)
  local vl=v:FindFirstChild("Label");if vl and not v:FindFirstChild("SwitchKnob") then vl.Position=UDim2.new();vl.Size=UDim2.fromScale(1,1);vl.TextYAlignment=Enum.TextYAlignment.Center end
  local sl=r:FindFirstChild("Slider");if sl then sl.AnchorPoint=Vector2.new(1,.5);sl.Position=UDim2.new(1,-16-w-24,.5,0);sl.Size=UDim2.fromOffset(196,32) end
 end
end
function PS.SettingsTab(p,i)
 local tab=SETTINGS_TABS[i] or SETTINGS_TABS[1]
 local o=p.Options
 local shown={}
 for k,id in ipairs(tab[2])do shown[id]=k end
 for _,r in ipairs(o:GetChildren())do
  if r:IsA("GuiObject") then
   local k=shown[r.Name]
   r.Visible=k~=nil
   if k then place(r,ROW_X,ROW_Y+(k-1)*(ROW_H+ROW_GAP),ROW_W,ROW_H) end
  end
 end
 local h=p:FindFirstChild("GameplayHeading");if h then h.Text=tab[1] end
 local info=p:FindFirstChild("SettingsInfo")
 if info then
  info.Title.Text=tab[1];info.Body.Text=tab[3]
  info.Keys.Visible=tab[1]=="CONTROLS"
  local notes=info:FindFirstChild("Notes")
  if notes then
   for _,c in ipairs(notes:GetChildren())do c:Destroy() end
   for k,nt in ipairs(SETTING_NOTES[tab[1]] or {})do
    local row=Instance.new("Frame");row.Name="Note"..k;row.BackgroundColor3=Color3.fromRGB(22,11,15);row.BackgroundTransparency=k%2==0 and 1 or .3
    row.BorderSizePixel=0;place(row,0,(k-1)*72,748,64);row.ZIndex=5;row.Parent=notes
    local rc=Instance.new("UICorner");rc.CornerRadius=UDim.new(0,5);rc.Parent=row
    local gem=Instance.new("Frame");gem.BorderSizePixel=0;gem.BackgroundColor3=C.RED;gem.Rotation=45;place(gem,18,17,8,8);gem.ZIndex=6;gem.Parent=row
    label(row,"Name",nt[1],18,UDim2.fromOffset(40,6),UDim2.fromOffset(690,26),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
    label(row,"Text",nt[2],15,UDim2.fromOffset(40,32),UDim2.fromOffset(690,24),C.MUTED,Enum.TextXAlignment.Left,FONT,6)
   end
   notes.Visible=tab[1]~="CONTROLS"
  end
 end
 p:SetAttribute("SettingsTab",i)
end
function PS.Settings(p)
 if not chrome(p,"SETTINGS","ADJUST YOUR GAME.  CHANGES ARE SAVED WHEN YOU APPLY THEM, OR WHEN YOU LEAVE THIS PAGE.") then return end
 tabs(p,"SectionTab",1,5,40,1592,128,56,{"GAMEPLAY","AUDIO","GRAPHICS","CONTROLS","ACCESSIBILITY"})
 -- one card on the left for the selected page's settings, one on the right about it
 local left=p.GameplayPanel;place(left,40,206,780,630);panel(left,.12)
 for _,n in ipairs({"AudioPanel","ControlsPanel","AccessPanel","AudioHeading","ControlsHeading","AccessHeading","NumberEntryNote"})do hide(p:FindFirstChild(n)) end
 local gh=p:FindFirstChild("GameplayHeading");if gh then place(gh,64,222,700,32);text(gh,24,C.BONE,Enum.TextXAlignment.Left,BOLD);gh.ZIndex=6 end
 local acc=p:FindFirstChild("HeadingAccent") or Instance.new("Frame");acc.Name="HeadingAccent";acc.BorderSizePixel=0;acc.BackgroundColor3=C.RED;place(acc,56,226,4,24);acc.ZIndex=6;acc.Parent=p
 if gh then place(gh,70,222,700,32) end
 local fovRow=p.Options:FindFirstChild("FOV");if fovRow then fovRow:Destroy() end
 for _,r in ipairs(p.Options:GetChildren())do if r:IsA("GuiObject") then settingRow(r) end end
 -- right: about this page (+ the fixed keys on CONTROLS)
 local info=p:FindFirstChild("SettingsInfo") or Instance.new("Frame");info.Name="SettingsInfo";place(info,836,206,796,630);panel(info,.12);info.ZIndex=4;info.Parent=p
 local acc2=info:FindFirstChild("Accent") or Instance.new("Frame");acc2.Name="Accent";acc2.BorderSizePixel=0;acc2.BackgroundColor3=C.RED;place(acc2,20,20,4,24);acc2.ZIndex=6;acc2.Parent=info
 label(info,"Title","",24,UDim2.fromOffset(34,16),UDim2.fromOffset(700,32),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
 local body=label(info,"Body","",17,UDim2.fromOffset(24,62),UDim2.fromOffset(740,70),C.MUTED,Enum.TextXAlignment.Left,FONT,6)
 body.TextWrapped=true;body.TextTruncate=Enum.TextTruncate.None;body.TextYAlignment=Enum.TextYAlignment.Top
 local notes=info:FindFirstChild("Notes") or Instance.new("Frame");notes.Name="Notes";notes.BackgroundTransparency=1;place(notes,24,140,748,470);notes.ZIndex=5;notes.Parent=info
 local keys=info:FindFirstChild("Keys") or Instance.new("Frame");keys.Name="Keys";keys.BackgroundTransparency=1;place(keys,24,130,748,480);keys.ZIndex=5;keys.Parent=info
 for i,kv in ipairs(FIXED_KEYS)do
  local y=(i-1)*50
  local row=keys:FindFirstChild("Key"..i) or Instance.new("Frame");row.Name="Key"..i;row.BackgroundColor3=Color3.fromRGB(22,11,15);row.BackgroundTransparency=i%2==0 and 1 or .3
  row.BorderSizePixel=0;place(row,0,y,748,44);row.ZIndex=5;row.Parent=keys
  local rc=row:FindFirstChildOfClass("UICorner") or Instance.new("UICorner");rc.CornerRadius=UDim.new(0,5);rc.Parent=row
  local cap=row:FindFirstChild("Cap") or Instance.new("Frame");cap.Name="Cap";cap.BackgroundColor3=Color3.fromRGB(34,18,23);cap.BorderSizePixel=0;place(cap,14,7,110,30);cap.ZIndex=6;cap.Parent=row
  stroke(cap,Color3.fromRGB(104,44,58),1,5)
  local g=cap:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient");g.Rotation=90;g.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(165,155,160));g.Parent=cap
  local kl=label(cap,"Key",kv[1],15,UDim2.fromOffset(0,0),UDim2.fromScale(1,1),C.BONE,Enum.TextXAlignment.Center,Font.new("rbxasset://fonts/families/RobotoMono.json",Enum.FontWeight.Bold),7)
  label(row,"Action",kv[2],18,UDim2.fromOffset(144,0),UDim2.fromOffset(580,44),C.BONE,Enum.TextXAlignment.Left,FONT,6)
 end
 place(p.Reset,X0+CW-186-16-186,BAR_Y,186,52);Style.Button(p.Reset,"RESET",18,false)
 place(p.ApplyChanges,X0+CW-186,BAR_Y,186,52);Style.Button(p.ApplyChanges,"APPLY",20,true)
 PS.SettingsTab(p,1)
end

-- ================= CREDITS =================
-- Left: the creator card (avatar, name, special thanks). Right: everything that came from the
-- Roblox Creator Store, in two scrolling columns: music, sound effects, hairstyles, character pieces, nature / map.
-- Names come from each asset's own creator on the Creator Store (looked up when this list was written).
local CREATOR={name="tzn",handle="@tazeno",userId=30217753}
local CREDIT_COLUMNS={
 {
  {"MUSIC","APM Music, through the Roblox Creator Store",{
   {"Strength of Will","Main menu"},{"Remembering You","Lobby"},{"Vanquish the Darkness","Rounds"},
   {"Hell Ride","Rounds"},{"Secret Warrior","Rounds"},{"Growing Tension","Round results"}}},
  {"HAIRSTYLES","Free models from the Creator Store",{
   {"Rush_X","Messy Crop, Side Part"},{"ChloeSkyyx","Long Layers"},{"DIDIgamedev","Shaggy"},{"viorrz","Fluffy"},
   {"xHysek","Spiky"},{"MaybeMaxi6666","Shoulder Length"},{"SinisterUGC","Ponytail"},{"nezko","Bob"},{"derpmeow","Emo Side Ponytail"}}},

 },
 {
  {"SOUND EFFECTS","Creator Store uploads",{
   {"APM Music","Stings and impacts"},{"ProSoundEffects","Whooshes, wind, water, city air"},{"Daily Sounds","Round and menu cues"},
   {"CoreCraft Studio","Menu hover"},{"CoderSays","Cash register"},{"GreaterEinstaff","Unholster"},{"YuvoNet","Landing"},{"TheAngelMGR","Footsteps"},{"yO_eyDev","Trash bags"},
   {"Abyssal Copepod","Wind"},{"fefe575787","Lobby bell"},{"YNazarBroserY, valient1063, shadoex3024","Crows"},{"user392328484895443","Landing"}}},
  {"NATURE & MAP","Free models from the Creator Store",{
   {"Stridity_1234","Cherry, oak, pine and old trees"},{"Letaij","Big oak"},{"Tazuk","Willow"},
   {"Calgacos, Ninjaruton, Mistertitanic44, RBLXImagineer","Ferns"},{"EindaMorra, AerialsAbove, SantinoRenaudt","Bushes"},
   {"awrtya","Vines"},{"narheas, CurbMandrill, RBLXImagineer","Flowers"},{"rstkdev","Old brick texture"}}},
 },
}
function PS.Credits(p)
 if not chrome(p,"CREDITS","MADE BY TZN.  WITH THANKS TO THE CREATORS BELOW.") then return end
 -- the old layout stays (hidden) so nothing that points at it breaks
 for i=0,3 do hide(p:FindFirstChild("Line"..i)) end
 for i=1,6 do hide(p:FindFirstChild("Credit"..i)) end
 for _,n in ipairs({"Thanks","Socials","VersionPanel","CharacterScene"}) do hide(p:FindFirstChild(n)) end
 local root=Instance.new("Frame");root.Name="CreditsContent";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(1672,941);root.ZIndex=3;root.Parent=p
 -- creator card
 local card=Instance.new("Frame");card.Name="Creator";place(card,40,128,468,708);panel(card,.06);card.ZIndex=4;card.ClipsDescendants=true;card.Parent=root
 local wash=Instance.new("Frame");wash.Name="Wash";wash.BorderSizePixel=0;wash.BackgroundColor3=Color3.fromRGB(120,0,28);wash.Size=UDim2.fromOffset(468,260);wash.ZIndex=4;wash.Parent=card
 local wg=Instance.new("UIGradient");wg.Rotation=90;wg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(1,1)});wg.Parent=wash
 label(card,"Eyebrow","CREATED BY",15,UDim2.fromOffset(28,24),UDim2.fromOffset(300,20),C.RED,Enum.TextXAlignment.Left,BOLD,6)
 local av=Instance.new("ImageLabel");av.Name="Avatar";av.BackgroundColor3=Color3.fromRGB(34,8,15);av.BorderSizePixel=0
 av.Image="rbxthumb://type=AvatarHeadShot&id="..CREATOR.userId.."&w=150&h=150";place(av,28,56,136,136);av.ZIndex=6;av.Parent=card
 stroke(av,C.RED,1.5,10)
 label(card,"Name",CREATOR.name,56,UDim2.fromOffset(184,70),UDim2.fromOffset(260,64),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
 label(card,"Handle",CREATOR.handle,19,UDim2.fromOffset(186,134),UDim2.fromOffset(260,24),C.MUTED,Enum.TextXAlignment.Left,FONT,6)
 local rule=Instance.new("Frame");rule.Name="Rule";rule.BorderSizePixel=0;rule.BackgroundColor3=C.DIM;place(rule,28,220,412,1);rule.ZIndex=6;rule.Parent=card
 label(card,"ThanksTitle","SPECIAL THANKS",15,UDim2.fromOffset(28,242),UDim2.fromOffset(300,20),C.RED,Enum.TextXAlignment.Left,BOLD,6)
 local th=label(card,"Thanks","To every player and tester who jumped in early, and to the creators on the Roblox Creator Store whose music, sounds and models are listed here.",17,
  UDim2.fromOffset(28,270),UDim2.fromOffset(412,96),C.MUTED,Enum.TextXAlignment.Left,FONT,6)
 th.TextWrapped=true;th.TextTruncate=Enum.TextTruncate.None;th.TextYAlignment=Enum.TextYAlignment.Top
 label(card,"Version","VER 1.0.0   //   SEASON 1",13,UDim2.fromOffset(28,660),UDim2.fromOffset(412,22),C.FAINT,Enum.TextXAlignment.Left,FONT,6)
 -- the Creator Store columns
 local colW=(CW-16)/2
 for ci,sections in ipairs(CREDIT_COLUMNS) do
  local sf=Instance.new("ScrollingFrame");sf.Name="Column"..ci;place(sf,X0+(ci-1)*(colW+16),128,colW,708);panel(sf,.06);sf.ZIndex=4
  sf.ScrollBarThickness=4;sf.ScrollBarImageColor3=C.RED;sf.ScrollingDirection=Enum.ScrollingDirection.Y
  sf.AutomaticCanvasSize=Enum.AutomaticSize.Y;sf.CanvasSize=UDim2.new();sf.ElasticBehavior=Enum.ElasticBehavior.Never;sf.Parent=root
  local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,26);pad.PaddingRight=UDim.new(0,26);pad.PaddingTop=UDim.new(0,22);pad.PaddingBottom=UDim.new(0,22);pad.Parent=sf
  local ll=Instance.new("UIListLayout");ll.SortOrder=Enum.SortOrder.LayoutOrder;ll.Padding=UDim.new(0,4);ll.Parent=sf
  local order=0
  local function nextOrder() order+=1;return order end
  for si,sec in ipairs(sections) do
   if si>1 then local gap=Instance.new("Frame");gap.Name="Gap";gap.BackgroundTransparency=1;gap.Size=UDim2.new(1,0,0,18);gap.LayoutOrder=nextOrder();gap.Parent=sf end
   local head=Instance.new("Frame");head.Name="Section_"..sec[1];head.BackgroundTransparency=1;head.Size=UDim2.new(1,0,0,sec[2] and 56 or 36);head.LayoutOrder=nextOrder();head.ZIndex=5;head.Parent=sf
   local acc=Instance.new("Frame");acc.Name="Accent";acc.BorderSizePixel=0;acc.BackgroundColor3=C.RED;place(acc,0,4,4,24);acc.ZIndex=6;acc.Parent=head
   label(head,"Title",sec[1],22,UDim2.fromOffset(14,0),UDim2.fromOffset(colW-66,32),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
   if sec[2] then label(head,"Sub",sec[2],14,UDim2.fromOffset(14,32),UDim2.fromOffset(colW-66,20),C.MUTED,Enum.TextXAlignment.Left,FONT,6) end
   for ri,r in ipairs(sec[3]) do
    local row=Instance.new("Frame");row.Name="Row"..ri;row.BackgroundColor3=Color3.fromRGB(24,10,15);row.BackgroundTransparency=ri%2==0 and 1 or .35
    row.BorderSizePixel=0;row.Size=UDim2.new(1,0,0,46);row.LayoutOrder=nextOrder();row.ZIndex=5;row.Parent=sf
    local rc=Instance.new("UICorner");rc.CornerRadius=UDim.new(0,5);rc.Parent=row
    label(row,"Name",r[1],17,UDim2.fromOffset(14,4),UDim2.new(1,-28,0,22),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
    label(row,"Detail",r[2],14,UDim2.fromOffset(14,25),UDim2.new(1,-28,0,18),C.MUTED,Enum.TextXAlignment.Left,FONT,6)
   end
  end
 end
 -- every time the page opens, both lists start from the top
 p:GetPropertyChangedSignal("Visible"):Connect(function()
  if p.Visible then for _,c in ipairs(root:GetChildren())do if c:IsA("ScrollingFrame") then c.CanvasPosition=Vector2.zero end end end
 end)
end

-- ================= HELP =================
-- H: how to play + every control, on the same 1672 x 941 canvas as the other menus (title + subtitle, cards,
-- BACK). Left: HOW TO PLAY in four steps. Right: the controls in four cards (movement, marking, menus, camera),
-- each row a key cap and what it does. The sprint / slide caps follow your key settings (PS.HelpKeys).
local HELP_STEPS={
 {"READ","Get close and look at someone's visor. Their four-digit number is your way in."},
 {"WRITE","Press E (or just start typing) and enter the number. ENTER marks them."},
 {"HIDE","Keep your own visor out of sight. Anyone who reads it can mark you."},
 {"SURVIVE","Move fast, stay unseen and be the last one standing."},
}
-- each row: {keyboard key, what it does, setting it follows, gamepad button, touch control}
local HELP_CARDS={
 {"MOVEMENT",{{"WASD","Move",nil,"L STICK","STICK"},{"SPACE","Jump",nil,"A","JUMP"},{"SHIFT","Sprint","Sprint","L3","RUN"},{"C","Slide","Slide","B","SLIDE"},{"Q","Dash",nil,"X","DASH"},{"CTRL","Crouch",nil,"LT","DUCK"}}},
 {"MARKING",{{"E","Type a number",nil,"Y","#"},{"0 - 9","Enter digits",nil,"R STICK + RB","KEYPAD"},{"ENTER","Mark them",nil,"RB","✓"},{"BACKSPACE","Erase a digit",nil,"LB","⌫"}}},
 {"MENUS",{{"P","Main menu",nil,"SELECT","MENU"},{"F2","Shop",nil,"SELECT","MENU"},{"I","Loadout",nil,"SELECT","MENU"},{"F3","Contracts",nil,"SELECT","MENU"},{"F4","Settings",nil,"SELECT","MENU"},{"TAB","Players",nil,"D-PAD ↓","MENU"},{"K","Lifetime stats (lobby)",nil,"MENU","MENU"},{"H","Help",nil,"D-PAD ↑","?"}}},
 {"CAMERA",{{"B","First / third person",nil,"D-PAD →","—"},{"CAPS","Free the mouse",nil,"—","—"}}},
}
local HELP_WRITE={keyboard="Press E (or just start typing) and enter the number. ENTER marks them.",
 gamepad="Press Y, pick each digit with the right stick and write it with RB. RB again marks them.",
 touch="Tap #, then tap the number on the keypad. ✓ marks them."}
local HELP_CLOSE={keyboard="PRESS  H  TO CLOSE",gamepad="PRESS  D-PAD ↑  OR  B  TO CLOSE",touch="TAP  BACK  TO CLOSE"}
local KEY_FONT=Font.new("rbxasset://fonts/families/RobotoMono.json",Enum.FontWeight.Bold)
local function keyCap(parent,txt,x,y)
 local TS=game:GetService("TextService")
 local w=math.max(40,TS:GetTextSize(txt,15,Enum.Font.RobotoMono,Vector2.new(400,40)).X+22)
 local cap=Instance.new("Frame");cap.Name="KeyCap";cap.BackgroundColor3=Color3.fromRGB(34,18,23);cap.BorderSizePixel=0
 place(cap,x,y,w,30);cap.ZIndex=parent.ZIndex+2;cap.Parent=parent
 local cc=Instance.new("UICorner");cc.CornerRadius=UDim.new(0,5);cc.Parent=cap
 local cs=Instance.new("UIStroke");cs.Color=Color3.fromRGB(104,44,58);cs.Thickness=1;cs.Parent=cap
 local g=Instance.new("UIGradient");g.Rotation=90;g.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(165,155,160));g.Parent=cap
 local l=Instance.new("TextLabel");l.Name="Key";l.BackgroundTransparency=1;l.Text=txt;l.FontFace=KEY_FONT;l.TextSize=15;l.TextColor3=C.BONE
 l.Size=UDim2.fromScale(1,1);l.ZIndex=cap.ZIndex+1;l.Parent=cap
 return cap,w
end
-- the + (get marks) button on the currency pill: its label and glow rings sat a couple of pixels off its box
function PS.CenterPlus(info)
 local l=info:FindFirstChild("Label")
 if l then l.AnchorPoint=Vector2.new(.5,.5);l.Position=UDim2.fromScale(.5,.47);l.Size=UDim2.fromScale(1,1);l.TextXAlignment=Enum.TextXAlignment.Center;l.TextYAlignment=Enum.TextYAlignment.Center end
 local g=info:FindFirstChild("Glow")
 if g then
  g.AnchorPoint=Vector2.new(.5,.5);g.Position=UDim2.fromScale(.5,.5);g.Size=UDim2.fromScale(1,1)
  for _,h in ipairs(g:GetChildren())do
   local k=tonumber(h.Name:match("^Halo(%d)$"))
   if k and h:IsA("GuiObject") then h.AnchorPoint=Vector2.new(.5,.5);h.Position=UDim2.fromScale(.5,.5);h.Size=UDim2.new(1,k*2,1,k*2) end
  end
 end
end
function PS.Help(p)
 if p:GetAttribute("Styled") then return end
 -- the old 380 x 300 card becomes a full menu canvas (Controller lays ReferenceV3 panels out like the leaderboard)
 p.Size=UDim2.fromOffset(1672,941);p:SetAttribute("ReferenceV3",true);p.ClipsDescendants=false
 for _,c in ipairs(p:GetChildren())do if c:IsA("GuiObject") and c.Name~="Close" then c.Visible=false end end
 local tp=p:FindFirstChild("TitlePlate") or Instance.new("Frame");tp.Name="TitlePlate";tp.Parent=p;tp.Visible=true
 local tt=tp:FindFirstChild("Title") or Instance.new("TextLabel");tt.Name="Title";tt.Parent=tp
 local cl=p:FindFirstChild("Close");if cl then cl.Visible=true;local lab=cl:FindFirstChild("Label");if lab then for _,d in ipairs(lab:GetChildren())do if d:IsA("GuiObject") then d.Visible=false end end end end
 if not chrome(p,"HELP","HOW MARKED WORKS, AND EVERY KEY YOU NEED.") then return end
 -- an overlay you can keep moving under: a lighter backdrop so the world shows through between the cards
 local bd=p:FindFirstChild("Backdrop");if bd then bd.BackgroundTransparency=.45 end
 -- (the mouse stays on the camera while it's up: H closes it; BACK is there for touch, or with the mouse freed by ALT)
 local root=Instance.new("Frame");root.Name="HelpContent";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(1672,941);root.ZIndex=3;root.Parent=p
 -- HOW TO PLAY
 local how=Instance.new("Frame");how.Name="HowToPlay";place(how,40,128,468,708);panel(how,.08);how.ZIndex=4;how.Parent=root
 label(how,"Heading","HOW TO PLAY",24,UDim2.fromOffset(28,22),UDim2.fromOffset(400,30),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
 local rule=Instance.new("Frame");rule.Name="Rule";rule.BorderSizePixel=0;rule.BackgroundColor3=C.RED;place(rule,28,58,64,3);rule.ZIndex=6;rule.Parent=how
 for i,s in ipairs(HELP_STEPS)do
  local y=88+(i-1)*136 -- (tighter, so the tutorial button and the tip below fit inside the card)
  if i<#HELP_STEPS then
   local line=Instance.new("Frame");line.Name="Link"..i;line.BorderSizePixel=0;line.BackgroundColor3=C.DIM;place(line,51,y+48,2,88);line.ZIndex=5;line.Parent=how
  end
  local num=Instance.new("Frame");num.Name="Step"..i;num.BackgroundColor3=Color3.fromRGB(70,0,18);num.BorderSizePixel=0;place(num,28,y,48,48);num.ZIndex=6;num.Parent=how
  local nc=Instance.new("UICorner");nc.CornerRadius=UDim.new(1,0);nc.Parent=num
  local ns=Instance.new("UIStroke");ns.Color=C.RED;ns.Thickness=1.5;ns.Parent=num
  label(num,"N",tostring(i),24,UDim2.fromOffset(0,0),UDim2.fromScale(1,1),C.BONE,Enum.TextXAlignment.Center,BOLD,7)
  label(how,"Title"..i,s[1],24,UDim2.fromOffset(92,y+2),UDim2.fromOffset(340,30),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
  local body=label(how,"Body"..i,s[2],17,UDim2.fromOffset(92,y+36),UDim2.fromOffset(340,72),C.MUTED,Enum.TextXAlignment.Left,FONT,6)
  if s[1]=="WRITE" then PS.HelpWriteBody=body end
  body.TextWrapped=true;body.TextTruncate=Enum.TextTruncate.None;body.TextYAlignment=Enum.TextYAlignment.Top
 end
 local tb=Instance.new("TextButton");tb.Name="TutorialButton";tb.Text="";place(tb,28,606,412,46);tb.ZIndex=6;tb.Parent=how
 Style.Button(tb,"PLAY THE TUTORIAL",18,true) -- (StarterPlayerScripts.Tutorial)
 label(how,"Tip","Change the sprint and slide keys in SETTINGS.",15,UDim2.fromOffset(28,664),UDim2.fromOffset(412,22),C.FAINT,Enum.TextXAlignment.Left,FONT,6)
 -- CONTROLS: two columns of cards
 local colW=(CW-16)/2
 local colY={128,128}
 PS.HelpKeyLabels={};PS.HelpCaps={}
 for k,card in ipairs(HELP_CARDS)do
  local col=(k==1 or k==2) and 1 or 2
  local rows=card[2]
  local h=64+#rows*44+10
  local f=Instance.new("Frame");f.Name="Card"..card[1];place(f,X0+(col-1)*(colW+16),colY[col],colW,h);panel(f,.08);f.ZIndex=4;f.Parent=root
  colY[col]+=h+16
  label(f,"Heading",card[1],20,UDim2.fromOffset(22,16),UDim2.fromOffset(300,28),C.BONE,Enum.TextXAlignment.Left,BOLD,6)
  local r=Instance.new("Frame");r.Name="Rule";r.BorderSizePixel=0;r.BackgroundColor3=C.RED;place(r,22,48,40,2);r.ZIndex=6;r.Parent=f
  for j,row in ipairs(rows)do
   local y=62+(j-1)*44
   if j>1 then local sep=Instance.new("Frame");sep.Name="Sep";sep.BorderSizePixel=0;sep.BackgroundColor3=Color3.fromRGB(40,18,24);place(sep,22,y-6,colW-44,1);sep.ZIndex=5;sep.Parent=f end
   local cap=keyCap(f,row[1],22,y+1)
   if row[3] then PS.HelpKeyLabels[row[3]]=cap.Key end
   table.insert(PS.HelpCaps,{cap=cap,keyboard=row[1],gamepad=row[4],touch=row[5],setting=row[3]})
   label(f,"Action"..j,row[2],18,UDim2.fromOffset(160,y),UDim2.fromOffset(colW-182,32),C.BONE,Enum.TextXAlignment.Left,FONT,6)
  end
 end
 PS.HelpCloseHint=label(root,"CloseHint","PRESS  H  TO CLOSE",15,UDim2.fromOffset(X0,BAR_Y+14),UDim2.fromOffset(CW,24),C.FAINT,Enum.TextXAlignment.Right,FONT,6)
end
-- the sprint / slide caps show your current keys (Settings)
local SHORT_HELP={LeftShift="SHIFT",RightShift="R SHIFT",LeftControl="CTRL",RightControl="R CTRL",LeftAlt="ALT",CapsLock="CAPS"}
-- and every cap is relabelled for the device in use (player attribute InputMode: keyboard / gamepad / touch)
function PS.HelpKeys(values)
 local l=PS.HelpKeyLabels;if not l or not values then return end
 local mode=game:GetService("Players").LocalPlayer:GetAttribute("InputMode") or "keyboard"
 local TS=game:GetService("TextService")
 for _,it in ipairs(PS.HelpCaps or {})do
  local txt=it[mode] or it.keyboard
  if mode=="keyboard" and it.setting=="Sprint" and values.SprintKey then txt=SHORT_HELP[values.SprintKey] or tostring(values.SprintKey):upper() end
  if mode=="keyboard" and it.setting=="Slide" and values.SlideKey then txt=SHORT_HELP[values.SlideKey] or tostring(values.SlideKey):upper() end
  if it.cap.Parent then
   it.cap.Key.Text=txt
   it.cap.Size=UDim2.fromOffset(math.min(128,math.max(40,TS:GetTextSize(txt,15,Enum.Font.RobotoMono,Vector2.new(400,40)).X+22)),it.cap.Size.Y.Offset)
  end
 end
 if PS.HelpWriteBody and PS.HelpWriteBody.Parent then PS.HelpWriteBody.Text=HELP_WRITE[mode] or HELP_WRITE.keyboard end
 if PS.HelpCloseHint and PS.HelpCloseHint.Parent then PS.HelpCloseHint.Text=HELP_CLOSE[mode] or HELP_CLOSE.keyboard end
end
return PS
