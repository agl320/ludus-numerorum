-- End-of-round screen (own ScreenGui "VictoryScreen"), shown to everyone who played the round while the match is in
-- its Results phase. Built fresh each time from the result attributes MatchService writes:
--   shared: Phase, RoundId, WinnerId, Winner, WinnerCode, EndsAt
--   each player: ResultRound, ResultPlace, ResultKills, ResultDeaths, ResultCode, ResultXP, ResultCoins,
--                ResultNumbers, ResultSurvival
-- Layout (1600x900 stage, fitted to the screen):
--   backdrop painting + vignette | VICTORY / DEFEAT / DRAW title | winner on a lit plinth (their real character,
--   visor lit with their number, slowly turning) | standings | your round + rewards counting up | LOBBY / STAY
local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local V={};V.__index=V
local RED=Color3.fromRGB(255,24,58)
local DEEP=Color3.fromRGB(96,0,16)
local BONE=Color3.fromRGB(240,230,222)
local MUTED=Color3.fromRGB(168,146,148)
local DIM=Color3.fromRGB(70,50,54)
local GOLD=Color3.fromRGB(255,200,104)
local PANEL=Color3.fromRGB(12,7,9)
local SERIF=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold)
local SERIF_R=Font.new("rbxasset://fonts/families/AccanthisADFStd.json")
local LABEL=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold)
local BODY=Font.new("rbxasset://fonts/families/Guru.json")
local MONO=Font.new("rbxasset://fonts/families/RobotoMono.json",Enum.FontWeight.Bold)
local W,H=1600,900

-- the winner's number in the NUMBER STYLE they wear: on their visor (drawn over the viewport, where SurfaceGuis don't
-- render) and on the name plate
local NumberStyles=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NumberStyles"))
local function drawVisor(Preview,vp,cam,model,style,code)
 if not Preview.VisorPanels(model) then error("no visor") end
 local nf=model:FindFirstChild("NumberForehead");if nf then nf:Destroy() end
 local ov=Instance.new("Frame");ov.Name="VisorOverlay";ov.BackgroundTransparency=1;ov.Size=UDim2.fromScale(1,1);ov.ZIndex=vp.ZIndex+1;ov.Parent=vp
 local cells={}
 -- re-projected every frame so the number stays glued to the visor while the winner sways on the plinth
 local function update()
  local panels=Preview.VisorPanels(model);if not panels then ov.Visible=false return end
  local size=vp.AbsoluteSize;if size.X<2 then return end
  ov.Visible=true
  local unit=vp.Size.Y.Offset>0 and vp.Size.Y.Offset/size.Y or 1
  local tanf=math.tan(math.rad(cam.FieldOfView)/2);local aspect=size.X/size.Y
  local function proj(p)
   local l=cam.CFrame:PointToObjectSpace(p);if l.Z>-0.05 then return nil end
   return Vector2.new((0.5+l.X/(-l.Z*tanf*aspect)/2)*size.X,(0.5-l.Y/(-l.Z*tanf)/2)*size.Y)
  end
  for i,pn in ipairs(panels)do
   local cf,w,h=pn[1],pn[2],pn[3]
   local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
   local ok=cf.LookVector:Dot((cam.CFrame.Position-cf.Position).Unit)>0.15
   if ok then
    for _,c in ipairs({Vector3.new(-w/2,-h/2,0),Vector3.new(w/2,-h/2,0),Vector3.new(-w/2,h/2,0),Vector3.new(w/2,h/2,0)})do
     local p=proj(cf*c);if not p then ok=false;break end
     minX,minY,maxX,maxY=math.min(minX,p.X),math.min(minY,p.Y),math.max(maxX,p.X),math.max(maxY,p.Y)
    end
   end
   local cell=cells[i]
   if ok and not cell then
    cell=Instance.new("Frame");cell.Name="Cell"..i;cell.BackgroundTransparency=1;cell.ZIndex=ov.ZIndex;cell.Parent=ov;cells[i]=cell
    NumberStyles.DrawScaled(cell,string.sub(code,i,i),style,math.max((maxY-minY)*unit,4))
    for _,d in ipairs(cell:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=ov.ZIndex end end
   end
   if cell then
    cell.Visible=ok
    if ok then
     cell.Position=UDim2.fromScale(minX/size.X,minY/size.Y);cell.Size=UDim2.fromScale((maxX-minX)/size.X,(maxY-minY)/size.Y)
    end
   end
  end
 end
 update()
 if not next(cells) then ov:Destroy() error("visor not visible") end
 return update
end
local function ease(t,s,d)return TweenInfo.new(t,s or Enum.EasingStyle.Quart,d or Enum.EasingDirection.Out)end
local function tween(o,info,props)local t=Tween:Create(o,info,props);t:Play();return t end
local function new(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function text(parent,str,font,size,color,props)
 local l=new("TextLabel",{BackgroundTransparency=1,Text=str,FontFace=font,TextSize=size,TextColor3=color,RichText=true},parent)
 for k,v in pairs(props or {})do l[k]=v end;return l
end
local function spaced(s)return (s:upper():gsub(".","%0 ")):sub(1,-2)end
local function valid(v)return type(v)=="string"and v~=""and v~="rbxassetid://0"and v~="0"end
local function ordinal(n)
 if not n or n<1 then return "—" end
 local s=(n%100>=11 and n%100<=13)and "TH" or ({"ST","ND","RD"})[n%10] or "TH"
 return n..s
end
local function clock(s)s=math.max(0,math.floor(s or 0));return string.format("%d:%02d",s//60,s%60)end
-- a dark panel with a thin border and a red top hairline
local function panel(parent,props)
 local f=new("Frame",{BackgroundColor3=PANEL,BackgroundTransparency=.12,BorderSizePixel=0},parent)
 for k,v in pairs(props)do f[k]=v end
 new("UICorner",{CornerRadius=UDim.new(0,6)},f)
 new("UIStroke",{Color=DIM,Thickness=1,Transparency=.2},f)
 local top=new("Frame",{BorderSizePixel=0,BackgroundColor3=RED,Size=UDim2.new(1,-24,0,2),Position=UDim2.fromOffset(12,0)},f)
 new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})},top)
 return f
