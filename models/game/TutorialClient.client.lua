-- Contextual guidance follows real UI and moving world targets.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local gui=pg:WaitForChild("TutorialUI")
gui.ScreenInsets=Enum.ScreenInsets.None -- keep viewport placement in the same coordinate space as the shop
local remote=RS:WaitForChild("TutorialRemote")
local spotlight=require(RS:WaitForChild("TutorialSpotlight")).new(gui)
local card=gui.StepCard
local skin=require(RS:WaitForChild("AnimalInventoryLayout"))
card.BackgroundColor3=Color3.fromRGB(18,107,165);card.BackgroundTransparency=0
skin.Checker(card);skin.Outline(card,3,Color3.fromRGB(8,20,28))
card.Title.Font=Enum.Font.GothamBlack;card.Title.TextColor3=Color3.fromRGB(255,220,68);card.Title.TextSize=16
card.Instruction.Font=Enum.Font.GothamBlack;card.Instruction.TextColor3=Color3.new(1,1,1)
card.Instruction.TextScaled=false;card.Instruction.TextWrapped=true;card.Instruction.TextSize=20
local instructionLimit=Instance.new("UITextSizeConstraint");instructionLimit.MinTextSize=12;instructionLimit.MaxTextSize=20;instructionLimit.Parent=card.Instruction
local stroke=Instance.new("UIStroke");stroke.Thickness=1.6;stroke.Color=Color3.fromRGB(8,20,28);stroke.Parent=card.Instruction
local titles={"TRAIN SPEED","GET A GUN","AIM","STUN THE ANIMAL","PICK IT UP","GO HOME","EQUIP PET","EARN CASH","GET A TRAIL"}

local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
local animal,body,nextSearch=nil,nil,0
local completedAt=nil
local lastStep=nil
local function find(root,...)
 for _,name in ipairs({...}) do root=root and root:FindFirstChild(name) end
 return root
end
local function visible(object)
 if not object then return false end
 local current=object
 while current and current~=pg do
  if current:IsA("GuiObject") and not current.Visible then return false end
  if current:IsA("ScreenGui") and not current.Enabled then return false end
  current=current.Parent
 end
 return current==pg
end
-- an open GameUI window (Index, Shop, Pets...) or the pet inventory
local function openMenu()
 local frames=find(pg,"GameUI","Frames")
 if frames then for _,frame in ipairs(frames:GetChildren()) do if frame:IsA("GuiObject") and frame.Visible then return frame end end end
 local inventory=find(pg,"AnimalInventoryUI","Inventory")
 if inventory and inventory.Visible then return inventory end
 return nil
end
local function button(target,text)
 if visible(target) then spotlight:Button(target) else spotlight:Clear() end
 card.Instruction.Text=text
end
local function world(position,label,text,radius)
 if position then spotlight:World(position,label,radius) else spotlight:Clear() end
 card.Instruction.Text=text
end
local function nearest(folder,root,owned)
 local best,score=nil,math.huge
 if not folder then return nil end
 for _,model in ipairs(folder:GetChildren()) do
  if model:IsA("Model") and model.PrimaryPart then
   local eligible=owned and model:GetAttribute("OwnerUserId")==player.UserId and not model:GetAttribute("Dragging")
    or not owned and not model:GetAttribute("Dead") and (model:GetAttribute("Health") or 1)>0
   if eligible then
    local cost=(model.PrimaryPart.Position-root.Position).Magnitude
    -- Keep the first hunt approachable: prefer a nearby small forest animal.
    if not owned and model:GetAttribute("Species")~="Bunny" then cost+=100 end
    if cost<score then best=model; score=cost end
   end
  end
 end
 return best
