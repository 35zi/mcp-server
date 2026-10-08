-- AnimalManager (ModuleScript in ServerScriptService; started by the AnimalSpawner Script)
--
-- Spawns, moves and damages the huntable animals. Everything is server-side; clients only add effects
-- (AnimalClient: dust puffs, squeaks, popups) and the weapon code (WeaponCombatService) calls Damage().
--
--   Animals:     ReplicatedStorage.AnimalData (which world each species lives in, rarity, stats)
--   Templates:   ServerStorage.AnimalTemplates.<Species>  (Models, PrimaryPart = Body / <Species>_Body, front = -Z)
--   Spawn zones: every Part in Workspace.AnimalSpawnZones (invisible boxes; move/resize them in Studio).
--                Attribute World = which world's animals spawn there (default 1); Population = most alive at once (default 5)
--   Decor:       Workspace.Decor (trees, rocks...): animals spawn away from it, walk around it, never stand on it
--   Live:        Workspace.Animals (Models with attributes Species, Rarity, World, Size, Mutation, Health, MaxHealth,
--                Hop, Land)
--
-- Waves: one at server start, then every WAVE_INTERVAL seconds. Animals that survived MAX_AGE_WAVES waves are
-- replaced, then every zone is topped back up to its Population.
-- Species: picked by rarity inside the zone's world (Common is almost guaranteed, Legendary is rare).
-- Sizes: each spawn rolls Small / Medium / Large (scale, HP and value change with it).
-- Mutations (rare): Gold = gold tint + sparkles + outline + 5x value; Silver = silver tint + 30% more HP.
-- Shooting it down: when Health reaches 0 the animal is STUNNED (not dead); AnimalCarry takes over (pick up, carry
-- over the red line, then it goes into the inventory). If nobody does that in time it wakes up: Revive() makes it a
-- live animal again with full health. Stunned animals still count towards their zone's Population. No money here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local AnimalCarry = require(script.Parent:WaitForChild("AnimalCarry"))

local AnimalManager = {}

---------------------------------------------------------------- tuning
local WAVE_INTERVAL = 300 -- seconds (5 minutes)
local DEFAULT_POPULATION = 5 -- most animals alive per zone (= per world) (zone attribute Population overrides)
local DEFAULT_MIN_POPULATION = 2 -- each wave picks a random target between this (zone attribute MinPopulation) and the max
local MAX_AGE_WAVES = 2 -- an animal is replaced after surviving this many waves
local MIN_SPACING = 7 -- studs between spawned animals
local ZONE_MARGIN = 3 -- keep animals this far inside a zone's edges

local SPECIES = AnimalData.Species
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
	local list = { animalsFolder, zonesFolder, AnimalCarry.Folder() }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- the floor below (decorations like trees and rocks are ignored, so animals never end up standing on them)
local function groundAt(x, z, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = excludeList()
	local decor = workspace:FindFirstChild("Decor")
	if decor then
		table.insert(list, decor)
	end
	params.FilterDescendantsInstances = list
	local result = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -200, 0), params)
	return result and result.Position.Y or nil
end

-- is a decoration (Workspace.Decor) within radius of this spot? (animals don't spawn inside trees)
local function nearDecor(position, radius)
	local decor = workspace:FindFirstChild("Decor")
	if not decor then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { decor }
	return #workspace:GetPartBoundsInRadius(position + Vector3.new(0, 2, 0), radius, params) > 0
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

local function randomPoint(zone)
	local hx, hz = zoneBounds(zone)
	local world = zone.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-hx, hx), 0, rng:NextNumber(-hz, hz)))
	local top = zone.Position.Y + zone.Size.Y / 2 + 20
	local y = groundAt(world.X, world.Z, top)
	if not y or nearDecor(Vector3.new(world.X, y, world.Z), 4) then
		return nil
	end
	return Vector3.new(world.X, y, world.Z)
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

