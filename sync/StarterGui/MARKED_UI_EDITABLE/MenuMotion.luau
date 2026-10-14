-- Main-menu animation; layout and button actions remain authored in StarterGui.
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local Motion={};Motion.__index=Motion
-- Hover easing: critically damped spring. Eases in and out, settles in ~0.3s and never overshoots,
-- so the logo/season hover no longer snaps on or jitters.
local HOVER_SPEED=16
local EDGE_HOT=Color3.fromRGB(255,150,165)
local function spring(x,v,target,omega,dt)
 local d=x-target;local e=math.exp(-omega*dt)
 return target+(d+(v+omega*d)*dt)*e,(v-omega*(v+omega*d)*dt)*e
end
-- Scale around the centre: UIScale grows from the AnchorPoint, so centring it removes the
-- per-frame pixel position compensation that made the hover wobble.
-- ease out with a small overshoot (items glide in and settle)
local function backOut(p) local c1=1.25;local c3=c1+1;return 1+c3*(p-1)^3+c1*(p-1)^2 end
local MENU_BUTTONS={Deploy=true,Shop=true,Inventory=true,Quests=true,Settings=true,Credits=true}
-- the row along the bottom (INVITE FRIENDS / REWARDS · CODES / JOIN COMMUNITY): they rise in together and lift on hover
local BOTTOM_BUTTONS={"InviteFriends","DailyReward","Community"}
local function centreAnchor(node)
 if not node or node.AnchorPoint==Vector2.new(.5,.5)then return end
 local s,a=node.Size,node.AnchorPoint
 node.Position=node.Position+UDim2.new(s.X.Scale*(.5-a.X),s.X.Offset*(.5-a.X),s.Y.Scale*(.5-a.Y),s.Y.Offset*(.5-a.Y))
 node.AnchorPoint=Vector2.new(.5,.5)