end
local function homePoint(root)
 local line=workspace:FindFirstChild("RedLine")
 local spawn=workspace:FindFirstChild("SpawnLocation")
 if not line then return spawn and spawn.Position end
 local normal=line.Size.X<line.Size.Z and line.CFrame.RightVector or line.CFrame.LookVector
 normal=Vector3.new(normal.X,0,normal.Z).Unit
 local sign=spawn and math.sign((spawn.Position-line.Position):Dot(normal)) or 1
 if sign==0 then sign=1 end
 local localPos=line.CFrame:PointToObjectSpace(root.Position)
 local pos=line.CFrame:PointToWorldSpace(Vector3.new(math.clamp(localPos.X,-line.Size.X*.45,line.Size.X*.45),0,math.clamp(localPos.Z,-line.Size.Z*.45,line.Size.Z*.45)))
 return pos+normal*sign*14+Vector3.new(0,3,0)
end
card.Skip.Activated:Connect(function() spotlight:Clear(); remote:FireServer("Skip") end)
gui.Help.Activated:Connect(function() completedAt=nil; remote:FireServer("Replay") end)
UIS.InputBegan:Connect(function(input,processed)
 if processed or player:GetAttribute("TutorialStep")~=3 then return end
 if input.UserInputType==Enum.UserInputType.MouseButton2 or input.KeyCode==Enum.KeyCode.ButtonL2
  or (touch and input.UserInputType==Enum.UserInputType.Touch) then remote:FireServer("Aim") end
end)
local function update(now)
 local camera=workspace.CurrentCamera
 if not camera then return end
 local vp=camera.ViewportSize
 local step=player:GetAttribute("TutorialStep") or 0
 if lastStep~=step then
  lastStep=step; spotlight:Clear(); animal=nil; body=nil; nextSearch=0
  if step==10 then completedAt=now else completedAt=nil end
 end
 local loading=pg:FindFirstChild("LoadingScreen")
 if loading and not loading.Enabled then loading=nil end
 local char=player.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local humanoid=char and char:FindFirstChildOfClass("Humanoid")
 local shop=pg:FindFirstChild("WeaponShopUI")
 local inShop=shop and shop.Enabled
 local trailShop=pg:FindFirstChild("TrailShop")
 local inTrailShop=trailShop and trailShop.Enabled
 gui.Enabled=true -- trail shop must retain its instructional overlay
 local active=step>=1 and step<=9
 local toast=step==10 and completedAt and now-completedAt<5
 gui.Help.Visible=(step==0 or step==10) and not loading and not inShop and not inTrailShop
 card.Visible=(active or toast) and not loading and root~=nil and humanoid and humanoid.Health>0
 if not card.Visible then spotlight:Clear(); return end
 card.Skip.Visible=active
 card.Size=UDim2.fromOffset(math.min(510,vp.X-24),104)
 card.Title.Position=UDim2.fromScale(.03,.08);card.Title.Size=UDim2.new(1,-88,.2,0)
 card.Instruction.Position=UDim2.fromScale(.03,.31);card.Instruction.Size=UDim2.new(1,-88,.62,0)
 card.Skip.AnchorPoint=Vector2.new(1,.5);card.Skip.Position=UDim2.new(1,-8,.5,0);card.Skip.Size=UDim2.fromOffset(60,64)
 card.Skip.Font=Enum.Font.GothamBlack;card.Skip.TextSize=16
 card.Instruction.TextScaled=false
 card.Instruction.TextSize=vp.X<480 and 17 or 20
 card.AnchorPoint=Vector2.new(.5,1); card.Position=UDim2.new(.5,0,1,-100)
 if toast then
  card.Title.Text="READY"
  card.Instruction.Text="Catch more pets. Earn cash. Upgrade!"
  spotlight:Clear(); return
 end
 card.Title.Text=string.format("%d / 9 • %s",step,titles[step] or "")
 if inShop and step~=2 then
  button(shop:FindFirstChild("Close",true),"Close the shop to continue.")
 elseif inTrailShop and step~=9 then
  button(trailShop:FindFirstChild("CloseButton",true),"Close the trail shop to continue.")
 elseif step==1 then
  local plot=player:GetAttribute("PlotName")
  local spot=plot and find(workspace,"Treadmills",plot,"Spot")
  local stats=player:FindFirstChild("leaderstats")
  local stamina=stats and stats:FindFirstChild("Stamina")
  local goal=player:GetAttribute("TutorialSpeedGoal") or 500
  if spot and (root.Position-spot.Position).Magnitude<60 then
   local amount=math.min(goal,stamina and stamina.Value or 0)
   world((spot.CFrame*CFrame.new(0,2,0)).Position,"YOUR TREADMILL",string.format("Walk onto your treadmill.\nTrain: %d / %d stamina • Jump to get off.",amount,goal),105)
  else button(find(pg,"GameUI","TopButtons","Base"),"Tap BASE, then walk onto your treadmill.") end
 elseif step==2 then
  if inShop then
   local count=shop:FindFirstChild("Count",true)
   local index=count and tonumber(count.Text:match("%d+")) or 1
   if index~=1 and not player:GetAttribute("EquippedWeapon") then
    button(shop:FindFirstChild("Previous",true),"Use the left arrow to choose Python.")
   else
    button(find(shop:FindFirstChild("Card",true),"Buy"),player:GetAttribute("Owns_Python") and "Tap EQUIP to use Python." or "Tap BUY to get Python for $50.")
   end
  elseif player:GetAttribute("Owns_Python") then
   button(find(pg,"AnimalInventoryUI","Hotbar","Weapon"),"Tap the gun in your hotbar to equip it.")
  else
   local zone=find(workspace,"WeaponShop","ShopView","ShopZone")
   if zone and (root.Position-zone.Position).Magnitude<35 then
    world(zone.Position+Vector3.new(0,2,0),"WEAPON SHOP","Walk into the shop ring.",105)
   else button(find(pg,"GameUI","TopButtons","Weapons"),"Tap WEAPONS to visit the gun shop.") end
  end
 elseif step==3 or step==4 then
  local tool=char:FindFirstChildOfClass("Tool")
  if not tool or not tool:GetAttribute("WeaponId") then
   button(find(pg,"AnimalInventoryUI","Hotbar","Weapon"),"Tap the gun in your hotbar to equip it.")
  else
   if now>=nextSearch or not animal or not animal.Parent or animal:GetAttribute("Dead") then
    animal=nearest(workspace:FindFirstChild("Animals"),root,false); nextSearch=now+.25
   end
   local text=step==3 and (touch and "Aim at the marked animal. Tap to shoot." or "Hold the right mouse button to aim at the animal.")
    or (touch and "Keep tapping to shoot until its health bar is empty." or "Keep aiming and left-click to shoot.\nEmpty its health bar to stun it.")
   world(animal and animal.PrimaryPart and animal.PrimaryPart.Position,"FIRST CATCH",text,80)
  end
 elseif step==5 then
  if now>=nextSearch or not body or not body.Parent then
   body=nearest(workspace:FindFirstChild("AnimalBodies"),root,true); nextSearch=now+.2
  end
  world(body and body.PrimaryPart and body.PrimaryPart.Position,"STUNNED ANIMAL",touch and "Hold the pickup prompt." or "Walk to the stunned animal.\nHold E to pick it up.",90)
 elseif step==6 then
  world(homePoint(root),"BACK TO YOUR BASE","Follow the beam home.\nDrag your animal across the red line.",110)
 elseif step==7 then
  local pets=find(pg,"GameUI","Frames","Pets")
  if visible(pets) then button(pets:FindFirstChild("EquipBestArtwork",true),"Tap EQUIP BEST to put pets in your plot.")
  else button(find(pg,"GameUI","RightButtons","Pets"),"Tap PETS to place your new animal.") end
 elseif step==8 then
  local placed=find(workspace,"PlotAnimals",tostring(player.UserId))
  local model=placed and placed:FindFirstChildWhichIsA("Model")
  local plot=workspace:FindFirstChild(player:GetAttribute("PlotName") or "")
  local part=plot and plot:FindFirstChild("Hitbox")
  spotlight:Clear();card.Instruction.Text="Your pet earns cash every second. Save up for a trail!"
 elseif step==9 then
  local data=require(RS.SpeedData)
  local owned=player:GetAttribute("OwnedTrails") or ""
  local index=1
  for i,t in ipairs(data.Trails) do
   if (","..owned..","):find(","..t.id..",",1,true) then index=i;break end
  end
  local trail=data.Trails[index]
  if inTrailShop then
   trailShop.Actions:Invoke("ScrollTo",index)
   button(find(trailShop,"Window","Cards","Card"..index,"Buy"),owned~="" and "Tap EQUIP to use your trail." or ("Buy the "..trail.name.." for $"..data.Short(trail.price)..".\nIt gives "..trail.gain.."x Stamina on treadmills."))
  else
   local circle=workspace:FindFirstChild("Circle")
   if circle and (root.Position-circle.Position).Magnitude<35 then
    world(circle.Position+Vector3.new(0,2,0),"TRAIL SHOP","Walk into the trail shop ring. Buy a trail to train faster.",105)
   else button(find(pg,"GameUI","TopButtons","Trail"),"Tap TRAIL, then buy a trail to train faster.") end
  end
 end
 -- Put the instructions away from bottom targets (hotbar, world hole, shop BUY).
 local targetPoint=spotlight.mode=="world" and spotlight.position and camera:WorldToViewportPoint(spotlight.position)
 if inShop or inTrailShop then
  if vp.Y<500 then
   local shopWindow=inTrailShop and trailShop:FindFirstChild("Window") or shop:FindFirstChild("Window",true)
   local width=shopWindow and shopWindow.AbsoluteSize.X or math.min(450,vp.X-24)
   local left=shopWindow and shopWindow.AbsolutePosition.X or (vp.X-width)/2
   card.Size=UDim2.fromOffset(math.min(450,width*.68),88)
   card.AnchorPoint=Vector2.zero;card.Position=UDim2.fromOffset(left+width*.04,4)
   card.Title.Size=UDim2.new(1,-64,.2,0)
   card.Instruction.Size=UDim2.new(1,-64,.62,0);card.Instruction.TextScaled=true
   card.Skip.Size=UDim2.fromOffset(40,60);card.Skip.TextSize=14
  else card.Position=UDim2.new(.5,0,1,-6) end
 elseif vp.Y<480 and targetPoint and targetPoint.Z>0 then
  if targetPoint.Y>vp.Y*.5 then
   card.AnchorPoint=Vector2.new(.5,0); card.Position=UDim2.new(.5,0,0,12)
  else card.Position=UDim2.new(.5,0,1,-12) end
 elseif (targetPoint and targetPoint.Z>0 and targetPoint.Y>vp.Y-260) then
  card.AnchorPoint=Vector2.new(.5,0); card.Position=UDim2.new(.5,0,0,90)
 end
 -- An open menu owns the middle of the screen: the card waits below it and world markers hide.
 local menu=not inShop and not inTrailShop and openMenu()
 if menu then card.AnchorPoint=Vector2.new(.5,1); card.Position=UDim2.new(.5,0,1,-6) end
 spotlight:Update(camera,now)
 if spotlight.mode=="world" then
  if menu then for _,object in ipairs(gui.WorldSpotlight:GetChildren()) do if object:IsA("GuiObject") then object.Visible=false end end end
  if spotlight.marker then spotlight.marker.Enabled=not menu end
 end
end
RunService:BindToRenderStep("TutorialSpotlight",Enum.RenderPriority.Camera.Value+10,function() update(os.clock()) end)
script.Destroying:Connect(function() RunService:UnbindFromRenderStep("TutorialSpotlight"); spotlight:Clear() end)
