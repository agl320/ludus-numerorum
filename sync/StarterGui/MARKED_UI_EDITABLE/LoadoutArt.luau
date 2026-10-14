-- Artwork for Loadout/Shop cards. Hair thumbnails use a clone of the player's real head and the shared
-- HairFit placement, so a thumbnail matches what the hairstyle looks like in game.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HairCatalog=require(RS:WaitForChild("Numberfall"):WaitForChild("HairCatalog"))
local Fit=require(RS.Numberfall:WaitForChild("HairFit"))
local Art={}
local colorById={}
for _,c in ipairs(HairCatalog.Colors)do colorById[c.Id]=Color3.fromRGB(c.Color[1],c.Color[2],c.Color[3])end
Art.ColorById=colorById
local GURU=Font.new("rbxasset://fonts/families/Guru.json")
local BAL=Font.new("rbxasset://fonts/families/Balthazar.json")

local function clearArt(container)
 for _,n in ipairs({"HairArt","SwatchArt","NumberArt","NotebookArt","SwatchChip"})do local o=container:FindFirstChild(n);if o then o:Destroy()end end
end
Art.Clear=clearArt

-- A clean copy of the player's head (mesh, face, HairAttachment); falls back to a classic head shape.
local headCache,headFor
function Art.Head()
 -- A fixed copy of the classic head every character wears (ReplicatedStorage.Numberfall.ThumbHead), in your skin
 -- tone. (It used to copy your own character's head, which right after joining can still be your Roblox avatar's
 -- head: a different size and shape, so the hair sat inside it and the cached cards kept that picture.)
 local tpl=RS.Numberfall:FindFirstChild("ThumbHead")
 if tpl then
  local h=tpl:Clone();h.Anchored=true;h.CanCollide=false;h.CFrame=CFrame.new();h.LocalTransparencyModifier=0;h.Transparency=0
  local skin=Players.LocalPlayer:GetAttribute("SkinTone")
  h.Color=typeof(skin)=="Color3" and skin or Color3.fromRGB(234,184,146)
  for _,d in ipairs(h:GetChildren())do if d:IsA("Decal")then d.LocalTransparencyModifier=0 end end
  return h
 end
 local char=Players.LocalPlayer.Character
 local head=char and char:FindFirstChild("Head")
 if head and headFor~=head and not head:FindFirstChildOfClass("FaceControls") then
  local old=head.Archivable;head.Archivable=true
  local ok,c=pcall(function()return head:Clone()end);head.Archivable=old
  if ok and c then
   for _,d in ipairs(c:GetChildren())do if not(d:IsA("Decal") or d:IsA("Attachment") or d:IsA("SpecialMesh") or d:IsA("SurfaceAppearance"))then d:Destroy()end end
   c.Anchored=true;c.CanCollide=false;c.CFrame=CFrame.new();c.LocalTransparencyModifier=0
   if c.Transparency>0.5 then c.Transparency=0 end
   for _,d in ipairs(c:GetChildren())do if d:IsA("Decal") then d.LocalTransparencyModifier=0 end end
   headCache,headFor=c,head
  end
 end
 if headCache then local h=headCache:Clone();h.LocalTransparencyModifier=0;for _,d in ipairs(h:GetChildren())do if d:IsA("Decal")then d.LocalTransparencyModifier=0 end end;return h end
 local p=Instance.new("Part");p.Size=Vector3.new(1.2,1.2,1.2);p.Anchored=true;p.Color=Color3.fromRGB(205,190,185)
 local m=Instance.new("SpecialMesh");m.MeshType=Enum.MeshType.Head;m.Scale=Vector3.new(1,1,1);m.Parent=p
 local a=Instance.new("Attachment");a.Name="HairAttachment";a.Position=Vector3.new(0,0.6,0);a.Parent=p
 return p
end

local function viewport(container,name,rect)
 local vp=Instance.new("ViewportFrame");vp.Name=name;vp.BackgroundTransparency=1;vp.BorderSizePixel=0
 vp.Position=rect.Position;vp.Size=rect.Size;vp.ZIndex=(container.ZIndex or 1)+2
 -- near-neutral light so skin reads as the real skin tone (a pink ambient made hands look grey-pink)
 vp.Ambient=Color3.fromRGB(158,150,144);vp.LightColor=Color3.fromRGB(255,246,236);vp.LightDirection=Vector3.new(-0.5,-0.8,0.6)
 return vp
end

function Art.Hair(container,styleId,colorId,rect,zoom)
 clearArt(container)
 local vp=viewport(container,"HairArt",rect)
 local world=Instance.new("WorldModel");world.Parent=vp
 local head=Art.Head();head.CFrame=CFrame.new();head.Parent=world
 local h=Fit.Build(head,styleId or HairCatalog.DefaultStyle,colorId or HairCatalog.DefaultColor)
 if h then h.Anchored=true;h.Parent=world end
 local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
 local z=zoom or 1
 cam.CFrame=CFrame.lookAt(Vector3.new(1.35,0.75,-3.6)*z,Vector3.new(0,0.32,0))
 vp.Parent=container
 return vp
