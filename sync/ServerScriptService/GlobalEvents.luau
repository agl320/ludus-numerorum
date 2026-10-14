-- Cross-server announcements and global events (e.g. "DOUBLE MARKS" for 24 hours), started from the admin panel.
--   * Every live server hears about it straight away through MessagingService.
--   * The active event is also kept in a MemoryStore (expires on its own), so servers that start later pick it up.
--   * The active event lives on ReplicatedStorage.Numberfall attributes: EventName, EventMarks, EventXP, EventEndsAt
--     (EventEndsAt in Unix seconds, compare with workspace:GetServerTimeNow()). ProfileService / MatchService multiply
--     rewards by it; StarterPlayerScripts.AdminPanel shows the banner.
local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

local TOPIC = "MarkedGlobal"
local KEY = "ActiveEvent"
local G = {}

function G.Start(shared, broadcast)
	local map
	pcall(function() map = MemoryStoreService:GetHashMap("MarkedGlobal") end)
	local current

	local function apply(ev)
		local now = workspace:GetServerTimeNow()
		if type(ev) == "table" and (tonumber(ev.EndsAt) or 0) > now then
			current = ev
			shared:SetAttribute("EventName", tostring(ev.Name or "EVENT"))
			shared:SetAttribute("EventMarks", math.clamp(tonumber(ev.Marks) or 1, 1, 10))
			shared:SetAttribute("EventXP", math.clamp(tonumber(ev.XP) or 1, 1, 10))
			shared:SetAttribute("EventEndsAt", tonumber(ev.EndsAt))
			shared:SetAttribute("EventId", tostring(ev.Id or ""))
		else
			current = nil
			for _, a in ipairs({"EventName", "EventMarks", "EventXP", "EventEndsAt", "EventId"}) do shared:SetAttribute(a, nil) end
		end
	end
	local function readStore()
		if not map then return end
		local ok, value = pcall(function() return map:GetAsync(KEY) end)
		if ok then
			if type(value) == "string" then
				local ok2, ev = pcall(HttpService.JSONDecode, HttpService, value)
				apply(ok2 and ev or nil)
			else
				apply(nil)
			end
		end
	end
	local function publish(data)
		local ok, err = pcall(function() MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode(data)) end)
		return ok, err
	end

	-- live messages from any server (including this one)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(msg)
				local ok2, data = pcall(HttpService.JSONDecode, HttpService, msg.Data)
				if not ok2 or type(data) ~= "table" then return end
				if data.Kind == "Announce" then
					broadcast:FireAllClients("Announce", {Text = tostring(data.Text), From = tostring(data.From), Global = true})
				elseif data.Kind == "Event" then
					apply(data.Event)
					broadcast:FireAllClients("Event", {Name = data.Event and data.Event.Name, Started = true})
				elseif data.Kind == "EventEnd" then
					apply(nil)
					broadcast:FireAllClients("Event", {Started = false})
				end
			end)
		end)
		if not ok then warn("[GlobalEvents] couldn't subscribe: " .. tostring(err)) end
	end)
	-- pick up an event that's already running, then keep it fresh (and clear it when it runs out)
	task.spawn(function()
		readStore()
		local t = 0
		while true do
			task.wait(15)
			t += 15
			if current and (tonumber(current.EndsAt) or 0) <= workspace:GetServerTimeNow() then apply(nil) end
			if t >= 120 then t = 0; readStore() end
		end
	end)

	-- API (AdminService) --------------------------------------------------------
	function G.Announce(text, from)
		local ok, err = publish({Kind = "Announce", Text = text, From = from})
		if not ok then
			-- MessagingService down: at least this server hears it
			broadcast:FireAllClients("Announce", {Text = text, From = from, Global = true})
			return false, tostring(err)
		end
		return true
	end
	function G.StartEvent(spec)
		local hours = math.clamp(tonumber(spec.Hours) or 1, 0.05, 24 * 14)
		local ev = {
			Id = HttpService:GenerateGUID(false), Name = tostring(spec.Name or "EVENT"):sub(1, 40),
			Marks = math.clamp(tonumber(spec.Marks) or 1, 1, 10), XP = math.clamp(tonumber(spec.XP) or 1, 1, 10),
			EndsAt = math.floor(workspace:GetServerTimeNow() + hours * 3600), By = spec.By,
		}
		if map then
			local ok, err = pcall(function() map:SetAsync(KEY, HttpService:JSONEncode(ev), math.floor(hours * 3600) + 60) end)
			if not ok then warn("[GlobalEvents] couldn't store the event: " .. tostring(err)) end
		end
		apply(ev)
		local ok = publish({Kind = "Event", Event = ev})
		if not ok then broadcast:FireAllClients("Event", {Name = ev.Name, Started = true}) end
		return ok, ev
	end
	function G.EndEvent()
		if map then pcall(function() map:RemoveAsync(KEY) end) end
		apply(nil)
		local ok = publish({Kind = "EventEnd"})
		if not ok then broadcast:FireAllClients("Event", {Started = false}) end
		return ok
	end
	function G.Current() return current end
end

return G
