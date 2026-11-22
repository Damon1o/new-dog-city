extends Node
const Look := preload("res://scripts/ui/theme.gd")
const Items := preload("res://scripts/data/items.gd")
const Keys := preload("res://scripts/systems/keys.gd")
var buff_row: HBoxContainer  # food / drink buff chips, bottom centre
var portrait: Control  # diamond dog portrait, top-left
var bones_label: Label
var map_hide: Array[Control] = []  # hidden while the full M map is open
var quest_btn: Button  # quest tracker header; click to minimize
## HUD: building and per-frame updates (moved from game.gd). Widget vars stay on
## game so save, tests and actors keep reading them there.

var g: Node2D

# Everything hangs off `g.hud` (full-rect) via anchors/containers, so it survives window resizes.

func hud_label(parent: Node, font_size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

func panel(alpha := 0.86) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.box(Color(Look.BG, alpha)))
	return p

func full(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.hud.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

## Full-screen column pinning `c` to the top or bottom edge with a margin.
func dock(c: Control, bottom: bool, margin: float, h := Control.SIZE_SHRINK_CENTER) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END if bottom else BoxContainer.ALIGNMENT_BEGIN
	full(box)
	var gap := Control.new()
	gap.custom_minimum_size.y = margin
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = h
	box.add_child(c)
	box.add_child(gap)
	map_hide.append(box)
	if not bottom:
		box.move_child(gap, 0)

func make_icon(kind: String, color: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(14, 14)
	c.draw.connect(draw_icon.bind(c, kind, color))
	return c

func draw_icon(c: Control, kind: String, color: Color) -> void:
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * minf(c.size.x, c.size.y) / 14.0)  # shapes are in a 14 px box
	match kind:
		"hp":  # heart
			c.draw_circle(Vector2(4, 5), 3.5, color)
			c.draw_circle(Vector2(10, 5), 3.5, color)
			c.draw_colored_polygon(PackedVector2Array([Vector2(0.5, 6.5), Vector2(13.5, 6.5), Vector2(7, 13.5)]), color)
		"hunger":  # bone
			c.draw_line(Vector2(3, 11), Vector2(11, 3), color, 3.0)
			for p in [Vector2(2, 9.5), Vector2(4.5, 12), Vector2(9.5, 2), Vector2(12, 4.5)]:
				c.draw_circle(p, 2.2, color)
		"thirst":  # droplet
			c.draw_circle(Vector2(7, 9), 4.5, color)
			c.draw_colored_polygon(PackedVector2Array([Vector2(7, 0.5), Vector2(11, 7.5), Vector2(3, 7.5)]), color)
		"stamina":  # bolt
			c.draw_colored_polygon(PackedVector2Array([Vector2(8.5, 0), Vector2(2, 8), Vector2(6.5, 8),
				Vector2(5, 14), Vector2(12, 5.5), Vector2(7.5, 5.5)]), color)
		"xp":  # gem
			c.draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(14, 7), Vector2(7, 14), Vector2(0, 7)]), color)

## Slanted bar. `size` is the drawn bar; `pips` > 0 splits it into segments (stamina).
func make_bar(parent: Control, key: String, color: Color, size := Vector2(190, 13), icon := true, pips := 0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	if icon:
		row.add_child(make_icon(key, color))
	var b := Control.new()
	b.custom_minimum_size = size + Vector2(4, 4)  # room for the dark frame
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.draw.connect(draw_bar.bind(key))
	row.add_child(b)
	g.bars[key] = {"ctl": b, "color": color, "v": 1.0, "ghost": -1.0, "text": "", "pips": pips}

## Parallelogram leaning right, filled `f` of the way from the left. Skew scales with height so
## a grown copy (the frame) stays parallel.
static func slant_poly(r: Rect2, f: float) -> PackedVector2Array:
	var k := r.size.y * 0.75
	var l := (r.size.x - k) * f
	var p := r.position
	return PackedVector2Array([p + Vector2(k, 0), p + Vector2(k + l, 0), p + Vector2(l, r.size.y), p + Vector2(0, r.size.y)])

## Framed slanted bar: black frame, dark track, crimson damage trail, fill with a light sheen on top.
func draw_slant(ci: CanvasItem, r: Rect2, v: float, ghost: float, col: Color) -> void:
	ci.draw_colored_polygon(slant_poly(r.grow(2), 1.0), Color(0.03, 0.03, 0.05, 0.92))
	ci.draw_colored_polygon(slant_poly(r, 1.0), Color(0.17, 0.14, 0.15, 0.92))
	if ghost > v:
		ci.draw_colored_polygon(slant_poly(r, ghost), Color(0.85, 0.12, 0.32))
	if v <= 0.0:
		return
	var p := slant_poly(r, v)
	ci.draw_colored_polygon(p, col.darkened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([p[0], p[1], p[1].lerp(p[2], 0.45), p[0].lerp(p[3], 0.45)]), col.lightened(0.25))

func set_bar(key: String, frac: float, delta: float, text := "") -> void:
	var b: Dictionary = g.bars[key]
	var v := clampf(frac, 0.0, 1.0)
	var ghost: float = b.ghost
	b.v = v
	b.ghost = maxf(v, move_toward(ghost, v, delta * 0.35))  # crimson trail shows how big the hit was
	b.text = text
	b.ctl.queue_redraw()

func draw_bar(key: String) -> void:
	var b: Dictionary = g.bars[key]
	var c: Control = b.ctl
	var col: Color = b.color
	var v: float = b.v
	var ghost: float = b.ghost if key in ["hp", "boss"] else 0.0  # damage trail only where hits land
	var text: String = b.text
	if key == "stamina" and g.player.winded:
		col = Color(0.5, 0.5, 0.5)
	elif key in g.LOW_KEYS and v < g.LOW:
		col = col.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	var r := Rect2(Vector2(2, 2), c.size - Vector2(4, 4))
	var n: int = b.pips
	if n > 0:  # segmented: each pip fills in turn
		var gap := 3.0
		var w := (r.size.x - gap * (n - 1)) / n
		for i in n:
			draw_slant(c, Rect2(r.position + Vector2(i * (w + gap), 0), Vector2(w, r.size.y)), clampf(v * n - i, 0.0, 1.0), 0.0, col)
	else:
		draw_slant(c, r, v, ghost, col)
	if text != "":
		var fs := clampi(int(r.size.y) - 2, 9, 13)
		var at := Vector2(0, r.position.y + r.size.y / 2.0 + fs * 0.36)
		c.draw_string_outline(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, fs, 3, Color.BLACK)
		c.draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, fs)

