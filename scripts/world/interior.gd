extends Node
## Interiors (spec 03): one room at a time, built from data/rooms.gd at O when the dog
## goes in through a street door, freed when it leaves.

const O := Vector2(20000, 0)  # far off the street map
const ROOMS := preload("res://scripts/data/rooms.gd").ROOMS
const Gates := preload("res://scripts/data/gates.gd")
const GatePopup := preload("res://scripts/ui/gate_popup.gd")

var g: Node2D
var room: Node2D       # the built room (group "interior"), null on the street
var door := {}         # street door the dog came in by
var floor_n := 0       # elevator floor, 0 = lobby (only the lobby has the street exit)
var rect := Rect2()    # room area, for the camera clamp
var spots := {}        # spot name -> world position
var tint := Color.WHITE

func data() -> Dictionary:
	return ROOMS[door.template]

## Elevator (spec 03): 0.6 s fade, ding, rebuild the template as floor n (0 = lobby).
## n == door.floors on a landmark = the roof: back on the street, camera zoomed out.
func ride(n: int) -> void:
	if door.template == "hq":
		ride_hq(n)
		return
	if n == floor_n or n < 0 or n > door.floors or (n == door.floors and not has_roof()) or g.player.frozen:
		return
	g.player.frozen = true
	var tw := g.create_tween()
	tw.tween_property(g.fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		Sound.sfx("ding")
		if n == door.floors:
			leave()
			g.cam.zoom = Vector2.ONE * 0.6  # roof view over the city
			return
		floor_n = n
		build(door.template)
		g.set_inside(data().kind, spots.elevator)
		g.ui.show_loading("%s   %s" % [door.name.to_upper() if door.name != "" else data().exit[0], floor_name(n)]))
	tw.tween_property(g.fade, "color:a", 0.0, 0.3)
	tw.tween_callback(func(): g.player.frozen = false)

## Hack Club HQ elevator (spec 03): floors 1-3 are puzzle floors behind gate G1, floor 4 (the clue
## room) opens once 1-3 are cleared. Tower floors stay hidden. Keys 1-4 pick a floor.
func hq_id(n: int) -> String:
	return "%s_%d" % [g.save_extra.get("world/city", "nyc"), n + 1]

## Why HQ floor n (0-based) is shut, "" = open.
func hq_block(n: int) -> String:
	if n == 3:
		return "" if range(3).all(func(k): return Story.floors.has(hq_id(k))) else "Clear floors 1-3 first"
	return Story.gate_block(Gates.HQ_GATE.get(g.city.id, "G1"), g.player.level)

func ride_hq(n: int) -> void:
	if n < 0 or n > 3 or g.player.frozen:
		return
	if hq_block(n) != "":
		if n < 3:
			GatePopup.open(g, Gates.HQ_GATE.get(g.city.id, "G1"))  # what's missing, with "Find XP"
		else:
			g.show_msg(hq_block(n))
		return
	if n == 3:  # ponytail: the clue plays in the lobby (cs_ch1_clue); floor 4 just replays it
		g.dialog.play("cs_ch1_clue")
		return
	g.player.frozen = true
	var tw := g.create_tween()
	tw.tween_property(g.fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		Sound.sfx("ding")
		g.hq.enter(hq_id(n))
		g.ui.show_loading("HACK CLUB HQ   FLOOR %d" % (n + 1)))
	tw.tween_property(g.fade, "color:a", 0.0, 0.3)
	tw.tween_callback(func(): g.player.frozen = false)

## Airport gates (spec 02): [text, selectable]. Locked ones say what opens them.
func gate_rows() -> Array:
	var rows := []
	for k in Gates.AIRPORT.size():
		var gate: Array = Gates.AIRPORT[k]
		var here: bool = gate[0] == g.city.id
		var locked: bool = gate[1] != "" and not Story.gate_open(gate[1], g.player.level)
		var note: String = "   (you are here)" if here else ("   " + gate[2] if locked else "")
		rows.append(["[%d]  %s%s" % [k + 1, Gates.CITIES[gate[0]][0], note], not here and not locked])
	return rows

