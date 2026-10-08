-- InventoryAdapter (ModuleScript in ServerScriptService)
--
-- TEMPORARY INVENTORY. The game has no real inventory yet, so delivered animals are kept here for the session only
-- (NOT saved). Each animal becomes a Folder inside player.AnimalInventory (it replicates, so clients can list it):
--   name = its Id; attributes Id, Species ("Frog"), Size ("Small" | "Medium" | "Large"),
--   Mutation ("None" | "Gold" | "Silver"), Rarity, World, Value (number, for selling later), CaughtAt,
--   State ("Bag" = in the inventory, "Held" = in the player's hand, "Plot" = placed on their plot)
-- Player attribute AnimalCount holds the total. Replace these functions with the real inventory when it exists.
local InventoryAdapter = {}

local nextId = 0

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
	nextId += 1
	local item = Instance.new("Folder")
	item.Name = tostring(nextId)
	item:SetAttribute("Id", nextId)
	item:SetAttribute("Species", entry.Species)
	item:SetAttribute("Size", entry.Size)
	item:SetAttribute("Mutation", entry.Mutation)
	item:SetAttribute("Rarity", entry.Rarity)
	item:SetAttribute("World", entry.World)
	item:SetAttribute("Value", entry.Value)
	item:SetAttribute("CaughtAt", os.time())
	item:SetAttribute("State", "Bag")
	item.Parent = folder
	player:SetAttribute("AnimalCount", #folder:GetChildren())
	return item
end

-- the entry Folder with this Id (or nil)
function InventoryAdapter.Get(player, id)
	return folderOf(player):FindFirstChild(tostring(id))
end

function InventoryAdapter.SetState(player, id, state)
	local item = InventoryAdapter.Get(player, id)
	if item then
		item:SetAttribute("State", state)
	end
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
