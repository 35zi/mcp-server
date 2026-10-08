local Http=game:GetService("HttpService")
local History=game:GetService("ChangeHistoryService")
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function has(n,s) return string.find(n,s,1,true)~=nil end
local dark=rgb(39,46,57)
local steel=rgb(99,113,131)
local function palette(kind,n)
 if kind=="Shotgun" then
  if has(n,"Stock_Panel") then return rgb(163,102,57)
  elseif has(n,"Stock_Core") then return rgb(111,66,38)
  elseif has(n,"Pump_Rib") then return rgb(127,76,42)
  elseif has(n,"Pump_") then return rgb(160,99,54)
  elseif has(n,"Butt_Pad") then return rgb(35,39,46)
  elseif has(n,"Ejection_Port") or has(n,"Loading_Port") then return rgb(25,31,40)
  elseif has(n,"Front_Sight") then return rgb(245,160,65)
  elseif has(n,"Safety") then return rgb(160,53,44)
  elseif has(n,"Receiver_Top") then return rgb(73,86,104)
  elseif has(n,"Barrel_Band") then return steel
  elseif has(n,"Barrel") or has(n,"Magazine_Tube") then return rgb(72,85,103)
  elseif has(n,"Trigger") then return rgb(56,66,81)
  else return steel end
 elseif kind=="BoltSniper" then
  if has(n,"Lens") then return rgb(84,169,189)
  elseif has(n,"Stock_Panel") then return rgb(111,130,77)
  elseif has(n,"Stock_Core") or has(n,"Forestock") then return rgb(75,92,54)
  elseif has(n,"Cheek_Rest") or has(n,"Pistol_Grip") then return rgb(48,62,43)
  elseif has(n,"Butt_Pad") then return rgb(29,35,38)
  elseif has(n,"Ejection_Window") then return rgb(24,31,40)
  elseif has(n,"Bolt_Handle_Knob") then return rgb(49,59,73)
  elseif has(n,"Bolt_Handle") or has(n,"Bolt_Housing") then return rgb(161,173,186)
  elseif has(n,"Scope_Mount") or has(n,"Scope_Rail") then return rgb(65,76,90)
  elseif has(n,"Scope_") then return rgb(41,49,62)
  elseif has(n,"Heavy_Barrel") or has(n,"Muzzle_Brake") then return rgb(65,78,95)
  elseif has(n,"Magazine") or has(n,"Trigger") then return rgb(52,63,76)
  elseif has(n,"Receiver_Side_Plate") then return rgb(110,124,141)
  else return rgb(91,106,125) end
 elseif kind=="AutomaticRifle" then
  if has(n,"Stock_Panel") then return rgb(156,94,50)
  elseif has(n,"Stock_Core") then return rgb(102,59,32)
  elseif has(n,"Handguard_Rib") then return rgb(130,77,38)
  elseif has(n,"Handguard_") then return rgb(164,99,51)
  elseif has(n,"Pistol_Grip") then return rgb(94,55,33)
  elseif has(n,"Butt_Pad") then return rgb(29,34,41)
  elseif has(n,"Magazine_Rib") then return rgb(104,114,130)
  elseif has(n,"Curved_Magazine") then return rgb(74,85,102)
  elseif has(n,"Magazine_") then return rgb(44,54,68)
  elseif has(n,"Ejection_Port") then return rgb(23,30,40)
  elseif has(n,"Selector") or has(n,"Charging_Handle") then return rgb(147,158,175)
  elseif has(n,"Sight") then return rgb(42,52,67)
  elseif has(n,"Receiver_Cover") then return rgb(84,99,119)
  elseif has(n,"Barrel") or has(n,"Gas_") or has(n,"Muzzle_") then return rgb(64,79,101)
  elseif has(n,"Trigger") then return rgb(51,61,77)
  else return rgb(103,118,139) end
 end
end
local definitions={
 {"shotgun","Shotgun",24},
 {"bolt_action_sniper","BoltSniper",33},
 {"automatic_rifle","AutomaticRifle",36}
}
local changes={}
local original={}
local totals={}
for _,def in definitions do
 local model=workspace:FindFirstChild(def[1])
 assert(model and model:IsA("Model"),"Missing import: "..def[1])
 local count=0
 for _,p in model:GetDescendants() do
  if p:IsA("BasePart") then
   assert(string.sub(p.Name,1,#def[2]+1)==def[2].."_","Unexpected part: "..p:GetFullName())
   local old={color=p.Color,cf=p.CFrame,size=p.Size,material=p.Material,variant=p.MaterialVariant,reflectance=p.Reflectance,transparency=p.Transparency,anchored=p.Anchored,collide=p.CanCollide,children=#p:GetChildren(),texture=p:IsA("MeshPart") and p.TextureID,mesh=p:IsA("MeshPart") and p.MeshId,surfaces={}}
   for _,s in p:GetChildren() do
    if s:IsA("SurfaceAppearance") then
     table.insert(old.surfaces,{object=s,colorMap=s.ColorMap,normalMap=s.NormalMap,metalnessMap=s.MetalnessMap,roughnessMap=s.RoughnessMap,alphaMode=s.AlphaMode})
    end
   end
   table.insert(changes,{part=p,color=palette(def[2],p.Name),old=old})
   table.insert(original,{path=p:GetFullName(),color={p.Color.R,p.Color.G,p.Color.B}})
   count+=1
  end
 end
 assert(count==def[3],"Unexpected part count: "..def[1].." "..count)
 totals[def[1]]=count
end
History:SetWaypoint("Before coloring shotgun sniper and automatic rifle")
local ok,err=pcall(function()
 for _,v in changes do v.part.Color=v.color end
 for _,v in changes do
  local p,o=v.part,v.old
  assert(p.Color==v.color,"Color verification failed: "..p.Name)
  assert(p.CFrame==o.cf and p.Size==o.size and p.Material==o.material and p.MaterialVariant==o.variant and p.Reflectance==o.reflectance and p.Transparency==o.transparency and p.Anchored==o.anchored and p.CanCollide==o.collide and #p:GetChildren()==o.children,"Non-color property changed: "..p.Name)
  if p:IsA("MeshPart") then assert(p.MeshId==o.mesh and p.TextureID==o.texture,"Mesh or texture changed: "..p.Name) end
  for _,s in o.surfaces do
   assert(s.object.Parent==p and s.object.ColorMap==s.colorMap and s.object.NormalMap==s.normalMap and s.object.MetalnessMap==s.metalnessMap and s.object.RoughnessMap==s.roughnessMap and s.object.AlphaMode==s.alphaMode,"Surface texture changed: "..p.Name)
  end
 end
end)
if not ok then for _,v in changes do v.part.Color=v.old.color end error(err) end
History:SetWaypoint("Colored shotgun sniper and automatic rifle")
return Http:JSONEncode({coloredParts=#changes,models=totals,onlyColorChanged=true,originalColors=original})
