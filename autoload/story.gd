extends Node
## Story: flags, Sam's items, keycards, cleared floors, gate checks, objective() and target().
## The world never checks chapter numbers, only flags (spec 01). Saved through systems/save.gd.

signal flag_set(flag: String)
signal waypoint_changed(pos: Vector2)

const Gates := preload("res://scripts/data/gates.gd")
const NO_TARGET := Vector2.INF

var flags: Array[String] = []
var items: Array[String] = []     # Sam's items: lanyard, sticker, backpack, ...
var keycards: Array[String] = []  # city ids
var floors := {}                  # cleared floor id -> best time (s)
var spots := {}                   # story spot id -> world position, registered by the world
var waypoint := NO_TARGET         # GPS waypoint chosen by "Find XP" (or a POI)

func has(flag: String) -> bool:
	return flag in flags

func set_flag(flag: String) -> void:
	if not has(flag):
		flags.append(flag)
		flag_set.emit(flag)

func add_item(id: String) -> void:
	if not id in items:
		items.append(id)

func add_keycard(city: String) -> void:
	if not city in keycards:
		keycards.append(city)

func has_keycard(city: String) -> bool:
	return city in keycards

## Records a cleared floor, keeping the best time.
func clear_floor(id: String, time: float) -> void:
	floors[id] = minf(float(floors.get(id, INF)), time)

func set_waypoint(pos: Vector2) -> void:
	waypoint = pos
	waypoint_changed.emit(pos)

## Why gate `id` is shut for a dog of `level`, or "" when it is open. Level is checked first,
## so the door reads "Level 20 required (you are 19)" even without the keycard.
func gate_block(id: String, level: int) -> String:
	var gate: Dictionary = Gates.GATES[id]
	var need_level := int(gate.get("level", 0))
	if level < need_level:
		return "Level %d required (you are %d)" % [need_level, level]
	if gate.has("keycard") and not has_keycard(gate.keycard):
		var c: Array = Gates.CITIES[gate.keycard]
		return "%s HQ keycard required (beat %s)" % [c[0], c[1]]
	if gate.has("flag") and not has(gate.flag):
		return "Find the clue first"
	var left: Array = gate.get("flags", []).filter(func(f): return not has(f))
	if left:
		return "Beat first: " + ", ".join(left.map(func(f): return Gates.BOSS_NAMES.get(f, f)))
	for f: String in gate.get("floors", []):
		if not floors.has(f):
			return "Clear Tower floors T1-T4 first"
	return ""

func gate_open(id: String, level: int) -> bool:
	return gate_block(id, level) == ""

func _step() -> Array:
	for s: Array in Gates.OBJECTIVES:
		if not has(s[0]):
			return s
	return []

## One line for the quest tracker.
func objective() -> String:
	var s := _step()
	return s[1] if s else "Free roam: find every flashback"

## World position of the current story target; NO_TARGET until the world registers that spot.
func target() -> Vector2:
	var s := _step()
	return spots.get(s[2], NO_TARGET) if s else NO_TARGET

func reset() -> void:
	flags.clear()
	items.clear()
	keycards.clear()
	floors = {}
	waypoint = NO_TARGET

## Save v2 "story/*" keys (see systems/save.gd).
func to_save() -> Dictionary:
	return {"story/flags": flags.duplicate(), "story/items": items.duplicate(),
		"story/keycards": keycards.duplicate(), "story/floors": floors.duplicate()}

## Missing or wrong-typed keys fall back to empty, so any older save loads.
func from_save(d: Dictionary) -> void:
	reset()
	for k: String in ["flags", "items", "keycards"]:
		var v: Variant = d.get("story/" + k)
		if v is Array:
			(get(k) as Array).assign(v)
	var f: Variant = d.get("story/floors")
	if f is Dictionary:
		floors = f.duplicate()