## Inventory slot: icon + count label. Returns the label.
func make_slot(parent: Control, t: Texture2D) -> Label:
	var box := HBoxContainer.new()
	parent.add_child(box)
	var icon := TextureRect.new()
	icon.texture = t
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(icon)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hud_label(box, 20)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS  # pause g.menu keeps working while the tree is paused
	add_child(layer)
	g.hud = Control.new()
	g.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(g.hud)
	g.fade = ColorRect.new()  # blackout for the subway ride
	g.fade.color = Color(0, 0, 0, 0)
	g.fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(g.fade)
	g.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.hud.theme = Look.make()  # UI overhaul: one sleek look for every panel / button under the HUD

	# red screen-edge g.vignette for low HP / hunger / thirst
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.6, 1.0])
	grad.colors = PackedColorArray([Color(0.8, 0, 0, 0), Color(0.8, 0, 0, 0.5)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.15, 0.5)
	g.vignette = TextureRect.new()
	g.vignette.texture = gt
	g.vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.vignette.modulate.a = 0.0
	full(g.vignette)

	# world-anchored bits: g.interact g.marker, drink ring, god's-eye icons
	g.overlay = full(Control.new())
	g.overlay.draw.connect(draw_overlay)
	for d in g.bodega_doors:
		g.pois.append({"pos": d, "text": "Shop", "color": Color(1, 0.55, 0.15)})
	for st in g.stations:
		g.pois.append({"pos": st.pos, "text": "Subway", "color": Color(0.3, 0.6, 1)})
	for w in g.water_spots:
		g.pois.append({"pos": w, "text": "Drink", "color": Color(0.5, 0.8, 1)})
	for b in get_tree().get_nodes_in_group("boss"):
		g.pois.append({"pos": b.home, "text": b.cfg.name, "color": g.BOSS_COLOR})
	g.pois.append({"pos": g.burrow, "text": "Final Boss", "color": Color(0.85, 0.3, 0.9)})
	var named := {"airport": "Airport", "gas": "Gas Station", "pizza": "Pizza", "cafe": "Cafe", "hq": "Hack Club HQ"}
	for d in g.doors.filter(func(x): return named.has(x.template)):
		g.pois.append({"pos": d.pos, "text": named[d.template], "color": POI_COLOR.get(d.template, Color(1, 0.55, 0.15))})

	# top-left, panel-less: diamond portrait + slanted HP / stamina pips / XP, needs frame under it,
	# then a currency column and the clock.
	var col := VBoxContainer.new()
	col.position = Vector2(14, 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	g.hud.add_child(col)
	map_hide.append(col)
	var frame := HBoxContainer.new()
	frame.add_theme_constant_override("separation", -10)  # bars tuck under the diamond's right point
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(frame)
	portrait = Control.new()
	portrait.custom_minimum_size = Vector2(84, 84)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.draw.connect(draw_portrait)
	portrait.z_index = 1  # over the bars' left ends
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel-art dog
	frame.add_child(portrait)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 1)
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(main)
	g.title = hud_label(main, 15)
	make_bar(main, "hp", Color(0.2, 0.82, 0.45), Vector2(230, 18), false)
	make_bar(main, "stamina", Color(0.98, 0.78, 0.3), Vector2(200, 10), false, 5)
	make_bar(main, "xp", Color(1, 0.45, 0.15), Vector2(150, 5), false)
	var needs := VBoxContainer.new()  # the small "companion" frame: hunger + thirst
	needs.add_theme_constant_override("separation", 3)
	needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(needs)
	make_bar(needs, "hunger", Color(0.95, 0.6, 0.2), Vector2(140, 9))
	make_bar(needs, "thirst", Color(0.3, 0.65, 1), Vector2(140, 9))
	var items := VBoxContainer.new()  # currency stack: big outlined numbers, icon on the left
	items.add_theme_constant_override("separation", 2)
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(items)
	g.treat_label = make_slot(items, g.tex.treat)
	var bone_row := HBoxContainer.new()
	bone_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.add_child(bone_row)
	var bone := make_icon("hunger", Color(0.95, 0.92, 0.82))
	bone.custom_minimum_size = Vector2(28, 28)
	bone_row.add_child(bone)
	bones_label = hud_label(bone_row, 20)
	g.slots.purina = make_slot(items, g.tex.purina)
	g.slots.water = make_slot(items, g.tex.water_bowl)
	var time_row := HBoxContainer.new()
	col.add_child(time_row)
	g.clock = Control.new()
	g.clock.custom_minimum_size = Vector2(26, 26)
	g.clock.draw.connect(draw_clock)
	time_row.add_child(g.clock)
	g.info = hud_label(time_row, 14)

	# top-right: minimap + legend
	g.mini = Control.new()
	g.mini.size = Vector2(200, 200 * g.WORLD.y / g.WORLD.x)  # the key lives on the M map now
	g.mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.mini.draw.connect(draw_minimap)
	g.hud.add_child(g.mini)
	map_hide.append(g.mini)
	g.mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 10)

	# under the minimap: tutorial / quest tracker
	var quests := panel()
	quests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qv := VBoxContainer.new()
	qv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quests.add_child(qv)
	quest_btn = Button.new()  # a Button so clicking it never bites (see game._input)
	quest_btn.flat = true
	quest_btn.focus_mode = Control.FOCUS_NONE
	quest_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_btn.add_theme_font_size_override("font_size", 11)
	quest_btn.pressed.connect(func(): g.quest_label.visible = not g.quest_label.visible)
	qv.add_child(quest_btn)
	g.quest_label = hud_label(qv, 12)
	g.quest_label.custom_minimum_size.x = 184
	g.hud.add_child(quests)
	map_hide.append(quests)
	quests.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quests.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	quests.offset_top = g.mini.size.y + 18

	# top-centre: level-up g.banner
	g.banner = hud_label(g.hud, 44, Color(1, 0.9, 0.3))
	g.banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.banner.offset_top = 150
	g.banner.modulate.a = 0.0
	g.boss_box = panel()
	var bv := VBoxContainer.new()
	g.boss_box.add_child(bv)
	g.boss_name = hud_label(bv, 16, g.BOSS_COLOR)
	g.boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	make_bar(bv, "boss", g.BOSS_COLOR)
	g.bars.boss.ctl.custom_minimum_size = Vector2(300, 14)
	g.boss_box.hide()
	dock(g.boss_box, false, 14)

	# bottom: g.toasts (left), shop / subway g.menu (centre)
	g.toasts = VBoxContainer.new()
	dock(g.toasts, true, 196, Control.SIZE_SHRINK_BEGIN)  # above the ability cluster
	g.toasts.get_parent().offset_left = 12
	g.menu = panel()
	var rows := VBoxContainer.new()
	g.menu.add_child(rows)
	g.menu_head = hud_label(rows, 18, Color(1, 0.9, 0.4))
	for i in 9:  # landmark elevators list 7 (6 floors + roof)
		g.menu_rows.append(hud_label(rows, 16))
	g.menu.hide()
	dock(g.menu, true, 60)
	# bottom-left: ability cluster (spec 11 HUD) in a diamond - pounce on top, dash left, bark right.
	# Locked ones hidden. Cooldown var = "<name>_cd".
	var cluster := Control.new()
	cluster.custom_minimum_size = Vector2(190, 176)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.draw.connect(draw_cluster.bind(cluster))
	dock(cluster, true, 8, Control.SIZE_SHRINK_BEGIN)
	cluster.get_parent().offset_left = 8
	for a in [["dash", Vector2(0, 76), g.player.DASH_CD], ["bark", Vector2(118, 76), g.player.BARK_CD],
			["pounce", Vector2(59, 0), g.player.POUNCE_CD]]:
		var c := Control.new()
		c.size = Vector2(72, 98)
		c.position = a[1]
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(draw_ability.bind(a[0]))
		cluster.add_child(c)
		g.abilities[a[0]] = {"ctl": c, "max": a[2], "v": 0.0}
	buff_row = HBoxContainer.new()
	buff_row.add_theme_constant_override("separation", 8)
	buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g.boss_box.get_parent().add_child(buff_row)  # top centre, under the boss bar (moves up when no boss)
	g.boss_box.get_parent().move_child(buff_row, g.boss_box.get_index() + 1)
	for slot in ["food", "drink"]:
		var chip := panel(0.8)
		chip.name = slot
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		chip.add_child(hb)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hb.add_child(icon)
		hud_label(hb, 13, Look.ACCENT.lightened(0.4)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.hide()
		buff_row.add_child(chip)

	# centre: collar name entry, pause g.menu
	var center := CenterContainer.new()
	full(center)
	g.name_edit = LineEdit.new()
	g.name_edit.placeholder_text = "Name your dog, then Enter"
	g.name_edit.max_length = 12
	g.name_edit.custom_minimum_size = Vector2(260, 36)
	g.name_edit.visible = false
	g.name_edit.text_submitted.connect(g.on_name_entered)
	center.add_child(g.name_edit)
	g.pause_panel = panel(0.94)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	g.pause_panel.add_child(pv)
	hud_label(pv, 24).text = "PAUSED"
	hud_label(pv, 14, Look.DIM).text = "Left click attacks toward the cursor.  On the M map, click a place to set a waypoint."
	var keys_btn := Button.new()
	keys_btn.text = "Key bindings"
	keys_btn.pressed.connect(func(): g.keybinds.open())
	pv.add_child(keys_btn)
	var calm := CheckBox.new()
	calm.text = "Reduce motion  (no screen shake)"
	calm.toggled.connect(func(on: bool): g.save_extra["ui/reduce_motion"] = on)
	g.pause_panel.visibility_changed.connect(func(): calm.set_pressed_no_signal(g.save_extra.get("ui/reduce_motion", false)))
	pv.add_child(calm)
	var big := CheckBox.new()
	big.text = "Large text"
	big.toggled.connect(func(on: bool):
		g.save_extra["ui/large_text"] = on
		Look.set_big_text(g, on))
	g.pause_panel.visibility_changed.connect(func(): big.set_pressed_no_signal(g.save_extra.get("ui/large_text", false)))
	pv.add_child(big)
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		hud_label(pv, 14).text = "Volume" if bus == "Master" else bus
		var sl := HSlider.new()
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = 1.0
		sl.value_changed.connect(func(v: float): Sound.set_volume(bus, v))
		pv.add_child(sl)
		g.vols[bus] = sl
	g.volume = g.vols.Master
	var resume := Button.new()
	resume.text = "Resume  [Esc]"
	resume.pressed.connect(set_paused.bind(false))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	resume.shortcut = Shortcut.new()
	resume.shortcut.events = [esc]  # only fires while the panel is visible
	pv.add_child(resume)
	restart_button(pv)
	g.skip_btn = Button.new()
	g.skip_btn.text = "Skip tutorial"
	g.skip_btn.pressed.connect(func():
		g.quest_step.Tutorial = g.Quests.QUESTS.Tutorial.size()
		g.skip_btn.hide())
	pv.add_child(g.skip_btn)
	var quit := Button.new()
	quit.text = "Save & Quit"
	quit.pressed.connect(g.quit_game)
	pv.add_child(quit)
	g.pause_panel.hide()
	center.add_child(g.pause_panel)

	g.death_panel = panel(0.94)
	var dv := VBoxContainer.new()
	dv.name = "Box"
	dv.add_theme_constant_override("separation", 10)
	g.death_panel.add_child(dv)
	var dead_head := hud_label(dv, 32, Color(0.95, 0.2, 0.2))
	dead_head.text = "YOU DIED"
	dead_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.death_why = hud_label(dv, 14)
	g.death_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var again := Button.new()
	again.name = "Respawn"
	again.text = "Respawn"
	again.pressed.connect(g.respawn)
	dv.add_child(again)
	restart_button(dv)
	var give_up := Button.new()
	give_up.text = "Save & Quit"
	give_up.pressed.connect(g.quit_game)
	dv.add_child(give_up)
	g.death_panel.hide()
	center.add_child(g.death_panel)

	build_corner()
	build_loading()

## Wipes the save, so it takes two clicks; re-arms whenever its panel reopens.
func restart_button(parent: Control) -> void:
	var b := Button.new()
	b.text = "Restart (new game)"
	b.pressed.connect(func():
		if b.text.begins_with("Sure"):
			g.restart()
		else:
			b.text = "Sure? Wipes your save - click again")
	b.visibility_changed.connect(func(): b.text = "Restart (new game)")
	parent.add_child(b)

func set_paused(on: bool) -> void:
	get_tree().paused = on
	g.pause_panel.visible = on
	g.skip_btn.visible = g.tutorial_on()

## Toast queue: newest at the bottom, max 3, each fades on its own.
func show_msg(text: String) -> void:
	if g.toasts.get_child_count() >= 3:
		g.toasts.get_child(0).free()
	var l = hud_label(g.toasts, 18, Color(1, 0.9, 0.4))
	l.text = text
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func show_banner(text: String) -> void:
	g.banner.text = text
	g.banner.modulate.a = 1.0
	if g.banner_tw:
		g.banner_tw.kill()
	g.banner_tw = create_tween()
	g.banner_tw.tween_interval(1.2)
	g.banner_tw.tween_property(g.banner, "modulate:a", 0.0, 0.6)

func show_menu(head: String, rows: Array) -> void:  # rows: [[text, enabled], ...]
	g.menu.show()
	g.menu_head.text = head
	for i in g.menu_rows.size():
		g.menu_rows[i].visible = i < rows.size()
		if i < rows.size():
			g.menu_rows[i].text = rows[i][0]
			g.menu_rows[i].modulate = Color(0.6, 1, 0.7) if rows[i][1] else Color(0.6, 0.6, 0.6)

func update_hud(delta: float) -> void:
	for n in map_hide:  # full map: nothing on top of it but the key
		n.visible = not g.god_view
	quest_btn.text = "QUESTS  [-]" if g.quest_label.visible else "QUESTS  [+]"
	g.title.text = g.player.display_name()
	portrait.queue_redraw()
	set_bar("hp", g.player.hp / g.player.max_hp, delta, "%d / %d" % [ceili(g.player.hp), int(g.player.max_hp)])
	set_bar("hunger", g.player.hunger / 100.0, delta)
	set_bar("thirst", g.player.thirst / 100.0, delta)
	set_bar("stamina", g.player.stamina / 100.0, delta, "winded" if g.player.winded else "")
	set_bar("xp", float(g.player.xp) / g.player.xp_needed(), delta, "%d / %d" % [g.player.xp, g.player.xp_needed()])
	var low: float = minf(g.player.hp / g.player.max_hp, minf(g.player.hunger, g.player.thirst) / 100.0)
	g.vignette.modulate.a = 0.0 if low >= g.LOW else \
		(0.4 + 0.6 * (1.0 - low / g.LOW)) * (0.7 + 0.3 * sin(Time.get_ticks_msec() / 180.0))
	for chip: PanelContainer in buff_row.get_children():  # spec 11 buff timers
		var b: Dictionary = g.player.buffs.get(chip.name, {})
		chip.visible = not b.is_empty()
		if chip.visible:
			var hb := chip.get_child(0)
			(hb.get_child(0) as TextureRect).texture = g.tex.get(Items.ITEM_INFO[b.id].icon)
			(hb.get_child(1) as Label).text = "%ds" % ceili(b.t)

	for b: Button in corner.values():
		b.queue_redraw()
	if g.player.treats != g.last_treats:
		if g.last_treats >= 0:  # pop green on gain, red on spend
			g.treat_label.modulate = Color(0.5, 1, 0.5) if g.player.treats > g.last_treats else Color(1, 0.45, 0.45)
			g.treat_label.pivot_offset = g.treat_label.size / 2.0
			g.treat_label.scale = Vector2.ONE * 1.5
			var tw := create_tween().set_parallel()
			tw.tween_property(g.treat_label, "scale", Vector2.ONE, 0.25)
			tw.tween_property(g.treat_label, "modulate", Color.WHITE, 0.4)
		g.last_treats = g.player.treats
		g.treat_label.text = "%d" % g.player.treats
	bones_label.text = "%d" % g.economy.bones
	for item in ["purina", "water"]:
		var n: int = g.player.get(item)
		var l: Label = g.slots[item]
		l.text = "%d" % n  # used from the hotbar (keys 1-4)
		l.get_parent().modulate.a = 1.0 if n > 0 else 0.4
	var mins = int(g.tod * 1440.0)
	g.info.text = "%02d:%02d" % [mins / 60, mins % 60]
	if g.player.sprinting:
		g.info.text += "   %d mph" % int(g.player.velocity.length() / g.player.PX_PER_MPH)
	g.clock.queue_redraw()
	var b: Node2D = g.boss if g.boss else (g.hedgehog if g.hedgehog.active else null)  # top nametag + bar
	g.boss_box.visible = b != null
	if b:
		if b == g.hedgehog:
			g.boss_name.text = "Daven the Hedgehog   Lv %d   wave %d / %d" % [b.level, b.wave + 1, b.WAVES]
		set_bar("boss", maxf(b.hp, 0.0) / b.max_hp, delta, "%d / %d" % [ceili(maxf(b.hp, 0.0)), int(b.max_hp)])
	g.quest_label.text = g.quest_text()
	g.quest_label.modulate = Color(1, 0.9, 0.4) if g.tutorial_on() else Color.WHITE
	for n in g.abilities:
		var ab: Dictionary = g.abilities[n]
		ab.v = float(g.player.get(n + "_cd")) / ab.max
		ab.ctl.visible = n != "pounce" or g.player.level >= g.player.POUNCE_LEVEL
		ab.ctl.queue_redraw()

## Ability orb: spiked dark ring, coloured core with an icon, gold rim when ready, dark sweep +
## seconds while cooling down, key pill under it.
const AB_COLOR := {"dash": Color(0.25, 0.5, 0.95), "bark": Color(0.6, 0.3, 0.9), "pounce": Color(0.2, 0.75, 0.6)}

func draw_ability(n: String) -> void:
	var ab: Dictionary = g.abilities[n]
	var c: Control = ab.ctl
	var mid := Vector2(c.size.x / 2.0, 36)
	var font := ThemeDB.fallback_font
	var ready: bool = ab.v <= 0.0
	var core: Color = AB_COLOR[n] if ready else AB_COLOR[n].darkened(0.55)
	var spikes := PackedVector2Array()  # 8-point star behind the ring
	for i in 16:
		spikes.append(mid + Vector2.RIGHT.rotated(TAU * i / 16.0 + PI / 16.0) * (36.0 if i % 2 == 0 else 31.0))
	c.draw_colored_polygon(spikes, Color(0.05, 0.04, 0.06, 0.95))
	c.draw_circle(mid, 29, Color(0.16, 0.14, 0.17))
	c.draw_circle(mid, 25, core)
	c.draw_circle(mid + Vector2(-6, -7), 12, Color(1, 1, 1, 0.12))  # glassy highlight
	ab_icon(c, n, mid, Color(1, 1, 1, 0.9 if ready else 0.45))
	if not ready:  # clockwise from 12 o'clock; a thick arc avoids polygon triangulation at tiny slices
		c.draw_arc(mid, 12.5, -PI / 2.0, -PI / 2.0 + TAU * ab.v, 32, Color(0, 0, 0, 0.6), 25.0)
		var secs := "%d" % ceili(float(g.player.get(n + "_cd")))
		c.draw_string_outline(font, mid + Vector2(-c.size.x / 2.0, 7), secs, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 20, 4, Color.BLACK)
		c.draw_string(font, mid + Vector2(-c.size.x / 2.0, 7), secs, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 20)
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 300.0)
	c.draw_arc(mid, 28, 0, TAU, 40, Color(0.95, 0.72, 0.3, pulse) if ready else Color(0.35, 0.33, 0.38), 3.0 if ready else 2.0)
	var key: String = Keys.label("bite" if n == "pounce" else n).get_slice(" / ", 0).left(5)  # follows rebinding
	var w := maxf(font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12, 26)
	var pill := Rect2(mid.x - w / 2.0, 74, w, 16)
	var sb := Look.box(Color(Look.SLOT, 0.95), 4, Color(1, 1, 1, 0.35), 0)
	sb.shadow_size = 0
	c.draw_style_box(sb, pill)
	c.draw_string(font, Vector2(pill.position.x, 86), key, HORIZONTAL_ALIGNMENT_CENTER, w, 11, Look.TEXT)

