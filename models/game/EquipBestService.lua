-- EquipBestService: server-owned ranking and reversible plot swaps.
local AnimalData=require(game:GetService("ReplicatedStorage"):WaitForChild("AnimalData"))
local ServerStorage=game:GetService("ServerStorage")
local Best={}
function Best.Equip(player,context)
 if not context.Plot(player) then return false,"You don't have a base yet." end
 local inventory=player:FindFirstChild("AnimalInventory")
 if not inventory or #inventory:GetChildren()==0 then return false,"Catch some pets first!" end
 local folder=context.Folder(player)
 local candidates,snapshots={},{}
 local oldIncome=0
 for _,item in inventory:GetChildren() do
  local state=item:GetAttribute("State")
  snapshots[item]=state
  local species=item:GetAttribute("Species")
  local income=AnimalData.Income(species,item:GetAttribute("WeightKg") or item:GetAttribute("Size"),item:GetAttribute("Mutation"))
  if AnimalData.Species[species] and type(item:GetAttribute("Id"))=="number" then
   table.insert(candidates,{item=item,income=income,id=item:GetAttribute("Id")})
  end
  if state=="Plot" then oldIncome+=income end
 end
 table.sort(candidates,function(a,b)
  if a.income~=b.income then return a.income>b.income end
  if snapshots[a.item]=="Plot" and snapshots[b.item]~="Plot" then return true end
  if snapshots[b.item]=="Plot" and snapshots[a.item]~="Plot" then return false end
  return a.id<b.id
 end)
 if #candidates==0 then return false,"No pets are available." end
 local staging=Instance.new("Folder") staging.Name="_EquipBest_"..player.UserId staging.Parent=ServerStorage
 local originalModels=folder:GetChildren()
 for _,model in originalModels do model.Parent=staging end
 for item,state in snapshots do if state=="Plot" then item:SetAttribute("State","Bag") end end
 local selected,count,income={},0,0
 local ok,err=pcall(function()
  -- A bounded candidate pass avoids expensive unlimited model creation.
  for i=1,math.min(#candidates,context.Maximum*4) do
   if count>=context.Maximum then break end
   local candidate=candidates[i]
   local placed=context.Place(player,candidate.item)
   if placed then
    selected[candidate.item]=true count+=1 income+=candidate.income
   end
  end
 end)
 if not ok or count==0 or income<oldIncome then
  for _,model in folder:GetChildren() do model:Destroy() end
  for item,state in snapshots do if item.Parent then item:SetAttribute("State",state) end end
  for _,model in originalModels do if model.Parent then model.Parent=folder end end
  staging:Destroy()
  if not ok then warn("[EquipBest]",err) end
  return false,"Your current pets are already best for the space on your base."
 end
 staging:Destroy()
 for item in selected do
  if snapshots[item]=="Held" then
   local tool=context.FindTool(player,item:GetAttribute("Id"))
   if tool then tool:Destroy() end
  end
 end
 player:SetAttribute("IncomePerSecond",income)
 return true,string.format("Equipped %d pets — $%s per second!",count,AnimalData.Commas(income))
end
return Best
