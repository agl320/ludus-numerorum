local NumberView = {}
-- tutorial bots are read like players (StarterPlayerScripts.BotProxy)
local BotProxy = require(script.Parent:WaitForChild("BotProxy"))
function NumberView.Update(players, localPlayer, camera, rules, config)
    local best,bestDistance=nil,110
    local list = BotProxy.List(players)
    for _, player in ipairs(list) do
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local plate = character and character:FindFirstChild("NumberForehead")
        -- The LED visor splits the number across one "FrontNumber" SurfaceGui per digit.
        local surfaces = {}
        if plate then
            for _, object in ipairs(plate:GetDescendants()) do
                if object.Name == "FrontNumber" and object:IsA("SurfaceGui") then table.insert(surfaces, object) end
            end
        end
        local surface = surfaces[1]
        local own = player == localPlayer
        -- Your own visor + digits: hidden in first person (it would sit right in front of your eyes),
        -- shown when the camera is pulled out to third person (B).
        local ownVisible = false
        if own and head then
            local root = character:FindFirstChild("HumanoidRootPart")
            local eye = root and root.Position + Vector3.new(0, 1.5, 0) or head.Position
            local flag = localPlayer:GetAttribute("OwnHeadHidden")
            if flag ~= nil then ownVisible = not flag
            else ownVisible = (camera.CFrame.Position - eye).Magnitude > math.max(config.OwnVisorDistance or 2, 3) end
            local visor = character:FindFirstChild("LEDVisor")
            local handle = visor and visor:FindFirstChild("Handle")
            if handle then handle.LocalTransparencyModifier = ownVisible and 0 or 1 end
        end
        if head and surface then
            local offset = camera.CFrame.Position - head.Position
            local dot = offset.Magnitude > 0.01 and head.CFrame.LookVector:Dot(offset.Unit) or -1
            local readable = if own then ownVisible else rules.FrontVisible(dot, config.FrontDot)
            -- killcam: you're watching your killer, so every number shows as ****
            local masked = not own and localPlayer:GetAttribute("Killcam") == true
            for _, gui in ipairs(surfaces) do
                gui.Enabled = readable and not masked
                local mask = gui.Parent and gui.Parent:FindFirstChild("MaskNumber")
                if mask then mask.Enabled = readable and masked end
            end
            if own then plate.LocalTransparencyModifier = 1 end
            local hum=character:FindFirstChildOfClass("Humanoid")
            if not own and surface.Enabled and character:GetAttribute("NumberfallCode") and player:GetAttribute("InMatch") and hum and hum.Health>0 and offset.Magnitude<(config.TargetDistance or 30) then
                -- frame exactly the lit digits on the visor (not the head): screen bounds of the digit panels
                local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
                local onScreen=false
                for _,gui in ipairs(surfaces) do
                    local panel=gui.Parent
                    if panel and panel:IsA("BasePart") then
                        -- only the lit glyph area of each digit cell (the cells have dark margins that curve round the visor)
                        local hx,hy=panel.Size.X/2*0.51,panel.Size.Y/2*0.63
                        for _,c in ipairs({Vector3.new(hx,hy,0),Vector3.new(-hx,hy,0),Vector3.new(hx,-hy,0),Vector3.new(-hx,-hy,0)}) do
                            local sp,vis=camera:WorldToViewportPoint(panel.CFrame:PointToWorldSpace(c))
                            if vis then onScreen=true end
                            minX,minY=math.min(minX,sp.X),math.min(minY,sp.Y);maxX,maxY=math.max(maxX,sp.X),math.max(maxY,sp.Y)
                        end
                    end
                end
                local screen=Vector3.new((minX+maxX)/2,(minY+maxY)/2,0)
                local visible=onScreen and minX<math.huge
                local distance=(Vector2.new(screen.X,screen.Y)-camera.ViewportSize/2).Magnitude
                if visible and distance<bestDistance then
                    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances=localPlayer.Character and {localPlayer.Character}or{}
                    local hit=workspace:Raycast(camera.CFrame.Position,head.Position-camera.CFrame.Position,params)
                    if hit and hit.Instance:IsDescendantOf(character) then
                        bestDistance=distance;best={X=screen.X,Y=screen.Y,W=maxX-minX,H=maxY-minY,Code=character:GetAttribute("NumberfallCode"),Surfaces=surfaces,Player=player}
                    end
                end
            end
        end
    end
    return best
end
-- Re-measure the chosen target's lit digits on screen. Picking a target runs ~20 times a second, but the lock-on
-- box and the enlarged number are moved with this every frame, so they stay glued to the visor while you strafe
-- or turn (they used to trail behind between updates, which made the number hard to read on the move).
-- loose: keep following the visor even if it has turned away (used to hold a lock for a moment after spotting)
function NumberView.Reproject(target, camera, loose)
    if not target or not target.Surfaces then return nil end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local onScreen, lit = false, false
    for _, gui in ipairs(target.Surfaces) do
        local panel = gui.Parent
        if (gui.Enabled or loose) and panel and panel:IsA("BasePart") and panel:IsDescendantOf(workspace) then
            lit = true
            local hx, hy = panel.Size.X / 2 * 0.51, panel.Size.Y / 2 * 0.63
            for _, c in ipairs({Vector3.new(hx, hy, 0), Vector3.new(-hx, hy, 0), Vector3.new(hx, -hy, 0), Vector3.new(-hx, -hy, 0)}) do
                local sp, vis = camera:WorldToViewportPoint(panel.CFrame:PointToWorldSpace(c))
                if vis then onScreen = true end
                minX, minY = math.min(minX, sp.X), math.min(minY, sp.Y); maxX, maxY = math.max(maxX, sp.X), math.max(maxY, sp.Y)
            end
        end
    end
    if not lit or not onScreen or minX == math.huge then return nil end
    return {X = (minX + maxX) / 2, Y = (minY + maxY) / 2, W = maxX - minX, H = maxY - minY, Code = target.Code,
        Surfaces = target.Surfaces, Player = target.Player}
end
return NumberView
