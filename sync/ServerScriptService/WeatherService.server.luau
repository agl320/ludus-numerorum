-- Rain now and then (ReplicatedStorage.Numberfall.Weather explains the attributes): every 4-8 minutes there's a
-- chance of a shower lasting 1.5-3.5 minutes. Clients do all the drawing and sound from these three attributes.
local RS = game:GetService("ReplicatedStorage")
local state = RS:WaitForChild("Numberfall")
local random = Random.new()

local CHANCE = 0.45          -- of a shower at each check
local GAP = {240, 480}       -- seconds between checks
local LENGTH = {90, 210}     -- shower length

local function shower(delay)
	local now = workspace:GetServerTimeNow()
	local starts = now + delay
	state:SetAttribute("RainStrength", random:NextNumber(0.55, 1))
	state:SetAttribute("RainStartsAt", starts)
	state:SetAttribute("RainEndsAt", starts + random:NextNumber(LENGTH[1], LENGTH[2]))
end

-- a fresh server sometimes opens in the rain
if random:NextNumber() < 0.3 then shower(random:NextNumber(20, 90)) end
while true do
	task.wait(random:NextNumber(GAP[1], GAP[2]))
	local ends = state:GetAttribute("RainEndsAt") or 0
	if workspace:GetServerTimeNow() > ends and random:NextNumber() < CHANCE then shower(5) end
end
