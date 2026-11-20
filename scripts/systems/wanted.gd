extends Node
## Wanted level (spec 08): hidden heat 0-125, stars = heat / 25. Other systems call
## g.wanted.add_heat(n, reason) (territory pee +10, pizza steal +25 ...). Staffs animal
## control: officers on foot (scripts/enemies/officer.gd), vans (car.gd) at 3+ stars that
## drop one more, net guns at 4+, a drone light at 5. Owns its HUD bits too: the stars
## (top right, left of the minimap) and the red edge warning toward a close officer.
## Not saved (spec 13: heat is 0 on load).

signal stars_changed(n: int)

const Officer := preload("res://scripts/enemies/officer.gd")
const MAX_HEAT := 125.0
const DECAY_AFTER := 10.0  # s unseen before heat drops
const DECAY := 2.0         # heat / s
const SIGHT := 450.0       # an officer this close sees the dog
const WHISTLE := 400.0
const NEAR_BARK := 300.0

var g: Node2D
var heat := 0.0
var unseen := 0.0   # s since an officer (or the drone) last saw the dog
var root_t := 0.0   # net root left
var flash_t := 0.0  # stars flash after a gain (off with reduce motion)
var warn_t := 0.0   # edge flash after a whistle
var warn_at := Vector2.ZERO  # officer that whistled, world pos
var caught_n := 0
var last_bark := 0.0
var staff_t := 0.0
var drone: Node2D
var stars_ui: Control
var edge: Control

func stars() -> int:
	return int(heat / 25.0)

func add_heat(n: float, _reason := "") -> void:
	var was := stars()
	heat = clampf(heat + n, 0.0, MAX_HEAT)
	if n > 0.0:
		unseen = 0.0  # a fresh crime counts as seen
	if stars() != was:
		if stars() > was and not reduce_motion():
			flash_t = 0.8
		stars_changed.emit(stars())

func clear() -> void:
	add_heat(-heat)
	unseen = 0.0
	if root_t > 0.0:
		g.player.frozen = false
	root_t = 0.0
	for n in officers() + vans():
		n.queue_free()
	if drone:
		drone.queue_free()
		drone = null

func reduce_motion() -> bool:
	return g.save_extra.get("ui/reduce_motion", false)

func officers() -> Array:
	return get_tree().get_nodes_in_group("officer").filter(func(o): return not o.is_queued_for_deletion())

func vans() -> Array:
	return get_tree().get_nodes_in_group("van").filter(func(o): return not o.is_queued_for_deletion())

## Net hit: the dog can't move for `t` s.
## A dog already frozen by a menu stays untouched, so the net never unfreezes it under a menu.
func root(t: float) -> void:
	if g.player.frozen and root_t <= 0.0:
		return
	root_t = t
	g.player.frozen = true

## Spec 08 getting caught: the pound cell (scripts/world/pound.gd), heat 0, treats and XP kept.
func caught() -> void:
	caught_n += 1
	g.pound.jail(stars())
	clear()

## Spec 08: HP 0 at 1+ stars is a catch, not a death (player.die keeps the treats then).
func jails_on_death() -> bool:
	return stars() > 0 and g.inside != "boss"

func _process(delta: float) -> void:
	if not stars_ui:
		build_hud()  # g.hud exists after game._ready
	flash_t = maxf(flash_t - delta, 0.0)
	warn_t = maxf(warn_t - delta, 0.0)
	stars_ui.queue_redraw()
	edge.queue_redraw()
	var p: CharacterBody2D = g.player
	if root_t > 0.0:
		root_t -= delta
		if root_t <= 0.0:
			p.frozen = false
	var offs := officers()
	if p.bark_cd > last_bark:  # bark() just fired; player.gd stays untouched
		for o in offs:
			if o.position.distance_to(p.position) < NEAR_BARK:  # the bark is heard all around, the wave only hits ahead
				o.stun(0.5)
		if offs.any(func(o): return o.position.distance_to(p.position) < NEAR_BARK):
			add_heat(5, "bark")
	last_bark = p.bark_cd
	var seen := drone != null
	for o in offs:
		var d: float = o.position.distance_to(p.position)
		seen = seen or d < SIGHT
		if d < WHISTLE and not o.whistled:
			o.whistled = true
			Sound.sfx("whistle")
			warn_at = o.position
			warn_t = 0.0 if reduce_motion() else 1.0
		elif d > WHISTLE + 100.0:
			o.whistled = false
	unseen = 0.0 if seen and g.inside == "" else unseen + delta
	if unseen >= DECAY_AFTER and heat > 0.0:
		var m := 1.0
		if g.inside not in ["", "shop"]:
			m = 2.0
		elif g.parks.any(func(r: Rect2): return r.has_point(p.position)):
			m = 3.0
		add_heat(-DECAY * m * delta, "decay")
	if drone:
		drone.position = p.position + Vector2(0, -60)
	staff_t -= delta
	if staff_t <= 0.0 and g.inside == "":
		staff_t = 1.0
		staff()

