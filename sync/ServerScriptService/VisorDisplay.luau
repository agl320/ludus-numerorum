-- LED visor: welds the PBR visor accessory to a character's head and lights its
-- curved screen with that character's NumberfallCode.
-- Digits are drawn as neon tubes (white-hot core + red glow) from GUI frames,
-- so no image assets are needed.
local ServerStorage = game:GetService("ServerStorage")
local VisorFit = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("VisorFit"))
-- digits are drawn in the dot-matrix LED style (Numberfall.LEDFont); set USE_DOTS = false for the neon tubes
local LEDFont = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("LEDFont"))
local USE_DOTS = true
-- the player's equipped NUMBER STYLE (Numberfall.NumberStyles) decides how the digits are drawn
local NumberStyles = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NumberStyles"))
local Players = game:GetService("Players")

local Visor = {}

-- ===== generated from the visor mesh (only change if the mesh changes) =====
local MESH_SIZE = Vector3.new(1.50800, 0.37181, 1.54824)  -- imported MeshPart size (studs)
local BOX_CENTRE = Vector3.new(0, 0.01246, -0.02288)      -- mesh bbox centre relative to the ring centre
local DESIGN_HEAD = 1.2                                    -- head width the ring was built around
local RING_INNER = Vector2.new(0.62, 0.65)                 -- inner (padding) half-width X / half-depth Z of the ring at design size
local HEAD_SINK = 0.02                                     -- padding tucks this far into the head so the top lip sits flush (no gap from above)
-- The glTF importer turns the mesh 180 degrees (glTF front is +Z); this puts the screen back at -Z.
local MESH_FLIP = CFrame.Angles(0, math.pi, 0)
local CELL = Vector2.new(0.12587, 0.18880)                 -- one digit panel (studs)
local CANVAS = Vector2.new(192, 288)                       -- panel canvas (px)
-- glyph box inside the canvas (px); lines up with the unlit segments baked into the screen texture
local GLYPH = {X = 47.2, Y = 54, W = 97.6, H = 180, Stroke = 8}
-- neon glow rings, outermost first: {width x stroke, how much red 0..1}. Drawn solid (not see-through)
-- so where strokes meet they merge cleanly instead of doubling up into blobs.
local RINGS = {{8, 0.05}, {6.4, 0.085}, {5, 0.14}, {3.8, 0.23}, {2.8, 0.38}, {2, 0.62}, {1.45, 1}}
local SCREEN_BLACK = Color3.fromRGB(16, 9, 10)             -- the visor screen's own colour, so the outer glow fades into it
local SLOTS = {  -- centre + outward normal of each digit, visor space (screen at -Z), left -> right as seen
	{Position = Vector3.new(0.15206, -0.01246, -0.71635), Normal = Vector3.new(0.21767, 0, -0.97602)},
	{Position = Vector3.new(0.04238, -0.01246, -0.73183), Normal = Vector3.new(0.06077, 0, -0.99815)},
	{Position = Vector3.new(-0.06839, -0.01246, -0.72976), Normal = Vector3.new(-0.09804, 0, -0.99518)},
	{Position = Vector3.new(-0.17740, -0.01246, -0.71021), Normal = Vector3.new(-0.25379, 0, -0.96726)},
}
local SEGMENTS = {  -- neon tubes: polylines in a 0..1 box (x right, y down); separate polylines = the small breaks
	["0"] = {{{0.17, 0}, {0.83, 0}, {1, 0.15}, {1, 0.46}}, {{1, 0.54}, {1, 0.85}, {0.83, 1}, {0.17, 1}, {0, 0.85}, {0, 0.54}}, {{0, 0.46}, {0, 0.15}, {0.17, 0}}},
	["1"] = {{{0.22, 0.2}, {0.6, 0}}, {{0.6, 0.07}, {0.6, 0.46}}, {{0.6, 0.54}, {0.6, 1}}},
	["2"] = {{{0, 0.17}, {0.17, 0}, {0.83, 0}, {1, 0.17}, {1, 0.36}, {0.56, 0.66}}, {{0.47, 0.72}, {0, 1}, {1, 1}}},
	["3"] = {{{0, 0}, {1, 0}, {0.5, 0.38}}, {{0.42, 0.43}, {0.85, 0.43}, {1, 0.57}, {1, 0.85}, {0.85, 1}, {0, 1}}},
	["4"] = {{{0.68, 0.03}, {0, 0.68}, {1, 0.68}}, {{0.75, 0}, {0.75, 0.6}}, {{0.75, 0.76}, {0.75, 1}}},
	["5"] = {{{1, 0}, {0.07, 0}}, {{0.02, 0.06}, {0, 0.44}, {0.8, 0.42}, {1, 0.6}, {1, 0.85}, {0.85, 1}, {0, 1}}},
	["6"] = {{{0.9, 0}, {0.3, 0}, {0, 0.38}}, {{0, 0.46}, {0, 0.85}, {0.15, 1}, {0.85, 1}, {1, 0.85}, {1, 0.6}, {0.85, 0.47}, {0.07, 0.47}}},
	["7"] = {{{0, 0}, {1, 0}, {0.66, 0.56}}, {{0.61, 0.64}, {0.4, 1}}},
	["8"] = {{{0.15, 0}, {0.85, 0}, {1, 0.12}, {1, 0.36}, {0.85, 0.47}, {0.15, 0.47}, {0, 0.36}, {0, 0.12}, {0.15, 0}}, {{0.15, 0.53}, {0, 0.64}, {0, 0.88}, {0.15, 1}, {0.85, 1}, {1, 0.88}, {1, 0.64}, {0.85, 0.53}, {0.15, 0.53}}},
	["9"] = {{{0.93, 0.53}, {0.15, 0.53}, {0, 0.4}, {0, 0.15}, {0.15, 0}, {0.85, 0}, {1, 0.15}, {1, 0.62}}, {{0.97, 0.7}, {0.7, 1}, {0.1, 1}}},
	["-"] = {{{0.12, 0.5}, {0.88, 0.5}}},                                                    -- no number (lobby)
	["*"] = {{{0.5, 0.22}, {0.5, 0.78}}, {{0.2, 0.36}, {0.8, 0.64}}, {{0.2, 0.64}, {0.8, 0.36}}}, -- masked (death cam)
}
-- ===========================================================================

