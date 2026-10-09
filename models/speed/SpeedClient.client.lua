-- SpeedClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Everything you see and feel on the Speed side (numbers in ReplicatedStorage.SpeedData, server in SpeedService):
--   * walk speed = SpeedData.Walk(your Speed, your trail), applied to your own Humanoid (left alone while something
--     else has frozen it at 0, e.g. the weapon shop view)
--   * TreadmillClient draws the treadmills and runs you on yours; it sets the local attribute TrainingLocal
--   * juice: floating "+15 ⚡" numbers, a rising tick, screen speed lines, a small FOV kick, sparkles, a Speed counter
--     above the cash, streak, milestone and upgrade banners with confetti
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local SpeedData = require(ReplicatedStorage:WaitForChild("SpeedData"))
local event = ReplicatedStorage:WaitForChild("SpeedEvent")
local audio = ReplicatedStorage:FindFirstChild("GameAudio")

local DARK = Color3.fromRGB(8, 20, 28)
local CYAN = Color3.fromRGB(90, 230, 255)
local YELLOW = Color3.fromRGB(255, 225, 70)
local MILESTONES = { 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000, 50000000, 100000000 }

local function make(class, props, parent)
	local x = Instance.new(class)
	for k, v in pairs(props) do
		x[k] = v
	end
	x.Parent = parent
	return x
end
local function outlined(props, parent, thickness)
	local t = make("TextLabel", props, parent)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	make("UIStroke", { Thickness = thickness or 2, Color = DARK }, t)
	return t
end

local function speedValue()
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Speed")
end
local function tierInfo()
	local tier = player:GetAttribute("TreadmillTier") or 1
	return tier, SpeedData.Treadmills[tier] or SpeedData.Treadmills[1]
end
local function rainbowAt(t)
	return Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
end
local function tierColor(info, t)
	return info.rainbow and rainbowAt(t) or info.color
end

local function playSound(name, pitch, volume)
	local s = audio and audio:FindFirstChild(name)
	if not s then
		return
	end
	local c = s:Clone()
	c.PlaybackSpeed = pitch or 1
	c.Volume = (c.Volume > 0 and c.Volume or 0.5) * (volume or 1)
	c.Parent = workspace.CurrentCamera
	c:Play()
	c.Ended:Connect(function()
		c:Destroy()
	end)
	task.delay(4, function()
		if c.Parent then
			c:Destroy()
		end
	end)
end

---------------------------------------------------------------- HUD: Speed counter above the cash + toasts + banners
local ui = make("ScreenGui", { Name = "SpeedUI", ResetOnSpawn = false, DisplayOrder = 10, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
local hud = make("Frame", { Name = "Speed", AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(300, 40), BackgroundTransparency = 1 }, ui)
local hudScale = make("UIScale", {}, hud)
local counter = outlined({ Name = "Counter", Size = UDim2.fromScale(0.62, 1), Text = "⚡ 0", TextColor3 = CYAN, TextXAlignment = Enum.TextXAlignment.Left }, hud, 2.2)
local counterScale = make("UIScale", {}, counter)
local rateLabel = outlined({ Name = "Rate", Position = UDim2.fromScale(0.62, 0.15), Size = UDim2.fromScale(0.38, 0.7), Text = "", TextColor3 = YELLOW, TextXAlignment = Enum.TextXAlignment.Left }, hud, 1.8)

local function placeHUD()
	local vp = workspace.CurrentCamera.ViewportSize
	local scale = math.min(1, vp.X / 800, vp.Y / 550)
	hudScale.Scale = scale
	-- just above Codex's HUD (bottom-left, 104 px tall at scale 1)
	hud.Position = UDim2.new(0.016, 0, 0.975, -math.floor(110 * scale))
end
placeHUD()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeHUD)

local function pop(object, scale, size)
	scale.Scale = size or 1.25
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local shownSpeed = 0
local function setCounter(value, animate)
	value = value or 0
	if animate and value > shownSpeed then
		local from = shownSpeed
		local start = os.clock()
		task.spawn(function()
			while os.clock() - start < 0.4 do
				local a = (os.clock() - start) / 0.4
				counter.Text = "⚡ " .. SpeedData.Commas(from + (value - from) * a) .. " SPEED"
				RunService.RenderStepped:Wait()
			end
			counter.Text = "⚡ " .. SpeedData.Commas(value) .. " SPEED"
		end)
		pop(counter, counterScale, 1.18)
	else
		counter.Text = "⚡ " .. SpeedData.Commas(value) .. " SPEED"
	end
	shownSpeed = value
end

local toastSerial = 0
local toast = outlined({ Name = "Toast", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.6, 0.055), Text = "", TextColor3 = Color3.new(1, 1, 1), Visible = false }, ui, 2)
local function notice(message, color)
	toastSerial += 1
	local serial = toastSerial
	toast.Text = message
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.Visible = true
	task.delay(3, function()
		if toastSerial == serial then
			toast.Visible = false
		end
	end)
