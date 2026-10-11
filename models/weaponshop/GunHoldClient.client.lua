-- GunHoldClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Real-life gun holding for every character holding a weapon (a Tool with a WeaponId):
--   * both hands on the gun: the right hand holds the grip (the gun is welded to it); the left hand cups the right
--     hand (pistols) or holds the handguard (long guns, the tool's SupportPos). Two-bone arm IK sets the shoulder,
--     elbow and wrist joints every frame after Roblox's own animations, so it fits any avatar size.
--   * standing / walking: "low ready" - gun at the chest, muzzle angled down
--   * aiming (right mouse) or shooting: the gun comes up to eye level and points where you aim; long guns go to
--     the shoulder with the cheek on the stock
--   * running: the upper body leans into the run, the gun is pulled in close and bobs / sways with the steps
-- The legs keep Roblox's normal walk / run animation. Others see where you aim: this client sends its aim through
-- ReplicatedStorage.GunPose and ServerScriptService.GunPoseService puts GunAim / GunPitch / GunYaw on the character.
-- Skipped while ragdolled (joints off), while carrying an animal (Dragging) and when dead.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GunPose")

local LONG_GUN = 3.0 -- studs from grip to muzzle; longer weapons are held at the shoulder (Python 2.6, Revolver 2.8, rifles 3.15+)
local SMOOTH = 14 -- how fast the gun follows its target pose
local AIM_HOLD = 0.7 -- seconds the gun stays up after a hip-fire shot
local SEND_EVERY = 0.1 -- seconds between aim updates sent to the server

local states = {} -- [character] = per-character pose state

---------------------------------------------------------------- joints (Motor6D or the newer AnimationConstraint)
local function frames(j)
	if j:IsA("Motor6D") then
		return j.C0, j.C1
	end
	return j.Attachment0.CFrame, j.Attachment1.CFrame
end

local function alive(j)
	if not j or not j.Parent then
		return false
	end
	if j:IsA("Motor6D") then
		return j.Enabled and j.Part0 ~= nil and j.Part1 ~= nil
	end
	return j.Enabled and j.Attachment0 ~= nil and j.Attachment1 ~= nil
end

local function rigOf(character)
	local function joint(partName, name)
		local part = character:FindFirstChild(partName)
		local j = part and part:FindFirstChild(name)
		if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
			return j
		end
		return nil
	end
	local rig = {
		waist = joint("UpperTorso", "Waist"),
		neck = joint("Head", "Neck"),
		rs = joint("RightUpperArm", "RightShoulder"),
		re = joint("RightLowerArm", "RightElbow"),
		rw = joint("RightHand", "RightWrist"),
		ls = joint("LeftUpperArm", "LeftShoulder"),
		le = joint("LeftLowerArm", "LeftElbow"),
		lw = joint("LeftHand", "LeftWrist"),
	}
	for _, key in ipairs({ "waist", "rs", "re", "rw", "ls", "le", "lw" }) do
		if not rig[key] then
			return nil
		end
	end
	return rig
end

---------------------------------------------------------------- two-bone arm IK (everything in UpperTorso space)
-- the part whose bone runs from p1 to p2 (part space) placed so p1 lands on A and p2 on B; its X axis follows the hinge
local function place(p1, p2, A, B, hinge)
	local yP = (p1 - p2).Unit
	local xP = (Vector3.xAxis - yP * Vector3.xAxis:Dot(yP)).Unit
	local zP = xP:Cross(yP)
	local yW = (A - B).Unit
	local xW = hinge - yW * hinge:Dot(yW)
	if xW.Magnitude < 1e-5 then
		xW = yW:Cross(Vector3.zAxis)
	end
	xW = xW.Unit
	local zW = xW:Cross(yW)
	local rotation = CFrame.fromMatrix(Vector3.zero, xW, yW, zW) * CFrame.fromMatrix(Vector3.zero, xP, yP, zP):Inverse()
	return CFrame.new(A) * rotation * CFrame.new(-p1)
end

local function armInfo(sh, el, wr)
	local s0, s1 = frames(sh)
	local e0, e1 = frames(el)
	local w0, w1 = frames(wr)
	return {
		s0 = s0, s1 = s1, e0 = e0, e1 = e1, w0 = w0, w1 = w1,
		upper = (e0.Position - s1.Position).Magnitude,
		lower = (w0.Position - e1.Position).Magnitude,
	}
end

-- joint Transforms so the hand ends at `hand` (UpperTorso space); `pole` = where the elbow points
local function solveArm(arm, hand, pole, side)
	local S = arm.s0.Position
	local W = (hand * arm.w1).Position
	local a, b = arm.upper, arm.lower
	local toW = W - S
	local d = math.clamp(toW.Magnitude, math.abs(a - b) + 1e-3, a + b - 1e-3)
	local dir = toW.Magnitude > 1e-4 and toW.Unit or Vector3.new(0, -1, 0)
	local cosA = math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1)
	local along, height = a * cosA, a * math.sqrt(1 - cosA * cosA)
	local perp = pole - dir * pole:Dot(dir)
	perp = perp.Magnitude > 1e-4 and perp.Unit or dir:Cross(Vector3.xAxis).Unit
	local E = S + dir * along + perp * height
	local Wr = S + dir * d
	local hinge = (E - S):Cross(Wr - E)
	if hinge.Magnitude < 1e-5 then
		hinge = dir:Cross(perp)
	end
	hinge = hinge.Unit * side
	local upperArm = place(arm.s1.Position, arm.e0.Position, S, E, hinge)
	local lowerArm = place(arm.e1.Position, arm.w0.Position, E, Wr, hinge)
	return arm.s0:Inverse() * upperArm * arm.s1,
		arm.e0:Inverse() * upperArm:Inverse() * lowerArm * arm.e1,
		arm.w0:Inverse() * lowerArm:Inverse() * hand * arm.w1
