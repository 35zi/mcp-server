-- WeaponShopCatalog (ModuleScript in ReplicatedStorage)
-- The weapons the Weapon Shop sells, in order. Read by BOTH the client (UI) and the server (WeaponShopService and
-- WeaponCombatService validate everything against this table, never against what the client sends).
--
--   Id      matches ServerStorage.WeaponTools.<Id> (the Tool players get), ReplicatedStorage.WeaponShopPreviews.<Id>
--           (the spinning shop preview) and ReplicatedStorage.WeaponConfig.<Id> (how it looks and feels)
--   Price   Cash; nil = not for sale yet (shows "???")
--   Stats   1-10 per stat (see WeaponStats for what each point means)
return {
	{
		Id = "Python",
		Name = "Python",
		Price = 50,
		Blurb = "Looks great. Shoots terribly.",
		Stats = { Damage = 1, Range = 3, ["Fire Rate"] = 1, Accuracy = 2 },
	},
	{
		Id = "Revolver",
		Name = "Revolver",
		Price = 250,
		Blurb = "A dependable six-shooter.",
		Stats = { Damage = 3, Range = 4, ["Fire Rate"] = 3, Accuracy = 5 },
	},
	{
		Id = "Shotgun",
		Name = "Shotgun",
		Price = 600,
		Blurb = "Huge hit, short reach.",
		Stats = { Damage = 6, Range = 2, ["Fire Rate"] = 2, Accuracy = 4 },
	},
	{
		Id = "AutomaticRifle",
		Name = "Automatic Rifle",
		Price = 1500,
		Blurb = "Hold the trigger and keep going.",
		Stats = { Damage = 2, Range = 6, ["Fire Rate"] = 9, Accuracy = 6 },
	},
	{
		Id = "BoltSniper",
		Name = "Sniper",
		Price = 3000,
		Blurb = "One shot. Very far away.",
		Stats = { Damage = 10, Range = 10, ["Fire Rate"] = 1, Accuracy = 10 },
	},
}
