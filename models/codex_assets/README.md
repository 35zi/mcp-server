# Block animal and weapon assets

Twelve editable Blender models in Emrik's cuboid, rectangular-eye style, with named pieces for Roblox Studio coloring and later animation. The geometry exports have no materials or colors. Studio palettes are archived separately so the existing textures and materials remain usable.

## Files

- `assets/block_animals/`: Mouse, Hedgehog, Duckling, Frog; individual FBX files, shared Blender source, preview.
- `assets/revolver/`: Revolver FBX, Blender source, preview.
- `assets/three_weapons/`: Pump-action Shotgun, scoped BoltSniper, AutomaticRifle; individual FBX files, shared Blender source, preview.
- `assets/desert_animals/`: Scorpion, Spider, single-hump Camel, Vulture; individual FBX files, shared Blender source, preview.
- `blender/`: Portable geometry builders, build entry point, and export validator.
- `studio/colors.json`: RGB values for all 403 original mesh pieces, captured from the Studio sources on 2026-10-08.
- `studio/RestoreModelColors.lua`: Command Bar script restoring those colors by exact mesh names, including prototypes, shop previews, and Tool copies.
- `studio/Color*.lua`: Original coloring operations for freshly imported models directly under Workspace, retained as the authoring record.
- `manifest.json`: Part counts, triangle counts, dimensions in Blender units, and FBX round-trip verification for all 12 models.

## Roblox Studio use

1. Import each animal or weapon FBX using Studio's 3D Importer. Keep its separate named mesh pieces if you want to color or animate them individually. Each export is centered on its own root, without the lineup offsets.
2. Keep your chosen textures/materials on the imported parts.
3. Paste `studio/RestoreModelColors.lua` into the Command Bar in Edit mode. It matches exact part names in Workspace, ReplicatedStorage, and ServerStorage and writes only `BasePart.Color`. Set `DRY_RUN = true` first to inspect how many pieces match. Studio Undo can revert an applied palette.
4. Save the place separately. Committing Blender/FBX files and colors does not save a Roblox place or publish it.

The first four animals are currently stored in `ServerStorage.AnimalTemplates`; weapon originals are in `ServerStorage.WeaponModels`, with copies in `ReplicatedStorage.WeaponShopPreviews` and `ServerStorage.WeaponTools`. The four desert animals remain under Workspace. These paths describe the observed place; gameplay integration was not changed by this asset update.

## Rebuild and validate

Requires Blender 5.2 with its bundled FBX import/export add-on. Use your local Blender executable in place of `blender` if it is not on PATH. From the repository root:

```sh
blender --background --python models/codex_assets/blender/build_models.py
blender --background --python models/codex_assets/blender/validate_assets.py
```

Use `-- --family desert_animals` to rebuild one family, or `-- --output /path/to/exports --skip-render` to generate geometry elsewhere without previews. The scripts resolve paths from their own locations; no Emrik-specific filesystem path is required. In background mode each family starts in an empty scene. Live Blender execution creates a separate scene and keeps unrelated scenes.

## Validation completed

- All 12 source models: closed, nondegenerate meshes; 403 separate pieces; zero material slots.
- All 12 packaged FBX files reopened with the expected part/triangle counts and no materials.
- All four families rebuilt in background Blender; their rebuilt FBX files passed the same validator.
- Studio coloring changed only colors; texture IDs, surface maps, materials, sizes, and placements were checked unchanged.
- The restore script's dry run matched the current original models and weapon copies without editing the place.
- Models and renders were visually checked during authoring. Gameplay behavior, buying, combat, and animations are outside this asset update.

## Previews

[First animals](assets/block_animals/animals_geometry_preview.png) · [Revolver](assets/revolver/revolver_geometry_preview.png) · [Three weapons](assets/three_weapons/three_weapons_geometry_preview.png) · [Desert animals](assets/desert_animals/desert_animals_geometry_preview.png)
