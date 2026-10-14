-- Elimination visuals + feedback (client only).
--   WorldBurst: everyone near a kill sees a red flash, shockwave ring, light pillar, shattering glass shards,
--               ember burst, the victim's number (in their style) struck out and the body burning out.
--   Kill:       the killer also gets a hitmarker, red vignette pulse, colour punch, camera kick and combo callouts.
--   Death:      the victim's screen drains of colour with a red tint until respawn.
local Players = game:GetService("Players")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local NF = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local KillFX = require(NF:WaitForChild("KillFX"))
local Extras = require(NF:WaitForChild("Extras"))
local NumberStyles = require(NF:WaitForChild("NumberStyles"))
-- the effect a kill plays and its colour: the killer's equipped KillEffect
local function effectOf(info)
    local killer = info and info.KillerId and Players:GetPlayerByUserId(info.KillerId)
    local id = killer and killer:GetAttribute("KillEffect")
    local def = Extras.Get(id)
    if not def or def.Kind ~= "killfx" then def = Extras.Get(Extras.DefaultKillFx) end
    return def.Id, Color3.fromRGB(table.unpack(def.Color or {255, 34, 58}))
end
local Effects = {}
Effects.__index = Effects
local RED = Color3.fromRGB(255, 34, 58)
local DEEP = Color3.fromRGB(120, 0, 18)
local EMBER = Color3.fromRGB(255, 120, 60)
local FONT = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Bold)
local COMBO = {[2] = "DOUBLE MARK", [3] = "TRIPLE MARK", [4] = "QUAD MARK", [5] = "MASSACRE"}

local function quad(t) return TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end

function Effects.new(player, config, rules, sound, feel, hud)
    local self = setmetatable({player = player, config = config, rules = rules, sound = sound, feel = feel,
        hud = hud, bursts = 0, lastKill = -math.huge, combo = 0, random = Random.new()}, Effects)
    self:BuildOverlay()
    player.CharacterAdded:Connect(function() self:ClearDeath() end)
    return self
end

function Effects:BuildOverlay()
    local gui = Instance.new("ScreenGui")
    gui.Name = "EliminationOverlay"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 5
    gui.Parent = self.player:WaitForChild("PlayerGui")
    self.overlay = gui
    -- vignette: four edge gradients
    local vignette = Instance.new("Frame")
    vignette.Name = "Vignette"; vignette.BackgroundTransparency = 1; vignette.Size = UDim2.fromScale(1, 1); vignette.Parent = gui
    self.edges = {}
    for _, e in ipairs({{UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0), 90}, {UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.68), -90},
        {UDim2.fromScale(0.26, 1), UDim2.fromScale(0, 0), 0}, {UDim2.fromScale(0.26, 1), UDim2.fromScale(0.74, 0), 180}}) do
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0; f.BackgroundColor3 = RED; f.Size = e[1]; f.Position = e[2]; f.BackgroundTransparency = 1; f.Parent = vignette
        local g = Instance.new("UIGradient"); g.Rotation = e[3]
        g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}); g.Parent = f
        table.insert(self.edges, f)
    end
    -- hitmarker: four angled ticks around the crosshair
    local hit = Instance.new("Frame")
    hit.Name = "Hitmarker"; hit.AnchorPoint = Vector2.new(0.5, 0.5); hit.Position = UDim2.fromScale(0.5, 0.5)
    hit.Size = UDim2.fromOffset(44, 44); hit.BackgroundTransparency = 1; hit.Visible = false; hit.Parent = gui
    for i = 0, 3 do
        local tick = Instance.new("Frame")
        tick.AnchorPoint = Vector2.new(0.5, 0.5); tick.BorderSizePixel = 0; tick.BackgroundColor3 = Color3.new(1, 1, 1)
        tick.Size = UDim2.fromOffset(14, 3)
        local a = math.rad(45 + i * 90)
        tick.Position = UDim2.new(0.5, math.cos(a) * 14, 0.5, math.sin(a) * 14); tick.Rotation = 45 + i * 90
        local stroke = Instance.new("UIStroke"); stroke.Color = RED; stroke.Thickness = 1.5; stroke.Parent = tick
        tick.Parent = hit
    end
    self.hitmarker = hit
    self.hitScale = Instance.new("UIScale"); self.hitScale.Parent = hit
    -- combo callout
    local label = Instance.new("TextLabel")
    label.Name = "Callout"; label.AnchorPoint = Vector2.new(0.5, 0.5); label.Position = UDim2.fromScale(0.5, 0.39)
    label.Size = UDim2.fromOffset(520, 56); label.BackgroundTransparency = 1; label.FontFace = FONT; label.TextSize = 46
    label.TextColor3 = Color3.fromRGB(238, 233, 230); label.TextTransparency = 1; label.Text = ""; label.Parent = gui
    local st = Instance.new("UIStroke"); st.Color = DEEP; st.Thickness = 2; st.Transparency = 1; st.Parent = label
    self.callout, self.calloutStroke = label, st
    local sub = label:Clone(); sub.Name = "CalloutSub"; sub.TextSize = 22; sub.Position = UDim2.fromScale(0.5, 0.435); sub.Parent = gui
    self.calloutSub = sub
