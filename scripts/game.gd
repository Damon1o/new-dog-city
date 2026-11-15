extends Node2D
## New Dog City — procedural Manhattan grid, animals, HUD, bodega, subway,
## steam, day/night, minimap / god's-eye view, autosave.

const BLOCK := Vector2(512, 384)
const ROAD := 128.0
const NX := 6
const NY := 5
const WORLD := Vector2(3968, 2688)  # NX*512 + (NX+1)*128, NY*384 + (NY+1)*128
const CITY_SEED := 20261115  # fixed layout so saves and subway stops stay valid
const DAY_LENGTH := 240.0
const SAVE_KEYS := ["level", "xp", "treats", "skin", "purina", "water", "collar", "hunger", "thirst",
	"points", "stat_hp", "stat_atk", "stat_spd"]
const CAR_DMG := 30.0
const MAX_PREY := 36
const MAX_TREATS := 25

const PreyScript := preload("res://scripts/prey.gd")
const RaccoonScript := preload("res://scripts/raccoon.gd")
const BossScript := preload("res://scripts/boss.gd")
const CarScript := preload("res://scripts/car.gd")

const TEX_NAMES := ["road", "sidewalk", "grass", "building_a", "building_b", "building_c",
	"empire_state", "chrysler", "bodega", "subway", "trashcan", "manhole", "water_bowl",
	"pigeon", "rat", "squirrel", "raccoon", "treat", "tree", "fountain", "hydrant", "purina",
	"cat", "shop_floor", "shop_wall", "shelf", "counter", "station_wall", "platform", "track",
	"pillar", "stairs", "map_board", "train"]
const SFX_NAMES := ["bark", "catch", "hurt", "buy", "levelup", "steam", "subway", "pickup"]

const PREY := {
	"pigeon": {"speed": 120.0, "flee": 150.0, "treats": 2, "xp": 8, "food": 8.0},
	"rat": {"speed": 105.0, "flee": 110.0, "treats": 1, "xp": 5, "food": 5.0},
	"squirrel": {"speed": 150.0, "flee": 190.0, "treats": 4, "xp": 14, "food": 10.0},
}
# One boss per park (index into PARKS; park 0 is the dog's spawn). special: see boss.gd.
const BOSSES := [
	{"name": "King of Raccoons", "tex": "raccoon", "park": 3, "hp": 260.0, "speed": 150.0, "dmg": 14.0,
		"specials": ["charge", "slam"], "tint": Color(1, 0.85, 0.4), "treats": 40, "xp": 150},
	{"name": "The Pideon Queen", "tex": "pigeon", "park": 1, "hp": 180.0, "speed": 175.0, "dmg": 9.0,
		"specials": ["feathers", "storm"], "tint": Color(1, 0.6, 0.9), "treats": 30, "xp": 120},
	{"name": "The Rat Meister", "tex": "rat", "park": 2, "hp": 220.0, "speed": 135.0, "dmg": 11.0,
		"specials": ["rats", "burrow"], "tint": Color(0.6, 1, 0.5), "treats": 35, "xp": 135},
]
const BOSS_COLOR := Color(0.85, 0.3, 1)
const TRAIN_EVERY := 20.0  # seconds between through-trains in the subway
const TRAIN_HALF := 480.0  # half the train's length: 4 cars * 96 px * 2.5 / 2
const SHOP := [["purina", 5], ["water", 3], ["collar", 25]]
const SHOP_INFO := {"purina": "Purina  (+50 food, +40 HP)", "water": "Water  (+60 thirst)", "collar": "Name Collar"}
const LOW := 0.25  # stat fraction where bars pulse and the vignette appears
const LOW_KEYS := ["hp", "hunger", "thirst"]

# Interiors live far off the street map; F at a door / stairwell moves the dog there.
const WALL_H := 96.0
const SHOP_O := Vector2(6000, 0)
const SHOP_ROOM := Rect2(SHOP_O, Vector2(768, 448))
const SHOP_EXIT := SHOP_O + Vector2(384, 432)
const SHOP_COUNTER := SHOP_O + Vector2(620, 280)
const SUB_O := Vector2(6000, 2000)
const SUB_ROOM := Rect2(SUB_O, Vector2(1152, 448))
const SUB_EXIT := SUB_O + Vector2(320, 112)
const SUB_BOARD := SUB_O + Vector2(576, 112)

const PARKS := [Vector2i(2, 2), Vector2i(5, 0), Vector2i(0, 3), Vector2i(4, 4)]
const BODEGAS := [Vector2i(3, 2), Vector2i(0, 0), Vector2i(5, 3)]
const LANDMARKS := {Vector2i(3, 1): ["empire_state", "Empire State Building"],
	Vector2i(1, 1): ["chrysler", "Chrysler Building"]}
const STATIONS := {Vector2i(4, 0): "Uptown", Vector2i(2, 1): "Midtown",
	Vector2i(1, 4): "Downtown", Vector2i(5, 2): "East Side"}

var tex := {}
var sounds := {}
var building_rects: Array[Rect2] = []
var parks: Array[Rect2] = []
var trees: Array[Vector2] = []
var cans: Array[Vector2] = []
var water_spots: Array[Vector2] = []
var bodega_doors: Array[Vector2] = []
var stations: Array[Dictionary] = []   # {pos, name}
var landmarks: Array[Dictionary] = []  # {pos, name, seen}
var manholes: Array[Dictionary] = []   # {pos, steam, t, on}
var treat_sprites: Array[Sprite2D] = []

var tod := 0.33  # time of day 0..1, 0.5 = noon
var ctx := ""    # "bodega" / "subway" — what number keys do right now; "door" = F prompt showing
var inside := ""  # "" street / "shop" / "subway"
var act := ""     # what F does right now
var act_i := 0
var return_pos := Vector2.ZERO  # street spot the bodega exit leads back to
var station_i := 0              # station the subway room currently is
var zoom_tw: Tween
var train: Sprite2D
var train_t := TRAIN_EVERY
var train_tw: Tween
var boss: Node2D  # boss currently fighting the dog, if any
var boss_box: PanelContainer
var boss_name: Label
var death_panel: PanelContainer
var death_why: Label
var death_cause := "You blacked out."
var save_path := "user://save.cfg"  # var so the smoke test can point it elsewhere
var stat_panel: PanelContainer
var stat_head: Label
var stat_buttons: Array[Button] = []
var station_sign: Label
var fade: ColorRect
var spawn_timer := 0.0
var save_timer := 20.0
var shake_amt := 0.0
var god_view := false

var ground: Node2D
var night: CanvasModulate
var hud: Control
var bars := {}   # key -> {ctl, color, v, ghost, text}
var slots := {}  # item -> count Label
var pois: Array[Dictionary] = []  # {pos, text, color} — shops, stations, water
var marker := {}                  # nearest poi, drawn as a floating tag
var drinking := false
var last_treats := -1
var card_t := 0.0
var prev_skin := 0
var banner_tw: Tween
var title: Label
var info: Label
var treat_label: Label
var banner: Label
var menu_head: Label
var menu_rows: Array[Label] = []
var menu: PanelContainer
var card: PanelContainer
var pause_panel: PanelContainer
var toasts: VBoxContainer
var vignette: TextureRect
var overlay: Control
var clock: Control
var card_art: Control
var mini: Control
var volume: HSlider
var name_edit: LineEdit

