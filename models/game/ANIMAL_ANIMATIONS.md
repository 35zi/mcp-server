# Shared animal rigs and procedural animations

Installed in the open Shoot an Animal place. Covers all 11 ServerStorage.AnimalTemplates models: Bunny, Frog, Mouse, Hedgehog, Fox, Camel, Duckling, Turkey, Vulture, Spider, Scorpion.

## Installed instances

- ReplicatedStorage.AnimalRig: skeleton builder, animation profiles and shared pose evaluator.
- StarterPlayer.StarterPlayerScripts.AnimalAnimationClient: one client PreSimulation loop.
- ServerScriptService.RigAnimalTemplates: idempotent setup for existing and newly added templates.
- Each template: AnimalJoints folder containing Motor6D movement joints and Weld decorative joints. PrimaryPart remains its original body. Only that body is anchored.
- Focused integration in AnimalManager, AnimalCarry, InventoryService and PlotAnimalsClient moves the body and attaches carried/held animals with one external weld.
- ServerStorage.AnimalAnimationBackup_20261008 contains untouched source models and original integration scripts. Do not move the backups into AnimalTemplates.

## Motion reuse

| Family | Species | Motion |
| --- | --- | --- |
| Hopper | Bunny, Frog | Existing hop trajectory; tucked front feet, hind-leg extension; Bunny ears fold back |
| Quadruped | Mouse, Hedgehog, Fox, Camel | Alternating legs; Camel uses a slower same-side pace |
| Bird | Duckling, Turkey, Vulture | Two-leg waddle, head/neck bob, occasional wing stretch; Turkey fan movement |
| Crawler | Spider, Scorpion | Alternating eight-leg scuttle; Scorpion claws and articulated tail |

Shared idle code supplies sniffing/look-around, ear flicks, tail movement and gentle breathing. BunnyBrain's original timing and ear/head motion inspired the hopper pose. Stunned and shoulder-carried animals use a neutral limp pose; held pets retain idle motion.

Animatable groups use Motor6D.Transform. Welds retain explicit neutral C0 offsets so decorative parts stay aligned when models move between storage and Workspace. No uploaded animation IDs or per-animal runtime scripts are required.

## Efficiency

Wild movement batches one body per animal. Body offsets are cached; batch arrays are reused. Pose changes stay on clients. Update rate decreases from each frame within 90 studs to 30 Hz / 12 Hz, then 2 Hz beyond 320 studs. Atomic model streaming and registration retry keep rigs complete when streamed in.

Tuning lives in AnimalRig.Profiles and AnimalRig.Pose. The existing hunting path planner, animal stats, currency, inventory, UI, spawn weights and income remain in their original systems. Non-hoppers now use ground gait instead of hopping.

## Validation

- All 379 original pieces matched backup positions, sizes, colors, materials, MeshIds and TextureIDs.
- 368 joints across 11 templates, with one anchor per animal.
- QAAnimalRigs.server.lua passed in Play: 33 scaled rigs, 1,137 connected pieces, 1,104 joints. Checks storage-to-world placement, connectivity, anchor count, idempotence, gait transforms, stunned reset and root motion.
- Client gallery: every species animated with coherent geometry, including models streamed in at distance.
- Real inventory remotes: holding and plot placement for Large Bunny, Frog, Camel, Vulture and Spider; assemblies and animation verified.
- Real proximity prompt: stunned Large Spider picked up, one shoulder weld / zero anchors; dropped with one anchor; revived at full health and resumed movement; picked up again and delivered across the red line, incrementing inventory.
- Final fresh Play output contained only the QA pass line. Studio returned to Edit mode; runtime fixtures were removed by stopping Play.

## Reapplying

Install AnimalRig in ReplicatedStorage, AnimalAnimationClient in StarterPlayerScripts, and RigAnimalTemplates in ServerScriptService. Update the four integration sources with this branch's versions. Run this in Edit mode to persist the template skeletons:

```lua
local rig = require(game.ReplicatedStorage.AnimalRig)
for _,model in game.ServerStorage.AnimalTemplates:GetChildren() do
    if model:IsA("Model") then rig.Build(model, model.Name) end
end
```

The QA script is an optional temporary server Script for Play testing. Do not install it as an always-running production script. Save the Studio place separately; source commits do not save or publish a place.

