-- Living sunset city (client-side, nothing replicates):
--   * soundscape: rooftop wind, evening air, water lapping along the canal, crows over the spires
--   * crows circling the cathedral and skyline spires, and a flock that crosses the sky now and then
--   * chimney smoke, canal mist, warm dust motes drifting in the low sun
--   * street lamps that flicker, candle-lit windows that breathe
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local random = Random.new()

local city = workspace:WaitForChild("SunsetCity", 30)
if not city then return end
-- The city streams in around you (it is no longer sent whole at join), so nothing here waits for it: the fixed
-- spots (canal, spires, crow perches, chimneys) come from ReplicatedStorage.Numberfall.AmbienceData, and lamps /
-- windows are picked up as their parts stream in.
local AD = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("AmbienceData"))
local WIND = Vector3.new(-0.74, 0, -0.67) -- matches the drifting petals

local folder = Instance.new("Folder")
folder.Name = "Ambience"; folder.Parent = workspace
-- invisible anchor for positional sounds and emitters
local function anchorAt(name, position)
    local p = Instance.new("Part")
    p.Name = name; p.Size = Vector3.new(0.2, 0.2, 0.2); p.Transparency = 1
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Position = position; p.Parent = folder
    return p
end

------------------------------------------------------------------ sound
local group = Instance.new("SoundGroup")
group.Name = "Ambience"; group.Volume = 0.85; group.Parent = SoundService
task.spawn(function()
    local audio = SoundService:WaitForChild("NumberfallAudio", 30)
    local master = audio and audio:WaitForChild("NumberfallSFX", 10)
    if not master then return end
    local function sync() group.Volume = master.Volume end
    master:GetPropertyChangedSignal("Volume"):Connect(sync)
    sync()
end)
local function loop(id, volume, parent, minDistance, maxDistance, treble)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id; s.Looped = true; s.Volume = volume; s.SoundGroup = group
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance = minDistance or 10; s.RollOffMaxDistance = maxDistance or 120
    if treble then local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = treble; eq.Parent = s end
    s.Parent = parent or SoundService
    s:Play()
    return s
end
loop(9114057128, 2, nil, nil, nil, -4)      -- light whistling rooftop wind (a very quiet recording, hence the high volume)
loop(9112834179, 0.06, nil, nil, nil, -4)   -- far-off evening air: crickets, a distant dog
-- water lapping at the canal walls (the canal runs along X at the Water part)
local water = AD.Water
if water then
    local half = math.min(water.Size.X / 2, 160)
    for i = -2, 2 do
        local anchor = anchorAt("CanalSound", water.Position + Vector3.new(i * half / 2, water.Size.Y / 2 + 0.5, 0))
        local s = loop(9120570701, 0.45, anchor, 8, 70)
        s.TimePosition = random:NextNumber(0, 20)
    end
end

------------------------------------------------------------------ crows
-- crow calls, each with a volume that evens out its loudness
local CROWS = {{130700387062990, 0.09}, {75610222559518, 0.1}, {89659350030351, 0.037}} -- (5829815715 removed: low quality)
local BLACK = Color3.fromRGB(18, 14, 18)
local function part(size)
    local p = Instance.new("Part")
    p.Size = size; p.Color = BLACK; p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Parent = folder
    return p
end
local S = 1 -- (the crow mesh is already built at sky-readable size)
-- crow mesh (ReplicatedStorage.Numberfall.CrowModel): a body and two wings that hinge at the shoulders
local template = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("CrowModel", 10)
local REST = {}
if template then
    local b = template.Body.CFrame
    REST.Left = b:ToObjectSpace(template.LeftWing.CFrame)
    REST.Right = b:ToObjectSpace(template.RightWing.CFrame)
end
local SHOULDER = {Left = Vector3.new(-0.55, 0.45, -0.15), Right = Vector3.new(0.55, 0.45, -0.15)}
local function meshPart(name, size)
    local p = template[name]:Clone()
    p.Size = p.Size * size
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Parent = folder
    return p
end
local function newBird(size)
    local b = {offset = random:NextNumber(0, 10), flapRate = random:NextNumber(9, 12), size = size or 1}
    if template then
        b.body, b.left, b.right = meshPart("Body", b.size), meshPart("LeftWing", b.size), meshPart("RightWing", b.size)
    else
        b.body = part(Vector3.new(0.9, 0.75, 2.7)); b.left = part(Vector3.new(2.7, 0.15, 1.3)); b.right = part(Vector3.new(2.7, 0.15, 1.3))
    end
    return b