end

local MASK_FLIP=CFrame.Angles(0,math.pi,0)
local MASK_VERSIONS={{height=1.0474,centre=Vector3.new(-0.0005,-0.5366,-0.0075)},{height=0.9874,centre=Vector3.new(-0.0020,-0.5066,-0.0075)}}
local MaskDye=require(RS.Numberfall:WaitForChild("Extras"))
-- cwId: a mask colourway (Numberfall.Extras.MaskColorways) to dye it in
function Art.Mask(container,maskId,rect,cwId)
 clearArt(container)
 local vp=viewport(container,"HairArt",rect)
 local world=Instance.new("WorldModel");world.Parent=vp
 local head=Art.Head();head.CFrame=CFrame.new();head.Parent=world
 local tpl=RS.Numberfall:FindFirstChild("MaskModels") and RS.Numberfall.MaskModels:FindFirstChild(maskId or "")
 local src=tpl and tpl:FindFirstChild("Handle")
 local onHead=false
 if src then
  local scale=head.Size.X/1.2;local best,bd=MASK_VERSIONS[1],math.huge
  for _,v in ipairs(MASK_VERSIONS)do local d=math.abs(src.Size.Y-v.height);if d<bd then best,bd=v,d end end
  local h=src:Clone();h.Anchored=true;h.CanCollide=false;h.Size=src.Size*scale
  local c0=CFrame.new(best.centre*scale)*MASK_FLIP
  -- catalog head items (the cat hood) sit by their attachment, like on the character
  local ac,asc=MaskDye.MaskOffset(head,src)
  if ac then c0=ac;h.Size=src.Size*asc;onHead=true end
  h.CFrame=head.CFrame*c0;h.Parent=world
  if cwId then MaskDye.DyeMask(h,cwId) end
 end
 local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
 if onHead then cam.CFrame=CFrame.lookAt(Vector3.new(1.8,0.9,-4.8),Vector3.new(0,0.15,0))
 else cam.CFrame=CFrame.lookAt(Vector3.new(1.5,0.4,-4.2),Vector3.new(0,-0.3,0)) end
 vp.Parent=container
 return vp
end

-- CLOTHING: the player's own body (skin tone, hair, visor) wearing the outfit, full length, standing
local Outfits=require(RS.Numberfall:WaitForChild("Outfits"))
local bodyCache,bodyFor
local function body()
 local char=Players.LocalPlayer.Character
 if char and bodyFor~=char and char:FindFirstChild("UpperTorso") then
  local old=char.Archivable;char.Archivable=true
  local ok,c=pcall(function()return char:Clone()end);char.Archivable=old
  if ok and c then
   for _,d in ipairs(c:GetDescendants())do
    if d:IsA("WrapTarget")or d:IsA("BallSocketConstraint")or d:IsA("NoCollisionConstraint")or d:IsA("Script")or d:IsA("LocalScript")or d:IsA("ModuleScript")or d:IsA("Sound")or d:IsA("SurfaceGui")or d:IsA("BillboardGui")then d:Destroy()
    elseif d:IsA("BasePart")then d.Anchored=true;d.CanCollide=false;d.LocalTransparencyModifier=0 end
   end
   local nf=c:FindFirstChild("NumberForehead");if nf then nf:Destroy() end
   -- no Humanoid on preview copies: inside a ViewportFrame its appearance compositing (avatar body colours / classic
 -- clothing) paints over the limbs, so hands and arms showed grey instead of the skin tone
   local hum=c:FindFirstChildOfClass("Humanoid");if hum then hum:Destroy() end
   for _,cl in ipairs(c:GetChildren())do if cl:IsA("Clothing") or cl:IsA("ShirtGraphic") then cl:Destroy() end end
   for _,bc in ipairs(c:GetChildren())do if bc:IsA("BodyColors")then bc:Destroy()end end
   bodyCache,bodyFor=c,char
  end
 end
 return bodyCache and bodyCache:Clone()
end
function Art.Outfit(container,outfitId,rect,cwId)
 clearArt(container)
 local vp=viewport(container,"HairArt",rect)
 local world=Instance.new("WorldModel");world.Parent=vp
 local m=body()
 if m then
  m.Parent=world;m:PivotTo(CFrame.new())
  local Preview=require(script.Parent:WaitForChild("LoadoutPreview"))
  pcall(Preview.Solve,m,5)
  Outfits.Apply(m,outfitId,Players.LocalPlayer:GetAttribute("SkinTone"),cwId)
  local cf,size=m:GetBoundingBox()
  local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
  local h=math.max(size.Y,2)
  local aspect=rect.Size.X.Offset/math.max(1,rect.Size.Y.Offset)
  local dist=(h*0.62)/math.tan(math.rad(15))*math.max(1,1.15/aspect*1.4)
  cam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(dist*0.28,h*0.08,-dist),cf.Position)
 end
 vp.Parent=container
 return vp
