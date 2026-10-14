-- Uses the authored StarterGui objects. No runtime-generated legacy screens.
local NumberStyles=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NumberStyles"))
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local View={};View.__index=View
-- phones / tablets (touch, no keyboard) always run in low end mode
local function isMobile()return UIS.TouchEnabled and not UIS.KeyboardEnabled end
-- consoles (the 10-foot interface) run low end mode too
local function isConsole()local ok,v=pcall(function()return game:GetService("GuiService"):IsTenFootInterface()end)return ok and v==true end
local function forcedLowEnd()return isMobile() or isConsole() end
local RED=Color3.fromRGB(255,8,56)
local WHITE=Color3.fromRGB(238,233,230)
local panels={"Lobby","Inventory","Shop","Quests","Settings","Results","Help","Entry","Credits","PatchNotes","Leaderboard"}
local function caption(button,value)button.Label.Text=tostring(value)end
local function clock(seconds)seconds=math.max(0,math.floor(seconds));return string.format("%02d:%02d",math.floor(seconds/60),seconds%60)end
function View.new(player,gui,shared,config,rules,catalog)
 local self=setmetatable({player=player,gui=gui,shared=shared,config=config,rules=rules,catalog=catalog,values=rules.Sanitize(),open=true,active="Lobby",page=1,feed={},feedEnabled=true,move={},lastRefresh=0},View)
 gui:SetAttribute("DemoMode",false);gui.Enabled=true
 local function logoAsset()
  local art=gui.Lobby:FindFirstChild("LogoArtwork");if not art then return end
  local enabled=art.Image~=""and art.Image~="rbxassetid://0"
  art.Visible=enabled
  for _,item in ipairs(gui.Lobby:GetChildren())do
   if item.Name=="Logo"or item.Name=="LogoRedK"or item.Name:match("^LetterFracture")then item.Visible=not enabled end
  end
 end
 logoAsset()
 if gui.Lobby:FindFirstChild("LogoArtwork")then gui.Lobby.LogoArtwork:GetPropertyChangedSignal("Image"):Connect(logoAsset)end
 self.remote=shared:WaitForChild("Menu")
 self.settingsRemote=shared:WaitForChild("Settings")
 self.templates={Book=gui.Inventory.Slot4.Artwork:Clone(),Pen=gui.Inventory.Slot5.Artwork:Clone()}
 for _,p in ipairs(panels)do gui[p].Visible=p=="Lobby" end
 gui.Toast.Visible=false;gui.Flash.BackgroundTransparency=1
 for _,b in ipairs(gui:GetDescendants())do
  if b:IsA("TextButton")then
   b.Modal=not b:IsDescendantOf(gui.MatchHUD) and not b:IsDescendantOf(gui.Entry) -- Modal frees the mouse in first person; number entry keeps the camera on the mouse
   local outline=b:FindFirstChild("Outline")
   if outline then
    b.MouseEnter:Connect(function()if b:GetAttribute("Locked")then return end;b:SetAttribute("RestingBorder",outline.Color);outline.Color=RED end)
    b.MouseLeave:Connect(function()if b:GetAttribute("Locked")then return end;outline.Color=b:GetAttribute("RestingBorder") or outline.Color end)
   end
  end
 end
 for _,p in ipairs(panels)do local close=gui[p]:FindFirstChild("Close");if close then close.Activated:Connect(function()self:Show(nil)end)end end
 local function deploy()self:Toast("Entering the arena…");self.remote:FireServer("Play")end
 gui.Lobby.Deploy.Activated:Connect(deploy)
 gui.Lobby.Credits.Activated:Connect(function()self:Show("Credits")end)
 gui.Lobby.PatchNotes.Activated:Connect(function()self:Show("PatchNotes")end)
 gui.Lobby.Community.Activated:Connect(function()player:SetAttribute("OpenCommunity",os.clock())end) -- StarterPlayerScripts.CommunityCard
 gui.Lobby.PlayerCard.DisplayName.Text=player.DisplayName
 gui.Lobby.PlayerCard.Username.Text="@"..player.Name
 task.spawn(function()
  local ok,content=pcall(function()return Players:GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)end)
  if ok then gui.Lobby.PlayerCard.Avatar.Image=content end
 end)
 for _,p in ipairs({"Inventory","Shop","Quests","Settings"})do gui.Lobby[p].Activated:Connect(function()self:Show(p)end)end
 self:ApplyLocks()
 -- redeem codes (main menu): small popup, the server checks the code and replies with a toast
 do
  local popup=gui.CodesPopup
  local function close()popup.Visible=false;popup.Input.Text=""end
  gui.Lobby.Codes.Activated:Connect(function()popup.Visible=not popup.Visible;if popup.Visible then popup.Input:CaptureFocus()end end)
  popup.Close.Activated:Connect(close)
  local function redeem()local text=popup.Input.Text;if text:gsub("%s","")~=""then self.remote:FireServer("Redeem",text);close()end end
  popup.Redeem.Activated:Connect(redeem)
  popup.Input.FocusLost:Connect(function(enter)if enter then redeem()end end)
  player:GetAttributeChangedSignal("InMatch"):Connect(close)
 end
 -- daily quests on the main menu: a COLLECT button appears on a row once its quest is done
 for i=1,3 do
  local row=gui.Lobby.DailyQuests["Row"..(i-1)]
  local b=Instance.new("TextButton");b.Name="Collect";b.AutoButtonColor=false;b.Visible=false
  b.Position=UDim2.fromOffset(268,6);b.Size=UDim2.fromOffset(68,36);b.ZIndex=8
  b.BackgroundColor3=Color3.fromRGB(150,14,34);b.BackgroundTransparency=.08;b.Text="COLLECT"
  b.FontFace=row.Title.FontFace;b.TextSize=13;b.TextColor3=Color3.fromRGB(255,240,236);b.Modal=true
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,4);c.Parent=b
  local st=Instance.new("UIStroke");st.Color=Color3.fromRGB(255,70,90);st.Thickness=1;st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Parent=b
  b.MouseEnter:Connect(function()b.BackgroundColor3=Color3.fromRGB(190,22,46)end)
  b.MouseLeave:Connect(function()b.BackgroundColor3=Color3.fromRGB(150,14,34)end)
  b.Activated:Connect(function()self.remote:FireServer("ClaimQuest",i)end)
  b.Parent=row
 end
 gui.Inventory.Reset.Activated:Connect(function()self.remote:FireServer("Equip","Classic")end)
 for i=1,4 do gui.Quests["Quest"..(i-1)].Claim.Activated:Connect(function()self.remote:FireServer(self.redesign and self.redesign.questTab==2 and "ClaimSeasonQuest"or "ClaimQuest",i)end)end
 gui.Quests.Daily.Claim.Activated:Connect(function()self.remote:FireServer("ClaimDaily")end)
 for _,entry in ipairs(rules.Items)do
  gui.Settings.Options[entry.Id].Value.Activated:Connect(function()
   if entry.Id=="LowEnd" and forcedLowEnd() then self:Toast(isConsole() and "Low end mode is always on for consoles." or "Low end mode is always on for mobile.");return end
   local index=table.find(entry.Values,self.values[entry.Id])or 1
   self.values[entry.Id]=entry.Values[index%#entry.Values+1];self.dirty=true;self:Apply()
  end)
 end
 gui.Settings.Feed.Activated:Connect(function()self.feedEnabled=not self.feedEnabled;caption(gui.Settings.Feed,self.feedEnabled and "KILLFEED: ON" or "KILLFEED: OFF")end)
 gui.Settings.Motion.Activated:Connect(function()self.values.ReducedMotion=not self.values.ReducedMotion;self.dirty=true;self:Apply()end)
 gui.Settings.Reset.Activated:Connect(function()self.values=rules.Sanitize();self.dirty=true;self:Apply()end)
 gui.Results.Again.Activated:Connect(function()if player:GetAttribute("InMatch")then self:Show("HUD")else deploy()end end)
 local function lobby()self:RestoreCamera();self.remote:FireServer("Menu")end
 gui.Results.Lobby.Activated:Connect(lobby)
 shared.MenuReply.OnClientEvent:Connect(function(message)self:Toast(tostring(message));self:RefreshProfile()end)
 self.settingsRemote.OnClientEvent:Connect(function(ok)
  if ok then self.dirty=false;self:Toast("Preferences saved.")else self:Toast("Preferences could not save. Close settings to retry.")end
 end)
 player:GetAttributeChangedSignal("ProfileReady"):Connect(function()self:LoadSettings();self:RefreshProfile()end)
 player:GetAttributeChangedSignal("InMatch"):Connect(function()self:Show(player:GetAttribute("InMatch")and "HUD"or "Lobby")end)
 player.CharacterAdded:Connect(function()self:RestoreCamera();if player:GetAttribute("InMatch")then self:Show("HUD")end end)
 local function phase()
  local p=shared:GetAttribute("Phase")
  if player:GetAttribute("InMatch") and player:GetAttribute("InArena") then
   -- the results now show on the VictoryScreen overlay; the old Results panel stays closed
   if self.active=="Results"then self:Show("HUD")end
  end
 end
 shared:GetAttributeChangedSignal("Phase"):Connect(phase)
 self.redesign=require(gui:WaitForChild("ReferenceMenusV3")).new(self)
 -- elimination banners + end-of-round victory screen (built at runtime on their own ScreenGuis)
 self.killBanner=require(gui:WaitForChild("KillBanner")).new(self)
 self:LoadSettings();self:RefreshProfile();self:Show(player:GetAttribute("InMatch")and "HUD"or "Lobby");phase()
 self.feedback=require(gui:WaitForChild("CombatFeedback")).new(self)
 self.presentation=require(gui:WaitForChild("RoundPresentation")).new(self)
 self.menuMotion=require(gui:WaitForChild("MenuMotion")).new(self)
 self.marksStore=require(gui:WaitForChild("MarksStoreController")).new(self)
 self.matchHud=require(gui:WaitForChild("MatchHUDController")).new(self)
 self.spotted=self.spotted or {}
 self.minimap=require(gui:WaitForChild("MinimapController")).new(self)
 self.leaderboard=require(gui:WaitForChild("LeaderboardController")).new(self)
 self.menuSounds=require(gui:WaitForChild("MenuSounds")).new(self)
 self.victory=require(gui:WaitForChild("VictoryScreen")).new(self)
 self.staminaBar=require(gui:WaitForChild("StaminaBar")).new(self)
 self.menuScenery=require(gui:WaitForChild("MenuScenery")).new(self) -- the main menu films the map behind itself
 gui:SetAttribute("Ready",true)
 return self
end
function View:Selected(b,on)
 local gradient=b:FindFirstChild("SurfaceGradient")
 if gradient and gradient.Enabled then
  b.BackgroundColor3=Color3.new(1,1,1)
  gradient.Color=ColorSequence.new(on and Color3.fromRGB(150,0,30)or Color3.fromRGB(18,16,18),on and Color3.fromRGB(65,0,12)or Color3.fromRGB(8,8,9))
 else
  b.BackgroundColor3=on and Color3.fromRGB(82,0,20)or Color3.fromRGB(9,7,10)
 end
 b.BackgroundTransparency=on and .05 or .12
 if b:FindFirstChild("Glow")then b.Glow.Visible=on end
 if b:FindFirstChild("TopShine")then b.TopShine.Visible=on end
 if b:FindFirstChild("Outline")then
  b.Outline.Color=on and RED or Color3.fromRGB(119,26,46)
  b:SetAttribute("RestingBorder",b.Outline.Color)
  if b.Name:match("^Category%d") or b.Name:match("^Tab%d") then b.BackgroundColor3=on and Color3.fromRGB(110,0,28) or Color3.fromRGB(10,6,8);b.BackgroundTransparency=on and .05 or .15 end
 end
end
-- notifications go to the stacked cards at the top of the screen (ReplicatedStorage.Numberfall.TopNotices);
-- the old bottom-centre Toast label stays hidden
local TopNotices=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("TopNotices"))
local ERRORS={"first","could not","coming soon","nobody","no players","already","invalid","expired","not enough","can't","cannot"}
function View:Toast(message,kind)
 message=tostring(message or "")
 if not kind then
  local lower=message:lower();kind="info"
  for _,w in ipairs(ERRORS)do if lower:find(w,1,true)then kind="bad";break end end
  if kind=="info"and(lower:find("saved",1,true)or lower:find("redeemed",1,true)or lower:find("purchased",1,true)or lower:find("equipped",1,true)or lower:find("level up",1,true)or lower:find("collected",1,true)or lower:find("claimed",1,true)or lower:find("%+%d"))then kind="good"end
 end
 TopNotices.Push(message,{kind=kind,eyebrow=kind=="bad"and"NOT NOW"or kind=="good"and"DONE"or nil})
