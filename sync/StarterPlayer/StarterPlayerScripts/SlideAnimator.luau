-- Procedural body layer on top of the character's animations, for every character on this client:
--   * designed walk and sprint cycles (Gait), blended by speed, replacing the stock run while grounded
--   * slide pose (SlidePose) while sliding, with a live layer: entry dip, scrape chatter, hand drag
--   * lean into speed, bank into turns, tuck/stretch in the air
--   * landing squash, double-jump front flip, kill lunge (StrikeAt attribute)
--   * dash (DashAt): a hard lean into the dash with the arms swept back, Jett-style (wind: AbilityFX)
-- Applied after the Animator each frame through the joint frame (JointRig), restored before the next one.
local Run = game:GetService("RunService")
local Gait = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Gait"))
local SlideAnimator = {}
SlideAnimator.__index = SlideAnimator
local TAU = math.pi * 2
local function approach(value, target, sharpness, dt) return target + (value - target) * math.exp(-sharpness * dt) end
local function smooth(t) return t * t * (3 - 2 * t) end
local function wrap(a) return (a + math.pi) % TAU - math.pi end
-- rotation/translation authored in the parent body's frame, converted into the joint's frame
local function inJoint(descriptor, displacement, rotation)
    local basis = descriptor.C0.Rotation
    return CFrame.new(basis:VectorToObjectSpace(displacement)) * basis:Inverse() * rotation * basis
end

