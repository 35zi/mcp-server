-- Mirror unequipped animal entries into Roblox's normal Backpack, one Tool per entry.
local Backpack={}
function Backpack.Start(player,context)
 local connections={} local watched={} local tools={} local stopped=false local pending=false
 local inventory
 local sync
 local function schedule()
  if stopped or pending then return end pending=true
  task.defer(function() pending=false if not stopped then sync() end end)
 end
 local function watch(item)
  if watched[item] then return end
  watched[item]=item:GetAttributeChangedSignal("State"):Connect(schedule)
 end
 sync=function()
  local character=player.Character
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  local backpack=player:FindFirstChildOfClass("Backpack")
  if not inventory or not backpack or not humanoid or humanoid.Health<=0 then return end
  for item,connection in watched do
   if item.Parent~=inventory then connection:Disconnect() watched[item]=nil end
  end
  for _,item in inventory:GetChildren() do
   if not item:IsA("Folder") then continue end
   watch(item)
   local id=item:GetAttribute("Id")
   if type(id)~="number" then continue end
   local state=item:GetAttribute("State")
   local tool=context.FindTool(player,id)
   if state=="Plot" then
    if tool then tool:Destroy() end
   elseif not tool then
    tool=context.CreateTool(player,item)
    if tool then
     tool.ToolTip="Select to hold. Click while in your base to equip."
     tools[tool]=true
     tool.Equipped:Connect(function()
      if item.Parent==inventory and item:GetAttribute("State")~="Plot" then item:SetAttribute("State","Held") end
     end)
     tool.Unequipped:Connect(function()
      if item.Parent==inventory and item:GetAttribute("State")=="Held" then item:SetAttribute("State","Bag") end
     end)
     local placing=false
     tool.Activated:Connect(function()
      if placing or tool.Parent~=player.Character or item.Parent~=inventory or item:GetAttribute("State")~="Held" then return end
      local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
      local plot=context.Plot(player)
      if not root or not plot or player:GetAttribute("Carrying") then return end
      local localPosition=plot.Hitbox.CFrame:PointToObjectSpace(root.Position)
      local half=plot.Hitbox.Size/2
      if math.abs(localPosition.X)>half.X or math.abs(localPosition.Z)>half.Z or math.abs(localPosition.Y)>half.Y+8 then return end
      placing=true
      context.Place(player,item)
      task.delay(.25,function() placing=false end)
     end)
     tool.Destroying:Connect(function() tools[tool]=nil schedule() end)
     tool.Parent=backpack
    end
   end
  end
  -- Deleted entries cannot leave orphan Tools behind.
  for tool in tools do
   local id=tool:GetAttribute("AnimalEntryId")
   if not inventory:FindFirstChild(tostring(id)) then tool:Destroy() end
  end
 end
 local function attach(folder)
  if inventory==folder then return end inventory=folder
  table.insert(connections,folder.ChildAdded:Connect(schedule))
  table.insert(connections,folder.ChildRemoved:Connect(schedule))
  schedule()
 end
 table.insert(connections,player.ChildAdded:Connect(function(child)
  if child.Name=="AnimalInventory" then attach(child) elseif child:IsA("Backpack") then schedule() end
 end))
 table.insert(connections,player.CharacterAdded:Connect(function(character)
  character:WaitForChild("Humanoid",10) player:WaitForChild("Backpack",10) schedule()
 end))
 if player:FindFirstChild("AnimalInventory") then attach(player.AnimalInventory) end
 return function()
  stopped=true
  for _,connection in connections do connection:Disconnect() end
  for _,connection in watched do connection:Disconnect() end
 end
end
return Backpack
