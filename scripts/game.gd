extends Node2D
## New Dog City — procedural Manhattan grid, animals, HUD, bodega, subway,
## steam, day/night, minimap / god's-eye view, autosave.

const NYC: Dictionary = preload("res://scripts/data/cities.gd").CITIES.nyc  # only city so far
const BLOCK: Vector2 = NYC.block
const ROAD := 128.0
const NX: int = NYC.grid.x
const NY: int = NYC.grid.y
const WORLD := Vector2(NX * BLOCK.x + (NX + 1) * ROAD, NY * BLOCK.y + (NY + 1) * ROAD)  # 5888 x 3712; the old 6 x 5 is the top-left
const DAY_LENGTH := 240.0
const CAR_DMG := 30.0
const MAX_PREY := 36  # tuned for the old 6 x 5 map; Spawns.cap() scales it by area
const Spawns := preload("res://scripts/data/spawns.gd")
const MAX_TREATS := 25

const PreyScript := preload("res://scripts/prey.gd")
const RaccoonScript := preload("res://scripts/raccoon.gd")
const BossScript := preload("res://scripts/boss.gd")
const CarScript := preload("res://scripts/car.gd")
const HedgehogScript := preload("res://scripts/hedgehog.gd")
const Save := preload("res://scripts/systems/save.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Street := preload("res://scripts/world/street.gd")
const Spawner := preload("res://scripts/world/spawner.gd")
const Fx := preload("res://scripts/world/fx.gd")
const Subway := preload("res://scripts/world/subway.gd")
const Territory := preload("res://scripts/systems/territory.gd")
const CityBuilder := preload("res://scripts/world/city_builder.gd")
const Interior := preload("res://scripts/world/interior.gd")
const Rooms := preload("res://scripts/data/rooms.gd")
const Quests := preload("res://scripts/systems/quests.gd")
const XP := preload("res://scripts/systems/xp.gd")
const Weather := preload("res://scripts/systems/weather.gd")
const Items := preload("res://scripts/data/items.gd")
const Economy := preload("res://scripts/systems/economy.gd")
const ShopUi := preload("res://scripts/ui/shop.gd")
const InventoryUi := preload("res://scripts/ui/inventory.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const Look := preload("res://scripts/ui/theme.gd")
const KeybindsUi := preload("res://scripts/ui/keybinds.gd")
const Wanted := preload("res://scripts/systems/wanted.gd")
const Pound := preload("res://scripts/world/pound.gd")
var pound: Node  # scripts/world/pound.gd: cell, fine, breakout (wanted.caught)
var wanted: Node  # scripts/systems/wanted.gd: heat, stars, animal control (add_heat)
var keybinds: Node  # scripts/ui/keybinds.gd (Settings > Key bindings)
var inventory: Node  # scripts/ui/inventory.gd (E bag, K stats)
var wardrobe: Node  # scripts/ui/wardrobe.gd (B)
var stocks: Node  # scripts/systems/stocks.gd: NYSE ticks, news, trades, stock app (P)
const DialogUi := preload("res://scripts/ui/dialog.gd")
var dialog: Node  # scripts/ui/dialog.gd (dialog box + cutscenes)
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

# Interiors (scripts/world/interior.gd) are built one at a time far off the street map.
const WALL_H := 96.0
const BOSS_EXIT := Interior.O + Vector2(480, 624)  # burrow exit spot; tools/smoke_test.gd parks the dog by it

const PARKS: Array = NYC.parks
const BODEGAS: Array = NYC.bodegas
const LANDMARKS: Dictionary = NYC.landmarks
const STATIONS: Dictionary = NYC.stations

var tex := {}
var building_rects: Array[Rect2] = []
var parks: Array[Rect2] = []
var trees: Array[Vector2] = []
var cans: Array[Vector2] = []
var water_spots: Array[Vector2] = []
var bodega_doors: Array[Vector2] = []
var doors: Array[Dictionary] = []      # every street door {pos, template, id, seed, floors, name}
var door := {}                         # the door under the dog right now (F enters it)
var stations: Array[Dictionary] = []   # {pos, name}
var landmarks: Array[Dictionary] = []  # {pos, name, seen}
var manholes: Array[Dictionary] = []   # {pos, steam, t, on}
var treat_sprites: Array[Sprite2D] = []

var tod := 0.33  # time of day 0..1, 0.5 = noon
var ctx := ""    # "bodega" / "subway" — what number keys do right now; "door" = F prompt showing
var inside := ""  # "" street / "shop" / "subway"
var act := ""     # what F does right now
var return_pos := Vector2.ZERO  # street door the dog went in by; leaving puts it back there
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
var rng_seed := 0  # 0 = random cars / prey / rolls; the smoke test pins one (city.build reseeds the global RNG)
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
var street: Node  # scripts/world/street.gd
var spawner: Node  # scripts/world/spawner.gd
var fx: Node  # scripts/world/fx.gd
var subway: Node  # scripts/world/subway.gd
var territory: Node2D  # scripts/systems/territory.gd (G: pee markers)
var city: Node  # scripts/world/city_builder.gd
var interior: Node  # scripts/world/interior.gd
var flashback: Node  # scripts/world/flashback.gd
var hq: Node  # scripts/world/hq_floor.gd (M5-4 puzzle floors)
var weather: Node  # scripts/systems/weather.gd
var economy: Node  # scripts/systems/economy.gd
var shop: Node  # scripts/ui/shop.gd
var cats: Node  # scripts/world/bodega_cats.gd (friendly bodega cats, M4-3)
var steps: Node  # scripts/systems/footsteps.gd (M3-5 footsteps by surface, ambience)
var trader: Node  # scripts/world/trader.gd (Pocket, M4-8)
var bars := {}   # key -> {ctl, color, v, ghost, text}
var slots := {}  # item -> count Label
var abilities := {}  # ability bar: name -> {ctl, key, v (cooldown left, 0..1)}
var pois: Array[Dictionary] = []  # {pos, text, color} — shops, stations, water
var marker := {}                  # nearest poi, drawn as a floating tag
var waypoint := {}                # GPS target (M2-5): a poi / landmark dict, {} = none
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
	for m: Array in [["city", CityBuilder], ["interior", Interior], ["subway", Subway], ["fx", Fx], ["spawner", Spawner], ["street", Street], ["weather", Weather], ["economy", Economy], ["wanted", Wanted], ["pound", Pound], ["territory", Territory], ["flashback", preload("res://scripts/world/flashback.gd")],
			["stocks", preload("res://scripts/systems/stocks.gd")]]:
		var n: Node = m[1].new()
		n.g = self
		add_child(n)
		set(m[0], n)
	cats = preload("res://scripts/world/bodega_cats.gd").new()
	cats.g = self
	add_child(cats)
	trader = preload("res://scripts/world/trader.gd").new()
	trader.g = self
	add_child(trader)
	hq = preload("res://scripts/world/hq_floor.gd").new()  # M5-4
	hq.g = self
	add_child(hq)
	steps = preload("res://scripts/systems/footsteps.gd").new()  # M3-5 footsteps + ambience
	steps.g = self
	add_child(steps)
	add_child(preload("res://scripts/systems/scent.gd").new())  # M5-3 scent trail (V), node "Scent"
	y_sort_enabled = true
	ground = Node2D.new()
	ground.z_index = -10
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.draw.connect(draw_ground)
	add_child(ground)
	night = CanvasModulate.new()
	add_child(night)

	burrow = block_origin(PARKS[3]) + Vector2(110, 300)
	city.build("nyc")
	hedgehog = HedgehogScript.new()
	add_child(hedgehog)
	hedgehog.setup(self, Rect2(Interior.O, Rooms.ROOMS.burrow.size))
	if rng_seed:
		seed(rng_seed)
	else:
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
	Sound.music("", Sound.BOSS)  # a restart mid-fight leaves no boss theme behind
	set_inside("")
	player.leveled.connect(func():
		show_banner("LEVEL %d" % player.level)
		sfx("levelup")
		show_msg("+%d stat points - spend them in Stats [%s]" % [XP.points_for(player.level), Keys.label("stats")])
		show_stats()
		check_quests())
	player.hit.connect(func():
		shake_amt = 6.0
		sfx("hurt"))
	player.died.connect(func():
		if wanted.jails_on_death():  # spec 08: HP 0 at 1+ stars = the pound, no death screen
			player.respawn()
			wanted.caught()
			return
		if inside == "boss":
			hedgehog.stop()
			player.treats = mini(player.treats, 20)  # spec 06: the hedgehog keeps treats above 20
			death_cause = "Daven the Hedgehog flattened you... it kept your treats over 20."
		death_why.text = death_cause + "\nLost half your treats."
		death_cause = "You blacked out."
		fade.color.a = 0.0  # in case the dog starved mid-ride
		death_panel.show()
		death_panel.get_node("Box/Respawn").grab_focus()
		get_tree().paused = true
		save_game())

	Story.waypoint_changed.connect(func(p: Vector2):  # "Find XP" (gate popup) drives the same GPS arrow
		waypoint = {} if p == Story.NO_TARGET else {"pos": p, "text": "Find XP", "color": Color(1, 0.9, 0.2)})
	Keys.apply({})  # defaults first so the HUD can show key names; the save overrides below
	build_hud()
	load_game()
	get_tree().node_added.connect(func(n: Node):  # labels built later (menus, toasts) scale too
		if save_extra.get("ui/large_text", false) and is_ancestor_of(n):
			Look.big_text(n, true))
	Look.set_big_text(self, save_extra.get("ui/large_text", false))
	Keys.apply(save_extra.get("ui/keys", {}))
	check_quests()
	show_stats()
	for i in 12:
		spawn_prey()
		spawn_treat()
	show_msg("Press Esc for controls")
	if not Story.has("cs_intro"):  # ponytail: old saves see it once too; gate on a fresh dog if that annoys
		dialog.play("cs_intro")
	elif get_tree().root.get_meta("open", "") == "wardrobe":  # home screen's Wardrobe button
		wardrobe.toggle()
	elif get_tree().root.get_meta("open", "") == "album":  # and its Album button
		inventory.toggle()
		inventory.show_album(true)
	get_tree().root.remove_meta("open")

func _process(delta: float) -> void:
	tod = fmod(tod + delta / DAY_LENGTH, 1.0)
	Sound.night = sun() < 0.2
	night.color = interior.tint if inside != "" else Color(0.3, 0.33, 0.55).lerp(Color.WHITE, sun())
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = 1.5
		if get_tree().get_nodes_in_group("prey").size() < Spawns.cap(MAX_PREY, Vector2i(NX, NY)):
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
	var shake := 0.0 if save_extra.get("ui/reduce_motion", false) else shake_amt  # spec 11 reduce motion
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
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
		if get_viewport().gui_get_hovered_control() is BaseButton:  # HUD corner boxes: no bite, no waypoint
			return
		if god_view:  # clicking the full map picks a waypoint instead of biting
			set_waypoint(get_canvas_transform().affine_inverse() * event.position)
			return
		var dir := player.position.direction_to(get_canvas_transform().affine_inverse() * event.position)
		if dir != Vector2.ZERO:
			player.facing = dir
			player.sprite.flip_h = dir.x < 0.0
		player.bite()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:  # fixed: always reaches pause / Settings
		if inventory.is_open():
			inventory.toggle()
		elif wardrobe.is_open():
			wardrobe.toggle()
		elif stocks.is_open():
			stocks.toggle()
		elif not name_edit.visible:
			set_paused(true)
		return
	if event.keycode >= KEY_5 and event.keycode <= KEY_9:  # fixed: long menus (elevators)
		on_number(event.keycode - KEY_1)
		return
	match Keys.action_of(event):  # scripts/systems/keys.gd, rebindable in Settings
		"breed":
			prev_skin = player.skin
			player.cycle_skin()
			card_t = 3.0
			card_art.queue_redraw()
		"bite":
			player.bite()
		"dash":
			if player.dash():
				poof(player.position - player.facing * 14.0 + Vector2(0, 12), Color(0.78, 0.74, 0.66, 0.7), 10, 70.0)
		"bark":
			if player.bark():
				spawner.scatter_near(player.position, 300.0)  # spec 05: pigeon flocks scatter at the sound
				cats.on_bark()  # spec 07: barking in a bodega costs friendship
		"interact":
			interact()
		"inventory", "stats":
			inventory.toggle()
		"wardrobe":
			wardrobe.toggle()
		"stocks":
			stocks.toggle()
		"map":
			toggle_map()
		"hot_1", "hot_2", "hot_3", "hot_4":  # hotbar on the street; menu choice in shops, subway, elevators, gates
			on_number(int(Keys.action_of(event).right(1)) - 1)

## M: god's-eye map with its key (street only).
func toggle_map() -> void:
	if inside != "":
		return
	god_view = not god_view
	bump("map", true)
	zoom_tw = create_tween()
	zoom_tw.tween_property(cam, "zoom", Vector2.ONE * (0.3 if god_view else 1.5), 0.4)

func sun() -> float:
	return clampf(sin((tod - 0.25) * TAU) * 1.5 + 0.6, 0.0, 1.0)

# ---------- world building ----------

# ---------- helpers ----------

## Switch between the street ("") and an interior; clamps the camera to that area.
func set_inside(room: String, at := player.position) -> void:
	inside = room
	Sound.room(room)
	if room == "":
		interior.clear()
	var r: Rect2 = interior.rect if room != "" else Rect2(Vector2.ZERO, WORLD)
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
	if act == "" and ctx == "bodega" and cats.interact():  # F at the counter: the bodega cat
		return
	if act == "" and ctx == "trader":  # F next to Pocket: chat / hint
		trader.talk()
		return
	match act:
		"enter":
			interior.enter(door)
		"enter_boss":  # shortcut tools/smoke_test.gd uses
			interior.enter(doors.filter(func(d): return d.template == "burrow")[0])
		"exit":
			interior.leave()
		"stocks":  # NYSE terminal (scripts/systems/stocks.gd sets the prompt)
			stocks.toggle(true)
		"desk":  # Hack Club HQ front desk (scripts/world/hq_floor.gd sets the prompt)
			hq.desk()

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

# ---------- systems ----------

func respawn() -> void:
	death_panel.hide()
	name_edit.hide()
	player.respawn()
	set_inside("")
	get_tree().paused = false

## New game: wipe the dog's progress (volume survives) and rebuild the scene.
func restart() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "volume", volume.value)
	cfg.set_value("ui", "keys", Keys.to_save())  # a new dog keeps your controls
	cfg.save(save_path)
	get_tree().paused = false
	get_tree().reload_current_scene()

## Stat points never pause the game: they wait in the bag's STATS panel (corner box shows +N).
func show_stats() -> void:
	if inventory.is_open():
		inventory.refresh.call_deferred()  # a + button may be the caller; free it next frame

func pick_stat(i: int) -> void:
	if player.points <= 0:
		return
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
	Sound.music("boss_fatcat", Sound.BOSS)  # placeholder until each boss has a theme
	boss_name.text = b.cfg.name
	show_banner(str(b.cfg.name).to_upper())
	sfx("bark")

func on_boss_left(b: Node2D) -> void:
	if boss == b:
		boss = null
		Sound.music("", Sound.BOSS)

func on_boss_beaten(b: Node2D) -> void:
	on_boss_left(b)
	player.treats += b.cfg.treats
	var got := XP.award(self, b.cfg.xp, b)
	show_banner("%s DEFEATED" % str(b.cfg.name).to_upper())
	show_msg("+%d treats   +%d XP" % [b.cfg.treats, got])
	poof(b.position, b.cfg.tint, 40, 240.0)
	sfx("levelup")
	if b.cfg.has("outro") and not Story.has(b.cfg.outro):
		dialog.play(b.cfg.outro)

func on_bite(center: Vector2, radius: float, dmg: float) -> void:
	sfx("bark")
	scratch(center, player.facing)
	var crit: bool = player.roll_crit()
	if crit:
		dmg *= 1.75  # spec 05
	hedgehog.hurt(center, radius, dmg)
	for r in get_tree().get_nodes_in_group("raccoon"):
		if r.position.distance_to(center) < radius + 10.0:
			r.hurt(dmg, player.position, crit)
	for b in get_tree().get_nodes_in_group("boss"):
		if b.position.distance_to(center) < radius + 34.0:  # bosses are big
			b.hurt(dmg, player.position, crit)
	for p in get_tree().get_nodes_in_group("prey"):
		if p.position.distance_to(center) < radius:
			on_prey_caught(p)

func on_prey_caught(prey: Node2D) -> void:
	if prey.is_queued_for_deletion():
		return
	var cfg: Dictionary = prey.cfg
	player.treats += cfg.treats
	XP.award(self, cfg.xp, prey)
	player.eat(cfg.food, 0.0)
	float_text(prey.position, "+%d treats" % cfg.treats, Color(1, 0.85, 0.5))
	poof(prey.position, Color(0.85, 0.85, 0.9))
	sfx("catch")
	prey.queue_free()
	if not prey.flock.is_empty():
		spawner.scatter(prey.flock)  # spec 07: catch one, the flock flees
	if prey.kind == "squirrel":
		bump("squirrels")
	cats.rat = cats.rat or prey.kind == "rat"  # carried in as a bodega cat gift
	bump("prey")

func on_prey_escaped(prey: Node2D) -> void:
	float_text(prey.position, "up the tree!", Color(0.7, 1, 0.7))
	prey.queue_free()

func on_raccoon_beaten(rac: Node2D) -> void:
	var loot: int = rac.stats.treats + randi() % 4
	player.treats += loot
	XP.award(self, rac.stats.xp, rac)
	float_text(rac.position, "Raccoon beaten! +%d treats" % loot, Color(1, 0.85, 0.5))
	poof(rac.position, Color(0.6, 0.6, 0.65))
	sfx("catch")
	bump("raccoons")

func on_hedgehog_beaten(at: Vector2) -> void:
	show_banner("DAVEN THE HEDGEHOG DEFEATED")
	sfx("levelup")
	poof(at, Color(0.45, 0.3, 0.18), 50, 280.0)
	poof(at, Color(1, 0.85, 0.4), 30, 200.0)
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
	if ctx == "bodega":
		shop.buy(n, 5 if Input.is_key_pressed(KEY_SHIFT) else 1)
	elif ctx == "trader":
		trader.buy(n)
	elif ctx == "elevator":
		interior.ride(n)
	elif ctx == "airport":
		interior.fly(n)
	elif ctx == "" and not player.frozen and n < 4:
		inventory.use_slot(n)  # hotbar
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
	shop = ShopUi.new()
	shop.g = self
	add_child(shop)
	shop.build()
	inventory = InventoryUi.new()
	inventory.g = self
	add_child(inventory)
	inventory.build()
	wardrobe = preload("res://scripts/ui/wardrobe.gd").new()
	wardrobe.g = self
	add_child(wardrobe)
	wardrobe.build()
	keybinds = KeybindsUi.new()
	keybinds.g = self
	add_child(keybinds)
	keybinds.build()
	dialog = DialogUi.new()
	dialog.g = self
	add_child(dialog)
	dialog.build()

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

## GPS (spec 11): nearest shop / station / landmark within 250 px of `at` becomes the
## waypoint; clicking the current one again clears it.
func set_waypoint(at: Vector2) -> void:
	var best := 250.0
	var pick := {}
	for p in pois.filter(func(x): return x.text != "Drink") + landmarks:
		if at.distance_to(p.pos) < best:
			best = at.distance_to(p.pos)
			pick = p
	waypoint = {} if pick == waypoint else pick

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
	elif inside != "":
		var spots: Dictionary = interior.spots
		if interior.room == null:
			pass  # a test set `inside` without going through a door
		elif spots.has("exit") and at.distance_to(spots.exit) < 40.0 and interior.floor_n == 0:
			var e: Array = interior.data().exit
			var n: String = interior.door.name
			set_act("exit", e[0].format({"name": n, "NAME": n.to_upper()}),
				"[F]  Flee to the street" if inside == "boss" and hedgehog.active else e[1])
		elif spots.has("counter") and at.distance_to(spots.counter) < 60.0:
			ctx = "bodega"  # scripts/ui/shop.gd shows its panel while ctx is "bodega"
		elif spots.has("elevator") and at.distance_to(spots.elevator) < 50.0:
			ctx = "elevator"
			show_menu("ELEVATOR", interior.floor_rows())
		elif spots.has("gates") and at.distance_to(spots.gates) < 60.0:
			ctx = "airport"
			show_menu("GATES", interior.gate_rows())
		elif spots.has("board") and at.distance_to(spots.board) < 50.0:
			ctx = "subway"
			var rows := []
			for k in stations.size():
				rows.append(["[%d]  %s%s" % [k + 1, stations[k].name, "   (you are here)" if k == station_i else ""], k != station_i])
			show_menu("SUBWAY MAP", rows)
	else:
		for d in doors:
			if at.distance_to(d.pos) < 45.0:
				door = d
				var t: Array = Rooms.ROOMS[d.template].door
				if d.template == "cafe" and Spawns.phase(sun()) == "night":  # spec 03: cafes close at night
					set_act("closed", "CAFE", "Closed until morning")
				else:
					set_act("enter", t[0].format({"name": d.name, "NAME": d.name.to_upper()}).strip_edges(), t[1])
		if act == "" and trader.near(at):  # Pocket's cart: [1-4] buy, F chat
			ctx = "trader"
			show_menu("POCKET'S CART", trader.rows())

	if not waypoint.is_empty() and inside == "" and player.position.distance_to(waypoint.pos) < 80.0:
		waypoint = {}  # arrived
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

# ---------- scripts/world/subway.gd ----------

func travel(n: int) -> void:
	subway.travel(n)

func update_train(delta: float) -> void:
	subway.update_train(delta)

# ---------- scripts/world/fx.gd ----------

## crit: yellow, bigger, with "!" (spec 06). x jitter keeps stacked numbers apart.
func float_text(pos: Vector2, text: String, color := Color.WHITE, crit := false) -> void:
	pos.x += randf_range(-10.0, 10.0)
	if not crit:
		fx.float_text(pos, text, color)
		return
	fx.poof(pos, Color(1, 0.9, 0.3), 20, 260.0)  # crit sparks; before the label, which must stay last
	fx.float_text(pos, text + "!", Color(1, 0.9, 0.2))
	var l: Label = get_child(-1)  # the label fx just added
	l.add_theme_font_size_override("font_size", 24)

func poof(pos: Vector2, color: Color, amount := 14, speed := 110.0) -> void:
	fx.poof(pos, color, amount, speed)

func scratch(center: Vector2, dir: Vector2) -> void:
	fx.scratch(center, dir)

# ---------- scripts/world/spawner.gd ----------

func spawn_treat() -> void:
	spawner.spawn_treat()

func spawn_prey() -> void:
	spawner.spawn_prey()

func check_pickups() -> void:
	spawner.check_pickups()

# ---------- scripts/world/street.gd ----------

func update_steam(delta: float) -> void:
	street.update_steam(delta)

func check_landmarks() -> void:
	street.check_landmarks()
