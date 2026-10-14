local B = {}
local m = workspace:FindFirstChild("SunsetCity", true)
local R = m and m:GetAttribute("RootCF") or CFrame.new()
local C, A = CFrame.new, CFrame.Angles
B.m, B.R, B.C, B.A = m, R, C, A
B.rng = Random.new(11)
B.IRON = Color3.fromRGB(28,24,24)
B.WARM = Color3.fromRGB(255,170,80)
B.SLATE = Color3.fromRGB(52,50,62)
B.WOOD = Color3.fromRGB(70,48,34)
B.STONE = Color3.fromRGB(100,88,80)
B.TRIM = Color3.fromRGB(112,100,90)
local rad = math.rad
function B.bind(model, cf) m = model R = cf B.m = model B.R = cf end

function B.folder(n, par) par = par or m local f = par:FindFirstChild(n) if not f then f = Instance.new("Model") f.Name = n f.Parent = par end return f end
function B.new(n, par) local f = Instance.new("Model") f.Name = n f.Parent = par or m return f end
local function apply(p, props) if props then for k,v in pairs(props) do p[k] = v end end end
function B.deco(p) p.CanCollide = false p.CanQuery = false p.CanTouch = false return p end
function B.P(par, size, cf, color, mat, props)
  local p = Instance.new("Part") p.Anchored = true p.Size = size p.CFrame = R*cf p.Color = color
  p.Material = mat or Enum.Material.SmoothPlastic apply(p, props) p.Parent = par return p
end
function B.D(par, size, cf, color, mat, props) local p = B.P(par, size, cf, color, mat, props) return B.deco(p) end
function B.W(par, size, cf, color, mat, props)
  local p = Instance.new("WedgePart") p.Anchored = true p.Size = size p.CFrame = R*cf p.Color = color
  p.Material = mat or Enum.Material.Slate apply(p, props) p.Parent = par return p
end
-- box from local min/max corners
function B.box(par, a, b, color, mat, props)
  local mn, mx = a:Min(b), a:Max(b)
  return B.P(par, mx - mn, C((mn + mx)/2), color, mat, props)
end
-- solid wedge ramp, low edge at `from`, high edge at `to` (surface points)
function B.ramp(par, from, to, width, color, mat, props)
  local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
  local dir = flat.Unit local rise = to.Y - from.Y
  local mid = Vector3.new((from.X + to.X)/2, from.Y + rise/2, (from.Z + to.Z)/2)
  return B.W(par, Vector3.new(width, rise, flat.Magnitude), CFrame.lookAt(mid, mid - dir), color, mat, props)
end
-- tilted slab (walk surface from a to b, top surface passes through a and b)
function B.slab(par, a, b, width, thick, color, mat, props)
  thick = thick or 1
  local cf = CFrame.lookAt((a + b)/2, b)
  return B.P(par, Vector3.new(width, thick, (b - a).Magnitude), cf * C(0, -thick/2, 0), color, mat, props)
end
-- stairs: visible steps (no collision) + invisible smooth collider so slides/run don't snag
function B.stairs(par, from, to, width, color, mat, solid)
  local S = B.new("Stairs", par)
  local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
  local len, dir = flat.Magnitude, flat.Unit
  local rise = to.Y - from.Y
  local n = math.max(2, math.ceil(math.abs(rise) / 1.1))
  local run = len / n
  local look = CFrame.lookAt(Vector3.zero, dir)
  for i = 1, n do
    local h = i * rise / n
    local c = from + dir * ((i - 0.5) * run)
    if solid then
      B.D(S, Vector3.new(width, h, run + 0.02), look + Vector3.new(c.X, from.Y + h/2, c.Z), color, mat)
    else
      B.D(S, Vector3.new(width, 1, run + 0.02), look + Vector3.new(c.X, from.Y + h - 0.5, c.Z), color, mat)
      B.D(S, Vector3.new(width, 0.4, 0.3), look + Vector3.new(c.X, from.Y + h - 1.2, c.Z) + dir*(run/2 - 0.2), B.WOOD, Enum.Material.Wood)
    end
  end
  if solid then
    B.ramp(S, from, to, width, color, mat, {Transparency = 1, Name = "Collider"})
  else
    B.slab(S, from, to, width, 0.6, color, mat, {Transparency = 1, Name = "Collider"})
  end
  return S
