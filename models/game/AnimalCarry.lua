-- AnimalCarry (ModuleScript in ServerScriptService; AnimalManager hands it knocked-out animals, AnimalSpawner starts it)
--
-- What happens when an animal is shot down (its health reaches 0):
--   1. it isn't dead, it's STUNNED: it topples over and lies in Workspace.AnimalBodies for STUN_TIME seconds
--      (model attribute StunEnd = server time it wakes up; AnimalClient shows stars + a countdown). No money is paid.
--   2. only the player who shot it can pick it up (ProximityPrompt, E) - EXCEPT after a carrier was shot and
--      dropped it (KnockOff with steal): then anyone may grab it, and whoever does becomes its owner - you carry one at a time, slung over your
--      right shoulder (hanging head-down your back, your right arm raised holding it; tools are put away meanwhile).
--      Picking it up stops the timer. Drop it (G / the Drop button, or by dying) and the timer starts over.
--   3. carry it over the red line (Workspace.RedLine, back towards the plots) and it goes into your inventory
--      (InventoryAdapter) and unlocks it in your Index (player attribute Caught_<Species> = how many you brought home)
--   4. if the timer runs out first, it stands back up and runs off: AnimalManager.Revive (registered via OnRevive)
--      makes it a live animal again, full health.
-- Player attribute Carrying = the name of what you carry (for the client's banner).
--   Remote: ReplicatedStorage.AnimalEvent  client -> server  FireServer("Drop")  put down what you carry
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local SpeedData = require(ReplicatedStorage:WaitForChild("SpeedData")) -- StaminaToCarry: heavy animals need Stamina
local AnimalRig = require(ReplicatedStorage:WaitForChild("AnimalRig"))
local InventoryAdapter = require(script.Parent:WaitForChild("InventoryAdapter"))

local AnimalCarry = {}

local STUN_TIME = AnimalData.StunTime or 10 -- seconds a stunned animal lies there before it wakes up (restarts when dropped)
local STANDUP_TIME = 0.4
local PICKUP_DISTANCE = 12
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

local bodies = {} -- [model] = body (lying stunned or being carried)
local carrying = {} -- [player] = body
local started = false
local reviveHandler = nil -- AnimalManager.Revive

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
	return AnimalData.DisplayName(info.species, info.weight or info.size, info.mutation)
end

local function notify(player, text)
	animalEvent:FireClient(player, "Notice", { text = text })
end

local function moveParts(info, rootCF)
	local model = info.parts[1].Parent
	while model and not model:FindFirstChild("AnimalJoints") do model = model.Parent end
	assert(model, "Missing rig for stunned animal")
	AnimalRig.Move(model, info.parts, info.offsets, rootCF)
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

---------------------------------------------------------------- bodies on the ground
local pickUp -- forward

local function addPrompt(body)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUp"
	prompt.ActionText = "Pick up"
	local need = SpeedData.StaminaToCarry(AnimalData.Weight(body.info.species, body.info.weight or body.info.size))
	prompt.ObjectText = "Stunned " .. displayName(body.info) .. (need > 0 and ("  •  needs " .. SpeedData.Commas(need) .. " ⚡ Stamina") or "")
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
	AnimalRig.SetAnchored(body.model, true)
	AnimalRig.Reset(body.model)
	body.model:SetAttribute("AnimationContext", "Stunned")
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
	-- the stun timer (re)starts whenever it is put down
	body.expires = os.clock() + STUN_TIME
	body.model:SetAttribute("StunEnd", workspace:GetServerTimeNow() + STUN_TIME)
	addPrompt(body)
end

-- the timer ran out: it gets back up (the reverse of toppling) and AnimalManager makes it a live animal again
local function wakeUp(body)
	bodies[body.model] = nil
	local model, info = body.model, body.info
	if body.prompt then
		body.prompt:Destroy()
		body.prompt = nil
	end
	model:SetAttribute("StunEnd", nil)
	task.spawn(function()
		local t0 = os.clock()
		while model.Parent do
			local t = math.min((os.clock() - t0) / STANDUP_TIME, 1)
			moveParts(info, groundPose(info, body.pos, info.yaw, 1 - t * t))
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if not model.Parent then
			return
		end
		model:SetAttribute("Dead", nil)
		model:SetAttribute("OwnerUserId", nil)
		local owner = Players:GetPlayerByUserId(body.ownerId)
		if owner then
			notify(owner, displayName(info) .. " woke up and ran off!")
		end
		if reviveHandler then
			reviveHandler(model, info, body.pos)
		else
			model:Destroy()
		end
	end)
end

-- AnimalManager: who brings animals back to life when they wake up
function AnimalCarry.OnRevive(handler)
	reviveHandler = handler
end

-- stunned animals (lying or carried) that belong to this spawn zone; they still count towards its population
function AnimalCarry.CountForZone(zone)
	local n = 0
	for _, body in pairs(bodies) do
		if body.info.zone == zone then
			n += 1
		end
	end
	return n
end

-- AnimalManager: this animal was just shot down (stunned) by `owner`
function AnimalCarry.AddBody(model, info, owner)
	local body = { model = model, info = info, ownerId = owner.UserId }
	bodies[model] = body
	model:SetAttribute("Dead", true)
	model:SetAttribute("OwnerUserId", owner.UserId)
	layDown(body, info.pos, true)
	animalEvent:FireClient(owner, "Killed", {
		species = info.species,
		weight = info.weight or AnimalData.Weight(info.species, info.size),
		mutation = info.mutation,
		rarity = info.rarity,
	})
end

function AnimalCarry.Folder()
	return bodiesFolder
end

---------------------------------------------------------------- carrying
pickUp = function(player, body)
	if body.carried or not body.model.Parent or (player.UserId ~= body.ownerId and not body.open) then
		return
	end
	if carrying[player] then
		notify(player, "You can only carry one animal at a time")
		return
	end
	-- heavy animals need Stamina (trained on your treadmill): models/speed/SpeedData.StaminaToCarry
	local need = SpeedData.StaminaToCarry(AnimalData.Weight(body.info.species, body.info.weight or body.info.size))
	local stats = player:FindFirstChild("leaderstats")
	local stamina = stats and stats:FindFirstChild("Stamina")
	if need > 0 and (not stamina or stamina.Value < need) then
		notify(player, string.format("Too heavy! You need %s ⚡ Stamina - train on your treadmill", SpeedData.Commas(need)))
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
	if body.open then
		-- it was knocked out of someone's hands: whoever grabs it first owns it now
		body.open = false
		body.ownerId = player.UserId
		body.model:SetAttribute("OwnerUserId", player.UserId)
	end
	body.expires = nil -- the stun timer stops while it's carried
	body.model:SetAttribute("StunEnd", nil)
	carrying[player] = body
	if body.prompt then
		body.prompt:Destroy()
		body.prompt = nil
	end
	local info = body.info

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
	moveParts(info, base)
	body.model.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = torso
	weld.Part1 = body.model.PrimaryPart
	weld.Parent = body.model.PrimaryPart
	AnimalRig.SetAnchored(body.model, false)
	player:SetAttribute("Carrying", displayName(info)) -- also tells every client to pose the holding arm
end

-- the carry is over (dropped, delivered): tools allowed again (the arm drops when Carrying is cleared)
local function endCarry(body)
	if body.toolWatch then
		body.toolWatch:Disconnect()
		body.toolWatch = nil
	end
end

-- put down what the player carries where they stand (Drop key, death, respawn) - its stun timer starts over;
-- destroy = remove it altogether
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
		WeightKg = info.weight or AnimalData.Weight(info.species, info.size),
		Scale = info.scale or AnimalData.WeightTraits(info.species, info.weight or info.size).scale,
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
		weight = info.weight or AnimalData.Weight(info.species, info.size),
		mutation = info.mutation,
		rarity = info.rarity,
		value = info.value,
		firstTime = count == 1,
	})
