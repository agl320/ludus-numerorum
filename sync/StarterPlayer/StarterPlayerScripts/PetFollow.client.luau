-- Pets follow their owners (player attribute Pet, Shop > Pets). Every client builds and moves every pet locally
-- (Numberfall.Pets), so they're smooth and cost the server nothing. Pets follow you everywhere: lobby, waiting area
-- and rounds.
-- MOODS: a pet keeps its owner company. Stand around and it does little idle things (stretches, hops, head tilts,
-- grooming, spins); stay still a while and it sits (flyers settle low), longer and it lies down for a nap. Crouch
-- and it lies down beside you straight away. When its owner is eliminated it plays dead by them until they're back.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local NF = game:GetService("ReplicatedStorage"):WaitForChild("Numberfall")
local Pets = require(NF:WaitForChild("Pets"))

local folder = Instance.new("Folder")
folder.Name = "LocalPets"
folder.Parent = workspace

local SIT_AFTER, NAP_AFTER = 9, 26 -- seconds of the owner standing still

local active = {} -- player -> state
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clear(p)
	local a = active[p]
	if a then if a.model then a.model:Destroy() end; active[p] = nil end
end
Players.PlayerRemoving:Connect(clear)

local function owner(p)
	local id = p:GetAttribute("Pet")
	if not id or id == "PetNone" then return nil end
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return id, char, root, hum
end

-- ---------------------------------------------------------------- sounds
-- Each pet has a few sounds per moment, picked at random with a little pitch drift so they don't repeat:
--   greet (appears / its owner is back), idle (now and then), rest (settling down for a nap), sad (owner eliminated),
--   flap (a bird taking off again). {asset id, volume, pitch, seconds before it fades (optional)}
local function S(id, vol, pitch, len) return {id, vol, pitch, len} end
local CROW = {
	greet = {S(130700387062990, 0.08, 1.1)},
	idle = {S(89659350030351, 0.05, 1.15, 1.3), S(130700387062990, 0.065, 1.05)},
	flap = {S(9113444792, 0.09, 1.1, 1.1)},
	sad = {S(5829815715, 0.055, 0.8, 1.5)},
}
local SOUNDS = {
	PetCat = {
		greet = {S(136138461897866, 0.12, 1.05)},
		idle = {S(134699420140804, 0.09, 1.1), S(83454004588488, 0.08, 1.15), S(136138461897866, 0.07, 1.2)},
		rest = {S(88584591314196, 0.11, 1, 2), S(17867246413, 0.09, 1, 3.2)},
		sad = {S(83454004588488, 0.11, 0.72)},
	},
	PetDog = {
		greet = {S(91046640900390, 0.09, 1.15), S(134287003226008, 0.08, 1.2)},
		idle = {S(3136676504, 0.11, 1.05, 1.6), S(123024926216748, 0.06, 1.25), S(91046640900390, 0.06, 1.2)},
		rest = {S(77414722255060, 0.045, 1.1, 1.4)},
		sad = {S(94677980597297, 0.11, 1), S(77414722255060, 0.09, 0.95)},
	},
	PetCrow = CROW,
	PetGilded = {greet = CROW.greet, idle = CROW.idle, flap = CROW.flap, sad = CROW.sad, pitch = 1.15},
	PetBat = {
		greet = {S(117491181431951, 0.055, 1.25, 1)},
		idle = {S(117491181431951, 0.045, 1.4, 1.1)},
		flap = {S(9113444792, 0.055, 1.7, 0.9)},
		sad = {S(117491181431951, 0.045, 0.8, 1.2)},
	},
	PetGhost = {
		greet = {S(9119421596, 0.075, 0.85, 1.8)},
		idle = {S(9119421596, 0.06, 0.7, 2.2), S(135385970610304, 0.035, 0.8, 1.6)},
		sad = {S(9119421596, 0.07, 0.55, 2.4)},
	},
	PetWisp = {
		greet = {S(135385970610304, 0.06, 1.2, 1.8)},
		idle = {S(135385970610304, 0.045, 1.35, 1.6), S(9119421596, 0.045, 1.45, 1.4)},
		sad = {S(135385970610304, 0.045, 0.7, 2)},
	},
	PetReaper = {
		greet = {S(9119421596, 0.08, 0.55, 2.2)},
		idle = {S(9119421596, 0.06, 0.5, 2.4)},
		sad = {S(9119421596, 0.07, 0.42, 2.6)},
	},
	PetSkull = {
		greet = {S(9117268552, 0.08, 1.35)},
		idle = {S(9117268552, 0.07, 1.25), S(9117268552, 0.06, 1.5)},
		sad = {S(9117268552, 0.07, 0.8)},
	},
	PetDrone = {
		greet = {S(601149073, 0.05, 1.1)},
		idle = {S(98505735316366, 0.045, 1.2), S(98505735316366, 0.04, 1.45)},
		rest = {S(98505735316366, 0.035, 0.8)},
		sad = {S(601149073, 0.045, 0.6, 1)},
	},
}
local function sfxGroup()
	local g = SoundService:FindFirstChild("NumberfallSFX", true)
	return g and g:IsA("SoundGroup") and g or nil
