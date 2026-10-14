-- Elimination banners (built here, on their own ScreenGui "KillBanners"):
--   Hit(info, combo)  you eliminated someone: a red slash wipes in under the top bar, the victim's name punches
--                     in, their number is struck through, +marks chip, combo tier on the eyebrow
--   Miss(number)      wrong number: a short glitching plate with the digits crossed out
--   Death(data)       you were eliminated: a black band (soft-ended, not full width) low in the middle, "YOU WERE MARKED" with a
--                     split-colour glitch, who did it, and your number falling apart
local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local NumberStyles=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NumberStyles"))
local TopNotices=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("TopNotices"))
local B={};B.__index=B
local RED=Color3.fromRGB(255,24,58)
local DEEP=Color3.fromRGB(110,0,18)
local BONE=Color3.fromRGB(240,230,222)
local MUTED=Color3.fromRGB(176,150,152)
local GOLD=Color3.fromRGB(255,196,92)
local SERIF=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold)
local LABEL=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold)
local MONO=Font.new("rbxasset://fonts/families/RobotoMono.json",Enum.FontWeight.Bold)
local TIERS={[2]="DOUBLE MARK",[3]="TRIPLE MARK",[4]="QUAD MARK",[5]="MASSACRE"}

local function ease(t,style,dir)return TweenInfo.new(t,style or Enum.EasingStyle.Quart,dir or Enum.EasingDirection.Out)end
local function tween(o,info,props)local t=Tween:Create(o,info,props);t:Play();return t end
-- fade a whole banner out. (Plain frames, not a CanvasGroup: a CanvasGroup renders its contents to a texture,
-- which made the text soft / blurry.)
local FADE_PROPS={TextLabel={"TextTransparency","BackgroundTransparency"},Frame={"BackgroundTransparency"},ImageLabel={"ImageTransparency","BackgroundTransparency"},UIStroke={"Transparency"}}
local function fadeOut(root,info)
 for _,d in ipairs(root:GetDescendants())do
  local props=FADE_PROPS[d.ClassName]
  if props then local goal={};for _,p in ipairs(props)do goal[p]=1 end;Tween:Create(d,info,goal):Play()end
 end
end
local function new(class,props,parent)
 local o=Instance.new(class)
 for k,v in pairs(props)do o[k]=v end
 o.Parent=parent
 return o
end
local function label(parent,text,font,size,color,props)
 local l=new("TextLabel",{BackgroundTransparency=1,Text=text,FontFace=font,TextSize=size,TextColor3=color,RichText=true},parent)
 for k,v in pairs(props or {})do l[k]=v end
 return l
end
-- letter-spaced caps for small eyebrows
local function spaced(s)return (s:upper():gsub(".","%0 ")):sub(1,-2)end

function B.new(view)
 local self=setmetatable({view=view,player=view.player,serial=0},B)
 local gui=Instance.new("ScreenGui");gui.Name="KillBanners";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=24
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 gui.Parent=self.player:WaitForChild("PlayerGui")
 self.gui=gui
 self.scale=new("UIScale",{},gui)
 -- size everything from a 1600px-wide reference
 local function fit()local v=gui.AbsoluteSize;self.scale.Scale=math.clamp(math.min(v.X/1600,v.Y/860),.55,1.15)end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit);fit()
 view.gui.Destroying:Connect(function()gui:Destroy()end)
 return self
end

function B:Clear(kind)
 for _,c in ipairs(self.gui:GetChildren())do
  if c:IsA("GuiObject")and(kind==nil or c:GetAttribute("Kind")==kind)then c:Destroy()end
 end
