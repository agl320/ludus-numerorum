-- Pure, injectable combat logic: tested without Roblox physics or networking.
local Combat = {}
Combat.__index = Combat
function Combat.new(config, rules, codes, isPlaying, onKill)
    return setmetatable({config = config, rules = rules, codes = codes, records = {},
        cooldowns = {}, isPlaying = isPlaying, onKill = onKill}, Combat)
end
function Combat:Register(owner, record)
    self:Remove(owner)
    record.Owner, record.Live = owner, true
    record.Code = self.codes:Assign(owner)
    self.records[owner] = record
    return record.Code
end
function Combat:Remove(owner, expectedCharacter)
    local record = self.records[owner]
    if expectedCharacter and record and record.Character ~= expectedCharacter then return end
    self.records[owner] = nil
    self.codes:Release(owner)
    -- Keep the deadline through respawn: resetting cannot bypass a miss cooldown.
end
function Combat:Forget(owner)
    self:Remove(owner)
    self.codes:Forget(owner)
    self.cooldowns[owner] = nil
end
-- Give a living fighter a brand new number (after an elimination). Returns it.
function Combat:Rescramble(owner)
    local record = self.records[owner]
    if not self:IsAlive(record) then return nil end
    record.Code = self.codes:Assign(owner)
    return record.Code
end
function Combat:IsAlive(record)
    return record and record.Live and record.Humanoid.Health > 0
end
function Combat:Submit(owner, code, now)
    local deadline = self.cooldowns[owner] or 0
    if now < deadline then return "Cooldown", deadline end
    local attacker = self.records[owner]
    if not self:IsAlive(attacker) then return "Dead", now end
    local targetOwner = self.rules.ValidCode(code) and self.codes:Resolve(code) or nil
    local selfHit=targetOwner==owner
    if not self.isPlaying() and not selfHit then return "Waiting", now end
    local victim = targetOwner and self.records[targetOwner]
    if victim and not selfHit and typeof(targetOwner)=="Instance" and targetOwner:IsA("Player") and not targetOwner:GetAttribute("InArena") then victim = nil end
    if not self:IsAlive(victim) or (not selfHit and not self.rules.IsEnemy(attacker.Side, victim.Side)) then
        deadline = now + self.config.MissCooldown
        self.cooldowns[owner] = deadline
        return "Miss", deadline
    end
    -- Claim the elimination before changing Health, whose Died callbacks can run immediately.
    victim.Live = false
    self.codes:Release(targetOwner)
    self.cooldowns[owner] = now + self.config.HitCooldown
    victim.Character:SetAttribute("EliminatedCode",code)
    victim.Character:SetAttribute("EliminatedByCode",attacker.Code)
    victim.Character:SetAttribute("EliminatedById",attacker.UserId)
    victim.Character:SetAttribute("EliminatedByName",attacker.Name) -- (tutorial bots have no Player to look up)
    victim.Humanoid.Health = 0
    if not selfHit then self.onKill(attacker, victim, code)end
    -- The attacker's number is scrambled straight after (Server's onKill calls Rescramble).
    return selfHit and "SelfHit"or "Hit", self.cooldowns[owner]
end
return Combat
