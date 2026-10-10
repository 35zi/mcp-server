-- AnimalClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Client-side polish for the huntable animals (the server, AnimalManager, owns the animals themselves):
--   * a small dust puff + a couple of leaf flicks under an animal every time it takes off or lands
--   * when an animal is hit: a quick white flash on it and a squeak
--   * when an animal is brought home or despawns: a poof (gold sparkles for gold ones)
--   * "<animal> STUNNED!" hint for the shooter, then "CAUGHT!" popup + cash-register sound once it's carried over the
--     red line (AnimalCarry); stunned animals show wobbling stars and a countdown until they wake up
--   * pick-up prompts on dead animals and plot animals only show for their owner
--   * a banner for everyone when a Legendary or a Gold / Silver animal appears; a SECRET one (the Yeti) gets a big
--     rainbow banner and a line in the chat so the whole server goes after it
--   * a thump when an aggressive animal (Yeti) punches someone
--   * a small HUD (bottom left): time until the next wave, animals in your bag + plot income, your Cash
--   * anyone carrying an animal (player attribute Carrying): their right arm is raised, holding it on the shoulder
-- Look: ReplicatedStorage.UIStyle.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")

local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local make, text = UIStyle.make, UIStyle.text

local player = Players.LocalPlayer
local animalEvent = ReplicatedStorage:WaitForChild("AnimalEvent")
local audio = ReplicatedStorage:WaitForChild("GameAudio")
local animalsFolder = workspace:WaitForChild("Animals")
local previews = ReplicatedStorage:WaitForChild("AnimalPreviews", 10)
local rng = Random.new()

local GOLD = Color3.fromRGB(255, 205, 50)
local SILVER = Color3.fromRGB(205, 215, 230)
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

---------------------------------------------------------------- HUD: animals in your bag + wave timer (bottom left), banners, popup
-- same coordinate space as GameUI, so banners can line up under its top buttons
local gui = make("ScreenGui", { Name = "AnimalEffects", ResetOnSpawn = false, DisplayOrder = 4, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, Parent = player:WaitForChild("PlayerGui") })
task.spawn(function() -- hide while the full-screen Weapon Shop view is open
	local shopGui = player.PlayerGui:WaitForChild("WeaponShopUI", 60)
	if shopGui then
		local function sync()
			gui.Enabled = not shopGui.Enabled
		end
		shopGui:GetPropertyChangedSignal("Enabled"):Connect(sync)
		sync()
	end
end)
-- Banners stack under the top travel buttons (newest at the bottom, at most 3) instead of piling up on them,
-- and step below GameFeedback's toast while one is showing.
local MAX_BANNERS = 3
local bannerStack = make("Frame", {
	Name = "Banners",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 100),
	Size = UDim2.new(1, -40, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = gui,
})
make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 2),
	Parent = bannerStack,
})
local function placeBanners()
	local gameUI = player.PlayerGui:FindFirstChild("GameUI")
	local top = gameUI and gameUI:FindFirstChild("TopButtons")
	local bottom = -math.huge
	if top then
		for _, button in ipairs(top:GetChildren()) do
			if button:IsA("GuiObject") and button.Visible then
				bottom = math.max(bottom, button.AbsolutePosition.Y + button.AbsoluteSize.Y)
			end
		end
	end
	local feedback = player.PlayerGui:FindFirstChild("GameFeedback")
	local toast = feedback and feedback:FindFirstChild("FeedbackToast")
	if toast then
		bottom = math.max(bottom, toast.AbsolutePosition.Y + toast.AbsoluteSize.Y)
	end
	-- AbsolutePosition is measured below the Roblox top bar; convert to this ScreenGui's own space
	local goal = UDim2.new(0.5, 0, 0, bottom > -math.huge and bottom - gui.AbsolutePosition.Y + 8 or 100)
	TweenService:Create(bannerStack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = goal }):Play()