end

function Effects:Reset()
    self.combo, self.lastKill = 0, -math.huge
    self.hitSerial = (self.hitSerial or 0) + 1
    if self.hitmarker then self.hitmarker.Visible = false end
end

local function part(parent, size, cf, color, props)
    local p = Instance.new("Part")
    p.Size, p.CFrame, p.Color = size, cf, color
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
    p.Material = Enum.Material.Neon
    if props then for k, v in pairs(props) do p[k] = v end end
    p.Parent = parent
    return p
end

function Effects:BurnBody(info, tint, fxId)
    local victim = info.VictimId and Players:GetPlayerByUserId(info.VictimId)
    local char = victim and victim.Character
    if not char then return end
    -- the effect's own body treatment: tinted outline + its particles on the limbs (Numberfall.KillFX)
    KillFX.Body(fxId or "FxShatter", char, 1.9)
end

function Effects:WorldBurst(info)
    local camera = workspace.CurrentCamera
    if not camera or not info.Position or (camera.CFrame.Position - info.Position).Magnitude > self.config.Feel.EffectRange then return end
    -- your own eliminations already play the Kill sound; don't stack the world shatter on top
    if info.KillerId ~= self.player.UserId then self.sound:PlayAt("WorldKill", info.Position) end
    local fxId, tint = effectOf(info)
    self:BurnBody(info, tint, fxId)
    if self.hud.flashes == false then return end
    if self.bursts >= self.config.Feel.MaxBursts then return end
    self.bursts += 1
    local group = Instance.new("Folder")
    group.Name, group.Parent = "EliminationBurst", workspace
    group.Destroying:Once(function() self.bursts -= 1 end)
    local origin = info.Position
    local r = self.random
    -- the killer's elimination effect (Shop > Elimination FX; Numberfall.KillFX)
    local life = KillFX.Play(fxId, group, origin, {random = r})
    Debris:AddItem(group, math.max(2.4, life + 0.6))
    -- the victim's number rises off the body as plain scrambled digits, rolls for a moment, then the digits fly
    -- apart and fade. Sized in studs (not screen pixels) so it stays small next to the body at any distance.
    local code = tostring(info.Code or "----")
    local anchor = part(group, Vector3.one * 0.1, CFrame.new(origin + Vector3.new(0, 2.4, 0)), tint, {Transparency = 1})
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromScale(3.6, 1.1); billboard.AlwaysOnTop = false; billboard.LightInfluence = 0
    billboard.MaxDistance = 140; billboard.Parent = anchor
    local digits = {}
    for i = 1, 4 do
        local d = Instance.new("TextLabel")
        d.AnchorPoint = Vector2.new(0.5, 0.5); d.Position = UDim2.fromScale((i - 0.5) / 4, 0.5); d.Size = UDim2.fromScale(0.25, 1)
        d.BackgroundTransparency = 1; d.Text = code:sub(i, i); d.TextColor3 = tint; d.TextScaled = true
        d.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(20, 0, 6); st.Thickness = 1.5; st.Transparency = 0.2; st.Parent = d
        d.Parent = billboard
        digits[i] = d
    end
    Tween:Create(anchor, TweenInfo.new(1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = origin + Vector3.new(0, 3.6, 0)}):Play()
    -- roll, settling left to right on the real number
    task.spawn(function()
        local t0 = os.clock()
        while billboard.Parent and os.clock() - t0 < 0.55 do
            local t = os.clock() - t0
            for i, d in ipairs(digits) do d.Text = t > 0.15 + i * 0.09 and code:sub(i, i) or tostring(r:NextInteger(0, 9)) end
            task.wait(0.04)
        end
        for i, d in ipairs(digits) do if d.Parent then d.Text = code:sub(i, i) end end
    end)
    -- then the digits fly apart
    task.delay(0.85, function()
        for i, d in ipairs(digits) do
            if d.Parent then
                local dx = (i - 2.5) * 0.18 + r:NextNumber(-0.05, 0.05)
                Tween:Create(d, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.fromScale((i - 0.5) / 4 + dx, 0.5 + r:NextNumber(0.6, 1.1)),
                    Rotation = (i - 2.5) * 40, TextTransparency = 1}):Play()
                local st = d:FindFirstChildOfClass("UIStroke")
                if st then Tween:Create(st, TweenInfo.new(0.8), {Transparency = 1}):Play() end
            end
        end
    end)
