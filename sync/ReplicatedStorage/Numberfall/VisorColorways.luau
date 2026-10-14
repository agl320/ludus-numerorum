-- VISOR COLOURWAYS: restyles of the standard LED visor (the VIP / MOD / OWNER visors keep their own look).
-- Owned once (OwnedHair[id], published as OwnHair_<id>), equipped as d.VisorColor (player attribute VisorColor).
-- Equipping one also puts the standard visor back on; picking "Standard" in Loadout > VISOR takes it off again
-- (VcOriginal is only the internal default, it isn't listed). CaseOnly ones aren't sold: they only drop from cases.
-- Each one's 3D model lives in NumberfallVisor.Colorways.<Id> (made from the base visor like the rank visors).
-- Hidden = true on an entry: not offered anywhere (shop, loadout, cases) and not drawn.
--   VisorColorways.Paint(handle, id)  -- restyle a visor Handle (call once it has its final Size / CFrame)
--   VisorColorways.Trim(handle)       -- refit a colourway's trim after the handle was resized (previews)
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local V = {}
local function c3(r, g, b) return Color3.fromRGB(r, g, b) end
V.Default = "VcOriginal"
V.List = {
	{Id = "VcOriginal", Name = "Original", Price = 0},
	{Id = "VcCobalt", Name = "Cobalt", Rarity = "Rare", Color = c3(40, 74, 190)},
	{Id = "VcBone", Name = "Bone", Rarity = "Uncommon", Color = c3(226, 216, 196)},
	{Id = "VcJade", Name = "Jade", Rarity = "Uncommon", Color = c3(30, 130, 90)},
	{Id = "VcAmethyst", Name = "Amethyst", Rarity = "Rare", Color = c3(150, 90, 220)},
	{Id = "VcGold", Name = "Gold", Rarity = "Epic", Color = c3(214, 168, 64)},
	-- case exclusives
	{Id = "VcCrimson", Name = "Crimson", Rarity = "Legendary", CaseOnly = true, Color = c3(160, 22, 40)},
	{Id = "VcChrome", Name = "Chrome", Rarity = "Legendary", CaseOnly = true, Color = c3(222, 226, 234)},
	{Id = "VcAbyss", Name = "Abyss", Rarity = "Legendary", CaseOnly = true, Color = c3(120, 50, 220)},
	{Id = "VcMolten", Name = "Molten", Rarity = "Legendary", CaseOnly = true, Color = c3(255, 110, 30)},
}
Rarity.Apply(V.List, "colour")
V.ById = {}
for _, c in ipairs(V.List) do
	c.Kind = "visorcolor"
	c.Blurb = c.CaseOnly and "Case exclusive." or nil
	V.ById[c.Id] = c
end
function V.Get(id) return V.ById[id or ""] end
function V.Tinted(id) local c = V.ById[id or ""]; return c ~= nil and c.Id ~= V.Default and not c.Hidden end

local MESH = Vector3.new(1.50800, 0.37181, 1.54824)
-- a colourway's 3D model (NumberfallVisor.Colorways.<Id>): a Shell MeshPart (the base visor re-textured, its own
-- SurfaceAppearance) and Trim MeshParts with a TrimOffset attribute (CFrame from the handle at design size),
-- like the rank visors' trims
local function model(id)
	local folder = script.Parent:FindFirstChild("NumberfallVisor")
	local set = folder and folder:FindFirstChild("Colorways")
	return set and set:FindFirstChild(id or "")
end
function V.Trim(handle)
	if not handle then return end
	local old = handle:FindFirstChild("ColorwayTrim")
	if old then old:Destroy() end
	local m = model(handle:GetAttribute("VisorColorway"))
	if not m then return end
	local k = handle.Size / MESH
	local holder
	for _, src in ipairs(m:GetChildren()) do
		local off = src:IsA("BasePart") and src:GetAttribute("TrimOffset")
		if typeof(off) == "CFrame" then
			holder = holder or Instance.new("Model")
			local p = src:Clone()
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = handle.Anchored, false, false, false, true, false
			p.Size = src.Size * k
			local rel = CFrame.new(off.Position * k) * off.Rotation
			p.CFrame = handle.CFrame * rel
			local w = Instance.new("Weld"); w.Part0, w.Part1, w.C0 = handle, p, rel; w.Parent = p
			p.Parent = holder
		end
	end
	if holder then holder.Name = "ColorwayTrim"; holder.Parent = handle end
end

-- restyle a standard visor handle in the colourway (fresh copy of NumberfallVisor.LEDVisor.Handle)
function V.Paint(handle, id)
	local c = V.ById[id or ""]
	if not handle or not c or c.Id == V.Default or c.Hidden then return false end
	handle:SetAttribute("VisorColorway", c.Id)
	local m = model(c.Id)
	local shell = m and m:FindFirstChild("Shell")
	if shell and shell:IsA("MeshPart") and handle:IsA("MeshPart") then
		local size = handle.Size
		pcall(function() handle:ApplyMesh(shell) end)
		handle.Size = size
	end
	local sa = (shell and shell:FindFirstChildOfClass("SurfaceAppearance")) or (m and m:FindFirstChildOfClass("SurfaceAppearance"))
	if sa then
		local old = handle:FindFirstChildOfClass("SurfaceAppearance")
		if old then old:Destroy() end
		sa:Clone().Parent = handle
	end
	V.Trim(handle)
	return true
end
return V
