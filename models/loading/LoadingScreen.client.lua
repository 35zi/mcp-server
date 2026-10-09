-- LoadingScreen (LocalScript in ReplicatedFirst)
--
-- The game's own world as a loading screen, in the same style as the rest of the UI (bright sky, studded green grass,
-- wooden fences, blocky trees, GothamBlack text with thick dark outlines):
--   * sky with drifting cartoon clouds, a warm glow + slowly turning sun rays behind the logo, twinkling sparkles
--   * rolling grass hills with a wooden plot fence and blocky trees like the Forest world
--   * the logo: a scope badge (red crosshair + paw print) and a bouncing "SHOOT AN / ANIMAL!" title with a shine
--   * a parade of the real animals (ReplicatedStorage.AnimalPreviews, made by InventoryService) popping in and turning
--   * a striped progress bar with tips, then a big pulsing PLAY button
-- PLAY (or Space / Enter / gamepad A, or AUTO_PLAY seconds) flashes white and drops you into the game; the SKIP
-- button in the corner does the same at any time, even before loading is done.
-- Pure UI, no uploaded images, so it shows instantly. Testing tip: Workspace attribute SkipLoadingScreen = true skips it.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if workspace:GetAttribute("SkipLoadingScreen") then
	return
end

local MIN_TIME = 3.5 -- the bar never fills faster than this (so the screen can be enjoyed)
local MAX_WAIT = 30 -- stop waiting for assets after this many seconds
local AUTO_PLAY = 12 -- PLAY presses itself this many seconds after it appears
local DARK = Color3.fromRGB(8, 20, 28) -- the outline colour the game UI uses
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.GothamBlack

local TIPS = {
	"Shoot an animal to stun it — then carry it home over the red line!",
	"Heavy animals need ⚡ Stamina — train on your treadmill",
	"Every 5 minutes the 🌙 NIGHT HUNT begins — be at the wall!",
	"Put animals in your pen to earn 💰 every second",
	"Trails make you run faster — visit the trail shop ✨",
	"Rare animals are announced to the whole server 🌟",
}
local PARADE = { "Bunny", "Fox", "Camel", "PolarBear", "Yeti" }

local function make(class, props, parent)
	local x = Instance.new(class)
	for k, v in pairs(props) do
		x[k] = v
	end
	x.Parent = parent
	return x
end
local function round(obj, r)
	make("UICorner", { CornerRadius = r or UDim.new(1, 0) }, obj)
end
local function border(obj, thickness, color)
	return make("UIStroke", { Thickness = thickness, Color = color or DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, obj)
end
local function grad(obj, a, b, rotation)
	return make("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 }, obj)
end
local function text(props, parent, strokeSize)
	local t = make("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = WHITE }, parent)
	for k, v in pairs(props) do
		t[k] = v
	end
	if strokeSize then
		make("UIStroke", { Thickness = strokeSize, Color = DARK, LineJoinMode = Enum.LineJoinMode.Round }, t)
	end
	return t
end
local function box(props, parent)
	local f = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE }, parent)
	for k, v in pairs(props) do
		f[k] = v
	end
	return f
end

---------------------------------------------------------------- the screen + sky
local gui = make("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local root = box({ Name = "Root", Size = UDim2.fromScale(1, 1), Active = true, ZIndex = 1 }, gui)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 130, 245)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(95, 185, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 235, 255)),
	}),
}, root)

-- sun rays (thin bars through the logo's centre, each turning slowly) and a soft glow
local SUN = UDim2.fromScale(0.5, 0.36)
local rays = {}
for i = 1, 9 do
	local r = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = SUN, Size = UDim2.new(0, i % 2 == 0 and 70 or 40, 2.4, 0), Rotation = i * 20, BackgroundColor3 = Color3.fromRGB(255, 250, 215), ZIndex = 2 }, root)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }) }, r)
	table.insert(rays, r)
end
local glows = {}
for i, g in ipairs({ { 0.95, 0.82 }, { 0.68, 0.7 }, { 0.44, 0.55 } }) do
	local c = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = SUN, Size = UDim2.fromScale(g[1], g[1]), BackgroundColor3 = Color3.fromRGB(255, 246, 200), BackgroundTransparency = g[2], ZIndex = 2 }, root)
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, c)
	round(c)
	glows[i] = { frame = c, base = g[2] }
