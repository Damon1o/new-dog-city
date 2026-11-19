# 06 Enemies and bosses

## Today

- `raccoon.gd`: trash-can ambusher, draws its own HP bar in `_draw()`.
- `boss.gd`: park bosses from `BOSSES` in `game.gd` (King of Raccoons,
  Pigeon Queen, Rat Meister). Generic: `cfg.specials` cycles through named
  specials (`charge`, `slam`, `feathers`, `storm`, `rats`, `burrow`),
  projectiles via `shoot(vel, homing, life)`.
- `hedgehog.gd`: Boss Hedgehog, 3 waves, in the burrow room.

New bosses reuse `boss.gd`: add new special names to its `special()` match,
and add a `phases` list to the config (below). No second boss framework.

## Enemy levels

- Every hostile (raccoon, cat, rat swarm, rival dog, drone, boss) has `level`.
- Spawn level: `clamp(band_min + (band_max - band_min) * district_t + randi_range(-2, 2), 1, 100)`
  where `district_t` is 0 near the city's airport and 1 at the far corner,
  so difficulty grows across a city. Night +2. Claimed block -1.
- Stats from level, applied once at spawn:
  - `hp = base_hp * (1 + 0.15 * (level - 1))`
  - `dmg = base_dmg * (1 + 0.08 * (level - 1))`
  - `xp = base_xp * (1 + 0.10 * (level - 1))`; treats use the same multiplier.
- One helper `scale_for_level(cfg, level) -> Dictionary` in `systems/levels.gd`;
  every enemy's `setup()` calls it.
- Level-gap rule (also used by bark): if `enemy.level <= player.level - 5`
  the enemy is "low". Low enemies give 50% XP.

## Overhead UI (damage numbers, level tags, health)

- One reusable `EnemyTag` node (`scripts/ui/enemy_tag.gd`) added as a child
  of each hostile: name + "Lv 23" label and HP bar (38 x 6 px, the existing
  raccoon style). Shown when damaged or within 260 px; hidden after 3 s
  without damage.
- Level tag color vs player: grey (5+ below), white (within 4), orange
  (5-9 above), red (10+ above).
- Damage numbers: reuse `float_text()` in `game.gd`. White normal, yellow crit
  (bigger, with "!"), red for damage to Byte, green for heals. Rise 30 px,
  fade 0.7 s, random x jitter so stacks don't overlap.
- Bosses: no overhead tag. They use the existing HUD boss bar (top center)
  with name, level and phase pips.
- Raccoon's own `_draw()` bar is replaced by `EnemyTag`.

## Common enemy list

| Enemy | Where | Base hp / dmg / xp | Behavior |
|-------|-------|--------------------|----------|
| Raccoon | all, more at night | existing | existing ambush |
| Tabby cat | all | 40 / 6 / 12 | Circles, swipes, retreats |
| Alley tom | NYC, SF | 80 / 10 / 20 | Slow, tanky, knockback swipe |
| Sphynx | Tokyo, Shenzhen | 35 / 8 / 18 | Fast dash-swipes |
| Calico | all | 45 / 7 / 16 | Dodges the first bite in each fight |
| Black cat | all, night only | 50 / 12 / 25 | Invisible until within 120 px, crits |
| Rat swarm | all, night x2 | 5 rats x 8 / 3 / 4 | Swarm, weak alone |
| Possum | night | 60 / 5 / 15 | Plays dead at 25% HP for 3 s, then bites |
| Rival dog | night, claimed blocks | 120 / 12 / 40 | Erases a territory marker if not beaten |
| Seagull | SF | 30 / 6 / 12 | Dive attack, steals 1-3 treats on hit |
| Security drone | Tower, near Shenzhen HQ | 50 / 8 / 20 | Chases, 1 s stun zap |
| Animal control officer | all | not damageable | See `08-wanted-pound.md` |

Each cat type has its own hiss/yowl SFX variant (`12-audio.md`).

## Bosses

