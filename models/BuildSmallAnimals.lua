-- Builds five small animals in the bunny's blocky plastic style: Frog, Mouse, Squirrel, Hedgehog, Duckling.
-- Studio: View > Command Bar, paste this whole file, press Enter. Re-running replaces Workspace.SmallAnimals.
-- Every animal is a Model of anchored Parts (PrimaryPart = Body), feet on y = 0 of its own frame, facing -Z
-- (like the Bunny). They are placed in a row near the far wall of the green area past the red line, facing the entrance.
-- Models only: no animation or AI yet.
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build small animals")

local old = workspace:FindFirstChild("SmallAnimals")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "SmallAnimals"

local V = Vector3.new
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local BK, WH, PINK = "#1b1b20", "#ffffff", "#ff9fb7"
local GROUND_Y = 2 -- top of the green ground slab in this place

-- newAnimal(name, x, z) -> model, part(name, size, localCentre, color, opts)
local function newAnimal(name, x, z)
	local model = Instance.new("Model")
	model.Name = name
	local BASE = CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, math.pi, 0) -- faces +Z (towards the entrance)
	local function part(pname, size, pos, color, opts)
		opts = opts or {}
		local p = Instance.new("Part")
		p.Name = pname
		p.Anchored = true
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = Color3.fromHex(color)
		p.Size = size
		p.CFrame = BASE * CFrame.new(pos) * CFrame.Angles(math.rad(opts.rx or 0), math.rad(opts.ry or 0), math.rad(opts.rz or 0))
		if opts.shape then p.Shape = opts.shape end
		if opts.noCollide then p.CanCollide = false end
		p.Parent = model
		return p
	end
	return model, part
end

local function finish(model)
	model.PrimaryPart = model:FindFirstChild("Body")
	model.Parent = folder
end

-- tiny helper: a pair of eyes (black blocks) on the head's front face
local function eyes(part, x, y, z, w, h)
	part("EyeL", V(w, h, 0.1), V(-x, y, z), BK, { noCollide = true })
	part("EyeR", V(w, h, 0.1), V(x, y, z), BK, { noCollide = true })
end

---------------------------------------------------------------- FROG
do
	local m, p = newAnimal("Frog", -30, -127)
	local G, G2, CR = "#5fbf3a", "#4aa52c", "#e9f3b0"
	p("Body", V(3.6, 2.2, 3.8), V(0, 1.9, 0.3), G)
	p("Belly", V(2.8, 0.9, 3.2), V(0, 1.0, 0.2), CR)
	p("Head", V(3.2, 1.5, 2.4), V(0, 2.5, -1.7), G)
	p("Mouth", V(2.6, 0.12, 0.1), V(0, 2.0, -2.92), BK, { noCollide = true })
	for _, s in ipairs({ -1, 1 }) do
		p("EyeBump", V(1.1, 1.1, 1.1), V(0.95 * s, 3.5, -1.2), G)
		p("EyeWhite", V(0.8, 0.8, 0.1), V(0.95 * s, 3.55, -1.78), WH, { noCollide = true })
		p("Pupil", V(0.4, 0.55, 0.1), V(0.95 * s, 3.5, -1.85), BK, { noCollide = true })
		p("Nostril", V(0.2, 0.2, 0.1), V(0.4 * s, 2.7, -2.92), BK, { noCollide = true })
		p("Cheek", V(0.5, 0.3, 0.1), V(1.2 * s, 2.25, -2.92), PINK, { noCollide = true })
		p("Thigh", V(1.0, 1.7, 2.4), V(2.1 * s, 1.4, 0.9), G2)
		p("HindFoot", V(1.4, 0.35, 2.4), V(2.3 * s, 0.18, -0.2), G2)
		p("Arm", V(0.8, 1.5, 0.8), V(1.3 * s, 0.95, -1.3), G2)
		p("Hand", V(1.1, 0.3, 1.1), V(1.3 * s, 0.15, -1.6), G2)
	end
	for _, s in ipairs({ { -0.8, 0.6 }, { 0.9, 1.2 }, { 0.1, -0.2 } }) do
		p("Spot", V(0.8, 0.15, 0.8), V(s[1], 3.05, s[2]), G2, { noCollide = true })
	end
	finish(m)
end

