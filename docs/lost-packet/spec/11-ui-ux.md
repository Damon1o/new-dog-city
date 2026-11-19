# 11 UI and UX

Existing (in `game.gd`): HUD hangs off one full-rect `hud` Control with
anchors; stat bars, low-stat vignette, context menu (`show_menu`), shop menu,
pause menu with restart and volume, quest tracker, death screen, skin card,
boss bar, stat-point picker, map (M god view), `float_text()`.

Rule: each new screen is its own script in `scripts/ui/`, added under `hud`,
opened and closed through one `ui.open(name)` / `ui.close()` pair that also
sets `player.frozen`. Only one modal screen at a time.

## Home screen (new)

- Shown on launch.
- Background: an NYC street behind a dark overlay, slow camera pan.
- Buttons: Continue (only if a save exists), New Story, Free Roam (after
  `ch1_clue`), Wardrobe, Album, Settings (volume, reduce motion, controls
  list), Quit (desktop only; hidden on web).
- New Story over an existing save asks to confirm (overwrite warning).
- Title "New Dog City", subtitle "Lost Packet".

## HUD additions

| Element | Position | Notes |
|---------|----------|-------|
| Wanted stars | top right | 5 slots, flash on gain |
| Clock + weather icon | under stars | sun/moon from `sun()`, weather icon |
| City name + reputation tier | top left under bars | fades 3 s after a city change |
| Minimap (GPS) | bottom right, 180 x 180 | see GPS |
| Ability bar | bottom center | Dash, Bark, Spin, Howl with cooldown sweeps; locked ones hidden |
| Buff icons | above ability bar | food and drink buff timers |
| Bones counter | next to treats | |
| Story objective | top of quest tracker | one line from `Story.objective()` |
| Officer warning | screen edge | red flash toward a nearby officer |

## Inventory (I)

Tabs: **Items** (consumables, counts, use), **Sam** (story items with text),
**Album** (17 polaroids, replay), **Keys** (keycards), **Stocks** (holdings
summary, opens the P app). Hotbar 1-4 binds from the Items tab ("Bind to 1-4").

## Shop UI

Extends the existing shop menu:
- Rows: icon, name, effect line, price (struck-through base when
  discounted), owned count.
- Footer: wallet (treats, bones) and discount source ("Mango likes you: -6%").
- Buy x1 / x5. Rows grey out when unaffordable.
- Pizza shop adds a "Steal" row with the clerk's eye icon.

## GPS

- Minimap: roads, current block, icons for bodegas, dog parks, HQ, airport,
  pound, stations, Pocket (when in town), officers (red dots at 2+ stars),
  territory markers.
- Waypoint: the story target or a chosen POI. Off screen: edge arrow plus
  distance.
- Full map on M (existing god view) with a legend; click a POI to set the
  waypoint.
- After the true ending, GPS hints come as text bubbles from a small cat icon.

## Wardrobe screen (B)

Left: live Byte preview (turns every 2 s). Right: tabs Skin, Collar, Hat,
Outfit. Item grid: owned, buyable (price), locked (hint). Equip / Buy button.
Treats and bones shown.

## Enemy UI

Health bars, damage numbers and level tags: `06-enemies-bosses.md`.

## Dialog and cutscenes

- Dialog box at the bottom: portrait, name, typewriter text (30 chars/s; any
  key completes, then advances).
- Cutscene letterbox bars slide in; HUD hides.
- Level gate popup: title, requirement, "Find XP" button (sets the waypoint).

## Accessibility basics

- Text at least 14 px at 1280 x 720; scales with the existing stretch mode.
- Wanted stars and level tags never rely on color alone (level number and
  star count always shown).
- "Reduce motion" setting turns off screen shake and flashes.
- Every prompt shows its key.
