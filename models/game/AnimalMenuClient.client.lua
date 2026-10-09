-- AnimalMenuClient: uses the supplied StarterGui.GameUI instead of constructing the old menus.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ContentProvider=game:GetService("ContentProvider")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
local gui=player:WaitForChild("PlayerGui"):WaitForChild("GameUI")
local layout=require(ReplicatedStorage:WaitForChild("GameUILayout"))
layout.Apply(gui)
local MarketplaceService=game:GetService("MarketplaceService")
local motion=require(ReplicatedStorage:WaitForChild("UIMotion"))
motion.BindButtons(gui)
local frames=gui:WaitForChild("Frames")
local index,pets=frames:WaitForChild("Index"),frames:WaitForChild("Pets")
local data=require(ReplicatedStorage:WaitForChild("AnimalData"))
local UIStyle=require(ReplicatedStorage:WaitForChild("UIStyle"))
local previews=ReplicatedStorage:WaitForChild("AnimalPreviews")
local remote=ReplicatedStorage:WaitForChild("AnimalInventoryRemote")
local teleport=ReplicatedStorage:WaitForChild("GameUITeleport")
local dark=Color3.fromRGB(8,20,28)
local green=Color3.fromRGB(77,238,41)
local blue=Color3.fromRGB(10,148,222)
local red=Color3.fromRGB(245,55,55)
local worldIndex=1
local page=nil
local busy=false
local inventory=nil
local connections={}
local lastMouse=nil
local refresh
local function make(class,props,parent)
 local x=Instance.new(class) for k,v in props do x[k]=v end x.Parent=parent return x
end
local function stroke(x,width)
 return make("UIStroke",{Thickness=width or 2,Color=dark},x)
end
local function label(name,parent,value,pos,size,max,color)
 local x=make("TextLabel",{Name=name,Text=value,Position=pos,Size=size,BackgroundTransparency=1,Font=Enum.Font.GothamBlack,TextScaled=true,TextWrapped=true,TextColor3=color or Color3.new(1,1,1),ZIndex=16},parent)
 stroke(x,1.4) make("UITextSizeConstraint",{MinTextSize=9,MaxTextSize=max or 20},x)
 return x
end
local function button(name,parent,value,pos,size,color)
 local x=make("TextButton",{Name=name,Text=value,Position=pos,Size=size,BackgroundColor3=color or blue,BorderSizePixel=0,Font=Enum.Font.GothamBlack,TextColor3=Color3.new(1,1,1),TextScaled=true,AutoButtonColor=true,ZIndex=17},parent)
 make("UIStroke",{Thickness=2,Color=dark,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},x)
 stroke(x,1.2) make("UITextSizeConstraint",{MinTextSize=9,MaxTextSize=16},x)
 return x
end
local function clearCards(scroller)
 for _,child in scroller:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
end
-- Measure the final layout, excluding the temporary frame animation scale.
local function layoutSize(node)
 local frame=node:IsDescendantOf(index) and index or pets
 local scale=frame:FindFirstChild("FrameMotionScale")
 return node.AbsoluteSize/(scale and scale.Scale or 1)
end
local function gridSize(scroller,height)
 local width=layoutSize(scroller).X
 local columns=math.clamp(math.floor(width/125),2,5)
 local layout=scroller:FindFirstChildOfClass("UIGridLayout")
 layout.CellSize=UDim2.fromOffset(math.max(70,math.floor((width-16-(columns-1)*8)/columns)),height)
