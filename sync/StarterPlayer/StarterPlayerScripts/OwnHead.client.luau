-- Hides your own head, LED visor and hats/accessories (bandanas, hair...) from your own camera in first person.
-- Runs right after the camera moves each frame, and switches the moment the camera mode changes, so nothing on
-- your head is ever seen for a few frames while the camera zooms in or out.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local player = Players.LocalPlayer

local headNames = {Head = true, LEDVisor = true, NumberForehead = true, FaceMask = true}
local tracked = {} -- instance -> original Enabled (guis/lights/effects) or "part" / "decal"
-- body parts hidden straight away in first person (legs stay visible while sliding: FeelController shows them)
local bodyNames = {UpperTorso = true, LowerTorso = true, Torso = true, LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    RightUpperArm = true, RightLowerArm = true, RightHand = true, ["Left Arm"] = true, ["Right Arm"] = true}
local legNames = {LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true,
    RightFoot = true, ["Left Leg"] = true, ["Right Leg"] = true}
local bodyHidden = false
-- arms stay visible while you climb a wall (they reach up past the camera)
local armNames = {LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
    ["Left Arm"] = true, ["Right Arm"] = true}
local function hideBody(char, on)
    local sliding = (char:GetAttribute("SlideUntil") or 0) > workspace:GetServerTimeNow()
    local climbing = char:GetAttribute("Climbing") == true
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then
            if on and climbing and armNames[p.Name] then
                p.LocalTransparencyModifier = 0
            elseif bodyNames[p.Name] or (legNames[p.Name] and not (on and sliding)) then
                p.LocalTransparencyModifier = on and 1 or 0
            end
        end
    end
end
local character, scannedAt = nil, 0
local hidden = false

local function track(d)
    if tracked[d] ~= nil then return end
    if d:IsA("BasePart") then tracked[d] = "part"
    elseif d:IsA("Decal") then
        if pcall(function() return d.LocalTransparencyModifier end) then tracked[d] = "decal" end
    elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
        tracked[d] = d.Enabled
    end
end
local function scan(char)
    for _, child in ipairs(char:GetChildren()) do
        -- head pieces, hats/accessories and any model worn on the head (the FaceMask bandana, the LED visor)
        if headNames[child.Name] or child:IsA("Accessory") or child:IsA("Hat") or child:IsA("Model") then
            track(child)
            for _, d in ipairs(child:GetDescendants()) do track(d) end
        end
    end
end
local function apply(hide)
    for d, original in pairs(tracked) do
        if not d.Parent then tracked[d] = nil
        elseif hide then
            if original == "part" or original == "decal" then d.LocalTransparencyModifier = 1 else d.Enabled = false end
        elseif not d:FindFirstAncestor("NumberForehead") then -- the number plate is handled by NumberView
            if original == "part" or original == "decal" then d.LocalTransparencyModifier = 0 else d.Enabled = original end
        end
    end
end

Run:BindToRenderStep("MarkedOwnHead", Enum.RenderPriority.Camera.Value + 1, function()
    local char = player.Character
    if char ~= character then
        if character then apply(false) end
        tracked = {}; character = char; scannedAt = 0; hidden = false; bodyHidden = false
    end
    if not char then return end
    if os.clock() - scannedAt > 0.4 then scannedAt = os.clock(); scan(char) end
    local camera = workspace.CurrentCamera
    local h = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local hide = false
    if camera and h and root and h.Health > 0 and camera.CameraType == Enum.CameraType.Custom and camera.CameraSubject == h then
        local position = camera.CFrame.Position
        local eye = root.Position + Vector3.new(0, 1.5, 0)
        hide = player.CameraMode == Enum.CameraMode.LockFirstPerson
            or (position - eye).Magnitude < 4
            or (head ~= nil and (position - head.Position).Magnitude < 2.5)
    end
    player:SetAttribute("OwnHeadHidden", hide)
    if hide then apply(true) elseif hidden then apply(false) end
    hidden = hide
    local firstPerson = hide and player.CameraMode == Enum.CameraMode.LockFirstPerson
    if firstPerson then hideBody(char, true) elseif bodyHidden then hideBody(char, false) end
    bodyHidden = firstPerson
end)
