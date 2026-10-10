-- Automatic button audio, confirmed rewards, music routing and player controls.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SoundService=game:GetService("SoundService")
local ContentProvider=game:GetService("ContentProvider")
local Tween=game:GetService("TweenService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local F=require(RS:WaitForChild("GameFeedback"))
local audio=RS:WaitForChild("GameAudio")
local bound=setmetatable({},{__mode="k"})
local function bind(button)
 if not button:IsA("GuiButton") or bound[button] then return end
 bound[button]=true
 button.MouseEnter:Connect(function() if button.Interactable and button.Active then F.Play("UIHover",1,.08) end end)
 button.Activated:Connect(function()
  if not button.Interactable or not button.Active then return end
  F.Play("UIClick") F.Ripple(button)
 end)
end
pg.DescendantAdded:Connect(bind)
for _,v in pg:GetDescendants() do bind(v) end
-- Route cloned game sounds, including existing gun/catch/treadmill sounds, through the SFX control.
local function route(sound)
 if sound:IsA("Sound") and audio:FindFirstChild(sound.Name) and sound.Name~="LobbyMusic" and sound.Name~="RangeMusic" then sound.SoundGroup=F.SFXGroup end
end
game.DescendantAdded:Connect(route)
for _,v in game:GetDescendants() do route(v) end
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({audio.UIClick,audio.UIError,audio.UIPurchase,audio.UIEquip}) end) end)
local zones=require(RS:WaitForChild("GameTravelZones"))
local musicTracks={}
local lastTargets={LobbyMusic=-1,RangeMusic=-1}
for _,name in {"LobbyMusic","RangeMusic"} do
 local template=audio:WaitForChild(name)
 local sound=template:Clone();sound.SoundGroup=F.MusicGroup;sound.Volume=0;sound.Looped=true;sound.Parent=SoundService
 musicTracks[name]=sound
 local function syncTrack()
  sound:Stop();sound.SoundId=template.SoundId;lastTargets[name]=-1
  if sound.SoundId~="" then sound:Play() end
 end
 template:GetPropertyChangedSignal("SoundId"):Connect(syncTrack);syncTrack()
end
local controls=Instance.new("ScreenGui") controls.Name="AudioControls" controls.ResetOnSpawn=false controls.DisplayOrder=15 controls.IgnoreGuiInset=true controls.ScreenInsets=Enum.ScreenInsets.None controls.Parent=pg
local strip=Instance.new("Frame") strip.Name="Toggles" strip.BackgroundTransparency=1 strip.AnchorPoint=Vector2.new(1,0)
strip.Position=UDim2.new(1,-12,0,8) strip.Size=UDim2.fromOffset(234,44) strip.Parent=controls
-- 3D game buttons like the GameUI ones: darker base, bright face with a soft gradient, icon + name + state.
local DARK=Color3.fromRGB(8,20,28)
local ON_FACE,ON_BASE=Color3.fromRGB(87,220,65),Color3.fromRGB(56,136,49)
local OFF_FACE,OFF_BASE=Color3.fromRGB(242,66,54),Color3.fromRGB(146,47,43)
local LOW_FACE,LOW_BASE=Color3.fromRGB(255,188,47),Color3.fromRGB(153,117,39)
local buttons,parts={},{}
local function caption(parent,name,position,size,maxSize)
 local l=Instance.new("TextLabel") l.Name=name l.BackgroundTransparency=1 l.Position=position l.Size=size
 l.Font=Enum.Font.GothamBlack l.TextScaled=true l.TextColor3=Color3.new(1,1,1) l.Text=""
 local s=Instance.new("UIStroke") s.Color=DARK s.Thickness=1.5 s.Parent=l
 local c=Instance.new("UITextSizeConstraint") c.MinTextSize=8 c.MaxTextSize=maxSize c.Parent=l
 l.Parent=parent return l
