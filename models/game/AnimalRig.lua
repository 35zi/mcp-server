-- AnimalRig: reusable Motor6D skeletons with welded decorative pieces.
-- One anchored body; all other parts belong to its assembly. No scripts per animal.
local Rig = {}
local CollectionService = game:GetService("CollectionService")
Rig.Version = 2
Rig.Profiles = {
 Bunny={family="Hopper",stride=1.8}, Frog={family="Hopper",stride=1.7},
 Mouse={family="Quadruped",stride=4.5}, Hedgehog={family="Quadruped",stride=3.2},
 Fox={family="Quadruped",stride=2.8}, Camel={family="Quadruped",stride=1.5,pace=true},
 Duckling={family="Bird",stride=3.4}, Turkey={family="Bird",stride=3.0}, Vulture={family="Bird",stride=2.4},
 Spider={family="Crawler",stride=5.5}, Scorpion={family="Crawler",stride=4.5},
}
function Rig.Profile(species) return Rig.Profiles[species] or {family="Quadruped",stride=3} end
function Rig.IsWalker(species) return Rig.Profile(species).family ~= "Hopper" end
local function partsOf(model)
 local parts={}
 for _,p in model:GetDescendants() do if p:IsA("BasePart") then table.insert(parts,p) end end
 return parts
end
function Rig.SetAnchored(model, anchored)
 local root=model.PrimaryPart
 for _,p in partsOf(model) do
  p.Anchored = p == root and anchored or false
  p.CanCollide=false
  p.CanTouch=false
  p.Massless=p~=root or not anchored
 end
end
function Rig.RootIndex(model, parts)
 for i,p in parts do if p==model.PrimaryPart then return i end end
 error("Animal rig has no primary body: "..model:GetFullName())
end
-- The legacy gameplay root is a ground-level frame, not the PrimaryPart frame.
function Rig.Move(model, parts, offsets, groundFrame)
 local i=Rig.RootIndex(model,parts)
 if not model:IsDescendantOf(workspace) then
  -- Storage has no active joint solver; place the complete neutral pose before parenting.
  for k,p in parts do p.CFrame=groundFrame*offsets[k] end
 else
  model.PrimaryPart.CFrame=groundFrame*offsets[i]
 end
end
function Rig.Reset(model)
 local folder=model:FindFirstChild("AnimalJoints")
 if folder then for _,j in folder:GetChildren() do if j:IsA("Motor6D") then j.Transform=CFrame.identity end end end
end
local function extent(p, direction)
 local cf=p.CFrame
 return (math.abs(cf.RightVector:Dot(direction))*p.Size.X+math.abs(cf.UpVector:Dot(direction))*p.Size.Y+math.abs(cf.LookVector:Dot(direction))*p.Size.Z)/2
end
local function distanceToPart(p, point)
 local v=p.CFrame:PointToObjectSpace(point)
 local s=p.Size/2
 return (v-Vector3.new(math.clamp(v.X,-s.X,s.X),math.clamp(v.Y,-s.Y,s.Y),math.clamp(v.Z,-s.Z,s.Z))).Magnitude
