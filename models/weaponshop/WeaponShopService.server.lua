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
-- ONE GUN AT A TIME: you only ever carry one gun (player attribute ActiveWeapon). Buying a gun swaps it in and takes
-- the old one out of your Backpack / hand / StarterGear; guns you bought stay owned, so EQUIP in the shop swaps back
-- to one of them for free. Other Tools (pets) are never touched: only Tools with a WeaponId attribute are guns.
--
-- Ownership is kept as player attributes Owns_<Id> (session only: NO DataStore yet) and the weapon in your hand as
-- the attribute EquippedWeapon. Tools come from ServerStorage.WeaponTools.<Id>; a copy of the active gun also goes
-- into StarterGear so it comes back after respawning.
--
-- TEMPORARY CURRENCY: there is no economy in the game yet, so Cash is a placeholder leaderstats value that lives
-- behind ServerScriptService.CashAdapter (shared with AnimalManager). Replace that module with the real economy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local catalog = require(ReplicatedStorage:WaitForChild("WeaponShopCatalog"))
local weaponTools = ServerStorage:WaitForChild("WeaponTools")
local sightSetup=require(ReplicatedStorage:WaitForChild("WeaponSightSetup"))
for _,tool in weaponTools:GetChildren() do sightSetup.Apply(tool) end

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

-- every gun except keepId leaves your hand, Backpack and StarterGear (pets and other Tools stay)
local function removeOtherGuns(player, keepId)
	local removed = nil
	for _, holder in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack"), player:FindFirstChild("StarterGear") }) do
		if holder then
			for _, child in ipairs(holder:GetChildren()) do
				local id = child:IsA("Tool") and child:GetAttribute("WeaponId")
				if id and id ~= keepId then
					if holder ~= player:FindFirstChild("StarterGear") then
						removed = removed or id
					end
					child:Destroy()
				end
			end
		end
	end
	return removed
end

-- makes id the one gun you carry; returns the id of the gun it replaced (if any)
local function setActive(player, id)
	local replaced = removeOtherGuns(player, id)
	player:SetAttribute("ActiveWeapon", id)
	grantTool(player, id)
	return replaced
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
		-- StarterGear copies into the Backpack on spawn; make sure exactly your one gun is there
		task.defer(function()
			local active = player:GetAttribute("ActiveWeapon")
			if type(active) == "string" and owns(player, active) then
				setActive(player, active)
			else
				removeOtherGuns(player, nil)
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
		local wasHolding = player:GetAttribute("EquippedWeapon") ~= nil
		local replaced = setActive(player, id)
		-- if you had a gun in your hand, the new one goes straight into it
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local tool = findTool(player, id)
		if wasHolding and humanoid and humanoid.Health > 0 and tool then
			humanoid:EquipTool(tool)
			player:SetAttribute("EquippedWeapon", id)
		end
		local old = replaced and byId[replaced]
		return true, old and ("Bought " .. item.Name .. " (replaced your " .. old.Name .. ")") or ("Bought " .. item.Name), stateOf(player)
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
		-- swapping to another gun you own: the one you carried leaves your inventory
		setActive(player, id)
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
