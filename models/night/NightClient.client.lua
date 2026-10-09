-- NightClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- What you see of the NIGHT HUNT (NightService): a banner while the wall is up, the big countdown 10 ... 1, "GO!"
-- when it drops, and the server message for rare animals ("Yeti has spawned!").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local event = ReplicatedStorage:WaitForChild("NightEvent")
local audio = ReplicatedStorage:FindFirstChild("GameAudio")

local DARK = Color3.fromRGB(8, 14, 30)
local WORLD_NAMES = { "Forest", "Desert", "Snow" }
local RARITY_ICON = { Legendary = "🌟", Secret = "🔮", Epic = "💜" }

local gui = Instance.new("ScreenGui")
gui.Name = "NightHunt"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props, parent, stroke)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		t[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Thickness = stroke or 4
	s.Color = DARK
	s.Parent = t
	t.Parent = parent
	return t, s
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

---------------------------------------------------------------- banner + countdown
local top = Instance.new("Frame")
top.Name = "Top"
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.fromScale(0.5, 0.1)
top.Size = UDim2.fromScale(0.62, 0.075)
top.BackgroundTransparency = 1
top.Visible = false
top.Parent = gui
local topText = label({ Size = UDim2.fromScale(1, 1), Text = "🌙 NIGHT HUNT — the wall opens in…" }, top, 4)

local big = label({ Name = "Count", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.34, 0.34), Text = "", Visible = false }, gui, 7)
local BIG = 2.6 -- the digit is a 100 px font drawn at 2.6x (TextScaled ignores UIScale, so it is off here)
big.TextScaled = false
big.TextSize = 100
local bigScale = Instance.new("UIScale")
bigScale.Scale = BIG
bigScale.Parent = big

local function pop(text, color, tickPitch)
	big.Text = text
	big.TextColor3 = color
	big.Visible = true
	bigScale.Scale = BIG * 1.6
	big.TextTransparency = 0
	TweenService:Create(bigScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = BIG }):Play()
	if tickPitch then
		playSound("HitTick", tickPitch, 1)
	end
end

local running = 0 -- serial number of the current countdown
local function countdown(goAt, endAt)
	running += 1
	local serial = running
	top.Visible = true
	topText.Text = "🌙 NIGHT HUNT — the wall opens in…"
	local lastShown = nil
	while running == serial do
		local left = goAt - workspace:GetServerTimeNow()
		if left <= 0 then
			break
		end
		local n = math.ceil(left)
		if n ~= lastShown then
			lastShown = n
			local hot = n <= 3
			pop(tostring(n), hot and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 235, 120), 0.8 + (10 - n) * 0.07)
		end
		RunService.RenderStepped:Wait()
	end
end

local function go()
	running += 1 -- stops the countdown loop
	top.Visible = false
	pop("GO!", Color3.fromRGB(90, 255, 110), nil)
	playSound("SpeedWhoosh", 1.2, 1)
	playSound("SpeedDing", 1.4, 0.8)
	task.delay(1.3, function()
		TweenService:Create(big, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.45, function()
			if big.Text == "GO!" then
				big.Visible = false
			end
		end)
	end)
end

---------------------------------------------------------------- the server message for rare animals
local toastSerial = 0
local toast = Instance.new("Frame")
toast.Name = "Rare"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.62) -- below the big countdown
toast.Size = UDim2.fromScale(0.7, 0.13)
toast.BackgroundTransparency = 1
toast.Visible = false
toast.Parent = gui
local toastScale = Instance.new("UIScale")
toastScale.Parent = toast
local toastTitle = label({ Size = UDim2.fromScale(1, 0.62), Text = "" }, toast, 5)
local toastSub = label({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.38), Text = "" }, toast, 3)

local function rare(data)
	local info = AnimalData.Species[data.species]
	local rarity = AnimalData.Rarities[data.rarity]
	local color = rarity and rarity.color or Color3.fromRGB(255, 200, 60)
	toastSerial += 1
	local serial = toastSerial
	toastTitle.Text = string.format("%s %s%s has spawned!", RARITY_ICON[data.rarity] or "⭐", AnimalData.PrettyName and AnimalData.PrettyName(data.species) or data.species, (data.count or 1) > 1 and (" ×" .. data.count) or "")
	toastTitle.TextColor3 = color
	toastSub.Text = string.format("%s • %s world", string.upper(data.rarity), WORLD_NAMES[data.world or (info and info.world) or 1] or "?")
	toast.Visible = true
	toastScale.Scale = 0.4
	TweenService:Create(toastScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	playSound("SpeedUpgrade", 1.1, 1)
	task.delay(6, function()
		if toastSerial == serial then
			TweenService:Create(toastScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
			task.delay(0.35, function()
				if toastSerial == serial then
					toast.Visible = false
				end
			end)
		end
	end)
end

---------------------------------------------------------------- server events
event.OnClientEvent:Connect(function(kind, data)
	data = data or {}
	if kind == "Start" then
		playSound("SpeedWhoosh", 0.7, 0.8)
		task.spawn(countdown, data.goAt, data.endAt)
	elseif kind == "Go" then
		go()
	elseif kind == "End" then
		top.Visible = false
	elseif kind == "Rare" then
		rare(data)
	end
end)