end

-- colourway chip: two halves (main garment / legs) with the accent as a thin ring
function Art.Colorway(container,outfitId,cwId,rect)
 local outfit=Outfits.ById[outfitId or ""] or Outfits.ById[Outfits.Default]
 local map=Outfits.ColorMap(outfit,cwId)
 local main=map(outfit.Wear.torso and outfit.Wear.torso[1] or Color3.new(.3,.3,.3))
 local legsSpec=outfit.Wear.upperLegs or outfit.Wear.lowerLegs or outfit.Wear.torso
 local legs=map(legsSpec[1])
 local cw=Outfits.ColorwayById[cwId or ""]
 local accent=cw and cw.Accent or Color3.fromRGB(205,24,48)
 local f=Instance.new("Frame");f.Name="SwatchChip";f.BorderSizePixel=0;f.Position=rect.Position;f.Size=rect.Size;f.BackgroundColor3=main;f.ClipsDescendants=true
 f.ZIndex=(container.ZIndex or 1)+6
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=f
 -- the two halves as a hard-edged gradient on the round chip itself (a separate half frame isn't clipped to the
 -- rounded corners, so it stuck out of the circle as a dark bar)
 f.BackgroundColor3=Color3.new(1,1,1)
 local g=Instance.new("UIGradient");g.Rotation=90
 g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,main),ColorSequenceKeypoint.new(.5,main),ColorSequenceKeypoint.new(.501,legs),ColorSequenceKeypoint.new(1,legs)})
 g.Parent=f
 local s=Instance.new("UIStroke");s.Color=accent;s.Thickness=2;s.Parent=f
 local ar=Instance.new("UIAspectRatioConstraint");ar.AspectRatio=1;ar.Parent=f
 f.Parent=container
 return f
end
-- VISOR: that visor (and its rank trim) worn on the head, framed exactly like the hair cards (Art.Hair). Fitted
-- with the same maths as the real one (Numberfall.VisorFit / ServerScriptService.VisorDisplay).
local VisorFit=require(RS.Numberfall:WaitForChild("VisorFit"))
local VisorConfig=require(RS.Numberfall:WaitForChild("Config"))
-- (cw: a standard visor colourway, Numberfall.VisorColorways)
local VisorCw=require(RS.Numberfall:WaitForChild("VisorColorways"))
function Art.Visor(container,id,rect,zoom,cw)
 clearArt(container)
 local vp=viewport(container,"HairArt",rect)
 local world=Instance.new("WorldModel");world.Parent=vp
 local head=Art.Head();head.CFrame=CFrame.new();head.Parent=world
 local folder=RS.Numberfall:FindFirstChild("NumberfallVisor")
 local rank=folder and folder:FindFirstChild("Ranks") and folder.Ranks:FindFirstChild(id or "")
 local src=rank and rank:FindFirstChild("Handle") or (folder and folder:FindFirstChild("LEDVisor") and folder.LEDVisor:FindFirstChild("Handle"))
 if src then
  local scale,c0=VisorFit.Compute(head,0,VisorConfig)
  local h=src:Clone();h.Anchored=true;h.CanCollide=false;h.Size=VisorFit.MESH_SIZE*scale;h.CFrame=head.CFrame*c0;h.Parent=world
  if not rank and cw then VisorCw.Paint(h,cw) end
  local trim=rank and rank:FindFirstChild("Trim")
  local off=trim and trim:GetAttribute("TrimOffset")
  if trim and typeof(off)=="CFrame" then
   local t=trim:Clone();t.Anchored=true;t.CanCollide=false;t.Size=trim.Size*scale
   t.CFrame=h.CFrame*(CFrame.new(off.Position*scale)*off.Rotation);t.Parent=world
  end
 end
 local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
 local z=zoom or 1
 cam.CFrame=CFrame.lookAt(Vector3.new(1.35,0.75,-3.6)*z,Vector3.new(0,0.32,0))
 vp.Parent=container
 return vp
