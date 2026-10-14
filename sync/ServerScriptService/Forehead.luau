-- Shows the character's number on the LED visor's screen (ServerScriptService.VisorDisplay).
-- Falls back to the original single-sided forehead plate if the visor template is missing.
local Visor = require(script.Parent:WaitForChild("VisorDisplay"))
local FaceMask = require(script.Parent:WaitForChild("FaceMask"))
local Hair = require(script.Parent:WaitForChild("Hair"))
local Outfit = require(script.Parent:WaitForChild("Outfit"))
local BodyType = require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("BodyType"))
local Forehead = {}
-- Body type (Loadout > Body): swap the torso to the player's choice. Done when the character spawns (before the
-- ragdoll rig is prepared) and on Loadout changes outside a round. Returns true if the torso changed; the outfit is
-- then re-applied by the cosmetics pass (SkinApplied cleared).
function Forehead.Body(character)
    local player = game:GetService("Players"):GetPlayerFromCharacter(character)
    if not player then return false end
    local ok, changed = pcall(BodyType.Apply, character, player:GetAttribute("BodyType"), true)
    if ok and changed then
        character:SetAttribute("SkinApplied", nil)
        local holder = character:FindFirstChild("Outfit"); if holder then holder:SetAttribute("OutfitId", nil) end
    end
    return ok and changed
end
function Forehead.Equip(character, config)
    Hair.Equip(character)                      -- chosen hairstyle (ServerScriptService.Hair)
    FaceMask.Equip(character)                  -- cloth bandana mask under the visor
    Outfit.Equip(character)                    -- clothing + the player's skin tone (ServerScriptService.Outfit)
    return character:FindFirstChild("LEDVisor") or Visor.Equip(character, config)
end
-- Re-apply the cosmetic look after a Loadout / Shop change (or once the profile loads): hair, scarf,
-- and refit the visor over the new bangs, keeping whatever its screen was showing.
function Forehead.Refresh(character, config)
    local oldPad = character:GetAttribute("VisorPad") or 0
    -- not mid-round: an arena body is already rigged for ragdolls (the new body type applies on the next spawn)
    local owner = game:GetService("Players"):GetPlayerFromCharacter(character)
    if not (owner and owner:GetAttribute("InArena")) then Forehead.Body(character) end
    Hair.Equip(character)
    FaceMask.Equip(character)
    Outfit.Equip(character)
    local visor = character:FindFirstChild("LEDVisor")
    local screen = character:FindFirstChild("NumberForehead")
    local code = character:GetAttribute("NumberfallCode") or (screen and screen:GetAttribute("Face")) or Visor.IDLE
    if visor and (character:GetAttribute("VisorPad") or 0) ~= oldPad then
        visor = Visor.Equip(character, config)
        if screen and visor then Visor.Display(character, visor, code, config) end
    elseif visor and screen then
        -- a new NUMBER STYLE: redraw the screen with the same number / face
        local player = game:GetService("Players"):GetPlayerFromCharacter(character)
        local style = player and player:GetAttribute("NumberStyle")
        if style and screen:GetAttribute("NumberStyle") ~= style then Visor.Display(character, visor, code, config) end
    end
end
-- the last number someone wore this round: the results screen shows it even after they've been eliminated
function Forehead.Remember(character, code)
    if not code then return end
    character:SetAttribute("LastCode", code)
    local player = game:GetService("Players"):GetPlayerFromCharacter(character)
    if player then player:SetAttribute("LastCode", code) end
end
function Forehead.Attach(character, code, tint, config)
    local head = character:FindFirstChild("Head")
    if not head then return end
    local visor = Forehead.Equip(character, config)
    local screen = visor and Visor.Display(character, visor, code, config)
    if screen then
        character:SetAttribute("NumberfallCode", code)
        Forehead.Remember(character, code)
        return screen
    end
    local plate = Instance.new("Part")
    plate.Name = "NumberForehead"
    plate.Size = Vector3.new(head.Size.X * 0.94, head.Size.Y * 0.44, 0.04)
    plate.Color = Color3.fromRGB(17, 24, 33)
    plate.Material = Enum.Material.SmoothPlastic
    plate.CanCollide, plate.CanTouch, plate.CanQuery, plate.Massless = false, false, false, true
    plate.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.27, -head.Size.Z / 2 - 0.035)
    plate.Parent = character
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1, weld.Parent = head, plate, plate
    local surface = Instance.new("SurfaceGui")
    surface.Name = "FrontNumber"
    surface.Face = Enum.NormalId.Front
    surface.AlwaysOnTop = false
    surface.LightInfluence = 0
    surface.MaxDistance = config.ForeheadDistance
    surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    surface.CanvasSize = Vector2.new(400, 100)
    surface.Parent = plate
    local label = Instance.new("TextLabel")
    label.Name = "Digits"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Text = code
    label.Font = Enum.Font.Code
    label.TextScaled = true
    label.TextColor3 = tint
    label.Parent = surface
    character:SetAttribute("NumberfallCode", code)
    Forehead.Remember(character, code)
    return plate
end
-- Main menu / lobby / waiting: no number assigned (nothing to target), the screen shows a blinking 0__0 face
function Forehead.Blank(character, config)
    local visor = Forehead.Equip(character, config)
    if visor then Visor.Display(character, visor, Visor.IDLE, config) end
    character:SetAttribute("NumberfallCode", nil)
end
-- Eliminated: the screen reads X__X (kept on the corpse)
function Forehead.Dead(character, config)
    character:SetAttribute("NumberfallCode", nil)
    local visor = character:FindFirstChild("LEDVisor")
    local screen = visor and Visor.Display(character, visor, Visor.DEAD, config)
    if not screen then
        local plate = character:FindFirstChild("NumberForehead")
        if plate then plate:Destroy() end
    end
end
return Forehead
