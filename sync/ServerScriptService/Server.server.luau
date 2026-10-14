-- Composition root. All server modules are siblings; shared modules live in one flat folder.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local shared = RS:WaitForChild("Numberfall")
local Config = require(shared.Config)
local Rules = require(shared.Rules)
local Codebook = require(script.Parent.Codebook)
local CombatService = require(script.Parent.CombatService)
local CharacterService = require(script.Parent.CharacterService)
local MatchService = require(script.Parent.MatchService)
local Forehead = require(script.Parent.Forehead)
local MotionRules = require(shared.MotionRules)
local RagdollService = require(script.Parent.RagdollService)
local MovementService = require(script.Parent.MovementService)
local notebooks = require(script.Parent.NotebookService).new(Players, shared.Note)
local profiles = require(script.Parent.ProfileService).new(Players, require(shared.Catalog), require(shared.SettingsRules), Config.Rewards)
local random = Random.new()
local codes = Codebook.new(Config, function(a, b) return random:NextInteger(a, b) end)
local match = MatchService.new(Config, shared, Rules)
-- a reserved server opened for the tutorial runs the lesson instead of rounds (ServerScriptService.TutorialService)
local Tutorial = require(script.Parent.TutorialService)
local tutorialServer = Tutorial.IsTutorialServer()
shared:SetAttribute("TutorialServer", tutorialServer)
profiles.notice = shared.Notice
-- cosmetics (hair, scarf, visor fit) follow the profile: on Loadout / Shop changes and when the profile loads
local function refreshLook(p) if p.Character then Forehead.Refresh(p.Character, Config) end end
profiles.onHairChanged = function(p) refreshLook(p) end
local function watchProfile(p) p:GetAttributeChangedSignal("ProfileReady"):Connect(function() refreshLook(p) end) end
Players.PlayerAdded:Connect(watchProfile)
for _, p in ipairs(Players:GetPlayers()) do watchProfile(p) end
match.onFinish=function(p)profiles:RoundComplete(p, shared:GetAttribute("WinnerId") == p.UserId)end
local ragdolls = RagdollService.new(Config, require(shared.JointRig))
match.onOut = function(p, character) if character then ragdolls:KeepCorpse(character, p.DisplayName) end end
match.onClear = function() ragdolls:ClearCorpses() end
local movement = MovementService.new(Config, MotionRules, shared.Move, shared.Notice)
local rescramble -- defined below (needs `combat`)
local combat = CombatService.new(Config, Rules, codes, function() return match:IsPlaying() end,
    function(attacker, victim, code)
        local root = victim.Character:FindFirstChild("HumanoidRootPart")
        local source = attacker.Character:FindFirstChild("HumanoidRootPart")
        local position = root and root.Position
        movement:Remove(victim.Owner, victim.Character)
        if root and source then ragdolls:Impulse(victim.Character, source.Position) end
        -- (marking a bot doesn't count towards a player's eliminations)
        if attacker.Owner.Parent == Players and not victim.Bot then attacker.Owner.leaderstats.Kills.Value = attacker.Owner.leaderstats.Kills.Value + 1 end
        shared.Notice:FireAllClients("Kill", {Killer = attacker.Name, Victim = victim.Name,
            KillerId = attacker.UserId, VictimId = victim.UserId, Side = "FFA", Code = code, Position = position})
        match:Death(victim.Owner,victim.Character)
        attacker.Character:SetAttribute("StrikeAt", workspace:GetServerTimeNow())
        attacker.Owner:SetAttribute("RoundNumbers",(attacker.Owner:GetAttribute("RoundNumbers") or 0)+1)
        attacker.Character:SetAttribute("NumbersWritten",(attacker.Character:GetAttribute("NumbersWritten") or 0)+1)
        -- (tutorial bots: no marks, XP or contract progress for marking them, or for them marking you;
        --  match bots (BotService) count like players: marking one scores, and a bot's own marks go on its tally)
        local tutorialBot = (victim.Bot and not victim.MatchBot) or (attacker.Bot and not attacker.MatchBot)
        if attacker.Bot then
            if attacker.MatchBot and match.bots then match.bots.Scored(attacker.Character) end
        elseif victim.MatchBot then
            -- a match bot: it counts for this round's standings, pays the marks/XP, but isn't an elimination stat
            local botsThisRound = match:Score(attacker.Owner, true)
            profiles:RewardBotKill(attacker.Owner, botsThisRound)
        elseif not tutorialBot then
            profiles:Reward(attacker.Owner)
            match:Score(attacker.Owner)
        end
        -- every elimination gives the killer a brand new number
        local killer = attacker.Owner
        task.defer(function()
            if killer and killer.Parent == Players and killer.Character == attacker.Character then rescramble(killer, "Kill") end
        end)
    end)
-- other systems can re-roll a fighter's number through this
local rescrambleEvent = Instance.new("BindableFunction")
rescrambleEvent.Name = "RescrambleNumber"
function rescramble(player, reason)
    local character = player and player.Character
    if not character then return nil end
    local fresh = combat:Rescramble(player)
    if fresh then
        Forehead.Attach(character, fresh, nil, Config)
        shared.Notice:FireClient(player, "NewNumber", {Code = fresh, Reason = reason or "Crypt"})
    end
    return fresh
end
rescrambleEvent.OnInvoke = rescramble
rescrambleEvent.Parent = script
local characters = CharacterService.new(Config, combat, Forehead, shared.Notice, ragdolls, movement)
-- Limit invalid traffic before doing any code lookup or sending replies.
local packetAt = {}
shared.Submit.OnServerEvent:Connect(function(player, code, requestId)
    local now = workspace:GetServerTimeNow()
    if now < (packetAt[player] or 0) then return end
    packetAt[player] = now + 0.06
    if type(requestId) ~= "number" or requestId ~= requestId or requestId % 1 ~= 0 or requestId < 1 or requestId > 2147483647 then return end
    -- Only players actually fighting in the arena can eliminate (lobby/out-of-lives players cannot).
    local status, untilTime
    if not player:GetAttribute("InArena") then
        status, untilTime = "Waiting", now
    else
        status, untilTime = combat:Submit(player, code, now)
    end
    notebooks:Result(player, code, status, untilTime)
    shared.Result:FireClient(player, requestId, status, untilTime)
end)
Players.PlayerRemoving:Connect(function(player) packetAt[player] = nil end)
local settingsAt={}
shared.Settings.OnServerEvent:Connect(function(player,values)
    if os.clock()<(settingsAt[player] or 0)then shared.Settings:FireClient(player,false);return end
    settingsAt[player]=os.clock()+.5
    shared.Settings:FireClient(player,profiles:SetSettings(player,values))
end)
Players.PlayerRemoving:Connect(function(player)settingsAt[player]=nil end)
characters.onDeath=function(player,character)match:Death(player,character);profiles:Died(player)end
characters:Start()
require(script.Parent.LobbyService).Start(Players, shared.Menu, shared.MenuReply, characters, profiles)
movement:Start()
-- Robux store: marks packs, revives, Robux-only cosmetics, VIP (ServerScriptService.Monetization)
require(script.Parent.Monetization).Start(profiles, match, shared)
-- admin panel (F6 in game; ServerScriptService.AdminService decides who's an admin)
require(script.Parent.AdminService).Start(profiles, match, shared)
if tutorialServer then
    task.spawn(Tutorial.RunTutorial, {shared = shared, combat = combat, match = match, forehead = Forehead,
        ragdolls = ragdolls, movement = movement, profiles = profiles, config = Config})
else
    -- AI fighters fill the round when a player readies up alone (ServerScriptService.BotService)
    require(script.Parent.BotService).Start({shared = shared, combat = combat, match = match, forehead = Forehead,
        ragdolls = ragdolls, config = Config, movement = movement})
    match:Start()
    require(script.Parent.ZoneService).Start(shared, require(shared.ZoneRules))
    Tutorial.StartOffer(shared, profiles)
end