## Spec 08 response table, one spawn / despawn per second. Night halves counts (round up).
func staff() -> void:
	var s := stars()
	var night: bool = g.Spawns.phase(g.sun()) == "night"
	var foot := mini(s, 2)
	var van_n := clampi(s - 2, 0, 2)
	if night:
		foot = ceili(foot / 2.0)
		van_n = ceili(van_n / 2.0)
	var feet := officers().filter(func(o): return not o.van_drop)
	for o in feet:
		o.net = s >= 4
	if feet.size() > foot:
		feet[-1].queue_free()
	elif feet.size() < foot and not g.parks.any(func(r: Rect2): return r.has_point(g.player.position)):
		var at := spawn_spot()
		if at.x >= 0.0:
			spawn_officer(at, false)
	var vs := vans()
	if vs.size() > van_n:
		var crew: Variant = vs[-1].get_meta("crew", null)
		if is_instance_valid(crew):
			crew.queue_free()
		vs[-1].queue_free()
	elif vs.size() < van_n:
		spawn_van()
	for v in vs:  # a van near the dog drops its officer
		if not v.has_meta("crew") and v.position.distance_to(g.player.position) < 300.0:
			v.set_meta("crew", spawn_officer(v.position, true))
	if s >= 5 and not drone:
		drone = make_drone()
	elif s < 5 and drone:
		drone.queue_free()
		drone = null

## Off screen, ~500 px from the dog, on open ground outside parks; x < 0 if none.
func spawn_spot() -> Vector2:
	for i in 12:
		var at: Vector2 = g.player.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(500.0, 600.0)
		if Rect2(Vector2(48, 48), g.WORLD - Vector2(96, 96)).has_point(at) and not g.blocked(at) \
				and not g.parks.any(func(r: Rect2): return r.has_point(at)):
			return at
	return Vector2(-1, -1)

func spawn_officer(at: Vector2, from_van: bool) -> Node2D:
	var o: Node2D = Officer.new()
	o.van_drop = from_van
	g.add_child(o)
	o.setup(g, at)
	return o

## White car.gd on the vertical road nearest the dog, driving at him from 700 px up.
func spawn_van() -> void:
	var col: float = g.BLOCK.x + g.ROAD
	var x: float = roundf((g.player.position.x - 32.0) / col) * col + 32.0
	var v: Node2D = g.CarScript.new()
	v.position = Vector2(x, fposmod(g.player.position.y - 700.0, g.WORLD.y))
	g.add_child(v)
	v.setup(Vector2.DOWN, g)
	v.color = Color(0.95, 0.95, 0.95)
	v.remove_from_group("car")  # not traffic: tests count cars
	v.add_to_group("van")
	var bar := Node2D.new()  # red / blue light bar on the roof. ponytail: lights don't blink
	bar.draw.connect(func():
		bar.draw_rect(Rect2(-6, -10, 6, 10), Color(1, 0.1, 0.1))
		bar.draw_rect(Rect2(-6, 0, 6, 10), Color(0.3, 0.45, 1)))
	v.add_child(bar)
	Sound.sfx("siren")

## 5 stars: a drone over the dog with a real light, so fog and night don't hide him.
func make_drone() -> Node2D:
	var d := Node2D.new()
	d.z_index = 50
	d.draw.connect(func():
		d.draw_rect(Rect2(-12, -3, 24, 6), Color(0.2, 0.2, 0.22))
		for x in [-14.0, 14.0]:
			d.draw_line(Vector2(x - 7, -5), Vector2(x + 7, -5), Color(0.7, 0.7, 0.75), 2.0)
		d.draw_circle(Vector2(0, 4), 2.5, Color(1, 0.2, 0.2)))
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	tex.width = 256
	tex.height = 256
	var light := PointLight2D.new()
	light.texture = tex
	light.position = Vector2(0, 60)  # on the dog, not the drone
	light.energy = 1.2
	d.add_child(light)
	g.add_child(d)
	return d

# ---------- HUD ----------

func build_hud() -> void:
	edge = Control.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.hud.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.draw.connect(draw_edge)
	stars_ui = Control.new()
	stars_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_ui.size = Vector2(150, 26)
	g.hud.add_child(stars_ui)
	stars_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 10)
	stars_ui.position.x -= g.mini.size.x + 10.0  # left of the minimap
	stars_ui.draw.connect(draw_stars)

## 5 slots, filled ones gold, plus the count as text (never color alone, spec 11).
func draw_stars() -> void:
	var c := stars_ui
	var s := stars()
	var blink := flash_t > 0.0 and int(flash_t * 10.0) % 2 == 0
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.45))
	for i in 5:
		var mid := Vector2(13 + i * 23, 13)
		var pts := PackedVector2Array()
		for k in 10:
			pts.append(mid + Vector2.UP.rotated(k * PI / 5.0) * (10.0 if k % 2 == 0 else 4.2))
		if i < s:
			c.draw_colored_polygon(pts, Color.WHITE if blink else Color(1, 0.82, 0.2))
		pts.append(pts[0])
		c.draw_polyline(pts, Color(1, 1, 1, 0.8), 1.2)
	var font := ThemeDB.fallback_font
	c.draw_string_outline(font, Vector2(118, 19), "%d/5" % s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
	c.draw_string(font, Vector2(118, 19), "%d/5" % s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

## Red strip on the screen edge toward the officer that whistled. Reduce motion: no flash,
## a steady strip while any officer is inside whistle range.
func draw_edge() -> void:
	var a := warn_t * 0.6
	var at := warn_at
	if reduce_motion():
		a = 0.0
		for o in officers():
			if o.position.distance_to(g.player.position) < WHISTLE:
				a = 0.35
				at = o.position
	if a <= 0.0 or g.inside != "":
		return
	var view := edge.size
	var dir: Vector2 = (g.get_canvas_transform() * at - view / 2.0).normalized()
	var col := Color(1, 0.1, 0.1, a)
	if absf(dir.x) * view.y > absf(dir.y) * view.x:
		edge.draw_rect(Rect2(view.x - 18 if dir.x > 0 else 0.0, 0, 18, view.y), col)
	else:
		edge.draw_rect(Rect2(0, view.y - 18 if dir.y > 0 else 0.0, view.x, 18), col)
