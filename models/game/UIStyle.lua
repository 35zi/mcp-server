-- UIStyle (ModuleScript in ReplicatedStorage)
--
-- The game's UI look, shared by every menu (Index / Bag, popups, banners, HUD, Weapon Shop): bright "simulator store"
-- style - chunky rounded font, white text with a thick dark outline, black-outlined rounded panels with warm gradient
-- headers, 3D buttons that press down, square icon tiles with red "!" badges, rarity gradients.
--
--   UIStyle.make(class, props)          Instance.new + props (Parent last)
--   UIStyle.text(props)                 outlined text label (props.TextSize, props.Stroke = outline thickness)
--   UIStyle.button(props) / setButton   3D button: props.Text, props.Color, props.TextSize -> TextButton
--   UIStyle.window(props)               panel with header (props.Title, props.Icon) -> window, body, closeButton
--   UIStyle.tile(props)                 side-menu tile (props.Icon, props.Label) -> button, badge
--   UIStyle.pill(props)                 small outlined label on a coloured background
--   UIStyle.rarityGradient(rarity)      ColorSequence for a rarity (Legendary / Secret = rainbow)
--   UIStyle.rainbow(guiObject, rot)     moving rainbow UIGradient (Secret animals: Index cards, names, banner)
--   UIStyle.pop(guiObject)              quick "pop in" scale animation
local TweenService = game:GetService("TweenService")

local UIStyle = {}

UIStyle.Font = Enum.Font.FredokaOne
UIStyle.Outline = Color3.fromRGB(24, 18, 28)
UIStyle.Colors = {
	Green = Color3.fromRGB(76, 208, 56),
	Blue = Color3.fromRGB(54, 150, 255),
	Red = Color3.fromRGB(235, 64, 52),
	Orange = Color3.fromRGB(255, 150, 30),
	Yellow = Color3.fromRGB(255, 214, 51),
	Grey = Color3.fromRGB(150, 150, 165),
	Purple = Color3.fromRGB(170, 90, 255),
	White = Color3.new(1, 1, 1),
	Money = Color3.fromRGB(95, 255, 95),
	Tile = Color3.fromRGB(44, 44, 58),
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 160, 40)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 235, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 235, 110)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 200, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(150, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 220)),
})

local RARITY = {
	Epic = ColorSequence.new(Color3.fromRGB(210, 150, 255), Color3.fromRGB(120, 50, 220)),
	Secret = RAINBOW,
	Common = ColorSequence.new(Color3.fromRGB(215, 218, 228), Color3.fromRGB(140, 145, 162)),
	Uncommon = ColorSequence.new(Color3.fromRGB(140, 240, 90), Color3.fromRGB(38, 168, 60)),
	Rare = ColorSequence.new(Color3.fromRGB(100, 205, 255), Color3.fromRGB(40, 100, 235)),
	Legendary = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 84, 84)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 190, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 230, 80)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 95, 255)),
	}),
}

