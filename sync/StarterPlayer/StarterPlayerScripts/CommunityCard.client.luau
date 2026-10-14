-- SUPPORT MARKED card: favourite the game, like it, and join the MARKED group for a one-time marks reward
-- (ServerScriptService.ProfileService:ClaimGroupReward checks the membership and pays). Shown once to new players on
-- the main menu, and any time from the JOIN COMMUNITY buttons (they set the player attribute OpenCommunity).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local menu = shared:WaitForChild("Menu")
local GROUP_ID, REWARD = 638378027, 1000

local INK = Color3.fromRGB(10, 6, 8); local TILE = Color3.fromRGB(18, 12, 14); local LINE = Color3.fromRGB(70, 26, 38)
local RED = Color3.fromRGB(255, 23, 74); local BLOOD = Color3.fromRGB(150, 0, 32); local BONE = Color3.fromRGB(240, 232, 228)
local MUTED = Color3.fromRGB(160, 144, 148); local GOLD = Color3.fromRGB(236, 190, 92)
local BAL = Font.new("rbxasset://fonts/families/Balthazar.json")
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

local function mk(class, props, parent) local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o end
local function corner(o, r) mk("UICorner", {CornerRadius = UDim.new(0, r or 6)}, o) end
local function stroke(o, c, t) return mk("UIStroke", {Color = c, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function text(parent, props)
	local base = {BackgroundTransparency = 1, TextColor3 = BONE, FontFace = BODY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true}
	for k, v in pairs(props) do base[k] = v end
	return mk("TextLabel", base, parent)
end
local function button(parent, label, pos, size, primary)
	local b = mk("TextButton", {Text = label, FontFace = BOLD, TextSize = 13, TextColor3 = BONE, AutoButtonColor = false, Position = pos, Size = size,
		BackgroundColor3 = primary and Color3.fromRGB(170, 12, 40) or TILE}, parent)
	corner(b, 5)
	local s = stroke(b, primary and Color3.fromRGB(255, 90, 115) or LINE)
	b.MouseEnter:Connect(function() s.Color = BONE end)
	b.MouseLeave:Connect(function() s.Color = primary and Color3.fromRGB(255, 90, 115) or LINE end)
	return b
end

local gui = mk("ScreenGui", {Name = "CommunityCard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Enabled = false}, player:WaitForChild("PlayerGui"))
-- Modal: frees the cursor while the card is up, even in first person
local shade = mk("TextButton", {Text = "", AutoButtonColor = false, Modal = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1)}, gui)
local card = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 372), BackgroundColor3 = INK}, gui)
corner(card, 8); stroke(card, Color3.fromRGB(150, 20, 46), 1.4)
local scale = mk("UIScale", {}, card)
local function fit() local v = gui.AbsoluteSize; scale.Scale = math.clamp(math.min(v.X / 640, v.Y / 480), 0.6, 1.15) end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit); fit()
local wash = mk("Frame", {BackgroundColor3 = BLOOD, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 86)}, card)
corner(wash, 8)
mk("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)})}, wash)
text(card, {Text = "WELCOME TO MARKED", FontFace = BOLD, TextSize = 11, TextColor3 = Color3.fromRGB(255, 120, 140), Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(400, 14)})
text(card, {Text = "Support the game", FontFace = BAL, TextSize = 34, Position = UDim2.fromOffset(22, 32), Size = UDim2.fromOffset(440, 40)})
local close = button(card, "X", UDim2.new(1, -44, 0, 14), UDim2.fromOffset(30, 30))

local function row(y, icon, title, body)
	local r = mk("Frame", {BackgroundColor3 = TILE, Position = UDim2.fromOffset(18, y), Size = UDim2.fromOffset(484, 74)}, card)
	corner(r, 6); stroke(r, LINE)
	local t = mk("Frame", {BackgroundColor3 = Color3.fromRGB(34, 8, 15), Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(48, 48)}, r)
	corner(t, 6); stroke(t, Color3.fromRGB(110, 20, 40))
	text(t, {Text = icon, FontFace = BOLD, TextSize = 22, TextColor3 = RED, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center})
	local tl = text(r, {Text = title, FontFace = BOLD, TextSize = 14, Position = UDim2.fromOffset(74, 12), Size = UDim2.fromOffset(270, 18)})
	text(r, {Text = body, TextSize = 12, TextColor3 = MUTED, Position = UDim2.fromOffset(74, 32), Size = UDim2.fromOffset(270, 32), TextYAlignment = Enum.TextYAlignment.Top})
	return r, tl
end
local favRow = row(100, "★", "FAVOURITE MARKED", "Find it in one tap next time and get notified about updates.")
local fav = button(favRow, "FAVOURITE", UDim2.new(1, -128, 0.5, -16), UDim2.fromOffset(116, 32), true)
local likeRow = row(182, "▲", "LEAVE A LIKE", "Tap the thumbs-up under MARKED on its Roblox page. It helps new players find us.")
text(likeRow, {Text = "ON THE GAME PAGE", FontFace = BOLD, TextSize = 10, TextColor3 = MUTED, Position = UDim2.new(1, -128, 0.5, -8), Size = UDim2.fromOffset(116, 16),
	TextXAlignment = Enum.TextXAlignment.Center})
local groupRow, groupTitle = row(264, "+", "JOIN THE GROUP  ·  +" .. REWARD .. " MARKS", "Join the MARKED group for a one-time reward of " .. REWARD .. " marks.")
local groupBtn = button(groupRow, "JOIN GROUP", UDim2.new(1, -128, 0.5, -16), UDim2.fromOffset(116, 32), true)
groupTitle.TextColor3 = GOLD

local function refresh()
	local claimed = player:GetAttribute("GroupRewarded") == true
	groupBtn.Text = claimed and "CLAIMED" or "JOIN GROUP"
	groupBtn.Active = not claimed; groupBtn.AutoButtonColor = false
	groupBtn.BackgroundColor3 = claimed and TILE or Color3.fromRGB(170, 12, 40)
end
player:GetAttributeChangedSignal("GroupRewarded"):Connect(refresh)

local function open()
	refresh()
	gui.Enabled = true
	card.Position = UDim2.new(0.5, 0, 0.5, 24)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.fromScale(0.5, 0.5)}):Play()
