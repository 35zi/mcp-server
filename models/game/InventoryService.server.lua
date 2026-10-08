-- InventoryService (Script in ServerScriptService)
--
-- Server side of the Inventory menu (AnimalMenuClient only asks; everything is checked here):
--   Remote: ReplicatedStorage.AnimalInventoryRemote (RemoteFunction) -> ok, message
--     :InvokeServer("Hold", id)   in the bag -> held in your hand (a Tool in your Backpack); held -> back in the bag
--     :InvokeServer("Plot", id)   put it on your plot (from the bag or your hand)
--     :InvokeServer("Bag", id)    back into the bag (from your plot or your hand)
-- Entries are the Folders in player.AnimalInventory (InventoryAdapter); their State attribute says where each is.
-- Placed animals live in Workspace.PlotAnimals.<UserId>; the owner can also walk up to one and press E to take it
-- back. Your plot comes from Codex's plot system: player attribute PlotName -> Workspace.<PlotName> (its Hitbox is
-- the area). Nothing is saved yet (no DataStore); selling comes later.
-- Also builds ReplicatedStorage.AnimalPreviews (one Medium model per species) for the menus' pictures.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local AnimalManager = require(ServerScriptService:WaitForChild("AnimalManager"))
local InventoryAdapter = require(ServerScriptService:WaitForChild("InventoryAdapter"))

local MAX_PER_PLOT = 24
local HOLD_SIZE = 2.6 -- studs: held animals are shrunk to fit in a hand
local rng = Random.new()

local remote = ReplicatedStorage:FindFirstChild("AnimalInventoryRemote")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "AnimalInventoryRemote"
	remote.Parent = ReplicatedStorage
end
local plotAnimals = workspace:FindFirstChild("PlotAnimals")
if not plotAnimals then
	plotAnimals = Instance.new("Folder")
	plotAnimals.Name = "PlotAnimals"
	plotAnimals.Parent = workspace
end

---------------------------------------------------------------- pictures for the menus
do
	local previews = ReplicatedStorage:FindFirstChild("AnimalPreviews") or Instance.new("Folder")
	previews.Name = "AnimalPreviews"
	previews:ClearAllChildren()
	for species in pairs(AnimalData.Species) do
		local model = AnimalManager.BuildModel(species, "Medium", "None")
		if model then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanQuery = false
				end
			end
			model.Parent = previews
		end
	end
	previews.Parent = ReplicatedStorage
end

---------------------------------------------------------------- helpers
local function nameOf(item)
	return AnimalData.DisplayName(item:GetAttribute("Species"), item:GetAttribute("Size"), item:GetAttribute("Mutation"))
end

local function plotOf(player)
	local name = player:GetAttribute("PlotName")
	local plot = type(name) == "string" and name ~= "" and workspace:FindFirstChild(name)
	if plot and plot:FindFirstChild("Hitbox") then
		return plot
	end
	return nil
end

local function plotFolder(player)
	local folder = plotAnimals:FindFirstChild(tostring(player.UserId))
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder.Parent = plotAnimals
	end
	return folder
end

local function findHeldTool(player, id)
	for _, holder in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("AnimalEntryId") == id then
					return child
				end
			end
		end
	end
	return nil
end

local function findPlaced(player, id)
	local folder = plotAnimals:FindFirstChild(tostring(player.UserId))
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:GetAttribute("EntryId") == id then
				return model
			end
		end
	end
	return nil
end