@onready var player: CharacterBody2D = $Player
@onready var cam: Camera2D = $Player/Camera2D

func _ready() -> void:
	for n in TEX_NAMES:
		tex[n] = load("res://assets/%s.png" % n)
	for n in SFX_NAMES:
		sounds[n] = load("res://assets/sfx/%s.wav" % n)
	y_sort_enabled = true
	ground = Node2D.new()
	ground.z_index = -10
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.draw.connect(draw_ground)
	add_child(ground)
	night = CanvasModulate.new()
	add_child(night)

	seed(CITY_SEED)
	build_bounds()
	for by in NY:
		for bx in NX:
			build_block(Vector2i(bx, by))
	place_manholes()
	build_interiors()
	randomize()
	for b in BOSSES:
		var boss_node: Node2D = BossScript.new()
		add_child(boss_node)
		boss_node.setup(b, block_origin(PARKS[b.park]) + BLOCK / 2.0 + Vector2(0, 110), tex[b.tex], self)
	for lane in 2:  # one car per lane, keep-right traffic
		for i in NX + 1:
			add_car(Vector2(i * (BLOCK.x + ROAD) + 32 + lane * 64, randf() * WORLD.y), [Vector2.DOWN, Vector2.UP][lane])
		for j in NY + 1:
			add_car(Vector2(randf() * WORLD.x, j * (BLOCK.y + ROAD) + 32 + lane * 64), [Vector2.LEFT, Vector2.RIGHT][lane])

	player.position = block_origin(PARKS[0]) + BLOCK / 2.0 + Vector2(0, 90)
	player.spawn_point = player.position
	set_inside("")
	player.leveled.connect(func():
		show_banner("LEVEL %d" % player.level)
		sfx("levelup")
		show_stats())
	player.hit.connect(func():
		shake_amt = 6.0
		sfx("hurt"))
	player.died.connect(func():
		death_why.text = death_cause + "\nLost half your treats."
		death_cause = "You blacked out."
		fade.color.a = 0.0  # in case the dog starved mid-ride
		death_panel.show()
		death_panel.get_node("Box/Respawn").grab_focus()
		get_tree().paused = true)

	build_hud()
	load_game()
	show_stats()
	for i in 12:
		spawn_prey()
		spawn_treat()
	show_msg("Press Esc for controls")

func _process(delta: float) -> void:
	tod = fmod(tod + delta / DAY_LENGTH, 1.0)
	night.color = {"shop": Color(1, 0.96, 0.88), "subway": Color(0.8, 0.86, 0.82)}.get(
		inside, Color(0.3, 0.33, 0.55).lerp(Color.WHITE, sun()))
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = 1.5
		if get_tree().get_nodes_in_group("prey").size() < MAX_PREY:
			spawn_prey()
		if treat_sprites.size() < MAX_TREATS:
			spawn_treat()
	save_timer -= delta
	if save_timer <= 0.0:
		save_timer = 20.0
		save_game()
	update_steam(delta)
	update_train(delta)
	check_pickups()
	check_landmarks()
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	shake_amt = lerpf(shake_amt, 0.0, minf(delta * 10.0, 1.0))
	update_hud(delta)
	mini.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			if not name_edit.visible:
				set_paused(true)
		KEY_TAB:
			prev_skin = player.skin
			player.cycle_skin()
			card_t = 3.0
			card_art.queue_redraw()
		KEY_SPACE:
			player.bite()
		KEY_Q:
			if player.use_purina():
				sfx("pickup")
				float_text(player.position, "+HP", Color(0.5, 1, 0.5))
		KEY_E:
			if player.use_water():
				sfx("pickup")
				float_text(player.position, "+water", Color(0.5, 0.8, 1))
		KEY_F:
			interact()
		KEY_M:
			if inside == "":
				god_view = not god_view
				zoom_tw = create_tween()
				zoom_tw.tween_property(cam, "zoom", Vector2.ONE * (0.3 if god_view else 1.5), 0.4)
		KEY_1, KEY_2, KEY_3, KEY_4:
			on_number(event.keycode - KEY_1)

func sun() -> float:
	return clampf(sin((tod - 0.25) * TAU) * 1.5 + 0.6, 0.0, 1.0)

# ---------- world building ----------

func block_origin(b: Vector2i) -> Vector2:
	return Vector2(ROAD + b.x * (BLOCK.x + ROAD), ROAD + b.y * (BLOCK.y + ROAD))

func draw_ground() -> void:
	ground.draw_texture_rect(tex.sidewalk, Rect2(Vector2.ZERO, WORLD), true)
	var step := BLOCK + Vector2(ROAD, ROAD)
	var yellow := Color(0.82, 0.7, 0.24)
	for i in NX + 1:
		ground.draw_texture_rect(tex.road, Rect2(i * step.x, 0, ROAD, WORLD.y), true)
	for j in NY + 1:
		ground.draw_texture_rect(tex.road, Rect2(0, j * step.y, WORLD.x, ROAD), true)
	for i in NX + 1:  # lane dashes, skipping intersections
		for j in NY:
			for k in int(BLOCK.y / 32):
				ground.draw_rect(Rect2(i * step.x + 62, ROAD + j * step.y + k * 32 + 6, 4, 20), yellow)
	for j in NY + 1:
		for i in NX:
			for k in int(BLOCK.x / 32):
				ground.draw_rect(Rect2(ROAD + i * step.x + k * 32 + 6, j * step.y + 62, 20, 4), yellow)
	for p in parks:
		ground.draw_texture_rect(tex.grass, p.grow(-8), true)
	# interiors, on black so a wide window never shows past the walls
	ground.draw_rect(SHOP_ROOM.grow(1200), Color.BLACK)
	ground.draw_rect(SUB_ROOM.grow(1200), Color.BLACK)
	ground.draw_texture_rect(tex.shop_floor, SHOP_ROOM, true)
	ground.draw_texture_rect(tex.shop_wall, Rect2(SHOP_O, Vector2(SHOP_ROOM.size.x, WALL_H)), true)
	ground.draw_rect(Rect2(SHOP_EXIT - Vector2(40, 8), Vector2(80, 24)), Color(0.55, 0.15, 0.15))  # door mat
	ground.draw_texture_rect(tex.platform, SUB_ROOM, true)
	ground.draw_texture_rect(tex.station_wall, Rect2(SUB_O, Vector2(SUB_ROOM.size.x, WALL_H)), true)
	ground.draw_rect(Rect2(SUB_O + Vector2(0, 88), Vector2(SUB_ROOM.size.x, 8)), Color(0.15, 0.4, 0.25))
	ground.draw_rect(Rect2(SUB_O + Vector2(0, 308), Vector2(SUB_ROOM.size.x, 12)), yellow)  # platform edge
	ground.draw_texture_rect(tex.track, Rect2(SUB_O + Vector2(0, 320), Vector2(SUB_ROOM.size.x, 128)), true)