end
function B:Reduced()return self.view.values.ReducedMotion==true or self.view.flashes==false end
-- Banners sit in the lower part of the screen, away from the top bar / notices: their bottom edge just above
-- the number-entry notebook when it's open, otherwise a little above the bottom HUD row. Returns the top y for a
-- banner `height` tall (in our scaled space).
function B:Top(height)
 local s=self.scale.Scale
 local screenH=self.gui.AbsoluteSize.Y
 local bottom=screenH-150*s
 local entry=self.view.gui:FindFirstChild("Entry")
 if entry and entry.Visible and entry.AbsoluteSize.Y>0 then bottom=math.min(bottom,entry.AbsolutePosition.Y+self.view.gui.AbsolutePosition.Y-12*s) end
 -- never higher than 58% of the screen (keeps the crosshair clear)
 bottom=math.max(bottom,screenH*.58+(height or 170)*s)
 return bottom/s-(height or 170)
end
-- keep a banner in place while it lives (the entry notebook can open / close under it)
function B:Dock(root,height)
 local conn;conn=RunService.RenderStepped:Connect(function()
  if not root.Parent then conn:Disconnect();return end
  local w=self.gui.AbsoluteSize.X/self.scale.Scale
  root.Position=UDim2.fromOffset(w/2,self:Top(height)+(root:GetAttribute("Lift")or 0))
 end)
end