## Simple white glyph per ability, centred on `m`.
func ab_icon(c: Control, n: String, m: Vector2, col: Color) -> void:
	match n:
		"dash":  # speed chevrons
			for i in 2:
				var o := m + Vector2(-5 + i * 9, 0)
				c.draw_polyline(PackedVector2Array([o + Vector2(-5, -9), o + Vector2(4, 0), o + Vector2(-5, 9)]), col, 4.0)
		"bark":  # mouth + sound waves
			c.draw_circle(m + Vector2(-7, 0), 4.0, col)
			for r in [8.0, 14.0]:
				c.draw_arc(m + Vector2(-7, 0), r, -0.7, 0.7, 10, col, 2.5)
		"pounce":  # paw
			c.draw_circle(m + Vector2(0, 5), 6.5, col)
			for p in [Vector2(-8, -3), Vector2(-3, -9), Vector2(3, -9), Vector2(8, -3)]:
				c.draw_circle(m + p, 3.0, col)

## Faint "+" hub between the orbs.
func draw_cluster(c: Control) -> void:
	var m := Vector2(95, 112)
	c.draw_rect(Rect2(m - Vector2(10, 3), Vector2(20, 6)), Color(0.4, 0.4, 0.45, 0.8))
	c.draw_rect(Rect2(m - Vector2(3, 10), Vector2(6, 20)), Color(0.4, 0.4, 0.45, 0.8))