func build_bounds() -> void:
	for wall in [[Vector2(WORLD.x / 2, -16), Vector2(WORLD.x, 32)], [Vector2(WORLD.x / 2, WORLD.y + 16), Vector2(WORLD.x, 32)],
			[Vector2(-16, WORLD.y / 2), Vector2(32, WORLD.y)], [Vector2(WORLD.x + 16, WORLD.y / 2), Vector2(32, WORLD.y)]]:
		add_static_box(wall[0], wall[1])

func add_static_box(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

## Sprite anchored at its base so y-sort lets the dog walk behind it.
func add_prop(t: Texture2D, base: Vector2, scl: float, tint := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.scale = Vector2(scl, scl)
	s.offset = Vector2(0, -t.get_height() / 2.0)
	s.position = base
	s.modulate = tint
	add_child(s)
	return s

## foot = fraction of sprite height that is solid footprint (rest is walk-behind).
func add_building(t: Texture2D, base: Vector2, scl: float, foot: float, tint := Color.WHITE) -> void:
	add_prop(t, base, scl, tint)
	var size := t.get_size() * scl
	var foot_size := Vector2(size.x, size.y * foot)
	add_static_box(base - Vector2(0, foot_size.y / 2.0), foot_size)
	building_rects.append(Rect2(base - Vector2(size.x / 2.0, foot_size.y), foot_size))

func add_tree(pos: Vector2) -> void:
	add_prop(tex.tree, pos, 2.5)
	add_static_box(pos - Vector2(0, 5), Vector2(14, 10))
	trees.append(pos)

func add_can(pos: Vector2) -> void:
	add_prop(tex.trashcan, pos, 2.0)
	add_static_box(pos - Vector2(0, 6), Vector2(20, 12))
	cans.append(pos)
	var rac: Node2D = RaccoonScript.new()
	add_child(rac)
	rac.setup(pos + Vector2(0, 2), tex.raccoon, self)

func build_block(b: Vector2i) -> void:
	var o := block_origin(b)
	var c := o + BLOCK / 2.0
	if b in PARKS:
		parks.append(Rect2(o, BLOCK))
		add_prop(tex.fountain, c, 2.5)
		add_static_box(c - Vector2(0, 20), Vector2(90, 36))
		water_spots.append(c + Vector2(0, 6))
		for i in 8:
			var p := o + Vector2(randf_range(40, 472), randf_range(70, 364))
			if p.distance_to(c) > 110.0:
				add_tree(p)
	elif LANDMARKS.has(b):
		var base := o + Vector2(256, 372)
		add_building(tex[LANDMARKS[b][0]], base, 2.5, 0.45)
		landmarks.append({"pos": base, "name": LANDMARKS[b][1], "seen": false})
		add_tree(o + Vector2(60, 360))
		add_tree(o + Vector2(452, 360))
	elif b in BODEGAS:
		var base := o + Vector2(256, 240)
		add_building(tex.bodega, base, 2.0, 0.6)
		bodega_doors.append(base + Vector2(54, 24))
		add_prop(tex.water_bowl, base + Vector2(-70, 34), 2.5)
		water_spots.append(base + Vector2(-70, 30))
		add_can(o + Vector2(450, 250))
		add_tree(o + Vector2(60, 340))
	else:
		for i in 3:
			if randf() < 0.85:
				var kind: String = ["building_a", "building_b", "building_c"].pick_random()
				add_building(tex[kind], o + Vector2(96 + i * 160, 236), 1.5, 0.6,
					Color.from_hsv(randf(), 0.15, randf_range(0.8, 1.0)))
		add_can(o + Vector2(randf_range(40, 170), randf_range(285, 360)))
		if randf() < 0.5:
			add_can(o + Vector2(randf_range(340, 470), randf_range(285, 360)))
		if STATIONS.has(b):
			var pos := o + Vector2(256, 340)
			add_prop(tex.subway, pos, 1.5)
			stations.append({"pos": pos, "name": STATIONS[b]})
		elif randf() < 0.5:
			add_prop(tex.hydrant, o + Vector2(256, 300), 2.0)
			water_spots.append(o + Vector2(256, 300))
		else:
			add_tree(o + Vector2(256, 330))

func place_manholes() -> void:
	var step := BLOCK + Vector2(ROAD, ROAD)
	for i in range(1, NX):
		for j in NY:
			if randf() < 0.4:
				add_manhole(Vector2(i * step.x + 64, ROAD + j * step.y + BLOCK.y / 2))
	for j in range(1, NY):
		for i in NX:
			if randf() < 0.25:
				add_manhole(Vector2(ROAD + i * step.x + BLOCK.x / 2, j * step.y + 64))

func add_manhole(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = tex.manhole
	s.position = pos
	s.scale = Vector2(1.5, 1.5)
	s.z_index = -5
	add_child(s)
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
	add_child(p)
	manholes.append({"pos": pos, "steam": p, "t": randf_range(2.0, 7.0), "on": false})

# ---------- helpers ----------

func build_interiors() -> void:
	for r: Rect2 in [SHOP_ROOM, SUB_ROOM]:  # back wall + three bounds
		add_static_box(r.position + Vector2(r.size.x / 2, WALL_H / 2), Vector2(r.size.x, WALL_H))
		add_static_box(r.position + Vector2(-16, r.size.y / 2), Vector2(32, r.size.y))
		add_static_box(r.position + Vector2(r.size.x + 16, r.size.y / 2), Vector2(32, r.size.y))
		add_static_box(r.position + Vector2(r.size.x / 2, r.size.y + 16), Vector2(r.size.x, 32))

	# bodega: shelves on the back wall and the floor, counter with the cat in charge
	for p in [Vector2(80, 130), Vector2(190, 130), Vector2(300, 130), Vector2(410, 130),
			Vector2(150, 320), Vector2(330, 320)]:
		add_prop(tex.shelf, SHOP_O + p, 2.0)
		add_static_box(SHOP_O + p - Vector2(0, 12), Vector2(96, 24))
	var counter := SHOP_COUNTER - Vector2(0, 30)
	add_prop(tex.counter, counter, 2.0)
	add_static_box(counter - Vector2(0, 20), Vector2(128, 40))
	add_prop(tex.cat, counter + Vector2(-30, 1), 2.5).offset.y -= 22.0  # sits on the countertop

	# subway: exit stairs and map board set into the wall, pillars, tracks, train
	add_prop(tex.stairs, SUB_EXIT - Vector2(0, 12), 2.0)
	add_prop(tex.map_board, SUB_O + Vector2(576, 84), 2.0)
	for x in [200, 456, 712, 968]:
		add_prop(tex.pillar, SUB_O + Vector2(x, 296), 2.5)
		add_static_box(SUB_O + Vector2(x, 291), Vector2(20, 10))
	station_sign = Label.new()
	station_sign.position = SUB_O + Vector2(476, 6)
	station_sign.size = Vector2(200, 26)
	station_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sign_bg := StyleBoxFlat.new()
	sign_bg.bg_color = Color(0.08, 0.08, 0.1)
	station_sign.add_theme_stylebox_override("normal", sign_bg)
	add_child(station_sign)
	train = Sprite2D.new()
	train.texture = tex.train
	train.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	train.region_enabled = true
	train.region_rect = Rect2(0, 0, tex.train.get_width() * 4, tex.train.get_height())  # 4 cars
	train.scale = Vector2(2.5, 2.5)
	train.position = SUB_O + Vector2(-600, 372)
	add_child(train)

## Switch between the street ("") and an interior; clamps the camera to that area.
func set_inside(room: String, at := player.position) -> void:
	inside = room
	var r: Rect2 = {"shop": SHOP_ROOM, "subway": SUB_ROOM}.get(room, Rect2(Vector2.ZERO, WORLD))
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.end.x)
	cam.limit_bottom = int(r.end.y)
	if zoom_tw:
		zoom_tw.kill()
	god_view = false
	cam.zoom = Vector2.ONE * 1.5
	player.position = at
	cam.reset_smoothing()

func interact() -> void:
	if player.frozen:
		return
	match act:
		"enter_shop":
			return_pos = player.position
			set_inside("shop", SHOP_EXIT - Vector2(0, 52))
		"enter_subway":
			station_i = act_i
			station_sign.text = stations[act_i].name
			set_inside("subway", SUB_EXIT + Vector2(0, 60))
		"exit":
			set_inside("", return_pos if inside == "shop" else stations[station_i].pos + Vector2(0, 62))

## F prompt shown through the context menu; "door" keeps the POI tag out of the way.
func set_act(a: String, head: String, row: String) -> void:
	act = a
	ctx = "door"
	show_menu(head, [[row, true]])

## Train pulls in, screen fades, the station room becomes station n, train leaves.
func travel(n: int) -> void:
	player.frozen = true
	sfx("subway")
	if train_tw:
		train_tw.kill()
	train_t = TRAIN_EVERY
	train.position.x = SUB_O.x - 600
	var tw := create_tween()
	tw.tween_property(train, "position:x", SUB_O.x + 576, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		if inside == "subway":  # dog may have blacked out mid-ride
			station_i = n
			station_sign.text = stations[n].name
			player.position = SUB_BOARD + Vector2(0, 40)
			cam.reset_smoothing())
	tw.tween_property(fade, "color:a", 0.0, 0.3)
	tw.tween_property(train, "position:x", SUB_O.x + 2400, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		player.frozen = false
		if inside == "subway":
			show_msg("Arrived at %s. Stairs lead up to the street." % stations[n].name))

func blocked(p: Vector2) -> bool:
	for r in building_rects:
		if r.has_point(p):
			return true
	return false

func nearest_tree(p: Vector2) -> Vector2:
	var best := trees[0]
	for t in trees:
		if p.distance_squared_to(t) < p.distance_squared_to(best):
			best = t
	return best

## Random walkable point at least min_dist from the dog; x < 0 if none found.
func random_spot(min_dist: float) -> Vector2:
	for attempt in 30:
		var p := Vector2(randf_range(48, WORLD.x - 48), randf_range(48, WORLD.y - 48))
		if p.distance_to(player.position) >= min_dist and not blocked(p):
			return p
	return Vector2(-1, -1)

func sfx(sound: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[sound]
	p.pitch_scale = randf_range(0.92, 1.08)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func float_text(pos: Vector2, text: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-20, -44)
	l.z_index = 20
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)

func poof(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 5
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.5
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

# ---------- systems ----------

## A train runs through the station every TRAIN_EVERY seconds; a dog on the tracks gets flung.
func update_train(delta: float) -> void:
	if inside != "subway":
		return
	if train_tw and train_tw.is_running() and not player.dead and player.position.y > SUB_O.y + 322 \
			and absf(player.position.x - train.position.x) < TRAIN_HALF + 10.0:
		train_hit()
	if player.frozen:
		return  # riding / dead: the schedule waits
	var before := train_t
	train_t -= delta
	if before > 3.0 and train_t <= 3.0:
		show_msg("Train approaching - stay off the tracks!")
	if train_t <= 0.0:
		train_t = TRAIN_EVERY
		sfx("subway")
		train.position.x = SUB_O.x - 600
		train_tw = create_tween()
		train_tw.tween_property(train, "position:x", SUB_O.x + 2400, 1.5)

func train_hit() -> void:
	player.dead = true  # no other damage while airborne; die() fires on landing
	player.frozen = true
	death_cause = "Flung by the train."
	shake_amt = 14.0
	sfx("hurt")
	var land := player.position + Vector2(420, -150)
	land.x = minf(land.x, SUB_ROOM.end.x - 30)
	var tw := create_tween()
	tw.tween_property(player, "position", land, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(player.sprite, "rotation", TAU * 3, 0.6)
	tw.tween_callback(player.die)

func respawn() -> void:
	death_panel.hide()
	name_edit.hide()
	player.respawn()
	set_inside("")
	get_tree().paused = stat_panel.visible

## New game: wipe the dog's progress (volume survives) and rebuild the scene.
func restart() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "volume", volume.value)
	cfg.save(save_path)
	get_tree().paused = false
	get_tree().reload_current_scene()

## Level-up picker: stays up (game paused) until every stat point is spent.
func show_stats() -> void:
	stat_panel.visible = player.points > 0
	get_tree().paused = stat_panel.visible or death_panel.visible
	stat_head.text = "LEVEL UP!   %d stat point%s" % [player.points, "" if player.points == 1 else "s"]
	for i in stat_buttons.size():
		stat_buttons[i].text = "[%d]  %s   (x%d)" % [i + 1, player.STATS[i][1], player.get(player.STATS[i][0])]

func pick_stat(i: int) -> void:
	player.spend(i)
	sfx("pickup")
	show_stats()
	save_game()

func add_car(pos: Vector2, dir: Vector2) -> void:
	var car: Node2D = CarScript.new()
	car.position = pos
	add_child(car)
	car.setup(dir, self)

func on_car_hit(_car: Node2D) -> void:
	death_cause = "Hit by a car."
	player.take_damage(CAR_DMG)
	shake_amt = 10.0
	if not player.dead:
		death_cause = "You blacked out."
		float_text(player.position, "HONK!", Color(1, 0.9, 0.3))

func quit_game() -> void:
	save_game()
	get_tree().quit()

func on_boss_woke(b: Node2D) -> void:
	boss = b
	boss_name.text = b.cfg.name
	show_banner(str(b.cfg.name).to_upper())
	sfx("bark")

func on_boss_left(b: Node2D) -> void:
	if boss == b:
		boss = null

func on_boss_beaten(b: Node2D) -> void:
	on_boss_left(b)
	player.treats += b.cfg.treats
	player.add_xp(b.cfg.xp)
	show_banner("%s DEFEATED" % str(b.cfg.name).to_upper())
	show_msg("+%d treats   +%d XP" % [b.cfg.treats, b.cfg.xp])
	poof(b.position, b.cfg.tint)
	sfx("levelup")

func update_steam(delta: float) -> void:
	for m in manholes:
		m.t -= delta
		if m.t <= 0.0:
			m.on = not m.on
			m.steam.emitting = m.on
			m.t = 1.5 if m.on else randf_range(3.5, 8.0)
			if m.on and player.position.distance_to(m.pos) < 500.0:
				sfx("steam")
		if m.on and player.position.distance_to(m.pos) < 38.0:
			player.take_damage(delta * 30.0)
			shake_amt = maxf(shake_amt, 2.0)

func check_pickups() -> void:
	for s in treat_sprites:
		if player.position.distance_to(s.position) < 26.0:
			player.treats += 1
			float_text(s.position, "+1 treat", Color(1, 0.85, 0.5))
			sfx("pickup")
			treat_sprites.erase(s)
			s.queue_free()
			return  # one per frame; list was mutated

func check_landmarks() -> void:
	for l in landmarks:
		if not l.seen and player.position.distance_to(l.pos) < 170.0:
			l.seen = true
			player.add_xp(50)
			show_msg("Discovered the %s!  +50 XP" % l.name)
			sfx("levelup")

func spawn_treat() -> void:
	var p := random_spot(200.0)
	if p.x < 0:
		return
	var s := Sprite2D.new()
	s.texture = tex.treat
	s.position = p
	s.scale = Vector2(2, 2)
	add_child(s)
	treat_sprites.append(s)

func spawn_prey() -> void:
	var kind := "pigeon"
	var pos := random_spot(350.0)
	var roll := randf()
	if roll < 0.3:  # squirrels live in parks
		kind = "squirrel"
		var r: Rect2 = parks.pick_random()
		pos = r.position + Vector2(randf(), randf()) * r.size
	elif roll < (0.75 if sun() < 0.3 else 0.55):  # rats by the trash, more at night
		kind = "rat"
		var can: Vector2 = cans.pick_random()
		pos = can + Vector2(randf_range(-60, 60), randf_range(10, 50))
	if pos.x < 0 or pos.distance_to(player.position) < 350.0:
		return
	for i in (3 if kind == "pigeon" else 1):  # pigeons flock
		var prey: Node2D = PreyScript.new()
		prey.position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)) * float(i > 0)
		add_child(prey)
		prey.setup(kind, PREY[kind], tex[kind], self)

func on_bite(center: Vector2, radius: float, dmg: float) -> void:
	sfx("bark")
	poof(center, Color(1, 1, 1, 0.7))
	for r in get_tree().get_nodes_in_group("raccoon"):
		if r.position.distance_to(center) < radius + 10.0:
			r.hurt(dmg, player.position)
	for b in get_tree().get_nodes_in_group("boss"):
		if b.position.distance_to(center) < radius + 34.0:  # bosses are big
			b.hurt(dmg, player.position)
	for p in get_tree().get_nodes_in_group("prey"):
		if p.position.distance_to(center) < radius:
			on_prey_caught(p)

func on_prey_caught(prey: Node2D) -> void:
	if prey.is_queued_for_deletion():
		return
	var cfg: Dictionary = prey.cfg
	player.treats += cfg.treats
	player.add_xp(cfg.xp)
	player.eat(cfg.food, 0.0)
	float_text(prey.position, "+%d treats" % cfg.treats, Color(1, 0.85, 0.5))
	poof(prey.position, Color(0.85, 0.85, 0.9))
	sfx("catch")
	prey.queue_free()

func on_prey_escaped(prey: Node2D) -> void:
	float_text(prey.position, "up the tree!", Color(0.7, 1, 0.7))
	prey.queue_free()

func on_raccoon_beaten(rac: Node2D) -> void:
	var loot := 3 + randi() % 4
	player.treats += loot
	player.add_xp(20 + player.level)
	float_text(rac.position, "Raccoon beaten! +%d treats" % loot, Color(1, 0.85, 0.5))
	poof(rac.position, Color(0.6, 0.6, 0.65))
	sfx("catch")

func on_number(n: int) -> void:
	if ctx == "bodega" and n < SHOP.size():
		var item: String = SHOP[n][0]
		var price: int = SHOP[n][1]
		if player.treats < price:
			show_msg("Need %d treats for that" % price)
			return
		player.treats -= price
		sfx("buy")
		if item == "collar":
			player.frozen = true
			name_edit.text = player.collar
			name_edit.show()
			name_edit.grab_focus()
		else:
			player.set(item, player.get(item) + 1)
			show_msg("Bought %s" % item)
		save_game()
	elif ctx == "subway" and n < stations.size():
		if n != station_i and not player.frozen:
			travel(n)

func on_name_entered(text: String) -> void:
	player.collar = text.strip_edges() if text.strip_edges() != "" else "Dog"
	player.apply_skin()
	player.frozen = false
	name_edit.release_focus()
	name_edit.hide()
	show_msg("New collar: %s" % player.collar)
	save_game()

# ---------- save ----------

func save_game() -> void:
	var cfg := ConfigFile.new()
	for key in SAVE_KEYS:
		cfg.set_value("dog", key, player.get(key))
	cfg.set_value("world", "seen", landmarks.filter(func(l): return l.seen).map(func(l): return l.name))
	cfg.set_value("ui", "volume", volume.value)
	cfg.save(save_path)

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	for key in SAVE_KEYS:
		player.set(key, cfg.get_value("dog", key, player.get(key)))
	if not cfg.has_section_key("dog", "points"):
		player.points = player.level - 1  # save from before stat points: pay them out now
	player.skin = clampi(player.skin, 0, player.BREEDS.size() - 1)
	player.level = clampi(player.level, 1, 100)
	volume.value = cfg.get_value("ui", "volume", 1.0)
	var seen: Array = cfg.get_value("world", "seen", [])
	for l in landmarks:
		l.seen = l.name in seen
	player.apply_skin()
	player.hp = player.max_hp

# ---------- HUD ----------
# Everything hangs off `hud` (full-rect) via anchors/containers, so it survives window resizes.

func hud_label(parent: Node, font_size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

func panel(alpha := 0.72) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, alpha)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	return p

func full(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

## Full-screen column pinning `c` to the top or bottom edge with a margin.
func dock(c: Control, bottom: bool, margin: float, h := Control.SIZE_SHRINK_CENTER) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END if bottom else BoxContainer.ALIGNMENT_BEGIN
	full(box)
	var gap := Control.new()
	gap.custom_minimum_size.y = margin
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = h
	box.add_child(c)
	box.add_child(gap)
	if not bottom:
		box.move_child(gap, 0)

func make_icon(kind: String, color: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(14, 14)
	c.draw.connect(draw_icon.bind(c, kind, color))
	return c

func draw_icon(c: Control, kind: String, color: Color) -> void:
	match kind:
		"hp":  # heart
			c.draw_circle(Vector2(4, 5), 3.5, color)
			c.draw_circle(Vector2(10, 5), 3.5, color)
			c.draw_colored_polygon(PackedVector2Array([Vector2(0.5, 6.5), Vector2(13.5, 6.5), Vector2(7, 13.5)]), color)
		"hunger":  # bone
			c.draw_line(Vector2(3, 11), Vector2(11, 3), color, 3.0)
			for p in [Vector2(2, 9.5), Vector2(4.5, 12), Vector2(9.5, 2), Vector2(12, 4.5)]:
				c.draw_circle(p, 2.2, color)
		"thirst":  # droplet
			c.draw_circle(Vector2(7, 9), 4.5, color)
			c.draw_colored_polygon(PackedVector2Array([Vector2(7, 0.5), Vector2(11, 7.5), Vector2(3, 7.5)]), color)
		"stamina":  # bolt
			c.draw_colored_polygon(PackedVector2Array([Vector2(8.5, 0), Vector2(2, 8), Vector2(6.5, 8),
				Vector2(5, 14), Vector2(12, 5.5), Vector2(7.5, 5.5)]), color)
		"xp":  # gem
			c.draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(14, 7), Vector2(7, 14), Vector2(0, 7)]), color)

