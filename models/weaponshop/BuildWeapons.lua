-- BuildWeapons (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- Turns the gun models into shop weapons:
--   * source models are kept (moved out of the world) in ServerStorage.WeaponModels
--   * ServerStorage.WeaponTools.<Id>             equippable Tool: invisible Handle at the grip, every visible part
--                                                 welded to it, Handle -Z = barrel direction
--   * ReplicatedStorage.WeaponShopPreviews.<Id>   anchored copy for the shop's spinning preview
-- Points the weapon code needs are stored as Tool attributes, in Handle space:
--   EyePos (where the camera sits when aiming), SightTarget (what it looks at: front sight / scope front lens),
--   MuzzlePos (also a MuzzleAttachment on the Handle), SupportPos (where the left hand holds it)
local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rec = CHS:TryBeginRecording("Build weapons")

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
local modelsFolder = folder(ServerStorage, "WeaponModels")
local toolsFolder = folder(ServerStorage, "WeaponTools")
local previewsFolder = folder(ReplicatedStorage, "WeaponShopPreviews")

local SOURCES = { "Python_Revolver", "revolver", "shotgun", "automatic_rifle", "bolt_action_sniper" }
for _, name in ipairs(SOURCES) do
	local m = workspace:FindFirstChild(name)
	if m then
		m.Parent = modelsFolder
	end
end

local UP = Vector3.new(0, 1, 0)
local NEG_X = Vector3.new(-1, 0, 0)

local function find(model, name)
	local p = model:FindFirstChild(name, true)
	assert(p, model.Name .. " has no part " .. name)
	return p
end
-- half the part's extent along a world direction
local function extent(p, dir)
	local d = p.CFrame:VectorToObjectSpace(dir)
	return math.abs(d.X) * p.Size.X / 2 + math.abs(d.Y) * p.Size.Y / 2 + math.abs(d.Z) * p.Size.Z / 2
end
local function tip(p, dir)
	return p.Position + dir * extent(p, dir)
end

local SPECS = {
	{
		id = "Python", name = "Python", source = "Python_Revolver", length = 3.1, forward = Vector3.new(0, 0, 1),
		-- single mesh exported from models/blender/python_gun_blocky.py: use the design coordinates of the sights
		-- (Blender x, y = forward, z = up; mesh origin = bounding-box centre at Blender (0, 1.0, -0.035), 8.8 long)
		points = function(m)
			local mesh = m:FindFirstChildWhichIsA("MeshPart", true)
			local k = mesh.Size.Z / 8.80
			local function P(y, z)
				return mesh.CFrame:PointToWorldSpace(Vector3.new(0, (z + 0.035) * k, (y - 1.0) * k))
			end
			local grip = P(-2.1, -0.95)
			return { front = P(4.88, 2.55), rear = P(-1.2, 2.55), muzzle = P(5.40, 0.95), grip = grip, support = grip - UP * 0.3 }
		end,
	},
	{
		id = "Revolver", name = "Revolver", source = "revolver", length = 3.2, forward = NEG_X,
		points = function(m, F)
			local n1, n2 = find(m, "Revolver_Rear_Sight_Notch_1"), find(m, "Revolver_Rear_Sight_Notch_-1")
			local grip = find(m, "Revolver_Grip_Core").Position
			return {
				front = tip(find(m, "Revolver_Front_Sight"), UP),
				rear = (tip(n1, UP) + tip(n2, UP)) / 2,
				muzzle = tip(find(m, "Revolver_Barrel"), F),
				grip = grip,
				support = grip - UP * 0.3 + F * 0.1,
			}
		end,
	},
	{
		id = "Shotgun", name = "Shotgun", source = "shotgun", length = 5.0, forward = NEG_X,
		points = function(m, F)
			local top = find(m, "Shotgun_Receiver_Top")
			local guard = find(m, "Shotgun_Trigger_Guard")
			return {
				front = tip(find(m, "Shotgun_Front_Sight"), UP),
				rear = tip(top, UP) - F * extent(top, F) * 0.8, -- back end of the receiver top (bead-sight gun)
				muzzle = tip(find(m, "Shotgun_Barrel"), F),
				grip = guard.Position - F * 0.75 + UP * 0.25,
				support = find(m, "Shotgun_Pump_Core").Position,
			}
		end,
	},
	{
		id = "AutomaticRifle", name = "Automatic Rifle", source = "automatic_rifle", length = 4.8, forward = NEG_X,
		-- the imported iron sights are chunky blocks: make a slim front post and thin rear ears with an open notch
		slim = function(m)
			local hood = find(m, "AutomaticRifle_Front_Sight_Hood")
			local function thin(p, across) -- each sight part's own Z runs across the gun
				p.Size = Vector3.new(p.Size.X, p.Size.Y, across)
			end
			thin(hood, 0.045)
			thin(find(m, "AutomaticRifle_Front_Sight_Base"), 0.045)
			for _, name in ipairs({ "AutomaticRifle_Rear_Sight_Notch_1", "AutomaticRifle_Rear_Sight_Notch_-1" }) do
				local ear = find(m, name)
				thin(ear, 0.026)
				local rel = hood.CFrame:PointToObjectSpace(ear.Position)
				local spot = hood.CFrame:PointToWorldSpace(Vector3.new(rel.X, rel.Y, math.sign(rel.Z) * 0.12))
				ear.CFrame = CFrame.new(spot) * ear.CFrame.Rotation
			end
		end,
		points = function(m, F)
			local n1, n2 = find(m, "AutomaticRifle_Rear_Sight_Notch_1"), find(m, "AutomaticRifle_Rear_Sight_Notch_-1")
			return {
				front = find(m, "AutomaticRifle_Front_Sight_Hood").Position, -- the post sits inside the hood
				rear = (tip(n1, UP) + tip(n2, UP)) / 2,
				muzzle = tip(find(m, "AutomaticRifle_Muzzle_Brake"), F),
				grip = find(m, "AutomaticRifle_Pistol_Grip").Position,
				support = find(m, "AutomaticRifle_Handguard_Core").Position,
			}
		end,
	},
	{
		id = "BoltSniper", name = "Sniper", source = "bolt_action_sniper", length = 5.6, forward = NEG_X, scope = true,
		points = function(m, F)
			return {
				front = find(m, "BoltSniper_Scope_Front_Lens").Position,
				rear = find(m, "BoltSniper_Scope_Rear_Lens").Position,
				muzzle = tip(find(m, "BoltSniper_Muzzle_Brake"), F),
				grip = find(m, "BoltSniper_Pistol_Grip").Position,
				support = find(m, "BoltSniper_Forestock").Position,
			}
		end,
	},
}

local built = {}
for _, spec in ipairs(SPECS) do
	local source = modelsFolder:FindFirstChild(spec.source)
	if not source then
		table.insert(built, spec.id .. ": SOURCE MISSING (" .. spec.source .. ")")
		continue
	end
	for _, f in ipairs({ toolsFolder, previewsFolder }) do
		local old = f:FindFirstChild(spec.id)
		if old then
			old:Destroy()
		end
	end

	-- scale the copy so the gun is spec.length studs long
	local model = source:Clone()
	model.Name = spec.id .. "Model"
	local F = spec.forward
	local _, size = model:GetBoundingBox()
	local length = math.abs(F.X) * size.X + math.abs(F.Y) * size.Y + math.abs(F.Z) * size.Z
	model:ScaleTo(model:GetScale() * spec.length / length)
	if spec.slim then
		spec.slim(model)
	end

	local pts = spec.points(model, F)
	local isIron = not spec.scope
	-- eye: a little behind and above the rear sight (irons) or behind the scope's rear lens
	local eye = isIron and (pts.rear - F * 0.5 + UP * 0.04) or (pts.rear - F * 0.35)
	local handleCF = CFrame.lookAt(pts.grip, pts.grip + F, UP)

	local tool = Instance.new("Tool")
	tool.Name = spec.id
	tool.ToolTip = spec.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", spec.id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = handleCF
	handle.Parent = tool

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = p
			weld.C0 = handleCF:ToObjectSpace(p.CFrame)
			weld.C1 = CFrame.new()
			weld.Parent = p
		elseif p:IsA("LuaSourceContainer") then
			p:Destroy()
		end
	end
	model.Parent = tool

	local function local_(v)
		return handleCF:PointToObjectSpace(v)
	end
	tool:SetAttribute("EyePos", local_(eye))
	tool:SetAttribute("SightTarget", local_(pts.front))
	tool:SetAttribute("MuzzlePos", local_(pts.muzzle))
	tool:SetAttribute("SupportPos", local_(pts.support))
	tool:SetAttribute("Scope", spec.scope == true)
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "MuzzleAttachment"
	muzzle.Position = local_(pts.muzzle)
	muzzle.Parent = handle
	tool.Grip = CFrame.new() -- tested: barrel points where the character faces, gun upright
	tool.Parent = toolsFolder

	-- shop preview: anchored copy of the visible gun
	local preview = model:Clone()
	preview.Name = spec.id
	for _, p in ipairs(preview:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		elseif p:IsA("JointInstance") then
			p:Destroy()
		end
	end
	preview.Parent = previewsFolder

	local n = 0
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	table.insert(built, string.format("%s: %d parts, %.1f studs long, eye %s -> sight %s, muzzle %s",
		spec.id, n, spec.length, tostring(local_(eye)), tostring(local_(pts.front)), tostring(local_(pts.muzzle))))
end

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return table.concat(built, "\n")
