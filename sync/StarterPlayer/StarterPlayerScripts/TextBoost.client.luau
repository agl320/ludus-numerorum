-- Bigger UI text everywhere: every text label / button / box in the game's screen GUIs is drawn at Scale times the
-- size it was built with (change the Scale attribute on this script to tune it; 1 = off).
-- A label that no longer fits its box at the bigger size steps back down (never below its own size), so nothing
-- spills out of buttons or gets cut off. Sizes set later by other scripts are taken as their new base and boosted
-- the same way. (Skipped: TextScaled labels, which already fill their box, and anything under an object with the
-- attribute NoTextBoost = true.)
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local gui=player:WaitForChild("PlayerGui")
local SKIP={FPSCounter=true,AdminPanel=true,Freecam=true}
local K=script:GetAttribute("Scale") or 1.3
local base=setmetatable({},{__mode="k"})   -- the size it was built with (or last set to by a script)
local fitted=setmetatable({},{__mode="k"}) -- the size it ended up at after fitting
local busy=setmetatable({},{__mode="k"})
local pending={} -- labels to (re)fit on the next frame
local function set(o,size) if o.TextSize~=size then busy[o]=true;o.TextSize=size;busy[o]=nil end end
-- (number-style art, the visor's digits, is drawn with text glyphs sized to the art: left as it is)
local ART={NumberSkin=true,NumberArt=true,VisorOverlay=true}
local function skipped(o)
	local a=o
	while a and a~=gui do
		if ART[a.Name] or a:GetAttribute("NoTextBoost")==true then return true end
		a=a.Parent
	end
	return false
end
-- fit: the boosted size, then down a point at a time (in the same frame) until the text fits its box
local function fit(o)
	if o.TextScaled or not base[o] or not o.Parent then return end
	local b=base[o]
	local size=math.max(1,math.floor(b*K+.5))
	set(o,size)
	while size>b and not o.TextFits do size-=1;set(o,size) end
	fitted[o]=size
end
local function track(o)
	if base[o] or not (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then return end
	local sg=o:FindFirstAncestorWhichIsA("LayerCollector")
	if not sg or not sg:IsA("ScreenGui") or SKIP[sg.Name] or skipped(o) then return end
	base[o]=o.TextSize
	o:SetAttribute("BaseTextSize",o.TextSize)
	o:GetPropertyChangedSignal("TextSize"):Connect(function()
		if busy[o] then return end
		-- (a script setting the same size again every frame keeps the fitted size; a new size is a new base)
		if o.TextSize==base[o] and fitted[o] then set(o,fitted[o]);return end
		base[o]=o.TextSize;o:SetAttribute("BaseTextSize",o.TextSize);pending[o]=true
	end)
	o:GetPropertyChangedSignal("Text"):Connect(function() pending[o]=true end)
	o:GetPropertyChangedSignal("TextScaled"):Connect(function() pending[o]=true end)
	o:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() pending[o]=true end)
	pending[o]=true
end
RunService.Heartbeat:Connect(function()
	for o in pairs(pending)do pending[o]=nil;fit(o) end
end)
for _,o in ipairs(gui:GetDescendants())do track(o) end
gui.DescendantAdded:Connect(track)
