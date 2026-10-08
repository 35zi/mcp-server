-- RigAnimalTemplates (Script in ServerScriptService).
-- Existing rigs are saved in the place; new named templates use the same builder.
local Rig=require(game:GetService("ReplicatedStorage"):WaitForChild("AnimalRig"))
local templates=game:GetService("ServerStorage"):WaitForChild("AnimalTemplates")
local function setup(model)
 if model:IsA("Model") then Rig.Build(model,model.Name) end
end
for _,model in templates:GetChildren() do setup(model) end
templates.ChildAdded:Connect(function(model)
 if model:IsA("Model") then
  task.defer(function()
   if model.Parent~=templates then return end
   if not model.PrimaryPart then
    model:WaitForChild(model.Name.."_Body",5)
   end
   setup(model)
  end)
 end
end)