end

-- cartoon clouds drifting across
local clouds = {}
local function cloud(y, size, speed, startX, tint)
	local c = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(startX, y), Size = UDim2.fromOffset(size * 2.4, size * 1.1), BackgroundTransparency = 1, ZIndex = 3 }, root)
	for _, b in ipairs({ { 0.5, 0.7, 2.3, 0.62 }, { 0.3, 0.52, 0.95, 0.95 }, { 0.58, 0.38, 1.2, 1.2 }, { 0.8, 0.58, 0.8, 0.8 } }) do
		local p = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(b[1], b[2]), Size = UDim2.fromOffset(size * b[3], size * b[4]), BackgroundColor3 = tint, ZIndex = 3 }, c)
		round(p)
	end
	-- a soft shadow on the cloud's belly
	local belly = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(size * 2.1, size * 0.22), BackgroundColor3 = Color3.fromRGB(200, 222, 245), ZIndex = 3 }, c)
	round(belly)
	table.insert(clouds, { frame = c, y = y, speed = speed, x = startX })
end
cloud(0.12, 70, 0.012, 0.12, Color3.fromRGB(255, 255, 255))
cloud(0.24, 46, 0.008, 0.82, Color3.fromRGB(240, 248, 255))
cloud(0.08, 38, 0.006, 0.58, Color3.fromRGB(235, 245, 255))
cloud(0.34, 56, 0.01, 1.1, Color3.fromRGB(250, 252, 255))
cloud(0.19, 30, 0.005, 0.32, Color3.fromRGB(232, 243, 255))

-- twinkling sparkles
local sparkles = {}
local rng = Random.new()
for _ = 1, 26 do
	local size = rng:NextInteger(6, 14) -- little diamonds (the font has no sparkle glyph)
	local s = box({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(255, 252, 220), ZIndex = 4 }, root)
	table.insert(sparkles, { label = s, x = rng:NextNumber(0.03, 0.97), y = rng:NextNumber(0.05, 0.62), phase = rng:NextNumber(0, 6.28), speed = rng:NextNumber(0.004, 0.012) })
end

---------------------------------------------------------------- the ground: hills, fence, blocky trees, grass tiles
local function hill(x, y, width, color, z)
	local h = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(width, width), BackgroundColor3 = color, ZIndex = z }, root)
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }, h)
	round(h)
	border(h, 6, Color3.fromRGB(40, 140, 45))
	return h
end
hill(0.12, 1.12, 0.62, Color3.fromRGB(70, 190, 80), 5)
hill(0.86, 1.18, 0.7, Color3.fromRGB(70, 190, 80), 5)
hill(0.5, 1.3, 0.8, Color3.fromRGB(78, 200, 86), 5)

-- blocky trees like the Forest world's (trunk + stacked leaf blocks)
local function tree(x, y, s)
	local t = box({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(60 * s, 110 * s), BackgroundTransparency = 1, ZIndex = 6 }, root)
	local trunk = box({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.24, 0.42), BackgroundColor3 = Color3.fromRGB(122, 79, 43), ZIndex = 6 }, t)
	border(trunk, 3)
	for i, l in ipairs({ { 0.5, 0.56, 1, 0.34, Color3.fromRGB(63, 163, 77) }, { 0.5, 0.3, 0.74, 0.28, Color3.fromRGB(76, 187, 90) }, { 0.5, 0.1, 0.46, 0.2, Color3.fromRGB(95, 207, 106) } }) do
		local leaf = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(l[1], l[2]), Size = UDim2.fromScale(l[3], l[4]), BackgroundColor3 = l[5], ZIndex = 6 + i }, t)
		round(leaf, UDim.new(0.12, 0))
		border(leaf, 3)
	end
end
tree(0.07, 0.8, 1.15)
tree(0.17, 0.77, 0.8)
tree(0.92, 0.79, 1.25)
tree(0.81, 0.76, 0.75)