-- crouch: hips dropped, knees bent, a slight forward lean (joint key -> {move, rotation} in the parent's space)
local rad = math.rad
local CROUCH = {
    R15 = {
        -- low sneak: hips down, back hunched forward, head kept level to watch ahead, arms drawn in close
        Root = {Vector3.new(0, -1.15, 0), CFrame.Angles(rad(-18), 0, 0)},
        UpperTorso = {Vector3.zero, CFrame.Angles(rad(-16), 0, 0)},
        Head = {Vector3.zero, CFrame.Angles(rad(26), 0, 0)},
        RightUpperArm = {Vector3.zero, CFrame.Angles(rad(30), rad(-14), rad(16))},
        LeftUpperArm = {Vector3.zero, CFrame.Angles(rad(8), rad(10), rad(-14))},
        RightLowerArm = {Vector3.zero, CFrame.Angles(rad(38), 0, 0)},
        LeftLowerArm = {Vector3.zero, CFrame.Angles(rad(52), 0, 0)},
        RightHand = {Vector3.zero, CFrame.Angles(rad(-24), 0, rad(-10))},
        LeftHand = {Vector3.zero, CFrame.Angles(rad(-18), 0, rad(10))},
        RightUpperLeg = {Vector3.zero, CFrame.Angles(rad(78), 0, rad(-4))},
        LeftUpperLeg = {Vector3.zero, CFrame.Angles(rad(58), 0, rad(4))},
        RightLowerLeg = {Vector3.zero, CFrame.Angles(rad(-112), 0, 0)},
        LeftLowerLeg = {Vector3.zero, CFrame.Angles(rad(-96), 0, 0)},
        RightFoot = {Vector3.zero, CFrame.Angles(rad(30), 0, 0)},
        LeftFoot = {Vector3.zero, CFrame.Angles(rad(36), 0, 0)},
    },
    R6 = {
        Root = {Vector3.new(0, -0.9, 0), CFrame.Angles(rad(-20), 0, 0)},
        Head = {Vector3.zero, CFrame.Angles(rad(22), 0, 0)},
        RightLeg = {Vector3.zero, CFrame.Angles(rad(40), 0, 0)},
        LeftLeg = {Vector3.zero, CFrame.Angles(rad(22), 0, 0)},
        RightArm = {Vector3.zero, CFrame.Angles(rad(38), 0, rad(14))},
        LeftArm = {Vector3.zero, CFrame.Angles(rad(18), 0, rad(-12))},
    },
}

-- dash: thrown hard into the direction of the dash (the root lean is worked out live from the dash direction),
-- head up to see where you're going, arms swept back, the back leg trailing
local DASH_LEAN = rad(40)
local DASH = {
    R15 = {
        UpperTorso = {Vector3.zero, CFrame.Angles(rad(-8), 0, 0)},
        Head = {Vector3.zero, CFrame.Angles(rad(30), 0, 0)},
        RightUpperArm = {Vector3.zero, CFrame.Angles(rad(-58), 0, rad(16))},
        LeftUpperArm = {Vector3.zero, CFrame.Angles(rad(-58), 0, rad(-16))},
        RightLowerArm = {Vector3.zero, CFrame.Angles(rad(14), 0, 0)},
        LeftLowerArm = {Vector3.zero, CFrame.Angles(rad(14), 0, 0)},
        RightHand = {Vector3.zero, CFrame.Angles(rad(-20), 0, 0)},
        LeftHand = {Vector3.zero, CFrame.Angles(rad(-20), 0, 0)},
        RightUpperLeg = {Vector3.zero, CFrame.Angles(rad(-30), 0, 0)},
        LeftUpperLeg = {Vector3.zero, CFrame.Angles(rad(42), 0, 0)},
        RightLowerLeg = {Vector3.zero, CFrame.Angles(rad(-48), 0, 0)},
        LeftLowerLeg = {Vector3.zero, CFrame.Angles(rad(-74), 0, 0)},
        RightFoot = {Vector3.zero, CFrame.Angles(rad(-24), 0, 0)},
        LeftFoot = {Vector3.zero, CFrame.Angles(rad(22), 0, 0)},
    },
    R6 = {
        Head = {Vector3.zero, CFrame.Angles(rad(28), 0, 0)},
        RightArm = {Vector3.zero, CFrame.Angles(rad(-60), 0, rad(14))},
        LeftArm = {Vector3.zero, CFrame.Angles(rad(-60), 0, rad(-14))},
        RightLeg = {Vector3.zero, CFrame.Angles(rad(-28), 0, 0)},
        LeftLeg = {Vector3.zero, CFrame.Angles(rad(36), 0, 0)},
    },
}
-- weight of the dash pose over its life (snaps in, holds, eases out)
local DASH_TIME = 0.36
local function dashWeight(t)
    if t < 0.14 then return smooth(t / 0.14) end
    if t < 0.55 then return 1 end
    return 1 - smooth(math.clamp((t - 0.55) / 0.45, 0, 1))
end

-- wall climb: hand over hand up the wall, knees driving, chest close to the wall and head tipped up.
-- phase advances while climbing; returns a pose table like CROUCH for this moment of the cycle.
-- wall hang: a coiled Spider-Man wall perch. Feet planted high on the wall in a deep crouch, knees out, one hand
-- gripping the wall beside the head, the other arm cocked back for balance, the body leaning out off the wall and
-- turned to look over the shoulder -- loaded like a spring, ready to launch to the next building.
-- `g` (0 = left hand on the wall .. 1 = right hand: the hand on the side you're heading), `lead` (-1..1: a wall
-- dash pulling you that way: you run sideways along the wall, stretched out, the leading hand reaching), `step`
-- (0..1 shimmying) with `phase` (its cycle: the hands and feet take little steps -- the body keeps facing the same
-- way, it used to swap sides every step and flip left and right) and `t`.
local function hangPose(isR15, t, g, lead, step, phase)
    local function mix(a, b, k) return a + (b - a) * k end
    local breath = math.sin(t * 2.1)
    local s = math.sin(phase or 0) * (step or 0)
    local c = math.cos(phase or 0) * (step or 0)
    local sgn = g * 2 - 1 -- +1 right hand on the wall, -1 left
    local reach = math.abs(lead)
    local fwd, back = math.max(lead, 0), math.max(-lead, 0)
    -- arms: the wall hand plants beside the head (reaching far along the wall in a dash); the free arm is cocked back
    local wallX, wallZ, wallElbow = mix(104, 92, reach), mix(34, 84, reach), mix(46, 8, reach)
    local freeX, freeZ, freeElbow = mix(-38, -60, reach), mix(34, 16, reach), mix(58, 20, reach)
    local rx, rz, re = mix(freeX, wallX, g), mix(freeZ, wallZ, g), mix(freeElbow, wallElbow, g)
    local lx, lz, le = mix(wallX, freeX, g), mix(wallZ, freeZ, g), mix(wallElbow, freeElbow, g)
    -- shimmy: the wall hand reaches ahead and pulls back, the free arm swings a little
    rz += 14 * s; lz -= 14 * s
    rx += 10 * c; lx -= 10 * c
    -- legs: deep crouch with the feet up on the wall and the knees out; a dash stretches the trailing leg out behind
    local crouchX, crouchKnee = 104 + breath * 3, -122
    local rlx = mix(crouchX, 30, back) + 8 * fwd
    local llx = mix(crouchX, 30, fwd) + 8 * back
    local rk = mix(crouchKnee, -20, back)
    local lk = mix(crouchKnee, -20, fwd)
    local rlz, llz = 26 + 10 * back, 26 + 10 * fwd
    -- shimmy: the feet step in turns
    rlx += 14 * c; llx -= 14 * c
    rlz += 8 * s; llz -= 8 * s
    -- body: dropped low and leaning out off the wall, turned to look out over the free shoulder
    local yaw = 34 * sgn * (1 - reach) - 20 * lead
    local roll = -30 * lead
    local root = {Vector3.new(0, -0.95 + breath * 0.05, 0.55), CFrame.Angles(rad(16 - 10 * reach), rad(yaw), rad(roll))}
    local head = {Vector3.zero, CFrame.Angles(rad(-10), rad(40 * sgn * (1 - reach) - 30 * lead), rad(-8 * sgn))}
    if isR15 then
        return {
            Root = root,
            UpperTorso = {Vector3.zero, CFrame.Angles(rad(-14), rad(12 * sgn * (1 - reach)), rad(-8 * lead))},
            Head = head,
            RightUpperArm = {Vector3.zero, CFrame.Angles(rad(rx), 0, rad(rz))},
            LeftUpperArm = {Vector3.zero, CFrame.Angles(rad(lx), 0, rad(-lz))},
            RightLowerArm = {Vector3.zero, CFrame.Angles(rad(re), 0, 0)},
            LeftLowerArm = {Vector3.zero, CFrame.Angles(rad(le), 0, 0)},
            RightHand = {Vector3.zero, CFrame.Angles(rad(mix(14, -30, g)), 0, 0)},
            LeftHand = {Vector3.zero, CFrame.Angles(rad(mix(-30, 14, g)), 0, 0)},
            RightUpperLeg = {Vector3.zero, CFrame.Angles(rad(rlx), 0, rad(rlz))},
            LeftUpperLeg = {Vector3.zero, CFrame.Angles(rad(llx), 0, rad(-llz))},
            RightLowerLeg = {Vector3.zero, CFrame.Angles(rad(rk), 0, 0)},
            LeftLowerLeg = {Vector3.zero, CFrame.Angles(rad(lk), 0, 0)},
            RightFoot = {Vector3.zero, CFrame.Angles(rad(34), 0, 0)},
            LeftFoot = {Vector3.zero, CFrame.Angles(rad(34), 0, 0)},
        }
    end
    return {
        Root = root,
        Head = head,
        RightArm = {Vector3.zero, CFrame.Angles(rad(rx), 0, rad(rz))},
        LeftArm = {Vector3.zero, CFrame.Angles(rad(lx), 0, rad(-lz))},
        RightLeg = {Vector3.zero, CFrame.Angles(rad(rlx * 0.8), 0, rad(rlz))},
        LeftLeg = {Vector3.zero, CFrame.Angles(rad(llx * 0.8), 0, rad(-llz))},
    }
end

local function climbPose(isR15, phase)
    local a = math.sin(phase)
    local up, down = 0.5 + 0.5 * a, 0.5 - 0.5 * a
    if isR15 then
        return {
            Root = {Vector3.new(0, 0.1, 0), CFrame.Angles(rad(-6), 0, 0)},
            UpperTorso = {Vector3.zero, CFrame.Angles(rad(4), rad(a * 6), 0)},
            Head = {Vector3.zero, CFrame.Angles(rad(22), 0, 0)},
            -- one arm reaches high while the other pulls down to the shoulder
            RightUpperArm = {Vector3.zero, CFrame.Angles(rad(110 + 60 * up), 0, rad(-8))},
            LeftUpperArm = {Vector3.zero, CFrame.Angles(rad(110 + 60 * down), 0, rad(8))},
            RightLowerArm = {Vector3.zero, CFrame.Angles(rad(10 + 70 * down), 0, 0)},
            LeftLowerArm = {Vector3.zero, CFrame.Angles(rad(10 + 70 * up), 0, 0)},
            RightHand = {Vector3.zero, CFrame.Angles(rad(-20), 0, 0)},
            LeftHand = {Vector3.zero, CFrame.Angles(rad(-20), 0, 0)},
            -- the opposite knee drives up
            RightUpperLeg = {Vector3.zero, CFrame.Angles(rad(15 + 60 * down), 0, 0)},
            LeftUpperLeg = {Vector3.zero, CFrame.Angles(rad(15 + 60 * up), 0, 0)},
            RightLowerLeg = {Vector3.zero, CFrame.Angles(rad(-20 - 70 * down), 0, 0)},
            LeftLowerLeg = {Vector3.zero, CFrame.Angles(rad(-20 - 70 * up), 0, 0)},
            RightFoot = {Vector3.zero, CFrame.Angles(rad(20), 0, 0)},
            LeftFoot = {Vector3.zero, CFrame.Angles(rad(20), 0, 0)},
        }
    end
    return {
        Root = {Vector3.zero, CFrame.Angles(rad(-6), 0, 0)},
        Head = {Vector3.zero, CFrame.Angles(rad(22), 0, 0)},
        RightArm = {Vector3.zero, CFrame.Angles(rad(120 + 50 * up), 0, 0)},
        LeftArm = {Vector3.zero, CFrame.Angles(rad(120 + 50 * down), 0, 0)},
        RightLeg = {Vector3.zero, CFrame.Angles(rad(10 + 50 * down), 0, 0)},
        LeftLeg = {Vector3.zero, CFrame.Angles(rad(10 + 50 * up), 0, 0)},
    }
end

function SlideAnimator.new(players, adapter, poses)
    local self = setmetatable({players = players, adapter = adapter, poses = poses, rigs = {}, bindings = {}}, SlideAnimator)
    local function watch(player)
        self.bindings[player] = {
            player.CharacterAdded:Connect(function(char) self:Track(char) end),
            player.CharacterRemoving:Connect(function(char) self:Forget(char) end),
        }
        if player.Character then self:Track(player.Character) end
    end
    players.PlayerAdded:Connect(watch)
    players.PlayerRemoving:Connect(function(player)
        if player.Character then self:Forget(player.Character) end
        for _, c in ipairs(self.bindings[player] or {}) do c:Disconnect() end
        self.bindings[player] = nil
    end)
    for _, player in ipairs(players:GetPlayers()) do watch(player) end
    -- AI fighters (BotService / tutorial bots, tagged MarkedBot) get the same gait, sprint, slide and crouch poses
    local CollectionService = game:GetService("CollectionService")
    CollectionService:GetInstanceAddedSignal("MarkedBot"):Connect(function(model) self:Track(model) end)
    CollectionService:GetInstanceRemovedSignal("MarkedBot"):Connect(function(model) self:Forget(model) end)
    for _, model in ipairs(CollectionService:GetTagged("MarkedBot")) do self:Track(model) end
    -- Restore last frame's base before Roblox advances its Animator, then overlay after it.
    Run.PreAnimation:Connect(function() self:Restore() end)
    Run.PreSimulation:Connect(function(dt) self:Step(math.min(dt, 1 / 20), workspace:GetServerTimeNow()) end)
    return self
end
function SlideAnimator:Track(character)
    if self.rigs[character] then return end
    local rig = {joints = {}, byObject = {}, weight = 0, char = character,
        m = {pitch = 0, roll = 0, dip = 0, wasAir = false, lastVy = 0,
            phase = math.random(), lw = 0, sprint = 0, dir = Vector3.new(0, 0, -1), seed = math.random() * 100}}
    self.rigs[character] = rig
    local function add(object)
        if rig.byObject[object] then return end
        local descriptor = self.adapter.Describe(object)
        if descriptor then
            descriptor.base = nil
            table.insert(rig.joints, descriptor)
            rig.byObject[object] = true
        end
    end
    rig.scan = function() for _, object in ipairs(character:GetDescendants()) do add(object) end end
    rig.nextScan = 0
    rig.added = character.DescendantAdded:Connect(add)
    for _, object in ipairs(character:GetDescendants()) do add(object) end
end
function SlideAnimator:RestoreRig(rig)
    for _, joint in ipairs(rig.joints) do
        if joint.base then
            if joint.Object.Parent and joint.Object.Enabled and not rig.char:GetAttribute("Ragdolled") then
                self.adapter.Restore(joint)
            end
            joint.base = nil
        end
    end
end
local BodyType -- (loaded on first use)
function SlideAnimator:Restore()
    local t = os.clock()
    for _, rig in pairs(self.rigs) do
        self:RestoreRig(rig)
        -- every half second, with the joints at rest: make sure the torso's shoulder / neck / waist attachments
        -- still match its body type (BodyType.Heal), so the arms can't stay floating off a slimmer torso
        if t > (rig.healAt or 0) and not rig.char:GetAttribute("Ragdolled") then
            rig.healAt = t + 0.5
            if not BodyType then
                local ok, m = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("BodyType")) end)
                BodyType = ok and m or false
            end
            if BodyType then pcall(BodyType.Heal, rig.char) end
        end
    end
