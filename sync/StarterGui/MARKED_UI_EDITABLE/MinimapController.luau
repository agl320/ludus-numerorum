-- Minimap (MatchHUD.Minimap, a round map top-left, under your number; shown while you're in the arena).
-- North up and centred on you: the city (MinimapData building footprints in SunsetCity's RootCF space) slides
-- under a fixed arrow, clipped to a circle (CanvasGroup) with an N tick on the rim and the zone status below.
--   * you: a white arrow pointing where the camera looks
--   * the closing zone: the current safe circle (purple ring) and, once it's announced, where it will end
--   * red dots: players you've spotted (locked onto their number) in the last few seconds, where you saw them
--   * red X: eliminations in the last minute. An X stays for the rest of the round when it was that player's
--     last life.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local shared=RS:WaitForChild("Numberfall")
local Zone=require(shared:WaitForChild("ZoneRules"))
local M={};M.__index=M
local F=Zone.Full
local D=190                -- circle diameter (reference px)
local VIEW_R=150           -- studs from you to the rim
local S=(D/2)/VIEW_R       -- px per stud
local MAP_W=(F.maxX-F.minX)*S
local MAP_H=(F.maxZ-F.minZ)*S
local BONE=Color3.fromRGB(236,228,224)
local RED=Color3.fromRGB(255,36,62)
local ZONE=Zone.Color
local SPOT_TIME=8          -- a spotted dot lasts this long (fading over the last 3s)
local X_TIME=60            -- an elimination X lasts a minute, unless it was a last life
local COLORS={b=Color3.fromRGB(58,44,48),l=Color3.fromRGB(96,62,68),g=Color3.fromRGB(26,40,30),w=Color3.fromRGB(22,44,66)}

local function toMap(lx,lz)return Vector2.new((lx-F.minX)*S,(lz-F.minZ)*S)end
local function worldToMap(pos)
 local l=Zone.Root():PointToObjectSpace(pos)
 return toMap(l.X,l.Z)
end
local function new(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end

function M.new(view)
 local self=setmetatable({view=view,player=view.player,kills={},dots={},xs={}},M)
 self.root=view.gui:WaitForChild("MatchHUD"):WaitForChild("Minimap")
 self:Frame()
 self.map.Size=UDim2.fromOffset(MAP_W,MAP_H)
 self:Build()
 -- eliminations (with their position) come from the Kill notice
 shared:WaitForChild("Notice").OnClientEvent:Connect(function(kind,data)
  if kind=="Kill" and type(data)=="table" and typeof(data.Position)=="Vector3" then
   table.insert(self.kills,{at=os.clock(),position=data.Position,victimId=data.VictimId,round=shared:GetAttribute("RoundId")})
  end
 end)
 shared:GetAttributeChangedSignal("RoundId"):Connect(function()table.clear(self.kills);if view.spotted then table.clear(view.spotted)end end)
 local acc=0
 RunService.RenderStepped:Connect(function(dt)
  acc+=dt
  self:Arrow()
  if acc<1/12 then return end
  acc=0
  self:Step()
 end)
 return self
end

-- the round frame: a dark disc that clips the sliding map, a red rim, an N tick and the zone pill underneath
function M:Frame()
 local root=self.root
 root.Size=UDim2.fromOffset(D,D);root.BackgroundTransparency=1;root.ClipsDescendants=false
 local rc=root:FindFirstChildOfClass("UICorner") or new("UICorner",{},root);rc.CornerRadius=UDim.new(1,0)
 local st=root:FindFirstChildOfClass("UIStroke") or new("UIStroke",{},root)
 st.Color=Color3.fromRGB(150,20,44);st.Thickness=2;st.Transparency=0;st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 local title=root:FindFirstChild("Title");if title then title.Visible=false end
 local old=root:FindFirstChild("Clip");if old then old:Destroy()end
 local clip=new("CanvasGroup",{Name="Clip",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(10,6,8),BackgroundTransparency=.12,
  Size=UDim2.fromScale(1,1),ZIndex=1},root)
 new("UICorner",{CornerRadius=UDim.new(1,0)},clip)
 local map=root:FindFirstChild("Map") or new("Frame",{Name="Map"},root)
 map.Parent=clip;map.ClipsDescendants=false;map.BackgroundColor3=Color3.fromRGB(20,13,16);map.BackgroundTransparency=0;map.BorderSizePixel=0
 local mc=map:FindFirstChildOfClass("UICorner");if mc then mc:Destroy()end
 self.map=map
 -- a soft dark edge inside the rim
 local edge=new("Frame",{Name="Edge",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=20},clip)
 new("UICorner",{CornerRadius=UDim.new(1,0)},edge)
 new("UIStroke",{Color=Color3.fromRGB(10,6,8),Thickness=10,Transparency=.45,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},edge)
 local inner=new("Frame",{Name="Inner",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
  Size=UDim2.new(1,-12,1,-12),ZIndex=21},clip)
 new("UICorner",{CornerRadius=UDim.new(1,0)},inner)
 new("UIStroke",{Color=Color3.fromRGB(255,60,90),Thickness=1,Transparency=.8},inner)
 -- you: a fixed arrow in the middle (outside the clip so it never gets cut)
 local oldMe=root:FindFirstChild("Me");if oldMe then oldMe:Destroy()end
 -- a white dot with a red edge, and a white chevron ahead of it that turns with the camera
 self.me=new("Frame",{Name="Me",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(34,34),ZIndex=30},root)
 local dot=new("Frame",{Name="Dot",BorderSizePixel=0,BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
  Size=UDim2.fromOffset(10,10),ZIndex=31},self.me)
 new("UICorner",{CornerRadius=UDim.new(1,0)},dot)
 new("UIStroke",{Color=Color3.fromRGB(190,10,40),Thickness=2},dot)
 for _,a in ipairs({-40,40})do
  local arm=new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(.5,.5),
   Position=UDim2.new(.5,a<0 and -4 or 4,0,4),Size=UDim2.fromOffset(11,3),Rotation=a,ZIndex=31},self.me)
  new("UICorner",{CornerRadius=UDim.new(1,0)},arm)
  new("UIStroke",{Color=Color3.fromRGB(120,0,20),Thickness=1,Transparency=.2},arm)
 end
 -- north tick on the rim
 local oldN=root:FindFirstChild("North");if oldN then oldN:Destroy()end
 local n=new("Frame",{Name="North",BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(150,20,44),AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(22,22),ZIndex=31},root)
 new("UICorner",{CornerRadius=UDim.new(1,0)},n)
 new("TextLabel",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text="N",FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold),
  TextSize=14,TextColor3=BONE,ZIndex=32},n)
 -- zone status: a pill hanging off the bottom of the rim (hidden while there's nothing to say)
 local zl=root:FindFirstChild("ZoneLabel")
 if zl then
  zl.AnchorPoint=Vector2.new(.5,.5);zl.Position=UDim2.new(.5,0,1,0);zl.AutomaticSize=Enum.AutomaticSize.X;zl.Size=UDim2.fromOffset(0,22)
  zl.BackgroundColor3=Color3.fromRGB(28,12,40);zl.BackgroundTransparency=0;zl.BorderSizePixel=0;zl.ZIndex=31
  zl.FontFace=Font.new("rbxasset://fonts/families/AccanthisADFStd.json",Enum.FontWeight.Bold);zl.TextSize=13;zl.TextColor3=Color3.fromRGB(214,180,255)
  if not zl:FindFirstChildOfClass("UICorner")then new("UICorner",{CornerRadius=UDim.new(1,0)},zl)end
  if not zl:FindFirstChildOfClass("UIPadding")then new("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},zl)end
  if not zl:FindFirstChildOfClass("UIStroke")then new("UIStroke",{Color=ZONE,Thickness=1,Transparency=.3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},zl)end
  zl.Visible=false
 end
end

function M:Build()
 local map=self.map
 for _,c in ipairs(map:GetChildren())do if not c:IsA("UICorner")then c:Destroy()end end
 -- quarter split lines + names
 local split=toMap(Zone.SplitX,Zone.SplitZ)
 new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(120,80,90),BackgroundTransparency=.82,Position=UDim2.fromOffset(split.X,0),Size=UDim2.new(0,1,1,0),ZIndex=2},map)
 new("Frame",{BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(120,80,90),BackgroundTransparency=.82,Position=UDim2.fromOffset(0,split.Y),Size=UDim2.new(1,0,0,1),ZIndex=2},map)
 for q=1,4 do
  local c=Zone.Quarter(q);local p=toMap(c.x,c.z)
  new("TextLabel",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(p.X,p.Y),Size=UDim2.fromOffset(40,14),
   Text=({"NW","NE","SW","SE"})[q],FontFace=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold),TextSize=11,
   TextColor3=Color3.fromRGB(150,120,126),TextTransparency=.45,ZIndex=3},map)
 end
 -- buildings
 local ok,data=pcall(require,self.view.gui:WaitForChild("MinimapData"))
 if ok and type(data)=="table"then
  for _,r in ipairs(data)do
   local p=toMap(r[1],r[2])
   local kind=r[6]
   new("Frame",{BorderSizePixel=0,BackgroundColor3=COLORS[kind]or COLORS.b,BackgroundTransparency=kind=="g"and .2 or 0,AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromOffset(p.X,p.Y),Size=UDim2.fromOffset(math.max(2,r[3]*S),math.max(2,r[4]*S)),Rotation=r[5],ZIndex=kind=="w"and 1 or kind=="g"and 1 or 2},map)
  end
 end
 -- zone rings
 local function ring(name,color,thick,trans)
  local f=new("Frame",{Name=name,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),ZIndex=6,Visible=false},map)
  new("UICorner",{CornerRadius=UDim.new(1,0)},f)
  new("UIStroke",{Color=color,Thickness=thick,Transparency=trans},f)
  return f
 end
 self.zoneNow=ring("ZoneNow",ZONE,2,0)
 self.zoneEnd=ring("ZoneEnd",Color3.new(1,1,1),1,.55)
 self.markers=new("Folder",{Name="Markers"},map)