end
local function center(model, fallback)
    if model and model:IsA("Model") then
        local cf, size = model:GetBoundingBox()
        return cf.Position + Vector3.new(0, size.Y / 2, 0)
    end
    return fallback
end
local cathedralTop = AD.CathedralTop or Vector3.new(1188, 100, 180)
local skylineTop = AD.SkylineTop or Vector3.new(1012, 121, 222)
local mapCenter = AD.MapCenter or Vector3.new(1220, 0, 160)
local flocks = {
    {center = cathedralTop + Vector3.new(0, 6, 0), radius = 30, speed = 0.32, birds = {}, count = 5},
    -- (the skyline spires stand outside the playable map: their flock now circles the cathedral's west end instead)
    {center = cathedralTop + Vector3.new(-26, -14, 30), radius = 22, speed = -0.27, birds = {}, count = 4},
}
-- an even grid of small flocks over the whole city (in the city's own frame), each a little jittered
do
    local root = city:GetAttribute("RootCF")
    if typeof(root) == "CFrame" then
        local i = 0
        for _, z in ipairs({70, -60, -190, -320}) do
            for _, x in ipairs({-135, -45, 45, 135}) do
                i += 1
                local nearCathedral = math.abs(x) < 60 and z < -280
                if not nearCathedral then
                    local p = root * Vector3.new(x + random:NextNumber(-15, 15), 0, z + random:NextNumber(-15, 15))
                    table.insert(flocks, {center = Vector3.new(p.X, random:NextNumber(58, 82), p.Z), radius = random:NextNumber(18, 28),
                        speed = (i % 2 == 0 and 1 or -1) * random:NextNumber(0.22, 0.32), birds = {}, count = 3})
                end
            end
        end
    else
        table.insert(flocks, {center = Vector3.new(mapCenter.X + 120, 70, mapCenter.Z - 60), radius = 38, speed = 0.22, birds = {}, count = 5})
        table.insert(flocks, {center = Vector3.new(mapCenter.X - 60, 62, mapCenter.Z - 120), radius = 28, speed = 0.3, birds = {}, count = 4})
    end
end
for _, flock in ipairs(flocks) do
    for i = 1, flock.count do
        local b = newBird(0.75)
        b.angle = (i / flock.count) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
        b.radius = flock.radius * random:NextNumber(0.75, 1.25)
        b.height = random:NextNumber(-6, 8)
        table.insert(flock.birds, b)
    end
end
-- a passing flock that crosses the sky every so often
local passing = {birds = {}, active = false, start = 0, nextAt = os.clock() + random:NextNumber(15, 30)}
for i = 1, 7 do
    local b = newBird(0.8)
    b.slot = Vector3.new((i - 4) * 6 + random:NextNumber(-2, 2), random:NextNumber(-4, 4), math.abs(i - 4) * 6 + random:NextNumber(-1.5, 1.5))
    table.insert(passing.birds, b)
end
local hidden = CFrame.new(0, -500, 0)
-- crows perched on the roof ridges; they take off when someone gets close, circle away and come back later
local perches = {}
do
    -- (spots on roof ridges, one per 55-stud cell across the city: AmbienceData.Perches)
    for _, spot in ipairs(AD.Perches or {}) do
        local yaw = random:NextNumber(0, math.pi * 2)
        local b = newBird(0.3)
        b.home = CFrame.new(spot) * CFrame.Angles(0, yaw, 0)
        b.state = "perched"; b.since = os.clock()
        table.insert(perches, b)
    end
end
-- wing pose around the shoulder hinge: `lift` rotates the wing up/down (0 = the mesh's raised rest pose),
-- `sweep` folds it back along the body (perched)
local function wing(cf, side, lift, sweep, size)
    local rest = REST[side]
    if not rest then return cf end
    rest = rest - rest.Position + rest.Position * size
    local hinge = SHOULDER[side] * size
    local sign = side == "Left" and 1 or -1
    return cf * CFrame.new(hinge) * CFrame.Angles(0, sweep * sign, lift * sign) * CFrame.new(-hinge) * rest
end
local function poseBird(b, cf, t, parts, frames, perched)
    local lift, sweep
    if perched then
        -- folded and still, the odd shake
        lift, sweep = 1.05 + math.max(0, math.sin(t * 3 + b.offset * 7) - 0.97) * 12, 1.25
    else
        -- flap in bursts, glide in between (rest pose is a raised V; gliding holds the wings flatter)
        local cycle = (t * 0.25 + b.offset) % 1
        local flapping = cycle < 0.45
        lift = flapping and (0.35 + math.sin(t * b.flapRate + b.offset) * 0.7) or (0.55 + math.sin(t * 2 + b.offset) * 0.05)
        sweep = 0
    end
    table.insert(parts, b.body); table.insert(frames, cf)
    table.insert(parts, b.left); table.insert(frames, wing(cf, "Left", lift, sweep, b.size))
    table.insert(parts, b.right); table.insert(frames, wing(cf, "Right", lift, sweep, b.size))
end
local function caw(position)
    local anchor = anchorAt("Caw", position)
    local s = Instance.new("Sound")
    local call = CROWS[random:NextInteger(1, #CROWS)]
    s.SoundId = "rbxassetid://" .. call[1]
    s.Volume = call[2] * random:NextNumber(0.85, 1.1); s.PlaybackSpeed = random:NextNumber(0.9, 1.08); s.SoundGroup = group
    s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = 30; s.RollOffMaxDistance = 320
    local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = -5; eq.Parent = s
    s.Parent = anchor
    s.Ended:Once(function() anchor:Destroy() end)
    s:Play()
    task.delay(8, function() if anchor.Parent then anchor:Destroy() end end)
end
local nextCaw = os.clock() + random:NextNumber(6, 12)

-- crows gathering over (and landing on) the bodies of players who are out of lives
local CollectionService = game:GetService("CollectionService")
local corpses = {}
local BODY = {"UpperTorso", "Torso", "LowerTorso", "Head", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "RightUpperArm"}
local function corpseCenter(m)
    local p = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
    return p and p.Position
end
local function addCorpse(m)
    if corpses[m] or not m:IsDescendantOf(workspace) then return end
    task.wait(0.2)
    local center = corpseCenter(m)
    if not center then return end
    local c = {model = m, center = center, circling = {}, landed = {}, nextCaw = os.clock() + random:NextNumber(1, 4)}
    for i = 1, 6 do
        local b = newBird(0.42)
        b.angle = i / 6 * math.pi * 2 + random:NextNumber(-0.4, 0.4)
        b.radius = random:NextNumber(4, 8); b.height = random:NextNumber(6, 12)
        b.spin = (random:NextNumber() < 0.5 and -1 or 1) * random:NextNumber(0.8, 1.3)
        table.insert(c.circling, b)
    end
    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = {m}
    local spots = {}
    for _, name in ipairs(BODY) do
        local part = m:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            local hit = workspace:Raycast(part.Position + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), params)
            if hit then table.insert(spots, hit.Position) end
        end
    end
    if #spots == 0 then spots = {center + Vector3.new(0, 0.6, 0)} end
    for i = 1, math.min(3, #spots + 1) do
        local b = newBird(0.3)
        local spot = table.remove(spots, random:NextInteger(1, #spots)) or center
        b.home = CFrame.new(spot + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
        b.state = "arriving"; b.since = os.clock() + i * 1.4
        if #spots == 0 then spots = {center + Vector3.new(random:NextNumber(-1.5, 1.5), 0.4, random:NextNumber(-1.5, 1.5))} end
        table.insert(c.landed, b)
    end
    corpses[m] = c
    if random:NextNumber() < 0.7 then caw(center + Vector3.new(0, 8, 0)) end
end
local function removeCorpse(m)
    local c = corpses[m]
    if not c then return end
    corpses[m] = nil
    for _, list in ipairs({c.circling, c.landed}) do
        for _, b in ipairs(list) do for _, p in ipairs({b.body, b.left, b.right}) do p:Destroy() end end
    end
end
CollectionService:GetInstanceAddedSignal("Corpse"):Connect(function(m) task.spawn(addCorpse, m) end)
CollectionService:GetInstanceRemovedSignal("Corpse"):Connect(removeCorpse)
for _, m in ipairs(CollectionService:GetTagged("Corpse")) do task.spawn(addCorpse, m) end
local function stepCorpses(t, dt, parts, frames)
    for m, c in pairs(corpses) do
        if not m.Parent then removeCorpse(m) continue end
        -- anyone alive standing close scares the landed ones up for a while
        local scared = false
        for _, other in ipairs(Players:GetPlayers()) do
            local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
            if r and (r.Position - c.center).Magnitude < 9 then scared = true break end
        end
        for _, b in ipairs(c.circling) do
            b.angle += dt * b.spin * (6 / b.radius)
            local r = b.radius + math.sin(t * 0.7 + b.offset) * 1.5
            local pos = c.center + Vector3.new(math.cos(b.angle) * r, b.height + math.sin(t * 1.1 + b.offset) * 1.5, math.sin(b.angle) * r)
            local tangent = Vector3.new(-math.sin(b.angle), 0, math.cos(b.angle)) * math.sign(b.spin)
            poseBird(b, CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, 0.5 * math.sign(b.spin)), t * 1.2, parts, frames)
        end
        for _, b in ipairs(c.landed) do
            local above = b.home.Position + Vector3.new(math.cos(b.offset * 5) * 6, 10, math.sin(b.offset * 5) * 6)
            if scared and b.state ~= "flushed" and b.state ~= "waiting" then b.state = "flushed"; b.since = t end
            if b.state == "waiting" or (b.state == "arriving" and t < b.since) then
                for _, p in ipairs({b.body, b.left, b.right}) do table.insert(parts, p); table.insert(frames, hidden) end
                if b.state == "waiting" and t > b.since and not scared then b.state = "arriving"; b.since = t end
            elseif b.state == "arriving" then
                local k = math.clamp((t - b.since) / 1.6, 0, 1)
                local e = 1 - (1 - k) ^ 2
                local pos = above:Lerp(b.home.Position, e)
                local look = (b.home.Position - above); look = Vector3.new(look.X, 0, look.Z).Unit
                poseBird(b, CFrame.lookAt(pos, pos + look) * CFrame.Angles(0.3 * (1 - k), 0, 0), t * 1.3, parts, frames, false)
                if k >= 1 then b.state = "perched"; b.since = t; b.nextHop = t + random:NextNumber(6, 14) end
            elseif b.state == "perched" then
                -- pecking at the body
                local peck = math.max(0, math.sin(t * 5 + b.offset * 9)) ^ 6 * 0.7
                local turn = math.sin(t * 0.5 + b.offset) * 0.6
                poseBird(b, b.home * CFrame.Angles(0, turn, 0) * CFrame.Angles(-peck, 0, 0), t, parts, frames, true)
                if t > b.nextHop then b.state = "hop"; b.since = t end
            elseif b.state == "hop" then
                local k = math.clamp((t - b.since) / 0.6, 0, 1)
                local cf = b.home * CFrame.new(0, math.sin(k * math.pi) * 1.2, 0)
                poseBird(b, cf, t * 2, parts, frames, false)
                if k >= 1 then
                    b.home = b.home * CFrame.Angles(0, random:NextNumber(-2, 2), 0)
                    b.state = "perched"; b.since = t; b.nextHop = t + random:NextNumber(6, 14)
                end
            elseif b.state == "flushed" then
                local k = t - b.since
                local pos = b.home.Position + Vector3.new(math.cos(b.offset * 5) * k * 9, math.min(k, 2) * 7, math.sin(b.offset * 5) * k * 9)
                local dir = Vector3.new(math.cos(b.offset * 5), 0.5, math.sin(b.offset * 5)).Unit
                poseBird(b, CFrame.lookAt(pos, pos + dir), t * 1.3, parts, frames, false)
                if k > 2.5 then b.state = "waiting"; b.since = t + random:NextNumber(4, 8) end
            end
        end
        if t >= c.nextCaw then
            c.nextCaw = t + random:NextNumber(5, 11)
            caw(c.center + Vector3.new(0, 6, 0))
        end
    end
end

------------------------------------------------------------------ smoke, mist, motes
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
-- (the same chimneys for every player: AmbienceData.Smoke)
for _, top in ipairs(AD.Smoke or {}) do
    do
        local a = anchorAt("ChimneySmoke", top)
        local e = Instance.new("ParticleEmitter")
        e.Texture = SMOKE
        -- (a sooty grey that reads against the red sky: the old pinkish smoke all but vanished into it)
        e.Color = ColorSequence.new(Color3.fromRGB(104, 96, 100), Color3.fromRGB(176, 166, 170)) -- (lighter + a touch self-lit: shows against the night sky)
        e.LightInfluence = 0.35; e.LightEmission = 0.12
        e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(0.5, 7.5), NumberSequenceKeypoint.new(1, 14)})
        e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.06, 0.12),
            NumberSequenceKeypoint.new(0.6, 0.45), NumberSequenceKeypoint.new(1, 1)})
        e.Lifetime = NumberRange.new(8, 12); e.Rate = random:NextNumber(5, 6.5)
        e.Speed = NumberRange.new(2, 3.4); e.SpreadAngle = Vector2.new(8, 8); e.EmissionDirection = Enum.NormalId.Top
        e.Acceleration = WIND * 1.1 + Vector3.new(0, 0.25, 0); e.Drag = 0.25
        e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-14, 14)
        e.Parent = a
    end
end
-- mist hanging over the canal
if water then
    local mist = Instance.new("Part")
    mist.Name = "CanalMist"; mist.Transparency = 1; mist.Anchored = true; mist.CanCollide = false; mist.CanQuery = false; mist.CanTouch = false
    mist.Size = Vector3.new(math.min(water.Size.X, 520), 2, water.Size.Z * 0.9)
    mist.Position = water.Position + Vector3.new(0, water.Size.Y / 2 + 1.6, 0)
    mist.Parent = folder
    local e = Instance.new("ParticleEmitter")
    e.Texture = SMOKE; e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    e.Color = ColorSequence.new(Color3.fromRGB(236, 176, 176), Color3.fromRGB(205, 150, 175))
    e.LightInfluence = 1; e.LightEmission = 0.1
    e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 13)})
    e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86),
        NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1)})
    e.Lifetime = NumberRange.new(12, 18); e.Rate = 7
    e.Speed = NumberRange.new(0.2, 0.6); e.SpreadAngle = Vector2.new(180, 10)
    e.Acceleration = WIND * 0.2; e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-6, 6)
    e.Parent = mist