end
local function shut()
	gui.Enabled = false
	if player:GetAttribute("CommunitySeen") ~= true then menu:FireServer("CommunitySeen") end
end
close.Activated:Connect(shut)
shade.Activated:Connect(shut)

-- Roblox's own "Add to Favourites" prompt (the same one the game page uses)
local function promptFavourite()
	local ok = pcall(function() AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true) end)
	if not ok then fav.Text = "ON GAME PAGE" end
end
AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success then
		fav.Text = "FAVOURITED"; fav.BackgroundColor3 = TILE
	end
end)
fav.Activated:Connect(promptFavourite)
groupBtn.Activated:Connect(function()
	if player:GetAttribute("GroupRewarded") == true then return end
	local inGroup = false
	pcall(function() inGroup = player:IsInGroup(GROUP_ID) end)
	if not inGroup then
		local ok, status = pcall(function() return GroupService:PromptJoinAsync(GROUP_ID) end)
		inGroup = ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember)
		if not ok then groupBtn.Text = "TRY AGAIN" return end
		if ok and status == Enum.GroupMembershipStatus.JoinRequestPending then groupBtn.Text = "REQUEST SENT" return end
	end
	if inGroup then groupBtn.Text = "CLAIMING…"; menu:FireServer("ClaimGroupReward") end
end)

-- JOIN COMMUNITY buttons
player:GetAttributeChangedSignal("OpenCommunity"):Connect(open)
-- new players: once, on the main menu, a few seconds after their profile loads
task.spawn(function()
	while player:GetAttribute("ProfileReady") ~= true do player:GetAttributeChangedSignal("ProfileReady"):Wait() end
	if player:GetAttribute("CommunitySeen") == true then return end
	task.wait(4)
	-- wait for the main menu (not during the intro or a match)
	local lobby = player.PlayerGui:WaitForChild("MARKED_UI_EDITABLE"):WaitForChild("Lobby")
	while not (lobby.Visible and player:GetAttribute("IntroPlaying") ~= true and player:GetAttribute("InMatch") ~= true) do task.wait(1) end
	if player:GetAttribute("CommunitySeen") ~= true and not gui.Enabled then
		open()
		-- first visit: pop Roblox's favourite prompt straight away on top of the card (the group row stays underneath)
		task.wait(0.8)
		if gui.Enabled then promptFavourite() end
	end
end)
