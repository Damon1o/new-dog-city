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
const CAR_DMG := 30.0
const MAX_PREY := 36
const MAX_TREATS := 25

const PreyScript := preload("res://scripts/prey.gd")
const RaccoonScript := preload("res://scripts/raccoon.gd")
const BossScript := preload("res://scripts/boss.gd")
const CarScript := preload("res://scripts/car.gd")
const HedgehogScript := preload("res://scripts/hedgehog.gd")
const Save := preload("res://scripts/systems/save.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Subway := preload("res://scripts/world/subway.gd")
const CityBuilder := preload("res://scripts/world/city_builder.gd")
const Quests := preload("res://scripts/systems/quests.gd")
const Items := preload("res://scripts/data/items.gd")
const BOSSES := preload("res://scripts/data/bosses.gd").BOSSES
const PREY := Items.PREY
const SHOP := Items.SHOP
const SHOP_INFO := Items.SHOP_INFO

const TEX_NAMES := ["road", "sidewalk", "grass", "building_a", "building_b", "building_c",
	"empire_state", "chrysler", "bodega", "subway", "trashcan", "manhole", "water_bowl",
	"pigeon", "rat", "squirrel", "raccoon", "treat", "tree", "fountain", "hydrant", "purina",
	"cat", "shop_floor", "shop_wall", "shelf", "counter", "station_wall", "platform", "track",
	"pillar", "stairs", "map_board", "train"]

const BOSS_COLOR := Color(0.85, 0.3, 1)
const TRAIN_EVERY := 20.0  # seconds between through-trains in the subway
const TRAIN_HALF := 480.0  # half the train's length: 4 cars * 96 px * 2.5 / 2
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
const BOSS_O := Vector2(6000, 4000)
const BOSS_ROOM := Rect2(BOSS_O, Vector2(960, 640))
const BOSS_EXIT := BOSS_O + Vector2(480, 624)
const BOSS_LEVEL_LOSS := 10  # levels lost when the Boss Hedgehog beats the dog

const PARKS := [Vector2i(2, 2), Vector2i(5, 0), Vector2i(0, 3), Vector2i(4, 4)]
const BODEGAS := [Vector2i(3, 2), Vector2i(0, 0), Vector2i(5, 3)]
const LANDMARKS := {Vector2i(3, 1): ["empire_state", "Empire State Building"],
	Vector2i(1, 1): ["chrysler", "Chrysler Building"]}
const STATIONS := {Vector2i(4, 0): "Uptown", Vector2i(2, 1): "Midtown",
	Vector2i(1, 4): "Downtown", Vector2i(5, 2): "East Side"}

var tex := {}
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
var save_version := 2  # version of the file last loaded (1 = before meta/version)
var save_extra := {}  # v2 keys no system owns yet, see Save.V2
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
var hedgehog: Node2D  # final boss, lives in the den
var burrow := Vector2.ZERO  # street entrance to the boss den
var stats := {}       # quest counters, saved
var quest_step := {}  # quest line -> index of its current step, saved
var quest_label: Label
var skip_btn: Button

var ground: Node2D
var night: CanvasModulate
var hud: Control  # HUD root Control (built by ui)
var ui: Node  # scripts/ui/hud.gd
var subway: Node  # scripts/world/subway.gd
var city: Node  # scripts/world/city_builder.gd
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
var volume: HSlider  # Master; same slider as vols.Master
var vols := {}  # bus name -> HSlider
var name_edit: LineEdit

@onready var player: CharacterBody2D = $Player
@onready var cam: Camera2D = $Player/Camera2D

func _ready() -> void:
	for n in TEX_NAMES:
		tex[n] = load("res://assets/%s.png" % n)
	for m: Array in [["city", CityBuilder], ["subway", Subway]]:
		var n: Node = m[1].new()
		n.g = self
		add_child(n)
		set(m[0], n)
	y_sort_enabled = true
	ground = Node2D.new()
	ground.z_index = -10
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.draw.connect(draw_ground)
	add_child(ground)
	night = CanvasModulate.new()
	add_child(night)

	burrow = block_origin(PARKS[3]) + Vector2(110, 300)
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
		show_stats()
		check_quests())
	player.hit.connect(func():
		shake_amt = 6.0
		sfx("hurt"))
	player.died.connect(func():
		if inside == "boss":
			hedgehog.stop()
			var lost := mini(BOSS_LEVEL_LOSS, player.level - 1)
			player.level -= lost
			player.xp = 0
			death_cause = "The Boss Hedgehog flattened you... lost %d levels." % lost
		death_why.text = death_cause + "\nLost half your treats."
		death_cause = "You blacked out."
		fade.color.a = 0.0  # in case the dog starved mid-ride
		death_panel.show()
		death_panel.get_node("Box/Respawn").grab_focus()
		get_tree().paused = true
		save_game())

	build_hud()
	load_game()
	check_quests()
	show_stats()
	for i in 12:
		spawn_prey()
		spawn_treat()
	show_msg("Press Esc for controls")

