# Implementation plan: "Lost Packet"

Read `README.md` first (scope, conflict resolutions, key map). Each task
points at the spec section that defines it. Sizes: **S** under half a day,
**M** 1-2 days, **L** 3-5 days (one developer with Claude Code).

A task is done only when:
1. Both smoke tests pass:
   `godot --headless --fixed-fps 60 --path . -s tests/smoke.gd` and
   `godot --headless --path . -s tools/smoke_test.gd`.
2. Its "Check" is added to `tests/smoke.gd`, or is a manual playtest step
   where marked **manual**.
3. The game launches and the feature works in a short playtest.

One task = one worktree = one PR, unless grouped below.

## Milestone overview

| # | Milestone | Outcome | Depends on |
|---|-----------|---------|------------|
| M0 | Foundation | `game.gd` split, data tables, save v2, Sound autoload | none |
| M1 | Combat and progression core | Enemy levels, overhead UI, dash, bark, new XP curve | M0 |
| M2 | World scale | Bigger NYC, city table, interior system, elevators, GPS | M0 |
| M3 | Living city | Day/night spawns, cats, weather, flocks, footsteps, territory | M1, M2 |
| M4 | Economy and law | Prices, NYC shops, bodega cats, wanted, pound, dog park, trader, NYSE stocks, inventory, wardrobe | M2 (M4-4 also M1) |
| M5 | Story framework + Ch 1 | Story, cutscenes, scent, puzzles, flashbacks, HQ, Fat Cat, music, home screen | M3, M4 |
| | **Checkpoint A** | **Ch 1 playable from start to clue. Ship a build.** | |
| M6 | Ch 2 San Francisco | SF city, fog, Seagull King, SF HQ | M5 |
| M7 | Ch 3 Tokyo | Tokyo city, rain, Maneki Neko, Claw King, Spin | M6 |
| M8 | Ch 4 Shenzhen | Shenzhen city, haze/storm, Mecha-Cat, drones | M7 |
| M9 | Ch 5 Finale | Tower floors, Null Cat, endings, credits | M8 |
| | **Checkpoint B** | **Full story playable. Ship a build.** | |
| M10 | Post-game and polish | Rebirth/NG+, Sam outfits, balance, accessibility, web export | M9 |

Parallel lanes once M0 lands: **Lane A** M1 then M3; **Lane B** M2 then M4.
They meet at M5. Inside M6-M8, art and audio tasks run alongside code tasks.

---

## M0 Foundation

| ID | Task | Size | Depends | Files | Check |
|----|------|------|---------|-------|-------|
| M0-1 | Pull `origin/main` into the local `main` checkout. Move web export output (`index.*`, `Archive.zip`) out of the repo root into `build/web/` and ignore `build/`. Commit `export_presets.cfg`. | S | none | `.gitignore`, `export_presets.cfg` | `git status` clean after an export |
| M0-2 | Move save code to `systems/save.gd` (no behavior change). | S | M0-1 | `game.gd`, `systems/save.gd` | existing tests pass |
| M0-3 | Move quest tracking (`QUESTS`, `bump`, `stat`, tracker) to `systems/quests.gd` + `data/quests.gd`. | M | M0-1 | `game.gd`, `systems/quests.gd`, `data/quests.gd` | quest smoke test passes |
| M0-4 | Move HUD building and updates to `ui/hud.gd`. | M | M0-1 | `game.gd`, `ui/hud.gd` | tests pass; **manual** HUD unchanged |
| M0-5 | Move city building to `world/city_builder.gd`, subway to `world/subway.gd`. | M | M0-1 | `game.gd`, `world/*` | train-kill test passes |
| M0-6 | `Sound` autoload: `sfx()`, buses Music/SFX/Ambience, settings sliders. | S | M0-1 | `autoload/sound.gd`, `project.godot`, `default_bus_layout.tres` | buses exist; `Sound.sfx("bark")` runs clean |
| M0-7 | Move `BOSSES`, `PREY`, `SHOP` into `data/bosses.gd`, `data/items.gd`. | S | M0-3 | `data/*` | tests pass |
| M0-8 | Save schema v2 skeleton: `meta/version`, read-with-default for every v2 key. | M | M0-2 | `systems/save.gd` | v1 file loads; full v2 round trip compares equal |

