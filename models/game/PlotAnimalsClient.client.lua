-- PlotAnimalsClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Animals placed on plots (Workspace.PlotAnimals, see InventoryService) wander around their plot: idle a moment,
-- turn, hop / scuttle (same moves as in the wild, from AnimalData) to a random spot inside the plot, repeat.
-- This is only the look: every client moves them locally and the server keeps them where it put them, so it costs
-- the server nothing. The area comes from model attributes AreaCFrame / AreaHalf (+ Avoid = the plot's spawn point).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimalData = require(ReplicatedStorage:WaitForChild("AnimalData"))
local AnimalRig = require(ReplicatedStorage:WaitForChild("AnimalRig"))
local plotAnimals = workspace:WaitForChild("PlotAnimals")
local rng = Random.new()

local MAX_TRIP = 14 -- studs per walk (times the animal's size)
local AVOID_RADIUS = 6 -- keep this far from the plot's spawn point

-- the treadmill corner of each plot (Workspace.Treadmills.<Plot>.AvoidArea, models/speed/BuildTreadmills) is off
-- limits: no trip may end in it or cut through it (a trip that starts inside may leave it)
local function crossesAvoid(from, to, margin)
	local folder = workspace:FindFirstChild("Treadmills")
	if not folder then
		return false
	end
	for _, treadmill in ipairs(folder:GetChildren()) do
		local box = treadmill:FindFirstChild("AvoidArea")
		if box then
			local a = box.CFrame:PointToObjectSpace(from)
			local b = box.CFrame:PointToObjectSpace(to)
			local hx, hz = box.Size.X / 2 + margin, box.Size.Z / 2 + margin
			if math.abs(b.X) < hx and math.abs(b.Z) < hz then
				return true
			end
			if not (math.abs(a.X) < hx and math.abs(a.Z) < hz) then
				-- does the segment a -> b pass through the box? (slab test on X and Z)
				local t0, t1 = 0, 1
				local hit = true
				for _, axis in ipairs({ { a.X, b.X - a.X, hx }, { a.Z, b.Z - a.Z, hz } }) do
					local start, delta, half = axis[1], axis[2], axis[3]
					if math.abs(delta) < 1e-6 then
						if math.abs(start) >= half then
							hit = false
							break
						end
					else
						local e0, e1 = (-half - start) / delta, (half - start) / delta
						if e0 > e1 then
							e0, e1 = e1, e0
						end
						t0, t1 = math.max(t0, e0), math.min(t1, e1)
						if t0 > t1 then
							hit = false
							break
						end
					end
				end
				if hit then
					return true
				end
			end
		end
	end
	return false
end

local animals = {} -- [model] = state

---------------------------------------------------------------- the model's root frame (bottom centre, facing front)
local CORNERS = {}
for _, x in ipairs({ -0.5, 0.5 }) do
	for _, y in ipairs({ -0.5, 0.5 }) do
		for _, z in ipairs({ -0.5, 0.5 }) do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

local function rootOf(model)
	local look = model.PrimaryPart.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local frame = CFrame.Angles(0, yaw, 0)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			for _, c in ipairs(CORNERS) do
				local p = frame:PointToObjectSpace(d.CFrame * (c * d.Size))
				low = low:Min(p)
				high = high:Max(p)
			end
		end
	end
	local bottom = frame:PointToWorldSpace(Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2))
	local root = CFrame.new(bottom) * frame
	local offsets = table.create(#parts)
	for i, d in ipairs(parts) do
		offsets[i] = root:ToObjectSpace(d.CFrame)
	end
	return parts, offsets, bottom, yaw
end

---------------------------------------------------------------- wandering
local function angleDiff(a, b)
	return ((b - a + math.pi) % (2 * math.pi)) - math.pi
end

local function startTrip(a)
	for _ = 1, 12 do
		local spot = a.area:PointToWorldSpace(Vector3.new(rng:NextNumber(-a.half.X, a.half.X), 0, rng:NextNumber(-a.half.Y, a.half.Y)))
		spot = Vector3.new(spot.X, a.groundY, spot.Z)
		local delta = spot - a.pos
		local maxTrip = MAX_TRIP * a.scale
		if delta.Magnitude > maxTrip then
			spot = a.pos + delta.Unit * maxTrip
			delta = spot - a.pos
		end
		local clear = not a.avoid or Vector3.new(spot.X - a.avoid.X, 0, spot.Z - a.avoid.Z).Magnitude > AVOID_RADIUS
		if clear and crossesAvoid(a.pos, spot, 1.5 * a.scale) then
			clear = false
		end
		for _, other in pairs(animals) do -- don't walk into a friend
			if clear and other ~= a and (Vector3.new(spot.X - other.pos.X, 0, spot.Z - other.pos.Z)).Magnitude < 4 * math.max(a.scale, other.scale) then
				clear = false
			end
		end
		if delta.Magnitude > 2 and clear then
			local hopDist = (a.cfg.hopDist or 3) * a.scale
			a.hopsLeft = math.max(1, math.ceil(delta.Magnitude / hopDist))
			a.step = delta / a.hopsLeft
			a.targetYaw = math.atan2(-delta.X, -delta.Z)
			a.state, a.stateT = "turn", 0
			return
		end
	end
	a.state, a.stateT, a.idleDur = "idle", 0, rng:NextNumber(1, 2)
end

local function step(a, dt)
	local cfg, scale = a.cfg, a.scale
	local walk = AnimalRig.IsWalker(a.species)
	a.clock += dt
	a.stateT += dt
	a.yaw += math.clamp(angleDiff(a.yaw, a.targetYaw), -6 * dt, 6 * dt)
	local yOff, pitch = 0, 0
	if a.state == "idle" then
		yOff = 0.04 * scale * math.sin(a.clock * 2.6)
		if a.stateT >= a.idleDur then
			startTrip(a)
		end
	elseif a.state == "turn" then
		if math.abs(angleDiff(a.yaw, a.targetYaw)) < 0.06 or a.stateT > 0.6 then
			a.state, a.stateT, a.hopFrom = "hop", 0, a.pos
		end
	elseif a.state == "hop" then
		local hopTime = cfg.hopTime or 0.4
		local p = math.min(a.stateT / hopTime, 1)
		a.pos = a.hopFrom:Lerp(a.hopFrom + a.step, p)
		yOff = (walk and math.min(cfg.hopHeight or 0.05, 0.06) or (cfg.hopHeight or 1)) * scale * 4 * p * (1 - p)
		pitch = walk and 0 or 0.3 * math.cos(math.pi * p)
		if p >= 1 then
			a.hopsLeft -= 1
			a.state, a.stateT = "land", 0
		end
	elseif a.state == "land" then
		local landTime = walk and 0.04 or 0.16
		local q = math.min(a.stateT / landTime, 1)
		yOff = walk and 0 or -0.12 * scale * math.sin(math.pi * q)
		if q >= 1 then
			if a.hopsLeft > 0 then
				a.state, a.stateT, a.hopFrom = "hop", 0, a.pos
			else
				a.state, a.stateT, a.idleDur = "idle", 0, rng:NextNumber(1.5, 5)
			end
		end
	end
	-- Local state is consumed by AnimalAnimationClient; it never travels to the server.
	a.model:SetAttribute("AnimState", a.state)
	if a.animState ~= a.state then
		a.animState = a.state
		a.model:SetAttribute("AnimStartedAt", workspace:GetServerTimeNow() - a.stateT)
		a.model:SetAttribute("AnimDuration", cfg.hopTime or 0.4)
	end
	return CFrame.new(a.pos + Vector3.new(0, yOff, 0)) * CFrame.Angles(0, a.yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

---------------------------------------------------------------- tracking the plot animals
local function add(model)
	if animals[model] or not model:IsA("Model") then
		return
	end
	task.spawn(function()
		local waited = 0
		while model.Parent and (not model.PrimaryPart or not model:GetAttribute("AreaCFrame")) and waited < 10 do
			waited += task.wait(0.1)
		end
		if not model.Parent or not model.PrimaryPart or animals[model] then
			return
		end
		local parts, offsets, bottom, yaw = rootOf(model)
		animals[model] = {
			model = model,
			species = model:GetAttribute("Species") or model:GetAttribute("RigSpecies"),
			rootIndex = AnimalRig.RootIndex(model, parts),
			parts = parts,
			offsets = offsets,
			cfg = AnimalData.Species[model:GetAttribute("Species")] or {},
			scale = model:GetAttribute("Scale") or 1,
			area = model:GetAttribute("AreaCFrame"),
			half = model:GetAttribute("AreaHalf") or Vector2.new(15, 15),
			avoid = model:GetAttribute("Avoid"),
			groundY = bottom.Y,
			pos = bottom,
			yaw = yaw,
			targetYaw = yaw,
			state = "idle",
			stateT = 0,
			idleDur = rng:NextNumber(0.5, 3),
			hopsLeft = 0,
			step = Vector3.zero,
			hopFrom = bottom,
			clock = rng:NextNumber(0, 10),
		}
	end)
end

local function watchOwnerFolder(folder)
	folder.ChildAdded:Connect(add)
	for _, model in ipairs(folder:GetChildren()) do
		add(model)
	end
end
plotAnimals.ChildAdded:Connect(watchOwnerFolder)
for _, folder in ipairs(plotAnimals:GetChildren()) do
	watchOwnerFolder(folder)
end

RunService.Heartbeat:Connect(function(dt)
	local allParts, allCFrames = {}, {}
	for model, a in pairs(animals) do
		if not model.Parent or not a.parts[1].Parent then
			animals[model] = nil -- taken back (or streamed out: it comes back through ChildAdded)
		else
			local root = step(a, math.min(dt, 0.1))
			table.insert(allParts, model.PrimaryPart)
			table.insert(allCFrames, root * a.offsets[a.rootIndex])
		end
	end
	if #allParts > 0 then
		workspace:BulkMoveTo(allParts, allCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

