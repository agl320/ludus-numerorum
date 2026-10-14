local Lobby={}
function Lobby.Start(players,remote,reply,characters,profiles)
    local last,busy={},{}
    -- CASES: the result of opening one goes back on its own remote, for the reel (StarterPlayerScripts.CaseOpening)
    local caseResult=remote.Parent:FindFirstChild("CaseResult") or Instance.new("RemoteEvent")
    caseResult.Name="CaseResult";caseResult.Parent=remote.Parent
    remote.OnServerEvent:Connect(function(p,action,id)
        if type(action)~="string" or os.clock()<(last[p] or 0) or busy[p] then return end
        last[p]=os.clock()+.3
        if action=="ClaimQuest" or action=="ClaimDaily" or action=="ClaimSeasonQuest" or action=="ClaimSeasonMilestone" then
            reply:FireClient(p,profiles:Claim(p,action,id));return
        end
        if action=="IntroSeen" then profiles:MarkIntro(p);return end
        -- REROLL a daily contract: remember which one, then the 5 Robux prompt (Numberfall.Store.Products.Reroll; the
        -- receipt does the swap in Monetization). Before the product is set up it's free in Studio, for testing.
        -- RerollQuest <slot> (2 R$), RerollAllQuests (8 R$), RerollWeekly <slot> (4 R$)
        if action=="RerollQuest" or action=="RerollAllQuests" or action=="RerollWeekly" then
            local d=profiles.data[p];if not d then reply:FireClient(p,"Profile loading…");return end
            local kind=action=="RerollAllQuests" and "all" or action=="RerollWeekly" and "weekly" or "daily"
            local ok,why
            if kind=="all" then ok,why=profiles:CanRerollAll(d) elseif kind=="weekly" then ok,why=profiles:CanRerollWeekly(d,id) else ok,why=profiles:CanReroll(d,id) end
            if not ok then reply:FireClient(p,why);return end
            local Store=require(game:GetService("ReplicatedStorage").Numberfall.Store)
            local product=Store.Products[kind=="all" and "RerollAll" or kind=="weekly" and "RerollWeekly" or "Reroll"]
            local pid=product and product.Id or 0
            profiles.rerollPick[p]={kind=kind,index=id}
            if pid>0 then
                game:GetService("MarketplaceService"):PromptProductPurchase(p,pid)
            elseif game:GetService("RunService"):IsStudio() then
                local msg=profiles:ApplyReroll(d,profiles.rerollPick[p]);profiles.rerollPick[p]=nil
                profiles:Publish(p);task.spawn(function() profiles:Save(p,false) end)
                reply:FireClient(p,msg.."  (Studio test: free)")
            else
                reply:FireClient(p,"Rerolls are coming soon")
            end
            return
        end
        -- BuyCase (marks), BuyCaseRobux (Numberfall.Store.Products.Case; free in Studio until it's set up), OpenCase
        if action=="BuyCase" then last[p]=os.clock()+.6;reply:FireClient(p,profiles:BuyCase(p));return end
        if action=="BuyCaseRobux" then
            local d=profiles.data[p];if not d then reply:FireClient(p,"Profile loading…");return end
            local Store=require(game:GetService("ReplicatedStorage").Numberfall.Store)
            local pid=Store.Products.Case and Store.Products.Case.Id or 0
            if pid>0 then
                game:GetService("MarketplaceService"):PromptProductPurchase(p,pid)
            elseif game:GetService("RunService"):IsStudio() then
                profiles:AddCases(d,1);profiles:Publish(p);task.spawn(function() profiles:Save(p,false) end)
                reply:FireClient(p,"+1 case  (Studio test: free)")
            else
                reply:FireClient(p,"Robux cases are coming soon")
            end
            return
        end
        if action=="OpenCase" then
            last[p]=os.clock()+1
            local res,why=profiles:OpenCase(p)
            if res then caseResult:FireClient(p,res) else reply:FireClient(p,why or "Can't open a case right now") end
            return
        end
        -- open 5 or 10 at once (id = how many)
        if action=="OpenCases" then
            last[p]=os.clock()+2
            local res,why=profiles:OpenCases(p,id)
            if res then caseResult:FireClient(p,res) else reply:FireClient(p,why or "Can't open cases right now") end
            return
        end
        if action=="ResetLoadout" then reply:FireClient(p,profiles:ResetLook(p));return end        if action=="ClaimGroupReward" then last[p]=os.clock()+2;reply:FireClient(p,profiles:ClaimGroupReward(p));return end
        if action=="CommunitySeen" then profiles:MarkCommunitySeen(p);return end
        if action=="Redeem" then
            last[p]=os.clock()+1.5 -- slow down code guessing
            reply:FireClient(p,profiles:Redeem(p,id));return
        end
        if action=="BuyHair" or action=="EquipHair" then
            if type(id)~="string" or #id>32 then return end
            reply:FireClient(p,profiles:HairAction(p,action,id));return
        end
        if action=="EquipVisor" or action=="EquipTrail" then
            if type(id)~="string" or #id>16 then return end
            reply:FireClient(p,profiles:LookAction(p,action,id));return
        end
        if action=="Buy" or action=="Equip" then
            if type(id)~="string" or #id>32 then return end
            reply:FireClient(p,profiles:Action(p,action,id));return
        end
        if action=="Ready" then
            -- ready toggle: only while waiting in the lobby, and not once the match countdown has begun
            if not p:GetAttribute("InMatch") or p:GetAttribute("InArena") then return end
            if remote.Parent:GetAttribute("Phase")=="Countdown" then return end
            p:SetAttribute("Ready",id==true);return
        end
        if action~="Play" and action~="Menu" then return end
        local playing=action=="Play"
        if playing== (p:GetAttribute("InMatch")==true) then return end
        -- no leaving for the main menu while you're alive in a round (the P key already checks this; the dock's MAIN MENU
        -- button didn't). Once you're eliminated the death / spectator Lobby buttons still take you out.
        if not playing and p:GetAttribute("InArena")==true then
            local phase=remote.Parent:GetAttribute("Phase")
            local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
            if (phase=="Countdown" or phase=="Playing") and h and h.Health>0 then reply:FireClient(p,"Not during a round");return end
        end
        if playing and not p:GetAttribute("ProfileReady") then reply:FireClient(p,"Profile loading…");return end
        busy[p]=true
        if not playing then characters.combat:Remove(p);characters.movement:Remove(p) end
        if playing then p:SetAttribute("MatchEnteredAt",workspace:GetServerTimeNow());p:SetAttribute("RoundNumbers",0) end
        -- Play puts you in the lobby; you only enter the arena when a match is starting.
        p:SetAttribute("InArena",playing and remote.Parent:GetAttribute("Phase")=="Countdown")
        p:SetAttribute("InMatch",playing)
        p:SetAttribute("Ready",playing and p:GetAttribute("InArena")==true)
        local ok=pcall(function()p:LoadCharacterAsync()end)
        if not ok and p.Parent then p:SetAttribute("InMatch",false);reply:FireClient(p,"Could not deploy. Try Play again.")end
        busy[p]=nil
    end)
    players.PlayerRemoving:Connect(function(p)last[p]=nil;busy[p]=nil end)
end
return Lobby
