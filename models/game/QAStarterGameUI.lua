-- Run manually with require(EquipBestService) and require(AnimalData).
-- Uses temporary mock inventories/plots; never touches a real player's data.
return function(Best, Data)
 local fixtures={}
 local function fixture()
  local inventory=Instance.new("Folder")
  local plot=Instance.new("Folder") plot.Name="TemporaryEquipBestQA" plot.Parent=workspace
  table.insert(fixtures,inventory) table.insert(fixtures,plot)
  local player={UserId=-801,Income=0}
  function player:FindFirstChild(name) return name=="AnimalInventory" and inventory or nil end
  function player:SetAttribute(name,value) if name=="IncomePerSecond" then self.Income=value end end
  local tools={}
  local context={Maximum=24,Plot=function() return plot end,Folder=function() return plot end}
  context.FindTool=function(_,id) return tools[id] end
  context.Place=function(_,item)
   local model=Instance.new("Model") model:SetAttribute("EntryId",item:GetAttribute("Id")) model.Parent=plot
   item:SetAttribute("State","Plot") return true
  end
  local id=0
  local function add(species,size,mutation,state)
   id+=1 local item=Instance.new("Folder")
   item:SetAttribute("Id",id) item:SetAttribute("Species",species) item:SetAttribute("Size",size)
   item:SetAttribute("Mutation",mutation) item:SetAttribute("Income",Data.Income(species,size,mutation))
   item:SetAttribute("State",state or "Bag") item.Parent=inventory return item
  end
  return player,context,add,inventory,plot,tools
 end
 local ok,result=xpcall(function()
  local player,context,add,inventory,plot,tools=fixture()
  for i=1,25 do add("Bunny","Small","None") end
  add("Fox","Large","Gold")
  local held=add("Vulture","Large","Gold","Held")
  local tool=Instance.new("Folder") tool.Parent=inventory -- staged outside item candidates before the call
  tool.Parent=plot tools[held:GetAttribute("Id")]=tool
  -- Tools belong outside the plot models in normal gameplay.
  tool.Parent=workspace table.insert(fixtures,tool)
  add("Camel","Large","None") add("Scorpion","Medium","Silver")
  add("Frog","Medium","None") add("Hedgehog","Medium","None")
  add("Spider","Small","None") add("Turkey","Small","None")
  local expectedItems=inventory:GetChildren()
  table.sort(expectedItems,function(a,b) return a:GetAttribute("Income")>b:GetAttribute("Income") end)
  local expected=0 for i=1,24 do expected+=expectedItems[i]:GetAttribute("Income") end
  assert(expected==737)
  local success,message=Best.Equip(player,context)
  assert(success,message)
  local count,income=0,0
  for _,item in inventory:GetChildren() do if item:GetAttribute("State")=="Plot" then count+=1 income+=item:GetAttribute("Income") end end
  assert(count==24 and income==expected and player.Income==expected,"Incorrect cap/ranking/income")
  assert(#plot:GetChildren()==24 and held:GetAttribute("State")=="Plot" and tool.Parent==nil,"Held pet/model cleanup failed")
  local p2,c2,add2,_,plot2=fixture()
  local original=add2("Fox","Medium","None","Plot") add2("Bunny","Small","None")
  local oldModel=Instance.new("Model") oldModel.Name="OriginalPet" oldModel.Parent=plot2
  c2.Place=function(_,item)
   if item==original then return false end
   local model=Instance.new("Model") model.Parent=plot2 item:SetAttribute("State","Plot") return true
  end
  local swapped=Best.Equip(p2,c2)
  assert(not swapped and original:GetAttribute("State")=="Plot" and oldModel.Parent==plot2 and #plot2:GetChildren()==1,"Lower-income swap did not roll back")
  assert(not game.ServerStorage:FindFirstChild("_EquipBest_-801"),"Staging leaked")
  return "PASS: 33 pets -> best 24 ($737/s), held-tool cleanup, lower-income rollback"
 end,debug.traceback)
 for _,object in fixtures do object:Destroy() end
 if not ok then error(result) end
 return result
end

