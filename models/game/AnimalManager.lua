-- AnimalManager (ModuleScript in ServerScriptService; started by the AnimalSpawner Script)
--
-- Spawns, moves, damages and "catches" the huntable animals. Everything is server-side; clients only add effects
-- (AnimalClient: dust puffs, squeaks, popups) and the weapon code (WeaponCombatService) calls Damage().
--
--   Templates:   ServerStorage.AnimalTemplates.<Species>  (Models of Parts, PrimaryPart = Body, front = Body -Z)
--   Spawn zones: every Part in Workspace.AnimalSpawnZones (invisible boxes; move/resize them in Studio)
--   Live:        Workspace.Animals (Models with attributes Species, Size, Mutation, Health, MaxHealth, Hop, Land)
--
-- Waves: one at server start, then every WAVE_INTERVAL seconds. Animals that survived MAX_AGE_WAVES waves are
-- replaced, then the population is topped back up to POPULATION.
-- Sizes: each spawn rolls Small / Medium / Large (scale, HP and value change with it).
-- Mutations (rare): Gold = gold tint + sparkles + 5x value and a Cash bonus when caught;
--                   Silver = silver tint + 30% more HP.
-- Catching: when Health reaches 0 the shooter gets the animal in their (placeholder) inventory.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CashAdapter = require(script.Parent:WaitForChild("CashAdapter"))
local InventoryAdapter = require(script.Parent:WaitForChild("InventoryAdapter"))

local AnimalManager = {}

---------------------------------------------------------------- tuning
local WAVE_INTERVAL = 300 -- seconds (5 minutes)
local POPULATION = 12 -- animals alive after each wave
local MAX_AGE_WAVES = 2 -- an animal is replaced after surviving this many waves
local MIN_SPACING = 7 -- studs between spawned animals
local ZONE_MARGIN = 3 -- keep animals this far inside a zone's edges

-- hp/value are for a Medium animal; weight = how often it spawns; hop* = how it moves
local SPECIES = {
	Bunny = { hp = 10, value = 10, weight = 3, hopHeight = 2.2, hopDist = 4.5, hopTime = 0.5 },
	Frog = { hp = 10, value = 12, weight = 2, hopHeight = 2.6, hopDist = 5.5, hopTime = 0.55 },
	Mouse = { hp = 5, value = 8, weight = 3, hopHeight = 0.8, hopDist = 2.6, hopTime = 0.28 },
	Squirrel = { hp = 15, value = 15, weight = 2, hopHeight = 1.8, hopDist = 4.0, hopTime = 0.42 },
	Hedgehog = { hp = 20, value = 20, weight = 1, hopHeight = 0.6, hopDist = 2.0, hopTime = 0.35 },
	Duckling = { hp = 10, value = 10, weight = 2, hopHeight = 1.0, hopDist = 2.5, hopTime = 0.32 },
}
local SIZES = {
	{ name = "Small", scale = 0.75, chance = 0.35, hp = 0.75, value = 0.8 },
	{ name = "Medium", scale = 1.0, chance = 0.45, hp = 1.0, value = 1.0 },
	{ name = "Large", scale = 1.35, chance = 0.20, hp = 1.5, value = 1.5 },
}
local MUTATIONS = {
	Gold = { chance = 0.015, tint = Color3.fromRGB(255, 196, 30), tintAmount = 0.85, reflectance = 0.25, hp = 1.0, value = 5 },
	Silver = { chance = 0.025, tint = Color3.fromRGB(205, 215, 230), tintAmount = 0.8, reflectance = 0.3, hp = 1.3, value = 1 },
}

---------------------------------------------------------------- setup
local templates = ServerStorage:WaitForChild("AnimalTemplates")
local zonesFolder = workspace:WaitForChild("AnimalSpawnZones")
local animalsFolder = workspace:FindFirstChild("Animals")
if not animalsFolder then
	animalsFolder = Instance.new("Folder")
	animalsFolder.Name = "Animals"
	animalsFolder.Parent = workspace
