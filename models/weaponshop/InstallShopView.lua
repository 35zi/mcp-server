-- InstallShopView (run once in Studio's command bar / via MCP, edit mode). Safe to re-run.
-- * removes the old "Press E" shop (ProximityPrompt anchor, ShopMenu ScreenGui, ShopServer Script)
-- * adds Workspace.WeaponShop.ShopView with the invisible markers WeaponShopClient uses (re-run it whenever the stall is rebuilt):
--     ShopZone    - cylinder over the neon ring in front of the counter (Workspace["Sell point"])
--     ShopCamera  - where the camera flies to
--     PreviewSpot - where the spinning preview floats (above the middle of the front counter)
--     ExitPoint   - where the player is put when leaving (just outside the ring, facing away)
-- Shop-local frame: origin = ground centre of the stall, +Z = towards the customers, y = 0 ground.
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Install Weapon Shop view")

local shop = workspace:WaitForChild("WeaponShop")
local structure = shop:FindFirstChild("Structure") -- only in the first stall design; the striped stall has none
local counter = structure and structure:FindFirstChild("CounterFront")

-- The ring in front of the stall (Workspace["Sell point"]): its centre and radius decide the trigger zone.
local ring = workspace:FindFirstChild("Sell point")
local ringCentre, ringRadius
if ring then
	local cf = ring:GetBoundingBox()
	ringCentre = cf.Position
	ringRadius = 0
	for _, p in ipairs(ring:GetDescendants()) do
		if p:IsA("BasePart") then
			local flat = Vector3.new(p.Position.X - ringCentre.X, 0, p.Position.Z - ringCentre.Z)
			ringRadius = math.max(ringRadius, flat.Magnitude + math.max(p.Size.X, p.Size.Z) / 2)
		end
	end
end

-- The stall's frame (origin = ground centre, +Z = towards the customers): from the old front counter if there is one
-- (centre at local (0, 3.6, 5)), else from the stall's own position, facing the ring.
local SHOP
if counter then
	SHOP = counter.CFrame * CFrame.new(0, -3.6, -5)
else
	local bbox, _ = shop:GetBoundingBox()
	local floorY = ring and (ring:GetBoundingBox().Position.Y - 0.2) or (bbox.Position.Y - 5)
	local origin = Vector3.new(bbox.Position.X, floorY, bbox.Position.Z)
	local toward = ring and Vector3.new(ringCentre.X - origin.X, 0, ringCentre.Z - origin.Z) or Vector3.new(bbox.LookVector.X, 0, bbox.LookVector.Z)
	SHOP = CFrame.lookAt(origin, origin - toward.Unit) -- local -Z points away from the customers
end
if not ring then
	ringCentre = (SHOP * CFrame.new(0, 0, 10)).Position
	ringRadius = 8
end

-- remove the old E-to-open shop
for _, name in ipairs({ "ShopMenu", "ShopServer" }) do
	local old = shop:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local anchor = structure and structure:FindFirstChild("ShopPromptAnchor")
if anchor then
	anchor:Destroy()
end

local old = shop:FindFirstChild("ShopView")
if old then
	old:Destroy()
end
local view = Instance.new("Model")
view.Name = "ShopView"
view.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- clients always have the markers
view.Parent = shop

local function marker(name, size, cframe, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = view
	return p
end

local ground = SHOP.Position.Y
marker("ShopZone", Vector3.new(6, ringRadius * 2, ringRadius * 2),
	CFrame.new(ringCentre.X, ground + 3, ringCentre.Z) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
marker("ShopCamera", Vector3.new(1, 1, 1), SHOP * CFrame.lookAt(Vector3.new(0, 6.6, 13.5), Vector3.new(0, 5.9, 5)))
marker("PreviewSpot", Vector3.new(1, 1, 1), SHOP * CFrame.new(0, 6.1, 5))
local ringLocalZ = SHOP:PointToObjectSpace(ringCentre).Z
marker("ExitPoint", Vector3.new(2, 2, 1), SHOP * CFrame.new(0, 3, ringLocalZ + ringRadius + 2.5) * CFrame.Angles(0, math.pi, 0))

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return string.format("ShopView installed: ring centre %s radius %.1f", tostring(ringCentre), ringRadius)
