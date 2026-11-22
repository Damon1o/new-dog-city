extends Node
## Bodega cats (spec 07): one named friendly cat on each NYC bodega counter. Friendship points
## 0-50 (10 per heart) saved as save_extra "cats/points"; daily limits as "cats/today"
## {id: [day, gifts, talked]}. F at the counter talks (once a day), then gifts (3 a day).
## Hearts take 2% each off that shop (economy discount "bodega_cat"), a story hint from 3 hearts,
## a one-time gift at 5 (first cat: Bell collar, the rest: bones). Bark inside -3, pee at the door -5.

const Keys := preload("res://scripts/systems/keys.gd")
## Shop door id (shop.gd door_id) -> [cat id, name].
## ponytail: NYC has 5 bodega doors and 4 cats, so nyc_bodega_4's counter cat is a plain prop.
const CATS := {"nyc_bodega_0": ["nyc_mango", "Mango"], "nyc_bodega_1": ["nyc_pepper", "Pepper"],
	"nyc_bodega_2": ["nyc_lotto", "Lotto"], "nyc_bodega_3": ["nyc_big_sal", "Big Sal"],
	# M6-3 SF corner stores
	"sf_bodega_0": ["sf_sourdough", "Sourdough"], "sf_bodega_1": ["sf_dim_sum", "Dim Sum"], "sf_bodega_2": ["sf_karl", "Karl"]}
const GIFTS := {"rat": 4, "purina": 3, "treats": 2}  # treats gift = 5 treats
const MAX_GIFTS := 3  # per cat per in-game day
const MAX_POINTS := 50
const GIFT_BONES := 2
const DOOR_NEAR := 120.0
const TALK := ["Mrrp?", "Mrow. You smell like the street.", "Purr. You again. Fine, sit."]
const CAT_TOP := Vector2(590, 200)  # room-local, just above the counter cat (rooms.gd bodega)

var g: Node2D
var rat := false   # a caught rat, carried in to gift (game.on_prey_caught sets it)
var badge: Node2D  # hearts over the counter cat; lives in the room, freed with it

## [cat id, name] of the cat in the bodega the dog is in, [] if none.
func here() -> Array:
	if g.inside != "shop" or g.interior.room == null or g.shop.template() != "bodega":
		return []
	return CATS.get(g.shop.door_id(), [])

func table(key: String) -> Dictionary:
	if not (g.save_extra.get(key) is Dictionary):
		g.save_extra[key] = {}
	return g.save_extra[key]

func points(id: String) -> int:
	return int(table("cats/points").get(id, 0))

func hearts(id: String) -> int:
	return points(id) / 10

## Today's [day, gifts, talked] for a cat; a new day resets it.
func today(id: String) -> Array:
	var t := table("cats/today")
	var day := int(g.save_extra.get("world/day", 1))
	if not (t.get(id) is Array) or t[id].size() < 3 or int(t[id][0]) != day:
		t[id] = [day, 0, false]
	return t[id]

func add(c: Array, n: int) -> void:
	table("cats/points")[c[0]] = clampi(points(c[0]) + n, 0, MAX_POINTS)
	if not g.save_extra.get("ui/reduce_motion", false):
		g.float_text(g.interior.O + CAT_TOP if not here().is_empty() else g.player.position, "%+d" % n, Color(1, 0.55, 0.7))
	if hearts(c[0]) == 5 and not Story.has("cat_gift_" + c[0]):
		Story.set_flag("cat_gift_" + c[0])
		var owned: Array = g.save_extra.get("wardrobe/owned", [])
		if not "bell" in owned:
			g.save_extra["wardrobe/owned"] = owned + ["bell"]
			g.show_banner("BELL COLLAR")
			g.show_msg("%s gave you a Bell collar (B to wear it)" % c[1])
		else:
			g.economy.add_bones(GIFT_BONES)
			g.show_msg("%s gave you %d bones" % [c[1], GIFT_BONES])