end

local function confetti(count)
	for _ = 1, count or 40 do
		local c = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.3, 0.28),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			BackgroundColor3 = SpeedData.RainbowColors[math.random(1, #SpeedData.RainbowColors)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 30,
		}, ui)
		local x = 0.5 + (math.random() - 0.5) * 1.1
		local t = TweenService:Create(c, TweenInfo.new(math.random(110, 190) / 100, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(x, 1.1),
			Rotation = c.Rotation + math.random(-540, 540),
		})
		t:Play()
		t.Completed:Connect(function()
			c:Destroy()
		end)
	end
end

local bannerSerial = 0
local function banner(title, subtitle, color)
	bannerSerial += 1
	local serial = bannerSerial
	local old = ui:FindFirstChild("Banner")
	if old then
		old:Destroy()
	end
	local frame = make("Frame", { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.7, 0.16), BackgroundTransparency = 1, ZIndex = 31 }, ui)
	local scale = make("UIScale", { Scale = 0.3 }, frame)
	local t = outlined({ Size = UDim2.fromScale(1, 0.62), Text = title, TextColor3 = color or YELLOW, ZIndex = 32 }, frame, 3.5)
	outlined({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.38), Text = subtitle or "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 32 }, frame, 2.5)
	make("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220)), Rotation = 90 }, t)
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if bannerSerial == serial and frame.Parent then
			local out = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
			out:Play()
			out.Completed:Connect(function()
				frame:Destroy()
			end)
		end
	end)
end

---------------------------------------------------------------- floating "+15 ⚡" over your head
local function floatNumber(amount, color, big)
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not head then
		return
	end
	local gui = make("BillboardGui", {
		Size = UDim2.fromOffset(big and 200 or 150, big and 60 or 44),
		StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 3, 2.2, 0),
		AlwaysOnTop = false, -- AlwaysOnTop billboards did not draw in this place
		LightInfluence = 0,
		Adornee = head,
	}, player.PlayerGui) -- BillboardGuis do not draw inside a ScreenGui
	local label = outlined({ Size = UDim2.fromScale(1, 1), Text = "+" .. SpeedData.Commas(amount) .. " ⚡", TextColor3 = color }, gui, 2.5)
	local scale = make("UIScale", { Scale = 0.4 }, label)
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 4.5, 0) }):Play()
	task.delay(0.55, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(label:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	task.delay(1.15, function()
		gui:Destroy()
	end)
end

---------------------------------------------------------------- screen speed lines while running
local lines = make("Frame", { Name = "SpeedLines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, ui)
local lineData = {}
for i = 1, 16 do
	local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, BackgroundTransparency = 0.6, ZIndex = 2 }, lines)
	table.insert(lineData, { frame = f, angle = (i / 16) * math.pi * 2 + math.random() * 0.3, phase = math.random() })
end
local lineStrength = 0
local function updateLines(dt, running)
	lineStrength = math.clamp(lineStrength + (running and dt * 2 or -dt * 3), 0, 1)
	lines.Visible = lineStrength > 0.01
	if not lines.Visible then
		return
	end
	local vp = workspace.CurrentCamera.ViewportSize
	local r0 = math.max(vp.X, vp.Y) * 0.36
	for _, l in ipairs(lineData) do
		l.phase = (l.phase + dt * 1.6) % 1
		local r = r0 + l.phase * r0 * 0.6
		local len = 60 + l.phase * 120
		l.frame.Size = UDim2.fromOffset(len, 3)
		l.frame.Position = UDim2.fromOffset(vp.X / 2 + math.cos(l.angle) * r, vp.Y / 2 + math.sin(l.angle) * r)
		l.frame.Rotation = math.deg(l.angle)
		l.frame.BackgroundTransparency = 1 - (0.55 * lineStrength * (1 - l.phase))
	end
end

---------------------------------------------------------------- while you train (TreadmillClient sets the local-only
-- attribute TrainingLocal on you): FOV kick, speed lines, sparkles and the +N/s next to the counter
local sparkles -- local particle emitter on your root while running
local function setSparkles(on, color)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if on and root then
		if not sparkles or sparkles.Parent ~= root then
			sparkles = make("ParticleEmitter", {
				Name = "TreadmillSparkles",
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Rate = 18,
				Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(3, 6),
				SpreadAngle = Vector2.new(40, 40),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
				LightEmission = 0.7,
				EmissionDirection = Enum.NormalId.Back,
			}, root)
		end
		sparkles.Color = ColorSequence.new(color)
		sparkles.Enabled = true
	elseif sparkles then
		sparkles.Enabled = false
	end
end

local running = false
local runningSince = 0
local baseFov = nil
RunService.RenderStepped:Connect(function(dt)
	local nowRunning = player:GetAttribute("TrainingLocal") == true
	if nowRunning ~= running then
		running = nowRunning
		runningSince = os.clock()
		if running then
			playSound("SpeedWhoosh", 1.1, 1)
		end
	end
	local character = player.Character
	local camera = workspace.CurrentCamera
	-- a little FOV kick while running (only when no weapon is out, so aiming keeps its own FOV)
	local tool = character and character:FindFirstChildOfClass("Tool")
	if running and not tool then
		baseFov = baseFov or camera.FieldOfView
		camera.FieldOfView += ((baseFov + 8) - camera.FieldOfView) * math.min(1, dt * 4)
	elseif baseFov then
		camera.FieldOfView += (baseFov - camera.FieldOfView) * math.min(1, dt * 6)
		if math.abs(camera.FieldOfView - baseFov) < 0.05 then
			camera.FieldOfView = baseFov
			baseFov = nil
		end
	end
	updateLines(dt, running)
	local tier, info = tierInfo()
	setSparkles(running, tierColor(info, os.clock()))
	rateLabel.Text = running and ("+" .. SpeedData.Commas(SpeedData.Gain(tier, player:GetAttribute("EquippedTrail"))) .. "/s") or ""
end)

---------------------------------------------------------------- walk speed
task.spawn(function()
	while true do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local value = speedValue()
		if humanoid and humanoid.WalkSpeed ~= 0 then
			local want = SpeedData.Walk(value and value.Value or 0, player:GetAttribute("EquippedTrail"))
			if math.abs(humanoid.WalkSpeed - want) > 0.05 then
				humanoid.WalkSpeed = want
			end
		end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------- server events
local streak = 0
event.OnClientEvent:Connect(function(kind, data)
	data = data or {}
	if kind == "Gain" then
		local _, info = tierInfo()
		streak = (os.clock() - runningSince < 0.3) and 1 or (streak + 1)
		local big = streak % 16 == 0 -- every 4 seconds of running
		floatNumber(data.amount, big and YELLOW or tierColor(info, os.clock()), big)
		playSound("SpeedPop", 0.9 + math.min(streak, 40) * 0.012, 0.8) -- pitch climbs the longer you run
		setCounter(data.total, true)
		local before = data.total - data.amount
		for _, m in ipairs(MILESTONES) do
			if before < m and data.total >= m then
				banner("⚡ " .. SpeedData.Commas(m) .. " SPEED!", "You're getting faster!", CYAN)
				confetti(45)
				playSound("SpeedDing", 1, 1)
			end
		end
		if big then
			pop(counter, counterScale, 1.4)
			confetti(14)
			playSound("SpeedDing", 1.5, 0.5)
		end
	elseif kind == "Upgraded" then
		local info = SpeedData.Treadmills[data.tier]
		if info then
			banner("TREADMILL UPGRADED!", string.format("%s  •  ⚡ +%s / sec", string.upper(info.name), SpeedData.Commas(SpeedData.Gain(data.tier, player:GetAttribute("EquippedTrail")))), info.rainbow and YELLOW or info.color)
			confetti(70)
			playSound("SpeedUpgrade", 1, 1)
		end
	elseif kind == "Bought" then
		local trail = SpeedData.Trail(data.id)
		if trail then
			banner(string.upper(trail.name) .. "!", string.format("+%d walk speed  •  x%s Speed/sec", trail.walk, tostring(trail.gain)), SpeedData.TrailColors(trail)[1])
			confetti(60)
			playSound("SpeedTrail", 1, 1)
		end
	elseif kind == "Notice" then
		notice(data.text or "", Color3.fromRGB(255, 120, 120))
	end
end)

-- keep the counter right when Speed changes some other way
task.spawn(function()
	local value = player:WaitForChild("leaderstats"):WaitForChild("Speed")
	setCounter(value.Value, false)
	value.Changed:Connect(function(v)
		if v < shownSpeed then
			setCounter(v, false)
		end
	end)
end)
