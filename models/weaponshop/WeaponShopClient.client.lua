-- WeaponShopClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Step onto the glowing ring in front of the Weapon Shop: your camera flies to the counter and the
-- shop view opens. Browse with the arrows (or A/D, Left/Right, LB/RB), leave with X (or Backspace / B).
-- Leaving puts you just outside the ring; you have to step out and back in to open it again.
--
-- Items live in ReplicatedStorage.WeaponShopCatalog (name, price, stats). The button is BUY $price -> EQUIP -> UNEQUIP;
-- the real work is done by ServerScriptService.WeaponShopService through ReplicatedStorage.WeaponShopRemote (the client
-- only asks). Items without a price show COMING SOON.
-- Positions come from the markers in Workspace.WeaponShop.ShopView:
--   ShopZone (invisible cylinder over the ring), ShopCamera, PreviewSpot, ExitPoint.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local catalog = require(ReplicatedStorage:WaitForChild("WeaponShopCatalog"))
local remote = ReplicatedStorage:WaitForChild("WeaponShopRemote", 10) -- server side: buying / equipping (WeaponShopService)

local shopView = workspace:WaitForChild("WeaponShop"):WaitForChild("ShopView")
local zone = shopView:WaitForChild("ShopZone")
local cameraMark = shopView:WaitForChild("ShopCamera")
local previewSpot = shopView:WaitForChild("PreviewSpot")
local exitPoint = shopView:WaitForChild("ExitPoint")

local ZONE_RADIUS = zone.Size.Z / 2 -- cylinder lies on its side (axis = X), so Y/Z are the diameter
local ZONE_HALF_HEIGHT = zone.Size.X / 2 + 4
local SHOP_FOV = 50
local ACTION = "WeaponShopControls"
local RENDER_STEP = "WeaponShopRender"
local SLIDE = 7 -- studs a preview slides when switching items

local YELLOW = Color3.fromRGB(255, 214, 51)
local DARK = Color3.fromRGB(43, 29, 20)
local LIGHT = Color3.fromRGB(232, 213, 192)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 20, 24)
local GREEN = Color3.fromRGB(47, 179, 74)
local GREY = Color3.fromRGB(110, 110, 120)
local RED = Color3.fromRGB(214, 54, 45)

-- Optional: the default PlayerModule's movement controls, when the place has one (not every place does,
-- so the character is also frozen directly through its Humanoid, see freezeCharacter)
local controls = nil
task.spawn(function()
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if playerModule then
		local ok, module = pcall(require, playerModule)
		if ok and module and module.GetControls then
			controls = module:GetControls()
		end
	end
end)

---------------------------------------------------------------- UI
local function make(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end
local function corner(parent, radius)
	make("UICorner", { CornerRadius = radius, Parent = parent })
end
local function outline(parent, color, thickness)
	make("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end
local function textOutline(parent, thickness)
	make("UIStroke", { Color = BLACK, Thickness = thickness, Parent = parent })
end

local gui = make("ScreenGui", {
	Name = "WeaponShopUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 30,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

local title = make("TextLabel", {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(520, 70),
	BackgroundTransparency = 1,
	Text = "WEAPON SHOP",
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = YELLOW,
	Parent = gui,
})
textOutline(title, 4)

local closeButton = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = RED,
	Text = "X",
	Font = Enum.Font.GothamBlack,
	TextSize = 34,
	TextColor3 = WHITE,
	Parent = gui,
})
corner(closeButton, UDim.new(0, 16))
outline(closeButton, BLACK, 3)

local function arrowButton(name, glyph, anchorX)
	local button = make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(anchorX, 0.5),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = YELLOW,
		Text = glyph,
		Font = Enum.Font.GothamBlack,
		TextSize = 56,
		TextColor3 = DARK,
		Parent = gui,
	})
	corner(button, UDim.new(1, 0))
	outline(button, BLACK, 4)
	return button
end
local leftButton = arrowButton("Previous", "<", 0)
local rightButton = arrowButton("Next", ">", 1)

local card = make("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(480, 190),
	BackgroundColor3 = DARK,
	Parent = gui,
})
corner(card, UDim.new(0, 20))
outline(card, YELLOW, 4)

local nameLabel = make("TextLabel", {
	Name = "ItemName",
	Position = UDim2.fromOffset(24, 16),
	Size = UDim2.new(1, -140, 0, 48),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = WHITE,
	Parent = card,
})
textOutline(nameLabel, 3)
local nameScale = make("UIScale", { Parent = nameLabel })