## Dog portrait in a diamond: black frame, crimson gem rim (pulses at low HP), level tag under it.
func draw_portrait() -> void:
	var c := portrait
	var m := c.size / 2.0 + Vector2(0, -4)
	var gem := Color(0.75, 0.12, 0.3)
	if g.player.hp / g.player.max_hp < g.LOW:
		gem = gem.lerp(Color(1, 0.4, 0.4), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	for ring in [[38.0, Color(0.03, 0.03, 0.05, 0.95)], [34.0, gem], [30.0, Color(0.1, 0.08, 0.11)], [27.0, Color(0.22, 0.2, 0.26)]]:
		var r: float = ring[0]
		c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, 0), m + Vector2(0, r), m + Vector2(-r, 0)]), ring[1])
	var t: Texture2D = g.player.sprite.texture
	if t:  # first frame of the breed sheet
		var frame := Vector2(t.get_width() / 2.0, t.get_height())
		var sz := frame * (34.0 / maxf(frame.x, frame.y))
		c.draw_texture_rect_region(t, Rect2(m - sz / 2.0, sz), Rect2(Vector2.ZERO, frame))
	var font := ThemeDB.fallback_font
	var tag := Rect2(m.x - 14, m.y + 26, 28, 16)
	var sb := Look.box(Color(0.08, 0.07, 0.1, 0.95), 3, gem, 0)
	sb.shadow_size = 0
	c.draw_style_box(sb, tag)
	c.draw_string(font, Vector2(tag.position.x, tag.position.y + 12), str(g.player.level), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 12, Color(1, 0.9, 0.5))