-- ============ HIT ============
function B:Hit(info,combo)
 combo=math.max(1,combo or 1)
 self:Clear("Hit");self:Clear("Miss")
 self.serial+=1;local serial=self.serial
 local reduced=self:Reduced()
 local accent=combo>=3 and GOLD or RED
 local vw=self.gui.AbsoluteSize.X/self.scale.Scale
 local root=new("Frame",{Name="Hit",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(580,170),
  Position=UDim2.fromOffset(vw/2,self:Top(166))},self.gui)
 root:SetAttribute("Kind","Hit")
 self:Dock(root,166)
 -- slash: black shadow bar + red bar wiping in from the left, both skewed
 local clip=new("Frame",{Name="SlashClip",BackgroundTransparency=1,ClipsDescendants=true,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.new(.5,0,0,82),Size=UDim2.fromOffset(0,96)},root)
 new("Frame",{Name="Shadow",BorderSizePixel=0,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.15,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.new(.5,10,.5,8),Size=UDim2.fromOffset(560,66),Rotation=-2.5},clip)
 local bar=new("Frame",{Name="Slash",BorderSizePixel=0,BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(560,66),Rotation=-2.5},clip)
 new("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,DEEP),ColorSequenceKeypoint.new(.5,accent),ColorSequenceKeypoint.new(1,DEEP)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,.08),NumberSequenceKeypoint.new(.88,.08),NumberSequenceKeypoint.new(1,1)})},bar)
 -- thin bright edge lines above and below the slash
 for _,dy in ipairs({-36,36})do
  local line=new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(255,170,180),AnchorPoint=Vector2.new(.5,.5),
   Position=UDim2.new(.5,0,.5,dy*.92),Size=UDim2.fromOffset(470,2),Rotation=-2.5},clip)
  new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(1,1)})},line)
 end
 -- eyebrow
 local eyebrow=label(root,spaced(combo>1 and(TIERS[math.min(combo,5)].."  x"..combo)or"target eliminated"),LABEL,15,accent==GOLD and GOLD or Color3.fromRGB(255,190,198),
  {AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,4),Size=UDim2.fromOffset(520,20),TextTransparency=1})
 new("UIStroke",{Color=Color3.new(0,0,0),Thickness=1.2,Transparency=.3},eyebrow)
 -- victim name
 local victim=tostring(info and(info.Victim)or"TARGET")
 local vp=info and info.VictimId and Players:GetPlayerByUserId(info.VictimId)
 if vp then victim=vp.DisplayName end
 local name=label(root,victim:upper(),SERIF,46,BONE,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,80),Size=UDim2.fromOffset(470,54),TextTransparency=1,TextScaled=true})
 new("UITextSizeConstraint",{MaxTextSize=46,MinTextSize=20},name) -- (long names shrink to fit the slash)
 new("UIStroke",{Color=Color3.fromRGB(40,0,8),Thickness=2.5,Transparency=.1},name)
 local nameScale=new("UIScale",{Scale=reduced and 1 or 1.35},name)
 -- struck-through number plate under the slash
 local code=tostring(info and info.Code or "----")
 -- row under the slash: [struck number] [+marks]
 local row=new("Frame",{Name="Row",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,126),Size=UDim2.fromOffset(400,38)},root)
 new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,14),SortOrder=Enum.SortOrder.LayoutOrder},row)
 local plate=new("Frame",{Name="Number",BackgroundColor3=Color3.fromRGB(10,6,8),BackgroundTransparency=.1,Size=UDim2.fromOffset(132,36),LayoutOrder=1},row)
 new("UICorner",{CornerRadius=UDim.new(0,4)},plate)
 new("UIStroke",{Color=accent,Thickness=1.2,Transparency=.25},plate)
 local digits=label(plate,code,MONO,26,RED,{Size=UDim2.fromScale(1,1),TextTransparency=1})
 local strike=new("Frame",{BorderSizePixel=0,BackgroundColor3=BONE,AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,10,.5,0),Size=UDim2.fromOffset(0,3),Rotation=-6,ZIndex=3},plate)
 -- reward chip
 local reward=(self.view.config and self.view.config.Rewards and self.view.config.Rewards.Coins)or 25
 local chipBox=new("Frame",{BackgroundColor3=Color3.fromRGB(40,26,8),BackgroundTransparency=.15,Size=UDim2.fromOffset(128,36),LayoutOrder=2},row)
 new("UICorner",{CornerRadius=UDim.new(0,4)},chipBox)
 new("UIStroke",{Color=GOLD,Thickness=1,Transparency=.45},chipBox)
 local chip=label(chipBox,"+"..reward.." MARKS",LABEL,19,GOLD,{Size=UDim2.fromScale(1,1),TextTransparency=1})
 -- animate in
 local wipe=reduced and 0 or .22
 clip.Size=UDim2.fromOffset(reduced and 590 or 0,96)
 tween(clip,ease(wipe+.01,Enum.EasingStyle.Quint),{Size=UDim2.fromOffset(590,96)})
 task.delay(wipe*.6,function()
  if self.serial~=serial or not root.Parent then return end
  tween(name,ease(.12),{TextTransparency=0})
  tween(nameScale,ease(.35,Enum.EasingStyle.Back),{Scale=1})
  tween(eyebrow,ease(.25),{TextTransparency=0})
 end)
 task.delay(wipe+.12,function()
  if self.serial~=serial or not root.Parent then return end
  -- the struck number: plain digits that roll for a moment, then settle on their number (the number-style
  -- skin made it far too big for the plate)
  tween(digits,ease(.12),{TextTransparency=0})
  local t0=os.clock()
  local rc;rc=RunService.RenderStepped:Connect(function()
   if not digits.Parent or os.clock()-t0>.3 then rc:Disconnect();if digits.Parent then digits.Text=code end;return end
   digits.Text=string.format("%04d",math.random(0,9999))
  end)
  task.delay(.18,function()if root.Parent then tween(strike,ease(.22,Enum.EasingStyle.Quint),{Size=UDim2.fromOffset(112,3)});tween(digits,ease(.3),{TextColor3=Color3.fromRGB(190,90,100)})end end)
  task.delay(.3,function()if root.Parent then tween(chip,ease(.25),{TextTransparency=0})end end)
 end)
 -- a quick white flash across the slash
 if not reduced then
  local flash=new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.2,AnchorPoint=Vector2.new(.5,.5),
   Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(560,66),Rotation=-2.5,ZIndex=4},clip)
  tween(flash,ease(.35),{BackgroundTransparency=1})
 end
 -- out
 task.delay(2.5,function()
  if self.serial~=serial or not root.Parent then return end
  fadeOut(root,ease(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.In))
  task.delay(.4,function()if root.Parent then root:Destroy()end end)
 end)
end

