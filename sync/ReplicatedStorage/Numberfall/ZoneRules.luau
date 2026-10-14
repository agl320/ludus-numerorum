-- Closing zone shared by server and clients: a circle that shrinks onto a random quarter of the city.
-- Everything is derived from three attributes on the Numberfall state object, so clients animate the wall
-- locally with no extra network traffic:
--   ZoneQuarter  (1..4, 0 = none)   which quarter of the city the final circle sits in
--   ZoneStartsAt (server time)       when the circle begins to shrink
--   ZoneEndsAt   (server time)       when it reaches the quarter
--   ZoneEndX / ZoneEndZ (local)      where the last, small circle ends up (an open spot inside the quarter)
-- Then, as the round runs out (state EndsAt), it keeps closing: from the quarter down to EndRadius around
-- ZoneEndX/Z, finishing a few seconds before the round ends.
-- Coordinates are local to workspace.SunsetCity's RootCF (x = across, z = along the city).
local Zone = {}
Zone.DelaySeconds = 60      -- after the round starts
Zone.CloseSeconds = 45      -- shrink time
Zone.WarnSeconds = 10       -- countdown shown before it moves
Zone.GraceSeconds = 5       -- time outside before losing a life
Zone.Color = Color3.fromRGB(150, 80, 255) -- wall / outline / tint colour
Zone.Full = {minX = -216, maxX = 216, minZ = -441, maxZ = 126}
Zone.SplitX = 0
Zone.SplitZ = -157.5
Zone.StartRadius = 360      -- covers the whole city
Zone.FinalRadius = 115      -- about one quarter
Zone.HoldSeconds = 12       -- pause at the quarter before the last squeeze
Zone.EndRadius = 0          -- the last circle, as the round runs out: fully closed
Zone.EndLeadSeconds = 0     -- reaches EndRadius this long before the round ends (0 = right as the timer hits 0)
Zone.Names = {"NORTH-WEST", "NORTH-EAST", "SOUTH-WEST", "SOUTH-EAST"}

function Zone.Root()
    local city = workspace:FindFirstChild("SunsetCity")
    return city and city:GetAttribute("RootCF") or CFrame.new()
end

-- the starting circle (whole city) and the final circle for a quarter: {x, z, r}
function Zone.Start()
    local f = Zone.Full
    return {x = (f.minX + f.maxX) / 2, z = (f.minZ + f.maxZ) / 2, r = Zone.StartRadius}
end
function Zone.Quarter(q)
    local f = Zone.Full
    local west = (q == 1 or q == 3)
    local north = (q == 1 or q == 2)
    local x0, x1 = west and f.minX or Zone.SplitX, west and Zone.SplitX or f.maxX
    local z0, z1 = north and f.minZ or Zone.SplitZ, north and Zone.SplitZ or f.maxZ
    return {x = (x0 + x1) / 2, z = (z0 + z1) / 2, r = Zone.FinalRadius}
end

local function lerp(a, b, t) return a + (b - a) * t end

-- the last, small circle (nil when the round has no end time / no end point)
function Zone.EndCircle(state)
    local q = state:GetAttribute("ZoneQuarter") or 0
    if q < 1 then return nil end
    local b = Zone.Quarter(q)
    return {x = state:GetAttribute("ZoneEndX") or b.x, z = state:GetAttribute("ZoneEndZ") or b.z, r = Zone.EndRadius}
end

-- when the last squeeze runs: start, finish (server time) or nil
function Zone.SqueezeTimes(state)
    local ends = state:GetAttribute("ZoneEndsAt")
    local roundEnd = state:GetAttribute("Phase") == "Playing" and state:GetAttribute("EndsAt")
    if not ends or not roundEnd then return nil end
    local s, f = ends + Zone.HoldSeconds, roundEnd - Zone.EndLeadSeconds
    if f - s < 5 then return nil end
    return s, f
end

-- Current safe circle, or nil while the zone is not closing yet. Also returns t (0-1, the first close onto the
-- quarter) and squeeze (0-1 during the last squeeze, nil before it).
function Zone.Circle(state, now)
    local q = state:GetAttribute("ZoneQuarter") or 0
    local starts = state:GetAttribute("ZoneStartsAt")
    local ends = state:GetAttribute("ZoneEndsAt")
    if q < 1 or not starts or not ends or now < starts then return nil end
    local t = math.clamp((now - starts) / math.max(ends - starts, 0.01), 0, 1)
    t = t * t * (3 - 2 * t) -- ease in/out
    local a, b = Zone.Start(), Zone.Quarter(q)
    local c = {x = lerp(a.x, b.x, t), z = lerp(a.z, b.z, t), r = lerp(a.r, b.r, t)}
    local s, f = Zone.SqueezeTimes(state)
    if s and now >= s then
        local k = math.clamp((now - s) / (f - s), 0, 1)
        local e = Zone.EndCircle(state)
        local w = k * k * (3 - 2 * k)
        c = {x = lerp(b.x, e.x, w), z = lerp(b.z, e.z, w), r = lerp(b.r, e.r, w)}
        return c, t, k
    end
    return c, t, nil
end

-- where the circle is heading right now (the quarter, then the last circle)
function Zone.Target(state, now)
    local q = state:GetAttribute("ZoneQuarter") or 0
    if q < 1 then return nil end
    local ends = state:GetAttribute("ZoneEndsAt")
    if ends and now >= ends and Zone.SqueezeTimes(state) then return Zone.EndCircle(state) end
    return Zone.Quarter(q)
end
Zone.Rect = Zone.Circle -- (old name)

-- distance (studs, flat) from a world position to the circle's centre
function Zone.Distance(circle, position)
    local l = Zone.Root():PointToObjectSpace(position)
    return math.sqrt((l.X - circle.x) ^ 2 + (l.Z - circle.z) ^ 2)
end
function Zone.Contains(circle, position, margin)
    if not circle then return true end
    return Zone.Distance(circle, position) <= circle.r - (margin or 0)
end
-- world position of the circle's centre at a given height (local y)
function Zone.Centre(circle, y)
    return Zone.Root():PointToWorldSpace(Vector3.new(circle.x, y or 0, circle.z))
end

-- True when position is outside the current safe area.
function Zone.Outside(state, now, position)
    local c = Zone.Circle(state, now)
    return c ~= nil and not Zone.Contains(c, position)
end

return Zone