end

---------------------------------------------------------------- the weapon
local function weaponOf(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") and child:FindFirstChild("Handle") then
			return child
		end
	end
	return nil
end

-- grip-space facts about a tool, measured once: muzzle, rear sight, support point, rear end of the stock
local function gunInfo(tool)
	local handle = tool.Handle
	local rear = 0
	for _, p in ipairs(tool:GetDescendants()) do
		if p:IsA("BasePart") and p ~= handle then
			local rel = handle.CFrame:ToObjectSpace(p.CFrame)
			local s = p.Size / 2
			for _, x in ipairs({ -1, 1 }) do
				for _, y in ipairs({ -1, 1 }) do
					for _, z in ipairs({ -1, 1 }) do
						rear = math.max(rear, (rel * Vector3.new(s.X * x, s.Y * y, s.Z * z)).Z)
					end
				end
			end
		end
	end
	local muzzle = tool:GetAttribute("MuzzlePos") or Vector3.new(0, 0.6, -2.5)
	local supportPos = tool:GetAttribute("SupportPos")
	-- a handguard well ahead of the grip means a two-handed long gun; pistols keep SupportPos at the grip
	local long = if supportPos then supportPos.Z < -0.6 else math.abs(muzzle.Z) > LONG_GUN
	return {
		long = long,
		eye = tool:GetAttribute("EyePos") or Vector3.new(0, 1, 0),
		support = long and (supportPos or Vector3.new(0, -0.1, -1.6)) or Vector3.new(-0.2, -0.18, 0.05),
		butt = Vector3.new(0, 0.15, rear - 0.15),
		grip = tool.Grip, -- the tool's resting grip (WeaponClient only adds a little kick on top)
	}
end

---------------------------------------------------------------- aim (local player) + what others sent
local camera = workspace.CurrentCamera
local lastShot = 0
local lastSent, sentAim, sentPitch, sentYaw = 0, false, 0, 0

local function rayParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	return params
end

-- world aim direction for the local player, or nil when the gun can stay at low ready
local function localAim(character, root)
	camera = workspace.CurrentCamera
	if camera.CameraType == Enum.CameraType.Scriptable then -- WeaponClient owns the camera while aiming down sights
		return camera.CFrame.LookVector
	end
	if os.clock() - lastShot < AIM_HOLD then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams(character))
		local point = hit and hit.Position or ray.Origin + ray.Direction * 1000
		local from = root.Position + Vector3.new(0, 1.5, 0)
		return (point - from).Magnitude > 0.5 and (point - from).Unit or root.CFrame.LookVector
	end
	return nil
end

local function send(root, dir)
	local now = os.clock()
	if now - lastSent < SEND_EVERY then
		return
	end
	local aim, pitch, yaw = dir ~= nil, 0, 0
	if dir then
		local rel = root.CFrame:VectorToObjectSpace(dir)
		pitch = math.asin(math.clamp(rel.Y, -1, 1))
		yaw = math.atan2(-rel.X, -rel.Z)
	end
	if aim == sentAim and math.abs(pitch - sentPitch) < 0.03 and math.abs(yaw - sentYaw) < 0.03 then
		return
	end
	lastSent, sentAim, sentPitch, sentYaw = now, aim, pitch, yaw
	remote:FireServer(aim, pitch, yaw)
