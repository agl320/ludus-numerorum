-- Lays out the Loadout (Inventory) panel on its 1672 x 941 canvas:
--   left  : brand + character preview with PREVIEW / POSE / RESET
--   right : title, category tabs across the top, section heading (+ hair STYLES / COLOURS toggle),
--           a 3 x 2 grid of large item cards, paging, BACK / RESET TO DEFAULT / primary action.
-- One clean stroke per element, no ornament frames. Idempotent (attribute Styled).
local Style={}
local RED=Color3.fromRGB(255,20,60)
local DIM=Color3.fromRGB(96,14,32)
local INK=Color3.fromRGB(9,5,7)
local CARD=Color3.fromRGB(16,9,12)
local BONE=Color3.fromRGB(240,232,228)
local MUTED=Color3.fromRGB(170,158,160)
local FAINT=Color3.fromRGB(105,92,96)
local ACTIVE=Color3.fromRGB(110,0,28)
local FONT=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Regular)
local BOLD=Font.new("rbxasset://fonts/families/Guru.json",Enum.FontWeight.Bold)
Style.Colors={RED=RED,DIM=DIM,INK=INK,BONE=BONE,MUTED=MUTED,FAINT=FAINT,ACTIVE=ACTIVE}

local X0,CW=548,1084                      -- content column
local TAB_Y,TAB_H,TAB_GAP=128,70,8
local GRID_Y,CARD_W,CARD_H,GAP_X,GAP_Y=270,350,266,17,16
local BAR_Y,BAR_H=860,52
Style.CardArt={Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(330,186)}
Style.SwatchArt={Position=UDim2.fromOffset(105,30),Size=UDim2.fromOffset(140,140)}
Style.TabNames={"NUMBER STYLE","HAIR","CLOTHING","ELIM FX","NOTEBOOK","PEN","TITLE","MASK","VISOR","TRAIL"}

local function stroke(frame,color,thick,radius)
 local s=frame:FindFirstChild("Outline") or Instance.new("UIStroke");s.Name="Outline";s.Color=color or DIM;s.Thickness=thick or 1;s.Transparency=0;s.Enabled=true
 s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=frame
 local c=frame:FindFirstChild("UICorner") or Instance.new("UICorner");c.CornerRadius=UDim.new(0,radius or 6);c.Parent=frame
 return s
end
local function text(l,size,color,x,font)
 l.FontFace=font or FONT;l.TextSize=size;l.TextColor3=color or BONE;l.TextScaled=false;l.TextWrapped=false;l.TextTruncate=Enum.TextTruncate.AtEnd;l.RichText=false
 l.TextXAlignment=x or Enum.TextXAlignment.Center;l.TextYAlignment=Enum.TextYAlignment.Center;l.BackgroundTransparency=1
end
local function label(parent,name,txt,size,pos,sz,color,xalign,font,z)
 local l=parent:FindFirstChild(name) or Instance.new("TextLabel");l.Name=name;l.Text=txt;l.Position=pos;l.Size=sz;l.ZIndex=z or (parent.ZIndex+4);l.Parent=parent
 text(l,size,color,xalign,font);return l
end
local function place(o,x,y,w,h) o.AnchorPoint=Vector2.zero;o.Position=UDim2.fromOffset(x,y);if w then o.Size=UDim2.fromOffset(w,h)end end
local function strip(o) for _,n in ipairs({"Glow","SurfaceGradient","TopShine","Icon","ReferenceTexture","CategoryIcon","ThornBorder","OrnamentAtlas"})do local c=o:FindFirstChild(n);if c then c:Destroy()end end end
local function button(b,txt,size,primary)
 strip(b);b.AutoButtonColor=false;b.BackgroundColor3=primary and ACTIVE or INK;b.BackgroundTransparency=primary and 0 or .05
 stroke(b,primary and RED or DIM,primary and 1.4 or 1.2,6)
 local l=b:FindFirstChild("Label") or Instance.new("TextLabel");l.Name="Label";l.Parent=b;l.Text=txt;l.Position=UDim2.fromOffset(0,0);l.Size=UDim2.fromScale(1,1);l.ZIndex=b.ZIndex+2
 text(l,size or 16,BONE,Enum.TextXAlignment.Center,BOLD)
