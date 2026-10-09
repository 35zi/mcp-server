-- WeaponStats (ModuleScript in ReplicatedStorage)
-- Turns the 1-10 shop stats from WeaponShopCatalog into real gameplay numbers. Used by BOTH the server
-- (WeaponCombatService: what a shot actually does) and the client (WeaponClient: cooldown, sway, aim dot range),
-- so the shop bars, the feel and the server rules always agree. Tune the formulas here.
--
-- Shots have NO random spread: a bullet always lands exactly where the aim dot / sights point.
--
--   Damage      HP taken per hit                         5 per point        (1 -> 5 HP, 10 -> 50 HP)
--   Range       studs a bullet travels                   100 + 13 * points^2 (2 -> 152, 6 -> 568, 10 -> 1400)
--   Fire Rate   seconds between shots                    1.5 / (1 + 0.5 * (FireRate - 1))   (1 -> 1.5 s, 10 -> 0.27 s)
--   Accuracy    sight sway while aiming down sights, deg (11 - Accuracy) * 0.12   (2 -> 1.08 deg, 10 -> 0.12 deg)
local WeaponStats = {}

function WeaponStats.derive(stats)
	stats = stats or {}
	local damage = math.clamp(tonumber(stats.Damage) or 1, 1, 10)
	local range = math.clamp(tonumber(stats.Range) or 1, 1, 10)
	local fireRate = math.clamp(tonumber(stats["Fire Rate"]) or 1, 1, 10)
	local accuracy = math.clamp(tonumber(stats.Accuracy) or 1, 1, 10)
	return {
		Damage = 5 * damage,
		Range = 100 + 13 * range * range,
		Cooldown = 1.5 / (1 + 0.5 * (fireRate - 1)),
		AdsSway = (11 - accuracy) * 0.12,
	}
end

function WeaponStats.forId(catalog, id)
	for _, item in ipairs(catalog) do
		if item.Id == id and type(item.Stats) == "table" then
			return WeaponStats.derive(item.Stats), item
		end
	end
	return nil
end

return WeaponStats
