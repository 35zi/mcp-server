# StarterGui GameUI

The gameplay Studio place is 80759588926584. Menus use the owner's imported GameUI artwork.

## Install

- ReplicatedStorage: UIMotion, GameUILayout, PetBackpack.
- StarterPlayerScripts: AnimalMenuClient, WeaponClient, WeaponShopClient.
- ServerScriptService: InventoryService, EquipBestService, GameUITeleports.
- Run BuildStarterGameUI only when generating the original UI. For the owner's newer Pets artwork, preserve the imported frame and run GameUILayout.Apply(GameUI); the client also applies it idempotently.

## Pets and Backpack

Frames.Pets is a compact right-side equipped-pet summary. It lists only entries with State=Plot, their individual earnings, total income, equipped count, a larger close button, and the supplied Equip Best artwork button. There are no inventory tabs, item actions, or status text. The desktop panel is 240 by approximately 383 pixels and shrinks to fit smaller viewports.

Bag/Held pets appear as Tools in Roblox's built-in Backpack. Selecting a pet holds it; clicking while inside the owner's base places it on the plot. Taking a plot pet back returns it to the Backpack. PetBackpack mirrors state changes, removes equipped/deleted entry Tools, and rebuilds Backpack Tools after respawn. It reuses the existing rigged held-pet factory and server plot placement rules.

Equip Best ranks income, respects the existing 24-pet cap and plot geometry, and rolls back lower-income/failed swaps. Inventory and cash remain session-only.

## Camera and shop buttons

Aiming from third person interpolates to a right shoulder view, retains the visible character and real gun, uses a centered muzzle-checked ray, and stops the camera before walls. Aiming from first person retains the existing iron sights, scope and viewmodel. Releasing aim restores the previous zoom and camera control.

Weapons lands four studs outside the shop activation ring and faces the counter. Enter the ring to open the existing weapon shop. Speed mirrors this safe arrival position across SpawnLocation.X. Base uses the owner's SpawnPoint. All destinations resolve on the server and retain rate limits and the carried-animal restriction.

Shop calls MarketplaceService.OpenShop(LocalPlayer), Roblox's native shop interface. It puts held Tools away so weapon input/cursor handling does not interfere.

## Motion

Buttons have centered anchors. A centered MotionVisual carries their artwork/caption and UIScale; the original button's layout slot and clickable area stay fixed. Hover/focus scales to 1.035, press to 0.95. Existing caption/color updates propagate to the artwork. Disabled buttons reset immediately, and mouse release outside the button clears pressed state.

Index/Pets open with a short scale/fade/slide and close in 0.12 seconds. Interrupted tweens cancel and reopen cleanly. Responsive positioning updates the frame's saved destination; grid measurement excludes its temporary animation scale. The weapon shop also uses shared button motion.

## Verification

Actual Studio Play checks passed:
- Three Bag pets produced exactly three Backpack Tools; no pets appeared in the equipped summary until placed.
- Built-in Backpack selection, placement on the base, put-away state, return to Backpack, and respawn restoration without duplicates.
- Equip Best selected three test pets ($137/s), removed their Backpack Tools, and produced three equipped-only cards with no item buttons.
- No status text or inventory tabs; smaller panel and larger X visually checked.
- Third-person shoulder view, visible avatar/reticle, release camera restoration; first-person sights and viewmodel preserved.
- Weapons arrived outside the ring without opening the shop view; Roblox's native Shop preview opened.
- Hover/press/release outside, stationary neighboring buttons and centered artwork, interrupted open/close, Index world tabs and caption updates.

QAStarterGameUI retains the ranking/cap/rollback mock regression. QAUIAnimation.client tests transition interruption, opacity/caption restoration and fixed centered layout slots. Both are manual fixtures.

Final Play console was clean. Temporary fixtures were discarded and Studio returned to Edit mode. Backup: ServerStorage.PetsCameraBackup_20261009. Save/publish the Studio place separately from Git.
