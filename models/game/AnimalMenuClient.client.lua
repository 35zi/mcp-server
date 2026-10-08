-- AnimalMenuClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Two buttons on the left side of the screen:
--   * INDEX  every animal per world with its rarity; the ones you've brought home are unlocked (picture + how many),
--            the rest are black silhouettes ("???"). Reads player attributes Caught_<Species> (set by AnimalCarry).
--   * BAG    your animals (player.AnimalInventory, InventoryAdapter): Hold it in your hand, Place it on your plot,
--            take it back. Asks the server through ReplicatedStorage.AnimalInventoryRemote (InventoryService).
-- Plus a banner while you carry a dead animal ("bring it over the red line"). While a menu is open the ScreenGui
-- attribute Open is true, so WeaponClient puts the gun aside and shows the cursor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local remote = ReplicatedStorage:WaitForChild("AnimalInventoryRemote")
local previews = ReplicatedStorage:WaitForChild("AnimalPreviews")

local GOLD = Color3.fromRGB(255, 205, 50)
local DARK = Color3.fromRGB(43, 29, 20)
local CARD = Color3.fromRGB(62, 44, 32)
local BLACK = Color3.fromRGB(20, 20, 24)
local WHITE = Color3.new(1, 1, 1)
local SOFT = Color3.fromRGB(232, 213, 192)
local GREEN = Color3.fromRGB(70, 160, 70)
local BLUE = Color3.fromRGB(60, 120, 200)
local GREY = Color3.fromRGB(110, 96, 84)

local function make(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = parent })
end

local gui = make("ScreenGui", { Name = "AnimalMenu", ResetOnSpawn = false, DisplayOrder = 6, Parent = player:WaitForChild("PlayerGui") })
gui:SetAttribute("Open", false)

---------------------------------------------------------------- side buttons
local side = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(72, 160),
	BackgroundTransparency = 1,
	Parent = gui,
})
make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })

local function sideButton(icon, caption, order)
	local b = make("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.1,
		Text = "",
		AutoButtonColor = true,
		Parent = side,
	})
	corner(b, 14)
	make("UIStroke", { Color = GOLD, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4), BackgroundTransparency = 1, Text = icon, TextSize = 30, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, Parent = b })
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 48), BackgroundTransparency = 1, Text = caption, TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = GOLD, Parent = b })
	return b
end
local indexButton = sideButton("📖", "INDEX", 1)
local bagButton = sideButton("🎒", "BAG", 2)

---------------------------------------------------------------- panel frame
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(620, 440),
	BackgroundColor3 = DARK,
	Visible = false,
	Active = true,
	Parent = gui,
})
corner(panel, 18)
make("UIStroke", { Color = GOLD, Thickness = 3, Parent = panel })
local panelScale = make("UIScale", { Parent = panel })
local function fitPanel()
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
	panelScale.Scale = math.min(1, (vp.X - 120) / 640, (vp.Y - 40) / 460)
end
fitPanel()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)

local title = make("TextLabel", {
	Position = UDim2.fromOffset(22, 12),
	Size = UDim2.new(1, -90, 0, 34),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = GOLD,
	Parent = panel,
})
make("UIStroke", { Color = BLACK, Thickness = 2, Parent = title })
local subtitle = make("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -70, 0, 20),
	Size = UDim2.fromOffset(260, 24),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = SOFT,
	Parent = panel,
})
local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.fromRGB(190, 60, 50),
	Text = "X",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextColor3 = WHITE,
	Parent = panel,
})
corner(closeButton, 10)
local status = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.new(1, -40, 0, 20),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextColor3 = SOFT,
	Parent = panel,
})

local indexPage = make("Frame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -86), BackgroundTransparency = 1, Visible = false, Parent = panel })
local bagPage = make("Frame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -86), BackgroundTransparency = 1, Visible = false, Parent = panel })

---------------------------------------------------------------- animal pictures
local function fillViewport(vp, species)
	vp:ClearAllChildren()
	local source = previews:FindFirstChild(species)
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
	local front = primary.CFrame.LookVector
	local right = primary.CFrame.RightVector
	local dir = (Vector3.new(front.X, 0, front.Z).Unit * 0.85 - right * 0.55 + Vector3.new(0, 0.38, 0)).Unit
	local dist = (size.Magnitude / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.02
	camera.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
end

local function viewport(parent, props)
	local vp = make("ViewportFrame", props)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(165, 160, 150)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-1, -1.4, -0.8)
	vp.Parent = parent
	return vp
end

---------------------------------------------------------------- INDEX page
local currentWorld = 1
local tabs = make("Frame", { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 0, 36), BackgroundTransparency = 1, Parent = indexPage })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = tabs })
local tabButtons = {}
local grid = make("Frame", { Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 1, -48), BackgroundTransparency = 1, Parent = indexPage })
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(136, 290),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Parent = grid,
})

