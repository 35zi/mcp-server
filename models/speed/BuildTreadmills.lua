-- BuildTreadmills (run in Studio's command bar / via MCP, edit mode; safe to re-run: rebuilds Workspace.Treadmills)
--
-- One treadmill per plot, in the back-right corner (seen from the plot's entrance). The server only keeps two
-- invisible, non-colliding parts per plot in Workspace.Treadmills.<PlotName>:
--   Spot       the treadmill's base frame on the floor (LookVector = the way the runner faces, towards the back
--              fence). SpeedService pays Speed while the plot's owner stands on the belt area above it.
--   AvoidArea  the corner the treadmill + its upgrade sign take up; plot animals don't wander or get placed there.
-- The treadmill you see (its look depends on your tier) and the upgrade sign are built on each client by SpeedClient:
-- the owner always sees their own; everyone else only while the owner is training on it.
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build plot treadmills")

local SIDE, BACK = 13, 13 -- studs right of / behind the plot centre (plots are 48 x 48)

local old = workspace:FindFirstChild("Treadmills")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Treadmills"
folder.Parent = workspace

-- the side with the biggest gap in the fence is the entrance
local function entranceOf(plot, centre)
	local best, bestDir = -1, Vector3.new(0, 0, -1)
	for _, dir in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local ts = {}
		for _, p in ipairs(plot.Fence:GetDescendants()) do
			if p:IsA("BasePart") then
				local rel = p.Position - centre
				if rel:Dot(dir) > 21 then
					table.insert(ts, rel:Dot(side))
				end
			end
		end
		table.sort(ts)
		local gap = 99
		if #ts > 0 then
			gap = math.max(ts[1] + 24, 24 - ts[#ts])
			for i = 2, #ts do
				gap = math.max(gap, ts[i] - ts[i - 1])
			end
		end
		if gap > best then
			best, bestDir = gap, dir
		end
	end
	return bestDir
end

local function floorY(plot, x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { folder, plot:FindFirstChild("Hitbox") }
	for _, name in ipairs({ "PlotAnimals", "Decor", "Animals" }) do
		table.insert(skip, workspace:FindFirstChild(name))
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or 1.5
end

local function hidden(name, cf, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local out = {}
for _, plot in ipairs(workspace:GetChildren()) do
	if plot:IsA("Model") and plot.Name:match("^Plot%d+$") and plot:FindFirstChild("Fence") and plot:FindFirstChild("SpawnPoint") then
		local centre = plot.SpawnPoint.Position
		local back = -entranceOf(plot, centre)
		local plotCF = CFrame.lookAt(centre, centre + back) -- -Z = towards the back fence
		local at = plotCF * CFrame.new(SIDE, 0, -BACK)
		local base = CFrame.new(at.X, floorY(plot, at.X, at.Z), at.Z) * plotCF.Rotation
		local model = Instance.new("Model")
		model.Name = plot.Name
		model.Parent = folder
		hidden("Spot", base, Vector3.new(6.6, 0.2, 12.5), model)
		-- treadmill (x -3.3..3.3, z -6.3..6.3) + the sign on its right (x 4..10): a bit of margin all round
		hidden("AvoidArea", base * CFrame.new(3, 3, 0), Vector3.new(14.5, 6, 15.5), model)
		model.PrimaryPart = model.Spot
		table.insert(out, string.format("%s: spot %s, faces %s", plot.Name, tostring(Vector3.new(math.floor(base.X), base.Y, math.floor(base.Z))), tostring(base.LookVector)))
	end
end

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return table.concat(out, "\n")