end
-- TRAIL: a dash of afterimage streaks in that trail's colours (Numberfall.Afterimages), with the ranked trails' dust
local Afterimages=require(RS.Numberfall:WaitForChild("Afterimages"))
function Art.Trail(container,id,rect)
 clearArt(container)
 local st=Afterimages.Styles[id=="Standard" and "default" or id] or Afterimages.Styles.default
 local holder=Instance.new("Frame");holder.Name="NotebookArt";holder.BackgroundTransparency=1;holder.ClipsDescendants=true
 holder.Position=rect.Position;holder.Size=rect.Size;holder.ZIndex=(container.ZIndex or 1)+2
 for i=1,6 do
  local col=st.colors[(i-1)%#st.colors+1]
  local s=Instance.new("Frame");s.BorderSizePixel=0;s.AnchorPoint=Vector2.new(.5,.5);s.BackgroundColor3=col
  s.Position=UDim2.fromScale(.5,.2+i*.1);s.Size=UDim2.new(.62-math.abs(i-3.5)*.06,0,0,i%2==0 and 7 or 11);s.Rotation=-14;s.ZIndex=holder.ZIndex+1
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=s
  local g=Instance.new("UIGradient");g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.75,.1),NumberSequenceKeypoint.new(1,0)});g.Parent=s
  s.Parent=holder
 end
 -- the head of the dash: a bright chevron
 -- two arms meeting at a tip just ahead of the streaks, pointing the way they fly
 local L,tipX,tipY=30,rect.Size.X.Offset*.85,rect.Size.Y.Offset*.46
 local back=math.rad(180-14)
 for _,side in ipairs({-1,1})do
  local a=back+side*math.rad(40)
  local dx,dy=math.cos(a),math.sin(a)
  local b=Instance.new("Frame");b.BorderSizePixel=0;b.AnchorPoint=Vector2.new(.5,.5);b.BackgroundColor3=Color3.new(1,1,1)
  b.Size=UDim2.fromOffset(L,7);b.Rotation=-math.deg(a);b.Position=UDim2.fromOffset(tipX+dx*L/2,tipY-dy*L/2);b.ZIndex=holder.ZIndex+2
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=b
  local s=Instance.new("UIStroke");s.Color=st.colors[1];s.Thickness=2;s.Parent=b
  b.Parent=holder
 end
 if st.dust then
  local r=Random.new(7)
  for i=1,10 do
   local d=Instance.new("Frame");d.BorderSizePixel=0;d.AnchorPoint=Vector2.new(.5,.5);d.BackgroundColor3=st.dust;d.Rotation=45
   local sz=r:NextInteger(3,6);d.Size=UDim2.fromOffset(sz,sz);d.Position=UDim2.fromScale(r:NextNumber(.15,.8),r:NextNumber(.2,.8));d.ZIndex=holder.ZIndex+3
   d.Parent=holder
  end
 end
 holder.Parent=container
 return holder
end
function Art.Swatch(container,colorId,rect,keep)
 if not keep then clearArt(container) end
 local f=Instance.new("Frame");f.Name="SwatchArt";f.BorderSizePixel=0;f.Position=rect.Position;f.Size=rect.Size
 f.BackgroundColor3=colorById[colorId] or Color3.new(0,0,0);f.ZIndex=(container.ZIndex or 1)+2
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=f
 local s=Instance.new("UIStroke");s.Color=Color3.fromRGB(240,232,228);s.Thickness=1;s.Transparency=.6;s.Parent=f
 local ar=Instance.new("UIAspectRatioConstraint");ar.AspectRatio=1;ar.Parent=f
 f.Parent=container
 return f
end

-- glitch number (chromatic split + scan lines)
function Art.Number(container,text,rect,color)
 clearArt(container)
 local holder=Instance.new("Frame");holder.Name="NumberArt";holder.BackgroundTransparency=1;holder.Position=rect.Position;holder.Size=rect.Size;holder.ZIndex=(container.ZIndex or 1)+2
 local function layer(dx,dy,col,trans,z)
  local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Position=UDim2.fromOffset(dx,dy);l.Size=UDim2.fromScale(1,1);l.Text=text
  l.FontFace=BAL;l.TextScaled=true;l.TextColor3=col;l.TextTransparency=trans;l.ZIndex=holder.ZIndex+z;l.Parent=holder;return l
 end
 layer(-3,0,Color3.fromRGB(0,200,255),.75,0);layer(3,0,Color3.fromRGB(255,0,90),.7,0)
 local main=layer(0,0,color or Color3.fromRGB(255,60,90),0,2)
 local st=Instance.new("UIStroke");st.Color=Color3.fromRGB(255,30,60);st.Thickness=1.2;st.Transparency=.3;st.Parent=main
 for i=1,5 do
  local s=Instance.new("Frame");s.BorderSizePixel=0;s.BackgroundColor3=Color3.fromRGB(8,4,6);s.BackgroundTransparency=.3
  s.Position=UDim2.new(0,0,(i*0.17)%1,0);s.Size=UDim2.new(1,0,0,1+(i%2));s.ZIndex=holder.ZIndex+4;s.Parent=holder
 end
 holder.Parent=container
 return holder
end

-- typing gear (Catalog items with Device): a little typewriter / keyboard in the item's colours
local function frame(parent,pos,size,color,anchor,z,corner)
 local f=Instance.new("Frame");f.BorderSizePixel=0;f.AnchorPoint=anchor or Vector2.new(.5,.5);f.Position=pos;f.Size=size
 f.BackgroundColor3=color;f.ZIndex=z or parent.ZIndex+1;f.Parent=parent
 if corner then local c=Instance.new("UICorner");c.CornerRadius=corner;c.Parent=f end
 return f
