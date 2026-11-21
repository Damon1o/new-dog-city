extends Node2D
## Friendly NPC (spec 07): a breed sprite (assets/dog_<breed>.png, same art as the player), idle
## wander inside `area`, talk() opens the shared dialog box (scripts/ui/dialog.gd). Never damaged:
## game.on_bite never looks at the "npc" group.

const SPEED := 70.0

var g: Node2D
var npc_name := ""
var tex: Texture2D     # 2-frame walk sheet, like player.gd's sprite
var size := 2.4        # sprite scale: the breed's player.gd BREEDS scale
var anim_t := 0.0
var area := Rect2()
var follow: Node2D     # walk after this node instead of wandering (escort quests)
var on_talk: Callable  # quest-giver hook: returns the lines to say
var goal := Vector2.ZERO
var rest := 0.0
var rng := RandomNumberGenerator.new()  # own rng: the global one is seeded for tests and the city

func setup(p_g: Node2D, p_name: String, breed: String, p_size: float, p_area: Rect2, at: Vector2) -> void:
	g = p_g
	npc_name = p_name
	tex = load("res://assets/dog_%s.png" % breed) if breed != "" else null  # "" = draws itself (human.gd)
	size = p_size
	area = p_area
	position = at
	goal = at
	rng.seed = hash(p_name)
	add_to_group("npc")

func _process(delta: float) -> void:
	var to := goal
	if follow and g.inside == "":
		to = follow.position
		if position.distance_to(to) < 50.0:
			stand()
			return
	elif position.distance_to(goal) < 4.0:
		rest -= delta
		if rest <= 0.0:
			rest = rng.randf_range(1.0, 4.0)
			goal = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		stand()
		return
	var step := position.direction_to(to) * SPEED * (2.5 if follow else 1.0) * delta
	if not g.blocked(position + step):  # ponytail: no pathfinding, a stuck dog picks a new goal on its next rest
		position += step
	else:
		goal = position
	scale.x = -1.0 if step.x < 0.0 else 1.0
	anim_t += delta * (14.0 if follow else 8.0)  # player.gd's walk / sprint frame rates
	queue_redraw()

func stand() -> void:
	if anim_t != 0.0:
		anim_t = 0.0
		queue_redraw()

func talk() -> void:
	var lines: Array = on_talk.call() if on_talk.is_valid() else ["Woof!"]
	g.dialog.play("npc", lines.map(func(t): return {"say": npc_name, "text": t, "face": draw_dog.bind(tex, 2.2, 0)}))

func _draw() -> void:
	draw_dog(self, tex, size, int(anim_t) % 2)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var y := -5.0 * size - 6.0  # just over the sprite's head
	draw_set_transform(Vector2.ZERO, 0.0, scale)  # undo the flip so the name reads left to right
	draw_string_outline(font, Vector2(-w / 2.0, y), npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
	draw_string(font, Vector2(-w / 2.0, y), npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)

## The dog figure, on any canvas item: this node in the world, the dialog portrait when talking.
## One frame of the 2-frame sheet, centred like player.gd's Sprite2D.
static func draw_dog(ci: CanvasItem, t: Texture2D, s: float, frame: int) -> void:
	var fw := t.get_width() / 2.0
	var fh := float(t.get_height())
	ci.draw_texture_rect_region(t, Rect2(-fw * s / 2.0, -fh * s / 2.0, fw * s, fh * s), Rect2(frame * fw, 0, fw, fh))
