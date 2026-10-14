local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local WorldPose=require(script.Parent:WaitForChild("NotebookWorldPose"))
local Gait=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Gait"))
local Controller={}
Controller.__index=Controller
local armNames={LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,["Left Arm"]=true,["Right Arm"]=true}
-- Your own head, LED visor and hats are hidden from your first-person camera. The visor is a Model with glowing
-- digit screens (SurfaceGuis), which the stock camera never hides, so it used to poke into view when the
-- sprint lean tipped the head forward.
local headNames={Head=true,LEDVisor=true,NumberForehead=true}
function Controller.new(players,player,input,remote,stateClass,modelClass)
    local self=setmetatable({players=players,player=player,input=input,remote=remote,State=stateClass,Model=modelClass,
        rigs={},localState=stateClass.new(),lastSent="",activity=0},Controller)
    Run:BindToRenderStep("NumberfallNotebook",Enum.RenderPriority.Camera.Value+2,function(dt) self:Render(dt) end)
    -- load the notebook meshes/textures and the number entry panel up front so the first E doesn't hitch
    task.spawn(function()
        local list={}
        local assets=game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):FindFirstChild("NotebookAssets")
        if assets then table.insert(list,assets) end
        local gui=player:WaitForChild("PlayerGui"):WaitForChild("MARKED_UI_EDITABLE",20)
        local entry=gui and gui:FindFirstChild("Entry")
        if entry then table.insert(list,entry) end
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
    end)
    players.PlayerRemoving:Connect(function(p) self:Forget(p) end)
    return self
end
local function approach(a,b,k,dt) return b+(a-b)*math.exp(-k*dt) end
local function smooth(t) t=math.clamp(t,0,1) return t*t*(3-2*t) end
local function smoother(t) t=math.clamp(t,0,1) return t*t*t*(t*(t*6-15)+10) end
local function lerp(a,b,t) return a+(b-a)*t end

