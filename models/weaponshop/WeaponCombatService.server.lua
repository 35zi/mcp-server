-- WeaponCombatService (Script in ServerScriptService)
--
-- Server side of shooting. The client (WeaponClient) only says "I pulled the trigger, aiming at this point";
-- everything that matters is decided here:
--   * the player must be alive, own the weapon and be holding it (Tool with attribute WeaponId)
--   * cooldown, spread, range and damage come from WeaponShopCatalog stats via WeaponStats (never from the client)
--   * the bullet starts at the gun's MuzzleAttachment (hip fire) or the head (aiming down sights), with a random
--     spread cone, and is raycast by the server
--   * any Humanoid that is hit takes damage (with a "creator" ObjectValue tag for kill credit)
-- Then every client is told what happened so they can draw the tracer, impact and (for others) sound + muzzle flash.
--
--   Remote: ReplicatedStorage.WeaponCombat (RemoteEvent)
--     client -> server  FireServer(weaponId, aimPoint: Vector3, aiming: boolean)
--     server -> clients FireAllClients(shooterUserId, weaponId, muzzlePos, hitPos, hitNormal, hitHumanoid: boolean)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local catalog = require(ReplicatedStorage:WaitForChild("WeaponShopCatalog"))
local WeaponStats = require(ReplicatedStorage:WaitForChild("WeaponStats"))

local combat = ReplicatedStorage:FindFirstChild("WeaponCombat")
if not combat then
	combat = Instance.new("RemoteEvent")
	combat.Name = "WeaponCombat"
	combat.Parent = ReplicatedStorage
end

local COOLDOWN_TOLERANCE = 0.85 -- accept shots slightly early to absorb network jitter
local MAX_ORIGIN_OFFSET = 10 -- studs a muzzle may be from the head before we distrust it

local lastShot = {}
local rng = Random.new()

local function finiteVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

combat.OnServerEvent:Connect(function(player, weaponId, aimPoint, aiming)
	if type(weaponId) ~= "string" or not finiteVector(aimPoint) then
		return
	end
	aiming = aiming == true

	local stats = WeaponStats.forId(catalog, weaponId)
	if not stats then
		return
	end
	if player:GetAttribute("Owns_" .. weaponId) ~= true then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not head then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponId") ~= weaponId then
		return
	end

	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < stats.Cooldown * COOLDOWN_TOLERANCE then
		return
	end
	lastShot[player] = now

	local handle = tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("MuzzleAttachment")
	local muzzlePos = muzzle and muzzle.WorldPosition or head.Position
	if (muzzlePos - head.Position).Magnitude > MAX_ORIGIN_OFFSET then
		muzzlePos = head.Position
	end
	local origin = aiming and head.Position or muzzlePos

	local toAim = aimPoint - origin
	local direction = toAim.Magnitude > 0.5 and toAim.Unit or head.CFrame.LookVector
	local spread = math.rad(aiming and stats.SpreadAds or stats.SpreadHip)
	local cone = CFrame.lookAt(origin, origin + direction)
		* CFrame.Angles(0, 0, rng:NextNumber(0, 2 * math.pi))
		* CFrame.Angles(math.sqrt(rng:NextNumber()) * spread, 0, 0)
	direction = cone.LookVector

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, direction * stats.Range, params)

	local hitPos = result and result.Position or origin + direction * stats.Range
	local hitNormal = result and result.Normal or -direction
	local hitHumanoid = false
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local victim = model and model ~= character and model:FindFirstChildOfClass("Humanoid")
		if victim and victim.Health > 0 then
			local tag = Instance.new("ObjectValue")
			tag.Name = "creator"
			tag.Value = player
			tag.Parent = victim
			Debris:AddItem(tag, 2)
			victim:TakeDamage(stats.Damage)
			hitHumanoid = true
		end
	end

	combat:FireAllClients(player.UserId, weaponId, muzzlePos, hitPos, hitNormal, hitHumanoid)
end)

Players.PlayerRemoving:Connect(function(player)
	lastShot[player] = nil
end)