end

-- the carrier got hit (shot by another player, punched by a Yeti): they drop it on the spot.
-- steal = true: ANYONE may pick it up now (until its stun timer runs out). message: "%s" = the animal's name.
function AnimalCarry.KnockOff(player, steal, message)
	local body = carrying[player]
	if not body then
		return false
	end
	if steal then
		body.open = true
		body.model:SetAttribute("OwnerUserId", nil) -- every client shows the pick-up prompt again
	end
	drop(player)
	if steal and body.prompt then
		body.prompt.ActionText = "Steal"
	end
	if message then
		notify(player, string.format(message, displayName(body.info)))
	end
	return true
end

function AnimalCarry.IsCarrying(player)
	return carrying[player] ~= nil
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
		drop(player)
		for _, body in pairs(bodies) do
			if body.ownerId == player.UserId and not body.carried then
				body.expires = os.clock() -- nobody can pick these up any more: they wake up right away
			end
		end
	end)

	-- the Drop key / button (AnimalMenuClient)
	local lastDrop = {}
	animalEvent.OnServerEvent:Connect(function(player, kind)
		if kind == "Drop" and carrying[player] and os.clock() - (lastDrop[player] or 0) > 0.5 then
			lastDrop[player] = os.clock()
			drop(player)
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

	-- stunned animals nobody picked up wake up
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, body in pairs(bodies) do
				if not body.carried and body.expires and now >= body.expires then
					wakeUp(body)
				end
			end
		end
	end)
end

return AnimalCarry
