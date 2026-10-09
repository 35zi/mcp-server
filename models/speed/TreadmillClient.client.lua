-- TreadmillClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Draws every plot's treadmill on this client. The server only has the invisible Workspace.Treadmills.<Plot>.Spot
-- (BuildTreadmills); what you see is built here, in Workspace.LocalTreadmills:
--   * your own (in front of your pen): always there and solid, in the look of your tier (Robot, Storm, Ice, Portal,
--     Volcano, Candy: a new Blender-made model on every upgrade), with a small upgrade panel: level now > next, Speed per second
--     now > next and a price button (SpeedRemote "UpgradeTreadmill")
--   * someone else's plot: only while its owner trains on it (their OnTreadmill attribute), and not solid for you
-- Standing on your belt runs you in place: the belt is a conveyor only on your screen and your character keeps
-- running forward until you press a move key or jump off. Sets the local-only attribute TrainingLocal on you
-- (SpeedClient uses it for the running effects).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local SpeedData = require(ReplicatedStorage:WaitForChild("SpeedData"))
local remote = ReplicatedStorage:WaitForChild("SpeedRemote")
local treadmills = workspace:WaitForChild("Treadmills")

local DARK = Color3.fromRGB(8, 20, 28)
local YELLOW = Color3.fromRGB(255, 225, 70)
local GREEN = Color3.fromRGB(60, 205, 40)
local GREY = Color3.fromRGB(120, 130, 145)
local GOLD = Color3.fromRGB(240, 175, 30)
local RED = Color3.fromRGB(255, 95, 95)
local HIDE_DELAY = 1 -- someone else's treadmill stays this long after they step off, so it doesn't flicker

local localFolder = Instance.new("Folder")
localFolder.Name = "LocalTreadmills"
localFolder.Parent = workspace

---------------------------------------------------------------- input: are you steering yourself?
-- the default PlayerModule's controls tell us; this place may not have one, then the keys decide
local controls = nil
task.spawn(function()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if module then
		local ok, result = pcall(function()
			return require(module):GetControls()
		end)
		if ok then
			controls = result
		end
	end
end)
local MOVE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right }
local function steering()
	if controls then
		return controls:GetMoveVector().Magnitude > 0.1
	end
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	for _, k in ipairs(MOVE_KEYS) do
		if UserInputService:IsKeyDown(k) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- helpers
local function myTier()
	return math.clamp(player:GetAttribute("TreadmillTier") or 1, 1, #SpeedData.Treadmills)
end
local function cash()
	local stats = player:FindFirstChild("leaderstats")
	local c = stats and stats:FindFirstChild("Cash")
	return c and c.Value or 0
end
local function speedOf(p)
	local stats = p:FindFirstChild("leaderstats")
	local s = stats and stats:FindFirstChild("Speed")
	return s and s.Value or 0
end
local function hex(c)
	return typeof(c) == "Color3" and c or Color3.fromHex(c)
end
local function rainbow(t, offset)
	return Color3.fromHSV((t * 0.25 + (offset or 0)) % 1, 0.8, 1)
end

---------------------------------------------------------------- the six treadmill models (one per tier)
-- Designed in Blender (models/speed/blender/treadmills.py) and exported as data: ReplicatedStorage.TreadmillDesigns
-- .Tier1..Tier6 (Robot, Storm, Ice, Portal, Volcano, Candy). Each is built once into a template here, then cloned.
-- Part names the client uses: Belt (the conveyor), Slat (slides along the belt), Glow (colour-cycles on Candy),
-- Fx* (invisible anchors that get particles + a light).
local designs = ReplicatedStorage:WaitForChild("TreadmillDesigns")
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local templates = {}

local function template(tier)
	if templates[tier] then
		return templates[tier]
	end
	local data = require(designs:FindFirstChild("Tier" .. tier) or designs:WaitForChild("Tier1"))
	local colors, materials = {}, {}
	for i, c in ipairs(data.colors) do
		colors[i] = Color3.fromHex(c)
	end
	for i, m in ipairs(data.materials) do
		materials[i] = Enum.Material[m]
	end
	local model = Instance.new("Model")
	model.Name = "Treadmill" .. tier
	for _, row in ipairs(data.parts) do
		local p = Instance.new("Part")
		p.Name = row[1]
		p.Color = colors[row[2]]
		p.Material = materials[row[3]]
		p.Transparency = row[4]
		p:SetAttribute("Collide", row[5] == 1)
		p.Size = Vector3.new(row[9], row[10], row[11])
		p.CFrame = row[12] and CFrame.new(row[6], row[7], row[8], row[12], row[13], row[14], row[15]) or CFrame.new(row[6], row[7], row[8])
		p.Anchored = true
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = row[4] < 1
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
	end
	model.WorldPivot = CFrame.new()
	templates[tier] = model
	return model
end

local function kp(t, v)
	return NumberSequenceKeypoint.new(t, v)
end

-- particles + light on an Fx anchor (its colour is the effect's colour)
local function addFx(anchor)
	local c = anchor.Color
	local light = Instance.new("PointLight")
	light.Color = c
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = anchor
	if anchor.Name == "FxGlow" then
		return light
	end
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Texture = SPARKLE
	e.LightEmission = 0.8
	e.Color = ColorSequence.new(c)
	if anchor.Name == "FxSpark" then -- Storm: crackling sparks
		e.Rate = 14
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ kp(0, 0.7), kp(1, 0) })
		e.Color = ColorSequence.new(Color3.new(1, 1, 1), c)
	elseif anchor.Name == "FxSnow" then -- Ice: snow drifting down
		e.Rate = 10
		e.Lifetime = NumberRange.new(2.5, 3.5)
		e.Speed = NumberRange.new(0.5, 1.2)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = Vector3.new(0, -1.5, 0)
		e.Size = NumberSequence.new(0.35)
		e.LightEmission = 0.3
	elseif anchor.Name == "FxVoid" then -- Portal: purple specks pouring out
		e.Rate = 16
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.EmissionDirection = Enum.NormalId.Back
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Size = NumberSequence.new({ kp(0, 0.6), kp(1, 0) })
		e.Color = ColorSequence.new(c, Color3.fromRGB(255, 107, 240))
	elseif anchor.Name == "FxFire" then -- Volcano: flames + embers rising
		e.Texture = FIRE
		e.Rate = 30
		e.Lifetime = NumberRange.new(0.6, 1)
		e.Speed = NumberRange.new(2, 4)
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({ kp(0, 1.4), kp(1, 0.2) })
		e.Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 80, 20))
		e.LightEmission = 1
	elseif anchor.Name == "FxRainbow" then -- Candy: rainbow sparkles bursting out
		e.Rate = 16
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(4, 8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ kp(0, 0.8), kp(1, 0) })
		e.Color = SpeedData.ColorSequence(SpeedData.RainbowColors)
	end
	e.Parent = anchor
	return light
