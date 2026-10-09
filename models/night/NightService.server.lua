-- NightService (Script in ServerScriptService)
--
-- The NIGHT HUNT, every animal wave (AnimalManager: every 5 minutes; it sets Workspace.Animals attribute Wave):
--   0 s   night falls (Lighting fades dark), everyone out in the worlds is put back behind the red line, a glowing wall
--         rises along the red line so nobody can go yet, the new animals are already out there
--         + a server message for every rare animal that spawned ("Yeti has spawned!")
--   0-10  everybody gets ready: NightClient shows the countdown 10, 9, 8 ... 1
--   10 s  GO! the wall drops and the hunt is on
--   15 s  the sun comes back up
-- The first wave (server start) is skipped. Test it any time: workspace.Animals:SetAttribute("Wave", <a new number>).
--   Remote: ReplicatedStorage.NightEvent  server -> client
--     "Start" { goAt = server time the wall opens, endAt = server time it is day again }
--     "Go"    {}      "End" {}
--     "Rare"  { species, rarity, world, count }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))

local COUNTDOWN = 10 -- seconds of waiting behind the wall
local NIGHT_LENGTH = 15 -- seconds from nightfall to sunrise
local WALL_HEIGHT = 44
local RARE_FROM = "Legendary" -- this rarity and above gets a server message

local event = ReplicatedStorage:FindFirstChild("NightEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "NightEvent"
	event.Parent = ReplicatedStorage
end

local animals = workspace:WaitForChild("Animals")
local redLine = workspace:WaitForChild("RedLine")

---------------------------------------------------------------- the wall
local floorY = redLine.Position.Y + redLine.Size.Y / 2 + 0.2
local wall = Instance.new("Part")
wall.Name = "NightWall"
wall.Anchored = true
wall.CanCollide = false
wall.CanTouch = false
wall.CanQuery = false
wall.CastShadow = false
wall.Material = Enum.Material.ForceField
wall.Color = Color3.fromRGB(255, 60, 70)
wall.Transparency = 0.15
wall.Size = Vector3.new(312, WALL_HEIGHT, 3)
local hiddenCF = CFrame.new(redLine.Position.X, floorY - WALL_HEIGHT / 2 - 1, redLine.Position.Z - 1.6)
local shownCF = CFrame.new(redLine.Position.X, floorY + WALL_HEIGHT / 2, redLine.Position.Z - 1.6)
wall.CFrame = hiddenCF
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(2400, 340)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = wall
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "🌙  NIGHT HUNT  🌙  GET READY  🌙  NIGHT HUNT  🌙"
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 8
	stroke.Color = Color3.fromRGB(120, 10, 20)
	stroke.Parent = label
	label.Parent = gui
end
wall.Parent = workspace

local function moveWall(cf, seconds)
	TweenService:Create(wall, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = cf }):Play()
end

---------------------------------------------------------------- night / day
local function snapshot()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	return {
		light = { Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, ClockTime = Lighting.ClockTime },
		atmosphere = atmosphere and { Color = atmosphere.Color, Decay = atmosphere.Decay },
		cc = cc and { TintColor = cc.TintColor, Brightness = cc.Brightness, Saturation = cc.Saturation, Contrast = cc.Contrast },
	}
end

local NIGHT = {
	light = { Brightness = 1, Ambient = Color3.fromRGB(80, 95, 150), OutdoorAmbient = Color3.fromRGB(75, 90, 145), ClockTime = 23.9 },
	atmosphere = { Color = Color3.fromRGB(70, 90, 160), Decay = Color3.fromRGB(35, 45, 110) },
	cc = { TintColor = Color3.fromRGB(150, 170, 245), Brightness = -0.04, Saturation = -0.05, Contrast = 0.08 },
}

local function fadeTo(state, seconds)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, state.light):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and state.atmosphere then
		TweenService:Create(atmosphere, info, state.atmosphere):Play()
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc and state.cc then
		TweenService:Create(cc, info, state.cc):Play()
	end
end

---------------------------------------------------------------- rare animals
local RARE_RANK = AnimalData.RarityRank(RARE_FROM)
local announced = setmetatable({}, { __mode = "k" }) -- models already announced

local function announceRares()
	local found = {} -- species -> count
	for _, model in ipairs(animals:GetChildren()) do
		local info = AnimalData.Species[model.Name]
		if info and not announced[model] and AnimalData.RarityRank(info.rarity) >= RARE_RANK then
			announced[model] = true
			found[model.Name] = (found[model.Name] or 0) + 1
		end
	end
	for species, count in pairs(found) do
		local info = AnimalData.Species[species]
		event:FireAllClients("Rare", { species = species, rarity = info.rarity, world = info.world, count = count })
	end
end

---------------------------------------------------------------- the hunt
local active = false
local lastWave = animals:GetAttribute("Wave")

local function backBehindTheLine()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Position.Z < redLine.Position.Z + 5 then
			local x = math.clamp(root.Position.X, redLine.Position.X - 140, redLine.Position.X + 140)
			local target = Vector3.new(x, redLine.Position.Y + 6, redLine.Position.Z + 14)
			character:PivotTo(CFrame.lookAt(target, target + Vector3.new(0, 0, -1)) * root.CFrame:ToObjectSpace(character:GetPivot()))
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function nightHunt()
	if active then
		return
	end
	active = true
	local before = snapshot()
	local now = workspace:GetServerTimeNow()
	event:FireAllClients("Start", { goAt = now + COUNTDOWN, endAt = now + NIGHT_LENGTH })
	backBehindTheLine()
	wall.CanCollide = true
	moveWall(shownCF, 1.2)
	fadeTo(NIGHT, 1.8)
	announceRares()
	-- anyone who spawned / was carried over the line meanwhile is moved back again as the wall settles
	task.delay(1.4, backBehindTheLine)

	task.wait(COUNTDOWN)
	wall.CanCollide = false
	moveWall(hiddenCF, 0.9)
	event:FireAllClients("Go")

	task.wait(NIGHT_LENGTH - COUNTDOWN)
	Lighting.ClockTime = 0 -- the sun rises again (0 -> morning), not sets
	local day = before.light
	fadeTo({ light = { Brightness = day.Brightness, Ambient = day.Ambient, OutdoorAmbient = day.OutdoorAmbient, ClockTime = day.ClockTime }, atmosphere = before.atmosphere, cc = before.cc }, 3)
	event:FireAllClients("End")
	active = false
end

animals:GetAttributeChangedSignal("Wave"):Connect(function()
	local wave = animals:GetAttribute("Wave")
	if wave == lastWave then
		return
	end
	lastWave = wave
	if wave and wave > 1 then
		task.spawn(nightHunt)
	end
end)