Do M0-2..M0-5 one after another (they all touch `game.gd`). Exit: no behavior
change, `game.gd` under 700 lines (under 500 by M5).

## M1 Combat and progression core

| ID | Task | Size | Depends | Spec | Check |
|----|------|------|---------|------|-------|
| M1-1 | `systems/levels.gd` with `scale_for_level()`; raccoons, prey, park bosses, hedgehog get `level`. | M | M0 | 06 Enemy levels | level 20 raccoon hp = base x (1 + 0.15 x 19) |
| M1-2 | `ui/enemy_tag.gd`: name, Lv tag colors, HP bar; damage numbers via `float_text()` with crit style; replace raccoon `_draw()` bar. | M | M1-1 | 06 Overhead UI | tag shows after a hit, hides 3 s later |
| M1-3 | Dash (C): burst, invulnerable, cooldown, stamina. | S | M0 | 05 | dash covers 200-240 px; no damage taken mid-dash |
| M1-4 | Bark (R): flee/stun by level gap; `bark_scare` SFX. | S | M1-1 | 05 | low raccoon flees, higher one does not |
| M1-5 | XP curve `15 + 6L`, catch-up, +1 point per 10 levels, low-enemy 50% XP, remove `BOSS_LEVEL_LOSS`. | S | M1-1 | 10 | sum of `xp_needed()` 1..99 = 31,185; hedgehog loss keeps level |
| M1-6 | `tools/xp_sim.py` pacing sim. | S | M1-5 | 10 Pacing | within 25% of the pacing table |
| M1-7 | Ability bar HUD with cooldown sweeps. | S | M1-3, M1-4 | 11 HUD | **manual** |
| M1-8 | Pounce (hold Space, level 30). | S | M1-3 | 05 | landing hit = 2x bite damage |

## M2 World scale

| ID | Task | Size | Depends | Spec | Check |
|----|------|------|---------|------|-------|
| M2-1 | NYC to 9 x 7, fixed landmark coordinates, old layout kept top-left, load fix-up to nearest road; profile web build. | M | M0-5 | 02 Bigger map | old save position lands on a road; frame time logged |
| M2-2 | `data/cities.gd`; builder reads it; free and rebuild a city behind a fade. NYC only for now. | M | M2-1 | 02 City data | build twice, same node count (no leak) |
| M2-3 | Interior system: `data/rooms.gd`, `world/interior.gd`, lazy build at `Vector2(20000, 0)`, doors on every building; port bodega, subway, burrow; templates apartment, office, shop_small. | L | M2-1 | 03 | 20 random doors in and out: always back at the right street door; one interior node max |
| M2-4 | Elevators with locked-floor reasons; landmarks get 6 floors and a roof view. | M | M2-3 | 03 Elevators | lobby to floor 3 and back |
| M2-5 | GPS: minimap, POI icons, waypoint, edge arrow; click map to set waypoint. | M | M2-2 | 11 GPS | waypoint on a bodega; arrow points at it |
| M2-6 | Airport room with gates (only NYC open); flight cutscene stub. | S | M2-3 | 02 City travel | locked gate shows its hint |

## M3 Living city

| ID | Task | Size | Depends | Spec | Check |
|----|------|------|---------|------|-------|
| M3-1 | `data/spawns.gd` day/dusk/night tables; spawner reads phase; night +2 levels; prey cap scales with area. | M | M1-1, M2-2 | 02 Day/night | night spawns have no pigeons |
| M3-2 | `enemies/cat.gd` with 5 types, possum, rat swarm; hiss/yowl synth per type. | L | M3-1 | 06, 12 | each type spawns and can be beaten |
| M3-3 | `systems/weather.gd`: daily roll, blend, all modifiers; snow and rain visuals (fog/haze/storm visuals ship with their cities). | M | M2-2 | 02 Weather | snow sets sprint multiplier to 0.9 |
| M3-4 | Pigeon flocks: group spawn, scatter together, regroup. | S | M3-1 | 07 Pigeons | catch one, all flock members flee |
| M3-5 | Footsteps by surface; ambience loop with indoor duck; CC0 sounds + `assets/sfx/CREDITS.md`. | M | M0-6, M3-3 | 12 | surface lookup is grass inside a park |
| M3-6 | Territory: pee (G), markers, claims, rep tiers, fade, rival dog. | M | M3-1 | 05 Territory | 3 markers = claimed; markers fade after 3 days |

