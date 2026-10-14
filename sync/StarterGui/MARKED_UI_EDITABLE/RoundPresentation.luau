-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
-- round-start intro: fade in, the number scrambles and locks in, then the YOU ARE MARKED card (seconds from the start)
local INTRO={Fade=.5,Scramble=1.6,Lock=2.9,Reveal=4.3,Finish=4.9}
-- Controls authored StarterGui instances; no runtime UI construction.
local Players=game:GetService("Players")
-- numbers on screen are drawn in each player's number style (Numberfall.NumberStyles)
local NumberStyles=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NumberStyles"))
local UIS=game:GetService("UserInputService")
local Presentation={};Presentation.__index=Presentation
-- a spectate / killcam target is a Player or a bot (a model in workspace.MatchBots)
local function isBot(t)return t~=nil and t:IsA("Model")end
local function charOf(t)if not t then return nil end;if isBot(t)then return t end;return t.Character end
local function living(p)
 if isBot(p)then
  local h=p.Parent and p:FindFirstChildOfClass("Humanoid")
  return h and h.Health>0 and h or nil
 end
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 return p:GetAttribute("InArena")==true and h and h.Health>0 and h or nil
end
local function code(p)
 local c=charOf(p)
 return tostring(c and c:GetAttribute("NumberfallCode") or "----")
end
local function nameOf(t)
 if not t then return "—" end
 if isBot(t)then return t:GetAttribute("DisplayName")or t.Name end
 return t.DisplayName
end
-- a bot's lives and eliminations this round, from the BotBoard the server publishes (BotService)
local HttpService=game:GetService("HttpService")
local function botEntry(state,bot)
 local ok,list=pcall(function()return HttpService:JSONDecode(state:GetAttribute("BotBoard")or"[]")end)
 if not ok or type(list)~="table" then return nil end
 local id=bot:GetAttribute("BotId")
 for _,e in ipairs(list)do if e.id==id then return e end end
 return nil
end
local function fit(frame,w,h,v)
 local scale=math.max(.1,math.min(1,v.X/w,v.Y/h))
 frame.ResponsiveScale.Scale=scale
 frame.Position=UDim2.fromOffset((v.X-w*scale)/2,(v.Y-h*scale)/2)
end
-- Spectator / killcam bar: the authored SpectatorHUD re-laid out at the bottom of the screen in the menu style
-- (ink panel, red edge and corner ticks, Balthazar name, Gotham captions). Size 430 x 132 before ResponsiveScale.
local SPEC_W,SPEC_H=430,132
local S_INK=Color3.fromRGB(14,10,12);local S_RED=Color3.fromRGB(255,34,58);local S_BONE=Color3.fromRGB(238,233,230);local S_MUTED=Color3.fromRGB(160,146,146)
local S_BAL=Font.new("rbxasset://fonts/families/Balthazar.json",Enum.FontWeight.Regular)
local S_GOTHAM=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold)
local function sMake(class,props,parent)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
local function ticks(parent,z)
 for i,pos in ipairs({UDim2.fromOffset(5,5),UDim2.new(1,-5,1,-5)})do
  local a=Vector2.new(i==1 and 0 or 1,i==1 and 0 or 1)
  sMake("Frame",{Name="TickH"..i,AnchorPoint=a,Position=pos,Size=UDim2.fromOffset(12,2),BackgroundColor3=S_RED,BorderSizePixel=0,ZIndex=z},parent)
  sMake("Frame",{Name="TickV"..i,AnchorPoint=a,Position=pos,Size=UDim2.fromOffset(2,12),BackgroundColor3=S_RED,BorderSizePixel=0,ZIndex=z},parent)
 end
