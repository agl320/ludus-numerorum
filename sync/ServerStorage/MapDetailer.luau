-- Procedural architectural detail for the MARKED map (stone window surrounds, sills, lintels...).
-- Pieces go in a "Detail" folder inside each building model; they don't collide or block raycasts.
local D={}
D.skip={shape=0,nowall=0,deep=0}
D.STONE=Color3.fromRGB(150,141,128)
local wallMats={[Enum.Material.Limestone]=true,[Enum.Material.Brick]=true,[Enum.Material.Cobblestone]=true,[Enum.Material.Slate]=true,
 [Enum.Material.SmoothPlastic]=true,[Enum.Material.Plastic]=true,[Enum.Material.Plaster]=true,[Enum.Material.Concrete]=true,[Enum.Material.Rock]=true,
 [Enum.Material.Granite]=true,[Enum.Material.Sandstone]=true,[Enum.Material.Wood]=true,[Enum.Material.WoodPlanks]=true,[Enum.Material.Basalt]=true}
local cache={}
local function walls(model)
 if cache[model] then return cache[model] end
 local list={}
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("BasePart") and wallMats[p.Material] and p.Transparency<0.5 and p.Parent.Name~="Detail" then
   local s=p.Size
   -- something wall-sized: at least two big dimensions
   local big=(s.X>3 and 1 or 0)+(s.Y>3 and 1 or 0)+(s.Z>3 and 1 or 0)
   if big>=2 then table.insert(list,p) end
  end
 end
 cache[model]=list
 return list
end
local function inside(list,point)
 for _,p in ipairs(list) do
  local l=p.CFrame:PointToObjectSpace(point)
  local s=p.Size/2
  if math.abs(l.X)<=s.X+0.02 and math.abs(l.Y)<=s.Y+0.02 and math.abs(l.Z)<=s.Z+0.02 then
   if p:IsA("WedgePart") then
    -- wedge: solid below the slope (slope from back-top to front-bottom)
    if (l.Y+s.Y)/(2*s.Y) <= (l.Z+s.Z)/(2*s.Z)+0.02 then return p end
   else return p end
  end
 end
 return nil
end
function D.Window(pane,folder,model)
 local cf,size=pane.CFrame,pane.Size
 local ax={{cf.RightVector,size.X},{cf.UpVector,size.Y},{cf.LookVector,size.Z}}
 local thin=1 for i=2,3 do if ax[i][2]<ax[thin][2] then thin=i end end
 if ax[thin][2]>0.45 then D.skip.shape+=1 return 0 end
 local others={} for i=1,3 do if i~=thin then table.insert(others,i) end end
 local hi,wi=others[1],others[2]
 if math.abs(ax[wi][1].Y)>math.abs(ax[hi][1].Y) then hi,wi=wi,hi end
 local up,right,n=ax[hi][1],ax[wi][1],ax[thin][1]
 if up.Y<0 then up=-up end
 local h,w=ax[hi][2],ax[wi][2]
 if math.abs(up.Y)<0.8 or h<1.2 or w<0.9 or h>9 or w>8 then D.skip.shape+=1 return 0 end
 local list=walls(model)
 local c=cf.Position
 local half=ax[thin][2]/2
 -- probe both sides for wall at the window's edges (not its middle: the opening may be cut out)
 local function wallAt(dir,dist)
  local hits=0
  for _,o in ipairs({right*(w/2+0.25),-right*(w/2+0.25),up*(h/2+0.25)}) do if inside(list,c+o+dir*dist) then hits+=1 end end
  return hits
 end
 local back,front=wallAt(-n,0.5),wallAt(n,0.5)
 if front>back then n=-n;back,front=front,back end
 if back==0 then
  back,front=wallAt(-n,1.2),wallAt(n,1.2)
  if front>back then n=-n;back,front=front,back end
  if back==0 then D.skip.nowall+=1 return 0 end
 end
 if front==back and front>0 then
  -- buried in a solid block: face away from the middle of the building
  local mid=model:GetBoundingBox().Position
  if (c-mid):Dot(n)<0 then n=-n end
 end
 -- wall surface: march outward until the window's edges are in open air
 local surface=half
 for i=0,30 do
  local d=i*0.1
  if wallAt(n,d)==0 then surface=math.max(d,half);break end
  if i==30 then D.skip.deep+=1 return 0 end
 end
 local function piece(name,offset,sz)
  local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
  p.Size=sz;p.Material=Enum.Material.Limestone;p.Color=D.STONE
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p.CFrame=CFrame.fromMatrix(c+right*offset.X+up*offset.Y+n*offset.Z,right,up,n)
  p.Parent=folder
 end
 local depth,side=0.3,0.32
 local z=surface+depth/2-0.05
 piece("Jamb",Vector3.new(-(w/2+side/2),0,z),Vector3.new(side,h+0.1,depth))
 piece("Jamb",Vector3.new(w/2+side/2,0,z),Vector3.new(side,h+0.1,depth))
 piece("Lintel",Vector3.new(0,h/2+0.28,z+0.03),Vector3.new(w+side*2+0.45,0.56,depth+0.06))
 piece("Sill",Vector3.new(0,-h/2-0.17,surface+0.3),Vector3.new(w+side*2+0.35,0.34,0.7))
 return 4
end
return D
