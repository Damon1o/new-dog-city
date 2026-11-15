extends Node2D
## New Dog City — builds the city, spawns animals, runs HUD / shop / subway / steam.

const TILE := 32
const COLS := 60
const ROWS := 40

const PreyScript := preload("res://scripts/prey.gd")
const RaccoonScript := preload("res://scripts/raccoon.gd")

const TEX := {
	"road": preload("res://assets/road.png"),
	"road_dash": preload("res://assets/road_dash.png"),
	"sidewalk": preload("res://assets/sidewalk.png"),
	"grass": preload("res://assets/grass.png"),
	"building_a": preload("res://assets/building_a.png"),
	"building_b": preload("res://assets/building_b.png"),
	"empire": preload("res://assets/empire_state.png"),
	"chrysler": preload("res://assets/chrysler.png"),
	"bodega": preload("res://assets/bodega.png"),
	"subway": preload("res://assets/subway.png"),
	"trashcan": preload("res://assets/trashcan.png"),
	"manhole": preload("res://assets/manhole.png"),
	"steam": preload("res://assets/steam.png"),
	"water_bowl": preload("res://assets/water_bowl.png"),
	"pigeon": preload("res://assets/pigeon.png"),
	"rat": preload("res://assets/rat.png"),
	"squirrel": preload("res://assets/squirrel.png"),
	"raccoon": preload("res://assets/raccoon.png"),
}

const PREY_KINDS := {
	"pigeon": {"speed": 130.0, "treats": 2, "xp": 8},
	"rat": {"speed": 110.0, "treats": 1, "xp": 5},
	"squirrel": {"speed": 160.0, "treats": 3, "xp": 12},
}
const MAX_PREY := 10

# road bands in tile indices
const V_ROADS := [[14, 17], [42, 45]]
const H_ROADS := [[12, 15], [28, 31]]
const PARK := Rect2i(24, 20, 13, 7)

var building_rects: Array[Rect2] = []
var manholes: Array[Dictionary] = []
var subway_spots: Array[Vector2] = [Vector2(300, 1150), Vector2(1660, 330)]
var water_bowls: Array[Vector2] = []
var bodega_door := Vector2.ZERO
var subway_cooldown := 0.0
var prey_count := 0
var spawn_timer := 0.0
var hud: Label
var msg: Label
var msg_timer := 0.0

@onready var player: CharacterBody2D = $Player

func world_rect() -> Rect2:
	return Rect2(0, 0, COLS * TILE, ROWS * TILE)

func _ready() -> void:
	build_ground()
	build_bounds()
	place_structures()
	build_hud()
	for i in MAX_PREY:
		spawn_prey()

