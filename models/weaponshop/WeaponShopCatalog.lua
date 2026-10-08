-- WeaponShopCatalog (ModuleScript in ReplicatedStorage)
-- The items the Weapon Shop view lets players browse, in order. Read by BOTH the client (UI) and the server
-- (WeaponShopService validates every purchase against this table, never against what the client sends).
--
--   Id      matches ServerStorage.WeaponTools.<Id> (the Tool players get) and
--           ReplicatedStorage.WeaponShopPreviews.<Id> (the spinning preview Model)
--   Price   number = for sale for that much Cash; nil = not for sale yet (shows "???")
--   Stats   1-10 per stat; nil = stats not decided yet (shows "???")
--
-- The two "Weapon" entries are still placeholders.
return {
	{
		Id = "Python",
		Name = "Python",
		Price = 50,
		Blurb = "Looks great. Shoots terribly.",
		Stats = { Damage = 1, Range = 1, ["Fire Rate"] = 1, Accuracy = 1 },
	},
	{ Id = "Weapon2", Name = "Weapon 2", Price = nil },
	{ Id = "Weapon3", Name = "Weapon 3", Price = nil },
}