end
local function play(a, kind, isMine)
	local set = SOUNDS[a.id]
	local list = set and set[kind]
	local part = a.model and a.model.PrimaryPart
	if not list or not part or not part.Parent then return end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - part.Position).Magnitude > (isMine and 80 or 55) then return end
	local def = list[math.random(1, #list)]
	local snd = Instance.new("Sound")
	snd.Name = "PetSound"; snd.SoundId = "rbxassetid://" .. def[1]
	snd.RollOffMode = Enum.RollOffMode.InverseTapered; snd.RollOffMinDistance = 5; snd.RollOffMaxDistance = 48
	snd.SoundGroup = sfxGroup()
	snd.Volume = def[2] * (isMine and 1 or 0.75)
	snd.PlaybackSpeed = def[3] * (set.pitch or 1) * (0.93 + math.random() * 0.14)
	-- take the harsh top off so they sit under the game's own sounds
	local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = -5; eq.MidGain = -1; eq.LowGain = 0; eq.Parent = snd
	snd.Parent = part
	snd:Play()
	local len = def[4]
	task.spawn(function()
		if len then
			task.wait(len)
			if snd.Parent and snd.IsPlaying then for _ = 1, 8 do snd.Volume *= 0.7; task.wait(0.025) end end
		else
			local t0 = os.clock()
			while snd.Parent and snd.IsPlaying and os.clock() - t0 < 6 do task.wait(0.2) end
		end
		snd:Destroy()
	end)
end

-- ---------------------------------------------------------------- following
local function approach(cur, goal, rate, dt) return cur + (goal - cur) * (1 - math.exp(-rate * dt)) end

local t0 = os.clock()
Run.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local now = os.clock()
	local t = now - t0
	local me = Players.LocalPlayer
	local exclude = {folder}
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then exclude[#exclude + 1] = p.Character end end
	rayParams.FilterDescendantsInstances = exclude
	for _, p in ipairs(Players:GetPlayers()) do
		local id, char, root, hum = owner(p)
		local a = active[p]
		if not id then clear(p); continue end
		local alive = root ~= nil and hum ~= nil and hum.Health > 0
		local mine = p == me
		local style = p:GetAttribute("NumberStyle")
		local cw = p:GetAttribute("PetColor")
		if not a or a.id ~= id or a.cw ~= cw or (id == "PetDrone" and a.style ~= style) then
			if not a and not alive then continue end -- nowhere to put it yet
			local keep, deadAt = a and a.cf, a and a.deadAt
			clear(p)
			local m = Pets.Build(id, p, cw)
			if not m then continue end
			m.Parent = folder
			a = {model = m, id = id, style = style, cw = cw, phase = math.random() * 6,
				cf = keep or root.CFrame * CFrame.new(2.4, 0, 2), sit = 0, lie = 0, dead = 0, stillFor = 0,
				nextFidget = now + math.random(2, 5), nextIdle = now + math.random(12, 26), greet = mine, deadAt = deadAt, pose = {}}
			if deadAt then Pets.SetDim(m, true) end
			active[p] = a
		end
		local model = a.model
		if not model or not model.PrimaryPart then continue end
		local ground = Pets.Ground(id)

		-- what the owner is doing
		local ownerSpeed, crouch = 0, false
		if alive then
			local v = root.AssemblyLinearVelocity
			ownerSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
			crouch = char:GetAttribute("Crouching") == true or hum.Sit
			local hop = a.lastRoot and (root.Position - a.lastRoot).Magnitude or 0
			a.lastRoot = root.Position
			if ownerSpeed < 1.5 and math.abs(v.Y) < 3 and hop < 0.3 then a.stillFor += dt else a.stillFor = 0 end
		else
			a.stillFor = 0
		end

		-- moods
		local wantDead = alive and 0 or 1
		local wantLie = (alive and (crouch or a.stillFor > NAP_AFTER)) and 1 or 0
		local wantSit = (alive and wantLie == 0 and a.stillFor > SIT_AFTER) and 1 or 0
		a.dead = approach(a.dead, wantDead, wantDead > a.dead and 4 or 6, dt)
		a.lie = approach(a.lie, wantLie, wantLie > a.lie and (crouch and 6 or 2) or 7, dt)
		a.sit = approach(a.sit, wantSit, wantSit > a.sit and 2.5 or 7, dt)

		-- moments (sounds and dimming)
		if not alive and not a.deadAt then
			a.deadAt = a.cf.Position
			a.fidget = nil
			task.delay(0.5, function() if active[p] == a then play(a, "sad", mine) end end)
			task.delay(0.35, function() if active[p] == a and a.deadAt then Pets.SetDim(model, true) end end)
		elseif alive and a.deadAt then
			a.deadAt = nil
			Pets.SetDim(model, false)
			a.greet = true
		end
		if a.greet and alive then
			a.greet = false
			task.delay(0.6, function() if active[p] == a then play(a, "greet", mine) end end)
		end
		if a.lie > 0.85 and not a.restSaid then
			a.restSaid = true
			task.delay(1.2, function() if active[p] == a and a.lie > 0.8 then play(a, "rest", mine) end end)
		elseif a.lie < 0.2 then
			a.restSaid = false
		end
		if not ground then
			if a.lie > 0.6 then a.landed = true
			elseif a.landed and a.lie < 0.4 then a.landed = false; play(a, "flap", mine) end
		end
		if alive and now >= a.nextIdle then
			a.nextIdle = now + math.random(16, 34)
			if a.lie < 0.5 then play(a, "idle", mine) end
		end

		-- fidgets while the owner stands about
		if a.fidget then
			a.fp = (now - a.fidgetAt) / Pets.FIDGET_TIME
			if a.fp >= 1 then a.fidget = nil; a.fp = 0 end
		elseif alive and a.stillFor > 1.2 and a.sit < 0.15 and a.lie < 0.15 and now >= a.nextFidget then
			local list = Pets.Fidgets(id)
			a.fidget = list[math.random(1, #list)]
			a.fidgetAt, a.fp = now, 0
			a.nextFidget = now + math.random(3, 6)
		end

		-- where to be: beside and a little behind the owner's right shoulder (or where it was, when they're down)
		local flat = a.flat or Vector3.new(0, 0, -1)
		if alive then
			local look = root.CFrame.LookVector
			local f = Vector3.new(look.X, 0, look.Z)
			if f.Magnitude > 0.01 then flat = f.Unit end
		end
		a.flat = flat
		local spot
		if a.deadAt then spot = a.deadAt
		else spot = root.Position + CFrame.lookAt(Vector3.zero, flat):VectorToWorldSpace(Vector3.new(2.3, 0, 1.6)) end
		local refY = alive and root.Position.Y or spot.Y
		local hit = workspace:Raycast(Vector3.new(spot.X, refY + 3, spot.Z), Vector3.new(0, -14, 0), rayParams)
		local gy = hit and hit.Position.Y or (refY - 3)
		local y
		if ground then
			y = gy
		else
			local bottom = model:GetAttribute("Bottom") or 0.3
			local settled = math.max(a.sit, a.lie)
			y = (alive and root.Position.Y or gy + 3) + 1.4 + math.sin(t * 2.2 + a.phase) * 0.25 * (1 - settled)
			y += ((gy + bottom + 0.55) - y) * a.sit
			y += ((gy + bottom + 0.02) - y) * a.lie
			y += ((gy + (model:GetAttribute("HalfW") or 0.3)) - y) * a.dead
		end
		local goal = Vector3.new(spot.X, y, spot.Z)
		local cur = a.cf.Position
		-- catch up straight away when far behind (teleports, respawns)
		if (goal - cur).Magnitude > 40 then cur = goal end
		local k = 1 - math.exp(-(ground and 10 or 6) * dt)
		local pos = cur:Lerp(goal, k)
		local moved = pos - cur
		local flatMove = Vector3.new(moved.X, 0, moved.Z)
		local speed = flatMove.Magnitude / math.max(dt, 1e-3)
		-- face where it's going, or the owner's way when idle (a pet playing dead stays put)
		local rot = a.cf.Rotation
		if a.dead < 0.5 then
			local face = flatMove.Magnitude > 0.02 and flatMove.Unit or flat
			rot = rot:Lerp(CFrame.lookAt(Vector3.zero, face).Rotation, 1 - math.exp(-8 * dt))
		end
		a.cf = CFrame.new(pos) * rot
		local shown = a.cf
		if not ground then shown = shown * CFrame.Angles(0, 0, math.sin(t * 1.3 + a.phase) * 0.08 * (1 - math.max(a.lie, a.dead))) end
		model.PrimaryPart.CFrame = shown
		local pose = a.pose
		pose.sit, pose.lie, pose.dead = a.sit, a.lie, a.dead
		pose.fidget, pose.fp = a.fidget, a.fp
		pose.sleep = a.stillFor > NAP_AFTER + 2 or (crouch and a.stillFor > 6)
		Pets.Animate(model, t + a.phase, speed, pose)
	end
end)
