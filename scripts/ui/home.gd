extends Control
## Home screen (spec 11 "Home"): the launch scene. Continue / New Story / Free Roam /
## Wardrobe / Album / Settings / Quit over a slowly panning NYC street.

const GAME_SCENE := "res://scenes/Main.tscn"
const Save := preload("res://scripts/systems/save.gd")
const Look := preload("res://scripts/ui/theme.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const TILE := 64.0
const STEP := Vector2(7, 5) * TILE  # one block + one road, same rhythm as the city

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
var large_text: CheckBox
var free_roam: Button
var wardrobe_btn: Button

## A save counts once it has a dog: restart() leaves a "ui"-only file (volumes), which is no save.
static func has_save(path: String) -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(path) == OK and cfg.has_section("dog")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Look.make()
	Sound.music("home_theme")
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
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	Keys.apply(cfg.get_value("ui", "keys", {}))  # the controls list shows your bindings
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	var menu_panel := panel()
	menu_panel.add_child(menu)
	center.add_child(menu_panel)
	menu.visibility_changed.connect(func(): menu_panel.visible = menu.visible)
	label(menu, 56, Color(1, 0.85, 0.3)).text = "New Dog City"
	label(menu, 22, Look.ACCENT.lightened(0.35)).text = "Lost Packet"
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	menu.add_child(gap)
	continue_btn = button("Continue", start_game)
	button("New Story", new_story)
	# spec open question 4: Free Roam opens once the story reaches ch1_clue.
	free_roam = button("Free Roam", start_game)
	wardrobe_btn = button("Wardrobe", open_in_game.bind("wardrobe"))
	for b in [button("Album", soon.bind("Album"))]:  # M5-5
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
	large_text = CheckBox.new()
	large_text.text = "Large text"
	large_text.button_pressed = cfg.get_value("ui", "large_text", false)
	large_text.toggled.connect(func(on: bool): Look.set_big_text(self, on))
	sv.add_child(large_text)
	label(sv, 16, Color(1, 0.9, 0.4)).text = "Controls"
	var keys := GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 18)
	for a: String in Keys.DEFAULTS:
		label(keys, 13, Look.DIM).text = Keys.DEFAULTS[a][0]
		label(keys, 13).text = Keys.label(a)
	sv.add_child(keys)
	label(sv, 12, Look.DIM).text = "Esc pauses. Rebind keys from the pause menu in game."
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
	Look.set_big_text(self, large_text.button_pressed)

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
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	free_roam.disabled = not "ch1_clue" in cfg.get_value("story", "flags", [])
	free_roam.tooltip_text = "Unlocks once you find Sam's first clue" if free_roam.disabled else ""
	wardrobe_btn.disabled = not continue_btn.visible  # dresses your saved dog
	wardrobe_btn.tooltip_text = "Start a story first" if wardrobe_btn.disabled else ""
	menu.visible = true
	confirm_panel.visible = false
	settings_panel.visible = false
	(continue_btn if continue_btn.visible else menu.get_child(4)).grab_focus.call_deferred()
	if not reduce_motion.button_pressed:
		menu.modulate.a = 0.0
		menu.create_tween().tween_property(menu, "modulate:a", 1.0, 0.25)

func start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

## Load the saved dog with a screen open (game._ready reads the "open" meta).
func open_in_game(screen: String) -> void:
	get_tree().root.set_meta("open", screen)
	start_game()

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
	cfg.set_value("ui", "large_text", large_text.button_pressed)
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
	p.add_theme_stylebox_override("panel", Look.box(Look.BG, 14, Look.EDGE, 24))
	return p