end
local corners={}
for _,x in {-.5,.5} do for _,y in {-.5,.5} do for _,z in {-.5,.5} do table.insert(corners,Vector3.new(x,y,z)) end end end
local function picture(parent,species,locked,mutation)
 local viewport=make("ViewportFrame",{Name="Preview",Position=UDim2.fromScale(.05,.05),Size=UDim2.fromScale(.90,.55),BackgroundTransparency=1,Ambient=Color3.fromRGB(210,215,230),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-2,-1),ZIndex=15},parent)
 local source=previews:FindFirstChild(species)
 if not source then label("MissingPreview",viewport,"?",UDim2.new(),UDim2.fromScale(1,1),48) return end
 local model=source:Clone()
 local low,high=Vector3.one*math.huge,-Vector3.one*math.huge
 for _,part in model:GetDescendants() do
  if part:IsA("BasePart") then
   part.Anchored=true
   if not locked and (mutation=="Gold" or mutation=="Silver") then
    local brightness=(part.Color.R+part.Color.G+part.Color.B)/3
    if brightness>.12 and brightness<.97 then
     part.Color=part.Color:Lerp(mutation=="Gold" and Color3.fromRGB(255,196,30) or Color3.fromRGB(205,215,230),mutation=="Gold" and .85 or .8)
     part.Material=Enum.Material.SmoothPlastic part.Reflectance=mutation=="Gold" and .25 or .3
    end
   end
   for _,c in corners do local p=part.CFrame*(c*part.Size) low=low:Min(p) high=high:Max(p) end
   if locked then part.Color=Color3.fromRGB(9,18,27) part.Material=Enum.Material.SmoothPlastic if part:IsA("MeshPart") then part.TextureID="" end end
  elseif locked and (part:IsA("SurfaceAppearance") or part:IsA("Decal") or part:IsA("Texture")) then part:Destroy()
  elseif locked and part:IsA("SpecialMesh") then part.TextureId="" end
 end
 model.Parent=viewport
 local centre=(low+high)/2
 local extent=high-low
 local primary=model.PrimaryPart
 local front=primary and Vector3.new(primary.CFrame.LookVector.X,0,primary.CFrame.LookVector.Z) or Vector3.new(0,0,-1)
 if front.Magnitude<.01 then front=Vector3.new(0,0,-1) end front=front.Unit
 local right=Vector3.new(-front.Z,0,front.X)
 local direction=(front*.9-right*.55+Vector3.new(0,.35,0)).Unit
 local camera=make("Camera",{FieldOfView=32},viewport)
 local distance=math.max(extent.X,extent.Y,extent.Z)*.72/math.tan(math.rad(16))
 camera.CFrame=CFrame.lookAt(centre+direction*distance,centre)
 viewport.CurrentCamera=camera
end
local function prettyName(name)
 return data.PrettyName and data.PrettyName(name) or name
end
local function rarityColor(name)
 local rarity=data.Rarities[name] return rarity and rarity.color or Color3.fromRGB(225,225,225)
end
local function card(parent,name,order,rarity)
 local c=make("Frame",{Name=name,LayoutOrder=order,BackgroundColor3=rarityColor(rarity):Lerp(Color3.new(1,1,1),.2),BorderSizePixel=0,ZIndex=14},parent)
 make("UIStroke",{Thickness=2,Color=dark,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},c)
 if rarity=="Secret" then
  -- Secret: a white card with a turning rainbow over it
  c.BackgroundColor3=Color3.new(1,1,1)
  UIStyle.rainbow(c,45)
 else
  make("UIGradient",{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(175,210,230)),Rotation=90},c)
 end
 return c
end
local function caught(species) return player:GetAttribute("Caught_"..species) or 0 end
local function found(world)
 local n=0 for _,species in world.species do if caught(species)>0 then n+=1 end end return n
