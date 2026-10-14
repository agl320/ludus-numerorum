-- Cosmetic replication only. Combat still validates all elimination submissions.
local Notebook = {}
Notebook.__index = Notebook
function Notebook.new(players, remote)
    local self=setmetatable({packets={},locked={},inspects={}},Notebook)
    remote.OnServerEvent:Connect(function(player,character,buffer,out,written,inspect)
        local now=workspace:GetServerTimeNow()
        if character~=player.Character or not character then return end
        local h=character:FindFirstChildOfClass("Humanoid")
        if not h or h.Health<=0 or type(buffer)~="string" or #buffer>4 or buffer:find("%D") then return end
        -- notebook out / put away (E), so other players see the book come out even before any digit is typed
        if type(out)=="boolean" and character:GetAttribute("NotebookOut")~=out then character:SetAttribute("NotebookOut",out) end
        -- inspecting the gear (Y): stamped so other players see it too. Typing gear's look clears itself; the notebook's
        -- pen spin lasts until the player stops it (inspect = false)
        if inspect==true and now>=(self.inspects[player] or 0) then
            self.inspects[player]=now+.5
            character:SetAttribute("InspectAt",now)
            local finish=player:GetAttribute("NotebookFinish")
            if finish=="Typewriter" or finish=="Keyboard" then
                task.delay(3.2,function() if character.Parent and character:GetAttribute("InspectAt")==now then character:SetAttribute("InspectAt",nil) end end)
            end
        elseif inspect==false and character:GetAttribute("InspectAt")~=nil then
            character:SetAttribute("InspectAt",nil)
        end
        if now<(self.packets[player] or 0) or now<(self.locked[character] or 0) then return end
        self.packets[player]=now+0.025
        -- (a finished line on the lobby scratch pad: shown written down, never as a mark)
        local lobbyLine=written==true and buffer~="" and player:GetAttribute("InArena")~=true
        character:SetAttribute("NoteSnapshot",(lobbyLine and "Written" or "Ready").."|"..buffer)
    end)
    players.PlayerRemoving:Connect(function(player) self.packets[player]=nil;self.inspects[player]=nil end)
    -- Weak keys release departed characters without retaining their notebook state.
    self.locked=setmetatable({}, {__mode="k"})
    return self
end
function Notebook:Result(player,code,status,deadline)
    local char=player.Character
    if not char or (status~="Hit" and status~="Miss") or type(code)~="string" or not code:match("^%d%d%d%d$") then return end
    self.locked[char]=deadline
    char:SetAttribute("NoteSnapshot",status.."|"..code)
end
return Notebook
