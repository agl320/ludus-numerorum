-- THE CRYPT (graveyard mausoleum): stand in the red circle for a few seconds to hold a SÉANCE: every other living
-- fighter is outlined through walls for you for SEANCE seconds (and each of them is told the dead are watching).
-- Risky on purpose: while anyone is channelling, a red beam rises out of the mausoleum roof that the whole map can
-- see, the crypt has one way in, and each player can only use it once every COOLDOWN seconds.
local Players=game:GetService("Players")
local crypt=workspace:WaitForChild("SunsetCity"):WaitForChild("Graveyard"):WaitForChild("Mausoleum"):WaitForChild("Crypt")
local pad=crypt:WaitForChild("CryptPad")
local beacon=crypt:WaitForChild("CryptBeacon")
local light=pad:FindFirstChild("PadLight")
local shared=game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local notice=shared:WaitForChild("Notice")
-- the beam wears the closing zone's colour
pcall(function() beacon.Color=require(shared:WaitForChild("ZoneRules")).Color end)
local CHANNEL=3.5
local COOLDOWN=30
local SEANCE=20
local function seance(caller,server)
 local ids={}
 for _,other in ipairs(Players:GetPlayers())do
  local c=other.Character
  local h=c and c:FindFirstChildOfClass("Humanoid")
  if other~=caller and other:GetAttribute("InArena")==true and h and h.Health>0 then
   table.insert(ids,other.UserId)
   notice:FireClient(other,"Seen",{Until=server+SEANCE})
  end
 end
 notice:FireClient(caller,"Seance",{Ids=ids,Until=server+SEANCE})
end
local RADIUS=pad:GetAttribute("Radius")or 3.1
local progress={}
Players.PlayerRemoving:Connect(function(p)progress[p]=nil end)
local last=os.clock()
while true do
 task.wait(.1)
 local now=os.clock();local dt=now-last;last=now
 local server=workspace:GetServerTimeNow()
 local anyone=0
 for _,player in ipairs(Players:GetPlayers())do
  local char=player.Character
  local root=char and char:FindFirstChild("HumanoidRootPart")
  local hum=char and char:FindFirstChildOfClass("Humanoid")
  local inside=false
  -- only fighters in a live round can call the dead
  if root and hum and hum.Health>0 and player:GetAttribute("InArena")==true and shared:GetAttribute("Phase")=="Playing" and not char:GetAttribute("Ragdolled")then
   local d=root.Position-pad.Position
   inside=Vector2.new(d.X,d.Z).Magnitude<=RADIUS and d.Y>-1 and d.Y<6
  end
  if inside then
   local readyAt=player:GetAttribute("CryptReadyAt")or 0
   if server<readyAt then
    progress[player]=0
    player:SetAttribute("CryptProgress",-1)
   else
    progress[player]=(progress[player]or 0)+dt
    anyone=math.max(anyone,progress[player]/CHANNEL)
    player:SetAttribute("CryptProgress",math.clamp(progress[player]/CHANNEL,0,1))
    if progress[player]>=CHANNEL then
     progress[player]=0
     player:SetAttribute("CryptReadyAt",server+COOLDOWN)
     seance(player,server)
     player:SetAttribute("CryptProgress",nil)
    end
   end
  elseif progress[player]or player:GetAttribute("CryptProgress")~=nil then
   progress[player]=nil
   player:SetAttribute("CryptProgress",nil)
  end
 end
 -- beacon + circle react to the channel
 local target=anyone>0 and .25+.35*(1-anyone)or 1
 beacon.Transparency+=(target-beacon.Transparency)*.35
 pad.Transparency=anyone>0 and .05 or .35
 if light then light.Brightness=1.2+anyone*4;light.Range=16+anyone*10 end
end
