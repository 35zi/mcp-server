-- BuildWorldAnimals (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- Builds the animals that have no model yet, from Parts in the same chunky style as the Bunny (feet on Y = 0,
-- facing -Z, PrimaryPart = Body), straight into ServerStorage.AnimalTemplates (replacing an older copy):
--   * Fox     (World 1, Legendary): orange with white chest/cheeks/tail tip, dark socks and ear tips, bushy tail
--   * Turkey  (World 2, Uncommon):  round brown body, striped wings, blue head with red wattle, big feather fan
-- Swap them for Blender meshes later: any Model with the same name, a <Name>_Body / Body part and -Z front works.
local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local rec = CHS:TryBeginRecording("Build Fox + Turkey")

local templates = ServerStorage:FindFirstChild("AnimalTemplates")
if not templates then
	templates = Instance.new("Folder")
	templates.Name = "AnimalTemplates"
	templates.Parent = ServerStorage
end

local function newModel(name)
	local old = templates:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = name
	return model
end

-- a block: name, colour, centre CFrame (or x, y, z), size
local function block(model, name, hex, cf, w, h, d)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = Color3.fromHex(hex)
	p.Size = Vector3.new(w, h, d)
	p.CFrame = cf
	p.Parent = model
	return p
end

local function at(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

---------------------------------------------------------------- Fox
do
	local m = newModel("Fox")
	local ORANGE, DEEP, WHITE, SOCK, BLACK = "#e8772e", "#c95f1f", "#fbf4ea", "#3b2a24", "#1b1b20"
	-- legs with dark socks
	for _, leg in ipairs({ { 0.85, -1.5 }, { -0.85, -1.5 }, { 0.85, 1.7 }, { -0.85, 1.7 } }) do
		block(m, "Leg", ORANGE, at(leg[1], 1.45, leg[2]), 0.8, 1.0, 0.8)
		block(m, "Sock", SOCK, at(leg[1], 0.5, leg[2]), 0.82, 1.0, 0.82)
	end
	local body = block(m, "Body", ORANGE, at(0, 2.75, 0.1), 2.4, 2.1, 4.6)
	block(m, "Back", DEEP, at(0, 3.82, 0.3), 1.9, 0.12, 3.8)
	block(m, "Belly", WHITE, at(0, 1.72, -0.2), 1.8, 0.1, 3.4)
	block(m, "Chest", WHITE, at(0, 2.6, -2.16), 1.8, 1.7, 0.4)
	-- head
	block(m, "Head", ORANGE, at(0, 4.3, -2.45), 2.6, 2.1, 2.1)
	block(m, "CheekL", WHITE, at(1.2, 3.75, -2.75), 0.6, 1.0, 1.4)
	block(m, "CheekR", WHITE, at(-1.2, 3.75, -2.75), 0.6, 1.0, 1.4)
	block(m, "Snout", ORANGE, at(0, 3.95, -4.05), 1.2, 0.85, 1.3)
	block(m, "Jaw", WHITE, at(0, 3.45, -3.95), 1.1, 0.35, 1.15)
	block(m, "Nose", BLACK, at(0, 4.18, -4.75), 0.5, 0.4, 0.2)
	block(m, "EyeL", BLACK, at(0.62, 4.65, -3.52), 0.42, 0.6, 0.1)
	block(m, "EyeR", BLACK, at(-0.62, 4.65, -3.52), 0.42, 0.6, 0.1)
	block(m, "EyeShineL", WHITE, at(0.7, 4.8, -3.58), 0.14, 0.18, 0.05)
	block(m, "EyeShineR", WHITE, at(-0.54, 4.8, -3.58), 0.14, 0.18, 0.05)
	-- ears: orange outside, dark tip, soft inside
	for _, side in ipairs({ 1, -1 }) do
		local ear = at(0.82 * side, 5.95, -2.25, 0, 0, -10 * side)
		block(m, "Ear", ORANGE, ear, 0.85, 1.4, 0.45)
		block(m, "EarTip", SOCK, ear * CFrame.new(0, 0.85, 0), 0.86, 0.35, 0.46)
		block(m, "EarInner", "#f6d7c3", ear * CFrame.new(0, -0.1, -0.24), 0.45, 0.9, 0.05)
	end
	-- big bushy tail lifted behind, white tip
	local tail = CFrame.new(0, 3.3, 2.75) * CFrame.Angles(math.rad(-28), 0, 0)
	block(m, "Tail", ORANGE, tail * CFrame.new(0, 0, 0.9), 1.5, 1.5, 2.6)
	block(m, "TailFluff", DEEP, tail * CFrame.new(0, 0.55, 0.9), 1.2, 0.5, 2.2)
	block(m, "TailTip", WHITE, tail * CFrame.new(0, 0, 2.6), 1.3, 1.3, 0.9)
	m.PrimaryPart = body
	m.Parent = templates
end

---------------------------------------------------------------- Turkey
do
	local m = newModel("Turkey")
	local BROWN, DARK, BAND, CREAM, LEG = "#6b4a2f", "#4a3221", "#9a6436", "#f1dcae", "#e3a256"
	local HEAD, RED, BEAK, BLACK = "#9ec3e6", "#d6332b", "#f2c14e", "#1b1b20"
	for _, side in ipairs({ 1, -1 }) do
		block(m, "Leg", LEG, at(0.6 * side, 0.85, 0.3), 0.35, 1.5, 0.35)
		block(m, "Foot", LEG, at(0.6 * side, 0.1, 0.05), 0.75, 0.2, 0.9)
	end
	local body = block(m, "Body", BROWN, at(0, 2.75, 0.3), 2.8, 2.5, 3.1)
	block(m, "Breast", DARK, at(0, 2.6, -1.35), 2.3, 2.0, 0.7)
	block(m, "Bottom", DARK, at(0, 1.55, 0.3), 2.2, 0.2, 2.6)
	for _, side in ipairs({ 1, -1 }) do
		block(m, "Wing", DARK, at(1.5 * side, 2.85, 0.45), 0.35, 1.8, 2.5)
		block(m, "WingBar", CREAM, at(1.53 * side, 2.35, 0.45), 0.35, 0.22, 2.3)
		block(m, "WingBar2", CREAM, at(1.53 * side, 2.85, 0.45), 0.35, 0.18, 2.3)
	end
	-- neck, head, beak, snood and wattle
	block(m, "Neck", "#d48f8f", at(0, 4.35, -1.3), 0.8, 1.4, 0.8)
	block(m, "Head", HEAD, at(0, 5.25, -1.45), 1.0, 1.0, 1.15)
	block(m, "Beak", BEAK, at(0, 5.2, -2.2), 0.36, 0.3, 0.5)
	block(m, "Snood", RED, at(0, 4.9, -2.15), 0.18, 0.75, 0.18)
	block(m, "Wattle", RED, at(0, 4.5, -1.78), 0.55, 0.8, 0.35)
	block(m, "EyeL", BLACK, at(0.51, 5.4, -1.7), 0.05, 0.26, 0.26)
	block(m, "EyeR", BLACK, at(-0.51, 5.4, -1.7), 0.05, 0.26, 0.26)
	-- tail fan: feathers spread in a half circle, leaning back, each with a dark band and a cream tip
	local base = CFrame.new(0, 3.2, 1.75) * CFrame.Angles(math.rad(15), 0, 0)
	local count = 9
	for i = 1, count do
		local angle = math.rad(-78 + 156 * (i - 1) / (count - 1))
		local z = 0.03 * math.abs(i - (count + 1) / 2) -- outer feathers sit a hair behind, no flicker
		local feather = base * CFrame.Angles(0, 0, angle)
		block(m, "Feather", i % 2 == 0 and BAND or BROWN, feather * CFrame.new(0, 2.0, z), 1.0, 3.0, 0.22)
		block(m, "FeatherBand", BLACK, feather * CFrame.new(0, 3.2, z - 0.01), 1.0, 0.28, 0.24)
		block(m, "FeatherTip", CREAM, feather * CFrame.new(0, 3.6, z - 0.01), 1.0, 0.5, 0.24)
	end
	m.PrimaryPart = body
	m.Parent = templates
end

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return "built Fox (" .. #templates.Fox:GetChildren() .. " parts) and Turkey (" .. #templates.Turkey:GetChildren() .. " parts)"