## Board an open gate (spec 02): free in story mode, but security turns away a wanted dog.
## Cities not built yet (no data/cities.gd entry) still just announce the flight.
func fly(n: int) -> void:
	if n < 0 or n >= Gates.AIRPORT.size() or not gate_rows()[n][1] or g.player.frozen:
		return
	if g.wanted.stars() > 0:
		g.show_msg("Security: lose the heat first")
		return
	var to: String = Gates.AIRPORT[n][0]
	var city_name: String = Gates.CITIES[to][0]
	g.show_banner("FLIGHT TO %s" % city_name.to_upper())
	if not g.city.CITIES.has(to):
		g.show_msg("Flights to %s start soon" % city_name)
		return
	leave()
	g.city.travel(to)

func floor_name(n: int) -> String:
	return "LOBBY" if n == 0 else "FLOOR %d" % (n + 1)

func has_roof() -> bool:
	return g.landmarks.any(func(l): return l.name == door.name)

## Menu rows for the elevator panel: [text, selectable].
func floor_rows() -> Array:
	var rows := []
	if door.template == "hq":
		for k in 4:
			var why := hq_block(k)
			var note: String = "   cleared" if Story.floors.has(hq_id(k)) else ("   " + why if why != "" else "")
			rows.append(["[%d]  Floor %d%s" % [k + 1, k + 1, note], why == ""])
		return rows
	for k in door.floors:
		rows.append(["[%d]  %s%s" % [k + 1, "Lobby" if k == 0 else "Floor %d" % (k + 1), "   (you are here)" if k == floor_n else ""], k != floor_n])
	if has_roof():
		rows.append(["[%d]  Roof" % (door.floors + 1), true])
	return rows

func enter(d: Dictionary) -> void:
	door = d
	floor_n = 0
	g.return_pos = d.pos
	build(d.template)
	g.set_inside(data().kind, spots.start)
	if data().has("door") and d.template != "flashback_room":  # loading card with the place's name
		var n: String = d.get("name", "")
		g.ui.show_loading(data().exit[0].format({"name": n, "NAME": n.to_upper()}))
	match d.template:
		"bodega":
			g.bump("shop", true)
			Sound.music("bodega")  # kind "shop" plays interior_shop; Sam's bodegas get their own song
		"cafe":
			g.bump("cafe")
		"subway":
			g.station_i = maxi(g.stations.map(func(s): return s.pos).find(d.pos), 0)
			g.station_sign.text = g.stations[g.station_i].name
			g.subway.spawn_rats()
		"burrow":
			g.hedgehog.start()
			g.bump("burrow", true)
		"hq":  # NYC: the door gate (level 30 + every boss) is the whole test, so the clue waits inside
			if g.city.id == "nyc" and not Story.has("ch1_clue"):
				g.dialog.play("cs_ch1_clue")
		"startup":  # first visit: Patch pitches the idea
			g.bump("met_patch", true)  # shows the Good Boy AI quest line
			if not Story.has("cs_startup_intro"):
				g.dialog.play("cs_startup_intro")
		"nyse", "pier":  # M5-7 bell podium + Fat Cat; M6-4 bait crate + Seagull King
			var arena: Node2D = preload("res://scripts/world/nyse_arena.gd").new()
			arena.g = g
			if d.template == "pier":
				arena.cfg = preload("res://scripts/data/bosses.gd").SEAGULL_KING
				arena.pre = "cs_seagull_pre"
				arena.ready_flags = ["cs_arrive_sf"]
				arena.crate = true
			room.add_child(arena)

