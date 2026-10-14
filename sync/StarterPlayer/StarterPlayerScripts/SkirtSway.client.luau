-- Skirts (Numberfall.Outfits skirt panels, welded to the LowerTorso) move like cloth. Each column of panels round the
-- skirt has two segments:
--  * the HIP BAND (SkirtWaist) stays fitted to the hips; it only tips out from the waist when a leg comes up against
--    it (a knee raised high in a jump);
--  * the SKIRT below it (Skirt + its Hem) swings from the hip line as a damped pendulum: it trails when you run,
--    swings forward when you stop or turn, lifts as you fall and settles back with a soft bounce.
-- The legs are a hard limit: a column is never closer in than the leg corners in front of it (checked against the
-- real thigh / shin boxes, a frame ahead for fast kicks). Neighbouring columns pull on each other, so the skirt moves as
-- one piece of cloth. Gussets (strips of the same cloth tucked behind every seam) keep the seams closed.
-- Purely visual and local: only the weld offsets of nearby characters are changed on this client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RANGE = 140          -- only characters this close (studs) are animated
local MARGIN = 0.02        -- clearance around a still leg (moving legs get more)
local LEG_PAD = 0.03       -- the shorts / socks over the legs
local MAX = math.rad(52)      -- the skirt's own swing (a raised thigh on a mini skirt comes out under the hem
local TOTAL = math.rad(60)    -- ... and with the hip band tipped out too: never flips up past this
local STIFF = 55           -- pull back to hanging straight (rad/s^2 per rad)
local DAMP = 10            -- damping (a little under critical: one soft bounce)
local COUPLE = 10 
local MAX_STEP = math.rad(5) -- most two neighbouring columns may differ: a knee lifts a broad smooth bulge, not one flap         -- how strongly neighbouring columns pull together (per second)
local DRAG = 0.012         -- lift from moving through the air (per stud/s)
local INERTIA = 0.004      -- swing from speeding up / slowing down (per stud/s^2)
local FALL = 0.005         -- lift while falling (per stud/s)
local LEGS = {"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"}
-- crouched (and tucked knees in the air, e.g. a jump straight out of a crouch): the knees come right up, so the cloth
-- may lift further to drape over them instead of the thighs poking through, and the columns may differ more, so only
-- the front lifts (the whole skirt flared out like a lampshade). The hem also never sinks into the floor.
local TUCK_MAX, TUCK_TOTAL, TUCK_STEP = math.rad(84), math.rad(90), math.rad(13)
local FLOOR_GAP = 0.12

local rigs = {}

local function flat(v) local f = Vector3.new(v.X, 0, v.Z); return f.Magnitude > 1e-4 and f.Unit or Vector3.new(0, 0, -1) end
local function pivot(P, axis, a) return CFrame.new(P) * CFrame.fromAxisAngle(axis, a) * CFrame.new(-P) end

