-- AnimalSpawner (Script in ServerScriptService): starts the animal waves (AnimalManager) and the pick-up / carry-home
-- system for dead animals (AnimalCarry).
require(script.Parent:WaitForChild("AnimalCarry")).Start()
require(script.Parent:WaitForChild("AnimalManager")).Start()
