-- Client-only posing of actual avatar limbs while a player writes (every client poses every writer, so the
-- writing pose is visible to everyone). Never hides other players' arms.
-- R15 (Motor6D or AnimationConstraint joints): analytic two-bone IK on shoulder + elbow, layered over the
-- running animation with a weight. R6: rotate the rigid arm at the shoulder.
local Run=game:GetService("RunService")
local Pose={};Pose.__index=Pose
local function frames(j)
 if j:IsA("Motor6D") then return j.Part0,j.Part1,j.C0,j.C1 end
 local a0,a1=j.Attachment0,j.Attachment1
 if a0 and a1 then return a0.Parent,a1.Parent,a0.CFrame,a1.CFrame end
end
local function joint(character,name)
 for _,d in ipairs(character:GetDescendants())do
  if d.Name==name and (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) then return d end
 end
end
-- shortest rotation taking unit vector a onto unit vector b
local function rotBetween(a,b)
 local axis=a:Cross(b);local dot=math.clamp(a:Dot(b),-1,1)
 if axis.Magnitude<1e-6 then
  if dot>0 then return CFrame.new() end
  local ortho=math.abs(a.X)<.9 and Vector3.xAxis or Vector3.yAxis
  return CFrame.fromAxisAngle(a:Cross(ortho).Unit,math.pi)
 end
 return CFrame.fromAxisAngle(axis.Unit,math.acos(dot))
end
function Pose.new(character)
 local self=setmetatable({character=character,chains={},motors={},weight=0},Pose)
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 local torso=character:FindFirstChild("UpperTorso")or character:FindFirstChild("Torso")
 if not humanoid or not torso then return self end
 self.torso=torso
 character:SetAttribute("LocalNotebookPose",true)
 for _,side in ipairs({"Left","Right"})do
  local shoulder=joint(character,side.."Shoulder")
  local elbow=joint(character,side.."Elbow")
  local wrist=joint(character,side.."Wrist")
  local hand=character:FindFirstChild(side.."Hand")
  if shoulder and elbow and wrist and hand and character:FindFirstChild(side.."UpperArm") then
   local _,_,_,sC1=frames(shoulder)
   local _,_,eC0,eC1=frames(elbow)
   local _,_,wC0=frames(wrist)
   if sC1 and eC0 and wC0 then
    local u=eC0.Position-sC1.Position
    local v=wC0.Position-eC1.Position
    v=v+(v.Magnitude>1e-3 and v.Unit or Vector3.new(0,-1,0))*hand.Size.Y*.55 -- reach to the middle of the hand
    self.chains[side]={shoulder=shoulder,elbow=elbow,u=u,v=v,L1=u.Magnitude,L2=v.Magnitude,
     pole=Vector3.new(side=="Left" and -.85 or .85,-1,.45)}
   end
  else
   for _,m in ipairs(torso:GetChildren())do
    if m:IsA("Motor6D")and m.Part1==character:FindFirstChild(side.." Arm")then
     self.motors[side]={joint=m,base=m.C0}
    end
   end
  end
 end
 -- Restore before Animator evaluates, then layer once after it evaluates.
 self.beforeAnimation=Run.PreAnimation:Connect(function()
  for _,data in pairs(self.motors)do
   if data.animationBase and data.joint.Parent then data.joint.Transform=data.animationBase end
   data.animationBase=nil
  end
  for _,c in pairs(self.chains)do
   if c.animS and c.shoulder.Parent then c.shoulder.Transform=c.animS end
   if c.animE and c.elbow.Parent then c.elbow.Transform=c.animE end
   c.animS,c.animE=nil,nil
  end
 end)
 self.beforeSimulation=Run.PreSimulation:Connect(function()
  if not character.Parent or humanoid.Health<=0 or character:GetAttribute("Ragdolled")then return end
  for _,data in pairs(self.motors)do
   local m=data.joint
   if m.Parent and m.Enabled and data.smoothed then
    data.animationBase=m.Transform
    m.Transform=data.animationBase:Lerp(data.base:Inverse()*data.smoothed,self.weight or 1)
    data.applied=data.smoothed
   end
  end
  for _,c in pairs(self.chains)do self:Solve(c) end
 end)
 return self