end

function M:Arrow()
 local cam=workspace.CurrentCamera;local char=self.player.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 if not root or not cam then self.me.Visible=false;return end
 self.me.Visible=true
 -- the map slides so you stay in the middle of the circle
 local p=worldToMap(root.Position)
 self.map.Position=UDim2.fromOffset(D/2-p.X,D/2-p.Y)
 local look=Zone.Root():VectorToObjectSpace(cam.CFrame.LookVector)
 self.me.Rotation=math.deg(math.atan2(look.X,-look.Z))
end

-- an X out of two short bars
local function makeX(parent)
 local f=new("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(11,11),ZIndex=8},parent)
 for _,r in ipairs({45,-45})do
  local b=new("Frame",{BorderSizePixel=0,BackgroundColor3=RED,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(13,3),Rotation=r,ZIndex=8},f)
  new("UIStroke",{Color=Color3.new(0,0,0),Thickness=1,Transparency=.3},b)
 end
 return f
end
local function makeDot(parent)
 local f=new("Frame",{BorderSizePixel=0,BackgroundColor3=RED,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(9,9),ZIndex=9},parent)
 new("UICorner",{CornerRadius=UDim.new(1,0)},f)
 new("UIStroke",{Color=Color3.fromRGB(255,200,205),Thickness=1,Transparency=.2},f)
 local pulse=new("Frame",{Name="Pulse",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(9,9),ZIndex=9},f)
 new("UICorner",{CornerRadius=UDim.new(1,0)},pulse)
 new("UIStroke",{Name="Ring",Color=RED,Thickness=1.5,Transparency=.2},pulse)
 return f
end

function M:Step()
 local p=self.player
 local presentation=self.view.presentation
 local dead=presentation and presentation.mode=="death"
 local show=p:GetAttribute("InArena")==true and not dead and self.view.gui.MatchHUD.Visible
 self.root.Visible=show
 if not show then return end
 local now=workspace:GetServerTimeNow()
 -- zone
 local circle=Zone.Circle(shared,now)
 local q=shared:GetAttribute("ZoneQuarter")or 0
 local starts=shared:GetAttribute("ZoneStartsAt")
 local label=self.root:FindFirstChild("ZoneLabel")
 if circle then
  local c=toMap(circle.x,circle.z);local d=circle.r*2*S
  self.zoneNow.Visible=true;self.zoneNow.Position=UDim2.fromOffset(c.X,c.Y);self.zoneNow.Size=UDim2.fromOffset(d,d)
 else self.zoneNow.Visible=false end
 if q>=1 and starts and now>=starts-Zone.WarnSeconds then
  local f=Zone.Target and Zone.Target(shared,now) or Zone.Quarter(q);local c=toMap(f.x,f.z);local d=f.r*2*S
  self.zoneEnd.Visible=true;self.zoneEnd.Position=UDim2.fromOffset(c.X,c.Y);self.zoneEnd.Size=UDim2.fromOffset(d,d)
  local _,t,squeeze=Zone.Circle(shared,now)
  local closing=circle and (t<1 or (squeeze~=nil and squeeze<1))
  if label then label.Text=now<starts and("CLOSING IN "..math.ceil(starts-now))or(closing and "CLOSING" or "SAFE: "..(Zone.Names[q]or""));label.Visible=true end
 else
  self.zoneEnd.Visible=false
  if label then label.Text="";label.Visible=false end
 end
 -- markers (rebuilt each tick: there are only ever a handful)
 self.markers:ClearAllChildren()
 local clock=os.clock()
 local round=shared:GetAttribute("RoundId")
 for i=#self.kills,1,-1 do
  local k=self.kills[i]
  local victim=k.victimId and Players:GetPlayerByUserId(k.victimId)
  -- a last life: the X stays for the rest of the round
  local final=victim and(victim:GetAttribute("Lives")or 1)<=0
  local age=clock-k.at
  if k.round~=round or(not final and age>X_TIME)then table.remove(self.kills,i)
  else
   local x=makeX(self.markers);local m=worldToMap(k.position)
   x.Position=UDim2.fromOffset(m.X,m.Y)
   local fade=final and 0 or math.clamp((age-(X_TIME-10))/10,0,1)
   if final then x.Size=UDim2.fromOffset(13,13)end
   for _,b in ipairs(x:GetChildren())do b.BackgroundTransparency=fade;b.BackgroundColor3=final and Color3.fromRGB(170,20,40)or RED end
  end
 end
 for who,info in pairs(self.view.spotted or {})do
  local age=clock-info.at
  local c=who.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
  if age>SPOT_TIME or not who.Parent or not h or h.Health<=0 then self.view.spotted[who]=nil
  else
   local d=makeDot(self.markers);local m=worldToMap(info.position)
   d.Position=UDim2.fromOffset(m.X,m.Y)
   local fade=math.clamp((age-(SPOT_TIME-3))/3,0,1)
   d.BackgroundTransparency=fade
   local ring=d.Pulse
   local t=(clock*1.4)%1
   ring.Size=UDim2.fromOffset(9+t*14,9+t*14);ring.Ring.Transparency=math.max(fade,.2+t*.8)
   d:FindFirstChildOfClass("UIStroke").Transparency=math.max(fade,.2)
  end
 end
end

return M