end
function B.truss(par, pos, h, lookDir)
  local t = Instance.new("TrussPart") t.Anchored = true t.Size = Vector3.new(2, h, 2)
  t.CFrame = R * (CFrame.lookAt(pos + Vector3.new(0, h/2, 0), pos + Vector3.new(0, h/2, 0) + (lookDir or Vector3.zAxis)))
  t.Color = B.IRON t.Material = Enum.Material.Metal t.Parent = par return t
end
-- gable roof, ridge along local Z of cf, `span` across X, `len` along Z, base at cf
function B.roof(par, cf, span, len, h, color)
  color = color or B.SLATE
  B.W(par, Vector3.new(len, h, span/2), cf * C(-span/4, h/2, 0) * A(0, rad(90), 0), color, Enum.Material.Slate)
  B.W(par, Vector3.new(len, h, span/2), cf * C(span/4, h/2, 0) * A(0, rad(-90), 0), color, Enum.Material.Slate)
  B.D(par, Vector3.new(0.6, 0.5, len + 0.2), cf * C(0, h + 0.05, 0), Color3.fromRGB(40,38,46), Enum.Material.Slate)
end
function B.spire(par, base, radius, h, color, segs)
  segs = segs or 6 color = color or B.SLATE
  for i = 0, segs - 1 do
    local t = i/segs local r = radius*(1 - t)
    B.P(par, Vector3.new(h/segs + 0.05, r*2, r*2), C(base + Vector3.new(0, h*(t + 0.5/segs), 0)) * A(0,0,rad(90)), color, Enum.Material.Slate, {Shape = Enum.PartType.Cylinder})
  end
  B.D(par, Vector3.new(0.25, h*0.12, 0.25), C(base + Vector3.new(0, h*1.06, 0)), B.IRON, Enum.Material.Metal)
end
-- window; cf LookVector = outward normal, centered on wall surface
function B.window(par, cf, w, h, lit)
  B.D(par, Vector3.new(w + 0.6, h + 0.6, 0.25), cf * C(0,0,-0.1), Color3.fromRGB(110,98,90), Enum.Material.Limestone)
  local col = lit and Color3.fromRGB(230, 95 + B.rng:NextInteger(0,30), 35) or Color3.fromRGB(38,28,32)
  B.D(par, Vector3.new(w, h, 0.2), cf * C(0,0,-0.2), col, lit and Enum.Material.Neon or Enum.Material.Glass)
  B.D(par, Vector3.new(0.18, h, 0.2), cf * C(0,0,-0.28), Color3.fromRGB(35,25,22), Enum.Material.Wood)
  B.D(par, Vector3.new(w, 0.18, 0.2), cf * C(0,h*0.15,-0.28), Color3.fromRGB(35,25,22), Enum.Material.Wood)
  B.D(par, Vector3.new(w + 0.8, 0.3, 0.6), cf * C(0,-h/2 - 0.35,-0.3), B.TRIM, Enum.Material.Limestone)
end
function B.door(par, cf, w, h)
  B.D(par, Vector3.new(w + 1, h + 0.8, 0.3), cf * C(0, 0.4, -0.12), Color3.fromRGB(95,84,78), Enum.Material.Limestone)
  B.D(par, Vector3.new(w, h, 0.3), cf * C(0, 0, -0.25), Color3.fromRGB(52,32,24), Enum.Material.Wood)
end
-- ivy; cf LookVector = outward normal
function B.ivy(par, cf, w, h, n)
  local f = B.folder("Ivy", par)
  for i = 1, n do
    local u = B.rng:NextNumber(-w/2, w/2)
    local v = h/2 - math.abs(B.rng:NextNumber(0,1))^1.5 * h
    local s = B.rng:NextNumber(0.6, 1.3)
    B.D(f, Vector3.new(s, s*B.rng:NextNumber(0.7,1.2), 0.1), cf * C(u, v, -0.12 - B.rng:NextNumber(0,0.35)) * A(B.rng:NextNumber(-0.6,0.6), B.rng:NextNumber(-0.6,0.6), B.rng:NextNumber(0,6.28)),
      Color3.fromRGB(B.rng:NextInteger(85,135), B.rng:NextInteger(6,18), B.rng:NextInteger(14,26)), Enum.Material.SmoothPlastic, {CastShadow = false})
  end
