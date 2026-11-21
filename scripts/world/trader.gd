extends Node
## Pocket the wandering trader (spec 07, 09): an old opossum with a shopping cart. Each in-game
## day, 50% he parks on a random sidewalk of the city the dog is in. He shows as a "Pocket" POI
## (minimap dot, GPS, street tag) with a pulsing ring on the minimap. On the street next to him
## game.gd sets ctx "trader": [1-4] buys from his 4 entries of Items.TRADER, F talks (one story
## hint per city). Saved as save_extra "trader/visit" {day, city, pos, stock} and "trader/hinted".

const Items := preload("res://scripts/data/items.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const CHANCE := 0.5
const STOCK := 4
const NEAR := 50.0

var g: Node2D
var body: Node2D  # Pocket and his cart on the street
var poi := {}     # entry in g.pois while he's in this city

## Today's visit; rolls a new one when the day changes. pos.x < 0 = not in town today.
func visit() -> Dictionary:
	var day := int(g.save_extra.get("world/day", 1))
	var v: Variant = g.save_extra.get("trader/visit")
	if v is Dictionary and int(v.get("day", 0)) == day:
		return v
	g.save_extra["trader/visit"] = roll(day, str(g.save_extra.get("world/city", "nyc")))
	v = g.save_extra["trader/visit"]
	if v.pos.x >= 0.0:
		g.show_msg("GPS: Pocket is in town")
	return v

## Own RNG seeded from the day and city: the same day always rolls the same visit and the
## global random stream (prey, crits) is left alone.
func roll(day: int, city: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, city, g.rng_seed])
	var pos := Vector2(-1, -1)
	if rng.randf() < CHANCE:
		pos = sidewalk(rng)
	var pool: Array = Items.TRADER.keys()
	var stock := []
	for i in STOCK:
		stock.append(pool.pop_at(rng.randi() % pool.size()))
	return {"day": day, "city": city, "pos": pos, "stock": stock}

## A free spot just off a road (the sidewalk strip), clear of buildings, trees and cans.
func sidewalk(rng: RandomNumberGenerator) -> Vector2:
	for attempt in 40:
		var p := Vector2(rng.randf_range(0, g.WORLD.x), rng.randf_range(0, g.WORLD.y))
		var r: Vector2 = g.city.nearest_road(p)
		if r.distance_to(p) < 1.0:
			continue
		var s: Vector2 = r + r.direction_to(p) * (g.ROAD / 2.0 + 26.0)
		if not g.city.blocked(s) and not g.city.on_road(s):
			return s
	return g.city.nearest_road(g.player.position)  # ponytail: never seen; on the road beats nowhere

## Where Pocket stands in the current city, or (-1, -1).
func spot() -> Vector2:
	var v := visit()
	return v.pos if v.city == g.city.id else Vector2(-1, -1)

func near(at: Vector2) -> bool:
	var p := spot()
	return g.inside == "" and p.x >= 0.0 and at.distance_to(p) < NEAR

func stock() -> Array:
	return visit().stock

func sold_out(id: String) -> bool:
	var owned: Array = g.save_extra.get("wardrobe/owned", [])
	return (id == "spiked" and "spiked" in owned) or (id == "rare_skin" and "rare:%d" % g.player.skin in owned)

func afford(id: String) -> bool:
	var e: Array = Items.TRADER[id]
	return (g.player.treats if e[2] == "treats" else g.economy.bones) >= int(e[1])

## Menu rows for game.show_menu.
func rows() -> Array:
	var out := []
	for i in stock().size():
		var id: String = stock()[i]
		var e: Array = Items.TRADER[id]
		out.append(["[%d]  %s  %d %s   %s%s" % [i + 1, e[0], e[1], e[2], e[3], "   (owned)" if sold_out(id) else ""],
			afford(id) and not sold_out(id)])
	out.append(["[%s]  Chat      Wallet: %d treats  %d bones" % [Keys.label("interact").get_slice(" / ", 0),
		g.player.treats, g.economy.bones], true])
	return out

