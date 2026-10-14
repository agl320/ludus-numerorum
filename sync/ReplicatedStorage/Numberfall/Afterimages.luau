-- AFTERIMAGES: the trail of glowing copies of the body left by a dash or a wall launch, styled by rank:
--   everyone   red (the game's accent)
--   VIP        amethyst violet, flecked with gold dust
--   MOD        steel blue, flecked with silver
--   OWNER      crimson and gold in turn, gold dust, a slightly longer and denser trail
--   + the trail colours bought in the Shop / won from cases (Numberfall.TrailColors: their Look)
-- Used by StarterPlayerScripts.AbilityFX (dashes, timed with the dash wind) and WallFX (wall launches).
--   Afterimages.Trail(character, duration)   a run of afterimages over `duration` seconds
--   Afterimages.Rank(character) -> "OWNER" | "MOD" | "VIP" | "default"
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local M = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
M.FADE = 0.3 -- each afterimage fades over this long (the dash wind's ribbons use the same)
local STYLES = {
	default = {colors = {rgb(255, 58, 74)}, transparency = 0.72},
	VIP = {colors = {rgb(184, 104, 255), rgb(132, 64, 220)}, transparency = 0.7, dust = rgb(255, 214, 120)},
	MOD = {colors = {rgb(156, 206, 255), rgb(92, 148, 236)}, transparency = 0.7, dust = rgb(226, 240, 255)},
	OWNER = {colors = {rgb(236, 30, 60), rgb(255, 196, 82)}, transparency = 0.67, dust = rgb(255, 228, 150), dense = true, longer = 1.2},
}
-- the bought trail colours, by their id
for _, t in ipairs(require(script.Parent:WaitForChild("TrailColors")).List) do STYLES[t.Id] = t.Look end
M.Styles = STYLES
local BODY = {
	Head = true, UpperTorso = true, LowerTorso = true, Torso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}
local RANGE = 170

local folder = workspace:FindFirstChild("Afterimages")
if not folder then folder = Instance.new("Folder"); folder.Name = "Afterimages"; folder.Parent = workspace end

-- the trail a player picked in Loadout > TRAIL, from the ones their rank unlocks (Numberfall.RankLooks)
local RankLooks = require(script.Parent:WaitForChild("RankLooks"))
function M.Rank(character)
	local p = Players:GetPlayerFromCharacter(character)
	if not p then return "default" end
	local id = RankLooks.Trail(p)
	return id ~= "Standard" and id or "default"
end

local function lowEnd()
	local me = Players.LocalPlayer
	return me and me:GetAttribute("LowEnd") == true
end

-- a pinch of glittering dust at the body (the ranked trails)
local function dust(root, color)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
	a.Transparency = 1; a.Size = Vector3.new(1.6, 2.6, 1); a.CFrame = root.CFrame; a.Parent = folder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Enabled = false
	e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Color = ColorSequence.new(color); e.LightEmission = 0.9; e.LightInfluence = 0
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(0.3, 0.5); e.Speed = NumberRange.new(0.5, 2); e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3; e.Rotation = NumberRange.new(0, 360)
	e.Parent = a
	e:Emit(3)
	Debris:AddItem(a, 0.6)
end

-- one afterimage of the body where it is now (`i` picks the colour for the two-tone trails)
-- your own body seen from inside (first person): its afterimages would cover the camera
local function ownFirstPerson(character)
	local me = Players.LocalPlayer
	return me ~= nil and character == me.Character and me:GetAttribute("OwnHeadHidden") == true
end
M.OwnFirstPerson = ownFirstPerson
function M.Ghost(character, style, i)
	if ownFirstPerson(character) then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam or (cam.CFrame.Position - root.Position).Magnitude > RANGE then return end
	local st = STYLES[style] or STYLES.default
	local color = st.colors[((i or 1) - 1) % #st.colors + 1]
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and BODY[part.Name] and part.Transparency < 0.9 then
			local copy = Instance.new("Part")
			copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.CastShadow = true, false, false, false, false
			copy.Material = st.material or Enum.Material.Neon
			copy.Color = color
			copy.Transparency = st.transparency
			copy.Size = part.Size * 0.98
			copy.CFrame = part.CFrame
			copy.Parent = folder
			TweenService:Create(copy, TweenInfo.new(M.FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Transparency = 1, Size = part.Size * 0.8}):Play()
			Debris:AddItem(copy, M.FADE + 0.05)
		end
	end
	if st.dust and not lowEnd() then dust(root, st.dust) end
end

function M.Trail(character, duration)
	local style = M.Rank(character)
	local st = STYLES[style] or STYLES.default
	duration *= st.longer or 1
	task.spawn(function()
		local gap = lowEnd() and 0.09 or (st.dense and 0.035 or 0.045)
		local t0, i = os.clock(), 0
		while os.clock() - t0 < duration and character.Parent do
			i += 1
			M.Ghost(character, style, i)
			task.wait(gap)
		end
	end)
end

return M