end
function SlideAnimator:Forget(character)
    local rig = self.rigs[character]
    if not rig then return end
    self:RestoreRig(rig)
    rig.added:Disconnect()
    self.rigs[character] = nil
end

-- movement-driven offsets for one character; returns root and waist rotations in body space
function SlideAnimator:Motion(rig, character, humanoid, root, sliding, dt, now)
    local m = rig.m
    local v = root.AssemblyLinearVelocity
    local flat = Vector3.new(v.X, 0, v.Z)
    local speed = flat.Magnitude
    local look = root.CFrame.LookVector
    local yaw = math.atan2(-look.X, -look.Z)
    local yawRate = m.lastYaw and wrap(yaw - m.lastYaw) / math.max(dt, 1e-3) or 0
    m.lastYaw = yaw
    local facing = Vector3.new(look.X, 0, look.Z)
    local forward = facing.Magnitude > 0.01 and flat:Dot(facing.Unit) or 0
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    -- targets
    local pitchTarget, rollTarget = 0, 0
    if not sliding then
        if grounded then
            pitchTarget = 0 -- the gait leans into speed
        else
            pitchTarget = v.Y > 6 and 0.07 or -0.13
        end
        rollTarget = math.clamp(yawRate * speed * 0.0032, -0.32, 0.32)
    end
    m.pitch = approach(m.pitch, pitchTarget, 8, dt)
    m.roll = approach(m.roll, rollTarget, 6, dt)
    -- landing squash
    if grounded and m.wasAir and m.lastVy < -28 then m.dip = math.clamp(-m.lastVy / 150, 0, 0.55) end
    m.wasAir = not grounded
    if not grounded then m.lastVy = v.Y end
    m.dip = approach(m.dip, 0, 9, dt)
    -- double-jump flip
    local airJump = character:GetAttribute("AirJumpAt")
    if airJump and airJump ~= m.airJumpSeen then
        m.airJumpSeen = airJump
        -- the owner sets this locally and the server mirrors it a moment later: only flip once
        if now - airJump < 0.5 and not (m.flipStart and os.clock() - m.flipStart < 0.45) then m.flipStart = os.clock() end
    end
    local flip = 0
    if m.flipStart then
        local t = (os.clock() - m.flipStart) / 0.46
        if t >= 1 then m.flipStart = nil else flip = -TAU * smooth(t) end
    end
    -- kill lunge
    local strike = character:GetAttribute("StrikeAt")
    if strike and strike ~= m.strikeSeen then
        m.strikeSeen = strike
        if now - strike < 0.6 then m.strikeStart = os.clock() end
    end
    local lunge, twist = 0, 0
    if m.strikeStart then
        local t = (os.clock() - m.strikeStart) / 0.38
        if t >= 1 then m.strikeStart = nil else
            local s = math.sin(math.pi * t)
            lunge, twist = -0.32 * s, 0.45 * s * (1 - t)
        end
    end
    local active = math.abs(m.pitch) + math.abs(m.roll) + m.dip > 0.003 or flip ~= 0 or lunge ~= 0
    if not active then return nil end
    return {
        rootMove = Vector3.new(0, -m.dip, 0),
        root = CFrame.Angles(m.pitch + flip, 0, m.roll),
        waist = CFrame.Angles(-m.pitch * 0.35 + lunge, twist, -m.roll * 0.3),
    }
