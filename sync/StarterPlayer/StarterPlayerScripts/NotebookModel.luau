-- Shared geometry for the camera arms and the character-held world model.
local Model = {}
Model.__index = Model
local ink=Color3.fromRGB(46,48,57)
-- viewmodel sleeves: dark coat with a red cuff, skin-toned hands with a thumb
local COAT=Color3.fromRGB(34,30,36)
local COAT_LOW=Color3.fromRGB(28,25,30)
local CUFF=Color3.fromRGB(150,16,34)
local Players=game:GetService("Players")
local function skinTone(character,side)
    local player=character and Players:GetPlayerFromCharacter(character)
    local tone=player and player:GetAttribute("SkinTone")
    if typeof(tone)=="Color3" then return tone end
    local hand=character and (character:FindFirstChild(side.."Hand") or character:FindFirstChild(side.." Arm"))
    return hand and hand.Color or Color3.fromRGB(210,168,128)
end
local function copyCloth(dst,src)
    if not src then return end
    dst.Color=src.Color;dst.Material=src.Material;dst.MaterialVariant=src.MaterialVariant
end
local function part(parent,name,size,color)
    local p=Instance.new("Part")
    p.Name,p.Size,p.Color=name,size,color
    p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery,p.CastShadow=true,false,false,false,false
    p.Material=Enum.Material.SmoothPlastic
    p.Parent=parent
    return p