-- a species from this world, picked by rarity (only species that have a template)
local function rollSpecies(worldId)
	local available = {}
	for _, world in ipairs(AnimalData.Worlds) do
		if world.id == worldId then
			for _, name in ipairs(world.species) do
				if SPECIES[name] and templates:FindFirstChild(name) then
					table.insert(available, name)
				end
			end
		end
	end
	if #available == 0 then
		return nil
	end
	-- a rarity tier keeps its overall chance however many species share it (two Legendaries split it)
	local tierCount = {}
	for _, name in ipairs(available) do
		local r = SPECIES[name].rarity
		tierCount[r] = (tierCount[r] or 0) + 1
	end
	return pickWeighted(available, function(name)
		local r = SPECIES[name].rarity
		return AnimalData.Rarities[r].weight / tierCount[r]
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
	gui.Size = UDim2.fromOffset(140, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, record.height * 0.75 + 1.4, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = body

	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui

	-- (the rarity is deliberately NOT shown over animals - you find out when you catch them)
	if record.mutation ~= "None" then
		local l = Instance.new("TextLabel")
		l.Name = "Mutation"
		l.LayoutOrder = 2
		l.Size = UDim2.new(1, 0, 0, 24)
		l.BackgroundTransparency = 1
		l.Text = string.upper(record.mutation)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = MUTATIONS[record.mutation].tint
		l.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(24, 18, 28)
		stroke.Parent = l
	end

	local slot = Instance.new("Frame")
	slot.Name = "HealthSlot"
	slot.LayoutOrder = 3
	slot.Size = UDim2.new(1, 0, 0, 14)
	slot.BackgroundTransparency = 1
	slot.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "HealthBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, 0)
	bar.Size = UDim2.fromOffset(92, 12)
	bar.BackgroundColor3 = Color3.fromRGB(40, 34, 46)
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = slot
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Thickness = 2.5
	barStroke.Color = Color3.fromRGB(24, 18, 28)
	barStroke.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	shine.Rotation = 90
	shine.Parent = fill
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

---------------------------------------------------------------- building a model
local function sizeByName(name)
	for _, s in ipairs(SIZES) do
		if s.name == name then
			return s
		end
	end
	return SIZES[2]
end

-- a dressed copy of a species' template (anchored, no scripts, sized, mutation look); nil if there is no template
function AnimalManager.BuildModel(species, sizeName, mutation)
	local template = templates:FindFirstChild(species)
	if not template then
		return nil
	end
	local model = template:Clone()
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
	local size = sizeByName(sizeName)
	if size.scale ~= 1 then
		-- relative to the template's own scale (imported meshes are stored at e.g. 0.017, not 1)
		model:ScaleTo(model:GetScale() * size.scale)
	end
	applyMutationLook(model, mutation or "None")
	model.Name = species
	return model
end

-- every part with its offset from the model's root frame: bottom centre, facing the front (Body -Z), yaw only.
-- The bounds are measured from the parts' corners (GetBoundingBox follows the model pivot, which imported meshes
-- often have turned on its side). Returns parts, offsets, size (X = width, Y = height, Z = length).
local CORNERS = {}
for _, x in ipairs({ -0.5, 0.5 }) do
	for _, y in ipairs({ -0.5, 0.5 }) do
		for _, z in ipairs({ -0.5, 0.5 }) do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

function AnimalManager.RootOffsets(model)
	local look = model.PrimaryPart.CFrame.LookVector
	local frame = CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			for _, c in ipairs(CORNERS) do
				local p = frame:PointToObjectSpace(d.CFrame * (c * d.Size))
				low = low:Min(p)
				high = high:Max(p)
			end
		end
	end
	local bottom = frame:PointToWorldSpace(Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2))
	local root0 = CFrame.new(bottom) * frame
	local offsets = table.create(#parts)
	for i, d in ipairs(parts) do
		offsets[i] = root0:ToObjectSpace(d.CFrame)
	end
	return parts, offsets, high - low
end

---------------------------------------------------------------- spawning
local function spawnOne(zone)
	local worldId = zone:GetAttribute("World") or 1
	local species = rollSpecies(worldId)
	if not species then
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
	local model = AnimalManager.BuildModel(species, size.name, mutation)
	local parts, offsets, boxSize = AnimalManager.RootOffsets(model)

	nextId += 1
	local maxHealth = math.max(1, math.floor(cfg.hp * size.hp * (MUTATIONS[mutation] and MUTATIONS[mutation].hp or 1) + 0.5))
	local value = math.floor(cfg.value * size.value * (MUTATIONS[mutation] and MUTATIONS[mutation].value or 1) + 0.5)
	model:SetAttribute("AnimalId", nextId)
	model:SetAttribute("Species", species)
	model:SetAttribute("Rarity", cfg.rarity)
	model:SetAttribute("World", worldId)
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
		worldId = worldId,
		parts = parts,
		offsets = offsets,
		height = boxSize.Y,
		width = boxSize.X,
		length = boxSize.Z,
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
	if mutation ~= "None" or AnimalData.ShouldAnnounce(cfg.rarity) then
		animalEvent:FireAllClients("Mutation", { species = species, mutation = mutation, rarity = cfg.rarity, size = size.name, world = worldId })
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
	for _, zone in ipairs(zonesFolder:GetChildren()) do
		if zone:IsA("BasePart") then
			local alive = AnimalCarry.CountForZone(zone) -- stunned ones will wake up again
			for _, record in pairs(records) do
				if record.zone == zone then
					alive += 1
				end
			end
			-- this wave's random size for this world (2..5 by default), never above the max
			local max = zone:GetAttribute("Population") or DEFAULT_POPULATION
			local min = math.min(zone:GetAttribute("MinPopulation") or DEFAULT_MIN_POPULATION, max)
			local target = rng:NextInteger(min, max)
			zone:SetAttribute("WaveTarget", target)
			for _ = alive + 1, target do
				spawnOne(zone)
			end
		end
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
	if not insideZone(record.zone, record.pos) then
		-- outside its home (it woke up where it was dropped): hop straight back into its zone
		local p = record.zone.CFrame:PointToObjectSpace(record.pos)
		local hx, hz = zoneBounds(record.zone)
		local inside = record.zone.CFrame:PointToWorldSpace(Vector3.new(math.clamp(p.X, -hx + 2, hx - 2), 0, math.clamp(p.Z, -hz + 2, hz - 2)))
		local delta = Vector3.new(inside.X - record.pos.X, 0, inside.Z - record.pos.Z)
		record.hopsLeft = math.max(1, math.ceil(delta.Magnitude / (cfg.hopDist * scale)))
		record.step = delta / record.hopsLeft
		record.targetYaw = math.atan2(-delta.X, -delta.Z)
		record.state, record.stateT = "turn", 0
		record.fleeing = true
		return
	end
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

local function beginHop(record)
	record.state, record.stateT = "hop", 0
	record.hopFrom = record.pos
	record.hopTo = record.pos + record.step
	local y = groundAt(record.hopTo.X, record.hopTo.Z, record.hopTo.Y + 10)
	if y then
		record.hopTo = Vector3.new(record.hopTo.X, y, record.hopTo.Z)
	end
	record.hops += 1
	if not record.cfg.walk then
		record.model:SetAttribute("Hop", record.hops)
	end
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

	local yOff, pitch = 0, 0
	if record.state == "idle" then
		yOff = 0.04 * scale * math.sin(record.clock * 2.6)
		if record.stateT >= record.idleDur then
			startWander(record)
		end
	elseif record.state == "turn" then
		if math.abs(angleDiff(record.yaw, record.targetYaw)) < 0.06 or record.stateT > 0.5 then
			beginHop(record)
		end
	elseif record.state == "hop" then
		local p = math.min(record.stateT / hopTime, 1)
		record.pos = record.hopFrom:Lerp(record.hopTo, p)
		yOff = cfg.hopHeight * scale * 4 * p * (1 - p)
		pitch = cfg.walk and 0 or 0.3 * math.cos(math.pi * p)
		if p >= 1 then
			record.pos = record.hopTo
			record.hopsLeft -= 1
			record.state, record.stateT = "land", 0
			if not cfg.walk then
				record.model:SetAttribute("Land", record.hops)
			end
		end
	elseif record.state == "land" then
		local landTime = cfg.walk and 0.04 or 0.16
		local q = math.min(record.stateT / landTime, 1)
		yOff = cfg.walk and 0 or -0.12 * scale * math.sin(math.pi * q)
		if q >= 1 then
			if record.hopsLeft > 0 then
				beginHop(record)
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
-- the live animal a part belongs to (or nil)
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

-- damage an animal; returns "hit" or "killed" ("killed" = shot down: it is now stunned, see AnimalCarry)
function AnimalManager.Damage(record, amount, player, hitPos)
	if record.dead then
		return "none"
	end
	record.health = math.max(0, record.health - amount)
	record.model:SetAttribute("Health", record.health)
	animalEvent:FireAllClients("Hit", { model = record.model, position = hitPos, scale = record.size.scale })

	if record.health <= 0 then
		-- it drops stunned where it stands; the shooter has to pick it up and carry it home (AnimalCarry)
		records[record.model] = nil
		record.dead = true
		local tag = record.model.PrimaryPart and record.model.PrimaryPart:FindFirstChild("AnimalTag")
		if tag then
			tag:Destroy()
		end
		AnimalCarry.AddBody(record.model, {
			species = record.species,
			rarity = record.cfg.rarity,
			world = record.worldId,
			size = record.size.name,
			mutation = record.mutation,
			value = record.value,
			parts = record.parts,
			offsets = record.offsets,
			height = record.height,
			width = record.width,
			length = record.length,
			pos = record.pos,
			yaw = record.yaw,
			zone = record.zone,
			maxHealth = record.maxHealth,
		}, player)
		return "killed"
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

-- AnimalCarry: a stunned animal nobody carried home woke up at `position`; it becomes a live animal again (full
-- health, back in its own zone) and runs away from whoever is closest
function AnimalManager.Revive(model, info, position)
	local zone = info.zone
	if not (zone and zone.Parent) then
		for _, z in ipairs(zonesFolder:GetChildren()) do
			if z:IsA("BasePart") and (z:GetAttribute("World") or 1) == info.world then
				zone = z
				break
			end
		end
	end
	local cfg = SPECIES[info.species]
	if not zone or not cfg or not model.Parent then
		model:Destroy()
		return
	end
	for _, p in ipairs(info.parts) do
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = true
		p.Massless = false
	end
	local maxHealth = info.maxHealth or cfg.hp
	model:SetAttribute("Health", maxHealth)
	local record = {
		model = model,
		species = info.species,
		cfg = cfg,
		size = sizeByName(info.size),
		mutation = info.mutation,
		zone = zone,
		worldId = info.world,
		parts = info.parts,
		offsets = info.offsets,
		height = info.height,
		width = info.width,
		length = info.length,
		pos = position,
		yaw = info.yaw,
		targetYaw = info.yaw,
		state = "idle",
		stateT = 0,
		idleDur = 0.2,
		hopsLeft = 0,
		step = Vector3.zero,
		hopFrom = position,
		hopTo = position,
		hops = 0,
		health = maxHealth,
		maxHealth = maxHealth,
		value = info.value,
		wave = waveNumber,
		clock = rng:NextNumber(0, 10),
	}
	makeTag(record)
	records[model] = record
	model.Parent = animalsFolder
	local nearest, best = nil, 40
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude < best then
			nearest, best = root.Position, (root.Position - position).Magnitude
		end
	end
	startWander(record, nearest)
end
AnimalCarry.OnRevive(AnimalManager.Revive)

return AnimalManager