Boss config adds `level`, `arena` (room template) and `phases`:
`[{at: 1.0, specials: [...], speed_mult}, {at: 0.6, ...}, {at: 0.3, ...}]`.
When HP falls below a phase's `at`, the boss switches special list, flashes and
roars. Every telegraphed attack shows a warning shape 0.6-1.0 s first.

### NYC: "Fat Cat" banker (level 20, NYSE floor)

| Phase | Specials |
|-------|----------|
| 1 (100%) | `coin_fan`: 7 gold coins in a 60-degree fan. `briefcase_charge`: existing `charge` with a briefcase sprite. |
| 2 (60%) | `margin_call`: summons 3 security cats (level 18). `ticker_wave`: a line of stock-ticker letters sweeps the floor; dash through it. |
| 3 (30%) | `golden_parachute`: jumps off screen, shadow marks the landing, then `slam` + shockwave ring. |

Drops: NYC keycard, 5 bones, 300 treats, flag `ch1_boss`.

### SF: Seagull King (level 40, pier)

| Phase | Specials |
|-------|----------|
| 1 | `dive_bomb`: shadow-line telegraph, then a fast dive along it. `fish_rain`: 8 fish fall on marked circles. |
| 2 (60%) | `gust`: pushes Byte 200 px toward the pier edge (falling in = 15 damage, respawn on the pier). Fog rolls in; King hidden except his shadow. |
| 3 (30%) | `flock_call`: 6 seagulls (level 38) plus `dive_bomb` twice in a row. |

Drops: Sam's backpack, SF keycard, 8 bones, sailor hat, flag `ch2_boss`.

### Tokyo: Claw King (level 60, arcade)

| Phase | Specials |
|-------|----------|
| 1 | `claw_grab`: claw shadow follows Byte 1.5 s then drops; caught = 2 s stuck + damage unless Byte mashes C to break out. `capsule_toss`: 5 prize capsules burst after 1 s. |
| 2 (60%) | `neon_floor`: floor tiles light in a pattern then shock; in rain the pattern is wider. |
| 3 (30%) | `jackpot`: two claw grabs per cycle; capsules home in slowly. |

Drops: Tokyo keycard, 10 bones, flag `ch3_boss`.

### Shenzhen: Mecha-Cat (level 80, rooftop)

| Phase | Specials |
|-------|----------|
| 1 | `laser_sweep`: rotating beam over 270 degrees; dash through its gap. `missile_lock`: 4 reticles track Byte, lock, missiles land. |
| 2 (60%) | `emp`: disables dash for 3 s. `drone_swarm`: 4 drones (level 78). |
| 3 (30%) | Armor falls off, core exposed (damage taken x1.5). All specials with cooldowns x0.7. |

Drops: Shenzhen keycard, 12 bones, shipping label (story item), flag `ch4_boss`.

### Secret final boss: Null Cat (level 100, Tower roof)

| Phase | Specials |
|-------|----------|
| 1a (100%) | Fat Cat moves: `coin_fan`, `golden_parachute` |
| 1b (80%) | Seagull King moves: `dive_bomb`, `gust` |
| 1c (60%) | Claw King moves: `claw_grab`, `neon_floor` |
| 1d (40%) | Mecha-Cat moves: `laser_sweep`, `missile_lock` |
| 2 (20%) | Own moves. `corrupt`: arena tiles glitch and deal damage over time. `invert`: controls inverted 3 s (HUD warning icon). `null_clone`: 2 copies of Byte that mirror his inputs. `stack_overflow`: projectiles pile from the top of the screen, faster and faster, until Byte lands a hit. |

`cs_nullcat_phase2` plays at 20%. Drops: Null crown, 25 bones. Then the reunion.

### Existing NYC mini-bosses

King of Raccoons, Pigeon Queen, Rat Meister and Boss Hedgehog stay as NYC side
content, now at levels 6, 8, 10 and 15. Boss Hedgehog's 10-level loss on
defeat (`BOSS_LEVEL_LOSS`) is removed: with level gates it is too harsh.
New penalty: lose carried treats above 20.