end
for i,row in {{"Music","MusicMuted","🎵"},{"SFX","SFXMuted","🔔"},{"VFX","EffectsReduced","✨"}} do
 local b=Instance.new("TextButton") b.Name=row[1] b.Size=UDim2.fromOffset(74,44) b.Position=UDim2.fromOffset((i-1)*80,0)
 b.Text="" b.BackgroundColor3=ON_BASE b.BorderSizePixel=0 b.AutoButtonColor=false
 local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,8) corner.Parent=b
 local stroke=Instance.new("UIStroke") stroke.Color=DARK stroke.Thickness=2.5 stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border stroke.Parent=b
 local face=Instance.new("Frame") face.Name="Face" face.Position=UDim2.fromOffset(2,2) face.Size=UDim2.new(1,-4,1,-8) face.BackgroundColor3=ON_FACE face.BorderSizePixel=0 face.Parent=b
 local faceCorner=Instance.new("UICorner") faceCorner.CornerRadius=UDim.new(0,6) faceCorner.Parent=face
 local shade=Instance.new("UIGradient") shade.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(205,205,205)) shade.Rotation=90 shade.Parent=face
 caption(face,"Icon",UDim2.fromScale(.04,.08),UDim2.fromScale(.3,.84),20).Text=row[3]
 local name=caption(face,"Name",UDim2.fromScale(.34,.06),UDim2.fromScale(.62,.46),12) name.Text=string.upper(row[1])
 local state=caption(face,"State",UDim2.fromScale(.34,.5),UDim2.fromScale(.62,.44),12)
 b.MouseButton1Down:Connect(function() face.Position=UDim2.fromOffset(2,4) end)
 b.MouseButton1Up:Connect(function() face.Position=UDim2.fromOffset(2,2) end)
 b.MouseLeave:Connect(function() face.Position=UDim2.fromOffset(2,2) end)
 b.Parent=strip buttons[row[2]]=b parts[row[2]]={face=face,state=state}
 b.Activated:Connect(function() player:SetAttribute(row[2],not player:GetAttribute(row[2])) end)
end
local function resizeControls()
 local vp=workspace.CurrentCamera.ViewportSize
 strip.Position=UDim2.new(1,-12,0,vp.X<vp.Y and 145 or vp.X<900 and 82 or 8)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeControls)
resizeControls()
local activeTweens={}
local function settings()
 F.SFXGroup.Volume=player:GetAttribute("SFXMuted") and 0 or 1
 for attr,b in buttons do
  local off=player:GetAttribute(attr)==true
  local low=off and attr=="EffectsReduced"
  parts[attr].state.Text=off and (low and "LOW" or "OFF") or "ON"
  parts[attr].face.BackgroundColor3=low and LOW_FACE or off and OFF_FACE or ON_FACE
  b.BackgroundColor3=low and LOW_BASE or off and OFF_BASE or ON_BASE
 end
end
for attr in buttons do player:GetAttributeChangedSignal(attr):Connect(settings) end
settings()
task.spawn(function()
 while controls.Parent do
  local loading=pg:FindFirstChild("LoadingScreen")
  controls.Enabled=loading==nil
  buttons.MusicMuted.Visible=musicTracks.LobbyMusic.SoundId~="" or musicTracks.RangeMusic.SoundId~=""
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local inRange=root and zones.InShootingRange(root.Position) or false
  local muted=loading~=nil or player:GetAttribute("MusicMuted")==true
  -- The Suno range slot stays silent until an uploaded Roblox audio ID is assigned.
  local targets={LobbyMusic=not muted and not inRange and .22 or 0,RangeMusic=not muted and inRange and .16 or 0}
  for name,sound in musicTracks do
   local volume=sound.SoundId~="" and targets[name] or 0
   if lastTargets[name]~=volume then
    lastTargets[name]=volume
    if activeTweens[name] then activeTweens[name]:Cancel() end
    activeTweens[name]=Tween:Create(sound,TweenInfo.new(1.2),{Volume=volume})
    activeTweens[name]:Play()
   end
  end
  task.wait(.3)
 end
end)
-- Pet delivery already has a catch jingle and card: add only the world burst.
RS:WaitForChild("AnimalEvent").OnClientEvent:Connect(function(kind,data)
 if kind=="Delivered" then
  local r=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if r then F.WorldBurst(r.Position,Color3.fromRGB(255,218,56)) end
 elseif kind=="Notice" and data and data.text then
  local message=string.lower(data.text)
  if message:find("too heavy",1,true) or message:find("can't",1,true) or message:find("cannot",1,true) then F.Error(data.text) end
 end
end)
pg:SetAttribute("FeedbackReady",true)