end

function Effects:Pulse(strength)
    local reduced = self.hud.flashes == false or self.player:GetAttribute("LocalReducedMotion")
    for _, edge in ipairs(self.edges) do
        edge.BackgroundTransparency = reduced and 0.85 or 0.45 - strength * 0.15
        Tween:Create(edge, quad(0.55), {BackgroundTransparency = 1}):Play()
    end
    if reduced then return end
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "KillPunch"; cc.TintColor = Color3.fromRGB(255, 205, 205); cc.Contrast = 0.25; cc.Saturation = 0.2; cc.Brightness = 0.05
    cc.Parent = workspace.CurrentCamera
    Tween:Create(cc, quad(0.4), {TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0, Brightness = 0}):Play()
    Debris:AddItem(cc, 0.45)
end

function Effects:Callout(text, sub)
    local label, s = self.callout, self.calloutSub
    label.Text, s.Text = text, sub or ""
    label.TextTransparency, s.TextTransparency, self.calloutStroke.Transparency = 0, 0.2, 0
    label.TextColor3 = RED
    label.Size = UDim2.fromOffset(620, 70)
    Tween:Create(label, quad(0.25), {Size = UDim2.fromOffset(520, 56)}):Play()
    Tween:Create(label, quad(0.2), {TextColor3 = Color3.fromRGB(238, 233, 230)}):Play()
    self.calloutSerial = (self.calloutSerial or 0) + 1
    local serial = self.calloutSerial
    task.delay(1.4, function()
        if self.calloutSerial ~= serial then return end
        Tween:Create(label, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        Tween:Create(s, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        Tween:Create(self.calloutStroke, TweenInfo.new(0.4), {Transparency = 1}):Play()
    end)
end

function Effects:Kill(info)
    self:WorldBurst(info)
    if info.KillerId ~= self.player.UserId then return end
    local now = workspace:GetServerTimeNow()
    self.combo = self.rules.Combo(self.lastKill, self.combo, now, self.config.Feel.ComboWindow)
    self.lastKill = now
    self.sound:Play("Kill", 1 + math.min(4, self.combo - 1) * 0.06)
    if self.combo > 1 then self.sound:Play("Combo", 1 + math.min(4, self.combo - 2) * 0.08) end
    self.feel:Punch(0.9)
    -- hitmarker
    local hit = self.hitmarker
    hit.Visible = true
    self.hitScale.Scale = 1.6
    for _, tick in ipairs(hit:GetChildren()) do if tick:IsA("Frame") then tick.BackgroundTransparency = 0; tick.BackgroundColor3 = Color3.new(1, 1, 1) end end
    Tween:Create(self.hitScale, quad(0.18), {Scale = 1}):Play()
    task.delay(0.08, function() for _, tick in ipairs(hit:GetChildren()) do if tick:IsA("Frame") then tick.BackgroundColor3 = RED end end end)
    -- fade out, then hide the whole marker (the ticks' red strokes would otherwise stay on screen)
    self.hitSerial = (self.hitSerial or 0) + 1
    local hitSerial = self.hitSerial
    task.delay(0.35, function()
        for _, tick in ipairs(hit:GetChildren()) do if tick:IsA("Frame") then Tween:Create(tick, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play() end end
    end)
    task.delay(0.62, function() if self.hitSerial == hitSerial then hit.Visible = false end end)
    self:Pulse(math.min(self.combo, 4) / 4)
    local victim = tostring(info.Victim or info.Code or "")
    -- the elimination banner (MARKED_UI_EDITABLE.KillBanner); the old centre callout is the fallback
    if self.hud.killBanner then self.hud.killBanner:Hit(info, self.combo)
    else self:Callout(COMBO[math.min(self.combo, 5)] or "MARKED", "#" .. tostring(info.Code or "----") .. "  ·  " .. victim) end
    self.hud:ConfirmKill(info.Victim, self.combo)
end

function Effects:Death(data)
    -- colour drains out until respawn
    self:ClearDeath()
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "DeathDrain"; cc.Parent = workspace.CurrentCamera
    self.deathCC = cc
    Tween:Create(cc, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Saturation = -0.85, Contrast = 0.15, TintColor = Color3.fromRGB(255, 190, 195), Brightness = -0.05}):Play()
    for _, edge in ipairs(self.edges) do
        edge.BackgroundColor3 = DEEP; edge.BackgroundTransparency = 0.25
        Tween:Create(edge, TweenInfo.new(2.4), {BackgroundTransparency = 0.6}):Play()
    end
end

function Effects:ClearDeath()
    if self.deathCC then self.deathCC:Destroy(); self.deathCC = nil end
    if self.edges then for _, edge in ipairs(self.edges) do edge.BackgroundColor3 = RED; edge.BackgroundTransparency = 1 end end
end

return Effects