end
-- ---- typing gear: Catalog items with Device = "Typewriter" / "Keyboard" swap the notebook and pen for that machine:
-- the imported model in ReplicatedStorage.Numberfall.NotebookAssets (front toward -Z), scaled down to hold. Laid out
-- in the notebook's own space (the board frame): +Y up the page, -Z out of the page toward whoever holds it, +X the
-- page's left. The live writing surface (your typed digits) goes on the typewriter's sheet / the keyboard's screen,
-- placed at surfaceAt. grip = where the hands rest on the keys (worked out from the keys part).
local function rgb(t)return Color3.fromRGB(t[1],t[2],t[3])end
local Gear=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("GearColorways"))
local DEVICES={}
-- fp = the first-person hold on top of the notebook's: {up, away, tilt} (tilt < 0 tips the deck up to face you)
-- (Typewriter: bigger and held closer in first person)
-- back = how it's carried on your back between uses: "upright" (standing, keys facing out, the sheet up by your
-- shoulders) or "flat" (strapped flat on, keys facing out); backHide = parts folded away while it's on your back
-- (Typewriter: held close, tipped up toward you; on the back its base is against you)
DEVICES.Typewriter={asset="Typewriter",scale=.4,fp={1.0,-.45,-1.0},back="flat",surfaceAt=Vector3.new(0,.24,-.09),
    oneLine=true,scale3=1.45,
    backHide={["Typewriter blank paper"]=true}, -- (the sheet is rolled in only once it's in your hands: it swept through your head)
    paperPart="Typewriter blank paper",paperStretch=1.6, -- (at hand size the sheet was too short for 4 rows: it rises higher out of the roller)
    keysPart="Typewriter circular keys",
    font=Enum.Font.SpecialElite,ink=Color3.fromRGB(34,32,36),ok=Color3.fromRGB(52,96,66),strike=Color3.fromRGB(34,32,36)}
-- (Keyboard: held close in first person, hands resting on the front corners of the keys like typing)
-- (Keyboard: held close and tipped well up toward you: the keys fill the lower view)
DEVICES.Keyboard={asset="Keyboard",scale=.36,fp={.86,-.82,-.85},back="flat",
    skip={["Keyboard braided cable"]=true}, -- (no coiled cable)
    gripPart="Keyboard bottom keys",gripX=.4,gripIn=-.1,hover=.02,textScale=1.35,scale3=1.55,
    backHide={ScreenStand=true,ScreenBezel=true,ScreenGlass=true,ScreenTrim=true,["Keyboard braided cable"]=true},surfaceAt=Vector3.new(0,.28,-.09),
    basePart="Keyboard enclosure",keysPart="Keyboard key row 3",screen=true,
    noScreen=true, -- (no display: the number shows in the monkeytype-style panel; the screen's spot only places the keyboard)
    font=Enum.Font.Code,ink=Color3.fromRGB(96,255,170),ok=Color3.fromRGB(200,255,220),strike=Color3.fromRGB(255,70,90)}
Model.Devices=DEVICES
local CANVAS=500/390 -- the writing surface's height / width (PaperInk canvas)
local layouts={}
local function deviceLayout(def)
    if layouts[def]~=nil then return layouts[def] or nil end
    local assets=game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NotebookAssets")
    local model=assets:FindFirstChild(def.asset)
    if not model then return nil end -- (not loaded yet: try again next time)
    local cf0=model:IsA("BasePart") and model.CFrame or model:GetBoundingBox()
    local s=def.scale
    local L={parts={}}
    local keysCF,keysSize,baseCF,baseSize
    for _,p in ipairs(model:IsA("BasePart") and {model} or model:GetDescendants())do
        if p:IsA("BasePart") and not (def.skip and def.skip[p.Name]) then
            local rel=cf0:ToObjectSpace(p.CFrame)
            local cf=CFrame.new(rel.Position*s)*rel.Rotation
            local size=p.Size*s
            if p.Name==def.paperPart then
                -- the sheet grows upward (its foot stays in the roller); the digits sit on its face, leaning back with it
                local k=def.paperStretch or 1
                local h=size.Y
                size=Vector3.new(size.X,h*k,size.Z)
                cf=cf+cf.UpVector*(h*(k-1)/2)
                local tilt=math.atan2(size.Z,size.Y)
                local sh=size.Y*.88
                local sw=math.min(size.X*.92,sh/CANVAS);sh=sw*CANVAS
                L.surface={size=Vector3.new(sw,sh,.002),cf=cf*CFrame.Angles(tilt*.85,0,0)*CFrame.new(0,0,-.012)}
            end
            if p.Name==def.keysPart then keysCF,keysSize=cf,size end
            if p.Name==def.basePart then baseCF,baseSize=cf,size end
            table.insert(L.parts,{src=p,name=p.Name,size=size,cf=cf})
        end
    end
    if def.screen and baseCF then
        -- a slim display on a little stand at the back of the keyboard, oxblood strip to match the trim
        local top=baseCF.Position.Y+baseSize.Y/2
        local back=baseCF.Position.Z+baseSize.Z/2
        local sw=.56;local sh=sw*CANVAS
        local bezel=Vector3.new(sw+.07,sh+.1,.032)
        local c=Vector3.new(0,top+.08+bezel.Y/2,back-.05)
        local dark=Color3.fromRGB(16,16,18)
        local smooth={Material=Enum.Material.SmoothPlastic}
        if not def.noScreen then
        table.insert(L.parts,{name="ScreenStand",size=Vector3.new(.22,.12,.05),cf=CFrame.new(0,top+.05,back-.05),color=dark,props=smooth})
        table.insert(L.parts,{name="ScreenBezel",size=bezel,cf=CFrame.new(c),color=dark,props=smooth})
        table.insert(L.parts,{name="ScreenGlass",size=Vector3.new(sw+.02,sh+.02,.004),cf=CFrame.new(c+Vector3.new(0,.012,-bezel.Z/2-.001)),
            color=Color3.fromRGB(6,8,8),props={Material=Enum.Material.Glass,Reflectance=.05}})
        table.insert(L.parts,{name="ScreenTrim",size=Vector3.new(sw,.012,.006),cf=CFrame.new(c+Vector3.new(0,-bezel.Y/2+.028,-bezel.Z/2-.002)),
            color=Color3.fromRGB(110,22,30),props={Material=Enum.Material.Neon}})
        end
        L.surface={size=Vector3.new(sw,sh,.002),cf=CFrame.new(c+Vector3.new(0,.012,-bezel.Z/2-.005))}
    end
    if not L.surface or not keysCF then layouts[def]=false;return nil end
    -- move the whole machine so the writing surface lands where the notebook's page would be
    local shift=def.surfaceAt-L.surface.cf.Position
    for _,e in ipairs(L.parts)do e.cf=e.cf+shift end
    L.surface.cf=L.surface.cf+shift
    local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
    for _,e in ipairs(L.parts)do
        if not (def.backHide and def.backHide[e.name]) then
            local c,h=e.cf.Position,e.size/2 -- (the parts are axis-aligned in the board frame)
            lo=lo:Min(c-h);hi=hi:Max(c+h)
        end
    end
    L.bounds={lo,hi}
    local keys=keysCF.Position+shift+Vector3.new(0,keysSize.Y/2+.05,0)
    L.grip={Left=keys+Vector3.new(keysSize.X*.56,-.07,.02),Right=keys+Vector3.new(-keysSize.X*.56,-.07,.02)} -- (hands on the machine's sides: the keys and the sheet stay in view)
    -- gripPart: the hands rest on that row of keys instead (gripX = how far out from the middle, gripIn = toward you)
    if def.gripPart then
        for _,e in ipairs(L.parts)do
            if e.name==def.gripPart then
                local top=e.cf.Position+Vector3.new(0,e.size.Y/2,0)
                local x=e.size.X*(def.gripX or .3)
                L.grip={Left=top+Vector3.new(x,0,def.gripIn or 0),Right=top+Vector3.new(-x,0,def.gripIn or 0)}
            end
        end
    end
    layouts[def]=L
    return L
end
function Model.new(parent,withArms,character)
    local self=setmetatable({pieces={},cells={},notebookVisible=true},Model)
    self.firstPerson=withArms==true
    self.model=Instance.new("Model"); self.model.Name="NotebookViewmodel"; self.model.Parent=parent
    local function piece(name,size,color,offset)
        local p=part(self.model,name,size,color); table.insert(self.pieces,{part=p,offset=offset}); return p
    end
    local assets=game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("NotebookAssets")
    local function mesh(name,scale)
        local p=assets:WaitForChild(name):Clone()
        p.Size=p.Size*scale;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
        p.Parent=self.model;return p
    end
    self.board=mesh("Notebook",.78)
    table.insert(self.pieces,{part=self.board,offset=CFrame.Angles(-math.pi/2,0,0)*CFrame.new(0.028499991*.78,0.086499997*.78,-0.000000000*.78)})
    -- Invisible writing surface sits just above the imported paper; textures stay intact.
    self.paper=piece("LiveWritingSurface",Vector3.new(1.096,1.587,.002),Color3.new(1,1,1),CFrame.new(0,0,-.090))
    self.paper.Transparency=1
    self.pencil=mesh("Pen",.5)
    local axis=(Vector3.new(-.69,.177,.57)-Vector3.new(.59,.177,-.84)).Unit
    local right=Vector3.new(0,1,0):Cross(axis).Unit
    local basis=CFrame.fromMatrix(Vector3.new(),right,axis,right:Cross(axis))
    local penTip=Vector3.new(.59,.177,-.84)-axis*.018
    local center=Vector3.new(-.0140107,.2034945,-.1769399)
    self.penOffset=basis:Inverse()*CFrame.new((center-penTip)*.5)
    local gui=Instance.new("SurfaceGui")
    gui.Name,gui.Face,gui.AlwaysOnTop="PaperInk",Enum.NormalId.Front,false
    gui.SizingMode,gui.CanvasSize=Enum.SurfaceGuiSizingMode.FixedSize,Vector2.new(390,500)
    gui.LightInfluence,gui.Parent=0,self.paper
    local function line(x,y,w,h,color,parent)
        local f=Instance.new("Frame"); f.BorderSizePixel=0; f.BackgroundColor3=color
        f.Position,f.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h);f.Parent=parent or gui;return f
    end
    for r=1,4 do
        local row={};self.cells[r]=row
        for c=1,8 do
            local label=Instance.new("TextLabel")
            label.BackgroundTransparency=1; label.Size=UDim2.fromOffset(37,58)
            label.Position=UDim2.fromOffset(50+(c-1)*39,52+(r-1)*90)
            label.Font=Enum.Font.PermanentMarker;label.TextSize=43;label.TextColor3=ink;label.Text="";label.Parent=gui
            local strike=line(0,29,37,3,ink,label);strike.Rotation=-12;strike.Visible=false
            row[c]={label=label,strike=strike}
        end
        row.strike=line(48,82+(r-1)*90,316,4,ink);row.strike.Rotation=-3;row.strike.Visible=false
    end
    -- ruled lines and a red margin, shown on the clean page a dyed notebook gets (Finish)
    self.rules=Instance.new("Frame");self.rules.Name="Rules";self.rules.BackgroundTransparency=1;self.rules.Size=UDim2.fromScale(1,1)
    self.rules.ZIndex=0;self.rules.Visible=false;self.rules.Parent=gui
    for k=0,9 do local f=line(28,66+k*45,340,2,Color3.fromRGB(176,196,224),self.rules);f.ZIndex=0 end
    do local f=line(40,20,2,470,Color3.fromRGB(220,120,120),self.rules);f.ZIndex=0 end
    self.arms={}
    local function limb(side,name,fallback,scale)
        -- Default block geometry, not avatar package meshes whose mesh scale,
        -- surface textures and baked cuffs can ignore the intended slim shape.
        local width=name=="UpperArm"and .46 or name=="LowerArm"and .40 or .36
        local p=part(self.model,side..name.."Viewmodel",Vector3.new(width,1,width*.85),fallback)
        return p
    end
    for _,side in ipairs(withArms and {"Left","Right"}or {}) do
        local tone=skinTone(character,side)
        local upper=limb(side,"UpperArm",COAT,.52)
        local lower=limb(side,"LowerArm",COAT_LOW,.48)
        upper.Material=Enum.Material.Fabric;lower.Material=Enum.Material.Fabric
        local hand=limb(side,"Hand",tone,.52)
        hand.Size=Vector3.new(hand.Size.X,.32,hand.Size.Z)
        local cuff=part(self.model,side.."CuffViewmodel",Vector3.new(lower.Size.X*1.12,.13,lower.Size.Z*1.12),CUFF)
        cuff.Material=Enum.Material.Fabric
        local thumb=part(self.model,side.."ThumbViewmodel",Vector3.new(.11,.24,.11),tone)
        self.arms[side]={upper=upper,lower=lower,hand=hand,cuff=cuff,thumb=thumb,upperWidth=upper.Size.X,upperDepth=upper.Size.Z,lowerWidth=lower.Size.X,lowerDepth=lower.Size.Z}
    end
    return self
end
function Model:Paint(state,now,activity)
    local progress=math.clamp((now-activity)/0.2,0,1)
    -- (the typewriter's sheet holds only the number being typed: a finished one clears a moment later, or as the
    -- next one starts, instead of piling up)
    local rows=state.rows
    if self.devDef and self.devDef.noScreen then rows={} -- (nothing to write on)
    elseif self.devDef and self.devDef.oneLine then
        local last=rows[#rows]
        rows=(last and not (last.closed and now-activity>2.5)) and {last} or {}
    end
    for r=1,4 do
        local row=rows[r]
        for c=1,8 do
            local cell=row and row.cells[c]
            local visual=self.cells[r][c]
            visual.label.Text=cell and cell.digit or ""
            local latest=row and r==#rows and c==#row.cells
            visual.label.TextTransparency=latest and not cell.crossed and 1-math.min(1,progress*3) or 0
            visual.label.TextColor3=row and row.accepted and (self.okInk or Color3.fromRGB(60,94,70)) or (self.ink or ink)
            visual.strike.Visible=cell and cell.crossed or false
            visual.strike.Size=UDim2.fromOffset(37*(latest and progress or 1),3)
        end
        self.cells[r].strike.Visible=row and row.rejected or false
        self.cells[r].strike.Size=UDim2.fromOffset(316*(r==#rows and progress or 1),4)
    end
end
local function segment(p,a,b,width,depth)
    p.Size=Vector3.new(width,math.max(.01,(a-b).Magnitude),depth)
    p.CFrame=CFrame.lookAt((a+b)*0.5,b)*CFrame.Angles(math.pi/2,0,0)
end
-- First-person arms wear the same clothes as the character: sleeves copy the upper / lower arm colour and fabric,
-- the cuff only shows where there is a sleeve, and the hands always take the player's skin tone.
function Model:Dress(character)
    if not character then return end
    -- re-dress whenever the character's own arms change (outfit, colourway, skin tone). The key used to be the outfit's
    -- attributes, which could be unset: the arms were dressed once, before the outfit had loaded, copied the bare grey /
    -- white body colour and never updated. Checked at most every half second.
    local now=os.clock()
    if self.dressedFor==character and now-(self.dressCheckAt or 0)<0.5 then return end
    self.dressCheckAt=now
    local function sig(p)return p and (tostring(p.Color)..p.Material.Name..p.MaterialVariant) or "-" end
    local player=Players:GetPlayerFromCharacter(character)
    local key=sig(character:FindFirstChild("LeftUpperArm"))..sig(character:FindFirstChild("LeftLowerArm"))..sig(character:FindFirstChild("RightUpperArm"))
        ..sig(character:FindFirstChild("RightLowerArm"))..tostring(player and player:GetAttribute("SkinTone"))
    if self.dressedFor==character and self.dressKey==key then return end
    self.dressedFor,self.dressKey=character,key
    for side,arm in pairs(self.arms) do
        local tone=skinTone(character,side)
        local upper=character:FindFirstChild(side.."UpperArm");local lower=character:FindFirstChild(side.."LowerArm")
        copyCloth(arm.upper,upper);copyCloth(arm.lower,lower)
        -- (the same plain skin material as the body: Outfits.Dress "skin")
        arm.hand.Color=tone;arm.hand.Material=Enum.Material.Concrete;arm.hand.MaterialVariant="MARKED_Skin"
        if arm.thumb then arm.thumb.Color=tone;arm.thumb.Material=Enum.Material.Concrete;arm.thumb.MaterialVariant="MARKED_Skin" end
        -- bare forearm (tee): no cuff; otherwise a cuff a shade darker than the sleeve
        local bare=lower and (lower.MaterialVariant=="MARKED_Skin" or (lower.Material==Enum.Material.Plastic and lower.MaterialVariant==""))
        if arm.cuff then
            arm.cuff.Transparency=bare and 1 or 0
            if lower and not bare then arm.cuff.Color=lower.Color:Lerp(Color3.new(0,0,0),.3);arm.cuff.Material=lower.Material;arm.cuff.MaterialVariant=lower.MaterialVariant end
        end
    end
end
function Model:Pose(boardFrame,shoulders,time,activity,state,character)
    self:Dress(character)
    self.boardFrame=boardFrame;self.character=character
    for _,entry in ipairs(self.pieces) do entry.part.CFrame=boardFrame*entry.offset end
    if self.device then return self:PoseTyping(boardFrame,shoulders,time,activity,state) end
    local row=state.rows[#state.rows]
    local column=row and #row.cells or 0
    local writing=math.max(0,1-(time-activity)/0.24)
    -- Front-face canvas runs from local +X (left on the page) toward -X.
    local x=0.41-math.min(7,math.max(0,column-1))*0.123
    local y=0.54-math.max(0,#state.rows-1)*0.285
    local cross=row and (row.rejected or (row.cells[column] and row.cells[column].crossed))
    local stroke=cross and (0.5-writing)*0.11 or math.sin(time*65)*0.035
    if row and row.rejected and writing>0 then x=0.46-(1-writing)*0.98;stroke=0 end
    -- Rest the pen at the right margin; only reach across the page while writing.
    x=-.54+(x+.54)*writing;y=.02+(y-.02)*writing
    local tip=boardFrame:PointToWorldSpace(Vector3.new(x+stroke*writing,y+math.cos(time*47)*writing*0.025,-0.09-(1-writing)*0.09))
    local direction=(boardFrame.UpVector*0.8-boardFrame.RightVector*0.5+boardFrame.LookVector*0.3).Unit
    self.penDirection=direction
    local right=boardFrame.RightVector:Cross(direction).Unit
    self.pencil.CFrame=CFrame.fromMatrix(tip,right,direction,right:Cross(direction))*self.penOffset
    local grips={Left=boardFrame:PointToWorldSpace(Vector3.new(0.59,-0.57,0.03)),Right=tip+direction*0.32}
    for side,arm in pairs(self.arms) do
        local shoulder=shoulders[side]
        local hand=grips[side]
        local delta=hand-shoulder
        local axis=delta.Magnitude>.01 and delta.Unit or Vector3.new(0,0,-1)
        local outward=boardFrame.RightVector*(side=="Left"and 1 or -1)-boardFrame.UpVector*.8
        local bend=outward-axis*outward:Dot(axis)
        bend=bend.Magnitude>.01 and bend.Unit or Vector3.new(0,-1,0)
        local elbow=shoulder:Lerp(hand,.5)+bend*math.sqrt(math.max(.015,1.15^2-(delta.Magnitude*.5)^2))
        segment(arm.upper,shoulder,elbow,arm.upperWidth,arm.upperDepth);segment(arm.lower,elbow,hand,arm.lowerWidth,arm.lowerDepth)
        arm.hand.CFrame=CFrame.lookAt(hand,hand+direction)*CFrame.Angles(math.pi/2,0,0)
        if arm.cuff then
            local along=(hand-elbow).Magnitude>.01 and (hand-elbow).Unit or axis
            local at=hand-along*.12
            arm.cuff.CFrame=CFrame.lookAt(at,at+along)*CFrame.Angles(math.pi/2,0,0)
        end
        if arm.thumb then arm.thumb.CFrame=arm.hand.CFrame*CFrame.new(side=="Left" and .17 or -.17,.04,-.1)*CFrame.Angles(0,0,side=="Left" and -.5 or .5) end
    end
    return grips
end
-- Show or hide the notebook and pen (the arms stay). Used to holster the book in first person.
-- ghost: drawn almost fully transparent (used to warm up meshes, textures and fonts before first use)
function Model:SetNotebookVisible(visible,ghost)
    local value=visible and (ghost and .985 or 0) or 1
    if self.notebookValue==value then return end
    self.notebookValue=value;self.notebookVisible=visible
    for _,entry in ipairs(self.pieces) do entry.part.LocalTransparencyModifier=(self.bookHidden or (self.backStowed and entry.backHide)) and 1 or value end
    self.pencil.LocalTransparencyModifier=value
    local gui=self.paper:FindFirstChild("PaperInk")
    if gui then gui.Enabled=visible and not (self.backStowed and self.devDef and self.devDef.backHide) end
end
-- the pen spin (inspect): the book itself is hidden, the pen stays (kept hidden every frame while on: other code
-- may reset the pieces' transparency)
function Model:SetBookHidden(on)
    on=on==true
    if not on and not self.bookHidden then return end
    self.bookHidden=on
    local value=self.notebookValue or 0
    for _,entry in ipairs(self.pieces)do entry.part.LocalTransparencyModifier=on and 1 or ((self.backStowed and entry.backHide) and 1 or value) end
    local gui=self.paper:FindFirstChild("PaperInk")
    if gui then gui.Enabled=not on and self.notebookVisible~=false end
end
-- typing gear on your back: fold away its backHide parts (the keyboard's screen and cable) while it's stowed
function Model:SetBackStowed(on)
    on=on==true
    if self.backStowed==on then return end
    self.backStowed=on
    local value=self.notebookValue or 0
    for _,entry in ipairs(self.pieces)do if entry.backHide then entry.part.LocalTransparencyModifier=on and 1 or value end end
    local gui=self.paper:FindFirstChild("PaperInk")
    if gui and self.devDef and self.devDef.backHide then gui.Enabled=self.notebookVisible~=false and not on end
end
-- where typing gear sits on your back (the board frame for Pose), from the torso; nil for the notebook
function Model:BackFrame(torso)
    local def,b=self.devDef,self.devBounds
    if not def or not b then return nil end
    local tc=torso.CFrame
    local L,U,R=tc.LookVector,tc.UpVector,tc.RightVector
    local backSurface=tc.Position-L*(torso.Size.Z*.5+.04)
    local lo,hi=b[1],b[2]
    if def.back=="flat" then
        -- flat on the back: its base against you (board -Y into the back), keys facing out, the space bar edge up
        local zc,xc=(lo.Z+hi.Z)/2,(lo.X+hi.X)/2
        local origin=backSurface+L*lo.Y+U*(.12+zc)-R*xc
        return CFrame.fromMatrix(origin,R,-L)
    end
    -- upright: standing on your back, its rear against you (board +Z forward), keys facing out, the sheet up top
    local yc,xc=(lo.Y+hi.Y)/2,(lo.X+hi.X)/2
    local origin=backSurface-L*hi.Z+U*(.18-yc)+R*xc
    return CFrame.fromMatrix(origin,-R,U)
end
-- Pose the arms to free hand targets: targets[side]={shoulder=,hand=,bend=,dir=}.
-- bend is the direction the elbow points; dir is the way the hand faces (defaults to along the forearm).
function Model:PoseArms(targets,character)
    self:Dress(character)
    for side,arm in pairs(self.arms) do
        local t=targets[side]
        if t then
            local shoulder,hand=t.shoulder,t.hand
            local delta=hand-shoulder
            local axis=delta.Magnitude>.01 and delta.Unit or Vector3.new(0,0,-1)
            local bend=t.bend-axis*t.bend:Dot(axis)
            bend=bend.Magnitude>.01 and bend.Unit or Vector3.new(0,-1,0)
            local elbow=shoulder:Lerp(hand,.5)+bend*math.sqrt(math.max(.015,1.15^2-(delta.Magnitude*.5)^2))
            segment(arm.upper,shoulder,elbow,arm.upperWidth,arm.upperDepth);segment(arm.lower,elbow,hand,arm.lowerWidth,arm.lowerDepth)
            local along=(hand-elbow).Magnitude>.01 and (hand-elbow).Unit or axis
            -- dir: the pen-grip facing; dirBlend eases the hand from that facing to following the forearm
            local dir=along
            if t.dir then
                local mixed=t.dir*(1-(t.dirBlend or 0))+along*(t.dirBlend or 0)
                dir=mixed.Magnitude>.01 and mixed.Unit or along
            end
            arm.hand.CFrame=CFrame.lookAt(hand,hand+dir)*CFrame.Angles(math.pi/2,0,0)
            if arm.cuff then
                local at=hand-along*.12
                arm.cuff.CFrame=CFrame.lookAt(at,at+along)*CFrame.Angles(math.pi/2,0,0)
            end
            if arm.thumb then arm.thumb.CFrame=arm.hand.CFrame*CFrame.new(side=="Left" and .17 or -.17,.04,-.1)*CFrame.Angles(0,0,side=="Left" and -.5 or .5) end
        end
    end
end
-- typing gear: both hands hover over the keys; the hand for the key just pressed dips onto it
function Model:PoseTyping(boardFrame,shoulders,time,activity,state)
    local row=state.rows[#state.rows]
    local column=row and #row.cells or 0
    local writing=math.max(0,1-(time-activity)/0.24)
    local down=-boardFrame.UpVector
    local into=-boardFrame.LookVector -- from the keys toward the paper / screen
    local direction=(into*.75+down*.65).Unit
    self.penDirection=direction
    local grips={}
    for side,offset in pairs(self.devGrip) do
        local base=boardFrame:PointToWorldSpace(offset)
        local pressing=column>0 and ((column%2==1)==(side=="Right"))
        local hover=self.devDef and self.devDef.hover or .07
        local dip=pressing and math.sin(writing*math.pi)*math.max(.03,hover) or 0
        local drift=math.sin(time*6+(side=="Left" and 0 or 2.2))*.015
        grips[side]=base-down*(hover-dip)+boardFrame.RightVector*drift
    end
    for side,arm in pairs(self.arms) do
        local shoulder=shoulders[side]
        local hand=grips[side]
        local delta=hand-shoulder
        local axis=delta.Magnitude>.01 and delta.Unit or Vector3.new(0,0,-1)
        local outward=boardFrame.RightVector*(side=="Left"and 1 or -1)-boardFrame.UpVector*.8
        local bend=outward-axis*outward:Dot(axis)
        bend=bend.Magnitude>.01 and bend.Unit or Vector3.new(0,-1,0)
        local elbow=shoulder:Lerp(hand,.5)+bend*math.sqrt(math.max(.015,1.15^2-(delta.Magnitude*.5)^2))
        segment(arm.upper,shoulder,elbow,arm.upperWidth,arm.upperDepth);segment(arm.lower,elbow,hand,arm.lowerWidth,arm.lowerDepth)
        arm.hand.CFrame=CFrame.lookAt(hand,hand+direction)*CFrame.Angles(math.pi/2,0,0)
        if arm.cuff then
            local along=(hand-elbow).Magnitude>.01 and (hand-elbow).Unit or axis
            local at=hand-along*.12
            arm.cuff.CFrame=CFrame.lookAt(at,at+along)*CFrame.Angles(math.pi/2,0,0)
        end
        if arm.thumb then arm.thumb.CFrame=arm.hand.CFrame*CFrame.new(side=="Left" and .17 or -.17,.04,-.1)*CFrame.Angles(0,0,side=="Left" and -.5 or .5) end
    end
    return grips
end
function Model:AnchorToPalms(palms,grips)
    if self.device then
        -- the machine sits between both hands: shift it so the keys are under the palms
        -- (eased in: the hands lag a frame or two behind, and snapping to them made it jolt as it arrived)
        if palms.Left and palms.Right and grips and grips.Left and grips.Right then
            local target=(palms.Left+palms.Right)/2-(grips.Left+grips.Right)/2
            self.anchorShift=(self.anchorShift or Vector3.zero):Lerp(target,.25)
            for _,entry in ipairs(self.pieces)do entry.part.CFrame=entry.part.CFrame+self.anchorShift end
        end
        return
    end
    -- Presentation offsets only: do not alter the already accepted arm pose.
    local torso=self.character and (self.character:FindFirstChild("UpperTorso")or self.character:FindFirstChild("Torso"))
    local forward=torso and torso.CFrame.LookVector or self.boardFrame.LookVector*-1
    local up=torso and torso.CFrame.UpVector or Vector3.yAxis
    if palms.Left then
        -- Support the middle of the binding rather than balancing the bottom
        -- corner on the wrist (which lifted the book into the shoulder).
        local frame=self.boardFrame*CFrame.Angles(.46,0,0)
        local binding=frame:PointToWorldSpace(Vector3.new(.57,-.10,-.03))
        frame=frame+(palms.Left+forward*.13-binding)
        for _,entry in ipairs(self.pieces)do entry.part.CFrame=frame*entry.offset end
    end
    if palms.Right then
        -- Expose the barrel above the knuckles instead of burying it inside
        -- the large rigid R6 hand. Preserve the pen's calibrated mesh basis.
        local side=torso and torso.CFrame.RightVector or self.boardFrame.RightVector*-1
        local grip=palms.Right+forward*.34+side*.08+up*.10
        self.pencil.CFrame=self.pencil.CFrame+(grip-grips.Right)
    end
end
-- cw: the gear colourway (Numberfall.GearColorways; nil / Original = as modelled)
function Model:Finish(id,cw)
    local catalog=require(game:GetService("ReplicatedStorage"):WaitForChild("Numberfall"):WaitForChild("Catalog"))
    local found
    for _,item in ipairs(catalog)do if item.Id==id then found=item end end
    self:Device(found and found.Device and DEVICES[found.Device] and found or nil,cw)
    if not self.device then
        -- the notebook: a dyed cover; a dyed notebook also gets a clean ruled page over its paper (the dye is for the
        -- cover: it would tint the page you write on too)
        self.board.Color=Color3.new(1,1,1);self.pencil.Color=Color3.new(1,1,1)
        local tinted=Gear.Tinted(cw)
        Gear.PaintPart(self.board,"Notebook",tinted and cw or nil)
        self.paper.Transparency=tinted and 0 or 1
        self.paper.Color=Color3.fromRGB(244,240,230);self.paper.Material=Enum.Material.SmoothPlastic
        if self.rules then self.rules.Visible=tinted end
    end
end
-- build the typing gear for this Catalog item (or put the notebook and pen back when item is nil)
local PAPER_SIZE,PAPER_OFFSET=Vector3.new(1.096,1.587,.002),CFrame.new(0,0,-.090)
function Model:Device(item,cw)
    local gone={}
    for _,p in ipairs(self.devParts or {})do gone[p]=true;p:Destroy() end
    for i=#self.pieces,1,-1 do if gone[self.pieces[i].part] then table.remove(self.pieces,i) end end
    self.devParts={}
    local def=item and DEVICES[item.Device]
    local L=def and deviceLayout(def)
    if not L then def=nil end -- (the model isn't loaded: keep the notebook for now)
    -- third person: typing gear is built bigger (scale3, about the board frame), or at the hand-held size it was lost
    -- under an avatar's hands and forearms
    local k=(def and not self.firstPerson) and (def.scale3 or 1) or 1
    local function sc(cf) return CFrame.new(cf.Position*k)*cf.Rotation end
    self.device=def and item.Device or nil
    self.devGrip=L and {Left=L.grip.Left*k,Right=L.grip.Right*k} or nil
    self.devFP=def and def.fp or nil
    self.devDef=def;self.devBounds=L and {L.bounds[1]*k,L.bounds[2]*k} or nil;self.backStowed=false
    local paperEntry
    for _,e in ipairs(self.pieces)do if e.part==self.paper then paperEntry=e end end
    local font,strike=Enum.Font.PermanentMarker,ink
    if def then
        self.board.Transparency=1;self.pencil.Transparency=1
        -- the writing surface stays invisible: the sheet / screen behind it is the machine's own part
        self.paper.Size=L.surface.size*k;self.paper.Transparency=1
        if self.rules then self.rules.Visible=false end
        if paperEntry then paperEntry.offset=sc(L.surface.cf) end
        self.ink=def.ink or rgb(item.Pencil);self.okInk=def.ok
        font,strike=def.font,def.strike or self.ink
        for _,e in ipairs(L.parts)do
            local p
            if e.src then
                p=e.src:Clone()
                for _,d in ipairs(p:GetChildren())do if not (d:IsA("SurfaceAppearance") or d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("Texture")) then d:Destroy() end end
            else
                p=Instance.new("Part");p.Color=e.color
            end
            if e.props then for k,v in pairs(e.props)do p[k]=v end end
            if e.src then Gear.PaintPart(p,e.name,cw) end
            p.Name="Device"..e.name;p.Size=e.size*k
            p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery,p.CastShadow,p.Massless=true,false,false,false,false,true
            p.LocalTransparencyModifier=self.notebookValue or 0
            p.Parent=self.model
            table.insert(self.pieces,{part=p,offset=sc(e.cf),backHide=def.backHide and def.backHide[e.name] or nil});table.insert(self.devParts,p)
        end
    else
        self.board.Transparency=0;self.pencil.Transparency=0
        self.paper.Size=PAPER_SIZE;self.paper.Transparency=1
        if paperEntry then paperEntry.offset=PAPER_OFFSET end
        self.ink=nil;self.okInk=nil
    end
    for r=1,4 do
        for c=1,8 do local v=self.cells[r][c];v.label.Font=font;v.label.TextSize=43*(def and def.textScale or 1);v.strike.BackgroundColor3=strike end
        self.cells[r].strike.BackgroundColor3=strike
    end
    if self.boardFrame then for _,e in ipairs(self.pieces)do e.part.CFrame=self.boardFrame*e.offset end end
end
function Model:Destroy() self.model:Destroy() end
return Model