---------------------------------------------------------------- holding (a Tool)
local function makeHoldTool(player, item)
	local id = item:GetAttribute("Id")
	local model = AnimalManager.BuildModel(item:GetAttribute("Species"), item:GetAttribute("Size"), item:GetAttribute("Mutation"))
	if not model then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > HOLD_SIZE then
		model:ScaleTo(model:GetScale() * HOLD_SIZE / biggest)
	end
	local parts, offsets, box = AnimalManager.RootOffsets(model)

	local tool = Instance.new("Tool")
	tool.Name = nameOf(item)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("AnimalEntryId", id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool
	-- held in the fist by its middle, facing forward (Handle -Z)
	local base = handle.CFrame * CFrame.new(0, -box.Y / 2, 0)
	for i, p in ipairs(parts) do
		p.CFrame = base * offsets[i]
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Anchored = false
	end
	model.Parent = tool
	tool.Destroying:Connect(function()
		-- lost with the Backpack on death etc.: it goes back into the bag
		if item.Parent and item:GetAttribute("State") == "Held" then
			item:SetAttribute("State", "Bag")
		end
	end)
	return tool
end

local function hold(player, item)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not backpack or not humanoid or humanoid.Health <= 0 then
		return false, "Can't hold it right now"
	end
	local tool = makeHoldTool(player, item)
	if not tool then
		return false, "This animal has no model"
	end
	item:SetAttribute("State", "Held")
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	return true, "Holding " .. nameOf(item)
end

---------------------------------------------------------------- plot
local function placeOnPlot(player, item)
	local plot = plotOf(player)
	if not plot then
		return false, "You don't have a plot yet"
	end
	local folder = plotFolder(player)
	if #folder:GetChildren() >= MAX_PER_PLOT then
		return false, "Your plot is full"
	end
	local model = AnimalManager.BuildModel(item:GetAttribute("Species"), item:GetAttribute("Size"), item:GetAttribute("Mutation"))
	if not model then
		return false, "This animal has no model"
	end
	local parts, offsets, box = AnimalManager.RootOffsets(model)
	local hitbox = plot.Hitbox
	local spawnPoint = plot:FindFirstChild("SpawnPoint")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { plotAnimals, hitbox }
	for _, name in ipairs({ "Animals", "AnimalBodies", "AnimalSpawnZones" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude

	local spacing = math.max(4, math.max(box.X, box.Z) * 0.8)
	local hx, hz = hitbox.Size.X / 2 - 5, hitbox.Size.Z / 2 - 5
	local spot
	for _ = 1, 60 do
		local p = hitbox.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-hx, hx), 0, rng:NextNumber(-hz, hz)))
		local ok = not spawnPoint or (Vector3.new(p.X - spawnPoint.Position.X, 0, p.Z - spawnPoint.Position.Z)).Magnitude > 7
		if ok then
			for _, other in ipairs(folder:GetChildren()) do
				local o = other:GetPivot().Position
				if Vector3.new(p.X - o.X, 0, p.Z - o.Z).Magnitude < spacing then
					ok = false
					break
				end
			end
		end
		if ok then
			local top = hitbox.Position.Y + hitbox.Size.Y / 2
			local hit = workspace:Raycast(Vector3.new(p.X, top, p.Z), Vector3.new(0, -(hitbox.Size.Y + 10), 0), params)
			if hit then
				spot = hit.Position
				break
			end
		end
	end
	if not spot then
		model:Destroy()
		return false, "No room on your plot"
	end

	local root = CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local cfs = table.create(#parts)
	for i, p in ipairs(parts) do
		p.CanQuery = false
		cfs[i] = root * offsets[i]
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("EntryId", item:GetAttribute("Id"))

	-- name tag (UIStyle look: chunky white text, dark outline)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PlotTag"
	gui.Size = UDim2.fromOffset(160, 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, spot.Y + box.Y - model.PrimaryPart.Position.Y + 1.2, 0) -- just above its head
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Adornee = model.PrimaryPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = nameOf(item)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(24, 18, 28)
	stroke.Parent = label
	gui.Parent = model.PrimaryPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakeBack"
	prompt.ActionText = "Put in bag"
	prompt.ObjectText = nameOf(item)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(who)
		if who == player and item.Parent and item:GetAttribute("State") == "Plot" then
			model:Destroy()
			item:SetAttribute("State", "Bag")
		end
	end)

	model.Parent = folder
	item:SetAttribute("State", "Plot")
	return true, nameOf(item) .. " is on your plot"
end

---------------------------------------------------------------- requests
local function handle(player, action, id)
	if type(id) ~= "number" then
		return false, "Bad request"
	end
	local item = InventoryAdapter.Get(player, id)
	if not item then
		return false, "You don't have that animal"
	end
	local state = item:GetAttribute("State")

	if action == "Hold" then
		if state == "Held" then
			local tool = findHeldTool(player, id)
			item:SetAttribute("State", "Bag")
			if tool then
				tool:Destroy()
			end
			return true, "Put away"
		elseif state == "Plot" then
			local placed = findPlaced(player, id)
			if placed then
				placed:Destroy()
			end
			item:SetAttribute("State", "Bag")
		end
		return hold(player, item)
	elseif action == "Plot" then
		if state == "Plot" then
			return false, "It's already on your plot"
		end
		local ok, message = placeOnPlot(player, item)
		if ok and state == "Held" then
			local tool = findHeldTool(player, id)
			if tool then
				tool:Destroy()
			end
		end
		return ok, message
	elseif action == "Bag" then
		if state == "Plot" then
			local placed = findPlaced(player, id)
			if placed then
				placed:Destroy()
			end
		elseif state == "Held" then
			local tool = findHeldTool(player, id)
			item:SetAttribute("State", "Bag")
			if tool then
				tool:Destroy()
			end
		end
		item:SetAttribute("State", "Bag")
		return true, "In your bag"
	end
	return false, "Unknown action"
end

local busy = {}
remote.OnServerInvoke = function(player, action, id)
	if type(action) ~= "string" or busy[player] then
		return false, "Slow down"
	end
	busy[player] = true
	task.delay(0.2, function()
		busy[player] = nil
	end)
	local ok, success, message = pcall(handle, player, action, id)
	if not ok then
		warn("[InventoryService]", success)
		return false, "Something went wrong"
	end
	return success, message
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	local folder = plotAnimals:FindFirstChild(tostring(player.UserId))
	if folder then
		folder:Destroy()
	end
end)
