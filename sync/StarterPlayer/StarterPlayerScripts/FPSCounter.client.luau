-- FPS, frame time and ping in the top-left: Settings > Graphics > Performance stats (the menu Controller sets the
-- player attribute ShowStats from it). Off by default.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "FPSCounter"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 100
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0, 0); label.Position = UDim2.fromOffset(8, 8); label.Size = UDim2.fromOffset(200, 20)
label.BackgroundColor3 = Color3.new(0, 0, 0); label.BackgroundTransparency = 0.45; label.BorderSizePixel = 0
label.Font = Enum.Font.Code; label.TextSize = 14; label.TextXAlignment = Enum.TextXAlignment.Left
label.TextColor3 = Color3.fromRGB(120, 255, 140); label.Text = " -- FPS"; label.Parent = gui
local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 4); pad.Parent = label
gui.Parent = player:WaitForChild("PlayerGui")

local function sync() gui.Enabled = player:GetAttribute("ShowStats") == true end
player:GetAttributeChangedSignal("ShowStats"):Connect(sync)
sync()

local frames, elapsed, worst = 0, 0, 0
RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then return end
	frames += 1; elapsed += dt; worst = math.max(worst, dt)
	if elapsed >= 0.5 then
		local fps = frames / elapsed
		local ping = 0
		pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
		label.Text = string.format("%d FPS  %.1fms  ping %dms", math.floor(fps + 0.5), worst * 1000, math.floor(ping + 0.5))
		label.TextColor3 = fps >= 55 and Color3.fromRGB(120, 255, 140) or (fps >= 30 and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(255, 90, 90))
		frames, elapsed, worst = 0, 0, 0
	end
end)