end
local function restyleSpectator(hud)
 if hud:GetAttribute("Restyled")then return end
 hud:SetAttribute("Restyled",true)
 hud.Size=UDim2.fromOffset(SPEC_W,SPEC_H);hud.BackgroundTransparency=1
 local plate=hud.Plate
 plate.Position=UDim2.fromOffset(56,22);plate.Size=UDim2.fromOffset(318,76)
 plate.BackgroundColor3=S_INK;plate.BackgroundTransparency=.1;plate.BorderSizePixel=0
 local edge=plate:FindFirstChildOfClass("UIStroke");if edge then edge.Color=S_RED;edge.Thickness=1.5;edge.Transparency=0 end
 if not plate:FindFirstChildOfClass("UICorner")then sMake("UICorner",{CornerRadius=UDim.new(0,4)},plate)end
 ticks(plate,plate.ZIndex+2)
 local av=plate:FindFirstChild("Avatar") or sMake("ImageLabel",{Name="Avatar",BackgroundColor3=Color3.fromRGB(52,12,22),BorderSizePixel=0,
  Position=UDim2.fromOffset(11,11),Size=UDim2.fromOffset(54,54),ZIndex=plate.ZIndex+1,Image=""},plate)
 sMake("UICorner",{CornerRadius=UDim.new(0,3)},av);sMake("UIStroke",{Color=S_RED,Thickness=1,Transparency=.35},av)
 local t=plate.Title
 t.FontFace=S_GOTHAM;t.TextSize=11;t.TextColor3=S_RED;t.TextXAlignment=Enum.TextXAlignment.Left
 t.Position=UDim2.fromOffset(78,10);t.Size=UDim2.fromOffset(228,14)
 local c=plate.Code
 c.FontFace=S_BAL;c.TextSize=30;c.TextColor3=S_BONE;c.TextXAlignment=Enum.TextXAlignment.Left;c.TextTruncate=Enum.TextTruncate.AtEnd
 c.Position=UDim2.fromOffset(78,23);c.Size=UDim2.fromOffset(228,32)
 if not plate:FindFirstChild("Info") then sMake("TextLabel",{Name="Info",BackgroundTransparency=1,FontFace=S_GOTHAM,TextSize=11,TextColor3=S_MUTED,
  TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(78,55),Size=UDim2.fromOffset(228,14),ZIndex=plate.ZIndex+1,Text=""},plate) end
 for i,b in ipairs({hud.Previous,hud.Next})do
  b.Position=UDim2.fromOffset(i==1 and 0 or SPEC_W-48,22);b.Size=UDim2.fromOffset(48,76)
  b.BackgroundColor3=S_INK;b.BackgroundTransparency=.1;b.AutoButtonColor=false
  local g=b:FindFirstChild("SurfaceGradient");if g then g.Enabled=false end
  local o=b:FindFirstChild("Outline");if o then o.Color=S_RED;o.Thickness=1.5;o.Transparency=.25 end
  local l=b:FindFirstChild("Label");if l then l.Size=UDim2.fromScale(1,1);l.Position=UDim2.new() end
  local glow=b:FindFirstChild("Glow");if glow then glow.Size=UDim2.fromScale(1,1) end
  b.MouseEnter:Connect(function()if o then o.Transparency=0 end;b.BackgroundColor3=Color3.fromRGB(60,10,20)end)
  b.MouseLeave:Connect(function()if o then o.Transparency=.25 end;b.BackgroundColor3=S_INK end)
 end
 local a=hud.Alive
 a.FontFace=S_GOTHAM;a.TextSize=11;a.TextColor3=S_MUTED;a.TextXAlignment=Enum.TextXAlignment.Left
 a.Position=UDim2.fromOffset(56,106);a.Size=UDim2.fromOffset(226,20)
 local back=hud.Lobby
 back.Position=UDim2.fromOffset(SPEC_W-56-88,104);back.Size=UDim2.fromOffset(88,24)
 back.BackgroundColor3=S_INK;back.BackgroundTransparency=.1;back.AutoButtonColor=false
 local bg=back:FindFirstChild("SurfaceGradient");if bg then bg.Enabled=false end
 local bo=back:FindFirstChild("Outline");if bo then bo.Color=S_RED;bo.Thickness=1.2;bo.Transparency=.3 end
 local bl=back:FindFirstChild("Label");if bl then bl.FontFace=S_GOTHAM;bl.TextSize=11;bl.TextColor3=S_BONE;bl.Size=UDim2.fromScale(1,1);bl.Position=UDim2.new() end
 local bglow=back:FindFirstChild("Glow");if bglow then bglow.Size=UDim2.fromScale(1,1) end
 back.MouseEnter:Connect(function()if bo then bo.Transparency=0 end;back.BackgroundColor3=Color3.fromRGB(60,10,20)end)
 back.MouseLeave:Connect(function()if bo then bo.Transparency=.3 end;back.BackgroundColor3=S_INK end)
end
-- bottom-centre placement for the spectator bar
local function placeSpectator(hud,viewport)
 local scale=math.clamp(math.min((viewport.X-24)/SPEC_W,viewport.Y/900),.6,1);hud.ResponsiveScale.Scale=scale
 hud.Position=UDim2.fromOffset((viewport.X-SPEC_W*scale)/2,viewport.Y-(SPEC_H+26)*scale)
