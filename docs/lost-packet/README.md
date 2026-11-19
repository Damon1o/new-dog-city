# New Dog City: "Lost Packet" expansion

Spec sheet and implementation plan for the feature list and the story mode.
Every feature from the request is in exactly one spec file below. `PLAN.md`
turns them into ordered, testable tasks.

## Files

| File | Covers |
|------|--------|
| [PLAN.md](PLAN.md) | Milestones, tasks, dependencies, acceptance checks, test plan, risks |
| [spec/01-story.md](spec/01-story.md) | Story mode "Lost Packet": premise, chapters, cutscenes, endings, post-game |
| [spec/02-cities-world.md](spec/02-cities-world.md) | City data, bigger map, city travel, day/night, weather |
| [spec/03-buildings-interiors.md](spec/03-buildings-interiors.md) | Interior system, elevators, every building type, Hack Club HQ |
| [spec/04-hq-puzzles.md](spec/04-hq-puzzles.md) | Every HQ floor puzzle, flashbacks, puzzle framework |
| [spec/05-dog.md](spec/05-dog.md) | Byte: moves, special attacks, territory, wardrobe |
| [spec/06-enemies-bosses.md](spec/06-enemies-bosses.md) | Enemy levels, overhead UI, every boss with attack specs |
| [spec/07-npcs-animals.md](spec/07-npcs-animals.md) | Cats, bodega cats, pigeon flocks, park dogs, Maneki Neko, trader |
| [spec/08-wanted-pound.md](spec/08-wanted-pound.md) | Wanted level, animal control, pound and breakout |
| [spec/09-economy.md](spec/09-economy.md) | Treats, bones, prices, loyalty, trader stock, kibble stock market |
| [spec/10-progression.md](spec/10-progression.md) | XP curve, level 100 cap, gates, quests, rebirth / New Game+ |
| [spec/11-ui-ux.md](spec/11-ui-ux.md) | Home screen, HUD, inventory, shop, GPS, wardrobe, dialog |
| [spec/12-audio.md](spec/12-audio.md) | Music per city, boss themes, every sound effect |
| [spec/13-save-data.md](spec/13-save-data.md) | Save schema v2 and migration |
| [spec/14-architecture.md](spec/14-architecture.md) | Splitting `game.gd`, file layout, data tables |

## Conflicts in the request, and how this spec resolves them

1. **City unlock levels.** The feature list says SF 20 / Tokyo 40 / Shenzhen 60
   and "HQ Tower needs level 100 in every city". The story replaces this.
   Final rule:
   - A city becomes *reachable* when the previous city's HQ clue is found.
   - A city's *HQ door* opens at a fixed level: NYC 20, SF 40, Tokyo 60, Shenzhen 80.
   - The Tower top (final floors) needs level 100.
   - Since each HQ clue sits at the top of an HQ, a city is in practice reachable
     at its predecessor's HQ level (SF at about 20, Tokyo at about 40, Shenzhen at about 60).
     This keeps the chapter level bands (Ch2 is levels 20 to 40 in SF, and so on).
2. **Where the Tower is.** The story says "the Hack Club Tower" without a city.
   Spec: the Tower is the sealed upper floors of the NYC HQ. Byte comes home for
   the finale. This saves building a fifth city. Alternative, if you want it:
   a standalone Tower district in Shenzhen (see `spec/02-cities-world.md`).
3. **"One HQ Tower in every city, level 100."** Replaced by rule 1. Only the
   final floors need level 100.
4. **Tokyo boss** has no name in the request. Spec uses the arcade claw-machine
   cat idea, named **Claw King**.
5. **"Copy GTA 6."** Not copied. The game keeps its own open-world style:
   wanted level, a big city, its own systems and art.
6. **Duplicate audio line** (car horns, sirens, pigeons) is listed once.

## Baseline assumption

Work starts from `origin/main` at `da90c2f`, which already has PR #1 (click
attack, claw scratch) and PR #2 (restart, stat points, park bosses, cars,
quest lines, Boss Hedgehog). The local `main` checkout is behind and only
needs `git pull`. Current code: `game.gd` 1604 lines (81 functions),
`player.gd`, `boss.gd`, `hedgehog.gd`, `raccoon.gd`, `prey.gd`, `car.gd`,
smoke tests in `tests/smoke.gd` and `tools/smoke_test.gd`.

## Naming and pronouns

- Dog: **Byte** (he/him, as written in the request). The player can rename him
  with the existing collar name.
- Owner: **Sam** (they/them).
- Rogue AI final boss: **Null Cat**.

## Key map (current keys kept, new keys use free keys)

| Key | Action | Status |
|-----|--------|--------|
| WASD / arrows | Move | existing |
| Shift | Sprint | existing |
| Space | Bite (hold for Pounce, level 30) | existing, extended |
| Mouse left | Attack | existing (PR #1) |
| Q / E | Use Purina / water | existing |
| F | Interact | existing |
| M | Full map / god view | existing, becomes GPS map |
| Tab | Cycle skin | existing, kept as quick swap |
| 1-4 | Hotbar | existing |
| Esc | Pause | existing |
| C | Dash | new |
| R | Bark (in puzzles: hold R to reset room) | new |
| V (hold) | Sniff, shows scent trail | new |
| G (hold) | Pee, claim territory | new |
| X | Trick attack: Spin (unlocks in Ch 3) | new |
| H | Howl (level 60) | new |
| I | Inventory | new |
| B | Wardrobe | new |
| P | Stock portfolio (NYSE app) | new |
