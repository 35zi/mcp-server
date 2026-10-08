-- Manual client regression: temporarily place this LocalScript in StarterPlayerScripts.
-- Creates its own invisible fixture, cleans up, and sets Result on success.
local motion=require(game.ReplicatedStorage:WaitForChild("UIMotion"))
local player=game.Players.LocalPlayer
local screen=Instance.new("ScreenGui")
screen.Name="TemporaryMotionFixture" screen.Enabled=false screen.Parent=player:WaitForChild("PlayerGui")
local ok,result=xpcall(function()
 local frame=Instance.new("Frame")
 frame.Visible=false frame.Position=UDim2.fromScale(.5,.5) frame.Size=UDim2.fromOffset(200,100) frame.Parent=screen
 local label=Instance.new("TextLabel")
 label.TextTransparency=.2 label.BackgroundTransparency=1 label.Parent=frame
 for i=1,5 do
  motion.SetFrame(frame,true) task.wait(.04)
  motion.SetFrame(frame,false) task.wait(.03)
 end
 motion.SetFrame(frame,true) task.wait(.3)
 assert(frame.Visible and frame.MotionFade.Value==0 and frame.FrameMotionScale.Scale==1,"Reopen did not settle")
 assert(math.abs(label.TextTransparency-.2)<.001,"Original transparency lost")
 motion.SetFrame(frame,false) task.wait(.2)
 assert(not frame.Visible and frame.Position==UDim2.fromScale(.5,.5) and frame.FrameMotionScale.Scale==1,"Close did not reset")
 return "PASS: interrupted transitions, original transparency, position reset"
end,debug.traceback)
screen:Destroy()
if not ok then error(result) end
script:SetAttribute("Result",result)
print(result)