local countLabel = make("TextLabel", {
	Name = "Count",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -22, 0, 24),
	Size = UDim2.fromOffset(100, 30),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = LIGHT,
	Parent = card,
})

local priceLabel = make("TextLabel", {
	Name = "Price",
	Position = UDim2.fromOffset(24, 68),
	Size = UDim2.new(1, -48, 0, 34),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = YELLOW,
	Parent = card,
})
textOutline(priceLabel, 2)

local buyButton = make("TextButton", {
	Name = "Buy",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.new(1, -48, 0, 58),
	BackgroundColor3 = GREEN,
	Text = "BUY",
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	TextColor3 = WHITE,
	Parent = card,
})
corner(buyButton, UDim.new(0, 14))
outline(buyButton, BLACK, 3)

local hint = make("TextLabel", {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(640, 24),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = WHITE,
	Parent = gui,
})
textOutline(hint, 2)

local BLUE = Color3.fromRGB(60, 110, 200)
local EMPTY = Color3.fromRGB(80, 62, 48)

local cashLabel = make("TextLabel", {
	Name = "Cash",
	Size = UDim2.fromOffset(230, 46),
	BackgroundColor3 = DARK,
	Text = "Cash: $0",
	Font = Enum.Font.GothamBlack,
	TextSize = 24,
	TextColor3 = YELLOW,
	Parent = gui,
})
corner(cashLabel, UDim.new(0, 12))
outline(cashLabel, YELLOW, 3)

-- stats panel: one 10-segment bar per stat (the value is 1-10; "?" while a weapon's stats are undecided)
local statsPanel = make("Frame", {
	Name = "Stats",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(330, 214),
	BackgroundColor3 = DARK,
	Parent = gui,
})
corner(statsPanel, UDim.new(0, 16))
outline(statsPanel, YELLOW, 3)
make("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.fromOffset(200, 28),
	BackgroundTransparency = 1,
	Text = "STATS",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = YELLOW,
	Parent = statsPanel,
})
local STAT_ORDER = { "Damage", "Range", "Fire Rate", "Accuracy" }
local statRows = {}
for i, name in ipairs(STAT_ORDER) do
	local y = 44 + (i - 1) * 34
	make("TextLabel", {
		Name = name,
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.fromOffset(96, 26),
		BackgroundTransparency = 1,
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Parent = statsPanel,
	})
	local segments = {}
	for k = 1, 10 do
		segments[k] = make("Frame", {
			Position = UDim2.fromOffset(114 + (k - 1) * 17, y + 5),
			Size = UDim2.fromOffset(15, 16),
			BackgroundColor3 = EMPTY,
			BorderSizePixel = 0,
			Parent = statsPanel,
		})
	end
	local value = make("TextLabel", {
		Position = UDim2.fromOffset(290, y),
		Size = UDim2.fromOffset(28, 26),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = YELLOW,
		Parent = statsPanel,
	})
	statRows[i] = { segments = segments, value = value }
end
local blurbLabel = make("TextLabel", {
	Name = "Blurb",
	Position = UDim2.fromOffset(16, 182),
	Size = UDim2.fromOffset(298, 24),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamMedium,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = LIGHT,
	Parent = statsPanel,
})

-- element, on-screen position, off-screen position (for the slide in/out)
local layout = {
	{ title, UDim2.new(0.5, 0, 0, 28), UDim2.new(0.5, 0, 0, -130) },
	{ closeButton, UDim2.new(1, -28, 0, 28), UDim2.new(1, 130, 0, 28) },
	{ leftButton, UDim2.new(0, 36, 0.5, 0), UDim2.new(0, -170, 0.5, 0) },
	{ rightButton, UDim2.new(1, -36, 0.5, 0), UDim2.new(1, 170, 0.5, 0) },
	{ card, UDim2.new(0.5, 0, 1, -40), UDim2.new(0.5, 0, 1, 320) },
	{ hint, UDim2.new(0.5, 0, 1, -10), UDim2.new(0.5, 0, 1, 90) },
	{ cashLabel, UDim2.new(0, 28, 0, 28), UDim2.new(0, -260, 0, 28) },
	{ statsPanel, UDim2.new(1, -28, 0, 90), UDim2.new(1, 400, 0, 90) },
}
for _, entry in ipairs(layout) do
	entry[1].Position = entry[3]
end

-- shrink the UI on small screens (phones)
local uiScales = {}
for _, entry in ipairs(layout) do
	table.insert(uiScales, make("UIScale", { Parent = entry[1] }))
end
local function applyScreenScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.55, 1)
	for _, uiScale in ipairs(uiScales) do
		uiScale.Scale = scale
	end