end
local function dot(parent,x,y,h,color,z,stroke)
 local f=frame(parent,UDim2.fromScale(x,y),UDim2.fromScale(h,h),color,nil,z,UDim.new(1,0))
 local ar=Instance.new("UIAspectRatioConstraint");ar.AspectRatio=1;ar.DominantAxis=Enum.DominantAxis.Height;ar.Parent=f
 if stroke then local s=Instance.new("UIStroke");s.Color=stroke;s.Thickness=1;s.Parent=f end
 return f
end
local function deviceArt(holder,item)
 local body=Color3.fromRGB(table.unpack(item.Color));local accent=Color3.fromRGB(table.unpack(item.Pencil))
 local z=holder.ZIndex
 if item.Device=="Typewriter" then
  local paper=frame(holder,UDim2.fromScale(.5,.52),UDim2.fromScale(.32,.46),Color3.fromRGB(244,238,222),Vector2.new(.5,1),z+1)
  local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Size=UDim2.fromScale(.86,.3);t.Position=UDim2.fromScale(.07,.12)
  t.Text="4217";t.Font=Enum.Font.SpecialElite;t.TextScaled=true;t.TextColor3=Color3.fromRGB(34,32,36);t.ZIndex=z+2;t.Parent=paper
  for i=1,2 do frame(paper,UDim2.fromScale(.5,.5+i*.16),UDim2.fromScale(.7,0),Color3.fromRGB(200,192,176),nil,z+2).Size=UDim2.new(.7,0,0,2) end
  frame(holder,UDim2.fromScale(.5,.53),UDim2.fromScale(.6,.09),Color3.fromRGB(22,22,24),nil,z+3,UDim.new(1,0))
  dot(holder,.2,.53,.12,accent,z+4);dot(holder,.8,.53,.12,accent,z+4)
  local b=frame(holder,UDim2.fromScale(.5,.57),UDim2.fromScale(.7,.36),body,Vector2.new(.5,0),z+2,UDim.new(.18,0))
  frame(b,UDim2.fromScale(.5,.9),UDim2.fromScale(.24,.06),accent,nil,z+4,UDim.new(1,0))
  for r,count in ipairs({7,6,5})do
   for c=1,count do dot(holder,.5+(c-(count+1)/2)*.075,.62+(r-1)*.085,.075,Color3.fromRGB(28,27,30),z+5,Color3.fromRGB(236,228,206)) end
  end
 else
  local bezel=frame(holder,UDim2.fromScale(.5,.5),UDim2.fromScale(.36,.46),Color3.fromRGB(20,20,24),Vector2.new(.5,1),z+1,UDim.new(.08,0))
  local scr=frame(bezel,UDim2.fromScale(.5,.47),UDim2.fromScale(.84,.76),Color3.fromRGB(8,12,10),nil,z+2,UDim.new(.06,0))
  local s=Instance.new("UIStroke");s.Color=accent;s.Thickness=1;s.Transparency=.4;s.Parent=scr
  local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Size=UDim2.fromScale(.86,.4);t.Position=UDim2.fromScale(.07,.12)
  t.Text="2093";t.Font=Enum.Font.Code;t.TextScaled=true;t.TextColor3=accent;t.ZIndex=z+3;t.Parent=scr
  frame(holder,UDim2.fromScale(.5,.52),UDim2.fromScale(.22,.04),Color3.fromRGB(20,20,24),nil,z+1)
  local base=frame(holder,UDim2.fromScale(.5,.55),UDim2.fromScale(.86,.3),body,Vector2.new(.5,0),z+2,UDim.new(.12,0))
  for r=1,3 do
   for c=1,10 do
    local lit=(r==1 and c==1) or (r==2 and c==10)
    frame(base,UDim2.fromScale(.075+(c-1)*.094,.2+(r-1)*.27),UDim2.fromScale(.07,.2),lit and accent or Color3.fromRGB(52,52,60),nil,z+3,UDim.new(.2,0))
   end
  end
  local glow=frame(holder,UDim2.fromScale(.5,.88),UDim2.fromScale(.8,.025),accent,nil,z+1,UDim.new(1,0))
  local g=Instance.new("UIGradient");g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(1,1)});g.Parent=glow
 end
end
-- GEAR thumbnails: the real models (ReplicatedStorage.Numberfall.NotebookAssets), the way they look in game.
-- Notebooks lie closed, cover up, tinted in the finish's colour, with the pen across them; typing gear (Device) shows
-- that machine from the front, three-quarter view. Art.GearScene returns the model and the direction to look from.
local GEAR_PEN_SCALE=.64 -- the pen beside the book at the same relative size as in your hands
-- a finish's hue at the cover's own brightness (the cover is a dark texture: multiplying by the raw colour went black)
local function finishTint(item)
 local c=item.Color or {255,255,255};local m=math.max(c[1],c[2],c[3],1)
 return Color3.new(c[1]/m,c[2]/m,c[3]/m)
