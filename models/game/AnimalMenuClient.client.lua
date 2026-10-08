-- AnimalMenuClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Two tiles on the left side of the screen (style: ReplicatedStorage.UIStyle):
--   * Index  every animal per world with its rarity; the ones you've brought home are unlocked (picture + how many),
--            the rest are black silhouettes ("???"). Reads player attributes Caught_<Species> (set by AnimalCarry).
--   * Bag    your animals (player.AnimalInventory, InventoryAdapter): Hold it in your hand, Place it on your plot,
--            take it back. Asks the server through ReplicatedStorage.AnimalInventoryRemote (InventoryService).
-- A red "!" badge shows on a tile when something new is in it. Plus a banner while you carry a dead animal
-- ("bring it over the red line"). While a menu is open the ScreenGui attribute Open is true, so WeaponClient puts the
-- gun aside and shows the cursor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local remote = ReplicatedStorage:WaitForChild("AnimalInventoryRemote")
local previews = ReplicatedStorage:WaitForChild("AnimalPreviews")

local make, text, C = UIStyle.make, UIStyle.text, UIStyle.Colors
local WORLD_ICONS = { "🌲", "🌵" }

local gui = make("ScreenGui", { Name = "AnimalMenu", ResetOnSpawn = false, DisplayOrder = 6, Parent = player:WaitForChild("PlayerGui") })
gui:SetAttribute("Open", false)
local MUTATION_COLORS = { Gold = Color3.fromRGB(255, 205, 50), Silver = Color3.fromRGB(215, 225, 240) }

---------------------------------------------------------------- side tiles
local side = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.5, 0),
	Size = UDim2.fromOffset(70, 160),
	BackgroundTransparency = 1,
	Parent = gui,
})
make("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
local indexTile, indexBadge = UIStyle.tile({ Icon = "📖", Label = "Index", LayoutOrder = 1, Parent = side })
local bagTile, bagBadge = UIStyle.tile({ Icon = "🎒", Label = "Bag", LayoutOrder = 2, Parent = side })

---------------------------------------------------------------- windows
local function fitScale()
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.min(1, (vp.X - 140) / 680, (vp.Y - 40) / 500)
end

local indexWindow, indexBody, indexClose = UIStyle.window({ Name = "Index", Title = "Index", Icon = "📖", Size = UDim2.fromOffset(660, 480), Visible = false, Parent = gui })
local bagWindow, bagBody, bagClose = UIStyle.window({ Name = "Bag", Title = "Bag", Icon = "🎒", Size = UDim2.fromOffset(660, 480), Visible = false, Parent = gui })
for _, w in ipairs({ indexWindow, bagWindow }) do
	make("UIScale", { Name = "PopScale", Scale = fitScale(), Parent = w })
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	for _, w in ipairs({ indexWindow, bagWindow }) do
		w.PopScale.Scale = fitScale()
	end
end)

local function statusLine(body)
	return text({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextSize = 18,
		Parent = body,
	})
end
local indexStatus = statusLine(indexBody)
local bagStatus = statusLine(bagBody)

---------------------------------------------------------------- INDEX
local currentWorld = 1
local tabs = {}
local tabRow = make("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = indexBody })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabRow })
local unlockedLabel = text({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 6),
	Size = UDim2.fromOffset(170, 34),
	Text = "",
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = indexBody,
})
local grid = make("Frame", { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 1, -90), BackgroundTransparency = 1, Parent = indexBody })
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(142, 290),
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
	unlockedLabel.Text = string.format("Unlocked %d/%d", unlocked, total)
	for id, b in pairs(tabs) do
		UIStyle.setButton(b, nil, id == currentWorld and C.Green or C.Grey)
	end
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, species in ipairs(AnimalData.Worlds[currentWorld].species) do
		local info = AnimalData.Species[species]
		local rarity = AnimalData.Rarities[info.rarity]
		local count = caughtCount(species)
		local known = count > 0
		local card = make("Frame", { LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1), Parent = grid })
		UIStyle.corner(card, 14)
		UIStyle.stroke(card, 3)
		UIStyle.gradient(card, UIStyle.rarityGradient(info.rarity), info.rarity == "Legendary" and 45 or 90)
		local vp = UIStyle.picture({ Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 140), Parent = card })
		UIStyle.showModel(vp, previews:FindFirstChild(species))
		if not known then
			vp.ImageColor3 = Color3.new(0, 0, 0)
			vp.ImageTransparency = 0.1
		end
		text({ Position = UDim2.fromOffset(4, 154), Size = UDim2.new(1, -8, 0, 32), Text = known and species or "???", TextSize = 26, Parent = card })
		UIStyle.pill({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 192),
			Size = UDim2.fromOffset(118, 26),
			Text = string.upper(info.rarity),
			TextSize = 16,
			Color = UIStyle.darker(rarity.color, 0.15),
			Parent = card,
		})
		text({
			Position = UDim2.fromOffset(4, 228),
			Size = UDim2.new(1, -8, 0, 48),
			Text = known and string.format("Caught: %d\n💰 $%s/s", count, AnimalData.Commas(AnimalData.Income(species, "Medium", "None"))) or "Not caught yet",
			TextWrapped = true,
			TextSize = 19,
			TextColor3 = known and C.White or Color3.fromRGB(225, 225, 230),
			Parent = card,
		})
	end
end

for _, world in ipairs(AnimalData.Worlds) do
	local b = UIStyle.button({
		Size = UDim2.fromOffset(210, 46),
		LayoutOrder = world.id,
		Text = string.format("%s World %d · %s", WORLD_ICONS[world.id] or "", world.id, world.name),
		TextSize = 19,
		Color = C.Grey,
		Parent = tabRow,
	})
	b.Activated:Connect(function()
		currentWorld = world.id
		renderIndex()
	end)
	tabs[world.id] = b
