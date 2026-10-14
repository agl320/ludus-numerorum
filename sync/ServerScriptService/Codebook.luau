-- Pure server-side registry. A code belongs to one living subject, never two.
-- Codes are drawn at random and then screened so they don't follow guessable patterns: no repeated digits (1111,
-- 3005, 1221), no runs (1234, 9876, 2468), no mirrored / doubled halves (1221, 4747), no round numbers (4500), and
-- never close to a code already in play or to your last one (at most 1 digit in the same place), so a known number
-- doesn't point at the others.
local Codebook = {}
Codebook.__index = Codebook
function Codebook.new(config, randomInteger)
    return setmetatable({min = config.CodeMin, max = config.CodeMax, random = randomInteger,
        byCode = {}, byOwner = {}, previous = {}}, Codebook)
end
function Codebook:Release(owner)
    local code = self.byOwner[owner]
    if code then self.byCode[code] = nil; self.byOwner[owner] = nil end
end
function Codebook:Forget(owner)
    self:Release(owner)
    self.previous[owner] = nil
end
local function digits(code)
    local d = {}
    for i = 1, #code do d[i] = tonumber(code:sub(i, i)) end
    return d
end
-- a code with no obvious pattern
local function scrambled(code)
    local d = digits(code)
    local n = #d
    local seen, distinct = {}, 0
    for _, v in ipairs(d) do if not seen[v] then seen[v] = true; distinct += 1 end end
    if distinct < n then return false end -- any repeated digit
    -- a steady run (1234, 9876, 1357, 8642)
    local step = d[2] - d[1]
    local steady = true
    for i = 3, n do if d[i] - d[i - 1] ~= step then steady = false end end
    if steady then return false end
    -- neighbouring digits that are consecutive more than once (2134, 5643)
    local adjacent = 0
    for i = 2, n do if math.abs(d[i] - d[i - 1]) == 1 then adjacent += 1 end end
    if adjacent >= 2 then return false end
    -- round numbers / ending in 0
    if d[n] == 0 then return false end
    return true
end
-- how many places two codes share
local function overlap(a, b)
    if not a or not b or #a ~= #b then return 0 end
    local same = 0
    for i = 1, #a do if a:sub(i, i) == b:sub(i, i) then same += 1 end end
    return same
end
function Codebook:Assign(owner)
    local old = self.previous[owner]
    self:Release(owner)
    local function free(code) return code ~= old and not self.byCode[code] end
    local function apart(code)
        if overlap(code, old) > 1 then return false end
        for other in pairs(self.byCode) do if overlap(code, other) > 1 then return false end end
        return true
    end
    local selected
    -- best: scrambled and well apart from every code in play; then just scrambled; then anything free
    for _, test in ipairs({function(c) return scrambled(c) and apart(c) end, scrambled, function() return true end}) do
        for _ = 1, 200 do
            local c = tostring(self.random(self.min, self.max))
            if free(c) and test(c) then selected = c; break end
        end
        if selected then break end
    end
    if not selected then
        for n = self.min, self.max do
            if free(tostring(n)) then selected = tostring(n); break end
        end
    end
    assert(selected, "No unused four-digit codes available")
    self.byCode[selected], self.byOwner[owner], self.previous[owner] = owner, selected, selected
    return selected
end
function Codebook:Resolve(code) return self.byCode[code] end
return Codebook