end

-- walk/sprint cycle for one character; returns the pose and its blend weight
function SlideAnimator:Locomotion(rig, character, humanoid, root, sliding, dt, isR15, scale)
    local m = rig.m
    local v = root.AssemblyLinearVelocity
    local flat = Vector3.new(v.X, 0, v.Z)
    local speed = flat.Magnitude
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    local state = humanoid:GetState()
    local moving = grounded and not sliding and speed > 1 and state ~= Enum.HumanoidStateType.Climbing
    m.lw = approach(m.lw, moving and math.clamp(speed / 7, 0, 1) or 0, moving and 14 or 10, dt)
    -- sprint look: holding sprint, or carrying momentum well past run speed
    local sprintTarget = math.max(character:GetAttribute("Sprinting") == true and math.clamp((speed - 20) / 6, 0, 1) or 0,
        math.clamp((speed - 30) / 8, 0, 1))
    m.sprint = approach(m.sprint, sprintTarget, 6, dt)
    if m.lw < 0.01 then return nil, 0 end
    local p = Gait.Params(m.sprint)
    if moving then
        local before = m.phase
        m.phase = (m.phase + dt * Gait.Cadence(p, speed)) % 1
        -- heel strikes: the right foot plants at 0.25 of the cycle, the left at 0.75 (Footsteps listens)
        if Gait.OnStep then
            local after = m.phase < before and m.phase + 1 or m.phase
            for _, contact in ipairs({0.25, 0.75, 1.25}) do
                if before < contact and after >= contact then
                    task.spawn(Gait.OnStep, character, speed)
                    break
                end
            end
        end
    end
    local localVelocity = root.CFrame:VectorToObjectSpace(flat)
    local direction = speed > 0.5 and Vector3.new(localVelocity.X, 0, localVelocity.Z).Unit or Vector3.new(0, 0, -1)
    m.dir = m.dir:Lerp(direction, 1 - math.exp(-10 * dt))
    local dir = m.dir.Magnitude > 0.05 and m.dir.Unit or Vector3.new(0, 0, -1)
    return Gait.Pose(isR15, m.phase, p, math.clamp(speed / 16, 0.3, 1), dir, scale), m.lw