func make_bar(parent: Control, key: String, color: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(make_icon(key, color))
	var b := Control.new()
	b.custom_minimum_size = Vector2(190, 13)
	b.draw.connect(draw_bar.bind(key))
	row.add_child(b)
	bars[key] = {"ctl": b, "color": color, "v": 1.0, "ghost": 1.0, "text": ""}

func set_bar(key: String, frac: float, delta: float, text := "") -> void:
	var b: Dictionary = bars[key]
	var v := clampf(frac, 0.0, 1.0)
	var ghost: float = b.ghost
	b.v = v
	b.ghost = maxf(v, move_toward(ghost, v, delta * 0.35))  # white trail shows how big the hit was
	b.text = text
	b.ctl.queue_redraw()

func draw_bar(key: String) -> void:
	var b: Dictionary = bars[key]
	var c: Control = b.ctl
	var col: Color = b.color
	var v: float = b.v
	var ghost: float = b.ghost
	var text: String = b.text
	if key == "stamina" and player.winded:
		col = Color(0.5, 0.5, 0.5)
	elif key in LOW_KEYS and v < LOW:
		col = col.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(0, 0, c.size.x * ghost, c.size.y), Color(1, 1, 1, 0.85))
	c.draw_rect(Rect2(0, 0, c.size.x * v, c.size.y), col)
	if text != "":
		c.draw_string_outline(ThemeDB.fallback_font, Vector2(0, c.size.y - 2), text, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 10, 3, Color.BLACK)
		c.draw_string(ThemeDB.fallback_font, Vector2(0, c.size.y - 2), text, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 10)

