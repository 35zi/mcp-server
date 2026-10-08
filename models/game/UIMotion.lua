-- UIMotion: shared, event-driven button and menu motion. No RenderStepped loop.
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Motion={}
local buttonStates=setmetatable({},{__mode="k"})
local frameStates=setmetatable({},{__mode="k"})
local pressed=setmetatable({},{__mode="k"})
local function tween(object,seconds,goals,style,direction)
 local t=TweenService:Create(object,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,direction or Enum.EasingDirection.Out),goals)
 t:Play() return t
end
local function buttonTarget(state)
 if state.down then return state.base*.95 end
 return state.base*((state.hover or state.selected) and 1.035 or 1)
end
local function updateButton(button,state,instant)
 if state.animation then state.animation:Cancel() state.animation=nil end
 if not button.Parent then return end
 local target=buttonTarget(state)
 if instant then state.scale.Scale=target
 else state.animation=tween(state.scale,state.down and .07 or .12,{Scale=target}) end
end
function Motion.ResetButtons(root)
 for button,state in buttonStates do
  if button==root or button:IsDescendantOf(root) then
   state.hover=false state.selected=false state.down=false pressed[button]=nil
   updateButton(button,state,true)
  end
 end
end
function Motion.CenterAnchor(button)
 if button.AnchorPoint==Vector2.new(.5,.5) then return end
 local parent=button.Parent
 local managed=parent and (parent:FindFirstChildOfClass("UIListLayout") or parent:FindFirstChildOfClass("UIGridLayout"))
 local delta=Vector2.new(.5,.5)-button.AnchorPoint
 if not managed then
  local size=button.Size
  button.Position+=UDim2.new(size.X.Scale*delta.X,size.X.Offset*delta.X,size.Y.Scale*delta.Y,size.Y.Offset*delta.Y)
 end
 button.AnchorPoint=Vector2.new(.5,.5)
end
local function buttonVisual(button)
 -- Scale only the artwork. Layouts and the clickable area retain a fixed size.
 local class=button:IsA("ImageButton") and "ImageLabel" or "TextLabel"
 local visual=Instance.new(class) visual.Name="MotionVisual"
 local properties={"BackgroundColor3","BackgroundTransparency","BorderSizePixel","BorderColor3","ZIndex","Rotation"}
 if class=="ImageLabel" then
  for _,property in {"Image","ImageColor3","ImageTransparency","ScaleType","SliceCenter","SliceScale","TileSize","ResampleMode"} do table.insert(properties,property) end
 else
  for _,property in {"Text","FontFace","TextSize","TextScaled","TextWrapped","RichText","TextColor3","TextTransparency","TextStrokeColor3","TextStrokeTransparency","TextXAlignment","TextYAlignment","TextTruncate","LineHeight"} do table.insert(properties,property) end
 end
 local bases
 for _,state in frameStates do
  if state.visuals[button] then bases=state.visuals[button] state.visuals[button]=nil end
 end
 for _,property in properties do visual[property]=bases and bases[property] or button[property] end
 visual.AnchorPoint=Vector2.new(.5,.5) visual.Position=UDim2.fromScale(.5,.5) visual.Size=UDim2.fromScale(1,1)
 for _,child in button:GetChildren() do
  if not child:IsA("UIAspectRatioConstraint") and not child:IsA("UISizeConstraint") and not child:IsA("LuaSourceContainer") then child.Parent=visual end
 end
 button.BackgroundTransparency=1 button.BorderSizePixel=0
 if class=="ImageLabel" then button.ImageTransparency=1 else button.TextTransparency=1 button.TextStrokeTransparency=1 end
 visual.Parent=button
 -- Color and caption changes still come from the existing button's public properties.
 for _,property in properties do
  if property~="BackgroundTransparency" and property~="ImageTransparency" and property~="TextTransparency" and property~="TextStrokeTransparency" and property~="BorderSizePixel" then
   button:GetPropertyChangedSignal(property):Connect(function() visual[property]=button[property] end)
  end
 end
 return visual
end
function Motion.BindButton(button)
 if buttonStates[button] or not button:IsA("GuiButton") then return end
 Motion.CenterAnchor(button)
 button.AutoButtonColor=false
 local visual=buttonVisual(button)
 local scale=visual:FindFirstChildOfClass("UIScale")
 if not scale then scale=Instance.new("UIScale") scale.Name="MotionScale" scale.Parent=visual end
 local state={scale=scale,base=scale.Scale,hover=false,selected=false,down=false}
 buttonStates[button]=state
 button.MouseEnter:Connect(function() if button.Active and button.Interactable then state.hover=true updateButton(button,state) end end)
 button.MouseLeave:Connect(function() state.hover=false updateButton(button,state) end)
 button.SelectionGained:Connect(function() state.selected=true updateButton(button,state) end)
 button.SelectionLost:Connect(function() state.selected=false state.down=false pressed[button]=nil updateButton(button,state) end)
 button.InputBegan:Connect(function(input)
  if not button.Active or not button.Interactable then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA then
   state.down=true pressed[button]=input updateButton(button,state)
  end
 end)
 local function availabilityChanged()
  if not button.Active or not button.Interactable then
   state.down=false state.hover=false state.selected=false pressed[button]=nil updateButton(button,state)
  end
 end
 button:GetPropertyChangedSignal("Active"):Connect(availabilityChanged)
 button:GetPropertyChangedSignal("Interactable"):Connect(availabilityChanged)
 button.Destroying:Connect(function()
  if state.animation then state.animation:Cancel() end
  buttonStates[button]=nil pressed[button]=nil
 end)
