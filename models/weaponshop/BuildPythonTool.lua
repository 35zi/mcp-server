-- BuildPythonTool: builds the "Python" revolver as a Roblox Tool + its shop preview (run in Studio, edit mode; safe to re-run).
--   ServerStorage.WeaponTools.Python            Tool (invisible Handle at the grip, every visible part welded to it)
--   ReplicatedStorage.WeaponShopPreviews.Python Model (anchored copy of the visible parts, spun by the shop view)
-- Built from Parts in the same chunky blocky design as the Blender model (models/blender/gun_blocky). When the Blender
-- mesh is imported, replace the Parts with the MeshPart and keep the Handle + Grip values.
--
-- Blender frame (forward +Y, up +Z) -> Roblox frame (forward -Z, up +Y):  (x, y, z) -> (x, z, -y).
local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rec = CHS:TryBeginRecording("Build Python tool")

local S = 0.34 -- Blender units -> studs (the gun ends up about 3 studs long)
local V = Vector3.new
local C = {
	navy = "#2a3f73", steel = "#8fa4d0", wood = "#c0804d", wood2 = "#8e5a33", brass = "#ffc83d",
	orange = "#ff5a1f", white = "#ffffff", black = "#15171c",
}
local GRIP = V(0, -2.1, -0.95) -- Blender coords of the grip centre: the Handle goes here

-- { material, name, centre (Blender), size (Blender), rotX degrees }
local BOXES = {
	{ "navy", "Frame", { 0, -0.9, 0.55 }, { 0.95, 1.8, 1.7 } },
	{ "navy", "TopStrap", { 0, 0.1, 1.3 }, { 0.85, 3.7, 0.42 } },
	{ "steel", "SidePlateL", { -0.5, -0.8, 0.5 }, { 0.1, 1.3, 1.0 } },
	{ "steel", "SidePlateR", { 0.5, -0.8, 0.5 }, { 0.1, 1.3, 1.0 } },
	{ "steel", "DrumA", { 0, 0.75, 0.5 }, { 1.95, 1.55, 1.4 } },      -- two crossed boxes = chamfered drum
	{ "steel", "DrumB", { 0, 0.75, 0.5 }, { 1.4, 1.55, 1.95 } },
	{ "navy", "Barrel", { 0, 3.35, 0.95 }, { 0.85, 3.7, 0.85 } },
	{ "navy", "Rib", { 0, 3.35, 1.52 }, { 0.32, 3.7, 0.24 } },
	{ "navy", "Underlug", { 0, 2.9, 0.38 }, { 0.72, 2.7, 0.55 } },
	{ "brass", "MuzzleRing", { 0, 5.15, 0.95 }, { 1.1, 0.34, 1.1 } },
	{ "black", "MuzzleHole", { 0, 5.34, 0.95 }, { 0.38, 0.12, 0.38 } },
	{ "navy", "RearSightBase", { 0, -1.2, 1.62 }, { 1.05, 0.7, 0.25 } },
	{ "navy", "RearSightL", { -0.38, -1.2, 2.2 }, { 0.3, 0.55, 0.72 } },
	{ "navy", "RearSightR", { 0.38, -1.2, 2.2 }, { 0.3, 0.55, 0.72 } },
	{ "white", "RearMarkL", { -0.38, -1.5, 2.25 }, { 0.16, 0.05, 0.42 } },
	{ "white", "RearMarkR", { 0.38, -1.5, 2.25 }, { 0.16, 0.05, 0.42 } },
	{ "navy", "FrontRamp", { 0, 4.7, 1.67 }, { 0.55, 0.85, 0.3 } },
	{ "orange", "FrontPost", { 0, 4.88, 2.1 }, { 0.24, 0.24, 0.9 } },
	{ "navy", "Hammer", { 0, -1.95, 1.0 }, { 0.38, 0.75, 1.1 }, 15 },
	{ "navy", "HammerSpur", { 0, -2.2, 1.58 }, { 0.54, 0.55, 0.24 }, 15 },
	{ "navy", "HammerBase", { 0, -1.75, 0.75 }, { 0.5, 0.4, 0.7 } },
	{ "navy", "GuardBottom", { 0, -0.45, -0.6 }, { 0.34, 1.7, 0.3 } },
	{ "navy", "GuardFront", { 0, 0.35, -0.1 }, { 0.34, 0.34, 1.0 } },
	{ "navy", "GuardRear", { 0, -1.25, -0.1 }, { 0.34, 0.34, 1.0 } },
	{ "navy", "Trigger", { 0, -0.45, -0.05 }, { 0.22, 0.22, 0.75 }, -15 },
	{ "wood", "Grip", { 0, -2.1, -0.95 }, { 0.98, 1.55, 2.8 }, -22 },
	{ "brass", "GripCap", { 0, -2.62, -2.2 }, { 1.04, 1.62, 0.3 }, -22 },
	{ "wood2", "GripInlayL", { -0.5, -2.1, -0.95 }, { 0.1, 1.05, 2.0 }, -22 },
	{ "wood2", "GripInlayR", { 0.5, -2.1, -0.95 }, { 0.1, 1.05, 2.0 }, -22 },
	{ "brass", "MedallionL", { -0.58, -2.1, -0.85 }, { 0.12, 0.55, 0.55 }, -22 },
	{ "brass", "MedallionR", { 0.58, -2.1, -0.85 }, { 0.12, 0.55, 0.55 }, -22 },
	{ "brass", "ScrewL", { -0.52, -1.0, 0.75 }, { 0.1, 0.3, 0.3 } },
	{ "brass", "ScrewR", { 0.52, -1.0, 0.75 }, { 0.1, 0.3, 0.3 } },
}
for i = 0, 5 do -- six chamber holes on the drum face
	local a = math.rad(60 * i + 30)
	table.insert(BOXES, { "black", "Chamber" .. (i + 1), { 0.58 * math.cos(a), 1.55, 0.5 + 0.58 * math.sin(a) }, { 0.36, 0.16, 0.36 } })
