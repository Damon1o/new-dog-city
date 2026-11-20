extends Node
## City building: ground, blocks, props, street doors (moved from game.gd).

var g: Node2D

const CITIES := preload("res://scripts/data/cities.gd").CITIES
const OLD := Vector2i(6, 5)  # the pre-M2-1 map, kept block for block as the top-left corner
const PERF_EVERY := 300  # frames per frame-time log line

var perf_n := 0
var perf_sum := 0.0
var perf_max := 0.0
var perf_last := 0
var id := ""     # current city, a key of CITIES
var root: Node2D  # the current city's nodes; freed and rebuilt on travel

## Free the current city and build `city_id` from data/cities.gd (seeded, so the same layout every time).
func build(city_id: String) -> void:
	var seen: Array = g.landmarks.filter(func(l): return l.seen).map(func(l): return l.name)
	if root:
		root.free()
	for list: Array in [g.building_rects, g.parks, g.trees, g.cans, g.water_spots, g.bodega_doors, g.doors, g.stations, g.landmarks, g.manholes]:
		list.clear()
	id = city_id
	root = Node2D.new()
	root.name = "City"
	root.y_sort_enabled = true
	g.add_child(root)
	seed(CITIES[id].seed)
	build_bounds()
	build_blocks()
	place_manholes()
	for l in g.landmarks:
		l.seen = l.name in seen
	g.ground.queue_redraw()

## Swap cities behind a fade (spec 02: only the current city is in the tree).
func travel(city_id: String) -> void:
	g.player.frozen = true
	var tw := g.create_tween()
	tw.tween_property(g.fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		build(city_id)
		randomize()
		g.player.position = fix_pos(g.player.position)
		g.cam.reset_smoothing())
	tw.tween_property(g.fade, "color:a", 0.0, 0.3)
	tw.tween_callback(func(): g.player.frozen = false)

## Street nodes go under the city root; interiors (built before the first city) stay on game.
func holder() -> Node:
	return root if root else g

## Seeded fill: the old 6 x 5 blocks first, in their old order, so they consume the same
## random numbers as before and come out identical. New blocks come after.
func build_blocks() -> void:
	for by in OLD.y:
		for bx in OLD.x:
			g.build_block(Vector2i(bx, by))
	for by in g.NY:
		for bx in g.NX:
			if bx >= OLD.x or by >= OLD.y:
				g.build_block(Vector2i(bx, by))

func on_road(p: Vector2) -> bool:
	var step: Vector2 = g.BLOCK + Vector2(g.ROAD, g.ROAD)
	return Rect2(Vector2.ZERO, g.WORLD).has_point(p) and (fmod(p.x, step.x) < g.ROAD or fmod(p.y, step.y) < g.ROAD)

## Closest point on a road centre line (the dog fits there, buildings never do).
func nearest_road(p: Vector2) -> Vector2:
	var step: Vector2 = g.BLOCK + Vector2(g.ROAD, g.ROAD)
	var q := p.clamp(Vector2(g.ROAD / 2, g.ROAD / 2), g.WORLD - Vector2(g.ROAD / 2, g.ROAD / 2))
	var vx: float = round((q.x - g.ROAD / 2) / step.x) * step.x + g.ROAD / 2  # nearest vertical road
	var hy: float = round((q.y - g.ROAD / 2) / step.y) * step.y + g.ROAD / 2  # nearest horizontal road
	return Vector2(vx, q.y) if absf(vx - q.x) <= absf(hy - q.y) else Vector2(q.x, hy)

## Off the map or inside something solid: an old save from a changed layout.
func blocked(p: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, g.WORLD).grow(-24).has_point(p):
		return true
	for r: Rect2 in g.building_rects:
		if r.grow(16).has_point(p):
			return true
	for list: Array in [g.trees, g.cans, g.water_spots]:
		for t: Vector2 in list:
			if t.distance_to(p) < 24.0:
				return true
	for park: Rect2 in g.parks:  # fountain
		if (park.position + g.BLOCK / 2.0).distance_to(p) < 60.0:
			return true
	return false

## Saved street position -> where the dog may stand now.
func fix_pos(p: Vector2) -> Vector2:
	return nearest_road(p) if blocked(p) else p

