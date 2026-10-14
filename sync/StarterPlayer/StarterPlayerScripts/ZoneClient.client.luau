-- Closing zone visuals: a ring of force-field wall that shrinks onto the safe circle, an outline on anyone caught
-- outside it, and a tinted screen + countdown + arrow back to safety when you are outside. Colour: ZoneRules.Color.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = RS:WaitForChild("Numberfall")
local Zone = require(shared:WaitForChild("ZoneRules"))
local COLOR = Zone.Color
local HEIGHT, BASE = 320, -30

-- wall: a ring of tall force-field panels around the safe circle
local SEGMENTS = 64
local folder = Instance.new("Folder")
folder.Name = "ZoneWalls"
local walls = {}
for i = 1, SEGMENTS do
    local w = Instance.new("Part")
    w.Name = "ZoneWall"
    w.Anchored = true; w.CanCollide = false; w.CanQuery = false; w.CanTouch = false; w.CastShadow = false
    w.Material = Enum.Material.ForceField
    w.Color = COLOR
    w.Size = Vector3.new(1, HEIGHT, 1)
    w.Parent = folder
    walls[i] = w
end
local wallFrames = table.create(SEGMENTS)
local lastRadius
local function placeWalls(circle)
    local R = Zone.Root()
    local y = BASE + HEIGHT / 2
    if lastRadius ~= circle.r then
        lastRadius = circle.r
        local width = 2 * math.pi * circle.r / SEGMENTS * 1.04
        for _, w in ipairs(walls) do w.Size = Vector3.new(width, HEIGHT, 1) end
    end
    for i = 1, SEGMENTS do
        local a = (i - 0.5) / SEGMENTS * math.pi * 2
        local x, z = circle.x + math.cos(a) * circle.r, circle.z + math.sin(a) * circle.r
        -- each panel faces the centre
        wallFrames[i] = R * CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(circle.x, y, circle.z))
    end
    workspace:BulkMoveTo(walls, wallFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- screen
local gui = Instance.new("ScreenGui")
gui.Name = "ZoneHUD"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")
-- red screen border (pulses while outside)
local edge = Instance.new("Frame")
edge.Size = UDim2.fromScale(1, 1); edge.BackgroundTransparency = 1; edge.Parent = gui
local vignette = Instance.new("UIStroke")
vignette.Color = COLOR; vignette.Thickness = 34; vignette.Transparency = 1
vignette.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; vignette.Parent = edge
-- the zone messages are pinned cards in the shared top notification stack (ReplicatedStorage.Numberfall.TopNotices)
local TopNotices = require(shared:WaitForChild("TopNotices"))
local function card(key, eyebrow)
    local self = {Visible = false, Text = ""}
    return setmetatable({}, {
        __index = self,
        __newindex = function(_, k, v)
            self[k] = v
            TopNotices.Set(key, self.Visible and self.Text ~= "" and {kind = "warn", eyebrow = eyebrow, text = self.Text, order = key == "zoneOut" and 2 or 1} or nil)
        end,
    })
end
local banner = card("zone", "THE ZONE")
local warning = card("zoneOut", "DANGER")
-- arrow back to safety: a double chevron that circles the crosshair and points along the ground toward the safe
-- circle (worked out from the camera's flat heading, so looking up or down doesn't throw it off), with the distance
local ARROW_RING = 118 -- px from the screen centre
local arrow = Instance.new("Frame")
arrow.Name = "ZoneArrow"; arrow.AnchorPoint = Vector2.new(0.5, 0.5); arrow.Size = UDim2.fromOffset(64, 64)
arrow.BackgroundTransparency = 1; arrow.Visible = false; arrow.Parent = gui
local function chevron(y, size, transparency)
    for _, side in ipairs({-1, 1}) do
        local bar = Instance.new("Frame")
        bar.AnchorPoint = Vector2.new(0.5, 0.5); bar.BorderSizePixel = 0
        bar.Size = UDim2.fromOffset(size, 7); bar.Rotation = side * 38
        bar.Position = UDim2.new(0.5, side * size * 0.39, 0, y)
        bar.BackgroundColor3 = Color3.fromRGB(255, 240, 232); bar.BackgroundTransparency = transparency
        local st = Instance.new("UIStroke"); st.Color = COLOR; st.Thickness = 2; st.Transparency = transparency; st.Parent = bar
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = bar
        bar.Parent = arrow
    end
end
chevron(22, 30, 0)
chevron(40, 26, 0.35)
local arrowDist = Instance.new("TextLabel")
arrowDist.AnchorPoint = Vector2.new(0.5, 0); arrowDist.Size = UDim2.fromOffset(160, 18)
arrowDist.BackgroundTransparency = 1; arrowDist.Font = Enum.Font.GothamBold; arrowDist.TextSize = 14
arrowDist.TextColor3 = Color3.fromRGB(255, 240, 232); arrowDist.TextStrokeColor3 = Color3.new(0, 0, 0); arrowDist.TextStrokeTransparency = 0.35
arrowDist.Visible = false; arrowDist.Parent = gui
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "ZoneTint"; tint.Enabled = false; tint.Parent = Lighting

-- outlines
local outlines = {}
local function outline(character, on)
    local h = outlines[character]
    if on and not h then
        h = Instance.new("Highlight")
        h.Name = "ZoneOutline"; h.FillColor = COLOR; h.FillTransparency = 0.85
        h.OutlineColor = COLOR; h.OutlineTransparency = 0; h.DepthMode = Enum.HighlightDepthMode.Occluded
        h.Adornee = character; h.Parent = character
        outlines[character] = h
    elseif not on and h then
        h:Destroy(); outlines[character] = nil
    end
end
local function clearOutlines() for c in pairs(outlines) do outline(c, false) end end

local announced, closingCue, squeezeCue, wasOutside = nil, nil, nil, false
local function cue()
    local s = Instance.new("Sound")
    -- the bell cue: a distant toll, not a jump scare (was 0.8, then 0.2 - still too loud)
    s.SoundId = "rbxassetid://77402059079473"; s.Volume = 0.08; s.Parent = gui
    local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = -10; eq.MidGain = -4; eq.LowGain = -1; eq.Parent = s
    s:Play(); s.Ended:Once(function() s:Destroy() end)
end

local accum = 0
RunService.RenderStepped:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    local playing = shared:GetAttribute("Phase") == "Playing" and not player:GetAttribute("IntroPlaying")
    local q = shared:GetAttribute("ZoneQuarter") or 0
    local starts = shared:GetAttribute("ZoneStartsAt")
    if not playing or q < 1 or not starts then
        folder.Parent = nil; banner.Visible = false; warning.Visible = false; arrow.Visible = false; arrowDist.Visible = false
        tint.Enabled = false; vignette.Transparency = 1; clearOutlines(); wasOutside = false
        return
    end
    local inArena = player:GetAttribute("InArena") == true
    -- lobby players see nothing of the zone (spectators still in the match keep the walls)
    if not inArena and player:GetAttribute("InMatch") ~= true then
        folder.Parent = nil; banner.Visible = false; warning.Visible = false; arrow.Visible = false; arrowDist.Visible = false
        tint.Enabled = false; vignette.Transparency = 1; clearOutlines(); wasOutside = false
        return
    end
    local round = shared:GetAttribute("RoundId")
    local name = Zone.Names[q] or "SAFE"
    -- countdown banner before the walls move
    if now < starts then
        local left = starts - now
        banner.Visible = inArena and left <= Zone.WarnSeconds
        banner.Text = string.format("THE CITY CLOSES IN %d  ·  RUN TO THE %s QUARTER", math.ceil(left), name)
        folder.Parent = nil
        if banner.Visible and announced ~= round then announced = round; cue() end
        return
    end
    -- walls
    local rect, t, squeeze = Zone.Circle(shared, now)
    placeWalls(rect)
    folder.Parent = workspace
    if closingCue ~= round then closingCue = round; if inArena then cue() end end
    -- the last squeeze as the round runs out
    if squeeze and squeezeCue ~= round then squeezeCue = round; if inArena then cue() end end
    local squeezing = squeeze ~= nil and squeeze < 1
    banner.Visible = inArena and (t < 1 or squeezing)
    banner.Text = t < 1 and ("THE CITY IS CLOSING  ·  " .. name .. " QUARTER IS SAFE")
        or squeezing and "THE CITY KEEPS CLOSING  ·  STAY INSIDE THE CIRCLE" or ""

    -- outlines on anyone in the closing area (throttled)
    accum += dt
    if accum >= 0.2 then
        accum = 0
        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            local root = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 and p:GetAttribute("InArena") and not Zone.Contains(rect, root.Position) then
                outline(c, true); seen[c] = true
            end
        end
        for c in pairs(outlines) do if not seen[c] then outline(c, false) end end
    end

    -- local player outside: tint, countdown, arrow
    local c = player.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    local outside = inArena and root ~= nil and hum ~= nil and hum.Health > 0 and not Zone.Contains(rect, root.Position)
    if outside then
        local since = c:GetAttribute("ZoneOutAt") or now
        local left = math.max(0, Zone.GraceSeconds - (now - since))
        local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
        warning.Visible = true
        warning.Text = string.format("RETURN TO THE SAFE ZONE  ·  %d", math.ceil(left))
        tint.Enabled = true
        tint.TintColor = Color3.new(1, 1, 1):Lerp(COLOR, 0.32 + 0.1 * pulse)
        tint.Saturation = -0.25
        vignette.Transparency = 0.25 + 0.35 * pulse
        -- arrow toward the nearest point inside the safe area (straight at the centre), measured on the ground: the
        -- camera's flat heading vs the flat direction, so pitching the camera can't skew it
        local target = Zone.Centre(rect, Zone.Root():PointToObjectSpace(root.Position).Y)
        local cam = workspace.CurrentCamera
        local to = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
        local fwd = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
        if fwd.Magnitude < 1e-3 then fwd = Vector3.new(-cam.CFrame.UpVector.X, 0, -cam.CFrame.UpVector.Z) end
        fwd = fwd.Unit
        local right = Vector3.new(-fwd.Z, 0, fwd.X)
        local ang = to.Magnitude > 0.01 and math.atan2(to.Unit:Dot(right), to.Unit:Dot(fwd)) or 0
        local view = cam.ViewportSize
        local cx, cy = view.X / 2, view.Y / 2
        local ax, ay = cx + math.sin(ang) * ARROW_RING, cy - math.cos(ang) * ARROW_RING
        arrow.Position = UDim2.fromOffset(ax, ay)
        arrow.Rotation = math.deg(ang)
        arrow.Visible = true
        local edgeDist = math.max(0, Zone.Distance(rect, root.Position) - rect.r)
        arrowDist.Text = string.format("SAFE ZONE  ·  %dm", math.ceil(edgeDist))
        arrowDist.Position = UDim2.fromOffset(ax, ay + 34)
        arrowDist.Visible = true
        if not wasOutside then wasOutside = true; cue() end
    else
        warning.Visible = false; arrow.Visible = false; arrowDist.Visible = false; tint.Enabled = false; vignette.Transparency = 1
        wasOutside = false
    end
end)
