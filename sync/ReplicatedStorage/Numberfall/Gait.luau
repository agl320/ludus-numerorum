-- Designed locomotion for MARKED: a walk cycle, a sprint cycle (blended by speed) and the live slide layer.
-- Angles are degrees in the parent body's frame, the same convention as SlidePose:
--   +X on a hip or shoulder swings the limb forward, -X on a knee folds the shin back,
--   +X on a foot lifts the toes, a negative pitch on the root leans the body forward.
local Gait = {}
local TAU = math.pi * 2
local rad = math.rad

-- Walk: the default 24 stud/s pace. Light, springy stride, upright chest, relaxed arms.
Gait.Walk = {
    Cadence = 1.45, RefSpeed = 24,
    Hip = 32, HipForward = 3, Knee = 8, KneeSwing = 66, ToeOff = 26, Heel = 12,
    Drop = 0.06, Bounce = 0.13, Lean = 6, Twist = 8, Counter = 12, Sway = 2.5,
    Arm = 32, ArmOut = 6, Elbow = 30, ElbowSwing = 16, HeadDown = 2,
}
-- Sprint: driving forward lean, high knees, long reach, big arm pump, head tucked.
Gait.Sprint = {
    Cadence = 1.7, RefSpeed = 32,
    Hip = 52, HipForward = 10, Knee = 14, KneeSwing = 112, ToeOff = 40, Heel = 8,
    Drop = 0.22, Bounce = 0.24, Lean = 17, Twist = 11, Counter = 17, Sway = 3,
    Arm = 60, ArmOut = 9, Elbow = 80, ElbowSwing = 20, HeadDown = 8,
}

local function mix(a, b, t) return a + (b - a) * t end
function Gait.Params(sprint)
    local p = {}
    for key, value in pairs(Gait.Walk) do p[key] = mix(value, Gait.Sprint[key], sprint) end
    return p
end
-- full cycles (two steps) per second at this speed
function Gait.Cadence(p, speed)
    return p.Cadence * math.clamp(0.45 + 0.55 * speed / p.RefSpeed, 0.4, 1.5)
end

local function entry(rotation, displacement) return {displacement or Vector3.zero, rotation} end

