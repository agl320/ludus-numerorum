-- Stamina bar: a thin slanted bar at the bottom centre of the match HUD. Reads the player attributes
-- Stamina (0..1) and StaminaExhausted written by ParkourController. Hidden while full; fades in as soon as
-- stamina is spent, a pale trail shows what was just used, and it blinks dim red while exhausted.
local RunService=game:GetService("RunService")
local B={};B.__index=B
local RED=Color3.fromRGB(255,24,58);local DIM=Color3.fromRGB(120,20,36);local TRAIL=Color3.fromRGB(255,214,220)
function B.new(view)
 local self=setmetatable({view=view,player=view.player,alpha=0,shown=1,trail=1,fullSince=0},B)
 local hud=view.gui:WaitForChild("MatchHUD")
 local old=hud:FindFirstChild("Stamina");if old then old:Destroy()end
 local root=Instance.new("CanvasGroup");root.Name="Stamina";root.AnchorPoint=Vector2.new(.5,1)
 root.Position=UDim2.new(.5,0,1,-40);root.Size=UDim2.fromOffset(316,26);root.BackgroundTransparency=1;root.GroupTransparency=1;root.ZIndex=20
 local track=Instance.new("Frame");track.Name="Track";track.AnchorPoint=Vector2.new(.5,1);track.Position=UDim2.new(.5,0,1,0)
 track.Size=UDim2.fromOffset(300,8);track.BackgroundColor3=Color3.fromRGB(14,10,12);track.BackgroundTransparency=.25;track.BorderSizePixel=0;track.ZIndex=20;track.Parent=root
 local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(110,22,40);stroke.Thickness=1;stroke.Transparency=.2;stroke.Parent=track
 local function fill(name,color,z)
  local f=Instance.new("Frame");f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=color;f.Size=UDim2.fromScale(1,1);f.ZIndex=z;f.Parent=track
  return f
 end
 self.trailFill=fill("Trail",TRAIL,21)
 self.fill=fill("Fill",RED,22)
 local shine=Instance.new("UIGradient");shine.Rotation=90
 shine.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(190,170,175));shine.Parent=self.fill
 -- slanted end caps + recovery tick (the point where sprinting comes back after exhaustion)
 local tick=Instance.new("Frame");tick.Name="Recover";tick.BorderSizePixel=0;tick.BackgroundColor3=Color3.fromRGB(255,255,255);tick.BackgroundTransparency=.55
 tick.AnchorPoint=Vector2.new(.5,.5);tick.Position=UDim2.fromScale(.25,.5);tick.Size=UDim2.new(0,2,1,4);tick.ZIndex=23;tick.Parent=track
 self.tick=tick
 local label=Instance.new("TextLabel");label.Name="Label";label.BackgroundTransparency=1;label.AnchorPoint=Vector2.new(.5,1)
 label.Position=UDim2.new(.5,0,1,-11);label.Size=UDim2.fromOffset(300,14);label.Text="STAMINA";label.TextSize=12
 label.Font=Enum.Font.GothamBold;label.TextColor3=Color3.fromRGB(235,215,218);label.TextTransparency=.3;label.ZIndex=20;label.Parent=root
 self.label=label
 root.Parent=hud
 self.root=root
 self.conn=RunService.RenderStepped:Connect(function(dt)self:Step(dt)end)
 view.gui.Destroying:Connect(function()if self.conn then self.conn:Disconnect()end end)
 return self
end
function B:Step(dt)
 dt=math.clamp(dt,0,.1)
 local p=self.player
 local inMatch=p:GetAttribute("InMatch")==true and self.view.gui.MatchHUD.Visible
 local value=math.clamp(p:GetAttribute("Stamina")or 1,0,1)
 local exhausted=p:GetAttribute("StaminaExhausted")==true
 local now=os.clock()
 if value<.999 then self.fullSince=now end
 local want=inMatch and(now-self.fullSince<1.1)and 1 or 0
 self.alpha+=(want-self.alpha)*(1-math.exp(-(want>self.alpha and 14 or 5)*dt))
 self.root.Visible=self.alpha>.01
 self.root.GroupTransparency=1-self.alpha
 if not self.root.Visible then self.shown=value;self.trail=value;return end
 -- the number entry card (E) docks at the bottom centre too: the bar moves up above it while it's open
 do
  local entry=self.view.gui:FindFirstChild("Entry")
  local parent=self.root.Parent
  if entry and entry.Visible and entry.AbsoluteSize.Y>0 and parent then
   self.root.Position=UDim2.new(.5,0,0,entry.AbsolutePosition.Y-parent.AbsolutePosition.Y-6)
  else
   self.root.Position=UDim2.new(.5,0,1,-40)
  end
 end
 self.shown+=(value-self.shown)*(1-math.exp(-22*dt))
 -- the trail holds briefly then catches up, so spending shows as a pale chunk
 if value<self.trail then self.trail+=(value-self.trail)*(1-math.exp(-3.2*dt))else self.trail=value end
 self.fill.Size=UDim2.fromScale(self.shown,1)
 self.trailFill.Size=UDim2.fromScale(math.max(self.trail,self.shown),1)
 if exhausted then
  local blink=.5+.5*math.sin(now*12)
  self.fill.BackgroundColor3=DIM:Lerp(RED,blink*.35)
  self.label.Text="WINDED";self.label.TextColor3=Color3.fromRGB(255,90,110)
 else
  self.fill.BackgroundColor3=RED
  self.label.Text="STAMINA";self.label.TextColor3=Color3.fromRGB(235,215,218)
 end
 self.tick.Visible=exhausted
end
return B
