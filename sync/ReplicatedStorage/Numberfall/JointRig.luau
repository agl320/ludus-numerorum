-- One adapter for classic Motor6D and upgraded R15 AnimationConstraint joints.
local Rig = {}
function Rig.Describe(object)
    local p0, p1, c0, c1
    if object:IsA("Motor6D") then
        p0, p1, c0, c1 = object.Part0, object.Part1, object.C0, object.C1
    elseif object:IsA("AnimationConstraint") then
        local a0, a1 = object.Attachment0, object.Attachment1
        if a0 and a1 then p0, p1, c0, c1 = a0.Parent, a1.Parent, a0.CFrame, a1.CFrame end
    end
    if not p0 or not p1 then return nil end
    local root = p0.Name == "HumanoidRootPart" or p1.Name == "HumanoidRootPart"
    return {Object = object, Part0 = p0, Part1 = p1, C0 = c0, C1 = c1,
        Root = root, Key = root and "Root" or p1.Name:gsub(" ", "")}
end
function Rig.Apply(joint, target, weight)
    local object = joint.Object
    local blended = object.Transform:Lerp(target, weight)
    -- the joint's rest frame is re-read whenever it isn't currently overlaid (Restore runs every frame): a frame
    -- cached when the character spawned goes stale when the body is reshaped later (Loadout > Body), which threw
    -- the arms out to the old shoulder width whenever the walk / lean overlay was on
    if not joint.savedFrame then
        if object:IsA("Motor6D") then joint.C0 = object.C0
        elseif object.Attachment0 then joint.C0 = object.Attachment0.CFrame end
    end
    -- Apply through the joint frame, which takes effect immediately and is not
    -- overwritten by the stock Animator's deferred Transform batch.
    if object:IsA("Motor6D") then
        joint.savedFrame = object.C0
        object.C0 = joint.C0 * blended * object.Transform:Inverse()
        joint.written = object.C0
    else
        joint.savedFrame = object.Attachment0.CFrame
        joint.savedKinematic = object.IsKinematic
        object.IsKinematic = true
        object.Attachment0.CFrame = joint.C0 * blended * object.Transform:Inverse()
        joint.written = object.Attachment0.CFrame
    end
end
-- the frame changed under us since the overlay wrote it (the server reshaped the body -- Loadout > Body, or the
-- body type landing a moment after the character arrived): that new frame is the real rest frame, so keep it.
-- Putting the saved one back here is what threw the arms out to the classic shoulder width on other screens / in
-- live servers (the reshape replicates in between the overlay and its restore).
local function same(a, b)
    return a and b and (a.Position - b.Position).Magnitude < 1e-4 and a.LookVector:Dot(b.LookVector) > 0.99999 and a.UpVector:Dot(b.UpVector) > 0.99999
end
function Rig.Restore(joint)
    if joint.savedFrame then
        if joint.Object:IsA("Motor6D") then
            if same(joint.Object.C0, joint.written) then joint.Object.C0 = joint.savedFrame end
        elseif joint.Object.Attachment0 then
            if same(joint.Object.Attachment0.CFrame, joint.written) then joint.Object.Attachment0.CFrame = joint.savedFrame end
            joint.Object.IsKinematic = joint.savedKinematic
        end
        joint.savedFrame, joint.written = nil, nil
    end
end
return Rig
