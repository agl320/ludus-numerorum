-- Stained-glass windows (cathedral + clock tower) are drawn with thousands of GUI frames (~47k elements in the
-- cathedral alone). This keeps the look up close and cuts the cost everywhere else, per window face:
--   * a face you can't see (camera behind it - the glass parts are opaque) isn't drawn at all
--   * near (< NEAR studs): the full design
--   * mid: the same design minus the tiny gold beads along the borders (too small to see past NEAR anyway)
--   * far (> FAR studs): also drops the smallest tiles and the lead lines / corners on small pieces
-- (checked side by side in Studio: mid is identical apart from the beads, far keeps every roundel and colour)
-- Element counts for all cathedral + clock tower windows: full 52k, mid 31k, far 19k, and only faces that point
-- at the camera are drawn.
-- The simplified copies are built on this client the first time they're needed (a few per frame), never saved.
-- Windows are the parts tagged "StainedGlass".
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local NEAR, FAR = 60, 160         -- studs
local HYSTERESIS = 0.1            -- 10% band so windows don't flicker between levels at the boundary
local LEVELS = {
	-- an element is dropped when it covers less than this share of the window (corner/stroke/gradient: of its frame)
	Mid = {frame = 0.002, stroke = 0.004, gradient = 0, corner = 0},
	Far = {frame = 0.004, stroke = 0.016, gradient = 0.016, corner = 0.008},
}
local BUILDS_PER_TICK = 4
local TICK = 0.15

local faces = {}   -- gui -> {part, full, Mid, Far, level}
local queue = {}

-- share of the canvas an element covers (Scale sizes multiplied up to the SurfaceGui)
local function share(o, root)
	local w, h = 1, 1
	local cur = o
	while cur and cur ~= root do
		if cur:IsA("GuiObject") then w *= cur.Size.X.Scale; h *= cur.Size.Y.Scale end
		cur = cur.Parent
	end
	return w * h
end

local function simplify(full, levelName)
	local rule = LEVELS[levelName]
	local copy = full:Clone()
	copy.Name = full.Name .. "_" .. levelName
	copy:SetAttribute("StainedGlassLOD", levelName)
	copy.Enabled = false
	local drop = {}
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("UICorner") then
			if d.Parent:IsA("GuiObject") and share(d.Parent, copy) < rule.corner then table.insert(drop, d) end
		elseif d:IsA("GuiObject") then
			if share(d, copy) < rule.frame then table.insert(drop, d) end
		elseif d:IsA("UIStroke") then
			if d.Parent:IsA("GuiObject") and share(d.Parent, copy) < rule.stroke then table.insert(drop, d) end
		elseif d:IsA("UIGradient") then
			if d.Parent:IsA("GuiObject") and share(d.Parent, copy) < rule.gradient then table.insert(drop, d) end
		end
	end
	for _, d in ipairs(drop) do if d.Parent then d:Destroy() end end
	copy.Parent = full.Parent
	return copy
end

local function addPart(part)
	if not part:IsA("BasePart") then return end
	for _, g in ipairs(part:GetChildren()) do
		if g:IsA("SurfaceGui") and not g:GetAttribute("StainedGlassLOD") and not faces[g] then
			faces[g] = {part = part, full = g, level = "Full"}
		end
	end
end
local function removePart(part)
	for g, f in pairs(faces) do if f.part == part then faces[g] = nil end end
end
CollectionService:GetInstanceAddedSignal("StainedGlass"):Connect(addPart)
CollectionService:GetInstanceRemovedSignal("StainedGlass"):Connect(removePart)
for _, p in ipairs(CollectionService:GetTagged("StainedGlass")) do addPart(p) end

local function show(f, level)
	f.full.Enabled = level == "Full"
	if f.Mid then f.Mid.Enabled = level == "Mid" end
	if f.Far then f.Far.Enabled = level == "Far" end
	f.level = level
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then return end
	local eye = cam.CFrame.Position
	local builds = 0
	-- low end mode (StarterPlayerScripts.LowEndMode): drop to the simpler designs much sooner
	local low = game:GetService("Players").LocalPlayer:GetAttribute("LowEnd") == true
	local NEAR, FAR = low and 18 or NEAR, low and 45 or FAR
	for g, f in pairs(faces) do
		local part = f.part
		if not g.Parent or not part.Parent then
			faces[g] = nil
		else
			local normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(g.Face))
			local half = (part.Size * Vector3.FromNormalId(g.Face)).Magnitude / 2
			local facePoint = part.Position + normal * half
			local toEye = eye - facePoint
			local facing = part.Transparency > 0.05 or toEye:Dot(normal) > -0.05
			local dist = math.max(0, toEye.Magnitude - math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2)
			local want
			if not facing then
				want = "Off"
			else
				-- hysteresis: it takes a little more distance to drop a level than to come back up
				local k = (f.level == "Full" or f.level == "Off") and (1 + HYSTERESIS) or 1
				local k2 = (f.level == "Far") and (1 - HYSTERESIS) or 1
				if dist < NEAR * k then want = "Full"
				elseif dist < FAR * (f.level == "Far" and k2 or (f.level == "Mid" and 1 + HYSTERESIS or 1)) then want = "Mid"
				else want = "Far" end
			end
			if want ~= f.level then
				if want == "Mid" or want == "Far" then
					if not f[want] then
						if builds < BUILDS_PER_TICK then
							builds += 1
							f[want] = simplify(f.full, want)
							show(f, want)
						end
						-- not built yet: keep what is showing until it is
					else
						show(f, want)
					end
				else
					show(f, want)
				end
			end
		end
	end
end)
