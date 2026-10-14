-- Movement is simulated on each player's own client (ParkourController); the character's physics belong to it.
-- The server only mirrors sprint/slide state as character attributes so every client can show the slide pose
-- and the slide ribbon.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Afterimages = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Afterimages"))
local Movement = {}
Movement.__index = Movement
-- the slide ribbon matches the player's dash afterimages (Numberfall.Afterimages: red, or VIP / MOD / OWNER colours)
local function rankColour(character)
    local st = Afterimages.Styles[Afterimages.Rank(character)] or Afterimages.Styles.default
    local a, b = st.colors[1], st.colors[2] or st.colors[1]
    return ColorSequence.new(a, b)
end
function Movement.new(config, rules, remote, notice)
    return setmetatable({config = config, rules = rules, remote = remote, notice = notice, states = {}}, Movement)
end
function Movement:Register(player, character)
    self:Remove(player)
    local h, root = character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
    if not h or not root then return end
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Position, a1.Position = Vector3.new(-0.7, -2, 0.6), Vector3.new(0.7, -2, 0.6)
    a0.Name, a1.Name, a0.Parent, a1.Parent = "SlideRibbonA", "SlideRibbonB", root, root
    local ribbon = Instance.new("Trail")
    ribbon.Name, ribbon.Attachment0, ribbon.Attachment1 = "SlideRibbon", a0, a1
    ribbon.Lifetime, ribbon.LightEmission = 0.18, 0.7
    ribbon.Transparency = NumberSequence.new(0.55, 1)
    local side = character:GetAttribute("NumberfallSide") or "FFA"
    local team = self.config.Teams[side] or self.config.Teams.FFA
    ribbon.Color = rankColour(character)
    ribbon.Enabled, ribbon.Parent = false, root
    self.states[player] = {char = character, h = h, root = root, sprint = false, packetAt = 0, ribbon = ribbon}
    character:SetAttribute("Sprinting", false)
    character:SetAttribute("SlideUntil", 0)
    character:SetAttribute("SlideReadyAt", 0)
    character:SetAttribute("Crouching", false)
    character:SetAttribute("Hanging", false)
end
function Movement:EndSlide(state)
    if state.ribbon.Parent then state.ribbon.Enabled = false end
    state.slideSince = nil
    if state.char.Parent then state.char:SetAttribute("SlideUntil", 0) end
end
function Movement:Remove(player, expected)
    local state = self.states[player]
    if state and (not expected or expected == state.char) then self:EndSlide(state); self.states[player] = nil end
end
function Movement:Request(player, action, value, direction)
    local state = self.states[player]
    if not state or state.h.Health <= 0 then return end
    if action == "Sprint" then
        state.sprint = value == true
        state.char:SetAttribute("Sprinting", state.sprint)
        return
    end
    local now = workspace:GetServerTimeNow()
    if action == "AirJump" then
        -- mirrored so other clients can play the double-jump flip
        if now - (state.airJumpAt or 0) < 0.15 then return end
        state.airJumpAt = now
        state.char:SetAttribute("AirJumpAt", now)
        return
    end
    if action == "Crouch" then
        state.char:SetAttribute("Crouching", value == true)
        return
    end
    if action == "Hang" then
        -- clinging to a wall (ParkourController's wall hang): other clients show the wall-hang pose
        state.hangSince = value == true and now or nil
        state.char:SetAttribute("Hanging", value == true)
        return
    end
    if action == "Dash" or action == "WallJump" or action == "WallBounce" or action == "Climb" or action == "WallLaunch" or action == "WallCatch" then
        -- mirrored so other clients can show the dash streak / wall kick
        if now - (state[action] or 0) < 0.12 then return end
        state[action] = now
        state.char:SetAttribute(action .. "At", now)
        return
    end
    if action ~= "Slide" then return end
    if value == true then
        if now < state.packetAt then return end
        state.packetAt = now + 0.05
        local dir = typeof(direction) == "Vector3" and Vector3.new(direction.X, 0, direction.Z) or Vector3.zero
        if dir.Magnitude < 0.1 or dir.Magnitude ~= dir.Magnitude then
            local look = state.root.CFrame.LookVector
            dir = Vector3.new(look.X, 0, look.Z)
        end
        state.slideSince = now
        state.char:SetAttribute("SlideDirection", dir.Unit)
        state.char:SetAttribute("SlideUntil", now + 3600)
        state.ribbon.Color = rankColour(state.char)
        state.ribbon.Enabled = true
    else
        self:EndSlide(state)
    end
end
function Movement:Start()
    self.remote.OnServerEvent:Connect(function(player, action, value, direction) self:Request(player, action, value, direction) end)
    Players.PlayerRemoving:Connect(function(player) self:Remove(player) end)
    Run.Heartbeat:Connect(function()
        local now = workspace:GetServerTimeNow()
        for player, state in pairs(self.states) do
            if not state.char.Parent or state.h.Health <= 0 then self:Remove(player)
            elseif state.slideSince and now - state.slideSince > 10 then self:EndSlide(state) end -- safety net
            -- (a hang can't outlast its stamina: clear a mirror whose "let go" never arrived)
            if state.hangSince and now - state.hangSince > 15 then state.hangSince = nil; state.char:SetAttribute("Hanging", false) end
        end
    end)
end
return Movement