local WHITE = Color3.new(1, 1, 1)

-- VIP / MOD / OWNER visors (ReplicatedStorage.Numberfall.NumberfallVisor.Ranks.<RANK>: a Handle the same size and
-- screen as the base visor, plus a Trim welded on top). Which one a player wears is their pick in Loadout > VISOR, from
-- the ones their rank unlocks (Numberfall.RankLooks); nil = the standard visor.
local RankLooks = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("RankLooks"))
-- the standard visor's shell colourway (Loadout > VISOR; player attribute VisorColor)
local VisorColorways = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("VisorColorways"))
function Visor.Colorway(character)
	local player = Players:GetPlayerFromCharacter(character)
	local id = player and player:GetAttribute("VisorColor")
	return VisorColorways.Tinted(id) and id or nil
end
function Visor.Rank(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return nil end
	local id = RankLooks.Visor(player)
	return id ~= "Standard" and id or nil
end
local function rankTemplate(rank)
	local folder = game:GetService("ReplicatedStorage").Numberfall:FindFirstChild("NumberfallVisor")
	local ranks = folder and folder:FindFirstChild("Ranks")
	return rank and ranks and ranks:FindFirstChild(rank)
end

local function template()
	local folder = game:GetService("ReplicatedStorage").Numberfall:FindFirstChild("NumberfallVisor")
	return folder and folder:FindFirstChild("LEDVisor")
end

-- Half-width (X) and half-depth (Z) of the visible head.
local function headHalfExtents(head)
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		return mesh.Scale.X / 2, mesh.Scale.Z / 2  -- R6 head: 1x1x1 head mesh scaled by the SpecialMesh
	end
	return head.Size.X / 2, head.Size.Z / 2
end

-- Returns the visor's frame on this head: screen facing the head's front, origin at the mesh bbox centre.
local function visorFrame(head, scale, config)
	local lift = (config.Visor and config.Visor.HeightOffset or 0.05) * head.Size.Y
	return CFrame.new(0, lift, 0) * CFrame.new(BOX_CENTRE * scale)
end

-- Weld the PBR visor to the head. Safe to call again (replaces the old one).
function Visor.Equip(character, config)
	local head = character:FindFirstChild("Head")
	local source = template()
	if not head or not source then return nil end
	local old = character:FindFirstChild("LEDVisor")
	if old then old:Destroy() end

	local rank = Visor.Rank(character)
	local rankModel = rankTemplate(rank)
	local sourceHandle = (rankModel and rankModel:FindFirstChild("Handle")) or source:FindFirstChild("Handle")
	if not sourceHandle then return nil end
	if not (rankModel and rankModel:FindFirstChild("Handle")) then rank, rankModel = nil, nil end

	-- Fit around this head, worn over the bangs (Hair sets the VisorPad attribute). Shared maths: Numberfall.VisorFit
	local scale, c0 = VisorFit.Compute(head, character:GetAttribute("VisorPad") or 0, config)
	-- Worn as a plain Model, not an Accessory: at runtime Roblox re-welds an Accessory that has no
	-- attachment as a legacy hat (HeadWeld, top of the head, flip removed), which put the visor
	-- on top of the head and backwards. A Model keeps exactly the weld made below.
	local accessory = Instance.new("Model")
	accessory.Name = "LEDVisor"
	accessory:SetAttribute("NumberfallVisor", true)
	accessory:SetAttribute("VisorScale", scale)
	local handle = sourceHandle:Clone()
	handle.Name = "Handle"
	handle.Anchored, handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, false, true
	handle.Size = MESH_SIZE * scale
	handle.Parent = accessory
	accessory.PrimaryPart = handle
	handle.CFrame = head.CFrame * c0
	local weld = Instance.new("Weld")
	weld.Name = "VisorWeld"
	weld.Part0, weld.Part1 = head, handle
	weld.C0 = c0
	weld.Parent = handle
	-- the rank trim, scaled with the visor and welded to it
	local trimSource = rankModel and rankModel:FindFirstChild("Trim")
	local offset = trimSource and trimSource:GetAttribute("TrimOffset")
	if trimSource and typeof(offset) == "CFrame" then
		local trim = trimSource:Clone()
		trim.Name = "RankTrim"
		trim.Anchored, trim.CanCollide, trim.CanTouch, trim.CanQuery, trim.Massless = false, false, false, false, true
		trim.Size = trimSource.Size * scale
		local rel = CFrame.new(offset.Position * scale) * offset.Rotation
		trim.CFrame = handle.CFrame * rel
		local trimWeld = Instance.new("Weld")
		trimWeld.Name = "TrimWeld"
		trimWeld.Part0, trimWeld.Part1, trimWeld.C0 = handle, trim, rel
		trimWeld.Parent = trim
		trim.Parent = accessory
	end
	accessory:SetAttribute("VisorRank", rank)
	-- the standard visor in the player's colourway
	local cw = not rank and Visor.Colorway(character) or nil
	if cw then VisorColorways.Paint(handle, cw) end
	accessory:SetAttribute("VisorColor", cw)
	accessory.Parent = character
	return accessory
end

local function tube(parent, a, b, width, color, z)
	local dx, dy = b.X - a.X, b.Y - a.Y
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + width, width)
	frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.BackgroundColor3 = color
	frame.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
