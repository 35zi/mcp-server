-- Shared procedural animation driver: one PreSimulation connection for all animals.
-- Cosmetic Motor6D.Transform stays on clients. The server only replicates body motion/state.
local RunService=game:GetService("RunService")
local CollectionService=game:GetService("CollectionService")
local Rig=require(game:GetService("ReplicatedStorage"):WaitForChild("AnimalRig"))
local bindings={}
local pending={}
local TAG="AnimatedAnimal"
local function track(model)
 if not model:IsA("Model") or bindings[model] or pending[model] then return end
 pending[model]=true
 task.spawn(function()
  local elapsed=0
  while model.Parent and model:IsDescendantOf(workspace) and elapsed<10 do
   local binding=Rig.Bind(model)
   if binding and #binding.joints>0 and #binding.joints==(model:GetAttribute("AnimatedJointCount") or #binding.joints) and model.PrimaryPart then
    binding.seed=model:GetAttribute("AnimalId") or model:GetAttribute("EntryId") or #model.Name*0.37
    bindings[model]=binding
    break
   end
   elapsed+=task.wait(0.1)
  end
  pending[model]=nil
 end)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model) bindings[model]=nil end)
for _,model in CollectionService:GetTagged(TAG) do if model:IsDescendantOf(workspace) then track(model) end end
-- Tags on templates exist before they enter Workspace, so watch models entering the scene too.
workspace.DescendantAdded:Connect(function(instance)
 if instance:IsA("Model") and CollectionService:HasTag(instance,TAG) then
  track(instance)
 elseif instance:IsA("Motor6D") or instance.Name=="AnimalJoints" then
  local ancestor=instance.Parent
  while ancestor and ancestor~=workspace do
   if ancestor:IsA("Model") and CollectionService:HasTag(ancestor,TAG) then track(ancestor) break end
   ancestor=ancestor.Parent
  end
 end
end)
RunService.PreSimulation:Connect(function(dt)
 local now=workspace:GetServerTimeNow()
 local camera=workspace.CurrentCamera
 for model,binding in bindings do
  if not model:IsDescendantOf(workspace) or not model.PrimaryPart then bindings[model]=nil
  else
   local distance=camera and (model.PrimaryPart.Position-camera.CFrame.Position).Magnitude or 0
   local interval=distance<90 and 0 or distance<180 and 1/30 or distance<320 and 1/12 or 0.5
   binding.elapsed=(binding.elapsed or 0)+dt
   if binding.elapsed>=interval then
    local state=model:GetAttribute("AnimState") or "idle"
    local context=model:GetAttribute("AnimationContext")
    local disabled=context=="Stunned"
    local moving=context~="Held" and state=="hop" and 1 or 0
    local duration=model:GetAttribute("AnimDuration") or 0.5
    local p=math.clamp((now-(model:GetAttribute("AnimStartedAt") or now))/math.max(duration,0.05),0,1)
    Rig.Pose(binding,now+binding.seed,moving,p,disabled,binding.elapsed)
    binding.elapsed=0
   end
  end
 end
end)