end
Style.Button=button
function Style.Claimable(b,on)
 if not b then return end
 b.BackgroundColor3=on and ACTIVE or INK;b.BackgroundTransparency=on and 0 or .05
 local o=b:FindFirstChild("Outline");if o then o.Color=on and RED or DIM end
 local l=b:FindFirstChild("Label");if l then l.TextColor3=on and BONE or MUTED end
end

function Style.Apply(inv,marksIcon)
 if inv:GetAttribute("Styled") then return end
 inv:SetAttribute("Styled",true)
 -- full-screen tinted backdrop behind the canvas
 local back=Instance.new("Frame");back.Name="Backdrop";back.BackgroundColor3=INK;back.BackgroundTransparency=.12;back.BorderSizePixel=0
 back.Position=UDim2.fromOffset(-3000,-3000);back.Size=UDim2.fromOffset(9000,9000);back.ZIndex=0;back.Parent=inv
 local vg=Instance.new("UIGradient");vg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(44,6,15)),ColorSequenceKeypoint.new(.5,INK),ColorSequenceKeypoint.new(1,Color3.fromRGB(26,4,10))});vg.Rotation=90;vg.Parent=back
 -- remove ornament frames and the old equipped-grid furniture
 for _,d in ipairs(inv:GetDescendants())do
  if d.Name=="OrnamentAtlas" or d.Name=="ThornBorder" or d.Name=="ThornHeader" or d.Name=="ReferenceTexture" then d:Destroy() end
 end
 for _,n in ipairs({"Header","Distress","SidebarDivider","SectionTitle","EquippedHeading","BrandTagline","RotatePreview"})do local o=inv:FindFirstChild(n);if o then o.Visible=false end end
 for i=0,7 do local s=inv:FindFirstChild("Slot"..i);if s then s.Visible=false end end
 inv.BrowserPanel.Visible=false
 -- header: brand mark over the preview, clean title over the content column, marks balance top right
 local logo=inv:FindFirstChild("BrandLogo");if logo then place(logo,40,22,250,90);logo.ZIndex=4 end
 local tp=inv.TitlePlate;place(tp,X0,26,720,96);tp.BackgroundTransparency=1;if tp:FindFirstChild("Outline")then tp.Outline.Enabled=false end
 local accent=tp:FindFirstChild("Accent") or Instance.new("Frame");accent.Name="Accent";accent.BorderSizePixel=0;accent.BackgroundColor3=RED;place(accent,0,8,5,50);accent.ZIndex=6;accent.Parent=tp
 local t=tp.Title;place(t,20,0,700,64);text(t,56,BONE,Enum.TextXAlignment.Left,BOLD);t.Text="LOADOUT";t.ZIndex=6
 local sub=inv.Subtitle;place(sub,X0+20,84,760,24);text(sub,18,MUTED,Enum.TextXAlignment.Left);sub.Text="CUSTOMISE YOUR MARK."
 local cur=inv.Currency;place(cur,1392,40,240,52);cur.BackgroundColor3=INK;cur.BackgroundTransparency=.05;stroke(cur,RED,1.4,6)
 if cur:FindFirstChild("MarksArtwork")then place(cur.MarksArtwork,14,12,28,28)end
 place(cur.Balance,50,0,150,52);text(cur.Balance,22,BONE,Enum.TextXAlignment.Left,BOLD)
 if cur:FindFirstChild("Info")then
  place(cur.Info,202,12,28,28)
  -- centre the + and its glow rings in the button (they sat a couple of pixels off)
  local l=cur.Info:FindFirstChild("Label")
  if l then l.AnchorPoint=Vector2.new(.5,.5);l.Position=UDim2.fromScale(.5,.47);l.Size=UDim2.fromScale(1,1);l.TextXAlignment=Enum.TextXAlignment.Center;l.TextYAlignment=Enum.TextYAlignment.Center end
  local g=cur.Info:FindFirstChild("Glow")
  if g then g.AnchorPoint=Vector2.new(.5,.5);g.Position=UDim2.fromScale(.5,.5);g.Size=UDim2.fromScale(1,1)
   for _,h in ipairs(g:GetChildren())do local k=tonumber(h.Name:match("^Halo(%d)$"));if k and h:IsA("GuiObject")then h.AnchorPoint=Vector2.new(.5,.5);h.Position=UDim2.fromScale(.5,.5);h.Size=UDim2.new(1,k*2,1,k*2)end end
  end
 end
 local ver=inv:FindFirstChild("Version");if ver then place(ver,1432,8,200,24);text(ver,11,FAINT,Enum.TextXAlignment.Right) end
 -- tabs
 local tabW=(CW-TAB_GAP*7)/8
 for i=0,9 do
  local b=inv:FindFirstChild("Category"..i);if not b then continue end;strip(b);b.AutoButtonColor=false;b.Visible=true
  place(b,X0+i*(tabW+TAB_GAP),TAB_Y,tabW,TAB_H);b.BackgroundColor3=INK;b.BackgroundTransparency=.05;stroke(b,DIM,1,6)
  local l=b.Label;place(l,6,10,tabW-12,28);text(l,20,BONE,Enum.TextXAlignment.Center,BOLD);l.Text=Style.TabNames[i+1];l.ZIndex=b.ZIndex+2
  label(b,"Sub","",14,UDim2.fromOffset(6,39),UDim2.fromOffset(tabW-12,20),MUTED,Enum.TextXAlignment.Center,FONT,b.ZIndex+2)
  local bar=b:FindFirstChild("Bar") or Instance.new("Frame");bar.Name="Bar";bar.BorderSizePixel=0;bar.BackgroundColor3=RED;bar.AnchorPoint=Vector2.new(.5,1)
  bar.Position=UDim2.new(.5,0,1,-1);bar.Size=UDim2.new(1,-24,0,3);bar.ZIndex=b.ZIndex+2;bar.Visible=false;bar.Parent=b
 end
 -- section heading + hair toggle
 label(inv,"SectionHeading","",32,UDim2.fromOffset(X0,210),UDim2.fromOffset(700,36),BONE,Enum.TextXAlignment.Left,BOLD,6)
 label(inv,"SectionCount","",16,UDim2.fromOffset(X0,244),UDim2.fromOffset(700,20),MUTED,Enum.TextXAlignment.Left,FONT,6)
 for k,info in ipairs({{"ToggleStyles","STYLES"},{"ToggleColours","COLOURS"}})do
  local b=inv:FindFirstChild(info[1]) or Instance.new("TextButton");b.Name=info[1];b.Text="";b.ZIndex=6;b.Parent=inv
  place(b,X0+CW-2*150-8+(k-1)*158,212,150,46);button(b,info[2],19,false)
 end
 -- item cards
 for i=0,5 do
  local c=inv["Owned"..i];local col,row=i%3,i//3
  place(c,X0+col*(CARD_W+GAP_X),GRID_Y+row*(CARD_H+GAP_Y),CARD_W,CARD_H);c.BackgroundColor3=CARD;c.BackgroundTransparency=0;c.ZIndex=4;stroke(c,DIM,1,8)
  if c:FindFirstChild("Thumbnail")then c.Thumbnail.Visible=false end
  local well=c:FindFirstChild("ArtWell") or Instance.new("Frame");well.Name="ArtWell";well.BorderSizePixel=0;well.BackgroundColor3=Color3.fromRGB(26,12,17);well.ZIndex=c.ZIndex+1
  place(well,10,10,CARD_W-20,186);well.Parent=c;local wc=well:FindFirstChild("UICorner") or Instance.new("UICorner");wc.CornerRadius=UDim.new(0,6);wc.Parent=well
  local wg=well:FindFirstChild("UIGradient") or Instance.new("UIGradient");wg.Rotation=90;wg.Color=ColorSequence.new(Color3.fromRGB(46,16,24),Color3.fromRGB(14,7,10));wg.Parent=well
  local n=c:FindFirstChild("Name");place(n,16,202,CARD_W-32,30);text(n,25,BONE,Enum.TextXAlignment.Left,BOLD);n.ZIndex=c.ZIndex+3
  label(c,"PriceRow","",18,UDim2.fromOffset(16,232),UDim2.fromOffset(CARD_W-32,24),MUTED,Enum.TextXAlignment.Left,FONT,c.ZIndex+3)
  local chip=c:FindFirstChild("EquippedChip") or Instance.new("TextLabel");chip.Name="EquippedChip";chip.Parent=c;chip.Text="EQUIPPED"
  place(chip,20,20,110,28);text(chip,14,BONE,Enum.TextXAlignment.Center,BOLD);chip.BackgroundTransparency=0;chip.BackgroundColor3=ACTIVE;chip.ZIndex=c.ZIndex+6;chip.Visible=false
  local cc=chip:FindFirstChild("UICorner") or Instance.new("UICorner");cc.CornerRadius=UDim.new(1,0);cc.Parent=chip
  local sel=c.Select;place(sel,0,0,CARD_W,CARD_H);sel.ZIndex=c.ZIndex+10;sel.BackgroundTransparency=1;sel.Text="";sel.AutoButtonColor=false
 end
 label(inv,"EmptyState","",36,UDim2.fromOffset(X0,GRID_Y+170),UDim2.fromOffset(CW,40),MUTED,Enum.TextXAlignment.Center,BOLD,6)
 label(inv,"EmptyHint","",19,UDim2.fromOffset(X0,GRID_Y+218),UDim2.fromOffset(CW,24),FAINT,Enum.TextXAlignment.Center,FONT,6)
 -- paging under the grid: big PREV / NEXT pills with a page counter and dots between them (Style.Pager),
 -- centred in the free space left of RESET / EQUIP
 Style.Pager(inv,X0+(CW-186-16-200-16)/2)
 inv.PageStatus.Visible=false
 -- bottom buttons
 local cl=inv.Close;place(cl,40,BAR_Y,170,BAR_H);button(cl,"←  BACK",20,false)
 local rs=inv.Reset;place(rs,X0+CW-186-16-200,BAR_Y,200,BAR_H);button(rs,"RESET TO DEFAULT",18,false)
 local sv=inv.SaveLoadout;place(sv,X0+CW-186,BAR_Y,186,BAR_H);button(sv,"EQUIP",20,true)
 -- character preview
 local cp=inv.CharacterPreview;place(cp,40,128,468,708);cp.BackgroundColor3=Color3.fromRGB(14,7,10);cp.BackgroundTransparency=.15;stroke(cp,DIM,1,10)
 local pg=cp:FindFirstChild("PreviewGlow") or Instance.new("UIGradient");pg.Name="PreviewGlow";pg.Rotation=90
 pg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(20,8,12)),ColorSequenceKeypoint.new(.7,Color3.fromRGB(52,10,22)),ColorSequenceKeypoint.new(1,Color3.fromRGB(20,6,10))});pg.Parent=cp
 local scene=cp:FindFirstChild("Scene");if scene then scene:SetAttribute("DesignAsset",nil);scene.Image="";scene.Visible=false end
 cp.AvatarViewport.Position=UDim2.fromOffset(0,0);cp.AvatarViewport.Size=UDim2.fromScale(1,1);cp.AvatarViewport.BackgroundTransparency=1;cp.AvatarViewport.ZIndex=cp.ZIndex+2
 if cp:FindFirstChild("Hint")then cp.Hint.Visible=false end
 local dh=cp.DragHint;dh.Visible=true;place(dh,0,680,468,24);text(dh,15,FAINT,Enum.TextXAlignment.Center);dh.Text="DRAG TO ROTATE";dh.ZIndex=cp.ZIndex+4
 local pn=label(cp,"PreviewTag","",16,UDim2.fromOffset(16,14),UDim2.fromOffset(436,22),MUTED,Enum.TextXAlignment.Right,BOLD,cp.ZIndex+4)
 local oldPreview=inv:FindFirstChild("SidePREVIEW");if oldPreview then oldPreview:Destroy() end
 for i,d in ipairs({{"POSE","✦"},{"RESET","↺"}})do
  local b=inv:FindFirstChild("Side"..d[1]) or Instance.new("TextButton");b.Name="Side"..d[1];b.Text="";b.Parent=inv;b.ZIndex=12
  place(b,40+(468-2*150-12)/2+(i-1)*162,756,150,44);button(b,d[2].."  "..d[1],16,false)
  local old=inv:FindFirstChild("SideLabel"..i);if old then old.Visible=false end
 end