end
function Presentation.new(view)
 local self=setmetatable({view=view,gui=view.gui,player=view.player,state=view.shared,mode=nil,serial=0,avatars={},roster={}},Presentation)
 self.gui.Lobby.PlayerCard.MarksPlus.Activated:Connect(function()view:Toast("Edit your avatar and display name from your Roblox profile.")end)
 self.gui.Shop.Currency.Info.Activated:Connect(function()view:Show("Shop");if view.marksStore then view.marksStore:SetActive(true)end end)
 pcall(restyleSpectator,self.gui.SpectatorHUD)
 for _,panel in ipairs({self.gui.SpectatorTransition.TargetCard,self.gui.SpectatorHUD})do
  panel.Previous.Activated:Connect(function()self:Cycle(-1)end)
  panel.Next.Activated:Connect(function()self:Cycle(1)end)
 end
 self.gui.SpectatorHUD.Lobby.Activated:Connect(function()
  if self.mode=="spectate" then self:Stop() return end
  self:Stop();view.remote:FireServer("Menu")
 end)
 -- lobby players can watch the round: names only, every visor masked (Killcam flag)
 local specButton=self.gui.MatchHUD:FindFirstChild("Spectate")
 if specButton then specButton.Activated:Connect(function()self:StartSpectate()end) end
 UIS.InputBegan:Connect(function(input,processed)
  if processed or chatTyping() or self.mode~="spectate" then return end
  if input.KeyCode==Enum.KeyCode.Left or input.KeyCode==Enum.KeyCode.A then self:Cycle(-1)
  elseif input.KeyCode==Enum.KeyCode.Right or input.KeyCode==Enum.KeyCode.D then self:Cycle(1)
  elseif input.KeyCode==Enum.KeyCode.Backspace or input.KeyCode==Enum.KeyCode.X then self:Stop() end
 end)
 self.gui.Results.Again.Activated:Connect(function()view:Toast("Ready for the next round.")end)
 -- (the match intro keeps running through the respawn into the arena: it covers that switch)
 self.player.CharacterAdded:Connect(function()if self.mode~="intro" then self:Stop()end end)
 self.player:GetAttributeChangedSignal("InMatch"):Connect(function()
  if not self.player:GetAttribute("InMatch")then self:Stop();self.introRound=nil end
 end)
 self.state:GetAttributeChangedSignal("Phase"):Connect(function()
  if self.state:GetAttribute("Phase")=="Results"then self:Stop();self:Results()end
 end)
 self.player:GetAttributeChangedSignal("Coins"):Connect(function()self:Currency()end)
 Players.PlayerRemoving:Connect(function(p)self.avatars[p.UserId]=nil;if self.target==p then self.target=nil end end)
 self:Currency()
 for _,id in ipairs(self.gui.ArtworkAssetIds:GetChildren())do id:GetPropertyChangedSignal("Value"):Connect(function()self:Artwork()end)end
 self:Artwork()
 if self.state:GetAttribute("Phase")=="Results"then self:Results()end
 return self
end
function Presentation:Artwork()
 if self.view.feedback then self.view.feedback:Artwork()end
 local ids=self.gui.ArtworkAssetIds
 for _,art in ipairs(self.gui.Lobby:GetDescendants())do
  local key=art:GetAttribute("MenuArtSlot")
  if key and art:IsA("ImageLabel")then
   local slot=ids:FindFirstChild(key)
   art.Image=slot and slot.Value or ""
   art.Visible=art.Image~=""and art.Image~="rbxassetid://0"
  end
 end
 self.gui.MenuBackground.Image=ids.MenuBackground.Value
 self.gui.Lobby.LogoArtwork.Image=ids.MarkedLogo.Value
 self.gui.MatchIntro.Fade.Logo.Image=ids.MarkedLogo.Value
 self.gui.MatchIntro.Reveal.Logo.Image=ids.MarkedLogo.Value
 local season=ids:FindFirstChild("SeasonBanner")
 self.gui.Lobby.Season.CityPreview.Image=season and season.Value~=""and season.Value or ids.MenuBackground.Value
 self.gui.MatchIntro.City.Image=ids.MenuBackground.Value
 self.gui.SpectatorTransition.City.Image=ids.MenuBackground.Value
 local function valid(v)return v~=""and v~="rbxassetid://0"and v~="0"end
 -- VictoryBackdrop holds the "VICTORY" lettering and VictoryTitle the dark painting, so they are used crosswise
 local title=ids.VictoryBackdrop.Value;local panel=self.gui.Results
 panel.VictoryArtwork.Image=title;panel.VictoryArtwork.ScaleType=Enum.ScaleType.Fit
 panel.VictoryArtwork.Visible=valid(title)and panel.Victory.Text=="VICTORY"
 panel.Victory.Visible=not panel.VictoryArtwork.Visible
 if valid(ids.VictoryTitle.Value)then panel.CityBackdrop.Image=ids.VictoryTitle.Value;panel.CityBackdrop.ImageTransparency=.55 end
 for _,image in ipairs(self.gui:GetDescendants())do
  if image.Name=="MarksArtwork"then
   image.Image=ids.MarksIcon.Value;image.Visible=image.Visible and valid(image.Image) -- unused placeholders (hidden in the editor, e.g. behind the daily quest skull) stay hidden

  end
 end
end
function Presentation:Currency()
 self.gui.Shop.Currency.Balance.Text="MARKS: "..tostring(self.player:GetAttribute("Coins")or 0)
end
function Presentation:Portrait(player,image)
 if not player then image.Image="";return end
 local id=player.UserId;image:SetAttribute("PortraitUser",id)
 if self.avatars[id]then image.Image=self.avatars[id];return end
 image.Image=""
 task.spawn(function()
  local ok,url=pcall(function()return Players:GetUserThumbnailAsync(id,Enum.ThumbnailType.AvatarThumbnail,Enum.ThumbnailSize.Size420x420)end)
  if ok then self.avatars[id]=url;if image.Parent and image:GetAttribute("PortraitUser")==id then image.Image=url end end
 end)
