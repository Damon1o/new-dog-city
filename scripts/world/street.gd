extends Node
## Per-frame street checks: manhole steam, landmark discovery (moved from game.gd).

var g: Node2D

func update_steam(delta: float) -> void:
	for m in g.manholes:
		m.t -= delta
		if m.t <= 0.0:
			m.on = not m.on
			m.steam.emitting = m.on
			m.t = 1.5 if m.on else randf_range(3.5, 8.0)
			if m.on and g.player.position.distance_to(m.pos) < 500.0:
				g.sfx("steam")
		if m.on and g.player.position.distance_to(m.pos) < 38.0:
			g.player.take_damage(delta * 30.0)
			g.shake_amt = maxf(g.shake_amt, 2.0)

func check_landmarks() -> void:
	for l in g.landmarks:
		if not l.seen and g.player.position.distance_to(l.pos) < 170.0:
			l.seen = true
			g.player.add_xp(50)
			g.show_msg("Discovered the %s!  +50 XP" % l.name)
			g.sfx("levelup")
			g.bump("sights")