local function caughtCount(species)
	return player:GetAttribute("Caught_" .. species) or 0
end

local function renderIndex()
	local unlocked, total = 0, 0
	for _, world in ipairs(AnimalData.Worlds) do
		for _, species in ipairs(world.species) do
			total += 1
			if caughtCount(species) > 0 then
				unlocked += 1
			end
		end
	end
	subtitle.Text = string.format("Unlocked %d / %d", unlocked, total)
	for id, b in pairs(tabButtons) do
		b.BackgroundColor3 = id == currentWorld and GOLD or CARD
		b.TextColor3 = id == currentWorld and DARK or SOFT
	end
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local world = AnimalData.Worlds[currentWorld]
	for i, species in ipairs(world.species) do
		local info = AnimalData.Species[species]
		local rarity = AnimalData.Rarities[info.rarity]
		local count = caughtCount(species)
		local known = count > 0
		local card = make("Frame", { LayoutOrder = i, BackgroundColor3 = CARD, Parent = grid })
		corner(card, 12)
		make("UIStroke", { Color = rarity.color, Thickness = 2, Transparency = known and 0 or 0.5, Parent = card })
		local vp = viewport(card, { Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 150) })
		fillViewport(vp, species)
		if not known then
			vp.ImageColor3 = Color3.new(0, 0, 0)
			vp.ImageTransparency = 0.15
		end
		make("TextLabel", {
			Position = UDim2.fromOffset(4, 164),
			Size = UDim2.new(1, -8, 0, 28),
			BackgroundTransparency = 1,
			Text = known and species or "???",
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextColor3 = WHITE,
			Parent = card,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(4, 194),
			Size = UDim2.new(1, -8, 0, 20),
			BackgroundTransparency = 1,
			Text = string.upper(info.rarity),
			Font = Enum.Font.GothamBlack,
			TextSize = 16,
			TextColor3 = rarity.color,
			Parent = card,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(4, 222),
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundTransparency = 1,
			Text = known and string.format("Caught: %d", count) or "Not caught yet",
			TextWrapped = true,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = known and SOFT or GREY,
			Parent = card,
		})
	end
end

for _, world in ipairs(AnimalData.Worlds) do
	local b = make("TextButton", {
		Size = UDim2.fromOffset(190, 36),
		BackgroundColor3 = CARD,
		Text = string.format("World %d · %s", world.id, world.name),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = SOFT,
		Parent = tabs,
	})
	corner(b, 10)
	b.Activated:Connect(function()
		currentWorld = world.id
		renderIndex()
	end)
	tabButtons[world.id] = b
end

---------------------------------------------------------------- BAG page
local list = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -32, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = GOLD,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = bagPage,
})
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
local emptyLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.new(1, -80, 0, 90),
	BackgroundTransparency = 1,
	Text = "Your bag is empty.\nShoot an animal, pick it up (E) and carry it over the red line!",
	TextWrapped = true,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = SOFT,
	Visible = false,
	Parent = bagPage,
})

local inventory = player:WaitForChild("AnimalInventory", 5)
local STATE_TEXT = { Bag = "In your bag", Held = "In your hand", Plot = "On your plot" }
local rarityRank = {}
for i, r in ipairs(AnimalData.RarityOrder) do
	rarityRank[r] = i
end

local busy = false
local function ask(action, id)
	if busy then
		return
	end
	busy = true
	status.Text = "..."
	local ok, success, message = pcall(function()
		return remote:InvokeServer(action, id)
	end)
	busy = false
	status.Text = ok and tostring(message or "") or "Try again"
	status.TextColor3 = (ok and success) and SOFT or Color3.fromRGB(255, 120, 100)
end

local function actionButton(parent, text, color, x, onClick)
	local b = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(126, 36),
		BackgroundColor3 = color,
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = WHITE,
		Parent = parent,
	})
	corner(b, 9)
	b.Activated:Connect(onClick)
	return b
end

