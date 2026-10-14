local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Gait = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Gait"))
local Feel = {}
Feel.__index = Feel
local legNames = { ["Left Leg"] = true, ["Right Leg"] = true, LeftUpperLeg = true,
    LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }
function Feel.new(player, config, rules, remote, sound, hud)
    local self = setmetatable({player = player, config = config, rules = rules, remote = remote,
        sound = sound, hud = hud, connections = {}, sprint = false, reduced = false,
        bob = 0, roll = 0, dip = 0, kick = 0, fov = config.Feel.BaseFOV}, Feel)
    UIS.WindowFocusReleased:Connect(function() self:SetSprint(false) end)
    UIS.TextBoxFocused:Connect(function() self:SetSprint(false) end)
    Run:BindToRenderStep("NumberfallCameraFeelRestore", Enum.RenderPriority.Camera.Value - 1, function()
        local camera=workspace.CurrentCamera
        if camera and camera==self.offsetCamera and self.lastOutput==camera.CFrame then camera.CFrame=self.cleanCamera end
        self.offsetCamera=nil;self.lastOutput=nil
    end)
    Run:BindToRenderStep("NumberfallCameraFeel", Enum.RenderPriority.Camera.Value + 1, function(dt) self:Render(dt) end)
    return self
end
function Feel:SetSprint(value)
    if self.sprint==value then return end
    self.sprint = value
    self.remote:FireServer("Sprint", value)
end
function Feel:Slide()
    -- Slides are simulated locally by ParkourController (instant, no server round trip).
    if self.parkour then self.parkour:RequestSlide() end
end
function Feel:ToggleMotion() self.reduced = not self.reduced end
function Feel:Punch(amount) self.kick = math.min(1.2, self.kick + amount) end
function Feel:Spawn(character)
    self:ShowSlideLegs(false)
    for _, c in ipairs(self.connections) do c:Disconnect() end
    self.connections = {}
    self.character = character
    self.legs = {}
    local function track(part)
        if part:IsA("BasePart") and legNames[part.Name] then self.legs[part] = {} end
    end
    for _, part in ipairs(character:GetChildren()) do track(part) end
    table.insert(self.connections, character.ChildAdded:Connect(track))
    self:SetSprint(false)
    self.kick, self.dip, self.roll, self.bob = 0, 0, 0, 0
    self.fov = self.config.Feel.BaseFOV
    self.dashSeen, self.dashStart = character:GetAttribute("DashAt"), nil
    task.spawn(function()
        local h = character:WaitForChild("Humanoid", 8)
        if not h or self.character ~= character then return end
        table.insert(self.connections, h.StateChanged:Connect(function(_, state)
            if state == Enum.HumanoidStateType.Landed then
                -- only a real fall lands (moving down), once per landing: the fall speed is used up here so a
                -- jump straight after landing can't replay the sound with the old value
                local fall = -(self.fallVelocity or 0)
                self.fallVelocity = 0
                -- hopping (landing again within ~1s of the last landing) stays quiet; longer jumps, double jumps and
                -- real drops still land with a sound
                local sinceLast = os.clock() - (self.landedAt or -math.huge)
                if fall > 4 then self.landedAt = os.clock() end
                local fresh = sinceLast > 1.1 or fall > 60
                self.dip = math.min(0.22, math.max(fall, 0) / 220)
                if fall > 12 and fresh then self.sound:Play("Land") end
            end
        end))
    end)
end
function Feel:ShowSlideLegs(visible)
    -- Run after the stock camera so the extended foot is visible in first person.
    for part, state in pairs(self.legs or {}) do
        if not part.Parent then self.legs[part] = nil
        elseif visible then
            if state.original == nil then state.original = part.LocalTransparencyModifier end
            part.LocalTransparencyModifier = 0
        elseif state.original ~= nil then
            part.LocalTransparencyModifier = state.original
            state.original = nil
        end
    end
