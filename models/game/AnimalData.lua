-- AnimalData (ModuleScript in ReplicatedStorage)
--
-- Which animals live in which world, how rare they are and their stats. Shared by the server (AnimalManager,
-- AnimalCarry, InventoryService) and the client (Index + Inventory menus), so change animals here.
--
--   Worlds    in order; zone = the World attribute on the Parts in Workspace.AnimalSpawnZones
--   Rarities  weight = how often a spawn picks that tier inside its world (the weights are relative)
--   Species   world, rarity, hp / value for a Medium animal,
--             income = Cash per second it earns while placed on your plot (Medium, no mutation), how it moves:
--               hopHeight / hopDist / hopTime  (studs, studs, seconds per hop)
--               walk = true  scuttles/walks instead of hopping (no dust puff on every step)
local AnimalData = {}

-- seconds a shot-down animal stays stunned before it wakes up again (restarts each time it's dropped)
AnimalData.StunTime = 10

-- size of each size class (must match AnimalManager's SIZES) and what size / mutation do to plot income
AnimalData.SizeScale = { Small = 0.75, Medium = 1, Large = 1.35 }
AnimalData.SizeIncome = { Small = 0.8, Medium = 1, Large = 1.5 }
AnimalData.MutationIncome = { Gold = 3, Silver = 1.5 }

AnimalData.Worlds = {
	{ id = 1, name = "Forest", species = { "Bunny", "Frog", "Hedgehog", "Fox" } },
	{ id = 2, name = "Desert", species = { "Spider", "Turkey", "Scorpion", "Camel", "Vulture" } },
}

AnimalData.RarityOrder = { "Common", "Uncommon", "Rare", "Legendary" }
AnimalData.Rarities = {
	Common = { weight = 72, color = Color3.fromRGB(225, 225, 225) },
	Uncommon = { weight = 18, color = Color3.fromRGB(110, 220, 110) },
	Rare = { weight = 8, color = Color3.fromRGB(80, 170, 255) },
	Legendary = { weight = 2, color = Color3.fromRGB(255, 170, 40) },
}

AnimalData.Species = {
	-- World 1: Forest
	Bunny = { world = 1, rarity = "Common", hp = 10, value = 10, income = 1, hopHeight = 2.2, hopDist = 4.5, hopTime = 0.5 },
	Frog = { world = 1, rarity = "Uncommon", hp = 12, value = 25, income = 2, hopHeight = 2.6, hopDist = 5.5, hopTime = 0.55 },
	Hedgehog = { world = 1, rarity = "Rare", hp = 20, value = 60, income = 5, hopHeight = 0.6, hopDist = 2.0, hopTime = 0.35 },
	Fox = { world = 1, rarity = "Legendary", hp = 30, value = 250, income = 60, hopHeight = 1.2, hopDist = 6.5, hopTime = 0.34 },
	-- World 2: Desert
	Spider = { world = 2, rarity = "Common", hp = 12, value = 20, income = 3, hopHeight = 0.15, hopDist = 1.6, hopTime = 0.12, walk = true },
	Turkey = { world = 2, rarity = "Uncommon", hp = 18, value = 45, income = 6, hopHeight = 0.4, hopDist = 1.8, hopTime = 0.22, walk = true },
	Scorpion = { world = 2, rarity = "Rare", hp = 26, value = 110, income = 15, hopHeight = 0.12, hopDist = 1.5, hopTime = 0.16, walk = true },
	Camel = { world = 2, rarity = "Legendary", hp = 45, value = 500, income = 66, hopHeight = 0.45, hopDist = 3.6, hopTime = 0.5, walk = true },
	Vulture = { world = 2, rarity = "Legendary", hp = 35, value = 450, income = 70, hopHeight = 0.5, hopDist = 3.2, hopTime = 0.4, walk = true },
}

-- spawns ABOVE this rarity are announced to everyone with a big message when the wave brings them
-- (add rarer tiers after "Legendary" in RarityOrder + Rarities and they are announced automatically)
AnimalData.AnnounceAbove = "Legendary"

function AnimalData.RarityRank(rarity)
	for i, r in ipairs(AnimalData.RarityOrder) do
		if r == rarity then
			return i
		end
	end
	return 0
end

function AnimalData.ShouldAnnounce(rarity)
	return AnimalData.RarityRank(rarity) > AnimalData.RarityRank(AnimalData.AnnounceAbove)
end

function AnimalData.WorldOf(species)
	local s = AnimalData.Species[species]
	return s and s.world
end

-- Cash per second this animal earns on a plot (whole dollars, at least 1)
function AnimalData.Income(species, size, mutation)
	local s = AnimalData.Species[species]
	if not s then
		return 0
	end
	local amount = (s.income or 1) * (AnimalData.SizeIncome[size] or 1) * (AnimalData.MutationIncome[mutation] or 1)
	return math.max(1, math.floor(amount + 0.5))
end

-- 62189 -> "62,189"
function AnimalData.Commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local sign, digits = s:match("^(-?)(%d+)$")
	if not digits then
		return s
	end
	return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- "Large Gold Bunny", "Small Fox"
function AnimalData.DisplayName(species, size, mutation)
	local parts = {}
	if size and size ~= "" then
		table.insert(parts, size)
	end
	if mutation and mutation ~= "None" and mutation ~= "" then
		table.insert(parts, mutation)
	end
	table.insert(parts, species)
	return table.concat(parts, " ")
end

return AnimalData