-- ============ MISS ============
function B:Miss(number)
 self:Clear("Miss")
 local reduced=self:Reduced()
 local vw=self.gui.AbsoluteSize.X/self.scale.Scale
 local root=new("Frame",{Name="Miss",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Size=UDim2.fromOffset(460,74),
  Position=UDim2.fromOffset(vw/2,self:Top(80))},self.gui)
 root:SetAttribute("Kind","Miss")
 self:Dock(root,80)
 local plate=new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(14,4,7),BackgroundTransparency=.08,Size=UDim2.fromScale(1,1)},root)
 new("UICorner",{CornerRadius=UDim.new(0,6)},plate)
 new("UIStroke",{Color=RED,Thickness=1.5,Transparency=.2},plate)
 local stripe=new("Frame",{BorderSizePixel=0,BackgroundColor3=RED,Size=UDim2.new(0,6,1,0)},plate)
 new("UICorner",{CornerRadius=UDim.new(0,3)},stripe)
 label(plate,spaced("wrong number"),LABEL,14,Color3.fromRGB(255,150,160),{Position=UDim2.fromOffset(24,10),Size=UDim2.fromOffset(240,18),TextXAlignment=Enum.TextXAlignment.Left})
 label(plate,"NOT THEIR NUMBER",SERIF,26,BONE,{Position=UDim2.fromOffset(24,30),Size=UDim2.fromOffset(260,32),TextXAlignment=Enum.TextXAlignment.Left})
 local box=new("Frame",{BackgroundColor3=Color3.fromRGB(26,6,10),AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-16,.5,0),Size=UDim2.fromOffset(140,44)},plate)
 new("UICorner",{CornerRadius=UDim.new(0,4)},box)
 local missLabel=label(box,tostring(number or "----"),MONO,28,RED,{Size=UDim2.fromScale(1,1)})
 for _,r in ipairs({-18,18})do
  new("Frame",{BorderSizePixel=0,BackgroundColor3=BONE,BackgroundTransparency=.1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(122,2),Rotation=r,ZIndex=3},box)
 end
 -- glitch shake in
 if not reduced then
  local t0=os.clock()
  local conn;conn=RunService.RenderStepped:Connect(function()
   local t=os.clock()-t0
   if not root.Parent or t>.32 then conn:Disconnect();if root.Parent then plate.Position=UDim2.new() end;return end
   plate.Position=UDim2.fromOffset(math.sin(t*90)*9*(1-t/.32),0)
  end)
 end
 task.delay(1.5,function()
  if not root.Parent then return end
  fadeOut(root,ease(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In))
  task.delay(.32,function()if root.Parent then root:Destroy()end end)
 end)
end

