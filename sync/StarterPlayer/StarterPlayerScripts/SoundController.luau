local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Tween = game:GetService("TweenService")
local Audio = {}
Audio.__index = Audio
-- Layers use Creator Store audio ids (Id); File keeps support for rbxasset:// client sounds.
local function soundId(layer)
    return layer.Id and ("rbxassetid://" .. layer.Id) or ("rbxasset://sounds/" .. tostring(layer.File))
end
function Audio.new(config)
    local self = setmetatable({config = config, last = {}, voices = 0, spatial = 0, failed = {}, random = Random.new()}, Audio)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "NumberfallAudio", SoundService
    self.folder = folder
    self.group = Instance.new("SoundGroup")
    self.group.Name, self.group.Volume, self.group.Parent = "NumberfallSFX", 0.85, folder
    local limiter = Instance.new("CompressorSoundEffect")
    limiter.Threshold, limiter.Ratio, limiter.Attack, limiter.Release = -6, 5, 0.01, 0.12
    limiter.Parent = self.group
    local preload, unique = {}, {}
    for _, definition in pairs(config.Sounds) do
        local sets = {definition.Layers}
        for _, v in ipairs(definition.Variants or {}) do table.insert(sets, v) end
        for _, set in ipairs(sets) do for _, layer in ipairs(set) do
            local id = soundId(layer)
            if not unique[id] then
                -- audio preloads reliably through Sound instances (raw id strings report failure)
                local cache = Instance.new("Sound")
                cache.Name, cache.SoundId, cache.Volume, cache.Parent = "Preload", id, 0, folder
                table.insert(preload, cache); unique[id] = true
            end
        end end
    end
    task.spawn(function()
        -- the menus / HUD artwork load first (ReplicatedFirst.PriorityPreload), then the sounds
        local lp, t0 = game:GetService("Players").LocalPlayer, os.clock()
        while lp and not lp:GetAttribute("UIPreloaded") and os.clock() - t0 < 12 do task.wait(0.2) end
        local ok, err = pcall(function()
            ContentProvider:PreloadAsync(preload, function(id, status)
                if status ~= Enum.AssetFetchStatus.Success then
                    self.failed[id] = true
                    warn("Numberfall audio could not load: " .. id)
                end
            end)
        end)
        if not ok then warn("Numberfall sound preload: " .. tostring(err)) end
    end)
    return self
end
function Audio:Play(name, pitch, parent)
    if self.caption then self.caption(name)end
    if (name == "Digit" or name == "TypeKey" or name == "Switch") and self.typingSounds == false then return end
    local definition = self.config.Sounds[name]
    if not definition then return end
    local now = os.clock()
    if now - (self.last[name] or -math.huge) < (definition.Gap or 0) then return end
    self.last[name] = now
    -- variety, so repeated moves don't sound identical: a definition can list Variants (other takes of the sound --
    -- picked at random, never the same one twice running) and Vary = {Pitch = .., Volume = ..} (how far each play is
    -- nudged up or down; the default is a light 3% pitch wobble)
    local layers = definition.Layers
    if definition.Variants and #definition.Variants > 0 then
        local count = #definition.Variants + 1
        local pick = self.random:NextInteger(1, count)
        self.lastTake = self.lastTake or {}
        if pick == self.lastTake[name] then pick = pick % count + 1 end
        self.lastTake[name] = pick
        layers = pick == 1 and definition.Layers or definition.Variants[pick - 1]
    end
    local vary = definition.Vary or {}
    local pv, vv = vary.Pitch or 0.03, vary.Volume or 0
    local pitchJitter = self.random:NextNumber(1 - pv, 1 + pv)
    local volumeJitter = self.random:NextNumber(1 - vv, 1 + vv)
    for _, layer in ipairs(layers) do
        task.delay(layer.Delay or 0, function()
            if self.voices >= self.config.Feel.MaxVoices or (parent and not parent.Parent) then return end
            local sound = Instance.new("Sound")
            sound.Name, sound.SoundId = name, soundId(layer)
            -- FadeIn rounds off a hard attack (bells); Reverb pushes a sound into the distance
            local volume = layer.Volume * volumeJitter
            sound.Volume = layer.FadeIn and 0 or volume
            if layer.Reverb then
                local r = Instance.new("ReverbSoundEffect")
                r.DecayTime, r.Density, r.Diffusion, r.DryLevel, r.WetLevel = 2.4, 1, 1, -4, layer.Reverb
                r.Parent = sound
            end
            sound.PlaybackSpeed = layer.Speed * (pitch or 1) * pitchJitter
            sound.SoundGroup = self.group
            sound.RollOffMinDistance, sound.RollOffMaxDistance = 12, 110
            sound.Parent = parent or self.folder
            if layer.Bass or layer.Treble then
                local eq = Instance.new("EqualizerSoundEffect")
                eq.LowGain, eq.HighGain, eq.Parent = layer.Bass or 0, layer.Treble or 0, sound
            end
            self.voices = self.voices + 1
            sound.Destroying:Once(function() self.voices = self.voices - 1 end)
            sound.Ended:Once(function() sound:Destroy() end)
            local played = false
            local function start()
                if played or not sound.Parent then return end
                played = true
                if layer.Start then sound.TimePosition = layer.Start end
                sound:Play()
                if layer.FadeIn then Tween:Create(sound, TweenInfo.new(layer.FadeIn, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Volume = volume}):Play() end
                local fade = layer.FadeOut or 0.07
                task.delay(layer.Duration or 0.5, function()
                    if sound.Parent then
                        Tween:Create(sound, TweenInfo.new(fade), {Volume = 0}):Play()
                        Debris:AddItem(sound, fade + 0.02)
                    end
                end)
            end
            -- Start trimming only once loaded, so a cold cache doesn't eat the transient.
            if sound.IsLoaded then start() else sound.Loaded:Once(start) end
            Debris:AddItem(sound, math.max(5, (layer.Delay or 0) + (layer.Duration or 0.5) + (layer.FadeOut or 0) + 1))
        end)
    end
end
function Audio:PlayAt(name, position)
    local definition = self.config.Sounds[name]
    if not definition or self.spatial >= 12 or self.voices >= self.config.Feel.MaxVoices then return end
    if os.clock() - (self.last[name] or -math.huge) < (definition.Gap or 0) then return end
    local anchor = Instance.new("Part")
    anchor.Name, anchor.Size, anchor.Position = "SoundOrigin", Vector3.one, position
    anchor.Anchored, anchor.Transparency = true, 1
    anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
    anchor.Parent = workspace
    self.spatial = self.spatial + 1
    anchor.Destroying:Once(function() self.spatial = self.spatial - 1 end)
    self:Play(name, 1, anchor)
    Debris:AddItem(anchor, 5)
end
return Audio
