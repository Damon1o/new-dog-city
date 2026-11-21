extends Node2D
## program (spec 04): Byte can't walk. Keys 1-4 fill up to 8 command slots, Undo drops the last,
## F runs them one step every 0.3 s. Bark opens the gate tile ahead; reach the key, then the door.
## A run that ends anywhere else puts Byte back at the start with the program kept.
## ponytail: no repeat slot yet (nyc_3 has none); add "repeat x2/x3" when a floor needs it.

const Keys := preload("res://scripts/systems/keys.gd")
const CMDS := ["forward", "left", "right", "bark"]
const SLOTS := 8
const STEP := 0.3

var room: Node
var bar: Array[String] = []
var running := false
var pc := 0
var step_t := 0.0
var has_key := false

func setup(_data: Dictionary, r: Node) -> void:
	room = r
	r.walk = false

func is_solved() -> bool:
	return has_key

## Puzzle keys; false = not ours (F on an empty bar still reaches the floor's exit prompt).
func on_key(e: InputEvent) -> bool:
	if running:
		return true
	var a := Keys.action_of(e)
	if a.begins_with("hot_"):
		if bar.size() < SLOTS:
			bar.append(CMDS[int(a.right(1)) - 1])
	elif a == "undo" and bar:
		bar.pop_back()
	elif a == "interact" and bar:
		running = true
		pc = 0
		step_t = 0.0
	else:
		return false
	queue_redraw()
	return true

func _process(delta: float) -> void:
	if not running:
		return
	step_t -= delta
	if step_t > 0.0:
		return
	step_t = STEP
	if pc >= bar.size():  # ran out without reaching the door: back to the start
		running = false
		has_key = false
		room.parse()
		room.place_dog()
		return
	var f: Vector2i = room.facing
	match bar[pc]:
		"forward":
			room.move(f)
			if room.cells[room.at] == "k":
				room.cells[room.at] = "."
				has_key = true
				Sound.sfx("pickup")
		"left":
			room.facing = Vector2i(f.y, -f.x)
		"right":
			room.facing = Vector2i(-f.y, f.x)
		"bark":
			Sound.sfx("bark")
			if room.cells.get(room.at + f) == "g":
				room.cells[room.at + f] = "."
	pc += 1
	room.redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for k in SLOTS:
		var r := Rect2(64 + k * 72, 40, 64, 40)
		draw_rect(r, Color(0.36, 0.6, 1.0) if running and k == pc - 1 else Color(0.14, 0.16, 0.24))
		draw_rect(r, Color(0.55, 0.75, 1.0, 0.5), false, 1.0)
		if k < bar.size():
			draw_string(font, r.position + Vector2(0, 26), bar[k].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 64, 12)
	draw_string(font, Vector2(64, 112), "[1] forward  [2] left  [3] right  [4] bark   [%s] undo   [F] run   hold [R] reset" % Keys.label("undo"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.62, 0.68, 0.8))
	var c: Vector2 = room.center(room.at)  # facing arrow on Byte's tile
	var f := Vector2(room.facing)
	draw_colored_polygon([c + f * 30, c + f * 18 + f.orthogonal() * 8, c + f * 18 - f.orthogonal() * 8], Color(1, 0.85, 0.3))