## Inventory slot: icon + count label. Returns the label.
func make_slot(parent: Control, t: Texture2D) -> Label:
	var box := HBoxContainer.new()
	parent.add_child(box)
	var icon := TextureRect.new()
	icon.texture = t
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	return hud_label(box, 14)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS  # pause menu keeps working while the tree is paused
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	fade = ColorRect.new()  # blackout for the subway ride
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# red screen-edge vignette for low HP / hunger / thirst
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.6, 1.0])
	grad.colors = PackedColorArray([Color(0.8, 0, 0, 0), Color(0.8, 0, 0, 0.5)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.15, 0.5)
	vignette = TextureRect.new()
	vignette.texture = gt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.modulate.a = 0.0
	full(vignette)

	# world-anchored bits: interact marker, drink ring, god's-eye icons
	overlay = full(Control.new())
	overlay.draw.connect(draw_overlay)
	for d in bodega_doors:
		pois.append({"pos": d, "text": "Shop", "color": Color(1, 0.55, 0.15)})
	for st in stations:
		pois.append({"pos": st.pos, "text": "Subway", "color": Color(0.3, 0.6, 1)})
	for w in water_spots:
		pois.append({"pos": w, "text": "Drink", "color": Color(0.5, 0.8, 1)})
	for b in get_tree().get_nodes_in_group("boss"):
		pois.append({"pos": b.home, "text": b.cfg.name, "color": BOSS_COLOR})

	# top-left: stats, inventory, clock
	var stats := panel()
	stats.position = Vector2(10, 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stats)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	stats.add_child(col)
	title = hud_label(col, 18)
	make_bar(col, "hp", Color(0.85, 0.2, 0.2))
	make_bar(col, "hunger", Color(0.9, 0.55, 0.15))
	make_bar(col, "thirst", Color(0.25, 0.55, 0.95))
	make_bar(col, "stamina", Color(0.9, 0.85, 0.2))
	make_bar(col, "xp", Color(0.65, 0.4, 0.9))
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 12)
	col.add_child(items)
	treat_label = make_slot(items, tex.treat)
	slots.purina = make_slot(items, tex.purina)
	slots.water = make_slot(items, tex.water_bowl)
	var time_row := HBoxContainer.new()
	col.add_child(time_row)
	clock = Control.new()
	clock.custom_minimum_size = Vector2(26, 26)
	clock.draw.connect(draw_clock)
	time_row.add_child(clock)
	info = hud_label(time_row, 14)

	# top-right: minimap + legend
	mini = Control.new()
	mini.size = Vector2(200, 200 * WORLD.y / WORLD.x + 34)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.draw.connect(draw_minimap)
	hud.add_child(mini)
	mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 10)

	# top-centre: level-up banner, breed card
	banner = hud_label(hud, 44, Color(1, 0.9, 0.3))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.offset_top = 150
	banner.modulate.a = 0.0
	card = panel()
	card_art = Control.new()
	card_art.custom_minimum_size = Vector2(280, 108)
	card_art.draw.connect(draw_card)
	card.add_child(card_art)
	card.hide()
	dock(card, false, 14)
	boss_box = panel()
	var bv := VBoxContainer.new()
	boss_box.add_child(bv)
	boss_name = hud_label(bv, 16, BOSS_COLOR)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	make_bar(bv, "boss", BOSS_COLOR)
	bars.boss.ctl.custom_minimum_size = Vector2(300, 14)
	boss_box.hide()
	dock(boss_box, false, 14)

	# bottom: toasts (left), shop / subway menu (centre)
	toasts = VBoxContainer.new()
	dock(toasts, true, 12, Control.SIZE_SHRINK_BEGIN)
	toasts.get_parent().offset_left = 12
	menu = panel()
	var rows := VBoxContainer.new()
	menu.add_child(rows)
	menu_head = hud_label(rows, 18, Color(1, 0.9, 0.4))
	for i in 4:
		menu_rows.append(hud_label(rows, 16))
	menu.hide()
	dock(menu, true, 60)

	# centre: collar name entry, pause menu
	var center := CenterContainer.new()
	full(center)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Name your dog, then Enter"
	name_edit.max_length = 12
	name_edit.custom_minimum_size = Vector2(260, 36)
	name_edit.visible = false
	name_edit.text_submitted.connect(on_name_entered)
	center.add_child(name_edit)
	pause_panel = panel(0.94)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pause_panel.add_child(pv)
	hud_label(pv, 24).text = "PAUSED"
	hud_label(pv, 14).text = "WASD / arrows   move\nShift   sprint\nSpace   bite\nQ / E   eat Purina / drink water\nTab   change breed\nM   god's-eye map\n1-4   shop and subway choices\nEsc   pause"
	hud_label(pv, 14).text = "Volume"
	volume = HSlider.new()
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = 1.0
	volume.value_changed.connect(func(v: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))))
	pv.add_child(volume)
	var resume := Button.new()
	resume.text = "Resume  [Esc]"
	resume.pressed.connect(set_paused.bind(false))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	resume.shortcut = Shortcut.new()
	resume.shortcut.events = [esc]  # only fires while the panel is visible
	pv.add_child(resume)
	restart_button(pv)
	var quit := Button.new()
	quit.text = "Save & Quit"
	quit.pressed.connect(quit_game)
	pv.add_child(quit)
	pause_panel.hide()
	center.add_child(pause_panel)

	death_panel = panel(0.94)
	var dv := VBoxContainer.new()
	dv.name = "Box"
	dv.add_theme_constant_override("separation", 10)
	death_panel.add_child(dv)
	var dead_head := hud_label(dv, 32, Color(0.95, 0.2, 0.2))
	dead_head.text = "YOU DIED"
	dead_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_why = hud_label(dv, 14)
	death_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var again := Button.new()
	again.name = "Respawn"
	again.text = "Respawn"
	again.pressed.connect(respawn)
	dv.add_child(again)
	restart_button(dv)
	var give_up := Button.new()
	give_up.text = "Save & Quit"
	give_up.pressed.connect(quit_game)
	dv.add_child(give_up)
	death_panel.hide()
	center.add_child(death_panel)

	stat_panel = panel(0.94)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	stat_panel.add_child(sv)
	stat_head = hud_label(sv, 24, Color(1, 0.9, 0.3))
	for i in player.STATS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE  # mashing Space (bite) must not pick a stat
		b.pressed.connect(pick_stat.bind(i))
		var key := InputEventKey.new()
		key.keycode = (KEY_1 + i) as Key
		b.shortcut = Shortcut.new()
		b.shortcut.events = [key]
		sv.add_child(b)
		stat_buttons.append(b)
	stat_panel.hide()
	center.add_child(stat_panel)