-- ============ DEATH ============
function B:Death(data)
 self:Clear()
 local reduced=self:Reduced()
 local killerId=data and data.KillerId
 local killer=killerId and Players:GetPlayerByUserId(killerId)
 local selfInflicted=killerId==self.player.UserId
 local code=tostring(data and data.Code or self.player.Character and self.player.Character:GetAttribute("NumberfallCode")or "----")
 local size=self.gui.AbsoluteSize/self.scale.Scale
 local root=new("Frame",{Name="Death",ClipsDescendants=true,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(math.min(size.X-40,820),250),
  Position=UDim2.fromOffset(size.X/2,size.Y*.72)},self.gui)
 root:SetAttribute("Kind","Death")
 local band=new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(6,2,3),BackgroundTransparency=.08,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,0,0,reduced and 210 or 0)},root)
 new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.16,.05),NumberSequenceKeypoint.new(.84,.05),NumberSequenceKeypoint.new(1,1)})},band)
 for _,y in ipairs({0,1})do
  local l=new("Frame",{BorderSizePixel=0,BackgroundColor3=RED,AnchorPoint=Vector2.new(0,y),Position=UDim2.fromScale(0,y),Size=UDim2.new(1,0,0,2)},band)
  new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})},l)
 end
 local mid=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(640,210)},root)
 label(mid,spaced(selfInflicted and "self eliminated" or "eliminated"),LABEL,15,Color3.fromRGB(255,150,160),{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,14),Size=UDim2.fromOffset(600,20)})
 -- title with a split-colour glitch behind it
 local title=selfInflicted and "YOU WROTE YOUR OWN" or "YOU WERE MARKED"
 local ghosts={}
 for i,c in ipairs({Color3.fromRGB(0,210,255),RED})do
  local g=label(mid,title,SERIF,56,c,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,76),Size=UDim2.fromOffset(640,66),TextTransparency=reduced and 1 or .45})
  ghosts[i]=g
 end
 local main=label(mid,title,SERIF,56,BONE,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,76),Size=UDim2.fromOffset(640,66)})
 new("UIStroke",{Color=DEEP,Thickness=2,Transparency=.1},main)
 local sub=selfInflicted and "Your own number, in your own notebook." or killer and ("by  <font color=\"#FF3A55\">"..killer.DisplayName:upper().."</font>") or (data and type(data.KillerName)=="string" and ("by  <font color=\"#FF3A55\">"..data.KillerName:upper().."</font>")) or "by an unknown hand"
 label(mid,sub,LABEL,21,MUTED,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,114),Size=UDim2.fromOffset(600,28)})
 -- your number, digit by digit, breaking apart
 local digitsFrame=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,150),Size=UDim2.fromOffset(200,46)},mid)
 local digitLabels={}
 for i=1,4 do
  local d=label(digitsFrame,code:sub(i,i),MONO,38,RED,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(25+(i-1)*50,23),Size=UDim2.fromOffset(46,46)})
  new("UIStroke",{Color=Color3.fromRGB(255,200,205),Thickness=1,Transparency=.5},d)
  digitLabels[i]=d
 end
 -- your number scrambles before it falls apart (plain digits: the number-style skin was far too big here)
 do
  local t0=os.clock()
  local rc;rc=RunService.RenderStepped:Connect(function()
   local t=os.clock()-t0
   if not root.Parent or t>.75 then rc:Disconnect()
    for i,d in ipairs(digitLabels)do if d.Parent then d.Text=code:sub(i,i) end end
    return
   end
   -- digits settle left to right
   for i,d in ipairs(digitLabels)do d.Text=t>.25+i*.11 and code:sub(i,i) or tostring(math.random(0,9)) end
  end)
 end
 -- in
 tween(band,ease(reduced and .01 or .28,Enum.EasingStyle.Quint),{Size=UDim2.new(1,0,0,210)})
 mid.Position=UDim2.fromScale(.5,.5)+UDim2.fromOffset(reduced and 0 or -60,0)
 tween(mid,ease(.5,Enum.EasingStyle.Quint),{Position=UDim2.fromScale(.5,.5)})
 local t0=os.clock()
 local conn;conn=RunService.RenderStepped:Connect(function()
  if not root.Parent then conn:Disconnect();return end
  local t=os.clock()-t0
  if not reduced then
   local j=(t<.6 or math.random()<.06)and 1 or 0
   ghosts[1].Position=UDim2.new(.5,-4*j+math.sin(t*50)*2*j,0,76)
   ghosts[2].Position=UDim2.new(.5,4*j-math.sin(t*44)*2*j,0,76+j)
  end
 end)
 -- the number breaks apart
 task.delay(.9,function()
  if not root.Parent then return end
  for i,d in ipairs(digitLabels)do
   local dx=(i-2.5)*28+math.random(-8,8)
   tween(d,ease(.9,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=d.Position+UDim2.fromOffset(dx,70+math.random(0,30)),Rotation=(i-2.5)*35,TextTransparency=1})
   local skin=d:FindFirstChild("NumberSkin");if skin then fadeOut(skin,ease(.9,Enum.EasingStyle.Quad,Enum.EasingDirection.In)) end
  end
 end)
 task.delay(2.4,function()
  if not root.Parent then return end
  fadeOut(root,ease(.45,Enum.EasingStyle.Quad,Enum.EasingDirection.In))
  task.delay(.5,function()if root.Parent then root:Destroy()end end)
 end)
end

return B