end
function Motion.new(view)
 local self=setmetatable({view=view,gui=view.gui,lobby=view.gui.Lobby,items={},buttons={},connections={},active=false,time=0},Motion)
 centreAnchor(self.lobby:FindFirstChild("LogoArtwork"))
 centreAnchor(self.lobby.Season:FindFirstChild("CityPreview"))
 -- (scaled around their centre, not the top-left corner)
 for _,name in ipairs(BOTTOM_BUTTONS)do centreAnchor(self.lobby:FindFirstChild(name))end
 local order={"LogoArtwork","Tagline","Deploy","Shop","Inventory","Quests","Settings","Credits","Season","PlayerCard","DailyQuests"}
 for index,name in ipairs(order)do
  local item=self.lobby:FindFirstChild(name)
  if item and item:IsA("GuiObject")then
   table.insert(self.items,{node=item,position=item.Position,delay=(index-1)*.045,direction=(name=="PlayerCard"or name=="DailyQuests")and 1 or -1})
  end
 end
 self.bottom={}
 for k,name in ipairs(BOTTOM_BUTTONS)do
  local item=self.lobby:FindFirstChild(name)
  if item and item:IsA("GuiObject")then
   table.insert(self.items,{node=item,position=item.Position,delay=.32+(k-1)*.06,rise=true})
   local stroke=item:FindFirstChild("Outline")
   self.bottom[item]={amount=0,velocity=0,stroke=stroke,color=stroke and stroke.Color,thickness=stroke and stroke.Thickness}
  end
 end
 -- the season card is a single banner: no carousel markers under it
 for _,m in ipairs(self.lobby.Season:GetChildren())do if m.Name:match("^SlideMarker")then m.Visible=false end end
 self.logoOffset=Vector2.zero
 self.hoverAmounts={logo=0,season=0}
 self.hoverTargets={logo=0,season=0}
 self.hoverVelocity={logo=0,season=0}
 self.cursor=Vector2.zero
 self.cursorFocused=true
 table.insert(self.connections,UIS.WindowFocusReleased:Connect(function()self.cursorFocused=false end))
 table.insert(self.connections,UIS.WindowFocused:Connect(function()self.cursorFocused=true end))
 self.background=self.gui.MenuBackground
 self.backgroundPosition=self.background.Position;self.backgroundSize=self.background.Size
 self.banner=self.lobby.Season.CityPreview
 self.bannerPosition=self.banner.Position;self.bannerSize=self.banner.Size
 self.lobby.Season.ClipsDescendants=true
 self.bannerScale=self.banner:FindFirstChild("HoverScale")or Instance.new("UIScale",self.banner);self.bannerScale.Name="HoverScale"
 self.edge=self.lobby.Season:FindFirstChildOfClass("UIStroke");self.edgeColor=self.edge and self.edge.Color
 self.dim=self.background:WaitForChild("SubmenuDim")
 self.logo=self.lobby:FindFirstChild("LogoArtwork")
 if self.logo then
  self.logoAlpha=self.logo.ImageTransparency
  self.logoScale=self.logo:FindFirstChild("HoverScale")or Instance.new("UIScale",self.logo);self.logoScale.Name="HoverScale"
  table.insert(self.connections,self.logo.MouseEnter:Connect(function()self.hoverTargets.logo=1 end))
  table.insert(self.connections,self.logo.MouseLeave:Connect(function()self.hoverTargets.logo=0 end))
 end
 table.insert(self.connections,self.lobby.Season.MouseEnter:Connect(function()self.hoverTargets.season=1 end))
 table.insert(self.connections,self.lobby.Season.MouseLeave:Connect(function()self.hoverTargets.season=0 end))
 self.glow=self.lobby.Deploy:FindFirstChild("Glow")
 if self.glow then self.glowAlpha=self.glow.BackgroundTransparency end
 for _,button in ipairs(self.lobby:GetDescendants())do
  if button:IsA("GuiButton")then
   local scale=Instance.new("UIScale");scale.Name="MenuMotionScale";scale.Parent=button
   local entry={node=button,scale=scale,hover=false,selected=false,pressed=false}
   self.buttons[button]=entry
   local function connect(signal,fn)table.insert(self.connections,signal:Connect(fn))end
   connect(button.MouseEnter,function()entry.hover=true;self:Button(entry)end)
   connect(button.MouseLeave,function()entry.hover=false;entry.pressed=false;self:Button(entry)end)
   connect(button.SelectionGained,function()entry.selected=true;self:Button(entry)end)
   connect(button.SelectionLost,function()entry.selected=false;entry.pressed=false;self:Button(entry)end)
   connect(button.MouseButton1Down,function()entry.pressed=true;self:Button(entry)end)
   connect(button.MouseButton1Up,function()entry.pressed=false;self:Button(entry)end)
  end
 end
 -- hover accents on the main menu buttons: a red bar that grows on the left edge, and the button glides right
 self.hoverX={}
 for name in pairs(MENU_BUTTONS)do
  local b=self.lobby:FindFirstChild(name)
  if b then
   local bar=b:FindFirstChild("HoverBar")or Instance.new("Frame")
   bar.Name="HoverBar";bar.BorderSizePixel=0;bar.BackgroundColor3=Color3.fromRGB(255,30,62);bar.AnchorPoint=Vector2.new(0,.5)
   bar.Position=UDim2.new(0,-1,.5,0);bar.Size=UDim2.new(0,4,0,0);bar.ZIndex=b.ZIndex+8;bar.Parent=b
   local glow=bar:FindFirstChild("Glow")or Instance.new("UIStroke");glow.Name="Glow";glow.Color=Color3.fromRGB(255,40,70);glow.Thickness=2;glow.Transparency=.55;glow.Parent=bar
   self.hoverX[b]={amount=0,velocity=0,bar=bar}
  end
 end
 -- a black veil the menu fades in from, and slow drifting embers over the city backdrop
 local veil=self.gui:FindFirstChild("MenuVeil")or Instance.new("Frame")
 veil.Name="MenuVeil";veil.BorderSizePixel=0;veil.BackgroundColor3=Color3.new(0,0,0);veil.Size=UDim2.fromScale(1,1)
 veil.Position=UDim2.fromScale(0,0);veil.ZIndex=60;veil.BackgroundTransparency=1;veil.Active=false;veil.Parent=self.gui
 self.veil=veil
 self.embers={}
 local layer=self.background:FindFirstChild("Embers")or Instance.new("Frame")
 layer.Name="Embers";layer.BackgroundTransparency=1;layer.Size=UDim2.fromScale(1,1);layer.ZIndex=self.background.ZIndex+1;layer.ClipsDescendants=true;layer.Parent=self.background
 layer:ClearAllChildren()
 local rng=Random.new()
 for i=1,26 do
  local e=Instance.new("Frame");e.Name="Ember";e.BorderSizePixel=0;e.AnchorPoint=Vector2.new(.5,.5)
  local s=rng:NextNumber(2,5);e.Size=UDim2.fromOffset(s,s)
  e.BackgroundColor3=Color3.fromRGB(255,rng:NextInteger(40,120),rng:NextInteger(50,80));e.ZIndex=layer.ZIndex
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=e
  e.Parent=layer
  table.insert(self.embers,{node=e,x=rng:NextNumber(),y=rng:NextNumber(),speed=rng:NextNumber(.018,.05),sway=rng:NextNumber(.004,.015),phase=rng:NextNumber(0,6.28),base=rng:NextNumber(.15,.55)})
 end
 self.nextGlitch=os.clock()+4
 table.insert(self.connections,self.gui.Destroying:Connect(function()self:Destroy()end))
 return self
