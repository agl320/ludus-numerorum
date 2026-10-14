-- Bounded paper history. Crossed-out cells stay on the page after deletion.
local State = {}
State.__index = State
function State.new() return setmetatable({rows={}, buffer="", status="Ready"}, State) end
function State:Line()
    local row = self.rows[#self.rows]
    if not row or row.closed then
        row={cells={}}; table.insert(self.rows,row)
        if #self.rows>4 then table.remove(self.rows,1) end
    end
    return row
end
function State:Update(buffer, status)
    local changed = buffer~=self.buffer or status~=self.status
    if not changed then return false end
    local row = self.rows[#self.rows]
    if buffer~=self.buffer then
        if row and row.closed then
            self.buffer=""
            row=nil
        end
        row = row or self:Line()
        local common=0
        while common<math.min(#buffer,#self.buffer) and buffer:sub(common+1,common+1)==self.buffer:sub(common+1,common+1) do common=common+1 end
        if common<#self.buffer then
            local remove=#self.buffer-common
            for i=#row.cells,1,-1 do
                if remove>0 and not row.cells[i].crossed then row.cells[i].crossed=true; remove=remove-1 end
            end
        end
        for i=common+1,#buffer do
            if #row.cells>=8 then row.closed=true; row=self:Line()
                for j=1,i-1 do table.insert(row.cells,{digit=buffer:sub(j,j)}) end
            end
            table.insert(row.cells,{digit=buffer:sub(i,i)})
        end
    end
    if status=="Miss" or status=="Cooldown" then
        row=row or self:Line(); row.rejected=true; row.closed=true
    elseif status=="Hit" then row=row or self:Line(); row.accepted=true; row.closed=true
    elseif status=="Written" then row=row or self:Line(); row.closed=true end -- (lobby scratch pad: just a finished line)
    self.buffer,self.status=buffer,status
    return true
end
return State
