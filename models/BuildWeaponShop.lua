-- Builds the open-air WEAPON SHOP market stall in Workspace (anchored plastic Parts, game style).
-- Studio: View > Command Bar, paste this whole file, press Enter. Re-running replaces the old shop.
-- Local frame of the shop: +Z is the front (customers, sign, counter), +X is its right, y = 0 is the ground.
-- Includes: a ProximityPrompt ("Browse weapons") on the counter, a placeholder shop menu (ScreenGui template
-- + LocalScript) and a server Script that opens it, plus a slowly spinning gold rifle above the counter.
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build Weapon Shop v2")
local old = workspace:FindFirstChild("WeaponShop")
if old then old:Destroy() end

-- Where the shop stands: left of the spawn, front (+Z local) turned towards the spawn (+X world).
local BASE = CFrame.new(-30, 2, 10) * CFrame.Angles(0, math.rad(90), 0)

local V = Vector3.new
local C = {
	wood = "#a9714a", woodDark = "#5f3b25", wood2 = "#7a4a2e", stone = "#9aa0a8", stoneDark = "#6f757e",
	red = "#d6362d", cream = "#f3ecdc", gold = "#ffc83d", neonGold = "#ffd23f", neonOrange = "#ff8a1f",
	steel = "#b9c2cc", black = "#222428", green = "#35d450", olive = "#5b7f3a", sign = "#3a2418", lens = "#6ec6ff",
	skin = "#ffcc99", vest = "#4f7a3a", jeans = "#3b4a63", hat = "#6b4a2b", darkGold = "#c98a1a",
}