end
function Motion:Button(entry)
 local reduced=self.view.values.ReducedMotion==true
 local big=self.bottom and self.bottom[entry.node]~=nil
 entry.target=not reduced and self.active and not entry.node:GetAttribute("Locked") and(entry.pressed and (big and .97 or .992) or(entry.hover or entry.selected)and (big and 1.04 or 1.01) or 1)or 1
end
function Motion:Reset()
 self.hoverTargets.logo=0;self.hoverTargets.season=0;self.hoverAmounts.logo=0;self.hoverAmounts.season=0
 self.hoverVelocity.logo=0;self.hoverVelocity.season=0
 if self.bannerScale then self.bannerScale.Scale=1 end
 if self.edge then self.edge.Color=self.edgeColor end
 if self.logoScale then self.logoScale.Scale=1 end
 for _,item in ipairs(self.items)do item.node.Position=item.position end
 for _,h in pairs(self.bottom or {})do h.amount=0;h.velocity=0;if h.stroke then h.stroke.Color=h.color;h.stroke.Thickness=h.thickness end end
 if self.logo then self.logo.ImageTransparency=self.logoAlpha end
 if self.glow then self.glow.BackgroundTransparency=self.glowAlpha end
 if self.veil then self.veil.Visible=false end
 if self.view.player:GetAttribute("InMatch")then self.veilPending=true end
 for _,entry in pairs(self.buttons)do
  if entry.tween then entry.tween:Cancel();entry.tween=nil end
  entry.hover=false;entry.selected=false;entry.pressed=false;entry.target=1;entry.scale.Scale=1
 end
end
function Motion:City(dt)
 local shown=self.gui.Enabled and self.view.active~=nil and self.view.player:GetAttribute("InMatch")~=true
 self.background.Visible=shown
 self.dim.Visible=shown and self.view.active~="Lobby"
 if not shown or self.view.values.ReducedMotion==true then
  self.cursor=Vector2.zero
  self.background.Position=self.backgroundPosition;self.background.Size=self.backgroundSize
  self.banner.Position=self.bannerPosition;self.banner.Size=self.bannerSize
  self.bannerScale.Scale=1
  if self.edge then self.edge.Color=self.edgeColor end
  return
 end
 local target=Vector2.zero
 local size=self.gui.AbsoluteSize
 local input=UIS:GetLastInputType()
 if self.cursorFocused and UIS.MouseEnabled and input~=Enum.UserInputType.Touch and not input.Name:match("^Gamepad")and size.X>0 and size.Y>0 then
  local mouse=UIS:GetMouseLocation()-self.gui.AbsolutePosition
  target=Vector2.new(math.clamp(mouse.X/size.X*2-1,-1,1),math.clamp(mouse.Y/size.Y*2-1,-1,1))
 end
 self.cursor=self.cursor:Lerp(target,1-math.exp(-4*math.clamp(dt,0,.1)))
 local x,y=self.cursor.X,self.cursor.Y
 self.background.Size=self.backgroundSize+UDim2.fromScale(.02,.02)
 self.background.Position=self.backgroundPosition+UDim2.fromScale(-.01-x*.004,-.01-y*.003)
 local hover=self.hoverAmounts.season
 self.banner.Size=self.bannerSize
 -- (still: the banner no longer drifts with the cursor; it only zooms a touch on hover)
 self.banner.Position=self.bannerPosition
 self.bannerScale.Scale=1+hover*.04
 if self.edge then self.edge.Color=self.edgeColor:Lerp(EDGE_HOT,hover*.6)end
