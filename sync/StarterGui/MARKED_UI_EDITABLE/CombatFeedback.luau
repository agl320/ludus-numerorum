-- All visuals are authored under StarterGui. This module only updates their state.
local Feedback={};Feedback.__index=Feedback
local RED=Color3.fromRGB(255,18,62)
local WHITE=Color3.fromRGB(238,233,230)
local GREEN=Color3.fromRGB(143,255,209)
local TopNotices=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("TopNotices"))
function Feedback.new(view)
 local self=setmetatable({view=view,gui=view.gui,pressed=false},Feedback)
 local confirm=self.gui.Entry.Confirm
 confirm.MouseButton1Down:Connect(function()self.pressed=true end)
 confirm.MouseButton1Up:Connect(function()self.pressed=false end)
 confirm.MouseLeave:Connect(function()self.pressed=false end)
 self.gui.CombatBanner.Spectate.Activated:Connect(function()
  if view.presentation and view.presentation.mode=="death"then view.presentation.began=os.clock()-1.6 end
 end)
 self.gui.CombatBanner.Lobby.Activated:Connect(function()
  if view.presentation then view.presentation:Stop()end
  self:Reset();view.remote:FireServer("Menu")
 end)
 view.player.CharacterAdded:Connect(function()self:Reset()end)
 view.player:GetAttributeChangedSignal("InMatch"):Connect(function()
  if not view.player:GetAttribute("InMatch")then self:Reset()end
 end)
 view.shared:GetAttributeChangedSignal("Phase"):Connect(function()self:Reset()end)
 return self
end
function Feedback:Reset()
 self.result=nil;self.bannerUntil=0;self.gui.CombatBanner.Visible=false;self.pressed=false
end
function Feedback:Artwork()
 local ids=self.gui.ArtworkAssetIds
 for _,e in ipairs(self.gui:GetDescendants())do
  local key=e.Name=="DistressArtwork"and "PanelDistress"or e.Name=="SkullArtwork"and "MarksIcon"
  if e.Name=="DistressArtwork"and (e.Parent.Name=="MatchIntro"or e.Parent.Name=="SpectatorTransition")then key="FrameLarge"end
  if e.Name=="SkullArtwork"and e.Parent.Parent.Name=="Eliminated"then key="MarksIcon"end
  if key then
   e.Image=ids[key].Value;e.Visible=e.Image~=""and e.Image~="rbxassetid://0"and e.Image~="0"
    if e.Name=="DistressArtwork"and e.Parent.Name=="MatchIntro"then e.Visible=false end -- (no picture frame behind the round-start number card)
   if e.Name=="SkullArtwork"and e.Parent:FindFirstChild("SkullFallback")then e.Parent.SkullFallback.Visible=not e.Visible end
  end
 end
 self.gui.CombatBanner.DeathArtwork.Image=ids.EliminationBanner.Value