local shop = Instance.new("Model")
shop.Name = "WeaponShop"
local function group(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = shop
	return m
end
local structure, canopy, signG = group("Structure"), group("Canopy"), group("Sign")
local display, props, keeper, lights = group("Display"), group("Props"), group("Shopkeeper"), group("Lights")

-- pos: Vector3 (centre, shop-local) or CFrame (shop-local); opts: rx/ry/rz degrees, shape, material, noCollide, transparency
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
	if opts.transparency then p.Transparency = opts.transparency end
	p.Parent = parent
	return p
end
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local NEON = Enum.Material.Neon

local function glow(p, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex(color)
	l.Brightness = brightness
	l.Range = range
	l.Parent = p
end

---------------------------------------------------------------- deck, steps, back wall
part(structure, "Deck", V(19, 0.6, 14), V(0, 0.3, 0.5), C.wood2)
for i = -4, 4 do
	part(structure, "DeckPlankLine", V(0.12, 0.05, 14), V(i * 2, 0.61, 0.5), C.woodDark, { noCollide = true })
end
part(structure, "DeckTrimFront", V(19.4, 0.4, 0.4), V(0, 0.5, 7.7), C.cream, { noCollide = true })
part(structure, "Step", V(6, 0.3, 1.4), V(0, 0.15, 8.2), C.stoneDark)

part(structure, "BackWall", V(17, 7.6, 0.8), V(0, 4.4, -5.6), C.woodDark)
part(structure, "BackPanel", V(15.4, 6.2, 0.3), V(0, 4.2, -5.05), C.wood2)
part(structure, "BackTrimTop", V(17.2, 0.4, 1.0), V(0, 8.3, -5.6), C.gold)
for _, x in ipairs({ -7.7, 7.7 }) do
	part(structure, "BackTrimSide", V(0.4, 7.6, 1.0), V(x, 4.4, -5.6), C.gold)
end
part(structure, "ShelfLow", V(15, 0.3, 1.0), V(0, 2.9, -4.55), C.woodDark)
part(structure, "ShelfHigh", V(15, 0.3, 1.0), V(0, 5.5, -4.55), C.woodDark)

-- posts with gold caps (canopy supports)
for _, x in ipairs({ -8.4, 8.4 }) do
	for _, z in ipairs({ -5.6, 6 }) do
		part(structure, "Post", V(0.8, 8.4, 0.8), V(x, 4.8, z), C.woodDark)
		part(structure, "PostCap", V(1.1, 0.35, 1.1), V(x, 1.0, z), C.gold, { noCollide = true })
	end
end

---------------------------------------------------------------- canopy (striped tent roof)
for i = 0, 7 do
	local x = -7 + 2 * i
	local col = (i % 2 == 0) and C.red or C.cream
	part(canopy, "StripeFront", V(2, 0.3, 7.2), V(x, 9.6, 3.4), col, { rx = 20, noCollide = true })
	part(canopy, "StripeBack", V(2, 0.3, 7.2), V(x, 9.6, -3.4), col, { rx = -20, noCollide = true })
	part(canopy, "Valance", V(2, 0.9, 0.15), V(x, 7.95, 6.8), (i % 2 == 0) and C.cream or C.red, { noCollide = true })
end
part(canopy, "RidgeBeam", V(16.6, 0.5, 0.6), V(0, 10.85, 0), C.gold, { noCollide = true })

---------------------------------------------------------------- sign: WEAPON SHOP (neon frame, on the ridge)
part(signG, "SignFrame", V(11.6, 3.8, 0.5), V(0, 13.0, 0.4), C.neonGold, { material = NEON })
local board = part(signG, "SignBoard", V(10.8, 3.0, 0.4), V(0, 13.0, 0.7), C.sign)
for _, x in ipairs({ -4, 4 }) do
	part(signG, "SignPost", V(0.6, 1.7, 0.6), V(x, 11.4, 0.4), C.woodDark)
end
for i = -5, 5 do
	local b = part(signG, "SignBulb", V(0.35, 0.35, 0.35), V(i, 15.0, 0.5), (i % 2 == 0) and C.neonGold or C.neonOrange, { shape = BALL, material = NEON, noCollide = true })
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
label.TextColor3 = Color3.fromHex(C.neonGold)
label.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromHex(C.black)
stroke.Parent = label
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 18), UDim.new(0, 18)
pad.Parent = label

---------------------------------------------------------------- string lights under the canopy edge
for i = 0, 10 do
	local x = -7.5 + 1.5 * i
	local b = part(lights, "StringBulb", V(0.5, 0.5, 0.5), V(x, 7.35 + 0.2 * math.sin(i * 1.2), 6.9), (i % 2 == 0) and C.neonGold or C.neonOrange, { shape = BALL, material = NEON, noCollide = true })
	if i % 3 == 0 then glow(b, "#ffcf7a", 0.9, 9) end
end

---------------------------------------------------------------- weapons
-- rifle along local +X; gold = shiny display version
local function rifle(parent, cf, gold)
	local function rp(name, size, off, color, opts)
		opts = opts or {}
		opts.noCollide = true
		return part(parent, name, size, cf * CFrame.new(off), color, opts)
	end
	local trim = gold and C.neonGold or C.steel
	local trimMat = gold and NEON or Enum.Material.Plastic
	rp("Stock", V(1.6, 0.5, 0.35), V(-1.5, -0.1, 0), gold and C.darkGold or C.wood2)
	rp("Grip", V(0.25, 0.6, 0.25), V(-0.5, -0.45, 0), gold and C.darkGold or C.wood2)
	rp("Receiver", V(1.3, 0.38, 0.3), V(0, 0.05, 0), gold and C.neonGold or C.black, { material = trimMat })
	rp("Barrel", V(2.8, 0.16, 0.16), V(1.95, 0.1, 0), trim, { material = trimMat })
	rp("Scope", V(1.0, 0.2, 0.2), V(0, 0.32, 0), C.black)
	rp("ScopeLens", V(0.06, 0.24, 0.24), V(0.52, 0.32, 0), C.lens)
end
local function crossbow(parent, cf)
	local function rp(name, size, off, color)
		return part(parent, name, size, cf * CFrame.new(off), color, { noCollide = true })
	end
	rp("Body", V(2.4, 0.3, 0.35), V(0, 0, 0), C.wood2)
	rp("Butt", V(0.7, 0.55, 0.35), V(-1.3, -0.1, 0), C.woodDark)
	rp("BowArm", V(0.28, 2.8, 0.28), V(0.9, 0, 0), C.steel)
	rp("String", V(0.05, 2.6, 0.05), V(0.45, 0, 0), C.cream)
	rp("Bolt", V(1.6, 0.1, 0.1), V(0.1, 0.12, 0), C.steel)
end
local function sword(parent, name, cf, s)
	part(parent, name .. "Blade", V(0.45 * s, 3 * s, 0.15), cf * CFrame.new(0, 0.8 * s, 0), C.steel, { noCollide = true })
	part(parent, name .. "Guard", V(1.3 * s, 0.3 * s, 0.2), cf * CFrame.new(0, -0.8 * s, 0), C.gold, { noCollide = true })
	part(parent, name .. "Grip", V(0.3 * s, 1.1 * s, 0.2), cf * CFrame.new(0, -1.4 * s, 0), C.woodDark, { noCollide = true })
end

-- wall display
rifle(display, CFrame.new(-4.4, 4.3, -4.8))
crossbow(display, CFrame.new(0, 4.3, -4.8))
rifle(display, CFrame.new(4.4, 4.3, -4.8))
for _, x in ipairs({ -6.6, -2.2, 2.2, 6.6 }) do
	part(display, "RackPeg", V(0.2, 0.2, 0.5), V(x, 4.2, -4.85), C.woodDark, { noCollide = true })
end
-- plaque with crossed swords above the shelf
local PL = V(0, 6.9, -4.8)
part(display, "EmblemPlaque", V(0.3, 2.6, 2.6), PL, C.red, { shape = CYL, ry = 90, noCollide = true })
part(display, "EmblemRim", V(0.2, 3.0, 3.0), PL + V(0, 0, -0.05), C.gold, { shape = CYL, ry = 90, noCollide = true })
sword(display, "SwordA", CFrame.new(PL + V(0, 0, 0.3)) * CFrame.Angles(0, 0, math.rad(40)), 0.6)
sword(display, "SwordB", CFrame.new(PL + V(0, 0, 0.4)) * CFrame.Angles(0, 0, math.rad(-40)), 0.6)
for i, x in ipairs({ -6.6, -5.2, 5.2, 6.6 }) do
	part(display, "AmmoBox", V(1.1, 0.7, 0.8), V(x, 3.4, -4.5), C.olive, { noCollide = true })
	part(display, "AmmoLabel", V(0.6, 0.25, 0.05), V(x, 3.45, -4.08), C.gold, { noCollide = true })
end
for _, x in ipairs({ -3, 3 }) do
	part(display, "TrophyShelfBox", V(1.2, 0.9, 0.9), V(x, 6.0, -4.5), C.cream, { noCollide = true })
end

-- spinning gold rifle above the counter (a Script below rotates it)
local floating = Instance.new("Model")
floating.Name = "FloatingRifle"
floating.Parent = display
rifle(floating, CFrame.new(-5.2, 5.6, 3.0), true)
floating.PrimaryPart = floating:FindFirstChild("Receiver")
glow(floating.Receiver, "#ffd23f", 1.2, 10)
part(display, "FloatingRifleBase", V(0.3, 2.4, 2.4), V(-5.2, 3.65, 3.0), C.neonOrange, { shape = CYL, rz = 90, material = NEON, noCollide = true })

---------------------------------------------------------------- counter + shopkeeper
part(structure, "CounterBase", V(10.2, 2.6, 1.4), V(0, 1.9, 3.0), C.wood2)
for _, x in ipairs({ -3.3, 0, 3.3 }) do
	part(structure, "CounterPanel", V(2.8, 1.6, 0.1), V(x, 1.9, 3.72), C.woodDark, { noCollide = true })
end
part(structure, "CounterTop", V(10.8, 0.3, 2.2), V(0, 3.35, 3.0), C.woodDark)
part(structure, "CounterGold", V(10.8, 0.15, 0.15), V(0, 3.15, 4.1), C.gold, { noCollide = true })
rifle(props, CFrame.new(-0.4, 3.65, 3.0) * CFrame.Angles(0, math.rad(6), 0))
for _, x in ipairs({ 2.6, 3.6 }) do
	part(props, "CounterAmmo", V(0.9, 0.55, 0.7), V(x, 3.78, 2.8), C.olive, { noCollide = true })
end
part(props, "RegisterBody", V(1.5, 0.9, 1.0), V(4.4, 3.95, 3.0), C.black, { noCollide = true })
part(props, "RegisterScreen", V(1.0, 0.5, 0.1), V(4.4, 4.5, 2.5), C.green, { material = NEON, noCollide = true })
part(props, "CounterBell", V(0.5, 0.5, 0.5), V(-3.6, 3.75, 3.7), C.gold, { shape = BALL, noCollide = true })

local KZ = 0.8 -- shopkeeper stands behind the counter
part(keeper, "LegL", V(0.9, 2, 0.9), V(-0.5, 1.6, KZ), C.jeans, { noCollide = true })
part(keeper, "LegR", V(0.9, 2, 0.9), V(0.5, 1.6, KZ), C.jeans, { noCollide = true })
part(keeper, "Torso", V(2, 2, 1), V(0, 3.6, KZ), C.vest, { noCollide = true })
part(keeper, "ArmL", V(0.7, 1.6, 0.7), V(-1.35, 3.8, KZ), C.cream, { noCollide = true })
part(keeper, "ArmR", V(0.7, 1.6, 0.7), V(1.35, 3.8, KZ), C.cream, { noCollide = true })
part(keeper, "HandL", V(0.7, 0.5, 0.7), V(-1.35, 2.75, KZ), C.skin, { noCollide = true })
part(keeper, "HandR", V(0.7, 0.5, 0.7), V(1.35, 2.75, KZ), C.skin, { noCollide = true })
part(keeper, "Head", V(1.5, 1.5, 1.5), V(0, 5.35, KZ), C.skin, { noCollide = true })
part(keeper, "EyeL", V(0.2, 0.3, 0.1), V(-0.35, 5.5, KZ + 0.78), C.black, { noCollide = true })
part(keeper, "EyeR", V(0.2, 0.3, 0.1), V(0.35, 5.5, KZ + 0.78), C.black, { noCollide = true })
part(keeper, "Smile", V(0.6, 0.12, 0.1), V(0, 5.05, KZ + 0.78), C.black, { noCollide = true })
part(keeper, "HatBrim", V(2.8, 0.2, 2.8), V(0, 6.15, KZ), C.hat, { noCollide = true })
part(keeper, "HatCrown", V(1.7, 0.9, 1.7), V(0, 6.7, KZ), C.hat, { noCollide = true })
part(keeper, "HatBand", V(1.75, 0.25, 1.75), V(0, 6.38, KZ), C.red, { noCollide = true })

---------------------------------------------------------------- outside props
local function barrel(pos)
	part(props, "Barrel", V(2.4, 1.8, 1.8), pos, C.wood, { shape = CYL, rz = 90 })
	for _, dy in ipairs({ -0.7, 0.7 }) do
		part(props, "BarrelHoop", V(0.22, 1.92, 1.92), pos + V(0, dy, 0), C.black, { shape = CYL, rz = 90, noCollide = true })
	end
end
local function crate(pos, ry)
	part(props, "Crate", V(2, 2, 2), pos, C.wood, { ry = ry })
	for _, dy in ipairs({ -0.75, 0.75 }) do
		part(props, "CrateBand", V(2.06, 0.3, 2.06), pos + V(0, dy, 0), C.woodDark, { ry = ry, noCollide = true })
	end
end
crate(V(-11.4, 1, 1.5), 0)
crate(V(-11.4, 1, -1.0), 0)
crate(V(-11.4, 3, 0.2), 15)
barrel(V(11.4, 1.2, 1.0))
barrel(V(11.6, 1.2, 3.2))
barrel(V(11.3, 3.4, 2.1))

-- shooting target on a stand
local TP = V(15, 0, 6)
part(props, "TargetPost", V(0.5, 4.4, 0.5), TP + V(0, 2.2, -0.5), C.woodDark)
part(props, "TargetBase", V(3.4, 0.35, 1.6), TP + V(0, 0.18, -0.5), C.woodDark)
local rings = { { 4.2, C.red }, { 3.2, C.cream }, { 2.2, C.red }, { 1.2, C.cream }, { 0.5, C.red } }
for i, r in ipairs(rings) do
	part(props, "TargetRing", V(0.3, r[1], r[1]), TP + V(0, 4.6, 0.12 * (i - 1)), r[2], { shape = CYL, ry = 90, noCollide = (i > 1) })
end

-- flags on the front corners
for _, x in ipairs({ -10, 10 }) do
	part(props, "FlagPole", V(0.25, 7, 0.25), V(x, 3.5, 7.4), C.woodDark)
	part(props, "FlagTop", V(0.5, 0.5, 0.5), V(x, 7.2, 7.4), C.gold, { shape = BALL, noCollide = true })
	part(props, "Flag", V(2.4, 1.4, 0.12), V(x + (x < 0 and 1.3 or -1.3), 6.2, 7.4), C.red, { noCollide = true })
	part(props, "FlagStripe", V(2.4, 0.3, 0.14), V(x + (x < 0 and 1.3 or -1.3), 6.2, 7.4), C.gold, { noCollide = true })
end

-- lamp posts + stepping-stone path towards the spawn
for _, x in ipairs({ -5, 5 }) do
	part(props, "LampPost", V(0.4, 5, 0.4), V(x, 2.5, 13), C.black)
	part(props, "LampCap", V(1.2, 0.3, 1.2), V(x, 5.6, 13), C.black, { noCollide = true })
	local lamp = part(props, "LampLight", V(0.9, 1.0, 0.9), V(x, 5.1, 13), C.neonGold, { material = NEON, noCollide = true })
	glow(lamp, "#ffcf7a", 1.0, 14)
end
for i = 0, 4 do
	part(props, "PathStone", V(2.6, 0.15, 2.4), V(0.3 * ((i % 2 == 0) and 1 or -1), 0.07, 10.5 + 3.1 * i), C.stone, { noCollide = true, ry = (i * 17) % 30 })
end
for _, b in ipairs({ { -10.5, 1, 9 }, { -9.2, 0.8, 10.4 }, { 10.2, 0.9, 9.4 }, { 12.4, 0.8, 8.6 } }) do
	part(props, "Bush", V(2.4, 2.4, 2.4), V(b[1], b[2], b[3]), C.green, { shape = BALL })
end

---------------------------------------------------------------- "Browse weapons" prompt
local anchor = part(structure, "ShopPromptAnchor", V(1, 1, 1), V(0, 4.4, 4.6), C.black, { noCollide = true, transparency = 1 })
local prompt = Instance.new("ProximityPrompt")
prompt.ObjectText = "Weapon Shop"
prompt.ActionText = "Browse weapons"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = anchor

---------------------------------------------------------------- shop menu (placeholder): ScreenGui template + LocalScript
local menu = Instance.new("ScreenGui")
menu.Name = "ShopMenu"
menu.ResetOnSpawn = false
menu.DisplayOrder = 20
menu.Parent = shop

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(580, 420)
window.BackgroundColor3 = Color3.fromHex("#3a2418")
window.Parent = menu
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = window
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromHex(C.neonGold)
	s.Thickness = 4
	s.Parent = window
end

local function text(parent, name, str, size, color, pos, sz, align)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Text = str
	t.Font = Enum.Font.GothamBlack
	t.TextSize = size
	t.TextColor3 = Color3.fromHex(color)
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.Position = pos
	t.Size = sz
	t.Parent = parent
	return t
end
text(window, "Title", "WEAPON SHOP", 38, C.neonGold, UDim2.fromOffset(24, 12), UDim2.fromOffset(400, 50))

local close = Instance.new("TextButton")
close.Name = "Close"
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextSize = 24
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromHex(C.red)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -16, 0, 16)
close.Size = UDim2.fromOffset(44, 44)
close.Parent = window
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = close
end

