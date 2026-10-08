-- Builds the simple WEAPON SHOP stall in Workspace (anchored plastic Parts, game style):
-- L-shaped counter on four posts, striped canopy, glowing circle on the ground, rifles on the counter,
-- a "WEAPON SHOP" sign. The shop view (step on the ring -> camera + browse UI) is in models/weaponshop/; the old
-- "Press E" prompt + menu were removed. NOTE: the place's shop has since been moved/edited by hand in Studio,
-- so this script rebuilds the original stall, not the current one.
-- Studio: View > Command Bar, paste this whole file, press Enter. Re-running replaces the old shop.
-- Local frame of the shop: +Z is the front (customers), +X is its right, y = 0 is the ground.
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build Weapon Shop v3")
local old = workspace:FindFirstChild("WeaponShop")
if old then old:Destroy() end

-- Where the shop stands: left of the spawn, front (+Z local) turned towards the spawn (+X world).
local BASE = CFrame.new(-30, 2, 10) * CFrame.Angles(0, math.rad(90), 0)

local V = Vector3.new
local C = {
	post = "#7a4a30", rail = "#8a5a3b", dark = "#3f4350", top = "#8a8fa3", white = "#f4f4ee", yellow = "#d8c628",
	glow = "#ffe600", gold = "#ffc83d", sign = "#3a2418", black = "#222428", steel = "#b9c2cc", wood = "#7a4a2e",
	woodDark = "#5f3b25", olive = "#5b7f3a", lens = "#6ec6ff", red = "#d6362d", cream = "#f3ecdc",
}

local shop = Instance.new("Model")
shop.Name = "WeaponShop"
local function group(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = shop
	return m
end
local structure, canopy, signG, props = group("Structure"), group("Canopy"), group("Sign"), group("Props")

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
local CYL = Enum.PartType.Cylinder
local NEON = Enum.Material.Neon

---------------------------------------------------------------- glowing circle on the ground
part(structure, "GlowZone", V(0.12, 22, 22), V(0, 0.07, 2), C.glow, { shape = CYL, rz = 90, material = NEON, transparency = 0.55, noCollide = true })
part(structure, "GlowZoneInner", V(0.14, 17, 17), V(0, 0.08, 2), C.glow, { shape = CYL, rz = 90, material = NEON, transparency = 0.7, noCollide = true })

---------------------------------------------------------------- posts, L-shaped counter, rails
local posts = { { -7, 5, 8 }, { 7, 5, 8 }, { 7, -5, 9.1 }, { -7, -5, 9.1 } } -- x, z, height (back ones taller: the canopy slopes)
for _, p in ipairs(posts) do
	part(structure, "Post", V(1, p[3], 1), V(p[1], p[3] / 2, p[2]), C.post)
	part(structure, "PostBase", V(1.5, 0.5, 1.5), V(p[1], 0.25, p[2]), C.dark)
	part(structure, "PostCap", V(1.3, 0.4, 1.3), V(p[1], p[3] - 0.2, p[2]), C.dark, { noCollide = true })
end

part(structure, "CounterFront", V(15, 0.5, 2), V(0, 3.6, 5), C.top)
part(structure, "CounterSide", V(2, 0.5, 8.6), V(7, 3.6, 0.3), C.top) -- meets the front counter at the corner
for _, y in ipairs({ 2.4, 1.3 }) do
	part(structure, "RailFront", V(14, 0.35, 0.35), V(0, y, 5), C.rail, { noCollide = true })
	part(structure, "RailSide", V(0.35, 0.35, 10), V(7, y, 0), C.rail, { noCollide = true })
end
for _, p in ipairs({ { -7, 5 }, { 7, 5 }, { 7, -5 } }) do
	part(structure, "CounterClamp", V(1.5, 0.6, 1.5), V(p[1], 3.2, p[2]), C.dark, { noCollide = true })
end

---------------------------------------------------------------- striped canopy with a scalloped edge
local TILT = 6 -- degrees, front edge lower
local tan = math.tan(math.rad(TILT))
for i = 0, 7 do
	local x = -7 + 2 * i
	local even = (i % 2 == 0)
	part(canopy, "Stripe", V(2, 0.3, 12.2), V(x, 8.6, 0), even and C.white or C.yellow, { rx = TILT, noCollide = true })
	-- front flap (hangs from the front edge z = 6.1)
	part(canopy, "FlapFront", V(2, 1, 0.2), V(x, 8.6 - 6.1 * tan - 0.55, 6.1), even and C.yellow or C.white, { noCollide = true })
end
for k = 0, 5 do
	local z = -5 + 2 * k
	part(canopy, "FlapSide", V(0.2, 1, 2), V(8.05, 8.6 - z * tan - 0.55, z), (k % 2 == 0) and C.white or C.yellow, { noCollide = true })
end

---------------------------------------------------------------- sign: WEAPON SHOP
part(signG, "SignFrame", V(10.2, 3.2, 0.5), V(0, 10.7, -1.7), C.glow, { material = NEON })
local board = part(signG, "SignBoard", V(9.6, 2.6, 0.4), V(0, 10.7, -1.45), C.sign)
for _, x in ipairs({ -3.5, 3.5 }) do
	part(signG, "SignPost", V(0.5, 0.9, 0.5), V(x, 9.1, -1.7), C.woodDark)
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
label.TextColor3 = Color3.fromHex(C.glow)
label.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromHex(C.black)
stroke.Parent = label
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
pad.Parent = label

---------------------------------------------------------------- rifles lying on the counter
-- rifle along local +X; cf is shop-local
local function rifle(parent, cf)
	local function rp(name, size, off, color)
		return part(parent, name, size, cf * CFrame.new(off), color, { noCollide = true })
	end
	rp("Stock", V(1.6, 0.5, 0.35), V(-1.5, -0.1, 0), C.wood)
	rp("Grip", V(0.25, 0.6, 0.25), V(-0.5, -0.45, 0), C.wood)
	rp("Receiver", V(1.3, 0.38, 0.3), V(0, 0.05, 0), C.black)
	rp("Barrel", V(2.8, 0.16, 0.16), V(1.95, 0.1, 0), C.steel)
	rp("Scope", V(1.0, 0.2, 0.2), V(0, 0.32, 0), C.black)
	rp("ScopeLens", V(0.06, 0.24, 0.24), V(0.52, 0.32, 0), C.lens)
end
local TOP = 3.85 + 0.5 -- counter top surface + half the rifle's height, so it rests on the counter
rifle(props, CFrame.new(-4.3, TOP, 4.6) * CFrame.Angles(0, math.rad(4), 0))
rifle(props, CFrame.new(1.2, TOP, 5.4) * CFrame.Angles(0, math.rad(-5), 0))
rifle(props, CFrame.new(6.5, TOP, -0.8) * CFrame.Angles(0, math.rad(-90), 0)) -- side counter, pointing back
rifle(props, CFrame.new(7.5, TOP, -1.6) * CFrame.Angles(0, math.rad(-92), 0))
for _, x in ipairs({ -1.4, -0.3 }) do
	part(props, "AmmoBox", V(0.9, 0.55, 0.7), V(x + 4.2, 4.1, 4.4), C.olive, { noCollide = true })
end

shop.PrimaryPart = structure:FindFirstChild("CounterFront")
shop.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
local n = 0
for _, d in ipairs(shop:GetDescendants()) do
	if d:IsA("BasePart") then n += 1 end
end
return "WeaponShop v3 built: " .. n .. " parts"
