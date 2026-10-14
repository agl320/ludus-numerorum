-- Where the LED visor sits on a head and how big it is. Shared by ServerScriptService.VisorDisplay (real
-- characters) and the Loadout preview, so a hairstyle previewed in the menu shows the visor exactly as in game.
-- The visor is worn OVER the bangs: the hairstyle's pad (studs, 1.2-wide head) pushes the ring's FRONT forward
-- (deeper ring, shifted forward, back stays on the head) and only widens the sides a little, so it never balloons.
local F={}
F.MESH_SIZE=Vector3.new(1.50800,0.37181,1.54824)
F.BOX_CENTRE=Vector3.new(0,0.01246,-0.02288)
F.DESIGN_HEAD=1.2
F.RING_INNER=Vector2.new(0.62,0.65)
F.HEAD_SINK=0.02
F.MESH_FLIP=CFrame.Angles(0,math.pi,0)
F.SIDE=0.3      -- share of the pad added to the sides
local function half(head)
 local mesh=head:FindFirstChildOfClass("SpecialMesh")
 if mesh and mesh.MeshType==Enum.MeshType.Head then return mesh.Scale.X/2,mesh.Scale.Z/2 end
 return head.Size.X/2,head.Size.Z/2
end
-- returns the mesh scale and the weld C0 (head -> visor handle)
function F.Compute(head,padStuds,config)
 local hx,hz=half(head)
 local pad=(padStuds or 0)*head.Size.X/F.DESIGN_HEAD
 local scale=Vector3.new(
  math.max((hx+pad*F.SIDE-F.HEAD_SINK)/F.RING_INNER.X,0.5),
  math.max(math.max(hx,hz)*2/F.DESIGN_HEAD,0.5),
  math.max((hz+pad*0.5-F.HEAD_SINK)/F.RING_INNER.Y,0.5))
 local lift=((config and config.Visor and config.Visor.HeightOffset) or 0.05)*head.Size.Y
 local frame=CFrame.new(0,lift,-pad*0.5)*CFrame.new(F.BOX_CENTRE*scale)
 return scale,frame*F.MESH_FLIP
end
return F
