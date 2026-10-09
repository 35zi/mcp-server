-- TreadmillClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Draws every plot's treadmill on this client. The server only has the invisible Workspace.Treadmills.<Plot>.Spot
-- (BuildTreadmills); what you see is built here, in Workspace.LocalTreadmills:
--   * your own (in front of your pen): always there and solid, in the look of your tier (Basic, Bronze, Silver, Gold,
--     Diamond, Rainbow: a new model on every upgrade), with a small upgrade panel: level now > next, Speed per second
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

---------------------------------------------------------------- the six treadmill looks (one per tier)
-- base = deck, frame = posts/rails/panels, trim = the glowing strips, accent = small details
local LOOKS = {
	{ base = "#2b2f38", frame = "#dfe3ea", trim = "#8a93a3", accent = "#ff5a5a" }, -- Basic
	{ base = "#3a2a1f", frame = "#c07a3c", trim = "#ff9a3c", accent = "#ffd29a", metal = true, neon = true, panels = true }, -- Bronze
	{ base = "#2f3642", frame = "#d3dce8", trim = "#eaf6ff", accent = "#4fc3ff", metal = true, neon = true, panels = true, grips = true, frontBar = true }, -- Silver
	{ base = "#2a2216", frame = "#f2b632", trim = "#ffd84a", accent = "#fff3b0", metal = true, neon = true, panels = true, grips = true, frontBar = true, fins = true, crown = true, sparkle = true }, -- Gold
	{ base = "#121a2b", frame = "#9feaff", trim = "#6ff0ff", accent = "#ffffff", glass = true, neon = true, panels = true, grips = true, frontBar = true, fins = true, crystals = true, sparkle = true, light = true }, -- Diamond
	{ base = "#151515", frame = "#f4f4f4", trim = "#ff5ad2", accent = "#ffffff", neon = true, rainbow = true, panels = true, grips = true, frontBar = true, fins = true, crystals = true, arch = true, sparkle = true, light = true }, -- Rainbow
}

local SLATS = 12

