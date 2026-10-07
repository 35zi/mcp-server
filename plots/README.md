# Plot assignment

Installed in the active Shoot an Animal Studio place on 2026-10-08.

## Studio instances
- `Workspace.Plot1` through `Plot5`: the existing Plot4 `Hitbox.PlayerUI` design on every plot.
- Each plot has an invisible, non-colliding `SpawnPoint` at its ground-level center, facing the central area.
- `ServerScriptService.PlotService`: ModuleScript from `PlotService.lua`.
- `ServerScriptService.PlotManager`: Script from `PlotManager.server.lua`.

## Behavior
Players receive the first free plot in numeric order. Their display name and avatar headshot update its sign, and both joining and death respawns use that plot. A departing owner's sign and ownership clear. Players beyond the five-plot capacity spawn at the existing central `Workspace.SpawnLocation` and receive a free plot when one becomes available.

Assignments last for the server session. No DataStore or economy behavior is added; the existing income label is unchanged. Server-owned attributes expose `PlotName`, `PlotId`, and `WaitingForPlot` on players, and `OwnerUserId`, `OwnerName`, and `OwnerDisplayName` on plots.

Avatar requests retry and check ownership before applying results, so a delayed thumbnail cannot overwrite another owner's sign.

## Reapplying to a copy of the place
The existing map, Plot1..Plot5 models, Hitboxes, Plot4 PlayerUI, and central SpawnLocation must exist. Run `SetupPlots.lua` in Studio Edit mode, then install the two runtime sources at the instance paths above. Setup is idempotent and preserves the UI's existing layout. The changes are already installed in the current Studio session; save that place separately because this repository does not contain the full place file.

## Validation
- Studio Play: real player's join assignment, matching server/client owner text and thumbnail URL.
- Visually confirmed the player's headshot renders in the ImageButton.
- Killed the character and confirmed automatic respawn retained the assigned plot and landed within 0.001 studs horizontally of its spawn.
- Ran `QAPlotAllocation.lua` with isolated fixtures: five unique owners, repeated assignment, sixth-player overflow, free-plot reuse, waiting-player spawn update, and owner UI cleanup.
- Studio output: no errors. Returned to Edit mode after QA.

The allocator checks use simulated player records; a five-client Studio session was not run.
