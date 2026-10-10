---
name: shoot-an-animal-animals
description: How animals are built, rigged, sized, colored and registered in the Roblox game "Shoot an Animal" (placeId 80759588926584). Use before making a new animal, remaking or improving an existing one, adding a world/biome of animals, or debugging an animal that looks, animates, sizes or spawns wrong.
---

# Making animals for "Shoot an Animal"

Analyzed from the live place on 2026-10-10: 40 templates (38 in worlds, Mouse + Duckling unused).
The live Studio place is the source of truth. Codex edits it too, so re-read the modules named
below before relying on line-level details, and follow the `roblox-codex-handoff` routine for edits.

**GitHub, every time:** before starting, fetch `35zi/mcp-server` and read the newest HANDOFF and
recent commits (Codex commits as "ESL") to see what ChatGPT/Codex did. After finishing, commit
the work on a `claude/<feature>` branch with a HANDOFF entry and push it (never to `main`). Keep
`docs/claude/ANIMALS.md` in the repo identical to this file.

## 1. Art style (non-negotiable)

Grow a Garden pet style: everything is boxes (cuboids, a few extruded polygon panels), flat
bright colors, studded surfaces, cute-but-readable faces.

- Face: square black eyes (`232735`) with a small white square highlight `EyeShine` (`fffaf1`) in
  the upper corner; block muzzle/snout lighter than the head; tiny dark nose/nostrils; a thin dark
  `Mouth` bar. Angry animals get angled `Brow` blocks.
- Palette per species = 4 tones: `base`, `light` (belly/chest/muzzle/face patch), `accent`
  (inner ears, wings, beaks, cheek patches), `dark` (hands/feet/toes, stripes, brows, scutes).
  Horns/claws/teeth/fangs `f7e9cc`, tongue `df7297`. Crystals/flames/embers = Neon.
- Studs: MeshPart animals use `MaterialVariant = "Studs"` (MaterialService.Studs, Plastic base).
  Part-built Snow animals use `TopSurface = Studs` instead. Never smooth, rounded or low-poly
  faceted.
- Detail bar = the Yeti (169 parts): 2-3 shades of the main color in fur fringes, layered face
  (eye sockets, brow ridge, cheek fur), open mouth with teeth/fangs/tongue and separate jaw,
  separate fingers/toes with dark claws, themed accents (ice crystals, horns). Most current
  animals have 30-86 parts. "More detailed" = more blocks in the same style.
- Front faces -Z in Roblox (-Y in Blender). Body is the root part.

## 2. Two ways the templates are built

| Kind | Animals | Parts | Names |
|---|---|---|---|
| Blender -> FBX -> 3D Importer (MeshParts, one mesh per block) | Frog, Hedgehog, Duckling, Mouse, Spider, Scorpion, Camel, Vulture, and all 24 of worlds 4-7 | `MeshPart`, Plastic + Studs variant | Prefixed: `Tiger_Body`, `Tiger_Leg_1_-1`, `Tiger_EyeShine_-1` |
| Roblox Parts built in Studio | Bunny, Fox, Turkey, Penguin, SnowFox, Wolf, PolarBear, Yeti | `Part` | Bare: `Body`, `Head`, `EarL`, `Leg`... |

Blender builder pattern (Codex repo `35zi/mcp-server`, branch `codex/block-model-assets`,
`models/codex_assets/blender/create_*.py`): every piece is its own object, 1 unit ~ 1 stud,
named `<Species>_<Piece>[_<side>][_<index>]` with side -1/1, parented to an empty `<Species>_Root`,
geometry only (colors are applied in Studio by part name). Helpers:

```python
def box(name, location, size, rotation=None): ...   # cuboid centred at location
def rod(name, start, end, width, depth=None): ...   # box stretched between two points (limbs, tails)
def panel(name, points, depth, location): ...       # extruded XZ polygon facing -Y (ears, wings, beaks)
def side_panel(name, points, width, location): ...  # extruded YZ polygon (wings/feathers seen from the side)
```

Export one FBX per animal, import with Studio's 3D Importer keeping separate parts, put the
Model in `ServerStorage.AnimalTemplates`, rename it to the species key.

## 3. Part names ARE the rig

`ServerScriptService.RigAnimalTemplates` rigs every model added to `AnimalTemplates`
(Motor6Ds + welds in an `AnimalJoints` folder, attributes `AnimalRigVersion`, `AnimationFamily`).
Which rigger runs depends on the species:

- Species listed in `ReplicatedStorage.NewBiomeData` (worlds 4-7) -> `ReplicatedStorage.BiomePetRig`
- Everything else -> `ReplicatedStorage.AnimalRig`

The species prefix `<Species>_` is stripped before matching. Moving joints:

