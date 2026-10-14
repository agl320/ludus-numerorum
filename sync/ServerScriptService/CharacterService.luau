local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
-- Roblox places a new character on a SpawnLocation right after CharacterAdded handlers run,
-- which would override our position. Pivot now and again after the first Heartbeat.
local function settle(character, cf)
    character:PivotTo(cf)
    task.spawn(function()
        RunService.Heartbeat:Wait()
        if character.Parent then character:PivotTo(cf) end
    end)
end
-- Dynamic (animated) heads are turned off: every character gets the classic head (and the classic face), so the
-- visor, hair and scarf fit the same head on everyone and the skin tone is a plain colour. Runs before anything
-- is welded to the head.
local function classicHead(character, humanoid)
    local head = character:FindFirstChild("Head")
    if not head then return end
    local dynamic = head:FindFirstChildOfClass("FaceControls") ~= nil or head:FindFirstChildOfClass("SurfaceAppearance") ~= nil
    local ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
    if not ok or not desc then return end
    if desc.Head == 0 and not dynamic then return end
    -- ApplyDescription needs the character in the world (CharacterAdded can fire just before it's parented)
    if not character:IsDescendantOf(workspace) then
        local t0 = os.clock()
        repeat task.wait() until character:IsDescendantOf(workspace) or os.clock() - t0 > 5
        if not character:IsDescendantOf(workspace) then return end
    end
    desc.Head = 0
    -- dynamic heads have their face built in; give the classic head the classic face
    if dynamic or desc.Face == 0 then desc.Face = 0 end
    -- no accessories (they're removed on spawn anyway), so the re-apply doesn't load them again
    pcall(function() desc:SetAccessories({}, true) end)
    for _, field in ipairs({"HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory"}) do
        pcall(function() desc[field] = "" end)
    end
    pcall(function() humanoid:ApplyDescription(desc) end)
    local newHead = character:FindFirstChild("Head")
    if newHead then
        local fc = newHead:FindFirstChildOfClass("FaceControls"); if fc then fc:Destroy() end
        local sa = newHead:FindFirstChildOfClass("SurfaceAppearance"); if sa then sa:Destroy() end
    end
    -- the outfit / skin is re-applied by the cosmetics pass that follows
    character:SetAttribute("SkinApplied", nil)
end
-- the default Roblox smile on every classic head (also if the head part gets swapped later)
local SMILE = "rbxasset://textures/face.png"
local function classicFace(character)
    local function dress(head)
        if not head:IsA("BasePart") or head.Name ~= "Head" then return end
        local face = head:FindFirstChild("face")
        if face and not face:IsA("Decal") then face:Destroy(); face = nil end
        if not face then
            face = Instance.new("Decal")
            face.Name = "face"
            face.Parent = head
        end
        face.Face = Enum.NormalId.Front
        face.Texture = SMILE
        face.Transparency = 0
    end
    local head = character:FindFirstChild("Head")
    if head then dress(head) end
    character.ChildAdded:Connect(dress)
end
local Characters = {}
Characters.__index = Characters
function Characters.new(config, combat, forehead, notice, ragdolls, movement)
    return setmetatable({config = config, combat = combat, forehead = forehead,
        notice = notice, ragdolls = ragdolls, movement = movement, connections = {}, prepared = {}, serial = 0}, Characters)
end
function Characters:Spawn(player, character)
    if self.prepared[player] == character then return end
    self.prepared[player] = character
    local humanoid = character:WaitForChild("Humanoid", 10)
    local root = character:WaitForChild("HumanoidRootPart", 10)
    local head = character:WaitForChild("Head", 10)
    if not humanoid or not root or not head or player.Character ~= character or player.Parent ~= Players then return end
    if humanoid.Health <= 0 then return end
    classicHead(character, humanoid)
    if player.Character ~= character then return end
    classicFace(character)
    self.forehead.Body(character) -- body type (Loadout > Body), before anything is rigged or dressed on the torso
    if not player:GetAttribute("InMatch") then
        root.Anchored=true;humanoid.WalkSpeed=0;humanoid.JumpPower=0
        -- on the main menu: parked out of sight under the lobby floor (the menu camera films the map)
        settle(character, CFrame.new(0,-40,0))
        self.forehead.Blank(character, self.config) -- every character wears the LED visor (blinking 0__0 until a code is assigned)
        return
    end
    self:ApplyAnimations(character)
    -- Deployed but not in the current round: wait in the lobby (no number, can't be targeted).
    if not player:GetAttribute("InArena") then
        self:SpawnLobby(player, character, humanoid, root)
        return
    end
    local side = "FFA"
    local team = self.config.Teams[side]
    local tint = Color3.fromRGB(table.unpack(team.RGB))
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.WalkSpeed = self.config.WalkSpeed
    humanoid.UseJumpPower = true
    humanoid.JumpPower = self.config.JumpPower
    self.serial = self.serial + 1
    -- Spawn at the map's SpawnLocations (tagged "MatchSpawn"); fall back to any enabled SpawnLocation.
    local spawns = {}
    for _, spawn in ipairs(CollectionService:GetTagged("MatchSpawn")) do
        if spawn:IsA("SpawnLocation") and spawn.Enabled and spawn:IsDescendantOf(workspace) then table.insert(spawns, spawn) end
    end
    if #spawns == 0 then
        for _, spawn in ipairs(workspace:GetDescendants()) do
            if spawn:IsA("SpawnLocation") and spawn.Enabled and not CollectionService:HasTag(spawn, "LobbySpawn") then table.insert(spawns, spawn) end
        end
    end
    -- Closing zone: once it is armed, respawns only land inside the safe quarter.
    local zoneCF
    do
        local shared = self.notice.Parent
        local rules = shared:FindFirstChild("ZoneRules")
        local zone = script.Parent:FindFirstChild("ZoneService")
        if rules and zone then
            spawns, zoneCF = require(zone).FilterSpawns(shared, require(rules), spawns)
        end
    end
    -- Pick the spawn farthest from everyone in the arena (players and bots), never one just handed to someone else
    -- (ServerScriptService.SpawnPicker -- several players used to land on the same spawn at the round start).
    local others = {}
    for _,other in ipairs(Players:GetPlayers()) do
        local r=other~=player and other:GetAttribute("InArena") and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
        if r then table.insert(others, r.Position) end
    end
    local bots = workspace:FindFirstChild("MatchBots")
    if bots then
        for _,m in ipairs(bots:GetChildren()) do
            local r = m:FindFirstChild("HumanoidRootPart")
            if r then table.insert(others, r.Position) end
        end
    end
    local chosen = require(script.Parent:WaitForChild("SpawnPicker")).Pick(spawns, others)
    if zoneCF then
        local position = zoneCF.Position + Vector3.new(0, humanoid.HipHeight + root.Size.Y/2 + 0.5, 0)
        -- the city streams in around players: load the spot before they land on it
        pcall(function() player:RequestStreamAroundAsync(position, 5) end)
        local look = zoneCF.LookVector
        settle(character, CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z)))
    elseif chosen then
        local look = chosen.CFrame.LookVector
        local facing = Vector3.new(look.X, 0, look.Z)
        if facing.Magnitude < 0.01 then facing = Vector3.new(0, 0, -1) end
        local position = chosen.Position + Vector3.new(0, chosen.Size.Y/2 + humanoid.HipHeight + root.Size.Y/2, 0)
        pcall(function() player:RequestStreamAroundAsync(position, 5) end)
        settle(character, CFrame.lookAt(position, position + facing.Unit))
    else
        warn("[CharacterService] No enabled SpawnLocation found; character stays where it loaded")
    end
    -- Keep hats from covering the visor screen, including late appearance replication.
    -- The LED visor itself (attribute NumberfallVisor) is kept: it is the number display.
    -- No ForceField: a valid assigned enemy number always eliminates instantly.
    local function clearAppearanceObject(object)
        if object:IsA("Accessory") and (object:GetAttribute("NumberfallVisor") or object:GetAttribute("NumberfallWear")) then return end
        if object:IsA("ForceField") or object:IsA("Accessory") then object:Destroy() end
    end
    for _, object in ipairs(character:GetChildren()) do
        clearAppearanceObject(object)
    end
    local appearanceConnection = character.ChildAdded:Connect(clearAppearanceObject)
    character:SetAttribute("NumberfallSide", side)
    local record = {Character = character, Humanoid = humanoid, Side = tostring(player.UserId), ColorSide = side,
        Name = player.DisplayName, UserId = player.UserId}
    local code = self.combat:Register(player, record)
    self.ragdolls:Prepare(character)
    self.movement:Register(player, character)
    self.forehead.Attach(character, code, tint, self.config)
    -- (no team tint on the torso any more: the body shows the player's outfit and skin tone, ServerScriptService.Outfit)
    humanoid.Died:Once(function()
        appearanceConnection:Disconnect()
        self.movement:Remove(player, character)
        self.ragdolls:Activate(character)
        self.combat:Remove(player, character)
        self.forehead.Dead(character, self.config) -- visor reads X__X (the corpse keeps it)
        if player.Parent == Players and player:GetAttribute("InMatch") and player:GetAttribute("InArena") then
            player.leaderstats.Deaths.Value = player.leaderstats.Deaths.Value + 1
            if self.onDeath then self.onDeath(player,character)end
            self.notice:FireClient(player, "Death", {
                Code=character:GetAttribute("EliminatedCode") or code,
                KillerCode=character:GetAttribute("EliminatedByCode"),
                KillerId=character:GetAttribute("EliminatedById"),
                KillerName=character:GetAttribute("EliminatedByName")})
            -- Writing your own number skips CombatService.onKill (no score/reward), so announce it to
            -- everyone's elimination feed here: killer and victim are the same player.
            if character:GetAttribute("EliminatedById") == player.UserId then
                local root = character:FindFirstChild("HumanoidRootPart")
                self.notice:FireAllClients("Kill", {Killer = player.DisplayName, Victim = player.DisplayName,
                    KillerId = player.UserId, VictimId = player.UserId, Side = "FFA", Self = true,
                    Code = tostring(character:GetAttribute("EliminatedCode") or code), Position = root and root.Position})
            end
        end
    end)
end
-- Swap the stock Animate script's animation ids for the game's set (it reloads them when they change).
function Characters:ApplyAnimations(character)
    local set = self.config.Animations
    if not set then return end
    task.spawn(function()
        local animate = character:WaitForChild("Animate", 10)
        if not animate then return end
        local map = {run = {RunAnim = set.Run}, walk = {WalkAnim = set.Walk}, idle = {Animation1 = set.Idle1, Animation2 = set.Idle2},
            fall = {FallAnim = set.Fall}, jump = {JumpAnim = set.Jump}, climb = {ClimbAnim = set.Climb}}
        for folderName, anims in pairs(map) do
            local folder = animate:WaitForChild(folderName, 5)
            if folder then
                for animName, id in pairs(anims) do
                    local anim = folder:FindFirstChild(animName)
                    if anim and id then anim.AnimationId = "rbxassetid://" .. id end
                end
            end
        end
    end)
end
function Characters:SpawnLobby(player, character, humanoid, root)
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.WalkSpeed = self.config.WalkSpeed
    humanoid.UseJumpPower = true
    humanoid.JumpPower = self.config.JumpPower
    local spawns = {}
    for _, spawn in ipairs(CollectionService:GetTagged("LobbySpawn")) do
        if spawn:IsA("SpawnLocation") and spawn:IsDescendantOf(workspace) then table.insert(spawns, spawn) end
    end
    if #spawns > 0 then
        local chosen = spawns[math.random(1, #spawns)]
        local look = chosen.CFrame.LookVector
        local facing = Vector3.new(look.X, 0, look.Z)
        if facing.Magnitude < 0.01 then facing = Vector3.new(0, 0, -1) end
        local position = chosen.Position + Vector3.new(0, chosen.Size.Y/2 + humanoid.HipHeight + root.Size.Y/2, 0)
        settle(character, CFrame.lookAt(position, position + facing.Unit))
    else
        warn("[CharacterService] No SpawnLocations tagged LobbySpawn found")
    end
    local function clearAppearanceObject(object)
        if object:IsA("Accessory") and (object:GetAttribute("NumberfallVisor") or object:GetAttribute("NumberfallWear")) then return end
        if object:IsA("ForceField") or object:IsA("Accessory") then object:Destroy() end
    end
    for _, object in ipairs(character:GetChildren()) do clearAppearanceObject(object) end
    local appearanceConnection = character.ChildAdded:Connect(clearAppearanceObject)
    self.forehead.Blank(character, self.config) -- no number while waiting: the visor shows a blinking 0__0
    character:SetAttribute("InLobby", true)
    self.movement:Register(player, character)
    humanoid.Died:Once(function()
        appearanceConnection:Disconnect()
        self.movement:Remove(player, character)
    end)
end
function Characters:Add(player)
    if self.connections[player] then return end
    player.CanLoadCharacterAppearance = false
    require(script.Parent:WaitForChild("Outfit")).LoadSkin(player) -- only the skin tone is taken from their Roblox avatar
    player.Team = nil
    player.Neutral = true
    player:SetAttribute("InMatch",false)
    player:SetAttribute("InArena",false)
    player:SetAttribute("RoundKills",0)
    -- third person by default (the client's B key switches to first person)
    player.CameraMode = Enum.CameraMode.Classic
    player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 10, 10
    local stats = Instance.new("Folder")
    stats.Name, stats.Parent = "leaderstats", player
    for _, name in ipairs({"Kills", "Deaths"}) do
        local value = Instance.new("IntValue")
        value.Name, value.Parent = name, stats
    end
    self.connections[player] = {
        player.CharacterAdded:Connect(function(char) self:Spawn(player, char) end),
        player.CharacterRemoving:Connect(function(char)
            self.combat:Remove(player, char)
            self.movement:Remove(player, char)
            self.ragdolls:Forget(char)
        end),
    }
    if player.Character then task.spawn(function() self:Spawn(player, player.Character) end) end
end
function Characters:Remove(player)
    for _, connection in ipairs(self.connections[player] or {}) do connection:Disconnect() end
    self.connections[player], self.prepared[player] = nil, nil
    self.combat:Forget(player)
    self.movement:Remove(player)
    if player.Character then self.ragdolls:Forget(player.Character) end
end
function Characters:Start()
    Players.RespawnTime = self.config.RespawnSeconds
    Players.PlayerAdded:Connect(function(player) self:Add(player) end)
    Players.PlayerRemoving:Connect(function(player) self:Remove(player) end)
    for _, player in ipairs(Players:GetPlayers()) do self:Add(player) end
end
return Characters
