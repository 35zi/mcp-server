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

-- Kilograms at the template's original scale. Most rolls use the normal range;
-- 4% are tiny (0.12..0.4 times average), 4% are giants (3..8 times average).
AnimalData.Weights = {
 Bunny={average=2.4,min=1.2,max=4.5}, Frog={average=0.2,min=0.08,max=0.45},
 Hedgehog={average=0.9,min=0.4,max=1.5}, Fox={average=6,min=3,max=10},
 Spider={average=0.03,min=0.01,max=0.08}, Turkey={average=7,min=3,max=12},
 Scorpion={average=0.06,min=0.02,max=0.15}, Camel={average=500,min=300,max=700},
 Vulture={average=7,min=3,max=12}, Penguin={average=25,min=10,max=40},
 SnowFox={average=5,min=2.5,max=9}, Wolf={average=45,min=25,max=70},
 PolarBear={average=450,min=200,max=700}, Yeti={average=650,min=400,max=900},
}
local legacyScale={Small=0.75,Medium=1,Large=1.35}
function AnimalData.Weight(species, weight)
 local cfg=AnimalData.Weights[species] or {average=1}
 if type(weight)=="number" and weight==weight and weight>0 and weight<1e7 then return weight end
 -- Compatibility for previously caught pets: preserve their exact visible size.
 return cfg.average*(legacyScale[weight] or 1)^3
end
function AnimalData.RollWeight(species, rng)
 local cfg=AnimalData.Weights[species] or {average=1,min=0.5,max=2}
 local roll=rng:NextNumber()
 local kg
 if roll<0.04 then kg=cfg.average*rng:NextNumber(0.12,0.4)
 elseif roll>0.96 then kg=cfg.average*rng:NextNumber(3,8)
 else kg=cfg.min+(cfg.max-cfg.min)*(rng:NextNumber()+rng:NextNumber())/2 end
 return math.max(0.001,math.floor(kg*1000+0.5)/1000)
end
function AnimalData.WeightTraits(species, weight)
 local kg=AnimalData.Weight(species,weight)
 local ratio=kg/(AnimalData.Weights[species] or {average=1}).average
 return {weight=kg,scale=ratio^(1/3),hp=math.clamp(ratio^0.35,0.4,2.5),value=math.clamp(ratio^0.5,0.35,3)}
end
function AnimalData.WeightText(weight)
 local kg=tonumber(weight) or 0
 if kg<1 then return string.format("%.3f kg",kg) end
 return string.format("%.2f kg",kg)
end
AnimalData.MutationIncome = { Gold = 3, Silver = 1.5 }

AnimalData.Worlds = {
	{ id = 1, name = "Forest", species = { "Bunny", "Frog", "Hedgehog", "Fox" } },
	{ id = 2, name = "Desert", species = { "Spider", "Turkey", "Scorpion", "Camel", "Vulture" } },
	{ id = 3, name = "Snow", species = { "Penguin", "SnowFox", "Wolf", "PolarBear", "Yeti" } },
}

AnimalData.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" }
AnimalData.Rarities = {
	Common = { weight = 72, color = Color3.fromRGB(225, 225, 225) },
	Uncommon = { weight = 18, color = Color3.fromRGB(110, 220, 110) },
	Rare = { weight = 8, color = Color3.fromRGB(80, 170, 255) },
	Epic = { weight = 4, color = Color3.fromRGB(170, 90, 255) },
	Legendary = { weight = 2, color = Color3.fromRGB(255, 170, 40) },
	-- Secret: shown in rainbow (UIStyle), announced to the whole server when one spawns
	Secret = { weight = 3, color = Color3.fromRGB(255, 120, 220) },
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
	-- World 3: Snow
	Penguin = { world = 3, rarity = "Common", hp = 25, value = 80, income = 10, hopHeight = 0.3, hopDist = 1.6, hopTime = 0.3, walk = true },
	SnowFox = { world = 3, rarity = "Rare", hp = 45, value = 300, income = 35, hopHeight = 0.5, hopDist = 4.5, hopTime = 0.32, walk = true },
	Wolf = { world = 3, rarity = "Epic", hp = 60, value = 700, income = 80, hopHeight = 0.5, hopDist = 5.0, hopTime = 0.34, walk = true },
	PolarBear = { world = 3, rarity = "Legendary", hp = 90, value = 1400, income = 160, hopHeight = 0.4, hopDist = 3.5, hopTime = 0.5, walk = true },
	-- aggressive: chases players inside its zone (aggroRange studs) at chaseSpeed and punches them (knockback + ragdoll)
	Yeti = { world = 3, rarity = "Secret", hp = 300, value = 6000, income = 700, hopHeight = 0.3, hopDist = 3.2, hopTime = 0.55, walk = true,
		aggressive = true, aggroRange = 60, chaseSpeed = 13, punchCooldown = 1.6, punchPower = 75 },
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
function AnimalData.Income(species, weight, mutation)
	local s = AnimalData.Species[species]
	if not s then
		return 0
	end
	local amount = (s.income or 1) * AnimalData.WeightTraits(species, weight).value * (AnimalData.MutationIncome[mutation] or 1)
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

-- "PolarBear" -> "Polar Bear", "SnowFox" -> "Snow Fox" (species keys have no spaces; they're used in attribute names)
function AnimalData.PrettyName(species)
	return (tostring(species):gsub("(%l)(%u)", "%1 %2"))
end

-- "Gold Bunny · 2.40 kg"
function AnimalData.DisplayName(species, weight, mutation)
	local parts = {}
	if mutation and mutation ~= "None" and mutation ~= "" then
		table.insert(parts, mutation)
	end
	table.insert(parts, AnimalData.PrettyName(species))
	return table.concat(parts, " ") .. (weight ~= nil and (" · " .. AnimalData.WeightText(AnimalData.Weight(species, weight))) or "")
end

return AnimalData