| Role | AnimalRig (worlds 1-3) names | BiomePetRig (worlds 4+) names |
|---|---|---|
| root | `Body` / `<Species>_Body` / `_Abdomen` | `Body`, `Thorax`, `Abdomen`, `CoilLow_00`, `Foot` |
| Neck, Head | `Neck`, `Head` | `Neck` or chain `Neck_00..`, `Head` (Hydra: `Neck_i_00..`, `Head_i`) |
| Leg | `Leg`, `Leg_[01]_-1`, `Leg_-1_[0-3]_Upper`, `Leg_-1` | `Leg_-1`, `Leg_[0-2]_-1`, `Leg_[0-2]_-1_00`, `Thigh_-1`, `HindLeg_-1` |
| LowerLeg | - | `Shin_-1` (under Thigh), `Leg_r_s_01` (under `_00`) |
| FrontLeg / HindLeg (hoppers) | `FrontPawL/R`, `Front_Leg_*` / `HaunchL/R`, `Hind_Thigh_*` | - |
| Arm / Forearm | `Arm` | `UpperArm_-1` / `Forearm_-1`, `LowerArm_-1` |
| Ear | `EarL`, `EarR`, `Ear`, `Ear_-1` | `Ear_-1` |
| Wing | `Wing`, `Wing_-1` | `Wing_-1`, `Wing_[01]_-1`, `WingShoulder_-1` |
| Tail | `Tail`, `Tail_Base`, `Tail_00/01` (Scorpion/Mouse: segment chain) | chain `Tail_00, Tail_01...` |
| Others | `Feather` (fan), `Claw_Arm_*` | `Antenna_-1_00..`, `GillStem_-1_[0-2]`, `EyeStalk_-1`, `Feeler_-1`, `Coil{Low,High}_0i` |

Everything else is welded by SUBSTRING to the nearest moving part: names containing Ear -> ear,
Tail/Antenna -> tail, Wing/Feather -> wing, Claw/Hand/Finger/Wrist -> arm, Leg/Foot/Toe/Talon/Palm
-> leg, and Eye/Brow/Muzzle/Nose/Mouth/Nostril/Cheek/Face/Hair/Head/Crown/Horn/Fang/Tooth/Whisker/
Bill/Beak/Snout/Jaw/Tongue/Mandible -> head; anything unmatched -> body.
**So never put those words in an unrelated part's name** (e.g. a back spike called `TailSpike`
would ride the tail; `HeadBand` on the body would ride the head). Sides come from the part's X
position (right = +1), so model symmetric pairs on the correct side.

Animation is procedural (`AnimalRig.Pose`, run by `AnimalAnimationClient`), by family:
Hopper, Quadruped, Bird, Crawler, Biped, Flyer (`flap`, `hoverHeight`), Serpent, Glider.
Families are set in `AnimalRig.Profiles` (worlds 1-3) or `NewBiomeData.Profiles` (worlds 4+).

## 4. Size and weight

`AnimalManager.BuildModel` scales the template so its longest dimension equals
`HuntingRules.BaseSize[species]` studs (at average kg), then by `(kg/average)^(1/3)` (max 2.5x,
min `MinimumVisualSize` 3.5). Template scale does not matter, proportions do. Keep trees/props a
bit taller than the big animals.

## 5. Checklist: adding a new animal

1. Build it in the style above (Blender boxes or Studio Parts), front -Z, named per section 3.
2. Put the Model in `ServerStorage.AnimalTemplates`, named exactly the species key (no spaces,
   CamelCase; `PrettyName` adds spaces). Check it got `AnimalJoints` + `AnimationFamily`.
3. Register it:
   - Worlds 1-3: `AnimalData.Worlds[i].species`, `AnimalData.Species` (world, rarity, hp, value,
     income, hop/walk), `AnimalData.Weights`, `AnimalRig.Profiles`.
   - Worlds 4+: one row in `NewBiomeData` rows (rarity comes from row order: 6 per world =
     Common..Secret), a `Profiles` entry, and a palette in `BiomePetAppearance`.
   - `HuntingRules.BaseSize`; optionally `Attackers` (chases/punches) or `EscapeSpeeds`.
   - `ProgressionBalance` may rescale stats; read it.
4. Menu/Index pictures need nothing: `InventoryService` builds `ReplicatedStorage.AnimalPreviews`
   from the templates at server start.
5. Playtest: spawn it in its zone, watch walk/idle, shoot it (headshot = any part chained to the
   Head joint), pick it up, place it on a plot, open Index. Screenshot before reporting.

## 6. Mutations and gotchas

- Gold/Silver tint every part with brightness between 0.12 and 0.97. Eye color `232735` is
  ~0.17, so eyes DO get tinted on Gold animals; use something darker than ~`1e1e1e` if eyes
  must stay black. `EyeShine` (`fffaf1`) is kept.
- Imported mesh models can have a rotated pivot; `GetBoundingBox` then lies. The game measures
  from part corners (`AnimalManager.RootOffsets`); do the same in tools.
- `require` from MCP `execute_luau` gets a fresh module copy (no shared state with game scripts).
- Mouse and Duckling templates exist but are in no world.
- Back up before big changes into `ServerStorage.<Name>Backup_<date>` (the project's habit).