-- phase: position in the cycle [0, 1). amount: stride size 0..1.
-- direction: unit travel direction in the root's space (x right, z back), so strafes and backpedals step the right way.
function Gait.Pose(isR15, phase, p, amount, direction, scale)
    local th = phase * TAU
    local s, c = math.sin(th), math.cos(th)
    local a = amount
    local axis = Vector3.new(-direction.Z, 0, direction.X)
    axis = axis.Magnitude > 0.01 and axis.Unit or Vector3.xAxis
    local sideways = math.abs(direction.X)
    local forward = -direction.Z
    local stride = a * (1 - 0.3 * sideways)
    local pose = {}
    local function leg(prefix, phi)
        local sin, cos = math.sin(phi), math.cos(phi)
        local hip = (p.HipForward * math.max(0, forward) + p.Hip * sin) * stride
        -- the knee folds hardest just after toe-off, then reaches out straight for the next contact
        local fold = math.max(0, math.cos(phi + 0.55)) ^ 1.4
        local knee = -(p.Knee * a + p.KneeSwing * fold * stride)
        local foot = (p.Heel * math.max(0, sin) - p.ToeOff * math.max(0, -sin) * math.max(0, cos) * 1.8) * stride
        if isR15 then
            pose[prefix .. "UpperLeg"] = entry(CFrame.fromAxisAngle(axis, rad(hip)))
            pose[prefix .. "LowerLeg"] = entry(CFrame.Angles(rad(knee), 0, 0))
            pose[prefix .. "Foot"] = entry(CFrame.Angles(rad(foot), 0, 0))
        else
            pose[prefix .. "Leg"] = entry(CFrame.fromAxisAngle(axis, rad(hip * 0.85)))
        end
    end
    leg("Right", th)
    leg("Left", th + math.pi)
    -- pelvis: drops at each contact, rises through the flight, leans into travel, twists with the legs
    local height = (-p.Drop + p.Bounce * (math.abs(s) - 0.5)) * a * scale
    pose.Root = entry(CFrame.fromAxisAngle(axis, -rad(p.Lean * a)) * CFrame.Angles(0, rad(p.Twist * s * a), rad(p.Sway * c * a)),
        Vector3.new(0, height, 0))
    local lean = p.Lean * math.max(0, forward)
    if isR15 then
        -- shoulders counter the hips; the head holds the horizon
        pose.UpperTorso = entry(CFrame.Angles(-rad(p.Lean * 0.3 * a), -rad(p.Counter * s * a), -rad(p.Sway * 0.6 * c * a)))
        pose.Head = entry(CFrame.Angles(rad((lean * 1.15 - p.HeadDown) * a), rad((p.Counter - p.Twist) * s * a * 0.85), 0))
        pose.RightUpperArm = entry(CFrame.Angles(rad(-p.Arm * s * a + 4), 0, rad(p.ArmOut * a)))
        pose.LeftUpperArm = entry(CFrame.Angles(rad(p.Arm * s * a + 4), 0, -rad(p.ArmOut * a)))
        pose.RightLowerArm = entry(CFrame.Angles(rad((p.Elbow + p.ElbowSwing * math.max(0, -s)) * a), 0, 0))
        pose.LeftLowerArm = entry(CFrame.Angles(rad((p.Elbow + p.ElbowSwing * math.max(0, s)) * a), 0, 0))
    else
        pose.Head = entry(CFrame.Angles(rad((lean - p.HeadDown) * a), -rad(p.Twist * s * a * 0.8), 0))
        pose.RightArm = entry(CFrame.Angles(rad(-p.Arm * s * a * 0.8), 0, rad(p.ArmOut * a)))
        pose.LeftArm = entry(CFrame.Angles(rad(p.Arm * s * a * 0.8), 0, -rad(p.ArmOut * a)))
    end
    return pose
end

-- Live layer on top of the slide pose: a deeper dip on entry that settles, scrape chatter that grows with speed,
-- the trailing hand dragging and the body balancing. t: seconds into the slide.
function Gait.SlideLayer(isR15, t, speed, seed, scale)
    local entryDip = -0.24 * math.sin(math.min(t / 0.3, 1) * math.pi) * scale
    local chatter = math.clamp(speed / 40, 0.25, 1)
    local n1 = math.noise(t * 23, seed, 0.5)
    local n2 = math.noise(seed, t * 19, 1.5)
    local n3 = math.noise(t * 3.2, seed, 2.5)
    local layer = {
        Root = entry(CFrame.Angles(rad(n1 * 1.8 * chatter), 0, rad(n2 * 2.2 * chatter + n3 * 3)), Vector3.new(0, entryDip, 0)),
        Head = entry(CFrame.Angles(rad(-n1 * 1.4 * chatter), rad(n3 * 4), 0)),
    }
    if isR15 then
        layer.UpperTorso = entry(CFrame.Angles(rad(n3 * 3), rad(n3 * 5), 0))
        layer.RightLowerLeg = entry(CFrame.Angles(rad(n2 * 4 * chatter), 0, 0))
        layer.RightFoot = entry(CFrame.Angles(rad(n1 * 6 * chatter), 0, 0))
        layer.LeftUpperArm = entry(CFrame.Angles(rad(n2 * 3 * chatter), 0, rad(n1 * 5 * chatter)))
        layer.RightUpperArm = entry(CFrame.Angles(rad(n3 * 6), 0, rad(n3 * 4)))
    else
        layer.RightLeg = entry(CFrame.Angles(rad(n2 * 4 * chatter), 0, 0))
        layer.LeftArm = entry(CFrame.Angles(0, 0, rad(n1 * 5 * chatter)))
    end
    return layer
end
return Gait