end

local function toRoblox(p)
	return V((p[1] - GRIP.X) * S, (p[3] - GRIP.Z) * S, -(p[2] - GRIP.Y) * S)
end

local tools = ServerStorage:FindFirstChild("WeaponTools")
if not tools then
	tools = Instance.new("Folder")
	tools.Name = "WeaponTools"
	tools.Parent = ServerStorage
end
local previews = ReplicatedStorage:FindFirstChild("WeaponShopPreviews")
if not previews then
	previews = Instance.new("Folder")
	previews.Name = "WeaponShopPreviews"
	previews.Parent = ReplicatedStorage
end
for _, parent in ipairs({ tools, previews }) do
	local old = parent:FindFirstChild("Python")
	if old then
		old:Destroy()
	end
end

local tool = Instance.new("Tool")
tool.Name = "Python"
tool.ToolTip = "Python"
tool.RequiresHandle = true
tool.CanBeDropped = false
tool:SetAttribute("WeaponId", "Python")

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = V(0.4, 0.4, 0.4)
handle.Transparency = 1
handle.CanCollide = false
handle.CanTouch = false
handle.Massless = true
handle.CFrame = CFrame.new(0, 0, 0)
handle.Parent = tool

local model = Instance.new("Model")
model.Name = "Python"

local function make(entry, anchored)
	local part = Instance.new("Part")
	part.Name = entry[2]
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = Color3.fromHex(C[entry[1]])
	local size = entry[4]
	part.Size = V(math.max(size[1] * S, 0.05), math.max(size[3] * S, 0.05), math.max(size[2] * S, 0.05))
	part.CFrame = CFrame.new(toRoblox(entry[3])) * CFrame.Angles(math.rad(entry[5] or 0), 0, 0)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = anchored
	return part
end

for _, entry in ipairs(BOXES) do
	local p = make(entry, false)
	p.Parent = tool
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = p
	weld.C0 = handle.CFrame:ToObjectSpace(p.CFrame)
	weld.C1 = CFrame.new()
	weld.Parent = p
	local copy = make(entry, true)
	copy.Parent = model
end
model.PrimaryPart = model:FindFirstChild("Frame")

-- Grip: tested in a playtest: with the default Grip the barrel (Handle -Z) points where the character faces and the
-- gun is upright, so no extra rotation is needed.
tool.Grip = CFrame.new(0, 0, 0)

tool.Parent = tools
model.Parent = previews
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
local n = 0
for _, d in ipairs(tool:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
local _, size = model:GetBoundingBox()
return string.format("Python tool built: %d parts, preview size %.2f x %.2f x %.2f studs", n, size.X, size.Y, size.Z)
