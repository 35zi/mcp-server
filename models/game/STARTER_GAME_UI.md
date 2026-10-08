# StarterGui GameUI

Installed in the gameplay Studio place (80759588926584), using the owner's imported cyan/stud GameUI images. The separate UI-only Studio place was left alone.

## Installation map

- `BuildStarterGameUI.lua`: run once in Edit mode after importing StarterGui.GameUI. Keeps the supplied Index image, close button, top/side tiles and their assets. Adds Index.Content, Frames.Pets, HUD and CarryBanner. Re-running replaces generated content. Imported buttons are explicitly made active.
- `AnimalMenuClient.client.lua`: replaces StarterPlayer.StarterPlayerScripts.AnimalMenuClient. Opens the existing frames, renders collections and pets, controls Close/Equip/Hold/Equip Best, updates cash/income, and calls the teleport remote. No second menu controller is needed.
- `EquipBestService.lua`: ServerScriptService ModuleScript used by InventoryService.
- `InventoryService.server.lua`: existing server script with the EquipBest action and rate limit added. Animal rig integration remains intact.
- `GameUITeleports.server.lua`: ServerScriptService Script, creates ReplicatedStorage.GameUITeleport at runtime.
- `AnimalClient.client.lua`: legacy AnimalHud cash/count/wave block removed; transient catch/stun/announcement feedback remains in AnimalEffects.
- `../weaponshop/WeaponClient.client.lua`: only the menu lookup changed from AnimalMenu to GameUI. Weapon shop source and appearance remain unchanged.

## Behavior

Index: world tabs, progress bar, found count, rarity cards, locked silhouettes and caught totals from Caught_<Species>. Collections come from AnimalData.Worlds.

Pets: Equipped means animals placed on the player's income-producing plot. All Pets includes Bag, Held and Plot entries. Equip Best ranks AnimalData.Income (size and mutation included), uses the existing plot placement rules, and caps equipped pets at 24. If a swap errors or earns less, it restores the previous plot and item states. Geometry can limit how many animals fit. Existing inventory and cash remain session-only, as before.

Base resolves the player's assigned PlotName and owned SpawnPoint. Weapons resolves WeaponShop.ShopView.ShopZone, which opens the existing shop. Speed reflects the shop's X coordinate across SpawnLocation.X, keeping the same Z and finding the floor. Destinations are computed on the server; requests are rate limited and cannot bypass bringing a carried animal home.

Desktop uses pet cards; small viewports use scrolling rows with larger controls and notification feedback. Menus hide side/top buttons when the viewport is narrow. GUI elements respect the imported DeviceSafeInsets.

## Verification

`QAStarterGameUI.lua` is a manual regression runner: pass the EquipBestService and AnimalData modules. It creates temporary mock inventories/plots, checks ranking/cap/income, held-tool cleanup and lower-income rollback, and removes its fixtures. A copy is under the Studio backup folder for inspection; it does not run automatically.

- Actual mouse clicks: Index/world switching/Close, Pets/tabs/Close, empty Equip Best, individual Equip/Unequip/Hold, held-pet Equip Best, Base, Weapons (including original shop Close), Speed.
- 33 temporary pets: selected 24 highest incomes, sum $737/s, 24 plot models; HUD and inventory totals agreed. Duplicate Equip Best requests were blocked.
- Deliberate placement-error fixture: old model and inventory state restored; temporary staging folder removed.
- Invalid destination, NaN ID, missing animal and teleport while carrying were rejected.
- Desktop screenshots: locked/unlocked Index, both worlds, empty/filled Pets. iPhone 17 Pro simulator: landscape and portrait visual previews; compact row layout and safe margins inspected. Studio mouse automation did not correctly target phone buttons, so phone interaction itself was not verified.
- Fresh desktop Play sessions had clean console output. All fixtures were temporary and removed by stopping Play. Studio returned to Edit/default viewport.

Backups: ServerStorage.StarterGuiBackup_20261008 contains the original GameUI and affected scripts (backup scripts disabled). Save/publish the Studio place separately from Git.

## Shared UI motion

`UIMotion.lua` is installed as ReplicatedStorage.UIMotion. AnimalMenuClient binds the GameUI buttons once, including buttons created later, and calls SetFrame for Index/Pets. Hover/focus uses 1.035 scale; press uses 0.95; releases return smoothly. Frames open with a 0.22-second scale/slide and 0.18-second fade, and close in 0.12 seconds. The original hierarchy, sizes and transparency values are preserved. Grid measurements exclude the temporary animation scale so layouts stay stable.

Tweens cancel when superseded, closing callbacks use revisions, removed buttons release state, and no idle animation loop is added. A runtime regression LocalScript is provided as QAUIAnimation.client.lua; install it temporarily to test interrupted open/close, opacity restoration and position reset. Studio's copy is disabled in ServerStorage.UIMotionBackup_20261008.

Verified in Play: hover, held press, release outside the button, new pet action hover, Index/Pets switch and Close, rapid real clicks, interrupted transitions and stable Desert card sizing. Final console clean; Studio returned to Edit.

Concurrent live Studio additions (PrettyName, new worlds/Secret cards and carry text) were preserved while applying motion. The local controller contains only the motion changes against the recorded repo version; merge concurrent gameplay changes before replacing the full live controller from this branch. The Secret name-gradient lookup in live Studio was corrected to retrieve the Name label rather than the instance's Name string. This task does not change AnimalData or UIStyle.
