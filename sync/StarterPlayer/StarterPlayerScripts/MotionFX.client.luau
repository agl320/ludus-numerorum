-- Speed and slide immersion:
--   * speed lines streaming out from the edges of the screen as you go fast (sprint, momentum, long falls, slides)
--   * a soft dark edge shade and a slight colour push at speed
--   * a wind rush that rises with speed
--   * air streaks rushing past the camera in a ring around your view while sprinting or sliding (first person)
--   * a burst of lines and an FOV surge (FeelController) the moment you break into a sprint
--   * slide dust and sparks at the feet of every sliding character (visible in first and third person)
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local random = Random.new()

local WIND_ID = "rbxassetid://119669684568685"
local LINES = 26

-- overlay (below the HUD, which sits at DisplayOrder 20)
local gui = Instance.new("ScreenGui")
gui.Name = "MotionFX"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 1
gui.Parent = player:WaitForChild("PlayerGui")
local field = Instance.new("Frame")
field.Name = "SpeedLines"; field.BackgroundTransparency = 1; field.Size = UDim2.fromScale(1, 1); field.Visible = false
field.Parent = gui
local shade = {}
for _, e in ipairs({{UDim2.fromScale(1, 0.24), UDim2.fromScale(0, 0), 90}, {UDim2.fromScale(1, 0.24), UDim2.fromScale(0, 0.76), -90},
    {UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0), 0}, {UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0), 180}}) do
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.fromRGB(12, 6, 10); f.Size = e[1]; f.Position = e[2]
    f.BackgroundTransparency = 1; f.Parent = gui
    local g = Instance.new("UIGradient"); g.Rotation = e[3]
    g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}); g.Parent = f
    table.insert(shade, f)
end
-- centre dot: where you're aiming, shown while the mouse is locked to the view
local UIS = game:GetService("UserInputService")
local dot = Instance.new("Frame")
local dotWasOn = false
dot.Name = "CenterDot"; dot.AnchorPoint = Vector2.new(0.5, 0.5); dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(5, 5); dot.BackgroundColor3 = Color3.fromRGB(255, 244, 236); dot.BorderSizePixel = 0
dot.BackgroundTransparency = 0.05; dot.ZIndex = 5; dot.Visible = false; dot.Parent = gui
do
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = dot
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(10, 4, 6); stroke.Thickness = 1; stroke.Transparency = 0.35; stroke.Parent = dot
end
local lines = {}
local function respawn(line, fresh)
    line.angle = random:NextNumber(0, math.pi * 2)
    -- streaks favour the sides of the screen, where motion reads best
    line.angle = line.angle + math.sin(line.angle * 2) * 0.25
    line.from = random:NextNumber(0.42, 0.62)
    line.to = line.from + random:NextNumber(0.45, 0.7)
    line.length = random:NextNumber(0.07, 0.17)
    line.life = random:NextNumber(0.16, 0.3)
    line.age = fresh and random:NextNumber(0, line.life) or 0
    line.width = random:NextInteger(1, 3)
end
for i = 1, LINES do
    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.fromRGB(255, 240, 228); frame.BackgroundTransparency = 1; frame.Parent = field
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 1)})
    g.Parent = frame
    local line = {frame = frame}
    respawn(line, true)
    lines[i] = line
end

-- air streaks: a ring-shaped emitter ahead of the camera fires thin streaks back past you
local streakPart = Instance.new("Part")
streakPart.Name = "AirStreaks"; streakPart.Transparency = 1; streakPart.Anchored = true
streakPart.CanCollide = false; streakPart.CanQuery = false; streakPart.CanTouch = false; streakPart.CastShadow = false
streakPart.Size = Vector3.new(17, 0.2, 10)
local streaks = Instance.new("ParticleEmitter")
streaks.Name = "Streaks"; streaks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
streaks.Squash = NumberSequence.new(2.8)
streaks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.3)})
streaks.Color = ColorSequence.new(Color3.fromRGB(255, 238, 222))
streaks.LightEmission = 0.8; streaks.LightInfluence = 0
streaks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.5),
    NumberSequenceKeypoint.new(0.75, 0.65), NumberSequenceKeypoint.new(1, 1)})
