extends RefCounted
## One HUD look (UI overhaul): glassy dark panels, soft border + shadow, blue accent.
## Set once on game.hud.theme; every Control under it inherits.

const BG := Color(0.07, 0.08, 0.12, 0.86)
const EDGE := Color(0.55, 0.75, 1.0, 0.28)
const ACCENT := Color(0.36, 0.6, 1.0)
const TEXT := Color(0.94, 0.96, 1.0)
const DIM := Color(0.62, 0.68, 0.8)

const BIG := 1.25  # "Large text" setting (spec 11 accessibility)

## Scale one Label / Button's text from the size it was built with. Safe to call repeatedly.
static func big_text(n: Node, on: bool) -> void:
	if not (n is Label or n is Button):
		return
	if not n.has_meta("fs"):
		n.set_meta("fs", n.get_theme_font_size("font_size"))
	n.add_theme_font_size_override("font_size", roundi(n.get_meta("fs") * (BIG if on else 1.0)))

static func set_big_text(root: Node, on: bool) -> void:
	for n in root.find_children("*", "Control", true, false):
		big_text(n, on)

static func box(bg := BG, radius := 10, edge := EDGE, pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("panel", "Panel", box())
	t.set_color("font_color", "Label", TEXT)
	for s in [["normal", Color(0.14, 0.16, 0.24, 0.92)], ["hover", Color(0.22, 0.32, 0.55, 0.95)],
			["pressed", ACCENT.darkened(0.15)], ["focus", Color(0, 0, 0, 0)], ["disabled", Color(0.12, 0.12, 0.16, 0.6)]]:
		var b := box(s[1], 8, EDGE if s[0] != "focus" else ACCENT, 8)
		b.shadow_size = 0
		if s[0] == "focus":
			b.set_border_width_all(2)
		t.set_stylebox(s[0], "Button", b)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 6))
	t.set_stylebox("tab_selected", "TabContainer", box(ACCENT.darkened(0.2), 8, ACCENT, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.12, 0.14, 0.2, 0.9), 8, EDGE, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.2, 0.28, 0.45, 0.95), 8, EDGE, 8))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_stylebox("slider", "HSlider", box(Color(0.2, 0.22, 0.3), 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("normal", "LineEdit", box(Color(0.1, 0.11, 0.16, 0.95), 8, EDGE, 8))
	return t
