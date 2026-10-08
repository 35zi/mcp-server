-- WeaponShopCatalog (ModuleScript in ReplicatedStorage)
-- The items the Weapon Shop view lets players browse, in order.
--
-- PLACEHOLDERS: the real weapons, prices and stats are not decided yet.
-- To add a real weapon later:
--   * put its preview Model in ReplicatedStorage.WeaponShopPreviews, named exactly like its Id
--     (the shop view scales it to fit and spins it; without one it shows a "?" placeholder)
--   * set Name and Price (a number). Price = nil shows "???".
return {
	{ Id = "Weapon1", Name = "Weapon 1", Price = nil },
	{ Id = "Weapon2", Name = "Weapon 2", Price = nil },
	{ Id = "Weapon3", Name = "Weapon 3", Price = nil },
}
