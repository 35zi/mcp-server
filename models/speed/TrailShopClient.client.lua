-- TrailShopClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- The Trails shop: walk into the neon Workspace.Circle in front of the blue trail stall and this window opens (in
-- the same look as the Index: its window art + close button, blue cards). Six trails from SpeedData.Trails: buy one
-- once, then equip / unequip it. Buying and equipping ask ReplicatedStorage.SpeedRemote (SpeedService).
-- Leaving the circle, the X or Backspace closes it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local SpeedData = require(ReplicatedStorage:WaitForChild("SpeedData"))
local remote = ReplicatedStorage:WaitForChild("SpeedRemote")
local playerGui = player:WaitForChild("PlayerGui")
local gameUI = playerGui:WaitForChild("GameUI")
local indexArt = gameUI:WaitForChild("Frames"):WaitForChild("Index")

local DARK = Color3.fromRGB(8, 20, 28)
local GREEN = Color3.fromRGB(77, 238, 41)
local BLUE = Color3.fromRGB(10, 148, 222)
local GREY = Color3.fromRGB(120, 130, 145)
local RED = Color3.fromRGB(245, 80, 80)
local ASPECT = 1.40090096 -- the Index art's width / height

local function make(class, props, parent)
	local x = Instance.new(class)
	for k, v in pairs(props) do
		x[k] = v
	end
	x.Parent = parent
	return x
end
local function label(props, parent, max, thickness)
	local t = make("TextLabel", props, parent)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	make("UIStroke", { Thickness = thickness or 1.6, Color = DARK }, t)
	make("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = max or 20 }, t)
	return t
end

---------------------------------------------------------------- window (the Index art with our own header)
local gui = make("ScreenGui", { Name = "TrailShop", ResetOnSpawn = false, DisplayOrder = 9, Enabled = false }, playerGui)
local window = make("ImageLabel", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	Image = indexArt.Image,
	ScaleType = indexArt.ScaleType,
	ZIndex = 10,
}, gui)
local windowScale = make("UIScale", {}, window)
-- cover the art's baked-in "INDEX" title with our own header
local header = make("Frame", {
	Name = "Header",
	Position = UDim2.fromScale(0.006, 0.01),
	Size = UDim2.fromScale(0.988, 0.193),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 11,
}, window)
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 222, 255), Color3.fromRGB(0, 182, 240)), Rotation = 90 }, header)
local title = label({ Name = "Title", Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.6, 0.84), Text = "✨ TRAILS", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 }, header, 54, 3.5)
make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 225, 255)), Rotation = 90 }, title)
local close = indexArt:WaitForChild("CloseButton"):Clone()
for _, c in ipairs(close:GetChildren()) do
	if not c:IsA("UIAspectRatioConstraint") then
		c:Destroy()
	end
end
close.ZIndex = 13
close.Parent = window