end

function V.new(view)
 local self=setmetatable({view=view,player=view.player,state=view.shared,conns={}},V)
 local gui=Instance.new("ScreenGui");gui.Name="VictoryScreen";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=30
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=self.player:WaitForChild("PlayerGui")
 self.gui=gui
 local function check()
  if self.state:GetAttribute("Phase")=="Results"then
   -- the result attributes land just before the phase flips; give them a moment to replicate
   task.delay(.35,function()if self.state:GetAttribute("Phase")=="Results"then self:Show()end end)
  else self:Hide()end
 end
 self.state:GetAttributeChangedSignal("Phase"):Connect(check)
 self.player:GetAttributeChangedSignal("InMatch"):Connect(function()if not self.player:GetAttribute("InMatch")then self:Hide()end end)
 view.gui.Destroying:Connect(function()gui:Destroy()end)
 check()
 return self
end

function V:Hide()
 for _,c in ipairs(self.conns)do c:Disconnect()end;table.clear(self.conns)
 pcall(function()RunService:UnbindFromRenderStep("VictoryCursor")end)
 if self.root then
  local root=self.root;self.root=nil
  -- fade to black, then remove
  local cover=root:FindFirstChild("Cover")
  if cover then tween(cover,ease(.3),{BackgroundTransparency=0})end
  task.delay(.32,function()root:Destroy();if not self.root then self.gui.Enabled=false end end)
 end
end