end
-- TEMPORARILY LOCKED menus: greyed out everywhere they can be opened from, and they show "Coming soon" instead
-- of opening. Empty this table to unlock them again (the greyed look is also saved on the buttons in the editor:
-- they carry a Locked attribute and a SoonTag, so clear those too).
View.Locked={}
local function grey(c,k)local l=c.R*.3+c.G*.59+c.B*.11;return Color3.new(l*k,l*k,l*k)end
-- full = recolour the whole button grey (menu buttons); otherwise lay a dark shade over it (painted icon buttons)
function View:LockButton(b,full)
 if not b or b:GetAttribute("Locked")then return end
 b:SetAttribute("Locked",true);b.AutoButtonColor=false
 if not full then
  local shade=Instance.new("Frame");shade.Name="LockedShade";shade.Size=UDim2.fromScale(1,1);shade.BorderSizePixel=0
  shade.BackgroundColor3=Color3.fromRGB(10,8,9);shade.BackgroundTransparency=.38;shade.ZIndex=60
  local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,6);corner.Parent=shade
  shade.Parent=b
  return
 end
 for _,d in ipairs(b:GetDescendants())do
  if d:IsA("TextLabel")then d.TextColor3=grey(d.TextColor3,.72);d.TextTransparency=math.max(d.TextTransparency,.3)
  elseif d:IsA("ImageLabel")then d.ImageColor3=grey(d.ImageColor3,.6);d.ImageTransparency=math.max(d.ImageTransparency,.45)
  elseif d:IsA("UIStroke")then d.Color=grey(d.Color,.5)
  elseif d:IsA("UIGradient")then local k=d.Color.Keypoints;d.Color=ColorSequence.new(grey(k[1].Value,.7),grey(k[#k].Value,.7))
  elseif d:IsA("Frame")and d.BackgroundTransparency<1 then d.BackgroundColor3=grey(d.BackgroundColor3,.6)end
 end
 b.BackgroundColor3=grey(b.BackgroundColor3,.6)
 local label=b:FindFirstChild("Label")
 local tag=Instance.new("TextLabel");tag.Name="SoonTag";tag.BackgroundTransparency=1;tag.Text="SOON"
 if label then tag.FontFace=label.FontFace end
 tag.TextSize=13;tag.TextColor3=Color3.fromRGB(150,138,138);tag.AnchorPoint=Vector2.new(1,.5)
 tag.Position=UDim2.new(1,-44,.5,0);tag.Size=UDim2.fromOffset(70,20);tag.TextXAlignment=Enum.TextXAlignment.Right;tag.ZIndex=b.ZIndex+6
 tag.Parent=b
end
function View:ApplyLocks()
 local g=self.gui
 for name in pairs(View.Locked)do self:LockButton(g.Lobby:FindFirstChild(name),true)end
 local rail=g.MatchHUD:FindFirstChild("Rail")
 -- (the rail's people icon opens the players leaderboard, not credits, so it stays usable)
 if rail then for name in pairs(View.Locked)do if name~="Credits"then self:LockButton(rail:FindFirstChild(name))end end end
 local side=g.MatchHUD:FindFirstChild("SideButtons")
 if side and View.Locked.Quests then self:LockButton(side:FindFirstChild("Quests"))end
end
-- once a round has started (you're in the arena) the shop, loadout and quests wait until it's over
local ROUND_LOCKED={Shop=true,Inventory=true,Quests=true}
function View:Show(name)
 if name and View.Locked[name]then self:Toast("Coming soon");return end
 if name and ROUND_LOCKED[name] and self.player:GetAttribute("InArena")==true then self:Toast("Not during a round");return end
 -- In-match menus stay in the lobby. Number entry and end-of-round results are the only panels.
 if self.player:GetAttribute("InMatch") and name~="Entry" and name~="Results" and name~="Settings" and name~="Help" and name~="Shop" and name~="Inventory" and name~="Quests" and name~="Credits" and name~="Leaderboard" then name="HUD" end
 if not name or name=="HUD"then
  if self.player:GetAttribute("InMatch")then name=nil else name="Lobby"end
 end
 if self.active=="Settings"and name~="Settings"and self.dirty then self.settingsRemote:FireServer(self.values)end
 if name=="Leaderboard" and self.leaderboard then self.leaderboard.nextRefresh=0 end
 -- open / close transition + sound for the big menus
 local QUIET={Entry=true,Results=true,Lobby=true}
 if name~=self.active then
  self.shownAt=os.clock()
  if self.sound and self.menuSounds and not self.peek then
   if name and not QUIET[name] then self.menuSounds:Play("UIOpen",nil,.15)
   elseif self.active and not QUIET[self.active] then self.menuSounds:Play("UIClose",nil,.15)end
  end
 end
 self.active=name;self.open=name~=nil
 self.gui:SetAttribute("PanelOpen",self.open)
 for _,p in ipairs(panels)do self.gui[p].Visible=p==name end
 -- Number entry is a light overlay: you keep running, the mouse stays locked and the camera keeps turning.
 -- Help (H) is an overlay too: you keep moving and turning while you read it; H closes it
 local light=name=="Entry" or name=="Help" or (name=="Leaderboard" and self.peek)
 -- holding Tab only peeks: keep the mouse on the camera; opened with L / the icon it frees the mouse for clicking
 if name=="Leaderboard" then for _,b in ipairs(self.gui.Leaderboard:GetDescendants())do if b:IsA("GuiButton")then b.Modal=not self.peek end end end
 if self.feel and not light and name~="Leaderboard" then self.feel:SetSprint(false)end
 if self.open and not light then
  if self.savedMode==nil then self.savedMode=self.player.CameraMode end
  self.player.CameraMode=Enum.CameraMode.Classic;UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true
 elseif self.savedMode then self.player.CameraMode=self.savedMode;self.savedMode=nil end
 self:RefreshProfile()
end
function View:Toggle(value)if value==false then self:Show(nil)else self:Show(self.active=="Settings"and "HUD"or "Settings")end end
function View:ToggleHelp()self:Show(self.active=="Help"and "HUD"or "Help")end
function View:CanType()return not(self.presentation and self.presentation:BlocksInput()) and (not self.open or self.active=="Entry" or self.active=="Help")end
function View:BindConfirm(confirm)
 self.gui.Entry.Confirm.Activated:Connect(confirm)
end
function View:Attach(sound,feel)
 self.sound=sound;self.feel=feel
 local labels={Digit="Writing",Submit="Number submitted",Miss="Incorrect number",Kill="Elimination",Death="Eliminated",Slide="Sliding",Land="Landed",Spawn="Respawned",Round="Round changed"}
 sound.caption=function(name)if self.values.Captions and labels[name]then self.gui.Caption.Text=labels[name];self.captionUntil=os.clock()+1.5 end end
 self:Apply()
end
function View:LoadSettings()
 if self.dirty then return end
 local raw={};for _,item in ipairs(self.rules.Items)do raw[item.Id]=self.player:GetAttribute("Setting_"..item.Id)end
 self.values=self.rules.Sanitize(raw);self:Apply()
end
function View:Apply()
 local v=self.values
 if self.sound then self.sound.group.Volume=v.Volume;self.sound.typingSounds=v.TypingSounds end
 if self.feel then self.feel.reduced=v.ReducedMotion end
 self.flashes=v.Flashes;self.sprintKey=v.SprintKey;self.slideKey=v.SlideKey
 UIS.MouseDeltaSensitivity=v.Sensitivity;self.player:SetAttribute("LocalReducedMotion",v.ReducedMotion)
 -- low end mode (StarterPlayerScripts.LowEndMode reads this): the setting, or forced on for mobile
 local mobile=isMobile()
 if mobile then v.LowEnd=true end
 self.player:SetAttribute("LowEnd",v.LowEnd==true or mobile or isConsole())
 self.player:SetAttribute("LowEndForced",mobile)
 -- music volume (StarterPlayerScripts.MarkedMusic), the elimination feed and the performance overlay (FPSCounter)
 self.player:SetAttribute("LocalMusicVolume",v.MusicVolume);self.feedEnabled=v.Killfeed~=false;self.player:SetAttribute("ShowStats",v.ShowStats==true)
 local NICE={LeftShift="Left Shift",RightShift="Right Shift",CapsLock="Caps Lock"}
 for _,entry in ipairs(self.rules.Items)do local x=v[entry.Id];caption(self.gui.Settings.Options[entry.Id].Value,type(x)=="boolean"and(x and "ON"or "OFF")or NICE[x] or x)end
 caption(self.gui.Settings.Motion,v.ReducedMotion and "MOTION: REDUCED"or "MOTION: FULL")
 if self.redesign then self.redesign:Settings()end
end
function View:TintPreview(container,item,pen)
 if container.Parent:GetAttribute("ReferenceV3")then return end
 local old=container:FindFirstChild("Artwork");local pos=old and old.Position or UDim2.fromOffset(4,23);local size=old and old.Size or UDim2.fromOffset(89,61)
 if old then old:Destroy()end
 local art=(pen and self.templates.Pen or self.templates.Book):Clone();art.Parent=container
 local scale=math.min(size.X.Offset/art.Size.X.Offset,size.Y.Offset/art.Size.Y.Offset)
 local scaler=Instance.new("UIScale");scaler.Scale=scale;scaler.Parent=art
 art.Position=UDim2.fromOffset(pos.X.Offset+(size.X.Offset-art.Size.X.Offset*scale)/2,pos.Y.Offset+(size.Y.Offset-art.Size.Y.Offset*scale)/2)
 local tint=Color3.fromRGB(table.unpack(pen and item.Pencil or item.Color))
 for _,p in ipairs(art:GetDescendants())do
  if p:IsA("UIStroke")then p.Color=tint
  elseif p:IsA("Frame")and p.BackgroundTransparency<1 then
   local c=p.BackgroundColor3;if c.R>c.G*1.4 and c.R>c.B*1.15 then p.BackgroundColor3=tint end
  end
 end
end
function View:RefreshShop()
 if self.redesign then self.redesign:Shop()end
end
function View:RefreshProfile()
 local p=self.player;local marks=p:GetAttribute("Coins")or 0
 self.gui.Lobby.Profile.Text=p:GetAttribute("ProfileReady")and(tostring(marks).." MARKS  /  "..tostring(p:GetAttribute("XP")or 0).." XP  /  "..(p:GetAttribute("ProfileStorage")or "Session only"))or "PROFILE LOADING…"
 local xp=p:GetAttribute("XP")or 0
 self.gui.Lobby.PlayerCard.Marks.Text='MARKS: <font color="#ff174a" size="22">'..marks..'</font>'
 -- level, progress through it and the goal come from the server (ProfileService level curve)
 local level=p:GetAttribute("Level")or 1;local into=p:GetAttribute("LevelXP")or 0;local goal=math.max(1,p:GetAttribute("LevelGoal")or 300)
 self.gui.Lobby.PlayerCard.Level.Text='<font size="15">LV.</font> '..level
 self.gui.Lobby.PlayerCard.Track.Fill.Size=UDim2.fromOffset(self.gui.Lobby.PlayerCard.Track.Size.X.Offset*math.clamp(into/goal,0,1),self.gui.Lobby.PlayerCard.Track.Size.Y.Offset)
 self.gui.Lobby.PlayerCard.XP.Text=tostring(into).." / "..tostring(goal).." XP"
 local finish=p:GetAttribute("NotebookFinish")or "Classic"
 for _,item in ipairs(self.catalog)do if item.Id==finish then
  self.gui.Inventory.Slot4.ItemName.Text=item.Name;self.gui.Inventory.Slot5.ItemName.Text="Matching pen"
  if self.lastFinish~=finish then self.lastFinish=finish;self:TintPreview(self.gui.Inventory.Slot4,item,false);self:TintPreview(self.gui.Inventory.Slot5,item,true)end
 end end
 for i=2,3 do self.gui.Inventory["Slot"..i].ItemName.Text="Coming soon"end;for i=0,3 do caption(self.gui.Inventory["Slot"..i].Change,"↻")end
 self:RefreshShop()
 for i=1,3 do
  local row=self.gui.Quests["Quest"..(i-1)];local goal=p:GetAttribute("Quest"..i.."Goal")or({3,2,5})[i];local progress=p:GetAttribute("Quest"..i.."Progress")or 0
  row.Progress.Text=progress.." / "..goal;row.Fill.Size=UDim2.fromOffset(row.Track.Size.X.Offset*math.clamp(progress/goal,0,1),row.Track.Size.Y.Offset)
  caption(row.Claim,p:GetAttribute("Quest"..i.."Claimed")and "✓"or "+"..tostring(p:GetAttribute("Quest"..i.."Reward")or({50,30,25})[i]))
  local preview=self.gui.Lobby.DailyQuests["Row"..(i-1)]
  -- today's quests rotate daily (ProfileService picks them); titles and rewards come from the server
  local title=p:GetAttribute("Quest"..i.."Title")
  if title then preview.Title.Text=title;if row:FindFirstChild("Title")then row.Title.Text=title end end
  preview.Reward.Text="+"..tostring(p:GetAttribute("Quest"..i.."Reward")or 0)
  preview.Progress.Text=progress.." / "..goal
  preview.Track.Fill.Size=UDim2.fromOffset(151*math.clamp(progress/goal,0,1),6)
  local claimed=p:GetAttribute("Quest"..i.."Claimed")==true
  local collect=preview:FindFirstChild("Collect")
  if collect then collect.Visible=progress>=goal and not claimed end
  if claimed then preview.Reward.Text="✓" end
 end
 local claimable=false
 for qi=1,4 do
  if not p:GetAttribute("Quest"..qi.."Claimed") and (p:GetAttribute("Quest"..qi.."Progress")or 0)>=(p:GetAttribute("Quest"..qi.."Goal")or ({3,2,5,1200})[qi])then claimable=true end
 end
 self.gui.Lobby.Quests.ClaimableBadge.Visible=claimable and not View.Locked.Quests
 caption(self.gui.Quests.Daily.Claim,p:GetAttribute("DailyClaimed")and "CLAIMED"or "CLAIM DAILY REWARD")
 if self.redesign then self.redesign:Refresh()end
end
function View:SetMovement(sliding,running,cooldown,reduced)self.move={sliding=sliding,running=running,cooldown=cooldown,reduced=reduced}end
function View:ConfirmKill(victim,combo)
 -- Compact feedback is driven by the authoritative Submit response (CombatFeedback banner).
end
function View:DeathFlash(data)
 if self.presentation then self.presentation:Death(data)end
 self.feedback:Death(data)
 if self.flashes~=false then self.gui.Flash.BackgroundTransparency=.9;Tween:Create(self.gui.Flash,TweenInfo.new(.4),{BackgroundTransparency=1}):Play()end
 if not self.presentation then self:Show("HUD")end
end
function View:AddKill(data,now)
 table.insert(self.feed,1,{data=data,time=now});while #self.feed>5 do table.remove(self.feed)end
end
function View:SetTarget(target)
 local box=self.gui.TargetLock
 box.Visible=target~=nil and (not self.open or self.active=="Entry") and self.player:GetAttribute("InMatch")==true
 if box.Visible then
  -- corner brackets hugging the visor digits only (sized to the digits on screen, not the head)
  if not box:FindFirstChild("Brackets")then
   box.Art.Visible=false;box.Number.Visible=false;box.BackgroundTransparency=1
   local holder=Instance.new("Folder");holder.Name="Brackets";holder.Parent=box
   local function bar(ax,ay,horizontal)
    local f=Instance.new("Frame");f.Name=horizontal and "BarH" or "BarV";f.BorderSizePixel=0;f.BackgroundColor3=Color3.fromRGB(255,198,202);f.AnchorPoint=Vector2.new(ax,ay)
    f.Position=UDim2.fromScale(ax,ay);f.Parent=box
    local s=Instance.new("UIStroke");s.Color=Color3.fromRGB(255,9,49);s.Transparency=.7;s.Thickness=1.5;s.Parent=f
   end
   for _,c in ipairs({{0,0},{1,0},{0,1},{1,1}})do bar(c[1],c[2],true);bar(c[1],c[2],false)end
  end
  -- ENHANCE: a zoomed-in copy of the visor's own lit digits (cloned from the visor screen), sitting right over the
  -- visor; the brackets hug it
  local rs=box:FindFirstChild("ResponsiveScale");if rs then rs.Scale=1 end
  local old=box:FindFirstChild("Readout");if old then old:Destroy() end
  -- corner brackets hug the visor digits
  local w=math.clamp((target.W or 30)*1.2+16,30,260);local h=math.clamp((target.H or 12)*1.45+12,20,120)
  box.AnchorPoint=Vector2.new(.5,.5);box.Size=UDim2.fromOffset(w,h);box.Position=UDim2.fromOffset(target.X,target.Y)
  -- corners only: short arms (about a third of the shorter side) so the sides stay open
  local arm=math.clamp(math.min(w,h)*.32,5,16)
  for _,b in ipairs(box:GetChildren())do
   if b.Name=="BarH"then b.Size=UDim2.fromOffset(arm,2) elseif b.Name=="BarV"then b.Size=UDim2.fromOffset(2,arm) end
  end
  -- the enhanced number floats above the head in the same plate as the intro's YOUR NUMBER lock-on
  local oldLens=box:FindFirstChild("Lens");if oldLens then oldLens:Destroy() end
  local plate=box:FindFirstChild("Plate")
  if plate then
   plate.Visible=true
   local digits=tostring(target.Code or "")
   local tStyle=NumberStyles.Of(target.Player)
    for i=0,3 do local d=plate:FindFirstChild("Digit"..i);if d then d.Text=digits:sub(i+1,i+1);NumberStyles.Skin(d,tStyle,d.Text,{fill=.96}) end end
   local plateH=math.clamp((target.H or 12)*1.8,26,52)
   plate.Zoom.Scale=plateH/146
   plate.Position=UDim2.new(.5,0,0,-math.clamp((target.H or 12)*1.5,6,56)-6)
  end
 end
end
function View:RestoreCamera()
 local camera=workspace.CurrentCamera
 if self.spectating and camera then
  local h=self.player.Character and self.player.Character:FindFirstChildOfClass("Humanoid")
  camera.CameraType=Enum.CameraType.Custom;if h then camera.CameraSubject=h end
 end
 self.spectating=false;self.target=nil
end
function View:Layout()
 local size=self.gui.AbsoluteSize;local w,h=size.X,size.Y;if w<=0 or h<=0 then return end
 local pref=math.clamp(self.gui:GetAttribute("InterfaceScale")or 1,.5,1.2)
 -- panels that just opened pop in: grow from 94% around their centre and rise 26px, with a slight overshoot
 local k=math.clamp((os.clock()-(self.shownAt or 0))/.32,0,1)
 local c1=1.4;local eased=1+(c1+1)*(k-1)^3+c1*(k-1)^2
 local motion=not self.values.ReducedMotion and k<1
 local function place(p,x,y,scale)
  if motion and p.Name==self.active and p.Name~="Entry" and p.Name~="Lobby" then
   local m=.94+.06*eased
   local sx,sy=p.Size.X.Offset*scale,p.Size.Y.Offset*scale
   x+=sx*(1-m)/2;y+=sy*(1-m)/2+26*(1-eased);scale*=m
  end
  p.ResponsiveScale.Scale=scale;p.Position=UDim2.fromOffset(x,y)
 end
 for _,name in ipairs(panels)do
  local p=self.gui[name]
  local large=name=="Shop"or name=="Inventory"or name=="Quests"or name=="Settings"or name=="Credits"or name=="PatchNotes"
  local scale=large and math.max(.1,math.min(2*pref,(w-64)/488,(h-120)/470))or math.max(.1,math.min(pref,(w-32)/p.Size.X.Offset,(h-150)/p.Size.Y.Offset))
  if name=="Entry"then
   -- number entry: compact, docked at the bottom centre so the view stays clear while you type
   local es=math.max(.1,math.min(.7*pref,(w-32)/p.Size.X.Offset,(h*.36)/p.Size.Y.Offset))
   p.AnchorPoint=Vector2.zero;place(p,(w-p.Size.X.Offset*es)/2,h-p.Size.Y.Offset*es-26,es)
  elseif p:GetAttribute("ReferenceV3")then
   local camera=workspace.CurrentCamera;local screen=camera and camera.ViewportSize or size
   local rw,rh=math.min(w,screen.X),math.min(h,screen.Y)
   local origin=self.gui.AbsolutePosition
   -- contain: the whole 1672x941 canvas visible, centred; the panel's own backdrop fills any letterbox
   local rs=math.max(.1,math.min((rw-16)/1672,(rh-16)/941));p.AnchorPoint=Vector2.zero;place(p,(rw-1672*rs)/2,8+(rh-16-941*rs)/2,rs)
  else
   place(p,(w-p.Size.X.Offset*scale)/2,math.max(large and 60 or 112,(h-p.Size.Y.Offset*scale)/2),scale)
  end
 end
 local ls=math.min(w/1440,h/810);place(self.gui.Lobby,(w-1440*ls)/2,(h-810*ls)/2,ls)
 self.gui.Toast.Visible=false
 -- captions (Settings > Captions: "Sliding", "Landed"...) sit bottom-left: just above the round minimap when it's
 -- down there, otherwise in the corner
 local cap=self.gui.Caption
 cap.AnchorPoint=Vector2.new(0,1);cap.TextXAlignment=Enum.TextXAlignment.Left
 local map=self.gui.MatchHUD:FindFirstChild("Minimap")
 local base=self.gui.AbsolutePosition
 if map and self.gui.MatchHUD.Visible and map.Visible and map.AbsoluteSize.X>0 and map.AbsolutePosition.Y-base.Y>h*.5 then
  cap.Position=UDim2.fromOffset(map.AbsolutePosition.X-base.X,map.AbsolutePosition.Y-base.Y-12)
 else
  cap.Position=UDim2.new(0,24,1,-150)
 end
end
function View:Render(input,shared,char,now,viewport)
 self:Layout()
 local menuNow=os.clock()
 if self.menuMotion then self.menuMotion:Step(self.menuLast and menuNow-self.menuLast or 0)end
 self.menuLast=menuNow
 if self.presentation then self.presentation:Step(now)end
 if self.open and self.active~="Entry" and self.active~="Help" and not(self.active=="Leaderboard" and self.peek) then UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true;self.player.CameraMode=Enum.CameraMode.Classic end
 if os.clock()>(self.captionUntil or 0)then self.gui.Caption.Text=""end
 local deployed=self.player:GetAttribute("InMatch")==true
 self.gui.MenuBackground.Visible=not deployed and self.active~=nil and self.gui.MenuBackground.Image~=""
 self.gui.Entry.Visible=self.active=="Entry"
 local entry=self.gui.Entry
 self.feedback:Render(input,now)
 if self.matchHud then self.matchHud:Step(input,shared,char,now) end
 if self.leaderboard then self.leaderboard:Step() end
 if not deployed and workspace.CurrentCamera and not self.player:GetAttribute("IntroPlaying") then
  if self.menuScenery then self.menuScenery:Step() else
   workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
   workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(0,24,-58),Vector3.new(0,16,40)) -- over the canal, looking up the court to the belfry
   workspace.CurrentCamera.FieldOfView=65
  end
 end
 local phase=shared:GetAttribute("Phase")or "Warmup"
 local resetRemaining=86400-math.floor(workspace:GetServerTimeNow())%86400
 self.gui.Lobby.DailyQuests.ResetTime.Text=string.format("%02d:%02d:%02d",math.floor(resetRemaining/3600),math.floor(resetRemaining/60)%60,resetRemaining%60)
 if now-self.lastRefresh<.2 then return end;self.lastRefresh=now;self:RefreshProfile()
 local lobbyLeft=(shared:GetAttribute("LobbyUntil")or 0)-now
 self.gui.Lobby.Phase.Text=phase=="Warmup"and(lobbyLeft>0 and "FREE FOR ALL  /  MATCH STARTS IN "..clock(lobbyLeft) or "FREE FOR ALL  /  WAITING FOR PLAYERS")or phase:upper().."  /  "..clock((shared:GetAttribute("EndsAt")or now)-now)
 local valid=self.player:GetAttribute("ResultRound")==shared:GetAttribute("RoundId")
 self.gui.Results.Placement.Text=valid and "#"..tostring(self.player:GetAttribute("ResultPlace")or 0)or "—"
 self.gui.Results.Stats.Value0.Text=tostring(valid and(self.player:GetAttribute("ResultKills")or 0)or 0)
 self.gui.Results.Stats.Value1.Text=clock(valid and(self.player:GetAttribute("ResultSurvival")or 0)or 0)
 self.gui.Results.Stats.Value2.Text=tostring(valid and(self.player:GetAttribute("ResultNumbers")or 0)or 0)
 self.gui.Results.Stats.Value3.Text="+"..tostring(valid and(self.player:GetAttribute("ResultCoins")or 0)or 0)
end
return View