end

-- PAGER (Shop + Loadout): the panel's Previous / Next buttons become wide "‹ PREV" / "NEXT ›" pills and a
-- PagerInfo block between them shows "PAGE 2 / 3" over a row of dots. It follows the panel's CurrentPage /
-- PageCount attributes (set by ReferenceMenusV3); at the first / last page the matching pill dims. NEXT pulses
-- while you're on page 1 of several, so new players notice there is more.
local PILL_W,INFO_W=168,150
function Style.Pager(p,cx)
 local prev,nxt=p.Previous,p.Next
 for k,b in ipairs({prev,nxt})do
  strip(b);b.AutoButtonColor=false;b.Text=""
  for _,c in ipairs(b:GetChildren())do if c:IsA("GuiObject") and c.Name~="Label" then c.Visible=false end end
  place(b,k==1 and cx-INFO_W/2-12-PILL_W or cx+INFO_W/2+12,BAR_Y,PILL_W,52)
  button(b,k==1 and "‹   PREV" or "NEXT   ›",20,k==2)
  b.ZIndex=8;b.Label.ZIndex=10
 end
 local info=p:FindFirstChild("PagerInfo") or Instance.new("Frame");info.Name="PagerInfo";info.BackgroundTransparency=1;info.ZIndex=8;info.Parent=p
 place(info,cx-INFO_W/2,BAR_Y,INFO_W,52)
 local t=label(info,"PageText","PAGE 1 / 1",18,UDim2.fromOffset(0,4),UDim2.fromOffset(INFO_W,24),BONE,Enum.TextXAlignment.Center,BOLD,10)
 local dots=info:FindFirstChild("Dots") or Instance.new("Frame");dots.Name="Dots";dots.BackgroundTransparency=1;dots.Parent=info
 place(dots,0,34,INFO_W,10)
 local ll=dots:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout");ll.FillDirection=Enum.FillDirection.Horizontal
 ll.HorizontalAlignment=Enum.HorizontalAlignment.Center;ll.VerticalAlignment=Enum.VerticalAlignment.Center;ll.Padding=UDim.new(0,7);ll.SortOrder=Enum.SortOrder.LayoutOrder;ll.Parent=dots
 local pulse=0
 local function refresh()
  local page,pages=p:GetAttribute("CurrentPage") or 1,p:GetAttribute("PageCount") or 1
  local show=pages>1 and prev.Visible
  info.Visible=show
  t.Text=string.format("PAGE %d / %d",page,pages)
  for _,d in ipairs(dots:GetChildren())do if d:IsA("Frame") then d:Destroy() end end
  for i=1,math.min(pages,9)do
   local d=Instance.new("Frame");d.BorderSizePixel=0;d.LayoutOrder=i;d.ZIndex=10
   local on=i==page
   d.Size=UDim2.fromOffset(on and 22 or 8,8);d.BackgroundColor3=on and RED or FAINT;d.BackgroundTransparency=on and 0 or .3
   local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=d;d.Parent=dots
  end
  local atStart,atEnd=page<=1,page>=pages
  for k,b in ipairs({prev,nxt})do
   local dim=(k==1 and atStart) or (k==2 and atEnd)
   b:SetAttribute("Dim",dim)
   b.BackgroundColor3=(k==2 and not dim) and ACTIVE or INK;b.BackgroundTransparency=dim and .5 or (k==2 and 0 or .05)
   if b:FindFirstChild("Outline") then b.Outline.Color=dim and Color3.fromRGB(60,14,26) or (k==2 and RED or DIM) end
   b.Label.TextColor3=dim and FAINT or BONE
  end
 end
 p:GetAttributeChangedSignal("CurrentPage"):Connect(refresh)
 p:GetAttributeChangedSignal("PageCount"):Connect(refresh)
 prev:GetPropertyChangedSignal("Visible"):Connect(refresh)
 refresh()
 -- hover: undimmed pills light up
 for _,b in ipairs({prev,nxt})do
  b.MouseEnter:Connect(function()if not b:GetAttribute("Dim") and b:FindFirstChild("Outline") then b.Outline.Color=BONE end end)
  b.MouseLeave:Connect(function()refresh()end)
 end
 -- NEXT breathes while you're on page 1 of several
 task.spawn(function()
  while p.Parent do
   local dt=task.wait(1/30)
   local page,pages=p:GetAttribute("CurrentPage") or 1,p:GetAttribute("PageCount") or 1
   local s=nxt:FindFirstChild("Outline")
   if s and p.Visible and nxt.Visible and page==1 and pages>1 then
    pulse+=dt*3.2
    s.Thickness=1.4+(math.sin(pulse)*.5+.5)*1.8
   elseif s and s.Thickness~=1.4 then s.Thickness=1.4 end
  end
 end)