func leave() -> void:
	g.hedgehog.stop()  # fleeing the den resets the fight
	g.set_inside("", door.pos)
	g.ui.show_loading(str(Gates.CITIES.get(g.city.id, ["New York"])[0]).to_upper())

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
	var up: Dictionary = r.get("upper", {}) if floor_n > 0 else {}  # upper floors have their own layout
	var paint_list: Array = up.get("paint", r.paint)
	var props: Array = up.get("props", r.props)
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
		for p: Array in paint_list:
			var area := Rect2(O + p[0].position, p[0].size)
			if p[1] is Color:
				paint.draw_rect(area, p[1])
			else:
				paint.draw_texture_rect(g.tex[p[1]], area, true, p[2] if p.size() > 2 else Color.WHITE)
		for i in up.get("units", []).size():  # apartment doors along the hall: 3A, 3B, ...
			draw_unit(paint, up.units[i], "%d%s" % [floor_n + 1, "ABCDEF"[i]])
		if spots.has("elevator"):
			draw_elevator(paint, spots.elevator.x))
	room.add_child(paint)
	var s := rect.size
	box(Vector2(s.x / 2, g.WALL_H / 2), Vector2(s.x, g.WALL_H))  # back wall + three bounds
	box(Vector2(-16, s.y / 2), Vector2(32, s.y))
	box(Vector2(s.x + 16, s.y / 2), Vector2(32, s.y))
	box(Vector2(s.x / 2, s.y + 16), Vector2(s.x, 32))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:f%d" % [door.id, floor_n]) if floor_n > 0 else door.get("seed", 0)  # spec 03: id + :fN
	for p: Array in props:
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

## Elevator in the back wall above the elevator spot: steel frame, doors, floor readout, call button.
func draw_elevator(c: CanvasItem, x: float) -> void:
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(x - 38, O.y + 14, 76, 82), Color(0.42, 0.44, 0.5))
	c.draw_rect(Rect2(x - 32, O.y + 26, 31, 70), Color(0.74, 0.77, 0.82))
	c.draw_rect(Rect2(x + 1, O.y + 26, 31, 70), Color(0.7, 0.73, 0.78))
	c.draw_line(Vector2(x, O.y + 26), Vector2(x, O.y + 96), Color(0.3, 0.32, 0.36), 2.0)
	c.draw_rect(Rect2(x - 16, O.y + 1, 32, 12), Color(0.08, 0.08, 0.1))
	var readout: String = "L" if floor_n == 0 else str(floor_n + 1)
	c.draw_string(font, Vector2(x - 16, O.y + 11), readout, HORIZONTAL_ALIGNMENT_CENTER, 32, 11, Color(1, 0.7, 0.2))
	c.draw_rect(Rect2(x + 42, O.y + 50, 10, 18), Color(0.3, 0.32, 0.36))
	c.draw_circle(Vector2(x + 47, O.y + 55), 2.5, Color(1, 0.8, 0.3))
	c.draw_circle(Vector2(x + 47, O.y + 63), 2.5, Color(0.9, 0.9, 0.95))

func draw_unit(c: CanvasItem, x: float, label: String) -> void:
	c.draw_rect(Rect2(O.x + x - 22, O.y + 30, 44, 66), Color(0.42, 0.26, 0.16))
	c.draw_rect(Rect2(O.x + x - 18, O.y + 34, 36, 58), Color(0.52, 0.33, 0.2))
	c.draw_circle(Vector2(O.x + x + 12, O.y + 66), 2.5, Color(0.95, 0.8, 0.35))
	c.draw_rect(Rect2(O.x + x - 10, O.y + 38, 20, 11), Color(0.92, 0.88, 0.75))
	c.draw_string(ThemeDB.fallback_font, Vector2(O.x + x - 10, O.y + 47), label, HORIZONTAL_ALIGNMENT_CENTER, 20, 9, Color(0.2, 0.15, 0.1))

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
	g.train.scale = Vector2(1.25, 1.25)  # 2x-res car art (tools/gen_subway.py)
	g.train.position = O + Vector2(-600, 372)
	room.add_child(g.train)
	g.train_t = g.TRAIN_EVERY