## Wipes the save, so it takes two clicks; re-arms whenever its panel reopens.
func restart_button(parent: Control) -> void:
	var b := Button.new()
	b.text = "Restart (new game)"
	b.pressed.connect(func():
		if b.text.begins_with("Sure"):
			restart()
		else:
			b.text = "Sure? Wipes your save - click again")
	b.visibility_changed.connect(func(): b.text = "Restart (new game)")
	parent.add_child(b)

func set_paused(on: bool) -> void:
	get_tree().paused = on
	pause_panel.visible = on

## Toast queue: newest at the bottom, max 3, each fades on its own.
func show_msg(text: String) -> void:
	if toasts.get_child_count() >= 3:
		toasts.get_child(0).free()
	var l := hud_label(toasts, 18, Color(1, 0.9, 0.4))
	l.text = text
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	if banner_tw:
		banner_tw.kill()
	banner_tw = create_tween()
	banner_tw.tween_interval(1.2)
	banner_tw.tween_property(banner, "modulate:a", 0.0, 0.6)

func show_menu(head: String, rows: Array) -> void:  # rows: [[text, enabled], ...]
	menu.show()
	menu_head.text = head
	for i in menu_rows.size():
		menu_rows[i].visible = i < rows.size()
		if i < rows.size():
			menu_rows[i].text = rows[i][0]
			menu_rows[i].modulate = Color(0.6, 1, 0.7) if rows[i][1] else Color(0.6, 0.6, 0.6)

