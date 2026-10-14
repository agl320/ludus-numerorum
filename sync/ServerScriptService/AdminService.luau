
-- Open the panel in game with F6 (or the ADMIN button top-left). Add people by UserId below.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local OWNERS = {
	[30217753] = true, -- tazeno
}
local MODS = {
	[436559665] = true,  -- tester
	[29042742] = true, -- tester
	[3697217] = true,    -- tester
	-- [UserId] = true,
}
local GROUP_RANK = 254

local Admin = {}

function Admin.IsAdmin(p)
	if OWNERS[p.UserId] or MODS[p.UserId] then return true end
	if RunService:IsStudio() then return true end
	if game.CreatorType == Enum.CreatorType.User and p.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function() return p:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= GROUP_RANK then return true end
	end
	return false
end

function Admin.Start(profiles, match, shared)
	local HairCatalog = require(shared:WaitForChild("HairCatalog"))
	local Outfits = require(shared:WaitForChild("Outfits"))
	local hairColors = {}
	for _, c in ipairs(HairCatalog.Colors) do hairColors[c.Id] = c end

	local call = Instance.new("RemoteFunction"); call.Name = "AdminCall"; call.Parent = shared
	local broadcast = Instance.new("RemoteEvent"); broadcast.Name = "AdminBroadcast"; broadcast.Parent = shared
	-- cross-server announcements + global events (ServerScriptService.GlobalEvents)
	local Global = require(script.Parent:WaitForChild("GlobalEvents"))
	Global.Start(shared, broadcast)

	local log = {}
	local function record(admin, text)
		local line = os.date("!%H:%M") .. "  " .. admin.Name .. "  " .. text
		table.insert(log, 1, line)
		while #log > 60 do table.remove(log) end
		print("[Admin] " .. line)
	end

	-- ChatRole drives the chat tags (StarterPlayerScripts.ChatTags) and the title over your head
	-- (StarterPlayerScripts.RoleTitles): OWNER for the game's owner (only that: the owner never shows MOD), MOD for
	-- every other admin. (Studio makes everyone an admin for testing, but only real owners / listed admins get one.)
	local function role(p)
		if OWNERS[p.UserId] then return "OWNER" end
		if game.CreatorType == Enum.CreatorType.User and p.UserId == game.CreatorId then return "OWNER" end
		if game.CreatorType == Enum.CreatorType.Group then
			local ok, rank = pcall(function() return p:GetRankInGroup(game.CreatorId) end)
			if ok and rank >= 255 then return "OWNER" end
			if ok and rank >= GROUP_RANK then return "MOD" end
		end
		if MODS[p.UserId] then return "MOD" end
		return nil
	end
	local function mark(p)
		if Admin.IsAdmin(p) then p:SetAttribute("MarkedAdmin", true) end
		p:SetAttribute("ChatRole", role(p))
	end
	Players.PlayerAdded:Connect(mark)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(mark, p) end

	local function target(id) return Players:GetPlayerByUserId(tonumber(id) or 0) end
	local function save(p) task.spawn(function() profiles:Save(p, false) end) end
	local function root(p) local c = p.Character; return c and c:FindFirstChild("HumanoidRootPart") end

	local busy = {}
	local A = {}

	function A.Players()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local r = root(p)
			table.insert(list, {
				UserId = p.UserId, Name = p.Name, DisplayName = p.DisplayName,
				Coins = p:GetAttribute("Coins") or 0, Level = p:GetAttribute("Level") or 1,
				VIP = p:GetAttribute("VIP") == true, VIPPermanent = p:GetAttribute("VIPPermanent") == true, Lives = p:GetAttribute("Lives"), InMatch = p:GetAttribute("InMatch") == true,
				Style = p:GetAttribute("NumberStyle"), Admin = p:GetAttribute("MarkedAdmin") == true,
				Frozen = (r and r.Anchored) == true,
			})
		end
		return true, list
	end
	function A.State()
		local st = shared:GetAttribute("Phase") or "?"
		local left = math.max(0, math.floor((shared:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()))
		local lobby = shared:GetAttribute("LobbyUntil") or 0
		return true, {Phase = st, Left = left, LobbyLeft = lobby > 0 and math.max(0, math.floor(lobby - workspace:GetServerTimeNow())) or nil,
			Round = shared:GetAttribute("RoundId") or 0, Players = #Players:GetPlayers(), Server = game.JobId ~= "" and game.JobId:sub(1, 8) or "studio",
			Event = (shared:GetAttribute("EventEndsAt") or 0) > workspace:GetServerTimeNow() and {Name = shared:GetAttribute("EventName"),
				Marks = shared:GetAttribute("EventMarks"), XP = shared:GetAttribute("EventXP"),
				Left = math.floor(shared:GetAttribute("EventEndsAt") - workspace:GetServerTimeNow())} or nil}
	end
	function A.Log() return true, log end

	-- economy ---------------------------------------------------------------
	function A.Marks(admin, a)
		local p = target(a.UserId); local d = p and profiles:Data(p)
		if not d then return false, "Player / profile not found" end
		local n = math.floor(tonumber(a.Amount) or 0)
		if n == 0 or math.abs(n) > 10000000 then return false, "Enter an amount" end
		d.Coins = math.max(0, d.Coins + n); profiles:Publish(p); save(p)
		record(admin, (n > 0 and "gave " or "took ") .. math.abs(n) .. " marks " .. (n > 0 and "to " or "from ") .. p.Name)
		return true, (n > 0 and "+" or "") .. n .. " marks  ·  " .. p.DisplayName .. " now has " .. d.Coins
	end
	function A.XP(admin, a)
		local p = target(a.UserId); local d = p and profiles:Data(p)
		if not d then return false, "Player / profile not found" end
		local n = math.floor(tonumber(a.Amount) or 0)
		if n == 0 or math.abs(n) > 10000000 then return false, "Enter an amount" end
		d.XP = math.max(0, d.XP + n); profiles:Publish(p); save(p)
		record(admin, "gave " .. n .. " XP to " .. p.Name)
		return true, (n > 0 and "+" or "") .. n .. " XP  ·  level " .. tostring(p:GetAttribute("Level"))
	end
	function A.Grant(admin, a)
		local p = target(a.UserId); local d = p and profiles:Data(p)
		if not d then return false, "Player / profile not found" end
		local id = tostring(a.Item or ""):gsub("%s", "")
		local ok
		local c = hairColors[id]
		local cw = Outfits.ColorwayById[id]
		if c and not (c.Premium or c.Vip) then
			-- normal hair colours belong to one hairstyle: the one being worn
			if not d.HairStyle or d.HairStyle == "None" then return false, "They need a hairstyle on for a normal hair colour" end
			d.OwnedHair[d.HairStyle .. "|" .. id] = true; ok = true
		elseif cw and not (cw.Premium or cw.Vip) then
			d.OwnedHair[Outfits.ColorwayKey(d.Outfit or Outfits.Default, id)] = true; ok = true
		else
			ok = profiles:Unlock(d, id)
		end
		if not ok then return false, "Unknown item id: " .. id end
		profiles:Publish(p); save(p)
		record(admin, "granted " .. id .. " to " .. p.Name)
		return true, "Granted " .. id .. " to " .. p.DisplayName
	end
	function A.Revoke(admin, a)
		local p = target(a.UserId); local d = p and profiles:Data(p)
		if not d then return false, "Player / profile not found" end
		local id = tostring(a.Item or ""):gsub("%s", "")
		if not profiles:Lock(d, id) then return false, p.DisplayName .. " doesn't own " .. id end
		profiles:Publish(p); save(p)
		if p.Character and profiles.onHairChanged then profiles.onHairChanged(p, p.Character) end
		record(admin, "revoked " .. id .. " from " .. p.Name)
		return true, "Revoked " .. id .. " from " .. p.DisplayName
	end
	function A.VIP(admin, a)
		local p = target(a.UserId); if not p then return false, "Player not found" end
		local on = p:GetAttribute("VIP") ~= true
		p:SetAttribute("VIP", on)
		record(admin, (on and "gave" or "removed") .. " VIP (this server) " .. (on and "to " or "from ") .. p.Name)
		return true, "VIP " .. (on and "ON" or "OFF") .. " for " .. p.DisplayName .. " (this server only)"
	end
	-- permanent VIP: saved for the account (every server, survives rejoining); works by UserId for offline players too
	local Monetization = require(script.Parent:WaitForChild("Monetization"))
	function A.VIPPermanent(admin, a)
		local id = tonumber(a.UserId); if not id then return false, "Select a player or enter a UserId" end
		local on = a.On == true
		local ok, err = Monetization.SetPermanentVip(id, on)
		if not ok then return false, "Couldn't save: " .. tostring(err) end
		local tp = Players:GetPlayerByUserId(id)
		local name = tp and tp.Name or tostring(id)
		record(admin, (on and "gave PERMANENT VIP to " or "removed permanent VIP from ") .. name)
		return true, on and ("Permanent VIP given to " .. name) or ("Permanent VIP removed from " .. name .. (tp and "" or " (applies when they next join)"))
	end
	-- weather (ReplicatedStorage.Numberfall.Weather reads these): a full-strength shower now, or clear skies
	function A.Weather(admin, a)
		local now = workspace:GetServerTimeNow()
		if a.Mode == "Rain" then
			local minutes = math.clamp(tonumber(a.Minutes) or 3, 1, 15)
			shared:SetAttribute("RainStrength", 1)
			shared:SetAttribute("RainStartsAt", now - 25) -- (already at full strength)
			shared:SetAttribute("RainEndsAt", now + minutes * 60)
			record(admin, "started rain for " .. minutes .. " min")
			return true, "Raining for " .. minutes .. " minutes"
		end
		shared:SetAttribute("RainEndsAt", now + 2)
		shared:SetAttribute("RainStartsAt", math.min(shared:GetAttribute("RainStartsAt") or now, now - 25))
		record(admin, "cleared the weather")
		return true, "Clear skies"
	end
	function A.ResetIntro(admin, a)
		local p = target(a.UserId); local d = p and profiles:Data(p)
		if not d then return false, "Player / profile not found" end
		d.IntroSeen = nil; p:SetAttribute("IntroSeen", false); save(p)
		record(admin, "reset the intro for " .. p.Name)
		return true, p.DisplayName .. " will see the intro next time they join"
	end

	-- in the world -----------------------------------------------------------
	function A.Goto(admin, a)
		local p = target(a.UserId); local r, me = p and root(p), root(admin)
		if not r or not me then return false, "No character" end
		admin.Character:PivotTo(r.CFrame * CFrame.new(0, 0, 4))
		return true, "Teleported to " .. p.DisplayName
	end
	function A.Bring(admin, a)
		local p = target(a.UserId); local r, me = p and root(p), root(admin)
		if not r or not me then return false, "No character" end
		p.Character:PivotTo(me.CFrame * CFrame.new(0, 0, -4))
		record(admin, "brought " .. p.Name)
		return true, "Brought " .. p.DisplayName
	end
	function A.Kill(admin, a)
		local p = target(a.UserId); local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not h then return false, "No character" end
		h.Health = 0
		record(admin, "killed " .. p.Name)
		return true, "Killed " .. p.DisplayName
	end
	function A.Respawn(admin, a)
		local p = target(a.UserId); if not p then return false, "Player not found" end
		task.spawn(function() pcall(function() p:LoadCharacterAsync() end) end)
		record(admin, "respawned " .. p.Name)
		return true, "Respawned " .. p.DisplayName
	end
	function A.Lives(admin, a)
		local p = target(a.UserId); if not p then return false, "Player not found" end
		if not match:IsPlaying() or not match.participants[p.UserId] then return false, p.DisplayName .. " isn't in a round" end
		p:SetAttribute("Lives", match.config.Lives or 3)
		record(admin, "refilled lives for " .. p.Name)
		return true, "Lives refilled for " .. p.DisplayName
	end
	function A.Freeze(admin, a)
		local p = target(a.UserId); local r = p and root(p)
		if not r then return false, "No character" end
		r.Anchored = not r.Anchored
		record(admin, (r.Anchored and "froze " or "unfroze ") .. p.Name)
		return true, (r.Anchored and "Froze " or "Unfroze ") .. p.DisplayName
	end

	-- moderation -------------------------------------------------------------
	local function reasonOf(a) local r = tostring(a.Reason or ""):sub(1, 200); return r ~= "" and r or "Removed by a moderator" end
	function A.Kick(admin, a)
		local p = target(a.UserId); if not p then return false, "Player not found" end
		if p == admin then return false, "That's you" end
		local reason = reasonOf(a)
		record(admin, "kicked " .. p.Name .. " (" .. reason .. ")")
		p:Kick(reason)
		return true, "Kicked " .. p.DisplayName
	end
	function A.Ban(admin, a)
		local id = tonumber(a.UserId); if not id then return false, "No player" end
		if id == admin.UserId then return false, "That's you" end
		if OWNERS[id] or MODS[id] then return false, "Can't ban an admin" end
		local hours = tonumber(a.Hours) or 0
		local reason = reasonOf(a)
		local ok, err = pcall(function()
			Players:BanAsync({UserIds = {id}, Duration = hours > 0 and math.floor(hours * 3600) or -1, DisplayReason = reason,
				PrivateReason = "Banned by " .. admin.Name .. " from the admin panel", ExcludeAltAccounts = false, ApplyToUniverse = true})
		end)
		if not ok then return false, "Ban failed: " .. tostring(err) end
		local tp = Players:GetPlayerByUserId(id)
		local name = tp and tp.Name or tostring(id)
		record(admin, "banned " .. name .. " (" .. (hours > 0 and (hours .. "h") or "permanent") .. ", " .. reason .. ")")
		return true, "Banned " .. name .. (hours > 0 and (" for " .. hours .. "h") or " permanently")
	end
	function A.Unban(admin, a)
		local id = tonumber(a.UserId); if not id then return false, "Enter a UserId" end
		local ok, err = pcall(function() Players:UnbanAsync({UserIds = {id}, ApplyToUniverse = true}) end)
		if not ok then return false, "Unban failed: " .. tostring(err) end
		record(admin, "unbanned " .. id)
		return true, "Unbanned " .. id
	end

	-- match -------------------------------------------------------------------
	function A.SkipLobby(admin)
		if match.phase ~= "Warmup" then return false, "Not waiting in the lobby" end
		match.lobbyUntil = 0
		if match.startAt then match.startAt = workspace:GetServerTimeNow() end
		record(admin, "skipped the lobby wait")
		return true, match.startAt and "Starting now" or "Lobby wait cleared (still needs enough players ready)"
	end
	function A.SkipCountdown(admin)
		if match.phase ~= "Countdown" then return false, "No countdown running" end
		match.endsAt = workspace:GetServerTimeNow()
		record(admin, "skipped the countdown")
		return true, "Countdown skipped"
	end
	function A.EndRound(admin)
		if not match:IsPlaying() then return false, "No round in progress" end
		match:Finish()
		record(admin, "ended the round")
		return true, "Round ended"
	end
	function A.AddTime(admin, a)
		if not match:IsPlaying() then return false, "No round in progress" end
		local s = math.clamp(math.floor(tonumber(a.Seconds) or 0), -600, 600)
		match.endsAt = math.max(workspace:GetServerTimeNow() + 5, match.endsAt + s)
		shared:SetAttribute("EndsAt", match.endsAt)
		record(admin, (s >= 0 and "added " or "removed ") .. math.abs(s) .. "s of round time")
		return true, (s >= 0 and "+" or "") .. s .. "s"
	end
	function A.Announce(admin, a)
		local text = tostring(a.Text or ""):sub(1, 140)
		if text:gsub("%s", "") == "" then return false, "Type a message" end
		-- anything shown to other players has to go through Roblox's text filter
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(text, admin.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
		end)
		if not ok then return false, "Text filter unavailable, try again" end
		broadcast:FireAllClients("Announce", {Text = filtered, From = admin.DisplayName})
		record(admin, "announced: " .. filtered)
		return true, "Announced"
	end

	-- global (every server) -------------------------------------------------
	local function filtered(admin, text)
		local ok, out = pcall(function()
			return TextService:FilterStringAsync(text, admin.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
		end)
		return ok and out or nil
	end
	function A.GlobalAnnounce(admin, a)
		local text = tostring(a.Text or ""):sub(1, 140)
		if text:gsub("%s", "") == "" then return false, "Type a message" end
		local f = filtered(admin, text); if not f then return false, "Text filter unavailable, try again" end
		local ok, err = Global.Announce(f, admin.DisplayName)
		record(admin, "announced to ALL servers: " .. f)
		return true, ok and "Sent to every server" or ("Only this server got it (" .. tostring(err) .. ")")
	end
	function A.StartEvent(admin, a)
		local name = tostring(a.Name or ""):sub(1, 40)
		if name:gsub("%s", "") == "" then return false, "Name the event" end
		local f = filtered(admin, name); if not f then return false, "Text filter unavailable, try again" end
		local marks, xp = tonumber(a.Marks) or 1, tonumber(a.XP) or 1
		if marks <= 1 and xp <= 1 then return false, "Pick a marks or XP multiplier" end
		local ok, ev = Global.StartEvent({Name = string.upper(f), Marks = marks, XP = xp, Hours = a.Hours, By = admin.Name})
		record(admin, string.format("started global event %s (marks x%s, XP x%s, %sh)", ev.Name, ev.Marks, ev.XP, tostring(a.Hours)))
		return true, ok and ("Event live on every server: " .. ev.Name) or "Event started here (other servers pick it up within 2 min)"
	end
	function A.EndEvent(admin)
		if (shared:GetAttribute("EventEndsAt") or 0) <= workspace:GetServerTimeNow() then return false, "No event running" end
		Global.EndEvent()
		record(admin, "ended the global event")
		return true, "Event ended on every server"
	end

	call.OnServerInvoke = function(p, action, args)
		if not Admin.IsAdmin(p) then return false, "Not an admin" end
		if type(action) ~= "string" or not A[action] then return false, "Unknown action" end
		local readOnly = action == "Players" or action == "State" or action == "Log"
		if not readOnly then
			if busy[p] then return false, "Busy, try again" end
			busy[p] = true
		end
		local ok, res, msg = pcall(A[action], p, type(args) == "table" and args or {})
		if not readOnly then busy[p] = nil end
		if not ok then warn("[Admin] " .. action .. " failed: " .. tostring(res)); return false, "Error: " .. tostring(res) end
		return res, msg
	end
	Players.PlayerRemoving:Connect(function(p) busy[p] = nil end)
end

return Admin
