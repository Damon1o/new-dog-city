extends RefCounted
## Prey spawn tables per city and day phase (spec 02 Day/night). Weights, not percents.
## Foe kinds (scripts/enemies/cat.gd TYPES, "rats" = a swarm of 5) go to spawner.spawn_foe.
## ponytail: raccoons x2 at night still pending; sphynx waits for a tokyo / shenzhen table.

const SPAWNS := {
	"nyc": {
		"day": {"pigeon": 0.45, "squirrel": 0.3, "rat": 0.25, "tabby": 0.05, "calico": 0.04, "tom": 0.03, "rats": 0.03},
		"dusk": {"pigeon": 0.25, "squirrel": 0.3, "rat": 0.45, "tabby": 0.05, "calico": 0.04, "tom": 0.03, "rats": 0.03},
		"night": {"squirrel": 0.25, "rat": 0.75, "tabby": 0.04, "calico": 0.03, "tom": 0.03, "black": 0.05, "possum": 0.05,
			"rats": 0.06},  # rats x2-ish, pigeons roost, black cats and possums out
	},
}
const NIGHT_LEVELS := 2
const OLD_AREA := 6 * 5  # blocks in the pre-M2-1 map, where MAX_PREY was tuned

static func phase(sun: float) -> String:
	return "day" if sun >= 0.6 else ("dusk" if sun >= 0.3 else "night")

static func pick(city: String, sun: float) -> String:
	var table: Dictionary = SPAWNS.get(city, SPAWNS.nyc)[phase(sun)]
	var roll: float = randf() * table.values().reduce(func(a, b): return a + b)
	for kind in table:
		roll -= table[kind]
		if roll <= 0.0:
			return kind
	return table.keys()[-1]

static func cap(base: int, grid: Vector2i) -> int:
	return base * grid.x * grid.y / OLD_AREA
