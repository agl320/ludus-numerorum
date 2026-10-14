-- INVITE FRIENDS on the main menu (StarterGui.MARKED_UI_EDITABLE.Lobby.InviteFriends): opens Roblox's invite window
-- so you can send this game to your friends.
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local player = Players.LocalPlayer
local button = player:WaitForChild("PlayerGui"):WaitForChild("MARKED_UI_EDITABLE"):WaitForChild("Lobby"):WaitForChild("InviteFriends")
local label = button:FindFirstChild("Label")
local busy = false
local function flash(text)
	if not label then return end
	label.Text = text
	task.delay(2.5, function() if label.Parent then label.Text = "INVITE FRIENDS" end end)
end
button.Activated:Connect(function()
	if busy then return end
	busy = true
	local ok, can = pcall(function() return SocialService:CanSendGameInviteAsync(player) end)
	if ok and can then
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Come play MARKED with me!"
		local shown = pcall(function() SocialService:PromptGameInvite(player, options) end)
		if not shown then pcall(function() SocialService:PromptGameInvite(player) end) end
	else
		flash("INVITES UNAVAILABLE")
	end
	task.wait(1)
	busy = false
end)