## M4 Economy and law

| ID | Task | Size | Depends | Spec | Check |
|----|------|------|---------|------|-------|
| M4-1 | `systems/economy.gd`: price formula, bones, discount cap; shop UI (x1/x5, struck price, footer). | M | M2-3 | 09, 11 Shop | discount never above 25% |
| M4-2 | NYC shops: gas station, cafe (closed at night), pizza shop, 4 bodegas with rolls; food and drink buff slots. | M | M4-1 | 03, 09 | cafe locked at night; buff timer runs down |
| M4-3 | Bodega cats: 4 NYC cats, points, daily limits, hint at 3 hearts, gift at 5. | M | M4-1 | 07 Bodega cats | 5 gifts in a day: only 3 count |
| M4-4 | `systems/wanted.gd`, `enemies/officer.gd`, vans, net gun, drone light, whistle and siren, edge warning. | L | M1-1, M2-2 | 08 | stars = heat / 25; decay starts after 10 s unseen |
| M4-5 | Pizza steal with the clerk's watch timer. | S | M4-2, M4-4 | 08 Stealing | steal adds 25 heat |
| M4-6 | Pound room, fine, 3-stage breakout. | M | M4-4 | 08 Pound | caught = pound with heat 0; fine is correct |
| M4-7 | `npc.gd`; dog park safe zone (fence, regen, officers blocked); move park bosses off dog park blocks; 3 NYC quest dogs. | M | M4-4 | 03 Dog park, 07 | officer stops at the fence; HP regenerates inside |
| M4-8 | Pocket the trader: daily spawn, stock, map ping, hint. | S | M4-1, M2-5 | 07, 09 | stock = 4 entries from the table |
| M4-9 | NYSE room, ticks, news, stock app (P), saved prices and holdings. | M | M4-1, M2-3 | 09 Stock market | 10,000-tick sim in [1, 999]; same-tick round trip loses |
| M4-10 | Inventory (I): Items/Sam/Album/Keys/Stocks tabs, hotbar binding. | M | M4-1 | 11 Inventory | **manual** |
| M4-11 | Wardrobe: item table, hats/collars/overlays as child sprites with per-breed offsets, screen (B). First items: skins, name collar, bodega cap. | M | M4-1 | 05, 11 | equip hat, save, reload: hat still on |

## M5 Story framework and Chapter 1

| ID | Task | Size | Depends | Spec | Check |
|----|------|------|---------|------|-------|
| M5-1 | `Story` autoload: flags, items, keycards, `objective()`, `target()`; gate checks; level-gate popup with "Find XP". | M | M0-8 | 01 Unlock schedule | G1 closed at level 19, open at 20 with keycard |
| M5-2 | Dialog box, cutscene runner (say/pan/wait/sfx/music/flag), `data/story.gd` with Ch 1 scripts. | M | M5-1 | 01 Cutscene, 11 Dialog | Esc skip still sets the cutscene's flags |
| M5-3 | Scent trail (V): road-grid path, weather range, edge arrow. | M | M5-1, M3-3 | 01 Story mechanics | path ends at the target; shorter range in rain |
| M5-4 | Puzzle framework + `sort`, `logic`, `program`; hold-R reset; hints after 3 resets; nyc_1-3 data. | L | M2-3 | 04 | each NYC floor solved by a scripted input list |
| M5-5 | Flashback room, sepia, Sam NPC, album, replay; fb_nyc_1-3. | M | M5-2 | 04 Flashback playback | clearing nyc_1 sets `fb_nyc_1` and adds a polaroid |
| M5-6 | NYC HQ building, lobby, front desk, elevator floors 1-4 (Tower floors hidden). | S | M2-4, M5-4 | 03 Hack Club HQ | floor 4 locked until 1-3 cleared |
| M5-7 | Fat Cat: `phases` support in `boss.gd`; coin_fan, briefcase_charge, margin_call, ticker_wave, golden_parachute; NYSE arena; drops. | L | M4-9, M1-2 | 06 Fat Cat | phase change at 60% and 30%; keycard + 5 bones dropped |
| M5-8 | Ch 1 content: Sam's apartment start, bodega find, tutorial as Ch 1 quest line, clue room, airport SF gate opens on `ch1_clue`. | M | M5-1..M5-7 | 01 Ch 1 | scripted run new game to `ch1_clue` |
| M5-9 | Music in `Sound`: crossfade, priority; home_theme, nyc_jazz(+night), interior_shop, hq_puzzle, boss_fatcat, piano_nyc, pound_escape; `assets/music/CREDITS.md`. | M | M0-6 | 12 Music | track swaps on room enter; same track is a no-op |
| M5-10 | Home screen: Continue/New Story/Free Roam/Wardrobe/Album/Settings/Quit. | M | M5-1 | 11 Home | Continue hidden with no save |
| M5-11 | Pound flashback line; officers near story spots. | S | M4-6, M5-5 | 01 Ties | **manual** |

