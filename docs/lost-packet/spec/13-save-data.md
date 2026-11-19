# 13 Save data (schema v2)

## Today

`save_game()` writes a `ConfigFile` at `save_path` (`user://save.cfg`):
section `dog` with every key in `SAVE_KEYS` (level, xp, treats, skin, purina,
water, collar, hunger, thirst, points, stat_hp, stat_atk, stat_spd), `world/seen`,
`ui/volume`, `quests/stats`, `quests/step`. `load_game()` reads each with a
default, and already migrates older saves (missing `points`).

## v2: keep ConfigFile, add sections

Same file, same pattern: every read has a default, so v1 saves load as-is.

| Section / key | Type | Example (synthetic) | Notes |
|---------------|------|---------------------|-------|
| meta/version | int | 2 | missing = 1 |
| meta/rebirths | int | 0 | |
| meta/true_ending | bool | false | |
| dog/* | as today | | plus `bones` (int), `buffs` (Dictionary id -> seconds left) |
| world/city | String | "nyc" | current city id |
| world/pos | Vector2 | Vector2(1200, 800) | street position; inside a room, the door position |
| world/tod | float | 0.42 | time of day |
| world/day | int | 12 | in-game day counter (markers, daily limits) |
| world/weather | Dictionary | {"nyc": "snow"} | per-city weather for the current day |
| world/seen | Array | as today | |
| story/flags | Array[String] | ["ch1_boss", "fb_nyc_1"] | every story flag |
| story/items | Array[String] | ["lanyard", "sticker"] | Sam's items |
| story/keycards | Array[String] | ["nyc"] | |
| story/floors | Dictionary | {"nyc_1": 41.5} | cleared floor -> best time |
| cats/points | Dictionary | {"nyc_mango": 23} | friendship points (hearts = points / 10) |
| cats/today | Dictionary | {"nyc_mango": [12, 2, true]} | [day, gifts, talked] for daily limits |
| territory/markers | Array[Dictionary] | [{"city": "nyc", "pos": Vector2(300, 500), "day": 12}] | |
| territory/rep | Dictionary | {"nyc": 64} | |
| wardrobe/owned | Array[String] | ["hat_beanie"] | |
| wardrobe/equipped | Dictionary | {"skin": 0, "collar": "name", "hat": "", "overlay": ""} | `skin` stays mirrored in `dog/skin` for v1 compatibility |
| stocks/prices | Dictionary | {"KIBL": 21.3} | |
| stocks/history | Dictionary | {"KIBL": [20.0, 20.4]} | last 60 points |
| stocks/held | Dictionary | {"KIBL": 10} | |
| quests/* | as today | | new stats are new keys in the same dict |
| ui/* | | | add `vol_music`, `vol_sfx`, `vol_amb`, `reduce_motion`; keep `volume` as Master |

Not saved: wanted heat (always 0 on load), enemy positions, Pocket's
location (re-rolled per day), progress inside an unfinished puzzle floor.

## Rules

- Save on: level up (existing), shop purchase, floor clear, boss win, city
  travel, quit, and every 60 s of play.
- Inside a room, save the door position so a load always starts on the street.
- Load fix-up: if `world/pos` is inside a collider (bigger map changed the
  layout), move to the nearest road point.
- One save slot, as today. Rebirth rewrites the same file.
- Self-check in `tests/smoke.gd`: write a v1-shaped file, load it, assert no
  errors and defaults filled; then round-trip a fully filled v2 save and
  compare every key.
