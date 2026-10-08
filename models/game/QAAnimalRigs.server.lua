-- Run as a temporary server Script during Play. Leaves no models behind.
local RunService=game:GetService("RunService")
local Rig=require(game:GetService("ReplicatedStorage"):WaitForChild("AnimalRig"))
local templates=game:GetService("ServerStorage"):WaitForChild("AnimalTemplates")
local folder=Instance.new("Folder")
folder.Name="_AnimalRigValidation"
folder.Parent=workspace
local count,totalParts,totalJoints=0,0,0
local ok,err=pcall(function()
 for _,template in templates:GetChildren() do
  if template:IsA("Model") then
   for _,scale in {0.75,1,1.35} do
    local model=template:Clone()
    Rig.Build(model,template.Name)
    model:ScaleTo(model:GetScale()*scale)
    local parts,offsets={},{}
    local root=model.PrimaryPart
    local initial=root.CFrame
    for _,p in model:GetDescendants() do if p:IsA("BasePart") then
     table.insert(parts,p)
     table.insert(offsets,initial:ToObjectSpace(p.CFrame))
    end end
    local target=CFrame.new(0,2000,0)
    Rig.Move(model,parts,offsets,target)
    model.Parent=folder
    RunService.Heartbeat:Wait()
    RunService.Heartbeat:Wait()
    local rootOffset=offsets[Rig.RootIndex(model,parts)]
    for i,p in parts do
     assert(p.AssemblyRootPart==root,template.Name..": disconnected "..p.Name)
     assert(p.Anchored==(p==root),template.Name..": incorrect anchor "..p.Name)
     assert((p.Position-(target*offsets[i]).Position).Magnitude<0.015,template.Name..": misplaced "..p.Name)
    end
    local joints=#model.AnimalJoints:GetChildren()
    assert(joints==#parts-1,template.Name..": unexpected joints")
    Rig.Build(model,template.Name)
    assert(#model.AnimalJoints:GetChildren()==joints,template.Name..": duplicate joints")
    local binding=Rig.Bind(model)
    Rig.Pose(binding,1.21,1,0.5,false,1)
    local active=0
    for _,g in binding.joints do if g.motor.Transform~=CFrame.identity then active+=1 end end
    assert(active>0,template.Name..": gait has no poses")
    Rig.Pose(binding,1.21,0,0,true,1)
    for _,g in binding.joints do assert(g.motor.Transform==CFrame.identity,template.Name..": stunned pose wasn't reset") end
    root.CFrame=target*rootOffset+CFrame.new().Position+Vector3.new(20,0,0)
    RunService.Heartbeat:Wait()
    RunService.Heartbeat:Wait()
    for i,p in parts do
     assert((p.Position-((target+Vector3.new(20,0,0))*offsets[i]).Position).Magnitude<0.015,template.Name..": root motion failed")
    end
    count+=1 totalParts+=#parts totalJoints+=joints
    model:Destroy()
   end
  end
 end
end)
folder:Destroy()
assert(ok,err)
print(string.format("[AnimalRigQA] PASS: %d scaled rigs, %d connected parts, %d joints",count,totalParts,totalJoints))
script:SetAttribute("Passed",true)
script:SetAttribute("ModelsChecked",count)