end
player.PlayerGui.DescendantAdded:Connect(function(node)
	if node.Name == "FeedbackToast" then
		task.defer(placeBanners)
	end
end)
player.PlayerGui.DescendantRemoving:Connect(function(node)
	if node.Name == "FeedbackToast" then
		task.defer(placeBanners)
	end
end)
local bannerOrder = 0
local function banner(message, color, duration)
	placeBanners()
	bannerOrder += 1
	local slot = make("Frame", {
		Name = "Banner",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = bannerOrder,
		Parent = bannerStack,
	})
	-- long announcements (rare spawns) outlive short notices when the stack is full
	slot:SetAttribute("Keep", (duration or 3.5) >= 6)
	local label = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, -0.8),
		Size = UDim2.fromScale(1, 1),
		Text = message,
		TextScaled = true,
		Stroke = 3,
		TextColor3 = color,
		Parent = slot,
	})
	make("UITextSizeConstraint", { MinTextSize = 14, MaxTextSize = 36, Parent = label })
	local slots = {}
	for _, child in ipairs(bannerStack:GetChildren()) do
		if child.Name == "Banner" then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	local extra = #slots - MAX_BANNERS
	for _, old in ipairs(slots) do
		if extra <= 0 then
			break
		end
		if old ~= slot and not old:GetAttribute("Keep") then
			old:Destroy()
			extra -= 1
		end
	end
	for _, old in ipairs(slots) do
		if extra <= 0 then
			break
		end
		if old.Parent and old ~= slot then
			old:Destroy()
			extra -= 1
		end
	end
	local stroke = label:FindFirstChildOfClass("UIStroke")
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	task.delay(duration or 3.5, function()
		if not slot.Parent then
			return
		end
		local info = TweenInfo.new(0.5)
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		local fade = TweenService:Create(stroke, info, { Transparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		slot:Destroy()
	end)
	return label
end

-- a line in the chat window (RBXGeneral) for this client, coloured
local function systemChat(message, hex)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(string.format('<font color="%s"><b>%s</b></font>', hex, message))
		end
	end)
end

local function worldName(id)
	for _, w in ipairs(AnimalData.Worlds) do
		if w.id == id then
			return "the " .. w.name .. " World"
		end
	end
	return "World " .. tostring(id or 1)
end

local popupToken = 0
local function caughtPopup(data)
	popupToken += 1
	local token = popupToken
	local old = gui:FindFirstChild("Caught")
	if old then
		old:Destroy()
	end
	local rarity = data.rarity or "Common"
	local nameColor = data.mutation == "Gold" and GOLD or data.mutation == "Silver" and SILVER or WHITE
	local frame = make("Frame", {
		Name = "Caught",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42), -- below the banner stack
		Size = UDim2.fromOffset(500, 156),
		BackgroundColor3 = WHITE,
		Parent = gui,
	})
	UIStyle.corner(frame, 18)
	UIStyle.stroke(frame, 4)
	UIStyle.gradient(frame, UIStyle.rarityGradient(rarity), (rarity == "Legendary" or rarity == "Secret") and 0 or 90)
	local vp = UIStyle.picture({ Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(126, 126), Parent = frame })
	UIStyle.showModel(vp, previews and previews:FindFirstChild(data.species))
	text({
		Position = UDim2.fromOffset(154, 4),
		Size = UDim2.new(1, -164, 0, 60),
		Text = "CAUGHT!",
		TextSize = 52,
		Stroke = 4.5,
		Rotation = -3,
		TextColor3 = UIStyle.Colors.Yellow,
		Parent = frame,
	})
	text({
		Position = UDim2.fromOffset(154, 66),
		Size = UDim2.new(1, -164, 0, 36),
		Text = AnimalData.DisplayName(data.species, data.weight or data.size, data.mutation),
		TextSize = 30,
		TextColor3 = nameColor,
		Parent = frame,
	})
	text({
		Position = UDim2.fromOffset(154, 106),
		Size = UDim2.new(1, -164, 0, 30),
		Text = string.format("%s  •  added to your Bag", string.upper(rarity)),
		TextSize = 20,
		Parent = frame,
	})
	if data.firstTime then
		local new = UIStyle.pill({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -8, 0, 6),
			Size = UDim2.fromOffset(84, 34),
			Text = "NEW!",
			TextSize = 22,
			Color = UIStyle.Colors.Red,
			Parent = frame,
		})
		new.Rotation = 12
	end
	local scale = UIStyle.pop(frame)
	task.delay(2.6, function()
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
		playSound("Catch", nil, 1, (data.mutation == "Gold" or data.rarity == "Legendary" or data.rarity == "Secret") and 1.2 or 1)
	elseif kind == "Killed" then
		banner(string.format("💫 %s STUNNED! Grab it (E) before it wakes up!", string.upper(AnimalData.DisplayName(data.species, data.weight or data.size, data.mutation))), WHITE, 3)
	elseif kind == "Notice" then
		-- refusals ("too heavy", "can't") already get FeedbackClient's red toast; don't show them twice
		local lower = string.lower(data.text or "")
		if not (lower:find("too heavy", 1, true) or lower:find("can't", 1, true) or lower:find("cannot", 1, true)) then
			banner(data.text, WHITE, 2.5)
		end
	elseif kind == "Mutation" then
		-- a mutation, or a rarity above AnimalData.AnnounceAbove (Legendary), arrived with the wave
		local parts = {}
		local special = AnimalData.ShouldAnnounce(data.rarity)
		if special then
			table.insert(parts, string.upper(data.rarity))
		end
		if data.mutation and data.mutation ~= "None" then
			table.insert(parts, string.upper(data.mutation))
		end
		table.insert(parts, string.upper(AnimalData.PrettyName(data.species)))
		local rarity = AnimalData.Rarities[data.rarity]
		local color = special and rarity and rarity.color or data.mutation == "Gold" and GOLD or data.mutation == "Silver" and SILVER or WHITE
		if data.rarity == "Secret" then
			-- the big one: a rainbow banner for everyone + a line in the chat
			local name = string.upper(AnimalData.DisplayName(data.species, nil, data.mutation))
			local message = string.format("🌈 A SECRET %s HAS SPAWNED IN %s! GO GET IT! 🌈", name, string.upper(worldName(data.world)))
			UIStyle.rainbow(banner(message, WHITE, 9))
			playSound("Catch", nil, 0.6, 1.5)
			systemChat(message, "#ff78dc")
		else
			banner(string.format("%sA %s appeared in %s!", special and "🌟 " or "", table.concat(parts, " "), worldName(data.world)), color, special and 6 or 4)
			if special then
				playSound("Catch", nil, 0.8, 1.2)
			end
		end
	elseif kind == "Punch" then
		-- an aggressive animal (Yeti) punched someone
		playSound("Impact", data.position, 0.6, 1.4)
		holder.Position = data.position
		poof:Emit(10)
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

---------------------------------------------------------------- one consistent card for live and toppled animals
local Overhead=require(ReplicatedStorage:WaitForChild("AnimalOverheadUI"))
local overheadTags={}
task.spawn(function()
 local bodies=workspace:WaitForChild("AnimalBodies")
 local function track(model)
  if not model:IsA("Model") or overheadTags[model] then return end
  if not model.PrimaryPart then task.wait(.1) end
  if model.Parent~=animalsFolder and model.Parent~=bodies then return end
  local tag=Overhead.Create(model,player.PlayerGui)
  if tag then overheadTags[model]=tag end
 end
 animalsFolder.ChildAdded:Connect(track);bodies.ChildAdded:Connect(track)
 for _,folder in {animalsFolder,bodies} do for _,model in folder:GetChildren() do track(model) end end
 local nextUpdate=0
 RunService.RenderStepped:Connect(function()
  local now=workspace:GetServerTimeNow()
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local refresh=now>=nextUpdate;if refresh then nextUpdate=now+.1 end
  for model,tag in pairs(overheadTags) do
   if (model.Parent~=animalsFolder and model.Parent~=bodies) or not model.PrimaryPart then
    Overhead.Destroy(tag);overheadTags[model]=nil
   else
    local distance=root and (model.PrimaryPart.Position-root.Position).Magnitude or math.huge
    if refresh then
     tag.gui.Enabled=distance<100 and model:GetAttribute("Dragging")~=true
     if tag.gui.Enabled then Overhead.Update(model,tag,distance<42,now) end
    end
    if tag.gui.Enabled then Overhead.Anchor(model,tag) end
   end
  end
 end)
end)

---------------------------------------------------------------- carriers: the right arm holds the animal on the shoulder
-- Anyone carrying (player attribute Carrying, set by AnimalCarry) gets their right arm posed right after the
-- animations run (PreSimulation), every frame, for every carrier we can see: upper arm raised up and forward, elbow
-- bent back so the hand grips the animal's hind end on top of the shoulder. Works for Motor6D joints and for the
-- newer AnimationConstraint joints (both have a Transform the animations write).
local ARM_POSE = {
	{ "RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(-22), 0, math.rad(-18)) },
	{ "RightLowerArm", "RightElbow", CFrame.Angles(math.rad(22), 0, 0) },
	{ "RightHand", "RightWrist", CFrame.identity },
	{ "Torso", "Right Shoulder", CFrame.Angles(0, 0, math.rad(-25)) }, -- R6
}
RunService.PreSimulation:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if character and p:GetAttribute("Dragging") then
			for _, joint in ipairs(ARM_POSE) do
				local holder = character:FindFirstChild(joint[1])
				local j = holder and holder:FindFirstChild(joint[2])
				if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
					j.Transform = joint[3]
				end
			end
		end
	end
end)