end
applyScreenScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScreenScale)

local uiToken = 0
local function openUI()
	uiToken += 1
	gui.Enabled = true
	for i, entry in ipairs(layout) do
		entry[1].Position = entry[3]
		TweenService:Create(entry[1], TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.15 + i * 0.03), { Position = entry[2] }):Play()
	end
end
local function closeUI()
	uiToken += 1
	local token = uiToken
	for _, entry in ipairs(layout) do
		TweenService:Create(entry[1], TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = entry[3] }):Play()
	end
	task.delay(0.25, function()
		if token == uiToken then
			gui.Enabled = false
		end
	end)
end

local function hintText()
	if UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") then
		return "LB / RB to browse   •   B to leave"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Tap the arrows to browse"
	end
	return "A / D or arrow keys to browse   •   Backspace to leave"
end

---------------------------------------------------------------- preview (local-only parts under the camera)
local offsetValue = Instance.new("NumberValue") -- sideways slide of the current preview
local current = nil -- { model = Model, centre = CFrame (pivot -> bounding-box centre) }
local previewToken = 0
local turntable = nil

local function buildPlaceholder()
	local model = Instance.new("Model")
	model.Name = "Preview"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3.2, 1.4, 0.5)
	body.Color = Color3.fromRGB(45, 50, 64)
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 60
		surface.LightInfluence = 0
		surface.Parent = body
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundTransparency = 1
		mark.Text = "?"
		mark.Font = Enum.Font.GothamBlack
		mark.TextScaled = true
		mark.TextColor3 = YELLOW
		mark.Parent = surface
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = BLACK
		stroke.Parent = mark
	end
	model.PrimaryPart = body
	return model
end

local function buildPreview(item)
	local folder = ReplicatedStorage:FindFirstChild("WeaponShopPreviews")
	local source = folder and folder:FindFirstChild(item.Id)
	local model
	if source and source:IsA("Model") then
		model = source:Clone()
	else
		model = buildPlaceholder()
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- fit the longest side to ~3.4 studs, then remember where its centre is relative to its pivot
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 and math.abs(longest - 3.4) > 0.05 then
		pcall(function()
			model:ScaleTo(model:GetScale() * (3.4 / longest))
		end)
	end
	local centre = model:GetPivot():ToObjectSpace((model:GetBoundingBox()))
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = YELLOW
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	return model, centre
end

local function clearPreview()
	previewToken += 1
	if current then
		current.model:Destroy()
		current = nil
	end
	if turntable then
		turntable:Destroy()
		turntable = nil
	end
end

local function showPreview(index, direction)
	previewToken += 1
	local token = previewToken
	local item = catalog[index]
	local function spawnNew()
		if token ~= previewToken then
			return
		end
		local model, centre = buildPreview(item)
		current = { model = model, centre = centre }
		model.Parent = workspace.CurrentCamera
		if direction ~= 0 then
			offsetValue.Value = direction * SLIDE
			TweenService:Create(offsetValue, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 }):Play()
		else
			offsetValue.Value = 0
		end
	end
	if current and direction ~= 0 then
		local old = current
		local out = TweenService:Create(offsetValue, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = -direction * SLIDE })
		out.Completed:Connect(function()
			old.model:Destroy()
			if current == old then
				current = nil
			end
			spawnNew()
		end)
		out:Play()
	else
		if current then
			current.model:Destroy()
			current = nil
		end
		spawnNew()
	end
end

local function makeTurntable()
	local disc = Instance.new("Part")
	disc.Name = "Turntable"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.15, 3.4, 3.4)
	disc.CFrame = previewSpot.CFrame * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	disc.Material = Enum.Material.Neon
	disc.Color = YELLOW
	disc.Transparency = 0.35
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = workspace.CurrentCamera
	return disc
end

---------------------------------------------------------------- shop state
local state = "idle" -- idle | open | leaving
local mustLeaveZone = false -- after leaving, the ring only works again once you have stepped off it
local index = 1
local saved = { cameraType = Enum.CameraType.Custom, fov = 70 }
local spin, clock = 0, 0
local buyBusy = false

local function setCharacterHidden(hidden)
	local character = player.Character
	if not character then
		return
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