end

-- Draws one digit as a neon tube: soft red glow rings, then a white-hot core on top.
local function drawDigit(surface, char, color, brightness, sheet, style)
	if style then NumberStyles.Draw(surface, char, style, brightness) return end
	surface:ClearAllChildren()
	-- Preferred: the pre-rendered neon digit sheet (LEDVisor_NeonDigits.png, 5 x 2 cells of 192 x 288).
	if sheet and sheet ~= "" and tonumber(char) then
		local n = tonumber(char)
		if not n then sheet = nil end
		local label = Instance.new("ImageLabel")
		label.Name = "Digit"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Image = sheet
		label.ImageRectSize = Vector2.new(192, 288)
		label.ImageRectOffset = Vector2.new((n % 5) * 192, math.floor(n / 5) * 288)
		label.Parent = surface
		return
	end
	if USE_DOTS then LEDFont.Draw(surface, char, color, brightness, GLYPH) return end
	-- Fallback: neon tubes built from frames.
	local lines = SEGMENTS[char]
	if not lines then return end
	-- SurfaceGui Brightness multiplies every colour; the glow rings are pre-divided by it so they
	-- fade into the screen, while the core stays over-bright on purpose (that is the neon look).
	local k = 1 / math.max(brightness or 1, 1)
	local layers = {}
	for _, ring in ipairs(RINGS) do
		local c = SCREEN_BLACK:Lerp(color, ring[2])
		table.insert(layers, {GLYPH.Stroke * ring[1], Color3.new(c.R * k, c.G * k, c.B * k)})
	end
	table.insert(layers, {GLYPH.Stroke, color:Lerp(WHITE, 0.6)})
	for z, layer in ipairs(layers) do
		for _, line in ipairs(lines) do
			for i = 1, #line - 1 do
				local a = Vector2.new(GLYPH.X + line[i][1] * GLYPH.W, GLYPH.Y + line[i][2] * GLYPH.H)
				local b = Vector2.new(GLYPH.X + line[i + 1][1] * GLYPH.W, GLYPH.Y + line[i + 1][2] * GLYPH.H)
				tube(surface, a, b, layer[1], layer[2], z)
			end
		end
	end