func update_hud(delta: float) -> void:
	title.text = "%s   Lv %d" % [player.display_name(), player.level]
	set_bar("hp", player.hp / player.max_hp, delta, "%d / %d" % [ceili(player.hp), int(player.max_hp)])
	set_bar("hunger", player.hunger / 100.0, delta)
	set_bar("thirst", player.thirst / 100.0, delta)
	set_bar("stamina", player.stamina / 100.0, delta, "winded" if player.winded else "")
	set_bar("xp", float(player.xp) / player.xp_needed(), delta, "%d / %d" % [player.xp, player.xp_needed()])
	var low: float = minf(player.hp / player.max_hp, minf(player.hunger, player.thirst) / 100.0)
	vignette.modulate.a = 0.0 if low >= LOW else \
		(0.4 + 0.6 * (1.0 - low / LOW)) * (0.7 + 0.3 * sin(Time.get_ticks_msec() / 180.0))

	if player.treats != last_treats:
		if last_treats >= 0:  # pop green on gain, red on spend
			treat_label.modulate = Color(0.5, 1, 0.5) if player.treats > last_treats else Color(1, 0.45, 0.45)
			treat_label.scale = Vector2.ONE * 1.5
			var tw := create_tween().set_parallel()
			tw.tween_property(treat_label, "scale", Vector2.ONE, 0.25)
			tw.tween_property(treat_label, "modulate", Color.WHITE, 0.4)
		last_treats = player.treats
		treat_label.text = "x%d" % player.treats
	for item in ["purina", "water"]:
		var n: int = player.get(item)
		var l: Label = slots[item]
		l.text = "x%d [%s]" % [n, "Q" if item == "purina" else "E"]
		l.get_parent().modulate.a = 1.0 if n > 0 else 0.4
	var mins := int(tod * 1440.0)
	info.text = "%02d:%02d" % [mins / 60, mins % 60]
	if player.sprinting:
		info.text += "   %d mph" % int(player.velocity.length() / player.PX_PER_MPH)
	clock.queue_redraw()
	card_t -= delta
	card.visible = card_t > 0.0 and boss == null  # boss bar uses the same spot
	boss_box.visible = boss != null
	if boss:
		set_bar("boss", boss.hp / boss.max_hp, delta, "%d / %d" % [ceili(boss.hp), int(boss.max_hp)])

	ctx = ""
	drinking = false
	menu.hide()
	for w in water_spots:
		if player.position.distance_to(w) < 40.0:
			player.drink(delta * 30.0)
			drinking = true
	act = ""
	var at := player.position
	if player.frozen:
		pass  # riding the train or typing a name: no prompts
	elif inside == "shop":
		if at.distance_to(SHOP_EXIT) < 36.0:
			set_act("exit", "BODEGA", "[F]  Back to the street")
		elif at.distance_to(SHOP_COUNTER) < 60.0:
			ctx = "bodega"
			var rows := []
			for i in SHOP.size():
				rows.append(["[%d]  %s   %d treats" % [i + 1, SHOP_INFO[SHOP[i][0]], SHOP[i][1]],
					player.treats >= SHOP[i][1]])
			show_menu("BODEGA   you have %d treats" % player.treats, rows)
	elif inside == "subway":
		if at.distance_to(SUB_EXIT) < 45.0:
			set_act("exit", "%s STATION" % stations[station_i].name.to_upper(), "[F]  Stairs up to the street")
		elif at.distance_to(SUB_BOARD) < 50.0:
			ctx = "subway"
			var rows := []
			for k in stations.size():
				rows.append(["[%d]  %s%s" % [k + 1, stations[k].name, "   (you are here)" if k == station_i else ""], k != station_i])
			show_menu("SUBWAY MAP", rows)
	else:
		for d in bodega_doors:
			if at.distance_to(d) < 70.0:
				set_act("enter_shop", "BODEGA", "[F]  Go inside")
		for i in stations.size():
			if at.distance_to(stations[i].pos) < 50.0:
				act_i = i
				set_act("enter_subway", "SUBWAY   %s" % stations[i].name, "[F]  Take the stairs down")

	marker = {}
	var best := 260.0
	for poi in pois:
		var d: float = player.position.distance_to(poi.pos)
		if d < best and not (poi.text == "Drink" and (drinking or player.thirst > 60.0)):
			best = d
			marker = poi
	overlay.queue_redraw()