end

-- Reorder a row of tabs (buttons named prefix..index) into `order`; tabs not listed are hidden. A "|" in the order
-- starts a new group: a wider gap with a thin divider between the groups.
local GROUP_GAP=26
function Style.OrderTabs(parent,prefix,order,x,w,y,h,rename)
 local tabs,groups={},0
 for _,i in ipairs(order)do if i=="|" then groups+=1 else table.insert(tabs,i) end end
 local n=#tabs;local tw=(w-8*(n-1-groups)-GROUP_GAP*groups)/n
 for _,d in ipairs(parent:GetChildren())do if d.Name=="TabGroupDivider" then d:Destroy() end end
 local listed={};local cx=x
 for _,i in ipairs(order)do
  if i=="|" then
   cx+=GROUP_GAP-8
   local div=Instance.new("Frame");div.Name="TabGroupDivider";div.BorderSizePixel=0;div.BackgroundColor3=RED;div.BackgroundTransparency=.45
   div.Position=UDim2.fromOffset(cx-GROUP_GAP/2-4,y+12);div.Size=UDim2.fromOffset(2,h-24);div.ZIndex=6;div.Parent=parent
   continue
  end
  listed[i]=true
  local b=parent:FindFirstChild(prefix..i);local k=cx;cx+=tw+8
  if b then
   b.Visible=true;b.Position=UDim2.fromOffset(k,y);b.Size=UDim2.fromOffset(tw,h)
   local l=b:FindFirstChild("Label");if l then l.Size=UDim2.fromOffset(tw-12,l.Size.Y.Offset) end
   local s=b:FindFirstChild("Sub");if s then s.Size=UDim2.fromOffset(tw-12,s.Size.Y.Offset) end
   if rename and rename[i] and l then l.Text=rename[i] end
  end
 end
 for _,b in ipairs(parent:GetChildren())do local i=tonumber(b.Name:match("^"..prefix.."(%d+)$"));if i and not listed[i] then b.Visible=false end end
