-- Builds the "WEAPON SHOP" in Workspace (Parts only, anchored, plastic block style).
-- Studio: View > Command Bar, paste this whole file, press Enter. Re-running replaces the old shop.
-- Local frame of the shop: +Z is the front (door, counter, sign), +X is its right, y = 0 is the ground.
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build Weapon Shop")
local old = workspace:FindFirstChild("WeaponShop")
if old then old:Destroy() end

-- Where the shop stands: left of the spawn, front (+Z local) turned towards the spawn (+X world).
local BASE = CFrame.new(-30, 2, 10) * CFrame.Angles(0, math.rad(90), 0)

local V = Vector3.new
local C = {
	wood = "#a9714a", woodDark = "#5f3b25", wood2 = "#7a4a2e", stone = "#9aa0a8", stoneDark = "#6f757e",
	red = "#d6362d", cream = "#f3ecdc", roof = "#7a2e2a", roofTop = "#923a33", gold = "#ffc83d",
	steel = "#b9c2cc", black = "#222428", green = "#35d450", olive = "#5b7f3a", sign = "#4a2f1f", lens = "#6ec6ff",
}

local shop = Instance.new("Model")
shop.Name = "WeaponShop"
local function group(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = shop
	return m
end
local building, roof, signG, props, interior = group("Building"), group("Roof"), group("Sign"), group("Props"), group("Interior")

-- pos: Vector3 (centre, shop-local) or CFrame (shop-local); opts: rx/ry/rz degrees, shape, material, noCollide
local function part(parent, name, size, pos, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Material = opts.material or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = Color3.fromHex(color)
	p.Size = size
	local lcf = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	p.CFrame = BASE * lcf * CFrame.Angles(math.rad(opts.rx or 0), math.rad(opts.ry or 0), math.rad(opts.rz or 0))
	if opts.shape then p.Shape = opts.shape end
	if opts.noCollide then p.CanCollide = false end
	p.Parent = parent
	return p
end
local CYL = Enum.PartType.Cylinder

---------------------------------------------------------------- building
part(building, "Floor", V(18, 0.6, 14), V(0, 0.3, 0), C.stone)
part(building, "DoorStep", V(3.4, 0.3, 1.4), V(-2, 0.15, 7.7), C.stoneDark)

-- walls (y 0.6 .. 8.6)
part(building, "WallBack", V(16, 8, 1), V(0, 4.6, -5.5), C.wood)
part(building, "WallLeft", V(1, 8, 11), V(-7.5, 4.6, 0), C.wood)
part(building, "WallRight", V(1, 8, 11), V(7.5, 4.6, 0), C.wood)
-- front wall: door opening x -3.5..-0.5, window opening x 1.5..6.5 (y 3.6..6.6)
part(building, "WallFrontLeft", V(4.5, 8, 1), V(-5.75, 4.6, 5.5), C.wood)
part(building, "DoorLintel", V(3, 2, 1), V(-2, 7.6, 5.5), C.wood)
part(building, "WallFrontPillar", V(2, 8, 1), V(0.5, 4.6, 5.5), C.wood)
part(building, "CounterWall", V(5, 3, 1), V(4, 2.1, 5.5), C.wood)
part(building, "WindowHeader", V(5, 2, 1), V(4, 7.6, 5.5), C.wood)
part(building, "WallFrontRight", V(1.5, 8, 1), V(7.25, 4.6, 5.5), C.wood)

-- corner posts and timber beams
for _, x in ipairs({ -7.7, 7.7 }) do
	for _, z in ipairs({ -5.7, 5.7 }) do
		part(building, "CornerPost", V(1.3, 8.6, 1.3), V(x, 4.3, z), C.woodDark)
	end
end
for _, z in ipairs({ -3, 0, 3 }) do
	part(building, "BeamLeft", V(0.3, 8, 0.7), V(-8.15, 4.6, z), C.woodDark)
	part(building, "BeamRight", V(0.3, 8, 0.7), V(8.15, 4.6, z), C.woodDark)
end
for _, x in ipairs({ -4.5, 0, 4.5 }) do
	part(building, "BeamBack", V(0.7, 8, 0.3), V(x, 4.6, -6.15), C.woodDark)
end
part(building, "BeltFront", V(16.6, 0.4, 0.3), V(0, 8.2, 6.1), C.woodDark)

-- stone foundation band
part(building, "BaseBack", V(17, 1.2, 0.4), V(0, 1.2, -6.1), C.stoneDark)
part(building, "BaseLeft", V(0.4, 1.2, 12.4), V(-8.1, 1.2, 0), C.stoneDark)
part(building, "BaseRight", V(0.4, 1.2, 12.4), V(8.1, 1.2, 0), C.stoneDark)
part(building, "BaseFrontL", V(4.7, 1.2, 0.4), V(-5.75, 1.2, 6.1), C.stoneDark)
part(building, "BaseFrontR", V(1.7, 1.2, 0.4), V(7.15, 1.2, 6.1), C.stoneDark)

-- door (opened outwards on the left jamb)
part(building, "DoorJambL", V(0.4, 6, 0.7), V(-3.7, 3.6, 5.5), C.woodDark)
part(building, "DoorJambR", V(0.4, 6, 0.7), V(-0.3, 3.6, 5.5), C.woodDark)
part(building, "Door", V(0.3, 6, 3), V(-3.75, 3.6, 7.1), C.wood2)
part(building, "DoorPlank", V(0.36, 0.4, 3), V(-3.75, 2.0, 7.1), C.woodDark)
part(building, "DoorPlank", V(0.36, 0.4, 3), V(-3.75, 5.2, 7.1), C.woodDark)
part(building, "DoorHandle", V(0.3, 0.3, 0.3), V(-3.5, 3.4, 8.3), C.gold, { shape = Enum.PartType.Ball, noCollide = true })

-- window frame and counter
part(building, "WindowJambL", V(0.3, 3.2, 0.6), V(1.6, 5.1, 5.5), C.woodDark, { noCollide = true })
part(building, "WindowJambR", V(0.3, 3.2, 0.6), V(6.4, 5.1, 5.5), C.woodDark, { noCollide = true })
part(building, "CounterTop", V(5.8, 0.3, 2.4), V(4, 3.75, 7.0), C.woodDark)
part(building, "CounterFront", V(5.4, 2.8, 0.3), V(4, 2.2, 8.1), C.wood2)
part(building, "AwningPostL", V(0.3, 2.9, 0.3), V(1.5, 5.0, 8.1), C.woodDark)
part(building, "AwningPostR", V(0.3, 2.9, 0.3), V(6.5, 5.0, 8.1), C.woodDark)
for i = 0, 5 do
	part(building, "AwningStripe", V(0.9, 0.2, 2.8), V(1.3 + 0.45 + 0.9 * i, 6.95, 7.3), (i % 2 == 0) and C.red or C.cream, { rx = 25, noCollide = true })
end

-- crossed-swords emblem on a red plaque, left of the door
local PL = V(-5.75, 4.8, 6.1)
part(building, "EmblemPlaque", V(0.3, 4.2, 4.2), PL, C.red, { shape = CYL, ry = 90, noCollide = true })
part(building, "EmblemRim", V(0.2, 4.7, 4.7), PL + V(0, 0, -0.05), C.gold, { shape = CYL, ry = 90, noCollide = true })
local function sword(name, rz, dz)
	local cf = CFrame.new(PL + V(0, 0, dz)) * CFrame.Angles(0, 0, math.rad(rz))
	part(building, name .. "Blade", V(0.45, 3, 0.15), cf * CFrame.new(0, 0.8, 0), C.steel, { noCollide = true })
	part(building, name .. "Guard", V(1.3, 0.3, 0.2), cf * CFrame.new(0, -0.8, 0), C.gold, { noCollide = true })
	part(building, name .. "Grip", V(0.3, 1.1, 0.2), cf * CFrame.new(0, -1.4, 0), C.woodDark, { noCollide = true })
end
sword("SwordA", 40, 0.35)
sword("SwordB", -40, 0.45)

---------------------------------------------------------------- roof (stepped, plastic-style)
part(roof, "Roof1", V(19, 0.8, 15), V(0, 9.0, 0), C.roof)
part(roof, "Roof2", V(16, 0.8, 12), V(0, 9.8, 0), C.roofTop)
part(roof, "Roof3", V(11, 0.8, 8), V(0, 10.6, 0), C.roof)
part(roof, "Roof4", V(6, 0.8, 4), V(0, 11.4, 0), C.roofTop)
part(roof, "EaveTrimFront", V(19, 0.3, 0.3), V(0, 8.75, 7.6), C.cream, { noCollide = true })
part(roof, "EaveTrimBack", V(19, 0.3, 0.3), V(0, 8.75, -7.6), C.cream, { noCollide = true })
part(roof, "EaveTrimLeft", V(0.3, 0.3, 15), V(-9.6, 8.75, 0), C.cream, { noCollide = true })
part(roof, "EaveTrimRight", V(0.3, 0.3, 15), V(9.6, 8.75, 0), C.cream, { noCollide = true })
part(roof, "Chimney", V(2, 4, 2), V(5, 11.4, -4), C.stoneDark)
part(roof, "ChimneyCap", V(2.6, 0.5, 2.6), V(5, 13.6, -4), C.stone)

---------------------------------------------------------------- sign: WEAPON SHOP
part(signG, "SignFrame", V(13, 3.8, 0.5), V(0, 11.3, 6.5), C.gold)
local board = part(signG, "SignBoard", V(12.2, 3.0, 0.4), V(0, 11.3, 6.85), C.sign)
for _, x in ipairs({ -4.5, 4.5 }) do
	part(signG, "SignPost", V(0.6, 2, 0.6), V(x, 10.4, 6.3), C.woodDark)
end
local gui = Instance.new("SurfaceGui")
gui.Name = "SignGui"
gui.Face = Enum.NormalId.Back -- the part's +Z side faces the shop front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 60
gui.Parent = board
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "WEAPON SHOP"
label.Font = Enum.Font.GothamBlack
label.TextScaled = true
label.TextColor3 = Color3.fromHex(C.gold)
label.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromHex(C.black)
stroke.Parent = label
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 18), UDim.new(0, 18)
pad.Parent = label

---------------------------------------------------------------- interior
local function rifle(parent, cf)
	local function rp(name, size, off, color, opts)
		opts = opts or {}
		opts.noCollide = true
		return part(parent, name, size, cf * CFrame.new(off), color, opts)
	end
	rp("Stock", V(1.6, 0.5, 0.35), V(-1.5, -0.1, 0), C.wood2)
	rp("Grip", V(0.25, 0.6, 0.25), V(-0.5, -0.45, 0), C.wood2)
	rp("Receiver", V(1.3, 0.38, 0.3), V(0, 0.05, 0), C.black)
	rp("Barrel", V(2.8, 0.16, 0.16), V(1.95, 0.1, 0), C.steel)
	rp("Scope", V(1.0, 0.2, 0.2), V(0, 0.32, 0), C.black)
	rp("ScopeLens", V(0.06, 0.24, 0.24), V(0.52, 0.32, 0), C.lens)
end

part(interior, "ShelfLow", V(11, 0.3, 1.2), V(0, 3.0, -4.4), C.wood2)
part(interior, "ShelfHigh", V(11, 0.3, 1.2), V(0, 5.9, -4.4), C.wood2)
for _, x in ipairs({ -4, 0, 4 }) do
	part(interior, "ShelfBracket", V(0.3, 0.9, 1.0), V(x, 2.4, -4.5), C.woodDark, { noCollide = true })
end
rifle(interior, CFrame.new(-2.6, 4.5, -4.6))
rifle(interior, CFrame.new(2.6, 4.5, -4.6))
rifle(interior, CFrame.new(0, 7.2, -4.6))
for _, x in ipairs({ -4.2, -1.0, 4.2 }) do
	part(interior, "RifleRackPeg", V(0.2, 0.2, 0.5), V(x, 4.45, -4.7), C.woodDark, { noCollide = true })
end
for i, x in ipairs({ -4.2, -2.8, 1.8, 3.2 }) do
	part(interior, "AmmoBox", V(1.1, 0.7, 0.8), V(x, 3.5, -4.4), C.olive, { noCollide = true })
	part(interior, "AmmoLabel", V(0.6, 0.25, 0.05), V(x, 3.55, -3.98), C.gold, { noCollide = true })
end
part(interior, "RugBorder", V(7.4, 0.06, 5.4), V(-2, 0.63, 0), C.cream, { noCollide = true })
part(interior, "Rug", V(7, 0.08, 5), V(-2, 0.65, 0), C.red, { noCollide = true })
part(interior, "LanternChain", V(0.12, 1.4, 0.12), V(-2, 7.9, 1), C.black, { noCollide = true })
local lantern = part(interior, "Lantern", V(0.9, 1.1, 0.9), V(-2, 6.6, 1), C.gold, { material = Enum.Material.Neon, noCollide = true })
local light = Instance.new("PointLight")
light.Color = Color3.fromHex("#ffcf7a")
light.Brightness = 1.4
light.Range = 16
light.Parent = lantern
-- a rifle resting on the counter
rifle(props, CFrame.new(4.1, 4.05, 7.1) * CFrame.Angles(0, math.rad(8), 0))
part(props, "CounterAmmo", V(1.0, 0.6, 0.8), V(2.4, 4.2, 7.2), C.olive, { noCollide = true })

---------------------------------------------------------------- outside props
local function barrel(pos)
	part(props, "Barrel", V(2.4, 1.8, 1.8), pos, C.wood, { shape = CYL, rz = 90 })
	for _, dy in ipairs({ -0.7, 0.7 }) do
		part(props, "BarrelHoop", V(0.22, 1.92, 1.92), pos + V(0, dy, 0), C.black, { shape = CYL, rz = 90, noCollide = true })
	end
end
barrel(V(-6.8, 1.2, 8.6))
barrel(V(-5.2, 1.2, 9.2))

local function crate(pos, ry)
	part(props, "Crate", V(2, 2, 2), pos, C.wood, { ry = ry })
	for _, dy in ipairs({ -0.75, 0.75 }) do
		part(props, "CrateBand", V(2.06, 0.3, 2.06), pos + V(0, dy, 0), C.woodDark, { ry = ry, noCollide = true })
	end
end
crate(V(-9.8, 1, 2.5), 0)
crate(V(-9.8, 1, 0), 0)
crate(V(-9.8, 3, 1.2), 15)

-- shooting target on a stand
local TP = V(11, 0, 9)
part(props, "TargetPost", V(0.5, 4.4, 0.5), TP + V(0, 2.2, -0.5), C.woodDark)
part(props, "TargetBase", V(3.4, 0.35, 1.6), TP + V(0, 0.18, -0.5), C.woodDark)
local rings = { { 4.2, C.red }, { 3.2, C.cream }, { 2.2, C.red }, { 1.2, C.cream }, { 0.5, C.red } }
for i, r in ipairs(rings) do
	part(props, "TargetRing", V(0.3, r[1], r[1]), TP + V(0, 4.6, 0.12 * (i - 1)), r[2], { shape = CYL, ry = 90, noCollide = (i > 1) })
end

-- bushes and a stepping-stone path towards the spawn
for _, b in ipairs({ { -10.5, 1, 7 }, { -9.4, 0.8, 8.4 }, { 9.8, 0.9, 6.8 } }) do
	part(props, "Bush", V(2.4, 2.4, 2.4), V(b[1], b[2], b[3]), C.green, { shape = Enum.PartType.Ball })
end
for i = 0, 4 do
	part(props, "PathStone", V(2.6, 0.15, 2.4), V(-2 + ((i % 2 == 0) and 0.3 or -0.3), 0.07, 10 + 3.1 * i), C.stone, { noCollide = true, ry = (i * 17) % 30 })
end

shop.PrimaryPart = building:FindFirstChild("Floor")
shop.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local n = 0
for _, d in ipairs(shop:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
return "WeaponShop built: " .. n .. " parts"
