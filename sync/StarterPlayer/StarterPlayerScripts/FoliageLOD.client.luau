-- Performance (this screen only): the see-through foliage layers thin out with distance.
-- The map has ~7,000 alpha-blended decals (grass tufts, bush and tree leaf cards); each is drawn over whatever is
-- behind it, which is one of the most expensive things to draw, above all on phones.
--   * grass tufts (tiny, ankle height): hidden past GRASS studs
--   * bushes: hidden past BUSH studs
--   * tree leaf cards: every other card hidden past TREE_THIN studs (a far canopy reads the same with half its
--     cards), the rest kept so trees never go bare
-- Low End Mode (Settings) shortens all of it. Only the decals' own Transparency is touched (FoliageFade uses
-- LocalTransparencyModifier up close), and the original value is put back as soon as it comes into range.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local RANGES = {
	normal = {grass = 90, bush = 150, tree = 170},
	low = {grass = 55, bush = 95, tree = 110},
}
local BATCH_EVERY = 0.1 -- a slice of the list every 0.1 s: the whole list once a second
local SLICES = 10

local items = {} -- {decal, kind, pos, original, hidden, odd}
local known = {}
local parity = setmetatable({}, {__mode = "k"})
local counter = 0

local function kindOf(decal)
	local part = decal.Parent
	if not part or not part:IsA("BasePart") then return nil end
	if part.Name == "Grass" then return "grass" end
	if part.Name == "Leaves" then
		local m = part:FindFirstAncestorWhichIsA("Model")
		if m and m.Name == "Bush" then return "bush" end
		if m and m.Name == "Tree" then return "tree" end
	end
	return nil
end

local function add(d)
	if known[d] or not d:IsA("Decal") then return end
	local kind = kindOf(d)
	if not kind then return end
	known[d] = true
	-- (every other CARD, not every other decal: a card carries a decal on each side)
	local part = d.Parent
	local odd = parity[part]
	if odd == nil then counter += 1; odd = counter % 2 == 1; parity[part] = odd end
	table.insert(items, {decal = d, kind = kind, pos = part.Position, original = d.Transparency, hidden = false, odd = odd})
end

local city = workspace:WaitForChild("SunsetCity", 60)
if not city then return end
for i, d in ipairs(city:GetDescendants()) do
	add(d)
	if i % 5000 == 0 then task.wait() end
end
-- (streaming: tufts and trees that load in later join the list)
city.DescendantAdded:Connect(function(d)
	if d:IsA("Decal") then task.defer(add, d) end
end)

local function rangesNow()
	return player:GetAttribute("LowEnd") == true and RANGES.low or RANGES.normal
end

local slice = 0
while true do
	task.wait(BATCH_EVERY)
	local cam = workspace.CurrentCamera
	if cam then
		local eye = cam.CFrame.Position
		local r = rangesNow()
		slice = (slice + 1) % SLICES
		local i = slice + 1
		while i <= #items do
			local it = items[i]
			local d = it.decal
			if d.Parent == nil then
				-- (streamed out or removed: drop it; it re-joins if it comes back)
				known[d] = nil
				items[i] = items[#items]; items[#items] = nil
			else
				local dist = (it.pos - eye).Magnitude
				local hide
				if it.kind == "grass" then hide = dist > r.grass
				elseif it.kind == "bush" then hide = dist > r.bush
				else hide = it.odd and dist > r.tree end
				if hide ~= it.hidden then
					it.hidden = hide
					d.Transparency = hide and 1 or it.original
				end
				i += SLICES
			end
		end
	end
end