## Frame-time log for the bigger map (spec 02: cull far blocks if web passes 8 ms).
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if perf_last > 0:
		var ms := (now - perf_last) / 1000.0
		perf_sum += ms
		perf_max = maxf(perf_max, ms)
		perf_n += 1
		if perf_n >= PERF_EVERY:
			print("[perf] frame %.2f ms avg, %.2f ms max, process %.2f ms, %d nodes (%d x %d blocks)" % [
				perf_sum / perf_n, perf_max, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), g.NX, g.NY])
			perf_n = 0
			perf_sum = 0.0
			perf_max = 0.0
	perf_last = now

func block_origin(b: Vector2i) -> Vector2:
	return Vector2(g.ROAD + b.x * (g.BLOCK.x + g.ROAD), g.ROAD + b.y * (g.BLOCK.y + g.ROAD))

func draw_ground() -> void:
	g.ground.draw_texture_rect(g.tex.sidewalk, Rect2(Vector2.ZERO, g.WORLD), true)
	var step = g.BLOCK + Vector2(g.ROAD, g.ROAD)
	var yellow := Color(0.82, 0.7, 0.24)
	for i in g.NX + 1:
		g.ground.draw_texture_rect(g.tex.road, Rect2(i * step.x, 0, g.ROAD, g.WORLD.y), true)
	for j in g.NY + 1:
		g.ground.draw_texture_rect(g.tex.road, Rect2(0, j * step.y, g.WORLD.x, g.ROAD), true)
	for i in g.NX + 1:  # lane dashes, skipping intersections
		for j in g.NY:
			for k in int(g.BLOCK.y / 32):
				g.ground.draw_rect(Rect2(i * step.x + 62, g.ROAD + j * step.y + k * 32 + 6, 4, 20), yellow)
	for j in g.NY + 1:
		for i in g.NX:
			for k in int(g.BLOCK.x / 32):
				g.ground.draw_rect(Rect2(g.ROAD + i * step.x + k * 32 + 6, j * step.y + 62, 20, 4), yellow)
	for p in g.parks:
		g.ground.draw_texture_rect(g.tex.grass, p.grow(-8), true)
	g.ground.draw_circle(g.burrow, 30.0, Color(0.35, 0.25, 0.15))
	g.ground.draw_circle(g.burrow, 22.0, Color(0.05, 0.04, 0.03))

func build_bounds() -> void:
	for wall in [[Vector2(g.WORLD.x / 2, -16), Vector2(g.WORLD.x, 32)], [Vector2(g.WORLD.x / 2, g.WORLD.y + 16), Vector2(g.WORLD.x, 32)],
			[Vector2(-16, g.WORLD.y / 2), Vector2(32, g.WORLD.y)], [Vector2(g.WORLD.x + 16, g.WORLD.y / 2), Vector2(32, g.WORLD.y)]]:
		add_static_box(wall[0], wall[1])

