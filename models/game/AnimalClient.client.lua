-- AnimalClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Client-side polish for the huntable animals (the server, AnimalManager, owns the animals themselves):
--   * a small dust puff + a couple of leaf flicks under an animal every time it takes off or lands
--   * when an animal is hit: a quick white flash on it and a squeak
--   * when an animal is brought home or despawns: a poof (gold sparkles for gold ones)
--   * "<animal> down!" hint for the shooter, then "CAUGHT!" popup + cash-register sound once it's carried over the
--     red line (AnimalCarry)
--   * pick-up prompts on dead animals and plot animals only show for their owner
--   * a banner for everyone when a Legendary or a Gold / Silver animal appears
--   * a small HUD: animals in your bag + time until the next wave
local AnimalData = require(game:GetService("ReplicatedStorage"):WaitForChild("AnimalData"))
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local animalEvent = ReplicatedStorage:WaitForChild("AnimalEvent")
local audio = ReplicatedStorage:WaitForChild("GameAudio")
local animalsFolder = workspace:WaitForChild("Animals")
local rng = Random.new()

local GOLD = Color3.fromRGB(255, 205, 50)
local SILVER = Color3.fromRGB(205, 215, 230)
local DARK = Color3.fromRGB(43, 29, 20)
local BLACK = Color3.fromRGB(20, 20, 24)
local WHITE = Color3.new(1, 1, 1)

---------------------------------------------------------------- sounds
local function playSound(name, at, pitch, volume)
	local template = audio:FindFirstChild(name)
	if not template then
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed *= pitch or 1
	sound.Volume *= volume or 1
	if typeof(at) == "Vector3" then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Position = at
		holder.Parent = workspace
		sound.Parent = holder
		Debris:AddItem(holder, 4)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 4)
	end
	sound:Play()
end

---------------------------------------------------------------- particles (one reusable emitter holder)
local holder = Instance.new("Part")
holder.Name = "AnimalFx"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.new(0.1, 0.1, 0.1)
holder.Parent = workspace
local attachment = Instance.new("Attachment")
attachment.Parent = holder

local function newEmitter(props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = attachment
	return e
end
local dust = newEmitter({
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(190, 165, 120)),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.4, 0.7),
	Speed = NumberRange.new(1.5, 3),
	SpreadAngle = Vector2.new(80, 80),
	EmissionDirection = Enum.NormalId.Top,
	Drag = 4,
	Acceleration = Vector3.new(0, -1, 0),
})
local leaves = newEmitter({
	Texture = "rbxasset://textures/particles/SquareParticle.png",
	Color = ColorSequence.new(Color3.fromRGB(70, 170, 60), Color3.fromRGB(150, 210, 70)),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.6, 0.9),
	Speed = NumberRange.new(3, 5),
	SpreadAngle = Vector2.new(60, 60),
	EmissionDirection = Enum.NormalId.Top,
	Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-300, 300),
	Acceleration = Vector3.new(0, -12, 0),
})
local poof = newEmitter({
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(245, 245, 245)),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(0.5, 0.9),
	Speed = NumberRange.new(4, 7),
	SpreadAngle = Vector2.new(180, 180),
	Drag = 5,
})
local sparkle = newEmitter({
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	LightEmission = 1,
	Lifetime = NumberRange.new(0.6, 1.2),
	Speed = NumberRange.new(5, 10),
	SpreadAngle = Vector2.new(180, 180),
	Drag = 2,
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
})

local function feetOf(model)
	local cf, size = model:GetBoundingBox()
	return cf.Position - Vector3.new(0, size.Y / 2, 0)
end

local MEADOW_DUST = ColorSequence.new(Color3.fromRGB(190, 165, 120))
local DESERT_DUST = ColorSequence.new(Color3.fromRGB(226, 196, 120))

local function puff(model, strength)
	if not model.Parent then
		return
	end
	local scale = model:GetAttribute("Scale") or 1
	local desert = model:GetAttribute("World") == 2
	holder.Position = feetOf(model) + Vector3.new(0, 0.2, 0)
	dust.Color = desert and DESERT_DUST or MEADOW_DUST
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * scale), NumberSequenceKeypoint.new(1, 1.3 * scale) })
	leaves.Size = NumberSequence.new(0.14 * scale)
	dust:Emit(math.floor(5 * strength + 0.5))
	if not desert and rng:NextNumber() < 0.6 then
		leaves:Emit(math.max(1, math.floor(2 * strength + 0.5)))
	end
end

local function watchAnimal(model)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Land"):Connect(function()
		puff(model, 1)
	end)
	model:GetAttributeChangedSignal("Hop"):Connect(function()
		puff(model, 0.5)
	end)
end
animalsFolder.ChildAdded:Connect(watchAnimal)
for _, model in ipairs(animalsFolder:GetChildren()) do
	watchAnimal(model)
end

---------------------------------------------------------------- HUD: bag counter, wave timer, banners, popup
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