-- the grass band with lighter tiles (like the studded floor) and a wooden plot fence on it
local grass = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(1.02, 0.22), BackgroundColor3 = Color3.fromRGB(77, 200, 70), ZIndex = 10 }, root)
border(grass, 6, Color3.fromRGB(40, 140, 45))
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(120, 235, 100), Color3.fromRGB(60, 175, 60)) }, grass)
for row = 0, 2 do
	for col = 0, 23 do
		if (row + col) % 2 == 0 then
			local tile = box({ Position = UDim2.fromScale(col / 24, 0.08 + row * 0.3), Size = UDim2.fromScale(1 / 24, 0.28), BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, ZIndex = 11 }, grass)
			round(tile, UDim.new(0.18, 0))
		end
	end
end
local fence = box({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.815), Size = UDim2.fromScale(1.02, 0.07), BackgroundTransparency = 1, ZIndex = 12 }, root)
for _, y in ipairs({ 0.25, 0.62 }) do
	local rail = box({ Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 0.2), BackgroundColor3 = Color3.fromRGB(196, 120, 52), ZIndex = 12 }, fence)
	border(rail, 3)
end
for i = 0, 20 do
	local post = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / 20, 0), Size = UDim2.new(0, 14, 1, 0), BackgroundColor3 = Color3.fromRGB(170, 98, 40), ZIndex = 13 }, fence)
	round(post, UDim.new(0.3, 0))
	border(post, 3)
end

---------------------------------------------------------------- the logo
local stage = box({ Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(1000, 640), BackgroundTransparency = 1, ZIndex = 20 }, root)
local stageScale = make("UIScale", {}, stage)
local logo = box({ Name = "Logo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, stage)
local logoScale = make("UIScale", { Scale = 1 }, logo)

-- the scope badge: orange disc, cream face, red crosshair, dark paw print
local badge = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 96), Size = UDim2.fromOffset(176, 176), ZIndex = 22 }, logo)
round(badge)
border(badge, 7)
grad(badge, Color3.fromRGB(255, 214, 80), Color3.fromRGB(255, 120, 40), 90)
local badgeScale = make("UIScale", { Scale = 0 }, badge)
local face = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.74, 0.74), BackgroundColor3 = Color3.fromRGB(255, 250, 236), ZIndex = 23 }, badge)
round(face)
border(face, 4)
local RED = Color3.fromRGB(235, 55, 55)
local ring = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundTransparency = 1, ZIndex = 24 }, face)
round(ring)
border(ring, 4, RED)
for _, s in ipairs({ { 0.5, 0.06, 0.07, 0.24 }, { 0.5, 0.94, 0.07, 0.24 }, { 0.06, 0.5, 0.24, 0.07 }, { 0.94, 0.5, 0.24, 0.07 } }) do
	local tick = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(s[1], s[2]), Size = UDim2.fromScale(s[3], s[4]), BackgroundColor3 = RED, ZIndex = 25 }, face)
	round(tick, UDim.new(0.5, 0))
end
local pad = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.34, 0.27), BackgroundColor3 = DARK, ZIndex = 26 }, face)
round(pad, UDim.new(0.45, 0))
for _, toe in ipairs({ { 0.29, 0.4 }, { 0.42, 0.29 }, { 0.58, 0.29 }, { 0.71, 0.4 } }) do
	local t = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(toe[1], toe[2]), Size = UDim2.fromScale(0.13, 0.16), BackgroundColor3 = DARK, ZIndex = 26 }, face)
	round(t)
end
local badgeShine = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3, 0.24), Size = UDim2.fromScale(0.28, 0.16), Rotation = -35, BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, ZIndex = 27 }, badge)
round(badgeShine)

-- "SHOOT AN" + "ANIMAL!" with a dark drop shadow, and a shine that sweeps over "ANIMAL!"
local titleGroup = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 314), Size = UDim2.fromOffset(900, 280), BackgroundTransparency = 1, ZIndex = 21 }, logo)
local titleScale = make("UIScale", { Scale = 0 }, titleGroup)
local function titleLine(str, y, h, z, color, strokeSize)
	return text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(450, y), Size = UDim2.fromOffset(880, h), Text = str, Rotation = -3, TextColor3 = color, ZIndex = z }, titleGroup, strokeSize)
