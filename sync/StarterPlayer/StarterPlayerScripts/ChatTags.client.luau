-- Chat tags in front of names: [OWNER] / [MOD] (ChatRole, set by ServerScriptService.AdminService) and a gold [VIP].
-- This one handles the current chat (TextChatService); ServerScriptService.ChatTagsLegacy covers the old Legacy chat.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then return end

local ROLE = {
	OWNER = '<font color="#FF174A"><b>[OWNER]</b></font>',
	MOD = '<font color="#5AB4FF"><b>[MOD]</b></font>',
}
local VIP = '<font color="#ECBE5C"><b>[VIP]</b></font>'

local function tagsFor(p)
	-- one tag only: OWNER / MOD take priority over VIP
	local tag = ROLE[p:GetAttribute("ChatRole") or ""] or (p:GetAttribute("VIP") == true and VIP) or nil
	return tag and (tag .. " ") or ""
end

TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local p = source and Players:GetPlayerByUserId(source.UserId)
	if p then
		local tags = tagsFor(p)
		if tags ~= "" then props.PrefixText = tags .. message.PrefixText end
	end
	return props
end
