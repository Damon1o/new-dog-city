# 10 Progression

## Today

`player.gd`: `xp_needed() = 20 + level * 10`, cap 100 in `add_xp()`, one stat
point per level (`points`, spent on `stat_hp`, `stat_atk`, `stat_spd`).
Total XP to reach 100 today: 51,480.

## Easier progression

- New curve: `xp_needed() = 15 + level * 6`. Total to 100: 31,185 (about 40% less).
- XP from enemies and prey scales with their level (`06-enemies-bosses.md`),
  so later cities pay more per kill.
- Low enemies (5+ levels below Byte) give 50% XP, so farming NYC rats at
  level 70 is not the fastest path.
- Catch-up: if Byte is more than 10 levels below the current city's HQ level,
  all XP +25%.
- Death keeps XP and level (existing treat halving stays). Daven the Hedgehog's
  10-level loss is removed.

### Pacing targets (tuned with the sim in task M1-6)

| Level | Target play time | Where |
|-------|------------------|-------|
| 20 | 1.5 h | NYC |
| 40 | 3.5 h | SF |
| 60 | 6 h | Tokyo |
| 80 | 9 h | Shenzhen |
| 100 | 12 h | Tower |

Each city's quest chains, boss and puzzles should cover about 40% of its
level band's XP. Enemies and prey cover the rest.

## Level 100 cap

Already enforced in `add_xp()`. At 100 the XP bar shows "MAX".

## Gates

Story gates are in `01-story.md`. Level gates check `player.level` only.

## Stat points

Keep 1 point per level, plus 1 bonus point every 10 levels. Soft cap 60
points per stat (each point past 60 counts half) to keep builds balanced.

## Quests

The existing `QUESTS` table and tracker stay. Additions:
- One story quest line per chapter (`"Ch 1: Missing"`, ...), driven by `Story`.
- Dog park chains (`07-npcs-animals.md`).
- Bodega cat friendship steps.
- Territory quests (claim N blocks, reach a reputation tier).
- Tracker order: current story step, then up to 2 side quests.

## Rebirth (New Game+)

- Unlocks after beating Null Cat (either ending). Offered on the Tower roof
  and from the home screen.
- Reset: level, XP, stat points, reachable cities (NYC only), story flags,
  Sam's items, bodega cat hearts, territory, quest progress; treats set to 10.
- Kept: wardrobe items, bones, flashback album, rebirth count, true-ending
  flag. Stock holdings are sold at market and 10% of the value is kept as treats.
- Scaling per rebirth: enemies +10% HP and damage, rewards +10% XP and treats
  (`rebirth_mult = 1 + 0.1 * rebirths`).
- New Game+ content: one hidden Sam outfit collectible per city.
- Rebirth count shows as stars on the collar name tag.
