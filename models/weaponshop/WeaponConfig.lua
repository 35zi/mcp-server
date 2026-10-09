-- WeaponConfig (ModuleScript in ReplicatedStorage)
-- How each weapon LOOKS and FEELS on the client (WeaponClient). Gameplay numbers (damage, range, fire rate, sway)
-- come from the shop stats via WeaponStats; this file is only presentation.
--
--   Fov         field of view when aiming down sights (lower = more zoom)
--   Scope       true = aiming shows a scope overlay instead of iron sights
--   Kick        recoil strength (1 = revolver)
--   Pitch       gunshot sound pitch, Volume = gunshot volume
--   Automatic   true = hold the trigger to keep firing
--   Cycle       what moves after a shot:
--                 "hammer"  hammer drops on the shot and re-cocks (with a click) just before the next shot is ready;
--                           Hammer / Cylinder name the parts (the cylinder turns one chamber per shot)
--                 "pump"    the Slide parts (name pattern) pump back and forward
--                 "bolt"    the Slide parts work the bolt back and forward
--                 "charge"  the Slide parts snap back briefly on every shot
--   SlideAmount studs the Slide parts move
--   Sight picture tweaks (studs, on top of the tool's EyePos / SightTarget attributes, which run from the rear
--   sight's top to the front sight's tip - set in ServerStorage.WeaponTools):
--     SightLift   raises the aim point (and the eye with it), e.g. from the middle of a front sight to its tip
--     EyeLift     raises only the eye, so the gun body sits lower under the sights
--     EyeBack     moves the eye back along the line of sight, so the rear sight looks smaller
return {
	Python = { Fov = 50, Kick = 1.0, Pitch = 1.05, Volume = 0.9, Cycle = "hammer", EyeBack = 1.6 },
	Revolver = {
		Fov = 50, Kick = 1.0, Pitch = 1.0, Volume = 0.9, Cycle = "hammer", EyeBack = 1.0,
		Hammer = "^Revolver_Hammer$", Cylinder = "^Revolver_Cylinder$",
	},
	Shotgun = {
		Fov = 55, Kick = 1.7, Pitch = 0.78, Volume = 1.0, Cycle = "pump", Slide = "^Shotgun_Pump", SlideAmount = 0.45,
		EyeBack = 0.8,
	},
	AutomaticRifle = {
		Fov = 50, Kick = 0.4, Pitch = 1.2, Volume = 0.7, Automatic = true, Cycle = "charge",
		Slide = "^AutomaticRifle_Charging_Handle$", SlideAmount = 0.18,
		EyeBack = 2.2, StableADS = true,
	},
	BoltSniper = {
		Fov = 16, Kick = 1.4, Pitch = 0.72, Volume = 1.0, Scope = true, Cycle = "bolt",
		Slide = "^BoltSniper_Bolt_Handle", SlideAmount = 0.35,
	},
}
