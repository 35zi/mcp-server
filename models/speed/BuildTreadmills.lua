-- BuildTreadmills (run in Studio's command bar / via MCP, edit mode; safe to re-run: rebuilds Workspace.Treadmills)
--
-- Three chunky treadmills next to the trail shop (the blue stall + neon Circle, left of spawn). Each is a Model
-- Treadmills.Treadmill<n> with:
--   Belt      the part you stand on (SpeedService pays Speed while you're on it; SpeedClient makes it a local conveyor)
--   Slats     thin lines SpeedClient slides along the belt so it looks like it's moving
--   Glow      neon rails / console strip, recoloured on each client to that player's treadmill tier
--   Console   with Screen (SurfaceGui), Sign (BillboardGui) and UpgradePrompt (ProximityPrompt, hold E)
-- The runner faces the console (the belt's LookVector, towards the hunting worlds).
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build treadmills")

local CENTRES_X = { -44, -33, -22 }
local CENTRE_Z = -58
local old = workspace:FindFirstChild("Treadmills")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Treadmills"
folder.Parent = workspace

local function floorY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, workspace:FindFirstChild("Decor") }
	local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or 1.5
end

local function part(model, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = typeof(color) == "Color3" and color or Color3.fromHex(color)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function text(parent, name, props)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in pairs(props) do
		t[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(8, 20, 28)
	s.Parent = t
	t.Parent = parent
	return t
end

local GREY = "#8a93a3"
for n, x in ipairs(CENTRES_X) do
	local model = Instance.new("Model")
	model.Name = "Treadmill" .. n
	model.Parent = folder
	local base = CFrame.new(x, floorY(x, CENTRE_Z), CENTRE_Z) -- faces -Z
	local at = function(px, py, pz)
		return base * CFrame.new(px, py, pz)
	end

	part(model, "Base", Vector3.new(6.6, 0.7, 12.5), at(0, 0.35, 0), "#2b2f38")
	local belt = part(model, "Belt", Vector3.new(5, 0.2, 11), at(0, 0.8, 0.4), "#17181c", { Material = Enum.Material.Fabric })
	model.PrimaryPart = belt
	local slats = Instance.new("Folder")
	slats.Name = "Slats"
	slats.Parent = model
	for i = 1, 12 do
		part(slats, "Slat", Vector3.new(4.9, 0.05, 0.22), belt.CFrame * CFrame.new(0, 0.125, -5.5 + (i - 0.5) * 11 / 12), "#3d4250", { CanCollide = false, CanQuery = false })
	end
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Glow", Vector3.new(0.4, 0.32, 12.5), at(side * 3.1, 0.78, 0), GREY, { Material = Enum.Material.Neon, CanCollide = false })
		part(model, "Post", Vector3.new(0.5, 4.6, 0.5), at(side * 2.75, 3.0, -5.6), "#dfe3ea")
		part(model, "Rail", Vector3.new(0.35, 0.35, 5.2), at(side * 2.75, 4.0, -3.2), "#dfe3ea")
		part(model, "RailEnd", Vector3.new(0.45, 0.45, 0.45), at(side * 2.75, 4.0, -0.55), "#ff5a5a")
	end
	for _, z in ipairs({ -5.9, 6.4 }) do
		part(model, "Roller", Vector3.new(5.3, 0.9, 0.9), at(0, 0.62, z), "#5b616e", { Shape = Enum.PartType.Cylinder })
	end

	-- console, tilted towards the runner
	local consoleCF = at(0, 5.45, -5.6) * CFrame.Angles(math.rad(-28), 0, 0)
	local console = part(model, "Console", Vector3.new(5.8, 1.5, 0.9), consoleCF, "#2b2f38")
	part(model, "Glow", Vector3.new(5.8, 0.18, 0.95), consoleCF * CFrame.new(0, 0.82, 0), GREY, { Material = Enum.Material.Neon, CanCollide = false })
	local screen = part(model, "Screen", Vector3.new(5, 1.1, 0.08), consoleCF * CFrame.new(0, 0, 0.47), "#0b1622", { CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Display"
	sg.Face = Enum.NormalId.Back -- +Z, towards the runner
	sg.CanvasSize = Vector2.new(500, 110)
	sg.LightInfluence = 0
	sg.Brightness = 1.5
	sg.Parent = screen
	text(sg, "Title", { Position = UDim2.fromScale(0.03, 0.04), Size = UDim2.fromScale(0.94, 0.46), Text = "BASIC TREADMILL" })
	text(sg, "Rate", { Position = UDim2.fromScale(0.03, 0.52), Size = UDim2.fromScale(0.94, 0.42), Text = "⚡ +5 SPEED / SEC", TextColor3 = Color3.fromRGB(90, 230, 255) })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade"
	prompt.ObjectText = "Treadmill"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = console

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(230, 64)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
	sign.MaxDistance = 45 -- close up only; the GroupSign shows from far away
	sign.LightInfluence = 0
	sign.Parent = console
	text(sign, "Title", { Size = UDim2.fromScale(1, 0.55), Text = "⚡ TREADMILL" })
	text(sign, "Info", { Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromScale(1, 0.45), Text = "Step on to gain Speed!", TextColor3 = Color3.fromRGB(255, 230, 90) })
end

-- one big sign over the middle treadmill, readable from spawn
local mid = folder:FindFirstChild("Treadmill" .. math.ceil(#CENTRES_X / 2))
if mid then
	local group = Instance.new("BillboardGui")
	group.Name = "GroupSign"
	group.Size = UDim2.fromOffset(340, 90)
	group.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
	group.MaxDistance = 260
	group.LightInfluence = 0
	group.Parent = mid.Console
	local title = text(group, "Title", { Size = UDim2.fromScale(1, 0.62), Text = "⚡ TREADMILLS ⚡", TextColor3 = Color3.fromRGB(90, 230, 255) })
	title.UIStroke.Thickness = 3
	local info = text(group, "Info", { Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.38), Text = "Run to gain SPEED!", TextColor3 = Color3.fromRGB(255, 225, 70) })
	info.UIStroke.Thickness = 3
end

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return "Treadmills: " .. #folder:GetChildren()
