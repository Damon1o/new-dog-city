extends Node2D
## Territory (spec 05): hold G by a tree, hydrant or building corner to leave a marker.
## 3 markers claim a city block; markers fade after 3 in-game days unless re-marked.
## Reputation per city with tiers; a rival dog hits claimed blocks at night.
## Markers live in g.save_extra["territory/markers"] as {city, pos, day} (spec 13).
## ponytail: claimed-block perks (prices -5%, prey XP +10%, enemies -1 level) and the Top Dog
## hat aren't wired; shop / XP / spawner / wardrobe can read claimed() and tier() when they want them.

const Spawns := preload("res://scripts/data/spawns.gd")
const Levels := preload("res://scripts/systems/levels.gd")
const HOLD := 1.2
const NEAR := 40.0
const COST := 10.0
const MIN_THIRST := 15.0
const CLAIM := 3
const FADE_DAYS := 3
const TIERS := [["Top Dog", 400], ["Regular", 150], ["Local", 50], ["Stray", 0]]
const RIVAL := {"hp": 120.0, "dmg": 12.0, "xp": 40, "treats": 5}  # spec 06, at level 1

var g: Node2D
var hold := 0.0
var last_tod := -1.0
var night := false
var rival: Node2D  # raccoon.gd wearing a dog skin, see rival_night
var rival_mark := {}

func _ready() -> void:
	z_index = -5  # over the ground, under everything that walks

func _process(delta: float) -> void:
	if Input.is_action_pressed("pee") and not g.player.frozen:
		if hold >= 0.0:
			hold += delta
			if hold >= HOLD:
				hold = -1.0  # once per hold
				pee()
	else:
		hold = 0.0
	if last_tod < 0.0:
		queue_redraw()  # first frame: the save just loaded its markers
	elif g.tod < last_tod:
		new_day()
	last_tod = g.tod
	var dark: bool = Spawns.phase(g.sun()) == "night"
	if dark != night:
		night = dark
		if dark:
			rival_night()
		else:
			rival_dawn()
	# ponytail: raccoon.gd's go_home(25) after a beat-down is the "beaten" signal; add a signal if more foes need it
	if rival and rival.hide_cooldown > 0.0:
		g.show_msg("The rival dog ran off!")
		rival.queue_free()
		rival = null

func markers() -> Array:
	if not (g.save_extra.get("territory/markers") is Array):
		g.save_extra["territory/markers"] = []
	return g.save_extra["territory/markers"]

func rep() -> Dictionary:
	if not (g.save_extra.get("territory/rep") is Dictionary):
		g.save_extra["territory/rep"] = {}
	return g.save_extra["territory/rep"]

func day() -> int:
	return int(g.save_extra.get("world/day", 1))

## The city block a point belongs to (nearest block center).
func block_of(p: Vector2) -> Vector2i:
	var step: Vector2 = g.BLOCK + Vector2(g.ROAD, g.ROAD)
	var b: Vector2 = ((p - Vector2(g.ROAD, g.ROAD) - g.BLOCK / 2.0) / step).round()
	return Vector2i(clampi(int(b.x), 0, g.NX - 1), clampi(int(b.y), 0, g.NY - 1))

func count(b: Vector2i) -> int:
	return markers().filter(func(m): return m.city == g.city.id and block_of(m.pos) == b).size()

func claimed(b: Vector2i) -> bool:
	return count(b) >= CLAIM

func tier(city: String = g.city.id) -> String:
	var r: int = rep().get(city, 0)
	for t in TIERS:
		if r >= t[1]:
			return t[0]
	return "Stray"

## ponytail: no lamp posts on the map yet, so trees, hydrants / water and building corners.
func pee_spot(at: Vector2) -> bool:
	for p: Vector2 in g.trees + g.water_spots:
		if at.distance_to(p) < NEAR:
			return true
	for r: Rect2 in g.building_rects:
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			if at.distance_to(c) < NEAR:
				return true
	return false

