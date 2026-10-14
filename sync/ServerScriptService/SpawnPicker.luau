-- One place that hands out match spawns, shared by players (CharacterService) and bots (BotService), so two fighters
-- are never put on the same SpawnLocation. Each pick goes to the spawn farthest from everyone already in the arena,
-- and a spawn just handed out counts as taken for a few seconds -- at the round start everybody spawns in the same
-- moment, before anyone has moved onto their spawn, which is how several used to land on one.
local M = {}
local CLAIM_SECONDS = 6
local NEAR_ENOUGH = 700 -- bodies farther than this from a spawn (the lobby) don't count
local claims = {} -- SpawnLocation -> os.clock() it was handed out

-- spawns: candidate SpawnLocations; others: positions of the fighters already in the arena
function M.Pick(spawns, others)
	local now = os.clock()
	-- spawns handed out a moment ago count as someone standing there (so a round start spreads everyone out)
	local occupied = table.clone(others)
	for s, at in pairs(claims) do
		if now - at < CLAIM_SECONDS and s.Parent then table.insert(occupied, s.Position) end
	end
	local best, bestScore = nil, -math.huge
	for _, s in ipairs(spawns) do
		local near = 1e6
		for _, o in ipairs(occupied) do
			local d = (o - s.Position).Magnitude
			if d < NEAR_ENOUGH and d < near then near = d end
		end
		local claimed = claims[s] and now - claims[s] < CLAIM_SECONDS
		-- taken spawns go to the back of the queue; ties broken at random so it isn't always the same one
		local score = (claimed and -1e6 + near or near) + math.random() * 6
		if score > bestScore then best, bestScore = s, score end
	end
	if best then claims[best] = now end
	return best
end

return M
