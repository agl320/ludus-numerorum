-- Lobby status: banner on screen + the board in the lobby courtyard.
-- Shown while you have pressed Play (InMatch) but are not in the current round (InArena).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local RED = Color3.fromRGB(255, 34, 58)
local BONE = Color3.fromRGB(238, 233, 230)
local FONT = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Regular)

-- the on-screen card is a pinned card in the shared top notification stack
local TopNotices = require(shared:WaitForChild("TopNotices"))

local function clock(s) s = math.max(0, math.floor(s)) return string.format("%02d:%02d", math.floor(s / 60), s % 60) end
local function status(now)
  local phase = shared:GetAttribute("Phase") or "Warmup"
  local left = (shared:GetAttribute("EndsAt") or now) - now
  if phase == "Warmup" then
    local q, need = shared:GetAttribute("Queued") or 0, shared:GetAttribute("MinPlayers") or 2
    local r = shared:GetAttribute("ReadyCount") or 0
    local breakLeft = (shared:GetAttribute("LobbyUntil") or 0) - now
    local bots = shared:GetAttribute("BotFill") or 0 -- AI fighters that will fill the round (BotService)
    local botLine = bots > 0 and string.format("  ·  +%d BOT%s", bots, bots == 1 and "" or "S") or ""
    if r + bots >= need and breakLeft > 0 then
      return "MATCH STARTING IN " .. clock(math.ceil(breakLeft)),
        (r >= q and string.format("ALL %d PLAYER%s READY", r, r == 1 and "" or "S") or string.format("%d / %d READY  ·  UNREADY PLAYERS SIT OUT", r, q)) .. botLine
    end
    return "WAITING FOR PLAYERS", string.format("%d / %d READY  ·  %d NEEDED TO START", r, q, need)
  elseif phase == "Countdown" then
    return "MATCH STARTING", "ENTERING THE CITY  ·  " .. clock(left)
  elseif phase == "Playing" then
    return "ROUND IN PROGRESS", "YOU'LL JOIN THE NEXT MATCH  ·  " .. clock(left)
  else
    return "ROUND ENDING", "NEXT MATCH SOON  ·  " .. clock(left)
  end
end

local last = 0
local boardDisplay
RunService.RenderStepped:Connect(function()
  local now = workspace:GetServerTimeNow()
  if now - last < 0.2 then return end
  last = now
  local t, s = status(now)
  local waiting = player:GetAttribute("InMatch") == true and player:GetAttribute("InArena") ~= true
  -- step aside while a menu or the Tab leaderboard is up
  local ui = player.PlayerGui:FindFirstChild("MARKED_UI_EDITABLE")
  if waiting and not (ui and ui:GetAttribute("PanelOpen") == true) and not player:GetAttribute("IntroPlaying") then
    TopNotices.Set("lobby", {kind = "status", eyebrow = "LOBBY", text = t, sub = s})
  else
    TopNotices.Set("lobby", nil)
  end
  -- (the board is looked up once and kept: a deep search of the whole lobby five times a second was costly)
  if not (boardDisplay and boardDisplay.Parent) then
    local lobby = workspace:FindFirstChild("Lobby")
    local board = lobby and lobby:FindFirstChild("StatusBoard", true)
    boardDisplay = board and board:FindFirstChild("Display")
  end
  local display = boardDisplay
  if display then
    display.Title.Text = t
    display.Sub.Text = s
  end
end)
