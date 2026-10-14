-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
-- PlayerScripts and ReplicatedStorage children can arrive after this LocalScript starts.
-- Resolve every dependency before wiring input; direct indexing can abort startup.
local submit = shared:WaitForChild("Submit")
local result = shared:WaitForChild("Result")
local notice = shared:WaitForChild("Notice")
local move = shared:WaitForChild("Move")
local noteRemote = shared:WaitForChild("Note")
local menuRemote = shared:WaitForChild("Menu")
local menuReply = shared:WaitForChild("MenuReply")
local Config, Rules = require(shared:WaitForChild("Config")), require(shared:WaitForChild("Rules"))
local InputState, Audio = require(script.Parent:WaitForChild("InputState")), require(script.Parent:WaitForChild("SoundController"))

local NumberView = require(script.Parent:WaitForChild("NumberView"))
local MotionRules = require(shared:WaitForChild("MotionRules"))
local FeelController = require(script.Parent:WaitForChild("FeelController"))
local EliminationEffects = require(script.Parent:WaitForChild("EliminationEffects"))
local SlideAnimator = require(script.Parent:WaitForChild("SlideAnimator"))
local NotebookController = require(script.Parent:WaitForChild("NotebookController"))
local NotebookModel = require(script.Parent:WaitForChild("NotebookModel"))
local NotebookState = require(shared:WaitForChild("NotebookState"))
local Catalog = require(shared:WaitForChild("Catalog"))
local settingsRemote = shared:WaitForChild("Settings")
local SettingsRules = require(shared:WaitForChild("SettingsRules"))
local ParkourController = require(script.Parent:WaitForChild("ParkourController"))
local player = Players.LocalPlayer
local slideAnimator = SlideAnimator.new(Players, require(shared:WaitForChild("JointRig")), require(shared:WaitForChild("SlidePose")))
-- Number keys belong to the typing mechanic, not an unused tool hotbar.
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
-- Tab is ours: hold it to peek at the MARKED leaderboard instead of Roblox's player list
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
local input, sound = InputState.new(), Audio.new(Config)
local notebook = NotebookController.new(Players, player, input, noteRemote, NotebookState, NotebookModel)
-- players start in third person (B switches to first person); CAPS LOCK frees / re-locks the mouse in both
local thirdPerson = true
local function cameraMode()
    player.CameraMode = thirdPerson and Enum.CameraMode.Classic or Enum.CameraMode.LockFirstPerson
    player.CameraMaxZoomDistance = thirdPerson and 10 or 0.5
    player.CameraMinZoomDistance = thirdPerson and 10 or 0.5
end
-- Third person (B): over-the-shoulder camera with mouse-look; the character turns with the camera
-- (like shift-lock) so other players see where you're aiming.
local shoulder = Vector3.zero
local crouchCam = 0
-- Caps Lock: free the mouse cursor (to click things) and press again to lock it back. (It used to be Left Alt, but
-- alt-tabbing kept unlocking it: Windows / Roblox report Alt going down and up around the switch.)
-- A hidden Modal button is how Roblox lets the cursor out of a first-person camera.
local mouseFree = false
local altTap = nil
local windowFocused, windowFocusedAt = true, -math.huge
local freeGui = Instance.new("ScreenGui")
freeGui.Name = "MouseUnlock"; freeGui.ResetOnSpawn = false; freeGui.DisplayOrder = 0
local freeButton = Instance.new("TextButton")
freeButton.Name = "Free"; freeButton.Modal = true; freeButton.Visible = false; freeButton.Text = ""
freeButton.BackgroundTransparency = 1; freeButton.Size = UDim2.fromOffset(0, 0); freeButton.Selectable = false
freeButton.Parent = freeGui
freeGui.Parent = player:WaitForChild("PlayerGui")
local function setMouseFree(on)
    mouseFree = on
    freeButton.Visible = on
    player:SetAttribute("MouseFree", on)
    if on then UIS.MouseBehavior = Enum.MouseBehavior.Default; UIS.MouseIconEnabled = true end
