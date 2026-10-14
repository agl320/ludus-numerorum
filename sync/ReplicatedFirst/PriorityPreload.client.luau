-- Loads what you SEE first: the menus / HUD artwork (match intro, players list, number entry...) and the
-- notebook you write in. Roblox loads assets one queue at a time, and the music, sound effects and footsteps
-- (dozens of files) used to go first, so on a real server the intro frames, Tab and the notebook showed up late
-- or blank. The audio preloads (SoundController, MarkedMusic, Footsteps) wait for the player attribute
-- UIPreloaded that this sets (or 12 s at most).
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local player = Players.LocalPlayer
local list = {}
local starter = game:GetService("StarterGui")
local ui = starter:WaitForChild("MARKED_UI_EDITABLE", 20)
if ui then
	-- the panels that pop up mid-game first, then everything else in the UI
	for _, name in ipairs({"MatchIntro", "Leaderboard", "Entry", "TargetLock", "MatchHUD", "CombatBanner", "Lobby"}) do
		local p = ui:FindFirstChild(name)
		if p then table.insert(list, p) end
	end
	table.insert(list, ui)
end
local nf = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall", 20)
local notebook = nf and nf:FindFirstChild("NotebookAssets")
if notebook then table.insert(list, notebook) end
local t0 = os.clock()
pcall(function() ContentProvider:PreloadAsync(list) end)
player:SetAttribute("UIPreloaded", true)
player:SetAttribute("UIPreloadSeconds", math.floor((os.clock() - t0) * 10 + 0.5) / 10)
