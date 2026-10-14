local Players=game:GetService("Players")
local Match={}
Match.__index=Match
function Match.new(config,state,rules)
    return setmetatable({config=config,state=state,rules=rules,phase="Warmup",score={},botScore={},deaths={},deathCharacters={},roundId=0,endsAt=0,participants={},outRank={}},Match)
end
function Match:SetPhase(phase,duration)
    self.phase=phase;self.endsAt=workspace:GetServerTimeNow()+duration
    self.state:SetAttribute("EndsAt",self.endsAt);self.state:SetAttribute("Phase",phase)
end
function Match:IsPlaying()return self.phase=="Playing"end
-- Players who pressed Play (in the lobby or in the arena).
function Match:Queued()
    local count=0
    for _,p in ipairs(Players:GetPlayers())do if p:GetAttribute("InMatch") then count=count+1 end end
    return count
end
-- Players who pressed Play AND readied up in the lobby. Only these are sent into the next match.
function Match:ReadyCount()
    local count=0
    for _,p in ipairs(Players:GetPlayers())do if p:GetAttribute("InMatch") and p:GetAttribute("Ready") then count=count+1 end end
    return count
end
function Match:BothTeamsReady()
    local need=self.config.MinPlayers or 2
    local ready=self:ReadyCount()
    -- a lone player (or a tiny lobby) gets AI fighters to fill the round (ServerScriptService.BotService)
    local planned=self.bots and self.bots.Planned(ready) or 0
    self.state:SetAttribute("Queued",self:Queued());self.state:SetAttribute("ReadyCount",ready);self.state:SetAttribute("MinPlayers",need)
    self.state:SetAttribute("BotFill",planned)
    return ready+planned>=need
end
local function reload(p)task.spawn(function()pcall(function()p:LoadCharacterAsync()end)end)end
-- Lobby -> arena: everyone who is queued joins the round that is about to start.
function Match:SendToArena()
    if self.onClear then self.onClear() end
    for _,p in ipairs(Players:GetPlayers())do
        if p:GetAttribute("InMatch") and p:GetAttribute("Ready") and not p:GetAttribute("InArena") then p:SetAttribute("InArena",true);reload(p) end
    end
end
-- Arena -> lobby: round over (or start cancelled), wait for the next match.
function Match:SendToLobby()
    if self.onClear then self.onClear() end
    if self.bots then self.bots.Clear() end
    for _,p in ipairs(Players:GetPlayers())do
        if p:GetAttribute("InArena") then
            p:SetAttribute("InArena",false)
            if p:GetAttribute("InMatch") then reload(p) end
        end
    end
end
-- bot: the elimination was a match bot (kept count of apart, they pay far less). Returns this round's bot count.
function Match:Score(player,bot)
    if not self:IsPlaying() or not player:GetAttribute("InArena") then return end
    local id=player.UserId
    self.score[id]=(self.score[id] or 0)+1
    if bot then self.botScore[id]=(self.botScore[id] or 0)+1 end
    local bots=self.botScore[id] or 0
    player:SetAttribute("RoundKills",self.score[id])
    if self.score[id]>=self.config.ScoreLimit then self:Finish()end
    return bots
end
function Match:Death(player,character)
    if not self:IsPlaying() or not player:GetAttribute("InArena") then return end
    if character and self.deathCharacters[player.UserId]==character then return end
    self.deathCharacters[player.UserId]=character
    self.deaths[player.UserId]=(self.deaths[player.UserId] or 0)+1
    -- lives: out of lives = out of the round (you go back to the lobby and watch the rest from there)
    local lives=math.max(0,(player:GetAttribute("Lives") or 0)-1)
    player:SetAttribute("Lives",lives)
    if lives<=0 then
        player:SetAttribute("OutAt",workspace:GetServerTimeNow())
        self.outOrder=(self.outOrder or 0)+1
        self.outRank[player.UserId]=self.outOrder
        if self.onOut then self.onOut(player,character) end
        if self.onLastLife then self.onLastLife(player) end
        task.delay((self.config.RespawnSeconds or 3)-0.2,function()
            if player.Parent and self:IsPlaying() and (player:GetAttribute("Lives") or 0)<=0 then player:SetAttribute("InArena",false) end
        end)
    end
end
-- players still in the fight (in the arena with a life left)
function Match:Standing()
    local list={}
    for _,p in ipairs(Players:GetPlayers())do
        if self.participants[p.UserId] and p:GetAttribute("InArena") and (p:GetAttribute("Lives") or 0)>0 then table.insert(list,p) end
    end
    return list