-- ---- inspecting your gear (Y, gamepad D-pad left, the touch LOOK button) ----
-- Typing gear plays a keyframed look; the notebook is put away and the pen is spun round the fingers until you stop.
-- Keyframes {time, turn, tilt, lift, toward you, sideways, roll, let go}, in the gear's own space (third person:
-- lift = up the body and toward you = out in front of it), eased between. "let go" (0..1) is how far the hands are
-- off it: they let go for the keyboard's toss and while the typewriter turns on its own.
local TAU=math.pi*2
local INSPECT_TRACKS={
    -- the keyboard: a dip, tossed up with a full flip, caught, then turned to show it off
    Keyboard={{0,0,0,0,0,0,0,0},{.35,0,-.3,.1,.12,0,0,0},{.62,0,-.25,.02,.12,0,0,0},{1.12,0,-.25-TAU,.65,.06,0,0,1},
        {1.42,0,-.3-TAU,.08,.12,0,0,0},{1.95,.65,-.4-TAU,.12,.14,0,.1,0},{2.45,-.55,-.35-TAU,.12,.14,0,-.1,0},{2.9,0,-TAU,0,0,0,0,0}},
    -- the typewriter: lifted, let go, it turns a full circle on its own, caught and tipped up to show the keys
    Typewriter={{0,0,0,0,0,0,0,0},{.4,0,-.2,.1,.1,0,0,0},{.65,0,-.18,.2,-.3,0,0,.85},{1.75,TAU,-.18,.28,-.3,0,0,.85},
        {2.05,TAU,-.3,.12,.14,0,0,0},{2.45,TAU+.35,-.35,.12,.16,0,.06,0},{2.9,TAU,0,0,0,0,0,0}},
    -- (third person: held up to eye level and tossed / turned above the head, where the camera behind you can see
    -- it; at the chest your own body and arms hide it)
    KeyboardHeld={{0,0,0,0,0,0,0,0},{.35,0,-.1,1.75,.35,0,0,0},{.62,0,-.08,1.6,.35,0,0,0},{1.12,0,-.08-TAU,3.1,.45,0,0,1},
        {1.42,0,-.1-TAU,1.75,.35,0,0,0},{1.95,.7,-.1-TAU,1.85,.38,0,.1,0},{2.45,-.6,-.08-TAU,1.85,.38,0,-.1,0},{2.9,0,-TAU,0,0,0,0,0}},
    TypewriterHeld={{0,0,0,0,0,0,0,0},{.4,0,-.1,1.55,.38,0,0,0},{.65,0,-.1,1.8,.4,0,0,.8},{1.75,TAU,-.1,2.0,.4,0,0,.8},
        {2.05,TAU,-.12,1.55,.38,0,0,0},{2.45,TAU+.35,-.15,1.6,.4,0,.06,0},{2.9,TAU,0,0,0,0,0,0}},
}
Controller.INSPECT_TIME=3
local function inspectTrack(name,t)
    local k=INSPECT_TRACKS[name]
    if not k or not t or t<=0 or t>=k[#k][1] then return nil end
    for i=1,#k-1 do
        local a,b=k[i],k[i+1]
        if t<=b[1] then
            local u=smooth((t-a[1])/(b[1]-a[1]))
            local r={}
            for j=2,8 do r[j]=a[j]+(b[j]-a[j])*u end
            return r
        end
    end
end
local function wrap(a) return math.atan2(math.sin(a),math.cos(a)) end
-- the held frame moved by inspect values r (nil = untouched), turning about the gear's middle; also how far the
-- hands have let go of it
function Controller:InspectFrame(model,frame,r)
    if not r then return frame,0 end
    local pivot=Vector3.zero
    if model.device and model.devBounds then pivot=(model.devBounds[1]+model.devBounds[2])/2 end
    local f=frame*CFrame.new(r[6],r[4],-r[5])*CFrame.new(pivot)*CFrame.Angles(r[3],0,0)*CFrame.Angles(0,r[2],0)*CFrame.Angles(0,0,r[7])*CFrame.new(-pivot)
    return f,math.clamp(r[8] or 0,0,1)
end
-- Y: typing gear plays its look; the notebook starts the pen spin, and Y again stops it
function Controller:Inspect()
    local char=self.player.Character
    if not char then return end
    local device=self.player:GetAttribute("NotebookFinish")
    local rig=self.rigs[self.player]
    device=rig and rig.model.device or (device=="Typewriter" or device=="Keyboard") and device or nil
    if not device then
        if self.spinning then self:StopSpin() return end
        self.spinning=true;self.inspectKind="spin"
    else
        if self.inspectAt and os.clock()-self.inspectAt<self.INSPECT_TIME then return end
        self.inspectAt=os.clock();self.inspectFade=nil;self.inspectKind=device
    end
    -- (others see it too: the server stamps InspectAt on your character, and clears it when a pen spin stops)
    self.remote:FireServer(char,self.input.buffer,true,self.input.status=="Written",true)
end
function Controller:StopSpin()
    if not self.spinning then return end
    self.spinning=false
    local char=self.player.Character
    if char then self.remote:FireServer(char,self.input.buffer,self:Typing(workspace:GetServerTimeNow()),self.input.status=="Written",false) end
end
-- typing, opening the number panel (or any menu) stops an inspect: what's left of a turn eases back instead of
-- snapping, and a pen spin is put away
function Controller:CancelInspect()
    if self.inspectAt and self.inspectLast then
        local r={}
        for j=2,8 do r[j]=self.inspectLast[j] end
        r[2],r[3],r[7]=wrap(r[2]),wrap(r[3]),wrap(r[7]) -- (a whole turn eases back the short way, not round again)
        self.inspectFade={r=r,at=os.clock()}
    end
    self.inspectAt=nil
    self:StopSpin()
end
function Controller:Inspecting()
    return self.spinning==true or (self.inspectAt~=nil and os.clock()-self.inspectAt<self.INSPECT_TIME) or self.inspectFade~=nil
end
function Controller:InspectValues(name)
    if self.inspectAt then
        local r=inspectTrack(name,os.clock()-self.inspectAt)
        if r then self.inspectLast=r;return r end
        if os.clock()-self.inspectAt>=self.INSPECT_TIME then self.inspectAt=nil;self.inspectLast=nil end
    end
    if self.inspectFade then
        local u=(os.clock()-self.inspectFade.at)/.25
        if u<1 then
            local k,r=1-smooth(u),{}
            for j=2,8 do r[j]=self.inspectFade.r[j]*k end
            return r
        end
        self.inspectFade=nil
    end
end
-- the pen spin: where it turns (a frame whose XZ plane the pen spins in, flat over the fingers: a thumbaround,
-- turning sideways round its middle) and the pen's own frame at time t
local function penSpinFrame(S,t,len)
    -- about two turns a second, surging and easing like a real thumbaround, with a slight wobble of the plane
    local a=t*12.5+math.sin(t*2.3)*1.8
    local wob=CFrame.Angles(math.sin(t*3.1)*.08,0,math.cos(t*2.7)*.08)
    return S*wob*CFrame.Angles(0,a,0)*CFrame.Angles(math.pi/2,0,0)*CFrame.new(0,-len*.5,0)
end
local function penLength(model)
    local p=model.pencil
    return p and math.max(p.Size.X,p.Size.Y,p.Size.Z) or 1
end

-- The notebook comes out only while you use it: number entry open (E), digits typed, or a moment after the
-- last digit so the result (accepted / crossed out) can be seen.
function Controller:Typing(now)
    if self:Inspecting() then return true end
    if self.input.buffer~="" then self.lastTypedAt=now;return true end
    if self.hud and self.hud.active=="Entry" then return true end
    return now-(self.lastTypedAt or -math.huge)<1.1
end

-- Shared first-person motion state plus the notebook's camera-space offset. Everything here is smooth:
-- no noise, no jitter. Walk/sprint bob follows the same stride as the body's gait.
function Controller:ViewmodelMotion(rig,char,h,root,camera,dt,now)
    local vm=rig.vm
    if not vm then
        vm={phase=0,pos=Vector3.zero,rot=Vector3.zero,kick=Vector3.zero,wasAir=false,lastVy=0,born=os.clock(),
            stance=self:Typing(now) and 1 or 0,sprint=0,run=0,air=0,slide=0,throw=0}
        rig.vm=vm
    end
    local reduced=self.player:GetAttribute("LocalReducedMotion")
    local scale=reduced and .35 or 1
    local v=root.AssemblyLinearVelocity
    local flat=Vector3.new(v.X,0,v.Z);local speed=flat.Magnitude
    local localVel=camera.CFrame:VectorToObjectSpace(flat)
    local grounded=h.FloorMaterial~=Enum.Material.Air
    local sliding=(char:GetAttribute("SlideUntil")or 0)>now
    -- stride shared with the body animation
    local sprintTarget=math.max(char:GetAttribute("Sprinting")==true and math.clamp((speed-20)/6,0,1) or 0,math.clamp((speed-30)/8,0,1))
    vm.sprint=approach(vm.sprint,sprintTarget,6,dt)
    local moving=grounded and not sliding and speed>1
    if moving then vm.phase=(vm.phase+dt*Gait.Cadence(Gait.Params(vm.sprint),speed))%1 end
    Gait.LocalPhase=vm.phase -- the camera bob (FeelController) steps on the same stride as the arms
    vm.run=approach(vm.run,moving and math.clamp(speed/16,0,1) or 0,10,dt)
    vm.air=approach(vm.air,(not grounded and not sliding) and 1 or 0,9,dt)
    vm.slide=approach(vm.slide,sliding and 1 or 0,14,dt)
    -- notebook bob: a soft dip on each step, calmer while sprinting so the page stays readable
    local th=vm.phase*math.pi*2
    local bob=Vector3.new(math.sin(th)*.03,-math.abs(math.cos(th))*.035,0)*vm.run*(1-.5*vm.sprint)
    local tPos,tRot=bob,Vector3.zero
    tPos+=Vector3.new(.08,-.1,.08)*vm.sprint*vm.run;tRot+=Vector3.new(-.14,.1,.14)*vm.sprint*vm.run
    tPos+=Vector3.new(.06,-.2,.06)*vm.slide;tRot+=Vector3.new(.06,0,.3)*vm.slide
    if not grounded then
        tPos+=Vector3.new(0,math.clamp(-v.Y*.003,-.1,.1),0)
        tRot+=Vector3.new(math.clamp(v.Y*.0035,-.1,.1),0,0)
    end
    tRot+=Vector3.new(0,0,math.clamp(-localVel.X*.004,-.12,.12))
    vm.pos=vm.pos:Lerp(tPos,1-math.exp(-10*dt));vm.rot=vm.rot:Lerp(tRot,1-math.exp(-9*dt))
    -- landing dip and slide entry dip (single smooth pulses)
    if grounded and vm.wasAir and vm.lastVy<-22 then vm.kick=Vector3.new(0,-math.clamp(-vm.lastVy/190,0,.3),.04) end
    if sliding and not vm.wasSliding then vm.kick=Vector3.new(0,-.1,.06) end
    vm.wasSliding=sliding
    vm.wasAir=not grounded;if not grounded then vm.lastVy=v.Y end
    vm.kick=vm.kick:Lerp(Vector3.zero,1-math.exp(-8*dt))
    -- double jump: the notebook turns, empty arms throw up
    local airJump=char:GetAttribute("AirJumpAt")
    if airJump and airJump~=vm.airJumpSeen then vm.airJumpSeen=airJump;if now-airJump<.5 and not(vm.spinAt and os.clock()-vm.spinAt<.4)then vm.spinAt=os.clock()end end
    local spin=0
    vm.throw=0
    -- double jump: a full arm move over .8s (load -> throw up -> tuck for the flip -> let go), see FreeArms
    vm.djT=nil
    if vm.spinAt then
        local t=(os.clock()-vm.spinAt)/.6
        if t>=1 then vm.spinAt=nil else
            vm.djT=t
            vm.throw=t<.1 and smooth(t/.1) or (t>.62 and 1-smooth((t-.62)/.38) or 1)
            spin=math.sin(math.pi*math.min(1,t/.7))*.5
        end
    end
    -- kill thrust (the server marks the attacker)
    local strike=char:GetAttribute("StrikeAt")
    if strike and strike~=vm.strikeSeen then vm.strikeSeen=strike;if now-strike<.6 then vm.strikeAt=os.clock()end end
    local thrust,thrustPitch=0,0
    if vm.strikeAt then local t=(os.clock()-vm.strikeAt)/.36;if t>=1 then vm.strikeAt=nil else local e=math.sin(math.pi*t);thrust=-.4*e;thrustPitch=-.45*e end end
    -- miss: one short side-to-side wobble of the book
    if self.input.status=="Miss" and vm.lastStatus~="Miss" then vm.shakeAt=os.clock()end
    vm.lastStatus=self.input.status
    local shake=0
    if vm.shakeAt then local t=(os.clock()-vm.shakeAt)/.38;if t>=1 then vm.shakeAt=nil else shake=math.sin(t*math.pi*3)*.05*(1-t)end end
    -- raise into view on spawn
    local raise=math.clamp((os.clock()-vm.born)/.4,0,1);raise=1-(1-raise)^3
    vm.raise=raise;vm.scale=scale
    local pos=(vm.pos+vm.kick)*scale+Vector3.new(shake,-(1-raise)*1.1+vm.throw*.12*scale,thrust)
    local rot=vm.rot*scale+Vector3.new(thrustPitch-(1-raise)*.5,0,spin*scale)
    return vm,CFrame.new(pos)*CFrame.Angles(rot.X,rot.Y,rot.Z)
end

-- Empty-handed arms (notebook put away): they swing with the body's stride, so fists pump into the bottom of the
-- screen when sprinting and peek in on a walk; one hand reaches out front for balance in a slide; both lift in
-- the air and throw up on a double jump. Returns camera-space hand targets.
function Controller:FreeArms(vm,amount)
    amount=amount or 1
    local th=vm.phase*math.pi*2
    local s=math.sin(th)
    local g=vm.sprint
    local hands={}
    for _,side in ipairs({"Left","Right"}) do
        local sx=side=="Right" and 1 or -1
        local forward=side=="Right" and -s or s -- each arm swings forward with the opposite leg
        local u=smooth((forward+1)/2)
        local front=Vector3.new(sx*lerp(.6,.48,g),lerp(-.8,-.5,g),lerp(-1.2,-1.42,g))
        local back=Vector3.new(sx*.95,-2.3,.1)
        local rest=Vector3.new(sx*.9,-2.2,-.5)
        local arc=math.sin(math.pi*u)
        local swing=back:Lerp(front,u)+Vector3.new(0,.1*arc,-.08*arc)
        swing=back:Lerp(front,.5):Lerp(swing,amount)
        local hand=rest:Lerp(swing,vm.run)
        hand=hand:Lerp(Vector3.new(sx*.85,-1.1,-1.1),vm.air*.8)
        local slideHand=side=="Right" and Vector3.new(.78,-.9,-1.55) or Vector3.new(-1.2,-2.3,.4)
        hand=hand:Lerp(slideHand,vm.slide)
        -- double jump: like a real jump, both arms swing up to drive it (rising into the bottom of the view, a little
        -- inward), then sweep down and back out of view before settling into the air pose. The left arm trails
        -- the right by a few frames so it doesn't look mirrored.
        if vm.djT and vm.throw>0 then
            local dt=math.clamp(vm.djT-(sx<0 and .06 or 0),0,1)
            local keys={
                {0,   Vector3.new(sx*.82,-1.45,-.85)},
                {.3,  Vector3.new(sx*.56,-.66+(sx>0 and .04 or 0),-1.3)},
                {.62, Vector3.new(sx*.86,-1.95,-.55)},
                {1,   Vector3.new(sx*.85,-1.2,-1.05)},
            }
            local jumpPose=keys[#keys][2]
            for i=1,#keys-1 do
                local a,b=keys[i],keys[i+1]
                if dt<=b[1] then
                    local u=(dt-a[1])/(b[1]-a[1])
                    -- quick out of the start, soft at the peak
                    u=i==1 and 1-(1-u)^2.2 or smooth(u)
                    jumpPose=a[2]:Lerp(b[2],u);break
                end
            end
            hand=hand:Lerp(jumpPose,vm.throw)
        end
        hand+=vm.kick*.6
        hand=Vector3.new(0,-(1-(vm.raise or 1))*1.1,0)+hand
        hands[side]=hand
    end
    return hands
end

function Controller:HideHead(rig,char)
    rig.headParts=rig.headParts or {}
    if not rig.headScan or os.clock()-rig.headScan>.5 then
        rig.headScan=os.clock()
        for _,child in ipairs(char:GetChildren()) do
            if headNames[child.Name] or child:IsA("Accessory") then
                local list=child:GetDescendants();table.insert(list,child)
                for _,d in ipairs(list) do
                    if rig.headParts[d]==nil then
                        if d:IsA("BasePart") then rig.headParts[d]=d.LocalTransparencyModifier
                        elseif d:IsA("Decal") then
                            local ok,value=pcall(function() return d.LocalTransparencyModifier end)
                            if ok then rig.headParts[d]=value end
                        elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") then rig.headParts[d]=d.Enabled end
                    end
                end
            end
        end
    end
    for d,original in pairs(rig.headParts) do
        if d.Parent then
            if type(original)=="boolean" then d.Enabled=false else d.LocalTransparencyModifier=1 end
        end
    end
end
function Controller:Forget(player)
    local rig=self.rigs[player]
    if not rig then return end
    rig.model:Destroy()
    if rig.pose then rig.pose:Destroy()end
    for part,value in pairs(rig.hidden) do
        if part.Parent then part.LocalTransparencyModifier=player==self.player and 0 or value end
    end
    for d,original in pairs(rig.headParts or {}) do
        if d.Parent then
            if type(original)=="boolean" then d.Enabled=original else d.LocalTransparencyModifier=0 end
        end
    end
    self.rigs[player]=nil
end
-- a clean page: the lines already written are dropped (only a number still being typed carries over), and the
-- typed buffer is kept so nothing finished gets written out again
function Controller:FreshPage(old)
    local st=self.State.new();st.buffer=old.buffer;st.status=old.status
    local last=old.rows[#old.rows]
    if last and not last.closed and old.buffer~="" then st.rows={last} end -- (an erased-to-empty line isn't carried over)
    return st
end
function Controller:Reset()
    self.spinning=false;self.inspectAt=nil;self.inspectFade=nil -- (a pen spin / look doesn't carry over a respawn)
    self.localState=self.State.new();self.lastSent="";self.lastOut=nil;self.localCharacter=self.player.Character
    self:Forget(self.player)
end
function Controller:Sync()
    local now=workspace:GetServerTimeNow()
    if self.localState:Update(self.input.buffer,self.input.status) then self.activity=now end
    -- the notebook being out (E pressed, or typing) is sent too, so others see it in third person straight away
    local out=self:Typing(now)==true
    -- (a line finished on the lobby scratch pad is sent too, so others see it written down rather than erased)
    local written=self.input.status=="Written"
    if (self.lastSent~=self.input.buffer or self.lastOut~=out or self.lastWritten~=written) and now>=(self.sendAt or 0) then
        self.sendAt=now+0.05
        self.lastSent=self.input.buffer;self.lastOut=out;self.lastWritten=written
        self.remote:FireServer(self.player.Character,self.input.buffer,out,written)
    end
end
local BotProxy = require(script.Parent:WaitForChild("BotProxy")) -- (tutorial bots write like players)
function Controller:Render(dt)
    dt=math.min(dt or 1/60,.05)
    local camera=workspace.CurrentCamera
    if not camera then return end
    local now=workspace:GetServerTimeNow()
    local seen={}
    -- a menu opening puts a pen spin away (number entry, Help and a held players list don't)
    local hud=self.hud
    if self.spinning and hud and hud.open and hud.active and hud.active~="Entry" and hud.active~="Help" and not hud.peek then self:StopSpin() end
    for _,player in ipairs(BotProxy.List(self.players)) do
        seen[player]=true
        local char=player.Character
        local h=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local head=char and char:FindFirstChild("Head")
        local rig=self.rigs[player]
        local alive=player:GetAttribute("InMatch") and h and root and head and h.Health>0
        -- a body that's been taken out of the world (cleared away, parked) keeps its last position: no notebook
        -- hanging there on its own
        alive=alive and char:IsDescendantOf(workspace)
        local localPlayer=player==self.player
        local firstPerson=alive and localPlayer and (camera.CFrame.Position-(root.Position+Vector3.new(0,1.5,0))).Magnitude<4
        if rig and (rig.char~=char or not alive or rig.firstPerson~=firstPerson) then self:Forget(player);rig=nil end
        if alive then
            if not rig then
                rig={char=char,firstPerson=firstPerson,model=self.Model.new(firstPerson and camera or workspace,firstPerson,char),state=self.State.new(),hidden={},activity=-math.huge,sway=Vector2.new(),held=0}
                if not firstPerson then rig.model:SetNotebookVisible(false) end
                self.rigs[player]=rig
            end
            if firstPerson and rig.model.model.Parent~=camera then rig.model.model.Parent=camera end
            local state=localPlayer and self.localState or rig.state
            local otherBuffer=""
            if not localPlayer then
                local status,buffer=(char:GetAttribute("NoteSnapshot") or "Ready|"):match("^(%a+)|(%d*)$")
                otherBuffer=buffer or ""
                if state:Update(buffer or "",status or "Ready") then rig.activity=now end
            end
            local finish=player:GetAttribute("NotebookFinish") or "Classic"
            local gcw=player:GetAttribute("GearColor")
            -- equipping other gear starts it on a clean page: the numbers written on the last one don't follow it
            -- (tracked apart from the rig, which is rebuilt when you switch first / third person)
            if localPlayer then
                if self.pageFinish and self.pageFinish~=finish then self.localState=self:FreshPage(self.localState);state=self.localState end
                self.pageFinish=finish
            else
                if rig.pageFinish and rig.pageFinish~=finish then rig.state=self:FreshPage(rig.state);state=rig.state end
                rig.pageFinish=finish
            end
            if rig.finish~=finish or rig.gcw~=gcw then rig.finish=finish;rig.gcw=gcw;rig.model:Finish(finish,gcw)end
            rig.model:Paint(state,now,localPlayer and self.activity or rig.activity)
            -- Only living arms are replaced; death/respawn restores the avatar.
            for _,part in ipairs(char:GetChildren()) do
                if firstPerson and armNames[part.Name] and part:IsA("BasePart") then
                    if rig.hidden[part]==nil then rig.hidden[part]=part.LocalTransparencyModifier end
                    part.LocalTransparencyModifier=1
                end
            end
            if firstPerson then
                -- head, visor and accessories are hidden by the OwnHead script (right after the camera moves)
                local vm,motion=self:ViewmodelMotion(rig,char,h,root,camera,dt,now)
                local typing=self:Typing(now)
                -- taking the book out / putting it away: the stance moves at a steady pace and is eased at both ends,
                -- so the hands travel in one continuous arc instead of snapping
                vm.stance=math.clamp(vm.stance+(typing and 1 or -1)*dt/(typing and .36 or .42),0,1)
                local k=smoother(vm.stance)
                local hide=1-k
                local wide=math.clamp(camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y),0.55,2)
                local distance=1/math.min(1,wide)
                local mouse=UIS:GetMouseDelta();local reduced=self.player:GetAttribute("LocalReducedMotion")
                local target=reduced and Vector2.new()or Vector2.new(math.clamp(mouse.X,-25,25),math.clamp(mouse.Y,-25,25))*.0015
                rig.sway=rig.sway:Lerp(target,1-math.exp(-12*dt))
                local view=camera.CFrame*motion
                -- the book drops out of view and tips away when it is put away
                -- the book sinks straight down and tips back a little as it is put away (no swing around the camera)
                -- (no on-screen warm-up: assets and the handwriting font are preloaded in the background instead)
                local warm=false
                local place=warm and 0 or hide
                -- putting it away: the book swings down and left to the hip (the same hip it hangs from in third
                -- person), turning edge-on and pulling in to the body, instead of dropping straight down
                -- the pen spin puts the book away the same way (the pen stays in the right hand)
                rig.spinW=(self.spinning and not rig.model.device) and approach(rig.spinW or 0,1,7,dt) or 0
                local spinW=smooth(rig.spinW)
                if not rig.model.device then place=math.max(place,spinW) end
                local side=smooth(math.clamp(place*1.25,0,1))   -- sideways first...
                local down=place*place                           -- ...then down, faster at the end
                local frame=view*CFrame.new(.02-rig.sway.X-side*.95,(-.95-rig.sway.Y)*distance-down*1.9-side*.2,-2.05*distance+side*.9)
                    *CFrame.Angles(-.12-side*.25,math.pi-side*1.15,-.06-side*.9)
                -- typing gear (typewriter / keyboard) is held a little higher and tipped toward you, so the keys show
                local fp=rig.model.device and rig.model.devFP



                if fp then
                    -- (it comes over your right shoulder from your back, and goes back there: up, over and behind you)
                    local up=smooth(math.clamp(place,0,1))
                    -- (arc: halfway it swings out wide past your right shoulder, so it never passes through the camera)
                    local arc=math.sin(math.pi*up)
                    frame=view*CFrame.new(.02-rig.sway.X+up*.5+arc*1.05,(-.95-rig.sway.Y)*distance+up*1.7+arc*.25,-2.05*distance+up*2.6)
                        *CFrame.Angles(-.12+up*.8,math.pi,-.06-up*.3)
                    frame=frame*CFrame.new(0,fp[1],fp[2])*CFrame.Angles(fp[3],0,0)
                    rig.model:SetBackStowed(false)
                end
                -- inspecting (Y): typing gear plays its look (the hands let go for a toss / a turn)
                local letGo=0
                if rig.model.device then frame,letGo=self:InspectFrame(rig.model,frame,self:InspectValues(rig.model.device)) end
                local shoulders={Left=view:PointToWorldSpace(Vector3.new(-.95,-1.45,.05)),Right=view:PointToWorldSpace(Vector3.new(.95,-1.45,.05))}
                rig.model:SetNotebookVisible(k>.04 or warm,warm and k<=.04)
                if not rig.fontWarmed then
                    rig.fontWarmed=true
                    task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({rig.model.model}) end) end)
                end
                local grips=rig.model:Pose(frame,shoulders,now,self.activity,state,char)
                -- the pen spin: the right hand comes up in front of you and the pen turns round the fingers
                local spinHand
                if spinW>.001 then
                    local armV=camera.CFrame*CFrame.new(-rig.sway.X*.6,-rig.sway.Y*.6,0)
                    local bob=math.sin(os.clock()*2)*.02
                    -- (the spin plane tips toward you, like the back of a hand you're looking down at)
                    local S=armV*CFrame.new(.34,-.3+bob,-1.6)*CFrame.Angles(.55,.35,-.2)
                    local len=penLength(rig.model)
                    local spun=penSpinFrame(S,os.clock(),len)
                    -- (the pen leaves the book and is carried up to the hand as the spin starts)
                    rig.model.pencil.CFrame=rig.model.pencil.CFrame:Lerp(spun*rig.model.penOffset,spinW)
                    rig.model.pencil.LocalTransparencyModifier=0;rig.spunPen=true
                    -- (fingertips just under the turning pen)
                    spinHand=S:PointToWorldSpace(Vector3.new(0,-.2,0));rig.spinUp=S.UpVector
                    rig.model:SetBookHidden(spinW>.9)
                else
                    rig.model:SetBookHidden(false)
                    -- (stopped: the pen goes straight back with the book, as hidden or shown as it is)
                    if rig.spunPen then rig.spunPen=nil;rig.model.pencil.LocalTransparencyModifier=rig.model.notebookValue or 0 end
                end
                -- Arms always go through one solver: blend book grip -> free arm for position, elbow direction and
                -- hand facing together. Hands let go of the book a beat before it is fully away (and grab it a beat
                -- after it starts rising), so they never get dragged down with it.
                -- the hands carry the book most of the way to the hip, then let go
                local release=smoother(math.clamp((hide-.5)/.5,0,1))
                local armView=camera.CFrame*CFrame.new(-rig.sway.X*.6,-rig.sway.Y*.6,0)
                -- while the book is being taken out or put away the arms hold a calm mid pose; the running swing only
                -- builds up once the hands are free (so sprinting + E doesn't fling the arms around)
                local free=self:FreeArms(vm,release*release)
                local penDir=rig.model.penDirection or frame.UpVector
                local targets={}
                for side,cameraHand in pairs(free) do
                    -- (the hands let go of typing gear for its toss / turn; with the pen spin the left hand is free
                    -- and the right one holds the spinning pen up)
                    local release=math.max(release,letGo,(side=="Left" and spinW) or 0)
                    local sx=side=="Right" and 1 or -1
                    local freeShoulder=armView:PointToWorldSpace(Vector3.new(sx*.95,-1.45,.05))
                    local freeHand=armView:PointToWorldSpace(cameraHand)
                    local freeBend=armView:VectorToWorldSpace(Vector3.new(sx*.45,-.55,.7))
                    local bookBend=frame.RightVector*(side=="Left" and 1 or -1)-frame.UpVector*.8
                    local bend=bookBend.Unit:Lerp(freeBend.Unit,release)
                    targets[side]={shoulder=shoulders[side]:Lerp(freeShoulder,release),hand=grips[side]:Lerp(freeHand,release),
                        bend=bend.Magnitude>.05 and bend or freeBend,dir=penDir,dirBlend=release}
                    if side=="Right" and spinHand then
                        local t=targets.Right
                        t.hand=t.hand:Lerp(spinHand,spinW);t.shoulder=t.shoulder:Lerp(shoulders.Right,spinW)
                        t.bend=t.bend:Lerp(armView:VectorToWorldSpace(Vector3.new(.6,-.7,.3)),spinW)
                        t.dir=rig.spinUp or armView:VectorToWorldSpace(Vector3.new(-.25,.9,-.35));t.dirBlend=t.dirBlend*(1-spinW)
                    end
                end
                rig.model:PoseArms(targets,char)
            else
                -- third person / other players: the book is only held while that player is writing; otherwise the
                -- arms are released so they swing with the walk and sprint
                local writing
                if localPlayer then writing=self:Typing(now)
                else
                    if otherBuffer~="" then rig.lastTypedAt=now end
                    local out=char:GetAttribute("NotebookOut")
                    local at=char:GetAttribute("InspectAt")
                    local looking=at~=nil and (not rig.model.device or workspace:GetServerTimeNow()-at<self.INSPECT_TIME)
                    if out==nil then writing=otherBuffer~="" or looking or now-(rig.lastTypedAt or -math.huge)<1.1
                    else writing=out==true or otherBuffer~="" or looking end
                end
                rig.held=approach(rig.held or 0,writing and 1 or 0,writing and 12 or 6,dt)
                local held=smooth(rig.held)
                if held>.01 and not rig.pose then rig.pose=WorldPose.new(char) end
                if held<=.01 and rig.pose then rig.pose:Destroy();rig.pose=nil end
                -- holstered: the book hangs on the left hip (cover out, pen tucked away) and is pulled up into the
                -- hands when the player starts writing
                local torso=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or root
                -- only on a body you can see: an invisible / faded-out body leaves no floating book behind
                local bodyShown=torso~=root and torso.Transparency<.9 and torso.LocalTransparencyModifier<.9
                rig.model:SetNotebookVisible(bodyShown or held>.01)
                local hold=torso.CFrame*CFrame.new(.12,-.35,-(torso.Size.Z*.5+.9))*CFrame.Angles(.45,math.pi,-.04)
                if rig.model.device then
                    -- (typing gear is held up at the chest and further out, tipped toward the face like a tablet:
                    -- down at the waist it was lost under the hands and forearms)
                    hold=torso.CFrame*CFrame.new(.1,.35,-(torso.Size.Z*.5+1.4))*CFrame.Angles(.7,math.pi,-.04)
                end
                local hipPart=char:FindFirstChild("LowerTorso") or torso
                local hipCF=hipPart.CFrame
                local hipDrop=hipPart==torso and -.75 or -.05
                local swing=math.clamp(root.AssemblyLinearVelocity.Magnitude/28,0,1)*math.sin(now*9)*.06
                local hipPos=hipCF:PointToWorldSpace(Vector3.new(-(hipPart.Size.X*.5+.16),hipDrop-.35,.05))
                local hip=CFrame.fromMatrix(hipPos,-hipCF.LookVector,hipCF.UpVector)*CFrame.Angles(0,0,.1+swing)*CFrame.Angles(.06,0,0)
                local frame=hip:Lerp(hold,held)
                -- typing gear is carried on the back (NotebookModel:BackFrame) and swung up over the shoulder to the
                -- hands (the arc keeps it out of the body on the way round)
                local back=rig.model.device and rig.model:BackFrame(torso)
                if back then
                    -- (out to the side first, then up and over: it swings wide of the head and clear of the body)
                    local arc=math.sin(math.pi*held)
                    local u=smooth(math.clamp((held-.12)/.76,0,1))
                    frame=back:Lerp(hold,u)+torso.CFrame.UpVector*arc*1.0+torso.CFrame.RightVector*math.sqrt(arc)*2.05
                    rig.model:SetBackStowed(held<.35)
                end
                -- inspecting (yours, or others' from the server's InspectAt stamp): typing gear plays its look, raised
                -- up toward the face; the notebook goes back on the hip and the pen is spun in front of the chest
                local r,letGo,spinning=nil,0,false
                if localPlayer then
                    if rig.model.device then r=self:InspectValues(rig.model.device.."Held") end
                    spinning=self.spinning==true and not rig.model.device
                elseif otherBuffer=="" then
                    local at=char:GetAttribute("InspectAt")
                    if at and rig.model.device then
                        r=inspectTrack(rig.model.device.."Held",workspace:GetServerTimeNow()-at)
                        if r then rig.lastTypedAt=now end -- (keep it out in their hands for the whole look)
                    elseif at then spinning=true end
                end
                if r then
                    local turn={r[1],r[2],r[3],0,0,r[6],r[7],r[8]}
                    frame,letGo=self:InspectFrame(rig.model,frame,turn)
                    frame=frame+torso.CFrame.UpVector*r[4]+torso.CFrame.LookVector*r[5]
                end
                rig.spinW=spinning and approach(rig.spinW or 0,1,7,dt) or 0
                local spinW=smooth(rig.spinW)
                if spinW>.001 then frame=frame:Lerp(hip,spinW) end
                local shoulders={Left=torso.CFrame:PointToWorldSpace(Vector3.new(-.85,.45,0)),Right=torso.CFrame:PointToWorldSpace(Vector3.new(.85,.45,0))}
                local grips=rig.model:Pose(frame,shoulders,now,localPlayer and self.activity or rig.activity,state,char)
                rig.model.pencil.LocalTransparencyModifier=(held>.35 or spinW>.05) and 0 or 1
                if spinW>.001 then
                    -- the right hand up and out in front of the shoulder (clear of the coat, so the pen reads
                    -- against the background), the left one down by the side; the book is put away
                    local S=torso.CFrame*CFrame.new(.62,.38,-(torso.Size.Z*.5+1.25))*CFrame.Angles(-.5,0,.2)
                    local spun=penSpinFrame(S,os.clock(),penLength(rig.model))
                    rig.model.pencil.CFrame=rig.model.pencil.CFrame:Lerp(spun*rig.model.penOffset,spinW)
                    grips={Left=grips.Left:Lerp(torso.CFrame:PointToWorldSpace(Vector3.new(-1.05,-1.7,-.2)),spinW),
                        Right=grips.Right:Lerp(S:PointToWorldSpace(Vector3.new(0,-.2,0)),spinW)}
                    rig.model:SetBookHidden(spinW>.9)
                else
                    rig.model:SetBookHidden(false)
                end
                if rig.pose then
                    rig.pose:SetWeight(held*(1-letGo))
                    rig.pose:Update(grips,dt)
                    if held>.9 and spinW<.05 then rig.model:AnchorToPalms(rig.pose:Palms(),grips) else rig.model.anchorShift=nil end
                end
            end
        end
    end
    -- a bot that's gone (marked and cleared away): drop its notebook
    for key in pairs(self.rigs) do
        if type(key)=="table" and key.IsBot and not seen[key] then self:Forget(key) end
    end
end
return Controller