streaks.Lifetime = NumberRange.new(0.28, 0.4); streaks.Rate = 0
streaks.Speed = NumberRange.new(55, 75); streaks.SpreadAngle = Vector2.new(4, 4)
streaks.EmissionDirection = Enum.NormalId.Top
pcall(function()
    -- a hollow disc: streaks come from a ring around the edge of the view, never straight through the crosshair
    streaks.Shape = Enum.ParticleEmitterShape.Disc
    streaks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    streaks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
    streaks.ShapePartial = 0.55
end)
streaks.Parent = streakPart
streakPart.Parent = workspace.CurrentCamera or workspace

-- colour push at speed (local-only effect)
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "MotionFXGrade"; grade.Parent = Lighting

-- wind rush, routed through the game's SFX volume
local wind = Instance.new("Sound")
wind.Name = "WindRush"; wind.SoundId = WIND_ID; wind.Looped = true; wind.Volume = 0
local eq = Instance.new("EqualizerSoundEffect")
eq.LowGain = -3; eq.MidGain = -2; eq.HighGain = -14; eq.Parent = wind
wind.Parent = SoundService
task.spawn(function()
    local audio = SoundService:WaitForChild("NumberfallAudio", 30)
    local group = audio and audio:WaitForChild("NumberfallSFX", 10)
    if group then wind.SoundGroup = group end
end)

-- slide dust and sparks
local DUST = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local function slideEmitters(root)
    local attachment = Instance.new("Attachment")
    attachment.Name = "SlideFX"; attachment.Parent = root
    local dust = Instance.new("ParticleEmitter")
    dust.Name = "Dust"; dust.Texture = DUST; dust.Enabled = false
    dust.Color = ColorSequence.new(Color3.fromRGB(196, 170, 160), Color3.fromRGB(150, 128, 128))
    dust.LightInfluence = 1; dust.LightEmission = 0
    dust.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.6)})
    dust.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 1)})
    dust.Lifetime = NumberRange.new(0.45, 0.8); dust.Rate = 50
    dust.Speed = NumberRange.new(5, 11); dust.SpreadAngle = Vector2.new(28, 14)
    dust.EmissionDirection = Enum.NormalId.Back; dust.Drag = 4
    dust.Acceleration = Vector3.new(0, 2.5, 0); dust.Rotation = NumberRange.new(0, 360); dust.RotSpeed = NumberRange.new(-60, 60)
    dust.Parent = attachment
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "Sparks"; sparks.Texture = SPARK; sparks.Enabled = false
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 226, 160), Color3.fromRGB(255, 110, 40))
    sparks.LightEmission = 1; sparks.LightInfluence = 0
    sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0)})
    sparks.Lifetime = NumberRange.new(0.16, 0.34); sparks.Rate = 30
    sparks.Speed = NumberRange.new(12, 24); sparks.SpreadAngle = Vector2.new(32, 16)
    sparks.EmissionDirection = Enum.NormalId.Back; sparks.Drag = 2
    sparks.Acceleration = Vector3.new(0, -55, 0)
    sparks.Parent = attachment
    return {attachment = attachment, dust = dust, sparks = sparks, sliding = false}
end
local slides = {}

-- double jump: a puff of air kicked out under the feet (a flat ring of air rushing outward plus a short jet
-- pushed straight down), for every player
local puffHolder = Instance.new("Part")
puffHolder.Name = "AirJumpPuff"; puffHolder.Anchored = true; puffHolder.CanCollide = false; puffHolder.CanQuery = false
puffHolder.CanTouch = false; puffHolder.Transparency = 1; puffHolder.Size = Vector3.new(1.6, 0.1, 1.6) -- ring radius
puffHolder.Parent = workspace
local ring = Instance.new("ParticleEmitter")
ring.Name = "Ring"; ring.Texture = DUST; ring.Enabled = false
ring.Shape = Enum.ParticleEmitterShape.Cylinder; ring.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
ring.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface; ring.ShapePartial = 1
ring.Color = ColorSequence.new(Color3.fromRGB(255, 250, 248), Color3.fromRGB(232, 218, 220))
ring.LightInfluence = 0.2; ring.LightEmission = 0.4
ring.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6)})
ring.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.58), NumberSequenceKeypoint.new(0.4, 0.76), NumberSequenceKeypoint.new(1, 1)})
ring.Lifetime = NumberRange.new(0.3, 0.48); ring.Speed = NumberRange.new(11, 15); ring.Drag = 7
ring.Rotation = NumberRange.new(0, 360); ring.RotSpeed = NumberRange.new(-90, 90)
ring.Parent = puffHolder
local jet = Instance.new("ParticleEmitter")
jet.Name = "Jet"; jet.Texture = DUST; jet.Enabled = false
jet.EmissionDirection = Enum.NormalId.Bottom; jet.SpreadAngle = Vector2.new(22, 22)
jet.Color = ring.Color; jet.LightInfluence = 0.2; jet.LightEmission = 0.4
jet.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 2)})
jet.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.66), NumberSequenceKeypoint.new(1, 1)})
jet.Lifetime = NumberRange.new(0.22, 0.36); jet.Speed = NumberRange.new(10, 16); jet.Drag = 6
jet.Rotation = NumberRange.new(0, 360); jet.RotSpeed = NumberRange.new(-60, 60)
jet.Parent = puffHolder
local puffs = {} -- player -> {seen = last AirJumpAt, at = os.clock() of the last puff}
local function airPuff(root, h)
    local feet = root.Position - Vector3.new(0, h.HipHeight + root.Size.Y / 2 - 0.2, 0)
    puffHolder.CFrame = CFrame.new(feet)
    ring:Emit(22)
    jet:Emit(8)