end
titleLine("SHOOT AN", 52 + 7, 76, 21, DARK, 7)
local line1 = titleLine("SHOOT AN", 52, 76, 22, WHITE, 7)
grad(line1, WHITE, Color3.fromRGB(200, 235, 255), 90)
local mainShadow = titleLine("ANIMAL!", 172 + 11, 170, 21, DARK, 10)
local main = titleLine("ANIMAL!", 172, 170, 22, WHITE, 10)
grad(main, Color3.fromRGB(255, 240, 110), Color3.fromRGB(255, 130, 30), 90)
local shine = titleLine("ANIMAL!", 172, 170, 23, WHITE, nil)
local shineGrad = make("UIGradient", {
	Rotation = 20,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }),
	Offset = Vector2.new(-1, 0),
}, shine)

-- ribbon under the title, in the game's red button colours
local ribbon = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 448), Size = UDim2.fromOffset(440, 52), Rotation = -2, ZIndex = 22 }, logo)
round(ribbon, UDim.new(0.3, 0))
border(ribbon, 5)
grad(ribbon, Color3.fromRGB(255, 90, 90), Color3.fromRGB(205, 30, 45), 90)
text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.62), Text = "HUNT  •  CATCH  •  COLLECT", ZIndex = 23 }, ribbon, 3)
local ribbonScale = make("UIScale", { Scale = 0 }, ribbon)

---------------------------------------------------------------- the animal parade (real 3D animals)
local CORNERS = {}
for _, x in ipairs({ -0.5, 0.5 }) do
	for _, y in ipairs({ -0.5, 0.5 }) do
		for _, z in ipairs({ -0.5, 0.5 }) do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end
local parade = {}
for i = 1, #PARADE do
	local holder = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500 + (i - 3) * 160, 565), Size = UDim2.fromOffset(150, 150), BackgroundTransparency = 1, ZIndex = 22 }, stage)
	local scale = make("UIScale", { Scale = 0 }, holder)
	local shadow = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(0.66, 0.14), BackgroundColor3 = DARK, BackgroundTransparency = 0.65, ZIndex = 22 }, holder)
	round(shadow)
	local vp = make("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 210), LightColor = WHITE, LightDirection = Vector3.new(-1, -1.6, -1), ZIndex = 23 }, holder)
	parade[i] = { holder = holder, scale = scale, vp = vp, y = 565, phase = i * 0.9 }
end

local function showAnimal(slot, source)
	pcall(function() -- mesh animals (Camel) are blank until their meshes are downloaded
		ContentProvider:PreloadAsync({ source })
	end)
	local model = source:Clone()
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			for _, c in ipairs(CORNERS) do
				local w = p.CFrame * (c * p.Size)
				low = low:Min(w)
				high = high:Max(w)
			end
		elseif p:IsA("LuaSourceContainer") then
			p:Destroy()
		end
	end
	if low.X == math.huge then
		model:Destroy()
		return
	end
	model.Parent = slot.vp
	local cam = make("Camera", { FieldOfView = 30 }, slot.vp)
	slot.vp.CurrentCamera = cam
	local extent = high - low
	slot.center = (low + high) / 2
	slot.dist = math.max(extent.X, extent.Y, extent.Z) * 0.66 / math.tan(math.rad(15))
	local front = model.PrimaryPart and model.PrimaryPart.CFrame.LookVector or Vector3.new(0, 0, -1)
	slot.yaw = math.atan2(front.X, front.Z)
	slot.cam = cam
	TweenService:Create(slot.scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

task.spawn(function()
	local previews = ReplicatedStorage:WaitForChild("AnimalPreviews", 25)
	if not previews then
		return
	end
	for i, name in ipairs(PARADE) do
		local source = previews:WaitForChild(name, 6)
		if source and gui.Parent then
			pcall(showAnimal, parade[i], source)
			task.wait(0.15)
		end
	end
end)

---------------------------------------------------------------- progress bar, tips, PLAY
local bottom = box({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.975), Size = UDim2.fromOffset(660, 140), BackgroundTransparency = 1, ZIndex = 30 }, root)
local bottomScale = make("UIScale", {}, bottom)
local track = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(330, 52), Size = UDim2.fromOffset(600, 44), BackgroundColor3 = Color3.fromRGB(18, 40, 60), BackgroundTransparency = 0.15, ZIndex = 30 }, bottom)
round(track)
border(track, 5)
local trackScale = make("UIScale", {}, track)
local fill = box({ Size = UDim2.fromScale(0, 1), ClipsDescendants = true, ZIndex = 31 }, track)
round(fill)
grad(fill, Color3.fromRGB(150, 255, 110), Color3.fromRGB(45, 200, 60), 90)
local fillShine = box({ Size = UDim2.new(0, 600, 1, 0), BackgroundColor3 = WHITE, ZIndex = 32 }, fill)
local fillShineGrad = make("UIGradient", {
	Rotation = 0,
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }),
	Offset = Vector2.new(-1, 0),
}, fillShine)
local fillTop = box({ Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.28), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, ZIndex = 33 }, fill)
round(fillTop)
local percent = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.62), Text = "LOADING… 0%", ZIndex = 34 }, track, 3)
local tip = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(330, 112), Size = UDim2.fromOffset(640, 30), Text = TIPS[1], ZIndex = 30 }, bottom, 3)