**Checkpoint A:** web export; 2-3 people playtest Ch 1 start to clue; feed
real timings into `xp_sim.py`; fix the top issues before M6.

## M6 Chapter 2: San Francisco

| ID | Task | Size | Depends | Spec |
|----|------|------|---------|------|
| M6-1 | SF entry in `data/cities.gd`, palette, hill slowdown, landmarks, cable car (subway reskin), arrival + `cs_arrive_sf`. | L | M5 | 02 |
| M6-2 | Fog visuals and sight radius; aggro limited by sight. | M | M6-1 | 02 Weather |
| M6-3 | 3 corner stores, cafe, gas station, pizza; 3 SF bodega cats; price mult 1.4. | M | M6-1 | 03, 07, 09 |
| M6-4 | Seagull enemy; Seagull King (dive_bomb, fish_rain, gust, flock_call) on the pier; backpack drop. | L | M6-1 | 06 |
| M6-5 | Puzzle types `debug`, `merge`, `ping`; sf_1-3; fb_sf_1-3; SF HQ; clue room. | L | M6-1 | 04 |
| M6-6 | SF quest dogs, Ch 2 quest line, cutscenes. | M | M6-4, M6-5 | 01, 07 |
| M6-7 | Music sf_synth(+night), boss_seagull, piano_sf; fog_horn; crowd_en/es/yue. | M | M6-1 | 12 |

Milestone check: scripted run from SF arrival to `ch2_clue`.

## M7 Chapter 3: Tokyo

| ID | Task | Size | Depends | Spec |
|----|------|------|---------|------|
| M7-1 | Tokyo entry, narrow blocks, neon palette, train reskin, arrival cutscene. | L | M6 | 02 |
| M7-2 | Rain visuals, puddles, slippery dash, puddle footsteps. | M | M7-1 | 02, 05, 12 |
| M7-3 | Maneki Neko guide, 8 statues, Lucky Paw collar. | S | M7-1 | 02, 07 |
| M7-4 | 3 konbini with chime, Tokyo cafe (Matcha Mutt), 3 bodega cats. | M | M7-1 | 03, 07, 09 |
| M7-5 | Arcade, claw machines, Claw King (claw_grab, capsule_toss, neon_floor, jackpot). | L | M7-1 | 06 |
| M7-6 | Puzzle types `pattern`, `stack`, `memory`; tokyo_1-3; flashbacks; Spin (X) unlock after fb_tokyo_3. | L | M7-1 | 04, 05 |
| M7-7 | Howl (H, level 60), Tokyo quest dogs, Ch 3 quest line, cutscenes. | M | M7-5, M7-6 | 05, 07 |
| M7-8 | Music tokyo_lofi(+night), boss_claw, piano_tokyo; rain_loop; crowd_ja. | M | M7-1 | 12 |

Milestone check: scripted run from Tokyo arrival to `ch3_clue`; Spin works after.

## M8 Chapter 4: Shenzhen