end
-- warm dust motes drifting around the player
local motes = Instance.new("Part")
motes.Name = "DustMotes"; motes.Transparency = 1; motes.Anchored = true; motes.CanCollide = false; motes.CanQuery = false; motes.CanTouch = false
motes.Size = Vector3.new(70, 30, 70); motes.Parent = folder
do
    local e = Instance.new("ParticleEmitter")
    e.Texture = SPARKLE; e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    e.Color = ColorSequence.new(Color3.fromRGB(255, 214, 170))
    e.LightEmission = 0.7; e.LightInfluence = 0.3
    e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0.1)})
    e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.35),
        NumberSequenceKeypoint.new(0.75, 0.45), NumberSequenceKeypoint.new(1, 1)})
    e.Lifetime = NumberRange.new(6, 10); e.Rate = 34
    e.Speed = NumberRange.new(0.2, 0.9); e.SpreadAngle = Vector2.new(180, 180)
    e.Acceleration = WIND * 0.35 + Vector3.new(0, 0.08, 0); e.Drag = 0.4
    e.Parent = motes
end

------------------------------------------------------------------ lamps and windows
local lamps = {}
local lampOf = {}
local function addLamp(light)
    if lampOf[light] then return end
    if light:IsA("PointLight") and light.Enabled and light.Parent and light.Parent:IsA("BasePart") and light:FindFirstAncestor("Lamp") then
        local lamp = {light = light, base = light:GetAttribute("BaseBrightness") or light.Brightness, seed = random:NextNumber(0, 100), pos = light.Parent.Position}
        table.insert(lamps, lamp)
        lampOf[light] = lamp
    end