end

---------------------------------------------------------------- BAG
local list = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -30),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = UIStyle.Outline,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = bagBody,
})
make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), Parent = list })
local emptyLabel = text({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(1, -60, 0, 120),
	Text = "Your bag is empty!\nShoot an animal, pick it up (E)\nand carry it over the red line.",
	TextWrapped = true,
	TextSize = 26,
	Visible = false,
	Parent = bagBody,
})

local inventory = player:WaitForChild("AnimalInventory", 5)
local STATE_TEXT = { Bag = "In bag", Held = "In hand", Plot = "On plot" }
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
	bagStatus.Text = "..."
	local ok, success, message = pcall(function()
		return remote:InvokeServer(action, id)
	end)
	busy = false
	bagStatus.Text = ok and tostring(message or "") or "Try again"
	bagStatus.TextColor3 = (ok and success) and C.White or Color3.fromRGB(255, 120, 100)
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
	emptyLabel.Visible = #items == 0
	for i, item in ipairs(items) do
		local a = item:GetAttributes()
		local row = make("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 80), BackgroundColor3 = Color3.new(1, 1, 1), Parent = list })
		UIStyle.corner(row, 14)
		UIStyle.stroke(row, 3)
		UIStyle.gradient(row, UIStyle.rarityGradient(a.Rarity), a.Rarity == "Legendary" and 0 or 90)
		local vp = UIStyle.picture({ Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(66, 66), Parent = row })
		UIStyle.showModel(vp, previews:FindFirstChild(a.Species))
		text({
			Position = UDim2.fromOffset(86, 8),
			Size = UDim2.new(1, -370, 0, 32),
			Text = AnimalData.DisplayName(a.Species, a.Size, a.Mutation),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextSize = 24,
			TextColor3 = MUTATION_COLORS[a.Mutation] or C.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		text({
			Position = UDim2.fromOffset(86, 42),
			Size = UDim2.new(1, -370, 0, 24),
			Text = string.format("%s  •  $%s/s  •  %s", string.upper(a.Rarity or "Common"), AnimalData.Commas(a.Income or 0), STATE_TEXT[a.State] or ""),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local id = a.Id
		local onPlot = a.State == "Plot"
		local place = UIStyle.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(136, 48),
			Text = onPlot and "Take back" or "Place",
			TextSize = 21,
			Color = onPlot and C.Orange or C.Green,
			Parent = row,
		})
		place.Activated:Connect(function()
			ask(onPlot and "Bag" or "Plot", id)
		end)
		local held = a.State == "Held"
		local hold = UIStyle.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -158, 0.5, 0),
			Size = UDim2.fromOffset(118, 48),
			Text = held and "Put away" or "Hold",
			TextSize = 21,
			Color = held and C.Grey or C.Blue,
			Parent = row,
		})
		hold.Activated:Connect(function()
			ask("Hold", id)
		end)
	end
end

---------------------------------------------------------------- open / close
local openPage = nil
local refresh -- forward (live updates below)
local function setOpen(page)
	openPage = page
	indexWindow.Visible = page == "index"
	bagWindow.Visible = page == "bag"
	gui:SetAttribute("Open", page ~= nil)
	indexStatus.Text, bagStatus.Text = "", ""
	if page == "index" then
		indexBadge.Visible = false
		renderIndex()
		UIStyle.pop(indexWindow, fitScale())
	elseif page == "bag" then
		bagBadge.Visible = false
		renderBag()
		UIStyle.pop(bagWindow, fitScale())
	end
end

indexTile.Activated:Connect(function()
	setOpen(openPage ~= "index" and "index" or nil)
end)
bagTile.Activated:Connect(function()
	setOpen(openPage ~= "bag" and "bag" or nil)
end)
indexClose.Activated:Connect(function()
	setOpen(nil)
end)
bagClose.Activated:Connect(function()
	setOpen(nil)
end)

-- the Weapon Shop view is full screen: step aside while it's open
task.spawn(function()
	local shopGui = player.PlayerGui:WaitForChild("WeaponShopUI", 60)
	if not shopGui then
		return
	end
	local function sync()
		if shopGui.Enabled and openPage then
			setOpen(nil)
		end
		gui.Enabled = not shopGui.Enabled
	end
	shopGui:GetPropertyChangedSignal("Enabled"):Connect(sync)
	sync()
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
		if openPage ~= "index" and player:GetAttribute(name) == 1 then
			indexBadge.Visible = true -- a new animal unlocked
		end
		refresh()
	end
end)
local function watchInventory(folder)
	inventory = folder
	folder.ChildAdded:Connect(function(item)
		item.AttributeChanged:Connect(refresh)
		if openPage ~= "bag" then
			bagBadge.Visible = true
		end
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
local carryBanner = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(640, 54),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
	Parent = gui,
})
UIStyle.corner(carryBanner, 14)
UIStyle.stroke(carryBanner, 3)
UIStyle.gradient(carryBanner, ColorSequence.new(Color3.fromRGB(255, 104, 40), Color3.fromRGB(255, 196, 56)), 0)
local carryText = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 24, Parent = carryBanner })
local function updateCarry()
	local carrying = player:GetAttribute("Carrying")
	local show = carrying ~= nil
	if show and not carryBanner.Visible then
		UIStyle.pop(carryBanner)
	end
	carryBanner.Visible = show
	if carrying then
		carryText.Text = string.format("🐾 Carrying %s  →  take it over the RED LINE!", carrying)
	end
end
player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
updateCarry()
