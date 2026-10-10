---
name: shoot-an-animal-ui
description: The UI style of the Roblox game "Shoot an Animal" (placeId 80759588926584) - artwork panels, fonts, colors, outlines, buttons, cards, motion, layout, and the scripts that own each menu. Use before making or changing any screen, menu, button, popup, banner, HUD element, billboard or loading screen in that game.
---

# UI style for "Shoot an Animal"

Analyzed from the live place and a playtest on 2026-10-10. The live place is the source of truth
(Codex edits it too); re-read the owning script before changing a menu, and follow the
`roblox-codex-handoff` routine.

## 1. The look in one paragraph

Bright Roblox "simulator" style: chunky saturated panels with a studded/checker brick texture,
a big header with a 3D icon and a huge white ALL-CAPS title, a red square X close button, thick
dark-navy outlines on everything, white Gotham Black text with a dark stroke, green for money and
"buy", blue for neutral tabs, rarity colors on cards. Minimal text, big icons, nothing thin or flat-gray.

## 2. Two layers: artwork + code

1. **Artwork** (owner-supplied uploaded images in `StarterGui.GameUI`): HUD buttons and the window
   backgrounds. Code never rebuilds these; it fills each window's `Content` frame.
2. **Code-built content** (cards, tabs, labels, inventory, billboards) imitates the artwork with
   Frames + UIStroke + UIGradient + checker frames.

Reusable artwork (rbxassetid):

| Asset | Id |
|---|---|
| Top buttons TRAILS / BASE / WEAPONS | 136662966928021 / 102550011104339 / 139075974617724 |
| Side tiles SHOP / INDEX / PETS | 139683566746409 / 113878203384539 / 116639132539469 |
| Windows: Index (blue) / Shop (red) / Weapons (red) / Trails (blue) / Pets (tall) | 91732122532542 / 85070497559288 / 99377442582079 / 111457366685106 / 124746773897427 |
| Close X (wide windows) / Pets close | 132686830110178 / 89283948180234 |
| Green / Red long buttons (Purchase) | 134700750050307 / 90376828515229 |
| Green arrow (Weapons Previous/Next) | 75334101779357 |
| EQUIP BEST button | 72032431266277 |
| Shop cards: 2x Money / 2x Stamina / Stamina multiplier | 133026954897017 / 97429007557282 / 104457136111343 |
| Trail cards 1-8 | 71647949057759, 113980614323675, 77039256456103, 124736258177045, 84869869832332, 92409093007723, 112771152822529, 71061246354073 |

Wide windows are `ImageLabel`s, ScaleType Fit, Size `{0.456,0},{0.656,0}` centered, with
`UIAspectRatioConstraint` 1.4009; content goes in `Content` at `{0.035,0.247}` size `{0.93,0.71}`
(below the header). For a new menu with no artwork yet, reuse the closest-colored window image
or build the code version from section 4.

## 3. Tokens

- **Font**: `Enum.Font.GothamBlack` (GothamSSm Heavy) for almost everything; GothamSSm Bold for
  small button captions. ALL CAPS for titles, labels, buttons.
- **Text**: white `ffffff` (or `fafdff`), `TextScaled = true` + `UITextSizeConstraint`
  (MinTextSize 9, Max 14-20), `UIStroke` color `08141c`, thickness 1.3-2 (1.8 on HUD).
- **Outline color**: `08141c` (text, cards, billboards) / `0d141b` (inventory). Frame borders use
  `UIStroke` ApplyStrokeMode Border, thickness 2-4.
- **Colors**: money/income/buy green `4dee29` (buttons `57dc41`, base `388831`); neutral/tab blue
  `0a94de` / `16a3ec` (base `126794`); panel blue `54b0df`; red/close `f53737` / `f24236`
  (base `922f2b`); gold/sort `ffbc2f`; stamina cyan (HUD "⚡ 0 STAMINA"); lime detail `b3ff6c`;
  multiplier yellow `ffea3d`.
- **Rarity**: colors from `AnimalData.Rarities[r].color`; gradients from
  `UIStyle.rarityGradient(r)`; Secret = `UIStyle.rainbow(guiObject, rotation)` (a spinning rainbow).
- **Mutation names**: Gold `ffdb45`, Silver `e1eeff`.

## 4. Building blocks (code)

- **3D button**: outer `TextButton` = darker shade (base) with 3px `0d141b` stroke; child `Face`
  Frame at `{0,2},{0,2}` size `{1,-4},{1,-7}` in the bright color, `UIGradient` `ffffff -> cdcdcd`
  (rotation 90), optional checker; `Label` inside. The bottom strip of base color reads as depth.
