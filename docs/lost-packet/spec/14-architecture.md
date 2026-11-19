# 14 Architecture

## Why split now

`game.gd` is 1604 lines with 81 functions: world building, interiors, HUD,
quests, save, input, subway, boss glue. This expansion adds about ten
systems. Earlier branches already hit merge conflicts in `game.gd` (PR #1 and
#2). Splitting first lets milestones run in parallel worktrees with fewer
conflicts.

## Rules

- Split by moving code, not rewriting it. Each move is its own commit, and
  both smoke tests pass after each one.
- Data tables are GDScript `const` dictionaries in `data/*.gd` (no JSON
  parsing; typos fail at parse time).
- Autoloads only for state read almost everywhere (two, below). Everything
  else is a child node of `Game`.
- No base classes unless two or more scripts share real code. Hostiles share
  `levels.gd` helpers and `EnemyTag` by composition.
- `game.gd` stays the orchestrator: `_ready`, input dispatch, wiring.

## Target layout

```
scripts/
  game.gd                 orchestrator, input, wiring (target under 500 lines)
  player.gd               + dash, bark, pounce, spin, howl, pee, wardrobe sprites
  prey.gd                 + flock reference
  raccoon.gd boss.gd hedgehog.gd car.gd   existing, kept
  npc.gd                  friendly NPC (talk, wander, quest hook)
  enemies/cat.gd          5 cat types from config
  enemies/officer.gd      animal control officer
  enemies/drone.gd        security drone
  world/city_builder.gd   draw_ground, build_block, props, doors (moved from game.gd)
  world/interior.gd       lazy room builder from data/rooms.gd, elevator
  world/subway.gd         stations, train, travel (moved from game.gd)
  systems/save.gd         save_game / load_game, schema v2 (moved from game.gd)
  systems/quests.gd       QUESTS tracking, bump(), stat() (moved from game.gd)
  systems/weather.gd      weather + day/night phase helpers
  systems/wanted.gd       heat, stars, officer spawning
  systems/economy.gd      price(), wallet, stock ticks
  systems/levels.gd       scale_for_level(), XP rules
  systems/territory.gd    markers, claims, reputation
  puzzles/*.gd            one per puzzle type
  ui/hud.gd               existing HUD code (moved from game.gd)
  ui/home.gd ui/inventory.gd ui/shop.gd ui/gps.gd ui/wardrobe.gd
  ui/stocks.gd ui/dialog.gd ui/enemy_tag.gd ui/pound.gd
autoload/
  story.gd                Story: flags, items, objective(), target(), cutscene runner
  sound.gd                Sound: sfx(name), footsteps, music crossfade
data/
  cities.gd rooms.gd spawns.gd items.gd wardrobe.gd bosses.gd
  puzzles.gd story.gd (cutscenes, dialog, flashbacks) quests.gd
tests/
  smoke.gd                existing + new checks per milestone
tools/
  smoke_test.gd           existing
  gen_assets.py           + new sprites and SFX
  xp_sim.py               pacing sim for the XP curve (stdlib only)
```

## Autoloads

| Name | Why global |
|------|------------|
| `Story` | Read by world, UI, NPCs, puzzles and save |
| `Sound` | `sfx()` is called from every actor script (today through `game`) |

Everything else goes through `game` (actors already get a `game` reference
in `setup()`).

## Main signals

| Signal | Emitter | Listeners |
|--------|---------|-----------|
| `leveled` (exists) | player | hud, save, story gates |
| `died` (exists) | player | game: death screen, or pound when wanted |
| `flag_set(name)` | Story | gps, quests, city_builder (unlocks) |
| `stars_changed(n)` | wanted | hud, officer spawner |
| `city_changed(id)` | game | Sound (music), weather, hud, gps |
| `phase_changed(i)` | boss | hud boss bar, Sound |
| `room_entered(template)` | interior | Sound (music, ambience duck), story |

## Tests

- Run: `godot --headless --fixed-fps 60 --path . -s tests/smoke.gd` and
  `godot --headless --path . -s tools/smoke_test.gd`. Both use throwaway saves.
- Each milestone adds asserts to `tests/smoke.gd` (listed per task in
  `PLAN.md`). No test framework.
- `tools/xp_sim.py`: stdlib script, prints hours to each gate for a scripted
  player; asserts the pacing table in `10-progression.md` within 25%.

## Performance budget

- Web export, 60 fps on a mid laptop; aim under 8 ms script time per frame.
- One city and one interior in memory at a time.
- Snow/rain particles capped at 400 on screen.
- Profile in a web build after M2-1 (bigger map) and M3-3 (weather).
