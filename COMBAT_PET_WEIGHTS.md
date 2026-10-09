# Combat and pet weight fixes

Installed in the connected Shoot an Animal place (80759588926584). Save/publish the Studio place separately; this PR publishes source only.

## Installation

Replace the matching existing scripts from models/game and models/weaponshop. New modules/scripts:

- ReplicatedStorage.WeaponSightSetup (ModuleScript)
- ServerScriptService.PlayerKnockback (ModuleScript)
- StarterPlayer.StarterPlayerScripts.KnockbackClient (LocalScript)

WeaponShopService applies the compact sight to ServerStorage.WeaponTools at server startup. For an Edit-mode preview, require a fresh clone of WeaponSightSetup and call Apply on the AutomaticRifle Tool. The live template is already updated. Original scripts/tools are backed up under ServerStorage.CombatWeightBackup_20261009 with backup Scripts disabled.

This branch also records the existing live Snow/Yeti/Secret and carrier theft additions needed by these scripts, including their AnimalRig profiles and UIStyle rainbow helper. It preserves their behavior. Claude's 394ea9d snow decoration commit touches BuildDecor only and does not overlap these fixes.

## Behavior

Weapons share one range formula (100 + 13 × shop range squared): Python 217, Revolver 308, Shotgun 152, AR 568, sniper 1,400 studs. Animal damage remains; player hits only ragdoll/fling. Server raycasts validate player hits, including obstructions. Carriers drop their pet.

Hip-fire cursor uses a fixed screen position from the mouse; shoulder aim stays centered. Aim release, unequip, death, menus, missed mouse release and window focus loss clear weapon-owned mouse capture. First-person/shift-lock continues to use the Roblox camera's normal mouse lock. AR ADS has a compact open U front sight and visible red dot. Camera recoil moves the sight and shot axis together.

AnimalData.Weights defines kilograms per species (gameplay defaults). 92% of spawns use the species normal range, 4% are tiny (0.12–0.4 × reference weight), and 4% giant (3–8 ×). Linear scale is the cube root of mass ratio. HP/income/value multipliers have caps. WeightKg travels through stun, carry, drop, delivery, Backpack Tool and plot placement. Carry/hand size caps were removed. Older Size entries resolve to equivalent kilograms to preserve their geometry; Small/Medium/Large are never displayed.

## Verification — 2026-10-09

- Fresh Play started without script errors.
- Actual AR automatic fire: red dot projected within 0.0005 pixels of the viewport center over 133 frames.
- Walking with fixed mouse position: reticle position error 0 over 120 frames. Repeated shoulder aim/release returned CameraType.Custom and MouseBehavior.Default; mouse moved freely.
- Real-player ragdoll: health 100 before/after, RequiresNeck restored, recovered.
- Production shot-handler fixture (dummy shooter, real victim): sniper at 600 studs ragdolled an unladen player with health unchanged; a wall at 300 studs blocked the claimed hit. This is a server handler test, not a two-client network test.
- Seed 42, 10,000 Bunny weights: 9,210 normal, 388 tiny, 402 giant. Test endpoints 0.288 / 2.4 / 19.2 kg produced scale 0.493 / 1 / 2.
- All 19 Bunny parts retained size for tiny/normal/giant Backpack Tools and plot models.
- Giant pickup/carry/delivery/held Tool retained 19.2 kg and full geometry. Real live shot → stun → prompt pickup → home delivery retained all 19 part sizes and 3.028 kg.
- Play-only fixtures are discarded by stopping Play.

Run tests/CombatWeightRegression.lua in the Server Command Bar or Studio MCP during Play to repeat numerical/model/shot checks. It reads Script.Source for the handler harness and is deliberately a privileged Studio-only test, not a production Script. Repeat mouse and Backpack/prompt checks through normal client input. A two-player network playtest remains useful for latency and fling feel.

