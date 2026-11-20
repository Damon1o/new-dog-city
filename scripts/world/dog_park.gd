extends Node2D
## Dog park (spec 03): the city's `dog_park` block (data/cities.gd), built by city_builder.gd.
## Fence drawn in code, HP regen 5/s inside, animal control stops at the fence (officer.gd and
## wanted.gd ask g.city.in_dog_park), and the three quest dogs (spec 07, chains in data/quests.gd).

const NPC := preload("res://scripts/npc.gd")
const REGEN := 5.0
const RACE_TIME := 60.0
const TALK_DIST := 50.0
const GATE := 96.0  # gap in the middle of each fence side
# spec 07 dogs per city: [name (= its quest line), coat]. ponytail: NYC only until SF / Tokyo / Shenzhen exist.
const DOGS := {"nyc": [["Biscuit", Color(0.85, 0.6, 0.3)], ["Duchess", Color(0.95, 0.92, 0.95)],
	["Old Rex", Color(0.45, 0.32, 0.2)]]}
# What each dog says at quest steps 1..3 of its line, then once the line is done.
const LINES := {
	"Biscuit": ["My ball rolled off into another park! Follow your GPS and sniff it out?",
		"Ball's back! Now those pigeons keep stealing my crumbs. Scatter 10 of them for me.",
		"Ha! Last thing: a real city dog claims blocks. Mark 3 of them.",
		"You're a proper street dog now. Keep the cap!"],
	"Duchess": ["Darling, I simply must have a cafe cup. Pop into the cafe for me?",
		"Lovely. Now walk me across two roads, I don't do traffic alone.",
		"One more: race you to the Empire State Building! Go!",
		"You won fair and square. Here, a little something."],
	"Old Rex": ["Kid, the King of Raccoons runs a park near here. Knock him off his throne.",
		"Not bad. Black cats rule the alleys at night. Beat 3 of them after dark.",
		"Last lesson: see the pound for yourself. Know what you're running from.",
		"You've seen it all now. Take these bones."],
}

var g: Node2D
var rect := Rect2()
var dogs := {}  # name -> npc.gd
var near: Node2D  # dog the F prompt points at
var ball := Vector2.ZERO  # Biscuit's ball on the street map, ZERO = none out
var race_t := 0.0
var race_at := Vector2.ZERO  # finish line
var escort_block := Vector2i(-1, -1)

func setup(p_g: Node2D, r: Rect2, city_id: String) -> void:
	g = p_g
	rect = r
	z_index = -9  # flat on the grass, over the ground layer
	for i in DOGS.get(city_id, []).size():
		var d: Array = DOGS[city_id][i]
		var n: Node2D = NPC.new()
		n.setup(g, d[0], d[1], r.grow(-70), r.position + Vector2(110 + i * 140, 90))
		n.on_talk = lines_for.bind(d[0])
		get_parent().add_child(n)
		dogs[d[0]] = n

func step(line: String) -> int:
	return int(g.quest_step.get(line, 0))

## Talk hook: the first talk starts the line, and some steps set up their task.
func lines_for(line: String) -> Array:
	g.bump("met_" + line.to_lower().replace(" ", "_"), true)
	var i := step(line)
	match [line, i]:
		["Biscuit", 1]:
			var p: Vector2 = g.city.block_origin(g.PARKS[4]) + Vector2(80, 330)  # ponytail: GPS stands in for the sniff trail (M5-3)
			ball = p
			g.waypoint = {"pos": p, "text": "Biscuit's ball", "color": Color(0.9, 0.9, 0.3)}
		["Duchess", 2]:
			dogs.Duchess.follow = g.player
			escort_block = g.territory.block_of(dogs.Duchess.position)
		["Duchess", 3]:
			race_t = RACE_TIME
			var es: Array = g.landmarks.filter(func(l): return l.name == "Empire State Building")
			if es:
				race_at = es[0].pos
				g.waypoint = es[0]
	return [LINES[line][clampi(i - 1, 0, 3)]]

func _process(delta: float) -> void:
	var p: CharacterBody2D = g.player
	if g.inside == "" and not p.dead and rect.has_point(p.position):
		p.hp = minf(p.hp + REGEN * delta, p.max_hp)
	near = null
	if g.inside == "" and g.act == "" and not p.frozen:
		for d: Node2D in dogs.values():
			if d.position.distance_to(p.position) < TALK_DIST:
				near = d
				g.set_act("talk", d.npc_name.to_upper(), "[%s]  Talk" % g.Keys.label("interact"))
				break
	if ball != Vector2.ZERO and g.inside == "" and p.position.distance_to(ball) < 40.0:
		ball = Vector2.ZERO
		g.float_text(p.position, "Got the ball!", Color(0.9, 0.9, 0.3))
		g.bump("ball")
	var duchess: Node2D = dogs.get("Duchess")
	if duchess and duchess.follow:
		var b: Vector2i = g.territory.block_of(duchess.position)
		if b != escort_block:
			escort_block = b
			g.bump("escort")
		if step("Duchess") != 2:  # walked far enough: she trots home
			duchess.follow = null
			duchess.position = rect.position + Vector2(250, 90)
			duchess.goal = duchess.position
	if race_t > 0.0:
		race_t -= delta
		if g.inside == "" and p.position.distance_to(race_at) < 150.0:
			race_t = 0.0
			g.bump("race")
		elif race_t <= 0.0:
			g.show_msg("Duchess won the race. Talk to her for a rematch.")
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and near and g.act == "talk" and g.Keys.action_of(event) == "interact":
		near.talk()

func _draw() -> void:
	var r := rect.grow(-6)
	var wood := Color(0.55, 0.4, 0.25)
	var mid := r.get_center()
	for side: Array in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.position.x, r.end.y), r.end],
			[r.position, Vector2(r.position.x, r.end.y)], [Vector2(r.end.x, r.position.y), r.end]]:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var gate_a := a.lerp(b, 0.5) - a.direction_to(b) * GATE / 2.0
		var gate_b := a.lerp(b, 0.5) + a.direction_to(b) * GATE / 2.0
		for seg: Array in [[a, gate_a], [gate_b, b]]:
			draw_line(seg[0], seg[1], wood, 3.0)  # rail
			var n := int(seg[0].distance_to(seg[1]) / 32.0)
			for k in n + 1:
				draw_rect(Rect2(seg[0].lerp(seg[1], float(k) / maxf(n, 1)) - Vector2(3, 3), Vector2(6, 6)), wood.darkened(0.3))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, mid + Vector2(-34, -150), "DOG PARK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(font, mid + Vector2(-34, -150), "DOG PARK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 1, 0.8))
	if ball != Vector2.ZERO:
		draw_circle(ball, 6.0, Color(0.85, 0.95, 0.3))
