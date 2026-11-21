extends Node
## Settings > Key bindings: click an action, press a key. Reset to defaults. Runs while paused.

const Keys := preload("res://scripts/systems/keys.gd")
const Look := preload("res://scripts/ui/theme.gd")

var g: Node2D
var box: PanelContainer
var buttons := {}     # action -> Button
var listening := ""   # action waiting for a key

func build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	box = g.ui.panel(0.94)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	g.ui.hud_label(col, 22, Look.ACCENT.lightened(0.35)).text = "KEY BINDINGS"
	g.ui.hud_label(col, 13, Look.DIM).text = "Click an action, then press a key.  Esc cancels.  Esc and 5-9 are fixed."
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for a: String in Keys.DEFAULTS:
		var l: Label = g.ui.hud_label(grid, 14)
		l.text = Keys.DEFAULTS[a][0]
		var b := Button.new()
		b.custom_minimum_size.x = 120
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): listening = a; refresh())
		grid.add_child(b)
		buttons[a] = b
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for spec in [["Reset to defaults", reset], ["Back  [Esc]", close]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		row.add_child(b)
	var c := CenterContainer.new()
	g.ui.full(c)
	c.add_child(box)
	box.hide()

func open() -> void:
	listening = ""
	refresh()
	g.pause_panel.hide()
	box.show()

func close() -> void:
	listening = ""
	box.hide()
	g.pause_panel.show()

func reset() -> void:
	Keys.reset()
	store()

func store() -> void:
	listening = ""
	g.save_extra["ui/keys"] = Keys.to_save()
	g.save_game()
	refresh()

func refresh() -> void:
	for a: String in buttons:
		buttons[a].text = "Press a key..." if a == listening else Keys.label(a)

func _input(event: InputEvent) -> void:
	if not box.visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()  # keys here never reach the game or the pause shortcuts
	if listening == "":
		if event.keycode == KEY_ESCAPE:
			close()
		return
	if event.keycode != KEY_ESCAPE and not (event.keycode >= KEY_5 and event.keycode <= KEY_9):
		Keys.rebind(listening, event.keycode)
		store()
	listening = ""
	refresh()
