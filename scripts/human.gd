extends "res://scripts/npc.gd"
## Street pedestrian: wanders like a park dog (npc.gd), but screams and runs when a bark wave
## passes close or a raccoon / rat gets near. Never talks. The dog's bite hurts them (game.on_bite);
## a kill maxes the wanted level (5 stars).

const HEAR := 200.0    # bark wave this close = scream
const THREAT := 110.0  # raccoon / rat this close = scream
const RUN := 190.0
const Person := preload("res://scripts/person_art.gd")

var scream_t := 0.0   # > 0 while screaming and running
var scream_cd := 0.0  # one scream per scare, not one per frame
var hp := 20.0
var flee := Vector2.ZERO
var look: Dictionary  # person_art.gd outfit
var homeless := false  # subway platform: sits on a blanket by a cardboard sign, used to the rats
var sign_text := ""

const SIGNS := ["ANYTHING
HELPS", "HUNGRY
GOD BLESS", "NEED BUS
FARE HOME", "SMILE :)", "VETERAN
PLS HELP"]

func setup_human(p_g: Node2D, at: Vector2, p_homeless := false) -> void:
	setup(p_g, "", "", 1.0, Rect2(at - Vector2(150, 150), Vector2(300, 300)), at)
	rng.seed = hash(at)
	look = Person.random_look(rng)
	homeless = p_homeless
	if homeless:  # worn layers: dull coat, beanie, no bag
		look.shirt = look.shirt.darkened(0.45).lerp(Color(0.4, 0.36, 0.3), 0.5)
		look.pants = look.pants.darkened(0.3)
		look.hat = "beanie"
		look.hat_col = Color(0.35, 0.3, 0.25).lerp(look.hat_col, 0.3)
		look.bag = false
		sign_text = SIGNS[rng.randi() % SIGNS.size()]
	remove_from_group("npc")  # "npc" = talkable park dogs
	add_to_group("human")
	add_to_group("person")  # game.on_bite hurts every person

## Position of whatever scares this human, or null.
func threat() -> Variant:
	for w in get_tree().get_nodes_in_group("bark"):
		if w.position.distance_to(position) < HEAR:
			return w.position
	if homeless:
		return null  # bark waves only: subway regulars shrug off rats
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
	Person.hit(self, g, dmg, hp <= 0.0)
	if hp > 0.0:
		scream(g.player.position)
		return
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
		anim_t += delta * 14.0  # sprinting legs
		return
	if scream_cd <= 0.0:
		var src = threat()
		if src != null:
			scream(src)
			return
	if homeless:
		scale.x = 1.0  # sign text reads left to right
		return  # sits where it is (or where the last run ended)
	super(delta)

func _draw() -> void:
	var scared := scream_t > 0.0
	if homeless and not scared:
		draw_sitting()
		return
	var swing := sin(anim_t * PI / 2.0) * 3.0  # npc.gd anim_t ticks 8/s walking, 14/s running
	Person.draw(self, look, swing, "up" if scared else "walk", "scream" if scared else "")
	if scared:
		draw_set_transform(Vector2.ZERO, 0.0, scale)  # undo the walk flip so text reads left to right
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-18, -40), "AAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
		draw_string(font, Vector2(-18, -40), "AAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))

## Sitting on the platform: blanket over the legs, cup out front, cardboard sign propped beside.
func draw_sitting() -> void:
	draw_colored_polygon(Person.ellipse(Vector2(0, 13), 20, 4), Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2(0, 9))  # hips down at floor level
	Person.draw(self, look, 0.0, "walk", "")
	draw_set_transform(Vector2.ZERO)
	Person.box(self, Rect2(-13, 5, 26, 8), Color(0.42, 0.5, 0.36))  # blanket
	draw_rect(Rect2(-13, 8, 26, 2), Color(0.3, 0.36, 0.26))
	Person.box(self, Rect2(14, 6, 5, 6), Color(0.9, 0.88, 0.8))  # cup
	draw_rect(Rect2(14, 7, 5, 1), Color(0.6, 0.15, 0.12))
	Person.box(self, Rect2(-34, -14, 22, 26), Color(0.72, 0.56, 0.36))  # cardboard sign
	var font := ThemeDB.fallback_font
	var y := -6.0
	for line in sign_text.split("
"):
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_string(font, Vector2(-23 - w / 2.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.12, 0.1, 0.08))
		y += 8.0