function UIStyle.make(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local make = UIStyle.make

function UIStyle.corner(parent, px)
	return make("UICorner", { CornerRadius = UDim.new(0, px or 12), Parent = parent })
end

-- black outline around a frame / button
function UIStyle.stroke(parent, thickness, color)
	return make("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UIStyle.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function UIStyle.gradient(parent, colors, rotation)
	if typeof(colors) == "table" then
		colors = ColorSequence.new(colors[1], colors[2])
	end
	return make("UIGradient", { Color = colors, Rotation = rotation or 90, Parent = parent })
end

function UIStyle.rarityGradient(rarity)
	return RARITY[rarity] or RARITY.Common
end

-- a rainbow UIGradient on `parent` that keeps turning (one shared loop for all of them; clients only)
local rainbows = setmetatable({}, { __mode = "k" })
local rainbowLoop = nil
function UIStyle.rainbow(parent, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Rainbow"
	gradient.Color = RAINBOW
	gradient.Rotation = rotation or 0
	gradient.Parent = parent
	rainbows[gradient] = rotation or 0
	if not rainbowLoop then
		rainbowLoop = game:GetService("RunService").RenderStepped:Connect(function()
			local spin = (os.clock() * 70) % 360
			for g, base in pairs(rainbows) do
				if g.Parent then
					g.Rotation = (base + spin) % 360
				else
					rainbows[g] = nil
				end
			end
		end)
	end
	return gradient
end

function UIStyle.darker(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.35)
end

-- outlined text: white, chunky font, outline thickness from the size (props.Stroke overrides, 0 = none)
function UIStyle.text(props)
	local class, strokeThickness = props.Class or "TextLabel", props.Stroke
	props.Class, props.Stroke = nil, nil
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or UIStyle.Font
	props.TextColor3 = props.TextColor3 or UIStyle.Colors.White
	props.TextSize = props.TextSize or 20
	local label = make(class, props)
	if strokeThickness == nil then
		strokeThickness = label.TextSize >= 30 and 3 or label.TextSize >= 18 and 2.5 or 2
	end
	if strokeThickness > 0 then
		make("UIStroke", { Thickness = strokeThickness, Color = UIStyle.Outline, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	end
	return label
end

-- 3D button: a darker base with the coloured face on top; the face sinks when pressed
function UIStyle.button(props)
	local color = props.Color or UIStyle.Colors.Green
	local button = make("TextButton", {
		Name = props.Name or "Button",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(140, 48),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = UIStyle.darker(color),
		Text = "",
		AutoButtonColor = false,
		Parent = props.Parent,
	})
	UIStyle.corner(button, props.Corner or 12)
	UIStyle.stroke(button, props.StrokeThickness or 3)
	local face = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = button,
	})
	UIStyle.corner(face, props.Corner or 12)
	UIStyle.gradient(face, { Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205) }, 90)
	-- a soft shine across the top half
	local shine = make("Frame", {
		Name = "Shine",
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0.35, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Parent = face,
	})
	UIStyle.corner(shine, 8)
	UIStyle.text({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "",
		TextSize = props.TextSize or 22,
		TextWrapped = true,
		Parent = face,
	})
	local function press(down)
		face.Position = down and UDim2.fromOffset(0, 3) or UDim2.new()
	end
	button.MouseButton1Down:Connect(function()
		press(true)
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
	end)
	button.MouseLeave:Connect(function()
		press(false)
	end)
	return button
end

function UIStyle.setButton(button, text, color)
	local face = button:FindFirstChild("Face")
	if not face then
		return
	end
	if text then
		face.Label.Text = text
	end
	if color then
		face.BackgroundColor3 = color
		button.BackgroundColor3 = UIStyle.darker(color)
	end
end

-- small outlined label on a coloured, outlined background
function UIStyle.pill(props)
	local pill = make("Frame", {
		Name = props.Name or "Pill",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(110, 24),
		BackgroundColor3 = props.Color or UIStyle.Colors.Red,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIStyle.corner(pill, props.Corner or 10)
	UIStyle.stroke(pill, 2)
	if props.Gradient then
		UIStyle.gradient(pill, props.Gradient, props.GradientRotation or 0)
	end
	UIStyle.text({ Name = "Label", Size = UDim2.fromScale(1, 1), Text = props.Text or "", TextSize = props.TextSize or 15, Parent = pill })
	return pill
end

-- panel: warm yellow body, orange header with icon + title, red X; returns window, body, closeButton, titleLabel
function UIStyle.window(props)
	local window = make("Frame", {
		Name = props.Name or "Window",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromOffset(600, 420),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Active = true,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
	})
	UIStyle.corner(window, 18)
	UIStyle.stroke(window, 4)
	UIStyle.gradient(window, { Color3.fromRGB(255, 226, 112), Color3.fromRGB(255, 172, 46) }, 90)

	local header = make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = window,
	})
	UIStyle.corner(header, 18)
	local headerColors = ColorSequence.new(Color3.fromRGB(255, 104, 40), Color3.fromRGB(255, 196, 56))
	UIStyle.gradient(header, headerColors, 0)
	local square = make("Frame", { -- squares off the header's bottom corners
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = header,
	})
	UIStyle.gradient(square, headerColors, 0)
	make("Frame", { -- dark line under the header
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = UIStyle.Outline,
		BorderSizePixel = 0,
		Parent = header,
	})
	UIStyle.text({
		Name = "Icon",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.fromOffset(50, 50),
		Text = props.Icon or "",
		TextSize = 34,
		Stroke = 0,
		Parent = header,
	})
	local title = UIStyle.text({
		Name = "Title",
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.new(1, -200, 1, 0),
		Text = props.Title or "",
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local close = UIStyle.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		Text = "X",
		TextSize = 26,
		Color = UIStyle.Colors.Red,
		Corner = 10,
		Parent = header,
	})
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -88),
		BackgroundTransparency = 1,
		Parent = window,
	})
	return window, body, close, title
end

-- square side-menu tile: dark glassy square, big icon, outlined label at the bottom, red "!" badge (hidden)
function UIStyle.tile(props)
	local button = make("TextButton", {
		Name = props.Name or props.Label or "Tile",
		Size = props.Size or UDim2.fromOffset(70, 70),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = UIStyle.Colors.Tile,
		BackgroundTransparency = 0.2,
		Text = "",
		AutoButtonColor = false,
		Parent = props.Parent,
	})
	UIStyle.corner(button, 12)
	UIStyle.stroke(button, 3)
	UIStyle.gradient(button, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 160, 175) }, 90)
	UIStyle.text({ Name = "Icon", Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 1, -16), Text = props.Icon or "", TextSize = 36, Stroke = 0, Parent = button })
	UIStyle.text({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.new(1, 10, 0, 20),
		Text = props.Label or "",
		TextSize = 17,
		Parent = button,
	})
	local badge = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = UIStyle.Colors.Red,
		Visible = false,
		ZIndex = 3,
		Parent = button,
	})
	make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	UIStyle.stroke(badge, 2)
	UIStyle.text({ Size = UDim2.fromScale(1, 1), Text = "!", TextSize = 17, ZIndex = 3, Parent = badge })
	local scale = make("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return button, badge
end

-- show a copy of `source` (a Model) in a ViewportFrame, seen from its front-left (front = PrimaryPart -Z)
function UIStyle.showModel(vp, source)
	vp:ClearAllChildren()
	if not source then
		return
	end
	local model = source:Clone()
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vp
	vp.CurrentCamera = camera
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local front, right = primary.CFrame.LookVector, primary.CFrame.RightVector
	local dir = (Vector3.new(front.X, 0, front.Z).Unit * 0.85 - right * 0.55 + Vector3.new(0, 0.38, 0)).Unit
	local dist = (size.Magnitude / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.02
	camera.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
end

-- a light rounded "photo" square holding a ViewportFrame; returns the ViewportFrame
function UIStyle.picture(props)
	local frame = make("Frame", {
		Name = "Picture",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(80, 80),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		Parent = props.Parent,
	})
	UIStyle.corner(frame, 10)
	UIStyle.stroke(frame, 2)
	return make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(165, 160, 150),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.4, -0.8),
		Parent = frame,
	})
end

-- quick "pop in" (uses / adds a UIScale; keeps any scale the caller set as the target)
function UIStyle.pop(guiObject, target)
	local scale = guiObject:FindFirstChild("PopScale") or make("UIScale", { Name = "PopScale", Parent = guiObject })
	target = target or 1
	scale.Scale = target * 0.6
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	return scale
end

return UIStyle
