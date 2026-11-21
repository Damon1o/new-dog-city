extends Node2D
## logic (spec 04): plates a/b/c are on while Byte or a crate sits on them; gate tiles combine
## them (& AND, | OR, ! NOT) and params.door is the gate wired to the door. Wires light when on.

var room: Node
var gates := {}  # gate char -> input chars
var out := ""
var at := {}     # char -> tile

func setup(data: Dictionary, r: Node) -> void:
	room = r
	gates = data.params.gates
	out = data.params.door
	for p: Vector2i in r.cells:
		at[r.cells[p]] = p

func on(c: String) -> bool:
	if c in ["a", "b", "c"]:
		return room.crates.has(at[c]) or room.at == at[c]
	var ins: Array = gates[c]
	match c:
		"&":
			return ins.all(on)
		"|":
			return ins.any(on)
	return not on(ins[0])  # "!"

func is_solved() -> bool:
	return on(out)

func _draw() -> void:
	for gate: String in gates:
		for c: String in gates[gate]:
			wire(c, gate)
	wire(out, "D")

func wire(from: String, to: String) -> void:
	var lit := on(from)
	draw_line(room.center(at[from]), room.center(at[to]), Color(1, 0.85, 0.3) if lit else Color(0.3, 0.32, 0.4), 4.0 if lit else 3.0)