- **Checker texture**: a `Checker` Frame filling the panel with a 6x4 grid (every other cell) of
  Frames, color `0d141b` at transparency 0.94 on colored panels, or white at 0.96 on dark/blue cards.
- **Tabs**: selected = green, others = blue (`AnimalMenuClient.renderIndex`).
- **Animal card** (Index): background = rarity color lerped 20% to white, `UIGradient`
  `ffffff -> afd2e6`, 2px dark stroke, `ViewportFrame` picture of
  `ReplicatedStorage.AnimalPreviews[species]` (locked = black silhouette `09121b`), then
  Name (caps), Rarity (rarity color), status line. Secret cards are white + rainbow.
- **World billboard card** (`AnimalOverheadUI`): `BillboardGui` size scale `6.8 x 2.25`,
  `AlwaysOnTop = false` (true does not render in this place), card gradient `35b1e7 -> 1169a5`,
  2.5 stroke, white checker, white name, lime details, health bar dark with fill lerping
  red `f14838` -> green `5aef41`.
- **Progress bar**: dark track, colored fill, centered caps label (Index world progress).
- `UIStyle` (ReplicatedStorage) is the older code-only kit (FredokaOne, orange windows). Keep using
  its helpers (`rainbow`, `rarityGradient`, `pop`, `showModel`), but don't use `UIStyle.window`
  for new menus; it no longer matches the artwork.

## 5. Motion and sound

- `UIMotion.BindButtons(screenGui)` on every ScreenGui: hover scales to 1.035, press to 0.95
  (it moves the visuals into a `MotionVisual` child; don't fight it with your own button scaling).
- Open/close a window with `UIMotion.SetFrame(frame, show)`: opens with scale 0.94 -> 1, fade-in and
  an 18px slide up (Quart, 0.22 s); closes in 0.12 s. It plays `UIOpen` / `UIClose` through
  `GameFeedback`. Use `GameFeedback.Success/Error/Equip` for result feedback.
- `UIStyle.pop` for quick pop-ins (Back easing 0.28 s).

## 6. Screen layout

- Top center: TRAILS / BASE / WEAPONS image buttons (travel).
- Left middle: SHOP, INDEX tiles. Right middle: PETS tile. Top right: small blue Music/SFX/VFX toggles.
- Bottom left HUD (`GameUI.HUD`): ⚡ STAMINA, cash `$100` (big green), `+$0 / SECOND`, `NEW ANIMALS IN m:ss`.
- Bottom center: hotbar (`AnimalInventoryUI.Hotbar`, B = bag, Q = gun, 1-0 pets) and the tutorial step card.
- Pets opens as a tall panel on the right; other menus open centered.
- Size with Scale + `UIAspectRatioConstraint` so it fits phones; test at phone size.

## 7. Who owns what

| Menu | Script |
|---|---|
| Index, Pets, Shop wiring, side/top buttons | `StarterPlayerScripts.AnimalMenuClient` (+ `GameUILayout`) |
| Shop purchases | `ShopClient`, `ReplicatedStorage.ShopWindowLayout` |
| Weapons shop | `WeaponShopClient` |
| Trails | `TrailShopClient` |
| Pet inventory + hotbar | `AnimalInventoryClient` (+ `AnimalInventoryLayout`) |
| Banners, catch popups | `AnimalClient`, `HuntingFeedback`, `FeedbackClient` |
| Tutorial | `TutorialClient`, `TutorialSpotlight` |
| Loading screen | `ReplicatedFirst.LoadingScreen` (code-only; Workspace attribute `SkipLoadingScreen` skips it) |
| Night countdown | `NightClient` |

## 8. Known style problems (2026-10-10)

- The tutorial step card is a dark, thin, low-contrast box (GothamSSm Medium); it doesn't match the rest
  and it covers the bottom of open menus.
- World labels such as "YOUR TREADMILL" (a BillboardGui) draw on top of open menus.
- Weapons window: both arrows show "<" in play. `Next` has Rotation 180, and `UIMotion` copies
  Rotation onto its `MotionVisual` child too, so the arrow turns 360 degrees. Flip the image or
  the visual instead of rotating a bound button.
- The HUD uses no artwork and the Music/SFX/VFX toggles are flat blue squares.

## 9. Testing UI via MCP

Playtest, then click with `user_mouse_input` at (screenshot x, screenshot y - 58). The 58px
offset comes from the top-bar inset. To see a window without its button, set
`PlayerGui.GameUI.Frames.<Name>.Visible = true` in the Client datamodel; content that a client
script fills on open will be empty. Screenshot every state before reporting.