end

local function approach(a, b, k, dt) return b + (a - b) * math.exp(-k * dt) end
local intensity, rush = 0, 0
local burst, wasSprinting, streakAmount = 0, false, 0
Run.RenderStepped:Connect(function(dt)
    dt = math.min(dt, 0.05)
    local now = workspace:GetServerTimeNow()
    -- every sliding character gets dust and sparks at the leading foot
    for _, other in ipairs(Players:GetPlayers()) do
        local char = other.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local h = char and char:FindFirstChildOfClass("Humanoid")
        local fx = slides[other]
        if fx and (not root or fx.attachment.Parent ~= root) then fx.attachment:Destroy(); slides[other] = nil; fx = nil end
        if root and h then
            -- wall jumps and wall bounces kick out a puff of air (the double jump's updraft is AbilityFX now)
            -- (the local jump and the server's copy of it only puff once)
            local puff = puffs[other]
            if not puff then puff = {seen = {}, at = {}}; puffs[other] = puff
                for _, key in ipairs({"WallJumpAt", "WallBounceAt"}) do puff.seen[key] = char:GetAttribute(key) end
            end
            for _, key in ipairs({"WallJumpAt", "WallBounceAt"}) do
                local at = char:GetAttribute(key)
                if at ~= puff.seen[key] then
                    puff.seen[key] = at
                    local gap = key == "AirJumpAt" and 1 or 0.3
                    if at and now - at < 0.5 and os.clock() - (puff.at[key] or 0) > gap and h.Health > 0 then
                        puff.at[key] = os.clock()
                        airPuff(root, h)
                    end
                end
            end
            local sliding = h.Health > 0 and (char:GetAttribute("SlideUntil") or 0) > now and h.FloorMaterial ~= Enum.Material.Air
            if sliding and not fx then fx = slideEmitters(root); slides[other] = fx end
            if fx then
                local v = root.AssemblyLinearVelocity
                local flat = Vector3.new(v.X, 0, v.Z)
                local direction = char:GetAttribute("SlideDirection")
                if typeof(direction) ~= "Vector3" or Vector3.new(direction.X, 0, direction.Z).Magnitude < 0.1 then
                    direction = flat.Magnitude > 1 and flat or root.CFrame.LookVector
                end
                direction = Vector3.new(direction.X, 0, direction.Z)
                direction = direction.Magnitude > 0.01 and direction.Unit or Vector3.new(0, 0, -1)
                local foot = root.Position - Vector3.new(0, h.HipHeight + root.Size.Y / 2 - 0.35, 0) + direction * 1.3
                fx.attachment.WorldCFrame = CFrame.lookAt(foot, foot + direction)
                local pace = math.clamp(flat.Magnitude / 36, 0.3, 1.2)
                fx.dust.Rate = 55 * pace; fx.sparks.Rate = 34 * pace
                fx.dust.Enabled = sliding; fx.sparks.Enabled = sliding
                if sliding and not fx.sliding then fx.dust:Emit(10); fx.sparks:Emit(8) end
                fx.sliding = sliding
            end
        end
    end
    for other, fx in pairs(slides) do
        if other.Parent ~= Players then fx.attachment:Destroy(); slides[other] = nil end
    end
    for other in pairs(puffs) do if other.Parent ~= Players then puffs[other] = nil end end

    -- local speed effects
    local camera = workspace.CurrentCamera
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local head = char and char:FindFirstChild("Head")
    local alive = camera and root and h and head and h.Health > 0 and player:GetAttribute("InMatch") == true
    local target, windTarget, streakTarget = 0, 0, 0
    local moveDirection
    local firstPerson = false
    local sliding = false
    if alive then
        local v = root.AssemblyLinearVelocity
        local flatSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
        sliding = (char:GetAttribute("SlideUntil") or 0) > now
        firstPerson = (camera.CFrame.Position - (root.Position + Vector3.new(0, 1.5, 0))).Magnitude < 4
        local fast = math.clamp((flatSpeed - 24) / 18, 0, 1) -- sprint (32) already streams, momentum pushes it further
        local falling = math.clamp((-v.Y - 45) / 40, 0, 0.6)
        -- breaking into a sprint fires a burst of lines that settles into the sprint level
        local sprinting = char:GetAttribute("Sprinting") == true and flatSpeed > 26 and not sliding
        if sprinting and not wasSprinting then burst = 1 end
        wasSprinting = sprinting
        target = math.max(fast, falling, sliding and (0.5 + fast * 0.5) or 0, burst * 0.85)
        streakTarget = math.max(math.clamp((flatSpeed - 25) / 14, 0, 1), sliding and 0.7 or 0)
        moveDirection = flatSpeed > 2 and Vector3.new(v.X, 0, v.Z).Unit or nil
        windTarget = math.clamp((v.Magnitude - 18) / 42, 0, 1) + (sliding and 0.2 or 0)
    end
    local reduced = player:GetAttribute("LocalReducedMotion") == true
    local dotOn = alive == true and UIS.MouseBehavior == Enum.MouseBehavior.LockCenter and player:GetAttribute("MouseFree") ~= true
    dot.Visible = dotOn
    -- the dot is the cursor while it's up: hide Roblox's own mouse icon, give it back when the dot goes away
    if dotOn then
        if UIS.MouseIconEnabled then UIS.MouseIconEnabled = false end
    elseif dotWasOn then
        UIS.MouseIconEnabled = true
    end
    dotWasOn = dotOn
    local scale = firstPerson and 1 or 0.55
    intensity = approach(intensity, target * scale, target > intensity and 10 or 5, dt)
    rush = approach(rush, math.min(windTarget, 1), 6, dt)
    burst = approach(burst, 0, 3, dt)

    -- air streaks (first person only)
    streakAmount = approach(streakAmount, (firstPerson and not reduced) and streakTarget or 0, 8, dt)
    if camera and streakPart.Parent ~= camera then streakPart.Parent = camera end
    if camera and moveDirection and streakAmount > 0.02 then
        local center = camera.CFrame.Position + moveDirection * 16 + Vector3.new(0, -0.5, 0)
        streakPart.CFrame = CFrame.lookAt(center, center + moveDirection) * CFrame.Angles(math.pi / 2, 0, 0)
        streaks.Rate = 110 * streakAmount
    else
        streaks.Rate = 0
    end

    -- speed lines
    local lineAmount = reduced and 0 or intensity
    field.Visible = lineAmount > 0.02
    if field.Visible and camera then
        local size = camera.ViewportSize
        local center = size / 2
        local reach = size.Magnitude / 2
        for _, line in ipairs(lines) do
            line.age += dt * (0.8 + lineAmount * 0.6)
            if line.age >= line.life then respawn(line, false) end
            local t = line.age / line.life
            local length = line.length * reach * (0.6 + lineAmount * 0.6)
            local r = (line.from + (line.to - line.from) * t) * reach
            local direction = Vector2.new(math.cos(line.angle), math.sin(line.angle))
            local mid = center + direction * (r + length / 2)
            line.frame.Position = UDim2.fromOffset(mid.X, mid.Y)
            line.frame.Size = UDim2.fromOffset(length, line.width)
            line.frame.Rotation = math.deg(line.angle)
            line.frame.BackgroundTransparency = 1 - lineAmount * 0.55 * math.sin(math.pi * t)
        end
    end
    for _, f in ipairs(shade) do f.BackgroundTransparency = 1 - intensity * 0.32 end
    grade.Contrast = intensity * 0.06
    grade.Saturation = intensity * 0.08

    -- wind
    local windVolume = rush ^ 1.6 * 0.05
    if windVolume > 0.001 then
        if not wind.IsPlaying then wind:Play() end
        wind.Volume = windVolume
        wind.PlaybackSpeed = 0.85 + rush * 0.3
    elseif wind.IsPlaying then
        wind.Volume = 0; wind:Pause()
    end
end)