end
local windows = {}
local glowColors = {["Bright orange"] = true, ["Neon orange"] = true, ["Flame reddish orange"] = true}
local function addWindow(d)
    if d:IsA("BasePart") and d.Material == Enum.Material.Neon and glowColors[d.BrickColor.Name] and #windows < 60 and random:NextNumber() < 0.22 then
        local h, s, v = d.Color:ToHSV()
        table.insert(windows, {part = d, h = h, s = s, v = v, seed = random:NextNumber(0, 100)})
    end
end
-- what has streamed in so far, then everything that streams in later (and forget what streams back out)
for _, d in ipairs(city:GetDescendants()) do
    if d:IsA("PointLight") then addLamp(d) elseif d:IsA("BasePart") then addWindow(d) end
end
city.DescendantAdded:Connect(function(d)
    if d:IsA("PointLight") then task.defer(addLamp, d) elseif d:IsA("BasePart") then addWindow(d) end
end)
city.DescendantRemoving:Connect(function(d)
    if d:IsA("PointLight") and lampOf[d] then
        local lamp = lampOf[d]; lampOf[d] = nil
        local i = table.find(lamps, lamp); if i then table.remove(lamps, i) end
    elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
        for i = #windows, 1, -1 do if windows[i].part == d then table.remove(windows, i) end end
    end
end)

