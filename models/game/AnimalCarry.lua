-- AnimalCarry (ModuleScript in ServerScriptService; AnimalManager hands it dead animals, AnimalSpawner starts it)
--
-- What happens after an animal is shot dead:
--   1. it topples over and lies on the ground in Workspace.AnimalBodies (no money is paid)
--   2. only the player who killed it can pick it up (ProximityPrompt, E) - you carry one at a time, slung over your
--      right shoulder (hanging head-down your back, your right arm raised holding it; tools are put away meanwhile)
--   3. carry it over the red line (Workspace.RedLine, back towards the plots) and it goes into your inventory
--      (InventoryAdapter) and unlocks it in your Index (player attribute Caught_<Species> = how many you brought home)
-- If you die while carrying, it drops where you died. Bodies nobody picks up vanish after BODY_LIFETIME seconds.
-- Player attribute Carrying = the name of what you carry (for the client's banner).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local InventoryAdapter = require(script.Parent:WaitForChild("InventoryAdapter"))

local AnimalCarry = {}

local BODY_LIFETIME = 120 -- seconds an uncollected body stays
local PICKUP_DISTANCE = 12
local MAX_CARRY_SIZE = 3.6 -- studs: bigger bodies are shrunk while carried so they fit on your shoulder
local TOPPLE_TIME = 0.3

local bodiesFolder = workspace:FindFirstChild("AnimalBodies")
if not bodiesFolder then
	bodiesFolder = Instance.new("Folder")
	bodiesFolder.Name = "AnimalBodies"
	bodiesFolder.Parent = workspace
end
local animalEvent = ReplicatedStorage:FindFirstChild("AnimalEvent")
if not animalEvent then
	animalEvent = Instance.new("RemoteEvent")
	animalEvent.Name = "AnimalEvent"
	animalEvent.Parent = ReplicatedStorage
end

local bodies = {} -- [model] = body
local carrying = {} -- [player] = body
local started = false

---------------------------------------------------------------- the red line
local line, lineNormal, homeSign

local function findLine()
	line = workspace:FindFirstChild("RedLine")
	if not line then
		for _, p in ipairs(workspace:GetChildren()) do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon and p.BrickColor == BrickColor.new("Bright red") then
				line = p
				break
			end
		end
	end
	if not line then
		warn("[AnimalCarry] no red line (Workspace.RedLine) found: animals can't be brought home")
		return
	end
	-- you cross the line along its thin horizontal axis; "home" is the side the SpawnLocation is on
	local axis = line.Size.X < line.Size.Z and line.CFrame.RightVector or line.CFrame.LookVector
	lineNormal = Vector3.new(axis.X, 0, axis.Z).Unit
	local spawn = workspace:FindFirstChild("SpawnLocation")
	homeSign = spawn and math.sign((spawn.Position - line.Position):Dot(lineNormal)) or 1
	if homeSign == 0 then
		homeSign = 1
	end
end

local function isHome(position)
	return line ~= nil and (position - line.Position):Dot(lineNormal) * homeSign > 1
end

---------------------------------------------------------------- helpers
local function groundBelow(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { bodiesFolder }
	for _, name in ipairs({ "Animals", "AnimalSpawnZones", "Decor" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return result and result.Position.Y or position.Y
end

local function displayName(info)
	return AnimalData.DisplayName(info.species, info.size, info.mutation)
end

local function notify(player, text)
	animalEvent:FireClient(player, "Notice", { text = text })
end

local function moveParts(info, rootCF)
	local cfs = table.create(#info.parts)
	for i in ipairs(info.parts) do
		cfs[i] = rootCF * info.offsets[i]
	end
	workspace:BulkMoveTo(info.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- lying on its side at pos (t = 0 standing .. 1 fully toppled), rolled about its own front-back axis
local function groundPose(info, pos, yaw, t)
	local roll = math.rad(90) * t
	return CFrame.new(pos + Vector3.new(0, info.width / 2 * math.sin(roll), 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, roll)
end

-- slung over the right shoulder, relative to the torso: hanging head-down your back with its belly against it,
-- its hind end at the top of the shoulder where the hand holds it.
-- (Animal axes: X width, Y up, Z length with the nose at -Z; the root is the bottom centre.)
-- The raised arm is posed on every client by AnimalClient (player attribute Carrying).
local HANG = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
local function carryPose(info, torso)
	local x = torso.Size.X / 2 - 0.4 -- over the right shoulder blade
	local y = torso.Size.Y / 2 + 0.3 - info.length / 2 -- hind end just above the shoulder
	local z = torso.Size.Z / 2 + 0.02 -- against the back
	return CFrame.new(x, y, z) * HANG
end

local function setScale(body, k)
	-- shrink (k < 1) or restore the body, keeping the stored pose offsets in step
	local info = body.info
	body.model:ScaleTo(body.model:GetScale() * k)
	for i, o in ipairs(info.offsets) do
		info.offsets[i] = o - o.Position + o.Position * k
	end
	info.height *= k
	info.width *= k
	info.length *= k
end

---------------------------------------------------------------- bodies on the ground
local pickUp -- forward

local function addPrompt(body)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUp"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = displayName(body.info)
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body.model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		pickUp(player, body)
	end)
	body.prompt = prompt
end

local function layDown(body, position, animate)
	local info = body.info
	for _, p in ipairs(info.parts) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	body.model.Parent = bodiesFolder
	local pos = Vector3.new(position.X, groundBelow(position), position.Z)
	body.pos = pos
	if animate then
		task.spawn(function()
			local t0 = os.clock()
			while true do
				local t = math.min((os.clock() - t0) / TOPPLE_TIME, 1)
				if body.carried or not body.model.Parent then
					return
				end
				moveParts(info, groundPose(info, pos, info.yaw, t * t))
				if t >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
	else
		moveParts(info, groundPose(info, pos, info.yaw, 1))
	end
	body.expires = os.clock() + BODY_LIFETIME
	addPrompt(body)
end

-- AnimalManager: this animal was just killed by `owner`
function AnimalCarry.AddBody(model, info, owner)
	local body = { model = model, info = info, ownerId = owner.UserId }
	bodies[model] = body
	model:SetAttribute("Dead", true)
	model:SetAttribute("OwnerUserId", owner.UserId)
	layDown(body, info.pos, true)
	animalEvent:FireClient(owner, "Killed", {
		species = info.species,
		size = info.size,
		mutation = info.mutation,
		rarity = info.rarity,
	})
end

function AnimalCarry.Folder()
	return bodiesFolder
end

---------------------------------------------------------------- carrying
pickUp = function(player, body)
	if body.carried or not body.model.Parent or player.UserId ~= body.ownerId then
		return
	end
	if carrying[player] then
		notify(player, "You can only carry one animal at a time")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	if (root.Position - body.pos).Magnitude > PICKUP_DISTANCE + 6 then
		return
	end

	body.carried = true
	carrying[player] = body
	if body.prompt then
		body.prompt:Destroy()
		body.prompt = nil
	end
	local info = body.info
	local biggest = math.max(info.height, info.width, info.length)
	body.carryScale = math.min(1, MAX_CARRY_SIZE / biggest)
	if body.carryScale < 0.999 then
		setScale(body, body.carryScale)
	end

	-- hands free: put any tool away, and keep it away while carrying
	humanoid:UnequipTools()
	body.toolWatch = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function()
				if carrying[player] == body then
					humanoid:UnequipTools()
					notify(player, "Your hands are full - take it over the red line first!")
				end
			end)
		end
	end)

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
	local base = torso.CFrame * carryPose(info, torso)
	for i, p in ipairs(info.parts) do
		p.CFrame = base * info.offsets[i]
	end
	body.model.Parent = character
	for _, p in ipairs(info.parts) do
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CarryWeld"
		weld.Part0 = torso
		weld.Part1 = p
		weld.Parent = p
		p.Anchored = false
	end
	player:SetAttribute("Carrying", displayName(info)) -- also tells every client to pose the holding arm
end

-- the carry is over (dropped, delivered): tools allowed again (the arm drops when Carrying is cleared)
local function endCarry(body)
	if body.toolWatch then
		body.toolWatch:Disconnect()
		body.toolWatch = nil
	end
end

-- put down what the player carries where they stand (death, respawn); destroy = they left the game
local function drop(player, destroy)
	local body = carrying[player]
	if not body then
		return
	end
	carrying[player] = nil
	endCarry(body)
	if player.Parent then
		player:SetAttribute("Carrying", nil)
	end
	local model = body.model
	if destroy or not model.Parent or not model.PrimaryPart then
		bodies[model] = nil
		model:Destroy()
		return
	end
	local position = model.PrimaryPart.Position
	for _, p in ipairs(body.info.parts) do
		local weld = p:FindFirstChild("CarryWeld")
		if weld then
			weld:Destroy()
		end
		p.Anchored = true
		p.Massless = false
	end
	if body.carryScale and body.carryScale < 0.999 then
		setScale(body, 1 / body.carryScale)
	end
	body.carried = false
	layDown(body, position, false)
end

local function deliver(player, body)
	carrying[player] = nil
	endCarry(body)
	bodies[body.model] = nil
	player:SetAttribute("Carrying", nil)
	local info = body.info
	InventoryAdapter.Add(player, {
		Species = info.species,
		Size = info.size,
		Mutation = info.mutation,
		Rarity = info.rarity,
		World = info.world,
		Value = info.value,
	})
	local key = "Caught_" .. info.species
	local count = (player:GetAttribute(key) or 0) + 1
	player:SetAttribute(key, count)
	local center = body.model.PrimaryPart and body.model.PrimaryPart.Position
	body.model:Destroy()
	if center then
		animalEvent:FireAllClients("Caught", { position = center, mutation = info.mutation, scale = 1 })
	end
	animalEvent:FireClient(player, "Delivered", {
		species = info.species,
		size = info.size,
		mutation = info.mutation,
		rarity = info.rarity,
		value = info.value,
		firstTime = count == 1,
	})
end

---------------------------------------------------------------- start
local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			drop(player)
		end)
	end
end

function AnimalCarry.Start()
	if started then
		return
	end
	started = true
	findLine()

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		player.CharacterRemoving:Connect(function()
			drop(player)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		drop(player, true)
		for model, body in pairs(bodies) do
			if body.ownerId == player.UserId and not body.carried then
				bodies[model] = nil
				model:Destroy()
			end
		end
	end)

	-- bring-home check for carriers
	RunService.Heartbeat:Connect(function()
		for player, body in pairs(carrying) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and isHome(root.Position) then
				deliver(player, body)
			end
		end
	end)

	-- old bodies vanish
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for model, body in pairs(bodies) do
				if not body.carried and body.expires and now > body.expires then
					bodies[model] = nil
					animalEvent:FireAllClients("Despawn", { position = body.pos + Vector3.new(0, 1, 0), mutation = body.info.mutation, scale = 1 })
					model:Destroy()
				end
			end
		end
	end)
end

return AnimalCarry