end
Style.TabOrder={1,2,7,4,0,3,6}   -- HAIR, CLOTHING, MASK, GEAR, then the coming-soon tabs

-- tab state: selected / equipped summary / coming soon
-- CATEGORY TABS: an icon over the name, the item count small underneath, a lift on hover and a red bar under the
-- one you're on. Icons from the game's icon sheet where there's a fitting one; hair, head and pets are drawn from
-- shapes (the sheet has none for them).
local TAB_SHEET="rbxassetid://117654350454534"
local TAB_SHEET_ICON={NUMBER=Vector2.new(0,0),NUMBERS=Vector2.new(0,0),ELIM=Vector2.new(768,0),GEAR=Vector2.new(0,256),TRAIL=Vector2.new(256,0),
 VISOR=Vector2.new(768,512),BUNDLE=Vector2.new(512,256),CLOTHING=Vector2.new(256,768),TITLE=Vector2.new(512,0)}
local function shape(parent,x,y,w,h,round,rot)
 local f=Instance.new("Frame");f.Name="Shape";f.BorderSizePixel=0;f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h)
 f.Rotation=rot or 0;f.ZIndex=parent.ZIndex;f.Parent=parent
 if round then local c=Instance.new("UICorner");c.CornerRadius=round==true and UDim.new(.5,0) or UDim.new(0,round);c.Parent=f end
 return f
