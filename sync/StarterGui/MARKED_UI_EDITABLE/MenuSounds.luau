-- Menu sounds and equip feedback.
--  * every button in the UI: soft tick on hover, click on press, page-turn on tabs/categories, error buzz when locked
--  * DEPLOY plays the deploy hit
--  * equipping / unequipping (hair, colour, mask, clothes, notebook) plays a holster sound and flashes the screen
--    edge red; only clothes (outfit / colourway) also play the quick-change on the preview (spin + scan ring,
--    ReferenceMenusV3 OutfitFX); spending Marks plays the register
local Players=game:GetService("Players")
local S={};S.__index=S
local EQUIP={HairStyle=true,HairColor=true,FaceMask=true,Outfit=true,OutfitColor=true,NotebookFinish=true,GearColor=true}
local EMPTY={[""]=true,None=true,Classic=true,Default=true}
function S.new(view)
 local self=setmetatable({view=view,gui=view.gui,player=view.player,lastHover=0,lastSound={},hooked=setmetatable({},{__mode="k"})},S)
 self.born=os.clock()
 for _,b in ipairs(self.gui:GetDescendants())do self:Hook(b)end
 self.gui.DescendantAdded:Connect(function(b)self:Hook(b)end)
 -- equip / purchase feedback
 self.coins=self.player:GetAttribute("Coins")
 self.player.AttributeChanged:Connect(function(name)self:Attribute(name)end)
 -- edge flash used by equips
 local flash=Instance.new("Frame");flash.Name="EquipFlash";flash.BackgroundTransparency=1;flash.Size=UDim2.fromScale(1,1);flash.ZIndex=55;flash.Active=false
 local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(255,30,62);stroke.Thickness=0;stroke.Transparency=1;stroke.Parent=flash
 flash.Parent=self.gui;self.flash=stroke
 return self
end
function S:Play(name,pitch,gap)
 local sound=self.view.sound;if not sound then return end
 local now=os.clock();if now-(self.lastSound[name]or 0)<(gap or .05)then return end
 self.lastSound[name]=now
 pcall(function()sound:Play(name,pitch)end)
end
local function isTab(b)
 local n=b.Name
 return n:match("^Category%d")or n:match("^Tab%d")or n:match("Tab$")or n=="Styles"or n=="Colours"or n=="Colors"or n=="PrevPage"or n=="NextPage"
end
function S:Hook(b)
 if not b:IsA("GuiButton")or self.hooked[b]then return end
 self.hooked[b]=true
 local inHud=b:IsDescendantOf(self.gui:FindFirstChild("MatchHUD")or b)and b~=self.gui
 b.MouseEnter:Connect(function()
  if inHud or b:GetAttribute("Locked")or not b.Visible then return end
  local now=os.clock();if now-self.lastHover<.045 then return end;self.lastHover=now
  self:Play("UIHover",1+math.random(-3,3)/100,0)
 end)
 b.Activated:Connect(function()
  if b:GetAttribute("Locked")then self:Play("UIError");return end
  if b.Name=="Deploy"and b.Parent and b.Parent.Name=="Lobby"then self:Play("Deploy");return end
  if isTab(b)then self:Play("UITab",1+math.random(-4,4)/100);return end
  self:Play("UIClick")
 end)
end
function S:Pulse(strength)
 local stroke=self.flash;if not stroke then return end
 self.pulseAt=os.clock();self.pulseStrength=strength or 1
 if self.pulsing then return end
 self.pulsing=true
 task.spawn(function()
  while true do
   local t=(os.clock()-self.pulseAt)/.45
   if t>=1 then break end
   stroke.Thickness=10*self.pulseStrength*(1-t)
   stroke.Transparency=.25+.75*t
   task.wait()
  end
  stroke.Thickness=0;stroke.Transparency=1;self.pulsing=false
 end)
end
function S:Attribute(name)
 local p=self.player
 if name=="Coins"then
  local new=p:GetAttribute("Coins")or 0;local old=self.coins;self.coins=new
  if old and new<old and not p:GetAttribute("InMatch")then self:Play("Purchase",nil,.3);self:Pulse(.7)end
  return
 end
 if not EQUIP[name]then return end
 -- ignore the burst of attributes the profile sets while it loads
 if os.clock()-self.born<4 or not p:GetAttribute("ProfileReady")or p:GetAttribute("InMatch")then return end
 local value=p:GetAttribute(name)
 local off=value==nil or(type(value)=="string"and EMPTY[value])
 self:Play(off and "Unequip"or "Equip",nil,.15)
 self:Pulse(off and .5 or 1)
 -- clothes only: the quick-change on the open preview (Loadout or Shop); hair, masks, notebooks don't spin
 local r=self.view.redesign
 if (name=="Outfit" or name=="OutfitColor") and r and r.OutfitFX and (self.view.active=="Inventory" or self.view.active=="Shop") then
  -- after the preview has re-dressed (the menus redraw .25s after a look attribute changes)
  local which=self.view.active
  task.delay(.28,function()pcall(r.OutfitFX,r,which,false)end)
 end
end
return S