func buy(n: int) -> bool:
	if n < 0 or n >= stock().size():
		return false
	var id: String = stock()[n]
	var e: Array = Items.TRADER[id]
	if sold_out(id):
		g.show_msg("You already have that")
		return false
	if not (g.economy.spend_treats(e[1]) if e[2] == "treats" else g.economy.spend_bones(e[1])):
		g.show_msg("Need %d %s for that" % [e[1], e[2]])
		return false
	g.sfx("buy")
	var p: Node = g.player
	match id:
		"xp_snack":
			p.consume("xp_snack")
		"mustache":
			g.wanted.add_heat(-25.0)
		"spiked", "rare_skin":
			# ponytail: "rare:<breed>" is only recorded; the wardrobe has no color variants to draw yet
			g.save_extra["wardrobe/owned"] = g.save_extra.get("wardrobe/owned", []) + ["spiked" if id == "spiked" else "rare:%d" % p.skin]
		"mega_purina":
			p.hp = p.max_hp
			p.hunger = 100.0
			p.thirst = 100.0
		"map_scrap":
			for i in g.bodega_doors.size():  # ponytail: marks last until the city is rebuilt, not saved
				var cat: Array = g.cats.CATS.get("%s_bodega_%d" % [g.city.id, i], [])
				if not cat.is_empty():
					g.pois.append({"pos": g.bodega_doors[i], "text": cat[1], "color": Color(1, 0.55, 0.7)})
	g.show_msg("Bought %s" % e[0])
	g.bump("bought")
	g.save_game()
	return true

## F next to Pocket: the first chat in each city is a hint about the story target.
func talk() -> void:
	var hinted: Array = g.save_extra.get("trader/hinted", [])
	var line := "Heh. Pocket sells, Pocket don't ask. Cart's open, pup."
	if not g.city.id in hinted:
		g.save_extra["trader/hinted"] = hinted + [g.city.id]
		line = "Free tip, since I like your face: %s." % Story.objective()
	g.dialog.play("trader", [{"say": "Pocket", "text": line}])
	g.save_game()

func _process(_delta: float) -> void:
	if g.mini and not g.mini.draw.is_connected(draw_ping):
		g.mini.draw.connect(draw_ping)
	var p := spot()
	if p.x < 0.0:
		if not poi.is_empty():
			g.pois.erase(poi)
			poi = {}
		if body:
			body.hide()
		return
	if poi.is_empty() or poi.pos != p:
		g.pois.erase(poi)
		poi = {"pos": p, "text": "Pocket", "color": Color(0.75, 0.6, 1)}
		g.pois.append(poi)
	if not is_instance_valid(body):
		body = Node2D.new()
		body.draw.connect(draw_body)
		g.add_child(body)
	body.show()
	body.position = p
	body.queue_redraw()  # idle sway, name tag

## Minimap ping: a ring that grows and fades around Pocket (still ring with reduce motion).
func draw_ping() -> void:
	var p := spot()
	if p.x < 0.0:
		return
	var s: float = g.mini.size.x / g.WORLD.x
	var t := 0.5 if g.save_extra.get("ui/reduce_motion", false) else fmod(Time.get_ticks_msec() / 1200.0, 1.0)
	g.mini.draw_arc(p * s, 4.0 + 6.0 * t, 0, TAU, 16, Color(0.75, 0.6, 1, 1.0 - t * 0.8), 1.5)

## Grey opossum (white face, pink nose and tail) behind a wire shopping cart.
func draw_body() -> void:
	var sway := 0.0 if g.save_extra.get("ui/reduce_motion", false) else sin(Time.get_ticks_msec() / 400.0) * 1.5
	var fur := Color(0.62, 0.6, 0.62)
	var pink := Color(1, 0.65, 0.7)
	body.draw_line(Vector2(-14, 4), Vector2(-24, 10 + sway), pink, 2.0)  # tail
	body.draw_circle(Vector2(-6, 0), 10.0, fur)
	body.draw_circle(Vector2(4, -10 + sway), 7.0, Color(0.95, 0.95, 0.92))  # face
	body.draw_circle(Vector2(1, -16 + sway), 2.5, Color(0.2, 0.2, 0.2))   # ears
	body.draw_circle(Vector2(8, -16 + sway), 2.5, Color(0.2, 0.2, 0.2))
	body.draw_circle(Vector2(6, -11 + sway), 1.2, Color.BLACK)  # eye
	body.draw_circle(Vector2(11, -8 + sway), 1.8, pink)  # nose
	var cart := Rect2(14, -14, 26, 18)
	body.draw_rect(cart, Color(0.4, 0.4, 0.45, 0.35))
	body.draw_rect(cart, Color(0.78, 0.8, 0.85), false, 1.5)
	for x in [18, 24, 30, 36]:
		body.draw_line(Vector2(x, -14), Vector2(x, 4), Color(0.78, 0.8, 0.85, 0.6), 1.0)
	body.draw_line(Vector2(14, -14), Vector2(10, -20), Color(0.78, 0.8, 0.85), 2.0)  # handle
	body.draw_circle(Vector2(18, 8), 2.5, Color(0.15, 0.15, 0.15))
	body.draw_circle(Vector2(36, 8), 2.5, Color(0.15, 0.15, 0.15))
	if g.ctx == "trader":
		body.draw_string(ThemeDB.fallback_font, Vector2(-40, -30), "Pocket", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(0.85, 0.75, 1))
