extends Node
## Prey and treat spawning and treat pickup (moved from game.gd).

const Spawns := preload("res://scripts/data/spawns.gd")

var g: Node2D
var flocks: Array[Dictionary] = []  # pigeon flocks, see spawn_flock

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
	var kind := Spawns.pick(g.city.id, g.sun())
	var pos = g.random_spot(350.0)
	if kind == "squirrel":  # squirrels live in g.parks
		var r: Rect2 = g.parks.pick_random()
		pos = r.position + Vector2(randf(), randf()) * r.size
	elif kind == "rat":  # rats by the trash
		var can: Vector2 = g.cans.pick_random()
		pos = can + Vector2(randf_range(-60, 60), randf_range(10, 50))
	var bonus := Spawns.NIGHT_LEVELS if Spawns.phase(g.sun()) == "night" else 0
	if pos.x < 0 or pos.distance_to(g.player.position) < 350.0:
		return
	if kind == "pigeon":
		spawn_flock(pos, bonus)
		return
	var prey: Node2D = g.PreyScript.new()
	prey.position = pos
	g.add_child(prey)
	prey.setup(kind, g.PREY[kind], g.tex[kind], g, bonus)

## Pigeon flock (spec 07): 5-12 birds round a center, a plain Dictionary the birds share.
func spawn_flock(center: Vector2, bonus := 0) -> Dictionary:
	var f := {"members": [], "center": center, "scatter": 0.0}
	for i in randi_range(5, 12):
		var prey: Node2D = g.PreyScript.new()
		prey.position = center + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		prey.flock = f
		g.add_child(prey)
		prey.setup("pigeon", g.PREY.pigeon, g.tex.pigeon, g, bonus)
		f.members.append(prey)
	flocks.append(f)
	return f

## The whole flock flees for 15-25 s, then regroups at a new center nearby.
func scatter(f: Dictionary) -> void:
	if f.scatter > 0.0:
		return
	f.scatter = randf_range(15.0, 25.0)
	g.sfx("pigeons_scatter")
	for p in f.members:
		g.bump("pigeons")  # Biscuit's "scatter 10 pigeons"

## Bark (spec 05): every flock with a bird inside the ring scatters.
func scatter_near(at: Vector2, radius: float) -> void:
	for f in flocks:
		if f.members.any(func(p): return is_instance_valid(p) and p.position.distance_to(at) < radius):
			scatter(f)

func _process(delta: float) -> void:
	for f in flocks.duplicate():
		f.members = f.members.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())
		if f.members.is_empty():
			flocks.erase(f)
		elif f.scatter > 0.0:
			f.scatter -= delta
			if f.scatter <= 0.0:
				f.center = regroup_spot(f.center)

## A sidewalk spot 150-400 px from c (not road, not inside a building); c if none found.
func regroup_spot(c: Vector2) -> Vector2:
	for attempt in 20:
		var p := c + Vector2.from_angle(randf() * TAU) * randf_range(150.0, 400.0)
		if not g.blocked(p) and not g.city.on_road(p) and Rect2(Vector2.ZERO, g.WORLD).grow(-48).has_point(p):
			return p
	return c

func check_pickups() -> void:
	for s in g.treat_sprites:
		if g.player.position.distance_to(s.position) < 26.0:
			g.player.treats += 1
			g.float_text(s.position, "+1 treat", Color(1, 0.85, 0.5))
			g.sfx("pickup")
			g.treat_sprites.erase(s)
			s.queue_free()
			return  # one per frame; list was mutated