local function renderBag()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local items = inventory and inventory:GetChildren() or {}
	table.sort(items, function(a, b)
		local ra, rb = rarityRank[a:GetAttribute("Rarity")] or 0, rarityRank[b:GetAttribute("Rarity")] or 0
		if ra ~= rb then
			return ra > rb
		end
		return (a:GetAttribute("Id") or 0) > (b:GetAttribute("Id") or 0)
	end)
	subtitle.Text = string.format("%d animal%s", #items, #items == 1 and "" or "s")
	emptyLabel.Visible = #items == 0
	for i, item in ipairs(items) do
		local a = item:GetAttributes()
		local rarity = AnimalData.Rarities[a.Rarity] or AnimalData.Rarities.Common
		local row = make("Frame", { LayoutOrder = i, Size = UDim2.new(1, -10, 0, 68), BackgroundColor3 = CARD, Parent = list })
		corner(row, 12)
		make("UIStroke", { Color = rarity.color, Thickness = 1.5, Transparency = 0.3, Parent = row })
		local vp = viewport(row, { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(60, 60) })
		fillViewport(vp, a.Species)
		make("TextLabel", {
			Position = UDim2.fromOffset(74, 10),
			Size = UDim2.new(1, -350, 0, 24),
			BackgroundTransparency = 1,
			Text = AnimalData.DisplayName(a.Species, a.Size, a.Mutation),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Font = Enum.Font.GothamBlack,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = WHITE,
			Parent = row,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(74, 36),
			Size = UDim2.new(1, -350, 0, 20),
			BackgroundTransparency = 1,
			RichText = true,
			Text = string.format('<font color="#%s">%s</font>  •  %s', rarity.color:ToHex(), string.upper(a.Rarity or "Common"), STATE_TEXT[a.State] or ""),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = SOFT,
			Parent = row,
		})
		local id = a.Id
		if a.State == "Plot" then
			actionButton(row, "Take back", GREY, -10, function()
				ask("Bag", id)
			end)
		else
			actionButton(row, "Place in plot", GREEN, -10, function()
				ask("Plot", id)
			end)
		end
		actionButton(row, a.State == "Held" and "Put away" or "Hold", a.State == "Held" and GREY or BLUE, -144, function()
			ask("Hold", id)
		end)
	end
end

---------------------------------------------------------------- open / close
local openPage = nil
local refresh -- forward (live updates below)
local function setOpen(page)
	openPage = page
	panel.Visible = page ~= nil
	gui:SetAttribute("Open", page ~= nil)
	indexPage.Visible = page == "index"
	bagPage.Visible = page == "bag"
	status.Text = ""
	if page == "index" then
		title.Text = "INDEX"
		renderIndex()
	elseif page == "bag" then
		title.Text = "INVENTORY"
		renderBag()
	end
	if page then
		fitPanel()
		local target = panelScale.Scale
		panelScale.Scale = target * 0.9
		TweenService:Create(panelScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
end

indexButton.Activated:Connect(function()
	setOpen(openPage ~= "index" and "index" or nil)
end)
bagButton.Activated:Connect(function()
	setOpen(openPage ~= "bag" and "bag" or nil)
end)
closeButton.Activated:Connect(function()
	setOpen(nil)
end)

-- live updates
local pending = false
function refresh()
	if pending then
		return
	end
	pending = true
	task.defer(function()
		pending = false
		if openPage == "index" then
			renderIndex()
		elseif openPage == "bag" then
			renderBag()
		end
	end)
end
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 7) == "Caught_" then
		refresh()
	end
end)
local function watchInventory(folder)
	inventory = folder
	folder.ChildAdded:Connect(function(item)
		item.AttributeChanged:Connect(refresh)
		refresh()
	end)
	folder.ChildRemoved:Connect(refresh)
	for _, item in ipairs(folder:GetChildren()) do
		item.AttributeChanged:Connect(refresh)
	end
	refresh()
end
-- meshes in ReplicatedStorage aren't downloaded until something asks: load the pictures' meshes up front
task.spawn(function()
	ContentProvider:PreloadAsync({ previews })
	refresh()
end)

if inventory then
	watchInventory(inventory)
else
	player.ChildAdded:Connect(function(child)
		if child.Name == "AnimalInventory" then
			watchInventory(child)
		end
	end)
end

---------------------------------------------------------------- carrying banner
local carryBanner = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(560, 46),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = WHITE,
	Visible = false,
	Parent = gui,
})
corner(carryBanner, 12)
make("UIStroke", { Color = Color3.fromRGB(255, 70, 60), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = carryBanner })
local function updateCarry()
	local carrying = player:GetAttribute("Carrying")
	carryBanner.Visible = carrying ~= nil
	if carrying then
		carryBanner.Text = string.format("Carrying %s - bring it over the RED LINE!", string.upper(carrying))
	end
end
player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
updateCarry()
