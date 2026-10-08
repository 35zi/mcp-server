local Http=game:GetService("HttpService")
local History=game:GetService("ChangeHistoryService")
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function has(n,s) return string.find(n,s,1,true)~=nil end
local ink=rgb(22,24,28)
local function colorFor(kind,n)
 if kind=="Scorpion" then
  if has(n,"Eye_") then return ink
  elseif has(n,"Stinger") then return rgb(65, 41,26)
  elseif has(n,"Mandible") then return rgb(103,65,36)
  elseif has(n,"Claw_") or has(n,"Pincer_") then return rgb(206,147,71)
  elseif has(n,"Back_Plate") then return rgb(158,101,46)
  elseif has(n,"Tail_") then return rgb(192,130,57)
  elseif has(n,"Leg_") then return rgb(159,106,48)
  elseif has(n,"Foot_") then return rgb(118,77,37)
  elseif has(n,"Head") then return rgb(207,158,91)
  else return rgb(184,124,56) end
 elseif kind=="Spider" then
  if has(n,"Eye_") then return ink
  elseif has(n,"Fang_") then return rgb(244,232,207)
  elseif has(n,"Foot_") then return rgb( 71, 48,34)
  elseif has(n,"Leg_") then return rgb(106, 75, 51)
  elseif has(n,"Head") then return rgb(148,106, 74)
  elseif has(n,"Abdomen_Panel") then return rgb(126,89, 58)
  else return rgb(96, 68, 50) end
 elseif kind=="Camel" then
  if has(n,"Eye_") or has(n,"Nostril_") then return ink
  elseif has(n,"Inner_Ear") then return rgb(226,157,126)
  elseif has(n,"Muzzle") then return rgb(242,208,154)
  elseif has(n,"Lower_Lip") then return rgb(158,113, 66)
  elseif has(n,"Foot_") or has(n,"Toe_") then return rgb(130, 90, 50)
  elseif has(n,"Tail_Tuft") then return rgb(99,66,37)
  elseif has(n,"Hump") then return rgb(194,143, 74)
  elseif has(n,"Head") or has(n,"Ear_") then return rgb(224,184,123)
  elseif has(n,"Leg_") then return rgb(202,155, 91)
  else return rgb(213,168,105) end
 elseif kind=="Vulture" then
  if has(n,"Eye_") then return ink
  elseif has(n,"Brow") then return rgb( 95, 64, 55)
  elseif has(n,"Collar") then return rgb(232,222,192)
  elseif has(n,"Head") then return rgb(219,157,136)
  elseif has(n,"Neck") then return rgb(191,129,111)
  elseif has(n,"Beak_Hook") then return rgb(195,130,39)
  elseif has(n,"Beak") then return rgb(232,177, 67)
  elseif has(n,"Toe_") or has(n,"Leg_") then return rgb(192,133, 62)
  elseif has(n,"Wing_Feather") then return rgb(104,83, 72)
  elseif has(n,"Wing_") or has(n,"Tail_") then return rgb( 60, 50, 44)
  else return rgb( 90, 70, 58) end
 end
end
local defs={{"scorpion","Scorpion",53},{"spider","Spider",37},{"camel","Camel",33},{"vulture","Vulture",32}}
local changes={}
local original={}
local totals={}
for _,def in defs do
 local model=workspace:FindFirstChild(def[1])
 assert(model and model:IsA("Model"),"Missing import: "..def[1])
 local count=0
 for _,p in model:GetDescendants() do
  if p:IsA("BasePart") then
   assert(string.sub(p.Name,1,#def[2]+1)==def[2].."_","Unexpected part: "..p:GetFullName())
   local old={color=p.Color,cf=p.CFrame,size=p.Size,material=p.Material,variant=p.MaterialVariant,reflectance=p.Reflectance,transparency=p.Transparency,anchored=p.Anchored,collide=p.CanCollide,children=#p:GetChildren(),texture=p:IsA("MeshPart") and p.TextureID,mesh=p:IsA("MeshPart") and p.MeshId,surfaces={}}
   for _,s in p:GetChildren() do
    if s:IsA("SurfaceAppearance") then table.insert(old.surfaces,{object=s,colorMap=s.ColorMap,normalMap=s.NormalMap,metalnessMap=s.MetalnessMap,roughnessMap=s.RoughnessMap,alphaMode=s.AlphaMode}) end
   end
   table.insert(changes,{part=p,color=colorFor(def[2],p.Name),old=old})
   table.insert(original,{path=p:GetFullName(),color={p.Color.R,p.Color.G,p.Color.B}})
   count+=1
  end
 end
 assert(count==def[3],"Unexpected part count: "..def[1].." "..count)
 totals[def[1]]=count
end
History:SetWaypoint("Before coloring scorpion spider camel and vulture")
local ok,err=pcall(function()
 for _,v in changes do v.part.Color=v.color end
 for _,v in changes do
  local p,o=v.part,v.old
  assert(p.Color==v.color,"Color mismatch: "..p.Name)
  assert(p.CFrame==o.cf and p.Size==o.size and p.Material==o.material and p.MaterialVariant==o.variant and p.Reflectance==o.reflectance and p.Transparency==o.transparency and p.Anchored==o.anchored and p.CanCollide==o.collide and #p:GetChildren()==o.children,"Non-color property changed: "..p.Name)
  if p:IsA("MeshPart") then assert(p.MeshId==o.mesh and p.TextureID==o.texture,"Mesh or texture changed: "..p.Name) end
  for _,s in o.surfaces do
   assert(s.object.Parent==p and s.object.ColorMap==s.colorMap and s.object.NormalMap==s.normalMap and s.object.MetalnessMap==s.metalnessMap and s.object.RoughnessMap==s.roughnessMap and s.object.AlphaMode==s.alphaMode,"Surface maps changed: "..p.Name)
  end
 end
end)
if not ok then for _,v in changes do v.part.Color=v.old.color end error(err) end
History:SetWaypoint("Colored scorpion spider camel and vulture")
return Http:JSONEncode({coloredParts=#changes,models=totals,onlyColorChanged=true,originalColors=original})