end
function Feel:Render(dt)
    if not self.player:GetAttribute("InMatch") then self:ShowSlideLegs(false);return end
    dt = math.min(dt, 0.06)
    local char, camera = self.character, workspace.CurrentCamera
    if not camera then return end
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local alive = h and root and h.Health > 0
    local now = workspace:GetServerTimeNow()
    local sliding = alive and self.parkour ~= nil and self.parkour.sliding == true
    local head = char and char:FindFirstChild("Head")
    local firstPerson = root and (camera.CFrame.Position - (root.Position + Vector3.new(0, 1.5, 0))).Magnitude < 4
    self:ShowSlideLegs(sliding and firstPerson)
    local running = alive and self.sprint
    local speed = alive and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
    local grounded = alive and h.FloorMaterial ~= Enum.Material.Air
    if alive and not grounded then self.fallVelocity = root.AssemblyLinearVelocity.Y end
    local cfg = self.config.Feel
    local motion = self.reduced and 0 or cfg.MotionScale
    local base = cfg.BaseFOV
    local targetFov = base
    if motion > 0 then
        -- FOV opens up with speed: run speed reaches the sprint FOV, momentum beyond it keeps widening the view
        local mv = self.config.Movement
        local run = math.clamp(speed / mv.SprintSpeed, 0, 1)
        local over = math.clamp((speed - mv.SprintSpeed) / math.max(1, mv.MaxSpeed - mv.SprintSpeed), 0, 1)
        targetFov = base + (cfg.SprintFOV - cfg.BaseFOV) * run + (cfg.SpeedFOV or 10) * over
        if sliding then targetFov = math.max(targetFov, base + (cfg.SlideFOV - cfg.BaseFOV)) end
    end
    self.fov = self.rules.Approach(self.fov, targetFov, 10, dt)
    -- sprint start: a quick FOV surge that settles into the sprint FOV
    local sprintingNow = alive and grounded and not sliding and self.sprint and speed > 26
    if sprintingNow and not self.wasSprinting then self.punch = 1 end
    self.wasSprinting = sprintingNow
    self.punch = self.rules.Approach(self.punch or 0, 0, 4, dt)
    -- hard cap (Config.Feel.MaxFOV): the speed surge and kicks never widen the view past it
    -- dash: the view snaps wider for a moment and eases back (like Apex), allowed past the cap while it lasts
    local dashAt = char and char:GetAttribute("DashAt")
    if dashAt ~= self.dashSeen then
        self.dashSeen = dashAt
        if alive and dashAt and now - dashAt < 0.5 then self.dashStart = os.clock() end
    end
    local dashK = 0
    if self.dashStart then
        local t = os.clock() - self.dashStart
        if t < 0.07 then dashK = t / 0.07
        elseif t < 0.2 then dashK = 1
        elseif t < 0.6 then dashK = 0.5 * (1 + math.cos(math.pi * (t - 0.2) / 0.4))
        else self.dashStart = nil end
    end
    local dashFov = self.reduced and 0 or (cfg.DashFOV or 12) * dashK
    camera.FieldOfView = math.min(cfg.MaxFOV or 80, self.fov + self.kick * motion * 2 + self.punch * 5 * motion) + dashFov
    local lateral = alive and camera.CFrame.RightVector:Dot(h.MoveDirection) or 0
    self.roll = self.rules.Approach(self.roll, alive and (-lateral * 0.018 + (sliding and -0.035 or 0)) or 0, 12, dt)
    self.bobWeight=self.rules.Approach(self.bobWeight or 0,alive and grounded and not sliding and math.clamp(speed/24,0,1)or 0,12,dt)
    self.sprintWeight=self.rules.Approach(self.sprintWeight or 0,alive and grounded and not sliding and (self.sprint or speed>30) and math.clamp((speed-24)/6,0,1) or 0,8,dt)
    -- head bob on the same stride as the body and the arms: a soft dip at each footfall, plus a slight
    -- side-to-side sway when sprinting. Smooth curves only, no noise.
    if alive and grounded and not sliding and speed > 1 then
        self.bob = (self.bob + dt * Gait.Cadence(Gait.Params(self.sprintWeight), speed)) % 1
    end
    local stride = (firstPerson and Gait.LocalPhase or self.bob) * math.pi * 2
    local bob = -(1 + math.cos(stride * 2)) * 0.5 * (.045 + .03 * self.sprintWeight) * self.bobWeight
    local sway = math.sin(stride) * .016 * self.sprintWeight * self.bobWeight
    local lower = sliding and -0.64 or 0
    self.lower = self.rules.Approach(self.lower or 0, lower, 14, dt)
    -- The stock first-person camera updates first; offsets never accumulate across frames.
    if alive and firstPerson then
        -- Preserve the user's exact aim. Post-camera pitch/roll feeds back into
        -- the stock camera on subsequent frames and can drive the view downward.
        self.cleanCamera=camera.CFrame;self.offsetCamera=camera
        camera.CFrame = CFrame.new(0,(bob-self.dip+self.lower)*motion,0)*self.cleanCamera*CFrame.new(sway*motion,0,0)
        self.lastOutput=camera.CFrame
    end
    self.kick = self.rules.Approach(self.kick, 0, 18, dt)
    self.dip = self.rules.Approach(self.dip, 0, 13, dt)
    local cooldown = self.parkour and math.max(0, (self.parkour.boostReadyAt or 0) - os.clock()) or 0
    self.hud:SetMovement(sliding, running, cooldown, self.reduced)
end
return Feel
