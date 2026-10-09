-- InstallTrailButton (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- The top "SPEED" button (StarterGui.GameUI.TopButtons.Speed) is an image with the word baked in. This lays a
-- matching cyan panel with "TRAIL" over the word. The button keeps its name "Speed" (AnimalMenuClient, UIMotion and
-- GameUILayout use it); GameUITeleports sends "Speed" to the trail shop's neon Circle.
local speed = game:GetService("StarterGui").GameUI.TopButtons.Speed
local old = speed:FindFirstChild("TrailCover")
if old then
	old:Destroy()
end
local cover = Instance.new("Frame")
cover.Name = "TrailCover"
cover.AnchorPoint = Vector2.new(0.5, 0.5)
cover.Position = UDim2.fromScale(0.5, 0.47)
cover.Size = UDim2.fromScale(0.8, 0.6)
cover.BackgroundColor3 = Color3.new(1, 1, 1)
cover.BorderSizePixel = 0
cover.ZIndex = speed.ZIndex + 1
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(64, 206, 245), Color3.fromRGB(28, 168, 228))
gradient.Rotation = 90
gradient.Parent = cover
cover.Parent = speed
local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.GothamBlack
label.Text = "TRAIL"
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.ZIndex = speed.ZIndex + 2
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2.5
stroke.Color = Color3.fromRGB(8, 20, 28)
stroke.Parent = label
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0.12, 0)
pad.PaddingBottom = UDim.new(0.1, 0)
pad.Parent = label
label.Parent = cover
return "TRAIL label on the Speed button"