func draw_overlay() -> void:
	var xf = g.get_canvas_transform()  # world -> screen
	var font := ThemeDB.fallback_font
	if g.drinking:
		g.overlay.draw_arc(xf * g.player.position, 30.0, -PI / 2, -PI / 2 + TAU * g.player.thirst / 100.0, 40, Color(0.35, 0.7, 1), 4.0)
	if g.god_view:
		for poi in g.pois:
			if poi.text != "Drink":
				draw_poi(g.overlay, xf * poi.pos, 10.0, glyph(poi.text), poi.color)
		for l in g.landmarks:
			draw_poi(g.overlay, xf * l.pos, 10.0, "*", Color.WHITE)
		for r in get_tree().get_nodes_in_group("raccoon"):
			if r.visible:
				draw_poi(g.overlay, xf * r.position, 7.0, "", Color(1, 0.2, 0.2))
		draw_map_key()
	if not g.waypoint.is_empty() and g.inside == "":
		var a := waypoint_arrow()
		if a.is_empty():  # on screen: pulse ring over it
			g.overlay.draw_arc(xf * g.waypoint.pos, 22.0 + sin(Time.get_ticks_msec() / 200.0) * 3.0, 0, TAU, 32, Color(1, 0.9, 0.2), 3.0)
		else:
			var p: Vector2 = a.pos
			g.overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(14, 0).rotated(a.angle),
				p + Vector2(-8, 9).rotated(a.angle), p + Vector2(-8, -9).rotated(a.angle)]), Color(1, 0.9, 0.2))
			g.overlay.draw_string_outline(font, p - a.dir * 26.0 + Vector2(-20, 5), "%d m" % a.dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
			g.overlay.draw_string(font, p - a.dir * 26.0 + Vector2(-20, 5), "%d m" % a.dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	if not g.god_view and g.ctx == "" and not g.marker.is_empty():
		var text: String = g.marker.text
		var p: Vector2 = xf * g.marker.pos + Vector2(0, -70 + sin(Time.get_ticks_msec() / 250.0) * 4.0)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		g.overlay.draw_rect(Rect2(p.x - w / 2 - 5, p.y - 14, w + 10, 19), Color(0, 0, 0, 0.65))
		g.overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 5), p + Vector2(5, 5), p + Vector2(0, 11)]), Color(0, 0, 0, 0.65))
		g.overlay.draw_string(font, Vector2(p.x - w / 2, p.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, g.marker.color)

## Off-screen waypoint: edge point, angle and distance (1 m = 10 px); {} when it's on screen.
func waypoint_arrow() -> Dictionary:
	var sp: Vector2 = g.get_canvas_transform() * g.waypoint.pos
	var view := Rect2(Vector2.ZERO, g.overlay.size)
	if view.grow(-20.0).has_point(sp):
		return {}
	var c := view.size / 2.0
	var dir := c.direction_to(sp)
	var t := minf(absf((c.x - 30.0) / dir.x) if dir.x != 0.0 else INF, absf((c.y - 30.0) / dir.y) if dir.y != 0.0 else INF)
	return {"pos": c + dir * t, "dir": dir, "angle": dir.angle(),
		"dist": int(g.player.position.distance_to(g.waypoint.pos) / 10.0)}

func draw_clock() -> void:
	var c: Vector2 = g.clock.size / 2.0
	var r := c.x
	g.clock.draw_circle(c, r, Color(0.1, 0.12, 0.3).lerp(Color(0.45, 0.72, 1.0), g.sun()))
	var a: float = (g.tod - 0.5) * TAU
	var dir = Vector2(sin(a), -cos(a))  # g.sun straight up at noon
	g.clock.draw_circle(c + dir * r * 0.55, 4.0, Color(1, 0.85, 0.2))
	g.clock.draw_circle(c - dir * r * 0.55, 3.0, Color(0.85, 0.88, 1))  # moon opposite
	var horizon := PackedVector2Array()  # lower half hides whichever one has set
	for i in 13:
		horizon.append(c + Vector2.RIGHT.rotated(PI * i / 12.0) * r)
	g.clock.draw_colored_polygon(horizon, Color(0.12, 0.14, 0.12))
	g.clock.draw_arc(c, r, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.0)

func draw_minimap() -> void:
	var font := ThemeDB.fallback_font
	var s: float = g.mini.size.x / g.WORLD.x
	var h: float = g.WORLD.y * s
	g.mini.draw_rect(Rect2(Vector2.ZERO, g.mini.size), Color(0.08, 0.08, 0.1, 0.8))
	for by in g.NY:
		for bx in g.NX:
			var b := Vector2i(bx, by)
			var col = Color(0.3, 0.6, 0.3) if b in g.PARKS else Color(0.45, 0.45, 0.48)
			g.mini.draw_rect(Rect2(g.block_origin(b) * s, g.BLOCK * s), col)
	for p in get_tree().get_nodes_in_group("prey"):
		if p.position.distance_to(g.player.position) < 700.0:
			g.mini.draw_circle(p.position * s, 1.5, Color(0.9, 0.9, 0.9))
	for r in get_tree().get_nodes_in_group("raccoon"):
		if r.visible:
			g.mini.draw_circle(r.position * s, 2.5, Color(1, 0.2, 0.2))
	for m in g.territory.markers():  # spec 05: markers show on the map
		if m.city == g.city.id:
			g.mini.draw_circle(m.pos * s, 1.5, Color(1, 0.85, 0.2))
	for poi in g.pois:
		if poi.text != "Drink":
			draw_poi(g.mini, poi.pos * s, 5.0, glyph(poi.text), poi.color)
	for l in g.landmarks:
		draw_poi(g.mini, l.pos * s, 5.0, "*", Color.WHITE)
	if g.ctx == "subway":  # number the destinations the g.menu offers
		for i in g.stations.size():
			var sp: Vector2 = g.stations[i].pos * s
			g.mini.draw_arc(sp, 6.0, 0, TAU, 16, Color.WHITE, 1.5)
			g.mini.draw_string(font, sp + Vector2(8, 4), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	if not g.waypoint.is_empty():
		g.mini.draw_arc(g.waypoint.pos * s, 6.0, 0, TAU, 16, Color(1, 0.9, 0.2), 2.0)
	var dog: Vector2 = g.player.position  # indoors: show the door / station the dog went in through
	if g.inside == "subway":
		dog = g.stations[g.station_i].pos
	elif g.inside != "":  # any interior: Interior.enter() set return_pos to its door
		dog = g.return_pos
	var c := dog * s
	var a: float = g.player.facing.angle()
	g.mini.draw_colored_polygon(PackedVector2Array([c + Vector2(6, 0).rotated(a),
		c + Vector2(-4, 4).rotated(a), c + Vector2(-4, -4).rotated(a)]), Color(1, 0.9, 0.2))
	g.mini.draw_rect(Rect2(Vector2.ZERO, g.mini.size), Color(1, 1, 1, 0.6), false, 1.0)
	var hint := "[%s] map + key" % Keys.label("map").get_slice(" / ", 0)
	g.mini.draw_string_outline(font, Vector2(4, h - 4), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color.BLACK)
	g.mini.draw_string(font, Vector2(4, h - 4), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.75))

# ---------- map icons + key (M) ----------

## Map POI text -> the letter drawn inside its dot.
const GLYPHS := {"Shop": "$", "Subway": "S", "Airport": "A", "Gas Station": "G", "Pizza": "P", "Cafe": "C",
	"Final Boss": "X", "Pocket": "T", "Hack Club HQ": "H"}
const HQ_RED := Color(0.93, 0.24, 0.32)  # Hack Club red
const POI_COLOR := {"airport": Color(0.7, 0.9, 1), "hq": HQ_RED}
## Rows of the M map key: [glyph, color, label]. Bosses share one row.
const MAP_KEY := [["$", Color(1, 0.55, 0.15), "Shop / bodega"], ["G", Color(1, 0.55, 0.15), "Gas station"],
	["P", Color(1, 0.55, 0.15), "Pizza"], ["C", Color(1, 0.55, 0.15), "Cafe"], ["S", Color(0.3, 0.6, 1), "Subway"],
	["A", Color(0.7, 0.9, 1), "Airport"], ["*", Color.WHITE, "Landmark"], ["!", Color(0.85, 0.3, 1), "Boss"],
	["X", Color(0.85, 0.3, 0.9), "Final boss"], ["T", Color(0.75, 0.6, 1), "Pocket (trader)"], ["H", HQ_RED, "Hack Club HQ"],
	["", Color(1, 0.2, 0.2), "Raccoon"]]

func glyph(text: String) -> String:
	if GLYPHS.has(text):
		return GLYPHS[text]
	if g.BOSSES.any(func(b): return b.name == text):
		return "!"
	return text.left(1).to_upper()

## Dot with an icon letter inside: dark rim, colored fill, letter in black or white for contrast.
func draw_poi(ci: CanvasItem, at: Vector2, r: float, letter: String, color: Color) -> void:
	ci.draw_circle(at, r + 1.0, Color(0, 0, 0, 0.8))
	ci.draw_circle(at, r, color)
	if letter == "":
		return
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.5)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, at + Vector2(-w / 2.0, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE)

