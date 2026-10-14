-- Facial accessory: the cloth bandana mask (ServerStorage.MARKED_Accessories.FaceMask), welded to the head.
-- Worn as a plain Model (like the visor) so Roblox never re-welds it as a legacy hat.
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Extras = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Extras"))
local Fit = require(game:GetService("ReplicatedStorage").Numberfall:WaitForChild("HairFit"))   -- hoods tuck the hair in

local FaceMask = {}

local DESIGN_HEAD = 1.2                                   -- head width the mask was modelled around
-- The glTF importer turns meshes 180 degrees (glTF front is +Z); this puts the mask's front back at -Z.
local MESH_FLIP = CFrame.Angles(0, math.pi, 0)
-- Mesh bbox centre relative to the head centre (studs at design size), per exported version (keyed by height).
local VERSIONS = {
	{height = 1.0474, centre = Vector3.new(-0.0005, -0.5366, -0.0075)},   -- sharp-V export
	{height = 0.9874, centre = Vector3.new(-0.0020, -0.5066, -0.0075)},   -- soft-V export
}

local function template()
	local folder = ServerStorage:FindFirstChild("MARKED_Accessories")
	return folder and folder:FindFirstChild("FaceMask")
end

local function centreFor(size)
	local best, bestD = VERSIONS[1], math.huge
	for _, v in VERSIONS do
		local d = math.abs(size.Y - v.height)
		if d < bestD then best, bestD = v, d end
	end
	return best.centre
end

-- Weld the mask to the head. Safe to call again (keeps the existing one).
function FaceMask.Equip(character)
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	-- worn only when bought and equipped in the Shop / Loadout (player attribute FaceMask: "Scarf", "CatHood"...)
	local player = Players:GetPlayerFromCharacter(character)
	local id = player and player:GetAttribute("FaceMask")
	local models = game:GetService("ReplicatedStorage").Numberfall:FindFirstChild("MaskModels")
	local catalogSrc = id ~= "Scarf" and models and models:FindFirstChild(id or "") and models[id]:FindFirstChild("Handle")
	local source = id == "Scarf" and template() or nil
	local sourceHandle = (source and source:FindFirstChild("Handle")) or catalogSrc
	if not sourceHandle then FaceMask.Unequip(character); return nil end
	-- the mask's colourway (Loadout > Head > COLOURS); a different mask or colourway rebuilds it
	local cw = player:GetAttribute("MaskColor") or Extras.DefaultMaskColorway
	local existing = character:FindFirstChild("FaceMask")
	if existing and existing:GetAttribute("MaskId") == id and (existing:GetAttribute("Colorway") or Extras.DefaultMaskColorway) == cw then return existing end
	if existing then existing:Destroy() end

	if catalogSrc then
		-- a catalog head item (the cat hood): placed by its own attachment
		local offset, s = Extras.MaskOffset(head, catalogSrc)
		if not offset then return nil end
		local model = Instance.new("Model"); model.Name = "FaceMask"
		model:SetAttribute("NumberfallFaceMask", true); model:SetAttribute("MaskId", id); model:SetAttribute("Colorway", cw)
		local handle = catalogSrc:Clone(); handle.Name = "Handle"
		handle.Anchored, handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, false, true
		handle.Size = catalogSrc.Size * s
		Extras.DyeMask(handle, cw)
		handle.Parent = model; model.PrimaryPart = handle
		handle.CFrame = head.CFrame * offset
		local weld = Instance.new("Weld"); weld.Name = "FaceMaskWeld"; weld.Part0, weld.Part1 = head, handle; weld.C0 = offset; weld.Parent = handle
		model.Parent = character
		Fit.ApplyTuck(character)
		return model
	end

	local scale = head.Size.X / DESIGN_HEAD
	local model = Instance.new("Model")
	model.Name = "FaceMask"
	model:SetAttribute("NumberfallFaceMask", true)
	model:SetAttribute("MaskId", id)
	local handle = sourceHandle:Clone()
	handle.Name = "Handle"
	handle.Anchored, handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, false, true
	handle.Size = sourceHandle.Size * scale
	Extras.DyeMask(handle, cw)
	model:SetAttribute("Colorway", cw)
	handle.Parent = model
	model.PrimaryPart = handle
	local offset = CFrame.new(centreFor(sourceHandle.Size) * scale)
	handle.CFrame = head.CFrame * offset * MESH_FLIP
	local weld = Instance.new("Weld")
	weld.Name = "FaceMaskWeld"
	weld.Part0, weld.Part1 = head, handle
	weld.C0 = offset * MESH_FLIP
	weld.Parent = handle
	model.Parent = character
	Fit.ApplyTuck(character)
	return model
end

function FaceMask.Unequip(character)
	local m = character:FindFirstChild("FaceMask")
	if m then m:Destroy() end
	Fit.ApplyTuck(character)
end

return FaceMask
