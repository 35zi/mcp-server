-- WeaponCombatService (Script in ServerScriptService)
--
-- Server side of shooting. The client (WeaponClient) shows the shot instantly and tells the server
-- "I fired weapon X at this point (and hit this part)"; everything that matters is decided here:
--   * the player must be alive, own the weapon and be holding it (Tool with attribute WeaponId)
--   * cooldown, range and damage come from WeaponShopCatalog stats via WeaponStats (never from the client)
--   * no random spread: the bullet goes exactly where the player aimed
--   * animals (Workspace.Animals): the client's hit is accepted if the hit point is close to that animal
--     (allows for network lag) and no wall is in the way; the animal is damaged through AnimalManager
--   * anything else: the server raycasts from the muzzle (hip fire) or the head (aiming down sights) and damages
--     any Humanoid it hits (with a "creator" tag for kill credit)
-- Then every client is told what happened (tracer, impact, sound, hit confirmation).
--
--   Remote: ReplicatedStorage.WeaponCombat (RemoteEvent)
--     client -> server  FireServer(weaponId, aimPoint: Vector3, aiming: boolean, hitPart: BasePart?)
--     server -> clients FireAllClients(shooterUserId, weaponId, muzzlePos, hitPos, hitNormal, kind)
--                       kind = "none" | "world" | "humanoid" | "animal" | "killed"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local catalog = require(ReplicatedStorage:WaitForChild("WeaponShopCatalog"))
local WeaponStats = require(ReplicatedStorage:WaitForChild("WeaponStats"))
local AnimalManager = require(ServerScriptService:WaitForChild("AnimalManager"))

local combat = ReplicatedStorage:FindFirstChild("WeaponCombat")
if not combat then
	combat = Instance.new("RemoteEvent")
	combat.Name = "WeaponCombat"
	combat.Parent = ReplicatedStorage
end

local COOLDOWN_TOLERANCE = 0.85 -- accept shots slightly early to absorb network jitter
local MAX_ORIGIN_OFFSET = 10 -- studs a muzzle may be from the head before we distrust it
local ANIMAL_LAG_TOLERANCE = 6 -- studs an animal may have moved between the client's view and the server's

local lastShot = {}

local function finiteVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

combat.OnServerEvent:Connect(function(player, weaponId, aimPoint, aiming, hitPart)
	if type(weaponId) ~= "string" or not finiteVector(aimPoint) then
		return
	end
	aiming = aiming == true

	local stats = WeaponStats.forId(catalog, weaponId)
	if not stats or player:GetAttribute("Owns_" .. weaponId) ~= true then
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
	local distance = toAim.Magnitude
	local direction = distance > 0.05 and toAim.Unit or head.CFrame.LookVector
	if distance > stats.Range + 4 then
		aimPoint = origin + direction * stats.Range
		distance = stats.Range
		hitPart = nil
	end

	local hitPos, hitNormal, kind = aimPoint, -direction, "none"

	-- 1) the client says it hit an animal: accept it if it's plausible
	local animal = typeof(hitPart) == "Instance" and hitPart:IsA("BasePart") and AnimalManager.FromPart(hitPart)
	if animal then
		local near = (AnimalManager.Position(animal) - aimPoint).Magnitude <= ANIMAL_LAG_TOLERANCE + hitPart.Size.Magnitude
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, AnimalManager.Folder() }
		local wall = workspace:Raycast(origin, direction * math.max(distance - 0.5, 0), params)
		if near and not wall then
			kind = AnimalManager.Damage(animal, stats.Damage, player, aimPoint) == "killed" and "killed" or "animal"
		else
			animal = nil
		end
	end

	-- 2) otherwise the server traces the shot itself
	if not animal then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local result = workspace:Raycast(origin, direction * math.min(distance + 2, stats.Range), params)
		if result then
			hitPos, hitNormal, kind = result.Position, result.Normal, "world"
			local hitAnimal = AnimalManager.FromPart(result.Instance)
			if hitAnimal then
				kind = AnimalManager.Damage(hitAnimal, stats.Damage, player, result.Position) == "killed" and "killed" or "animal"
			else
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				local victim = model and model ~= character and model:FindFirstChildOfClass("Humanoid")
				if victim and victim.Health > 0 then
					local tag = Instance.new("ObjectValue")
					tag.Name = "creator"
					tag.Value = player
					tag.Parent = victim
					Debris:AddItem(tag, 2)
					victim:TakeDamage(stats.Damage)
					kind = "humanoid"
				end
			end
		end
	end

	combat:FireAllClients(player.UserId, weaponId, muzzlePos, hitPos, hitNormal, kind)
end)

Players.PlayerRemoving:Connect(function(player)
	lastShot[player] = nil
end)