local play = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(330, 60), Size = UDim2.fromOffset(300, 86), BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 40 }, bottom)
round(play, UDim.new(0.28, 0))
border(play, 6)
grad(play, Color3.fromRGB(130, 255, 90), Color3.fromRGB(40, 190, 50), 90)
local playTop = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.08), Size = UDim2.fromScale(0.9, 0.32), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, ZIndex = 41 }, play)
round(playTop, UDim.new(0.5, 0))
text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.8, 0.62), Text = "▶  PLAY", ZIndex = 42 }, play, 5)
local playScale = make("UIScale", { Scale = 0 }, play)

-- SKIP: small corner button, there from the start, for anyone who wants to jump straight in
local skip = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 64), Size = UDim2.fromOffset(150, 48), BackgroundColor3 = Color3.fromRGB(18, 40, 60), BackgroundTransparency = 0.15, AutoButtonColor = true, Text = "", ZIndex = 50 }, root)
round(skip, UDim.new(0.3, 0))
border(skip, 4)
text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.78, 0.56), Text = "SKIP  ⏭", ZIndex = 51 }, skip, 3)
local skipScale = make("UIScale", {}, skip)

local function layout()
	local size = root.AbsoluteSize
	if size.X < 10 then
		return
	end
	local s = math.clamp(math.min(size.X / 1100, size.Y / 820), 0.4, 1.5)
	stageScale.Scale = s
	bottomScale.Scale = s
	skipScale.Scale = math.max(s, 0.7)
end
layout()
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

---------------------------------------------------------------- intro
local function pop(scale, delay, target)
	task.delay(delay, function()
		TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target or 1 }):Play()
	end)
end
pop(badgeScale, 0.15)
pop(titleScale, 0.35)
pop(ribbonScale, 0.6)

---------------------------------------------------------------- loading + animation
local start = os.clock()
local preloaded = false
local maxQueue = 1
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local items = {}
	local ui = playerGui:WaitForChild("GameUI", 10)
	if ui then
		table.insert(items, ui)
	end
	pcall(function()
		ContentProvider:PreloadAsync(items)
	end)
	preloaded = true
end)

local shown = 0
local ready = false
local readyAt = nil
local finished = false
local tipIndex, nextTip = 1, start + 3.4