end
function Motion:Step(dt)
 if self.destroyed then return end
 local blend=1-math.exp(-5*math.clamp(dt,0,.1))
 local sdt=math.clamp(dt,0,.1)
 for key,target in pairs(self.hoverTargets)do
  self.hoverAmounts[key],self.hoverVelocity[key]=spring(self.hoverAmounts[key],self.hoverVelocity[key],target,HOVER_SPEED,sdt)
 end
 for _,entry in pairs(self.buttons)do entry.scale.Scale+=((entry.target or 1)-entry.scale.Scale)*blend end
 if self.logoScale and self.view.values.ReducedMotion==true then self.logoScale.Scale=1+self.hoverAmounts.logo*.025 end
 -- hover glide + accent bar
 for b,h in pairs(self.hoverX)do
  local e=self.buttons[b]
  local target=(e and (e.hover or e.selected) and self.active and not b:GetAttribute("Locked")) and 1 or 0
  h.amount,h.velocity=spring(h.amount,h.velocity,target,18,sdt)
  h.bar.Size=UDim2.new(0,4,math.clamp(h.amount,0,1.05)*.72,0)
  h.bar.BackgroundTransparency=1-math.clamp(h.amount*1.4,0,1)
 end
 -- bottom row: the outline heats up and thickens on hover
 for b,h in pairs(self.bottom or {})do
  local e=self.buttons[b]
  local target=(e and (e.hover or e.selected) and self.active) and 1 or 0
  h.amount,h.velocity=spring(h.amount,h.velocity,target,18,sdt)
  local a=math.clamp(h.amount,0,1)
  if h.stroke then h.stroke.Color=h.color:Lerp(EDGE_HOT,a*.7);h.stroke.Thickness=h.thickness+a*.8 end
 end
 self:City(dt)
 -- embers drift up over the backdrop (main menu only)
 local showEmbers=self.background.Visible and self.view.values.ReducedMotion~=true and not self.view.player:GetAttribute("LowEnd")
 local layer=self.background:FindFirstChild("Embers")
 if layer then layer.Visible=showEmbers end
 if showEmbers then
  local now=os.clock()
  for _,em in ipairs(self.embers)do
   em.y-=em.speed*sdt
   if em.y<-.05 then em.y=1.05;em.x=math.random() end
   local x=em.x+math.sin(now*.8+em.phase)*em.sway
   em.node.Position=UDim2.fromScale(x,em.y)
   local flicker=.5+.5*math.sin(now*3+em.phase*2)
   em.node.BackgroundTransparency=1-em.base*(.55+.45*flicker)*math.clamp((1.05-em.y)*3,0,1)*math.clamp(em.y*4,0,1)
  end
 end
 local visible=self.gui.Enabled and self.lobby.Visible and self.view.active=="Lobby"
 if not visible then
  if self.active then self.active=false;self:Reset()end
  return
 end
 if not self.active then
  self.active=true;self.time=0
  -- only fade up from black on first load or when returning from a match, not when backing out of a submenu
  self.veilOn=self.veilPending~=false;self.veilPending=false
 end
 self.time=self.time+math.clamp(dt,0,.1)
 if self.veil then
  self.veil.Visible=self.veilOn and self.time<.6
  self.veil.BackgroundTransparency=math.clamp(self.time/.55,0,1)
 end
 local reduced=self.view.values.ReducedMotion==true
 if reduced then
  if not self.reduced then self:Reset()end
  self.reduced=true;return
 end
 if self.reduced then self.time=2;self.reduced=false end
 local t=self.time
 local logoTarget=self.cursor*1.4
 self.logoOffset=self.logoOffset:Lerp(logoTarget,1-math.exp(-3*math.clamp(dt,0,.1)))
 for _,item in ipairs(self.items)do
  local progress=math.clamp((t-item.delay*1.4)/.7,0,1)
  local offset=item.rise and 0 or 80*item.direction*(1-backOut(progress))
  local rise=item.rise and 36*(1-backOut(progress)) or 0
  local bh=self.bottom and self.bottom[item.node]
  if bh then rise-=math.clamp(bh.amount,0,1.1)*3 end
  local blend=math.clamp((t-.4)/1.2,0,1);blend=blend*blend*(3-2*blend)
  local logo=item.node==self.logo
  local h=self.hoverX[item.node]
  local glide=h and h.amount*10 or 0
  local jitter=Vector2.zero
  item.node.Position=item.position+UDim2.fromOffset(offset+glide+jitter.X+(logo and self.logoOffset.X*blend or 0),rise+jitter.Y+(logo and self.logoOffset.Y*blend or 0))
 end
 if self.logo then self.logo.ImageTransparency=self.logoAlpha+(1-self.logoAlpha)*.7*(1-math.clamp(t/.8,0,1))end
 -- the logo punches in (no glitch shake: it read as a bug)
 if self.logoScale then
  local k=math.clamp(t/.75,0,1)
  self.logoScale.Scale=1+self.hoverAmounts.logo*.025+.16*(1-backOut(k))
 end
 if self.glow then self.glow.BackgroundTransparency=math.clamp(self.glowAlpha+.055*math.sin(t*1.8),0,1)end
end
function Motion:Destroy()
 if self.destroyed then return end
 self.destroyed=true;self.active=false;self:Reset()
 self.background.Position=self.backgroundPosition;self.background.Size=self.backgroundSize
 self.banner.Position=self.bannerPosition;self.banner.Size=self.bannerSize
 self.dim.Visible=false
 for _,connection in ipairs(self.connections)do connection:Disconnect()end
 for _,entry in pairs(self.buttons)do entry.scale:Destroy()end
end
return Motion
