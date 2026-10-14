-- LOBBY LEADERBOARDS (server): the three boards in the terrace niches -- MOST PLAYED (lifetime time in game), MOST
-- ELIMINATIONS (lifetime player eliminations; bots don't count) and MOST MARKS (marks held), each to the top 1000.
--   * every player's figures are written to an OrderedDataStore every few minutes and when they leave (from the
--     attributes ProfileService publishes: StatPlaySeconds, StatKills, Coins)
--   * the top 1000 of each is read back a page (100) at a time, gently enough to stay inside the data store budget,
--     merged with this server's own players (so a board never lags behind someone standing in front of it), names
--     looked up as real usernames, and published as JSON in ReplicatedStorage.Numberfall.LobbyBoards.<Stat>
--     ([[userId, "username", value], ...]); StarterPlayerScripts.LobbyBoards draws and scrolls them.
local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local Http = game:GetService("HttpService")
local UserService = game:GetService("UserService")
local RunService = game:GetService("RunService")

local NF = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local out = NF:FindFirstChild("LobbyBoards") or Instance.new("Folder")
out.Name = "LobbyBoards"; out.Parent = NF
local ORDER = {"Playtime", "Kills", "Marks"}
local STATS = {
	Playtime = {store = "LB_Playtime_v1", attr = "StatPlaySeconds"},
	Kills = {store = "LB_Kills_v1", attr = "StatKills"},
	Marks = {store = "LB_Marks_v1", attr = "Coins"},
}
local WRITE_EVERY = 150   -- s between writes of one player's figures
local PAGE_GAP = 13       -- s between page reads (GetSortedAsync budget: 5 + 2 per player a minute)
local PAGES, PAGE_SIZE = 10, 100

local stores, values = {}, {}
for _, id in ipairs(ORDER) do
	local ok, store = pcall(function() return DSS:GetOrderedDataStore(STATS[id].store) end)
	if ok then stores[id] = store end
	local v = out:FindFirstChild(id) or Instance.new("StringValue")
	v.Name = id; v.Value = "[]"; v.Parent = out
	values[id] = v
end

------------------------------------------------------------------ names (real usernames, looked up in batches)
local names = {}
local function resolve(ids)
	local need = {}
	for _, uid in ipairs(ids) do
		if not names[uid] then
			local p = Players:GetPlayerByUserId(uid)
			if p then names[uid] = p.Name else table.insert(need, uid) end
		end
	end
	for i = 1, #need, 100 do
		local batch = {}
		for k = i, math.min(i + 99, #need) do table.insert(batch, need[k]) end
		local ok, infos = pcall(function() return UserService:GetUserInfosByUserIdsAsync(batch) end)
		if ok and infos then for _, info in ipairs(infos) do names[info.Id] = info.Username end end
	end
end

------------------------------------------------------------------ data
local function valueOf(p, id)
	local v = p:GetAttribute(STATS[id].attr)
	return typeof(v) == "number" and math.max(0, math.floor(v)) or nil
end
local lastWrite = {}
local function write(p)
	if p.UserId <= 0 then return end
	for id, store in pairs(stores) do
		local v = valueOf(p, id)
		if v then pcall(function() store:SetAsync(tostring(p.UserId), v) end) end
	end
	lastWrite[p] = os.clock()
end
Players.PlayerRemoving:Connect(function(p) write(p); lastWrite[p] = nil end)
game:BindToClose(function()
	if RunService:IsStudio() then return end
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(write, p) end
	task.wait(3)
end)

local stored = {} -- id -> {userId -> value} as last read from the store
for _, id in ipairs(ORDER) do stored[id] = {} end
local function publish(id)
	local byUser = table.clone(stored[id])
	for _, p in ipairs(Players:GetPlayers()) do
		local v = valueOf(p, id)
		if v and p.UserId > 0 then byUser[p.UserId] = math.max(byUser[p.UserId] or 0, v) end
	end
	local list = {}
	for uid, v in pairs(byUser) do table.insert(list, {uid, v}) end
	table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
	for i = #list, PAGES * PAGE_SIZE + 1, -1 do list[i] = nil end
	local ids = {}
	for _, e in ipairs(list) do table.insert(ids, e[1]) end
	resolve(ids)
	local rows = {}
	for _, e in ipairs(list) do table.insert(rows, {e[1], names[e[1]] or "user" .. e[1], e[2]}) end
	values[id].Value = Http:JSONEncode(rows)
	out:SetAttribute(id .. "Online", stores[id] ~= nil)
end

-- one page at a time: page 1 of every board first (so all three fill quickly), then the deeper pages
local function readAll()
	local pagers = {}
	for _, id in ipairs(ORDER) do
		local fresh = {}
		local store = stores[id]
		if store then
			local ok, pages = pcall(function() return store:GetSortedAsync(false, PAGE_SIZE) end)
			if ok then
				for _, e in ipairs(pages:GetCurrentPage()) do local uid = tonumber(e.key); if uid then fresh[uid] = e.value end end
				pagers[id] = pages
			end
		end
		stored[id] = fresh
		pcall(publish, id)
		task.wait(PAGE_GAP)
	end
	for _ = 2, PAGES do
		for _, id in ipairs(ORDER) do
			local pages = pagers[id]
			if pages and not pages.IsFinished then
				local ok = pcall(function() pages:AdvanceToNextPageAsync() end)
				if ok then
					for _, e in ipairs(pages:GetCurrentPage()) do local uid = tonumber(e.key); if uid then stored[id][uid] = e.value end end
					pcall(publish, id)
				else
					pagers[id] = nil
				end
				task.wait(PAGE_GAP)
			end
		end
	end
end

task.spawn(function()
	task.wait(6)
	for _, id in ipairs(ORDER) do pcall(publish, id) end -- this server's players straight away
	while true do
		for _, p in ipairs(Players:GetPlayers()) do
			if os.clock() - (lastWrite[p] or -math.huge) > WRITE_EVERY and p:GetAttribute("Coins") ~= nil then task.spawn(write, p) end
		end
		readAll()
		task.wait(30)
	end
end)
-- this server's players' own figures move between full reads
task.spawn(function()
	while task.wait(20) do for _, id in ipairs(ORDER) do pcall(publish, id) end end
end)
