extends Node
## HQ puzzle floors (spec 04): a 15 x 10 grid of 64 px tiles from data/puzzles.gd, built in the
## hq_floor room. This floor owns the grid, Byte's tile, the crates and the exit door; the type
## script (scripts/puzzles/<type>.gd: setup, is_solved) owns the rules. Byte steps one tile per
## move key and pushes crates. Hold R 1 s = reset; 3 resets on one floor show params.hint.
## Walking through the open door clears the floor: rewards, back to the street, then
## flashback.clear_floor() plays the memory. F on the start tile leaves without clearing.
## Debug: `godot --path . -- --floor=nyc_1` drops the dog straight onto a floor.
## The HQ lobby elevator (M5-6, interior.gd ride_hq) calls enter(); the lobby's front desk talks here.

const PUZZLES: Dictionary = preload("res://scripts/data/puzzles.gd").PUZZLES
const TYPES := {"sort": preload("res://scripts/puzzles/sort.gd"), "logic": preload("res://scripts/puzzles/logic.gd"),
	"program": preload("res://scripts/puzzles/program.gd")}
const Keys := preload("res://scripts/systems/keys.gd")
const Look := preload("res://scripts/ui/theme.gd")
const XP := preload("res://scripts/systems/xp.gd")
const T := 64
const HOLD := 1.0
const CITY := {"nyc": 1, "sf": 2, "tokyo": 3, "shenzhen": 4, "tower": 5}  # spec 04: XP = 200 x city index
const DIRS := {"move_up": Vector2i.UP, "move_down": Vector2i.DOWN, "move_left": Vector2i.LEFT, "move_right": Vector2i.RIGHT}
const WALK := [".", "_", "a", "b", "c", "k"]

var g: Node2D
var id := ""          # floor being played, "" = none
var cells := {}       # Vector2i -> tile char (crates and S lifted off)
var crates := {}      # Vector2i -> crate label ("1"-"9", "x")
var at := Vector2i.ZERO
var start := Vector2i.ZERO
var facing := Vector2i.UP
var walk := true      # false: the type drives Byte (program)
var puzzle: Node2D
var board: Node2D
var hint: Label
var t := 0.0          # time on this floor (par_time)
var hold := 0.0       # R held
var resets := {}      # floor id -> resets this session
var tw: Tween

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--floor="):
			enter.call_deferred(a.trim_prefix("--floor="))

func active() -> bool:
	return id != "" and g.inside == "hq"

func enter(floor_id: String) -> void:
	if not PUZZLES.has(floor_id):
		return
	var it: Node = g.interior
	var pos: Vector2 = g.player.position if g.inside == "" else g.return_pos
	it.door = {"template": "hq_floor", "id": floor_id, "name": "Hack Club HQ", "floors": 1, "pos": pos}
	it.floor_n = 0
	g.return_pos = pos
	it.build("hq_floor")
	id = floor_id
	t = 0.0
	g.player.set_physics_process(false)  # grid steps only; hunger waits too
	board = Node2D.new()
	board.z_index = -5
	board.position = it.O
	board.draw.connect(draw_board)
	it.room.add_child(board)
	hint = Label.new()
	hint.add_theme_stylebox_override("normal", Look.box())
	hint.add_theme_font_size_override("font_size", 14)
	hint.position = it.O + Vector2(64, 576)
	it.room.add_child(hint)
	load_puzzle()
	g.set_inside("hq", center(at) + it.O)
	g.cam.zoom = Vector2.ONE  # the whole 960 x 640 grid on screen

## (Re)build the type script from data; also the hold-R reset.
func load_puzzle() -> void:
	if puzzle:
		puzzle.free()
	var d: Dictionary = PUZZLES[id]
	parse()
	walk = true
	puzzle = TYPES[d.type].new()
	puzzle.position = g.interior.O
	puzzle.z_index = -4
	puzzle.setup(d, self)
	g.interior.room.add_child(puzzle)
	g.interior.spots["exit"] = g.interior.O + center(start)
	var n: int = resets.get(id, 0)
	hint.visible = n >= 3
	hint.text = "Hint: " + str(d.params.get("hint", ""))
	place_dog()

## Grid chars -> cells / crates / start, Byte back on S facing up.
func parse() -> void:
	cells = {}
	crates = {}
	var rows: Array = PUZZLES[id].grid
	for y in rows.size():
		for x in rows[y].length():
			var p := Vector2i(x, y)
			var c: String = rows[y][x]
			if c == "S":
				start = p
				c = "."
			elif c in ["A", "B", "C"]:
				crates[p] = "x"
				c = c.to_lower()
			elif c == "x" or c.is_valid_int():
				crates[p] = c
				c = "."
			cells[p] = c
	at = start
	facing = Vector2i.UP

func reset() -> void:
	resets[id] = resets.get(id, 0) + 1
	g.show_msg("Puzzle reset")
	load_puzzle()

func center(p: Vector2i) -> Vector2:
	return Vector2(p * T) + Vector2(T, T) / 2.0

func passable(p: Vector2i) -> bool:
	return cells.get(p, "#") in WALK or (cells.get(p) == "D" and puzzle.is_solved())

## One step; pushes a crate in the way. False = blocked.
func move(dir: Vector2i) -> bool:
	facing = dir
	var to := at + dir
	if crates.has(to):
		var past := to + dir
		if not passable(past) or crates.has(past) or cells[past] == "D":
			return false
		crates[past] = crates[to]
		crates.erase(to)
	elif not passable(to):
		return false
	at = to
	if dir.x != 0:
		g.player.sprite.flip_h = dir.x < 0
	place_dog()
	if cells[at] == "D":
		clear.call_deferred()  # deferred: leaving frees the room the type script lives in
	return true