end
function Presentation:Results()
 local panel=self.gui.Results;local winnerId=self.state:GetAttribute("WinnerId")or 0
 local won=winnerId==self.player.UserId
 panel.Victory.Text=won and "VICTORY"or winnerId==0 and "DRAW"or "ROUND OVER"
 panel.Header.Text=won and "YOU WON THE ROUND"or "MATCH RESULTS"
 panel.Eyebrow.Text=winnerId==0 and "NO OUTRIGHT WINNER"or "TOP SCORING PLAYER"
 self:Artwork()
 local winner=Players:GetPlayerByUserId(winnerId)
 local number=tostring(self.state:GetAttribute("WinnerCode")or "----")
 panel.Winner.Badge.Code.Text=number;panel.Stats.WinnerCode.Text=number
 task.defer(function()
  local ws=NumberStyles.Of(winner)
  pcall(NumberStyles.Skin,panel.Winner.Badge.Code,ws,number);pcall(NumberStyles.Skin,panel.Stats.WinnerCode,ws,number)
 end)
 self:Portrait(winner,panel.Winner.Avatar)
 local others={}
 for _,p in ipairs(Players:GetPlayers())do
  if p.UserId~=winnerId and p:GetAttribute("ResultRound")==self.state:GetAttribute("RoundId")then table.insert(others,p)end
 end
 table.sort(others,function(a,b)return(a:GetAttribute("ResultPlace")or 999)<(b:GetAttribute("ResultPlace")or 999)end)
 for i=0,4 do
  local row=panel["Opponent"..i];local p=others[i+1];row.Visible=p~=nil
  if p then row.Code.Text=tostring(p:GetAttribute("ResultCode")or "----");task.defer(pcall,NumberStyles.Skin,row.Code,NumberStyles.Of(p),row.Code.Text)end
 end
end
-- the spectator plate's avatar + "3 LIVES · 2 ELIMS" line for the player being watched
function Presentation:SpecInfo(hud,p)
 local plate=hud.Plate;local av=plate:FindFirstChild("Avatar");local info=plate:FindFirstChild("Info")
 if av then
  local id=p and not isBot(p) and p.UserId or 0
  if av:GetAttribute("For")~=id then
   av:SetAttribute("For",id);av.Image=""
   if p then task.spawn(function()
    local ok,url=pcall(function()return Players:GetUserThumbnailAsync(id,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)end)
    if ok and av:GetAttribute("For")==id then av.Image=url end
   end)end
  end
 end
 if info then
  if not p then info.Text="" return end
  local lives,kills
  if isBot(p) then local e=botEntry(self.state,p);lives=e and e.l;kills=e and e.k or 0
  else lives=p:GetAttribute("Lives");kills=p:GetAttribute("RoundKills") or 0 end
  info.Text=(lives and (lives..(lives==1 and " LIFE" or " LIVES").."   ·   ") or "")..kills..(kills==1 and " ELIM" or " ELIMS")
 end
end
function Presentation:BlocksInput()return self.mode~=nil end
function Presentation:StartIntro(round)
 self:Stop();self.mode="intro";self.began=os.clock();self.introRound=round;self.held=false;self.introRan=false
 self.number=code(self.player);self.view:Show("HUD")
 self.gui.SequenceMatte.BackgroundColor3=Color3.fromRGB(3,3,5)
end
function Presentation:Death(data)
 if not self.player:GetAttribute("InArena")or self.state:GetAttribute("Phase")=="Results"then return end
 self:Stop();self.mode="death";self.began=os.clock();self.number=tostring(data and data.Code or code(self.player));self.deathCharacter=self.player.Character
 self.killerId=data and data.KillerId;self.killerCode=data and data.KillerCode and tostring(data.KillerCode)or nil
 -- the killcam names the killer (like the killfeed) and never shows their number
 local killerPlayer=self.killerId and Players:GetPlayerByUserId(self.killerId)
 self.killerName=killerPlayer and killerPlayer.DisplayName or nil
 self.player:SetAttribute("Killcam",true)
 self.respawnAt=os.clock()+Players.RespawnTime
 self.view:Show("HUD");self.view.open=true;self.gui:SetAttribute("PanelOpen",true)
 self.gui.SequenceMatte.BackgroundColor3=Color3.fromRGB(22,0,5)
 self.view.spectating=true
