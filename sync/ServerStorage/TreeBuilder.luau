-- Edit-time tool: rebuilds every map tree (models named "Tree" with a Kind attribute) the same way:
--   * centred on its tree pit / planter (the small soil part under it), standing on the ground
--   * one trunk mesh per kind (Cherry for street trees, Pine for cypresses, OldTree for dead trees), one height
--     per area so rows match
--   * a canopy of crossed leaf cards (v2 foliage images) kept above head height, see-through, tagged "Foliage"
--     (StarterPlayerScripts.FoliageFade thins out the cards near the camera)
-- Run from the command bar: require(game.ServerStorage.TreeBuilder).All()
local CS=game:GetService("CollectionService")
local T={}
T.TEX={Crimson="rbxassetid://111299316026689",Oak="rbxassetid://114828499756116",Linden="rbxassetid://105651907390774",
 Autumn="rbxassetid://124683832956022",Cypress="rbxassetid://84825294637605",Dead="rbxassetid://81374435205324"}
T.HEIGHT={TownCircle=17,Corner45=20,Corner135=20,NorthQuarter=19,Terrace=17,Furnishing=19,CathedralSquare=24}
T.LEAF_TRANSPARENCY=.32
local function heightFor(t,kind)if t.Parent.Name=="Graveyard"then return kind=="Cypress"and 26 or 19 end;return T.HEIGHT[t.Parent.Name]or 19 end
local function meshFor(kind)return kind=="Cypress"and "Pine"or kind=="Dead"and "OldTree"or "Cherry"end
local function pit(t)
 local piv=t:GetPivot().Position local best,bd
 for _,p in ipairs(workspace:GetPartBoundsInRadius(piv+Vector3.new(0,1.5,0),3.2))do
  if not p:IsDescendantOf(t)and(p.Name=="Planter"or p.Name=="Part")and p.Parent==t.Parent and p.Size.X<12 and p.Size.Z<12 then
   local d=(Vector3.new(p.Position.X,0,p.Position.Z)-Vector3.new(piv.X,0,piv.Z)).Magnitude
   if not bd or d<bd then best,bd=p,d end
  end
 end
 return best
end
local function card(parent,cf,w,h,tex,rng,trans)
 local p=Instance.new("Part");p.Name="Leaves";p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Transparency=1
 p.Size=Vector3.new(w,h,.05);p.CFrame=cf;p.Parent=parent
 local tint=rng:NextNumber(.86,1)
 for _,f in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do
  local d=Instance.new("Decal");d.Face=f;d.Texture=tex;d.Transparency=trans;d.Color3=Color3.new(tint,tint,tint);d.Parent=p
 end
 CS:AddTag(p,"Foliage")
 return p
end
function T.Build(t,index)
 local NAT=game.ServerStorage.MarkedNature
 local kind=t:GetAttribute("Kind");local rng=Random.new(index*977)
 local H=heightFor(t,kind)
 -- anchor: the pit under the tree (first build) or the stored base (rebuilds)
 local stored=t:GetAttribute("Base")
 local p=not stored and pit(t)
 local anchor=stored or(p and p.Position)or t:GetPivot().Position
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={t}
 local g=workspace:Raycast(Vector3.new(anchor.X,anchor.Y+10,anchor.Z),Vector3.new(0,-30,0),params)
 local base=Vector3.new(anchor.X,g and g.Position.Y or anchor.Y,anchor.Z)
 for _,c in ipairs(t:GetChildren())do c:Destroy()end
 -- trunk
 local src=NAT[meshFor(kind)].tree
 local m=src:Clone();m.Name="TrunkMesh";m.Anchored=true;m.CanCollide=false;m.CanQuery=false;m.CanTouch=false;m.CastShadow=true
 for _,c in ipairs(m:GetChildren())do if c:IsA("ParticleEmitter")then c:Destroy()end end
 local sa=m:FindFirstChildOfClass("SurfaceAppearance")
 if sa and kind=="Cypress"then pcall(function()sa.Color=Color3.fromRGB(105,78,60)end)end
 local rx,rz=src.Size.X/src.Size.Y,src.Size.Z/src.Size.Y
 local k=math.min(1,.78/math.max(rx,rz))
 m.Size=Vector3.new(H*rx*k,H,H*rz*k)
 m.CFrame=CFrame.new(base+Vector3.new(0,H/2-.25,0))*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),0)
 m.Parent=t
 local col=Instance.new("Part");col.Name="TrunkCollider";col.Shape=Enum.PartType.Cylinder;col.Anchored=true;col.Transparency=1;col.CastShadow=false
 local tw=kind=="Cypress"and 1 or 1.2
 col.Size=Vector3.new(H*.4,tw,tw);col.CFrame=CFrame.new(base+Vector3.new(0,H*.2,0))*CFrame.Angles(0,0,math.rad(90));col.Parent=t
 local tex=T.TEX[kind]or T.TEX.Oak
 local n=0
 if kind=="Cypress"then
  -- a narrow column of pine sprays around the trunk, tapering to a point
  local y0,y1=.26*H,1.02*H;local levels=12
  for i=0,levels-1 do
   local f=i/(levels-1);local y=y0+(y1-y0)*f
   local r=(.21*H)*(1-f*.8)
   for j=0,3 do
    local yaw=j*math.pi/4+i*.6+rng:NextNumber(-.2,.2)
    card(t,CFrame.new(base+Vector3.new(0,y,0))*CFrame.Angles(0,yaw,0)*CFrame.Angles(rng:NextNumber(-.08,.08),0,0),2*r+1.2,.18*H*(1-f*.3),tex,rng,T.LEAF_TRANSPARENCY-.08);n+=1
   end
  end
 else
  local dead=kind=="Dead"
  local C=base+Vector3.new(0,.76*H,0)
  local Rx,Ry=.38*H,.21*H
  local N=dead and 8 or 24
  local golden=math.pi*(3-math.sqrt(5))
  for i=0,N-1 do
   local yv=1-(i+.5)/N*1.55 -- upper part of a sphere only: nothing hangs down into eye level
   local rad=math.sqrt(math.max(0,1-yv*yv));local th=i*golden+rng:NextNumber(-.3,.3)
   local dir=Vector3.new(math.cos(th)*rad,yv,math.sin(th)*rad)
   local r=rng:NextNumber(.55,1)
   local pos=C+Vector3.new(dir.X*Rx*r,dir.Y*Ry*r,dir.Z*Rx*r)
   local S=.3*H*rng:NextNumber(.85,1.15)
   local yaw=math.atan2(dir.X,dir.Z)+rng:NextNumber(-.4,.4)
   for j=0,1 do
    card(t,CFrame.new(pos)*CFrame.Angles(0,yaw+j*math.pi/2,0)*CFrame.Angles(rng:NextNumber(-.25,.25),0,rng:NextNumber(-.15,.15)),S,S*.85,tex,rng,dead and .15 or T.LEAF_TRANSPARENCY);n+=1
   end
  end
 end
 t.WorldPivot=CFrame.new(base)
 t:SetAttribute("Base",base);t:SetAttribute("Rebuilt",true);t:SetAttribute("TrunkMesh",meshFor(kind));t:SetAttribute("Height",H)
 return n
end
function T.All()
 local trees={}
 for _,mm in ipairs(workspace:GetDescendants())do if mm:IsA("Model")and mm.Name=="Tree"and mm:GetAttribute("Kind")then table.insert(trees,mm)end end
 local total=0
 for i,t in ipairs(trees)do total+=T.Build(t,i)end
 return #trees,total
end
return T
