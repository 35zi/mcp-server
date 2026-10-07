-- BunnyBrain: hop-only wandering + idle animation for the Bunny model.
-- Put this Script inside the Bunny model (PrimaryPart = Body). All parts stay Anchored;
-- every frame the script moves them together with BulkMoveTo.
local RunService = game:GetService("RunService")

local model = script.Parent
local body = model.PrimaryPart or model:FindFirstChild("Body")

-- Tuning
local HOP_TIME = 0.5 -- seconds in the air per hop
local HOP_HEIGHT = 2.2
local HOP_DIST = 4.5 -- studs per hop
local LAND_PAUSE = 0.2 -- little crouch between hops
local WANDER_RADIUS = 30 -- never roam further than this from the start spot
local TURN_SPEED = 7 -- radians per second

local rng = Random.new()

-- Remember each part's position relative to the body
local parts, offs = {}, {}
local bodyCF0 = body.CFrame
for _, p in ipairs(model:GetChildren()) do
	if p:IsA("BasePart") then
		table.insert(parts, p)
		offs[p] = bodyCF0:ToObjectSpace(p.CFrame)
	end
end

-- Ear + head groups pivot around a point in body space
local function pivotOf(partName, localPoint)
	local p = model:FindFirstChild(partName)
	return offs[p]:PointToWorldSpace(localPoint)
end
local earGroups = {
	L = { names = { "EarL", "EarInnerL" }, pivot = pivotOf("EarL", Vector3.new(0, -1.7, 0)) },
	R = { names = { "EarR", "EarInnerR" }, pivot = pivotOf("EarR", Vector3.new(0, -1.7, 0)) },
}
local headNames = { "Head", "Muzzle", "EyeL", "EyeR", "Nose", "CheekL", "CheekR" }
local headPivot = pivotOf("Head", Vector3.new(0, -1.3, 1.3))

local function rotAbout(pivot, angle)
	return CFrame.new(pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(-pivot)
end

local home = bodyCF0.Position
local pos = home
local _, yaw0 = bodyCF0:ToEulerAnglesYXZ()
local yaw, targetYaw = yaw0, yaw0

local state = "idle"
local stateT = 0
local idleDur = rng:NextNumber(1.5, 3)
local nextFlick = rng:NextNumber(0.6, 1.8)
local flickT, flickSide = nil, "L"
local hopsLeft, hopFrom, hopTo, step = 0, pos, pos, Vector3.zero
local clock = 0

local function startWander()
	local ang = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(7, 16)
	local target = pos + Vector3.new(math.cos(ang), 0, math.sin(ang)) * dist
	local fromHome = target - home
	if fromHome.Magnitude > WANDER_RADIUS then
		target = home + fromHome.Unit * WANDER_RADIUS
	end
	local delta = target - pos
	hopsLeft = math.max(1, math.ceil(delta.Magnitude / HOP_DIST))
	step = delta / hopsLeft
	targetYaw = math.atan2(-delta.X, -delta.Z)
	state, stateT = "turn", 0
end

local function angleDiff(a, b)
	return ((b - a + math.pi) % (2 * math.pi)) - math.pi
end

local conn
conn = RunService.Heartbeat:Connect(function(dt)
	if not model.Parent then
		conn:Disconnect()
		return
	end
	clock += dt
	stateT += dt

	-- Smoothly face the target direction
	local diff = angleDiff(yaw, targetYaw)
	yaw += math.clamp(diff, -TURN_SPEED * dt, TURN_SPEED * dt)

	local yOff, pitch, earBack, nod = 0, 0, 0, 0
	local earFlick = { L = 0, R = 0 }

	if state == "idle" then
		-- breathing, sniffing and the odd ear flick
		yOff = 0.05 * math.sin(clock * 2.6)
		local gate = math.clamp(math.sin(clock * 0.8) * 3, 0, 1)
		nod = 0.09 * math.sin(clock * 10) * gate
		earBack = 0.04 * math.sin(clock * 1.7)
		if not flickT and stateT > nextFlick then
			flickT, flickSide = 0, (rng:NextInteger(1, 2) == 1) and "L" or "R"
		end
		if flickT then
			flickT += dt
			earFlick[flickSide] = 0.55 * math.sin(math.pi * math.min(flickT / 0.25, 1))
			if flickT >= 0.25 then
				flickT = nil
				nextFlick = stateT + rng:NextNumber(0.8, 2.2)
			end
		end
		if stateT >= idleDur then
			startWander()
		end
	elseif state == "turn" then
		-- quick look in the new direction, then hop
		nod = -0.05
		if math.abs(angleDiff(yaw, targetYaw)) < 0.05 or stateT > 0.6 then
			state, stateT = "hop", 0
			hopFrom, hopTo = pos, pos + step
		end
	elseif state == "hop" then
		local p = math.min(stateT / HOP_TIME, 1)
		pos = hopFrom:Lerp(hopTo, p)
		yOff = HOP_HEIGHT * 4 * p * (1 - p)
		pitch = 0.3 * math.cos(math.pi * p) -- nose up on take-off, down on landing
		earBack = 0.6 * math.sin(math.pi * p) -- ears flop back in the air
		nod = 0.05 * math.sin(math.pi * p)
		if p >= 1 then
			pos = hopTo
			hopsLeft -= 1
			state, stateT = "land", 0
		end
	elseif state == "land" then
		local q = math.min(stateT / LAND_PAUSE, 1)
		yOff = -0.15 * math.sin(math.pi * q) -- crouch
		earBack = -0.15 * math.sin(math.pi * q)
		if q >= 1 then
			if hopsLeft > 0 then
				state, stateT = "hop", 0
				hopFrom, hopTo = pos, pos + step
			else
				state, stateT = "idle", 0
				idleDur = rng:NextNumber(2, 4)
				nextFlick = rng:NextNumber(0.6, 1.8)
				flickT = nil
			end
		end
	end

	local bodyCF = CFrame.new(pos + Vector3.new(0, yOff, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)

	local extra = {}
	for side, g in pairs(earGroups) do
		local r = rotAbout(g.pivot, earBack + earFlick[side])
		for _, n in ipairs(g.names) do
			extra[n] = r
		end
	end
	local headRot = rotAbout(headPivot, nod)
	for _, n in ipairs(headNames) do
		extra[n] = headRot
	end

	local cfs = table.create(#parts)
	for i, p in ipairs(parts) do
		cfs[i] = bodyCF * (extra[p.Name] or CFrame.identity) * offs[p]
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
