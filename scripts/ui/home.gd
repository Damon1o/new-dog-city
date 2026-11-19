extends Control
## Home screen (spec 11 "Home"): the launch scene. Continue / New Story / Free Roam /
## Wardrobe / Album / Settings / Quit over a slowly panning NYC street.

const GAME_SCENE := "res://scenes/Main.tscn"
const Save := preload("res://scripts/systems/save.gd")
const TILE := 64.0
const STEP := Vector2(7, 5) * TILE  # one block + one road, same rhythm as the city
## Keep in sync with the pause panel in scripts/ui/hud.gd.
const CONTROLS := "WASD / arrows   move\nShift   sprint\nSpace / left click   attack\nF   doors, stairs, burrow\nQ / E   eat Purina / drink water\nTab   change breed\nM   god's-eye map\n1-4   shop and subway choices\nEsc   pause"

var save_path := "user://save.cfg"  # var so the smoke test can point it elsewhere
var tex := {}
var pan := 0.0
var bg: Control
var menu: VBoxContainer
var continue_btn: Button
var confirm_panel: PanelContainer
var settings_panel: PanelContainer
var toasts: VBoxContainer
var vols := {}  # bus name -> HSlider
var reduce_motion: CheckBox

## A save counts once it has a dog: restart() leaves a "ui"-only file (volumes), which is no save.
static func has_save(path: String) -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(path) == OK and cfg.has_section("dog")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for n in ["road", "sidewalk", "building_a", "building_b", "building_c", "bodega", "tree", "hydrant"]:
		tex[n] = load("res://assets/%s.png" % n)
	bg = Control.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(draw_street)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	center.add_child(menu)
	label(menu, 56, Color(1, 0.85, 0.3)).text = "New Dog City"
	label(menu, 22, Color(0.7, 0.85, 1)).text = "Lost Packet"
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	menu.add_child(gap)
	continue_btn = button("Continue", start_game)
	button("New Story", new_story)
	# ponytail: spec open question 4 locks Free Roam until Story flag ch1_clue; Story (M5-1) isn't in yet, so it's always open.
	button("Free Roam", start_game)
	for b in [button("Wardrobe", soon.bind("Wardrobe")), button("Album", soon.bind("Album"))]:  # M4-11, M5-5
		b.modulate.a = 0.55  # not built yet: dimmed, press shows a "coming soon" toast
	button("Settings", open_settings)
	button("Quit", get_tree().quit).visible = not OS.has_feature("web")

	confirm_panel = panel()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	confirm_panel.add_child(cv)
	label(cv, 20, Color(1, 0.5, 0.4)).text = "Start a new story?"
	label(cv, 14).text = "This overwrites your saved dog.\nVolume settings are kept."
	button("Overwrite and start", wipe_and_start, cv)
	button("Back", show_menu, cv)
	center.add_child(confirm_panel)

	settings_panel = panel()
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	settings_panel.add_child(sv)
	label(sv, 24).text = "SETTINGS"
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		label(sv, 14).text = "Volume" if bus == "Master" else bus
		var sl := HSlider.new()
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size.x = 260
		sl.value_changed.connect(func(v: float): Sound.set_volume(bus, v))
		sl.value = cfg.get_value("ui", "volume" if bus == "Master" else Save.VOLS[bus], 1.0)
		Sound.set_volume(bus, sl.value)
		sv.add_child(sl)
		vols[bus] = sl
	reduce_motion = CheckBox.new()
	reduce_motion.text = "Reduce motion"
	reduce_motion.button_pressed = cfg.get_value("ui", "reduce_motion", false)
	sv.add_child(reduce_motion)
	label(sv, 16, Color(1, 0.9, 0.4)).text = "Controls"
	label(sv, 13).text = CONTROLS
	button("Back", save_settings, sv)
	center.add_child(settings_panel)

	toasts = VBoxContainer.new()
	toasts.alignment = BoxContainer.ALIGNMENT_END
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)
	toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toasts.offset_left = 16
	toasts.offset_top = -120
	toasts.offset_bottom = -16
	show_menu()

func _process(delta: float) -> void:
	if not reduce_motion.button_pressed:
		pan += delta * 18.0
		bg.queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not menu.visible:
		if settings_panel.visible:
			save_settings()
		else:
			show_menu()
		get_viewport().set_input_as_handled()

## Street tiles: sidewalk everywhere, a road every block, a few buildings, drifting diagonally.
func draw_street() -> void:
	var off := Vector2(fmod(pan, STEP.x), fmod(pan * 0.6, STEP.y))
	var sz := bg.size + STEP * 2
	bg.draw_texture_rect(tex.sidewalk, Rect2(-off, sz), true)
	var builds := ["building_a", "building_b", "building_c", "bodega"]
	var cols := int(sz.x / STEP.x) + 1
	var rows := int(sz.y / STEP.y) + 1
	for i in cols:
		bg.draw_texture_rect(tex.road, Rect2(Vector2(i * STEP.x, 0) - off, Vector2(TILE * 2, sz.y)), true)
	for j in rows:
		bg.draw_texture_rect(tex.road, Rect2(Vector2(0, j * STEP.y) - off, Vector2(sz.x, TILE * 2)), true)
	for i in cols:
		for j in rows:
			var o := Vector2(i * STEP.x + TILE * 2.5, j * STEP.y + TILE * 2.5) - off
			var t: Texture2D = tex[builds[(i + j * 3) % builds.size()]]
			bg.draw_texture_rect(t, Rect2(o, Vector2(TILE * 4, TILE * 2.2)), false)
			bg.draw_texture_rect(tex.tree, Rect2(o + Vector2(TILE * 4.1, TILE * 0.2), Vector2(TILE, TILE)), false)
			bg.draw_texture_rect(tex.hydrant, Rect2(o + Vector2(TILE * 0.2, TILE * 2.4), Vector2(TILE, TILE) * 0.5), false)

func show_menu() -> void:
	continue_btn.visible = has_save(save_path)
	menu.visible = true
	confirm_panel.visible = false
	settings_panel.visible = false
	(continue_btn if continue_btn.visible else menu.get_child(4)).grab_focus.call_deferred()

func start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

## Over an existing save, New Story asks first (in-UI, not a dialog).
func new_story() -> void:
	if not has_save(save_path):
		start_game()
		return
	menu.visible = false
	confirm_panel.visible = true

## Same wipe as game.restart(): drop the dog, quests and world; keep the ui section.
func wipe_and_start() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		for s in cfg.get_sections():
			if s != "ui":
				cfg.erase_section(s)
		cfg.save(save_path)
	start_game()

func open_settings() -> void:
	menu.visible = false
	settings_panel.visible = true
	vols.Master.grab_focus.call_deferred()

## Writes only the ui section, so it never turns a missing save into a "save".
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	for bus in vols:
		cfg.set_value("ui", "volume" if bus == "Master" else Save.VOLS[bus], vols[bus].value)
	cfg.set_value("ui", "reduce_motion", reduce_motion.button_pressed)
	cfg.save(save_path)
	show_menu()

func soon(what: String) -> void:
	if toasts.get_child_count() >= 3:
		toasts.get_child(0).free()
	var l := label(toasts, 18, Color(1, 0.9, 0.4))
	l.text = what + ": coming soon"
	var tw := l.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func label(parent: Node, font_size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l

func button(text: String, on_press: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 38)
	b.pressed.connect(on_press)
	(parent if parent else menu).add_child(b)
	return b

func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.94)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	return p
