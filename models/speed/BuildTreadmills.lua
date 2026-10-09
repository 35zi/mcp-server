-- BuildTreadmills (run in Studio's command bar / via MCP, edit mode; safe to re-run: rebuilds Workspace.Treadmills)
--
-- One treadmill per plot, like Steal an Egg: just outside the pen, in front of it and beside the entrance (the side
-- further from the shops / spawn), the runner facing the pen. The server only keeps two invisible, non-colliding
-- parts per plot in Workspace.Treadmills.<PlotName>:
--   Spot       the treadmill's base frame on the floor (LookVector = the way the runner faces, towards the pen).
--              SpeedService pays Speed while the plot's owner stands on the belt area above it. Attribute SignSide
--              (+1 / -1) = which side (Spot's local X) the small upgrade panel stands on (away from the entrance).
--   AvoidArea  the ground the treadmill + panel take up (plot animals keep out of it; outside the pen it's spare).
-- The treadmill you see (its look depends on your tier) and the upgrade panel are built on each client by
-- TreadmillClient: the owner always sees their own; everyone else only while the owner is training on it.
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Build plot treadmills")

local FRONT, SIDE = 37, 14 -- studs in front of the plot centre (fence at 24; the front piece reaches 11 studs ahead) / beside the entrance line

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

local function floorY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { folder }
	for _, name in ipairs({ "PlotAnimals", "Decor", "Animals" }) do
		table.insert(skip, workspace:FindFirstChild(name))
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), params)
	return hit and hit.Position.Y or 1.5
end

-- things to stay away from: the shops and the spawn
local landmarks = {}
for _, name in ipairs({ "Shop", "Circle", "WeaponShop", "Sell point", "SpawnLocation" }) do
	local thing = workspace:FindFirstChild(name)
	if thing then
		table.insert(landmarks, thing:IsA("Model") and thing:GetBoundingBox().Position or thing.Position)
	end
end
local function clearance(p)
	local nearest = math.huge
	for _, l in ipairs(landmarks) do
		nearest = math.min(nearest, (Vector3.new(p.X - l.X, 0, p.Z - l.Z)).Magnitude)
	end
	return nearest
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
		local entrance = entranceOf(plot, centre)
		local across = Vector3.new(-entrance.Z, 0, entrance.X)
		-- left or right of the entrance: whichever is further from the shops / spawn
		local best, bestSide = -1, 1
		for _, side in ipairs({ 1, -1 }) do
			local c = clearance(centre + entrance * FRONT + across * side * SIDE)
			if c > best then
				best, bestSide = c, side
			end
		end
		local at = centre + entrance * FRONT + across * bestSide * SIDE
		local base = CFrame.lookAt(Vector3.new(at.X, floorY(at.X, at.Z), at.Z), Vector3.new(at.X, floorY(at.X, at.Z), at.Z) - entrance)
		local model = Instance.new("Model")
		model.Name = plot.Name
		model.Parent = folder
		local spot = hidden("Spot", base, Vector3.new(7.8, 0.2, 14.6), model)
		-- the panel goes on the side away from the entrance
		local signSide = (across * bestSide):Dot(base.RightVector) >= 0 and 1 or -1
		spot:SetAttribute("SignSide", signSide)
		hidden("AvoidArea", base * CFrame.new(signSide * 1.9, 3, -1.4), Vector3.new(12, 10, 20), model) -- deck, front piece and panel
		model.PrimaryPart = spot
		table.insert(out, string.format("%s: spot (%.0f, %.0f) faces %s, panel side %d", plot.Name, base.X, base.Z, tostring(base.LookVector), signSide))
	end
end

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return table.concat(out, "\n")
