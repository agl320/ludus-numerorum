-- Character preview helpers for the Loadout / Shop viewports.
--  * Solve: re-poses an anchored character clone from its joints (rest pose = standing straight, arms down),
--    optionally with a named pose. Keeps accessories, hair and the visor attached.
--  * Visor: lights the LED visor with **** using neon bars (SurfaceGuis don't render inside a ViewportFrame).
--  * TryOn: swaps the clone's hair for a style / colour without buying it.
local RS=game:GetService("ReplicatedStorage")
local Fit=require(RS:WaitForChild("Numberfall"):WaitForChild("HairFit"))
local VisorFit=require(RS.Numberfall:WaitForChild("VisorFit"))
local Config=require(RS.Numberfall:WaitForChild("Config"))
local P={}
local rad=math.rad
local function A(x,y,z)return CFrame.Angles(rad(x or 0),rad(y or 0),rad(z or 0))end
-- Motor6D transforms per pose (R15 names; R6 names map below)
local V=Vector3.new
-- Aim an arm: u = upper-arm direction, f = forearm direction, both in the torso's space
-- (+X = the character's right, +Y = up, -Z = forward). Returns the shoulder and elbow transforms, with the
-- elbow hinge set so the forearm bends exactly toward f.
local function aim(u,f)
 u=u.Unit;f=f.Unit
 local perp=f-u*f:Dot(u)
 if perp.Magnitude<1e-3 then perp=V(0,0,-1)-u*(-u.Z) end
 if perp.Magnitude<1e-3 then perp=V(1,0,0) end
 perp=perp.Unit
 local y=-u;local z=-perp;local x=y:Cross(z)
 return CFrame.fromMatrix(Vector3.zero,x,y,z),CFrame.Angles(math.acos(math.clamp(u:Dot(f),-1,1)),0,0)
end
P.Aim=aim
local function mir(v)return V(-v.X,v.Y,v.Z)end
-- right arm (u,f); left arm (u,f)
-- comp: swing the arms about the middle of the shoulder instead of the joint's corner pivot (arms-akimbo poses)
local function arms(j,ru,rf,lu,lf,comp)
 j.RightShoulder,j.RightElbow=aim(ru,rf)
 j.LeftShoulder,j.LeftElbow=aim(lu or mir(ru),lf or mir(rf))
 j._Comp=comp or nil
 return j
end
-- breathing / weight shift layered on every pose
local function idle(t,j)
 local b=math.sin(t*1.6);local s=math.sin(t*0.7)
 j.Waist=(j.Waist or CFrame.identity)*A(b*1.2,s*1.5,0)
 j.Neck=(j.Neck or CFrame.identity)*A(-b*1.2,s*2,0)
 return j
end
P.Poses={
 {Name="STANCE",F=function(t)local b=math.sin(t*1.6)*0.03
  return idle(t,arms({Root=A(0,-14,0),Waist=A(0,6,0),Neck=A(-3,12,0),LeftHip=A(0,0,-7),RightHip=A(6,0,4),RightKnee=A(-10,0,0),RightAnkle=A(4,0,0)},
   V(0.08+b,-1,0.05),V(0.04,-1,-0.25),V(-0.1-b,-1,0.02),V(-0.04,-1,-0.3)))end},
 {Name="CONFIDENT",F=function(t)local b=math.sin(t*1.6)*0.02
  return idle(t,arms({Neck=A(4,6,0),LeftHip=A(0,0,-8),RightHip=A(0,0,8)},V(0.45+b,-0.8,0.3),V(-0.7,-0.5,0.1),nil,nil,true))end},
 {Name="ARMS CROSSED",F=function(t)local b=math.sin(t*1.6)*0.02
  return idle(t,arms({Root=A(0,10,0),Neck=A(-6,-8,0),LeftHip=A(0,0,-5),RightHip=A(0,0,5)},
   V(-0.5,-0.7,-0.55+b),V(-1,-0.45,-0.05),V(0.5,-1,-0.35+b),V(1,0.5,0.12)))end},
 {Name="WAVE",F=function(t)local w=math.sin(t*7)
  return idle(t,arms({Neck=A(-4,-8,4),LeftHip=A(0,0,-5),RightHip=A(0,0,5)},
   V(1,0.3,0.05),V(0.1+w*0.4,1,0),V(-0.08,-1,0.05),V(-0.04,-1,-0.25)))end},
 {Name="STANDING",F=function(t)return idle(t,arms({},V(0.06,-1,0),V(0.04,-1,-0.12)))end},
}
-- holding gear (a notebook / typewriter / keyboard picked in GEAR): upper arms down and a little forward, forearms
-- forward and in toward the chest
function P.HoldJoints(t)
 local b=math.sin((t or 0)*1.6)*0.015
 return idle(t or 0,arms({},V(0.16,-0.84,-0.46+b),V(-0.1,0.12,-0.99)))
end
function P.Joints(index,t)local p=P.Poses[index] or P.Poses[1];return p.F and p.F(t or 0) or p.J or {} end
function P.Blend(from,to,alpha)
 local out={}
 for k,cf in pairs(to)do if typeof(cf)=="CFrame" then local f=from[k];out[k]=(typeof(f)=="CFrame" and f or CFrame.identity):Lerp(cf,alpha)end end
 for k,cf in pairs(from)do if typeof(cf)=="CFrame" and not out[k] then out[k]=cf:Lerp(CFrame.identity,alpha)end end
 out._Comp=(alpha>.5 and to._Comp or from._Comp) or nil
 return out
end
local R6={["Left Shoulder"]="LeftShoulder",["Right Shoulder"]="RightShoulder",["Left Hip"]="LeftHip",["Right Hip"]="RightHip",Neck="Neck"}

function P.Solve(model,poseIndex)
 local root=model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart;if not root then return end
 local pose=type(poseIndex)=="table" and poseIndex or P.Joints(poseIndex or 1,0)
 local edges={}
 local function add(a,b,f)edges[a]=edges[a] or {};table.insert(edges[a],{b,f})end
 for _,j in ipairs(model:GetDescendants())do
  if j:IsA("JointInstance") and j.Part0 and j.Part1 and j.Part0:IsDescendantOf(model) and j.Part1:IsDescendantOf(model) then
   local c0,c1=j.C0,j.C1
   local t=j:IsA("Motor6D") and pose[R6[j.Name] or j.Name] or CFrame.identity
   add(j.Part0,j.Part1,function(cf)return cf*c0*t*c1:Inverse()end)
   add(j.Part1,j.Part0,function(cf)return cf*c1*t:Inverse()*c0:Inverse()end)
  elseif (j:IsA("AnimationConstraint") or j:IsA("RigidConstraint")) and j.Attachment0 and j.Attachment1 and j.Attachment0.Parent and j.Attachment1.Parent and j.Attachment0.Parent:IsA("BasePart") and j.Attachment1.Parent:IsA("BasePart") then
   -- new avatar joints: parts are joined through their rig attachments
   local a0,a1=j.Attachment0,j.Attachment1;local p0,p1=a0.Parent,a1.Parent
   local c0,c1=CFrame.new(a0.Position),CFrame.new(a1.Position)
   local t=j:IsA("AnimationConstraint") and pose[R6[j.Name] or j.Name] or CFrame.identity
   if pose._Comp and (j.Name=="RightShoulder" or j.Name=="LeftShoulder") then local ox=-a1.Position.X;t=CFrame.new(ox,0,0)*t*CFrame.new(-ox,0,0) end
   add(p0,p1,function(cf)return cf*c0*t*c1:Inverse()end)
   add(p1,p0,function(cf)return cf*c1*t:Inverse()*c0:Inverse()end)
  elseif j:IsA("WeldConstraint") and j.Part0 and j.Part1 and j.Part0:IsDescendantOf(model) and j.Part1:IsDescendantOf(model) then
   local rel=j.Part0.CFrame:ToObjectSpace(j.Part1.CFrame)
   add(j.Part0,j.Part1,function(cf)return cf*rel end)
   add(j.Part1,j.Part0,function(cf)return cf*rel:Inverse()end)
  end
 end
 local seen={[root]=true};local queue={root};local i=1
 while queue[i] do
  local part=queue[i];i+=1
  for _,e in ipairs(edges[part] or {})do
   local other=e[1]
   if not seen[other] then seen[other]=true;other.CFrame=e[2](part.CFrame);table.insert(queue,other)end
  end
 end
end

-- ---- visor ****
local MESH_SIZE=Vector3.new(1.50800,0.37181,1.54824)
local MESH_FLIP=CFrame.Angles(0,math.pi,0)
local CELL=Vector2.new(0.12587,0.18880)
local GLYPH={X=47.2,Y=54,W=97.6,H=180}
local SLOTS={
 {Vector3.new(0.15206,-0.01246,-0.71635),Vector3.new(0.21767,0,-0.97602)},
 {Vector3.new(0.04238,-0.01246,-0.73183),Vector3.new(0.06077,0,-0.99815)},
 {Vector3.new(-0.06839,-0.01246,-0.72976),Vector3.new(-0.09804,0,-0.99518)},
 {Vector3.new(-0.17740,-0.01246,-0.71021),Vector3.new(-0.25379,0,-0.96726)},
}
local STAR={{{0.5,0.22},{0.5,0.78}},{{0.2,0.36},{0.8,0.64}},{{0.2,0.64},{0.8,0.36}}}
local LEDFont=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("LEDFont"))
local GLOW=Color3.fromRGB(255,30,48);local CORE=Color3.fromRGB(255,190,190)
local function bar(parent,handle,cf,len,thick,color,depth)
 local p=Instance.new("Part");p.Name="StarBar";p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
 p.Material=Enum.Material.Neon;p.Color=color;p.Size=Vector3.new(len+thick,thick,depth);p.CFrame=cf;p.Parent=parent
 local w=Instance.new("WeldConstraint");w.Part0=handle;w.Part1=p;w.Parent=p
end
-- code: any LEDFont characters ("****", "O__O", "-__-"...). name: holder model name, so a preview can keep two
-- faces built (e.g. open / shut eyes) and swap them to blink.
function P.Visor(model,code,name)
 local vis=model:FindFirstChild("LEDVisor");local handle=vis and vis:FindFirstChild("Handle");if not handle then return false end
 name=name or "PreviewStars"
 local old=vis:FindFirstChild(name);if old then old:Destroy()end
 local nf=model:FindFirstChild("NumberForehead");if nf then nf:Destroy()end
 local scale=vis:GetAttribute("VisorScale")
 if typeof(scale)=="number" then scale=Vector3.one*scale end
 if typeof(scale)~="Vector3" then scale=handle.Size/MESH_SIZE end
 local visorCF=handle.CFrame*MESH_FLIP:Inverse()
 local holder=Instance.new("Model");holder.Name=name;holder.Parent=vis
 local w,h=CELL.X*scale.X,CELL.Y*scale.Y
 local function lp(pt)local u=(GLYPH.X+pt[1]*GLYPH.W)/192;local v=(GLYPH.Y+pt[2]*GLYPH.H)/288;return Vector2.new((0.5-u)*w,(0.5-v)*h)end
 for s,slot in ipairs(SLOTS)do
  local ch=string.sub(code or "****",s,s)
  local pos=slot[1]*scale;local normal=(slot[2]/scale).Unit
  local panel=visorCF*CFrame.lookAt(pos,pos+normal)
  if ch~="" and ch~=" " then
   -- dot-matrix LEDs, same font and spacing as the real visor (Numberfall.LEDFont)
   local B=LEDFont.Box
   local pitch=math.min(B.W/(LEDFont.Cols-1),B.H/(LEDFont.Rows-1))
   local bw,bh=pitch*(LEDFont.Cols-1),pitch*(LEDFont.Rows-1)
   local box={B.X+(B.W-bw)/2,B.Y+(B.H-bh)/2}
   for _,d in ipairs(LEDFont.Dots(ch))do
    local p=lp({(box[1]-GLYPH.X+d.X*bw)/GLYPH.W,(box[2]-GLYPH.Y+d.Y*bh)/GLYPH.H})
    local led=Instance.new("Part");led.Name="StarDot";led.Shape=Enum.PartType.Ball;led.Anchored=true;led.CanCollide=false;led.CanQuery=false;led.CanTouch=false;led.CastShadow=false
    led.Material=Enum.Material.Neon;led.Color=GLOW;led.Size=Vector3.one*(w*pitch/192*0.84)
    led.CFrame=panel*CFrame.new(p.X,p.Y,-0.004);led.Parent=holder
    local wc=Instance.new("WeldConstraint");wc.Part0=handle;wc.Part1=led;wc.Parent=led
   end
  end
 end
 return true
end

-- The four digit cells of the visor screen, in world space: {CFrame (LookVector = out of the screen), width, height},
-- left -> right as seen. The Loadout / Shop draw the number style over these as a 2D overlay (Numberfall.NumberStyles).
function P.VisorPanels(model)
 local vis=model:FindFirstChild("LEDVisor");local handle=vis and vis:FindFirstChild("Handle");if not handle then return nil end
 local scale=vis:GetAttribute("VisorScale")
 if typeof(scale)=="number" then scale=Vector3.one*scale end
 if typeof(scale)~="Vector3" then scale=handle.Size/MESH_SIZE end
 local visorCF=handle.CFrame*MESH_FLIP:Inverse()
 local out={}
 for i,slot in ipairs(SLOTS)do
  local pos=slot[1]*scale;local normal=(slot[2]/scale).Unit
  out[i]={visorCF*CFrame.lookAt(pos,pos+normal),CELL.X*scale.X,CELL.Y*scale.Y}
 end
 return out
end

-- ---- visor refit for a (previewed) hairstyle: same maths as the real visor (Numberfall.VisorFit)
function P.FitVisor(model,styleId)
 local head=model:FindFirstChild("Head");local vis=model:FindFirstChild("LEDVisor");local h=vis and vis:FindFirstChild("Handle")
 if not head or not h then return end
 local pad=(styleId and styleId~="None" and Fit.VisorPad and Fit.VisorPad[styleId]) or 0
 local scale,c0=VisorFit.Compute(head,pad,Config)
 h.Size=VisorFit.MESH_SIZE*scale;vis:SetAttribute("VisorScale",scale)
 h.CFrame=head.CFrame*c0
 local w=h:FindFirstChild("VisorWeld");if w then w.C0=c0 end
 -- a colourway's modelled trim is rebuilt at the new fit (Numberfall.VisorColorways)
 if h:FindFirstChild("ColorwayTrim") then require(RS.Numberfall:WaitForChild("VisorColorways")).Trim(h) end
 -- the rank visor's trim follows the new fit
 local trim=vis:FindFirstChild("RankTrim");local off=trim and trim:GetAttribute("TrimOffset")
 if trim and typeof(off)=="CFrame" then
  local base=trim:GetAttribute("TrimSize") or trim.Size/((h.Size/VisorFit.MESH_SIZE))
  local rel=CFrame.new(off.Position*scale)*off.Rotation
  trim.Size=base*scale;trim.CFrame=h.CFrame*rel
  local tw=trim:FindFirstChild("TrimWeld");if tw then tw.C0=rel end
 end
 P.Visor(model,"****")
end

-- ---- visor try-on: the base visor or a rank one (Numberfall.NumberfallVisor.Ranks) with its trim, built the same way
-- as the real one (ServerScriptService.VisorDisplay), at the size / place the visor already has on the preview
local VisorCw=require(RS.Numberfall:WaitForChild("VisorColorways"))
function P.RankVisor(model,rankId,cw)
 local vis=model:FindFirstChild("LEDVisor");local h=vis and vis:FindFirstChild("Handle");if not h then return end
 local folder=RS.Numberfall:FindFirstChild("NumberfallVisor");if not folder then return end
 local rank=rankId and rankId~="Standard" and folder:FindFirstChild("Ranks") and folder.Ranks:FindFirstChild(rankId) or nil
 local src=(rank and rank:FindFirstChild("Handle")) or (folder:FindFirstChild("LEDVisor") and folder.LEDVisor:FindFirstChild("Handle"))
 if not src then return end
 if not (rank and rank:FindFirstChild("Handle")) then rank=nil end
 local nh=src:Clone();nh.Name="Handle"
 nh.Anchored,nh.CanCollide,nh.CanQuery,nh.CanTouch=true,false,false,false
 nh.Size=h.Size;nh.CFrame=h.CFrame
 -- the standard visor in its colourway (its modelled trim is built at the final size / place)
 local oldTrim=h:FindFirstChild("ColorwayTrim");if oldTrim then oldTrim:Destroy() end
 if not rank and cw then VisorCw.Paint(nh,cw) end
 -- the old handle's welds / attachments move over; everything joined to it is re-pointed
 for _,d in ipairs(h:GetChildren())do if not d:IsA("SurfaceAppearance") then d.Parent=nh end end
 for _,j in ipairs(model:GetDescendants())do
  if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
   if j.Part0==h then j.Part0=nh end
   if j.Part1==h then j.Part1=nh end
  end
 end
 nh.Parent=vis;h:Destroy()
 if vis:IsA("Model") then vis.PrimaryPart=nh end
 local old=vis:FindFirstChild("RankTrim");if old then old:Destroy() end
 local tsrc=rank and rank:FindFirstChild("Trim");local off=tsrc and tsrc:GetAttribute("TrimOffset")
 if tsrc and typeof(off)=="CFrame" then
  local scale=vis:GetAttribute("VisorScale")
  if typeof(scale)~="number" and typeof(scale)~="Vector3" then scale=nh.Size/VisorFit.MESH_SIZE end
  local t=tsrc:Clone();t.Name="RankTrim"
  t.Anchored,t.CanCollide,t.CanQuery,t.CanTouch=true,false,false,false
  t.Size=tsrc.Size*scale
  t:SetAttribute("TrimSize",tsrc.Size);t:SetAttribute("TrimOffset",off)
  local rel=CFrame.new(off.Position*scale)*off.Rotation
  t.CFrame=nh.CFrame*rel
  local tw=Instance.new("Weld");tw.Name="TrimWeld";tw.Part0=nh;tw.Part1=t;tw.C0=rel;tw.Parent=t
  t.Parent=vis
 end
 vis:SetAttribute("VisorRank",rank and rankId or nil)
end

-- ---- trail try-on: one dash of afterimages (Numberfall.Afterimages colours) sweeping in to the preview body from
-- its side, into `world` (the viewport's WorldModel). Particles don't show in a viewport, so the ranked trails' dust
-- is drawn as little glinting neon specks.
local Afterimages=require(RS.Numberfall:WaitForChild("Afterimages"))
local TS=game:GetService("TweenService")
local GHOST_BODY={Head=true,UpperTorso=true,LowerTorso=true,Torso=true,LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,
 RightUpperArm=true,RightLowerArm=true,RightHand=true,LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,
 RightLowerLeg=true,RightFoot=true,["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true}
function P.TrailDash(world,model,styleId)
 local st=Afterimages.Styles[(styleId==nil or styleId=="Standard") and "default" or styleId] or Afterimages.Styles.default
 local root=model:FindFirstChild("HumanoidRootPart");if not root then return end
 local parts={}
 for _,part in ipairs(model:GetChildren())do if part:IsA("BasePart") and GHOST_BODY[part.Name] and part.Transparency<0.9 then table.insert(parts,part) end end
 local side=root.CFrame.RightVector
 local n=st.dense and 8 or 6
 local fade=0.5
 local rng=Random.new()
 for i=1,n do
  if not world.Parent or model.Parent~=world then return end
  local off=-side*(3.4*(1-(i-1)/n)) -- farthest first, closing in on the body
  local color=st.colors[(i-1)%#st.colors+1]
  local holder=Instance.new("Model");holder.Name="TrailPreview";holder.Parent=world
  for _,part in ipairs(parts)do
   local c=Instance.new("Part");c.Anchored=true;c.CanCollide=false;c.CanQuery=false;c.CanTouch=false;c.CastShadow=false
   c.Material=st.material or Enum.Material.Neon;c.Color=color;c.Transparency=st.material and st.transparency or math.max(0.45,st.transparency-0.12)
   c.Size=part.Size*0.98;c.CFrame=part.CFrame+off;c.Parent=holder
   TS:Create(c,TweenInfo.new(fade,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=1,Size=part.Size*0.8}):Play()
  end
  if st.dust and i%2==0 then
   for _=1,3 do
    local d=Instance.new("Part");d.Shape=Enum.PartType.Ball;d.Anchored=true;d.CanCollide=false;d.CanQuery=false;d.CanTouch=false;d.CastShadow=false
    d.Material=Enum.Material.Neon;d.Color=st.dust;d.Size=Vector3.one*rng:NextNumber(0.1,0.18)
    d.CFrame=CFrame.new(root.Position+off+Vector3.new(rng:NextNumber(-0.6,0.6),rng:NextNumber(-1.6,1.4),rng:NextNumber(-0.5,0.5)));d.Parent=holder
    TS:Create(d,TweenInfo.new(fade+0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.zero,CFrame=d.CFrame+Vector3.new(0,0.5,0)}):Play()
   end
  end
  task.delay(fade+0.25,function()holder:Destroy()end)
  task.wait(st.dense and 0.035 or 0.045)
 end
end

-- ---- face mask (scarf) on the preview
local MASK_FLIP=CFrame.Angles(0,math.pi,0)
local MASK_VERSIONS={{height=1.0474,centre=Vector3.new(-0.0005,-0.5366,-0.0075)},{height=0.9874,centre=Vector3.new(-0.0020,-0.5066,-0.0075)}}
local MaskDye=require(RS.Numberfall:WaitForChild("Extras"))
function P.Mask(model,maskId,cwId)
 local head=model:FindFirstChild("Head");if not head then return end
 local old=model:FindFirstChild("FaceMask");if old then old:Destroy()end
 local folder=RS.Numberfall:FindFirstChild("MaskModels")
 local src=folder and folder:FindFirstChild(maskId or "") and folder[maskId]:FindFirstChild("Handle")
 if not src then Fit.ApplyTuck(model);return end
 local scale=head.Size.X/1.2;local best,bd=MASK_VERSIONS[1],math.huge
 for _,v in ipairs(MASK_VERSIONS)do local d=math.abs(src.Size.Y-v.height);if d<bd then best,bd=v,d end end
 local holder=Instance.new("Model");holder.Name="FaceMask"
 local h=src:Clone();h.Name="Handle";h.Anchored=true;h.CanCollide=false;h.Size=src.Size*scale
 local c0=CFrame.new(best.centre*scale)*MASK_FLIP
 -- catalog head items (the cat hood) sit by their attachment instead
 local ac,asc=MaskDye.MaskOffset(head,src)
 if ac then c0=ac;h.Size=src.Size*asc end
 h.CFrame=head.CFrame*c0;h.Parent=holder
 if cwId then MaskDye.DyeMask(h,cwId) end
 local w=Instance.new("Weld");w.Name="FaceMaskWeld";w.Part0=head;w.Part1=h;w.C0=c0;w.Parent=h
 holder.Parent=model
 Fit.ApplyTuck(model) -- a hood tucks the hair in under it
end

-- ---- clothing try-on (Numberfall.Outfits), with the player's skin tone on the uncovered parts
local Outfits=require(RS.Numberfall:WaitForChild("Outfits"))
function P.Outfit(model,outfitId,cwId)
 Outfits.Apply(model,outfitId,game:GetService("Players").LocalPlayer:GetAttribute("SkinTone"),cwId)
end

-- ---- hair try-on
function P.Hair(model,styleId,colorId)
 local head=model:FindFirstChild("Head");if not head then return end
 local old=model:FindFirstChild("Hair");if old then old:Destroy()end
 local h,offset=Fit.Build(head,styleId,colorId);if not h then return end
 local holder=Instance.new("Model");holder.Name="Hair";holder:SetAttribute("StyleId",styleId);holder:SetAttribute("ColorId",colorId)
 h.Anchored=true;h.CanCollide=false;h.CFrame=head.CFrame*offset;h.Parent=holder
 local weld=Instance.new("Weld");weld.Name="HairWeld";weld.Part0=head;weld.Part1=h;weld.C0=offset;weld.Parent=h
 holder.Parent=model
 Fit.ApplyTuck(model)
end
return P