local content = make("Frame", { Name = "Content", Position = UDim2.fromScale(0.035, 0.235), Size = UDim2.fromScale(0.93, 0.72), BackgroundTransparency = 1, ZIndex = 12 }, window)
local cashLabel = label({ Name = "Cash", Size = UDim2.fromScale(0.4, 0.11), Text = "$0", TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 }, content, 24, 2)
local hint = label({ Name = "Hint", Position = UDim2.fromScale(0.4, 0), Size = UDim2.fromScale(0.6, 0.11), Text = "Trails make you run faster + more ⚡ Speed/sec!", TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 13 }, content, 15, 1.4)
local cards = make("ScrollingFrame", {
	Name = "Cards",
	Position = UDim2.fromScale(0, 0.14),
	Size = UDim2.fromScale(1, 0.86),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = DARK,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 13,
}, content)
local grid = make("UIGridLayout", { CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, cards)
make("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6), PaddingRight = UDim.new(0, 8) }, cards)
local message = label({ Name = "Message", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 1.01), Size = UDim2.fromScale(0.9, 0.07), Text = "", ZIndex = 13 }, window, 20, 2)

---------------------------------------------------------------- cards
local animated = {} -- gradients that slide (and rainbow ones that cycle)
local buttons = {}

local function owned()
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedTrails") or "", "[^,]+") do
		set[id] = true
	end
	return set
end
local function cash()
	local stats = player:FindFirstChild("leaderstats")
	local c = stats and stats:FindFirstChild("Cash")
	return c and c.Value or 0
end

local busy = false
local messageSerial = 0
local function say(text, color)
	messageSerial += 1
	local serial = messageSerial
	message.Text = text
	message.TextColor3 = color or Color3.new(1, 1, 1)
	task.delay(2.5, function()
		if messageSerial == serial then
			message.Text = ""
		end
	end)
end

local refresh
local function ask(action, id)
	if busy then
		return
	end
	busy = true
	local ok, success, text = pcall(function()
		return remote:InvokeServer(action, id)
	end)
	busy = false
	if not ok then
		say("Please try again.", RED)
	elseif not success then
		say(text or "Can't do that.", RED)
	elseif action ~= "BuyTrail" then
		say(text or "", GREEN)
	end
	refresh()
end

for i, trail in ipairs(SpeedData.Trails) do
	local colors = SpeedData.TrailColors(trail)
	local card = make("Frame", { Name = trail.id, LayoutOrder = i, BackgroundColor3 = colors[1]:Lerp(Color3.new(1, 1, 1), 0.25), BorderSizePixel = 0, ZIndex = 14 }, cards)
	make("UIStroke", { Thickness = 2, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 210, 230)), Rotation = 90 }, card)
	-- preview: a dark window with the trail streaking through it
	local preview = make("Frame", { Name = "Preview", Position = UDim2.fromScale(0.06, 0.05), Size = UDim2.fromScale(0.88, 0.34), BackgroundColor3 = Color3.fromRGB(16, 30, 44), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 15 }, card)
	make("UIStroke", { Thickness = 2, Color = DARK }, preview)
	for row = 1, 2 do
		local streak = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, row == 1 and 0.42 or 0.66),
			Size = UDim2.fromScale(1, row == 1 and 0.32 or 0.14),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 16,
		}, preview)
		local g = make("UIGradient", {
			Color = SpeedData.ColorSequence(colors),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.15), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
		}, streak)
		table.insert(animated, { gradient = g, speed = row == 1 and 0.9 or 1.4, phase = math.random(), rainbow = trail.rainbow })
	end
	label({ Name = "TrailName", Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.92, 0.14), Text = string.upper(trail.name), ZIndex = 15 }, card, 18, 1.8)
	label({ Name = "Stats", Position = UDim2.fromScale(0.04, 0.57), Size = UDim2.fromScale(0.92, 0.12), Text = string.format("+%d WALK  •  x%s ⚡/s", trail.walk, tostring(trail.gain)), TextColor3 = Color3.fromRGB(255, 240, 150), ZIndex = 15 }, card, 13, 1.4)
	local b = make("TextButton", {
		Name = "Action",
		Position = UDim2.fromScale(0.08, 0.73),
		Size = UDim2.fromScale(0.84, 0.21),
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
		Text = "",
		ZIndex = 16,
	}, card)
	make("UIStroke", { Thickness = 2, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	make("UIStroke", { Thickness = 1.4, Color = DARK }, b)
	make("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = 18 }, b)
	b.Activated:Connect(function()
		local set = owned()
		if not set[trail.id] then
			ask("BuyTrail", trail.id)
		elseif player:GetAttribute("EquippedTrail") == trail.id then
			ask("Unequip")
		else
			ask("EquipTrail", trail.id)
		end
	end)
	buttons[trail.id] = b
end

refresh = function()
	local set = owned()
	local money = cash()
	local equipped = player:GetAttribute("EquippedTrail")
	cashLabel.Text = "💰 $" .. SpeedData.Commas(money)
	for _, trail in ipairs(SpeedData.Trails) do
		local b = buttons[trail.id]
		if equipped == trail.id then
			b.Text, b.BackgroundColor3 = "EQUIPPED ✓", Color3.fromRGB(40, 160, 40)
		elseif set[trail.id] then
			b.Text, b.BackgroundColor3 = "EQUIP", BLUE
		elseif money >= trail.price then
			b.Text, b.BackgroundColor3 = "BUY $" .. SpeedData.Short(trail.price), GREEN
		else
			b.Text, b.BackgroundColor3 = "$" .. SpeedData.Short(trail.price), GREY
		end
	end
end

local function layout()
	local vp = workspace.CurrentCamera.ViewportSize
	local width = math.min(680, vp.X - 32, vp.Y * 0.8 * ASPECT)
	window.Size = UDim2.fromOffset(width, width / ASPECT)
	local inner = width * 0.93 - 18
	local columns = inner > 420 and 3 or 2
	local w = math.floor((inner - (columns - 1) * 8) / columns)
	grid.CellSize = UDim2.fromOffset(w, math.floor(w * 1.05))
end
layout()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled then
		return
	end
	local t = os.clock()
	for _, a in ipairs(animated) do
		a.phase = (a.phase + dt * a.speed) % 2
		a.gradient.Offset = Vector2.new(a.phase - 1, 0)
		if a.rainbow then
			local keys = {}
			for k = 0, 5 do
				table.insert(keys, ColorSequenceKeypoint.new(k / 5, Color3.fromHSV((t * 0.3 + k / 6) % 1, 0.75, 1)))
			end
			a.gradient.Color = ColorSequence.new(keys)
		end
	end
end)

---------------------------------------------------------------- open / close
local isOpen = false
local savedMouse = nil
local function setOpen(open)
	if open == isOpen then
		return
	end
	isOpen = open
	if open then
		refresh()
		message.Text = ""
		savedMouse = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		gui.Enabled = true
		windowScale.Scale = 0.6
		TweenService:Create(windowScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		gui.Enabled = false
		if savedMouse then
			UserInputService.MouseBehavior = savedMouse
			savedMouse = nil
		end
	end
end
close.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and isOpen and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB) then
		setOpen(false)
	end
end)

-- walking into the circle opens it once; you have to step out and back in to open it again after closing
local inside = false
task.spawn(function()
	while true do
		local circle = workspace:FindFirstChild("Circle")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local now = false
		if circle and root then
			local d = root.Position - circle.Position
			now = Vector2.new(d.X, d.Z).Magnitude <= math.max(circle.Size.X, circle.Size.Z) / 2 and math.abs(d.Y) < 8
		end
		if now ~= inside then
			inside = now
			setOpen(now)
		end
		task.wait(0.15)
	end
end)

player:GetAttributeChangedSignal("OwnedTrails"):Connect(function()
	if isOpen then
		refresh()
	end
end)
player:GetAttributeChangedSignal("EquippedTrail"):Connect(function()
	if isOpen then
		refresh()
	end
end)
task.spawn(function()
	local c = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	c.Changed:Connect(function()
		if isOpen then
			refresh()
		end
	end)
end)