local gui = make("ScreenGui", { Name = "AnimalHud", ResetOnSpawn = false, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
local bag = make("Frame", {
	Name = "Bag",
	Position = UDim2.new(0, 16, 0, 64),
	Size = UDim2.fromOffset(190, 64),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Parent = gui,
})
make("UICorner", { CornerRadius = UDim.new(0, 12), Parent = bag })
make("UIStroke", { Color = GOLD, Thickness = 2, Parent = bag })
local bagCount = make("TextLabel", {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 28),
	BackgroundTransparency = 1,
	Text = "Animals: 0",
	Font = Enum.Font.GothamBlack,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = WHITE,
	Parent = bag,
})
local waveLabel = make("TextLabel", {
	Position = UDim2.fromOffset(12, 34),
	Size = UDim2.new(1, -24, 0, 22),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(232, 213, 192),
	Parent = bag,
})
local function updateBag()
	bagCount.Text = "Animals: " .. tostring(player:GetAttribute("AnimalCount") or 0)
end
player:GetAttributeChangedSignal("AnimalCount"):Connect(updateBag)
updateBag()
task.spawn(function()
	while true do
		local nextAt = animalsFolder:GetAttribute("NextWaveAt")
		if nextAt then
			local left = math.max(0, nextAt - os.time())
			waveLabel.Text = string.format("New animals in %d:%02d", left // 60, left % 60)
		end
		task.wait(0.5)
	end
end)

local function banner(text, color, duration)
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -60),
		Size = UDim2.fromOffset(640, 48),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = color,
		Parent = gui,
	})
	make("UIStroke", { Color = BLACK, Thickness = 3, Parent = label })
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 96) }):Play()
	task.delay(duration or 3.5, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

local popupToken = 0
local function caughtPopup(data)
	popupToken += 1
	local token = popupToken
	local old = gui:FindFirstChild("Caught")
	if old then
		old:Destroy()
	end
	local rarity = AnimalData.Rarities[data.rarity] or AnimalData.Rarities.Common
	local mutationColor = data.mutation == "Gold" and GOLD or data.mutation == "Silver" and SILVER or rarity.color
	local frame = make("Frame", {
		Name = "Caught",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(500, 116),
		BackgroundColor3 = DARK,
		Parent = gui,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 16), Parent = frame })
	make("UIStroke", { Color = mutationColor == WHITE and GOLD or mutationColor, Thickness = 3, Parent = frame })
	local scale = make("UIScale", { Scale = 0.6, Parent = frame })
	local title = make("TextLabel", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Text = "CAUGHT!",
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = GOLD,
		Parent = frame,
	})
	make("UIStroke", { Color = BLACK, Thickness = 2, Parent = title })
	local name = AnimalData.DisplayName(data.species, data.size, data.mutation)
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = mutationColor,
		Parent = frame,
	})
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = string.format("%s  •  added to your inventory%s", string.upper(data.rarity or "Common"), data.firstTime and "  •  NEW in your Index!" or ""),
		Font = Enum.Font.GothamMedium,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(232, 213, 192),
		Parent = frame,
	})
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.4, function()
		if token ~= popupToken or not frame.Parent then
			return
		end
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.01 }):Play()
		task.wait(0.27)
		frame:Destroy()
	end)
end

---------------------------------------------------------------- server events
animalEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "Hit" then
		local model = data.model
		if model and model.Parent then
			local flash = Instance.new("Highlight")
			flash.FillColor = WHITE
			flash.FillTransparency = 0.25
			flash.OutlineTransparency = 1
			flash.DepthMode = Enum.HighlightDepthMode.Occluded
			flash.Parent = model
			Debris:AddItem(flash, 0.12)
		end
		local scale = data.scale or 1
		playSound("Squeak", data.position, rng:NextNumber(1.05, 1.3) / math.sqrt(scale), 0.8)
	elseif kind == "Caught" or kind == "Despawn" then
		holder.Position = data.position
		local scale = data.scale or 1
		poof.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * scale), NumberSequenceKeypoint.new(1, 2.4 * scale) })
		poof:Emit(kind == "Caught" and 14 or 8)
		if data.mutation == "Gold" or data.mutation == "Silver" then
			sparkle.Color = ColorSequence.new(data.mutation == "Gold" and GOLD or SILVER)
			sparkle:Emit(24)
		end
	elseif kind == "Delivered" then
		caughtPopup(data)
		playSound("Catch", nil, 1, (data.mutation == "Gold" or data.rarity == "Legendary") and 1.2 or 1)
	elseif kind == "Killed" then
		banner(string.format("%s down! Pick it up (E)", string.upper(AnimalData.DisplayName(data.species, data.size, data.mutation))), WHITE, 3)
	elseif kind == "Notice" then
		banner(data.text, WHITE, 2.5)
	elseif kind == "Mutation" then
		local parts = {}
		if data.rarity == "Legendary" then
			table.insert(parts, "LEGENDARY")
		end
		if data.mutation and data.mutation ~= "None" then
			table.insert(parts, string.upper(data.mutation))
		end
		table.insert(parts, string.upper(data.species))
		local color = data.mutation == "Gold" and GOLD or data.mutation == "Silver" and SILVER or AnimalData.Rarities.Legendary.color
		banner(string.format("A %s appeared in World %d!", table.concat(parts, " "), data.world or 1), color, 4)
	end
end)

---------------------------------------------------------------- owner-only prompts (dead animals, plot animals)
local function ownerOf(prompt)
	local node = prompt.Parent
	while node and node ~= workspace do
		local owner = node:GetAttribute("OwnerUserId")
		if owner then
			return owner
		end
		node = node.Parent
	end
	return nil
end

local function filterPrompt(prompt)
	if prompt:IsA("ProximityPrompt") then
		local owner = ownerOf(prompt)
		if owner and owner ~= player.UserId then
			prompt.Enabled = false
		end
	end
end

for _, name in ipairs({ "AnimalBodies", "PlotAnimals" }) do
	task.spawn(function()
		local folder = workspace:WaitForChild(name)
		folder.DescendantAdded:Connect(filterPrompt)
		for _, d in ipairs(folder:GetDescendants()) do
			filterPrompt(d)
		end
	end)
end
