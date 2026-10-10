-- LoadingScreen (LocalScript in ReplicatedFirst)
--
-- Grow a Garden style: a black screen with the logo in the middle, one tip at the bottom and a small
-- "Loading 84/412" counter in the corner.
--   * logo: classic studded bricks. "SHOOT AN" in white bricks (the second O is a red crosshair), "ANIMAL" in green
--     bricks. Letters pop in one by one, sit a little crooked like hand-made letters and sway gently.
--   * tip: one line, a coloured keyword ("Gold animals are rare, but valuable!"), a new one every few seconds.
--   * counter: the real number of assets (meshes, images, sounds, animations...) this client preloads, counting up.
-- Enters the game by itself once the assets and the character are ready (at least MIN_TIME, at most MAX_WAIT).
-- A small "Skip" shows up after SKIP_AFTER seconds.
-- Pure UI, no uploaded images, so it shows instantly. Testing tip: Workspace attribute SkipLoadingScreen = true skips it.
-- Other scripts look for PlayerGui.LoadingScreen (FeedbackClient mutes music, TutorialClient waits): keep that name.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if workspace:GetAttribute("SkipLoadingScreen") then
	return
end

local MIN_TIME = 3 -- seconds the logo is on screen at least
local MAX_WAIT = 30 -- enter the game after this many seconds even if assets are still loading
local SKIP_AFTER = 6
local TIP_TIME = 3.6
local WHITE = Color3.new(1, 1, 1)

local TIPS = {
	'<font color="#FFD23F">Gold</font> animals are rare, but valuable!',
	'Shoot an animal to <font color="#7CF06A">stun</font> it, then carry it home!',
	'<font color="#FF78DC">Secret</font> animals are announced to the whole server!',
	'Heavy animals need <font color="#5FD7FF">Stamina</font>. Train on your treadmill!',
	'Every 5 minutes the <font color="#B48CFF">Night Hunt</font> begins!',
	'Pets in your pen earn <font color="#7CF06A">cash</font> every second!',
	'<font color="#FFB23F">Trails</font> make you train faster!',
	'<font color="#C9D2DC">Silver</font> animals are tougher to stun!',
}

local rng = Random.new()

local function make(class, props, parent)
	local x = Instance.new(class)
	for k, v in pairs(props) do
		x[k] = v
	end
	x.Parent = parent
	return x
end
local function round(obj)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, obj)
end

---------------------------------------------------------------- screen
local gui = make("ScreenGui", {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
-- one CanvasGroup so the whole screen can fade out together
local root = make("CanvasGroup", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	Active = true,
}, gui)

---------------------------------------------------------------- studded brick logo
-- Bold 7-row brick font (2-brick strokes): "#" = a brick in the line's colour, "r" / "w" = red / white.
-- The crosshair is 9 rows, so it hangs over the line like the pot in the Grow a Garden logo.
local GLYPHS = {
	S = { " #####", "##    ", "##    ", " #### ", "    ##", "    ##", "##### " },
	H = { "##  ##", "##  ##", "##  ##", "######", "##  ##", "##  ##", "##  ##" },
	T = { "######", "  ##  ", "  ##  ", "  ##  ", "  ##  ", "  ##  ", "  ##  " },
	A = { " #### ", "##  ##", "##  ##", "######", "##  ##", "##  ##", "##  ##" },
	N = { "##  ##", "### ##", "### ##", "######", "## ###", "## ###", "##  ##" },
	I = { "####", " ## ", " ## ", " ## ", " ## ", " ## ", "####" },
	M = { "##   ##", "### ###", "#######", "## # ##", "##   ##", "##   ##", "##   ##" },
	L = { "##    ", "##    ", "##    ", "##    ", "##    ", "##    ", "######" },
	O = { " #### ", "##  ##", "##  ##", "##  ##", "##  ##", "##  ##", " #### " },
	[" "] = { "  ", "  ", "  ", "  ", "  ", "  ", "  " },
	Scope = {
		"  rrrrr  ",
		" rr   rr ",
		"rr  w  rr",
		"r   w   r",
		"r wwwww r",
		"r   w   r",
		"rr  w  rr",
		" rr   rr ",
		"  rrrrr  ",
	},
}
local PALETTES = {
	white = { base = Color3.fromRGB(242, 242, 238), shade = Color3.fromRGB(176, 176, 170), stud = Color3.fromRGB(255, 255, 255), studShade = Color3.fromRGB(196, 196, 190) },
	green = { base = Color3.fromRGB(88, 206, 82), shade = Color3.fromRGB(46, 132, 48), stud = Color3.fromRGB(128, 232, 114), studShade = Color3.fromRGB(56, 156, 56) },
	red = { base = Color3.fromRGB(232, 62, 54), shade = Color3.fromRGB(150, 30, 30), stud = Color3.fromRGB(255, 112, 100), studShade = Color3.fromRGB(168, 38, 36) },
}

-- one classic brick: darker edge at the bottom/right, the face, and a round stud with its shadow
local function brick(parent, x, y, size, palette)
	local jitter = rng:NextNumber(-0.05, 0.05) -- tiny colour differences, like real bricks
	local function tint(c)
		return jitter > 0 and c:Lerp(WHITE, jitter) or c:Lerp(Color3.new(0, 0, 0), -jitter)
	end
	local edge = make("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size - 1, size - 1),
		BackgroundColor3 = tint(palette.shade),
		BorderSizePixel = 0,
	}, parent)
	local face = make("Frame", {
		Size = UDim2.new(1, -2, 1, -3),
		BackgroundColor3 = tint(palette.base),
		BorderSizePixel = 0,
	}, edge)
	local studShadow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 1, 0.5, 1),
		Size = UDim2.fromScale(0.58, 0.58),
		BackgroundColor3 = tint(palette.studShade),
		BorderSizePixel = 0,
	}, face)
	round(studShadow)
	local stud = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -1, 0.5, -1),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = tint(palette.stud),
		BorderSizePixel = 0,
	}, face)
	round(stud)