## F at the counter. false = no named cat here (F falls through).
func interact() -> bool:
	var c := here()
	if c.is_empty():
		return false
	var t := today(c[0])
	var line: String
	if not t[2]:
		t[2] = true
		add(c, 1)
		line = ("Psst. Word on the block: %s." % Story.objective()) if hearts(c[0]) >= 3 else TALK[mini(hearts(c[0]), TALK.size() - 1)]
	else:
		line = gift(c)
	g.dialog.play("bodega_cat", [{"say": c[1], "text": line}])
	g.save_game()
	return true

## Best thing in the dog's paws: rat, then Purina, then 5 treats. Only 3 a day count.
func gift(c: Array) -> String:
	var kind := "rat" if rat else ("purina" if g.player.purina > 0 else ("treats" if g.player.treats >= 5 else ""))
	if kind == "":
		return "*stares at your empty paws*  (gift a rat, a Purina or 5 treats)"
	var t := today(c[0])
	if t[1] >= MAX_GIFTS:
		return "*too full to care*  Come back tomorrow."
	t[1] += 1
	match kind:
		"rat":
			rat = false
		"purina":
			g.player.purina -= 1
		"treats":
			g.player.treats -= 5
	var bell: bool = g.save_extra.get("wardrobe/equipped", {}).get("collar", "") == "bell"  # spec 05: +1 per gift
	add(c, GIFTS[kind] + (1 if bell else 0))
	return {"rat": "*eyes widen*  ...For me? Respect.", "purina": "*crunch crunch*  Mrrp.", "treats": "*sniffs*  Acceptable."}[kind]

## Barking inside the shop scares the cat.
func on_bark() -> void:
	var c := here()
	if not c.is_empty():
		add(c, -3)
		g.show_msg("%s hisses at you!" % c[1])

## Peeing near a bodega door upsets that cat.
func on_pee(at: Vector2) -> void:
	for i in g.bodega_doors.size():
		var c: Array = CATS.get("%s_bodega_%d" % [g.save_extra.get("world/city", "nyc"), i], [])
		if not c.is_empty() and at.distance_to(g.bodega_doors[i]) < DOOR_NEAR:
			add(c, -5)
			g.show_msg("%s saw that. Not cool." % c[1])

func _process(_delta: float) -> void:
	var c := here()
	if c.is_empty():
		g.economy.clear_discount("bodega_cat")
		return
	g.economy.set_discount("bodega_cat", hearts(c[0]) * 0.02, "%s likes you" % c[1])
	if not is_instance_valid(badge) or badge.is_queued_for_deletion():
		badge = Node2D.new()
		badge.z_index = 5
		badge.position = g.interior.O + CAT_TOP
		badge.draw.connect(draw_badge)
		g.interior.room.add_child(badge)
	badge.queue_redraw()

## Name, 5 hearts and the F prompt over the counter cat.
func draw_badge() -> void:
	var c := here()
	if c.is_empty():
		return
	var font := ThemeDB.fallback_font
	badge.draw_string(font, Vector2(-40, -22), c[1], HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color.WHITE)
	for i in 5:
		var p := Vector2(-24 + i * 12, -10)
		var col := Color(1, 0.4, 0.6) if i < hearts(c[0]) else Color(0.25, 0.2, 0.25)
		badge.draw_circle(p + Vector2(-2.5, 0), 3.0, col)
		badge.draw_circle(p + Vector2(2.5, 0), 3.0, col)
		badge.draw_colored_polygon(PackedVector2Array([p + Vector2(-5.4, 1), p + Vector2(5.4, 1), p + Vector2(0, 7)]), col)
	if g.ctx == "bodega":
		var verb := "Talk" if not today(c[0])[2] else "Gift"
		badge.draw_string(font, Vector2(-50, 20), "[%s] %s" % [Keys.label("interact").get_slice(" / ", 0), verb],
			HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color(1, 0.9, 0.4))
