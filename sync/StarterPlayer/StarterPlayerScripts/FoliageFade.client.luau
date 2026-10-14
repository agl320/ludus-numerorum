-- Leaf cards (tag "Foliage", built by ServerStorage.TreeBuilder) thin out when they would get in the way:
--   * the closer a card is to the camera, the more see-through it gets
--   * cards between the camera and your character (third person, killcam, spectating) almost vanish
-- Uses the decals' LocalTransparencyModifier, so it's per player and never replicates.
local CollectionService=game:GetService("CollectionService")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer

local NEAR,FAR=5,22          -- full fade at NEAR studs from the camera, none past FAR
local MAX_FADE=.78
local RANGE=48               -- only trees this close to the camera are checked
local TICK=1/15

local trees={}               -- model -> {centre=Vector3, cards={part}, faded=bool}
local function add(card)
 if not card:IsA("BasePart")then return end
 local m=card.Parent
 if not m then return end
 local t=trees[m]
 if not t then t={cards={},faded=false};trees[m]=t end
 local decals={}
 for _,d in ipairs(card:GetChildren())do if d:IsA("Decal")then table.insert(decals,d)end end
 table.insert(t.cards,{part=card,decals=decals,fade=0})
 local sum=Vector3.zero;for _,c in ipairs(t.cards)do sum+=c.part.Position end
 t.centre=sum/#t.cards
end
for _,c in ipairs(CollectionService:GetTagged("Foliage"))do add(c)end
CollectionService:GetInstanceAddedSignal("Foliage"):Connect(add)

-- distance from point p to the segment a-b
local function segDist(p,a,b)
 local ab=b-a;local len=ab:Dot(ab)
 if len<1e-4 then return(p-a).Magnitude end
 local t=math.clamp((p-a):Dot(ab)/len,0,1)
 return(p-(a+ab*t)).Magnitude
end

local acc=0
RunService.Heartbeat:Connect(function(dt)
 acc+=dt;if acc<TICK then return end;acc=0
 local cam=workspace.CurrentCamera;if not cam then return end
 local eye=cam.CFrame.Position
 local char=player.Character
 local subject=cam.CameraSubject
 local focus=(subject and subject:IsA("Humanoid")and subject.Parent and subject.Parent:FindFirstChild("Head"))or(char and char:FindFirstChild("Head"))
 local target=focus and focus.Position
 local thirdPerson=target and(target-eye).Magnitude>3
 for m,t in pairs(trees)do
  if not m.Parent then trees[m]=nil
  elseif(t.centre-eye).Magnitude<RANGE+12 then
   t.faded=true
   for _,c in ipairs(t.cards)do
    local part=c.part
    if #c.decals==0 then for _,d in ipairs(part:GetChildren())do if d:IsA("Decal")then table.insert(c.decals,d)end end end
    if part.Parent then
     local d=(part.Position-eye).Magnitude
     local fade=math.clamp(1-(d-NEAR)/(FAR-NEAR),0,1)*MAX_FADE
     if thirdPerson and segDist(part.Position,eye,target)<part.Size.X*.5+1.5 then fade=math.max(fade,.88)end
     if math.abs(c.fade-fade)>.02 then
      c.fade=fade
      for _,dc in ipairs(c.decals)do dc.LocalTransparencyModifier=fade end
     end
    end
   end
  elseif t.faded then
   t.faded=false
   for _,c in ipairs(t.cards)do c.fade=0;for _,dc in ipairs(c.decals)do if dc.Parent then dc.LocalTransparencyModifier=0 end end end
  end
 end
end)
