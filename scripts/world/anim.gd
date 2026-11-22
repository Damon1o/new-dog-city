extends RefCounted
## Procedural poses for the one-frame sprite actors (bosses, cats, raccoons, prey). No frames to
## swap, so every frame sets the sprite's position / rotation / scale from a few numbers. Nothing
## is tweened, so the hit-flash tweens on modulate never fight it.
##   walk    seconds spent moving (0 = standing): a hop and a waddle
##   windup  0..1: crouch low and tremble before an attack
##   strike  1 -> 0 over an attack: jump toward `dir` and stretch out, then settle back
##   dizzy   stunned: rock side to side
##   y       extra height (parachute drop, pigeon flight)

const REACH := 9.0  # strike lunge, px

static func pose(s: Node2D, base: Vector2, walk: float, windup := 0.0, strike := 0.0, dir := Vector2.ZERO,
		dizzy := false, y := 0.0) -> void:
	var k := sin(clampf(strike, 0.0, 1.0) * PI)  # 0 -> 1 -> 0 as strike runs down
	var hop := absf(sin(walk * 11.0)) * 3.0 if walk > 0.0 else 0.0
	var ms := Time.get_ticks_msec()  # not randf(): the global rng is seeded for tests and the city
	s.position = dir * REACH * k + Vector2(sin(ms * 0.11) * 1.5 * windup, y - hop)
	s.rotation = sin(walk * 11.0) * 0.07
	if dizzy:
		s.rotation = sin(ms / 70.0) * 0.18
	s.scale = base * Vector2(1.0 + 0.18 * windup + 0.22 * k, 1.0 - 0.2 * windup - 0.14 * k)
