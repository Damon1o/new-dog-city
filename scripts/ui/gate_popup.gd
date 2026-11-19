extends CenterContainer
## Level-gate popup (spec 11): title, requirement, "Find XP" (sets the waypoint) and Close.
## Open with GatePopup.open(game, "G1"); it freezes the dog while up and frees itself on close.

var g: Node2D
var gate := ""
var req: Label
var find_btn: Button

static func open(game: Node2D, gate_id: String) -> Node:
	var p: Node = load("res://scripts/ui/gate_popup.gd").new()
	p.g = game
	p.gate = gate_id
	game.hud.add_child(p)
	return p

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: PanelContainer = g.ui.panel(0.94)
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	var head: Label = g.ui.hud_label(v, 24, Color(1, 0.9, 0.3))
	head.text = "Locked: " + str(Story.Gates.GATES[gate].opens)
	req = g.ui.hud_label(v, 18)
	req.text = Story.gate_block(gate, g.player.level)
	find_btn = Button.new()
	find_btn.text = "Find XP"
	find_btn.pressed.connect(find_xp)
	v.add_child(find_btn)
	var close_btn := Button.new()
	close_btn.text = "Close (Esc)"
	close_btn.pressed.connect(close)
	v.add_child(close_btn)
	g.player.frozen = true
	find_btn.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

## Waypoint to the nearest open side content (a boss still standing). The GPS draws it (M2-5).
func find_xp() -> void:
	var best := Story.NO_TARGET
	var from: Vector2 = g.player.position
	for b: Node2D in get_tree().get_nodes_in_group("boss"):
		if b.visible and from.distance_to(b.home) < from.distance_to(best):
			best = b.home
	Story.set_waypoint(best)
	g.show_msg("Waypoint set: side quest" if best != Story.NO_TARGET else "No side quests left nearby")
	close()

func close() -> void:
	g.player.frozen = false
	queue_free()
