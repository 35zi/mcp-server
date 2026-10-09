-- KnockbackClient (LocalScript in StarterPlayerScripts)
-- The client half of PlayerKnockback (ServerScriptService): this client owns its character's physics, so it is
-- the one that goes floppy (Humanoid Physics state), gets pushed, and stands back up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Knockback")
local rng = Random.new()

remote.OnClientEvent:Connect(function(kind, velocity)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if kind == "Ragdoll" then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		-- push on the next physics step, once the Humanoid has let go (else it eats the push)
		RunService.Stepped:Wait()
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-3, 3), rng:NextNumber(-6, 6))
	elseif kind == "GetUp" then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)