end
function Feedback:Banner(kind,number,killerId,data)
 -- new banners (KillBanner): a kill is announced from the Kill notice (it carries the victim's name), a miss and
 -- your own elimination from here. The old authored CombatBanner stays hidden.
 local kb=self.view.killBanner
 if kb then
  self.bannerUntil=0
  if kind=="Miss"then kb:Miss(number)elseif kind=="Death"then kb:Death(data or {KillerId=killerId})end
  return
 end
 local b=self.gui.CombatBanner;self.bannerKind=kind;self.bannerUntil=os.clock()+(kind=="Death"and 4 or 2.6)
 -- death: the killcam runs on its own, so the banner just says who got you (no buttons)
 b.Visible=true;b.Spectate.Visible=false;b.Lobby.Visible=false
 b.Emblem.Visible=kind=="Hit";b.ErrorMark.Visible=kind=="Miss";b.Portrait.Visible=kind=="Death"
 local artwork=b.DeathArtwork.Image
 b.DeathArtwork.Visible=kind=="Death"and artwork~=""and artwork~="rbxassetid://0"and artwork~="0"
 if b.DeathArtwork.Visible then b.Portrait.Visible=false end
 b.Heading.Text=kind=="Hit"and "SUCCESS (ELIMINATED)"or kind=="Miss"and "ERROR (INCORRECT)"or "ELIMINATED (YOU)"
 b.Title.Text=kind=="Hit"and "TARGET ELIMINATED"or kind=="Miss"and "INCORRECT NUMBER"or "YOU WERE ELIMINATED"
 local killerName=nil
 if kind=="Death"and killerId then local kp=game:GetService("Players"):GetPlayerByUserId(killerId);killerName=kp and kp.DisplayName end
 b.Detail.Text=kind=="Hit"and "You eliminated "..number.."."or kind=="Miss"and number.." is not their number."or killerName and killerName.." eliminated you."or "You were eliminated."
 if kind=="Death"and killerId==self.view.player.UserId then b.Detail.Text="You wrote your own number."end
 b.Title.Size=UDim2.fromOffset(370,25)
 b.Detail.Size=UDim2.fromOffset(370,22)
 if kind=="Death"then
  b.Portrait.Image=""
  local players=game:GetService("Players");local p=killerId and players:GetPlayerByUserId(killerId)
  if p and self.view.presentation and not b.DeathArtwork.Visible then self.view.presentation:Portrait(p,b.Portrait)end
 end
end
function Feedback:Result(status,number)
 if status~="Hit"and status~="Miss"then return end
 self.result={status=status,number=number,untilTime=os.clock()+(status=="Hit"and 1.1 or 1.25)}
 self:Banner(status,number)
end
function Feedback:Death(data)
 self.result=nil
 self:Banner("Death",tostring(data and data.KillerCode or "----"),data and data.KillerId,data)
end
-- gear-styled number panels (just the four slots, no frame art):
-- Keyboard: a monkeytype-style strip. Dark slate, monospace digits, grey for what's still to type, a soft yellow caret;
--   red for a wrong number, yellow for a hit.
-- Typewriter: a strip of paper rolled under a dark platen. Typewriter-face digits struck a little unevenly, a red
--   ribbon line under the next slot; a wrong number is struck through in red, a hit is inked green.
local RGB=Color3.fromRGB
local STYLES={
 Keyboard={kind="mono",bg=RGB(50,52,55),text=RGB(209,208,197),sub=RGB(100,102,105),hit=RGB(226,183,20),err=RGB(202,71,84),
  dim=RGB(100,102,105),caretC=RGB(226,183,20),W=360,cell=68,gap=12,top=16,H=116,Ht=172,confirmY=112,
  font=Font.fromEnum(Enum.Font.RobotoMono),ts=64,cellH=84,
  caret={a=Vector2.new(0,.5),p=UDim2.new(0,8,.5,-2),s=UDim2.fromOffset(3,54)}},
 Typewriter={kind="paper",bg=RGB(30,25,24),text=RGB(38,33,35),sub=RGB(186,174,150),hit=RGB(44,98,62),err=RGB(158,26,38),
  dim=RGB(132,120,106),caretC=RGB(170,30,44),W=380,cell=64,gap=16,top=22,H=126,Ht=182,confirmY=124,
  font=Font.fromEnum(Enum.Font.SpecialElite),ts=64,cellH=80,tilt={-3,2,-1.5,3},nudge={1,-2,2,0},
  caret={a=Vector2.new(.5,1),p=UDim2.new(.5,0,1,-6),s=UDim2.fromOffset(34,3)}},
}
-- the typewriter's paper, platen and strike line (built once, shown only for the typewriter)
local function paperDeco(e,st)
 local deco=e:FindFirstChild("TWDeco")
 if not deco then
  deco=Instance.new("Frame");deco.Name="TWDeco";deco.BackgroundTransparency=1;deco.Size=UDim2.fromScale(1,1);deco.ZIndex=29;deco.Parent=e
  local function box(name,x,y,w,h,col,parent,z)
   local f=Instance.new("Frame");f.Name=name;f.BorderSizePixel=0;f.BackgroundColor3=col;f.Position=UDim2.fromOffset(x,y)
   f.Size=UDim2.fromOffset(w,h);f.ZIndex=z or 29;f.Parent=parent or deco;return f
  end
  local W=st.W
  -- the sheet, a little warm at the bottom where it comes off the roller
  local paper=box("Paper",22,14,W-44,98,RGB(240,231,208))
  local pc=Instance.new("UICorner");pc.CornerRadius=UDim.new(0,3);pc.Parent=paper
  local pg=Instance.new("UIGradient");pg.Rotation=90;pg.Color=ColorSequence.new(RGB(255,255,255),RGB(226,212,184));pg.Parent=paper
  box("Margin",18,0,1,98,RGB(206,112,112),paper).BackgroundTransparency=.35
  box("Rule",8,84,W-60,1,RGB(150,170,200),paper).BackgroundTransparency=.45
  -- the platen (roller) across the top of the sheet, with its two knobs
  local platen=box("Platen",10,6,W-20,14,RGB(18,16,16))
  local rc=Instance.new("UICorner");rc.CornerRadius=UDim.new(0,7);rc.Parent=platen
  local rg=Instance.new("UIGradient");rg.Rotation=90;rg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,RGB(70,62,58)),ColorSequenceKeypoint.new(.45,RGB(26,22,22)),ColorSequenceKeypoint.new(1,RGB(10,9,9))});rg.Parent=platen
  for _,x in ipairs({2,W-16}) do
   local k=box("Knob",x,3,14,20,RGB(150,118,70));local kc=Instance.new("UICorner");kc.CornerRadius=UDim.new(0,4);kc.Parent=k
  end
 end
 local strike=e:FindFirstChild("TWStrike")
 if not strike then
  local x0=(st.W-(st.cell*4+st.gap*3))/2
  strike=Instance.new("Frame");strike.Name="TWStrike";strike.BorderSizePixel=0;strike.BackgroundColor3=st.err;strike.ZIndex=31
  strike.Position=UDim2.fromOffset(x0-6,st.top+st.cellH/2);strike.Size=UDim2.fromOffset(st.cell*4+st.gap*3+12,4);strike.Rotation=-2
  strike.Visible=false;strike.Parent=e
 end
 return deco,strike