end
function B.lamp(par, pos, h, light)
  local L = B.new("Lamp", par) h = h or 9
  B.P(L, Vector3.new(0.7, h, 0.7), C(pos + Vector3.new(0, h/2, 0)), B.IRON, Enum.Material.Metal)
  B.D(L, Vector3.new(1.2, 0.5, 1.2), C(pos + Vector3.new(0, 0.25, 0)), B.IRON, Enum.Material.Metal)
  local top = pos + Vector3.new(0, h, 0)
  B.D(L, Vector3.new(1.6, 0.3, 1.6), C(top + Vector3.new(0, 0.15, 0)), B.IRON, Enum.Material.Metal)
  local g = B.D(L, Vector3.new(1.3, 1.8, 1.3), C(top + Vector3.new(0, 1.2, 0)), Color3.fromRGB(255,190,110), Enum.Material.Glass, {Transparency = 0.35})
  B.D(L, Vector3.new(0.6, 1, 0.6), C(top + Vector3.new(0, 1.2, 0)), B.WARM, Enum.Material.Neon)
  for _,o in ipairs({{1,1},{1,-1},{-1,1},{-1,-1}}) do B.D(L, Vector3.new(0.15, 2, 0.15), C(top + Vector3.new(o[1]*0.7, 1.2, o[2]*0.7)), B.IRON, Enum.Material.Metal) end
  B.D(L, Vector3.new(1.8, 0.3, 1.8), C(top + Vector3.new(0, 2.25, 0)), B.IRON, Enum.Material.Metal)
  B.D(L, Vector3.new(0.9, 0.6, 0.9), C(top + Vector3.new(0, 2.7, 0)), B.IRON, Enum.Material.Metal)
  if light ~= false then local l = Instance.new("PointLight") l.Color = B.WARM l.Brightness = 1.6 l.Range = 16 l.Parent = g end
  return L
end
function B.crate(par, pos, s, rot)
  s = s or 4
  local cf = C(pos + Vector3.new(0, s/2, 0)) * A(0, rad(rot or 0), 0)
  local c = B.P(par, Vector3.new(s, s, s), cf, Color3.fromRGB(105,76,50), Enum.Material.WoodPlanks)
  B.D(par, Vector3.new(s + 0.1, 0.4, s + 0.1), cf * C(0, s/2 - 0.3, 0), Color3.fromRGB(70,50,34), Enum.Material.Wood)
  B.D(par, Vector3.new(s + 0.1, 0.4, s + 0.1), cf * C(0, -s/2 + 0.3, 0), Color3.fromRGB(70,50,34), Enum.Material.Wood)
  return c
