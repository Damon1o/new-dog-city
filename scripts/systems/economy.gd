extends Node
## Prices, bones wallet and shop discounts (spec 09). Treats stay on the player.
## Final price = base * city_mult * shop_roll * (1 - discount), rounded, min 1.

const CITY_MULT := {"nyc": 1.0, "sf": 1.4, "tokyo": 1.2, "shenzhen": 0.8}
const ROLL_MIN := 0.85
const ROLL_MAX := 1.15
const MAX_DISCOUNT := 0.25

var g: Node2D
var bones := 0  # saved as dog/bones by systems/save.gd
## Discount sources: id -> {"pct": float, "label": String}. Bodega cats (M4-3) and
## claimed blocks plug in here with set_discount(); the total is capped at MAX_DISCOUNT.
var discounts := {}

## Per-shop price roll in [ROLL_MIN, ROLL_MAX], seeded from the door id: stable across sessions.
static func shop_roll(door_id: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = door_id.hash()
	return rng.randf_range(ROLL_MIN, ROLL_MAX)

static func final_price(base: int, city_mult: float, roll: float, discount: float) -> int:
	var d := clampf(discount, 0.0, MAX_DISCOUNT)
	return maxi(1, roundi(base * city_mult * roll * (1.0 - d)))

func city_mult() -> float:
	return CITY_MULT.get(g.save_extra.get("world/city", "nyc"), 1.0)

func set_discount(id: String, pct: float, label := "") -> void:
	discounts[id] = {"pct": maxf(pct, 0.0), "label": label}

func clear_discount(id: String) -> void:
	discounts.erase(id)

## Sum of all sources before the cap.
func raw_discount() -> float:
	var total := 0.0
	for id in discounts:
		total += float(discounts[id].pct)
	return total

## What prices actually use: never above MAX_DISCOUNT.
func discount() -> float:
	return minf(raw_discount(), MAX_DISCOUNT)

## Footer text, e.g. "Mango likes you: -6%". Empty when nothing applies.
func discount_label() -> String:
	var parts := PackedStringArray()
	for id in discounts:
		var d: Dictionary = discounts[id]
		if d.pct > 0.0:
			parts.append("%s: -%d%%" % [d.label if d.label != "" else id, roundi(d.pct * 100.0)])
	var text := "   ".join(parts)
	if raw_discount() > MAX_DISCOUNT:
		text += "   (capped at %d%%)" % roundi(MAX_DISCOUNT * 100.0)
	return text

## Undiscounted price at this shop (what the UI strikes through).
func list_price(base: int, door_id: String) -> int:
	return final_price(base, city_mult(), shop_roll(door_id), 0.0)

func price(base: int, door_id: String) -> int:
	return final_price(base, city_mult(), shop_roll(door_id), discount())

func spend_treats(n: int) -> bool:
	if g.player.treats < n:
		return false
	g.player.treats -= n
	return true

func add_bones(n: int) -> void:
	bones += maxi(n, 0)

func spend_bones(n: int) -> bool:
	if bones < n:
		return false
	bones -= n
	return true
