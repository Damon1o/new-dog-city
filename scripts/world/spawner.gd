extends Node
## Prey and treat spawning and treat pickup (moved from game.gd).

var g: Node2D

func spawn_treat() -> void:
	var p = g.random_spot(200.0)
	if p.x < 0:
		return
	var s := Sprite2D.new()
	s.texture = g.tex.treat
	s.position = p
	s.scale = Vector2(2, 2)
	g.add_child(s)
	g.treat_sprites.append(s)

func spawn_prey() -> void:
	var kind := "pigeon"
	var pos = g.random_spot(350.0)
	var roll := randf()
	if roll < 0.3:  # squirrels live in g.parks
		kind = "squirrel"
		var r: Rect2 = g.parks.pick_random()
		pos = r.position + Vector2(randf(), randf()) * r.size
	elif roll < (0.75 if g.sun() < 0.3 else 0.55):  # rats by the trash, more at g.night
		kind = "rat"
		var can: Vector2 = g.cans.pick_random()
		pos = can + Vector2(randf_range(-60, 60), randf_range(10, 50))
	if pos.x < 0 or pos.distance_to(g.player.position) < 350.0:
		return
	for i in (3 if kind == "pigeon" else 1):  # pigeons flock
		var prey: Node2D = g.PreyScript.new()
		prey.position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)) * float(i > 0)
		g.add_child(prey)
		prey.setup(kind, g.PREY[kind], g.tex[kind], g)

func check_pickups() -> void:
	for s in g.treat_sprites:
		if g.player.position.distance_to(s.position) < 26.0:
			g.player.treats += 1
			g.float_text(s.position, "+1 treat", Color(1, 0.85, 0.5))
			g.sfx("pickup")
			g.treat_sprites.erase(s)
			s.queue_free()
			return  # one per frame; list was mutated
