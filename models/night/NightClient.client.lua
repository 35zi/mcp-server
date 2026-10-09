-- NightClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- What you see of the NIGHT HUNT (NightService): the countdown 10 ... 1 and "GO!" painted ON THE WALL (not on your screen;
-- everyone hears the ticks), and the server message for rare animals ("Yeti has spawned!") for everyone.
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

---------------------------------------------------------------- the countdown lives ON THE WALL
-- Nothing is drawn over your screen: the title and the big numbers are painted on both faces of Workspace.NightWall,
-- so only the people standing at the wall see them. Everyone else just hears the ticks / the GO sound.
local wallGuis = {} -- { title, numbers = { labels } } per face
local function buildWallGuis(wall)
	for _, g in ipairs(wallGuis) do
		g.gui:Destroy()
	end
	wallGuis = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "NightWallText"
		sg.Face = face
		sg.Adornee = wall
		sg.CanvasSize = Vector2.new(2400, 340)
		sg.LightInfluence = 0
		sg.Brightness = 1.5
		sg.MaxDistance = 400
		sg.ResetOnSpawn = false
		sg.Parent = player:WaitForChild("PlayerGui")
		local title = label({ Position = UDim2.fromScale(0, 0.02), Size = UDim2.fromScale(1, 0.24), Text = "🌙 NIGHT HUNT — the wall opens in…", Visible = false }, sg, 6)
		local numbers = {}
		for _, x in ipairs({ 0.14, 0.5, 0.86 }) do -- repeated along the wall so it reads from anywhere
			local n = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, 0.27), Size = UDim2.fromScale(0.22, 0.72), Text = "", Visible = false }, sg, 8)
			table.insert(numbers, n)
		end
		table.insert(wallGuis, { gui = sg, title = title, numbers = numbers })
	end
end

local function setWall(titleText, text, color)
	local wall = workspace:FindFirstChild("NightWall")
	if wall and (not wallGuis[1] or wallGuis[1].gui.Adornee ~= wall or not wallGuis[1].gui.Parent) then
		buildWallGuis(wall)
	end
	for _, g in ipairs(wallGuis) do
		g.title.Visible = titleText ~= nil
		g.title.Text = titleText or ""
		for _, n in ipairs(g.numbers) do
			n.Visible = text ~= nil
			n.Text = text or ""
			n.TextColor3 = color or Color3.new(1, 1, 1)
		end
	end
end

local running = 0 -- serial number of the current countdown
local function countdown(goAt, endAt)
	running += 1
	local serial = running
	setWall("🌙 NIGHT HUNT — the wall opens in…", "", Color3.new(1, 1, 1))
	local lastShown = nil
	while running == serial do
		local left = goAt - workspace:GetServerTimeNow()
		if left <= 0 then
			break
		end
		local n = math.ceil(left)
		if n ~= lastShown then
			lastShown = n
			setWall("🌙 NIGHT HUNT — the wall opens in…", tostring(n), n <= 3 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 235, 120))
			playSound("HitTick", 0.8 + (10 - n) * 0.07, 1) -- everyone hears the ticks, wherever they are
		end
		RunService.RenderStepped:Wait()
	end
end

local function go()
	running += 1 -- stops the countdown loop
	setWall("🌙 NIGHT HUNT", "GO!", Color3.fromRGB(90, 255, 110))
	playSound("SpeedWhoosh", 1.2, 1)
	playSound("SpeedDing", 1.4, 0.8)
	local serial = running
	task.delay(2, function()
		if running == serial then -- not if a new night started meanwhile
			setWall(nil, nil)
		end
	end)
end

---------------------------------------------------------------- the server message for rare animals
local toastSerial = 0
local toast = Instance.new("Frame")
toast.Name = "Rare"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.14) -- top of the screen (for everyone, wherever they are)
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
		setWall(nil, nil)
	elseif kind == "Rare" then
		rare(data)
	end
end)
