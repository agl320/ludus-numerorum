-- Shared whitelist: the client cannot persist arbitrary fields or invalid values.
local Settings={}
Settings.Items={
 {Id="Volume",Label="Sound volume",Values={0,.25,.5,.75,1},Default=.75},
 {Id="MusicVolume",Label="Music volume",Values={0,.25,.5,.75,1},Default=.75},
 {Id="TypingSounds",Label="Typing sounds",Values={true,false},Default=true},
 {Id="Sensitivity",Label="Mouse sensitivity",Values={.25,.5,.75,1,1.25,1.5,2},Default=1},
 -- (no field of view setting: the camera is fixed, capped at 80 -- Config.Feel.MaxFOV)
 {Id="ReducedMotion",Label="Reduce camera motion",Values={false,true},Default=false},
 {Id="Flashes",Label="Elimination flashes",Values={true,false},Default=true},
 {Id="Captions",Label="Sound captions",Values={false,true},Default=false},
 {Id="SprintMode",Label="Sprint mode",Values={"Hold","Toggle","Always"},Default="Hold"},
 -- (Q dashes, E opens number entry and CTRL crouches, so none of those can be picked here)
 {Id="SprintKey",Label="Sprint key",Values={"LeftShift","RightShift"},Default="LeftShift"}, -- (Caps Lock frees the mouse)
 {Id="SlideKey",Label="Slide key",Values={"C","X","Z","V"},Default="C"},
 {Id="JumpBuffer",Label="Jump buffering",Values={true,false},Default=true},
 {Id="LowEnd",Label="Low end mode",Values={false,true},Default=false}, -- fewer lights / shadows / effects; forced on for mobile (LowEndMode)
 {Id="Killfeed",Label="Elimination feed",Values={true,false},Default=true},
 {Id="ShowStats",Label="Performance stats",Values={false,true},Default=false}, -- FPS / frame time / ping overlay (FPSCounter)
}
function Settings.Sanitize(raw)
 local result={}
 for _,item in ipairs(Settings.Items) do
  result[item.Id]=item.Default
  for _,value in ipairs(item.Values) do if type(raw)=="table" and raw[item.Id]==value then result[item.Id]=value end end
 end
 return result
end
return Settings