end

-- other fighters further than this from the camera keep their plain animations (the procedural poses can't be
-- made out from there, and with a full server of players / bots they were a big share of the frame)
local POSE_RANGE = 150
function SlideAnimator:Step(dt, now)
    local cam = workspace.CurrentCamera
    local eye = cam and cam.CFrame.Position
    local mine = game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Character
    for character, rig in pairs(self.rigs) do
        -- Joint instances may arrive before Part0/Part1 or attachments are populated.
        -- (often for the first few seconds of a body, then every 2 s: a full scan of every character 5x a second
        -- added up with a server full of fighters)
        if now >= rig.nextScan then rig.scan(); rig.scans = (rig.scans or 0) + 1; rig.nextScan = now + (rig.scans < 15 and 0.2 or 2) end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        local range = (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:GetAttribute("LowEnd") == true) and 70 or POSE_RANGE
        local far = root and eye and character ~= mine and (root.Position - eye).Magnitude > range
        if not character.Parent then self:Forget(character)
        elseif far then rig.weight = 0
        elseif humanoid and root then
            local alive = humanoid.Health > 0 and not character:GetAttribute("Ragdolled")
            if not alive then rig.weight = 0
            else
                local sliding = (character:GetAttribute("SlideUntil") or 0) > now
                rig.weight = self.poses.Weight(rig.weight, sliding, dt)
                local motion = self:Motion(rig, character, humanoid, root, sliding, dt, now)
                local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
                local scale = math.clamp(root.Size.Y / 2, 0.7, 1.5)
                local loco, locoWeight = self:Locomotion(rig, character, humanoid, root, sliding, dt, isR15, scale)
                local m = rig.m
                local crouchOn = character:GetAttribute("Crouching") == true and not sliding
                m.crouch = approach(m.crouch or 0, crouchOn and 1 or 0, 12, dt)
                local crouchPose = m.crouch > 0.01 and (isR15 and CROUCH.R15 or CROUCH.R6) or nil
                -- wall hang: your own flag (WallHang, set by ParkourController) or the server mirror (Hanging) for others
                local hanging = (character == mine and character:GetAttribute("WallHang") == true)
                    or (character ~= mine and character:GetAttribute("Hanging") == true)
                m.hang = approach(m.hang or 0, hanging and 1 or 0, hanging and 18 or 10, dt)
                local hangPoseNow
                if m.hang > 0.01 then
                    -- sideways speed along the wall (the body faces the wall): shimmy steps, or a wall dash stretch
                    local sx = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity).X
                    local ax = math.abs(sx)
                    -- (only a real move along the wall turns you: the small push that keeps the hands on the wall doesn't)
                    if ax > 3 then m.hangSide = approach(m.hangSide or 0, sx > 0 and 1 or -1, 10, dt) end
                    m.hangDash = approach(m.hangDash or 0, (hanging and ax > 22) and 1 or 0, 22, dt)
                    m.hangStep = approach(m.hangStep or 0, (hanging and ax > 1.5 and ax <= 22) and 1 or 0, 10, dt)
                    m.hangPhase = (m.hangPhase or 0) + dt * math.min(ax, 12) * 1.15
                    m.hangT = (m.hangT or 0) + dt
                    local side = m.hangSide or 0
                    -- which hand holds on: the one on the side you're heading (right by default)
                    m.hangGrip = approach(m.hangGrip or 1, side < -0.2 and 0 or 1, 6, dt)
                    hangPoseNow = hangPose(isR15, m.hangT, m.hangGrip, m.hangDash * side, m.hangStep, m.hangPhase)
                else
                    m.hangSide, m.hangDash, m.hangStep, m.hangGrip = 0, 0, 0, nil
                end
                -- wall climb: your own flag (ParkourController), or the server mirror (ClimbAt) for other players
                local climbAt = character:GetAttribute("ClimbAt") or -1e9
                -- (hanging has its own pose, so it's never the climb)
                local climbing = not hanging and (character:GetAttribute("Climbing") == true or (now - climbAt < 0.85
                    and humanoid.FloorMaterial == Enum.Material.Air and (character:GetAttribute("WallJumpAt") or 0) < climbAt))
                m.climb = approach(m.climb or 0, climbing and 1 or 0, climbing and 16 or 9, dt)
                if climbing then m.climbPhase = (m.climbPhase or 0) + dt * 10 end
                local climbPoseNow = m.climb > 0.01 and climbPose(isR15, m.climbPhase or 0) or nil
                -- dash (your own DashAt is set locally, the server mirrors it a moment later: lean once)
                local dashAt = character:GetAttribute("DashAt")
                if dashAt and dashAt ~= m.dashSeen then
                    m.dashSeen = dashAt
                    if now - dashAt < 0.5 and not (m.dashStart and os.clock() - m.dashStart < 0.5) then m.dashStart = os.clock() end
                end
                if hanging then m.dashStart = nil end -- (a wall dash has its own stretch in the hang pose)
                local dashW = 0
                local dashPoseNow
                if m.dashStart then
                    local t = (os.clock() - m.dashStart) / DASH_TIME
                    if t >= 1 or sliding then m.dashStart = nil else
                        dashW = dashWeight(t)
                        -- lean toward the way the body is actually travelling (forward, sideways or back)
                        local lv = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
                        local flat = Vector3.new(lv.X, 0, lv.Z)
                        local d = flat.Magnitude > 8 and flat.Unit or Vector3.new(0, 0, -1)
                        m.dashDir = m.dashDir and m.dashDir:Lerp(d, 1 - math.exp(-18 * dt)) or d
                        local axis = m.dashDir:Cross(Vector3.yAxis)
                        axis = axis.Magnitude > 0.01 and axis.Unit or Vector3.xAxis
                        local pose = table.clone(isR15 and DASH.R15 or DASH.R6)
                        pose.Root = {Vector3.new(0, -0.3, 0), CFrame.fromAxisAngle(axis, -DASH_LEAN)}
                        dashPoseNow = pose
                    end
                end
                if sliding and not m.wasSliding then m.slideStart = os.clock() end
                m.wasSliding = sliding
                local slideLayer = rig.weight > 0 and m.slideStart and
                    Gait.SlideLayer(isR15, os.clock() - m.slideStart, Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude, m.seed, scale) or nil
                if rig.weight > 0 or motion or loco or crouchPose or climbPoseNow or dashPoseNow or hangPoseNow then
                    local direction = character:GetAttribute("SlideDirection")
                    local yaw = 0
                    if typeof(direction) == "Vector3" and direction.Magnitude > 0.1 then
                        local localDirection = root.CFrame:VectorToObjectSpace(direction)
                        yaw = math.atan2(-localDirection.X, -localDirection.Z)
                    end
                    local ease = self.poses.Ease(rig.weight)
                    local locoEase = self.poses.Ease(math.clamp(locoWeight, 0, 1))
                    local notebookPose = character:GetAttribute("LocalNotebookPose")
                    -- how firmly the hands hold the notebook (NotebookWorldPose): the arm overlay fades in as it's put away
                    local bookWeight = notebookPose and math.clamp(character:GetAttribute("LocalNotebookWeight") or 1, 0, 1) or 0
                    for _, joint in ipairs(rig.joints) do
                        local key = joint.Key
                        local definition = rig.weight > 0 and self.poses.Get(isR15, key) or nil
                        local stride = loco and loco[key]
                        local live = slideLayer and slideLayer[key]
                        local crouchKey = crouchPose and crouchPose[key]
                        local climbKey = climbPoseNow and climbPoseNow[key]
                        local dashKey = dashPoseNow and dashPoseNow[key]
                        local hangKey = hangPoseNow and hangPoseNow[key]
                        local extra
                        if motion then
                            if joint.Root then extra = inJoint(joint, motion.rootMove, motion.root)
                            elseif key == "UpperTorso" or (not isR15 and key == "Torso") then extra = inJoint(joint, Vector3.zero, motion.waist) end
                        end
                        local isArm = key:find("Arm") or key:find("Hand")
                        local notebookArm = isArm and bookWeight >= 0.98
                        if climbKey or hangKey then notebookArm = false end -- climbing / hanging takes the arms off the notebook
                        if (definition or extra or stride or live or crouchKey or climbKey or dashKey or hangKey) and not notebookArm and joint.Object.Parent and joint.Object.Enabled then
                            joint.base = joint.Object.Transform
                            local current = joint.Object.Transform
                            local blended = current
                            if stride then blended = blended:Lerp(inJoint(joint, stride[1], stride[2]), locoEase) end
                            if definition then blended = blended:Lerp(self.poses.Target(joint, definition, scale, joint.Root and yaw or 0), ease) end
                            if live then blended = CFrame.identity:Lerp(inJoint(joint, live[1], live[2]), ease) * blended end
                            if crouchKey then blended = CFrame.identity:Lerp(inJoint(joint, crouchKey[1] * scale, crouchKey[2]), m.crouch) * blended end
                            if climbKey then blended = blended:Lerp(inJoint(joint, climbKey[1] * scale, climbKey[2]), m.climb) end
                            if hangKey then blended = blended:Lerp(inJoint(joint, hangKey[1] * scale, hangKey[2]), m.hang) end
                            if dashKey then
                                if joint.Root then blended = CFrame.identity:Lerp(inJoint(joint, dashKey[1] * scale, dashKey[2]), dashW) * blended
                                else blended = blended:Lerp(inJoint(joint, dashKey[1] * scale, dashKey[2]), dashW) end
                            end
                            if extra then blended = extra * blended end
                            if isArm and bookWeight > 0 then blended = current:Lerp(blended, 1 - bookWeight) end
                            self.adapter.Apply(joint, blended, 1)
                        end
                    end
                end
            end
        end
    end
end
return SlideAnimator