end
-- the lobby SPECTATE button: styled like the READY button (ink, red edge, corner ticks) and kept beside it, the same
-- height, to its right. It used to sit on top of READY's label once you'd readied up.
function Presentation:PlaceSpectateButton(b)
 if not b:GetAttribute("ReadyStyle")then
  b:SetAttribute("ReadyStyle",true)
  b.AutoButtonColor=false;b.BackgroundColor3=Color3.fromRGB(14,10,12);b.BackgroundTransparency=.12;b.Text=""
  local glow=b:FindFirstChild("Glow");if glow then glow.Visible=false end
  local c=b:FindFirstChildOfClass("UICorner")or Instance.new("UICorner");c.CornerRadius=UDim.new(0,4);c.Parent=b
  local e=b:FindFirstChild("SpecEdge")or Instance.new("UIStroke");e.Name="SpecEdge";e.Color=Color3.fromRGB(255,34,58);e.Thickness=1.5
  e.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;e.Parent=b
  local label=b:FindFirstChild("Label")
  if label then
   label.Text="SPECTATE";label.TextSize=24;label.TextColor3=Color3.fromRGB(238,233,230)
   label.AnchorPoint=Vector2.new(.5,0);label.Position=UDim2.new(.5,0,0,6);label.Size=UDim2.new(1,0,.55,0);label.TextScaled=false
  end
  local hint=Instance.new("TextLabel");hint.Name="SpecHint";hint.BackgroundTransparency=1;hint.AnchorPoint=Vector2.new(.5,1)
  hint.Position=UDim2.new(.5,0,1,-7);hint.Size=UDim2.new(1,0,0,12);hint.Text="WATCH THE ROUND";hint.TextSize=10
  hint.FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold);hint.TextColor3=Color3.fromRGB(160,146,146);hint.Parent=b
  for i,pos in ipairs({UDim2.fromOffset(6,6),UDim2.new(1,-6,1,-6)})do
   local a=Vector2.new(i==1 and 0 or 1,i==1 and 0 or 1)
   for _,sz in ipairs({UDim2.fromOffset(12,2),UDim2.fromOffset(2,12)})do
    local t=Instance.new("Frame");t.Name="SpecTick";t.AnchorPoint=a;t.Position=pos;t.Size=sz;t.BorderSizePixel=0
    t.BackgroundColor3=Color3.fromRGB(255,34,58);t.ZIndex=b.ZIndex+1;t.Parent=b
   end
  end
 end
 local rui=self.player:FindFirstChild("PlayerGui")and self.player.PlayerGui:FindFirstChild("ReadyUI")
 local root=rui and rui.Enabled and rui:FindFirstChild("Root")
 local btn=root and root.Visible and root:FindFirstChild("Button")
 if btn then
  local at=btn.AbsolutePosition-b.Parent.AbsolutePosition
  local w,h=math.floor(btn.AbsoluteSize.X*.62),math.floor(btn.AbsoluteSize.Y)
  b.AnchorPoint=Vector2.zero
  b.Size=UDim2.fromOffset(w,h)
  b.Position=UDim2.fromOffset(at.X+btn.AbsoluteSize.X+12,at.Y)
  local label=b:FindFirstChild("Label");if label then label.TextSize=math.clamp(math.floor(h*.44),16,26)end
 else
  b.AnchorPoint=Vector2.new(.5,1);b.Size=UDim2.fromOffset(190,52);b.Position=UDim2.new(.5,0,1,-118)
 end
end
function Presentation:Candidates()
 local list={}
 for _,p in ipairs(Players:GetPlayers())do if p~=self.player and living(p)then table.insert(list,p)end end
 table.sort(list,function(a,b)return a.UserId<b.UserId end)
 -- bots can be watched too (after the players)
 local bots=workspace:FindFirstChild("MatchBots")
 if bots then
  local b={}
  for _,m in ipairs(bots:GetChildren())do if m:IsA("Model")and living(m)then table.insert(b,m)end end
  table.sort(b,function(x,y)return nameOf(x)<nameOf(y)end)
  for _,m in ipairs(b)do table.insert(list,m)end
 end
 return list
end
function Presentation:SelectTarget(delta)
 local list=self:Candidates();self.roster=list
 local index=table.find(list,self.target)
 self.target=#list>0 and list[((index or (delta>0 and 0 or 2))-1+delta)%#list+1]or nil
 self.view.spectating=true
 local card=self.gui.SpectatorTransition.TargetCard
 card.Code.Text=code(self.target);card.Title.Text=self.target and "S P E C T A T I N G"or "WAITING FOR A PLAYER"
 pcall(NumberStyles.Skin,card.Code,(not isBot(self.target))and NumberStyles.Of(self.target)or nil,card.Code.Text)
 self:Portrait((not isBot(self.target))and self.target or nil,card.Avatar)
end
function Presentation:CanSpectate()
 return self.player:GetAttribute("InMatch")==true and self.player:GetAttribute("InArena")~=true
  and self.state:GetAttribute("Phase")=="Playing" and #self:Candidates()>0
end
function Presentation:StartSpectate()
 if not self:CanSpectate() then self.view:Toast("Nobody is playing a round right now.") return end
 self:Stop();self.mode="spectate";self.began=os.clock()
 self.player:SetAttribute("Killcam",true)
 self.view:Show("HUD")
 self:SelectTarget(1)
