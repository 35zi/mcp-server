-- Studio Server Command Bar / Studio MCP only, during Play. Never install as an auto-running game Script.
-- Uses the production shot handler with only its event subscription exposed for direct calls.
-- A dummy shooter replaces the second network client; the victim is the real connected player.
local RS=game:GetService("ReplicatedStorage")
local SSS=game:GetService("ServerScriptService")
local SS=game:GetService("ServerStorage")
local player=assert(game.Players:GetPlayers()[1],"Start Play with a player")
local data=require(RS.AnimalData)
local manager=require(SSS.AnimalManager)
local stats=require(RS.WeaponStats)
local catalog=require(RS.WeaponShopCatalog)
assert(stats.forId(catalog,"AutomaticRifle").Range==568)
assert(stats.forId(catalog,"BoltSniper").Range==1400)
assert(data.WeightText(2.4)=="2.40 kg")
assert(not data.DisplayName("Bunny","Large","None"):find("Large"),"Legacy size leaked into display")
local rng=Random.new(42)
local counts={normal=0,tiny=0,giant=0}
for _=1,10000 do
 local w=data.RollWeight("Bunny",rng)
 assert(w>0 and w==w)
 local kind=w<1.2 and "tiny" or w>4.5 and "giant" or "normal"
 counts[kind]+=1
end
assert(counts.normal>8900 and counts.normal<9500)
assert(counts.tiny>250 and counts.giant>250)
for _,weight in ipairs({.288,2.4,19.2}) do
 local model=assert(manager.BuildModel("Bunny",weight,"None"))
 local normal=assert(manager.BuildModel("Bunny",2.4,"None"))
 local scale=(weight/2.4)^(1/3)
 for _,part in ipairs(normal:GetDescendants()) do
  if part:IsA("BasePart") then
   local actual=model:FindFirstChild(part.Name,true)
   assert(actual and (actual.Size-part.Size*scale).Magnitude<.001,"Bad proportional scale")
  end
 end
 assert(model:GetAttribute("WeightKg")==weight)
 model:Destroy() normal:Destroy()
end
local module=Instance.new("ModuleScript")
local fake=Instance.new("Model")
local wall=Instance.new("Part")
local root=player.Character.HumanoidRootPart
local original=player.Character:GetPivot()
local originalAnchored=root.Anchored
local humanoid=player.Character.Humanoid
local health=humanoid.Health
local ok,err=xpcall(function()
 local source=SSS.WeaponCombatService.Source
 local n
 source,n=source:gsub("combat.OnServerEvent:Connect%(function%(","local handleShot = function(",1)
 assert(n==1,"Handler subscription changed; update the harness")
 source,n=source:gsub("end%)\n\nPlayers.PlayerRemoving","end\n\nPlayers.PlayerRemoving",1)
 assert(n==1,"Handler ending changed; update the harness")
 module.Name="QACombatHandler" module.Source=source.."\nreturn handleShot" module.Parent=SSS
 local handle=require(module)
 root.Anchored=true player.Character:PivotTo(CFrame.new(0,100,-600))
 fake.Name="QAShooter"
 local h=Instance.new("Humanoid") h.Parent=fake
 local head=Instance.new("Part") head.Name="Head" head.Anchored=true
 head.Position=Vector3.new(0,100,0) head.Parent=fake
 SS.WeaponTools.BoltSniper:Clone().Parent=fake fake.Parent=workspace
 local shooter={Character=fake,UserId=123,GetAttribute=function(_,name)return name=="Owns_BoltSniper" end}
 local knock=require(SSS.PlayerKnockback)
 handle(shooter,"BoltSniper",player.Character.Head.Position,true,player.Character.Head)
 assert(knock.IsRagdolled(player),"600-stud shot must ragdoll a player without a carried pet")
 assert(humanoid.Health==health,"Gun must never reduce player health")
 assert(not humanoid.RequiresNeck,"Ragdoll must protect neck before disabling joints")
 task.wait(1.3)
 assert(not knock.IsRagdolled(player),"Player must stand up")
 assert(humanoid.Health==health and humanoid.RequiresNeck,"Ragdoll must restore safely")
 wall.Anchored=true wall.Size=Vector3.new(20,30,5)
 wall.Position=Vector3.new(0,100,-300) wall.Parent=workspace
 task.wait(1.3)
 handle(shooter,"BoltSniper",player.Character.Head.Position,true,player.Character.Head)
 assert(not knock.IsRagdolled(player),"Client-reported victim must not bypass a wall")
 assert(humanoid.Health==health)
end,debug.traceback)
wall:Destroy() fake:Destroy() module:Destroy()
player.Character:PivotTo(original) root.Anchored=originalAnchored
assert(ok,err)
print("PASS: weight distribution, template scaling, 600-stud nonlethal player shot, recovery, wall validation",counts)