end
function Match:Finish()
    if not self:IsPlaying() then return end
    local ranking={}
    for _,p in ipairs(Players:GetPlayers())do if self.participants[p.UserId] or p:GetAttribute("InArena") then table.insert(ranking,p)end end
    -- bots (BotService) are ranked alongside: plain tables with the same fields
    local botRows={}
    if self.bots then for _,b in ipairs(self.bots.Entries())do table.insert(ranking,b);botRows[b]=true end end
    -- order: still standing > went out later; then more lives left, more kills, fewer deaths
    local function key(p)
        if botRows[p] then return p.out or math.huge, p.lives or 0, p.kills or 0, -(p.deaths or 0) end
        local id=p.UserId
        local out=self.outRank[id]
        return out and out or math.huge, p:GetAttribute("Lives") or 0, self.score[id] or 0, -(self.deaths[id] or 0)
    end
    local function better(a,b)
        local a1,a2,a3,a4=key(a);local b1,b2,b3,b4=key(b)
        if a1~=b1 then return a1>b1 end
        if a2~=b2 then return a2>b2 end
        if a3~=b3 then return a3>b3 end
        if a4~=b4 then return a4>b4 end
        return nil
    end
    local function idOf(p) return botRows[p] and p.id or p.UserId end
    local function nameOf(p) return botRows[p] and p.name or p.DisplayName end
    table.sort(ranking,function(a,b) local r=better(a,b);if r==nil then return idOf(a)<idOf(b) end;return r end)
    local winner=ranking[1]
    local tied=winner and ranking[2] and better(winner,ranking[2])==nil
    self.state:SetAttribute("Winner",not tied and winner and nameOf(winner) or "DRAW")
    self.state:SetAttribute("WinnerId",not tied and winner and idOf(winner) or 0)
    self.state:SetAttribute("WinnerCode",not tied and winner and (botRows[winner] and winner.code or (winner.Character and winner.Character:GetAttribute("NumberfallCode") or winner:GetAttribute("LastCode"))) or "----")
    self.state:SetAttribute("ResultFighters",#ranking)
    local place,lastScore=0,nil
    local places={}
    local botResults={}
    local humans=0
    for _,p in ipairs(ranking)do if not botRows[p] then humans+=1 end end
    for i,p in ipairs(ranking)do
        if botRows[p] then
            if i==1 or better(ranking[i-1],p)~=nil then place=i end;places[i]=place
            table.insert(botResults,{Name=p.name,Id=p.id,Place=place,Kills=p.kills or 0,Deaths=p.deaths or 0,Code=p.code})
            continue
        end
        local kills=self.score[p.UserId] or 0
        if i==1 or better(ranking[i-1],p)~=nil then place=i end;places[i]=place
        p:SetAttribute("ResultCode",p.Character and p.Character:GetAttribute("NumberfallCode") or p:GetAttribute("LastCode") or "----");p:SetAttribute("ResultRound",self.roundId);p:SetAttribute("ResultPlace",place);p:SetAttribute("ResultKills",kills)
        p:SetAttribute("ResultDeaths",self.deaths[p.UserId] or 0)
        -- what the eliminations actually paid (shown on the results screen): players at full rate, bots at the bot rate
        local R=self.config.Rewards
        local botKills=math.min(self.botScore[p.UserId] or 0,kills)
        local coins=(kills-botKills)*R.Coins+math.min(botKills,R.BotCoinsCap or math.huge)*(R.BotCoins or 0)
        local xp=(kills-botKills)*R.XP+botKills*(R.BotXP or 0)
        p:SetAttribute("ResultVsBots",humans<=1) -- nobody else real in the round: the win bonus is the bot one (ProfileService)
        if p:GetAttribute("VIP")==true and self.vip then coins=math.floor(coins*self.vip.Marks+.5);xp=math.floor(xp*self.vip.XP+.5) end
        -- global event multipliers (GlobalEvents), same as the profile rewards
        if (self.state:GetAttribute("EventEndsAt") or 0)>workspace:GetServerTimeNow() then
            coins=math.floor(coins*(self.state:GetAttribute("EventMarks") or 1)+.5);xp=math.floor(xp*(self.state:GetAttribute("EventXP") or 1)+.5)
        end
        p:SetAttribute("ResultCoins",coins);p:SetAttribute("ResultXP",xp)
        p:SetAttribute("ResultNumbers",p:GetAttribute("RoundNumbers") or 0)
        local began=math.max(self.state:GetAttribute("RoundStartedAt") or workspace:GetServerTimeNow(),p:GetAttribute("MatchEnteredAt") or 0)
        p:SetAttribute("ResultSurvival",math.max(0,workspace:GetServerTimeNow()-began))
        if self.onFinish then self.onFinish(p) end
    end
    -- the results screen lists the bots too (VictoryScreen reads this)
    self.state:SetAttribute("BotResults",#botResults>0 and game:GetService("HttpService"):JSONEncode(botResults) or "")
    for i=1,3 do
        local p=ranking[i]
        self.state:SetAttribute("PodiumId"..i,p and idOf(p) or 0)
        self.state:SetAttribute("PodiumName"..i,p and nameOf(p) or "—")
        self.state:SetAttribute("PodiumPlace"..i,places[i] or 0)
        self.state:SetAttribute("PodiumKills"..i,p and (botRows[p] and p.kills or self.score[p.UserId] or 0) or 0)
    end
    self:SetPhase("Results",self.config.ResultsSeconds)
end
function Match:Start()
    self.state:SetAttribute("Mode","FFA");self:SetPhase("Warmup",0)
    Players.PlayerRemoving:Connect(function(p)self.score[p.UserId]=nil;self.botScore[p.UserId]=nil;self.deaths[p.UserId]=nil;self.deathCharacters[p.UserId]=nil end)
    task.spawn(function()
        while task.wait(.25)do
            local now=workspace:GetServerTimeNow()
            if self.phase=="Warmup" then
                -- Once enough players are queued, the lobby counts down (LobbyStartSeconds, 25s) so others can still
                -- join before the match starts; if people leave and too few are left, the timer resets.
                local ready=self:BothTeamsReady()
                if ready then
                    if not self.startAt then
                        self.startAt=math.max(now+(self.config.LobbyStartSeconds or 25),self.lobbyUntil or 0)
                        self.state:SetAttribute("LobbyUntil",self.startAt)
                    end
                    -- everyone in the lobby is ready: skip the rest of the wait (AllReadySeconds, 5s)
                    local quick=now+(self.config.AllReadySeconds or 5)
                    if self:ReadyCount()>=self:Queued() and self.startAt>quick then
                        self.startAt=quick;self.state:SetAttribute("LobbyUntil",self.startAt)
                    end
                    if now>=self.startAt then
                        self.startAt=nil;self.state:SetAttribute("LobbyUntil",0)
                        self:SetPhase("Countdown",self.config.IntermissionSeconds);self:SendToArena()
                    end
                elseif self.startAt then
                    self.startAt=nil;self.state:SetAttribute("LobbyUntil",0)
                end
            elseif self.phase=="Countdown" then
                if not self:BothTeamsReady()then self:SetPhase("Warmup",0);self:SendToLobby()
                elseif now>=self.endsAt then
                    self.score={};self.botScore={};self.deaths={};self.deathCharacters={}
                    self.roundId=self.roundId+1;self.state:SetAttribute("RoundId",self.roundId)
                    self.state:SetAttribute("RoundStartedAt",now)
                    self.participants={};self.outRank={};self.outOrder=0
                    for _,p in ipairs(Players:GetPlayers())do
                        if p:GetAttribute("InArena") then self.participants[p.UserId]=true;p:SetAttribute("Lives",self.config.Lives or 3);p:SetAttribute("OutAt",nil) end
                        p:SetAttribute("RoundKills",0);p:SetAttribute("RoundNumbers",0)
                        p:SetAttribute("LastCode",p.Character and p.Character:GetAttribute("NumberfallCode") or nil)
                        if p.Character then p.Character:SetAttribute("NumbersWritten",0) end
                    end
                    self.state:SetAttribute("Winner","");self:SetPhase("Playing",self.config.RoundSeconds)
                    if self.bots then
                        local humans=0;for _ in pairs(self.participants)do humans+=1 end
                        self.bots.Begin(self.bots.Planned(humans))
                    end
                end
            elseif self.phase=="Playing" then
                -- end early if players leave and too few are left in the arena to keep playing
                local humansStanding=#self:Standing()
                local humans=0;for _ in pairs(self.participants)do humans+=1 end
                local standing=humansStanding+(self.bots and self.bots.Standing() or 0)
                local started=humans+(self.bots and self.bots.Started() or 0)
                -- (with bots in, the round also ends as soon as no real player is left in it)
                if now>=self.endsAt or standing<=1 and started>=2 or standing<(started>=2 and 2 or 1)
                    or (self.bots and self.bots.Started()>0 and humans>=1 and humansStanding==0) then self:Finish()end
            elseif self.phase=="Results" and now>=self.endsAt then
                self:SetPhase("Warmup",0)
                self.lobbyUntil=now+(self.config.LobbySeconds or 15)
                self.startAt=nil
                -- everyone who played has to ready up again for the next match (keeps AFK players out)
                for _,p in ipairs(Players:GetPlayers())do
                    if self.participants[p.UserId] or p:GetAttribute("InArena") then p:SetAttribute("Ready",false) end
                end
                self:SendToLobby()
            end
        end
    end)
end
return Match
