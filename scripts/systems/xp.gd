extends RefCounted
## XP rules (spec/10-progression.md): curve, stat points, low-enemy and catch-up multipliers.

# ponytail: HQ levels inline until the M2 city table lands; read it from there then.
const HQ_LEVEL := {"nyc": 20, "sf": 40, "tokyo": 60, "shenzhen": 80, "tower": 100}

static func needed(level: int) -> int:
	return 15 + level * 6

## Stat points earned on reaching `level`: one, plus a bonus every 10 levels.
static func points_for(level: int) -> int:
	return 2 if level % 10 == 0 else 1

## XP after rules. `src` is the enemy/prey the XP came from (null for quests, sights).
static func scaled(amount: int, player_level: int, hq_level: int, src: Object = null) -> int:
	var mult := 1.0
	if src != null:
		var lv: Variant = src.get("level")
		var enemy_level: int = 1 if lv == null else int(lv)
		if enemy_level <= player_level - 5:
			mult *= 0.5
	if player_level < hq_level - 10:
		mult *= 1.25
	return roundi(amount * mult)

## Grant XP to g.player with every rule applied; returns what was granted.
static func award(g: Node, amount: int, src: Object = null) -> int:
	var city := str(g.save_extra.get("world/city", "nyc"))
	var got := scaled(amount, g.player.level, int(HQ_LEVEL.get(city, 20)), src)
	g.player.add_xp(got)
	return got
