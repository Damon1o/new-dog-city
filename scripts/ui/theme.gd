extends RefCounted
## One HUD look: warm NYC-dusk glass panels (espresso + streetlight tan), hydrant-brick
## accent, taxi-gold focus. Set once on game.hud.theme; every Control under it inherits.

const BG := Color(0.11, 0.09, 0.08, 0.9)
const EDGE := Color(1.0, 0.82, 0.55, 0.22)
const ACCENT := Color(0.91, 0.4, 0.25)
const GOLD := Color(1.0, 0.85, 0.3)
const TEXT := Color(0.98, 0.95, 0.9)
const DIM := Color(0.74, 0.68, 0.6)
const SLOT := Color(0.13, 0.11, 0.1, 0.92)  # wells: inventory slots, text fields, puzzle cells

const BIG := 1.25  # "Large text" setting (spec 11 accessibility)
const SANS := preload("res://fonts/BalsamiqSans-Regular.ttf")

## Engravers' Old English BT is used ONLY for the game title.
static var TITLE_FONT := _title_font()

static func _title_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = ["Engravers' Old English BT", "Engravers Old English BT", "EngraversOldEnglish BT", "Old English Text MT"]
	f.fallbacks = [SANS]
	return f

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
	t.default_font = SANS
	ThemeDB.fallback_font = SANS
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("panel", "Panel", box())
	t.set_color("font_color", "Label", TEXT)
	for s in [["normal", Color(0.18, 0.15, 0.13, 0.92)], ["hover", Color(0.33, 0.22, 0.16, 0.95)],
			["pressed", ACCENT.darkened(0.15)], ["focus", Color(0, 0, 0, 0)], ["disabled", Color(0.14, 0.12, 0.11, 0.6)]]:
		var b := box(s[1], 8, EDGE if s[0] != "focus" else GOLD, 8)
		b.shadow_size = 0
		if s[0] == "focus":
			b.set_border_width_all(2)
		t.set_stylebox(s[0], "Button", b)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 6))
	t.set_stylebox("tab_selected", "TabContainer", box(ACCENT.darkened(0.2), 8, ACCENT, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.16, 0.13, 0.12, 0.9), 8, EDGE, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.33, 0.22, 0.16, 0.95), 8, EDGE, 8))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_stylebox("slider", "HSlider", box(Color(0.26, 0.21, 0.18), 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("normal", "LineEdit", box(SLOT, 8, EDGE, 8))
	return t
