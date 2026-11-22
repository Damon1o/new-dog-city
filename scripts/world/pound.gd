extends Node
## The pound (spec 08), redesigned: wanted.caught() wakes the dog in his kennel ("pound" room,
## data/rooms.gd): a row of four cells (three hold caged strays), the warden's office and the
## exercise yard. At the cell door: [1] pay the fine, [2] break out. Breakout:
##   sneak    out of the cell, across the corridor to the yard fence. Warden Brutus patrols it
##            with a flashlight; his light on you (or a bite) = the fight
##   fight    Warden Brutus is a real boss (boss.gd + data/bosses.gd WARDEN, dog's level + 2):
##            beat him for his keys = out, +treats/XP; downed = back in the cell, he resets
##   dig      at the fence press G (pee) when the marker is in the zone, 6 hits; 3 misses refill
##   squeeze  mash C (dash) MASH times before the 3 s timer runs out; out = +50 XP, escapes +1
## Walls, bars, fences, strays and the bar UI are drawn in code.

const XP := preload("res://scripts/systems/xp.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const BossScript := preload("res://scripts/boss.gd")
const WARDEN := preload("res://scripts/data/bosses.gd").WARDEN
const NPC := preload("res://scripts/npc.gd")
const GUARD_SPEED := 80.0
const PATROL := [180.0, 900.0]  # warden x range, room-local, at y GUARD_Y
const GUARD_Y := 470.0
const CONE := 240.0       # flashlight length
const CONE_HALF := 0.5    # rad
const HITS := 6
const MISSES := 3
const ZONE := Vector2(0.4, 0.6)  # dig bar hit zone, 0..1
const DIG_SPEED := 0.9   # marker sweeps / s
const SQUEEZE_T := 3.0
const MASH := 15
# [cell x centre, name plate, stray breed or ""]: cell 0 is the dog's
const CELLS := [[80, "YOU", ""], [240, "BISCUIT", "pug"], [400, "LUNA", "husky"], [560, "TINY", "chihuahua"]]

var g: Node2D
var fine := 0
var stage := ""   # "" (in the cell) / "sneak" / "fight" / "dig" / "squeeze"
var guard: Node2D  # Warden Brutus (boss.gd), lives in the room
var light: Node2D  # his flashlight cone
var guard_dir := Vector2.RIGHT
var mark := 0.0   # dig marker 0..1
var mark_v := DIG_SPEED
var hits := 0
var misses := 0
var squeeze_t := 0.0
var mashed := 0
var bar_ui: Control

## Caught with `stars`: fade in on the cell, fine = 15 x stars x city price (min 10).
func jail(stars: int) -> void:
	fine = maxi(10, roundi(15 * stars * g.economy.city_mult()))
	g.bump("pound")  # Old Rex: "visit the pound"
	stage = ""
	# ponytail: no pound building on the street map; the street door is the dog's park spawn
	g.interior.enter({"template": "pound", "pos": g.player.spawn_point, "id": "pound", "seed": 0, "name": "Pound", "floors": 1})
	build()
	g.player.position = g.interior.spots.start
	g.fade.color.a = 1.0
	g.create_tween().tween_property(g.fade, "color:a", 0.0, 0.5)
	g.show_msg("Caught! Fine: %d treats.  Cell door: pay or break out" % fine)

## Walls, decor, strays, the warden and his light, all children of the room (freed with it).
func build() -> void:
	var O: Vector2 = g.interior.O
	for b: Array in [[Vector2(320, 300), Vector2(640, 8)],  # kennel bars
			[Vector2(160, 196), Vector2(8, 200)], [Vector2(320, 196), Vector2(8, 200)], [Vector2(480, 196), Vector2(8, 200)],
			[Vector2(644, 196), Vector2(8, 200)],  # kennel end wall
			[Vector2(960, 173), Vector2(8, 154)],  # office wall, doorway below it
			[Vector2(1160, 320), Vector2(240, 8)], [Vector2(960, 520), Vector2(8, 240)]]:  # yard fences, gate at the corner
		g.interior.box(b[0], b[1])
	var deco := Node2D.new()
	deco.z_index = -9
	deco.draw.connect(draw_deco.bind(deco, O))
	g.interior.room.add_child(deco)
	for c: Array in CELLS:  # caged strays pacing their cells
		if c[2] == "":
			continue
		var dog := Node2D.new()
		var x0: float = O.x + c[0]
		dog.position = Vector2(x0, O.y + 180)
		var tex: Texture2D = load("res://assets/dog_%s.png" % c[2])
		dog.draw.connect(func(): NPC.draw_dog(dog, tex, 2.2, 0))
		g.interior.room.add_child(dog)
		var tw := dog.create_tween().set_loops()
		tw.tween_property(dog, "position:x", x0 + 30.0, 1.6 + c[0] / 400.0)
		tw.tween_callback(func(): dog.scale.x = -1.0)
		tw.tween_property(dog, "position:x", x0 - 30.0, 1.6 + c[0] / 400.0)
		tw.tween_callback(func(): dog.scale.x = 1.0)
	var cfg := WARDEN.duplicate()
	cfg.level = maxi(int(WARDEN.level), g.player.level + 2)
	guard = BossScript.new()
	g.interior.room.add_child(guard)
	guard.setup(cfg, O + Vector2(PATROL[0], GUARD_Y), g.tex[WARDEN.critter], g)
	guard.arena = g.interior.rect
	guard.base_scale = Vector2(1.8, 1.8)  # a person, not a monster: smaller than ART_SCALE
	guard.sprite.scale = guard.base_scale
	guard_dir = Vector2.RIGHT
	light = Node2D.new()
	light.z_index = -8
	light.draw.connect(draw_light)
	g.interior.room.add_child(light)

func rows() -> Array:
	return [["[1]  Pay the fine: %d treats" % fine, g.player.treats >= fine], ["[2]  Break out", true]]

func choose(n: int) -> void:
	if n == 0 and g.economy.spend_treats(fine):
		g.show_msg("Fine paid. Behave out there.")
		release()
	elif n == 1:
		stage = "sneak"
		g.player.position = g.interior.spots.out
		g.show_msg("Sneak to the yard fence. Stay out of the warden's light - or fight him for the keys.")

## Back on the street by the pound's street door.
func release() -> void:
	stage = ""
	g.player.frozen = false
	if is_instance_valid(guard):
		g.on_boss_left(guard)  # boss bar and music off
	g.set_inside("", g.interior.door.pos)

func back_to_cell(why: String) -> void:
	stage = ""
	g.player.frozen = false
	g.player.position = g.interior.spots.start
	g.show_msg(why)

## The warden saw (or got bitten by) the dog.
func start_fight() -> void:
	stage = "fight"
	Sound.sfx("whistle")
	if guard.state == guard.State.IDLE:
		guard.wake()
	g.show_msg("Warden Brutus: \"Back in your cage!\"  Beat him for the gate keys.")

## game.gd player.died in the pound: no death screen, the warden drags the dog back.
func knocked_out() -> void:
	g.player.respawn()
	if is_instance_valid(guard) and guard.state != guard.State.DEAD:
		guard.clear_shots()
		g.on_boss_left(guard)
		guard.state = guard.State.IDLE  # wake() refills hp and phase next time
		guard.position = g.interior.O + Vector2(PATROL[0], GUARD_Y)
		guard_dir = Vector2.RIGHT
	back_to_cell("Warden Brutus threw you back in the cell.")

func press(action: String) -> void:
	if stage == "dig" and action == "pee":
		if mark >= ZONE.x and mark <= ZONE.y:
			hits += 1
			Sound.sfx("pickup")
		else:
			misses += 1
			if misses >= MISSES:
				hits = 0
				misses = 0
				g.show_msg("The hole caved in. Start digging again.")
		if hits >= HITS:
			stage = "squeeze"
			squeeze_t = SQUEEZE_T
			mashed = 0
	elif stage == "squeeze" and action == "dash":
		mashed += 1
		if mashed >= MASH:
			escaped(50, "ESCAPED THE POUND")

func escaped(xp: int, banner: String) -> void:
	release()
	var got := XP.award(g, xp)
	g.bump("escapes")
	g.show_banner(banner)
	g.show_msg("+%d XP" % got)

func _unhandled_key_input(event: InputEvent) -> void:
	if g.inside != "pound" or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var a := Keys.action_of(event)
	if g.ctx == "pound" and a in ["hot_1", "hot_2"]:
		choose(int(a.right(1)) - 1)
	else:
		press(a)

func _process(delta: float) -> void:
	if not bar_ui:
		bar_ui = Control.new()
		bar_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.hud.add_child(bar_ui)
		bar_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bar_ui.draw.connect(draw_bar)
	bar_ui.queue_redraw()
	if g.inside != "pound" or not is_instance_valid(guard):
		stage = ""
		return
	var p: CharacterBody2D = g.player
	var s: Dictionary = g.interior.spots
	light.queue_redraw()
	if guard.state == guard.State.DEAD:  # beaten: on_boss_beaten paid out, his keys open the gate
		g.bump("warden")
		escaped(120, "BEAT WARDEN BRUTUS")
		return
	if guard.state == guard.State.IDLE:
		patrol(delta)
	elif stage != "fight":  # bitten mid-sneak (or through the cell bars)
		start_fight()
	match stage:
		"":
			if p.position.distance_to(s.cell) < 50.0 and not p.frozen:
				g.ctx = "pound"  # runs after game.update_prompts (child order), like shop.gd
				g.show_menu("POUND   cell door", rows())
		"sneak":
			var to: Vector2 = p.position - guard.position
			if to.length() < CONE and absf(guard_dir.angle_to(to)) < CONE_HALF:
				start_fight()
			elif p.position.distance_to(s.fence) < 40.0:
				stage = "dig"
				p.frozen = true
				hits = 0
				misses = 0
				g.show_msg("Dig: press %s when the marker hits the zone" % Keys.label("pee"))
		"dig":
			mark += mark_v * delta
			if mark > 1.0 or mark < 0.0:
				mark_v = -mark_v
				mark = clampf(mark, 0.0, 1.0)
		"squeeze":
			squeeze_t -= delta
			if squeeze_t <= 0.0:
				back_to_cell("Stuck under the fence... they dragged you back to the cell.")

## Corridor patrol while he's not fighting; boss.gd's IDLE state leaves him to us.
func patrol(delta: float) -> void:
	var x: float = guard.position.x - g.interior.O.x + guard_dir.x * GUARD_SPEED * delta
	if x < PATROL[0] or x > PATROL[1]:
		guard_dir = -guard_dir
	guard.position.x += guard_dir.x * GUARD_SPEED * delta
	guard.home = guard.position
	guard.sprite.flip_h = guard_dir.x < 0.0

func draw_light() -> void:
	if not is_instance_valid(guard) or guard.state != guard.State.IDLE:
		return
	var at: Vector2 = guard.position + Vector2(0, -30)
	var cone := PackedVector2Array([at])
	for k in 9:
		cone.append(at + guard_dir.rotated(-CONE_HALF + k * CONE_HALF / 4.0) * CONE)
	light.draw_colored_polygon(cone, Color(1, 0.95, 0.5, 0.32 if stage == "sneak" else 0.22))

func draw_deco(d: Node2D, O: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var bar := Color(0.28, 0.28, 0.33)
	var chain := Color(0.62, 0.64, 0.68)
	d.draw_rect(Rect2(O + Vector2(380, 18), Vector2(520, 50)), Color(0.15, 0.25, 0.4))  # big wall sign
	d.draw_rect(Rect2(O + Vector2(380, 18), Vector2(520, 50)), Color(0.9, 0.75, 0.2), false, 3.0)
	d.draw_string(font, O + Vector2(400, 56), "CITY ANIMAL CONTROL  -  POUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.95, 0.9))
	for i in 3:  # LOST PET posters
		var r := Rect2(O + Vector2(60 + i * 90, 22), Vector2(56, 64))
		d.draw_rect(r, Color(0.95, 0.93, 0.85))
		d.draw_string(font, r.position + Vector2(4, 14), "LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.1, 0.1))
		d.draw_circle(r.position + Vector2(28, 40), 12, Color(0.6, 0.45, 0.3))
	for c: Array in CELLS:  # cell plates and straw beds
		var x: float = c[0]
		d.draw_rect(Rect2(O + Vector2(x - 34, 120), Vector2(68, 30)), Color(0.75, 0.62, 0.3))
		d.draw_rect(Rect2(O + Vector2(x - 26, 100), Vector2(52, 16)), Color(0.2, 0.2, 0.22))
		d.draw_string(font, O + Vector2(x - 24, 113), c[1], HORIZONTAL_ALIGNMENT_LEFT, 48, 11, Color(1, 0.85, 0.3) if c[1] == "YOU" else Color.WHITE)
	for x in range(0, 641, 12):  # kennel bars + rails
		d.draw_line(O + Vector2(x, 236), O + Vector2(x, 300), bar, 3.0)
	for y in [238, 270, 298]:
		d.draw_line(O + Vector2(0, y), O + Vector2(640, y), bar.darkened(0.3), 3.0)
	d.draw_rect(Rect2(O + Vector2(56, 236), Vector2(48, 64)), Color(0.5, 0.2, 0.15, 0.35))  # the dog's cell door
	d.draw_rect(Rect2(O + Vector2(1030, 130), Vector2(150, 44)), Color(0.38, 0.24, 0.12))  # warden's desk
	d.draw_rect(Rect2(O + Vector2(1050, 112), Vector2(40, 26)), Color(0.15, 0.15, 0.18))  # monitor watching the kennels
	d.draw_rect(Rect2(O + Vector2(1054, 116), Vector2(32, 18)), Color(0.3, 0.6, 0.5))
	d.draw_circle(O + Vector2(1150, 124), 8, Color(0.55, 0.4, 0.25))  # donut
	d.draw_rect(Rect2(O + Vector2(1210, 104), Vector2(40, 30)), Color(0.3, 0.22, 0.12))  # key hook
	d.draw_string(font, O + Vector2(1214, 118), "KEYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.3))
	d.draw_circle(O + Vector2(1230, 126), 4, Color(0.9, 0.8, 0.3))
	d.draw_string(font, O + Vector2(980, 116), "WARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.6))
	for y in range(400, 640, 12):  # yard chain-link fences
		d.draw_line(O + Vector2(956, y), O + Vector2(964, y + 12), chain, 1.5)
	for x in range(1040, 1280, 12):
		d.draw_line(O + Vector2(x, 316), O + Vector2(x + 12, 324), chain, 1.5)
	for y in range(320, 640, 12):
		d.draw_line(O + Vector2(1268, y), O + Vector2(1276, y + 12), chain, 1.5)
	d.draw_circle(O + Vector2(1236, 540), 14, Color(0.4, 0.3, 0.2, 0.5))  # loose dirt under the fence
	d.draw_string(font, O + Vector2(1170, 600), "loose dirt", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.25, 0.15))

## Dig and squeeze bars, bottom center.
func draw_bar() -> void:
	if g.inside != "pound" or stage not in ["dig", "squeeze"]:
		return
	var font := ThemeDB.fallback_font
	var r := Rect2(bar_ui.size.x / 2.0 - 160, bar_ui.size.y - 170, 320, 22)
	bar_ui.draw_rect(r.grow(4), Color(0, 0, 0, 0.7))
	var text := ""
	if stage == "dig":
		bar_ui.draw_rect(Rect2(r.position + Vector2(r.size.x * ZONE.x, 0), Vector2(r.size.x * (ZONE.y - ZONE.x), r.size.y)), Color(0.3, 0.9, 0.4))
		bar_ui.draw_rect(Rect2(r.position + Vector2(r.size.x * mark - 2, -4), Vector2(4, r.size.y + 8)), Color.WHITE)
		text = "DIG  [%s]   %d / %d   misses %d / %d" % [Keys.label("pee"), hits, HITS, misses, MISSES]
	else:
		bar_ui.draw_rect(Rect2(r.position, Vector2(r.size.x * squeeze_t / SQUEEZE_T, r.size.y / 2)), Color(1, 0.4, 0.3))
		bar_ui.draw_rect(Rect2(r.position + Vector2(0, r.size.y / 2), Vector2(r.size.x * mashed / MASH, r.size.y / 2)), Color(0.4, 0.8, 1))
		text = "SQUEEZE  mash [%s]   %d / %d" % [Keys.label("dash"), mashed, MASH]
	bar_ui.draw_string_outline(font, r.position + Vector2(0, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
	bar_ui.draw_string(font, r.position + Vector2(0, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
