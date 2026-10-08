-- BuildDecor (run in Studio's command bar / via MCP, edit mode; safe to re-run: it rebuilds Workspace.Decor)
--
-- A few small blocky decorations, in the same chunky style as the animals:
--   * Workspace.Decor.Forest (World 1, the green floor past the red line): small round + pine trees, bushes with
--     berries, flower patches, rocks, a fallen log
--   * Workspace.Decor.Desert (World 2, the gold floor): cacti, sandstone rocks, dry bushes, a cow skull
-- Trees, cacti and rocks are solid; bushes and flowers you can walk through. AnimalManager keeps animals from
-- spawning on top of decorations and they walk around them (Workspace.Decor).
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build decor")
local rng = Random.new(20261008) -- fixed seed: the same layout every time
local FLOOR_Y = 2 -- top of the world floors

local old = workspace:FindFirstChild("Decor")
if old then
	old:Destroy()
end
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = workspace
local forest = Instance.new("Folder")
forest.Name = "Forest"
forest.Parent = decor
local desert = Instance.new("Folder")
desert.Name = "Desert"
desert.Parent = decor

-- a block in a model: colour, centre (relative to the model's base CFrame), size, solid?
local function block(model, base, hex, offset, size, solid)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = Color3.fromHex(hex)
	p.Size = size
	p.CFrame = base * offset
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CanQuery = solid ~= "ghost" -- tiny things (flowers) don't stop bullets or animals
	p.Parent = model
	return p
end

local function newModel(folder, name, x, z, scale)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	local base = CFrame.new(x, FLOOR_Y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	return model, base, scale or 1
end

local function at(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

---------------------------------------------------------------- forest pieces
local LEAVES = { "#3fa34d", "#4cbb5a", "#5fcf6a" }
local PINE = { "#2f7d3e", "#38914a", "#43a656" }

local function roundTree(x, z, s)
	local m, b = newModel(forest, "Tree", x, z)
	block(m, b, "#7a4f2b", at(0, 2 * s, 0), Vector3.new(1.2, 4, 1.2) * s, true)
	block(m, b, LEAVES[1], at(0, 5.6 * s, 0), Vector3.new(5, 3, 5) * s, true)
	block(m, b, LEAVES[2], at(0.3 * s, 7.6 * s, -0.2 * s, 0, 20, 0), Vector3.new(3.8, 2, 3.8) * s, true)
	block(m, b, LEAVES[3], at(-0.2 * s, 9.1 * s, 0.2 * s, 0, 45, 0), Vector3.new(2.4, 1.4, 2.4) * s, true)
	m.PrimaryPart = m:GetChildren()[1]
end

local function pineTree(x, z, s)
	local m, b = newModel(forest, "PineTree", x, z)
	block(m, b, "#6b4426", at(0, 1.5 * s, 0), Vector3.new(1, 3, 1) * s, true)
	block(m, b, PINE[1], at(0, 3.8 * s, 0), Vector3.new(4.6, 1.8, 4.6) * s, true)
	block(m, b, PINE[2], at(0, 5.4 * s, 0, 0, 45, 0), Vector3.new(3.4, 1.6, 3.4) * s, true)
	block(m, b, PINE[3], at(0, 6.8 * s, 0), Vector3.new(2.2, 1.4, 2.2) * s, true)
	block(m, b, PINE[2], at(0, 7.9 * s, 0, 0, 45, 0), Vector3.new(1, 1, 1) * s, true)
	m.PrimaryPart = m:GetChildren()[1]
end

local function bush(x, z, s)
	local m, b = newModel(forest, "Bush", x, z)
	block(m, b, LEAVES[1], at(0, 0.8 * s, 0), Vector3.new(2.4, 1.6, 2.2) * s)
	block(m, b, LEAVES[2], at(1.1 * s, 0.6 * s, 0.5 * s, 0, 25, 0), Vector3.new(1.6, 1.2, 1.6) * s)
	block(m, b, LEAVES[3], at(-0.9 * s, 0.7 * s, -0.6 * s, 0, 40, 0), Vector3.new(1.5, 1.3, 1.5) * s)
	for i = 1, 3 do
		local a = i * 2.1
		block(m, b, "#e0413a", at(math.cos(a) * 1.05 * s, (1.1 + 0.25 * i) * s * 0.6, math.sin(a) * 1.05 * s), Vector3.new(0.35, 0.35, 0.35) * s)
	end
	m.PrimaryPart = m:GetChildren()[1]
end

local FLOWER_COLOURS = { "#ff7eb6", "#ffd23f", "#ffffff", "#b07cff", "#ff8c42" }
local function flowers(x, z)
	local m, b = newModel(forest, "Flowers", x, z)
	for _ = 1, 4 do
		local ox, oz = rng:NextNumber(-1.4, 1.4), rng:NextNumber(-1.4, 1.4)
		local h = rng:NextNumber(0.6, 1)
		block(m, b, "#3c9a44", at(ox, h / 2, oz), Vector3.new(0.14, h, 0.14), "ghost")
		block(m, b, FLOWER_COLOURS[rng:NextInteger(1, #FLOWER_COLOURS)], at(ox, h + 0.1, oz, 0, 45, 0), Vector3.new(0.55, 0.22, 0.55), "ghost")
		block(m, b, "#ffe066", at(ox, h + 0.2, oz), Vector3.new(0.22, 0.1, 0.22), "ghost")
	end
	m.PrimaryPart = m:GetChildren()[1]
end

local function rock(folder, x, z, s, colours)
	local m, b = newModel(folder, "Rock", x, z)
	block(m, b, colours[1], at(0, 0.7 * s, 0, 0, 0, 8), Vector3.new(2.4, 1.6, 2) * s, true)
	block(m, b, colours[2], at(1.2 * s, 0.45 * s, 0.6 * s, 0, 30, -6), Vector3.new(1.3, 1, 1.2) * s, true)
	block(m, b, colours[1], at(-1 * s, 0.35 * s, -0.5 * s, 0, 60, 0), Vector3.new(1, 0.8, 1) * s, true)
	m.PrimaryPart = m:GetChildren()[1]
end

local function log(x, z)
	local m, b = newModel(forest, "Log", x, z)
	local trunk = Instance.new("Part")
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Anchored = true
	trunk.Material = Enum.Material.Plastic
	trunk.Color = Color3.fromHex("#7a4f2b")
	trunk.Size = Vector3.new(5, 1.3, 1.3)
	trunk.CFrame = b * CFrame.new(0, 0.65, 0)
	trunk.CanTouch = false
	trunk.Parent = m
	block(m, b, "#c8935a", at(2.52, 0.65, 0, 0, 0, 0), Vector3.new(0.06, 1.1, 1.1))
	block(m, b, "#c8935a", at(-2.52, 0.65, 0, 0, 0, 0), Vector3.new(0.06, 1.1, 1.1))
	block(m, b, LEAVES[2], at(0.6, 1.35, 0.1, 0, 20, 0), Vector3.new(0.7, 0.3, 0.6))
	m.PrimaryPart = trunk
end

---------------------------------------------------------------- desert pieces
local CACTUS, CACTUS_DARK = "#4f9d4a", "#3f8a3c"
local SANDSTONE = { "#c99a5b", "#b5834a" }

local function cactus(x, z, s)
	local m, b = newModel(desert, "Cactus", x, z)
	block(m, b, CACTUS, at(0, 3 * s, 0), Vector3.new(1.4, 6, 1.4) * s, true)
	block(m, b, CACTUS_DARK, at(0, 3 * s, 0), Vector3.new(1.0, 6.1, 1.5) * s, true) -- ribs
	-- left arm
	block(m, b, CACTUS, at(-1.2 * s, 2.8 * s, 0), Vector3.new(1.2, 0.9, 0.9) * s, true)
	block(m, b, CACTUS, at(-1.75 * s, 3.9 * s, 0), Vector3.new(0.9, 2.2, 0.9) * s, true)
	-- right arm (higher)
	block(m, b, CACTUS, at(1.2 * s, 3.9 * s, 0), Vector3.new(1.2, 0.9, 0.9) * s, true)
	block(m, b, CACTUS, at(1.75 * s, 4.8 * s, 0), Vector3.new(0.9, 1.9, 0.9) * s, true)
	block(m, b, "#ff7eb6", at(0, 6.15 * s, 0, 0, 45, 0), Vector3.new(0.6, 0.3, 0.6) * s, "ghost")
	m.PrimaryPart = m:GetChildren()[1]
end

local function dryBush(x, z)
	local m, b = newModel(desert, "DryBush", x, z)
	for i = 1, 7 do
		local yaw = i * 360 / 7
		local tilt = rng:NextNumber(25, 55)
		block(m, b, i % 2 == 0 and "#8a6a3d" or "#a07c48", CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, 0.7, 0), Vector3.new(0.14, 1.5, 0.14))
	end
	m.PrimaryPart = m:GetChildren()[1]
end

local function skull(x, z)
	local m, b = newModel(desert, "Skull", x, z)
	block(m, b, "#f2ead8", at(0, 0.55, 0), Vector3.new(1.3, 1.1, 1.2), true)
	block(m, b, "#e6dcc4", at(0, 0.35, -0.9), Vector3.new(0.9, 0.7, 0.8), true)
	block(m, b, "#2a2420", at(0.33, 0.7, -0.61), Vector3.new(0.3, 0.3, 0.05), true)
	block(m, b, "#2a2420", at(-0.33, 0.7, -0.61), Vector3.new(0.3, 0.3, 0.05), true)
	block(m, b, "#efe2c0", at(1.05, 1.0, 0.1, 0, 0, -35), Vector3.new(0.9, 0.3, 0.3), true)
	block(m, b, "#efe2c0", at(-1.05, 1.0, 0.1, 0, 0, 35), Vector3.new(0.9, 0.3, 0.3), true)
	m.PrimaryPart = m:GetChildren()[1]
end

---------------------------------------------------------------- layout (World 1: z -190 .. -86, World 2: z -347 .. -190, x -54 .. 56)
local GREY_ROCK = { "#8d929b", "#a3a8b1" }

roundTree(-47, -104, 1.0)
pineTree(49, -116, 1.1)
roundTree(-45, -160, 1.15)
pineTree(48, -176, 0.95)
roundTree(-18, -180, 0.9)
pineTree(24, -142, 1.0)
bush(-34, -97, 1)
bush(37, -101, 1.1)
bush(8, -162, 0.9)
bush(-28, -131, 1)
bush(44, -150, 0.95)
for _, p in ipairs({ { -10, -108 }, { 18, -120 }, { -38, -146 }, { 30, -170 }, { -5, -140 }, { 40, -128 } }) do
	flowers(p[1], p[2])
end
rock(forest, -10, -122, 0.9, GREY_ROCK)
rock(forest, 31, -186, 1.1, GREY_ROCK)
rock(forest, -50, -134, 1, GREY_ROCK)
log(12, -112)

cactus(-46, -212, 1.0)
cactus(47, -234, 1.15)
cactus(-40, -282, 0.9)
cactus(45, -302, 1.05)
cactus(-15, -332, 1.2)
cactus(20, -257, 0.85)
rock(desert, -25, -222, 1.1, SANDSTONE)
rock(desert, 30, -207, 0.9, SANDSTONE)
rock(desert, -48, -316, 1.3, SANDSTONE)
rock(desert, 10, -296, 1, SANDSTONE)
rock(desert, 48, -340, 1.2, SANDSTONE)
dryBush(0, -242)
dryBush(-30, -262)
dryBush(38, -272)
dryBush(-5, -312)
skull(25, -322)

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return string.format("Decor: %d forest pieces, %d desert pieces", #forest:GetChildren(), #desert:GetChildren())