-- builds a treadmill on base (the Spot's CFrame; the runner faces base.LookVector = local -Z)
local function build(tier, base, solid)
	local look = LOOKS[tier] or LOOKS[1]
	local model = Instance.new("Model")
	model.Name = "Treadmill" .. tier
	local glows = {}
	local function piece(name, size, offset, color, props, class)
		local p = Instance.new(class or "Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = base * offset
		p.Color = hex(color)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = solid
		p.CanQuery = false
		p.CanTouch = false
		for k, v in pairs(props or {}) do
			p[k] = v
		end
		p.Parent = model
		return p
	end
	local function glow(name, size, offset, props)
		local p = piece(name, size, offset, look.trim, props)
		p.Material = look.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p:SetAttribute("Hue", #glows * 0.07)
		table.insert(glows, p)
		return p
	end
	local frameProps = {
		Material = look.glass and Enum.Material.Glass or look.metal and Enum.Material.Metal or Enum.Material.SmoothPlastic,
		Transparency = look.glass and 0.2 or 0,
		Reflectance = look.metal and 0.15 or 0,
	}
	local at = CFrame.new

	piece("Base", Vector3.new(6.6, 0.7, 12.5), at(0, 0.35, 0), look.base)
	local belt = piece("Belt", SpeedData.Belt.size, at(SpeedData.Belt.center), "#17181c", { Material = Enum.Material.Fabric })
	local slats = {}
	for i = 1, SLATS do
		slats[i] = piece("Slat", Vector3.new(4.9, 0.05, 0.22), at(0, 0, 0), "#3d4250", { CanCollide = false })
	end
	for _, z in ipairs({ -5.9, 6.4 }) do
		piece("Roller", Vector3.new(5.3, 0.9, 0.9), at(0, 0.62, z), hex(look.frame):Lerp(Color3.new(0, 0, 0), 0.45), { Shape = Enum.PartType.Cylinder })
	end
	for _, side in ipairs({ -1, 1 }) do
		glow("Glow", Vector3.new(0.4, 0.32, 12.5), at(side * 3.1, 0.78, 0))
		piece("Post", Vector3.new(0.5, 4.6, 0.5), at(side * 2.75, 3.0, -5.6), look.frame, frameProps)
		piece("Rail", Vector3.new(0.35, 0.35, 5.2), at(side * 2.75, 4.0, -3.2), look.frame, frameProps)
		piece("RailEnd", Vector3.new(0.45, 0.45, 0.45), at(side * 2.75, 4.0, -0.55), look.accent, { CanCollide = false })
		if look.panels then
			piece("Panel", Vector3.new(0.25, 0.9, 12.3), at(side * 3.45, 0.45, 0), look.frame, frameProps)
		end
		if look.grips then
			piece("Grip", Vector3.new(0.5, 0.5, 1.6), at(side * 2.75, 4.0, -2.2), "#1d1d22", { CanCollide = false })
		end
		if look.fins then -- swept fins at the back, tall end towards the rear
			piece("Fin", Vector3.new(0.3, 1.8, 2.6), at(side * 3.45, 1.6, 5.0), look.frame, frameProps, "WedgePart")
		end
		if look.crystals then
			for _, spotAt in ipairs({ at(side * 3.35, 6.15, -5.6), at(side * 3.0, 1.5, 6.6) }) do
				local turn = CFrame.Angles(math.rad(45), 0, math.rad(45))
				piece("Crystal", Vector3.new(0.9, 0.9, 0.9), spotAt * turn, look.trim, { Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false })
				glow("Glow", Vector3.new(0.45, 0.45, 0.45), spotAt * turn)
			end
		end
		if look.arch then
			glow("Glow", Vector3.new(0.5, 7.2, 0.5), at(side * 3.7, 3.6, 6.0))
		end
	end
	if look.arch then
		glow("Glow", Vector3.new(7.9, 0.5, 0.5), at(0, 7.45, 6.0))
	end
	if look.frontBar then
		glow("Glow", Vector3.new(5.2, 0.25, 0.25), at(0, 2.2, -5.75))
	end

	-- console, tilted towards the runner (no text on it, just lights)
	local consoleCF = at(0, 5.45, -5.6) * CFrame.Angles(math.rad(-28), 0, 0)
	piece("Console", Vector3.new(5.8, 1.5, 0.9), consoleCF, look.base)
	glow("Glow", Vector3.new(5.8, 0.18, 0.95), consoleCF * at(0, 0.82, 0))
	local screen = piece("Screen", Vector3.new(5, 1.1, 0.08), consoleCF * at(0, 0, 0.47), "#0b1622", { CanCollide = false })
	glow("Glow", Vector3.new(3.6, 0.22, 0.05), consoleCF * at(0, 0.15, 0.52))
	glow("Glow", Vector3.new(2.2, 0.16, 0.05), consoleCF * at(-0.7, -0.22, 0.52))
	if look.crown then
		for _, x in ipairs({ -1.6, 0, 1.6 }) do
			piece("Crown", Vector3.new(0.55, 0.55, 0.55), consoleCF * at(x, 1.05, 0) * CFrame.Angles(0, 0, math.rad(45)), look.accent, { Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	if look.light then
		local light = Instance.new("PointLight")
		light.Color = hex(look.trim)
		light.Range = 14
		light.Brightness = 1.3
		light.Parent = screen
	end
	if look.sparkle then
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0.3, 5)
		a.Parent = belt
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 6
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(1, 2.5)
		e.SpreadAngle = Vector2.new(60, 60)
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.LightEmission = 0.8
		e.Color = look.rainbow and SpeedData.ColorSequence(SpeedData.RainbowColors) or ColorSequence.new(hex(look.trim))
		e.Parent = a
	end

	model.WorldPivot = base
	model.Parent = localFolder
	return { model = model, belt = belt, slats = slats, glows = glows, look = look, light = look.light and screen:FindFirstChildOfClass("PointLight") }
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
	local pos = Vector3.new(signSide * 5.3, 0, 5)
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
		local z = ((i - 0.5) * len / SLATS + s.offset) % len - len / 2
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
				if s.built.look.rainbow then
					for _, g in ipairs(s.built.glows) do
						g.Color = rainbow(now, g:GetAttribute("Hue"))
					end
					if s.built.light then
						s.built.light.Color = rainbow(now)
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
