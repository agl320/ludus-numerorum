-- ArtworkLoader: syncs ArtworkAssetIds to ImageLabels. Direct rbxassetid:// only, no thumbnail fallback.
local Players = game:GetService("Players")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MARKED_UI_EDITABLE")
local slots = gui:WaitForChild("ArtworkAssetIds")
local allowed, cache, pending, watched = {}, {}, {}, {}
local function refreshIds()
    table.clear(allowed)
    for _, slot in ipairs(slots:GetChildren()) do
        if slot:IsA("StringValue") then
            local id = slot.Value:match("rbxassetid://(%d+)")
            if id then allowed[id] = true end
        end
    end
end
local function apply(image, original, uri)
    if image.Parent and image.Image == original and original ~= uri then image.Image = uri end
end
local function check(image)
    local original = image.Image
    local id = original:match("^rbxassetid://(%d+)$")
    if not id or not allowed[id] then return end
    if cache[id] then apply(image, original, cache[id]); return end
    if pending[id] then
        pending[id][image] = original
        return
    end
    pending[id] = {[image] = original}
    task.spawn(function()
        -- Always use the direct rbxassetid:// URL for full resolution.
        -- No PreloadAsync gatekeeping, no low-res thumbnail fallback.
        cache[id] = original
        local waiting = pending[id]
        pending[id] = nil
        for target, expected in pairs(waiting) do apply(target, expected, original) end
    end)
end
local function watch(node)
    if watched[node] or not (node:IsA("ImageLabel") or node:IsA("ImageButton")) then return end
    watched[node] = true
    node:GetPropertyChangedSignal("Image"):Connect(function() check(node) end)
    check(node)
end
refreshIds()
for _, slot in ipairs(slots:GetChildren()) do
    if slot:IsA("StringValue") then slot.Changed:Connect(refreshIds) end
end
for _, node in ipairs(gui:GetDescendants()) do watch(node) end
gui.DescendantAdded:Connect(watch)