end
function Rig.Build(model, species)
 species=species or model.Name
 CollectionService:AddTag(model,"AnimatedAnimal")
 model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 if model:GetAttribute("AnimalRigVersion")==Rig.Version and model:FindFirstChild("AnimalJoints") then
  Rig.SetAnchored(model,true)
  return model
 end
 local parts=partsOf(model)
 local body=model.PrimaryPart or model:FindFirstChild(species.."_Body",true) or model:FindFirstChild("Body",true) or model:FindFirstChild(species.."_Abdomen",true)
 assert(body and body:IsA("BasePart"),"No body for "..species)
 model.PrimaryPart=body
 local old=model:FindFirstChild("AnimalJoints")
 if old then old:Destroy() end
 for _,p in parts do p.Anchored=true end
 local folder=Instance.new("Folder")
 folder.Name="AnimalJoints"
 folder.Parent=model
 local look=body.CFrame.LookVector
 local yaw=math.atan2(-look.X,-look.Z)
 local axes=CFrame.Angles(0,yaw,0)
 local frame=CFrame.new(body.Position)*axes
 local groups,anchors={},{}
 local head,neck
 for _,p in parts do
  local n=p.Name:gsub("^"..species.."_","")
  if n=="Head" then head=p elseif n=="Neck" then neck=p end
 end
 local function add(p,role,parent,pivot)
  local v=frame:PointToObjectSpace(p.Position)
  local side=v.X>=0 and 1 or -1
  local front=v.Z<0
  local phase
  if role=="Leg" then
   if Rig.Profile(species).family=="Crawler" then
    local idx=tonumber(p.Name:match("_([0-3])_Upper$")) or 0
    phase=((idx+(side>0 and 1 or 0))%2)*math.pi
   elseif Rig.Profile(species).pace then phase=side>0 and 0 or math.pi
   else phase=((front and side>0) or (not front and side<0)) and 0 or math.pi end
  else phase=0 end
  local g={part=p,role=role,parent=parent or body,pivot=pivot or p.Position,side=side,phase=phase,front=front}
  table.insert(groups,g) anchors[p]=g
 end
 if neck then add(neck,"Neck",body,neck.Position:Lerp(body.Position,0.4)) end
 if head then add(head,"Head",neck or body,head.Position:Lerp((neck or body).Position,0.35)) end
 for _,p in parts do
  if p~=body and not anchors[p] then
   local n=p.Name:gsub("^"..species.."_","")
   if n:match("^Ear[LR]$") or n=="Ear" or n:match("^Ear_%-?1$") then
    add(p,"Ear",head or body,p.Position-Vector3.yAxis*extent(p,Vector3.yAxis)*0.8)
   elseif n=="Leg" or n:match("^Leg_[01]_%-?1$") or n:match("^Leg_%-?1_[0-3]_Upper$") then
    add(p,"Leg",body,p.Position+Vector3.yAxis*extent(p,Vector3.yAxis)*0.85)
   elseif n:match("^Foot_[01]_%-?1$") and (species=="Mouse" or species=="Hedgehog") then
    add(p,"Leg",body,p.Position+Vector3.yAxis*extent(p,Vector3.yAxis))
   elseif n:match("^Leg_%-?1$") then
    add(p,"Leg",body,p.Position+Vector3.yAxis*extent(p,Vector3.yAxis)*0.85)
   elseif n:match("^FrontPaw[LR]$") or n:match("^Front_Leg_") then
    add(p,"FrontLeg",body,p.Position+Vector3.yAxis*extent(p,Vector3.yAxis)*0.8)
   elseif n:match("^Haunch[LR]$") or n:match("^Hind_Thigh_") then
    add(p,"HindLeg",body,p.Position+Vector3.yAxis*extent(p,Vector3.yAxis)*0.55)
   elseif n=="Wing" or n:match("^Wing_%-?1$") then
    local v=frame:PointToObjectSpace(p.Position)
    add(p,"Wing",body,p.Position-axes.RightVector*(v.X>=0 and 1 or -1)*extent(p,axes.RightVector)*0.8)
   elseif n=="Tail" or n=="Tail_Base" or n=="Tail_01" or n=="Tail_00" then
    add(p,"Tail",body,p.Position:Lerp(body.Position,0.4))
   elseif n=="Feather" then
    add(p,"Fan",body,frame:PointToWorldSpace(Vector3.new(0,-0.15,1.4)))
   elseif n:match("^Claw_Arm_") then
    add(p,"Claw",body,p.Position:Lerp(body.Position,0.45))
   end
  end
 end
 -- A scorpion's tail is articulated; a mouse's flexible tail shares the same chain solver.
 if species=="Scorpion" or species=="Mouse" then
  local previous
  local sequence=species=="Scorpion" and {"Tail_00","Tail_01","Tail_02","Tail_03","Tail_04","Tail_05","Stinger"} or {"Tail_01","Tail_02","Tail_03","Tail_04","Tail_05"}
  for i,n in sequence do
   local p=model:FindFirstChild(species.."_"..n,true)
   if p then
    if not anchors[p] then
     add(p,"TailSegment",previous or body,previous and p.Position:Lerp(previous.Position,0.5) or p.Position)
     anchors[p].phase=i*0.5
    end
    previous=p
   end
  end
 end
 local function nearest(point, roles, side)
  local best,score=nil,math.huge
  for _,g in groups do
   if roles[g.role] and (not side or g.side==side) then
    local d=distanceToPart(g.part,point)
    if d<score then best,score=g.part,d end
   end
  end
  return best
 end
 for i,g in groups do
  local pivot=CFrame.new(g.pivot)*axes
  local j=Instance.new("Motor6D")
  j.Name=g.role.."_"..i
  j.Part0=g.parent j.Part1=g.part
  j.C0=g.parent.CFrame:ToObjectSpace(pivot)
  j.C1=g.part.CFrame:ToObjectSpace(pivot)
  j:SetAttribute("Role",g.role)
  j:SetAttribute("Side",g.side)
  j:SetAttribute("Phase",g.phase)
  j:SetAttribute("Front",g.front)
  j.Parent=folder
 end
 for _,p in parts do
  if p~=body and not anchors[p] then
   local n=p.Name:gsub("^"..species.."_","")
   local v=frame:PointToObjectSpace(p.Position)
   local side=v.X>=0 and 1 or -1
   local parent=body
   if n:find("Ear",1,true) then parent=nearest(p.Position,{Ear=true},side) or head or body
   elseif n:find("Tail",1,true) then parent=nearest(p.Position,{Tail=true,TailSegment=true}) or body
   elseif n:find("Feather",1,true) then
    parent=nearest(p.Position,{Fan=true}) or nearest(p.Position,{Wing=true},side) or body
   elseif n:find("Wing",1,true) then parent=nearest(p.Position,{Wing=true},side) or body
   elseif n:find("Claw",1,true) or n:find("Pincer",1,true) then parent=nearest(p.Position,{Claw=true},side) or body
   elseif n:find("Hind",1,true) or n:find("Haunch",1,true) or n:find("Back_Toe",1,true) then
    parent=nearest(p.Position,{HindLeg=true},side) or body
   elseif n:find("Leg",1,true) or n:find("Foot",1,true) or n:find("Toe",1,true) or n=="Sock" then
    parent=nearest(p.Position,{Leg=true,FrontLeg=true,HindLeg=true},side) or body
   elseif n:find("Collar",1,true) then parent=neck or body
   elseif n:find("Eye",1,true) or n:find("Muzzle",1,true) or n:find("Nose",1,true) or n:find("Nostril",1,true)
    or n:find("Mouth",1,true) or n:find("Smile",1,true) or n:find("Cheek",1,true) or n:find("Bill",1,true)
    or n:find("Beak",1,true) or n:find("Pupil",1,true) or n:find("Tooth",1,true) or n:find("Whisker",1,true)
    or n:find("Brow",1,true) or n:find("Fang",1,true) or n:find("Mandible",1,true) or n=="Snout" or n=="Jaw" or n=="Snood" or n=="Wattle" or n=="Crown_Step" then parent=head or body end
   local w=Instance.new("Weld")
   w.Name="DetailWeld_"..p.Name
   w.Part0=parent w.Part1=p
   w.C0=parent.CFrame:ToObjectSpace(p.CFrame)
   w.C1=CFrame.identity
   w.Parent=folder
  end
 end
 model:SetAttribute("AnimatedJointCount",#groups)
 model:SetAttribute("AnimalRigVersion",Rig.Version)
 model:SetAttribute("AnimationFamily",Rig.Profile(species).family)
 model:SetAttribute("RigSpecies",species)
 Rig.SetAnchored(model,true)
 return model
end
function Rig.Bind(model)
 local folder=model:FindFirstChild("AnimalJoints")
 if not folder then return nil end
 local out={model=model,species=model:GetAttribute("RigSpecies") or model.Name,joints={}}
 out.profile=Rig.Profile(out.species)
 for _,j in folder:GetChildren() do if j:IsA("Motor6D") then
  table.insert(out.joints,{motor=j,role=j:GetAttribute("Role"),side=j:GetAttribute("Side") or 1,phase=j:GetAttribute("Phase") or 0,front=j:GetAttribute("Front")})
 end end
 return out
end
-- All species share idle sniff/look, ear flick, and tail motion. Families replace only their gait.
function Rig.Pose(binding,t,moving,hopProgress,disabled,dt)
 local profile=binding.profile
 local blend=1-math.exp(-math.min(dt or 1/60,0.1)*12)
 binding.move=(binding.move or 0)+(moving-(binding.move or 0))*blend
 local move=binding.move
 local breath=math.sin(t*2.6)
 local sniff=math.sin(t*10)*math.clamp(math.sin(t*0.8)*3,0,1)*(1-move)
 local hop=math.sin(math.pi*(hopProgress or 0))*move
 local gait=t*profile.stride*math.pi*2
 for _,g in binding.joints do
  local x,y,z=0,0,0
  local r=g.role
  if not disabled then
   if r=="Head" then
    x=0.025*breath+0.055*sniff+(profile.family=="Bird" and 0.10*math.sin(gait)*move or 0.05*hop)
    y=0.07*math.sin(t*0.75)*(1-move)
   elseif r=="Neck" then x=0.02*breath+0.04*math.sin(gait)*move
   elseif r=="Ear" then
    local flick=(t+g.side*0.8)%4.7
    x=0.04*math.sin(t*1.7)+0.6*hop+(flick<0.24 and 0.38*math.sin(flick/0.24*math.pi) or 0)*(1-move)
    z=0.02*g.side*breath
   elseif r=="Tail" or r=="TailSegment" then
    y=(binding.species=="Fox" and 0.22 or 0.08)*math.sin(t*2.3-g.phase)*(0.5+move)
    x=binding.species=="Scorpion" and 0.035*math.sin(t*1.4-g.phase) or 0
   elseif r=="FrontLeg" then x=-0.35*hop
   elseif r=="HindLeg" then x=0.55*hop
   elseif r=="Leg" then
    local swing=math.sin(gait+g.phase)*move
    if profile.family=="Crawler" then y=0.18*swing z=g.side*0.14*math.max(0,swing)
    else x=(binding.species=="Camel" and 0.24 or 0.38)*swing end
   elseif r=="Wing" then
    local stretch=math.max(0,math.sin(t*0.9))^12
    z=g.side*(0.025*breath+0.25*stretch*(1-move)+0.045*move)
   elseif r=="Fan" then y=0.025*g.side*breath z=0.025*g.side*math.sin(t*1.1)*(1-move)
   elseif r=="Claw" then y=g.side*(0.06*math.sin(t*1.8)+0.05*move*math.sin(gait)) end
  end
  g.motor.Transform=CFrame.Angles(x,y,z)
 end
end
return Rig

