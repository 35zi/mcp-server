-- One short instruction outside menus; only a button spotlight inside shops.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local gui=pg:WaitForChild("TutorialUI")
gui.ScreenInsets=Enum.ScreenInsets.None
gui.DisplayOrder=100
local remote=RS:WaitForChild("TutorialRemote")
local spotlight=require(RS:WaitForChild("TutorialSpotlight")).new(gui)
local card=gui.StepCard
card.BackgroundTransparency=1
card.BorderSizePixel=0
for _,child in ipairs(card:GetChildren()) do
 if child:IsA("GuiObject") then child.Visible=child==card.Instruction
 elseif child:IsA("UIStroke") then child.Enabled=false end
end
gui.Help.Visible=false
local instruction=card.Instruction
instruction.BackgroundTransparency=1
instruction.TextColor3=Color3.new(1,1,1)
instruction.TextStrokeTransparency=1
instruction.Font=Enum.Font.GothamBlack
instruction.TextWrapped=true
instruction.TextXAlignment=Enum.TextXAlignment.Center
instruction.TextScaled=true
instruction.Position=UDim2.new()
instruction.Size=UDim2.fromScale(1,1)
for _,child in ipairs(instruction:GetChildren()) do
 if child:IsA("UIStroke") or child:IsA("UITextSizeConstraint") then child:Destroy() end
end
local outline=Instance.new("UIStroke")
outline.Color=Color3.new();outline.Thickness=3;outline.Parent=instruction
local limit=Instance.new("UITextSizeConstraint")
limit.MinTextSize=16;limit.MaxTextSize=24;limit.Parent=instruction
local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
local animal,body,nextSearch=nil,nil,0
local lastStep=nil
local lastScroll=nil
local speedData=require(RS:WaitForChild("SpeedData"))
-- Skip button: top right under the Music/SFX/VFX toggles, the same 3D style (FeedbackClient). The first tap turns it gold
-- ("TAP AGAIN"), the second sends TutorialRemote "Skip" (TutorialService finishes the tutorial and saves it).
local DARK=Color3.fromRGB(8,20,28)
local SKIP_FACE,SKIP_BASE=Color3.fromRGB(242,66,54),Color3.fromRGB(146,47,43)
local SURE_FACE,SURE_BASE=Color3.fromRGB(255,188,47),Color3.fromRGB(153,117,39)
local skip=Instance.new("TextButton")
skip.Name="SkipTutorial";skip.AnchorPoint=Vector2.new(1,0);skip.Size=UDim2.fromOffset(154,42)
skip.Text="";skip.AutoButtonColor=false;skip.BorderSizePixel=0;skip.BackgroundColor3=SKIP_BASE;skip.ZIndex=20;skip.Visible=false
local skipCorner=Instance.new("UICorner");skipCorner.CornerRadius=UDim.new(0,8);skipCorner.Parent=skip
local skipStroke=Instance.new("UIStroke");skipStroke.Color=DARK;skipStroke.Thickness=2.5;skipStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;skipStroke.Parent=skip
local skipFace=Instance.new("Frame");skipFace.Name="Face";skipFace.Position=UDim2.fromOffset(2,2);skipFace.Size=UDim2.new(1,-4,1,-8)
skipFace.BackgroundColor3=SKIP_FACE;skipFace.BorderSizePixel=0;skipFace.ZIndex=21;skipFace.Parent=skip
local skipFaceCorner=Instance.new("UICorner");skipFaceCorner.CornerRadius=UDim.new(0,6);skipFaceCorner.Parent=skipFace
local skipShade=Instance.new("UIGradient");skipShade.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(205,205,205));skipShade.Rotation=90;skipShade.Parent=skipFace
local skipLabel=Instance.new("TextLabel");skipLabel.Name="Label";skipLabel.BackgroundTransparency=1
skipLabel.Position=UDim2.fromScale(.06,.12);skipLabel.Size=UDim2.fromScale(.88,.76);skipLabel.ZIndex=22
skipLabel.Font=Enum.Font.GothamBlack;skipLabel.TextScaled=true;skipLabel.TextColor3=Color3.new(1,1,1);skipLabel.Text="SKIP TUTORIAL";skipLabel.Parent=skipFace
local skipLabelStroke=Instance.new("UIStroke");skipLabelStroke.Color=DARK;skipLabelStroke.Thickness=1.5;skipLabelStroke.Parent=skipLabel
local skipLimit=Instance.new("UITextSizeConstraint");skipLimit.MinTextSize=9;skipLimit.MaxTextSize=15;skipLimit.Parent=skipLabel
skip.Parent=gui
require(RS:WaitForChild("UIMotion")).BindButton(skip)
local confirmUntil,skipped=0,false
skip.Activated:Connect(function()
 if os.clock()<confirmUntil then
  confirmUntil=0;skipped=true;skip.Visible=false
  remote:FireServer("Skip")
 else confirmUntil=os.clock()+3 end
end)
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
 card.Instruction.Text=text or ""
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
 if not line then
  local z=RS.GameTravelZones:GetAttribute("BoundaryZ")
  return spawn and spawn.Position or (z and Vector3.new(root.Position.X,root.Position.Y,z+14))
 end
 local normal=line.Size.X<line.Size.Z and line.CFrame.RightVector or line.CFrame.LookVector
 normal=Vector3.new(normal.X,0,normal.Z).Unit
 local sign=spawn and math.sign((spawn.Position-line.Position):Dot(normal)) or 1
 if sign==0 then sign=1 end
 local localPos=line.CFrame:PointToObjectSpace(root.Position)
 local pos=line.CFrame:PointToWorldSpace(Vector3.new(math.clamp(localPos.X,-line.Size.X*.45,line.Size.X*.45),0,math.clamp(localPos.Z,-line.Size.Z*.45,line.Size.Z*.45)))
 return pos+normal*sign*14+Vector3.new(0,3,0)