end
function Presentation:Cycle(delta)
 if self.mode=="spectate" then self:SelectTarget(delta) return end
 if self.mode~="death"then return end
 self:SelectTarget(delta);self.began=os.clock()-.8
end
function Presentation:Stop()
 self.serial=self.serial+1;self.mode=nil;self.target=nil;self.player:SetAttribute("Killcam",nil)
 self.gui.MatchIntro.Visible=false;self.gui.SpectatorTransition.Visible=false
 self.gui.SpectatorHUD.Visible=false;self.gui.SequenceMatte.Visible=false
 self.gui.SpectatorHUD.Lobby.Label.Text="LOBBY"
 if self.view.spectating then
  self.view:RestoreCamera()
  self.view.open=self.view.active~=nil;self.gui:SetAttribute("PanelOpen",self.view.open)
 end
 if self.camMode then self.player.CameraMode=self.camMode;self.camMode=nil end
 if self.zoomMin then self.player.CameraMinZoomDistance=self.zoomMin;self.player.CameraMaxZoomDistance=self.zoomMax;self.zoomMin=nil end
end
function Presentation:Step(now)
 local camera=workspace.CurrentCamera;if not camera then return end
 local viewport=self.gui.AbsoluteSize
 local phase=self.state:GetAttribute("Phase")
 local deployed=self.player:GetAttribute("InMatch")==true
 if not deployed or phase=="Results"then if self.mode then self:Stop()end;return end
 local round=self.state:GetAttribute("RoundId")or 0
 -- the round number is taken once when the countdown starts: the server bumps RoundId, EndsAt and Phase together
 -- at the round start but they can reach us a frame apart, and a RoundId that's already new while we still see the
 -- countdown used to look like ANOTHER round and replay the whole intro
 if phase~=self.lastPhase then
  if phase=="Countdown" then self.cdBase=round end
  self.lastPhase=phase
 end
 local nextRound=phase=="Countdown"and (self.cdBase or round)+1 or round
 -- the intro covers the screen the moment you're sent into the arena (the countdown), not a few seconds before
 -- the round: before, you could look round the arena while it waited. It holds on the black MARKED card and runs
 -- the number lock-in so it finishes as the round starts.
 local inArena=self.player:GetAttribute("InArena")==true
 local cue=inArena and (phase=="Playing" or phase=="Countdown")
 if cue and (self.introRound or -1)<nextRound then self:StartIntro(nextRound)end
 local specButton=self.gui.MatchHUD:FindFirstChild("Spectate")
 if specButton then
  specButton.Visible=self.mode==nil and self:CanSpectate() and not self.view.open
  if specButton.Visible then self:PlaceSpectateButton(specButton) end
 end
 if not self.mode then return end
 local elapsed=os.clock()-self.began
 if self.mode=="spectate" then
  if self.player:GetAttribute("InArena")==true or phase~="Playing" then self:Stop() return end
  if not(self.target and living(self.target)) then
   if #self:Candidates()==0 then self:Stop();self.view:Toast("The round has no players left to watch.") return end
   self:SelectTarget(1)
  end
  local hud=self.gui.SpectatorHUD;hud.Visible=true
  placeSpectator(hud,viewport)
  -- (the roster is re-read every frame: it used to be taken only when switching, so once the watched player died and
  -- respawned the switch arrows stayed hidden)
  self.roster=self:Candidates()
  hud.Previous.Visible=#self.roster>1;hud.Next.Visible=#self.roster>1
  hud.Plate.Title.Text="S P E C T A T I N G   ·   "..#self:Candidates().." ALIVE"
  hud.Plate.Code.Text=self.target and nameOf(self.target):upper() or "—"
  self:SpecInfo(hud,self.target)
  hud.Alive.Text=(#self.roster>1 and "A / D  SWITCH  ·  " or "").."HOLD RMB  LOOK  ·  X  LEAVE"
  -- (shrinks to fit beside the BACK button)
  if not hud.Alive:FindFirstChild("FitText") then
   local size=hud.Alive.TextSize;hud.Alive.TextScaled=true
   local c=Instance.new("UITextSizeConstraint");c.Name="FitText";c.MaxTextSize=size;c.MinTextSize=7;c.Parent=hud.Alive
  end
  hud.Lobby.Label.Text="BACK";hud.Lobby.Visible=true
  -- (a free cursor for the buttons -- except while right-click is held: that's the camera turning round them)
  if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then UIS.MouseBehavior=Enum.MouseBehavior.Default end
  UIS.MouseIconEnabled=true
  local h=self.target and living(self.target)
  if h then
   if not self.zoomMin then self.zoomMin=self.player.CameraMinZoomDistance;self.zoomMax=self.player.CameraMaxZoomDistance end
   self.player.CameraMaxZoomDistance=18;self.player.CameraMinZoomDistance=8
   if not self.camMode then self.camMode=self.player.CameraMode end
   self.player.CameraMode=Enum.CameraMode.Classic
   camera.CameraType=Enum.CameraType.Custom;if camera.CameraSubject~=h then camera.CameraSubject=h end
    -- your own body is back in the lobby, so the city only streams in around it: keep the area round whoever you're
    -- watching loaded (buildings, street lamps and their light), refreshed every couple of seconds as they move
    local r=h.RootPart
    if r and os.clock()-(self.streamAt or 0)>2 then
     self.streamAt=os.clock()
     local at=r.Position
     task.spawn(function() pcall(function() self.player:RequestStreamAroundAsync(at,4) end) end)
    end
  end
  return
 end
 local reduced=self.view.values.ReducedMotion==true or self.view.flashes==false
 local matte=self.gui.SequenceMatte
 if self.mode=="intro"then
  -- in the countdown the intro is timed off the round start: hold on the card until the lock-in has to begin
  local hold=false
  local left=(self.state:GetAttribute("EndsAt")or now)-now
  -- (an EndsAt that's already the round's -- minutes away -- is ignored, and once the lock-in has started the
  -- intro only ever moves forward: it can't rewind and play twice)
  if phase=="Countdown" and left<=30 then
   local target=INTRO.Finish-left
   if target<0 and not self.introRan then hold=true;elapsed=0;self.held=true
   else self.introRan=true;elapsed=math.min(math.max(target,elapsed),INTRO.Finish-.05) end
   self.began=os.clock()-elapsed
  end
  -- your number arrives with your arena body: scramble until it's there
  local c=code(self.player);if c~="----" then self.number=c end
  if elapsed>=INTRO.Finish then self:Stop();return end
  local intro=self.gui.MatchIntro;fit(intro,1000,560,viewport)
  intro.Visible=true;matte.Visible=true
  -- (no fade-in when it started straight away: the screen goes black at once, so the arena never shows)
  matte.BackgroundTransparency=(hold or (self.held and elapsed<INTRO.Fade)) and 0 or elapsed<INTRO.Fade and 1-elapsed/INTRO.Fade or elapsed>INTRO.Reveal and math.clamp((elapsed-INTRO.Reveal)/(INTRO.Finish-INTRO.Reveal),0,1)or 0
  intro.Fade.Visible=elapsed<INTRO.Fade;intro.Lock.Visible=elapsed>=INTRO.Fade and elapsed<INTRO.Lock
  local scrambling=(elapsed>=INTRO.Fade and elapsed<INTRO.Scramble) or (self.number=="----" and elapsed>=INTRO.Fade)
  intro.Lock.Brackets.Visible=elapsed>=INTRO.Scramble
  -- the black number panel (red border) is up from the start, behind the rolling digits, instead of filling in
  -- after them
  intro.Lock.NumberBox.Visible=true
  intro.Lock.Caption.Visible=elapsed>=INTRO.Scramble
  intro.Fade.Logo.ImageTransparency=reduced and .35 or .42+.17*math.abs(math.sin(elapsed*24))
  intro.Reveal.Visible=elapsed>=INTRO.Lock and elapsed<INTRO.Reveal
  intro.City.ImageTransparency=.97
  intro.Glitch.Visible=not reduced and scrambling
  local tick=math.floor(elapsed*16)
  local digits=self.number
  -- the number rolls before it locks in (always: Reduced motion / Flashes only drop the glitch bars over it)
  if scrambling then digits=string.format("%04d",(tick*1789+(tonumber(self.number)or 0))%10000)end
  intro.Lock.Number.Text=digits
  -- round line (eyebrow on the number card, footer on the logo card)
  local inArena=0;for _,p in ipairs(Players:GetPlayers())do if p:GetAttribute("InArena")==true then inArena+=1 end end
  local roundNo=self.introRound or self.state:GetAttribute("RoundId") or 1
  local eb=intro.Lock:FindFirstChild("Eyebrow");if eb then eb.Text="ROUND "..roundNo.."   ·   "..inArena.." IN THE ARENA" end
  local ri=intro.Reveal:FindFirstChild("RoundInfo");if ri then ri.Text="ROUND "..roundNo.."   ·   "..inArena..(inArena==1 and " PLAYER" or " PLAYERS").."   ·   GOOD LUCK" end
  -- lock-in: the plate punches in, the brackets snap shut and a white flash, as the scramble stops
  local k=math.clamp((elapsed-INTRO.Scramble)/.28,0,1);local ease=1-(1-k)^3
  local punch=intro.Lock.NumberBox:FindFirstChild("Punch");if punch then punch.Scale=reduced and 1 or (elapsed<INTRO.Scramble and .97 or 1.08-.08*ease) end
  local close=intro.Lock.Brackets:FindFirstChild("Close");if close then close.Scale=reduced and 1 or (elapsed<INTRO.Scramble and 1.18 or 1.18-.18*ease) end
  local flash=intro.Lock:FindFirstChild("Flash");if flash then flash.BackgroundTransparency=(reduced or elapsed<INTRO.Scramble) and 1 or math.clamp(.35+(elapsed-INTRO.Scramble)*3,0,1) end
  local glow=intro.Lock:FindFirstChild("Glow");if glow then glow.Size=UDim2.fromOffset(elapsed<INTRO.Scramble and 120 or 120+260*ease,3) end
  -- the logo card grows in slowly
  local grow=intro.Reveal.Logo:FindFirstChild("Grow");if grow then grow.Scale=reduced and 1 or .94+.06*math.clamp((elapsed-INTRO.Lock)/(INTRO.Reveal-INTRO.Lock),0,1) end
  local numStyle=NumberStyles.Of(self.player)
  for i=0,3 do local d=intro.Lock["Digit"..i];d.Text=digits:sub(i+1,i+1);NumberStyles.Skin(d,numStyle,d.Text,{fill=.96})end
  if scrambling and not reduced then
   for row=0,3 do
    local echo=string.format("%04d",(tick*317+row*2371)%10000)
    for i=0,3 do intro.Glitch["Echo"..row.."_"..i].Text=echo:sub(i+1,i+1)end
   end
   for i=0,143 do
    local bar=intro.Glitch["Bar"..i]
    bar.Visible=(i+tick)%5~=0
    bar.Position=UDim2.fromOffset(246+(i*137+tick*(i%3+1)*7)%508,66+(i*53+tick*11)%424)
   end
  end
  intro.Glitch.Position=UDim2.fromOffset(0,0)
  intro.Reveal.Logo.ImageTransparency=reduced and 0 or .025+.045*math.abs(math.sin(elapsed*4))
  if elapsed>=INTRO.Reveal then intro.Visible=false end
 else
  if living(self.player)and(self.player.Character~=self.deathCharacter or elapsed>.25)then self:Stop();return end
  -- killcam target: the player who wrote your number (yourself / nobody: your own body)
  local killer=self.killerId and self.killerId~=self.player.UserId and Players:GetPlayerByUserId(self.killerId)or nil
  self.target=killer and living(killer)and killer or nil
  -- 0-1.3s: red flash then the ELIMINATED card; after that the killcam with a small plate up top
  local transition=self.gui.SpectatorTransition;fit(transition,740,450,viewport)
  local card=elapsed<1.3
  -- the big ELIMINATED moment is the KillBanner death band now; the old card stays hidden
  transition.Visible=false;matte.Visible=true
  matte.BackgroundTransparency=elapsed<.15 and .2 or card and .35 or math.min(.82,.35+(elapsed-1.3)*1.2)
  transition.Eliminated.Visible=card
  transition.Eliminated.Code.Text=self.number
  transition.Switch.Visible=false;transition.TargetCard.Visible=false
  if transition:FindFirstChild("ScanLines")then transition.ScanLines.Visible=false end
  local hud=self.gui.SpectatorHUD;hud.Visible=elapsed>=1.1
  placeSpectator(hud,viewport)
  hud.Previous.Visible=false;hud.Next.Visible=false
  local selfInflicted=self.killerId==self.player.UserId
  hud.Plate.Title.Text=selfInflicted and "Y O U   W R O T E   Y O U R S" or self.killerName and "E L I M I N A T E D   B Y" or "E L I M I N A T E D"
  hud.Plate.Code.Text=selfInflicted and self.player.DisplayName:upper() or self.killerName and self.killerName:upper() or "—"
  self:SpecInfo(hud,selfInflicted and self.player or killer or nil)
  local remaining=math.max(0,math.ceil((self.respawnAt or os.clock())-os.clock()))
  local livesLeft=self.player:GetAttribute("Lives")
   if livesLeft~=nil and livesLeft<=0 and self.state:GetAttribute("Phase")=="Playing" then hud.Alive.Text="OUT OF LIVES  ·  BACK TO THE LOBBY"
   else hud.Alive.Text=(livesLeft and (livesLeft..(livesLeft==1 and " LIFE LEFT   ·   " or " LIVES LEFT   ·   ")) or "")..(remaining>0 and("RESPAWNING IN "..remaining)or "RESPAWNING…") end
  hud.Lobby.Visible=false
  if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then UIS.MouseBehavior=Enum.MouseBehavior.Default end
  UIS.MouseIconEnabled=true
  self.player.CameraMode=Enum.CameraMode.Classic
  local h=self.target and living(self.target)
  local body=self.deathCharacter and self.deathCharacter:FindFirstChildOfClass("Humanoid")
  local subject=h or body
  if subject then
   if not self.zoomMin then self.zoomMin=self.player.CameraMinZoomDistance;self.zoomMax=self.player.CameraMaxZoomDistance end
   self.player.CameraMaxZoomDistance=h and 16 or 12;self.player.CameraMinZoomDistance=h and 8 or 6
   camera.CameraType=Enum.CameraType.Custom;if camera.CameraSubject~=subject then camera.CameraSubject=subject end
  end
 end
end
return Presentation
