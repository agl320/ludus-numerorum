local Physics = game:GetService("PhysicsService")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Ragdolls = {}
Ragdolls.__index = Ragdolls
function Ragdolls.new(config, adapter)
    for _, group in ipairs({"NumberfallBodies", "NumberfallLiving"}) do
        if not Physics:IsCollisionGroupRegistered(group) then Physics:RegisterCollisionGroup(group) end
    end
    Physics:CollisionGroupSetCollidable("NumberfallBodies", "NumberfallBodies", false)
    Physics:CollisionGroupSetCollidable("NumberfallBodies", "NumberfallLiving", false)
    return setmetatable({config = config, adapter = adapter, rigs = {}}, Ragdolls)
end
function Ragdolls:Prepare(character)
    if self.rigs[character] then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.BreakJointsOnDeath = false
    humanoid.RequiresNeck = false
    local rig = {joints = {}, parts = {}, humanoid = humanoid, active = false, kicked = false}
    self.rigs[character] = rig
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "RagdollConstraints", character
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") and object.Name ~= "NumberForehead" then
            object.CollisionGroup = "NumberfallLiving"
            table.insert(rig.parts, object)
        else
            local joint = self.adapter.Describe(object)
            if joint and not joint.Root then
            local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
            a0.Name, a1.Name = "RagdollA", "RagdollB"
            a0.CFrame, a1.CFrame = joint.C0, joint.C1
            a0.Parent, a1.Parent = joint.Part0, joint.Part1
            local socket = Instance.new("BallSocketConstraint")
            socket.Name = object.Name .. "Socket"
            socket.Attachment0, socket.Attachment1 = a0, a1
            socket.LimitsEnabled, socket.TwistLimitsEnabled = true, true
            socket.UpperAngle = object.Name == "Neck" and 30 or 55
            socket.TwistLowerAngle, socket.TwistUpperAngle = -35, 35
            socket.MaxFrictionTorque, socket.Restitution = 8, 0
            socket.Enabled, socket.Parent = false, folder
            table.insert(rig.joints, {motor = object, socket = socket, attachment = a0, c0 = joint.C0})
            end
        end
    end
end
function Ragdolls:Activate(character)
    local rig = self.rigs[character]
    if not rig or rig.active then return end
    rig.active = true
    character:SetAttribute("Ragdolled", true)
    rig.humanoid.AutoRotate = false
    rig.humanoid.PlatformStand = true
    local animate = character:FindFirstChild("Animate")
    if animate and animate:IsA("LocalScript") then animate.Enabled = false end
    local animator = rig.humanoid:FindFirstChildOfClass("Animator")
    if animator then for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0) end end
    for _, joint in ipairs(rig.joints) do
        joint.attachment.CFrame = joint.c0 * joint.motor.Transform
        joint.motor.Enabled = false
        joint.socket.Enabled = true
    end
    for _, part in ipairs(rig.parts) do
        if part.Parent then
            part.CollisionGroup = "NumberfallBodies"
            part.CanCollide = part.Name ~= "HumanoidRootPart"
            part.CanTouch = false
            if part:CanSetNetworkOwnership() then part:SetNetworkOwner(nil) end
        end
    end
    -- Fade near respawn. Debris is a fallback if the player leaves first.
    task.delay(math.max(0.2, self.config.RespawnSeconds - self.config.Ragdoll.FadeSeconds), function()
        if not character.Parent then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                Tween:Create(part, TweenInfo.new(self.config.Ragdoll.FadeSeconds), {Transparency = 1}):Play()
            end
        end
    end)
    Debris:AddItem(character, self.config.RespawnSeconds + 2)
end
function Ragdolls:Impulse(character, origin)
    self:Activate(character)
    local rig = self.rigs[character]
    local root = character:FindFirstChild("HumanoidRootPart")
    if not rig or rig.kicked or not root then return end
    rig.kicked = true
    local delta = root.Position - origin
    local flat = Vector3.new(delta.X, 0, delta.Z)
    local direction = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
    local desired = direction * self.config.Ragdoll.Push + Vector3.new(0, self.config.Ragdoll.Lift, 0)
    local seen = {}
    for _, part in ipairs(rig.parts) do
        local assembly = part.Parent and part.AssemblyRootPart
        if assembly and not seen[assembly] and not assembly.Anchored then
            seen[assembly] = true
            assembly:ApplyImpulse((desired - assembly.AssemblyLinearVelocity) * assembly.AssemblyMass)
        end
    end
    root:ApplyAngularImpulse(Vector3.new(direction.Z, 0, -direction.X) * root.AssemblyMass * self.config.Ragdoll.Spin)
end
function Ragdolls:Forget(character) self.rigs[character] = nil end
-- Out of lives: leave a frozen copy of the ragdoll where it fell (crows gather on it client-side).
function Ragdolls:KeepCorpse(character, name)
    local delay = math.max(0.4, self.config.RespawnSeconds - self.config.Ragdoll.FadeSeconds - 0.3)
    task.delay(delay, function()
        if not character.Parent then return end
        local folder = workspace:FindFirstChild("Corpses")
        if not folder then folder = Instance.new("Folder"); folder.Name = "Corpses"; folder.Parent = workspace end
        character.Archivable = true
        local ok, corpse = pcall(function() return character:Clone() end)
        if not ok or not corpse then return end
        for _, d in ipairs(corpse:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Constraint") or d:IsA("Sound")
                or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") or d:IsA("ForceField") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
                d.AssemblyLinearVelocity = Vector3.zero; d.AssemblyAngularVelocity = Vector3.zero
            elseif d:IsA("Humanoid") then
                d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                d.EvaluateStateMachine = false
            end
        end
        corpse.Name = "Corpse"
        corpse.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        corpse:SetAttribute("CorpseOf", name or "")
        corpse:SetAttribute("Ragdolled", true)
        corpse.Parent = folder
        game:GetService("CollectionService"):AddTag(corpse, "Corpse")
    end)
end
function Ragdolls:ClearCorpses()
    local folder = workspace:FindFirstChild("Corpses")
    if folder then folder:ClearAllChildren() end
end
return Ragdolls
