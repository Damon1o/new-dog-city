extends Node
## Interiors (spec 03): one room at a time, built from data/rooms.gd at O when the dog
## goes in through a street door, freed when it leaves.

const O := Vector2(20000, 0)  # far off the street map
const ROOMS := preload("res://scripts/data/rooms.gd").ROOMS

var g: Node2D
var room: Node2D       # the built room (group "interior"), null on the street
var door := {}         # street door the dog came in by
var rect := Rect2()    # room area, for the camera clamp
var spots := {}        # spot name -> world position
var tint := Color.WHITE

func data() -> Dictionary:
	return ROOMS[door.template]

func enter(d: Dictionary) -> void:
	door = d
	g.return_pos = d.pos
	build(d.template)
	g.set_inside(data().kind, spots.start)
	match d.template:
		"bodega":
			g.bump("shop", true)
		"subway":
			g.station_i = maxi(g.stations.map(func(s): return s.pos).find(d.pos), 0)
			g.station_sign.text = g.stations[g.station_i].name
		"burrow":
			g.hedgehog.start()
			g.bump("burrow", true)

func leave() -> void:
	g.hedgehog.stop()  # fleeing the den resets the fight
	g.set_inside("", door.pos)

## Free the room (game.set_inside("") calls this, so dying indoors cleans up too).
func clear() -> void:
	if g.train_tw:
		g.train_tw.kill()
	if room:
		room.free()  # not queue_free: in and out in one frame must never leave two rooms
		room = null

func build(template: String) -> void:
	clear()
	var r: Dictionary = ROOMS[template]
	rect = Rect2(O, r.size)
	tint = r.tint
	spots = {}
	for k: String in r.spots:
		spots[k] = O + r.spots[k]
	room = Node2D.new()
	room.y_sort_enabled = true
	room.add_to_group("interior")
	g.add_child(room)
	var paint := Node2D.new()
	paint.z_index = -10
	paint.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	paint.draw.connect(func():
		paint.draw_rect(rect.grow(1200), Color.BLACK)  # a wide window never shows past the walls
		for p: Array in r.paint:
			var area := Rect2(O + p[0].position, p[0].size)
			if p[1] is Color:
				paint.draw_rect(area, p[1])
			else:
				paint.draw_texture_rect(g.tex[p[1]], area, true, p[2] if p.size() > 2 else Color.WHITE))
	room.add_child(paint)
	var s := rect.size
	box(Vector2(s.x / 2, g.WALL_H / 2), Vector2(s.x, g.WALL_H))  # back wall + three bounds
	box(Vector2(-16, s.y / 2), Vector2(32, s.y))
	box(Vector2(s.x + 16, s.y / 2), Vector2(32, s.y))
	box(Vector2(s.x / 2, s.y + 16), Vector2(s.x, 32))
	var rng := RandomNumberGenerator.new()
	rng.seed = door.get("seed", 0)
	for p: Array in r.props:
		var spr := Sprite2D.new()
		var t: Texture2D = g.tex[p[0]]
		spr.texture = t
		spr.scale = Vector2(p[2], p[2])
		spr.offset = Vector2(0, -t.get_height() / 2.0 - (p[4] if p.size() > 4 else 0.0))
		spr.position = O + p[1]
		if r.get("vary", false):
			spr.modulate = Color.from_hsv(rng.randf(), 0.15, rng.randf_range(0.85, 1.0))
		room.add_child(spr)
		if p[3] != Vector2.ZERO:
			box(p[1] - Vector2(0, p[3].y / 2), p[3])
	if template == "subway":
		build_subway()

## Room-local static collider.
func box(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = O + pos
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	shape.shape = rect_shape
	body.add_child(shape)
	room.add_child(body)

## Station name sign and the through-train (scripts/world/subway.gd drives it).
func build_subway() -> void:
	g.station_sign = Label.new()
	g.station_sign.position = O + Vector2(476, 6)
	g.station_sign.size = Vector2(200, 26)
	g.station_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sign_bg := StyleBoxFlat.new()
	sign_bg.bg_color = Color(0.08, 0.08, 0.1)
	g.station_sign.add_theme_stylebox_override("normal", sign_bg)
	room.add_child(g.station_sign)
	g.train = Sprite2D.new()
	g.train.texture = g.tex.train
	g.train.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.train.region_enabled = true
	g.train.region_rect = Rect2(0, 0, g.tex.train.get_width() * 4, g.tex.train.get_height())  # 4 cars
	g.train.scale = Vector2(2.5, 2.5)
	g.train.position = O + Vector2(-600, 372)
	room.add_child(g.train)
	g.train_t = g.TRAIN_EVERY