------------------------------------------------------------------ per frame
local lastSlow = 0
local frameNo = 0
-- only lamps near the camera flicker (changing hundreds of lights every frame is expensive)
local nearLamps, lastNear = {}, 0
local NEAR = 150
local function refreshNear(camPos)
    table.clear(nearLamps)
    for _, lamp in ipairs(lamps) do
        local near = (lamp.pos - camPos).Magnitude < NEAR
        -- (Scale: day/night level and glare guard from StarterPlayerScripts.LampLevel)
        local base = lamp.base * (lamp.light:GetAttribute("Scale") or 1)
        if near then table.insert(nearLamps, lamp) elseif lamp.light.Parent and math.abs(lamp.light.Brightness - base) > 0.005 then lamp.light.Brightness = base end
    end
end
Run.RenderStepped:Connect(function(dt)
    local t = os.clock()
    local camera = workspace.CurrentCamera
    if camera then motes.CFrame = CFrame.new(camera.CFrame.Position) end
    -- crows: only while the camera is anywhere near the city (nothing to animate from the lobby or the menu)
    local far = camera ~= nil and (camera.CFrame.Position - mapCenter).Magnitude > 900
    if not far then
    local parts, frames = {}, {}
    frameNo += 1
    local camAt = camera and camera.CFrame.Position
    for _, flock in ipairs(flocks) do
        -- (far flocks are re-posed every third frame: you can't tell from there, and it's a lot of parts)
        local farFlock = camAt ~= nil and (flock.center - camAt).Magnitude > 260 and frameNo % 3 ~= 0
        for _, b in ipairs(flock.birds) do
            b.angle += dt * flock.speed * (30 / b.radius)
            if farFlock then continue end
            local r = b.radius + math.sin(t * 0.3 + b.offset) * 4
            local pos = flock.center + Vector3.new(math.cos(b.angle) * r, b.height + math.sin(t * 0.5 + b.offset) * 3, math.sin(b.angle) * r)
            local tangent = Vector3.new(-math.sin(b.angle), 0, math.cos(b.angle)) * math.sign(flock.speed)
            local bank = 0.35 * math.sign(flock.speed)
            poseBird(b, CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, bank), t, parts, frames)
        end
    end
    if not passing.active and t >= passing.nextAt then
        passing.active = true; passing.start = t
        local heading = random:NextNumber(0, math.pi * 2)
        passing.dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
        -- across the city inside its walls: from one edge of the play area to the other (city frame x +-200, z -415..110)
        local root = city:GetAttribute("RootCF")
        local mid = Vector3.new(1300, random:NextNumber(85, 120), 140)
        local span = 420
        if typeof(root) == "CFrame" then
            local c = root * Vector3.new(0, 0, -152)
            mid = Vector3.new(c.X, random:NextNumber(85, 120), c.Z)
            local d = root:VectorToObjectSpace(passing.dir)
            local tx = math.abs(d.X) > 1e-3 and 200 / math.abs(d.X) or math.huge
            local tz = math.abs(d.Z) > 1e-3 and 262 / math.abs(d.Z) or math.huge
            span = math.min(tx, tz)
        end
        passing.from = mid - passing.dir * span; passing.span = span * 2; passing.duration = math.max(14, span * 2 / 24.7)
        if random:NextNumber() < 0.6 then task.delay(passing.duration * 0.45, function() caw(mid) end) end
    end
    if passing.active then
        local k = (t - passing.start) / passing.duration
        if k >= 1 then
            passing.active = false; passing.nextAt = t + random:NextNumber(45, 90)
        else
            local leader = passing.from + passing.dir * ((passing.span or 840) * k)
            local cf = CFrame.lookAt(leader, leader + passing.dir)
            for _, b in ipairs(passing.birds) do
                local wobble = Vector3.new(0, math.sin(t * 0.8 + b.offset) * 1.2, 0)
                poseBird(b, cf * CFrame.new(b.slot) + wobble, t, parts, frames)
            end
        end
    end
    if not passing.active then
        for _, b in ipairs(passing.birds) do
            for _, p in ipairs({b.body, b.left, b.right}) do table.insert(parts, p); table.insert(frames, hidden) end
        end
    end
    -- perched crows
    local camPos = camera and camera.CFrame.Position
    for _, b in ipairs(perches) do
        -- perched crows far from you sit still (posed once, then left alone until you come near)
        local farPerch = b.state == "perched" and camPos ~= nil and (b.home.Position - camPos).Magnitude > 140
        if farPerch and b.posedFar then continue end
        b.posedFar = farPerch or nil
        if b.state == "perched" then
            local near = false
            for _, other in ipairs(Players:GetPlayers()) do
                local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
                if r and (r.Position - b.home.Position).Magnitude < 16 then near = true break end
            end
            -- small head bob / turn while sitting
            local bob = math.max(0, math.sin(t * 1.3 + b.offset * 3) - 0.9) * 3
            poseBird(b, b.home * CFrame.Angles(0, math.sin(t * 0.4 + b.offset) * 0.25, 0) * CFrame.Angles(-0.1 - bob * 0.15, 0, 0), t, parts, frames, true)
            if near then
                b.state = "flying"; b.since = t
                local away = Vector3.new(math.cos(b.offset * 9), 0, math.sin(b.offset * 9))
                -- (towards the middle of the map, give or take, so they never fly out over the walls)
                local toMid = Vector3.new(mapCenter.X - b.home.Position.X, 0, mapCenter.Z - b.home.Position.Z)
                if toMid.Magnitude > 1 then away = (toMid.Unit * 1.6 + away * 0.6).Unit end
                b.flyDir = away
                if random:NextNumber() < 0.5 then caw(b.home.Position) end
            end
        else
            local k = t - b.since
            if k > 14 then
                b.state = "perched"; b.since = t
            else
                -- burst up and away, then off out of sight; it comes back to the same spot later
                local climb = math.min(k, 3) * 9 + math.max(0, k - 3) * 2
                local pos = b.home.Position + b.flyDir * (k * 22) + Vector3.new(0, climb, 0)
                local look = (b.flyDir + Vector3.new(0, k < 3 and 0.45 or 0.08, 0)).Unit
                if k > 9 then pos = hidden.Position end
                poseBird(b, CFrame.lookAt(pos, pos + look), t * 1.25, parts, frames, false)
            end
        end
    end
    stepCorpses(t, dt, parts, frames)
    workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
    if t >= nextCaw then
        nextCaw = t + random:NextNumber(9, 22)
        local flock = flocks[random:NextInteger(1, #flocks)]
        local b = flock.birds[random:NextInteger(1, #flock.birds)]
        caw(b.body.Position)
    end
    end
    -- lamps and windows flicker at 20 Hz
    if camera and t - lastNear >= 0.5 then
        lastNear = t
        refreshNear(camera.CFrame.Position)
    end
    if t - lastSlow >= 0.066 then
        lastSlow = t
        for _, lamp in ipairs(nearLamps) do
            if lamp.light.Parent then
                local n = math.noise(t * 3.1, lamp.seed) + math.noise(t * 11, lamp.seed, 1) * 0.35
                lamp.light.Brightness = lamp.base * (lamp.light:GetAttribute("Scale") or 1) * (1 + n * 0.22)
            end
        end
        for _, w in ipairs(windows) do
            if w.part.Parent then
                local n = math.noise(t * 1.7, w.seed) + math.noise(t * 6, w.seed, 2) * 0.3
                w.part.Color = Color3.fromHSV(w.h, w.s, math.clamp(w.v * (0.86 + n * 0.25), 0, 1))
            end
        end
    end
end)