end
function Pose:Solve(c)
 local w=self.weight or 0
 if not c.localTarget or w<=.001 then return end
 local P0,_,C0,C1=frames(c.shoulder)
 local _,_,D0,D1=frames(c.elbow)
 if not P0 or not D0 then return end
 -- targets are kept torso-relative so they stay glued to the body however fast it moves
 c.target=self.torso.CFrame:PointToWorldSpace(c.localTarget)
 c.animS,c.animE=c.shoulder.Transform,c.elbow.Transform
 local shoulderFrame=P0.CFrame*C0
 local S=shoulderFrame.Position
 local L1,L2=c.L1,c.L2
 local d=c.target-S
 local dist=math.clamp(d.Magnitude,math.abs(L1-L2)+.05,L1+L2-.02)
 local du=d.Magnitude>1e-3 and d.Unit or -P0.CFrame.UpVector
 local pole=P0.CFrame:VectorToWorldSpace(c.pole)
 local perp=pole-du*pole:Dot(du)
 perp=perp.Magnitude>1e-3 and perp.Unit or -P0.CFrame.UpVector
 local a=(L1*L1-L2*L2+dist*dist)/(2*dist)
 local E=S+du*a+perp*math.sqrt(math.max(0,L1*L1-a*a))
 local T=S+du*dist
 -- upper arm: turn the animated bone onto the solved direction (keeps the animation's twist)
 local upperCur=shoulderFrame*c.animS*C1:Inverse()
 local upperRot=rotBetween(upperCur:VectorToWorldSpace(c.u).Unit,(E-S).Unit)*upperCur.Rotation
 local Xs=CFrame.new(c.animS.Position)*(shoulderFrame.Rotation:Inverse()*upperRot*C1.Rotation)
 local upperNew=shoulderFrame*Xs*C1:Inverse()
 -- forearm
 local elbowFrame=upperNew*D0
 local lowerCur=elbowFrame*c.animE*D1:Inverse()
 local lowerRot=rotBetween(lowerCur:VectorToWorldSpace(c.v).Unit,(T-E).Unit)*lowerCur.Rotation
 local Xe=CFrame.new(c.animE.Position)*(elbowFrame.Rotation:Inverse()*lowerRot*D1.Rotation)
 c.shoulder.Transform=c.animS:Lerp(Xs,w)
 c.elbow.Transform=c.animE:Lerp(Xe,w)
 c.palmLocal=self.torso.CFrame:PointToObjectSpace(T)
end
-- 0..1: how firmly the arms hold the book (eases the arms in and out as the book is taken out or put away)
function Pose:SetWeight(weight)
 self.weight=weight
 -- (SlideAnimator hands the arms back to the walk / sprint swing by this much, so putting the book away while
 -- running blends the arms back into the stride instead of snapping them)
 if self.character and math.abs((self.character:GetAttribute("LocalNotebookWeight") or -1)-weight)>.02 then
  self.character:SetAttribute("LocalNotebookWeight",weight)
 end
end
function Pose:Update(grips,dt)
 for side,c in pairs(self.chains)do
  local g=grips[side]
  if g then
   -- torso-relative smoothing so the hands follow the body without lag but strokes stay soft
   local localTarget=self.torso.CFrame:PointToObjectSpace(g)
   c.localTarget=c.localTarget and c.localTarget:Lerp(localTarget,1-math.exp(-30*dt)) or localTarget
  end
 end
 -- R6 has no elbow joint. Rotate its real rigid arm at its real shoulder.
 for side,data in pairs(self.motors)do
  local m=data.joint
  if m.Parent and m.Part0 and m.Part1 then
   local pivot=m.Part0.CFrame*data.base
   local delta=grips[side]-pivot.Position
   if delta.Magnitude>.01 then
    local direction=delta.Unit
    local palm=Vector3.new(0,-m.Part1.Size.Y*.43,0)
    local localReach=palm-m.C1.Position
    local localBasis=CFrame.lookAt(Vector3.zero,localReach,Vector3.zAxis)
    local worldBasis=CFrame.lookAt(pivot.Position,pivot.Position+direction,m.Part0.CFrame.LookVector)
    local armRotation=worldBasis.Rotation*localBasis.Rotation:Inverse()
    local orientation=m.Part0.CFrame.Rotation:Inverse()*armRotation*m.C1.Rotation
    local localPose=CFrame.new(data.base.Position)*orientation.Rotation
    data.smoothed=(data.smoothed or localPose):Lerp(localPose,1-math.exp(-22*dt))
   end
  end
 end
end
function Pose:Palms()
 local palms={}
 for side,data in pairs(self.motors)do
  local m=data.joint
  if data.smoothed and m.Part0 and m.Part1 then
   local arm=m.Part0.CFrame*(data.applied or data.smoothed)*m.C1:Inverse()
   palms[side]=arm:PointToWorldSpace(Vector3.new(0,-m.Part1.Size.Y*.43,0))
  end
 end
 for side,c in pairs(self.chains)do
  if c.palmLocal then palms[side]=self.torso.CFrame:PointToWorldSpace(c.palmLocal) end
 end
 return palms
end
function Pose:Destroy()
 if self.beforeAnimation then self.beforeAnimation:Disconnect()end
 if self.beforeSimulation then self.beforeSimulation:Disconnect()end
 if self.character then self.character:SetAttribute("LocalNotebookPose",nil);self.character:SetAttribute("LocalNotebookWeight",nil) end
 for _,data in pairs(self.motors)do
  if data.joint.Parent and data.animationBase then data.joint.Transform=data.animationBase end
 end
 for _,c in pairs(self.chains)do
  if c.animS and c.shoulder.Parent then c.shoulder.Transform=c.animS end
  if c.animE and c.elbow.Parent then c.elbow.Transform=c.animE end
 end
end
return Pose