func _process(delta: float) -> void:
	subway_cooldown = maxf(subway_cooldown - delta, 0.0)
	spawn_timer -= delta
	if prey_count < MAX_PREY and spawn_timer <= 0.0:
		spawn_timer = 2.0
		spawn_prey()
	update_steam(delta)
	check_subway()
	check_water(delta)
	update_hud(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_TAB:
			player.cycle_skin()
			show_msg("Skin: " + player.skin_name())
		KEY_1, KEY_KP_1:
			try_buy("purina")
		KEY_2, KEY_KP_2:
			try_buy("water")

# ---------- world building ----------

func build_ground() -> void:
	for ty in ROWS:
		for tx in COLS:
			var tex: Texture2D = TEX.sidewalk
			var on_v := in_band(tx, V_ROADS)
			var on_h := in_band(ty, H_ROADS)
			if on_v or on_h:
				tex = TEX.road_dash if (is_band_center(tx, V_ROADS) or is_band_center(ty, H_ROADS)) and not (on_v and on_h) else TEX.road
			elif PARK.has_point(Vector2i(tx, ty)):
				tex = TEX.grass
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position = Vector2(tx * TILE, ty * TILE)
			s.z_index = -10
			add_child(s)

func in_band(i: int, bands: Array) -> bool:
	for b in bands:
		if i >= b[0] and i <= b[1]:
			return true
	return false

func is_band_center(i: int, bands: Array) -> bool:
	for b in bands:
		if i == (b[0] + b[1]) / 2:
			return true
	return false

func build_bounds() -> void:
	var w := COLS * TILE
	var h := ROWS * TILE
	for wall in [[Vector2(w / 2.0, -16), Vector2(w, 32)], [Vector2(w / 2.0, h + 16), Vector2(w, 32)],
			[Vector2(-16, h / 2.0), Vector2(32, h)], [Vector2(w + 16, h / 2.0), Vector2(32, h)]]:
		add_static_box(wall[0], wall[1])

func add_static_box(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	return body

func add_building(tex: Texture2D, pos: Vector2, scl := 1.5) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2(scl, scl)
	s.z_index = 2
	add_child(s)
	var size := tex.get_size() * scl
	add_static_box(pos, size)
	building_rects.append(Rect2(pos - size / 2.0, size))

func place_structures() -> void:
	add_building(TEX.empire, Vector2(640, 190))
	add_building(TEX.chrysler, Vector2(1180, 190))
	add_building(TEX.building_a, Vector2(230, 240))
	add_building(TEX.building_b, Vector2(1700, 800))
	add_building(TEX.building_a, Vector2(950, 1150))
	add_building(TEX.building_b, Vector2(230, 760))
	# Bodega (sells items)
	var bodega_pos := Vector2(820, 700)
	add_building(TEX.bodega, bodega_pos, 2.0)
	bodega_door = bodega_pos + Vector2(60, 90)
	add_sprite(TEX.water_bowl, bodega_pos + Vector2(-80, 80), 2.5)
	water_bowls.append(bodega_pos + Vector2(-80, 80))
	add_sprite(TEX.water_bowl, Vector2(980, 740), 2.5)
	water_bowls.append(Vector2(980, 740))
	# Subway entrances (fast travel)
	for spot in subway_spots:
		add_sprite(TEX.subway, spot, 1.5)
	# Trash cans with raccoons
	for pos in [Vector2(380, 620), Vector2(1250, 560), Vector2(700, 1080),
			Vector2(1540, 1120), Vector2(240, 980), Vector2(1800, 250)]:
		add_sprite(TEX.trashcan, pos, 2.0)
		var rac: Node2D = RaccoonScript.new()
		add_child(rac)
		rac.setup(pos, TEX.raccoon, self)
	# Manholes on road centers, with steam bursts
	for pos in [Vector2(512, 448), Vector2(1408, 448), Vector2(512, 960), Vector2(1408, 960)]:
		add_sprite(TEX.manhole, pos, 1.5)
		var steam := Sprite2D.new()
		steam.texture = TEX.steam
		steam.position = pos + Vector2(0, -14)
		steam.scale = Vector2(3, 3)
		steam.visible = false
		steam.z_index = 3
		add_child(steam)
		manholes.append({"pos": pos, "sprite": steam, "t": randf_range(2.0, 7.0), "on": false})

func add_sprite(tex: Texture2D, pos: Vector2, scl: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2(scl, scl)
	add_child(s)

# ---------- systems ----------

func update_steam(delta: float) -> void:
	for m in manholes:
		m.t -= delta
		if m.t <= 0.0:
			m.on = not m.on
			m.sprite.visible = m.on
			m.t = 1.5 if m.on else randf_range(3.5, 8.0)
		if m.on and player.position.distance_to(m.pos) < 34.0:
			player.take_damage(delta * 25.0)

func check_subway() -> void:
	if subway_cooldown > 0.0:
		return
	for i in subway_spots.size():
		if player.position.distance_to(subway_spots[i]) < 45.0:
			var other: Vector2 = subway_spots[(i + 1) % subway_spots.size()]
			player.position = other + Vector2(0, 60)
			subway_cooldown = 2.0
			show_msg("Took the subway downtown!")
			return

func check_water(delta: float) -> void:
	for pos in water_bowls:
		if player.position.distance_to(pos) < 30.0:
			player.drink(delta * 25.0)

func try_buy(item: String) -> void:
	if player.position.distance_to(bodega_door) > 80.0:
		return
	if item == "purina":
		if player.treats >= 5:
			player.treats -= 5
			player.eat(50.0, 30.0)
			show_msg("Bought Purina! +HP +hunger")
		else:
			show_msg("Need 5 treats for Purina")
	elif item == "water":
		if player.treats >= 3:
			player.treats -= 3
			player.drink(60.0)
			show_msg("Bought water! +thirst")
		else:
			show_msg("Need 3 treats for water")

func spawn_prey() -> void:
	var kind: String = PREY_KINDS.keys()[randi() % PREY_KINDS.size()]
	var cfg: Dictionary = PREY_KINDS[kind]
	var pos := Vector2.ZERO
	for attempt in 20:
		pos = Vector2(randf_range(64, COLS * TILE - 64), randf_range(64, ROWS * TILE - 64))
		if pos.distance_to(player.position) < 300.0:
			continue
		var blocked := false
		for r in building_rects:
			if r.grow(20).has_point(pos):
				blocked = true
				break
		if not blocked:
			break
	var prey: Node2D = PreyScript.new()
	prey.position = pos
	add_child(prey)
	prey.setup(kind, TEX[kind], cfg.speed, cfg.treats, cfg.xp, self)
	prey_count += 1

func on_prey_caught(prey: Node2D) -> void:
	player.treats += prey.treat_reward
	player.add_xp(prey.xp_reward)
	player.eat(prey.hunger_reward, 0.0)
	show_msg("Caught %s! +%d treats" % [prey.kind, prey.treat_reward])
	prey_count -= 1
	prey.queue_free()

# ---------- HUD ----------

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(12, 10)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)
	msg = Label.new()
	msg.position = Vector2(12, 600)
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	msg.add_theme_color_override("font_outline_color", Color.BLACK)
	msg.add_theme_constant_override("outline_size", 5)
	layer.add_child(msg)
	show_msg("WASD move | TAB skin | catch prey, avoid raccoons & steam")

func show_msg(text: String) -> void:
	msg.text = text
	msg_timer = 3.5

func update_hud(delta: float) -> void:
	msg_timer -= delta
	if msg_timer <= 0.0:
		msg.text = ""
		if player.position.distance_to(bodega_door) <= 80.0:
			msg.text = "BODEGA  [1] Purina 5t (+HP)   [2] Water 3t"
	hud.text = "%s  Lv %d  (%d/%d xp)\nHP %d/%d   Treats %d\nHunger %d   Thirst %d" % [
		player.skin_name(), player.level, player.xp, player.xp_needed(),
		int(player.hp), int(player.max_hp), player.treats,
		int(player.hunger), int(player.thirst)]