end
function Feedback:StyleLayout(e,st)
 -- (the panel's own layout is kept the first time and put back when another gear is equipped)
 local o=self.styleSaved
 if not o then
  o={W=e.Size.X.Offset,bgT=e.BackgroundTransparency,cells={}}
  for i=0,3 do
   local c=e["Digit"..i];local k=c.Caret
   o.cells[i]={pos=c.Position,size=c.Size,font=c.Value.FontFace,ts=c.Value.TextSize,bgT=c.BackgroundTransparency,
    kA=k.AnchorPoint,kP=k.Position,kS=k.Size,kC=k.BackgroundColor3}
  end
  self.styleSaved=o
 end
 local on=st~=nil
 e.Edge.Enabled=not on;e.InnerFrame.Visible=not on;e.DistressArtwork.Visible=not on;e.Title.Visible=not on;e.Feedback.Visible=not on
 e.BackgroundTransparency=on and 0 or o.bgT
 e.Size=UDim2.fromOffset(on and st.W or o.W,e.Size.Y.Offset)
 local paper=on and st.kind=="paper"
 if paper then paperDeco(e,st) end
 local deco=e:FindFirstChild("TWDeco");if deco then deco.Visible=paper end
 local strike=e:FindFirstChild("TWStrike");if strike then strike.Visible=false end
 for i=0,3 do
  local c=e["Digit"..i];local k=c.Caret;local s=o.cells[i]
  c.Edge.Enabled=not on;c.BackgroundTransparency=on and 1 or s.bgT
  if on then
   local x0=(st.W-(st.cell*4+st.gap*3))/2
   c.Position=UDim2.fromOffset(x0+i*(st.cell+st.gap),st.top+(st.nudge and st.nudge[i+1] or 0));c.Size=UDim2.fromOffset(st.cell,st.cellH)
   c.Value.FontFace=st.font;c.Value.TextSize=st.ts;c.Value.Rotation=st.tilt and st.tilt[i+1] or 0
   k.AnchorPoint=st.caret.a;k.Position=st.caret.p;k.Size=st.caret.s;k.BackgroundColor3=st.caretC
  else
   c.Position=s.pos;c.Size=s.size;c.Value.FontFace=s.font;c.Value.TextSize=s.ts;c.Value.Rotation=0
   k.AnchorPoint=s.kA;k.Position=s.kP;k.Size=s.kS;k.BackgroundColor3=s.kC;k.BackgroundTransparency=0
  end
 end
end
function Feedback:Render(input,now)
 local clock=os.clock();local e=self.gui.Entry;local r=self.result
 -- A new digit cancels the held visual immediately; never extend the server cooldown.
 if r and (clock>=r.untilTime or (input.status~="Hit"and input.status~="Miss"and input.buffer~=""))then
  self.result=nil;r=nil
  if input.buffer==""and self.view.active=="Entry"then self.view:Show("HUD")end
 end
 local status=r and r.status or input.status;local number=r and r.number or input.buffer
 local hit=status=="Hit";local miss=status=="Miss";local written=status=="Written"
 -- the device in use: a keyboard marks with ENTER and a gamepad with RB (both shown in the hint row), so the
 -- CONFIRM button is only there for touch screens. In the lobby the panel is a scratch pad: nothing is marked.
 local player=self.view.player
 local mode=player:GetAttribute("InputMode")or "keyboard";local touch=mode=="touch"
 local lobby=player:GetAttribute("InArena")~=true
 local open=not r and not input.pending and now>=(input.deadline or 0)
 local ready=open and (lobby and #input.buffer>0 or #input.buffer==4)
 local tint=hit and GREEN or miss and RED or WHITE
 local style=STYLES[player:GetAttribute("NotebookFinish") or ""]
 if style~=self.style then self.style=style;self:StyleLayout(e,style) end
 local H=style and (touch and style.Ht or style.H) or (touch and 216 or 178)
 if e.Size.Y.Offset~=H then e.Size=UDim2.fromOffset(e.Size.X.Offset,H)end
 e:SetAttribute("VisualState",hit and "Success"or miss and "Incorrect"or written and "Written"or input.pending and "Sending"or ready and "Ready"or #number>0 and "Typing"or "Idle")
 e.Title.Text=hit and "TARGET ELIMINATED"or miss and "INCORRECT NUMBER"or lobby and ""or "E N T E R   N U M B E R" -- (no title in the lobby)
 e.Title.TextColor3=tint;e.Edge.Color=hit and GREEN or RED
 e.InnerFrame.Edge.Color=hit and GREEN or Color3.fromRGB(164,138,141)
 e.DistressArtwork.ImageColor3=hit and GREEN or RED
 e.BackgroundColor3=hit and Color3.fromRGB(2,17,13)or Color3.fromRGB(8,5,7)
 -- the next cell to fill gets a blinking red caret
 local at=(open and not written and #number<4)and #number or -1
 local blink=(clock*1.6)%1<.62
 for i=0,3 do
  local cell=e["Digit"..i];local d=number:sub(i+1,i+1)
  cell.Value.Text=d~=""and d or "";cell.Value.TextColor3=tint
  cell.Edge.Color=hit and Color3.fromRGB(81,129,111)or miss and RED or i==at and Color3.fromRGB(196,40,64)or d~=""and Color3.fromRGB(122,104,108)or Color3.fromRGB(64,46,51)
  local caret=cell:FindFirstChild("Caret");if caret then caret.Visible=i==at and blink end
 end
 e.Confirm.Visible=touch and not hit and not miss;e.Confirm.Active=ready;e.Confirm.AutoButtonColor=false
 e.Confirm.Glow.Visible=ready and not self.pressed
 e.Confirm.BackgroundColor3=ready and (self.pressed and Color3.fromRGB(64,0,12)or Color3.fromRGB(178,0,30))or Color3.fromRGB(27,4,9)
 e.Confirm.Label.Text=input.pending and "CHECKING…"or written and "NOTED"or lobby and "WRITE"or "CONFIRM"
 e.Confirm.Label.TextColor3=ready and WHITE or Color3.fromRGB(173,132,140)
 e.SuccessMark.Visible=hit;e.ErrorMark.Visible=miss;e.ErrorGlitch.Visible=miss
 local markY=touch and 175 or 157
 e.SuccessMark.Position=UDim2.fromOffset(e.Size.X.Offset/2,markY);e.ErrorMark.Position=UDim2.fromOffset(e.Size.X.Offset/2,markY)
 e.Feedback.Text=(input.pending and not touch)and "VERIFYING NUMBER…"or ""
 -- the keys for this device (none on touch: the CONFIRM button and the keypad do it)
 local hint=e:FindFirstChild("Hint")
 if hint then
  local K=function(k)return '<font color="#ff4d6d">'..k..'</font>'end
  local text
  if mode=="gamepad"then text=K("RB")..(lobby and "  write     "or "  write / mark     ")..K("LB").."  erase     "..K("Y").."  put away"
  else text=K("ENTER")..(lobby and "  write     "or "  mark     ")..K("BACKSPACE").."  erase     "..K("E").."  put away"end
  if hint.Text~=text then hint.Text=text end
  hint.Visible=not touch and not hit and not miss and e.Feedback.Text==""
 end
 if style then
  e.BackgroundColor3=style.bg
  e.SuccessMark.Visible=false;e.ErrorMark.Visible=false;e.ErrorGlitch.Visible=false
  if hint then hint.Visible=false end
  -- typed digits (hit / miss / dimmed once written); slots still to type faint
  local col=hit and style.hit or miss and style.err or written and style.dim or style.text
  -- (the caret fades in and out rather than blinking hard)
  local fade=1-(.5+.5*math.cos(clock*math.pi*2/1.1))
  for i=0,3 do
   local cell=e["Digit"..i];local d=number:sub(i+1,i+1)
   cell.Value.Text=d~="" and d or "_";cell.Value.TextColor3=d~="" and col or style.sub
   local caret=cell.Caret;caret.Visible=i==at;caret.BackgroundTransparency=fade*.85
  end
  -- (the typewriter strikes a wrong number through)
  local strike=e:FindFirstChild("TWStrike");if strike then strike.Visible=style.kind=="paper" and miss end
  if touch then
   e.Confirm.Position=UDim2.fromOffset(26,style.confirmY);e.Confirm.Size=UDim2.fromOffset(style.W-52,46)
  end
 elseif self.styleSaved and e.Confirm.Size.X.Offset~=356 then
  e.Confirm.Position=UDim2.fromOffset(52,148);e.Confirm.Size=UDim2.fromOffset(356,54)
 end
 local reduced=self.view.values.ReducedMotion==true or self.view.flashes==false
 e.ErrorGlitch.Position=UDim2.fromOffset(not reduced and math.sin(clock*39)*6 or 0,0)
 if miss and not reduced then e.Position=e.Position+UDim2.fromOffset(math.sin(clock*47)*3,0)end
 local b=self.gui.CombatBanner
 b.Visible=clock<(self.bannerUntil or 0)and self.view.player:GetAttribute("InMatch")==true and self.view.shared:GetAttribute("Phase")~="Results"
 -- docked at the top centre under the match top bar; the TopNotices stack moves down to make room for it
 local v=self.gui.AbsoluteSize;local s=math.min(1,(v.X-32)/580)*math.clamp(v.X/1400,.62,1)
 TopNotices.Reserve("0banner",b.Visible and 106*s or 0)
 b.ResponsiveScale.Scale=s;b.Position=UDim2.fromOffset((v.X-580*s)/2,TopNotices.Top("0banner")) -- this ScreenGui ignores the top inset too
end
return Feedback
