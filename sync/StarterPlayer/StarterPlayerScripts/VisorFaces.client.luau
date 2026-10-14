-- Idle visors (tag "VisorBlink", the 0__0 face on unassigned players and statues) blink now and then:
-- each "0" eye panel holds an "Open" and a "Closed" layer (built by ServerScriptService.VisorDisplay).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BLINK = 0.13          -- how long the eyes stay shut
local GAP = {2.2, 5.5}      -- seconds between blinks (random per face)
local DOUBLE = 0.25         -- chance of a quick double blink

local faces = {}            -- anchor -> {next = time, shutUntil = time, again = bool}
local rng = Random.new()

local function setEyes(anchor, open)
	for _, panel in ipairs(anchor:GetChildren()) do
		local gui = panel:FindFirstChild("FrontNumber")
		local o = gui and gui:FindFirstChild("Open")
		local c = gui and gui:FindFirstChild("Closed")
		if o and c then o.Visible = open; c.Visible = not open end
	end
end

local function add(anchor)
	faces[anchor] = {next = os.clock() + rng:NextNumber(0.5, GAP[2])}
end
local function remove(anchor) faces[anchor] = nil end

CollectionService:GetInstanceAddedSignal("VisorBlink"):Connect(add)
CollectionService:GetInstanceRemovedSignal("VisorBlink"):Connect(remove)
for _, a in ipairs(CollectionService:GetTagged("VisorBlink")) do add(a) end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / 30 then return end
	acc = 0
	local now = os.clock()
	-- low end mode: statues and idle visors just keep their eyes open
	if game:GetService("Players").LocalPlayer:GetAttribute("LowEnd") == true then
		for anchor, f in pairs(faces) do if f.shutUntil and anchor.Parent then setEyes(anchor, true); f.shutUntil = nil end end
		return
	end
	for anchor, f in pairs(faces) do
		if not anchor.Parent then
			faces[anchor] = nil
		elseif f.shutUntil then
			if now >= f.shutUntil then
				setEyes(anchor, true)
				f.shutUntil = nil
				if not f.second and rng:NextNumber() < DOUBLE then
					f.second = true                  -- quick second blink
					f.next = now + 0.12
				else
					f.second = false
					f.next = now + rng:NextNumber(GAP[1], GAP[2])
				end
			end
		elseif now >= f.next then
			setEyes(anchor, false)
			f.shutUntil = now + BLINK
		end
	end
end)
