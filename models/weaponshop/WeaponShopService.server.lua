-- WeaponShopService (Script in ServerScriptService)
--
-- Server side of the Weapon Shop: owns purchases and equipping. The client (WeaponShopClient) only ASKS; every
-- request is validated here against ReplicatedStorage.WeaponShopCatalog.
--
--   Remote: ReplicatedStorage.WeaponShopRemote (RemoteFunction)
--     :InvokeServer("State")          -> state
--     :InvokeServer("Buy", id)        -> ok, message, state
--     :InvokeServer("Equip", id)      -> ok, message, state     (Equip of the equipped weapon unequips it)
--   state = { cash = number, owned = { [id] = true }, equipped = id | nil }
--
-- Ownership is kept as player attributes Owns_<Id> (session only: NO DataStore yet) and the equipped weapon as the
-- attribute EquippedWeapon. Tools come from ServerStorage.WeaponTools.<Id>; a copy also goes into StarterGear so the
-- weapon comes back after respawning.
--
-- TEMPORARY CURRENCY: there is no economy in the game yet, so Cash is a placeholder leaderstats value that lives
-- behind ServerScriptService.CashAdapter (shared with AnimalManager). Replace that module with the real economy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local catalog = require(ReplicatedStorage:WaitForChild("WeaponShopCatalog"))
local weaponTools = ServerStorage:WaitForChild("WeaponTools")

local byId = {}
for _, item in ipairs(catalog) do
	byId[item.Id] = item
end

local remote = ReplicatedStorage:FindFirstChild("WeaponShopRemote")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "WeaponShopRemote"
	remote.Parent = ReplicatedStorage
end

---------------------------------------------------------------- Cash (placeholder economy, see CashAdapter)
local CashAdapter = require(game:GetService("ServerScriptService"):WaitForChild("CashAdapter"))
local setupCash, getCash, spendCash = CashAdapter.Setup, CashAdapter.Get, CashAdapter.Spend

---------------------------------------------------------------- ownership + tools
local function owns(player, id)
	return player:GetAttribute("Owns_" .. id) == true
end

local function stateOf(player)
	local owned = {}
	for _, item in ipairs(catalog) do
		if owns(player, item.Id) then
			owned[item.Id] = true
		end
	end
	return { cash = getCash(player), owned = owned, equipped = player:GetAttribute("EquippedWeapon") }
end

local function findTool(player, id)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, holder in ipairs({ character, backpack }) do
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") == id then
					return child
				end
			end
		end
	end
	return nil
end

local function grantTool(player, id)
	local template = weaponTools:FindFirstChild(id)
	if not template then
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not findTool(player, id) then
		local tool = template:Clone()
		tool:SetAttribute("WeaponId", id)
		tool.Parent = backpack
	end
	local gear = player:FindFirstChild("StarterGear")
	if gear and not gear:FindFirstChild(template.Name) then
		local copy = template:Clone()
		copy:SetAttribute("WeaponId", id)
		copy.Parent = gear
	end
	return true
end

-- keep the EquippedWeapon attribute in step with what the character is really holding (hotbar included)
local function watchCharacter(player, character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			player:SetAttribute("EquippedWeapon", child:GetAttribute("WeaponId"))
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") and player:GetAttribute("EquippedWeapon") == child:GetAttribute("WeaponId") then
			player:SetAttribute("EquippedWeapon", nil)
		end
	end)
	player:SetAttribute("EquippedWeapon", nil)
end

local function onPlayer(player)
	setupCash(player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
		-- StarterGear copies into the Backpack on spawn; make sure owned weapons are there regardless
		task.defer(function()
			for _, item in ipairs(catalog) do
				if owns(player, item.Id) then
					grantTool(player, item.Id)
				end
			end
		end)
	end)
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end

---------------------------------------------------------------- requests
local busy = {}

local function handle(player, action, id)
	if action == "State" then
		return true, "", stateOf(player)
	end
	if type(id) ~= "string" then
		return false, "Bad request", stateOf(player)
	end
	local item = byId[id]
	if not item then
		return false, "Unknown weapon", stateOf(player)
	end

	if action == "Buy" then
		if typeof(item.Price) ~= "number" then
			return false, "Not for sale yet", stateOf(player)
		end
		if owns(player, id) then
			return false, "You already own this", stateOf(player)
		end
		if not weaponTools:FindFirstChild(id) then
			return false, "Not available yet", stateOf(player)
		end
		if not spendCash(player, item.Price) then
			return false, "Not enough Cash", stateOf(player)
		end
		player:SetAttribute("Owns_" .. id, true)
		grantTool(player, id)
		return true, "Bought " .. item.Name, stateOf(player)
	elseif action == "Equip" then
		if not owns(player, id) then
			return false, "You don't own this", stateOf(player)
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return false, "Can't equip right now", stateOf(player)
		end
		if player:GetAttribute("EquippedWeapon") == id then
			humanoid:UnequipTools()
			player:SetAttribute("EquippedWeapon", nil)
			return true, "Unequipped", stateOf(player)
		end
		grantTool(player, id)
		local tool = findTool(player, id)
		if not tool then
			return false, "Weapon missing", stateOf(player)
		end
		humanoid:EquipTool(tool)
		player:SetAttribute("EquippedWeapon", id)
		return true, "Equipped " .. item.Name, stateOf(player)
	end
	return false, "Unknown action", stateOf(player)
end

remote.OnServerInvoke = function(player, action, id)
	if type(action) ~= "string" then
		return false, "Bad request", stateOf(player)
	end
	if action ~= "State" then
		if busy[player] then -- tiny rate limit against spam clicking
			return false, "Slow down", stateOf(player)
		end
		busy[player] = true
		task.delay(0.25, function()
			busy[player] = nil
		end)
	end
	local ok, success, message, state = pcall(handle, player, action, id)
	if not ok then
		warn("[WeaponShopService]", success)
		return false, "Something went wrong", stateOf(player)
	end
	return success, message, state
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
