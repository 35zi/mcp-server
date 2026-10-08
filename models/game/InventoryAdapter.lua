-- InventoryAdapter (ModuleScript in ServerScriptService)
--
-- TEMPORARY INVENTORY. The game has no real inventory yet, so caught animals are kept here for the session only
-- (NOT saved). Each caught animal becomes a Folder inside player.AnimalInventory with attributes
--   Species ("Frog"), Size ("Small" | "Medium" | "Large"), Mutation ("None" | "Gold" | "Silver"), Value (number)
-- and player attribute AnimalCount holds the total, so clients can show it. Selling / placing animals on plots is
-- not built yet. Replace these functions with the real inventory when it exists.
local InventoryAdapter = {}

local function folderOf(player)
	local folder = player:FindFirstChild("AnimalInventory")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "AnimalInventory"
		folder.Parent = player
	end
	return folder
end

function InventoryAdapter.Add(player, entry)
	local folder = folderOf(player)
	local item = Instance.new("Folder")
	item.Name = entry.Species
	item:SetAttribute("Species", entry.Species)
	item:SetAttribute("Size", entry.Size)
	item:SetAttribute("Mutation", entry.Mutation)
	item:SetAttribute("Value", entry.Value)
	item:SetAttribute("CaughtAt", os.time())
	item.Parent = folder
	player:SetAttribute("AnimalCount", #folder:GetChildren())
	return item
end

function InventoryAdapter.List(player)
	local list = {}
	for _, item in ipairs(folderOf(player):GetChildren()) do
		table.insert(list, item:GetAttributes())
	end
	return list
end

return InventoryAdapter
