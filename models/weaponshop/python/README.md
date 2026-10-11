# Python revolver (owner's model, 2026-10-11)

`python_revolver.obj` is the owner's model (135 named pieces, 7 materials). The `.mtl` was missing from the
download; `python_revolver.mtl` here was recreated by Claude from the material names.

Studio can't upload meshes from scripts (`AssetService:CreateAssetAsync` is "not available yet") and
EditableMesh MeshParts are not saved with the place, so the model was **rebuilt in Studio from Parts**:

- 68 pieces are axis-aligned boxes -> one `Part` each.
- 67 pieces are extruded outlines (round screws, chambers, barrel, frame, grip, hammer...) -> each cap
  triangle becomes two `WedgePart`s, unioned with `GeometryService:UnionAsync` into one `UnionOperation`
  per piece (unions are stored in the place file). Bevels of 0.0014 OBJ units (~0.02 studs) are dropped.
- Names: `Python_<obj name>`. Colours come from the material names (see `COLORS` in the build step).
- The 27 cylinder pieces are unioned into `Python_Cylinder` and the 6 hammer pieces into `Python_Hammer`
  (UsePartColor = false keeps their colours; a tiny axis-aligned helper part makes the union axis-aligned so
  WeaponClient's hammer pivot and cylinder rotation work). `WeaponConfig.Python` names them.
- Scale: OBJ length 0.2623 -> 3.1 studs (same as the old Python). OBJ +X (muzzle) -> Roblox -Z, OBJ Y -> Y.

`PythonBuildData.lua` is the OBJ reduced to that form (boxes: `lo`/`hi`; prisms: extrusion axis `ax`,
`lo`/`hi` along it and the cap triangles `t` in the other two axes). It was produced by a PowerShell
parser (pick the axis with the fewest distinct values, keep the triangles lying on its top level).

Where it lives in the place:

| Instance | What |
|---|---|
| `ServerStorage.WeaponModels.Python_Revolver` | source model (104 parts), pivot = the grip |
| `ServerStorage.WeaponTools.Python` | the Tool: Handle at the grip (`OBJ -0.088, 0.075, 0`), every part welded to it; attributes MuzzlePos `(0, 0.706, -2.590)`, SightTarget `(0, 1.042, -2.545)` (front sight fibre top), EyePos `(0, 1.067, -0.185)` (just behind the rear sight), SupportPos `(0, -0.3, 0)` |
| `ReplicatedStorage.WeaponShopPreviews.Python` | anchored copy for the shop / hotbar, muzzle towards +Z like the old preview |
| `ServerStorage.PythonBackup_20261011` | the old single-mesh Python (tool, source, preview) |