---------------------------------------------------------------- MOUSE
do
	local m, p = newAnimal("Mouse", -16, -127)
	local G = "#b9b9c2"
	p("Body", V(2.2, 1.8, 3.0), V(0, 1.2, 0.4), G)
	p("Head", V(1.8, 1.6, 1.8), V(0, 1.7, -1.7), G)
	p("Snout", V(0.9, 0.8, 0.9), V(0, 1.4, -2.8), G)
	p("Nose", V(0.45, 0.4, 0.25), V(0, 1.5, -3.3), PINK, { noCollide = true })
	p("Teeth", V(0.45, 0.3, 0.1), V(0, 1.0, -3.2), WH, { noCollide = true })
	eyes(p, 0.55, 2.0, -2.62, 0.3, 0.45)
	for _, s in ipairs({ -1, 1 }) do
		p("Ear", V(0.25, 1.6, 1.6), V(0.95 * s, 2.9, -1.4), G, { shape = CYL, ry = 90 })
		p("EarInner", V(0.2, 1.1, 1.1), V(0.95 * s, 2.9, -1.55), PINK, { shape = CYL, ry = 90, noCollide = true })
		p("WhiskerHigh", V(1.3, 0.05, 0.05), V(1.2 * s, 1.5, -3.0), WH, { rz = 10 * s, noCollide = true })
		p("WhiskerLow", V(1.3, 0.05, 0.05), V(1.2 * s, 1.25, -3.0), WH, { rz = -10 * s, noCollide = true })
		p("Foot", V(0.7, 0.35, 0.9), V(0.7 * s, 0.18, -0.7), PINK)
		p("HindFoot", V(0.7, 0.35, 0.9), V(0.8 * s, 0.18, 1.4), PINK)
		p("Hand", V(0.4, 0.7, 0.4), V(0.8 * s, 0.9, -1.0), PINK, { noCollide = true })
	end
	p("Tail1", V(0.25, 0.25, 1.0), V(0, 0.9, 2.4), PINK, { noCollide = true })
	p("Tail2", V(0.25, 0.25, 1.0), V(0, 0.9, 3.3), PINK, { noCollide = true })
	p("Tail3", V(0.25, 0.25, 1.0), V(0, 1.1, 4.1), PINK, { rx = -15, noCollide = true })
	p("Tail4", V(0.25, 0.25, 1.0), V(0, 1.5, 4.7), PINK, { rx = -35, noCollide = true })
	finish(m)
end

---------------------------------------------------------------- SQUIRREL
do
	local m, p = newAnimal("Squirrel", 14, -127)
	local O, O2, CR = "#c9733a", "#a85a28", "#f3e0c0"
	p("Body", V(2.2, 2.4, 2.6), V(0, 1.9, 0.3), O)
	p("Belly", V(1.5, 1.8, 0.1), V(0, 1.8, -1.03), CR, { noCollide = true })
	p("Head", V(1.9, 1.7, 1.8), V(0, 3.6, -1.2), O)
	p("Muzzle", V(1.1, 0.7, 0.6), V(0, 3.2, -2.2), CR)
	p("Nose", V(0.4, 0.3, 0.15), V(0, 3.4, -2.55), BK, { noCollide = true })
	eyes(p, 0.6, 3.9, -2.12, 0.3, 0.45)
	for _, s in ipairs({ -1, 1 }) do
		p("Cheek", V(0.45, 0.3, 0.1), V(0.85 * s, 3.4, -2.12), PINK, { noCollide = true })
		p("Ear", V(0.5, 0.9, 0.4), V(0.65 * s, 4.8, -1.0), O)
		p("EarTuft", V(0.3, 0.4, 0.3), V(0.65 * s, 5.4, -1.0), O2, { noCollide = true })
		p("Arm", V(0.5, 1.0, 0.5), V(0.65 * s, 1.9, -1.4), CR, { noCollide = true })
		p("Thigh", V(0.9, 1.2, 1.6), V(1.1 * s, 1.0, 0.5), O2)
		p("Foot", V(0.8, 0.35, 1.5), V(1.0 * s, 0.18, -0.5), CR)
	end
	p("Acorn", V(0.8, 0.8, 0.8), V(0, 2.2, -1.9), "#8a5a2b", { shape = BALL, noCollide = true })
	p("AcornCap", V(0.9, 0.35, 0.9), V(0, 2.6, -1.9), "#5f3b25", { noCollide = true })
	p("Tail1", V(1.5, 1.5, 1.4), V(0, 1.2, 2.2), O)
	p("Tail2", V(1.7, 2.0, 1.4), V(0, 2.7, 2.7), O)
	p("Tail3", V(1.8, 2.1, 1.4), V(0, 4.5, 2.8), O)
	p("TailTip", V(1.5, 1.5, 1.2), V(0, 5.9, 2.4), CR)
	p("TailStripe1", V(1.85, 0.3, 1.45), V(0, 3.7, 2.75), O2, { noCollide = true })
	p("TailStripe2", V(1.85, 0.3, 1.45), V(0, 5.3, 2.8), O2, { noCollide = true })
	finish(m)