end
local shoulderHud -- set once the HUD exists (it is created further down)
-- a menu, text box or overlay card (support card, end-of-round screen) is up: the mouse must stay free for clicking
local function overlayUp()
    local pg = player:FindFirstChild("PlayerGui")
    for _, name in ipairs({"CommunityCard", "VictoryScreen", "DailyRewardCard", "LifetimeStats"}) do
        local g = pg and pg:FindFirstChild(name)
        if g and g.Enabled then return true end
    end
    return false
end
local function menuUp()
    -- (Help counts as a menu for the mouse: it stays free while Help is open, so you can read / click it. Number
    -- entry and the held-Tab players peek keep the camera.)
    if shoulderHud and shoulderHud.open and shoulderHud.active ~= "Entry" and not shoulderHud.peek then return true end
    return chatTyping() or overlayUp()
end
Run:BindToRenderStep("MarkedShoulderCamera", Enum.RenderPriority.Camera.Value - 2, function(dt)
    local char = player.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not h or not root then return end
    -- mouse unlocked (ALT): keep it free and visible every frame. Coming back from a menu in first person, Roblox's
    -- camera re-locks the mouse to the centre (and the centre dot then hid the cursor), so the cursor went missing.
    -- (the hidden Modal button is what lets the cursor out of a first-person camera: up while free or in a menu)
    local wantFree = mouseFree or menuUp()
    if freeButton.Visible ~= wantFree then freeButton.Visible = wantFree end
    if wantFree then
        if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then UIS.MouseBehavior = Enum.MouseBehavior.Default end
        if not UIS.MouseIconEnabled then UIS.MouseIconEnabled = true end
    elseif not thirdPerson and h.Health > 0 and player:GetAttribute("InMatch") == true and player.CameraMode == Enum.CameraMode.LockFirstPerson
        and not menuUp() then
        -- first person: ALT again locks the mouse back onto the camera (it used to stay loose until you right-clicked)
        if UIS.MouseBehavior ~= Enum.MouseBehavior.LockCenter then UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end
    end
    local active = thirdPerson and h.Health > 0 and player:GetAttribute("InMatch") == true and not char:GetAttribute("Ragdolled")
    local target = active and Vector3.new(1.9, 0.45, 0) or Vector3.zero
    shoulder = shoulder:Lerp(target, 1 - math.exp(-12 * math.min(dt, 0.05)))
    local crouchTarget = (char:GetAttribute("Crouching") == true and h.Health > 0) and -1.6 or 0
    crouchCam = crouchCam + (crouchTarget - crouchCam) * (1 - math.exp(-14 * math.min(dt, 0.05)))
    h.CameraOffset = shoulder + Vector3.new(0, crouchCam, 0)
    if active then
        -- in a round you always face where the camera looks (shoulder aim); in the lobby you turn with your movement,
        -- so the camera can swing round to the front of your character (see your look, visor and all)
        local aim = player:GetAttribute("InArena") == true
        h.AutoRotate = not aim
        if not mouseFree and not menuUp() then UIS.MouseBehavior = Enum.MouseBehavior.LockCenter end
        if mouseFree then UIS.MouseBehavior = Enum.MouseBehavior.Default end
        local camera = workspace.CurrentCamera
        local look = camera and camera.CFrame.LookVector
        if aim and look and Vector3.new(look.X, 0, look.Z).Magnitude > 0.01 and (char:GetAttribute("SlideUntil") or 0) <= workspace:GetServerTimeNow()
            and not char:GetAttribute("WallHang") then -- (hanging on a wall you face the wall, not the camera)
            root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
        end
    elseif not h.AutoRotate and not char:GetAttribute("Ragdolled") then
        h.AutoRotate = true
    end
end)
local gui=player:WaitForChild("PlayerGui"):WaitForChild("MARKED_UI_EDITABLE")
local View=require(gui:WaitForChild("Controller"))
local hud=View.new(player,gui,shared,Config,SettingsRules,Catalog)
shoulderHud = hud
notebook.hud = hud -- the first-person notebook only comes out while you type
local feel = FeelController.new(player, Config, MotionRules, move, sound, hud)
local effects = EliminationEffects.new(player, Config, MotionRules, sound, feel, hud)
local settings=hud
hud:Attach(sound,feel)
local parkour = ParkourController.new(player, Config, settings, feel)
local function now() return workspace:GetServerTimeNow() end
local function ready()
    if not hud:CanType() or not player:GetAttribute("InMatch") then return false end
    local char = player.Character
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local phase=shared:GetAttribute("Phase")
    -- (in the lobby courtyard the gear comes out at any time: it's only a scratch pad there)
    local lobby = player:GetAttribute("InArena") ~= true
    return (lobby or phase=="Warmup" or phase=="Countdown" or phase=="Playing") and h and h.Health > 0
end
-- typing gear has its own key sound (Typewriter: a type bar strike, Keyboard: a creamy switch); nil = the pen
local function keySound()
    local finish = player:GetAttribute("NotebookFinish")
    return finish == "Typewriter" and "TypeKey" or finish == "Keyboard" and "Switch" or nil
end
local confirm -- (below: typing on past the 4th digit uses it)
-- one digit at a time: a digit that lands within DIGIT_GAP of the last one is dropped. Macros and slamming several
-- keys at once arrive in the same instant; real typing, even fast rolling from key to key, is spaced further apart
-- than this, so it's never held back.
local DIGIT_GAP = 0.03
local lastDigitAt = -math.huge
local function typeDigit(digit)
    if not ready() then return end
    local t = os.clock()
    if t - lastDigitAt < DIGIT_GAP then return end
    lastDigitAt = t
    -- typing on past the 4th digit sends the number (in the lobby: writes it down), then the entry resets
    if #input.buffer >= 4 and not input.pending and now() >= input.deadline then confirm() return end
    notebook:CancelInspect()
    hud:Show("Entry")
    local previous = input.buffer
    local code, serial = input:Digit(digit, now())
    -- (the Typewriter clacks a key instead of the pen's scratch, the 4th digit too: no submit chime on top)
    local key = keySound()
    if previous ~= input.buffer or (code and key) then sound:Play(key or "Digit"); notebook:Sync() end
    if code then if not key then sound:Play("Submit") end; submit:FireServer(code, serial) end
end
local function erase()
    if not ready()then return end
    local previous = input.buffer
    input:Backspace(now())
    -- (backspace makes the same sound as typing on your gear: the pen, the type bar, the switch)
    if previous ~= input.buffer then sound:Play(keySound() or "Digit") end
    notebook:Sync()
end
-- Y: take out your gear and turn it over to look at it (NotebookController:Inspect)
local function inspect()
    if not ready() then return end
    notebook:Inspect()
end
function confirm()
    if not ready() then return end
    -- the lobby: the line is written down and a fresh one starts. Nothing is sent, so no one can be marked there.
    if player:GetAttribute("InArena") ~= true then
        if input:Write(now()) then sound:Play(keySound() or "Submit"); notebook:Sync() end
        return
    end
    local code,serial=input:Confirm(now())
    -- (Enter on the Typewriter is one more key strike, like the digits)
    if code then sound:Play(keySound() or "Submit");submit:FireServer(code,serial) end
end
hud:BindConfirm(confirm)
-- touch buttons / keypad and gamepad controls (StarterPlayerScripts.PadControls)
local pad = require(script.Parent:WaitForChild("PadControls")).new({player = player, hud = hud, feel = feel, parkour = parkour, input = input,
    sound = sound, typeDigit = typeDigit, erase = erase, confirm = confirm, inspect = inspect,
    toggleCamera = function() thirdPerson = not thirdPerson; cameraMode() end})
-- E / the TYPE A NUMBER prompt opens number entry (and closes it again while nothing is typed)
hud.openEntry = function()
    if not ready() then return end
    notebook:CancelInspect()
    -- E toggles the notebook. Putting it away cancels whatever is typed (even a full number), unless a number is
    -- already being checked by the server.
    local out = hud.active == "Entry" or input.buffer ~= ""
    if out then
        if input.pending then return end
        input.buffer, input.status = "", "Ready" -- (any miss cooldown still runs)
        notebook.lastTypedAt = -math.huge
        notebook:Sync()
        hud:Show("HUD")
    else
        hud:Show("Entry")
    end
end
local names = {"Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
local digits = {}
for index, name in ipairs(names) do digits[name] = tostring(index - 1); digits["Keypad" .. name] = tostring(index - 1) end

UIS.InputBegan:Connect(function(key, consumed)
    -- Tab: the players list once you've deployed (lobby courtyard or match). Hold it to peek (release to go
    -- back), or tap it to keep the list open (tap again to close). Not on the main menu.
    if key.KeyCode == Enum.KeyCode.Tab and altTap then altTap.clean = false; return end
    if key.KeyCode == Enum.KeyCode.Tab and not chatTyping() then
        if hud.active == "Leaderboard" and not hud.peek then hud:Show("HUD"); return end
        if not hud.peek and hud.active == nil and player:GetAttribute("InMatch") == true then
            hud.peekReturn = hud.active or "HUD"; hud.peek = true; hud.peekAt = os.clock(); hud:Show("Leaderboard")
        end
        return
    end
    -- Caps Lock frees / re-locks the mouse
    if key.KeyCode == Enum.KeyCode.CapsLock then
        if windowFocused and not chatTyping() and player:GetAttribute("InMatch") then
            setMouseFree(not mouseFree)
            hud:Toast(mouseFree and "Mouse unlocked  ·  CAPS LOCK to lock" or "Mouse locked")
        end
        return
    end
    if altTap then altTap.clean = false end
    if chatTyping() then return end
    local name = key.KeyCode.Name
    -- menu keys come before the "already handled" check: Roblox's camera uses I (and O) to zoom, so I arrived
    -- marked as handled and the Loadout never opened
    if name=="F4" then settings:Toggle();return end
    if name=="I" then hud:Show(hud.active=="Inventory" and "HUD" or "Inventory");return end
    if name=="F2" then hud:Show(hud.active=="Shop" and "HUD" or "Shop");return end
    if name=="F3" then hud:Show(hud.active=="Quests" and "HUD" or "Quests");return end
    -- H opens Help and closes it again (an overlay: the movement keys below keep working while it's up)
    if name=="H" and player:GetAttribute("InMatch")==true and (hud.active==nil or hud.active=="Help") then hud:ToggleHelp();return end
    if consumed then return end
    -- (gamepad buttons, B included, are handled by PadControls)
    if not hud:CanType() or not player:GetAttribute("InMatch") then return end
    -- (number keys, ENTER and E work in the lobby too: the gear comes out as a scratch pad, see confirm)
    if digits[name] then typeDigit(digits[name])
    elseif name == "Return" or name == "KeypadEnter" then confirm()
    elseif name == "Backspace" then erase()
    elseif name == "P" then
        -- no leaving for the main menu mid-round
        if player:GetAttribute("InArena") == true then hud:Toast("Not during a round") else menuRemote:FireServer("Menu") end
    elseif name == "B" then thirdPerson = not thirdPerson; cameraMode()
    elseif name == settings.values.SprintKey then
        if settings.values.SprintMode=="Toggle" then feel:SetSprint(not feel.sprint)else feel:SetSprint(true)end
    elseif name == settings.values.SlideKey then feel:Slide()
    elseif name == "Q" then parkour:RequestDash()
    elseif name == "LeftControl" or name == "RightControl" then parkour:SetCrouch(true)

    elseif name == "E" then hud.openEntry()
    elseif name == "Y" then inspect() end
end)
UIS.WindowFocusReleased:Connect(function() windowFocused = false; altTap = nil end)
-- mouse unlocked (CAPS LOCK) and you click into the world (not on a button): lock it again, dot back
UIS.InputBegan:Connect(function(i, processed)
    if processed or i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if mouseFree and not menuUp() and player:GetAttribute("InMatch") == true then
        setMouseFree(false)
        hud:Toast("Mouse locked")
    end
end)
UIS.WindowFocused:Connect(function() windowFocused = true; windowFocusedAt = os.clock(); altTap = nil end)
-- (if the "focused" event never arrives, the first click or key after counts as coming back)
UIS.InputBegan:Connect(function(i)
    if windowFocused then return end
    local t = i.UserInputType
    if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 then
        windowFocused = true; windowFocusedAt = os.clock(); altTap = nil
    end
end)
UIS.InputEnded:Connect(function(key)
    if key.KeyCode == Enum.KeyCode.Tab and hud.peek then
        hud.peek = false
        if hud.active == "Leaderboard" then
            -- a quick tap keeps the list open (with the mouse free for its buttons); a hold closes it on release
            if os.clock() - (hud.peekAt or 0) < 0.3 then hud:Show("Leaderboard") else hud:Show(hud.peekReturn or "HUD") end
        end
        return
    end
    if key.KeyCode.Name == settings.values.SprintKey and settings.values.SprintMode=="Hold" then feel:SetSprint(false) end
    if key.KeyCode == Enum.KeyCode.LeftControl or key.KeyCode == Enum.KeyCode.RightControl then parkour:SetCrouch(false) end
end)
result.OnClientEvent:Connect(function(serial, status, deadline)
    if input:Resolve(serial, status, deadline) then
        hud.feedback:Result(status,input.buffer)
        notebook:Sync()
        if status == "Miss" then sound:Play("Miss") end
    end
end)
notice.OnClientEvent:Connect(function(kind, data)
    if kind == "Kill" then
        hud:AddKill(data, now())
        -- a self-elimination still shatters in the world, but is not a kill for anyone
        if data.KillerId == data.VictimId then effects:WorldBurst(data) else effects:Kill(data) end
    elseif kind == "Slide" then sound:Play("Slide"); feel:Punch(0.22)
    elseif kind == "LevelUp" then hud:Toast("LEVEL UP  —  LV. " .. tostring(data and data.Level or "?")); sound:Play("Combo")
    elseif kind == "NewNumber" then
        -- your number was scrambled (after an elimination)
        local TopNotices = require(shared:WaitForChild("TopNotices"))
        TopNotices.Push("NEW NUMBER  ·  " .. tostring(data and data.Code or "????"), {kind = "good",
            eyebrow = data and data.Reason == "Crypt" and "THE CRYPT" or "SCRAMBLED", duration = 3.2})
        sound:Play("Spawn")
    elseif kind == "Seance" then
        -- THE CRYPT: every other living fighter is outlined through walls for a few seconds
        local TopNotices = require(shared:WaitForChild("TopNotices"))
        local left = math.max(0.5, (data and data.Until or 0) - workspace:GetServerTimeNow())
        local ids = data and data.Ids or {}
        local marks = {}
        for _, id in ipairs(ids) do
            local other = Players:GetPlayerByUserId(id)
            local character = other and other.Character
            if character then
                local h = Instance.new("Highlight")
                h.Name = "SeanceMark"
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillColor = Color3.fromRGB(150, 12, 24); h.FillTransparency = 0.82
                h.OutlineColor = Color3.fromRGB(255, 60, 60); h.OutlineTransparency = 0
                h.Adornee = character
                h.Parent = character
                table.insert(marks, h)
            end
        end
        TopNotices.Push(#ids == 0 and "NO SOULS ANSWER" or (#ids .. (#ids == 1 and " SOUL" or " SOULS") .. " REVEALED  ·  " .. math.floor(left + 0.5) .. "s"),
            {kind = "good", eyebrow = "THE SÉANCE", duration = 3.2})
        sound:Play("Spawn")
        task.delay(left, function()
            for _, h in ipairs(marks) do
                if h.Parent then
                    local tween = game:GetService("TweenService"):Create(h, TweenInfo.new(0.5), {FillTransparency = 1, OutlineTransparency = 1})
                    tween:Play()
                    game:GetService("Debris"):AddItem(h, 0.6)
                end
            end
        end)
    elseif kind == "Seen" then
        -- someone finished a séance at the crypt: you're visible to them through walls for a few seconds
        local TopNotices = require(shared:WaitForChild("TopNotices"))
        local left = math.max(0.5, (data and data.Until or 0) - workspace:GetServerTimeNow())
        TopNotices.Set("Seen", {text = "THE DEAD ARE WATCHING YOU", sub = "Someone at the crypt can see you through walls.",
            eyebrow = "THE SÉANCE", kind = "bad", order = 4})
        sound:Play("Miss")
        task.delay(left, function() TopNotices.Set("Seen", nil) end)
    elseif kind == "Death" then
        input:Reset(); notebook:Reset(); effects:Reset(); feel:SetSprint(false)
        hud:DeathFlash(data); sound:Play("Death"); effects:Death(data)
    end
end)
-- THE CRYPT: progress card while you stand in the circle (CryptService writes CryptProgress: 0..1, or -1 on cooldown)
do
    local TopNotices = require(shared:WaitForChild("TopNotices"))
    local lastStep = -1
    local function cryptCard()
        local p = player:GetAttribute("CryptProgress")
        if p == nil then TopNotices.Set("Crypt", nil); lastStep = -1; return end
        if p < 0 then
            local left = math.max(0, math.ceil((player:GetAttribute("CryptReadyAt") or 0) - workspace:GetServerTimeNow()))
            TopNotices.Set("Crypt", {text = "THE CIRCLE IS COLD  ·  " .. left .. "s", eyebrow = "THE CRYPT", kind = "bad", order = 5})
            return
        end
        local steps = math.floor(p * 10 + 0.5)
        TopNotices.Set("Crypt", {text = "CALLING THE DEAD  " .. string.rep("▰", steps) .. string.rep("▱", 10 - steps),
            sub = "Stay in the circle. Everyone can see the beam.", eyebrow = "THE CRYPT", kind = "info", order = 5})
        if steps ~= lastStep and steps > 0 then lastStep = steps; sound:Play("UITab", 0.8 + steps * 0.04) end
    end
    player:GetAttributeChangedSignal("CryptProgress"):Connect(cryptCard)
    task.spawn(function()
        while true do task.wait(1); if (player:GetAttribute("CryptProgress") or 0) < 0 then cryptCard() end end
    end)
end
local phaseSounds = {Countdown = "Countdown", Playing = "Round", Results = "Results"}
-- the round bell tolls again with one minute left
do
    local minuteRound = nil
    task.spawn(function()
        while task.wait(0.5) do
            if shared:GetAttribute("Phase") == "Playing" and player:GetAttribute("InArena") then
                local left = (shared:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()
                local round = shared:GetAttribute("RoundId")
                if left <= 60 and left > 55 and minuteRound ~= round then
                    minuteRound = round
                    sound:Play("Round")
                    if hud and hud.Toast then pcall(function() hud:Toast("ONE MINUTE REMAINS") end) end
                end
            end
        end
    end)
end
shared:GetAttributeChangedSignal("Phase"):Connect(function()
    input:Reset(); notebook:Reset(); effects:Reset()
    local phase = shared:GetAttribute("Phase")
    local cue = phaseSounds[phase]
    if phase == "Countdown" then
        -- the match is starting: you're sent into the arena a moment after the phase changes (it used to check
        -- InArena straight away and miss it, so the start was silent). Wait for it, then the start sting + countdown.
        task.spawn(function()
            local t0 = os.clock()
            while os.clock() - t0 < 3 and not player:GetAttribute("InArena") do task.wait(0.1) end
            if player:GetAttribute("InArena") and shared:GetAttribute("Phase") == "Countdown" then
                sound:Play("MatchStart"); sound:Play(cue)
            end
        end)
    elseif cue and player:GetAttribute("InArena") then
        sound:Play(cue)
    end
end)
-- READY UP / cancel in the lobby
player:GetAttributeChangedSignal("Ready"):Connect(function()
    if player:GetAttribute("InArena") == true then return end
    if player:GetAttribute("Ready") == true then sound:Play("ReadyUp") return end
    -- (the server also clears Ready when it sends you in: only a cancel that leaves you in the lobby gets the sound)
    task.delay(0.35, function()
        local phase = shared:GetAttribute("Phase")
        if player:GetAttribute("Ready") ~= true and player:GetAttribute("InArena") ~= true and phase ~= "Countdown" then sound:Play("ReadyCancel") end
    end)
end)
parkour:On(function(name)
    if name == "Jump" then sound:Play("Jump")
    elseif name == "AirJump" then sound:Play("AirJump"); feel:Punch(0.12)
    elseif name == "Dash" or name == "WallBounce" then sound:Play("AirJump")
    elseif name == "WallJump" then sound:Play("Jump")
    elseif name == "Mantle" then sound:Play("Land")
    elseif name == "Climb" then sound:Play("Jump")
    elseif name == "WallHang" then sound:Play("Land")
    elseif name == "WallDash" then sound:Play("AirJump")
    elseif name == "WallLaunch" then sound:Play("AirJump"); sound:Play("Jump") end
end)
-- Roblox's UI navigation mode (toggled by the \ key, which sits right next to Enter on many keyboards) draws a
-- white outline around a menu button and swallows movement keys, which left players stuck after typing a number.
-- Keyboard/mouse players never need it, so it is switched off; gamepads still get normal selection.
local GuiService = game:GetService("GuiService")
-- (PadControls switches AutoSelectGuiEnabled on only while a gamepad is in use)
local function gamepadInput()
    local last = UIS:GetLastInputType()
    return last.Name:match("^Gamepad") ~= nil
end
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
    if GuiService.SelectedObject and not gamepadInput() then GuiService.SelectedObject = nil end
end)
-- Leaving the window (alt-tab) can leave W/A/S/D "held" in Roblox's own controls. Switching them off while
-- unfocused and back on when you return clears any stuck key.
task.spawn(function()
    local ok, controls = pcall(function()
        return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
    end)
    if not ok or not controls then return end
    -- (Roblox doesn't always report the window coming back -- in Studio pressing Alt alone jumps to the menu bar and
    -- back -- so the controls also come back on the first key press or click after; otherwise you were left frozen)
    local off = false
    UIS.WindowFocusReleased:Connect(function() off = true; pcall(function() controls:Disable() end) end)
    local function back() if off then off = false; pcall(function() controls:Enable() end) end end
    UIS.WindowFocused:Connect(back)
    UIS.InputBegan:Connect(function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 then back() end
    end)
end)
local codeConnection
local function spawn(character)
    if mouseFree then setMouseFree(false) end
    if codeConnection then codeConnection:Disconnect() end
    input:Reset()
    notebook:Reset()
    feel:Spawn(character)
    effects:Reset()
    cameraMode()
    if player:GetAttribute("InMatch") and workspace.CurrentCamera then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        workspace.CurrentCamera.CameraSubject = character:WaitForChild("Humanoid")
    end
    local function assigned() if character:GetAttribute("NumberfallCode") then sound:Play("Spawn") end end
    codeConnection = character:GetAttributeChangedSignal("NumberfallCode"):Connect(assigned)
    assigned()
end
player.CharacterAdded:Connect(spawn)
if player.Character then spawn(player.Character) end
cameraMode()
local elapsed = 0
local lockTarget = nil
-- once a number has been spotted, the lock (and the enlarged number) holds on for a moment after you lose sight
-- of it, so a glimpse is enough to read it
local LOCK_HOLD = 0.6
local heldLock, heldAt = nil, -math.huge
-- who you've spotted recently (the minimap shows them): player -> {at = os.clock(), position = Vector3}
hud.spotted = hud.spotted or {}
local function lockAlive(t)
    local p = t and t.Player
    local c = p and p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return p and p.Parent and h and h.Health > 0 and c:GetAttribute("NumberfallCode") == t.Code
end
Run.RenderStepped:Connect(function(dt)
    input:Tick(now())
    notebook:Sync()
    local camera = workspace.CurrentCamera
    if not camera then return end
    hud:Render(input, shared, player.Character, now(), camera.ViewportSize)
    elapsed = elapsed + dt
    -- choose who you're looking at ~20x a second; keep the lock-on glued to their visor every frame
    if elapsed >= 0.05 then
        elapsed = 0
        local fresh = NumberView.Update(Players, player, camera, Rules, Config)
        if fresh then
            heldLock, heldAt = fresh, os.clock()
            local root = fresh.Player and fresh.Player.Character and fresh.Player.Character:FindFirstChild("HumanoidRootPart")
            if root then hud.spotted[fresh.Player] = {at = os.clock(), position = root.Position} end
        end
        if fresh then lockTarget = fresh
        elseif heldLock and os.clock() - heldAt < LOCK_HOLD and lockAlive(heldLock) then lockTarget = heldLock
        else lockTarget, heldLock = nil, nil end
    end
    local shown = lockTarget and (NumberView.Reproject(lockTarget, camera) or NumberView.Reproject(lockTarget, camera, true)) or nil
    hud:SetTarget(shown)
end)