func draw_overlay() -> void:
	var xf := get_canvas_transform()  # world -> screen
	var font := ThemeDB.fallback_font
	if drinking:
		overlay.draw_arc(xf * player.position, 30.0, -PI / 2, -PI / 2 + TAU * player.thirst / 100.0, 40, Color(0.35, 0.7, 1), 4.0)
	if god_view:
		for poi in pois:
			if poi.text != "Drink":
				overlay.draw_circle(xf * poi.pos, 6.0, poi.color)
		for l in landmarks:
			overlay.draw_circle(xf * l.pos, 6.0, Color.WHITE)
		for r in get_tree().get_nodes_in_group("raccoon"):
			if r.visible:
				overlay.draw_circle(xf * r.position, 5.0, Color(1, 0.2, 0.2))
	elif ctx == "" and not marker.is_empty():
		var text: String = marker.text
		var p: Vector2 = xf * marker.pos + Vector2(0, -70 + sin(Time.get_ticks_msec() / 250.0) * 4.0)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		overlay.draw_rect(Rect2(p.x - w / 2 - 5, p.y - 14, w + 10, 19), Color(0, 0, 0, 0.65))
		overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 5), p + Vector2(5, 5), p + Vector2(0, 11)]), Color(0, 0, 0, 0.65))
		overlay.draw_string(font, Vector2(p.x - w / 2, p.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, marker.color)

func draw_clock() -> void:
	var c := clock.size / 2.0
	var r := c.x
	clock.draw_circle(c, r, Color(0.1, 0.12, 0.3).lerp(Color(0.45, 0.72, 1.0), sun()))
	var a := (tod - 0.5) * TAU
	var dir := Vector2(sin(a), -cos(a))  # sun straight up at noon
	clock.draw_circle(c + dir * r * 0.55, 4.0, Color(1, 0.85, 0.2))
	clock.draw_circle(c - dir * r * 0.55, 3.0, Color(0.85, 0.88, 1))  # moon opposite
	var horizon := PackedVector2Array()  # lower half hides whichever one has set
	for i in 13:
		horizon.append(c + Vector2.RIGHT.rotated(PI * i / 12.0) * r)
	clock.draw_colored_polygon(horizon, Color(0.12, 0.14, 0.12))
	clock.draw_arc(c, r, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.0)

## Breed card: sprite, name, stat bars with a tick + delta against the previous breed.
func draw_card() -> void:
	var b: Dictionary = player.breed()
	var old: Dictionary = player.BREEDS[prev_skin]
	var font := ThemeDB.fallback_font
	var t: Texture2D = player.sprite.texture
	var frame := Vector2(t.get_width() / 2.0, t.get_height())
	card_art.draw_texture_rect_region(t, Rect2(4, 14, 64, 64 * frame.y / frame.x), Rect2(Vector2.ZERO, frame))
	card_art.draw_string(font, Vector2(84, 18), str(b.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var y := 32.0
	for stat in [["mph", "Speed"], ["hp", "HP"], ["atk", "Bite"]]:
		var k: String = stat[0]
		var top: float = player.BREEDS.map(func(x): return x[k]).max()
		var v: float = b[k]
		var was: float = old[k]
		card_art.draw_string(font, Vector2(84, y + 10), "%s %d" % [stat[1], int(v)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		card_art.draw_rect(Rect2(150, y, 90, 10), Color(0, 0, 0, 0.55))
		card_art.draw_rect(Rect2(150, y, 90 * v / top, 10), Color(0.6, 1, 0.7))
		card_art.draw_line(Vector2(150 + 90 * was / top, y - 2), Vector2(150 + 90 * was / top, y + 12), Color.WHITE, 2.0)
		if v != was:
			card_art.draw_string(font, Vector2(246, y + 10), "%+d" % int(v - was), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.5, 1, 0.5) if v > was else Color(1, 0.45, 0.45))
		y += 20.0
	card_art.draw_string(font, Vector2(84, 104), "[Tab] next breed   | = previous", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))

func draw_minimap() -> void:
	var font := ThemeDB.fallback_font
	var s := mini.size.x / WORLD.x
	var h := WORLD.y * s
	mini.draw_rect(Rect2(Vector2.ZERO, mini.size), Color(0.08, 0.08, 0.1, 0.8))
	for by in NY:
		for bx in NX:
			var b := Vector2i(bx, by)
			var col := Color(0.3, 0.6, 0.3) if b in PARKS else Color(0.45, 0.45, 0.48)
			mini.draw_rect(Rect2(block_origin(b) * s, BLOCK * s), col)
	for p in get_tree().get_nodes_in_group("prey"):
		if p.position.distance_to(player.position) < 700.0:
			mini.draw_circle(p.position * s, 1.5, Color(0.9, 0.9, 0.9))
	for r in get_tree().get_nodes_in_group("raccoon"):
		if r.visible:
			mini.draw_circle(r.position * s, 2.5, Color(1, 0.2, 0.2))
	for poi in pois:
		if poi.text != "Drink":
			mini.draw_circle(poi.pos * s, 3.0, poi.color)
	for l in landmarks:
		mini.draw_circle(l.pos * s, 3.0, Color.WHITE)
	if ctx == "subway":  # number the destinations the menu offers
		for i in stations.size():
			var sp: Vector2 = stations[i].pos * s
			mini.draw_arc(sp, 6.0, 0, TAU, 16, Color.WHITE, 1.5)
			mini.draw_string(font, sp + Vector2(8, 4), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var dog := player.position  # indoors: show the door / station the dog went in through
	if inside == "shop":
		dog = return_pos
	elif inside == "subway":
		dog = stations[station_i].pos
	var c := dog * s
	var a: float = player.facing.angle()
	mini.draw_colored_polygon(PackedVector2Array([c + Vector2(6, 0).rotated(a),
		c + Vector2(-4, 4).rotated(a), c + Vector2(-4, -4).rotated(a)]), Color(1, 0.9, 0.2))
	mini.draw_rect(Rect2(Vector2.ZERO, mini.size), Color(1, 1, 1, 0.6), false, 1.0)
	var x := 6.0
	for e in [["shop", Color(1, 0.55, 0.15)], ["subway", Color(0.3, 0.6, 1)], ["sight", Color.WHITE], ["raccoon", Color(1, 0.2, 0.2)]]:
		var word: String = e[0]
		mini.draw_circle(Vector2(x + 3, h + 10), 3.0, e[1])
		mini.draw_string(font, Vector2(x + 9, h + 14), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		x += 16.0 + font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	mini.draw_string(font, Vector2(6, h + 28), "[M] god's-eye map   [Esc] pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