func place_dog() -> void:
	var to: Vector2 = g.interior.O + center(at)
	if tw:
		tw.kill()
	if g.save_extra.get("ui/reduce_motion", false):
		g.player.position = to
	else:
		tw = g.create_tween()
		tw.tween_property(g.player, "position", to, 0.1)
	redraw()

func redraw() -> void:
	board.queue_redraw()
	puzzle.queue_redraw()

## Door reached: first clear = 200 XP x city index + 5 treats; under par (first time) = +1 bone.
func clear() -> void:
	var fid := id
	var d: Dictionary = PUZZLES[fid]
	var prev := float(Story.floors.get(fid, INF))
	var got := 0
	if prev == INF:
		got = XP.award(g, 200 * int(CITY.get(fid.get_slice("_", 0), 1)))
		g.player.treats += 5
	var bone: bool = t <= d.par_time and prev > d.par_time
	if bone:
		g.economy.add_bones(1)
	g.show_banner("FLOOR CLEAR")
	g.show_msg("%.1f s  (par %d)%s%s" % [t, d.par_time, "   +%d XP  +5 treats" % got if prev == INF else "", "   +1 bone" if bone else ""])
	g.interior.leave()
	done()
	g.flashback.clear_floor(fid, t)

func done() -> void:
	id = ""
	board = null
	puzzle = null
	if tw:
		tw.kill()
	g.player.set_physics_process(true)

func _process(delta: float) -> void:
	if id != "" and g.inside != "hq":
		done()  # left by the start tile, blacked out, or caught
	if g.inside == "hq_lobby" and g.interior.room and g.act == "" and not g.player.frozen \
			and g.player.position.distance_to(g.interior.spots.desk) < 60.0:
		g.set_act("desk", "FRONT DESK", "[F]  Talk to the receptionist")
	if not active():
		return
	t += delta
	if Input.is_action_pressed("bark"):
		hold += delta
		if hold >= HOLD and hold - delta < HOLD:
			reset()
	else:
		hold = 0.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not active() or g.dialog.playing() or not event.is_pressed():
		return
	if puzzle.has_method("on_key") and puzzle.on_key(event):
		get_viewport().set_input_as_handled()
		return
	var a := Keys.action_of(event)
	if walk and DIRS.has(a):
		get_viewport().set_input_as_handled()
		move(DIRS[a])

## Tiles, crates, gates, door; the type script draws its own extras (wires, command bar) on top.
func draw_board() -> void:
	var font := ThemeDB.fallback_font
	var open: bool = puzzle.is_solved()
	for p: Vector2i in cells:
		var r := Rect2(Vector2(p * T), Vector2(T, T))
		var c: String = cells[p]
		match c:
			"#":
				board.draw_rect(r, Color(0.2, 0.22, 0.3))
				board.draw_rect(r.grow(-2), Color(0.26, 0.28, 0.38))
			"D":
				board.draw_rect(r, Color(0.25, 0.75, 0.45) if open else Color(0.7, 0.22, 0.25))
				board.draw_rect(r.grow(-10), Color(0.1, 0.3, 0.18) if open else Color(0.3, 0.08, 0.1))
			"&", "|", "!", "g":
				board.draw_rect(r, Color(0.16, 0.18, 0.26))
				board.draw_rect(r.grow(-6), Color(0.36, 0.6, 1.0, 0.8), false, 3.0)
				board.draw_string(font, r.position + Vector2(0, 42), {"&": "AND", "|": "OR", "!": "NOT", "g": "GATE"}[c], HORIZONTAL_ALIGNMENT_CENTER, T, 16)
			_:
				board.draw_rect(r, Color(0.5, 0.52, 0.58))
				board.draw_rect(r, Color(0.42, 0.44, 0.5), false, 1.0)
				if c == "_":
					board.draw_rect(r.grow(-6), Color(0.36, 0.6, 1.0, 0.55))
				elif c in ["a", "b", "c"]:
					board.draw_circle(r.get_center(), 22, Color(1, 0.85, 0.3) if puzzle.on(c) else Color(0.6, 0.5, 0.25))
					board.draw_string(font, r.position + Vector2(0, 40), c, HORIZONTAL_ALIGNMENT_CENTER, T, 18, Color.BLACK)
				elif c == "k":
					board.draw_circle(r.get_center() - Vector2(8, 0), 9, Color(1, 0.85, 0.3))
					board.draw_rect(Rect2(r.get_center() - Vector2(0, 3), Vector2(18, 6)), Color(1, 0.85, 0.3))
	for p: Vector2i in crates:
		var r := Rect2(Vector2(p * T), Vector2(T, T)).grow(-6)
		board.draw_rect(r, Color(0.6, 0.4, 0.22))
		board.draw_rect(r.grow(-5), Color(0.72, 0.5, 0.28), false, 3.0)
		if crates[p] != "x":
			board.draw_string(font, r.position + Vector2(0, 36), crates[p], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color.WHITE)

## Front desk (M5-6): the gate, or a nudge toward the first floor not cleared yet.
func desk() -> void:
	var it: Node = g.interior
	var line := "Welcome to Hack Club HQ! The elevator is on the right."
	var why: String = it.hq_block(0)
	if why != "":
		line = "Sorry, the floors are members only. " + why + "."
	else:
		for k in 4:
			if not Story.floors.has(it.hq_id(k)):
				line = "Floor 4 is the clue room. It isn't ready yet." if k == 3 \
					else "Floor %d today. Tip: %s" % [k + 1, PUZZLES[it.hq_id(k)].params.get("hint", "")]
				break
	g.dialog.play("hq_desk", [{"say": "Receptionist", "text": line}])
