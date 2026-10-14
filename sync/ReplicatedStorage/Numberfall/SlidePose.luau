-- Authored procedural pose. Rotations are degrees in the parent body's frame.
-- Root translation lowers the visible pelvis without shrinking the collision capsule.
local Pose = {}
Pose.BlendIn, Pose.BlendOut = 0.09, 0.13
Pose.R15 = {
    -- baseball slide: pelvis low and leaning back, lead (right) leg reaching out along the ground,
    -- trailing leg folded under, lead arm out front for balance, trailing hand dragging behind the hip
    Root = {0, -1.0, 0.1, 20, 0, -7},
    UpperTorso = {0, 0, 0, 6, 12, 4},
    Head = {0, 0, 0, -22, -8, 2},
    RightUpperLeg = {0, 0, 0, 58, -6, 6},
    RightLowerLeg = {0, 0, 0, -6, 0, 0},
    RightFoot = {0, 0, 0, 18, 0, 0},
    LeftUpperLeg = {0, 0, 0, 78, 12, -18},
    LeftLowerLeg = {0, 0, 0, -120, 0, 0},
    LeftFoot = {0, 0, 0, 22, 0, 0},
    RightUpperArm = {0, 0, 0, 52, -8, 22},
    RightLowerArm = {0, 0, 0, 30, 0, 0},
    RightHand = {0, 0, 0, 0, 0, -8},
    LeftUpperArm = {0, 0, 0, -48, 0, -26},
    LeftLowerArm = {0, 0, 0, 10, 0, 0},
    LeftHand = {0, 0, 0, 0, 0, 10},
}
Pose.R6 = {
    Root = {0, -0.85, 0.15, -14, 0, -8},
    Head = {0, 0, 0, 15, 0, 4},
    RightLeg = {0, 0, 0, 69, -8, 10},
    LeftLeg = {0, 0, 0, 44, 18, -27},
    RightArm = {0, 0, 0, 25, -5, 24},
    LeftArm = {0, 0, 0, -30, 0, -35},
}
function Pose.Weight(current, active, dt)
    local step = math.max(0, dt) / (active and Pose.BlendIn or Pose.BlendOut)
    return active and math.min(1, current + step) or math.max(0, current - step)
end
function Pose.Ease(weight) return weight * weight * (3 - 2 * weight) end
function Pose.Get(isR15, key) return (isR15 and Pose.R15 or Pose.R6)[key] end
function Pose.Target(descriptor, definition, scale, yaw)
    local basis = descriptor.C0.Rotation
    local displacement = Vector3.new(definition[1], definition[2], definition[3]) * scale
    local rotation = CFrame.Angles(math.rad(definition[4]), math.rad(definition[5]) + (yaw or 0), math.rad(definition[6]))
    return CFrame.new(basis:VectorToObjectSpace(displacement)) * basis:Inverse() * rotation * basis
end
return Pose
