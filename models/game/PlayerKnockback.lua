-- PlayerKnockback (ModuleScript in ServerScriptService)
--
-- Knocks a player back and ragdolls them for a moment (a Yeti punch or any player weapon hit).
--   * the server makes the body floppy, so everyone sees it:
--       - new avatar joints (AnimationConstraint + BallSocketConstraint, "Avatar Joint Upgrade"): the
--         AnimationConstraints are switched off and the ball sockets that are already there hold the limbs
--       - classic Motor6D rigs: each Motor6D is swapped for a BallSocketConstraint
--   * the player's own client (StarterPlayerScripts.KnockbackClient) puts the Humanoid into the Physics state and
--     applies the push, because each client owns its own character's physics
--   * after `duration` seconds the joints come back and the client stands up again
-- Hitting someone who is already ragdolled pushes them again and restarts the timer.
--   Remote: ReplicatedStorage.Knockback  server -> client  FireClient("Ragdoll", velocity: Vector3) / FireClient("GetUp")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("Knockback")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "Knockback"
	remote.Parent = ReplicatedStorage
end

local PlayerKnockback = {}

local active = {} -- [character] = { saved, requiresNeck, token }
local gotUpAt = {} -- [player] = os.clock() when they last stood back up

local function ragdoll(character)
	local saved = { motors = {}, animated = {}, created = {}, collide = {} }
	local root = character:FindFirstChild("HumanoidRootPart")
	for _, joint in ipairs(character:GetDescendants()) do
		if joint:IsA("AnimationConstraint") and joint.Enabled then
			local p0 = joint.Attachment0 and joint.Attachment0.Parent
			local p1 = joint.Attachment1 and joint.Attachment1.Parent
			if p0 and p1 and p0 ~= root and p1 ~= root then
				joint.Enabled = false
				table.insert(saved.animated, joint)
			end
		end
	end
	for _, motor in ipairs(character:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Enabled and motor.Part0 and motor.Part1 and motor.Part0 ~= root and motor.Part1 ~= root then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollJoint"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = 50
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -35
			socket.TwistUpperAngle = 35
			socket.Parent = motor.Part0
			motor.Enabled = false
			table.insert(saved.motors, motor)
			table.insert(saved.created, a0)
			table.insert(saved.created, a1)
			table.insert(saved.created, socket)
		end
	end
	-- limbs collide while floppy, so they don't sink into the floor
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part ~= root then
			saved.collide[part] = part.CanCollide
			part.CanCollide = true
		end
	end
	return saved
end

local function restore(saved)
	for _, inst in ipairs(saved.created) do
		inst:Destroy()
	end
	for _, motor in ipairs(saved.motors) do
		if motor.Parent then
			motor.Enabled = true
		end
	end
	for _, joint in ipairs(saved.animated) do
		if joint.Parent then
			joint.Enabled = true
		end
	end
	for part, value in pairs(saved.collide) do
		if part.Parent then
			part.CanCollide = value
		end
	end
end

-- push `player` away from fromPos (power = studs/second sideways; they also pop up a bit) and ragdoll them
-- for `duration` seconds. Returns false if they have no living character.
function PlayerKnockback.Knock(player, fromPos, power, duration)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	power = power or 50
	duration = duration or 1.4
	local away = root.Position - fromPos
	away = Vector3.new(away.X, 0, away.Z)
	away = away.Magnitude > 0.1 and away.Unit or -root.CFrame.LookVector
	local velocity = away * power + Vector3.new(0, power * 0.45, 0)

	local state = active[character]
	if not state then
		local requiresNeck=humanoid.RequiresNeck
		humanoid.RequiresNeck = false -- disable before disconnecting the neck joint
		state = { saved = ragdoll(character), requiresNeck = requiresNeck, token = 0 }
		active[character] = state
	end
	state.token += 1
	local token = state.token
	remote:FireClient(player, "Ragdoll", velocity)

	task.delay(duration, function()
		if active[character] ~= state or state.token ~= token then
			return -- hit again meanwhile: the newer knock decides when they get up
		end
		active[character] = nil
		restore(state.saved)
		if humanoid.Parent then
			humanoid.RequiresNeck = state.requiresNeck
		end
		gotUpAt[player] = os.clock()
		if player.Parent and player.Character == character then
			remote:FireClient(player, "GetUp")
		end
	end)
	return true
end

function PlayerKnockback.IsRagdolled(player)
	return player.Character ~= nil and active[player.Character] ~= nil
end

-- may an attacker (the Yeti) hit this player now? Not while they're down, and not for `grace` seconds after
-- they got back up (so they can't be punched over and over without a chance to run)
function PlayerKnockback.Vulnerable(player, grace)
	if PlayerKnockback.IsRagdolled(player) then
		return false
	end
	return os.clock() - (gotUpAt[player] or -math.huge) >= (grace or 0)
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	gotUpAt[player] = nil
end)

return PlayerKnockback