function V:Show(force)
 local p=self.player;local round=self.state:GetAttribute("RoundId")
 if not force and(p:GetAttribute("InMatch")~=true or p:GetAttribute("ResultRound")~=round)then return end
 self:Hide()
 if self.root then self.root:Destroy()end
 self.gui.Enabled=true
 local reduced=self.view.values.ReducedMotion==true
 -- a plain Frame (a CanvasGroup renders to a texture and made the whole screen blurry); it fades in from black
 -- with a cover on top instead
 local root=new("Frame",{Name="Root",BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0,BorderSizePixel=0,Size=UDim2.fromScale(1,1)},self.gui)
 self.root=root
 local cover=new("Frame",{Name="Cover",BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=100},root)
 tween(cover,ease(.5),{BackgroundTransparency=1})
 -- the cursor has to be free and visible while this is up (first person locks and hides it every frame)
 local UIS=game:GetService("UserInputService")
 pcall(function()RunService:UnbindFromRenderStep("VictoryCursor")end)
 RunService:BindToRenderStep("VictoryCursor",Enum.RenderPriority.Last.Value+5,function()
  if self.root then UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true end
 end)
 local ids=self.view.gui:FindFirstChild("ArtworkAssetIds")
 local function art(key)local v=ids and ids:FindFirstChild(key);return v and v.Value or ""end
 -- backdrop: the dark city painting, slowly pushing in, with a red floor glow and vignette
 local back=new("ImageLabel",{BackgroundTransparency=1,Image=valid(art("VictoryTitle"))and art("VictoryTitle")or art("MenuBackground"),ScaleType=Enum.ScaleType.Crop,
  ImageTransparency=.42,ImageColor3=Color3.fromRGB(255,190,196),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1)},root)
 local backScale=new("UIScale",{Scale=reduced and 1 or 1.08},back)
 tween(backScale,ease(12,Enum.EasingStyle.Sine),{Scale=1})
 local shade=new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.new(0,0,0),Size=UDim2.fromScale(1,1),BackgroundTransparency=.05},root)
 new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.45,.75),NumberSequenceKeypoint.new(1,.15)})},shade)
 local glow=new("Frame",{BorderSizePixel=0,BackgroundColor3=RED,Size=UDim2.fromScale(1,.5),Position=UDim2.fromScale(0,.5),BackgroundTransparency=.5},root)
 new("UIGradient",{Rotation=-90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(1,1)})},glow)
 -- stage, fitted to the screen
 local stage=new("Frame",{Name="Stage",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(W,H)},root)
 local fit=new("UIScale",{},stage)
 local function refit()local v=self.gui.AbsoluteSize;fit.Scale=math.max(.3,math.min(v.X/W,v.Y/H))end
 refit();table.insert(self.conns,self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit))

 -- ---------- data ----------
 local winnerId=self.state:GetAttribute("WinnerId")or 0
 local winner=winnerId>0 and Players:GetPlayerByUserId(winnerId)or nil
 local won=winnerId==p.UserId
 local draw=winnerId==0
 local players={}
 for _,q in ipairs(Players:GetPlayers())do if q:GetAttribute("ResultRound")==round then table.insert(players,q)end end
 -- AI fighters (ServerScriptService.BotService) that were in the round: stand-ins with the same result fields
 do
  local raw=self.state:GetAttribute("BotResults")
  local ok,rows=pcall(function()return game:GetService("HttpService"):JSONDecode(raw)end)
  if type(raw)=="string" and raw~="" and ok and type(rows)=="table" then
   local folder=workspace:FindFirstChild("MatchBots")
   local looks=game:GetService("ReplicatedStorage"):FindFirstChild("BotLooks")
   for _,b in ipairs(rows)do
    local attrs={ResultPlace=b.Place,ResultKills=b.Kills,ResultDeaths=b.Deaths,ResultCode=b.Code,ResultRound=round}
    -- the still copy BotService keeps of each bot's dressed body (the real one is gone a few seconds after an
    -- elimination); a live body only as a fallback
    local body=looks and looks:FindFirstChild(tostring(b.Id))
    if not body and folder then for _,m in ipairs(folder:GetChildren())do if m:GetAttribute("BotId")==b.Id then body=m end end end
    table.insert(players,{UserId=b.Id,DisplayName=b.Name,Name=b.Name,IsBot=true,Character=body,GetAttribute=function(_,k)if attrs[k]~=nil then return attrs[k] end return body and body:GetAttribute(k)end})
   end
  end
 end
 table.sort(players,function(a,b)
  local pa,pb=a:GetAttribute("ResultPlace")or 99,b:GetAttribute("ResultPlace")or 99
  if pa~=pb then return pa<pb end
  return(a:GetAttribute("ResultKills")or 0)>(b:GetAttribute("ResultKills")or 0)
 end)
 if not winner and winnerId<0 then for _,q in ipairs(players)do if q.UserId==winnerId then winner=q end end end
 local myPlace=p:GetAttribute("ResultPlace")

 -- ---------- header ----------
 text(stage,spaced("round "..tostring(round or "").."  /  results"),LABEL,16,MUTED,{Position=UDim2.fromOffset(60,44),Size=UDim2.fromOffset(500,20),TextXAlignment=Enum.TextXAlignment.Left})
 local titleText=won and "VICTORY" or draw and "DRAW" or "DEFEAT"
 local titleColor=won and BONE or draw and MUTED or Color3.fromRGB(230,200,204)
 local titleRow=new("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(52,62),Size=UDim2.fromOffset(900,140)},stage)
 new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder},titleRow)
 for i=1,#titleText do
  local ch=titleText:sub(i,i)
  -- each letter is its own label (sized to the glyph) so it can rise in on its own
  local holder=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(0,140),AutomaticSize=Enum.AutomaticSize.X,LayoutOrder=i},titleRow)
  local l=text(holder,ch,SERIF,138,titleColor,{Size=UDim2.fromOffset(0,140),AutomaticSize=Enum.AutomaticSize.X,TextTransparency=1,Position=UDim2.fromOffset(0,reduced and 0 or 36)})
  new("UIStroke",{Color=won and RED or DEEP,Thickness=won and 2 or 1.5,Transparency=won and .15 or .4},l)
  task.delay((reduced and 0 or .25)+(i-1)*.06,function()
   if l.Parent then tween(l,ease(.55,Enum.EasingStyle.Back),{TextTransparency=0,Position=UDim2.fromOffset(0,0)})end
  end)
 end
 local tag=won and "YOU WON THE ROUND" or draw and "NO ONE STOOD ALONE" or (winner and (winner.DisplayName:upper().." TOOK THE ROUND") or "ROUND OVER")
 local sub=text(stage,tag,SERIF_R,30,won and RED or MUTED,{Position=UDim2.fromOffset(60,200),Size=UDim2.fromOffset(820,36),TextXAlignment=Enum.TextXAlignment.Left,TextTransparency=1})
 task.delay(.7,function()if sub.Parent then tween(sub,ease(.5),{TextTransparency=0})end end)
 -- placement badge (top right)
 local badge=panel(stage,{Position=UDim2.fromOffset(W-340,52),Size=UDim2.fromOffset(280,120)})
 text(badge,spaced("your place"),LABEL,14,MUTED,{Position=UDim2.fromOffset(22,16),Size=UDim2.fromOffset(240,18),TextXAlignment=Enum.TextXAlignment.Left})
 text(badge,ordinal(myPlace),SERIF,62,myPlace==1 and GOLD or BONE,{Position=UDim2.fromOffset(20,36),Size=UDim2.fromOffset(160,70),TextXAlignment=Enum.TextXAlignment.Left})
 text(badge,"OF "..#players,LABEL,20,MUTED,{Position=UDim2.fromOffset(170,62),Size=UDim2.fromOffset(90,30),TextXAlignment=Enum.TextXAlignment.Left})

 -- ---------- winner showcase ----------
 local show=new("Frame",{Name="Winner",BackgroundTransparency=1,Position=UDim2.fromOffset(40,250),Size=UDim2.fromOffset(560,600)},stage)
 local skull=new("ImageLabel",{BackgroundTransparency=1,Image=art("CrownedSkullDetailed"),ImageTransparency=.86,ImageColor3=RED,ScaleType=Enum.ScaleType.Fit,
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,250),Size=UDim2.fromOffset(460,460)},show)
 skull.Visible=valid(skull.Image)
 -- plinth light
 local spot=new("Frame",{BorderSizePixel=0,BackgroundColor3=RED,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,0,500),Size=UDim2.fromOffset(420,90),BackgroundTransparency=.35},show)
 new("UICorner",{CornerRadius=UDim.new(1,0)},spot)
 new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.1),NumberSequenceKeypoint.new(1,1)})},spot)
 local vp=new("ViewportFrame",{BackgroundTransparency=1,Size=UDim2.fromOffset(560,520),Ambient=Color3.fromRGB(175,145,150),LightColor=Color3.fromRGB(255,232,226),
  LightDirection=Vector3.new(-.5,-.6,-.6)},show)
 local world=new("WorldModel",{},vp)
 local cam=new("Camera",{FieldOfView=26},vp);vp.CurrentCamera=cam
 local model
 local subject=winner or(draw and players[1])or nil
 -- the number on the plate: the winner's, or (a draw) the top of the board's own
 local plateCode=tostring(self.state:GetAttribute("WinnerCode")or "----")
 if (plateCode=="----" or plateCode=="") and subject then plateCode=tostring(subject:GetAttribute("ResultCode")or "----") end
  local visorUpdate
 if subject and subject.Character then
  local ch=subject.Character
  local was=ch.Archivable;ch.Archivable=true
  local ok,c=pcall(function()return ch:Clone()end);ch.Archivable=was
  if ok and c then
   model=c
   for _,d in ipairs(c:GetDescendants())do
    if d:IsA("LuaSourceContainer")or d:IsA("Sound")or d:IsA("BillboardGui")or d:IsA("ForceField")or d:IsA("ParticleEmitter")then d:Destroy()
    elseif d:IsA("BasePart")then d.Anchored=true;d.CanCollide=false;d.LocalTransparencyModifier=0 end
   end
   local hum=c:FindFirstChildOfClass("Humanoid");if hum then hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
   c.Parent=world;c:PivotTo(CFrame.new())
   local Preview=require(self.view.gui:WaitForChild("LoadoutPreview"))
   pcall(Preview.Solve,c,2) -- confident pose
   -- SurfaceGuis don't draw in a viewport: light the visor with the winner's number in neon instead
   local code=plateCode
   local style=NumberStyles.Of(subject)
   task.defer(function()
    for _=1,90 do if vp.AbsoluteSize.X>1 and vp.Parent then break end task.wait() end
    local ok,upd=pcall(drawVisor,Preview,vp,cam,c,style,code)
     if ok then visorUpdate=upd else pcall(Preview.Visor,c,code) end
   end)
   local cf,size=c:GetBoundingBox()
   local h=math.max(size.Y,4)
   local dist=(h*.58)/math.tan(math.rad(13))
   cam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(0,h*.04,-dist),cf.Position+Vector3.new(0,-h*.02,0))
  end
 end
 if not model then
  text(show,draw and "NO WINNER" or "—",SERIF,40,MUTED,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,260),Size=UDim2.fromOffset(400,60)})
 end
 -- name plate
 local plate=panel(show,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,500),Size=UDim2.fromOffset(440,92)})
 text(plate,spaced(draw and "top of the board" or "winner"),LABEL,13,GOLD,{Position=UDim2.fromOffset(22,12),Size=UDim2.fromOffset(300,16),TextXAlignment=Enum.TextXAlignment.Left})
 text(plate,(subject and subject.DisplayName or "—"):upper(),SERIF,34,BONE,{Position=UDim2.fromOffset(22,30),Size=UDim2.fromOffset(270,44),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
 local led=new("Frame",{BackgroundColor3=Color3.fromRGB(8,3,5),AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-18,.5,4),Size=UDim2.fromOffset(122,48)},plate)
 new("UICorner",{CornerRadius=UDim.new(0,4)},led);new("UIStroke",{Color=RED,Thickness=1,Transparency=.4},led)
 local ledText=text(led,plateCode,MONO,30,RED,{Size=UDim2.fromScale(1,1)})
 new("UIStroke",{Color=Color3.fromRGB(255,120,130),Thickness=1,Transparency=.6},ledText)
 if subject then
  task.defer(function()
   for _=1,90 do if ledText.AbsoluteSize.X>1 then break end task.wait() end
   pcall(NumberStyles.Skin,ledText,NumberStyles.Of(subject),ledText.Text)
  end)
 end

 -- ---------- standings ----------
 local shown=math.min(8,#players)
 local board=panel(stage,{Position=UDim2.fromOffset(640,250),Size=UDim2.fromOffset(500,math.max(190,62+shown*62))})
 text(board,spaced("standings"),LABEL,15,MUTED,{Position=UDim2.fromOffset(24,18),Size=UDim2.fromOffset(300,18),TextXAlignment=Enum.TextXAlignment.Left})
 for i,h in ipairs({{"ELIMS",330},{"DEATHS",400}})do
  text(board,h[1],LABEL,13,MUTED,{Position=UDim2.fromOffset(h[2],19),Size=UDim2.fromOffset(60,16)})
 end
 for i=1,math.min(8,#players)do
  local q=players[i];local me=q==p;local place=q:GetAttribute("ResultPlace")or i
  local row=new("Frame",{BackgroundColor3=me and Color3.fromRGB(80,6,20)or Color3.fromRGB(22,14,17),BackgroundTransparency=me and .15 or .35,BorderSizePixel=0,
   Position=UDim2.fromOffset(16,46+(i-1)*62),Size=UDim2.fromOffset(468,54)},board)
  new("UICorner",{CornerRadius=UDim.new(0,5)},row)
  if me then new("UIStroke",{Color=RED,Thickness=1,Transparency=.3},row)end
  text(row,tostring(place),SERIF,30,place==1 and GOLD or place<=3 and BONE or MUTED,{Position=UDim2.fromOffset(6,0),Size=UDim2.fromOffset(40,54)})
  local av=new("ImageLabel",{BackgroundColor3=Color3.fromRGB(30,20,24),Position=UDim2.fromOffset(50,7),Size=UDim2.fromOffset(40,40)},row)
  new("UICorner",{CornerRadius=UDim.new(1,0)},av)
  if typeof(q)=="table" or (q.UserId or 0)<=0 then
   -- bots have no Roblox headshot: a small 3D portrait of their body instead
   local ch=q.Character
   local head=ch and ch:FindFirstChild("Head")
   if head then
    local was=ch.Archivable;ch.Archivable=true
    local ok,c=pcall(function()return ch:Clone()end);ch.Archivable=was
    if ok and c then
     local pv=new("ViewportFrame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Ambient=Color3.fromRGB(170,150,150),LightColor=Color3.fromRGB(255,236,230),LightDirection=Vector3.new(-.4,-.5,-.8)},av)
     new("UICorner",{CornerRadius=UDim.new(1,0)},pv)
     local wm=new("WorldModel",{},pv)
     for _,d in ipairs(c:GetDescendants())do
      if d:IsA("LuaSourceContainer")or d:IsA("Sound")or d:IsA("BillboardGui")or d:IsA("ParticleEmitter")then d:Destroy()
      elseif d:IsA("BasePart")then d.Anchored=true;d.CanCollide=false;d.Transparency=(d.Name=="HumanoidRootPart")and 1 or math.min(d.Transparency,d.Transparency>=.99 and 1 or 0) end
     end
     local hm=c:FindFirstChildOfClass("Humanoid");if hm then hm.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
     c.Parent=wm
     local h=c:FindFirstChild("Head")or head
     local pc=new("Camera",{FieldOfView=32},pv);pv.CurrentCamera=pc
     local at=h.Position+Vector3.new(0,-.15,0)
     pc.CFrame=CFrame.lookAt(at+h.CFrame.LookVector*2.6+Vector3.new(0,.15,0),at)
    end
   end
  else
   task.spawn(function()
    local ok,url=pcall(function()return Players:GetUserThumbnailAsync(q.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)end)
    if ok and av.Parent then av.Image=url end
   end)
  end
  text(row,q.DisplayName:upper(),SERIF,22,me and BONE or Color3.fromRGB(220,206,206),{Position=UDim2.fromOffset(102,6),Size=UDim2.fromOffset(200,26),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
  text(row,"#"..tostring(q:GetAttribute("ResultCode")or "----"),MONO,14,RED,{Position=UDim2.fromOffset(102,30),Size=UDim2.fromOffset(120,18),TextXAlignment=Enum.TextXAlignment.Left,TextTransparency=.15})
  text(row,tostring(q:GetAttribute("ResultKills")or 0),SERIF,26,BONE,{Position=UDim2.fromOffset(314,0),Size=UDim2.fromOffset(60,54)})
  text(row,tostring(q:GetAttribute("ResultDeaths")or 0),SERIF,26,MUTED,{Position=UDim2.fromOffset(384,0),Size=UDim2.fromOffset(60,54)})
  -- rows slide in one after another
  row.Position=row.Position+UDim2.fromOffset(reduced and 0 or 40,0);row.BackgroundTransparency=1
  task.delay(.6+i*.07,function()
   if row.Parent then tween(row,ease(.45),{Position=UDim2.fromOffset(16,46+(i-1)*62),BackgroundTransparency=me and .15 or .35})end
  end)
 end

 -- ---------- your round ----------
 local mine=panel(stage,{Position=UDim2.fromOffset(1180,250),Size=UDim2.fromOffset(380,400)})
 text(mine,spaced("your round"),LABEL,15,MUTED,{Position=UDim2.fromOffset(24,18),Size=UDim2.fromOffset(300,18),TextXAlignment=Enum.TextXAlignment.Left})
 local stats={
  {"ELIMINATIONS",p:GetAttribute("ResultKills")or 0},
  {"DEATHS",p:GetAttribute("ResultDeaths")or 0},
  {"NUMBERS WRITTEN",p:GetAttribute("ResultNumbers")or 0},
  {"SURVIVED",clock(p:GetAttribute("ResultSurvival"))},
 }
 for i,s in ipairs(stats)do
  local col,rowI=(i-1)%2,(i-1)//2
  local tile=new("Frame",{BackgroundColor3=Color3.fromRGB(24,15,18),BackgroundTransparency=.3,BorderSizePixel=0,Position=UDim2.fromOffset(18+col*176,48+rowI*92),Size=UDim2.fromOffset(168,82)},mine)
  new("UICorner",{CornerRadius=UDim.new(0,5)},tile)
  text(tile,tostring(s[2]),SERIF,38,BONE,{Position=UDim2.fromOffset(14,8),Size=UDim2.fromOffset(150,44),TextXAlignment=Enum.TextXAlignment.Left})
  text(tile,s[1],LABEL,12,MUTED,{Position=UDim2.fromOffset(14,54),Size=UDim2.fromOffset(150,16),TextXAlignment=Enum.TextXAlignment.Left})
 end
 -- rewards count up
 local xp,marks=p:GetAttribute("ResultXP")or 0,p:GetAttribute("ResultCoins")or 0
 local rewards=new("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(18,244),Size=UDim2.fromOffset(344,140)},mine)
 text(rewards,spaced("earned"),LABEL,13,GOLD,{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(200,16),TextXAlignment=Enum.TextXAlignment.Left})
 local xpL=text(rewards,"+0 XP",SERIF,34,BONE,{Position=UDim2.fromOffset(0,22),Size=UDim2.fromOffset(160,48),TextXAlignment=Enum.TextXAlignment.Left,TextScaled=false})
 local mkL=text(rewards,"+0 MARKS",SERIF,34,GOLD,{Position=UDim2.fromOffset(164,22),Size=UDim2.fromOffset(180,48),TextXAlignment=Enum.TextXAlignment.Right})
 -- level bar
 local level=p:GetAttribute("Level")or 1;local into=p:GetAttribute("LevelXP")or 0;local goal=math.max(1,p:GetAttribute("LevelGoal")or 300)
 text(rewards,"LV. "..level,LABEL,16,BONE,{Position=UDim2.fromOffset(0,86),Size=UDim2.fromOffset(80,18),TextXAlignment=Enum.TextXAlignment.Left})
 text(rewards,into.." / "..goal.." XP",LABEL,14,MUTED,{Position=UDim2.fromOffset(180,86),Size=UDim2.fromOffset(164,18),TextXAlignment=Enum.TextXAlignment.Right})
 local track=new("Frame",{BackgroundColor3=Color3.fromRGB(34,22,26),BorderSizePixel=0,Position=UDim2.fromOffset(0,110),Size=UDim2.fromOffset(344,8)},rewards)
 new("UICorner",{CornerRadius=UDim.new(1,0)},track)
 local fill=new("Frame",{BackgroundColor3=RED,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track)
 new("UICorner",{CornerRadius=UDim.new(1,0)},fill)
 task.delay(1.1,function()
  if not fill.Parent then return end
  tween(fill,ease(1.2),{Size=UDim2.fromScale(math.clamp(into/goal,0,1),1)})
  local t0=os.clock()
  local c;c=RunService.RenderStepped:Connect(function()
   if not xpL.Parent then c:Disconnect();return end
   local k=math.clamp((os.clock()-t0)/1.1,0,1);k=1-(1-k)^3
   xpL.Text="+"..math.floor(xp*k+.5).." XP";mkL.Text="+"..math.floor(marks*k+.5).." MARKS"
   if k>=1 then c:Disconnect()end
  end)
 end)

 -- ---------- buttons + countdown ----------
 local function button(textStr,primary,x)
  local b=new("TextButton",{AutoButtonColor=false,Modal=true,Text="",BackgroundColor3=primary and Color3.fromRGB(150,0,28)or Color3.fromRGB(20,12,15),
   BorderSizePixel=0,Position=UDim2.fromOffset(x,676),Size=UDim2.fromOffset(182,58)},stage)
  new("UICorner",{CornerRadius=UDim.new(0,5)},b)
  local st=new("UIStroke",{Color=primary and RED or DIM,Thickness=1.4,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
  text(b,textStr,SERIF,22,BONE,{Size=UDim2.fromScale(1,1)})
  b.MouseEnter:Connect(function()st.Color=RED;b.BackgroundColor3=primary and Color3.fromRGB(185,0,36)or Color3.fromRGB(40,14,20)end)
  b.MouseLeave:Connect(function()st.Color=primary and RED or DIM;b.BackgroundColor3=primary and Color3.fromRGB(150,0,28)or Color3.fromRGB(20,12,15)end)
  return b
 end
 local stay=button("NEXT ROUND",true,1180)
 local lobby=button("MAIN MENU",false,1378)
 stay.Activated:Connect(function()self.view:Toast("You're queued for the next round.");self:Hide()end)
 lobby.Activated:Connect(function()self:Hide();self.view:RestoreCamera();self.view.remote:FireServer("Menu")end)
 local countdown=text(stage,"",LABEL,15,MUTED,{Position=UDim2.fromOffset(1180,744),Size=UDim2.fromOffset(380,20)})
 -- live bits: the winner turns on the plinth, the countdown ticks, the title glows
 local spin=0
 table.insert(self.conns,RunService.RenderStepped:Connect(function(dt)
  if model and model.Parent and not reduced then
   spin+=dt*.35
   model:PivotTo(CFrame.Angles(0,math.sin(spin)*.55,0))
    if visorUpdate then pcall(visorUpdate) end
  end
  local left=math.max(0,math.ceil((self.state:GetAttribute("EndsAt")or 0)-workspace:GetServerTimeNow()))
  countdown.Text=spaced("back to the lobby in ").."  "..left
  spot.BackgroundTransparency=.4+.08*math.sin(os.clock()*2)
 end))
 if self.view.sound then pcall(function()self.view.sound:Play(won and "Combo" or "UIOpen")end)end
end

return V