local items = Instance.new("Frame")
items.Name = "Items"
items.BackgroundTransparency = 1
items.Position = UDim2.fromOffset(20, 76)
items.Size = UDim2.fromOffset(540, 280)
items.Parent = window
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 10)
	l.Parent = items
end

-- placeholder catalogue (prices are NOT final: the economy is still undecided)
local catalogue = {
	{ "Hunting Rifle", "Reliable all-rounder", "$100" },
	{ "Crossbow", "Quiet and accurate", "$250" },
	{ "Golden Rifle", "Shoots far and looks amazing", "$1,000" },
}
for i, it in ipairs(catalogue) do
	local row = Instance.new("Frame")
	row.Name = "Item" .. i
	row.BackgroundColor3 = Color3.fromHex("#5f3b25")
	row.Size = UDim2.fromOffset(540, 84)
	row.LayoutOrder = i
	row.Parent = items
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = row
	text(row, "Name", it[1], 24, "#ffffff", UDim2.fromOffset(16, 8), UDim2.fromOffset(260, 32))
	local d = text(row, "Desc", it[2], 16, "#e8d5c0", UDim2.fromOffset(16, 44), UDim2.fromOffset(260, 28))
	d.Font = Enum.Font.GothamMedium
	text(row, "Price", it[3], 26, C.neonGold, UDim2.fromOffset(280, 24), UDim2.fromOffset(110, 36), Enum.TextXAlignment.Right)
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Text = "BUY"
	buy.Font = Enum.Font.GothamBlack
	buy.TextSize = 22
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.BackgroundColor3 = Color3.fromHex("#2fb34a")
	buy.Position = UDim2.fromOffset(410, 20)
	buy.Size = UDim2.fromOffset(112, 44)
	buy.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 10)
	bc.Parent = buy