local function finish(force) -- force = SKIP (works before loading is done too)
	if finished or (not ready and not force) then
		return
	end
	finished = true
	skip.Visible = false
	local audio = ReplicatedStorage:FindFirstChild("GameAudio")
	local sound = audio and audio:FindFirstChild("SpeedUpgrade")
	if sound then
		local c = sound:Clone()
		c.Parent = workspace
		c:Play()
		game:GetService("Debris"):AddItem(c, 4)
	end
	TweenService:Create(playScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = 0.85 }):Play()
	TweenService:Create(logoScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 1.3 }):Play()
	local flash = box({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 253, 240), BackgroundTransparency = 1, ZIndex = 200 }, gui)
	local fadeIn = TweenService:Create(flash, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Wait()
	root:Destroy()
	local fadeOut = TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	gui:Destroy()
end
play.Activated:Connect(function()
	finish(false)
end)
skip.Activated:Connect(function()
	finish(true)
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		finish(false)
	end
end)

local function setReady()
	ready = true
	readyAt = os.clock()
	percent.Text = "READY!"
	TweenService:Create(trackScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.delay(0.2, function()
		play.Visible = true
		TweenService:Create(playScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	tip.Text = "Press PLAY to start hunting!"
end

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not root.Parent then
		connection:Disconnect()
		return
	end
	local now = os.clock()
	local t = now - start

	-- sky
	for i, r in ipairs(rays) do
		r.Rotation = i * 20 + t * 5
	end
	for i, g in ipairs(glows) do
		g.frame.BackgroundTransparency = g.base + 0.04 * math.sin(t * 1.6 + i)
	end
	for _, c in ipairs(clouds) do
		c.x += c.speed * dt
		if c.x > 1.25 then
			c.x = -0.25
		end
		c.frame.Position = UDim2.fromScale(c.x, c.y + 0.006 * math.sin(t * 0.7 + c.y * 20))
	end
	for _, s in ipairs(sparkles) do
		s.y -= s.speed * dt
		if s.y < 0.02 then
			s.y = 0.62
			s.x = rng:NextNumber(0.03, 0.97)
		end
		s.label.Position = UDim2.fromScale(s.x, s.y)
		s.label.BackgroundTransparency = 0.25 + 0.65 * (0.5 + 0.5 * math.sin(t * 2.4 + s.phase))
		s.label.Rotation = t * 40 + s.phase * 30
	end

	-- logo
	logo.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2) * 6)
	if not finished then
		badge.Rotation = math.sin(t * 1.3) * 6
	end
	local wobble = -3 + math.sin(t * 1.7) * 1.6
	main.Rotation, mainShadow.Rotation, shine.Rotation = wobble, wobble, wobble
	local sweep = (t % 3.2) / 1.1 -- the shine crosses in ~1.1 s, then rests
	shineGrad.Offset = Vector2.new(math.min(sweep, 1) * 2 - 1, 0)

	-- parade: each animal turns a little left and right and hops gently
	for _, slot in ipairs(parade) do
		if slot.cam then
			local a = slot.yaw + 0.55 + math.sin(t * 0.9 + slot.phase) * 0.8
			local dir = Vector3.new(math.sin(a), 0.32, math.cos(a)).Unit
			slot.cam.CFrame = CFrame.lookAt(slot.center + dir * slot.dist, slot.center)
			slot.holder.Position = UDim2.fromOffset(slot.holder.Position.X.Offset, slot.y - math.abs(math.sin(t * 2.2 + slot.phase)) * 10)
		end
	end

	-- loading progress
	if not ready then
		local assets
		if preloaded then
			assets = 1
		else
			local q = ContentProvider.RequestQueueSize
			maxQueue = math.max(maxQueue, q)
			assets = (game:IsLoaded() and 0.55 or 0.2) + 0.35 * (1 - q / maxQueue)
		end
		if t > MAX_WAIT then
			assets = 1
		end
		local target = math.min(assets, t / MIN_TIME)
		shown = math.max(shown, shown + (target - shown) * math.min(1, dt * 5))
		fill.Size = UDim2.fromScale(math.max(shown, 0.06), 1)
		percent.Text = string.format("LOADING… %d%%", math.floor(shown * 100 + 0.5))
		fillShineGrad.Offset = Vector2.new(((t * 0.8) % 1.6) * 2 - 1.6, 0)
		if now > nextTip then
			nextTip = now + 3.4
			tipIndex = tipIndex % #TIPS + 1
			tip.Text = TIPS[tipIndex]
		end
		if assets >= 1 and shown > 0.985 then
			fill.Size = UDim2.fromScale(1, 1)
			percent.Text = "LOADING… 100%"
			setReady()
		end
	elseif not finished then
		if now - readyAt > 0.8 then -- after the pop-in
			playScale.Scale = 1 + 0.05 * math.sin((now - readyAt) * 5)
		end
		if now - readyAt > AUTO_PLAY then
			finish(false)
		end
	end
end)
