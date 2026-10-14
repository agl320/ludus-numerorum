-- (typing anywhere -- a text box, or the Roblox chat bar, which GetFocusedTextBox doesn't report -- means no hotkeys)
local function chatTyping()
	if game:GetService("UserInputService"):GetFocusedTextBox() then return true end
	local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatInputBarConfiguration")
	local ok, focused = pcall(function() return cfg and cfg.IsFocused end)
	return ok and focused == true
end
-- Evade-style movement, simulated on the owning client right before each physics step.
--  * Ground: Quake/Source acceleration + friction (snappy starts, crisp stops, momentum above top speed fades slowly)
--  * Slopes: velocity follows the floor plane, so you run up and down ramps/stairs at full speed
--  * Air: Source air-strafing (A/D + mouse gains speed) plus speed-preserving steering when holding forward
--  * Jumps: buffered + coyote time, hold to auto-hop; landing grace keeps hop momentum; one small double jump
--  * Slide: hold the slide key; gravity speeds you up downhill, slide-jumps add speed, ramps launch you (trimp)
--  * Crouch (hold Ctrl): slow, low walk; Dash (Q): short burst in the direction you're holding (one in the air)
--  * Wall jump: jump while touching a wall in the air (up to 3 per jump, not twice off the same wall in a row)
--  * Wall hang: dash into a wall (tall enough to hold) and you cling to it like a spider. While hanging: Q dashes
--    along the wall (left / right by your keys, else where the camera looks) and you stay on it, A / D shimmy, jump
--    kicks you off (or pulls you up onto a ledge in reach when you're pushing into the wall), Ctrl / the slide key
--    lets go. Hanging is a rest (stamina refills); after a moment you start to slip down. Up to 3 hangs per air time.
--    Q while looking away from the wall launches you across the gap: reach another wall and you catch it
--    (building to building; chained catches are free, only stamina limits them).
--  * Wall bounce: dash into a low wall (nothing to hold on to) and you rebound off it with a kick upward
--  * Stamina: sprinting, dashes, wall jumps, double jumps, climbing, wall dashes / launches and mantling use it; it refills when you rest (or hang on a wall).
--    Run dry and you can't sprint, dash or climb until it is back to 25% (player attribute Stamina, 0..1).
--  * Mantle: running or jumping into a ledge you can reach (up to ~6.8 studs above your feet, ~8.6 while climbing a wall,
--    ladder or truss) pulls you up onto it
--  * Wall climb: in the air, hold forward into a wall to run up it for a moment (once per jump), then mantle the top
-- The server only mirrors slide/sprint/air-jump state for other players' animations (MovementService).
local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Parkour = {}
Parkour.__index = Parkour

local UP = Vector3.yAxis
local function flatten(v) return Vector3.new(v.X, 0, v.Z) end
-- rotate a horizontal vector toward `dir` by at most `maxAngle` radians, keeping its length
local function turnToward(vec, dir, maxAngle)
	local speed = vec.Magnitude
	if speed < 1e-3 or maxAngle <= 0 then return vec end
	local cur = vec / speed
	local dot = math.clamp(cur:Dot(dir), -1, 1)
	local angle = math.acos(dot)
	if angle < 1e-4 then return vec end
	local sign = cur:Cross(dir).Y >= 0 and 1 or -1
	local step = math.min(maxAngle, angle) * sign
	return CFrame.fromAxisAngle(UP, step):VectorToWorldSpace(cur) * speed
end
-- vertical speed that keeps a horizontal velocity glued to a floor with normal n
local function alongFloor(flat, n)
	if n.Y >= 0.999 then return 0 end
	return -(n.X * flat.X + n.Z * flat.Z) / math.max(n.Y, 0.35)
end
local BLOCKING_STATES = {
	[Enum.HumanoidStateType.Seated] = true, [Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true, [Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true, [Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Ragdoll] = true, [Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
}

function Parkour.new(player, config, settings, feel)
	local self = setmetatable({player = player, config = config, cfg = config.Movement, settings = settings, feel = feel,
		listeners = {}}, Parkour)
	self:Reset()
	feel.parkour = self
	UIS.JumpRequest:Connect(function()
		if not self:Blocked() and not self.jumpHeld then self.jumpPressedAt = os.clock() end
		self.requestAt = os.clock()
	end)
	Run.PreSimulation:Connect(function(dt) self:Step(math.min(dt, 1/20)) end)
	-- alt-tab / clicking out of the window: Roblox never sees the key-up for keys held at that moment, so the
	-- character kept walking (or got stuck sprinting/crouching). While unfocused, all input is treated as released.
	UIS.WindowFocusReleased:Connect(function()
		self.unfocused = true
		self.crouchHeld = false
		self.crouchCancelled = false
		self.dashQueuedAt, self.slideQueuedAt, self.jumpPressedAt = -math.huge, -math.huge, -math.huge
		if self.feel and self.feel.sprint then self.feel:SetSprint(false) end
	end)
	UIS.WindowFocused:Connect(function() self.unfocused = false end)
	-- (the focused event can go missing -- Studio's Alt menu, some alt-tabs -- which left you unable to move: any key
	-- press or click means the window is ours again)
	UIS.InputBegan:Connect(function(i)
		if not self.unfocused then return end
		local t = i.UserInputType
		if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 then
			self.unfocused = false
		end
	end)
	return self
end

-- Movement events for camera feel, viewmodel and sounds: "Jump", "AirJump", "Land", "SlideStart", "SlideEnd"
function Parkour:On(callback) table.insert(self.listeners, callback) end
function Parkour:Emit(name, data)
	for _, callback in ipairs(self.listeners) do task.spawn(callback, name, data) end
end

function Parkour:Reset()
	-- (a hang cut short by a respawn / leaving the round mustn't leave the clinging flags on the body)
	local old = self.character
	if self.hang and old and old.Parent then
		old:SetAttribute("WallHang", false); old:SetAttribute("Climbing", false)
		self.feel.remote:FireServer("Hang", false)
	end
	self.character, self.humanoid, self.root = nil, nil, nil
	self.sliding, self.slideHoldMode = false, false
	self.slideStart, self.lastSlideEnd = -math.huge, -math.huge
	self.boostReadyAt, self.slideJumpReadyAt = 0, 0
	self.slideQueuedAt = -math.huge
	self.jumpPressedAt, self.jumpedAt, self.airJumpedAt = -math.huge, -math.huge, -math.huge
	self.lastGround, self.landedAt = -math.huge, -math.huge
	self.grounded, self.jumpHeld = false, false
	self.airJumps = 0
	self.normal = UP
	self.speed = 0
	self.lastFlat, self.prevAirVY = nil, nil
	self.crouching = false
	self.dashUntil, self.dashReadyAt, self.dashQueuedAt = -math.huge, 0, -math.huge
	self.airDashUsed = false
	self.wallJumps, self.lastWallJumpAt, self.lastWallNormal = 0, -math.huge, nil
	self.stamina, self.exhausted, self.staminaUsedAt = 1, false, -math.huge
	self.mantle, self.climb, self.climbUsed = nil, nil, false
	self.climbEndedAt = -math.huge
	self.hang, self.hangsUsed, self.launch = nil, 0, nil
	self.player:SetAttribute("Stamina", 1)
end

-- ===== stamina =====
local STAMINA = {SprintDrain = 0.15, Regen = 0.3, RegenDelay = 0.8, Dash = 0.2, WallJump = 0.1, AirJump = 0.12,
	ClimbDrain = 0.14, Mantle = 0.04, Recover = 0.25, WallDash = 0.06, WallLaunch = 0.08, HangRefund = 0.1}
-- (wall movement is meant to chain building to building: holding a wall is a rest -- stamina refills while you
-- hang -- a dash that ends in a hang gives half its cost back, and a launch that lands on the next wall is free)
Parkour.Stamina = STAMINA
function Parkour:Spend(amount)
	-- the lobby (not in a round's arena) has unlimited stamina
	if self.player:GetAttribute("InArena") ~= true then self.stamina, self.exhausted = 1, false; return end
	self.stamina = math.max(0, self.stamina - amount)
	self.staminaUsedAt = os.clock()
	if self.stamina <= 0 then self.exhausted = true end
end
function Parkour:HasStamina(amount) return not self.exhausted and self.stamina >= (amount or 0.01) end

-- ===== ledges =====
-- A ledge in front (direction `dir`, flat unit vector) the character can pull up onto, or nil.
-- `reach`: how high above the feet the top can be (higher while climbing: your hands are already up there).
function Parkour:FindLedge(h, root, dir, reach)
	reach = reach or 6.8
	local feet = root.Position.Y - (h.HipHeight + root.Size.Y / 2)
	local wall
	for _, up in ipairs({1.0, 2.6, 4.2, 5.8}) do
		local origin = Vector3.new(root.Position.X, feet + up, root.Position.Z)
		local hit = workspace:Raycast(origin, dir * 2.4, self.params)
		if hit and math.abs(hit.Normal.Y) < 0.4 then wall = hit; break end
	end
	if not wall then return nil end
	local n = flatten(wall.Normal)
	if n.Magnitude < 0.1 then return nil end
	n = n.Unit
	-- look down just past the edge (two depths, so thin walls and railings work too)
	local top, height
	for _, depth in ipairs({0.8, 0.45, 1.4}) do
		local probe = wall.Position - n * depth
		local hit = workspace:Raycast(Vector3.new(probe.X, feet + reach + 0.8, probe.Z), Vector3.new(0, -(reach + 0.8), 0), self.params)
		if hit and hit.Normal.Y >= 0.7 then
			local hgt = hit.Position.Y - feet
			if hgt >= 1.6 and hgt <= reach then top, height = hit, hgt; break end
		end
	end
	if not top then return nil end
	-- room to stand on top, and nothing overhead on the way up
	if workspace:Raycast(top.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, 4.6, 0), self.params) then return nil end
	local headroom = workspace:Raycast(root.Position, Vector3.new(0, math.max(0, top.Position.Y - root.Position.Y) + 3, 0), self.params)
	if headroom then return nil end
	return {top = top.Position, height = height, normal = n, wall = wall}
end

function Parkour:StartMantle(h, root, ledge, speed)
	local rise = h.HipHeight + root.Size.Y / 2 + 0.08
	local target = ledge.top + Vector3.new(0, rise, 0) - ledge.normal * 0.9
	local duration = 0.2 + math.clamp(ledge.height, 0, 8.6) * 0.035
	if self.sliding then self:EndSlide() end
	self.mantle = {from = root.Position, to = target, t = 0, duration = duration, look = -ledge.normal,
		exit = math.max(10, math.min(speed or 0, 22))}
	self.climb = nil
	self:Spend(STAMINA.Mantle)
	self.character:SetAttribute("MantleAt", workspace:GetServerTimeNow())
	self.feel.remote:FireServer("WallJump") -- reuse the mirrored kick so others hear / see the effort
	self.feel:Punch(0.14)
	self:Emit("Mantle", {height = ledge.height})
end

-- moves the body along the mantle path; returns true while mantling
function Parkour:MantleStep(h, root, dt)
	local m = self.mantle
	if not m then return false end
	m.t += dt
	local k = math.clamp(m.t / m.duration, 0, 1)
	-- up first, then over the edge
	local upK = math.clamp(k / 0.6, 0, 1); upK = 1 - (1 - upK) ^ 2
	local overK = math.clamp((k - 0.45) / 0.55, 0, 1); overK = overK * overK * (3 - 2 * overK)
	local pos = Vector3.new(m.from.X + (m.to.X - m.from.X) * overK, m.from.Y + (m.to.Y - m.from.Y) * upK, m.from.Z + (m.to.Z - m.from.Z) * overK)
	local look = root.CFrame.LookVector:Lerp(m.look, math.min(1, dt * 14))
	look = flatten(look); if look.Magnitude < 0.01 then look = m.look end
	root.CFrame = CFrame.lookAt(pos, pos + look.Unit)
	root.AssemblyLinearVelocity = Vector3.zero
	h:ChangeState(Enum.HumanoidStateType.Freefall)
	if k >= 1 then
		self.mantle = nil
		local exit = m.look * m.exit
		root.AssemblyLinearVelocity = Vector3.new(exit.X, 2, exit.Z)
		self.lastFlat, self.prevAirVY = exit, nil
		self.jumpedAt = os.clock() - 1
		self:Emit("Land", {fall = 0, speed = m.exit})
	end
	return true
end

function Parkour:RequestDash() if self:HasStamina(STAMINA.Dash) then self.dashQueuedAt = os.clock() elseif self.feel then self.feel:Punch(0.05) end end
function Parkour:SetCrouch(on)
	self.crouchHeld = on == true
	-- (letting go of the key clears a cancelled crouch, so the next press crouches again)
	if not self.crouchHeld then self.crouchCancelled = false end
end
-- Crouching is its own move: jumping, dashing, sliding, sprinting, mantling or climbing ends it (no crouch-jumps,
-- no crouched dashes). Still holding the key, you crouch again as soon as you're back on the ground after the move
-- (it used to need a fresh press). Only sprinting (`latch`) keeps it off until the key is pressed again.
function Parkour:CancelCrouch(latch)
	if latch and self.crouchHeld then self.crouchCancelled = true end
	if self.crouching then
		self.crouching = false
		local char = self.character
		if char and char.Parent then char:SetAttribute("Crouching", false) end
		self.feel.remote:FireServer("Crouch", false)
	end
end

-- nearest wall (steep surface) within `dist` around the body, checked in 8 directions at waist height
function Parkour:FindWall(root, dist)
	local best, bestDistance = nil, math.huge
	for i = 0, 7 do
		local a = i * math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local hit = workspace:Raycast(root.Position, dir * dist, self.params)
		if hit and math.abs(hit.Normal.Y) < 0.35 and hit.Distance < bestDistance then best, bestDistance = hit, hit.Distance end
	end
	return best
end

function Parkour:Blocked()
	local s = self.settings
	-- (number entry, the players list and Help are overlays: you keep moving with them up)
	return (s.open and s.active ~= "Entry" and s.active ~= "Leaderboard" and s.active ~= "Help") or chatTyping()
end

function Parkour:SlideKeyDown()
	-- a gamepad's B held down counts as the slide key (PadControls sets padSlideHeld)
	if self.padSlideHeld then return true end
	local ok, code = pcall(function() return Enum.KeyCode[self.settings.values.SlideKey] end)
	return ok and code ~= nil and not chatTyping() and UIS:IsKeyDown(code)
end

-- Called by FeelController:Slide() (keyboard key, gamepad B or the touch SLIDE button).
function Parkour:RequestSlide()
	self.slideQueuedAt = os.clock()
	-- keyboard / gamepad: slide while held; touch: slide until it runs out of speed (or you jump)
	self.slideHoldMode = self:SlideKeyDown()
end

function Parkour:MaxSpeed()
	if self.crouching then return self.config.WalkSpeed * (self.cfg.CrouchSpeedScale or 0.5) end
	return (self.feel.sprint and not self.exhausted) and self.cfg.SprintSpeed or self.config.WalkSpeed
end

function Parkour:StartSlide(flat, now, holdMode)
	local cfg = self.cfg
	local dir = flat.Magnitude > 0.1 and flat.Unit or flatten(self.root.CFrame.LookVector).Unit
	local boosted = now >= self.boostReadyAt
	if boosted then
		flat += dir * cfg.SlideBoost
		self.boostReadyAt = now + cfg.SlideCooldown
	end
	self:CancelCrouch()
	self.sliding, self.slideStart, self.slideHoldMode = true, now, holdMode
	local char = self.character
	char:SetAttribute("SlideUntil", workspace:GetServerTimeNow() + 3600)
	char:SetAttribute("SlideDirection", dir)
	self.feel.remote:FireServer("Slide", true, dir)
	if self.feel.sound then self.feel.sound:Play("Slide") end
	self.feel:Punch(0.22)
	self:Emit("SlideStart", {boosted = boosted})
	return flat
end

function Parkour:EndSlide()
	if not self.sliding then return end
	self.sliding = false
	self.lastSlideEnd = os.clock()
	local char = self.character
	if char and char.Parent then char:SetAttribute("SlideUntil", 0) end
	self.feel.remote:FireServer("Slide", false)
	self:Emit("SlideEnd")
end

function Parkour:GroundStep(flat, wish, dt, now)
	local cfg = self.cfg
	local maxSpeed = self:MaxSpeed()
	local speed = flat.Magnitude
	-- friction (skipped for a moment after landing so hops keep their speed)
	if speed > 1e-3 and now - self.landedAt > cfg.LandGrace then
		local friction = (speed > maxSpeed + 0.5 and wish.Magnitude > 0.01) and cfg.OverspeedFriction or cfg.Friction
		local drop = math.max(speed, cfg.StopSpeed) * friction * dt
		flat *= math.max(speed - drop, 0) / speed
	end
	if wish.Magnitude > 0.01 then
		local dir = wish.Unit
		local wishSpeed = maxSpeed * wish.Magnitude
		local add = wishSpeed - flat:Dot(dir)
		if add > 0 then flat += dir * math.min(cfg.GroundAccel * wishSpeed * dt, add) end
	end
	return flat
end

function Parkour:AirStep(flat, wish, dt)
	local cfg = self.cfg
	if wish.Magnitude < 0.01 then return flat end
	local dir = wish.Unit
	local maxSpeed = self:MaxSpeed()
	-- Source air acceleration: only a small wish speed, so holding a strafe key while turning gains speed
	local wishSpeed = math.min(maxSpeed * wish.Magnitude, cfg.AirWishCap)
	local add = wishSpeed - flat:Dot(dir)
	if add > 0 then flat += dir * math.min(cfg.AirAccel * maxSpeed * dt, add) end
	-- steering: bend the current velocity toward the input direction without losing speed
	local speed = flat.Magnitude
	if speed > 1 then
		local dot = (flat / speed):Dot(dir)
		local strength = math.clamp((dot + 0.35) / 1.35, 0, 1)
		flat = turnToward(flat, dir, cfg.AirTurn * strength * dt)
	elseif add > 0 then
		flat += dir * math.min(cfg.AirAccel * dt * 4, maxSpeed * 0.5)
	end
	return flat
end

function Parkour:SlideStep(flat, wish, dt, now)
	local cfg = self.cfg
	local n = self.normal
	-- gravity along the floor: downhill speeds you up, uphill slows you down
	local g = workspace.Gravity * cfg.SlideGravity
	flat += Vector3.new(n.X * n.Y, 0, n.Z * n.Y) * g * dt
	local speed = flat.Magnitude
	if speed > 1e-3 then flat *= math.max(speed - cfg.SlideFriction * dt, 0) / speed end
	if wish.Magnitude > 0.01 then flat = turnToward(flat, wish.Unit, cfg.SlideSteer * dt) end
	local elapsed = now - self.slideStart
	local downhill = (n.X * flat.X + n.Z * flat.Z) > 0.5
	if elapsed > cfg.SlideMinTime then
		if flat.Magnitude < cfg.SlideEndSpeed then self:EndSlide()
		elseif self.slideHoldMode and not self:SlideKeyDown() then self:EndSlide()
		elseif not self.slideHoldMode and elapsed > cfg.SlideTouchTime and not downhill then self:EndSlide() end
	end
	if self.sliding and flat.Magnitude > 0.5 then self.character:SetAttribute("SlideDirection", flat.Unit) end
	return flat
end

-- Floor under the feet, plus a look-ahead so a ramp you're running onto is climbed instead of hit
function Parkour:FloorNormal(h, root, flat)
	local depth = h.HipHeight + root.Size.Y / 2 + 2.2
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -depth, 0), self.params)
	local n = hit and hit.Normal or UP
	if flat.Magnitude > 1 then
		local origin = root.Position + flat.Unit * 1.6 + Vector3.new(0, 1.5, 0)
		local ahead = workspace:Raycast(origin, Vector3.new(0, -(depth + 1.5), 0), self.params)
		if ahead and ahead.Normal.Y > 0.4 and ahead.Normal.Y < 0.999 and alongFloor(flat, ahead.Normal) > alongFloor(flat, n) then
			n = ahead.Normal
		end
	end
	return n
end

function Parkour:Jump(h, root, flat, v, now, air)
	local cfg = self.cfg
	local speed = flat.Magnitude
	if speed > cfg.MaxSpeed then flat *= cfg.MaxSpeed / speed; speed = cfg.MaxSpeed end
	local vy
	if air then
		-- a real second jump: full power from the top of the arc, and still a proper boost when pressed on the way up
		-- (it used to just reset your upward speed to about a normal jump's, so an early press added almost nothing)
		vy = math.min(cfg.AirJumpPower + math.max(0, v.Y) * 0.45, cfg.AirJumpPower * 1.3)
		self:Spend(STAMINA.AirJump)
		self.airJumps += 1
		self.airJumpedAt = now
		self.character:SetAttribute("AirJumpAt", workspace:GetServerTimeNow())
		self.feel.remote:FireServer("AirJump")
		self:Emit("AirJump", {speed = speed})
	else
		-- hopping keeps your momentum, but each hop sheds a third of any speed above running pace (from a slide,
		-- dash or wall bounce): holding jump used to keep that boost forever, so hopping beat running
		local run = self:MaxSpeed()
		if speed > run + 0.5 then
			local s2 = run + (speed - run) * 0.65
			flat *= s2 / speed
			speed = s2
		end
		-- running up a slope carries some of the climb into the jump
		local climb = self.grounded and math.max(0, alongFloor(flat, self.normal)) or 0
		vy = h.JumpPower + math.min(climb * 0.6, 18)
		self:Emit("Jump", {speed = speed})
	end
	self.jumpedAt, self.grounded = now, false
	self.airJumpArmed = false
	self.prevAirVY = vy
	-- the built-in Jumping state is disabled (it would add its own JumpPower); go straight to freefall
	h:ChangeState(Enum.HumanoidStateType.Freefall)
	h.WalkSpeed = speed
	h:Move(speed > 0.05 and flat.Unit or Vector3.zero, false)
	root.AssemblyLinearVelocity = Vector3.new(flat.X, vy, flat.Z)
	self.lastFlat = flat
end

-- ===== wall hang =====
local WALL_DASH_SPEED, WALL_DASH_TIME, WALL_DASH_GAP = 54, 0.2, 0.32
local SHIMMY_SPEED, SLIP_AFTER = 9, 1.8
-- wall launch: from a hang, Q while looking away from the wall fires you across the gap; you catch the next wall
-- you reach on your own (building to building). Powered for LAUNCH_TIME, then it coasts and can still catch for
-- LAUNCH_CATCH more seconds.
local LAUNCH_SPEED, LAUNCH_TIME, LAUNCH_CATCH = 82, 0.5, 0.75
function Parkour:WallLaunch(h, root, now, look, n)
	local flat = flatten(look)
	flat = flat.Magnitude > 0.1 and flat.Unit or n
	-- mostly level, aimed a little by the camera: a dash across the gap, not a jump
	local up = math.clamp(look.Y, -0.3, 0.5)
	self:EndHang()
	self:Spend(STAMINA.WallLaunch)
	self.launch = {dir = flat, up = up, powerUntil = now + LAUNCH_TIME, catchUntil = now + LAUNCH_TIME + LAUNCH_CATCH, from = n}
	self.dashReadyAt = now + 0.2
	self.airDashUsed = false
	self.jumpedAt, self.grounded = now, false
	self.dashUntil = -math.huge
	local char = self.character
	local t = workspace:GetServerTimeNow()
	char:SetAttribute("DashAt", t)
	char:SetAttribute("WallLaunchAt", t)
	self.feel.remote:FireServer("Dash")
	self.feel.remote:FireServer("WallLaunch")
	self.feel:Punch(0.32)
	self:Emit("WallLaunch", {dir = flat})
end
-- one physics step of a wall launch; returns true when it handled the body
function Parkour:LaunchStep(h, root, now, dt, grounded, blocked)
	local L = self.launch
	if blocked or grounded or now > L.catchUntil then self.launch = nil; return false end
	-- reached a wall: catch it (chained catches across buildings don't use up your hangs)
	local v = root.AssemblyLinearVelocity
	local flatV = flatten(v)
	local dir = flatV.Magnitude > 4 and flatV.Unit or L.dir
	local hit = workspace:Raycast(root.Position, dir * 3.4, self.params)
	if hit and math.abs(hit.Normal.Y) < 0.35 and flatten(hit.Normal).Magnitude > 0.1 and flatten(hit.Normal).Unit:Dot(dir) < -0.3
		and self:HasStamina(0.03) then
		self.launch = nil
		self.hangsUsed = math.max(0, self.hangsUsed - 1)
		if self:StartHang(h, root, hit, now, false) then
			self.stamina = math.min(1, self.stamina + STAMINA.WallLaunch) -- a landed launch is free
			self.character:SetAttribute("WallCatchAt", workspace:GetServerTimeNow())
			self.feel.remote:FireServer("WallCatch")
			self.feel:Punch(0.3)
			return true
		end
	end
	if now < L.powerUntil then
		-- powered: straight along the aim, gravity cancelled
		local vel = L.dir * LAUNCH_SPEED + Vector3.new(0, L.up * LAUNCH_SPEED * 0.45 + workspace.Gravity * dt * 0.5, 0)
		h:ChangeState(Enum.HumanoidStateType.Freefall)
		h.WalkSpeed = LAUNCH_SPEED
		h:Move(L.dir, false)
		root.AssemblyLinearVelocity = vel
		self.lastFlat, self.prevAirVY = flatten(vel), vel.Y
		self.jumpedAt = now - 0.13
		return true
	end
	-- out of power: glide on with a good part of the speed in a floaty arc (about a third of gravity), steerable a little with
	-- the movement keys, still catching any wall you reach
	local vy
	if not L.released then
		L.released = true
		L.glide = L.dir * LAUNCH_SPEED * 0.62
		vy = math.max(v.Y * 0.3, 4)
	else
		vy = v.Y + workspace.Gravity * dt * 0.68
	end
	local wishDir = flatten(h.MoveDirection)
	if wishDir.Magnitude > 0.1 then L.glide = turnToward(L.glide, wishDir.Unit, 1.6 * dt) end
	h:ChangeState(Enum.HumanoidStateType.Freefall)
	h.WalkSpeed = L.glide.Magnitude
	h:Move(L.glide.Unit, false)
	root.AssemblyLinearVelocity = Vector3.new(L.glide.X, vy, L.glide.Z)
	self.lastFlat, self.prevAirVY = L.glide, vy
	return true
end
function Parkour:StartHang(h, root, hit, now, grounded)
	local n = flatten(hit.Normal)
	if n.Magnitude < 0.1 then return false end
	n = n.Unit
	self.dashUntil = -math.huge
	self.launch = nil
	if self.sliding then self:EndSlide() end
	self:CancelCrouch()
	self.climb = nil
	-- flat against the wall, facing it (lifted off the ground if you dashed in from it)
	local at = hit.Position + n * 1.25
	local y = root.Position.Y + (grounded and 3 or 0)
	local pos = Vector3.new(at.X, y, at.Z)
	-- (y: the height the hands hold at; it only drops once you start to slip)
	self.hang = {normal = n, since = now, dashUntil = -math.huge, dashReadyAt = now + 0.15, pingAt = 0, y = y}
	self.hangsUsed += 1
	self.airDashUsed = false
	self.dashQueuedAt = -math.huge
	root.CFrame = CFrame.lookAt(pos, pos - n)
	root.AssemblyLinearVelocity = Vector3.zero
	h:ChangeState(Enum.HumanoidStateType.Freefall)
	self.jumpedAt, self.grounded = now, false
	self.lastFlat, self.prevAirVY = Vector3.zero, 0
	local char = self.character
	char:SetAttribute("WallHang", true)
	self.feel.remote:FireServer("Hang", true) -- mirrored (Hanging), so others see the wall-hang pose
	self.feel:Punch(0.18)
	self:Emit("WallHang", {normal = n})
	return true
end
function Parkour:EndHang()
	if not self.hang then return end
	self.hang = nil
	self.dashReadyAt = math.max(self.dashReadyAt, os.clock() + 0.3)
	local char = self.character
	if char and char.Parent then char:SetAttribute("WallHang", false) end
	self.feel.remote:FireServer("Hang", false)
end
-- one physics step while hanging; returns true when it handled the body
function Parkour:HangStep(h, root, now, dt, wish, grounded, blocked)
	local hang, cfg, char = self.hang, self.cfg, self.character
	local n = hang.normal
	local function letGo(vel)
		self:EndHang()
		if vel then
			root.AssemblyLinearVelocity = vel
			self.lastFlat, self.prevAirVY = flatten(vel), vel.Y
		end
	end
	if blocked or (grounded and now - hang.since > 0.2) then letGo(); return false end
	-- jump: pushing into the wall with a ledge in reach pulls you up onto it; otherwise kick off the wall
	if now - self.jumpPressedAt <= 0.15 then
		self.jumpPressedAt = -math.huge
		if wish.Magnitude > 0.3 and wish.Unit:Dot(-n) > 0.5 then
			local ledge = self:FindLedge(h, root, -n, 8.6)
			if ledge then letGo(); self:StartMantle(h, root, ledge, 4); return true end
		end
		letGo()
		local out = n * (cfg.WallJumpPush or 26)
		if wish.Magnitude > 0.1 then out += wish.Unit * 8 end
		local vy = cfg.WallJumpPower or 42
		self:Spend(STAMINA.WallJump)
		self.lastWallJumpAt, self.lastWallNormal = now, n
		self.jumpedAt, self.grounded = now, false
		self.airJumpArmed = false
		h:ChangeState(Enum.HumanoidStateType.Freefall)
		h.WalkSpeed = out.Magnitude
		h:Move(out.Unit, false)
		root.AssemblyLinearVelocity = Vector3.new(out.X, vy, out.Z)
		self.lastFlat, self.prevAirVY = out, vy
		char:SetAttribute("WallJumpAt", workspace:GetServerTimeNow())
		self.feel.remote:FireServer("WallJump")
		self.feel:Punch(0.16)
		self:Emit("WallJump", {normal = n})
		return true
	end
	-- let go: crouch or the slide key. (Not by "pulling away": the movement keys follow the camera, so turning round to
	-- aim a launch while still holding W dropped you off the wall.)
	if self.crouchHeld or self:SlideKeyDown() then
		letGo(n * 6 + Vector3.new(0, -2, 0))
		return true
	end
	if self.exhausted then letGo(n * 4); return true end
	-- facing the wall: "right" along it
	local right = (-n):Cross(UP)
	right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
	-- Q: dash along the wall, staying on it -- or, looking away from the wall, launch across to the next building
	if now - self.dashQueuedAt <= 0.15 and now >= hang.dashReadyAt and self:HasStamina(STAMINA.WallDash) then
		self.dashQueuedAt = -math.huge
		local cam = workspace.CurrentCamera
		local camLook = cam and cam.CFrame.LookVector or -n
		local flatLook = flatten(camLook)
		if flatLook.Magnitude > 0.1 and flatLook.Unit:Dot(n) > 0.3 and math.abs(wish:Dot(right)) < 0.6 then
			self:WallLaunch(h, root, now, camLook, n)
			return true
		end
		local along = wish:Dot(right)
		local side
		if math.abs(along) > 0.2 then side = math.sign(along)
		else
			local cam = workspace.CurrentCamera
			local look = cam and flatten(cam.CFrame.LookVector) or Vector3.zero
			side = look:Dot(right) >= 0 and 1 or -1
		end
		hang.dashDir = right * side
		hang.dashUntil = now + WALL_DASH_TIME
		hang.dashReadyAt = now + WALL_DASH_GAP
		hang.since = math.max(hang.since, now - SLIP_AFTER * 0.5) -- a dash buys back a little grip
		self:Spend(STAMINA.WallDash)
		char:SetAttribute("DashAt", workspace:GetServerTimeNow())
		self.feel.remote:FireServer("Dash")
		self.feel:Punch(0.14)
		self:Emit("WallDash", {dir = hang.dashDir})
	end
	-- still a wall behind your hands? (follows curved / angled walls; off the end of it you let go)
	local wall = workspace:Raycast(root.Position, -n * 2.8, self.params)
	if not wall or math.abs(wall.Normal.Y) > 0.35 then
		-- (dashing off the corner keeps the dash's speed: you fly off the end of the wall)
		local vel = now < hang.dashUntil and (hang.dashDir * WALL_DASH_SPEED * 0.8 + Vector3.new(0, 6, 0)) or Vector3.new(0, -2, 0)
		letGo(vel)
		return true
	end
	local wn = flatten(wall.Normal)
	if wn.Magnitude > 0.1 then n = wn.Unit; hang.normal = n end
	-- dashing into an inside corner: grab the wall you ran into and stop there
	if now < hang.dashUntil then
		local block = workspace:Raycast(root.Position, hang.dashDir * 2.2, self.params)
		if block and math.abs(block.Normal.Y) < 0.35 then
			local bn = flatten(block.Normal)
			if bn.Magnitude > 0.1 and bn.Unit:Dot(n) < 0.8 then
				n = bn.Unit; hang.normal = n; wall = block
				right = (-n):Cross(UP); right = right.Magnitude > 0.01 and right.Unit or Vector3.xAxis
			end
			hang.dashUntil = now
		end
	end
	local vel
	if now < hang.dashUntil then
		vel = hang.dashDir * WALL_DASH_SPEED
	else
		-- hold on; A / D shimmy along; slipping slowly down after a moment
		vel = right * (wish:Dot(right) * SHIMMY_SPEED)
		hang.y -= math.clamp((now - hang.since - SLIP_AFTER) * 5, 0, 10) * dt
	end
	-- hold the hands' height (gravity is cancelled for the step, so you don't sink down the wall)
	local vy = math.clamp((hang.y - root.Position.Y) * 10, -20, 20) + workspace.Gravity * dt * 0.5
	vel = Vector3.new(vel.X, vy, vel.Z)
	-- keep the hands on the wall
	local gap = (root.Position - wall.Position):Dot(n)
	vel += -n * math.clamp((gap - 1.25) * 8, -4, 6)
	h:ChangeState(Enum.HumanoidStateType.Freefall)
	-- (not 0: with WalkSpeed 0 the humanoid reports no MoveDirection, so A / D and pulling away stopped working)
	h.WalkSpeed = 0.01
	h:Move(Vector3.zero, false)
	root.CFrame = CFrame.lookAt(root.Position, root.Position - n)
	root.AssemblyLinearVelocity = vel
	self.lastFlat, self.prevAirVY = flatten(vel), vel.Y
	self.jumpedAt = now - 0.13
	return true
end

function Parkour:Step(dt)
	local player = self.player
	local char = player.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not player:GetAttribute("InMatch") or not h or not root or h.Health <= 0 or root.Anchored then
		if self.sliding then self:EndSlide() end
		if self.character ~= nil then self:Reset() end
		return
	end
	if self.character ~= char then
		if self.sliding then self:EndSlide() end
		self:Reset()
		self.character, self.humanoid, self.root = char, h, root
		self.params = RaycastParams.new()
		self.params.FilterType = Enum.RaycastFilterType.Exclude
		self.params.FilterDescendantsInstances = {char}
		self.params.RespectCanCollide = true
		-- lobby boundary walls (collision group LobbyBoundary) are invisible: the movement rays ignore them so you
		-- can't wall-climb, mantle or wall-jump off them. The body still collides with them as normal.
		local okGroup, hasGroup = pcall(function() return game:GetService("PhysicsService"):IsCollisionGroupRegistered("ParkourRay") end)
		if okGroup and hasGroup then self.params.CollisionGroup = "ParkourRay" end
		h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	local state = h:GetState()
	if state == Enum.HumanoidStateType.Climbing and h.Jump and not self:Blocked() then
		-- jump off ladders/trusses (the built-in Jumping state is disabled)
		h.Jump = false
		local back = -flatten(root.CFrame.LookVector)
		h:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = back * 14 + Vector3.new(0, h.JumpPower * 0.8, 0)
		self.jumpedAt = os.clock()
		self.lastFlat, self.prevAirVY = back * 14, h.JumpPower * 0.8
		return
	end
	-- ladders / trusses: the humanoid climbs at 0.7 x WalkSpeed, and our movement leaves WalkSpeed at whatever the
	-- last ground speed was (often near zero), so climbing was slow and random. Give it a steady, quick climb.
	if state == Enum.HumanoidStateType.Climbing and not self:Blocked() then
		local look = flatten(root.CFrame.LookVector)
		if look.Magnitude > 0.01 and flatten(h.MoveDirection):Dot(look.Unit) > 0.2 then
			local ledge = self:FindLedge(h, root, look.Unit, 8.6)
			if ledge and ledge.height <= 8.6 then
				self:StartMantle(h, root, ledge, 12)
				self:MantleStep(h, root, dt)
				return
			end
		end
	end
	if state == Enum.HumanoidStateType.Climbing then
		h.WalkSpeed = self.cfg.ClimbWalkSpeed or 30
		local v = root.AssemblyLinearVelocity
		if h.MoveDirection:Dot(root.CFrame.LookVector) > 0.2 and v.Y < (self.cfg.ClimbSpeed or 19) then
			root.AssemblyLinearVelocity = Vector3.new(v.X, self.cfg.ClimbSpeed or 19, v.Z)
		end
	end
	if BLOCKING_STATES[state] or char:GetAttribute("Ragdolled") then
		if self.sliding then self:EndSlide() end
		self.lastFlat, self.prevAirVY = nil, nil
		return
	end
	local cfg = self.cfg
	local now = os.clock()
	local blocked = self:Blocked()
	if not blocked and self.settings.values.SprintMode == "Always" and not self.feel.sprint then self.feel:SetSprint(true) end
	-- stamina: drains while sprinting on the move (and climbing), refills after a short rest
	do
		local v0 = root.AssemblyLinearVelocity
		local moving = Vector3.new(v0.X, 0, v0.Z).Magnitude > self.config.WalkSpeed * 0.8
		if self.feel.sprint and moving and not self.sliding and not self.exhausted and h.FloorMaterial ~= Enum.Material.Air then
			self:Spend(STAMINA.SprintDrain * dt)
		elseif now - self.staminaUsedAt > STAMINA.RegenDelay and not self.climb then
			self.stamina = math.min(1, self.stamina + STAMINA.Regen * dt * (self.crouching and 1.4 or 1))
		end
		if self.exhausted and self.stamina >= STAMINA.Recover then self.exhausted = false end
		if math.abs((player:GetAttribute("Stamina") or 1) - self.stamina) > 0.004 or (self.stamina >= 1 and player:GetAttribute("Stamina") ~= 1) then
			player:SetAttribute("Stamina", self.stamina)
		end
		player:SetAttribute("StaminaExhausted", self.exhausted)
	end
	-- mantling: the body is moved along the pull-up path, nothing else runs
	if self:MantleStep(h, root, dt) then return end

	-- input
	local unfocused = self.unfocused == true
	if unfocused and self.sliding then self:EndSlide() end
	local wish = (blocked or unfocused) and Vector3.zero or flatten(h.MoveDirection)
	-- with Ctrl held, Roblox's own controls can ignore W/A/S/D (Ctrl+key counts as a shortcut), so crouching from a
	-- standstill couldn't start walking. Read the keys directly while crouched.
	if self.crouchHeld and not blocked and not unfocused and wish.Magnitude < 0.01 then
		local x = (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
		local z = (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
		if x ~= 0 or z ~= 0 then
			local cam = workspace.CurrentCamera
			local look = cam and flatten(cam.CFrame.LookVector) or flatten(root.CFrame.LookVector)
			if look.Magnitude > 0.01 then
				look = look.Unit
				local right = Vector3.new(-look.Z, 0, look.X)
				wish = (right * x - look * z).Unit
			end
		end
	end
	if wish.Magnitude > 1 then wish = wish.Unit end
	local jumpHeld = not blocked and not unfocused and (h.Jump or now - (self.requestAt or -math.huge) < 0.05)
	h.Jump = false -- we perform jumps ourselves
	if jumpHeld and not self.jumpHeld then self.jumpPressedAt = now end
	self.jumpHeld = jumpHeld
	if not jumpHeld then self.airJumpArmed = true end

	-- ground
	local v = root.AssemblyLinearVelocity
	local flat = flatten(v)
	local grounded = h.FloorMaterial ~= Enum.Material.Air and now - self.jumpedAt > 0.12
	if not grounded and self.prevAirVY and v.Y > self.prevAirVY + 0.5 then v = Vector3.new(v.X, self.prevAirVY, v.Z) end
	-- horizontal speed only grows through our own rules (accel, slides, hops); physics may slow or redirect it
	-- (walls, slopes) but never add to it, which stops humanoid/slope feedback loops
	if self.lastFlat and flat.Magnitude > self.lastFlat.Magnitude + 0.5 then flat = flat.Unit * self.lastFlat.Magnitude end
	if grounded then
		self.normal = self:FloorNormal(h, root, flat)
		self.lastGround = now
		self.airJumps = 0
	end
	-- slid off the top of a ramp: launch along it (trimp)
	if self.grounded and not grounded and self.sliding and now - self.jumpedAt > 0.12 then
		local climb = alongFloor(flat, self.normal)
		if climb > 0 and flat.Magnitude > 4 then v = Vector3.new(v.X, math.max(v.Y, climb * cfg.TrimpScale), v.Z) end
		self:EndSlide()
	end
	local justLanded = grounded and not self.grounded
	if justLanded then
		self.landedAt = now
		self:Emit("Land", {fall = -(self.lastAirVY or 0), speed = flat.Magnitude})
	end
	if not grounded then self.lastAirVY = v.Y end
	self.grounded = grounded

	-- slide start: fresh press, or landing while holding the slide key
	if not self.sliding and grounded and not blocked then
		local pressed = now - self.slideQueuedAt <= 0.2
		local holdLand = justLanded and self:SlideKeyDown()
		-- a short rest after each slide so tapping the key can't chain slides (and their sound / camera kick)
		local rested = os.clock() - self.lastSlideEnd >= (cfg.SlideRestTime or 0.45)
		if (pressed or holdLand) and rested and flat.Magnitude >= cfg.SlideMinSpeed then
			self.slideQueuedAt = -math.huge
			flat = self:StartSlide(flat, now, pressed and self.slideHoldMode or holdLand)
		end
	end

	-- crouch (held): low and slow on the ground; mirrored so others see the pose. Only on the ground (no tucking in
	-- the air), and not after another move cancelled it until the key is pressed again. Sprinting cancels it.
	local sprintOn = self.feel.sprint == true
	if sprintOn and not self.lastSprintOn and self.crouching then self:CancelCrouch(true) end
	self.lastSprintOn = sprintOn
	local wantCrouch = self.crouchHeld == true and not self.crouchCancelled and grounded and not blocked and not self.sliding
	if wantCrouch ~= self.crouching then
		self.crouching = wantCrouch
		char:SetAttribute("Crouching", wantCrouch)
		self.feel.remote:FireServer("Crouch", wantCrouch)
	end
	if grounded then self.hangsUsed = 0; self.wallJumps = 0; self.airDashUsed = false; self.climbUsed = false; self.climb = nil end
	-- local flag for the climbing pose (SlideAnimator) and your own arms in first person (OwnHead)
	if self.character and (self.climb ~= nil or self.hang ~= nil) ~= (self.character:GetAttribute("Climbing") == true) then self.character:SetAttribute("Climbing", self.climb ~= nil or self.hang ~= nil) end
	-- hanging on a wall: it runs the body (see HangStep)
	if self.hang and self:HangStep(h, root, now, dt, wish, grounded, blocked) then return end
	-- flying across from a wall launch (see LaunchStep)
	if self.launch and not self.hang and self:LaunchStep(h, root, now, dt, grounded, blocked) then return end

	-- mantle: pushing into a ledge you can reach. In the air it happens on its own; from the ground, press jump
	if not blocked and not self.sliding then
		local look = flatten(root.CFrame.LookVector)
		local dir = wish.Magnitude > 0.3 and wish.Unit or (look.Magnitude > 0.01 and look.Unit or nil)
		local pushing = wish.Magnitude > 0.3
		local tryAir = not grounded and pushing and v.Y < 30 and now - self.jumpedAt > 0.08
		local tryGround = grounded and pushing and now - self.jumpPressedAt <= 0.15
		local climbing = self.climb ~= nil or now - (self.climbEndedAt or -math.huge) < 0.4
		if dir and (tryAir or tryGround or climbing) then
			local ledge = self:FindLedge(h, root, dir, climbing and 8.6 or 6.8)
			if ledge and (tryGround and ledge.height > 2.2 or not grounded) and wish.Unit:Dot(-ledge.normal) > 0.45 then
				self.jumpPressedAt = -math.huge
				self:CancelCrouch()
				self:StartMantle(h, root, ledge, flat.Magnitude)
				return
			end
		end
		-- wall climb: in the air, holding forward into a wall with no ledge in reach -> run up it (once per jump)
		if not grounded and pushing and not self.climb and not self.climbUsed and self:HasStamina(0.05) and v.Y > -18 and now - self.jumpedAt > 0.1 then
			local hit = workspace:Raycast(root.Position, wish.Unit * 1.9, self.params)
			if hit and math.abs(hit.Normal.Y) < 0.35 and wish.Unit:Dot(-flatten(hit.Normal).Unit) > 0.7 then
				self:CancelCrouch()
				self.climb = {until_ = now + 0.85, normal = flatten(hit.Normal).Unit}
				self.climbUsed = true
				self.character:SetAttribute("ClimbAt", workspace:GetServerTimeNow())
				self.feel.remote:FireServer("Climb") -- mirrored so other players see the climb pose
				self:Emit("Climb")
			end
		end
		if self.climb then
			local c = self.climb
			local hit = workspace:Raycast(root.Position, -c.normal * 2.1, self.params)
			local still = hit and math.abs(hit.Normal.Y) < 0.35 and pushing and wish.Unit:Dot(-c.normal) > 0.4
			-- a fresh jump press leaves the climb so the wall jump below kicks you off the wall
			if now > c.until_ or not still or not self:HasStamina(0.01) or now - self.jumpPressedAt <= 0.12 then
				self.climb = nil
				self.climbEndedAt = now
			else
				self:Spend(STAMINA.ClimbDrain * dt)
				local up = (cfg.WallClimbSpeed or 18) * math.clamp((c.until_ - now) / 0.85 + 0.35, 0.35, 1)
				h:ChangeState(Enum.HumanoidStateType.Freefall)
				root.AssemblyLinearVelocity = Vector3.new(0, up, 0) - c.normal * 3
				self.lastFlat, self.prevAirVY = -c.normal * 3, up
				self.jumpedAt = now - 0.13 -- counts as airborne for wall jumps off the climb
				return
			end
		end
	end

	-- dash: a short burst toward the movement keys (or where you look); one per air time
	local camera = workspace.CurrentCamera
	if not blocked and now - self.dashQueuedAt <= 0.15 and now >= self.dashReadyAt and (grounded or not self.airDashUsed) then
		self.dashQueuedAt = -math.huge
		self:CancelCrouch()
		self:Spend(STAMINA.Dash)
		local look = camera and flatten(camera.CFrame.LookVector) or flatten(root.CFrame.LookVector)
		local dir = wish.Magnitude > 0.1 and wish.Unit or (look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1))
		if self.sliding then self:EndSlide() end
		self.dashDir, self.dashUntil = dir, now + (cfg.DashTime or 0.17)
		self.dashReadyAt = now + (cfg.DashCooldown or 1)
		if not grounded then self.airDashUsed = true end
		char:SetAttribute("DashAt", workspace:GetServerTimeNow())
		self.feel.remote:FireServer("Dash")
		self.feel:Punch(0.2)
		self:Emit("Dash", {dir = dir})
	end
	if now < self.dashUntil then
		local dir = self.dashDir
		-- dashed into a wall: rebound off it with a kick upward
		local hit = workspace:Raycast(root.Position, dir * 2.6, self.params)
		if hit and math.abs(hit.Normal.Y) < 0.35 then
			-- a wall tall enough to hold on to: cling to it instead of bouncing off
			local tall = workspace:Raycast(root.Position + Vector3.new(0, 2.6, 0), dir * 3.4, self.params)
			if tall and math.abs(tall.Normal.Y) < 0.35 and self.hangsUsed < (cfg.WallHangs or 3) and not self.exhausted
				and self:StartHang(h, root, hit, now, grounded) then
				self.stamina = math.min(1, self.stamina + STAMINA.HangRefund) -- half the dash back
				return
			end
			local n = flatten(hit.Normal).Unit
			local bounce = (dir - 2 * dir:Dot(n) * n).Unit * (cfg.DashSpeed or 58) * (cfg.WallBounceScale or 0.9)
			local vy = cfg.WallBounceUp or 34
			self.dashUntil = -math.huge
			self.airDashUsed = false
			self.dashReadyAt = now + 0.25
			self.jumpedAt, self.grounded = now, false
			h:ChangeState(Enum.HumanoidStateType.Freefall)
			h.WalkSpeed = bounce.Magnitude
			h:Move(bounce.Unit, false)
			root.AssemblyLinearVelocity = Vector3.new(bounce.X, vy, bounce.Z)
			self.lastFlat, self.prevAirVY = bounce, vy
			char:SetAttribute("WallBounceAt", workspace:GetServerTimeNow())
			self.feel.remote:FireServer("WallBounce")
			self.feel:Punch(0.26)
			self:Emit("WallBounce", {normal = n})
			return
		end
		local speed = cfg.DashSpeed or 58
		local burst = dir * speed
		local vy = grounded and v.Y or math.max(v.Y, 1.5) -- a little hang in the air
		h.WalkSpeed = speed
		h:Move(dir, false)
		root.AssemblyLinearVelocity = Vector3.new(burst.X, vy, burst.Z)
		self.lastFlat, self.prevAirVY = burst, (not grounded) and vy or nil
		return
	end

	-- jumps
	local buffer = self.settings.values.JumpBuffer == false and 0.03 or cfg.JumpBuffer
	local fresh = now - self.jumpPressedAt <= buffer
	local canGroundJump = (grounded or now - self.lastGround <= cfg.CoyoteTime) and now - self.jumpedAt > 0.2
	if not blocked and canGroundJump and (fresh or (jumpHeld and cfg.AutoHop)) then
		self.jumpPressedAt = -math.huge
		self:CancelCrouch()
		-- holding jump hops again the moment you land, so the ground step (where running speed builds up) never
		-- runs: take off at running speed toward the movement keys instead of hopping on the spot
		if not self.sliding and wish.Magnitude > 0.01 then
			local dir = wish.Unit
			local target = self:MaxSpeed() * math.min(wish.Magnitude, 1)
			local along, before = flat:Dot(dir), flat.Magnitude
			if along < target then
				flat += dir * (target - along)
				-- never more than you already had (or running speed): no free speed from strafe-hopping
				local cap = math.max(before, target)
				if flat.Magnitude > cap then flat = flat.Unit * cap end
			end
		end
		if self.sliding then
			if now >= self.slideJumpReadyAt and flat.Magnitude > 1 then
				flat += flat.Unit * cfg.SlideJumpBoost
				self.slideJumpReadyAt = now + cfg.SlideJumpCooldown
			end
			self:EndSlide()
		end
		self:Jump(h, root, flat, v, now, false)
		return
	end
	-- wall jump: a fresh press in the air next to a wall kicks you off it (doesn't use up the double jump)
	if not blocked and fresh and not grounded and now - self.jumpedAt > 0.12 and now - self.lastGround > cfg.CoyoteTime
		and self.wallJumps < (cfg.WallJumps or 3) and now - self.lastWallJumpAt > 0.22 then
		local hit = self:FindWall(root, cfg.WallJumpReach or 2.4)
		local n = hit and flatten(hit.Normal)
		if n and n.Magnitude > 0.1 then n = n.Unit end
		local sameWall = n and self.lastWallNormal and n:Dot(self.lastWallNormal) > 0.9 and now - self.lastWallJumpAt < 0.9
		if hit and not sameWall then
			self.jumpPressedAt = -math.huge
			local along = flat - n * flat:Dot(n)
			local out = n * (cfg.WallJumpPush or 26) + along * 0.85
			if wish.Magnitude > 0.1 then out += wish.Unit * 6 end
			local vy = cfg.WallJumpPower or 42
			self.wallJumps += 1
			self:Spend(STAMINA.WallJump)
			self.climb = nil
			self.lastWallJumpAt, self.lastWallNormal = now, n
			self.airDashUsed = false
			self.jumpedAt, self.grounded = now, false
			self.airJumpArmed = false
			h:ChangeState(Enum.HumanoidStateType.Freefall)
			h.WalkSpeed = out.Magnitude
			h:Move(out.Magnitude > 0.05 and out.Unit or Vector3.zero, false)
			root.AssemblyLinearVelocity = Vector3.new(out.X, vy, out.Z)
			self.lastFlat, self.prevAirVY = out, vy
			char:SetAttribute("WallJumpAt", workspace:GetServerTimeNow())
			self.feel.remote:FireServer("WallJump")
			self.feel:Punch(0.16)
			self:Emit("WallJump", {normal = n})
			return
		end
	end
	-- double jump: a fresh press in the air (holding space never spends it)
	if not blocked and fresh and self.airJumpArmed and not grounded and self.airJumps < cfg.AirJumps and now - self.jumpedAt > 0.15
		and now - (self.airJumpedAt or -math.huge) >= (cfg.AirJumpCooldown or 1.2) -- no double-jump spam across hops
		and now - self.lastGround > cfg.CoyoteTime then
		self.jumpPressedAt = -math.huge
		if wish.Magnitude > 0.01 then
			if flat.Magnitude > 1 then flat = turnToward(flat, wish.Unit, math.rad(cfg.AirJumpTurn))
			else flat = wish.Unit * cfg.AirJumpPush end
		end
		self:Jump(h, root, flat, v, now, true)
		return
	end

	-- movement
	if self.sliding then flat = self:SlideStep(flat, wish, dt, now)
	elseif grounded then flat = self:GroundStep(flat, wish, dt, now)
	else flat = self:AirStep(flat, wish, dt) end
	local speed = flat.Magnitude
	if speed > cfg.MaxSpeed then flat *= cfg.MaxSpeed / speed; speed = cfg.MaxSpeed end
	self.speed = speed
	-- on the ground, follow the floor plane: full speed up and down ramps and stairs, no bouncing off slopes
	local vy = v.Y
	if grounded and self.normal.Y < 0.999 then
		vy = alongFloor(flat, self.normal)
		if vy < 0 then vy -= 2 end -- keep feet planted running downhill
	end
	-- the humanoid keeps handling steps; the assembly gets the velocity directly for instant response.
	-- On slopes the humanoid measures speed along the surface, so scale it up to keep the horizontal pace.
	local surface = (grounded and self.normal.Y < 0.999) and math.sqrt(speed * speed + vy * vy) or speed
	h.WalkSpeed = surface
	h:Move(speed > 0.05 and flat.Unit or Vector3.zero, false)
	root.AssemblyLinearVelocity = Vector3.new(flat.X, vy, flat.Z)
	self.prevAirVY = (not grounded) and vy or nil
	self.lastFlat = flat
end

return Parkour
