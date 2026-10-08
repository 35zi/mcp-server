local H=game:GetService("ChangeHistoryService")
local Http=game:GetService("HttpService")
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local ink=rgb(22,25,30)
local function has(n,s) return string.find(n,s,1,true)~=nil end
local function colorFor(model,n)
 if model=="mouse" then
  if has(n,"Inner_Ear") or has(n,"Tail_") then return rgb(220,151,174)
  elseif has(n,"Cheek_") then return rgb(227,145,172)
  elseif has(n,"Nose") then return rgb(221,119,153)
  elseif has(n,"Eye_") or has(n,"Mouth") then return ink
  elseif has(n,"Tooth_") then return rgb(248,244,225)
  elseif has(n,"Muzzle") then return rgb(221,224,228)
  elseif has(n,"Whisker_") then return rgb(233,233,223)
  elseif has(n,"Foot_") then return rgb(219,164,182)
  elseif has(n,"Head") then return rgb(157,164,177)
  else return rgb(140,148,162) end
 elseif model=="hedgehog" then
  if has(n,"Eye_") or has(n,"Nose") or has(n,"Mouth") then return ink
  elseif has(n,"Inner_Ear") then return rgb(204,145,130)
  elseif has(n,"Quill_") then
   local digit=tonumber(string.match(n,"(%d+)$")) or 0
   return digit%2==0 and rgb(92,61,38) or rgb(119,82,48)
  elseif has(n,"Muzzle") then return rgb(230,202,156)
  elseif has(n,"Head") or has(n,"Ear_") then return rgb(205,168,120)
  elseif has(n,"Foot_") then return rgb(143,104,69)
  else return rgb(124,88,56) end
 elseif model=="duckling" then
  if has(n,"Eye_") then return ink
  elseif has(n,"Nostril_") then return rgb(119,70,35)
  elseif has(n,"Bill_Lower") then return rgb(231,131,37)
  elseif has(n,"Bill_") or has(n,"Foot_") or has(n,"Leg_") then return rgb(250,161,47)
  elseif has(n,"Wing_Feather") then return rgb(255,221,79)
  elseif has(n,"Wing_") then return rgb(241,190,43)
  elseif has(n,"Head") then return rgb(255,232,91)
  else return rgb(255,216,60) end
 elseif model=="frog" then
  if has(n,"Pupil_") or has(n,"Smile") then return ink
  elseif has(n,"Nostril_") then return rgb(43,87,42)
  elseif has(n,"Eye_Panel") then return rgb(241,240,198)
  elseif has(n,"Belly_Panel") then return rgb(213,229,151)
  elseif has(n,"Hind_") or has(n,"Front_Leg") then return rgb(65,145,63)
  elseif has(n,"Toe_") then return rgb(105,182,78)
  elseif has(n,"Head") or has(n,"Eye_Bump") then return rgb(99,184,79)
  else return rgb(80,163,68) end
 elseif model=="revolver" then
  if has(n,"Grip_Panel") then return rgb(155,96,54)
  elseif has(n,"Grip_Core") then return rgb(87,52,33)
  elseif has(n,"Grip_Screw") then return rgb(185,193,201)
  elseif has(n,"Front_Sight") then return rgb(240,151,55)
  elseif has(n,"Rear_Sight") then return rgb(37,44,55)
  elseif has(n,"Cylinder_Release") then return rgb(62,73,89)
  elseif n=="Revolver_Cylinder" then return rgb(130,141,155)
  elseif has(n,"Ejector") then return rgb(157,168,180)
  elseif has(n,"Hammer") or has(n,"Trigger") then return rgb(73,83,98)
  elseif has(n,"Barrel_Rib") then return rgb(66,78,96)
  elseif has(n,"Barrel") or has(n,"Underlug") then return rgb(83,97,116)
  else return rgb(104,118,137) end
 end
end
local targets={}
local totals={}
local backup={}
for _,name in {"mouse","hedgehog","duckling","frog","revolver"} do
 local m=workspace:FindFirstChild(name)
 assert(m and m:IsA("Model"),"Missing imported model: "..name)
 totals[name]=0
 for _,p in m:GetDescendants() do
  if p:IsA("BasePart") then
   assert(string.sub(p.Name,1,#name+1):lower()==name.."_","Unexpected part in import: "..p:GetFullName())
   local texture=p:IsA("MeshPart") and p.TextureID or nil
   local surface={}
   for _,s in p:GetChildren() do
    if s:IsA("SurfaceAppearance") then
     table.insert(surface,{instance=s,colorMap=s.ColorMap,normalMap=s.NormalMap,metalnessMap=s.MetalnessMap,roughnessMap=s.RoughnessMap,alphaMode=s.AlphaMode})
    end
   end
   table.insert(targets,{part=p,model=name,color=colorFor(name,p.Name)})
   table.insert(backup,{path=p:GetFullName(),color={p.Color.R,p.Color.G,p.Color.B}})
   targets[#targets].unchanged={texture=texture,material=p.Material,variant=p.MaterialVariant,size=p.Size,cf=p.CFrame,mesh=p:IsA("MeshPart") and p.MeshId or nil,surface=surface,children=#p:GetChildren()}
   totals[name]+=1
  end
 end
end
assert(#targets==155,"Expected 155 imported mesh parts, found "..#targets)
H:SetWaypoint("Before coloring imported animals and revolver")
local ok,err=pcall(function()
 for _,t in targets do t.part.Color=t.color end
 for _,t in targets do
  local p,u=t.part,t.unchanged
  assert(p.Color==t.color,"Color mismatch: "..p.Name)
  assert(p.Material==u.material and p.MaterialVariant==u.variant and p.CFrame==u.cf and p.Size==u.size and #p:GetChildren()==u.children,"Non-color property changed: "..p.Name)
  if p:IsA("MeshPart") then assert(p.TextureID==u.texture and p.MeshId==u.mesh,"Mesh/texture changed: "..p.Name) end
  for _,s in u.surface do assert(s.instance.Parent==p and s.instance.ColorMap==s.colorMap and s.instance.NormalMap==s.normalMap and s.instance.MetalnessMap==s.metalnessMap and s.instance.RoughnessMap==s.roughnessMap and s.instance.AlphaMode==s.alphaMode,"Surface maps changed: "..p.Name) end
 end
end)
if not ok then
 for i,t in targets do local c=backup[i].color t.part.Color=Color3.new(c[1],c[2],c[3]) end
 error(err)
end
H:SetWaypoint("Colored imported animals and revolver")
return Http:JSONEncode({colored=#targets,models=totals,onlyColorChanged=true,originalColors=backup})
