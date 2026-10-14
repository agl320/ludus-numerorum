-- Closing zone: one minute into each round a circle covering the city starts shrinking onto a random
-- quarter over ZoneRules.CloseSeconds. Anyone outside the safe area for GraceSeconds loses a life
-- (normal death flow: lives, respawn, results). Respawns are placed inside the circle. As the round runs out it
-- keeps squeezing down to ZoneRules.EndRadius around an open spot in that quarter (a spawn pad: never inside a house).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Zone = {}

function Zone.Start(shared, rules)
    local random = Random.new()
    local function clear()
        shared:SetAttribute("ZoneQuarter", 0)
        shared:SetAttribute("ZoneStartsAt", nil)
        shared:SetAttribute("ZoneEndsAt", nil)
        shared:SetAttribute("ZoneEndX", nil)
        shared:SetAttribute("ZoneEndZ", nil)
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c then c:SetAttribute("ZoneOutAt", nil) end
        end
    end
    local function arm()
        local began = shared:GetAttribute("RoundStartedAt") or workspace:GetServerTimeNow()
        local q = random:NextInteger(1, 4)
        shared:SetAttribute("ZoneQuarter", q)
        shared:SetAttribute("ZoneStartsAt", began + rules.DelaySeconds)
        shared:SetAttribute("ZoneEndsAt", began + rules.DelaySeconds + rules.CloseSeconds)
        -- the last circle closes on a spawn pad well inside the quarter (open, walkable ground)
        local quarter = rules.Quarter(q)
        local root = rules.Root()
        local picks = {}
        local city = workspace:FindFirstChild("SunsetCity")
        local folder = city and city:FindFirstChild("Spawns")
        for _, s in ipairs(folder and folder:GetChildren() or {}) do
            if s:IsA("BasePart") then
                local l = root:PointToObjectSpace(s.Position)
                local d = math.sqrt((l.X - quarter.x) ^ 2 + (l.Z - quarter.z) ^ 2)
                if d <= quarter.r - math.max(rules.EndRadius, 30) - 4 then table.insert(picks, l) end
            end
        end
        local spot = #picks > 0 and picks[random:NextInteger(1, #picks)] or Vector3.new(quarter.x, 0, quarter.z)
        shared:SetAttribute("ZoneEndX", spot.X)
        shared:SetAttribute("ZoneEndZ", spot.Z)
    end
    local function onPhase()
        if shared:GetAttribute("Phase") == "Playing" then
            task.defer(arm) -- RoundStartedAt is written in the same step as Phase
        else
            clear()
        end
    end
    shared:GetAttributeChangedSignal("Phase"):Connect(onPhase)
    onPhase()

    local function expel(player, character, humanoid)
        local root = character:FindFirstChild("HumanoidRootPart")
        character:SetAttribute("ZoneOutAt", nil)
        character:SetAttribute("EliminatedByZone", true)
        shared.Notice:FireAllClients("Kill", {Killer = "THE ZONE", Victim = player.DisplayName,
            KillerId = 0, VictimId = player.UserId, Side = "FFA", Zone = true,
            Code = tostring(character:GetAttribute("NumberfallCode") or ""), Position = root and root.Position})
        humanoid.Health = 0
    end

    task.spawn(function()
        while true do
            task.wait(0.2)
            if shared:GetAttribute("Phase") == "Playing" then
                local now = workspace:GetServerTimeNow()
                local rect = rules.Circle(shared, now)
                for _, player in ipairs(Players:GetPlayers()) do
                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if humanoid and root and humanoid.Health > 0 and player:GetAttribute("InArena") then
                        if rect and not rules.Contains(rect, root.Position) then
                            local since = character:GetAttribute("ZoneOutAt")
                            if not since then
                                character:SetAttribute("ZoneOutAt", now)
                            elseif now - since >= rules.GraceSeconds then
                                expel(player, character, humanoid)
                            end
                        elseif character:GetAttribute("ZoneOutAt") then
                            character:SetAttribute("ZoneOutAt", nil)
                        end
                    end
                end
            end
        end
    end)
end

-- Spawn filter used by CharacterService once the zone is armed. Returns the spawns inside the final
-- circle, or a raycast ground point inside it when the circle has no SpawnLocation.
function Zone.FilterSpawns(shared, rules, spawns)
    local q = shared:GetAttribute("ZoneQuarter") or 0
    local starts = shared:GetAttribute("ZoneStartsAt")
    if q < 1 or not starts or workspace:GetServerTimeNow() < starts - rules.WarnSeconds then return spawns, nil end
    -- where the circle will be in a few seconds (the quarter before it moves)
    local target = rules.Circle(shared, workspace:GetServerTimeNow() + 8) or rules.Quarter(q)
    local inside = {}
    for _, s in ipairs(spawns) do
        if rules.Contains(target, s.Position, 10) then table.insert(inside, s) end
    end
    if #inside > 0 then return inside, nil end
    -- no spawn pad in this quarter: drop onto open ground near its centre
    local root = rules.Root()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore, p.Character) end end
    params.FilterDescendantsInstances = ignore
    local rng = Random.new()
    for _ = 1, 30 do
        local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * target.r * 0.7
        local x, z = target.x + math.cos(a) * d, target.z + math.sin(a) * d
        local top = root:PointToWorldSpace(Vector3.new(x, 400, z))
        local hit = workspace:Raycast(top, Vector3.new(0, -600, 0), params)
        if hit and hit.Normal.Y > 0.85 and hit.Material ~= Enum.Material.Water and hit.Position.Y < root.Position.Y + 40 then
            return {}, CFrame.new(hit.Position) * root.Rotation
        end
    end
    return spawns, nil
end

return Zone
