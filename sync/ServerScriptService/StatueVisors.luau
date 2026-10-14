-- Puts the LED visor on the city's statues, showing the blinking 0__0 idle face (StarterPlayerScripts.VisorFaces).
-- The statues are single meshes, so each statue type has a hand-fitted head box, given as fractions of the
-- statue mesh part's size (works at any scale). Other statues: tag the model "VisorStatue" and give it
-- attributes VisorHead (Vector3, fractions of the mesh part size), VisorWidth / VisorDepth (fractions) and
-- VisorTilt (degrees, negative = head bowed).
local CollectionService = game:GetService("CollectionService")
local Visor = require(script.Parent:WaitForChild("VisorDisplay"))

local S = {}
S.FIT = {
	-- measured from the meshes (EditableMesh depth renders): the scribe's face sits off-centre (x -0.14 studs at
	-- scale 0.64) with its front at z -0.46 inside the hood; the angel's head is a ~1.5 wide shell centred at z -0.8
	-- with the hands in front of the eyes
	ScribeStatue = {Head = Vector3.new(-0.044, 0.381, -0.045), Width = 0.19, Depth = 0.19, Tilt = 0},  -- across the eyes, inside the hood
	AngelStatue = {Head = Vector3.new(0, 0.302, -0.172), Width = 0.272, Depth = 0.343, Tilt = -8},     -- round the head, over the hands covering its eyes
}

local function meshPart(statue)
	if statue:IsA("BasePart") then return statue end
	local best
	for _, d in ipairs(statue:GetDescendants()) do
		if d:IsA("BasePart") and (not best or d.Size.Magnitude > best.Size.Magnitude) then best = d end
	end
	return best
end

function S.Apply(statue, config)
	local geom = meshPart(statue)
	if not geom then return end
	local fit = S.FIT[statue.Name] or {}
	local head = statue:GetAttribute("VisorHead") or fit.Head
	if typeof(head) ~= "Vector3" then return end
	local width = statue:GetAttribute("VisorWidth") or fit.Width or 0.2
	local depth = statue:GetAttribute("VisorDepth") or fit.Depth or width
	local tilt = statue:GetAttribute("VisorTilt") or fit.Tilt or 0
	local old = statue:FindFirstChild("StatueVisor")
	if old then old:Destroy() end
	local rig = Instance.new("Model")
	rig.Name = "StatueVisor"
	local h = Instance.new("Part")
	h.Name = "Head"
	h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.CastShadow = true, false, false, false, false
	h.Transparency = 1
	local w = width * geom.Size.X
	h.Size = Vector3.new(w, w * 1.1, depth * geom.Size.Z)
	h.CFrame = geom.CFrame * CFrame.new(head * geom.Size) * CFrame.Angles(math.rad(tilt), 0, 0)
	h.Parent = rig
	rig.PrimaryPart = h
	rig.Parent = statue
	local visor = Visor.Equip(rig, config)
	if visor then
		for _, d in ipairs(visor:GetDescendants()) do
			if d:IsA("BasePart") then d.CanQuery = false end
		end
		Visor.Display(rig, visor, Visor.IDLE, config)
	end
	return rig
end

function S.ApplyAll(config, root)
	root = root or workspace
	local done = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and S.FIT[d.Name] then S.Apply(d, config); done[d] = true end
	end
	for _, d in ipairs(CollectionService:GetTagged("VisorStatue")) do
		if not done[d] and d:IsDescendantOf(root) then S.Apply(d, config) end
	end
end

return S