end

---------------------------------------------------------------- HEDGEHOG
do
	local m, p = newAnimal("Hedgehog", 28, -127)
	local SP, SP2, FACE = "#6b4a3a", "#a07a5e", "#e6c9a0"
	p("Body", V(3.4, 2.4, 3.6), V(0, 1.6, 0.6), SP)
	p("Head", V(1.9, 1.5, 1.7), V(0, 1.2, -2.2), FACE)
	p("Snout", V(0.9, 0.8, 1.0), V(0, 1.0, -3.2), FACE)
	p("Nose", V(0.5, 0.5, 0.5), V(0, 1.15, -3.75), BK, { shape = BALL, noCollide = true })
	eyes(p, 0.6, 1.6, -3.04, 0.3, 0.45)
	for _, s in ipairs({ -1, 1 }) do
		p("Ear", V(0.5, 0.5, 0.35), V(0.8 * s, 2.1, -1.7), FACE)
		p("Foot", V(0.7, 0.35, 0.9), V(0.9 * s, 0.18, -1.5), FACE)
		p("HindFoot", V(0.7, 0.35, 0.9), V(0.9 * s, 0.18, 1.8), FACE)
		for iz = 0, 3 do
			p("SideSpike", V(0.4, 0.9, 0.4), V(1.9 * s, 2.5, -0.2 + iz * 1.0), (iz % 2 == 0) and SP2 or SP, { rz = -35 * s, noCollide = true })
		end
	end
	for iz = 0, 4 do
		for ix = -1, 1 do
			local x = ix * 1.05 + ((iz % 2 == 1) and 0.5 or 0)
			if math.abs(x) <= 1.4 then
				p("Spike", V(0.4, 1.0, 0.4), V(x, 3.2, -0.4 + iz * 0.8), (iz % 2 == 0) and SP2 or SP, { rx = 22, noCollide = true })
			end
		end
	end
	finish(m)
end

---------------------------------------------------------------- DUCKLING
do
	local m, p = newAnimal("Duckling", 42, -127)
	local Y, Y2, OR = "#ffd93d", "#f0b81f", "#ff8a1f"
	p("Body", V(2.6, 2.2, 3.0), V(0, 1.6, 0.5), Y)
	p("Head", V(2.0, 1.9, 2.0), V(0, 3.3, -0.9), Y)
	p("Beak", V(1.2, 0.4, 0.9), V(0, 3.0, -2.35), OR)
	p("HeadTuft", V(0.4, 0.6, 0.4), V(0, 4.4, -0.8), Y, { noCollide = true })
	eyes(p, 0.7, 3.6, -1.92, 0.3, 0.4)
	p("Tail", V(0.9, 0.7, 0.8), V(0, 2.5, 2.1), Y)
	for _, s in ipairs({ -1, 1 }) do
		p("Cheek", V(0.4, 0.3, 0.1), V(0.9 * s, 3.1, -1.92), PINK, { noCollide = true })
		p("Wing", V(0.4, 1.3, 1.7), V(1.5 * s, 1.7, 0.4), Y2)
		p("Leg", V(0.3, 0.5, 0.3), V(0.7 * s, 0.25, 0), OR, { noCollide = true })
		p("Foot", V(0.9, 0.15, 1.1), V(0.7 * s, 0.08, -0.3), OR, { noCollide = true })
	end
	finish(m)
end

folder.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local out = {}
for _, a in ipairs(folder:GetChildren()) do
	local n = 0
	for _, d in ipairs(a:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	local _, size = a:GetBoundingBox()
	table.insert(out, string.format("%s: %d parts, %.1f x %.1f x %.1f", a.Name, n, size.X, size.Y, size.Z))
end
return table.concat(out, "\n")
