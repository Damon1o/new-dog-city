extends "res://scripts/npc.gd"
## Street pedestrian: wanders like a park dog (npc.gd), but screams and runs when a bark wave
## passes close or a raccoon / rat gets near. Never talks. The dog's bite hurts them (game.on_bite);
## a kill maxes the wanted level (5 stars).

const HEAR := 200.0    # bark wave this close = scream
const THREAT := 110.0  # raccoon / rat this close = scream
const RUN := 190.0
const SKIN := [Color(0.98, 0.84, 0.7), Color(0.85, 0.65, 0.48), Color(0.6, 0.42, 0.3), Color(0.4, 0.27, 0.2)]

var scream_t := 0.0   # > 0 while screaming and running
var scream_cd := 0.0  # one scream per scare, not one per frame
var hp := 20.0
var flee := Vector2.ZERO
var skin: Color
var hair: Color

func setup_human(p_g: Node2D, at: Vector2) -> void:
	setup(p_g, "", Color.from_hsv(randf(), 0.55, 0.85), Rect2(at - Vector2(150, 150), Vector2(300, 300)), at)
	rng.seed = hash(at)
	skin = SKIN[randi() % SKIN.size()]
	hair = Color.from_hsv(randf_range(0.05, 0.12), 0.6, randf_range(0.1, 0.6))
	remove_from_group("npc")  # "npc" = talkable park dogs
	add_to_group("human")

## Position of whatever scares this human, or null.
func threat() -> Variant:
	for w in get_tree().get_nodes_in_group("bark"):
		if w.position.distance_to(position) < HEAR:
			return w.position
	for f in get_tree().get_nodes_in_group("raccoon") + get_tree().get_nodes_in_group("prey"):
		if f.visible and f.get("kind") in [null, "rat"] and f.position.distance_to(position) < THREAT:
			return f.position  # raccoon.gd has no kind; cats / pigeons / squirrels don't scare anyone
	return null

func scream(from: Vector2) -> void:
	scream_t = 1.4
	scream_cd = 2.5
	flee = from.direction_to(position)
	if flee == Vector2.ZERO:
		flee = Vector2.RIGHT
	Sound.sfx("scream")

func hurt(dmg: float) -> void:
	hp -= dmg
	g.float_text(position, "-%d" % dmg, Color(1, 0.4, 0.4))
	if hp > 0.0:
		scream(g.player.position)
		return
	g.poof(position, Color(0.8, 0.1, 0.1))
	g.float_text(position + Vector2(0, -20), "WANTED!", Color(1, 0.2, 0.2))
	g.wanted.add_heat(g.wanted.MAX_HEAT, "human")  # 5 stars
	queue_free()

func _process(delta: float) -> void:
	scream_cd -= delta
	queue_redraw()
	if scream_t > 0.0:
		scream_t -= delta
		var step := flee * RUN * delta
		if not g.blocked(position + step):
			position += step
		goal = position  # rest where the run ends
		scale.x = -1.0 if flee.x < 0.0 else 1.0
		return
	if scream_cd <= 0.0:
		var src = threat()
		if src != null:
			scream(src)
			return
	super(delta)

func _draw() -> void:
	var scared := scream_t > 0.0
	draw_rect(Rect2(-5, 0, 4, 12), Color(0.2, 0.22, 0.35))   # legs
	draw_rect(Rect2(1, 0, 4, 12), Color(0.2, 0.22, 0.35))
	draw_rect(Rect2(-7, -16, 14, 16), color)                  # shirt
	for s in [-1.0, 1.0]:                                     # arms: up when screaming
		draw_line(Vector2(6 * s, -14), Vector2(12 * s, -30) if scared else Vector2(8 * s, -2), skin, 3.0)
	draw_circle(Vector2(0, -22), 6.0, skin)                   # head
	draw_rect(Rect2(-6, -29, 12, 4), hair)
	if scared:
		draw_circle(Vector2(0, -19), 2.2, Color.BLACK)        # open mouth
		draw_set_transform(Vector2.ZERO, 0.0, scale)          # undo the walk flip so text reads left to right
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-18, -36), "AAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
		draw_string(font, Vector2(-18, -36), "AAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))