end

local function remoteAim(character, root)
	if character:GetAttribute("GunAim") ~= true then
		return nil
	end
	local pitch, yaw = character:GetAttribute("GunPitch") or 0, character:GetAttribute("GunYaw") or 0
	local rel = Vector3.new(-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	return root.CFrame:VectorToWorldSpace(rel)
end

---------------------------------------------------------------- one character, one frame
local function release(character, state)
	-- hand the joints back to Roblox's animations (they only rewrite joints that an animation moves)
	if state.rig then
		for _, key in ipairs({ "rs", "re", "rw", "ls", "le", "lw" }) do
			local j = state.rig[key]
			if j and j.Parent then
				j.Transform = CFrame.identity
			end
		end
		local waist = state.rig.waist
		if waist and waist.Parent and state.waistWritten and waist.Transform == state.waistWritten then
			waist.Transform = state.waistBase or CFrame.identity
		end
	end
	states[character] = nil
end

local function pose(character, dt, isLocal)
	local state = states[character]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local lowerTorso = character:FindFirstChild("LowerTorso")
	local rightHand = character:FindFirstChild("RightHand")
	local leftHand = character:FindFirstChild("LeftHand")
	local tool = weaponOf(character)
	local grip = rightHand and rightHand:FindFirstChild("RightGrip")
	local carrying = Players:GetPlayerFromCharacter(character)
	carrying = carrying and carrying:GetAttribute("Dragging")
	if not (tool and grip and humanoid and humanoid.Health > 0 and root and lowerTorso and leftHand) or carrying then
		if state then
			release(character, state)
		end
		if isLocal and root then
			send(root, nil)
		end
		return
	end
	if not state or state.tool ~= tool or not state.rig or not alive(state.rig.waist) then
		if state then
			release(character, state)
		end
		local rig = rigOf(character)
		if not rig then
			return
		end
		state = { tool = tool, rig = rig, gun = nil, phase = 0, info = gunInfo(tool) }
		states[character] = state
	end
	local rig = state.rig
	for _, key in ipairs({ "waist", "rs", "re", "rw", "ls", "le", "lw" }) do
		if not alive(rig[key]) then -- ragdolled: the physics owns the body
			release(character, state)
			return
		end
	end
	local info = state.info

	-- movement: how much we run, and where we are in the stride
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local run = math.clamp((speed - 10) / 10, 0, 1)
	local moving = math.clamp(speed / 6, 0, 1)
	state.phase = (state.phase + dt * math.clamp(speed, 0, 40) * 0.45) % (math.pi * 2)
	local phase = state.phase

	-- upper body leans into the run and counter-twists with the steps (on top of the run animation)
	local waist = rig.waist
	local current = waist.Transform
	local base = (state.waistWritten and current == state.waistWritten) and state.waistBase or current
	local lean = math.rad(10) * run + math.rad(3) * moving * (1 - run)
	local twist = math.rad(6) * math.sin(phase) * run
	local waistT = base * CFrame.Angles(-lean, twist, 0)
	state.waistBase, state.waistWritten = base, waistT
	waist.Transform = waistT
	local w0, w1 = frames(waist)
	local torso = lowerTorso.CFrame * w0 * waistT * w1:Inverse() -- where UpperTorso will be this frame

	-- where the gun points
	local aimWorld
	if isLocal then
		aimWorld = localAim(character, root)
		send(root, aimWorld)
	else
		aimWorld = remoteAim(character, root)
	end

	-- target pose of the grip (handle) in UpperTorso space; the gun's forward is -Z
	local head = character:FindFirstChild("Head")
	local n0 = rig.neck and select(1, frames(rig.neck)) or CFrame.new(0, 0.85, 0)
	local headSize = head and head.Size or Vector3.new(1.2, 1.2, 1.2)
	local eye = n0.Position + Vector3.new(0, headSize.Y * 0.45, -headSize.Z * 0.3)
	local target
	if aimWorld then
		local A = torso:VectorToObjectSpace(aimWorld)
		local rot = CFrame.lookAt(Vector3.zero, A, Vector3.yAxis)
		if info.long then
			-- shouldered: rear sight just in front of the right eye, cheek on the stock
			local sight = eye + Vector3.new(0.22, -0.05, 0) + A * 0.35
			target = CFrame.new(sight) * rot * CFrame.new(-info.eye)
		else
			-- two-handed pistol, arms pushed out towards the target
			local sight = eye + Vector3.new(0.05, -0.15, 0) + A * 1.5
			target = CFrame.new(sight) * rot * CFrame.new(-info.eye)
		end
	elseif info.long then
		-- low ready (walking) / tucked across the chest (running): stock in the right shoulder pocket
		local pocket = Vector3.new(0.55, 0.3, -0.55)
		local ready = CFrame.Angles(math.rad(-28), math.rad(10), 0)
		local sprint = CFrame.Angles(math.rad(-38), math.rad(28), math.rad(-18))
		local rot = ready:Lerp(sprint, run)
		local at = pocket:Lerp(Vector3.new(0.45, 0.15, -0.6), run)
		target = CFrame.new(at) * rot * CFrame.new(-info.butt)
	else
		-- pistol low ready: at the chest, muzzle down; pulled in closer while running
		local ready = CFrame.new(0.2, -0.3, -1.15) * CFrame.Angles(math.rad(-30), 0, 0)
		local sprint = CFrame.new(0.15, -0.35, -0.85) * CFrame.Angles(math.rad(-52), 0, 0)
		target = ready:Lerp(sprint, run)
	end
	local alpha = 1 - math.exp(-math.min(dt, 0.1) * SMOOTH)
	state.gun = state.gun and state.gun:Lerp(target, alpha) or target
	-- the steps: a little bounce and sway while moving (less when aiming)
	local bob = (aimWorld and 0.35 or 1) * moving
	local gun = state.gun
		* CFrame.new(0.03 * math.sin(phase) * bob, 0.05 * math.sin(phase * 2) * bob * (0.5 + run), 0)
		* CFrame.Angles(0.035 * math.sin(phase * 2) * bob, 0.04 * math.sin(phase) * bob, 0)

	-- right hand on the grip (the gun is welded to it); pull the gun in if the arm can't reach
	local c0 = grip.C0
	local rightArm = state.rightArm or armInfo(rig.rs, rig.re, rig.rw)
	local leftArm = state.leftArm or armInfo(rig.ls, rig.le, rig.lw)
	state.rightArm, state.leftArm = rightArm, leftArm
	local hand = gun * info.grip * c0:Inverse()
	local S = rightArm.s0.Position
	local W = (hand * rightArm.w1).Position
	local reach = (rightArm.upper + rightArm.lower) * 0.97
	if (W - S).Magnitude > reach then
		gun = gun + (S + (W - S).Unit * reach - W)
		hand = gun * info.grip * c0:Inverse()
	end
	local tS, tE, tW = solveArm(rightArm, hand, info.long and Vector3.new(0.8, -1, 0.5) or Vector3.new(0.6, -1, 0.5), 1)
	rig.rs.Transform, rig.re.Transform, rig.rw.Transform = tS, tE, tW

	-- left hand: cups the right hand (pistol) or holds the handguard (long gun)
	local leftGrip = leftHand:FindFirstChild("LeftGripAttachment")
	local leftGripCF = leftGrip and leftGrip.CFrame or CFrame.new(-c0.Position.X, c0.Position.Y, c0.Position.Z) * c0.Rotation
	local support = info.long and (gun * CFrame.new(info.support) * CFrame.Angles(0, 0, math.rad(-60)))
		or (gun * CFrame.new(info.support) * CFrame.Angles(0, 0, math.rad(-25)))
	local leftHandCF = support * leftGripCF:Inverse()
	local lS, lE, lW = solveArm(leftArm, leftHandCF, info.long and Vector3.new(-0.3, -1, 0.3) or Vector3.new(-0.6, -1, 0.5), -1)
	rig.ls.Transform, rig.le.Transform, rig.lw.Transform = lS, lE, lW
end

---------------------------------------------------------------- every frame, after the animations
local function watchShots(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			child.Activated:Connect(function()
				lastShot = os.clock()
			end)
		end
	end)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			child.Activated:Connect(function()
				lastShot = os.clock()
			end)
		end
	end
end
player.CharacterAdded:Connect(watchShots)
if player.Character then
	watchShots(player.Character)
end

local warned = {}
RunService.PreSimulation:Connect(function(dt)
	for character in pairs(states) do
		if not character.Parent then
			states[character] = nil
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if character and character.Parent then
			local ok, err = pcall(pose, character, dt, p == player)
			if not ok then
				if not warned[tostring(err)] then
					warned[tostring(err)] = true
					warn("GunHoldClient: " .. tostring(err))
				end
				local state = states[character]
				if state then
					release(character, state)
				end
			end
		end
	end
end)
