-- WeaponSightSetup (ReplicatedStorage): repeatable compact AK front sight.
local Setup={}
function Setup.Apply(tool)
 if tool:GetAttribute("WeaponId")~="AutomaticRifle" then return end
 local handle=tool:FindFirstChild("Handle")
 if not handle then return end
 local old=tool:FindFirstChild("CompactFrontSight")
 if old then old:Destroy() end
 -- Imported closed hood/base obscured the aim point. Replace it with an open U and a red post dot.
 for _,p in tool:GetDescendants() do
  if p:IsA("BasePart") and (p.Name=="AutomaticRifle_Front_Sight_Hood" or p.Name=="AutomaticRifle_Front_Sight_Base") then
   p.Transparency=1
  end
 end
 local model=Instance.new("Model") model.Name="CompactFrontSight" model.Parent=tool
 local center=Vector3.new(0,1.04835,-2.30769)
 local dark=Color3.fromRGB(35,42,48)
 local function part(name,size,cf,color)
  local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=handle.CFrame*cf
  p.Color=color or dark p.Material=Enum.Material.SmoothPlastic
  p.Massless=true p.CanCollide=false p.CanQuery=false p.CanTouch=false
  p.Parent=model
  local w=Instance.new("Weld") w.Part0=handle w.Part1=p w.C0=cf w.Parent=p
  return p
 end
 -- Open upper third of the protective hood, like the reference.
 for i=0,15 do
  local a=math.rad(145+i*250/16) local b=math.rad(145+(i+1)*250/16)
  local p=center+Vector3.new(math.cos(a)*0.135,math.sin(a)*0.135,0)
  local q=center+Vector3.new(math.cos(b)*0.135,math.sin(b)*0.135,0)
  part("AutomaticRifle_SightU_"..i,Vector3.new(0.027,0.027,(q-p).Magnitude+0.006),CFrame.lookAt((p+q)/2,q))
 end
 part("AutomaticRifle_SightPost",Vector3.new(0.04,0.13,0.045),CFrame.new(center+Vector3.new(0,-0.061,0)))
 local target=center+Vector3.new(0,0,0.05)
 local red=part("AutomaticRifle_FrontRedDot",Vector3.new(0.04,0.04,0.018),CFrame.new(target),Color3.fromRGB(255,65,35))
 red.Material=Enum.Material.Neon
 tool:SetAttribute("SightTarget",target)
 tool:SetAttribute("EyePos",Vector3.new(0,target.Y,-0.47472))
 tool:SetAttribute("SightVersion",2)
end
return Setup

