-- Pure typing state machine, shared by physical keyboard and touch keypad.
local Input = {}
Input.__index = Input
function Input.new()
    return setmetatable({buffer = "", serial = 0, pending = false, deadline = 0, status = "Ready", sentAt = 0}, Input)
end
function Input:Reset()
    self.serial = self.serial + 1 -- Late replies from a previous life cannot change this life.
    self.buffer, self.pending, self.deadline, self.status = "", false, 0, "Ready"
end
function Input:Tick(now)
    if self.pending and now - self.sentAt >= 5 then
        self.serial = self.serial + 1
        self.pending, self.buffer, self.status = false, "", "Timeout"
    elseif not self.pending and now >= self.deadline and self.deadline > 0 then
        self.buffer, self.deadline, self.status = "", 0, "Ready"
    end
end
function Input:Digit(digit, now)
    self:Tick(now)
    if self.pending or now < self.deadline or type(digit) ~= "string" or not digit:match("^%d$") then return nil end
    if #self.buffer >= 4 then return nil end
    self.buffer = self.buffer .. digit
    self.status = #self.buffer == 4 and "Complete" or "Ready"
    return nil
end
function Input:Confirm(now)
    self:Tick(now)
    if self.pending or now < self.deadline or #self.buffer ~= 4 then return nil end
    self.serial = self.serial + 1
    self.pending, self.sentAt, self.status = true, now, "Sending"
    return self.buffer, self.serial
end
-- the lobby scratch pad: what's typed is written down (nothing is sent), then the page moves to a fresh line
function Input:Write(now)
    self:Tick(now)
    if self.pending or now < self.deadline or #self.buffer == 0 then return false end
    self.status, self.deadline = "Written", now + 0.45
    return true
end
function Input:Backspace(now)
    if not self.pending and now >= self.deadline then self.buffer = self.buffer:sub(1, math.max(0, #self.buffer - 1));self.status="Ready" end
end
function Input:Resolve(serial, status, deadline)
    if not self.pending or serial ~= self.serial then return false end
    self.pending, self.status, self.deadline = false, status, deadline
    return true
end
return Input