end
local animalEvent = ReplicatedStorage:FindFirstChild("AnimalEvent")
if not animalEvent then
	animalEvent = Instance.new("RemoteEvent")
	animalEvent.Name = "AnimalEvent"
	animalEvent.Parent = ReplicatedStorage
end

local rng = Random.new()
local records = {} -- [model] = record
local waveNumber = 0
local nextId = 0
local started = false

local function excludeList()
	local list = { animalsFolder, zonesFolder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function groundAt(x, z, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local result = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -200, 0), params)
	return result and result.Position.Y or nil
end

-- local-space bounds of a zone part, shrunk by the margin
local function zoneBounds(zone)
	local hx = math.max(zone.Size.X / 2 - ZONE_MARGIN, 0.5)
	local hz = math.max(zone.Size.Z / 2 - ZONE_MARGIN, 0.5)
	return hx, hz
end

local function insideZone(zone, position)
	local p = zone.CFrame:PointToObjectSpace(position)
	local hx, hz = zoneBounds(zone)
	return math.abs(p.X) <= hx and math.abs(p.Z) <= hz
end

local function pickZone()
	local zones, total = {}, 0
	for _, z in ipairs(zonesFolder:GetChildren()) do
		if z:IsA("BasePart") then
			local area = z.Size.X * z.Size.Z
			table.insert(zones, { z, area })
			total += area
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in ipairs(zones) do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return zones[#zones][1]
end

local function randomPoint(zone)
	local hx, hz = zoneBounds(zone)
	local world = zone.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-hx, hx), 0, rng:NextNumber(-hz, hz)))
	local top = zone.Position.Y + zone.Size.Y / 2 + 20
	local y = groundAt(world.X, world.Z, top)
	return y and Vector3.new(world.X, y, world.Z) or nil
end