end
Art.FinishTint=finishTint
-- typing gear: how each machine's mesh sits (rotation from the imported mesh to "front toward -Z") and the view
local DEVICE_VIEW={Typewriter={rot=CFrame.identity,dir=Vector3.new(.55,.7,-1)},Keyboard={rot=CFrame.identity,dir=Vector3.new(.5,.55,-1)}}
Art.DeviceView=DEVICE_VIEW
local GearCw=require(RS.Numberfall:WaitForChild("GearColorways"))
function Art.GearScene(item,cw)
 local A=RS.Numberfall:FindFirstChild("NotebookAssets");if not A then return nil end
 local m=Instance.new("Model");m.Name="GearScene"
 local function put(src,cf,scale)
  local p=src:Clone();p.Anchored=true;p.CanCollide=false;p.CastShadow=false;p.Size=src.Size*(scale or 1);p.CFrame=cf;p.Parent=m;return p
 end
 if item.Device then
  local src=A:FindFirstChild(item.Device);local view=DEVICE_VIEW[item.Device]
  if not src or not view then m:Destroy();return nil end
  if src:IsA("BasePart") then put(src,view.rot)
  else
   local c=src:Clone()
   -- (the keyboard is shown without its coiled cable, as it's held in game)
   local cable=c:FindFirstChild("Keyboard braided cable",true);if cable then cable:Destroy() end
   for _,d in ipairs(c:GetDescendants())do if d:IsA("BasePart")then d.Anchored=true;d.CanCollide=false;d.CastShadow=false;GearCw.PaintPart(d,d.Name,cw) end end
   c:PivotTo(view.rot);c.Parent=m
  end
  return m,view.dir
 end
 local book=A:FindFirstChild("Notebook");local pen=A:FindFirstChild("Pen")
 if not book then m:Destroy();return nil end
 -- (the cover is the mesh's -Y face: flipped over, then turned a little for some angle)
 local b=put(book,CFrame.Angles(0,math.rad(-16),0)*CFrame.Angles(math.pi,0,0))
 GearCw.PaintPart(b,"Notebook",cw)
 if pen then
  put(pen,CFrame.new(.1,b.Size.Y/2+pen.Size.Y*GEAR_PEN_SCALE/2+.004,-.04)*CFrame.Angles(0,math.rad(12),0),GEAR_PEN_SCALE)
 end
 return m,Vector3.new(.28,1,-.62)
end
-- GEAR card art: the 3D scene above (falls back to the flat drawing if the models aren't there)
function Art.Kit(container,item,rect,cw)
 clearArt(container)
 if not item then return nil end
 local scene,dir=Art.GearScene(item,cw)
 if scene then
  local vp=viewport(container,"HairArt",rect)
  vp.LightDirection=Vector3.new(-.5,-.75,.5)
  vp.Ambient=Color3.fromRGB(150,142,140);vp.LightColor=Color3.fromRGB(255,244,232)
  local world=Instance.new("WorldModel");world.Parent=vp;scene.Parent=world
  local cf,size=scene:GetBoundingBox()
  local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
  local ax,ay=rect.Size.X.Offset,rect.Size.Y.Offset
  local aspect=(ax>0 and ay>0) and ax/ay or 1
  local fill=item.Device and .6 or .68
  local dist=size.Magnitude/2/math.tan(math.rad(15))*math.max(fill,fill/aspect)
  cam.CFrame=CFrame.lookAt(cf.Position+dir.Unit*dist,cf.Position)
  vp.Parent=container
  return vp
 end
 if item.Device then
  local holder=Instance.new("Frame");holder.Name="NotebookArt";holder.BackgroundTransparency=1;holder.AnchorPoint=Vector2.new(.5,.5)
  holder.Position=UDim2.new(rect.Position.X.Scale,rect.Position.X.Offset+rect.Size.X.Offset/2,rect.Position.Y.Scale,rect.Position.Y.Offset+rect.Size.Y.Offset/2)
  holder.Size=rect.Size;holder.ZIndex=(container.ZIndex or 1)+2
  local ar=Instance.new("UIAspectRatioConstraint");ar.AspectRatio=1.6;ar.Parent=holder
  deviceArt(holder,item)
  holder.Parent=container
  return holder
 end
 local holder=Instance.new("Frame");holder.Name="NotebookArt";holder.BackgroundTransparency=1;holder.AnchorPoint=Vector2.new(.5,.5)
 holder.Position=UDim2.new(rect.Position.X.Scale,rect.Position.X.Offset+rect.Size.X.Offset/2,rect.Position.Y.Scale,rect.Position.Y.Offset+rect.Size.Y.Offset/2)
 holder.Size=rect.Size;holder.ZIndex=(container.ZIndex or 1)+2
 local col=Color3.fromRGB(table.unpack(item.Color));local pc=Color3.fromRGB(table.unpack(item.Pencil))
 local ar=Instance.new("UIAspectRatioConstraint");ar.AspectRatio=1.6;ar.Parent=holder
 local book=Instance.new("Frame");book.AnchorPoint=Vector2.new(.5,.5);book.Position=UDim2.fromScale(.42,.5);book.Size=UDim2.fromScale(.36,.86);book.BackgroundColor3=col;book.BorderSizePixel=0;book.ZIndex=holder.ZIndex+1;book.Parent=holder
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=book
 local spine=Instance.new("Frame");spine.Size=UDim2.new(0,8,1,0);spine.BackgroundColor3=col:Lerp(Color3.new(0,0,0),.45);spine.BorderSizePixel=0;spine.ZIndex=book.ZIndex+1;spine.Parent=book
 local band=Instance.new("Frame");band.Position=UDim2.new(0,0,.7,0);band.Size=UDim2.new(1,0,0,6);band.BackgroundColor3=pc;band.BorderSizePixel=0;band.ZIndex=book.ZIndex+1;band.Parent=book
 local lab=Instance.new("TextLabel");lab.BackgroundTransparency=1;lab.Size=UDim2.fromScale(1,.5);lab.Position=UDim2.fromScale(0,.15);lab.Text="記";lab.TextScaled=true;lab.TextColor3=Color3.fromRGB(240,232,228);lab.TextTransparency=.35;lab.ZIndex=book.ZIndex+2;lab.Parent=book
 local pen=Instance.new("Frame");pen.AnchorPoint=Vector2.new(.5,.5);pen.Position=UDim2.fromScale(.66,.56);pen.Size=UDim2.fromScale(.5,.07);pen.Rotation=-58;pen.BackgroundColor3=pc;pen.BorderSizePixel=0;pen.ZIndex=holder.ZIndex+4;pen.Parent=holder
 local pcn=Instance.new("UICorner");pcn.CornerRadius=UDim.new(1,0);pcn.Parent=pen
 local tip=Instance.new("Frame");tip.Size=UDim2.new(.16,0,1,0);tip.BackgroundColor3=col;tip.BorderSizePixel=0;tip.ZIndex=pen.ZIndex+1;tip.Parent=pen
 local ps=Instance.new("UIStroke");ps.Color=Color3.fromRGB(9,5,7);ps.Thickness=1.5;ps.Parent=pen
 holder.Parent=container
 return holder
end

-- simple notebook cover in the finish colour with its matching pen
function Art.Notebook(container,item,rect,pen)
 clearArt(container)
 local holder=Instance.new("Frame");holder.Name="NotebookArt";holder.BackgroundTransparency=1;holder.Position=rect.Position;holder.Size=rect.Size;holder.ZIndex=(container.ZIndex or 1)+2
 local col=Color3.fromRGB(table.unpack(item.Color));local pc=Color3.fromRGB(table.unpack(item.Pencil))
 if not pen then
  local book=Instance.new("Frame");book.AnchorPoint=Vector2.new(.5,.5);book.Position=UDim2.fromScale(.5,.5);book.Size=UDim2.fromScale(.42,.82);book.BackgroundColor3=col;book.BorderSizePixel=0;book.ZIndex=holder.ZIndex+1;book.Parent=holder
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=book
  local spine=Instance.new("Frame");spine.Size=UDim2.new(0,8,1,0);spine.BackgroundColor3=col:Lerp(Color3.new(0,0,0),.45);spine.BorderSizePixel=0;spine.ZIndex=book.ZIndex+1;spine.Parent=book
  local band=Instance.new("Frame");band.Position=UDim2.new(0,0,.7,0);band.Size=UDim2.new(1,0,0,6);band.BackgroundColor3=pc;band.BorderSizePixel=0;band.ZIndex=book.ZIndex+1;band.Parent=book
  local lab=Instance.new("TextLabel");lab.BackgroundTransparency=1;lab.Size=UDim2.fromScale(1,.5);lab.Position=UDim2.fromScale(0,.15);lab.Text="記";lab.TextScaled=true;lab.TextColor3=Color3.fromRGB(240,232,228);lab.TextTransparency=.35;lab.ZIndex=book.ZIndex+2;lab.Parent=book
 else
  local p=Instance.new("Frame");p.AnchorPoint=Vector2.new(.5,.5);p.Position=UDim2.fromScale(.5,.5);p.Size=UDim2.fromScale(.75,.09);p.Rotation=-28;p.BackgroundColor3=pc;p.BorderSizePixel=0;p.ZIndex=holder.ZIndex+1;p.Parent=holder
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=p
  local tip=Instance.new("Frame");tip.Size=UDim2.new(.16,0,1,0);tip.BackgroundColor3=col;tip.BorderSizePixel=0;tip.ZIndex=p.ZIndex+1;tip.Parent=p
 end
 holder.Parent=container
 return holder
end
-- BODY TYPE: your character wearing your outfit, on that body type
local BodyType=require(RS.Numberfall:WaitForChild("BodyType"))
function Art.Body(container,bodyId,rect)
 clearArt(container)
 local vp=viewport(container,"HairArt",rect)
 local world=Instance.new("WorldModel");world.Parent=vp
 local m=body()
 if m then
  m.Parent=world;m:PivotTo(CFrame.new())
  pcall(BodyType.Apply,m,bodyId,false)
  local Preview=require(script.Parent:WaitForChild("LoadoutPreview"))
  pcall(Preview.Solve,m,5)
  local p=Players.LocalPlayer
  Outfits.Apply(m,p:GetAttribute("Outfit"),p:GetAttribute("SkinTone"),p:GetAttribute("OutfitColor"))
  local cf,size=m:GetBoundingBox()
  local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
  local h=math.max(size.Y,2)
  local aspect=rect.Size.X.Offset/math.max(1,rect.Size.Y.Offset)
  local dist=(h*0.62)/math.tan(math.rad(15))*math.max(1,1.15/aspect*1.4)
  cam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(dist*0.28,h*0.08,-dist),cf.Position)
 end
 vp.Parent=container
 return vp
end

-- PET: the pet on its own, three-quarter view
local Pets=require(RS.Numberfall:WaitForChild("Pets"))
function Art.Pet(container,petId,rect,cwId)
 clearArt(container)
 local vp=viewport(container,"HairArt",rect)
 local world=Instance.new("WorldModel");world.Parent=vp
 local m=Pets.Build(petId,Players.LocalPlayer,cwId)
 if m then
  m.Parent=world;m.PrimaryPart.CFrame=CFrame.new();Pets.Animate(m,0.35,0)
  -- lights / particles don't show in a viewport anyway
  local cf,size=m:GetBoundingBox()
  local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
  local r=math.max(size.X,size.Y,size.Z,0.8)
  local aspect=rect.Size.X.Offset/math.max(1,rect.Size.Y.Offset)
  local dist=r*0.85/math.tan(math.rad(15))*math.max(1,1.1/aspect)
  cam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(dist*0.45,dist*0.22,-dist),cf.Position)
 else
  local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Size=UDim2.fromScale(1,1);l.Text="NO PET";l.FontFace=BAL;l.TextSize=26
  l.TextColor3=Color3.fromRGB(150,138,138);l.ZIndex=vp.ZIndex;l.Parent=vp
 end
 vp.Parent=container
 return vp
end

-- ELIMINATION FX: a burst emblem in the effect's colours (the Shop / Loadout preview plays the real thing)
local FX_ACCENT={FxShatter={255,220,220},FxInk={110,96,150},FxSakura={255,230,240},FxFrost={240,250,255},FxVoid={20,6,40},
 FxStorm={240,250,255},FxGlitch={255,40,200},FxInferno={255,214,90},FxHellgate={255,170,80},FxGilded={255,240,190}}
function Art.KillFx(container,item,rect)
 clearArt(container)
 local col=Color3.fromRGB(table.unpack(item.Color or {255,34,58}))
 local acc=Color3.fromRGB(table.unpack(FX_ACCENT[item.Id] or {255,255,255}))
 local holder=Instance.new("Frame");holder.Name="NotebookArt";holder.BackgroundTransparency=1;holder.ClipsDescendants=true
 holder.Position=rect.Position;holder.Size=rect.Size;holder.ZIndex=(container.ZIndex or 1)+2
 local function circle(scale,color,trans,z)
  local f=Instance.new("Frame");f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromScale(.5,.52);f.Size=UDim2.fromScale(scale,scale)
  f.BackgroundColor3=color;f.BackgroundTransparency=trans or 0;f.BorderSizePixel=0;f.ZIndex=holder.ZIndex+(z or 0)
  local ar=Instance.new("UIAspectRatioConstraint");ar.AspectRatio=1;ar.Parent=f
  local c=Instance.new("UICorner");c.CornerRadius=UDim.new(1,0);c.Parent=f
  f.Parent=holder;return f
 end
 -- glow
 local glow=circle(.92,col,0,0)
 local g=Instance.new("UIGradient");g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(.5,.85),NumberSequenceKeypoint.new(1,1)});g.Parent=glow
 -- rays
 for i=0,11 do
  local long=i%2==0
  local ray=Instance.new("Frame");ray.AnchorPoint=Vector2.new(0,.5);ray.Position=UDim2.fromScale(.5,.52)
  ray.Size=UDim2.fromScale(long and .42 or .3,long and .035 or .022);ray.BorderSizePixel=0;ray.BackgroundColor3=long and col or acc
  ray.Rotation=i*30+8;ray.ZIndex=holder.ZIndex+1
  local rg=Instance.new("UIGradient");rg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,0),NumberSequenceKeypoint.new(1,1)});rg.Parent=ray
  ray.Parent=holder
 end
 -- shockwave ring + core
 local ring=circle(.62,col,1,2);local st=Instance.new("UIStroke");st.Color=col;st.Thickness=3;st.Parent=ring
 local ring2=circle(.4,col,1,2);local st2=Instance.new("UIStroke");st2.Color=acc;st2.Thickness=1.5;st2.Transparency=.3;st2.Parent=ring2
 circle(.2,acc,0,3)
 circle(.11,Color3.new(1,1,1),0,4)
 holder.Parent=container
 return holder
end
return Art