local function collect(char)
	local holder = char:FindFirstChild("Outfit")
	local lt = char:FindFirstChild("LowerTorso")
	if not holder or not lt then rigs[char] = nil; return end
	local columns, order = {}, {}
	for _, p in ipairs(holder:GetChildren()) do
		local cf = p:GetAttribute("SkirtCF")
		local w = p:FindFirstChild("OutfitWeld")
		if cf and w and w:IsA("Weld") and w.Part0 == lt then
			local angle = p:GetAttribute("SkirtAngle") or 0
			local key = math.floor(angle * 1000 + 0.5)
			local col = columns[key]
			if not col then col = {angle = angle, band = {}, skirt = {}, a = 0, w = 0, b = 0}; columns[key] = col; table.insert(order, col) end
			local h = p:GetAttribute("SkirtH") or 1
			local pc = {weld = w, cf = cf, h = h, off = p:GetAttribute("SkirtOff") or CFrame.identity, part = p, size = p.Size,
				hinge = p:GetAttribute("SkirtHinge"), r = math.max(0.5, Vector3.new(cf.Position.X, 0, cf.Position.Z).Magnitude)}
			table.insert(p.Name == "SkirtWaist" and col.band or col.skirt, pc)
		end
	end
	if #order == 0 then rigs[char] = nil; return end
	table.sort(order, function(x, y) return x.angle < y.angle end)
	for _, col in ipairs(order) do
		local any = col.band[1] or col.skirt[1]
		local H1 = any.hinge and any.cf * any.hinge or any.cf * Vector3.new(0, any.h / 2, 0)
		local out = flat(any.cf.ZVector)
		if out:Dot(Vector3.new(H1.X, 0, H1.Z)) < 0 then out = -out end
		local tan = flat(any.cf.XVector)
		-- the hip line: bottom of the hip band (or the waist hinge for a skirt without one)
		local H2 = H1
		for _, pc in ipairs(col.band) do if pc.off == CFrame.identity then H2 = pc.cf * Vector3.new(0, -pc.h / 2, 0) end end
		-- the skirt's rest shape below the hip line, and the band's below the waist: {drop, out, sideways}
		local function prof(from, pieces)
			local t = {{0, 0, 0}}
			for _, pc in ipairs(pieces) do
				if pc.off == CFrame.identity then
					local b = pc.cf * Vector3.new(0, -pc.h / 2, 0) - from
					table.insert(t, {-b.Y, b:Dot(out), b:Dot(tan)})
				end
			end
			table.sort(t, function(x, y) return x[1] < y[1] end)
			return t
		end
		col.H1, col.H2, col.out, col.tan = H1, H2, out, tan
		col.prof1, col.prof2 = prof(H1, col.band), prof(H2, col.skirt)
		local hw = 0
		for _, pc in ipairs(col.band) do hw = math.max(hw, pc.size.X / 2) end
		for _, pc in ipairs(col.skirt) do hw = math.max(hw, pc.size.X / 2) end
		col.halfW = hw
		-- which way round the tangent axis swings the cloth outward
		local test = pivot(H2, tan, 0.2) * (H2 - Vector3.new(0, 1, 0))
		col.axis = ((test - H2):Dot(out) > 0) and tan or -tan
		col.reach2 = math.max(0.2, col.prof2[#col.prof2][1])
		col.reach1 = math.max(0.1, col.prof1[#col.prof1][1])
	end
	-- how sharply the skirt turns at each column (the angle between its neighbours' outward directions): swinging out
	-- only stretches the hem where it curves round a corner; on the flat front / back faces it doesn't stretch at all
	for i, col in ipairs(order) do
		local p, q = order[(i - 2) % #order + 1], order[i % #order + 1]
		local function ang(u, v) return math.acos(math.clamp(u:Dot(v), -1, 1)) end
		col.curv = (ang(col.out, p.out) + ang(col.out, q.out)) / 2
	end
	-- GUSSETS: a strip of the same cloth behind every seam between neighbouring panels, re-fitted every frame
	for _, old in ipairs(holder:GetChildren()) do if old.Name == "SkirtGusset" then old:Destroy() end end
	local gussets = {}
	local n = #order
	for i, col in ipairs(order) do
		local nxt = order[i % n + 1]
		local all, allN = {}, {}
		for _, pc in ipairs(col.band) do table.insert(all, pc) end
		for _, pc in ipairs(col.skirt) do table.insert(all, pc) end
		for _, pc in ipairs(nxt.band) do table.insert(allN, pc) end
		for _, pc in ipairs(nxt.skirt) do table.insert(allN, pc) end
		for _, pa in ipairs(all) do
			local pb
			for _, q in ipairs(allN) do if q.part.Name == pa.part.Name then pb = q; break end end
			if pb then
				local g = pa.part:Clone()
				g.Name = "SkirtGusset"
				for _, a in ipairs({"SkirtCF", "SkirtH", "SkirtOff", "SkirtAngle", "SkirtHinge", "SkirtReach"}) do g:SetAttribute(a, nil) end
				for _, d in ipairs(g:GetChildren()) do if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end end
				g.CanCollide, g.CanTouch, g.CanQuery, g.CastShadow, g.Massless = false, false, false, false, true
				local w = Instance.new("Weld"); w.Name = "GussetWeld"; w.Part0 = lt; w.Part1 = g; w.C0 = pa.weld.C0; w.Parent = g
				local ca = pa.cf * pa.off; local cb = pb.cf * pb.off
				local sa = (ca:PointToObjectSpace(cb.Position).X >= 0) and 1 or -1
				local sb = (cb:PointToObjectSpace(ca.Position).X >= 0) and 1 or -1
				g.Parent = holder
				table.insert(gussets, {part = g, weld = w, a = pa, b = pb, sa = sa, sb = sb, thick = 0.03, depth = pa.size.Z / 2 + 0.045})
			end
		end
	end
	local rig = {lt = lt, root = char:FindFirstChild("HumanoidRootPart"), hum = char:FindFirstChildOfClass("Humanoid"),
		legs = {}, columns = order, holder = holder, gussets = gussets, accel = Vector3.zero}
	for _, nm in ipairs(LEGS) do local l = char:FindFirstChild(nm); if l then table.insert(rig.legs, l) end end
	rigs[char] = rig
end

local watched = {}
local function watch(char)
	if watched[char] then return end
	watched[char] = true
	local function rescan() task.defer(collect, char) end
	char.ChildAdded:Connect(function(c) if c.Name == "Outfit" then rescan() end end)
	char.DescendantAdded:Connect(function(d) if d.Name == "OutfitWeld" then rescan() end end)
	char.AncestryChanged:Connect(function(_, parent) if not parent then rigs[char] = nil; watched[char] = nil end end)
	rescan()
end
local function player(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(player)
for _, p in ipairs(Players:GetPlayers()) do player(p) end

local function restAt(prof, d)
	for i = 2, #prof do
		local a, b = prof[i - 1], prof[i]
		if d <= b[1] or i == #prof then
			local t = (d - a[1]) / math.max(b[1] - a[1], 1e-4)
			return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
		end
	end
	local l = prof[#prof]
	return l[2], l[3]
end
-- how far a segment hinged at H (rest shape prof below it) must open to clear the leg points
local function needFor(pts, H, out, tan, prof, halfW, dMin)
	local need = 0
	local maxD = prof[#prof][1] + 0.15
	for _, pm in ipairs(pts) do
		local rel = pm[1] - H
		local d = -rel.Y
		if d > dMin and d < maxD then
			local rest, side = restAt(prof, d)
			local rp = rel:Dot(out) + pm[2]
			if rp > rest and math.abs(rel:Dot(tan) - side) < halfW then
				need = math.max(need, math.atan2(rp, d) - math.atan2(rest, d))
			end
		end
	end
	return need
end

-- thigh: all 8 corners; shin: the knee end and halfway down (a heel kicking up behind passes under a short skirt;
-- following it made the back flap out on every running stride)
local corners, shinPts = {}, {}
for _, sx in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
	for _, sy in ipairs({-0.5, 0.5}) do table.insert(corners, Vector3.new(sx, sy, sz)) end
	for _, sy in ipairs({0.5, 0}) do table.insert(shinPts, Vector3.new(sx, sy, sz)) end
end end
local PAD = Vector3.new(LEG_PAD, 0, LEG_PAD)

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local here = cam and cam.CFrame.Position or Vector3.zero
	-- low end mode (phones / consoles): only skirts close to the camera move
	local RANGE = game:GetService("Players").LocalPlayer:GetAttribute("LowEnd") == true and 55 or RANGE
	dt = math.clamp(dt, 1 / 240, 1 / 20)
	local now = os.clock()
	for char, rig in pairs(rigs) do
		local lt = rig.lt
		if not lt.Parent or not rig.holder.Parent then rigs[char] = nil
		elseif (lt.Position - here).Magnitude < RANGE then
			local ltcf = lt.CFrame
			-- leg corners in the hips' space (plus a frame ahead; more clearance the faster they move)
			local pts, prev, cur = {}, rig.prev, {}
			for _, leg in ipairs(rig.legs) do
				if leg.Parent then
					local lcf, size = leg.CFrame, leg.Size + PAD
					for _, c in ipairs(leg.Name:find("Lower") and shinPts or corners) do
						local P = ltcf:PointToObjectSpace(lcf * (c * size))
						local i = #cur + 1
						cur[i] = P
						local q = prev and prev[i]
						local v = q and (P - q).Magnitude or 0
						if v > 1.5 then v = 0 end
						local m = MARGIN + math.min(0.1, v * 2)
						table.insert(pts, {P, m})
						if v > 0 then table.insert(pts, {P + (P - q), m}) end
					end
				end
			end
			rig.prev = cur
			-- how the hips move through the air, in their own space
			local root, hum = rig.root, rig.hum
			local vel = root and root.AssemblyLinearVelocity or Vector3.zero
			local vLocal = ltcf:VectorToObjectSpace(vel)
			local acc = rig.lastV and (vLocal - rig.lastV) / dt or Vector3.zero
			rig.lastV = vLocal
			if acc.Magnitude > 400 then acc = Vector3.zero end -- (teleports, respawns)
			rig.accel = rig.accel:Lerp(acc, 1 - math.exp(-12 * dt))
			local airborne = hum and hum.FloorMaterial == Enum.Material.Air
				and hum:GetState() ~= Enum.HumanoidStateType.Climbing and hum:GetState() ~= Enum.HumanoidStateType.Seated
			local fall = airborne and math.max(0, -vel.Y) * FALL or 0
			local crouched = char:GetAttribute("Crouching") == true
			if crouched then rig.crouchAt = now end
			-- (a jump out of a crouch keeps the tucked limits for a moment while the knees come up)
			local tuck = crouched or (airborne and now - (rig.crouchAt or -1e9) < 1.2)
			local capA, capT, capStep = tuck and TUCK_MAX or MAX, tuck and TUCK_TOTAL or TOTAL, tuck and TUCK_STEP or MAX_STEP
			-- the floor under the feet, in the hips' space (only while standing on something)
			local floorRel
			if hum and root and not airborne then
				floorRel = (root.Position.Y - hum.HipHeight - root.Size.Y / 2) - ltcf.Position.Y
			end
			local speed = Vector3.new(vLocal.X, 0, vLocal.Z).Magnitude
			local cols, n = rig.columns, #rig.columns
			-- 1) the legs' limits for both segments of every column
			for _, col in ipairs(cols) do
				col.need1 = needFor(pts, col.H1, col.out, col.tan, col.prof1, col.halfW + 0.1, 0.15)
				col.need2 = needFor(pts, col.H2, col.out, col.tan, col.prof2, col.halfW + 0.1, 0.12)
			end
			-- 2) the skirt swings: a damped pendulum per column, pushed by drag / inertia / falling
			for i, col in ipairs(cols) do
				local u = col.out
				local push = -(Vector3.new(vLocal.X, 0, vLocal.Z):Dot(u)) * DRAG -- moving forward lifts the back
					- rig.accel:Dot(u) * INERTIA                                 -- speeding up swings it back, stopping forward
					+ fall
					+ (speed > 8 and math.sin(now * 6 + col.angle * 2.3) * speed * 0.002 or 0) -- a little flutter at a run
				push = math.clamp(push, -0.2, 0.35) -- (where it would settle, in radians)
				local acc2 = -STIFF * col.a - DAMP * col.w + push * STIFF
				col.w += acc2 * dt
				col.a += col.w * dt
			end
			-- 3) cloth: neighbours pull together
			local k = 1 - math.exp(-COUPLE * dt)
			local snap = {}
			for i, col in ipairs(cols) do snap[i] = col.a end
			for i, col in ipairs(cols) do
				local avg = (snap[(i - 2) % n + 1] + snap[i % n + 1]) / 2
				col.a += (avg - col.a) * k * 0.5
			end
			-- 4) the legs win: never closer in than they allow (and pushing the cloth gives it some swing)
			for i, col in ipairs(cols) do
				local l, r = cols[(i - 2) % n + 1].need2, cols[i % n + 1].need2
				local need = math.min(col.need2, math.max(l, r) + 0.3) -- (a lone column can't stand far out of the rest)
				need = math.max(need, 0.5 * math.max(l, r))
				if col.a < need then
					-- (only a little of the leg's push carries on as swing: more pumped energy in stride after stride)
					col.w = math.max(col.w, math.min(1.2, (need - col.a) / dt * 0.1))
					col.a = need
				end
				-- the hem stays above the floor (crouched low, the back of the skirt used to sink into the ground)
				if floorRel then
					local last = col.prof2[#col.prof2]
					local d, o = last[1], last[2]
					local allow = col.H2.Y - floorRel - FLOOR_GAP
					if d > allow then
						local R = math.sqrt(d * d + o * o)
						local th = math.acos(math.clamp(allow / R, -1, 1)) - math.atan2(o, d)
						if col.a < th then col.a = th; col.w = math.max(col.w, 0) end
					end
				end
				if col.a > capA then col.a = capA; col.w = math.min(col.w, 0) end
				if col.a < -0.05 then col.a = -0.05; col.w = math.max(col.w, 0) end
				-- the hip band: only where a leg pushes on it
				local nb = math.min(col.need1, capA)
				if nb > col.b then col.b = nb else col.b += (nb - col.b) * (1 - math.exp(-10 * dt)) end
			end
			-- 4b) no splits: neighbouring columns stay within MAX_STEP of each other. Where a leg pushes one column out
			-- (front and back, where one knee comes forward and the other doesn't) the columns beside it are lifted
			-- too, tapering off round the skirt, the way the sides already move together
			for _ = 1, 2 do
				for i = 1, n do
					local col, p = cols[i], cols[(i - 2) % n + 1]
					if col.a < p.a - capStep then col.a = p.a - capStep; col.w = math.max(col.w, p.w * 0.5) end
					if col.b < p.b - capStep then col.b = p.b - capStep end
				end
				for i = n, 1, -1 do
					local col, p = cols[i], cols[i % n + 1]
					if col.a < p.a - capStep then col.a = p.a - capStep; col.w = math.max(col.w, p.w * 0.5) end
					if col.b < p.b - capStep then col.b = p.b - capStep end
				end
			end
			for _, col in ipairs(cols) do
				if col.a + col.b > capT then col.a = capT - col.b; col.w = math.min(col.w, 0) end
			end
			-- 5) pose the panels
			for _, col in ipairs(cols) do
				local T1 = pivot(col.H1, col.axis, col.b)
				local T2 = T1 * pivot(col.H2, col.axis, math.max(col.a, 0) + math.min(col.a, 0))
				for _, pc in ipairs(col.band) do
					if pc.weld.Parent then
						pc.now = T1 * pc.cf * pc.off
						pc.weld.C0 = pc.now
						local w = Vector3.new(pc.size.X + math.sin(math.max(col.b, 0)) * col.reach1 * col.curv, pc.size.Y, pc.size.Z)
						if (pc.part.Size - w).Magnitude > 0.004 then pc.part.Size = w end
					end
				end
				for _, pc in ipairs(col.skirt) do
					if pc.weld.Parent then
						pc.now = T2 * pc.cf * pc.off
						pc.weld.C0 = pc.now
						-- as the hem swings out it gets longer round the corners: widen those panels by just that much (the
						-- flat front / back faces don't stretch; widening them made the panels splay into each other)
						local w = Vector3.new(pc.size.X + math.sin(math.max(col.a + col.b, 0)) * col.reach2 * col.curv, pc.size.Y, pc.size.Z)
						if (pc.part.Size - w).Magnitude > 0.004 then pc.part.Size = w end
					end
				end
			end
			-- 6) re-fit the gussets behind the seams
			for _, g in ipairs(rig.gussets) do
				local A, B = g.a, g.b
				local ca, cb = A.now, B.now
				if ca and cb and g.weld.Parent then
					local wa, ha = A.part.Size.X / 2, A.part.Size.Y / 2
					local wb, hb = B.part.Size.X / 2, B.part.Size.Y / 2
					local at, ab = ca * Vector3.new(g.sa * wa, ha, 0), ca * Vector3.new(g.sa * wa, -ha, 0)
					local bt, bb = cb * Vector3.new(g.sb * wb, hb, 0), cb * Vector3.new(g.sb * wb, -hb, 0)
					local across = ca.XVector * g.sa - cb.XVector * g.sb
					local down = ca.YVector + cb.YVector
					if across.Magnitude > 1e-4 and down.Magnitude > 1e-4 then
						local x = across.Unit
						local y = (down - x * down:Dot(x)).Unit
						local z = x:Cross(y)
						local c = (at + ab + bt + bb) / 4
						if z:Dot(Vector3.new(c.X, 0, c.Z)) < 0 then z = -z; x = -x end
						c = c - z * g.depth -- (fully behind the panels: level with them it z-fought)
						local width = math.max(math.abs((bt - at):Dot(x)), math.abs((bb - ab):Dot(x))) + 0.16
						local height = math.max((at - ab).Magnitude, (bt - bb).Magnitude)
						g.weld.C0 = CFrame.fromMatrix(c, x, y, z)
						local size = Vector3.new(width, height, g.thick)
						if (g.part.Size - size).Magnitude > 0.004 then g.part.Size = size end
					end
				end
			end
		end
	end
end)