local function pickWeighted(list, weightOf)
	local total = 0
	for _, v in ipairs(list) do
		total += weightOf(v)
	end
	local roll = rng:NextNumber(0, total)
	for _, v in ipairs(list) do
		roll -= weightOf(v)
		if roll <= 0 then
			return v
		end
	end
	return list[#list]
end

local function rollSpecies()
	local available = {}
	for _, t in ipairs(templates:GetChildren()) do
		if t:IsA("Model") and SPECIES[t.Name] then
			table.insert(available, t.Name)
		end
	end
	if #available == 0 then
		return nil
	end
	return pickWeighted(available, function(name)
		return SPECIES[name].weight
	end)
end

local function rollSize()
	return pickWeighted(SIZES, function(s)
		return s.chance
	end)
end

local function rollMutation()
	local roll = rng:NextNumber()
	if roll < MUTATIONS.Gold.chance then
		return "Gold"
	elseif roll < MUTATIONS.Gold.chance + MUTATIONS.Silver.chance then
		return "Silver"
	end
	return "None"
end

---------------------------------------------------------------- look: mutation tint + tag / health bar
local function applyMutationLook(model, mutation)
	local m = MUTATIONS[mutation]
	if not m then
		return
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local c = part.Color
			local brightness = (c.R + c.G + c.B) / 3
			-- keep eyes, pupils and catch-lights readable
			if brightness > 0.12 and brightness < 0.97 then
				part.Color = c:Lerp(m.tint, m.tintAmount)
				part.Material = Enum.Material.SmoothPlastic
				part.Reflectance = m.reflectance
			end
		end
	end
	local body = model.PrimaryPart
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "MutationSparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(m.tint)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Transparency = NumberSequence.new(0.2)
	sparkle.Lifetime = NumberRange.new(0.6, 1.1)
	sparkle.Rate = mutation == "Gold" and 8 or 4
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = body
	if mutation == "Gold" then
		-- a thin gold outline so it stands out across the field (Gold is rare, so few Highlights at once)
		local outline = Instance.new("Highlight")
		outline.Name = "GoldOutline"
		outline.FillTransparency = 1
		outline.OutlineColor = m.tint
		outline.OutlineTransparency = 0.2
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
	end
end

local function makeTag(record)
	local body = record.model.PrimaryPart
	local gui = Instance.new("BillboardGui")
	gui.Name = "AnimalTag"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(120, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, record.height * 0.75 + 1.4, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = body

	if record.mutation ~= "None" then
		local label = Instance.new("TextLabel")
		label.Name = "Mutation"
		label.Size = UDim2.new(1, 0, 0, 22)
		label.BackgroundTransparency = 1
		label.Text = string.upper(record.mutation)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = MUTATIONS[record.mutation].tint
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(20, 20, 24)
		stroke.Parent = label
	end

	local bar = Instance.new("Frame")
	bar.Name = "HealthBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, 0)
	bar.Size = UDim2.fromOffset(90, 10)
	bar.BackgroundColor3 = Color3.fromRGB(30, 22, 18)
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	record.healthBar = bar
	record.healthFill = fill
end

local function showHealth(record)
	local bar, fill = record.healthBar, record.healthFill
	if not bar then
		return
	end
	local fraction = math.clamp(record.health / record.maxHealth, 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(90, 220, 90), fraction)
	bar.Visible = true
	record.barToken = (record.barToken or 0) + 1
	local token = record.barToken
	task.delay(4, function()
		if record.barToken == token and bar.Parent then
			bar.Visible = false
		end
	end)
end

---------------------------------------------------------------- spawning
local function spawnOne()
	local species = rollSpecies()
	local zone = pickZone()
	if not species or not zone then
		return nil
	end
	local position
	for _ = 1, 25 do
		local p = randomPoint(zone)
		if p then
			local ok = true
			for _, r in pairs(records) do
				if (r.pos - p).Magnitude < MIN_SPACING then
					ok = false
					break
				end
			end
			if ok then
				position = p
				break
			end
		end
	end
	if not position then
		return nil
	end

	local cfg = SPECIES[species]
	local size = rollSize()
	local mutation = rollMutation()
	local model = templates[species]:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = true
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("Body", true) or model:FindFirstChildWhichIsA("BasePart", true)
	end
	if size.scale ~= 1 then
		-- relative to the template's own scale (imported meshes are stored at e.g. 0.017, not 1)
		model:ScaleTo(model:GetScale() * size.scale)
	end
	applyMutationLook(model, mutation)

	-- root frame: bottom centre of the model, facing the template's front (Body -Z), yaw only
	local boxCF, boxSize = model:GetBoundingBox()
	local look = model.PrimaryPart.CFrame.LookVector
	local yaw0 = math.atan2(-look.X, -look.Z)
	local root0 = CFrame.new(boxCF.Position - Vector3.new(0, boxSize.Y / 2, 0)) * CFrame.Angles(0, yaw0, 0)
	local parts, offsets = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, root0:ToObjectSpace(d.CFrame))
		end
	end

	nextId += 1
	local maxHealth = math.max(1, math.floor(cfg.hp * size.hp * (MUTATIONS[mutation] and MUTATIONS[mutation].hp or 1) + 0.5))
	local value = math.floor(cfg.value * size.value * (MUTATIONS[mutation] and MUTATIONS[mutation].value or 1) + 0.5)
	model.Name = species
	model:SetAttribute("AnimalId", nextId)
	model:SetAttribute("Species", species)
	model:SetAttribute("Size", size.name)
	model:SetAttribute("Scale", size.scale)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("Value", value)
	model:SetAttribute("Hop", 0)
	model:SetAttribute("Land", 0)

	local record = {
		model = model,
		species = species,
		cfg = cfg,
		size = size,
		mutation = mutation,
		zone = zone,
		parts = parts,
		offsets = offsets,
		height = boxSize.Y,
		pos = position,
		yaw = rng:NextNumber(0, math.pi * 2),
		targetYaw = 0,
		state = "idle",
		stateT = 0,
		idleDur = rng:NextNumber(0.5, 3),
		hopsLeft = 0,
		step = Vector3.zero,
		hopFrom = position,
		hopTo = position,
		hops = 0,
		health = maxHealth,
		maxHealth = maxHealth,
		value = value,
		wave = waveNumber,
		clock = rng:NextNumber(0, 10),
	}
	record.targetYaw = record.yaw
	makeTag(record)
	records[model] = record
	model.Parent = animalsFolder
	if mutation ~= "None" then
		animalEvent:FireAllClients("Mutation", { species = species, mutation = mutation, size = size.name })
	end
	return record
end

local function removeRecord(record, effect)
	records[record.model] = nil
	record.dead = true
	if effect then
		animalEvent:FireAllClients(effect, { position = record.pos + Vector3.new(0, record.height / 2, 0), mutation = record.mutation, scale = record.size.scale })
	end
	record.model:Destroy()
end

local function wave()
	waveNumber += 1
	for _, record in pairs(records) do
		if waveNumber - record.wave >= MAX_AGE_WAVES then
			removeRecord(record, "Despawn")
		end
	end
	local alive = 0
	for _ in pairs(records) do
		alive += 1
	end
	for _ = alive + 1, POPULATION do
		spawnOne()
	end
	animalsFolder:SetAttribute("Wave", waveNumber)
	animalsFolder:SetAttribute("NextWaveAt", os.time() + WAVE_INTERVAL)
end

---------------------------------------------------------------- movement (one loop for every animal)
local function angleDiff(a, b)
	return ((b - a + math.pi) % (2 * math.pi)) - math.pi
end

local function pathClear(from, to, radius)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local up = Vector3.new(0, radius + 0.6, 0)
	return workspace:Spherecast(from + up, radius, to - from, params) == nil
end

local function startWander(record, awayFrom)
	local cfg = record.cfg
	local scale = record.size.scale
	for attempt = 1, 14 do
		local ang, dist
		if awayFrom and attempt <= 8 then
			local away = Vector3.new(record.pos.X - awayFrom.X, 0, record.pos.Z - awayFrom.Z)
			local base = away.Magnitude > 0.1 and math.atan2(away.Z, away.X) or rng:NextNumber(0, 2 * math.pi)
			ang = base + rng:NextNumber(-0.7, 0.7)
			dist = rng:NextNumber(10, 18) * scale
		else
			ang = rng:NextNumber(0, 2 * math.pi)
			dist = rng:NextNumber(5, 14) * scale
		end
		local target = record.pos + Vector3.new(math.cos(ang), 0, math.sin(ang)) * dist
		if insideZone(record.zone, target) and pathClear(record.pos, target, 0.8 * scale) then
			local delta = target - record.pos
			local hopDist = cfg.hopDist * scale
			record.hopsLeft = math.max(1, math.ceil(delta.Magnitude / hopDist))
			record.step = delta / record.hopsLeft
			record.targetYaw = math.atan2(-delta.X, -delta.Z)
			record.state, record.stateT = "turn", 0
			record.fleeing = awayFrom ~= nil
			return
		end
	end
	record.state, record.stateT = "idle", 0
	record.idleDur = rng:NextNumber(1, 2)
end

local function step(record, dt)
	local cfg = record.cfg
	local scale = record.size.scale
	local hopTime = cfg.hopTime * (record.fleeing and 0.75 or 1)
	record.clock += dt
	record.stateT += dt
	local diff = angleDiff(record.yaw, record.targetYaw)
	local turnSpeed = record.fleeing and 14 or 7
	record.yaw += math.clamp(diff, -turnSpeed * dt, turnSpeed * dt)

	local yOff, pitch, squash = 0, 0, 0
	if record.state == "idle" then
		yOff = 0.04 * scale * math.sin(record.clock * 2.6)
		if record.stateT >= record.idleDur then
			startWander(record)
		end
	elseif record.state == "turn" then
		if math.abs(angleDiff(record.yaw, record.targetYaw)) < 0.06 or record.stateT > 0.5 then
			record.state, record.stateT = "hop", 0
			record.hopFrom = record.pos
			record.hopTo = record.pos + record.step
			local y = groundAt(record.hopTo.X, record.hopTo.Z, record.hopTo.Y + 10)
			if y then
				record.hopTo = Vector3.new(record.hopTo.X, y, record.hopTo.Z)
			end
			record.hops += 1
			record.model:SetAttribute("Hop", record.hops)
		end
	elseif record.state == "hop" then
		local p = math.min(record.stateT / hopTime, 1)
		record.pos = record.hopFrom:Lerp(record.hopTo, p)
		yOff = cfg.hopHeight * scale * 4 * p * (1 - p)
		pitch = 0.3 * math.cos(math.pi * p)
		if p >= 1 then
			record.pos = record.hopTo
			record.hopsLeft -= 1
			record.state, record.stateT = "land", 0
			record.model:SetAttribute("Land", record.hops)
		end
	elseif record.state == "land" then
		local q = math.min(record.stateT / 0.16, 1)
		yOff = -0.12 * scale * math.sin(math.pi * q)
		if q >= 1 then
			if record.hopsLeft > 0 then
				record.state, record.stateT = "hop", 0
				record.hopFrom = record.pos
				record.hopTo = record.pos + record.step
				local y = groundAt(record.hopTo.X, record.hopTo.Z, record.hopTo.Y + 10)
				if y then
					record.hopTo = Vector3.new(record.hopTo.X, y, record.hopTo.Z)
				end
				record.hops += 1
				record.model:SetAttribute("Hop", record.hops)
			else
				record.fleeing = false
				record.state, record.stateT = "idle", 0
				record.idleDur = rng:NextNumber(1.5, 4)
			end
		end
	end
	return CFrame.new(record.pos + Vector3.new(0, yOff, 0)) * CFrame.Angles(0, record.yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

local function onHeartbeat(dt)
	local allParts, allCFrames = {}, {}
	for _, record in pairs(records) do
		if record.model.Parent then
			local root = step(record, dt)
			for i, part in ipairs(record.parts) do
				table.insert(allParts, part)
				table.insert(allCFrames, root * record.offsets[i])
			end
		end
	end
	if #allParts > 0 then
		workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------- public API
-- the animal a part belongs to (or nil)
function AnimalManager.FromPart(part)
	if typeof(part) ~= "Instance" or not part:IsDescendantOf(animalsFolder) then
		return nil
	end
	local model = part
	while model and model.Parent ~= animalsFolder do
		model = model.Parent
	end
	local record = model and records[model]
	if record and not record.dead then
		return record
	end
	return nil
end

function AnimalManager.Folder()
	return animalsFolder
end

function AnimalManager.Position(record)
	return record.pos + Vector3.new(0, record.height / 2, 0)
end

-- damage an animal; returns "hit" or "caught"
function AnimalManager.Damage(record, amount, player, hitPos)
	if record.dead then
		return "none"
	end
	record.health = math.max(0, record.health - amount)
	record.model:SetAttribute("Health", record.health)
	animalEvent:FireAllClients("Hit", { model = record.model, position = hitPos, scale = record.size.scale })

	if record.health <= 0 then
		local entry = { Species = record.species, Size = record.size.name, Mutation = record.mutation, Value = record.value }
		InventoryAdapter.Add(player, entry)
		local bonus = record.mutation == "Gold" and record.value or 0
		CashAdapter.Add(player, bonus)
		animalEvent:FireClient(player, "YouCaught", {
			species = record.species,
			size = record.size.name,
			mutation = record.mutation,
			value = record.value,
			bonus = bonus,
			count = player:GetAttribute("AnimalCount") or 1,
		})
		removeRecord(record, "Caught")
		return "caught"
	end

	showHealth(record)
	local character = player.Character
	local from = character and character:FindFirstChild("HumanoidRootPart")
	startWander(record, from and from.Position or hitPos)
	return "hit"
end

function AnimalManager.Start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(onHeartbeat)
	task.spawn(function()
		while true do
			wave()
			task.wait(WAVE_INTERVAL)
		end
	end)
end

-- for testing in Studio: force the next wave now
function AnimalManager.ForceWave()
	wave()
end

return AnimalManager