| ID | Task | Size | Depends | Spec |
|----|------|------|---------|------|
| M8-1 | Shenzhen entry, LED palette, metro reskin, arrival cutscene. | L | M7 | 02 |
| M8-2 | Haze and storm (lightning reveal). | S | M8-1 | 02 |
| M8-3 | Electronics market + rooftop elevator, 3 stalls, 3 bodega cats, battery treat. | M | M8-1 | 03, 07, 09 |
| M8-4 | Security drones; Shenzhen heat x1.5 gain, x0.75 decay. | M | M8-1 | 06, 08 |
| M8-5 | Mecha-Cat (laser_sweep, missile_lock, emp, drone_swarm, armor break); label reveal. | L | M8-4 | 06 |
| M8-6 | Puzzle types `binary`, `circuit`, `route`; shenzhen_1-3; flashbacks; clue message. | L | M8-1 | 04 |
| M8-7 | Shenzhen quest dogs, Ch 4 quest line, cutscenes. | M | M8-5, M8-6 | 01, 07 |
| M8-8 | Music shenzhen_electro(+night), boss_mecha, piano_shenzhen; thunder, cicadas; crowd_zh. | M | M8-1 | 12 |

Milestone check: scripted run from Shenzhen arrival to `ch4_clue`.

## M9 Chapter 5: Finale

| ID | Task | Size | Depends | Spec |
|----|------|------|---------|------|
| M9-1 | Tower floors T1-T5 in the NYC HQ elevator (hidden until `ch4_clue`; T5 needs level 100); combined puzzle rooms; drones; fb_tower_1-5. | L | M8 | 04 |
| M9-2 | Null Cat: phases 1a-1d reuse boss specials; phase 2 corrupt, invert, null_clone, stack_overflow; `cs_nullcat_phase2`. | L | M9-1 | 06 Null Cat |
| M9-3 | Reunion cutscene, credits over polaroids, post-credits remaining count, roof replay. | M | M9-2 | 01 Endings |
| M9-4 | True ending check (17 flashbacks + 13 cats at 5 hearts), true ending scene, GPS helper cat. | M | M9-3 | 01 Endings, 11 GPS |
| M9-5 | Music tower_theme, boss_nullcat_1/2, credits. | M | M9-1 | 12 |

**Checkpoint B:** full playthrough on the web build (debug saves per chapter
allowed). Fix blockers.

## M10 Post-game and polish

| ID | Task | Size | Depends | Spec |
|----|------|------|---------|------|
| M10-1 | Rebirth / New Game+: reset and keep lists, scaling, rebirth stars. | M | M9 | 10 Rebirth |
| M10-2 | Hidden Sam outfit per city on NG+; Sam-themed bone items; Null crown. | S | M10-1, M4-11 | 05 |
| M10-3 | Balance pass with `xp_sim.py` and playtest data (prices, boss HP). | M | M9 | 09, 10 |
| M10-4 | Accessibility: reduce motion, text size, color-plus-text tags. | S | M9 | 11 |
| M10-5 | Web export size and perf: OGG bitrates, texture import, profile each city. | M | M9 | 14 Performance |
| M10-6 | Art for all new sprites in `gen_assets.py` (cats, officers, bosses, rooms, hats). Runs in parallel from M3 on. | L | M3 | all |

## Asset checklist (made in `tools/gen_assets.py` unless noted)

- Sprites: 5 cats, possum, seagull, rival dog, officer, van, drone, Pocket,
  Maneki Neko + statue, 12 quest dogs, 13 bodega cats (tints of the base cat),
  Sam, 5 bosses (Fat Cat, Seagull King, Claw King, Mecha-Cat, Null Cat),
  about 20 wardrobe items, territory marker, puddle, snowflake, rain streak.