end

UIS.InputBegan:Connect(function(input,processed)
 if processed or player:GetAttribute("TutorialStep")~=3 then return end
 if input.UserInputType==Enum.UserInputType.MouseButton2 or input.KeyCode==Enum.KeyCode.ButtonL2
  or (touch and input.UserInputType==Enum.UserInputType.Touch) then remote:FireServer("Aim") end
end)
local function trailChoice()
 local owned=","..(player:GetAttribute("OwnedTrails") or "")..","
 for i,trail in ipairs(speedData.Trails) do if owned:find(","..trail.id..",",1,true) then return i,0 end end
 return 1,speedData.Trails[1].price
end
local function update(now)
 local camera=workspace.CurrentCamera
 if not camera then return end
 local step=player:GetAttribute("TutorialStep") or 0
 if step~=lastStep then
  lastStep=step;spotlight:Clear();animal=nil;body=nil;nextSearch=0;lastScroll=nil;skipped=false;confirmUntil=0
 end
 local loading=pg:FindFirstChild("LoadingScreen")
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local shop=pg:FindFirstChild("WeaponShopUI")
 local trailShop=pg:FindFirstChild("TrailShop")
 local inShop=shop and shop.Enabled
 local inTrails=trailShop and trailShop.Enabled
 gui.Enabled=true
 local active=step>=1 and step<=9 and not (loading and loading.Enabled)
  and root~=nil and humanoid and humanoid.Health>0
 card.Visible=active and not inShop and not inTrails or false
 skip.Visible=card.Visible and not skipped
 if not active then spotlight:Clear();return end
 local vp=camera.ViewportSize
 -- right edge = the toggles' right edge, top = 8 px under them (UIMotion re-centres the anchor, so place by the anchor)
 local toggles=find(pg,"AudioControls","Toggles")
 local skipRight,skipTop=vp.X-12,60
 if toggles then
  skipRight=toggles.AbsolutePosition.X+toggles.AbsoluteSize.X-gui.AbsolutePosition.X
  skipTop=toggles.AbsolutePosition.Y+toggles.AbsoluteSize.Y-gui.AbsolutePosition.Y+8
 end
 local skipSize=skip.Size
 skip.Position=UDim2.fromOffset(skipRight-(1-skip.AnchorPoint.X)*skipSize.X.Offset,skipTop+skip.AnchorPoint.Y*skipSize.Y.Offset)
 local sure=now<confirmUntil
 skipLabel.Text=sure and "TAP AGAIN" or "SKIP TUTORIAL"
 skipFace.BackgroundColor3=sure and SURE_FACE or SKIP_FACE
 skip.BackgroundColor3=sure and SURE_BASE or SKIP_BASE
 local top=find(pg,"GameUI","TopButtons")
 local bottom=-math.huge
 if top then for _,child in ipairs(top:GetChildren()) do
  if child:IsA("GuiObject") then bottom=math.max(bottom,child.AbsolutePosition.Y+child.AbsoluteSize.Y) end
 end end
 card.AnchorPoint=Vector2.new(.5,0)
 card.Position=UDim2.new(.5,0,0,(bottom>-math.huge and bottom-gui.AbsolutePosition.Y+8 or 80))
 card.Size=UDim2.fromOffset(math.min(600,vp.X-28),44)
 limit.MaxTextSize=vp.X<480 and 20 or 24
 local wallet=find(player,"PlayerStats","Cash")
 local money=wallet and wallet.Value or 0
 if inShop then
  if step==2 and not player:GetAttribute("EquippedWeapon") then
   local count=shop:FindFirstChild("Count",true)
   local index=count and tonumber(count.Text:match("%d+")) or 1
   if index~=1 then button(shop:FindFirstChild("Previous",true))
   else button(find(shop:FindFirstChild("Card",true),"Buy")) end
  else button(shop:FindFirstChild("Close",true)) end
 elseif inTrails then
  local index,cost=trailChoice()
  if step==9 and money>=cost then
   if lastScroll~=index then
    lastScroll=index
    local actions=trailShop:FindFirstChild("Actions")
    if actions then actions:Invoke("ScrollTo",index) end
   end
   button(find(trailShop,"Window","Cards","Card"..index,"Buy"))
  else button(trailShop:FindFirstChild("CloseButton",true)) end
 elseif step==1 then
  local plot=player:GetAttribute("PlotName")
  local spot=plot and find(workspace,"Treadmills",plot,"Spot")
  if spot and (root.Position-spot.Position).Magnitude<60 then
   world(spot.Position+Vector3.new(0,2,0),"","Train to 500 Stamina.",105)
  else button(find(pg,"GameUI","TopButtons","Base"),"Go to your treadmill.") end
 elseif step==2 then
  if player:GetAttribute("Owns_Python") then
   button(find(pg,"AnimalInventoryUI","Hotbar","Weapon"),"Equip your gun.")
  else
   local zone=find(workspace,"WeaponShop","ShopView","ShopZone")
   if zone and (root.Position-zone.Position).Magnitude<35 then
    world(zone.Position+Vector3.new(0,2,0),"","Get a gun.",105)
   else button(find(pg,"GameUI","TopButtons","Weapons"),"Get a gun.") end
  end
 elseif step==3 or step==4 then
  local tool=character:FindFirstChildOfClass("Tool")
  if not tool or not tool:GetAttribute("WeaponId") then
   button(find(pg,"AnimalInventoryUI","Hotbar","Weapon"),"Equip your gun.")
  else
   if now>=nextSearch or not animal or not animal.Parent or animal:GetAttribute("Dead") then
    animal=nearest(workspace:FindFirstChild("Animals"),root,false);nextSearch=now+.25
   end
   local text=step==3 and (touch and "Tap to aim." or "Hold right-click to aim.") or "Shoot to knock the animal."
   world(animal and animal.PrimaryPart and animal.PrimaryPart.Position,"",text,80)
  end
 elseif step==5 then
  if now>=nextSearch or not body or not body.Parent then
   body=nearest(workspace:FindFirstChild("AnimalBodies"),root,true);nextSearch=now+.2
  end
  world(body and body.PrimaryPart and body.PrimaryPart.Position,"",touch and "Hold to pick it up." or "Hold E to pick it up.",90)
 elseif step==6 then
  world(homePoint(root),"","Bring your animal home.",110)
 elseif step==7 then
  local pets=find(pg,"GameUI","Frames","Pets")
  if visible(pets) then button(pets:FindFirstChild("EquipBestArtwork",true),"Place your pet.")
  else button(find(pg,"GameUI","RightButtons","Pets"),"Place your pet.") end
 elseif step==8 then
  local _,cost=trailChoice()
  spotlight:Clear()
  instruction.Text="Save $"..speedData.Short(math.max(0,cost-money)).." more for a trail."
 elseif step==9 then
  local _,cost=trailChoice()
  if money<cost then
   spotlight:Clear();instruction.Text="Save $"..speedData.Short(cost-money).." more for a trail."
  else
   local circle=workspace:FindFirstChild("Circle")
   if circle and (root.Position-circle.Position).Magnitude<35 then
    world(circle.Position+Vector3.new(0,2,0),"","Get a trail.",105)
   else button(find(pg,"GameUI","TopButtons","Trail"),"Get a trail.") end
  end
 end
 local menu=not inShop and not inTrails and openMenu()
 if menu then skip.Visible=false end
 if menu and spotlight.mode=="world" then spotlight:Clear() end
 spotlight:Update(camera,now)
end
RunService:BindToRenderStep("TutorialSpotlight",Enum.RenderPriority.Camera.Value+10,function() update(os.clock()) end)
script.Destroying:Connect(function() RunService:UnbindFromRenderStep("TutorialSpotlight");spotlight:Clear() end)