end
local TAB_DRAWN={
 -- spiky hair: a crown with three spikes on top and locks down the sides
 HAIR=function(f) shape(f,2,8,20,10,5);shape(f,2,13,5,9,2);shape(f,17,13,5,9,2)
  shape(f,3.5,4,7,7,1,45);shape(f,8.5,1,7,7,1,45);shape(f,13.5,4,7,7,1,45) end,
 -- a head with a scarf wrapped round the neck, the end hanging
 HEAD=function(f) shape(f,6,1,12,12,true);shape(f,3,14,18,6,3);shape(f,14,17,5,7,2,18) end,
 -- a paw print
 PETS=function(f) shape(f,6,12,12,10,true);shape(f,2,7,5,6,true);shape(f,6.5,2,5,6,true);shape(f,12.5,2,5,6,true);shape(f,17,7,5,6,true) end,
}
local function tabIconColor(icon,c)
 if icon:IsA("ImageLabel") then icon.ImageColor3=c
 else for _,d in ipairs(icon:GetChildren()) do if d:IsA("Frame") then d.BackgroundColor3=c end end end
end
local function tabSetup(b)
 local l=b:FindFirstChild("Label");local sub=b:FindFirstChild("Sub");if not l then return end
 local word=(l.Text:upper():match("^(%a+)")) or ""
 if word=="NUMBER" then l.Text="NUMBERS";word="NUMBERS" end
 if b:GetAttribute("TabIconKey")~=word then
  b:SetAttribute("TabIconKey",word)
  local old=b:FindFirstChild("TabIcon");if old then old:Destroy() end
  local icon
  if TAB_SHEET_ICON[word] then
   icon=Instance.new("ImageLabel");icon.Image=TAB_SHEET;icon.ImageRectOffset=TAB_SHEET_ICON[word];icon.ImageRectSize=Vector2.new(256,256)
   icon.BackgroundTransparency=1;icon.ScaleType=Enum.ScaleType.Fit
  elseif TAB_DRAWN[word] then
   icon=Instance.new("Frame");icon.BackgroundTransparency=1
  end
  if icon then
   icon.Name="TabIcon";icon.Size=UDim2.fromOffset(24,24);icon.AnchorPoint=Vector2.new(.5,0);icon.Position=UDim2.new(.5,0,0,5);icon.ZIndex=b.ZIndex+2
   -- (drawn at 24, shown at 30)
   local sc=Instance.new("UIScale");sc.Scale=1.25;sc.Parent=icon
   icon.Parent=b
   if TAB_DRAWN[word] then TAB_DRAWN[word](icon) end
  end
 end
 if not b:GetAttribute("TabV2") then
  b:SetAttribute("TabV2",true)
  -- name under the icon, the count small at the bottom
  l.AnchorPoint=Vector2.zero;l.Position=UDim2.new(0,4,0,34);l.Size=UDim2.new(1,-8,0,20);l.TextSize=18;l.TextYAlignment=Enum.TextYAlignment.Center
  l.TextTruncate=Enum.TextTruncate.AtEnd
  if sub then sub.AnchorPoint=Vector2.zero;sub.Position=UDim2.new(0,4,0,52);sub.Size=UDim2.new(1,-8,0,13);sub.TextSize=13 end
  local o=b:FindFirstChild("Outline")
  b.MouseEnter:Connect(function() if not b:GetAttribute("TabOn") then b.BackgroundColor3=Color3.fromRGB(28,10,16);if o then o.Color=Color3.fromRGB(170,30,60) end end end)
  b.MouseLeave:Connect(function() if not b:GetAttribute("TabOn") then b.BackgroundColor3=INK;if o then o.Color=DIM end end end)
 end