end
UserInputService.InputEnded:Connect(function(input)
 for button,start in pressed do
  if input==start or (input.UserInputType==Enum.UserInputType.MouseButton1 and start.UserInputType==Enum.UserInputType.MouseButton1) or input.KeyCode==Enum.KeyCode.ButtonA then
   local state=buttonStates[button]
   pressed[button]=nil
   if state then state.down=false updateButton(button,state) end
  end
 end
end)
function Motion.BindButtons(gui)
 for _,node in gui:GetDescendants() do if node:IsA("GuiButton") then Motion.BindButton(node) end end
 gui.DescendantAdded:Connect(function(node)
  if node:IsA("GuiButton") then task.defer(function() if node:IsDescendantOf(gui) then Motion.BindButton(node) end end) end
 end)
 gui:GetPropertyChangedSignal("Enabled"):Connect(function() if not gui.Enabled then Motion.ResetButtons(gui) end end)
 gui.DescendantRemoving:Connect(function(node) if node:IsA("GuiObject") then Motion.ResetButtons(node) end end)
end
local function visualProperties(node)
 if node:IsA("UIStroke") then return {"Transparency"} end
 if not node:IsA("GuiObject") or (node:IsA("GuiButton") and buttonStates[node]) then return {} end
 local properties={"BackgroundTransparency"}
 if node:IsA("ImageLabel") or node:IsA("ImageButton") or node:IsA("ViewportFrame") then table.insert(properties,"ImageTransparency") end
 if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
  table.insert(properties,"TextTransparency") table.insert(properties,"TextStrokeTransparency")
 end
 return properties
end
local function frameState(frame)
 local existing=frameStates[frame] if existing then return existing end
 local scale=Instance.new("UIScale") scale.Name="FrameMotionScale" scale.Parent=frame
 local opacity=Instance.new("NumberValue") opacity.Name="MotionFade" opacity.Value=1 opacity.Parent=frame
 local state={scale=scale,opacity=opacity,position=frame.Position,revision=0,visuals={}}
 frameStates[frame]=state
 local function track(node)
  local properties=visualProperties(node)
  if #properties==0 then return end
  local values={}
  for _,property in properties do values[property]=node[property] end
  state.visuals[node]=values
  for property,value in values do node[property]=value+(1-value)*opacity.Value end
 end
 track(frame) for _,node in frame:GetDescendants() do track(node) end
 frame.DescendantAdded:Connect(track)
 frame.DescendantRemoving:Connect(function(node) state.visuals[node]=nil end)
 opacity.Changed:Connect(function(value)
  for node,values in state.visuals do
   for property,base in values do node[property]=base+(1-base)*value end
  end
 end)
 frame.Destroying:Connect(function()
  for _,t in state.tweens or {} do t:Cancel() end
  table.clear(state.visuals) frameStates[frame]=nil
 end)
 return state
end
function Motion.SetFramePosition(frame,position)
 local state=frameStates[frame]
 if state then
  state.position=position
  if state.tweens and state.tweens[3] then state.tweens[3]:Cancel() end
 end
 frame.Position=position
end
local function offset(position,y) return position+UDim2.fromOffset(0,y) end
function Motion.SetFrame(frame,show,instant)
 local state=frameState(frame)
 state.revision+=1 local revision=state.revision
 for _,t in state.tweens or {} do t:Cancel() end
 state.tweens={}
 Motion.ResetButtons(frame)
 if instant then
  state.scale.Scale=1 state.opacity.Value=show and 0 or 1 frame.Position=state.position frame.Visible=show
  return
 end
 if show then
  if not frame.Visible then
   state.scale.Scale=.94 state.opacity.Value=1 frame.Position=offset(state.position,18)
  end
  frame.Visible=true
  state.tweens={
   tween(state.scale,.22,{Scale=1},Enum.EasingStyle.Quart),
   tween(state.opacity,.18,{Value=0}),
   tween(frame,.22,{Position=state.position},Enum.EasingStyle.Quart),
  }
 elseif frame.Visible then
  state.tweens={
   tween(state.scale,.12,{Scale=.96},Enum.EasingStyle.Quad,Enum.EasingDirection.In),
   tween(state.opacity,.12,{Value=1},Enum.EasingStyle.Quad,Enum.EasingDirection.In),
   tween(frame,.12,{Position=offset(state.position,10)},Enum.EasingStyle.Quad,Enum.EasingDirection.In),
  }
  state.tweens[2].Completed:Once(function(playback)
   if playback==Enum.PlaybackState.Completed and revision==state.revision then
    frame.Visible=false frame.Position=state.position state.scale.Scale=1
   end
  end)
 end
end
return Motion

