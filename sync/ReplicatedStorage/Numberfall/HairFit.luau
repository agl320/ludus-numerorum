-- One source of truth for where a hairstyle sits on a head and how it's tinted.
-- Used by ServerScriptService.Hair (the real character) and the Loadout/Shop thumbnails (client),
-- so what you see in the menu is exactly what you get in game.
local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS:WaitForChild("Numberfall"):WaitForChild("HairCatalog"))
local Models=RS.Numberfall:WaitForChild("HairModels")
local Fit={}
local DESIGN_HEAD=1.2

-- Styles whose accessory attachment data is wrong: explicit handle centre relative to the head centre,
-- in studs for a 1.2-wide head (+Y up, -Z = face), then an optional rotation and size multiplier.
local OVERRIDE={
 WolfShag    ={Vector3.new(0,0.30,0.06)},
 WolfShoulder={Vector3.new(0,-0.20,0.06)},
 WolfStorm   ={Vector3.new(0,0.12,0.04)},
 -- old girl hat meshes (no hair attachment, sized for other heads): placed, turned and resized by eye
 GirlWavy     ={Vector3.new(0.1,-1.42,0.02),CFrame.Angles(0,math.pi,0)*CFrame.Angles(math.rad(20),0,0),0.86}, -- faces backwards; tipped forward so the crown covers the head
 GirlSpaceBuns={Vector3.new(0,-0.6,0.1)},
 GirlBraids   ={Vector3.new(0,0.27,0.07),nil,1.24},
 GirlBraidBun ={Vector3.new(0,0.33,0.3),nil,1.1},
}
Fit.Override=OVERRIDE
-- The visor is worn OVER the bangs: its ring is widened by this much (studs, 1.2-wide head) for each style.
local VISOR_PAD={
 -- (enough to clear each style's bangs: any less and the fringe pokes through and hides the numbers)
 WolfMessy=0.16, WolfLayered=0.05, WolfShag=0.26, WolfFluff=0.36, WolfStorm=0.10,
 WolfSweep=0.10, WolfShoulder=0.05, WolfPony=0.05, WolfBob=0.06, EmoSidePony=0.10,
 GirlPigtails=0.08, GirlBraidBun=0.10, GirlBraids=0.10, GirlSpaceBuns=0.22, GirlWavy=0.18,
}
Fit.VisorPad=VISOR_PAD

local colors={}
for _,c in ipairs(Catalog.Colors)do colors[c.Id]=c end

function Fit.Template(styleId)
 return Models:FindFirstChild(styleId or Catalog.DefaultStyle) or Models:FindFirstChild(Catalog.DefaultStyle)
end

-- Handle offset relative to the head's CFrame, plus the uniform scale applied to the mesh.
function Fit.Offset(head,styleId)
 local tpl=Fit.Template(styleId);local h=tpl and tpl:FindFirstChild("Handle");if not h then return nil end
 local scale=head.Size.X/DESIGN_HEAD
 local o=OVERRIDE[tpl.Name]
 if o then return CFrame.new(o[1]*scale)*(o[2] or CFrame.identity),scale*(o[3] or 1) end
 local headAtt=head:FindFirstChild("HairAttachment")
 local headCF=headAtt and headAtt.CFrame or CFrame.new(0,head.Size.Y/2,0)
 local a=h:FindFirstChild("HairAttachment");local hairCF=a and a.CFrame or CFrame.new()
 hairCF=CFrame.new(hairCF.Position*scale)*(hairCF-hairCF.Position)
 return headCF*hairCF:Inverse(),scale
end

-- Tint. A texture can only be multiplied by VertexColor, so only light (greyscale) textures take a colour.
-- Most of these hairs ship with near-black textures: for those, any colour other than Ink drops the texture
-- and shows the mesh in the flat colour (the strand geometry still gives it shape and shading).
local TEXTURE_TINT={WolfLayered=true,GirlSpaceBuns=true,GirlWavy=true}           -- light textures: tint through the texture
Fit.TextureTint=TEXTURE_TINT
function Fit.Tint(handle,colorId)
 local c=colors[colorId or Catalog.DefaultColor] or colors[Catalog.DefaultColor]
 local sm=handle:FindFirstChildWhichIsA("SpecialMesh")
 local rgb=Vector3.new(c.Color[1],c.Color[2],c.Color[3])/255
 handle.Color=Color3.new(rgb.X,rgb.Y,rgb.Z)
 if not sm then
  -- catalog hair (a textured MeshPart): Ink keeps its own texture, any other colour shows the mesh in that colour
  if handle:IsA("MeshPart") then
   local tex=handle:GetAttribute("HairTexture")
   if tex==nil then tex=handle.TextureID;handle:SetAttribute("HairTexture",tex) end
   pcall(function() handle.TextureID=(c.Id==Catalog.DefaultColor) and tex or "" end)
  end
  return
 end
 local orig=handle:GetAttribute("HairTexture")
 if orig==nil then orig=sm.TextureId;handle:SetAttribute("HairTexture",orig) end
 local style=handle:GetAttribute("HairStyleId") or (handle.Parent and handle.Parent:GetAttribute("StyleId"))
 local light=TEXTURE_TINT[style]
 if orig=="" then sm.TextureId="";sm.VertexColor=Vector3.one
 elseif c.Id==Catalog.DefaultColor then sm.TextureId=orig;sm.VertexColor=Vector3.one*(light and 0.16 or 0.38)  -- ink
 elseif light then sm.TextureId=orig;sm.VertexColor=rgb*3
 else sm.TextureId="";sm.VertexColor=Vector3.one end
end

-- Hair under a hood: a head item flagged CoversHair (attribute on its Handle, e.g. the cat hood) tucks the hair in,
-- shrinking it toward the head centre so the hood shows instead of being buried in the strands. Idempotent: the
-- untucked size / weld are kept as attributes, so taking the hood off (or switching item) restores the hair.
-- Call with the character (or a preview copy) after the hair or the head item changes.
local TUCK={WolfFluff=0.72,WolfShag=0.74,EmoSidePony=1}
Fit.Tuck=TUCK
function Fit.ApplyTuck(model)
 local head=model and model:FindFirstChild("Head")
 local hair=model and model:FindFirstChild("Hair");local h=hair and hair:FindFirstChild("Handle")
 local w=h and h:FindFirstChild("HairWeld")
 if not(head and h and w) then return end
 local mask=model:FindFirstChild("FaceMask");local mh=mask and mask:FindFirstChild("Handle")
 local covers=mh~=nil and mh:GetAttribute("CoversHair")==true
 local style=h:GetAttribute("HairStyleId") or hair:GetAttribute("StyleId")
 local f=covers and (TUCK[style] or 0.78) or 1
 if (h:GetAttribute("TuckF") or 1)==f then return end
 local sm=h:FindFirstChildWhichIsA("SpecialMesh")
 if h:GetAttribute("TuckSize")==nil then
  h:SetAttribute("TuckSize",h.Size);h:SetAttribute("TuckC0",w.C0)
  if sm then h:SetAttribute("TuckMesh",sm.Scale) end
 end
 local size,c0,ms=h:GetAttribute("TuckSize"),h:GetAttribute("TuckC0"),h:GetAttribute("TuckMesh")
 if sm and ms then sm.Scale=ms*f end
 h.Size=size*f
 local nc=(f==1) and c0 or CFrame.new(c0.Position*f-Vector3.new(0,0.05*head.Size.X/DESIGN_HEAD,0))*c0.Rotation
 w.C0=nc
 if h.Anchored then h.CFrame=head.CFrame*nc end
 h:SetAttribute("TuckF",f)
end

-- Build a ready-to-weld handle clone for `head` (not parented).
function Fit.Build(head,styleId,colorId)
 local tpl=Fit.Template(styleId);local src=tpl and tpl:FindFirstChild("Handle");if not src then return nil end
 local offset,scale=Fit.Offset(head,styleId)
 local h=src:Clone();h.Name="Handle";h:SetAttribute("HairStyleId",tpl.Name)
 h.Anchored,h.CanCollide,h.CanTouch,h.CanQuery,h.Massless=false,false,false,false,true
 h.Material=Enum.Material.SmoothPlastic
 local sm=h:FindFirstChildWhichIsA("SpecialMesh");if sm then sm.Scale=sm.Scale*scale end
 h.Size=src.Size*scale
 Fit.Tint(h,colorId)
 h.CFrame=head.CFrame*offset
 return h,offset,tpl.Name
end
return Fit
