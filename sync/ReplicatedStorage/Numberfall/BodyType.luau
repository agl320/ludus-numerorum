-- BODY TYPES: reshapes a character's UpperTorso / LowerTorso into the ones in Numberfall.BodyParts.<Parts>
-- (Classic = the standard blocky torso, Woman = the Roblox woman torso). Used by the server on real characters
-- (ServerScriptService.Forehead) and by the Loadout / Shop previews on their anchored clones, so the menu shows
-- exactly what you get in game. Re-dress the outfit after a change (Numberfall.Outfits.Apply).
--
-- The torso parts are NOT replaced: the same parts get the other mesh (MeshPart:ApplyMesh), size and rig
-- attachments, and the joints are re-seated from the attachments. Replacing the parts made the server and the
-- client disagree for a moment about which part the joints held, so the body could fall apart (cut in half),
-- vanish, or the Humanoid could die from a missing neck.
local RS = game:GetService("ReplicatedStorage")
local Extras = require(RS:WaitForChild("Numberfall"):WaitForChild("Extras"))
local Parts = RS.Numberfall:WaitForChild("BodyParts")
local B = {}
local NAMES = {"UpperTorso", "LowerTorso"}
-- legs: the feminine body has slimmer legs (width X, depth Z) so they sit under its narrower hips without overlapping
local LEGS = {"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"}
local LEG_SCALE = {BodyWoman = Vector3.new(0.64, 1, 0.86)}
-- torso parts reshaped on top of the template mesh (width X, depth Z): the feminine lower torso is narrowed so the
-- waist and hips run on from the narrow upper torso instead of flaring out (it was wider than the chest)
local SHAPE = {BodyWoman = {LowerTorso = Vector3.new(0.76, 1, 0.9)}}
local function shapeOf(id, name) return SHAPE[id] and SHAPE[id][name] or Vector3.one end
-- arms: slimmer too on the feminine body (width X, depth Z), so they don't look bulky next to its narrow torso
local ARMS = {"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand"}
local ARM_SCALE = {BodyWoman = Vector3.new(0.76, 1, 0.82)}
local LIMBS = {}
for _, n in ipairs(LEGS) do LIMBS[#LIMBS + 1] = {n, LEG_SCALE} end
for _, n in ipairs(ARMS) do LIMBS[#LIMBS + 1] = {n, ARM_SCALE} end

function B.Id(id) local b = Extras.Get(id); return (b and b.Kind == "body") and b.Id or Extras.DefaultBody end
function B.Current(model)
	local t = model:FindFirstChild("UpperTorso")
	return t and t:GetAttribute("BodyType") or Extras.DefaultBody
end
local function template(id, name)
	local def = Extras.Get(B.Id(id))
	local folder = Parts:FindFirstChild(def and def.Parts or "Classic") or Parts:FindFirstChild("Classic")
	return folder and folder:FindFirstChild(name)
end

-- Reshape `model`'s torso into body type `id`. live: a real character. Returns true if anything changed.
function B.Apply(model, id, live)
	id = B.Id(id)
	local touched = {}
	local changed = false
	for _, name in ipairs(NAMES) do
		local part = model:FindFirstChild(name)
		local tpl = template(id, name)
		local cur = part and (part:GetAttribute("BodyType") or Extras.DefaultBody)
		if part and part:IsA("MeshPart") and tpl and cur ~= id then
			-- the character's own scale: its size against the template of the body it has now
			local curTpl = template(cur, name)
			local scale = Vector3.one
			local sh = shapeOf(id, name)
			if curTpl then
				scale = part.Size / (curTpl.Size * (part:GetAttribute("TorsoShape") or Vector3.one))
				if scale.X < 0.3 or scale.X > 3 or scale.Y < 0.3 or scale.Y > 3 or scale.Z < 0.3 or scale.Z > 3 then scale = Vector3.one end
			end
			local tex = part.TextureID
			local ok = pcall(function() part:ApplyMesh(tpl) end)
			if not ok then warn("[BodyType] ApplyMesh failed on " .. name) end
			if ok then
				pcall(function() part.TextureID = tex end)
				part.Size = tpl.Size * scale * sh
				part:SetAttribute("TorsoShape", sh ~= Vector3.one and sh or nil)
				for _, a in ipairs(tpl:GetChildren()) do
					if a:IsA("Attachment") then
						local mine = part:FindFirstChild(a.Name)
						if not (mine and mine:IsA("Attachment")) then mine = Instance.new("Attachment"); mine.Name = a.Name; mine.Parent = part end
						mine.CFrame = CFrame.new(a.Position * scale * sh) * a.CFrame.Rotation
					end
				end
				local os = part:FindFirstChild("OriginalSize")
				local tos = tpl:FindFirstChild("OriginalSize")
				if os and tos then os.Value = tos.Value end
				local st, tst = part:FindFirstChild("AvatarPartScaleType"), tpl:FindFirstChild("AvatarPartScaleType")
				if tst and not st then tst:Clone().Parent = part elseif st and not tst then st:Destroy() elseif st and tst then st.Value = tst.Value end
				part:SetAttribute("BodyType", id)
				touched[part] = true
				changed = true
			end
		end
	end
	-- torso already this body type: make sure its rig attachments still match the template. Roblox's avatar scaling
	-- rebuilds every attachment from its OriginalPosition whenever the character is (re)scaled or parented (spawn,
	-- preview clones), which used to put the shoulders back at the classic width: the arms floated off the torso.
	for _, name in ipairs(NAMES) do
		local part = model:FindFirstChild(name)
		local tpl = template(id, name)
		if part and part:IsA("MeshPart") and tpl and not touched[part] and (part:GetAttribute("BodyType") or Extras.DefaultBody) == id then
			local have, sh = part:GetAttribute("TorsoShape") or Vector3.one, shapeOf(id, name)
			if (have - sh).Magnitude > 1e-3 then
				part.Size = part.Size / have * sh
				part:SetAttribute("TorsoShape", sh ~= Vector3.one and sh or nil)
				changed = true
			end
			local scale = part.Size / tpl.Size
			if scale.X < 0.3 or scale.X > 3 or scale.Y < 0.3 or scale.Y > 3 or scale.Z < 0.3 or scale.Z > 3 then scale = Vector3.one end
			for _, a in ipairs(tpl:GetChildren()) do
				if a:IsA("Attachment") then
					local mine = part:FindFirstChild(a.Name)
					local want = a.Position * scale
					if mine and mine:IsA("Attachment") and (mine.Position - want).Magnitude > 0.01 then
						mine.CFrame = CFrame.new(want) * a.CFrame.Rotation
						touched[part] = true
						changed = true
					end
				end
			end
		end
	end
	-- legs and arms
	for _, limb in ipairs(LIMBS) do
		local name, want = limb[1], limb[2][id] or Vector3.one
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local cur = part:GetAttribute("LegScale") or Vector3.one
			if (cur - want).Magnitude > 1e-3 then
				local base = part:GetAttribute("BaseSize")
				if not base then base = part.Size / cur; part:SetAttribute("BaseSize", base) end
				local k = want / cur
				part.Size = base * want
				for _, a in ipairs(part:GetChildren()) do
					if a:IsA("Attachment") then a.Position = a.Position * Vector3.new(k.X, 1, k.Z) end
				end
				local os = part:FindFirstChild("OriginalSize")
				if os and os:IsA("Vector3Value") then os.Value = os.Value * k end
				part:SetAttribute("LegScale", want)
				touched[part] = true
				changed = true
			end
		end
	end
	-- keep Roblox's scaling data in step with the reshaped parts: each attachment's OriginalPosition is what avatar
	-- scaling rebuilds it from (position = OriginalPosition * Size / OriginalSize), so write it back from where the
	-- attachment is now. Without this a rescale / re-parent snapped the body back to the classic joint positions.
	local function syncOriginals(part)
		local os = part:FindFirstChild("OriginalSize")
		if not (os and os:IsA("Vector3Value")) then return end
		local o = os.Value
		if o.X <= 0 or o.Y <= 0 or o.Z <= 0 then return end
		local r = part.Size / o
		for _, a in ipairs(part:GetChildren()) do
			if a:IsA("Attachment") then
				local op = a:FindFirstChild("OriginalPosition")
				if op and op:IsA("Vector3Value") then
					local v = a.Position / r
					if (op.Value - v).Magnitude > 1e-3 then op.Value = v end
				end
			end
		end
	end
	for _, name in ipairs(NAMES) do local part = model:FindFirstChild(name); if part then syncOriginals(part) end end
	for _, limb in ipairs(LIMBS) do local part = model:FindFirstChild(limb[1]); if part then syncOriginals(part) end end
	if changed then
		-- re-seat every joint on the reshaped parts from their rig attachments
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part0 and d.Part1 and (touched[d.Part0] or touched[d.Part1]) then
				local a0 = d.Part0:FindFirstChild(d.Name .. "RigAttachment")
				local a1 = d.Part1:FindFirstChild(d.Name .. "RigAttachment")
				if a0 and a1 then d.C0 = a0.CFrame; d.C1 = a1.CFrame end
			end
		end
	end
	return changed
end
-- Client-side safety net (SlideAnimator runs it every half second, while the joints are at rest): put the torso's
-- rig attachments back where this body type has them (the same rule the server uses above). If a reshape from the
-- server ever got overwritten on this screen, the arms would otherwise float off the torso at the classic width
-- until the next respawn.
function B.Heal(model)
	for _, name in ipairs(NAMES) do
		local part = model:FindFirstChild(name)
		local id = part and part:GetAttribute("BodyType")
		local tpl = id and template(id, name)
		if tpl and part:IsA("BasePart") then
			local scale = part.Size / tpl.Size
			if scale.X >= 0.3 and scale.X <= 3 and scale.Y >= 0.3 and scale.Y <= 3 and scale.Z >= 0.3 and scale.Z <= 3 then
				for _, a in ipairs(tpl:GetChildren()) do
					if a:IsA("Attachment") and a.Name:find("RigAttachment") then
						local mine = part:FindFirstChild(a.Name)
						local want = a.Position * scale
						if mine and mine:IsA("Attachment") and (mine.Position - want).Magnitude > 0.02 then
							mine.CFrame = CFrame.new(want) * a.CFrame.Rotation
						end
					end
				end
			end
		end
	end
end
return B
