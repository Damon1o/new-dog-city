extends Node2D
## Friendly NPC (spec 07): drawn in code, idle wander inside `area`, talk() opens the shared
## dialog box (scripts/ui/dialog.gd). Never damaged: game.on_bite never looks at the "npc" group.

const SPEED := 70.0

var g: Node2D
var npc_name := ""
var color := Color.WHITE
var area := Rect2()
var follow: Node2D     # walk after this node instead of wandering (escort quests)
var on_talk: Callable  # quest-giver hook: returns the lines to say
var goal := Vector2.ZERO
var rest := 0.0
var rng := RandomNumberGenerator.new()  # own rng: the global one is seeded for tests and the city

func setup(p_g: Node2D, p_name: String, p_color: Color, p_area: Rect2, at: Vector2) -> void:
	g = p_g
	npc_name = p_name
	color = p_color
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
			return
	elif position.distance_to(goal) < 4.0:
		rest -= delta
		if rest <= 0.0:
			rest = rng.randf_range(1.0, 4.0)
			goal = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		return
	var step := position.direction_to(to) * SPEED * (2.5 if follow else 1.0) * delta
	if not g.blocked(position + step):  # ponytail: no pathfinding, a stuck dog picks a new goal on its next rest
		position += step
	else:
		goal = position
	scale.x = -1.0 if step.x < 0.0 else 1.0
	queue_redraw()

func talk() -> void:
	var lines: Array = on_talk.call() if on_talk.is_valid() else ["Woof!"]
	g.dialog.play("npc", lines.map(func(t): return {"say": npc_name, "text": t, "face": draw_dog.bind(color)}))

func _draw() -> void:
	draw_dog(self, color)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_set_transform(Vector2.ZERO, 0.0, scale)  # undo the flip so the name reads left to right
	draw_string_outline(font, Vector2(-w / 2.0, -26), npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
	draw_string(font, Vector2(-w / 2.0, -26), npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)

## The dog figure, on any canvas item: this node in the world, the dialog portrait when talking.
static func draw_dog(ci: CanvasItem, c: Color) -> void:
	var dark := c.darkened(0.35)
	ci.draw_rect(Rect2(-12, -10, 22, 10), c)        # body
	for x in [-11.0, -4.0, 3.0, 8.0]:
		ci.draw_rect(Rect2(x, 0, 3, 7), dark)           # legs
	ci.draw_line(Vector2(-12, -8), Vector2(-18, -15), dark, 3.0)  # tail
	ci.draw_circle(Vector2(12, -13), 6.0, c)        # head
	ci.draw_rect(Rect2(9, -18, 4, 8), dark)             # ear
	ci.draw_circle(Vector2(17, -12), 1.8, Color.BLACK)  # nose
