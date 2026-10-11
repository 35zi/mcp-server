-- GunPoseService (Script in ServerScriptService)
-- Relays where each player aims their gun, so every client can pose that player's arms
-- (StarterPlayer.StarterPlayerScripts.GunHoldClient). The owner sends aim on/off + pitch/yaw relative to their
-- HumanoidRootPart through ReplicatedStorage.GunPose; this puts them on the character as GunAim / GunPitch / GunYaw.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:FindFirstChild("GunPose")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GunPose"
	remote.Parent = ReplicatedStorage
end

local last = {}
remote.OnServerEvent:Connect(function(player, aim, pitch, yaw)
	local now = os.clock()
	if now - (last[player] or 0) < 0.05 then
		return
	end
	last[player] = now
	if type(aim) ~= "boolean" or type(pitch) ~= "number" or type(yaw) ~= "number" or pitch ~= pitch or yaw ~= yaw then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("GunAim", aim)
	character:SetAttribute("GunPitch", math.clamp(pitch, -1.5, 1.5))
	character:SetAttribute("GunYaw", math.clamp(yaw, -math.pi, math.pi))
end)
Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