end

-- Light the screen with `code`. Returns the "NumberForehead" anchor part that the rest of
-- the game already uses: destroying it turns the screen off, and NumberView toggles its
-- "FrontNumber" SurfaceGuis so the number is only readable from the front and never by its owner.
function Visor.Display(character, accessory, code, config)
	local handle = accessory and accessory:FindFirstChild("Handle")
	if not handle then return nil end
	local settings = config.Visor or {}
	local color = settings.LEDColor and Color3.fromRGB(table.unpack(settings.LEDColor)) or Color3.fromRGB(255, 38, 48)
	local scale = accessory:GetAttribute("VisorScale")
	if typeof(scale) == "number" then scale = Vector3.one * scale end
	if typeof(scale) ~= "Vector3" then scale = handle.Size / MESH_SIZE end
	local visorCF = handle.CFrame * MESH_FLIP:Inverse()
	local owner = Players:GetPlayerFromCharacter(character)
	local style = character:GetAttribute("NumberStyle") or (owner and owner:GetAttribute("NumberStyle")) or NumberStyles.Default
	style = NumberStyles.Get(style).Id
	local sheet = style == NumberStyles.Default and settings.DigitSheet or nil

	local old = character:FindFirstChild("NumberForehead")
	if old then old:Destroy() end
	local anchor = Instance.new("Part")
	anchor.Name = "NumberForehead"
	anchor.Size = Vector3.new(0.05, 0.05, 0.05)
	anchor.Transparency = 1
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Massless = false, false, false, true
	anchor.CastShadow = false
	anchor.CFrame = visorCF
	anchor:SetAttribute("NumberStyle", style)
	anchor.Parent = character
	local anchorWeld = Instance.new("WeldConstraint")
	anchorWeld.Part0, anchorWeld.Part1, anchorWeld.Parent = handle, anchor, anchor

	code = tostring(code or "")
	for i, slot in ipairs(SLOTS) do
		local pos = slot.Position * scale
		local panel = Instance.new("Part")
		panel.Name = "Digit" .. i
		panel.Size = Vector3.new(CELL.X * scale.X, CELL.Y * scale.Y, 0.01)
		panel.Transparency = 1
		panel.CanCollide, panel.CanTouch, panel.CanQuery, panel.Massless = false, false, false, true
		panel.CastShadow = false
		local normal = (slot.Normal / scale).Unit       -- stays perpendicular to the screen when the ring is fitted unevenly
		panel.CFrame = visorCF * CFrame.lookAt(pos, pos + normal)
		panel.Parent = anchor
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, panel, panel

		local surface = Instance.new("SurfaceGui")
		surface.Name = "FrontNumber"
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = CANVAS
		surface.LightInfluence = 0                 -- unlit, so Lighting.Bloom makes it glow
		surface.Brightness = settings.Brightness or 2.4
		surface.AlwaysOnTop = false
		surface.MaxDistance = config.ForeheadDistance or 160
		surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		surface.Parent = panel
		local ch = string.sub(code, i, i)
		if ch == "0" and code == Visor.IDLE then
			-- idle face: each eye is drawn open and closed; VisorFaces (client) swaps them to blink
			surface:ClearAllChildren()
			surface.CanvasSize = NumberStyles.Canvas(style)
			for _, state in ipairs({{"Open", "O", true}, {"Closed", "-", false}}) do
				local layer = Instance.new("Frame")
				layer.Name = state[1]; layer.BackgroundTransparency = 1; layer.Size = UDim2.fromScale(1, 1); layer.Visible = state[3]
				layer.Parent = surface
				NumberStyles.Draw(layer, state[2], style, surface.Brightness, surface.CanvasSize.Y)
			end
		else
			drawDigit(surface, ch, color, surface.Brightness, sheet, not sheet and style or nil)
		end
		local mask = surface:Clone()
		mask.Name = "MaskNumber"; mask.Enabled = false
		mask.Parent = panel
		drawDigit(mask, "*", color, surface.Brightness, nil, style)
	end
	if code == Visor.IDLE or code == Visor.DEAD then anchor:SetAttribute("Face", code) end
	if code == Visor.IDLE then anchor:AddTag("VisorBlink") end  -- StarterPlayerScripts.VisorFaces blinks the eyes
	return anchor
end
-- faces shown instead of a number
Visor.IDLE = "0__0"   -- no number yet (menu / lobby): blinks
Visor.DEAD = "X__X"   -- eliminated

return Visor