end
-- house: frame at (x,0,z) rotated rot deg; front faces local +Z. w along local X, d along local Z.
-- o = {x,z,w,d,wall,roof,rot,flat,ivy,dormer,chim}
function B.house(par, o)
  local H = B.new("House", par)
  local r = B.rng
  local F = C(o.x, o.y or 0, o.z) * A(0, rad(o.rot or 0), 0)
  local w, d, wall = o.w, o.d, o.wall
  local g = r:NextInteger(92,122)
  local col = o.color or Color3.fromRGB(g + 18, g, g - 12)
  local mat = (r:NextNumber() > 0.5) and Enum.Material.Cobblestone or Enum.Material.Brick
  B.P(H, Vector3.new(w, wall, d), F * C(0, wall/2, 0), col, mat)
  B.D(H, Vector3.new(w + 0.6, 0.6, d + 0.6), F * C(0, 0.3, 0), Color3.fromRGB(80,70,66), Enum.Material.Limestone)
  if wall > 12 then B.D(H, Vector3.new(w + 0.4, 0.5, d + 0.4), F * C(0, 10, 0), B.TRIM, Enum.Material.Limestone) end
  if o.flat then
    B.P(H, Vector3.new(w + 0.8, 0.8, d + 0.8), F * C(0, wall + 0.4, 0), B.TRIM, Enum.Material.Limestone)
    local pH, top = 1.6, wall + 0.8
    B.P(H, Vector3.new(w + 0.8, pH, 0.8), F * C(0, top + pH/2, d/2), B.TRIM, Enum.Material.Limestone)
    B.P(H, Vector3.new(w + 0.8, pH, 0.8), F * C(0, top + pH/2, -d/2), B.TRIM, Enum.Material.Limestone)
    B.P(H, Vector3.new(0.8, pH, d), F * C(w/2, top + pH/2, 0), B.TRIM, Enum.Material.Limestone)
    B.P(H, Vector3.new(0.8, pH, d), F * C(-w/2, top + pH/2, 0), B.TRIM, Enum.Material.Limestone)
    B.P(H, Vector3.new(w - 1, 0.2, d - 1), F * C(0, top + 0.1, 0), Color3.fromRGB(58,52,52), Enum.Material.Slate)
    -- rooftop clutter: stair hut + chimney
    B.P(H, Vector3.new(6, 6, 6), F * C(w/2 - 5, top + 3, -d/2 + 5), col, mat)
    B.P(H, Vector3.new(7, 0.6, 7), F * C(w/2 - 5, top + 6.3, -d/2 + 5), B.TRIM, Enum.Material.Limestone)
  else
    local rh = o.roof or 8
    B.D(H, Vector3.new(w + 0.8, 0.6, d + 0.8), F * C(0, wall - 0.3, 0), B.TRIM, Enum.Material.Limestone)
    B.roof(H, F * C(0, wall, 0) * A(0, rad(90), 0), d + 1.6, w + 1, rh)
    if o.dormer ~= false then
      local nd = math.max(1, math.floor(w/14))
      for i = 1, nd do
        local dx = -w/2 + (i - 0.5)*w/nd
        local dz = d/4 + 0.4
        local dy = wall + rh*0.5 - 1.6
        B.P(H, Vector3.new(4.5, 4.5, 4), F * C(dx, dy, dz), Color3.fromRGB(70,64,66), Enum.Material.Slate)
        B.roof(H, F * C(dx, dy + 2.25, dz), 5.4, 4.6, 2.4)
        B.window(H, F * C(dx, dy + 0.1, dz + 2) , 2, 2.6, r:NextNumber() > 0.3)
      end
    end
    for i = 1, (o.chim or 1) do
      local cx = (i == 1) and (w/2 - 3) or (-w/2 + 3)
      local ch = rh + 4
      B.P(H, Vector3.new(3, ch, 3), F * C(cx, wall + ch/2, -1), Color3.fromRGB(g + 5, g - 10, g - 20), Enum.Material.Brick)
      B.P(H, Vector3.new(3.8, 0.6, 3.8), F * C(cx, wall + ch, -1), B.TRIM, Enum.Material.Limestone)
      B.D(H, Vector3.new(0.9, 1, 0.9), F * C(cx - 0.7, wall + ch + 0.8, -1), Color3.fromRGB(120,80,60), Enum.Material.Brick)
      B.D(H, Vector3.new(0.9, 1, 0.9), F * C(cx + 0.7, wall + ch + 0.8, -1), Color3.fromRGB(120,80,60), Enum.Material.Brick)
    end
  end
  -- windows front & back
  local cols = math.max(2, math.floor(w/7))
  for side = 0, 1 do
    local face = side == 0 and F * C(0, 0, d/2) or F * A(0, math.pi, 0) * C(0, 0, d/2)
    local fy = 5
    local fl = 0
    while fy + 3 < wall do
      for i = 1, cols do
        local wx = -w/2 + (i - 0.5)*w/cols
        if fl == 0 and side == 0 and i == math.ceil(cols/2) then
          B.door(H, face * C(wx, 3.9, 0), 4, 7.4)
        else
          B.window(H, face * C(wx, fy + 0.5, 0), 2.6, 4.2, r:NextNumber() > 0.55)
        end
      end
      fy += 10 fl += 1
    end
  end
  if o.ivy and o.ivy > 0 then B.ivy(H, F * C(r:NextNumber(-w/5, w/5), wall*0.55, d/2), w*0.8, wall*0.9, o.ivy) end
  H:SetAttribute("Top", o.flat and wall + 0.8 or wall)
  return H
end
return B
