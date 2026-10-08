-- GameUITeleports: the client names a destination; the server resolves its position.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local remote=ReplicatedStorage:FindFirstChild("GameUITeleport") or Instance.new("RemoteFunction")
remote.Name="GameUITeleport" remote.Parent=ReplicatedStorage
local last={}
local function floorAt(position,character)
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 local excluded={character}
 for _,name in {"WeaponShop","AnimalSpawnZones","Animals","AnimalBodies","PlotAnimals","Decor"} do
  local object=workspace:FindFirstChild(name) if object then table.insert(excluded,object) end
 end
 for _,object in workspace:GetChildren() do if object:IsA("Model") and object.Name:match("^Plot%d+$") then
  local hitbox=object:FindFirstChild("Hitbox") if hitbox then table.insert(excluded,hitbox) end
 end end
 params.FilterDescendantsInstances=excluded
 local hit=workspace:Raycast(position+Vector3.new(0,50,0),Vector3.new(0,-150,0),params)
 return hit and hit.Position.Y or position.Y
end
remote.OnServerInvoke=function(player,destination)
 if destination~="Base" and destination~="Weapons" and destination~="Speed" then return false,"Unknown destination." end
 local now=os.clock()
 if now-(last[player] or -math.huge)<.8 then return false,"Please wait a moment." end
 last[player]=now
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root or not humanoid or humanoid.Health<=0 then return false,"Wait for your character to spawn." end
 if player:GetAttribute("Carrying") then return false,"Bring your animal home or drop it before teleporting." end
 local position,look
 if destination=="Base" then
  local plotName=player:GetAttribute("PlotName")
  local plot=type(plotName)=="string" and workspace:FindFirstChild(plotName)
  local spawn=plot and plot:FindFirstChild("SpawnPoint")
  if not spawn then return false,"You don't have a base yet." end
  if plot:GetAttribute("OwnerUserId")~=player.UserId then return false,"This base isn't assigned to you." end
  position=spawn.Position look=spawn.CFrame.LookVector
 else
  local shop=workspace:FindFirstChild("WeaponShop")
  local view=shop and shop:FindFirstChild("ShopView")
  local zone=view and view:FindFirstChild("ShopZone")
  local preview=view and view:FindFirstChild("PreviewSpot")
  if not zone then return false,"The weapon shop isn't ready." end
  position=zone.Position
  look=preview and (preview.Position-zone.Position) or Vector3.new(0,0,-1)
  if destination=="Speed" then
   local spawn=workspace:FindFirstChild("SpawnLocation")
   local centre=spawn and spawn.Position.X or 0
   position=Vector3.new(centre*2-position.X,position.Y,position.Z)
   look=Vector3.new(-look.X,look.Y,look.Z)
  end
 end
 local y=floorAt(position,character)+humanoid.HipHeight+root.Size.Y/2+.15
 local target=Vector3.new(position.X,y,position.Z)
 look=Vector3.new(look.X,0,look.Z)
 if look.Magnitude<.01 then look=Vector3.new(0,0,-1) end
 -- Shift the whole character so its HumanoidRootPart, rather than its model pivot, lands at the target.
 local desired=CFrame.lookAt(target,target+look)
 character:PivotTo(desired*root.CFrame:ToObjectSpace(character:GetPivot()))
 root.AssemblyLinearVelocity=Vector3.zero root.AssemblyAngularVelocity=Vector3.zero
 return true,destination=="Base" and "Back at your base!" or destination=="Weapons" and "Weapon shop!" or "Speed area!"
end
Players.PlayerRemoving:Connect(function(player) last[player]=nil end)