func pee(at: Vector2 = g.player.position) -> bool:
	if g.inside != "":
		g.show_msg("Not here!")
		return false
	if g.player.thirst < MIN_THIRST:
		g.show_msg("Too thirsty. Find water first")
		return false
	if not pee_spot(at):
		g.show_msg("Find a tree, hydrant or corner")
		return false
	g.player.thirst -= COST
	# spec 05: peeing within 300 px of an officer adds heat
	if g.get("wanted") and get_tree().get_nodes_in_group("officer").any(func(o): return o.position.distance_to(at) < 300.0):
		g.wanted.add_heat(10, "pee")
	for m in markers():
		if m.city == g.city.id and m.pos.distance_to(at) < NEAR:
			m.day = day()  # re-marked: the fade clock restarts
			g.float_text(at, "re-marked", Color(1, 0.9, 0.3))
			queue_redraw()
			return true
	markers().append({"city": g.city.id, "pos": at, "day": day()})
	add_rep(2)
	g.float_text(at, "marked!", Color(1, 0.9, 0.3))
	if count(block_of(at)) == CLAIM:
		add_rep(10)
		g.show_banner("BLOCK CLAIMED")
		g.bump("blocks")  # quest hook "Claim 3 blocks"
	queue_redraw()
	return true

func add_rep(n: int, city: String = g.city.id) -> void:
	var before := tier(city)
	rep()[city] = maxi(int(rep().get(city, 0)) + n, 0)
	if n > 0 and tier(city) != before:
		g.show_banner(tier(city).to_upper())

## Called when the clock wraps: day counter +1, old markers fade (-2 rep each).
func new_day() -> void:
	g.save_extra["world/day"] = day() + 1
	for m in markers().duplicate():
		if day() - int(m.day) >= FADE_DAYS:
			markers().erase(m)
			add_rep(-2, m.city)
	queue_redraw()

## Nightfall: one rival dog waits on a marker in a claimed block (level = city band max).
## ponytail: it reuses raccoon.gd's ambush AI and sits on its marker instead of walking the blocks.
func rival_night() -> void:
	var mine := markers().filter(func(m): return m.city == g.city.id and claimed(block_of(m.pos)))
	if mine.is_empty() or rival:
		return
	rival_mark = mine.pick_random()
	rival = g.RaccoonScript.new()
	g.add_child(rival)
	rival.setup(rival_mark.pos, g.player.sprite.texture, g)
	rival.sprite.hframes = 2  # dog sheets are 2 frames wide
	rival.modulate = Color(0.55, 0.45, 0.4)
	rival.level = Levels.NYC_BAND.y
	rival.stats = Levels.scale_for_level(RIVAL, rival.level)
	rival.tag.label.text = "Rival dog Lv %d" % rival.level
	g.show_msg("A rival dog is sniffing round your turf...")

## Dawn: an unbeaten rival overwrites its marker.
func rival_dawn() -> void:
	if not rival:
		return
	markers().erase(rival_mark)
	g.show_msg("A rival dog marked over your spot!")
	rival.queue_free()
	rival = null
	queue_redraw()

## Puddle + yellow paw per marker, fading as it ages.
func _draw() -> void:
	for m in markers():
		if m.city != g.city.id:
			continue
		var p: Vector2 = m.pos
		var c := Color(1, 0.85, 0.2, 1.0 - 0.25 * (day() - int(m.day)))
		draw_set_transform(p, 0.0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 14.0, Color(0.95, 0.85, 0.2, 0.3 * c.a))
		draw_set_transform(Vector2.ZERO)
		draw_circle(p + Vector2(0, 2), 4.5, c)
		for toe: Vector2 in [Vector2(-5, -3), Vector2(-2, -6), Vector2(2, -6), Vector2(5, -3)]:
			draw_circle(p + toe, 1.8, c)
