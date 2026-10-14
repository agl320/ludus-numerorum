-- Chat tags for the old Legacy chat (TextChatService.ChatVersion = LegacyChatService): [OWNER] / [MOD] and a gold
-- [VIP] in front of names. The current chat (TextChatService) is handled by StarterPlayerScripts.ChatTags.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")
if TextChatService.ChatVersion ~= Enum.ChatVersion.LegacyChatService then return end

local runner = ServerScriptService:WaitForChild("ChatServiceRunner", 60)
if not runner then return end
local ChatService = require(runner:WaitForChild("ChatService"))

local ROLE = {
	OWNER = {TagText = "OWNER", TagColor = Color3.fromRGB(255, 23, 74)},
	MOD = {TagText = "MOD", TagColor = Color3.fromRGB(90, 180, 255)},
}
local VIP = {TagText = "VIP", TagColor = Color3.fromRGB(236, 190, 92)}

local function apply(p)
	local speaker = ChatService:GetSpeaker(p.Name)
	if not speaker then return end
	-- one tag only: OWNER / MOD take priority over VIP
	local tag = ROLE[p:GetAttribute("ChatRole") or ""] or (p:GetAttribute("VIP") == true and VIP) or nil
	speaker:SetExtraData("Tags", tag and {tag} or {})
end
local function watch(p)
	p:GetAttributeChangedSignal("VIP"):Connect(function() apply(p) end)
	p:GetAttributeChangedSignal("ChatRole"):Connect(function() apply(p) end)
	apply(p)
end
ChatService.SpeakerAdded:Connect(function(name)
	local p = Players:FindFirstChild(name)
	if p then apply(p) end
end)
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do watch(p) end
