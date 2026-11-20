extends Node
## The pound (spec 08): wanted.caught() wakes the dog in the "pound" room (data/rooms.gd).
## At the cell door: [1] pay the fine, [2] break out. Breakout = three stages:
##   sneak    walk from the cell door to the yard fence; the guard's cone sees you = restart
##   dig      at the fence press G (pee) when the marker is in the zone, 6 hits; 3 misses refill
##   squeeze  mash C (dash) MASH times before the 3 s timer runs out; out = +50 XP, escapes +1
## Fail (timer out) = back in the cell. Walls, guard and the bar UI are drawn in code.

const XP := preload("res://scripts/systems/xp.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const GUARD_SPEED := 70.0
const PATROL := [260.0, 720.0]  # guard x range, room-local, at y GUARD_Y
const GUARD_Y := 354.0
const CONE := 220.0       # vision length
const CONE_HALF := 0.5    # rad
const HITS := 6
const MISSES := 3
const ZONE := Vector2(0.4, 0.6)  # dig bar hit zone, 0..1
const DIG_SPEED := 0.9   # marker sweeps / s
const SQUEEZE_T := 3.0
const MASH := 15

var g: Node2D
var fine := 0
var stage := ""   # "" (in the cell) / "sneak" / "dig" / "squeeze"
var guard: Node2D
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
	stage = ""
	# ponytail: no pound building on the street map; the street door is the dog's park spawn
	g.interior.enter({"template": "pound", "pos": g.player.spawn_point, "id": "pound", "seed": 0, "name": "Pound", "floors": 1})
	var s: Dictionary = g.interior.spots
	var O: Vector2 = g.interior.O
	for b: Array in [[Vector2(204, 178), Vector2(8, 164)], [Vector2(104, 264), Vector2(208, 8)], [Vector2(940, 272), Vector2(8, 352)]]:
		g.interior.box(b[0], b[1])  # cell side, cell front, yard fence
	var deco := Node2D.new()
	deco.z_index = -9
	deco.draw.connect(func():
		for i in 13:  # cell bars
			deco.draw_line(O + Vector2(i * 16, 260), O + Vector2(i * 16, 236), Color(0.3, 0.3, 0.35), 3.0)
		for y in range(96, 448, 12):  # chain-link fence
			deco.draw_line(O + Vector2(936, y), O + Vector2(944, y + 12), Color(0.6, 0.62, 0.65), 1.5)
		deco.draw_string(ThemeDB.fallback_font, O + Vector2(300, 60), "LOST PETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16))
	g.interior.room.add_child(deco)
	guard = Node2D.new()
	guard.position = O + Vector2(PATROL[0], GUARD_Y)
	guard.draw.connect(draw_guard)
	g.interior.room.add_child(guard)
	g.player.position = s.start
	g.fade.color.a = 1.0
	g.create_tween().tween_property(g.fade, "color:a", 0.0, 0.5)
	g.show_msg("Caught! Fine: %d treats.  Cell door: pay or break out" % fine)

func rows() -> Array:
	return [["[1]  Pay the fine: %d treats" % fine, g.player.treats >= fine], ["[2]  Break out", true]]

func choose(n: int) -> void:
	if n == 0 and g.economy.spend_treats(fine):
		g.show_msg("Fine paid. Behave out there.")
		release()
	elif n == 1:
		stage = "sneak"
		g.player.position = g.interior.spots.out
		g.show_msg("Sneak to the yard fence. Stay out of the guard's light.")

## Back on the street by the pound's street door.
func release() -> void:
	stage = ""
	g.player.frozen = false
	g.set_inside("", g.interior.door.pos)

func back_to_cell(why: String) -> void:
	stage = ""
	g.player.frozen = false
	g.player.position = g.interior.spots.start
	g.show_msg(why)

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
			release()
			var got := XP.award(g, 50)
			g.bump("escapes")
			g.show_banner("ESCAPED THE POUND")
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
	if g.inside != "pound":
		stage = ""
		return
	var p: CharacterBody2D = g.player
	var s: Dictionary = g.interior.spots
	match stage:
		"":
			if p.position.distance_to(s.cell) < 50.0 and not p.frozen:
				g.ctx = "pound"  # runs after game.update_prompts (child order), like shop.gd
				g.show_menu("POUND   cell door", rows())
		"sneak":
			var x: float = guard.position.x - g.interior.O.x + guard_dir.x * GUARD_SPEED * delta
			if x < PATROL[0] or x > PATROL[1]:
				guard_dir = -guard_dir
			guard.position.x += guard_dir.x * GUARD_SPEED * delta
			guard.queue_redraw()
			var to: Vector2 = p.position - guard.position
			if to.length() < CONE and absf(guard_dir.angle_to(to)) < CONE_HALF:
				Sound.sfx("whistle")
				p.position = s.out
				g.show_msg("Spotted! Back to the cell door.")
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

func draw_guard() -> void:
	var cone := PackedVector2Array([Vector2.ZERO])
	for k in 9:
		cone.append(guard_dir.rotated(-CONE_HALF + k * CONE_HALF / 4.0) * CONE)
	guard.draw_colored_polygon(cone, Color(1, 0.95, 0.5, 0.25))
	guard.draw_rect(Rect2(-9, -14, 18, 22), Color(0.35, 0.3, 0.2))
	guard.draw_circle(Vector2(0, -20), 7, Color(0.95, 0.78, 0.62))

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
