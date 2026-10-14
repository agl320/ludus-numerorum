-- Overhead badges: OWNER for the game's owner, MOD for every other admin (player attribute ChatRole, set by
-- ServerScriptService.AdminService -- the owner only ever gets OWNER), and VIP for VIP players (player attribute VIP,
-- set by ServerScriptService.Monetization / the admin panel). One badge per player: admins have VIP automatically,
-- so they only ever show their role badge.
-- Built here on each screen, on the head, so they follow head swaps and never replicate. Lobby only: a badge is hidden
-- while that player is in a round (InArena), so it can't give away who or where they are. Your own is hidden in first
-- person.
--
-- The look (all built from frames, no images):
--   OWNER  a black-and-crimson plate with a gold frame, a gold crown on top, gold lettering with a light sweeping across
--          it and the frame, a pulsing gold halo, filigree lines and twinkling sparks either side. The showpiece.
--   MOD    a midnight-blue plate with a steel frame, silver-blue lettering with a slower sweep, a shield-point
--          diamond above, steel filigree lines.
--   VIP    a royal-purple plate with a gold frame, pale-gold lettering with a sweep, its own small coronet on top (three
--          diamond-tipped points and an amethyst -- not the owner's crown), short gold lines either side.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local me = Players.LocalPlayer

local MAX_DISTANCE = 70
-- the title is sized in the world, not on screen: it keeps its size against the body however far away or high up the
-- camera is (it used to stay the same number of pixels, so it looked bigger the further away you were).
-- PX_PER_STUD = how many of the badge's design pixels make one stud.
local PX_PER_STUD = 60
local FONT = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold)
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function cs(points)
	local k = {}
	for _, p in ipairs(points) do table.insert(k, ColorSequenceKeypoint.new(p[1], p[2])) end
	return ColorSequence.new(k)
end
local function ns(points)
	local k = {}
	for _, p in ipairs(points) do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end
-- a metal with a bright band in the middle: the band is what sweeps across (UIGradient.Offset is animated)
local function sheen(base, mid, light)
	return cs({{0, base}, {0.38, mid}, {0.47, light}, {0.5, rgb(255, 255, 255)}, {0.53, light}, {0.62, mid}, {1, base}})
end
-- (the title itself is built by ReplicatedStorage.Numberfall.BadgeArt.Title, so the lobby profile card shows exactly
-- the same thing)
local BadgeArt = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("BadgeArt"))
local BADGES = BadgeArt.Titles
local titles = {} -- player -> BillboardGui
local animated = {} -- BillboardGui -> info from BadgeArt.Title (sweeps, halo, sparks, period, seed)

local function build(kind)
	local holder, info, crownH = BadgeArt.Title(kind, 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RoleTitle"
	local w, h = holder.Size.X.Offset, holder.Size.Y.Offset
	gui.Size = UDim2.fromScale(w / PX_PER_STUD, h / PX_PER_STUD)
	-- (bottom of the plate sits where the old title did; anything on top grows upward)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.5 + crownH / 60, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	-- the badge is laid out in design pixels: scale it to however big the title is on screen right now
	holder.Size = UDim2.fromOffset(w, h)
	local fit = holder:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	fit.Parent = holder
	local function refit() if gui.AbsoluteSize.X > 0 then fit.Scale = gui.AbsoluteSize.X / w end end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	holder.Parent = gui
	refit()
	animated[gui] = info
	return gui
end

-- which badge this player gets: their role if they have one, otherwise VIP, otherwise none
local function kindOf(p)
	local role = p:GetAttribute("ChatRole")
	if role and BADGES[role] then return role end
	if p:GetAttribute("VIP") == true then return "VIP" end
	return nil
end

local function drop(gui)
	animated[gui] = nil
	gui:Destroy()
end

local function refresh(p)
	local kind = kindOf(p)
	local char = p.Character
	local head = char and char:FindFirstChild("Head")
	local gui = titles[p]
	if not kind or not head then
		if gui then drop(gui); titles[p] = nil end
		return
	end
	if gui and (gui:GetAttribute("Kind") ~= kind or gui.Parent ~= head) then drop(gui); gui = nil end
	if not gui then
		gui = build(kind)
		gui:SetAttribute("Kind", kind)
		gui.Adornee = head
		gui.Parent = head
		titles[p] = gui
	end
end

local function watch(p)
	p:GetAttributeChangedSignal("ChatRole"):Connect(function() refresh(p) end)
	p:GetAttributeChangedSignal("VIP"):Connect(function() refresh(p) end)
	p.CharacterAdded:Connect(function(char)
		refresh(p)
		-- the head can be swapped after spawning (classic head / body type): follow it
		char.ChildAdded:Connect(function(c) if c.Name == "Head" then task.defer(refresh, p) end end)
	end)
	if p.Character then
		p.Character.ChildAdded:Connect(function(c) if c.Name == "Head" then task.defer(refresh, p) end end)
	end
	refresh(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p) if titles[p] then drop(titles[p]); titles[p] = nil end end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watch, p) end

-- show / hide (dead, ragdolled, in a round, your own in first person), ten times a second
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	acc = 0
	local cam = workspace.CurrentCamera
	for p, gui in pairs(titles) do
		if not gui.Parent then titles[p] = nil; animated[gui] = nil; task.defer(refresh, p)
		else
			local char = p.Character
			local h = char and char:FindFirstChildOfClass("Humanoid")
			local show = h ~= nil and h.Health > 0 and not char:GetAttribute("Ragdolled") and p:GetAttribute("InArena") ~= true
			if show and p == me and cam then
				local head = gui.Parent
				show = (cam.CFrame.Position - head.Position).Magnitude > 3
			end
			if gui.Enabled ~= show then gui.Enabled = show end
		end
	end
end)

-- the light sweep, the halo breathing and the sparks twinkling (only for badges on screen, ~30 times a second)
local animAcc = 0
RunService.RenderStepped:Connect(function(dt)
	animAcc += dt
	if animAcc < 1 / 30 then return end
	animAcc = 0
	local now = os.clock()
	for gui, info in pairs(animated) do
		if gui.Enabled and gui.Parent then
			BadgeArt.AnimateTitle(info, now)
		end
	end
end)