end

local LINE1_CELL, LINE2_CELL, LINE_GAP = 14, 19, 18
local LOGO_W = 800
local LOGO_H = 7 * LINE1_CELL + LINE_GAP + 7 * LINE2_CELL
local logo = make("Frame", {
	Name = "Logo",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(LOGO_W, LOGO_H),
	BackgroundTransparency = 1,
}, root)
local logoFit = make("UIScale", {}, logo)
local inner = make("Frame", { Name = "Inner", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, logo)
local breathe = make("UIScale", {}, inner)

local letters = {}
local function line(word, cell, paletteName, top)
	local glyphs = {}
	local width = 0
	for _, key in ipairs(word) do
		local rows = GLYPHS[key]
		table.insert(glyphs, { key = key, rows = rows, w = #rows[1] })
		width += #rows[1] * cell
	end
	width += (#glyphs - 1) * cell -- one empty column between letters
	local x = (LOGO_W - width) / 2
	for _, g in ipairs(glyphs) do
		local w, h = g.w * cell, #g.rows * cell
		if g.key ~= " " then
			local scope = g.key == "Scope"
			local holder = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(w, h),
				BackgroundTransparency = 1,
			}, inner)
			for r, row in ipairs(g.rows) do
				for c = 1, #row do
					local ch = row:sub(c, c)
					if ch ~= " " then
						local palette = ch == "r" and PALETTES.red or ch == "w" and PALETTES.white or PALETTES[paletteName]
						brick(holder, (c - 1) * cell, (r - 1) * cell, cell, palette)
					end
				end
			end
			local letter = {
				holder = holder,
				scale = make("UIScale", { Scale = 0 }, holder),
				x = x + w / 2,
				y = top + 3.5 * cell + (scope and -3 or rng:NextNumber(-4, 4)), -- centred on the line
				rotation = scope and -10 or rng:NextNumber(-5, 5),
				size = scope and 1.05 or 1,
				phase = #letters * 0.55,
			}
			holder.Position = UDim2.fromOffset(letter.x, letter.y)
			holder.Rotation = letter.rotation
			table.insert(letters, letter)
		end
		x += w + cell
	end
end
line({ "S", "H", "O", "Scope", "T", " ", "A", "N" }, LINE1_CELL, "white", 0)
line({ "A", "N", "I", "M", "A", "L" }, LINE2_CELL, "green", 7 * LINE1_CELL + LINE_GAP)

---------------------------------------------------------------- tip + counter + skip
local tip = make("TextLabel", {
	Name = "Tip",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.885),
	Size = UDim2.new(0.9, 0, 0, 36),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	RichText = true,
	TextScaled = true,
	TextColor3 = WHITE,
	TextTransparency = 1,
	Text = TIPS[1],
}, root)
make("UITextSizeConstraint", { MinTextSize = 14, MaxTextSize = 30 }, tip)

local counter = make("TextLabel", {
	Name = "Counter",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -10),
	Size = UDim2.fromOffset(320, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = WHITE,
	TextTransparency = 0.15,
	Text = "Loading...",
}, root)

local skip = make("TextButton", {
	Name = "Skip",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, -8),
	Size = UDim2.fromOffset(70, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = WHITE,
	TextTransparency = 1,
	Text = "Skip  ›",
	Visible = false,
}, root)

local function layout()
	local size = root.AbsoluteSize
	if size.X < 10 then
		return
	end
	logoFit.Scale = math.clamp(math.min(size.X * 0.66 / LOGO_W, size.Y * 0.4 / LOGO_H), 0.3, 1.6)
end
layout()
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

---------------------------------------------------------------- intro: letters pop in one by one
for i, letter in ipairs(letters) do
	task.delay(0.15 + i * 0.06, function()
		TweenService:Create(letter.scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = letter.size }):Play()
	end)