end
local function renderIndex()
 local body=index.Content
 local tabWidth=math.min(145,math.max(90,math.floor((layoutSize(body.WorldTabs).X-4)/math.max(1,#data.Worlds))))
 for _,tab in body.WorldTabs:GetChildren() do if tab:IsA("TextButton") then tab.Size=UDim2.fromOffset(tabWidth,32) end end
 local total,unlocked=0,0
 for _,world in data.Worlds do total+=#world.species unlocked+=found(world) end
 body.Total.Text=string.format("%d / %d FOUND",unlocked,total)
 local world=data.Worlds[worldIndex]
 if not world then return end
 local count=found(world)
 body.Progress.Fill.Size=UDim2.fromScale(count/math.max(1,#world.species),1)
 body.Progress.Label.Text=string.upper(world.name)..string.format("  %d / %d",count,#world.species)
 for _,tab in body.WorldTabs:GetChildren() do if tab:IsA("TextButton") then
  local number=tab:GetAttribute("WorldIndex")
  tab.BackgroundColor3=number==worldIndex and green or blue
  local w=data.Worlds[number]
  tab.Text=string.upper(w.name)..string.format(" %d/%d",found(w),#w.species)
 end end
 local scroller=body.Cards
 local oldScroll=scroller.CanvasPosition
 clearCards(scroller)
 gridSize(scroller,math.clamp(layoutSize(scroller).X*.31,142,184))
 local species=table.clone(world.species)
 table.sort(species,function(a,b)
  local ra,rb=data.RarityRank(data.Species[a].rarity),data.RarityRank(data.Species[b].rarity)
  return ra==rb and a<b or ra<rb
 end)
 for i,name in species do
  local info=data.Species[name]
  local known=caught(name)>0
  local c=card(scroller,"Animal_"..name,i,info.rarity)
  c:SetAttribute("Unlocked",known)
  picture(c,name,not known)
  label("Name",c,known and string.upper(prettyName(name)) or "???",UDim2.fromScale(.03,.59),UDim2.fromScale(.94,.13),20)
  label("Rarity",c,string.upper(info.rarity),UDim2.fromScale(.03,.73),UDim2.fromScale(.94,.10),12,rarityColor(info.rarity))
  if info.rarity=="Secret" then
   -- rainbow rarity (and name, once caught)
   c.Rarity.TextColor3=Color3.new(1,1,1) UIStyle.rainbow(c.Rarity)
   if known then UIStyle.rainbow(c:FindFirstChild("Name")) end
  end
  label("Caught",c,known and ("CAUGHT: "..caught(name)) or "NOT FOUND",UDim2.fromScale(.03,.86),UDim2.fromScale(.94,.10),12)
 end
 scroller.CanvasPosition=oldScroll
end
local notice
local function ask(action,id)
 if busy then return end
 busy=true
 pets.EquipBestArtwork.Interactable=false
 local ok,success,message=pcall(function() return remote:InvokeServer(action,id) end)
 local feedback=ok and tostring(message or "") or "Please try again."
 busy=false pets.EquipBestArtwork.Interactable=true
 if notice and (not ok or not success) then notice(feedback) end
 if refresh then refresh() end
end
local function renderPets()
 local body=pets.Content
 local items={}
 local equipped=0
 if inventory then for _,item in inventory:GetChildren() do
  if item:IsA("Folder") then
   if item:GetAttribute("State")=="Plot" then equipped+=1 end
   if item:GetAttribute("State")=="Plot" then table.insert(items,item) end
  end
 end end
 table.sort(items,function(a,b)
  local ia,ib=a:GetAttribute("Income") or 0,b:GetAttribute("Income") or 0
  return ia==ib and (a:GetAttribute("Id") or 0)<(b:GetAttribute("Id") or 0) or ia>ib
 end)
 body.Count.Text=string.format("%d / 24 EQUIPPED",equipped)
 body.Income.Text="$"..data.Commas(player:GetAttribute("IncomePerSecond") or 0).." / SECOND"
 local scroller=body.Cards
 local oldScroll=scroller.CanvasPosition
 clearCards(scroller)
 scroller.Size=UDim2.fromScale(1,.76)
 scroller:FindFirstChildOfClass("UIGridLayout").CellSize=UDim2.fromOffset(math.max(100,layoutSize(scroller).X-16),84)
 body.Empty.Visible=#items==0
 body.Empty.Text="NO PETS EQUIPPED\nSelect EQUIP BEST to use pets from your Backpack."
 for i,item in items do
  local a=item:GetAttributes()
  local species=a.Species or "Pet"
  local c=card(scroller,"Pet_"..tostring(a.Id),i,a.Rarity)
  c:SetAttribute("EntryId",a.Id) c:SetAttribute("State",a.State)
  picture(c,species,false,a.Mutation)
  -- Equipped summary: preview, weight, variant and income.
  c.Preview.Size=UDim2.fromScale(.90,.42)
  label("Name",c,string.upper(prettyName(species)),UDim2.fromScale(.02,.47),UDim2.fromScale(.96,.10),18)
  if a.Rarity=="Secret" then UIStyle.rainbow(c:FindFirstChild("Name")) end
  local variant=data.WeightText(data.Weight(species, a.WeightKg or a.Size))..(a.Mutation and a.Mutation~="None" and (" • "..string.upper(a.Mutation)) or "")
  label("Variant",c,variant,UDim2.fromScale(.02,.59),UDim2.fromScale(.96,.08),11)
  label("Income",c,"$"..data.Commas(a.Income or 0).."/s",UDim2.fromScale(.02,.69),UDim2.fromScale(.96,.10),18,green)
  c.Preview.Position=UDim2.fromScale(.02,.04) c.Preview.Size=UDim2.fromScale(.30,.90)
  c:FindFirstChild("Name").Position=UDim2.new(.35,0,0,5) c:FindFirstChild("Name").Size=UDim2.new(.63,0,0,24)
  c.Variant.Position=UDim2.new(.35,0,0,31) c.Variant.Size=UDim2.new(.63,0,0,12)
  c.Income.Position=UDim2.new(.35,0,0,49) c.Income.Size=UDim2.new(.63,0,0,24)
 end
 scroller.CanvasPosition=oldScroll
end
local refreshPending=false
refresh=function()
 if refreshPending then return end refreshPending=true
 task.defer(function()
  refreshPending=false
  if page=="Index" then renderIndex() elseif page=="Pets" then renderPets() end
 end)
end
local function resize()
 local vp=workspace.CurrentCamera.ViewportSize
 local width=math.min(680,vp.X-32,vp.Y*.80*1.40090096)
 index.Size=UDim2.fromOffset(width,width/1.40090096)
 layout.ResizePets(gui,vp)
 motion.SetFramePosition(pets,pets.Position)
 gui.CarryBanner.Size=UDim2.fromOffset(math.min(650,vp.X-32),44)
 local scale=gui.HUD:FindFirstChildOfClass("UIScale") or make("UIScale",{},gui.HUD)
 scale.Scale=math.min(1,vp.X/800,vp.Y/550)
 local hideSides=page~=nil and vp.X<760
 gui.LeftButtons.Visible=not hideSides gui.RightButtons.Visible=not hideSides and page~="Pets" gui.TopButtons.Visible=not hideSides
 refresh()
end
local function setOpen(value)
 if value==page then value=nil end
 if value and not page then lastMouse=UserInputService.MouseBehavior end
 page=value
 resize()
 motion.SetFrame(index,value=="Index") motion.SetFrame(pets,value=="Pets")
 gui:SetAttribute("Open",value~=nil)
 if value then UserInputService.MouseBehavior=Enum.MouseBehavior.Default UserInputService.MouseIconEnabled=true
 elseif lastMouse then UserInputService.MouseBehavior=lastMouse lastMouse=nil end
 resize()
 refresh()
end
for i,world in data.Worlds do
 local tab=button("World_"..world.id,index.Content.WorldTabs,string.upper(world.name),UDim2.new(),UDim2.fromOffset(145,32),blue)
 tab.LayoutOrder=i tab:SetAttribute("WorldIndex",i)
 tab.Activated:Connect(function() worldIndex=i index.Content.Cards.CanvasPosition=Vector2.zero renderIndex() end)
end
gui.LeftButtons.Index.Activated:Connect(function() setOpen("Index") end)
gui.RightButtons.Pets.Activated:Connect(function() setOpen("Pets") end)
index.CloseButton.Activated:Connect(function() setOpen(nil) end)
pets.CloseButton.Activated:Connect(function() setOpen(nil) end)
pets.EquipBestArtwork.Activated:Connect(function() ask("EquipBest") end)
UserInputService.InputBegan:Connect(function(input,processed)
 if not processed and (input.KeyCode==Enum.KeyCode.Backspace or input.KeyCode==Enum.KeyCode.ButtonB) and page then setOpen(nil) end
end)
local notificationSerial=0
notice=function(message)
 notificationSerial+=1 local serial=notificationSerial
 local node=gui:FindFirstChild("Notification") or label("Notification",gui,"",UDim2.fromScale(.2,.84),UDim2.fromScale(.6,.07),21)
 node.ZIndex=40 node.Text=tostring(message) node.Visible=true
 task.delay(3,function() if notificationSerial==serial then node.Visible=false end end)
end
local travelBusy=false
local function travel(destination)
 if travelBusy then return end travelBusy=true
 if page then setOpen(nil) end
 local ok,success,message=pcall(function() return teleport:InvokeServer(destination) end)
 if not ok or not success then notice(ok and message or "Please try again.") end
 travelBusy=false
end
for _,destination in {"Base","Weapons","Speed"} do gui.TopButtons[destination].Activated:Connect(function() travel(destination) end) end
-- Roblox's native shop lists this experience's passes and developer products.
local shopBusy=false
gui.LeftButtons.Shop.Activated:Connect(function()
 if shopBusy then return end
 shopBusy=true
 if page then setOpen(nil) end
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if humanoid then humanoid:UnequipTools() end
 local ok=pcall(function() MarketplaceService:OpenShop(player) end)
 if not ok then
  notice("The Roblox shop is unavailable right now.")
 end
 task.delay(1,function() shopBusy=false end)
end)
local function updateHUD()
 gui.HUD.Income.Text="+$"..data.Commas(player:GetAttribute("IncomePerSecond") or 0).." / SECOND"
 if page=="Pets" then refresh() end
end
player:GetAttributeChangedSignal("IncomePerSecond"):Connect(updateHUD)
task.spawn(function()
 local cash=player:WaitForChild("leaderstats"):WaitForChild("Cash")
 local function update() gui.HUD.Cash.Text="$"..data.Commas(cash.Value) end
 cash.Changed:Connect(update) update()
end)
task.spawn(function()
 local animals=workspace:WaitForChild("Animals")
 while gui.Parent do
  local nextAt=animals:GetAttribute("NextWaveAt")
  if nextAt then local left=math.max(0,nextAt-os.time()) gui.HUD.Wave.Text=string.format("NEW ANIMALS IN %d:%02d",left//60,left%60) end
  task.wait(.5)
 end
end)
local function watchItem(item)
 if connections[item] then return end
 connections[item]=item.AttributeChanged:Connect(refresh)
end
local function watchInventory(folder)
 inventory=folder
 for _,item in folder:GetChildren() do watchItem(item) end
 folder.ChildAdded:Connect(function(item) watchItem(item) refresh() end)
 folder.ChildRemoved:Connect(function(item) if connections[item] then connections[item]:Disconnect() connections[item]=nil end refresh() end)
 refresh()
end
local existing=player:FindFirstChild("AnimalInventory")
if existing then watchInventory(existing) end
player.ChildAdded:Connect(function(child) if child.Name=="AnimalInventory" and child~=inventory then watchInventory(child) end end)
player.AttributeChanged:Connect(function(name) if name:sub(1,7)=="Caught_" then refresh() end end)
local animalEvent=ReplicatedStorage:WaitForChild("AnimalEvent")
local function drop() animalEvent:FireServer("Drop") end
gui.CarryBanner.Drop.Activated:Connect(drop)
local function carryChanged()
 local carrying=player:GetAttribute("Carrying")
 gui.CarryBanner.Visible=carrying~=nil
 gui.CarryBanner.Label.Text=carrying and ("CARRYING "..string.upper(carrying).." — BRING IT HOME! (others can shoot you to steal it)") or ""
 if carrying then
  ContextActionService:BindAction("DropAnimal",function(_,state) if state==Enum.UserInputState.Begin then drop() end return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.G,Enum.KeyCode.ButtonY)
 else ContextActionService:UnbindAction("DropAnimal") end
end
player:GetAttributeChangedSignal("Carrying"):Connect(carryChanged) carryChanged()
task.spawn(function()
 local shop=player.PlayerGui:WaitForChild("WeaponShopUI",60)
 if shop then
  local function sync() if shop.Enabled and page then setOpen(nil) end gui.Enabled=not shop.Enabled end
  shop:GetPropertyChangedSignal("Enabled"):Connect(sync) sync()
 end
end)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({previews}) end) refresh() end)
motion.SetFrame(index,false,true) motion.SetFrame(pets,false,true)
resize() updateHUD() gui:SetAttribute("Ready",true)