func add_static_box(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	holder().add_child(body)

## Sprite anchored at its base so y-sort lets the dog walk behind it.
func add_prop(t: Texture2D, base: Vector2, scl: float, tint := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.scale = Vector2(scl, scl)
	s.offset = Vector2(0, -t.get_height() / 2.0)
	s.position = base
	s.modulate = tint
	holder().add_child(s)
	return s

## foot = fraction of sprite height that is solid footprint (rest is walk-behind).
func add_building(t: Texture2D, base: Vector2, scl: float, foot: float, tint := Color.WHITE) -> void:
	add_prop(t, base, scl, tint)
	var size := t.get_size() * scl
	var foot_size := Vector2(size.x, size.y * foot)
	add_static_box(base - Vector2(0, foot_size.y / 2.0), foot_size)
	g.building_rects.append(Rect2(base - Vector2(size.x / 2.0, foot_size.y), foot_size))

func add_tree(pos: Vector2) -> void:
	add_prop(g.tex.tree, pos, 2.5)
	add_static_box(pos - Vector2(0, 5), Vector2(14, 10))
	g.trees.append(pos)

func add_can(pos: Vector2) -> void:
	add_prop(g.tex.trashcan, pos, 2.0)
	add_static_box(pos - Vector2(0, 6), Vector2(20, 12))
	g.cans.append(pos)
	var rac: Node2D = g.RaccoonScript.new()
	holder().add_child(rac)
	rac.setup(pos + Vector2(0, 2), g.tex.raccoon, g)

## Street door (spec 03). id "<city>:<bx>,<by>:<slot>" is stable, so per-room state can be saved.
func add_door(pos: Vector2, template: String, b: Vector2i, slot: int, floors := 1, door_name := "") -> Dictionary:
	var id := "%s:%d,%d:%d" % [g.save_extra.get("world/city", "nyc"), b.x, b.y, slot]
	if floors == 1 and template in ["apartment", "office"]:  # 2-4 floors, hashed so the seeded layout is untouched
		floors = 2 + absi(hash(id)) % 3
	var d := {"pos": pos, "template": template, "id": id, "seed": hash(id), "floors": floors, "name": door_name}
	g.doors.append(d)
	return d

func build_block(b: Vector2i) -> void:
	var o := block_origin(b)
	var c = o + g.BLOCK / 2.0
	if b in g.PARKS:
		g.parks.append(Rect2(o, g.BLOCK))
		if Rect2(o, g.BLOCK).has_point(g.burrow):
			add_door(g.burrow, "burrow", b, 0)
		add_prop(g.tex.fountain, c, 2.5)
		add_static_box(c - Vector2(0, 20), Vector2(90, 36))
		g.water_spots.append(c + Vector2(0, 6))
		for i in 8:
			var p := o + Vector2(randf_range(40, 472), randf_range(70, 364))
			if p.distance_to(c) > 110.0:
				add_tree(p)
	elif g.LANDMARKS.has(b):
		var base := o + Vector2(256, 372)
		add_building(g.tex[g.LANDMARKS[b][0]], base, 2.5, 0.45)
		g.landmarks.append({"pos": base, "name": g.LANDMARKS[b][1], "seen": false})
		add_door(base + Vector2(0, 18), "office", b, 0, 6, g.LANDMARKS[b][1])
		add_tree(o + Vector2(60, 360))
		add_tree(o + Vector2(452, 360))
	elif b in g.BODEGAS:
		var base := o + Vector2(256, 240)
		add_building(g.tex.bodega, base, 2.0, 0.6)
		g.bodega_doors.append(base + Vector2(54, 24))
		add_door(base + Vector2(54, 24), "bodega", b, 0)
		add_prop(g.tex.water_bowl, base + Vector2(-70, 34), 2.5)
		g.water_spots.append(base + Vector2(-70, 30))
		add_can(o + Vector2(450, 250))
		add_tree(o + Vector2(60, 340))
	else:
		for i in 3:
			if randf() < 0.85:
				var kind: String = ["building_a", "building_b", "building_c"].pick_random()
				add_building(g.tex[kind], o + Vector2(96 + i * 160, 236), 1.5, 0.6,
					Color.from_hsv(randf(), 0.15, randf_range(0.8, 1.0)))
				add_door(o + Vector2(96 + i * 160, 256), g.Rooms.BY_BUILDING[kind], b, i)
		add_can(o + Vector2(randf_range(40, 170), randf_range(285, 360)))
		if randf() < 0.5:
			add_can(o + Vector2(randf_range(340, 470), randf_range(285, 360)))
		if g.STATIONS.has(b):
			var pos := o + Vector2(256, 340)
			add_prop(g.tex.subway, pos, 1.5)
			g.stations.append({"pos": pos, "name": g.STATIONS[b], "door": add_door(pos, "subway", b, 3, 1, g.STATIONS[b])})
		elif randf() < 0.5:
			add_prop(g.tex.hydrant, o + Vector2(256, 300), 2.0)
			g.water_spots.append(o + Vector2(256, 300))
		else:
			add_tree(o + Vector2(256, 330))

func place_manholes() -> void:
	var step = g.BLOCK + Vector2(g.ROAD, g.ROAD)
	for i in range(1, g.NX):
		for j in g.NY:
			if randf() < 0.4:
				add_manhole(Vector2(i * step.x + 64, g.ROAD + j * step.y + g.BLOCK.y / 2))
	for j in range(1, g.NY):
		for i in g.NX:
			if randf() < 0.25:
				add_manhole(Vector2(g.ROAD + i * step.x + g.BLOCK.x / 2, j * step.y + 64))

func add_manhole(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = g.tex.manhole
	s.position = pos
	s.scale = Vector2(1.5, 1.5)
	s.z_index = -5
	holder().add_child(s)
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 5
	p.emitting = false
	p.amount = 40
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 18.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = Color(1, 1, 1, 0.55)
	holder().add_child(p)
	g.manholes.append({"pos": pos, "steam": p, "t": randf_range(2.0, 7.0), "on": false})
