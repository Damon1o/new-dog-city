extends RefCounted
## Enemy levels (spec 06 "Enemy levels"). Stats scale once, at spawn.

const NYC_BAND := Vector2i(1, 20)

## Copy of cfg with hp/dmg/xp/treats scaled to level; other keys pass through.
static func scale_for_level(cfg: Dictionary, level: int) -> Dictionary:
	var out := cfg.duplicate()
	var l := float(level - 1)
	out.level = level
	if cfg.has("hp"):
		out.hp = float(cfg.hp) * (1.0 + 0.15 * l)
	if cfg.has("dmg"):
		out.dmg = float(cfg.dmg) * (1.0 + 0.08 * l)
	if cfg.has("xp"):
		out.xp = roundi(float(cfg.xp) * (1.0 + 0.10 * l))
	if cfg.has("treats"):
		out.treats = roundi(float(cfg.treats) * (1.0 + 0.10 * l))
	return out

## district_t: 0 near the city's airport, 1 at the far corner.
static func spawn_level(band: Vector2i, district_t: float) -> int:
	return clampi(roundi(band.x + (band.y - band.x) * clampf(district_t, 0.0, 1.0)) + randi_range(-2, 2), 1, 100)

## ponytail: no airport or city table yet, so the world origin stands in for the airport; read both from data/cities.gd once M2-2 lands.
static func level_at(pos: Vector2, world: Vector2) -> int:
	return spawn_level(NYC_BAND, pos.length() / world.length())
