extends Node2D
## sort (spec 04): numbered crates pushed onto the `_` pad row must read ascending, left to right.

var room: Node

func setup(_data: Dictionary, r: Node) -> void:
	room = r

func is_solved() -> bool:
	var pads: Array = room.cells.keys().filter(func(p): return room.cells[p] == "_")
	pads.sort_custom(func(a, b): return a.x < b.x)
	var nums: Array = pads.map(func(p): return int(room.crates.get(p, "0")))  # empty pad = 0
	var sorted := nums.duplicate()
	sorted.sort()
	return not 0 in nums and nums == sorted