- Tiles per city: road, sidewalk, grass, 3 building variants, landmarks, HQ.
- Room tiles and props for every template in `03-buildings-interiors.md`.
- UI icons: abilities, stars, weather, buffs, POIs, items, tickers.
- SFX: every "synth" row in `12-audio.md`.
- Recorded audio (CC0) and music: per `12-audio.md`, listed in CREDITS files.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Story and buildings use Hack Club's real name | Permission or brand issue if published | Ask Hack Club before publishing; original art, no logo; keep the name in one constant in `data/story.gd` |
| Real places (NYSE, Empire State, Chrysler) | Low; landmarks only | Text signs only, no logos |
| Scope: 4 cities, 5 bosses, 21 floors | Months of work | Checkpoint A is a complete Ch 1 build; each later city is a self-contained milestone |
| `game.gd` merge conflicts | Slows parallel work | M0 split first; one task per worktree |
| Web build size (36 MB wasm today) | Slow first load | OGG, short loops, budget in `12-audio.md`; checked in M10-5 |
| Bigger map performance | Low fps on web | Measure in M2-1; hide far blocks if needed |
| Music sourcing | Blocks M5-9 | Decide early (open question 2); placeholders meanwhile |
| Balance over 100 levels | Grindy or too easy | `xp_sim.py` plus Checkpoint A playtest |

## Open questions (defaults used until answered)

1. Tower location: default NYC HQ upper floors; alternative a separate district.
2. Music: who makes it? Default placeholder synth loops from `gen_assets.py`
   until real tracks exist.
3. Hack Club naming: default keep the name with original art; confirm before
   publishing.
4. Free roam: default unlocked after `ch1_clue`.

## Coverage check (every requested item to its task)

| Request item | Spec | Task |
|--------------|------|------|
| Bigger map | 02 | M2-1 |
| SF, Tokyo, Shenzhen | 02 | M6-1, M7-1, M8-1 |
| Day/night, night enemies | 02 | M3-1 |
| Snow NYC, fog SF, rain Tokyo | 02 | M3-3, M6-2, M7-2 |
| Maneki Neko | 02, 07 | M7-3 |
| Every building has an inside | 03 | M2-3 |
| Elevators | 03 | M2-4 |
| Gas station, cafes, pizza shop, different bodegas | 03 | M4-2, M6-3, M7-4, M8-3 |
| NYSE | 03, 09 | M4-9 |
| Airport | 02, 03 | M2-6 |
| Pizza steal = wanted | 08 | M4-5 |
| Dog park safe zone + quest dogs | 03, 07 | M4-7, M6-6, M7-7, M8-7 |
| Pound: minigame or pay | 08 | M4-6 |
| Hack Club HQ per city, puzzle floors, final boss | 03, 04 | M5-4, M5-6, M6-5, M7-6, M8-6, M9-1 |
| Dash, bark scare + SFX | 05, 12 | M1-3, M1-4 |
| New special attacks | 05 | M1-8, M7-6, M7-7 |
| Peeing territory and reputation | 05 | M3-6 |
| Wardrobe (skins, collars, hats) | 05, 11 | M4-11, M10-2 |
| Enemy levels, damage numbers, level tags, health | 06 | M1-1, M1-2 |
| Fat Cat, Seagull King, Tokyo boss, Mecha-Cat, final boss | 06 | M5-7, M6-4, M7-5, M8-5, M9-2 |
| Different cats, hiss/yowl per type | 06, 12 | M3-2 |
| Bodega cats discounts | 07, 09 | M4-3 |
| Pigeon groups | 07 | M3-4 |
| Animal control, wanted level, caught = pound | 08 | M4-4, M4-6 |
| Currency, differing prices | 09 | M4-1 |
| Wandering trader | 07, 09 | M4-8 |
| Bones from bosses | 09 | M4-1, M5-7 |
| Stock market minigame | 09 | M4-9 |
| Easier progression, level 100 cap | 10 | M1-5, M1-6 |
| Rebirth | 10 | M10-1 |
| Unlock levels (story schedule) | 01 | M5-1 |
| Home screen, inventory, shop UI, GPS | 11 | M5-10, M4-10, M4-1, M2-5 |
| Music per city, boss themes | 12 | M5-9, M6-7, M7-8, M8-8, M9-5 |
| All listed SFX (footsteps, horns, sirens, pigeons, subway, bell, jingle, ka-ching, whistle, crowd chatter) | 12 | M3-2, M3-5, M4-4, M5-9 and city audio tasks |
| Story: chapters, scent trail, flashbacks, Sam's items, gates | 01, 04 | M5-1..M5-8, M6-M9 |
| Endings, true ending | 01 | M9-3, M9-4 |
| New Game+ Sam outfits | 01, 10 | M10-2 |