end
task.delay(0.15 + #letters * 0.06 + 0.2, function()
	TweenService:Create(tip, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
end)

---------------------------------------------------------------- real asset preloading (counted for the corner)
-- every remote content id the client can see; local rbxasset:// files are instant and not counted
local CONTENT = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	Sound = { "SoundId" },
	Animation = { "AnimationId" },
	ParticleEmitter = { "Texture" },
	Beam = { "Texture" },
	Trail = { "Texture" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	MaterialVariant = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	Shirt = { "ShirtTemplate" },
	Pants = { "PantsTemplate" },
	ShirtGraphic = { "Graphic" },
	Tool = { "TextureId" },
}
local function remoteId(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if value:find("rbxassetid://", 1, true) or value:find("roblox.com/asset", 1, true) or value:match("^%d+$") then
		return value
	end
	return nil
end
local total, loaded = nil, 0
local preloaded = false
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local seen, list = {}, {}
	local sources = {
		workspace,
		ReplicatedStorage,
		game:GetService("Lighting"),
		game:GetService("SoundService"),
		game:GetService("MaterialService"),
		game:GetService("StarterGui"),
		ReplicatedFirst,
	}
	local visited = 0
	for _, source in ipairs(sources) do
		for _, inst in ipairs(source:GetDescendants()) do
			local properties = CONTENT[inst.ClassName]
			if properties then
				for _, property in ipairs(properties) do
					local ok, value = pcall(function()
						return inst[property]
					end)
					local id = ok and remoteId(value)
					if id and not seen[id] then
						seen[id] = true
						table.insert(list, id)
					end
				end
			end
			visited += 1
			if visited % 3000 == 0 then
				task.wait()
			end
		end
	end
	total = #list
	pcall(function()
		ContentProvider:PreloadAsync(list, function()
			loaded += 1
		end)
	end)
	loaded = total
	preloaded = true
end)

---------------------------------------------------------------- enter the game
local start = os.clock()
local finished = false
local function finish()
	if finished then
		return
	end
	finished = true
	skip.Visible = false
	for i, letter in ipairs(letters) do
		task.delay((#letters - i) * 0.02, function()
			TweenService:Create(letter.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		end)
	end
	task.wait(0.2)
	local fade = TweenService:Create(root, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	gui:Destroy()
end
skip.Activated:Connect(function()
	task.spawn(finish)
end)

local tipIndex, nextTip = 1, start + TIP_TIME + 1
local function nextTipText()
	tipIndex = tipIndex % #TIPS + 1
	local out = TweenService:Create(tip, TweenInfo.new(0.25), { TextTransparency = 1 })
	out:Play()
	out.Completed:Once(function()
		tip.Text = TIPS[tipIndex]
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end)
end

local connection
connection = RunService.RenderStepped:Connect(function()
	if not gui.Parent then
		connection:Disconnect()
		return
	end
	local now = os.clock()
	local t = now - start

	-- the letters sway like hand-placed bricks; the whole logo breathes a little
	for _, letter in ipairs(letters) do
		letter.holder.Rotation = letter.rotation + math.sin(t * 1.6 + letter.phase) * 1.4
		letter.holder.Position = UDim2.fromOffset(letter.x, letter.y + math.sin(t * 2.1 + letter.phase) * 2.5)
	end
	breathe.Scale = 1 + 0.015 * math.sin(t * 1.4)

	if finished then
		return
	end
	if total then
		counter.Text = string.format("Loading %d/%d", math.min(loaded, total), total)
	end
	if now > nextTip then
		nextTip = now + TIP_TIME
		nextTipText()
	end
	if t > SKIP_AFTER and not skip.Visible then
		skip.Visible = true
		TweenService:Create(skip, TweenInfo.new(0.4), { TextTransparency = 0.25 }):Play()
	end
	local character = player.Character
	local ready = preloaded and character and character:FindFirstChild("HumanoidRootPart")
	if t >= MIN_TIME and (ready or t > MAX_WAIT) then
		task.spawn(finish)
	end
end)