-- Stop the character walking/jumping while the shop is open, and give the old values back afterwards
local frozen = nil -- { humanoid, walkSpeed, jumpPower, jumpHeight }
local function freezeCharacter(humanoid)
	frozen = {
		humanoid = humanoid,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:Move(Vector3.zero)
	if controls then
		controls:Disable()
	end
end
local function unfreezeCharacter()
	if controls then
		controls:Enable()
	end
	if frozen and frozen.humanoid.Parent then
		local humanoid = frozen.humanoid
		-- only restore what we changed (another script may have set its own value meanwhile)
		if humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = frozen.walkSpeed
		end
		if humanoid.JumpPower == 0 then
			humanoid.JumpPower = frozen.jumpPower
		end
		if humanoid.JumpHeight == 0 then
			humanoid.JumpHeight = frozen.jumpHeight
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	frozen = nil
end

-- What the server says about this player: cash, owned weapons, equipped weapon (see WeaponShopService)
local shopState = { cash = 0, owned = {}, equipped = nil }

local function updateCash()
	cashLabel.Text = "Cash: $" .. tostring(shopState.cash)
end

local function updateStats()
	local item = catalog[index]
	for i, name in ipairs(STAT_ORDER) do
		local row = statRows[i]
		local value = item.Stats and item.Stats[name]
		for k = 1, 10 do
			row.segments[k].BackgroundColor3 = (value and k <= value) and YELLOW or EMPTY
		end
		row.value.Text = value and tostring(value) or "?"
	end
	blurbLabel.Text = item.Blurb or ""
end

-- the main button is BUY $price -> EQUIP -> UNEQUIP (COMING SOON while an item has no price yet)
local function updateButton()
	if buyBusy then
		return
	end
	local item = catalog[index]
	if typeof(item.Price) ~= "number" then
		buyButton.Text = "COMING SOON"
		buyButton.BackgroundColor3 = GREY
	elseif shopState.owned[item.Id] then
		if shopState.equipped == item.Id then
			buyButton.Text = "UNEQUIP"
			buyButton.BackgroundColor3 = GREY
		else
			buyButton.Text = "EQUIP"
			buyButton.BackgroundColor3 = BLUE
		end
	else
		buyButton.Text = "BUY  $" .. tostring(item.Price)
		buyButton.BackgroundColor3 = GREEN
	end
end

local function applyState(newState)
	shopState.cash = tonumber(newState.cash) or 0
	shopState.owned = typeof(newState.owned) == "table" and newState.owned or {}
	shopState.equipped = newState.equipped
	updateCash()
	updateButton()
end

local function refreshState()
	if not remote then
		return
	end
	task.spawn(function()
		local ok, _, _, newState = pcall(remote.InvokeServer, remote, "State")
		if ok and typeof(newState) == "table" then
			applyState(newState)
		end
	end)
end

-- show a short message on the button, then go back to its normal text
local function flash(text, color)
	buyBusy = true
	buyButton.Text = text
	buyButton.BackgroundColor3 = color
	task.delay(1.1, function()
		buyBusy = false
		updateButton()
	end)
end

local function updateLabels()
	local item = catalog[index]
	nameLabel.Text = item.Name
	countLabel.Text = string.format("%d / %d", index, #catalog)
	if typeof(item.Price) == "number" then
		priceLabel.Text = "Price: $" .. tostring(item.Price)
	else
		priceLabel.Text = "Price: ???"
	end
	updateStats()
	updateButton()
end

local function step(direction)
	if state ~= "open" or #catalog == 0 then
		return
	end
	index = (index - 1 + direction) % #catalog + 1
	updateLabels()
	nameScale.Scale = 1.2
	TweenService:Create(nameScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	showPreview(index, direction)
end

local function onRender(dt)
	clock += dt
	spin += dt * 1.1
	if current and current.model.Parent then
		local bob = math.sin(clock * 2) * 0.12
		local target = previewSpot.CFrame * CFrame.new(offsetValue.Value, bob, 0) * CFrame.Angles(0, spin, 0)
		current.model:PivotTo(target * current.centre:Inverse())
	end
	setCharacterHidden(true) -- the default camera scripts may reset this, so keep it applied
	if frozen and frozen.humanoid.Parent then -- other scripts (sprint etc.) may change these, keep them at 0
		local humanoid = frozen.humanoid
		if humanoid.WalkSpeed ~= 0 then
			humanoid.WalkSpeed = 0
		end
		if humanoid.JumpPower ~= 0 then
			humanoid.JumpPower = 0
		end
		if humanoid.JumpHeight ~= 0 then
			humanoid.JumpHeight = 0
		end
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default -- shift-lock / first person would lock the mouse
end

local leaveShop -- forward declaration

local function onAction(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.A or key == Enum.KeyCode.Left or key == Enum.KeyCode.ButtonL1 or key == Enum.KeyCode.DPadLeft then
		step(-1)
	elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right or key == Enum.KeyCode.ButtonR1 or key == Enum.KeyCode.DPadRight then
		step(1)
	elseif key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
		leaveShop(true)
	end
	return Enum.ContextActionResult.Sink
end

local function enterShop()
	if state ~= "idle" or #catalog == 0 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	state = "open"
	local camera = workspace.CurrentCamera
	saved.cameraType = camera.CameraType
	saved.fov = camera.FieldOfView
	freezeCharacter(humanoid)
	root.AssemblyLinearVelocity = Vector3.zero

	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		CFrame = cameraMark.CFrame,
		FieldOfView = SHOP_FOV,
	}):Play()

	index = math.clamp(index, 1, #catalog)
	updateLabels()
	refreshState()
	hint.Text = hintText()
	turntable = makeTurntable()
	showPreview(index, 0)
	openUI()
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, onRender)
	ContextActionService:BindActionAtPriority(ACTION, onAction, false, Enum.ContextActionPriority.High.Value + 50,
		Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Left, Enum.KeyCode.Right,
		Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight,
		Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
end

function leaveShop(teleportOut)
	if state ~= "open" then
		return
	end
	state = "leaving"
	mustLeaveZone = true
	ContextActionService:UnbindAction(ACTION)
	closeUI()
	clearPreview()

	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = root ~= nil and humanoid ~= nil and humanoid.Health > 0
	if teleportOut and alive then
		character:PivotTo(exitPoint.CFrame)
		root.AssemblyLinearVelocity = Vector3.zero
	end

	local function finish()
		RunService:UnbindFromRenderStep(RENDER_STEP)
		setCharacterHidden(false)
		camera.FieldOfView = saved.fov
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		unfreezeCharacter()
		state = "idle"
	end

	if alive then
		-- glide back to a normal third-person view behind the character, then hand the camera back
		local focus = root.Position + Vector3.new(0, 2, 0)
		local back = CFrame.lookAt(focus - root.CFrame.LookVector * 12 + Vector3.new(0, 4, 0), focus)
		local tween = TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			CFrame = back,
			FieldOfView = saved.fov,
		})
		tween.Completed:Connect(finish)
		tween:Play()
	else
		finish()
	end
end

---------------------------------------------------------------- buttons
leftButton.Activated:Connect(function()
	step(-1)
end)
rightButton.Activated:Connect(function()
	step(1)
end)
closeButton.Activated:Connect(function()
	leaveShop(true)
end)
buyButton.Activated:Connect(function()
	if buyBusy or state ~= "open" or not remote then
		return
	end
	local item = catalog[index]
	if typeof(item.Price) ~= "number" then
		return -- placeholder item, nothing to buy yet
	end
	local action = shopState.owned[item.Id] and "Equip" or "Buy"
	buyBusy = true -- hold the button while the server answers
	local ok, success, message, newState = pcall(remote.InvokeServer, remote, action, item.Id)
	buyBusy = false
	if ok and typeof(newState) == "table" then
		applyState(newState)
	end
	if ok and success then
		if action == "Buy" then
			flash("BOUGHT!", GREEN)
		else
			updateButton()
		end
	else
		flash(string.upper(ok and tostring(message) or "ERROR"), RED)
	end
end)

-- keep cash / ownership / equipped in step with the server (also when the weapon is equipped from the hotbar)
player.AttributeChanged:Connect(function(name)
	if name == "EquippedWeapon" then
		shopState.equipped = player:GetAttribute(name)
		updateButton()
	elseif name:sub(1, 5) == "Owns_" then
		shopState.owned[name:sub(6)] = player:GetAttribute(name) == true or nil
		updateButton()
	end
end)
task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 15)
	local cash = stats and stats:WaitForChild("Cash", 15)
	if cash then
		shopState.cash = cash.Value
		updateCash()
		cash.Changed:Connect(function(value)
			shopState.cash = value
			updateCash()
		end)
	end
end)
refreshState()

---------------------------------------------------------------- the ring
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local offset = root.Position - zone.Position
	local inside = Vector2.new(offset.X, offset.Z).Magnitude <= ZONE_RADIUS and math.abs(offset.Y) <= ZONE_HALF_HEIGHT
	if not inside then
		mustLeaveZone = false
	elseif state == "idle" and not mustLeaveZone then
		enterShop()
	end
end)

-- dying or respawning while the shop is open closes it cleanly
local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			leaveShop(false)
		end)
	end
end
player.CharacterAdded:Connect(watchCharacter)
player.CharacterRemoving:Connect(function()
	leaveShop(false)
end)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
