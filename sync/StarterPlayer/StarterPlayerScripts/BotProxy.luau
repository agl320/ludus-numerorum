-- Tutorial bots (ServerScriptService.TutorialService tags them MarkedBot) stand in for players in the client systems
-- that loop over players: NumberView (reading their visor) and NotebookController (their notebook, held and written in
-- like a player's). One stable table per bot, with the fields those use.
local CollectionService = game:GetService("CollectionService")
local proxies = setmetatable({}, {__mode = "k"})
local M = {}
function M.Of(model)
    local p = proxies[model]
    if not p then
        p = {Character = model, Name = model.Name, DisplayName = model:GetAttribute("DisplayName") or model.Name,
            UserId = model:GetAttribute("BotId") or 0, IsBot = true}
        function p:GetAttribute(key) if key == "InMatch" or key == "InArena" then return true end return model:GetAttribute(key) end
        proxies[model] = p
    end
    p.Parent = model.Parent
    return p
end
-- every player, then every living tutorial bot
function M.List(players)
    local list = players:GetPlayers()
    for _, model in ipairs(CollectionService:GetTagged("MarkedBot")) do table.insert(list, M.Of(model)) end
    return list
end
return M
