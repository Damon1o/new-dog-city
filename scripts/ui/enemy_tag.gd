extends Node2D
## Overhead tag for common enemies (spec 06 "Overhead UI"): "Name Lv N" tinted by the
## level gap to Byte, and a 38 x 6 HP bar. Parent needs level, hp, max_hp.
## Shown for 3 s after a hit, or while Byte is within 260 px.

const SHOW_DIST := 260.0
const HOLD := 3.0

var player: Node2D
var label := Label.new()
var hold := 0.0

func setup(p_name: String, p_player: Node2D) -> void:
	player = p_player
	label.text = "%s Lv %d" % [p_name, get_parent().level]
	label.position = Vector2(-60, -52)
	label.size = Vector2(120, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	z_index = 10
	visible = false

## Grey 5+ below Byte, white within 4, orange 5-9 above, red 10+ above.
static func level_color(gap: int) -> Color:
	if gap <= -5:
		return Color(0.6, 0.6, 0.6)
	if gap >= 10:
		return Color(1, 0.25, 0.2)
	if gap >= 5:
		return Color(1, 0.6, 0.15)
	return Color.WHITE

func hit() -> void:
	hold = HOLD
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	hold = maxf(hold - delta, 0.0)
	visible = hold > 0.0 or player.position.distance_to(get_parent().position) < SHOW_DIST
	if visible:
		label.add_theme_color_override("font_color", level_color(get_parent().level - player.level))

func _draw() -> void:
	var p := get_parent()
	draw_rect(Rect2(-19, -31, 38, 6), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-18, -30, 36.0 * clampf(p.hp / p.max_hp, 0.0, 1.0), 4), Color(0.9, 0.2, 0.2))