end
function Style.Tab(b,on,sub,soon)
 if not b then return end
 pcall(tabSetup,b)
 b:SetAttribute("TabOn",on==true)
 local icon=b:FindFirstChild("TabIcon");if icon then tabIconColor(icon,on and BONE or (soon and FAINT or MUTED)) end
 b.BackgroundColor3=on and ACTIVE or INK;b.BackgroundTransparency=on and 0 or .05
 local o=b:FindFirstChild("Outline");if o then o.Color=on and RED or DIM;o.Thickness=on and 1.4 or 1 end
 local bar=b:FindFirstChild("Bar");if bar then bar.Visible=on end
 local l=b:FindFirstChild("Label");if l then l.TextColor3=(soon and not on) and FAINT or BONE end
 local s=b:FindFirstChild("Sub");if s then s.Text=sub or "";s.TextColor3=on and BONE or (soon and FAINT or MUTED) end
end
function Style.Toggle(b,on)
 b.BackgroundColor3=on and ACTIVE or INK;b.BackgroundTransparency=on and 0 or .05;b.Outline.Color=on and RED or DIM
 b.Label.TextColor3=on and BONE or MUTED
end
-- card state: price / owned / equipped, selection ring
function Style.Card(card,item,equipped,owned,selected,status)
 local chip=card:FindFirstChild("EquippedChip");if chip then chip.Visible=equipped==true end
 local pr=card:FindFirstChild("PriceRow");if not pr then return end
 if status then pr.Text=status;pr.TextColor3=FAINT
 elseif not item then pr.Text=""
 elseif equipped then pr.Text="EQUIPPED";pr.TextColor3=BONE
 elseif owned then pr.Text=item.Price==0 and "FREE  ·  OWNED" or "OWNED";pr.TextColor3=MUTED
 else pr.Text=string.format("✹  %d MARKS",item.Price);pr.TextColor3=RED end
 card.Outline.Color=selected and BONE or equipped and RED or DIM
 card.Outline.Thickness=selected and 2 or equipped and 1.6 or 1
end
-- shared helpers for the other menus (PanelStyle)
Style.H={stroke=stroke,text=text,label=label,place=place,strip=strip,FONT=FONT,BOLD=BOLD,CARD=CARD,X0=X0,CW=CW}
return Style