## Key panel on the left of the full map; only while the map is open.
func draw_map_key() -> void:
	var font := ThemeDB.fallback_font
	var rows: int = MAP_KEY.size()
	var box := Rect2(14, (g.overlay.size.y - (rows * 24 + 64)) / 2.0, 190, rows * 24 + 64)
	g.overlay.draw_style_box(Look.box(Color(Look.BG, 0.9)), box)
	g.overlay.draw_string(font, box.position + Vector2(12, 24), "MAP KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Look.ACCENT.lightened(0.3))
	var y := box.position.y + 46.0
	for k: Array in MAP_KEY:
		draw_poi(g.overlay, Vector2(box.position.x + 22, y), 8.0, k[0], k[1])
		g.overlay.draw_string(font, Vector2(box.position.x + 38, y + 5), k[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		y += 24.0
	g.overlay.draw_string(font, Vector2(box.position.x + 12, y + 4), "Click a place: waypoint", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM)
	g.overlay.draw_string(font, Vector2(box.position.x + 12, y + 18), "[%s] close map" % Keys.label("map").get_slice(" / ", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM)

# ---------- corner boxes ----------

## Bottom-right, over the hotbar: one icon box per screen, key in the corner. Stats shows +N unspent points.
const CORNER := [["stats", "Stats"], ["inventory", "Bag"], ["wardrobe", "Wardrobe"], ["map", "Map"], ["stocks", "Stocks"], ["pause", "Menu"]]
var corner := {}  # action -> Button

func build_corner() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Array in CORNER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.focus_mode = Control.FOCUS_NONE  # Space / Enter must never press these
		b.tooltip_text = c[1]
		b.draw.connect(draw_corner.bind(b, c[0]))
		b.pressed.connect(corner_pressed.bind(c[0]))
		row.add_child(b)
		corner[c[0]] = b
	dock(row, true, 62, Control.SIZE_SHRINK_END)

func corner_pressed(a: String) -> void:
	match a:
		"stats", "inventory":
			g.inventory.toggle()
		"wardrobe":
			g.wardrobe.toggle()
		"map":
			g.toggle_map()
		"stocks":
			g.stocks.toggle()
		"pause":
			set_paused(true)

func draw_corner(b: Button, a: String) -> void:
	var c := b.size / 2.0 + Vector2(0, -3)
	var col := Look.TEXT if a != "map" or g.inside == "" else Color(0.5, 0.5, 0.55)
	var dark := Color(Look.SLOT, 1.0)
	match a:
		"stats":  # bar chart
			for i in 3:
				var hgt := 6.0 + i * 5.0
				b.draw_rect(Rect2(c.x - 10 + i * 7, c.y + 8 - hgt, 5, hgt), col)
		"inventory":  # backpack
			b.draw_rect(Rect2(c.x - 9, c.y - 6, 18, 16), col)
			b.draw_arc(c + Vector2(0, -6), 5.0, PI, TAU, 10, col, 2.0)
			b.draw_rect(Rect2(c.x - 5, c.y + 1, 10, 5), dark)
		"wardrobe":  # cap
			b.draw_arc(c + Vector2(0, 4), 5.0, PI, TAU, 14, col, 9.0)
			b.draw_rect(Rect2(c.x - 2, c.y + 2, 14, 3), col)
		"map":  # folded map
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -7), c + Vector2(-4, -9), c + Vector2(4, -7),
				c + Vector2(11, -9), c + Vector2(11, 8), c + Vector2(4, 10), c + Vector2(-4, 8), c + Vector2(-11, 10)]), col)
			b.draw_line(c + Vector2(-4, -9), c + Vector2(-4, 8), dark, 1.5)
			b.draw_line(c + Vector2(4, -7), c + Vector2(4, 10), dark, 1.5)
		"stocks":  # rising line
			b.draw_polyline(PackedVector2Array([c + Vector2(-11, 7), c + Vector2(-4, 0), c + Vector2(1, 4), c + Vector2(11, -8)]), Color(0.4, 1, 0.55), 2.5)
		"pause":  # menu lines
			for i in 3:
				b.draw_rect(Rect2(c.x - 9, c.y - 7 + i * 6, 18, 3), col)
	var font := ThemeDB.fallback_font
	var key: String = "Esc" if a == "pause" else Keys.label(a).get_slice(" / ", 0).left(3)
	b.draw_string_outline(font, Vector2(4, b.size.y - 4), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
	b.draw_string(font, Vector2(4, b.size.y - 4), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Look.DIM)
	if a == "stats" and g.player.points > 0:  # badge: unspent points
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
		b.draw_circle(Vector2(b.size.x - 8, 8), 9.0, Color(1, 0.75, 0.2, pulse))
		var t := "+%d" % g.player.points
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		b.draw_string(font, Vector2(b.size.x - 8 - w / 2.0, 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)

# ---------- loading screen ----------

const TIPS := ["Hotbar keys 1-4 use what's in each slot.", "E opens your bag; drag items onto the hotbar.",
	"Every level gives 3 stat points. Spend them in Stats (K) whenever you like.",
	"Armor from shops cuts the damage you take. Wear it in the bag's Armor slot.",
	"M opens the full map with its key. Click a place to set a waypoint.",
	"Bark (R) sends lower-level foes running.", "Elevators: stand by the doors and pick a floor."]
var loading: ColorRect
var loading_title: Label
var loading_tip: Label
var loading_bar: ProgressBar
var loading_tw: Tween

func build_loading() -> void:
	loading = ColorRect.new()
	loading.color = Color(0.04, 0.05, 0.08)
	full(loading)
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	loading_title = hud_label(v, 34, Look.TEXT)
	loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_bar = ProgressBar.new()
	loading_bar.custom_minimum_size = Vector2(360, 10)
	loading_bar.show_percentage = false
	loading_bar.max_value = 1.0
	v.add_child(loading_bar)
	loading_tip = hud_label(v, 14, Look.DIM)
	loading_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.hide()

## Loading card over a scene change (doors, elevators). The room is already built underneath;
## this only covers the swap, so nothing waits on it.
func show_loading(title: String) -> void:
	if get_tree().paused:  # never cover the death / pause panels
		return
	loading_title.text = title
	loading_tip.text = "Tip: " + TIPS.pick_random()
	loading_bar.value = 0.0
	loading.modulate.a = 1.0
	loading.show()
	if loading_tw:
		loading_tw.kill()
	loading_tw = create_tween()
	loading_tw.tween_property(loading_bar, "value", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	loading_tw.tween_property(loading, "modulate:a", 0.0, 0.3)
	loading_tw.tween_callback(loading.hide)
