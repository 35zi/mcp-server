-- CashAdapter (ModuleScript in ServerScriptService)
--
-- TEMPORARY CURRENCY. The game has no real economy yet, so Cash is a placeholder leaderstats value that starts at
-- STARTING_CASH and is NOT saved between sessions. Every script that touches money (WeaponShopService,
-- AnimalManager) goes through these four functions only, so when the real economy exists, replace the bodies
-- here and nothing else has to change.
local CashAdapter = {}

local STARTING_CASH = 100

local function cashValue(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

-- make sure the player has a Cash value (safe to call more than once)
function CashAdapter.Setup(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	if not stats:FindFirstChild("Cash") then
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = STARTING_CASH
		cash.Parent = stats
	end
end

function CashAdapter.Get(player)
	local cash = cashValue(player)
	return cash and cash.Value or 0
end

-- returns true if the player could pay
function CashAdapter.Spend(player, amount)
	local cash = cashValue(player)
	if not cash or amount < 0 or cash.Value < amount then
		return false
	end
	cash.Value -= amount
	return true
end

function CashAdapter.Add(player, amount)
	if amount <= 0 then
		return
	end
	CashAdapter.Setup(player)
	local cash = cashValue(player)
	cash.Value += math.floor(amount + 0.5)
end

return CashAdapter
