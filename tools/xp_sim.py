"""XP pacing simulator (plan task M1-6, spec 10 "Pacing targets").

Run: python tools/xp_sim.py [--kpm N]
Prints simulated play time per level milestone next to the spec table and
exits 1 if any row is off by more than 25%.

Formulas mirror the spec (stdlib only, no game code):
  xp_needed(L)  = 15 + 6 L                        (10-progression.md)
  enemy xp      = base_xp * (1 + 0.10 (lvl - 1))  (06-enemies-bosses.md)
  low enemy     = enemy.level <= L - 5 -> 50% XP
  catch-up      = L < city HQ level - 10 -> all XP +25%
  quest share   = quests/boss/puzzles cover 40% of each band's XP

Assumptions (the spec does not give these):
  - Byte fights enemies at his own level (clamped to the city band), so the
    low-enemy rule never fires on the intended path. The +-2 spawn jitter
    averages out because XP is linear in level.
  - Base XP is the mean of the common enemy table.
  - KPM is "kills per minute of play time", i.e. it already folds in travel,
    shopping, story and the time quests take. Quest XP only shrinks how much
    enemy XP each level needs.
"""

import argparse
import sys

TOLERANCE = 0.25

# (level, hours) from spec 10 pacing table.
TARGETS = [(20, 1.5), (40, 3.5), (60, 6.0), (80, 9.0), (100, 12.0)]

# City bands: (name, first player level spent there, HQ level, enemy band).
# The Tower is the NYC HQ's sealed top floors, needing level 100.
CITIES = [
    ("NYC", 1, 20, (1, 20)),
    ("SF", 20, 40, (20, 40)),
    ("Tokyo", 40, 60, (40, 60)),
    ("Shenzhen", 60, 80, (60, 80)),
    ("Tower", 80, 100, (80, 100)),
]

# Base XP from the common enemy table (rat swarm = 5 rats x 4).
BASE_XP_TABLE = {
    "tabby": 12, "alley_tom": 20, "sphynx": 18, "calico": 16, "black_cat": 25,
    "rat_swarm": 20, "possum": 15, "rival_dog": 40, "seagull": 12, "drone": 20,
}
BASE_XP = sum(BASE_XP_TABLE.values()) / len(BASE_XP_TABLE)

QUEST_SHARE = 0.40
DEFAULT_KPM = 0.20  # free parameter; see module docstring


def xp_needed(level):
    return 15 + level * 6


def city_for(level):
    for c in reversed(CITIES):
        if level >= c[1]:
            return c
    return CITIES[0]


def enemy_xp(enemy_level, player_level, hq_level):
    xp = BASE_XP * (1 + 0.10 * (enemy_level - 1))
    if enemy_level <= player_level - 5:
        xp *= 0.5
    if player_level < hq_level - 10:
        xp *= 1.25
    return xp


def simulate(kpm):
    """Return {level: minutes} for reaching each level from level 1."""
    minutes, out = 0.0, {1: 0.0}
    for level in range(1, 100):
        _, _, hq, (lo, hi) = city_for(level)
        e_level = min(max(level, lo), hi)
        enemy_part = xp_needed(level) * (1 - QUEST_SHARE)
        minutes += enemy_part / (kpm * enemy_xp(e_level, level, hq))
        out[level + 1] = minutes
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--kpm", type=float, default=DEFAULT_KPM,
                    help="effective kills per minute of play (default %(default)s)")
    args = ap.parse_args()

    total = sum(xp_needed(l) for l in range(1, 100))
    assert total == 31185, total

    times = simulate(args.kpm)
    print(f"xp_needed(1..99) = {total}  base_xp = {BASE_XP:.1f}  kpm = {args.kpm}")
    print(f"{'Level':>5} {'Target h':>9} {'Sim h':>7} {'Diff':>7}  Result")
    worst, failed = 0.0, False
    for level, target in TARGETS:
        sim = times[level] / 60
        diff = (sim - target) / target
        ok = abs(diff) <= TOLERANCE
        failed |= not ok
        worst = max(worst, abs(diff))
        print(f"{level:>5} {target:>9.1f} {sim:>7.2f} {diff:>+7.1%}  {'ok' if ok else 'FAIL'}")

    # Rate that lands level 100 exactly on 12 h, for reference.
    fit = args.kpm * times[100] / 60 / TARGETS[-1][1]
    print(f"worst row {worst:.1%} (limit {TOLERANCE:.0%}); "
          f"kpm for exactly 12 h at 100: {fit:.3f} "
          f"(1 kill per {60 / fit:.0f} s of play)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