func _process(delta: float) -> void:
	tod = fmod(tod + delta / DAY_LENGTH, 1.0)
	night.color = {"shop": Color(1, 0.96, 0.88), "subway": Color(0.8, 0.86, 0.82), "boss": Color(0.85, 0.78, 0.7)}.get(
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
	if player.velocity != Vector2.ZERO:
		bump("sprinted" if player.sprinting else "moved", true)
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

## Left click attacks toward the cursor. _input, not _unhandled_input: the full-screen
## HUD controls would swallow the click. This node is paused while the pause menu is up.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not player.frozen:
		var dir := player.position.direction_to(get_canvas_transform().affine_inverse() * event.position)
		if dir != Vector2.ZERO:
			player.facing = dir
			player.sprite.flip_h = dir.x < 0.0
		player.bite()

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
				bump("map", true)
				zoom_tw = create_tween()
				zoom_tw.tween_property(cam, "zoom", Vector2.ONE * (0.3 if god_view else 1.5), 0.4)
		KEY_1, KEY_2, KEY_3, KEY_4:
			on_number(event.keycode - KEY_1)

func sun() -> float:
	return clampf(sin((tod - 0.25) * TAU) * 1.5 + 0.6, 0.0, 1.0)

# ---------- world building ----------

# ---------- helpers ----------

## Switch between the street ("") and an interior; clamps the camera to that area.
func set_inside(room: String, at := player.position) -> void:
	inside = room
	var r: Rect2 = {"shop": SHOP_ROOM, "subway": SUB_ROOM, "boss": BOSS_ROOM}.get(room, Rect2(Vector2.ZERO, WORLD))
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
			bump("shop", true)
		"enter_subway":
			station_i = act_i
			station_sign.text = stations[act_i].name
			set_inside("subway", SUB_EXIT + Vector2(0, 60))
		"enter_boss":
			set_inside("boss", BOSS_EXIT - Vector2(0, 52))
			hedgehog.start()
			bump("burrow", true)
		"exit":
			hedgehog.stop()  # fleeing the den resets the fight
			set_inside("", {"shop": return_pos, "boss": burrow + Vector2(0, 50)}.get(
				inside, stations[station_i].pos + Vector2(0, 62)))

## F prompt shown through the context menu; "door" keeps the POI tag out of the way.
func set_act(a: String, head: String, row: String) -> void:
	act = a
	ctx = "door"
	show_menu(head, [[row, true]])

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
	Sound.sfx(sound)

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
			bump("sights")

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

## Three claw marks that pop at the hit point, facing the attack, then fade.
func scratch(center: Vector2, dir: Vector2) -> void:
	var n := Node2D.new()
	n.position = center
	n.rotation = dir.angle()
	n.z_index = 6
	n.scale = Vector2(0.4, 0.4)
	for i in 3:
		var x := (i - 1) * 10.0
		for stroke in [[6.0, Color(0.75, 0.1, 0.1)], [3.0, Color(1, 0.96, 0.9)]]:  # red edge, white core
			var l := Line2D.new()
			l.points = PackedVector2Array([Vector2(x + 12, -18), Vector2(x - 12, 18)])
			l.width = stroke[0]
			l.default_color = stroke[1]
			l.begin_cap_mode = Line2D.LINE_CAP_ROUND
			l.end_cap_mode = Line2D.LINE_CAP_ROUND
			n.add_child(l)
	add_child(n)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(n, "modulate:a", 0.0, 0.2)
	tw.tween_callback(n.queue_free)

func on_bite(center: Vector2, radius: float, dmg: float) -> void:
	sfx("bark")
	scratch(center, player.facing)
	hedgehog.hurt(center, radius, dmg)
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
	if prey.kind == "squirrel":
		bump("squirrels")
	bump("prey")

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
	bump("raccoons")

func on_hedgehog_beaten(at: Vector2) -> void:
	show_banner("BOSS HEDGEHOG DEFEATED")
	sfx("levelup")
	poof(at, Color(0.45, 0.3, 0.18))
	player.treats += 50
	float_text(at, "+50 treats", Color(1, 0.85, 0.5))
	show_msg("The den is yours. The door leads back to the street.")
	bump("boss")
	save_game()

# ---------- quests ----------

func bump(key: String, once := false) -> void:
	Quests.bump(self, key, once)

func stat(key: String) -> int:
	return Quests.stat(self, key)

func tutorial_on() -> bool:
	return Quests.tutorial_on(self)

func check_quests() -> void:
	Quests.check(self)

func quest_text() -> String:
	return Quests.text(self)

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
		bump("bought")
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
	Save.write(self)

func load_game() -> void:
	Save.read(self)

# ---------- HUD (scripts/ui/hud.gd) ----------

func build_hud() -> void:
	ui = Hud.new()
	ui.g = self
	add_child(ui)
	ui.build_hud()

func update_hud(delta: float) -> void:
	ui.update_hud(delta)
	update_prompts(delta)

func set_paused(on: bool) -> void:
	ui.set_paused(on)

func show_msg(text: String) -> void:
	ui.show_msg(text)

func show_banner(text: String) -> void:
	ui.show_banner(text)

func show_menu(head: String, rows: Array) -> void:
	ui.show_menu(head, rows)

## Interact prompts, drinking and the nearest-POI marker for this frame.
func update_prompts(delta: float) -> void:
	ctx = ""
	drinking = false
	menu.hide()
	for w in water_spots:
		if player.position.distance_to(w) < 40.0:
			player.drink(delta * 30.0)
			drinking = true
			bump("drank", true)
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
	elif inside == "boss":
		if at.distance_to(BOSS_EXIT) < 40.0:
			set_act("exit", "HEDGEHOG DEN", "[F]  Flee to the street" if hedgehog.active else "[F]  Back to the street")
	else:
		if at.distance_to(burrow) < 50.0:
			set_act("enter_boss", "HEDGEHOG BURROW   final boss, 3 waves",
				"[F]  Challenge the Boss Hedgehog  (lose %d levels if you fall)" % BOSS_LEVEL_LOSS)
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

# ---------- scripts/world/city_builder.gd ----------

func block_origin(b: Vector2i) -> Vector2:
	return city.block_origin(b)

func draw_ground() -> void:
	city.draw_ground()

func build_bounds() -> void:
	city.build_bounds()

func build_block(b: Vector2i) -> void:
	city.build_block(b)

func place_manholes() -> void:
	city.place_manholes()

func build_interiors() -> void:
	city.build_interiors()

# ---------- scripts/world/subway.gd ----------

func travel(n: int) -> void:
	subway.travel(n)

func update_train(delta: float) -> void:
	subway.update_train(delta)