end
local note = text(window, "Note", "Placeholder prices. Buying is not hooked up to the economy yet.", 14, "#c9b49b", UDim2.fromOffset(24, 372), UDim2.fromOffset(530, 30))
note.Font = Enum.Font.GothamMedium

local client = Instance.new("LocalScript")
client.Name = "MenuClient"
client.Source = [==[
-- Placeholder shop menu: closes with X (or Esc is left to the player), BUY flashes "Soon!" until the economy exists.
local gui = script.Parent
local window = gui:WaitForChild("Window")
window:WaitForChild("Close").Activated:Connect(function()
	gui.Enabled = false
end)
for _, row in ipairs(window:WaitForChild("Items"):GetChildren()) do
	local buy = row:FindFirstChild("Buy")
	if buy then
		buy.Activated:Connect(function()
			if buy.Text ~= "BUY" then
				return
			end
			buy.Text = "SOON!"
			task.delay(1.2, function()
				buy.Text = "BUY"
			end)
		end)
	end
end
]==]
client.Parent = menu

---------------------------------------------------------------- server scripts: open the menu, spin the gold rifle
local server = Instance.new("Script")
server.Name = "ShopServer"
server.Source = [==[
-- Opens the shop menu for whoever triggers the "Browse weapons" prompt, and spins the gold display rifle.
local RunService = game:GetService("RunService")
local shop = script.Parent
local prompt = shop:FindFirstChildWhichIsA("ProximityPrompt", true)
local template = shop:FindFirstChild("ShopMenu")

prompt.Triggered:Connect(function(player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = playerGui:FindFirstChild("ShopMenu")
	if gui then
		gui.Enabled = true
	else
		gui = template:Clone()
		gui.Enabled = true
		gui.Parent = playerGui
	end
end)

local rifle = shop.Display.FloatingRifle
local base = rifle:GetPivot()
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	rifle:PivotTo(base * CFrame.Angles(0, t * 1.4, 0) + Vector3.new(0, math.sin(t * 2) * 0.25, 0))
end)
]==]
server.Parent = shop

shop.PrimaryPart = structure:FindFirstChild("Deck")
shop.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local n = 0
for _, d in ipairs(shop:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
return "WeaponShop v2 built: " .. n .. " parts"