end

-- builds a treadmill on base (the Spot's CFrame; the runner faces base.LookVector = local -Z)
local function build(tier, base, solid)
	local model = template(tier):Clone()
	local belt, slats, glows, lights = nil, {}, {}, {}
	for _, p in ipairs(model:GetChildren()) do
		p.CanCollide = solid and p:GetAttribute("Collide") == true
		if p.Name == "Belt" then
			belt = p
		elseif p.Name == "Slat" then
			table.insert(slats, p)
		elseif p.Name == "Glow" then
			p:SetAttribute("Hue", #glows * 0.07)
			table.insert(glows, p)
		end
	end
	table.sort(slats, function(a, b) -- front to back, so the stripe pattern stays in order while they slide
		return a.Position.Z < b.Position.Z
	end)
	model:PivotTo(base)
	for _, p in ipairs(model:GetChildren()) do
		if p.Name:sub(1, 2) == "Fx" then
			table.insert(lights, addFx(p))
		end
	end
	model.Parent = localFolder
	local info = SpeedData.Treadmills[tier] or SpeedData.Treadmills[1]
	return { model = model, belt = belt, slats = slats, glows = glows, rainbow = info.rainbow == true, lights = lights }
end

-- a burst of sparkles + an expanding glow ball where a treadmill was just upgraded
local function burst(base, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = base * CFrame.new(0, 2.5, 0)
	p.Parent = localFolder
	local a = Instance.new("Attachment")
	a.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(12, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 1
	e.Color = ColorSequence.new(color)
	e.Parent = a
	e:Emit(70)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Transparency = 0.2
	ball.Size = Vector3.one * 2
	ball.CFrame = p.CFrame
	ball.Parent = localFolder
	TweenService:Create(ball, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 18, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.6)
	Debris:AddItem(p, 1.5)
end

---------------------------------------------------------------- the small upgrade panel next to YOUR treadmill
-- like Steal an Egg: a little dark panel on a post at the corner where you step on, almost no text:
--   UPGRADE / LEVEL 1 > LEVEL 2 / ⚡5/s > ⚡15/s / [ $10K ]   (the price button is green when you can pay)
local sign = nil
local signBusy = false
local messageUntil = 0

local function signLabel(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		t[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = DARK
	s.Parent = t
	t.Parent = parent
	return t
end

local function destroySign()
	if sign then
		sign.model:Destroy()
		sign.gui:Destroy()
		sign = nil
	end
end

local function buildSign(spotCF, signSide, plotName)
	destroySign()
	local model = Instance.new("Model")
	model.Name = "UpgradeSign"
	-- beside the step-on end of the belt, facing the people walking up, turned a little towards the treadmill
	local pos = Vector3.new(signSide * 5.9, 0, 6.0)
	local dir = Vector3.new(-signSide * math.sin(math.rad(20)), 0, math.cos(math.rad(20)))
	local cf = spotCF * CFrame.lookAt(pos, pos + dir)
	local panelCF = CFrame.new(0, 4.1, 0) * CFrame.Angles(math.rad(12), 0, 0) -- leaning back a little
	local function piece(name, size, offset, color, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = hex(color)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanQuery = false
		p.CanTouch = false
		for k, v in pairs(props or {}) do
			p[k] = v
		end
		p.Parent = model
		return p
	end
	piece("Post", Vector3.new(0.45, 3.3, 0.45), CFrame.new(0, 1.65, 0.25), "#2b2f38")
	local board = piece("Board", Vector3.new(4.4, 2.8, 0.25), panelCF, "#1c2431", { CanQuery = true }) -- clicks land here
	local border = piece("Border", Vector3.new(4.65, 3.05, 0.2), panelCF * CFrame.new(0, 0, 0.06), "#8a93a3", { Material = Enum.Material.Neon, CanCollide = false })
	model.Parent = localFolder

	-- the face lives in PlayerGui (so the button can be clicked), drawn on the board's front
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TreadmillSign"
	gui.Adornee = board
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(440, 280)
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	signLabel(gui, { Name = "Title", Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.2), Text = "UPGRADE" })
	local levelText = signLabel(gui, { Name = "Level", Position = UDim2.fromScale(0.05, 0.26), Size = UDim2.fromScale(0.9, 0.16), Text = "" })
	local speedText = signLabel(gui, { Name = "Speed", Position = UDim2.fromScale(0.05, 0.43), Size = UDim2.fromScale(0.9, 0.15), Text = "", TextColor3 = YELLOW })
	local button = Instance.new("TextButton")
	button.Name = "Upgrade"
	button.Position = UDim2.fromScale(0.14, 0.63)
	button.Size = UDim2.fromScale(0.72, 0.31)
	button.BackgroundColor3 = GREEN
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = button
	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = DARK
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = button
	local textEdge = Instance.new("UIStroke")
	textEdge.Thickness = 2.5
	textEdge.Color = DARK
	textEdge.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.16, 0)
	pad.PaddingBottom = UDim.new(0.16, 0)
	pad.Parent = button
	button.Parent = gui

	sign = { model = model, gui = gui, board = board, border = border, level = levelText, speed = speedText, button = button, plot = plotName }

	local function say(text)
		messageUntil = os.clock() + 2.2
		speedText.Text = text
		speedText.TextColor3 = RED
	end
	button.Activated:Connect(function()
		if signBusy or not SpeedData.Treadmills[myTier() + 1] then
			return
		end
		signBusy = true
		local ok, success, message = pcall(function()
			return remote:InvokeServer("UpgradeTreadmill")
		end)
		signBusy = false
		if not ok then
			say("Try again!")
		elseif not success then
			say(message and message:find("need") and "Not enough cash!" or (message or "Can't upgrade"))
		end
	end)
end

local function refreshSign()
	if not sign then
		return
	end
	local tier = myTier()
	local nextInfo = SpeedData.Treadmills[tier + 1]
	local trail = player:GetAttribute("EquippedTrail")
	local now = SpeedData.Short(SpeedData.Gain(tier, trail))
	local showSpeed = os.clock() >= messageUntil
	if showSpeed then
		sign.speed.TextColor3 = YELLOW
	end
	if nextInfo then
		sign.level.Text = string.format("LEVEL %d  >  LEVEL %d", tier, tier + 1)
		if showSpeed then
			sign.speed.Text = string.format("⚡%s/s  >  ⚡%s/s", now, SpeedData.Short(SpeedData.Gain(tier + 1, trail)))
		end
		sign.button.Text = "$" .. SpeedData.Short(nextInfo.price)
		sign.button.BackgroundColor3 = cash() >= nextInfo.price and GREEN or GREY
		sign.button.AutoButtonColor = true
	else
		sign.level.Text = string.format("LEVEL %d  •  MAX", tier)
		if showSpeed then
			sign.speed.Text = "⚡" .. now .. "/s"
		end
		sign.button.Text = "MAX"
		sign.button.BackgroundColor3 = GOLD
		sign.button.AutoButtonColor = false
	end
end

---------------------------------------------------------------- which treadmills to show, and keeping them alive
local states = {} -- PlotName -> { built = build() result, tier, mine, offset, hideAt }

local function ownerOf(plotName)
	local plot = workspace:FindFirstChild(plotName)
	local id = plot and plot:GetAttribute("OwnerUserId")
	if type(id) ~= "number" or id == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(id)
end

local function placeSlats(s, speed, dt)
	local belt = s.built.belt
	local len = belt.Size.Z
	s.offset = (s.offset + speed * dt) % len
	local parts, cframes = {}, {}
	for i, slat in ipairs(s.built.slats) do
		local z = ((i - 0.5) * len / #s.built.slats + s.offset) % len - len / 2
		parts[i] = slat
		cframes[i] = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 0.025, z)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local training = false
local lastSign = 0
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local myPlot = player:GetAttribute("PlotName")
	local seen = {}
	for _, tm in ipairs(treadmills:GetChildren()) do
		local spot = tm:FindFirstChild("Spot")
		if spot then
			seen[tm.Name] = true
			local owner = ownerOf(tm.Name)
			local mine = owner == player and myPlot == tm.Name
			local s = states[tm.Name]
			if not s then
				s = { offset = 0, hideAt = 0 }
				states[tm.Name] = s
			end
			local want, tier = false, 1
			if mine then
				want, tier = true, myTier()
			elseif owner then
				if owner:GetAttribute("OnTreadmill") == tm.Name then
					s.hideAt = now + HIDE_DELAY
				end
				want = now < s.hideAt
				tier = math.clamp(owner:GetAttribute("TreadmillTier") or 1, 1, #SpeedData.Treadmills)
			end
			if want and (not s.built or s.tier ~= tier or s.mine ~= mine) then
				local upgraded = s.built and mine and s.mine and tier > s.tier
				if s.built then
					s.built.model:Destroy()
				end
				s.built = build(tier, spot.CFrame, mine)
				s.tier, s.mine = tier, mine
				placeSlats(s, 0, 0)
				if upgraded then
					local info = SpeedData.Treadmills[tier]
					burst(spot.CFrame, info.rainbow and Color3.new(1, 1, 1) or info.color)
				end
			elseif not want and s.built then
				s.built.model:Destroy()
				s.built = nil
			end
			if s.built then
				-- belt slats: yours at your walk speed while you train, someone else's while they do
				local speed = 0
				if mine then
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					speed = training and humanoid and humanoid.WalkSpeed or 0
				elseif owner and owner:GetAttribute("OnTreadmill") == tm.Name then
					speed = SpeedData.Walk(speedOf(owner), owner:GetAttribute("EquippedTrail"))
				end
				if speed > 0 then
					placeSlats(s, speed, dt)
				end
				if s.built.rainbow then
					for _, g in ipairs(s.built.glows) do
						g.Color = rainbow(now, g:GetAttribute("Hue"))
					end
					for _, l in ipairs(s.built.lights) do
						l.Color = rainbow(now)
					end
				end
			end
		end
	end
	for name, s in pairs(states) do
		if not seen[name] then
			if s.built then
				s.built.model:Destroy()
			end
			states[name] = nil
		end
	end

	-- the sign stands next to your own treadmill only
	local mineState = type(myPlot) == "string" and states[myPlot]
	if mineState and mineState.mine and mineState.built then
		if not sign or sign.plot ~= myPlot then
			local spot = treadmills[myPlot].Spot
			buildSign(spot.CFrame, spot:GetAttribute("SignSide") or 1, myPlot)
			lastSign = 0
		end
		local info = SpeedData.Treadmills[myTier()]
		sign.border.Color = info.rainbow and rainbow(now) or info.color
		if now - lastSign > 0.2 then
			lastSign = now
			refreshSign()
		end
	elseif sign then
		destroySign()
	end
end)

---------------------------------------------------------------- running on your own belt
RunService:BindToRenderStep("TreadmillRun", Enum.RenderPriority.Input.Value + 1, function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local myPlot = player:GetAttribute("PlotName")
	local s = type(myPlot) == "string" and states[myPlot]
	local tm = s and s.mine and s.built and treadmills:FindFirstChild(myPlot)
	local spot = tm and tm:FindFirstChild("Spot")
	local on = spot ~= nil and root ~= nil and humanoid ~= nil and humanoid.Health > 0 and not player:GetAttribute("Carrying") and SpeedData.OnBelt(spot.CFrame, root.Position, 0.3)
	if on then
		local forward = spot.CFrame.LookVector
		s.built.belt.AssemblyLinearVelocity = -forward * humanoid.WalkSpeed
		if not steering() then
			humanoid:Move(forward, false)
		end
	elseif s and s.built then
		s.built.belt.AssemblyLinearVelocity = Vector3.zero
	end
	if on ~= training then
		training = on
		player:SetAttribute("TrainingLocal", on)
	end
end)
