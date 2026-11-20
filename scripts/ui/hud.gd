extends Node
const Look := preload("res://scripts/ui/theme.gd")
const Items := preload("res://scripts/data/items.gd")
const Keys := preload("res://scripts/systems/keys.gd")
var buff_row: HBoxContainer  # food / drink buff chips above the ability bar
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
	if not bottom:
		box.move_child(gap, 0)

func make_icon(kind: String, color: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(14, 14)
	c.draw.connect(draw_icon.bind(c, kind, color))
	return c

func draw_icon(c: Control, kind: String, color: Color) -> void:
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

func make_bar(parent: Control, key: String, color: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(make_icon(key, color))
	var b := Control.new()
	b.custom_minimum_size = Vector2(190, 13)
	b.draw.connect(draw_bar.bind(key))
	row.add_child(b)
	g.bars[key] = {"ctl": b, "color": color, "v": 1.0, "ghost": 1.0, "text": ""}

func set_bar(key: String, frac: float, delta: float, text := "") -> void:
	var b: Dictionary = g.bars[key]
	var v := clampf(frac, 0.0, 1.0)
	var ghost: float = b.ghost
	b.v = v
	b.ghost = maxf(v, move_toward(ghost, v, delta * 0.35))  # white trail shows how big the hit was
	b.text = text
	b.ctl.queue_redraw()

func draw_bar(key: String) -> void:
	var b: Dictionary = g.bars[key]
	var c: Control = b.ctl
	var col: Color = b.color
	var v: float = b.v
	var ghost: float = b.ghost
	var text: String = b.text
	if key == "stamina" and g.player.winded:
		col = Color(0.5, 0.5, 0.5)
	elif key in g.LOW_KEYS and v < g.LOW:
		col = col.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(0, 0, c.size.x * ghost, c.size.y), Color(1, 1, 1, 0.85))
	c.draw_rect(Rect2(0, 0, c.size.x * v, c.size.y), col)
	if text != "":
		c.draw_string_outline(ThemeDB.fallback_font, Vector2(0, c.size.y - 2), text, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 10, 3, Color.BLACK)
		c.draw_string(ThemeDB.fallback_font, Vector2(0, c.size.y - 2), text, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 10)

## Inventory slot: icon + count label. Returns the label.
func make_slot(parent: Control, t: Texture2D) -> Label:
	var box := HBoxContainer.new()
	parent.add_child(box)
	var icon := TextureRect.new()
	icon.texture = t
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	return hud_label(box, 14)

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
	var named := {"airport": "Airport", "gas": "Gas Station", "pizza": "Pizza", "cafe": "Cafe"}
	for d in g.doors.filter(func(x): return named.has(x.template)):
		g.pois.append({"pos": d.pos, "text": named[d.template], "color": Color(0.7, 0.9, 1) if d.template == "airport" else Color(1, 0.55, 0.15)})

	# top-left: stats, inventory, g.clock
	var stats := panel()
	stats.position = Vector2(10, 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.hud.add_child(stats)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	stats.add_child(col)
	g.title = hud_label(col, 18)
	make_bar(col, "hp", Color(0.85, 0.2, 0.2))
	make_bar(col, "hunger", Color(0.9, 0.55, 0.15))
	make_bar(col, "thirst", Color(0.25, 0.55, 0.95))
	make_bar(col, "stamina", Color(0.9, 0.85, 0.2))
	make_bar(col, "xp", Color(0.65, 0.4, 0.9))
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 12)
	col.add_child(items)
	g.treat_label = make_slot(items, g.tex.treat)
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
	g.mini.size = Vector2(200, 200 * g.WORLD.y / g.WORLD.x + 34)
	g.mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.mini.draw.connect(draw_minimap)
	g.hud.add_child(g.mini)
	g.mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 10)

	# under the minimap: tutorial / quest tracker
	var quests := panel()
	quests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.quest_label = hud_label(quests, 12)
	g.quest_label.custom_minimum_size.x = 184
	g.hud.add_child(quests)
	quests.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quests.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	quests.offset_top = g.mini.size.y + 18

	# top-centre: level-up g.banner, breed g.card
	g.banner = hud_label(g.hud, 44, Color(1, 0.9, 0.3))
	g.banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.banner.offset_top = 150
	g.banner.modulate.a = 0.0
	g.card = panel()
	g.card_art = Control.new()
	g.card_art.custom_minimum_size = Vector2(280, 108)
	g.card_art.draw.connect(draw_card)
	g.card.add_child(g.card_art)
	g.card.hide()
	dock(g.card, false, 14)
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
	dock(g.toasts, true, 12, Control.SIZE_SHRINK_BEGIN)
	g.toasts.get_parent().offset_left = 12
	g.menu = panel()
	var rows := VBoxContainer.new()
	g.menu.add_child(rows)
	g.menu_head = hud_label(rows, 18, Color(1, 0.9, 0.4))
	for i in 9:  # landmark elevators list 7 (6 floors + roof)
		g.menu_rows.append(hud_label(rows, 16))
	g.menu.hide()
	dock(g.menu, true, 60)
	# bottom centre: ability bar (spec 11 HUD); locked ones hidden. Cooldown var = "<name>_cd".
	var abar := HBoxContainer.new()
	abar.add_theme_constant_override("separation", 10)
	for a in [["dash", "C", g.player.DASH_CD], ["bark", "R", g.player.BARK_CD], ["pounce", "Spc", g.player.POUNCE_CD]]:
		var c := Control.new()
		c.custom_minimum_size = Vector2(44, 52)
		c.draw.connect(draw_ability.bind(a[0]))
		abar.add_child(c)
		g.abilities[a[0]] = {"ctl": c, "key": a[1], "max": a[2], "v": 0.0}
	dock(abar, true, 4)
	buff_row = HBoxContainer.new()
	buff_row.add_theme_constant_override("separation", 8)
	buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock(buff_row, true, 62)
	for slot in ["food", "drink"]:
		var chip := panel(0.8)
		chip.name = slot
		hud_label(chip, 13, Look.ACCENT.lightened(0.4))
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

	g.stat_panel = panel(0.94)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	g.stat_panel.add_child(sv)
	g.stat_head = hud_label(sv, 24, Color(1, 0.9, 0.3))
	for i in g.player.STATS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE  # mashing Space (bite) must not pick a stat
		b.pressed.connect(g.pick_stat.bind(i))
		var key := InputEventKey.new()
		key.keycode = (KEY_1 + i) as Key
		b.shortcut = Shortcut.new()
		b.shortcut.events = [key]
		sv.add_child(b)
		g.stat_buttons.append(b)
	g.stat_panel.hide()
	center.add_child(g.stat_panel)

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
	g.title.text = "%s   Lv %d" % [g.player.display_name(), g.player.level]
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
			(chip.get_child(0) as Label).text = "%s  %ds" % [Items.ITEM_INFO[b.id].name, ceili(b.t)]

	if g.player.treats != g.last_treats:
		if g.last_treats >= 0:  # pop green on gain, red on spend
			g.treat_label.modulate = Color(0.5, 1, 0.5) if g.player.treats > g.last_treats else Color(1, 0.45, 0.45)
			g.treat_label.scale = Vector2.ONE * 1.5
			var tw := create_tween().set_parallel()
			tw.tween_property(g.treat_label, "scale", Vector2.ONE, 0.25)
			tw.tween_property(g.treat_label, "modulate", Color.WHITE, 0.4)
		g.last_treats = g.player.treats
		g.treat_label.text = "x%d   %d bones" % [g.player.treats, g.economy.bones]
	for item in ["purina", "water"]:
		var n: int = g.player.get(item)
		var l: Label = g.slots[item]
		l.text = "x%d [%s]" % [n, "Q" if item == "purina" else "E"]
		l.get_parent().modulate.a = 1.0 if n > 0 else 0.4
	var mins = int(g.tod * 1440.0)
	g.info.text = "%02d:%02d" % [mins / 60, mins % 60]
	if g.player.sprinting:
		g.info.text += "   %d mph" % int(g.player.velocity.length() / g.player.PX_PER_MPH)
	g.clock.queue_redraw()
	g.card_t -= delta
	g.card.visible = g.card_t > 0.0 and g.boss == null  # g.boss bar uses the same spot
	g.boss_box.visible = g.boss != null
	if g.boss:
		set_bar("boss", g.boss.hp / g.boss.max_hp, delta, "%d / %d" % [ceili(g.boss.hp), int(g.boss.max_hp)])
	g.quest_label.text = g.quest_text()
	g.quest_label.modulate = Color(1, 0.9, 0.4) if g.tutorial_on() else Color.WHITE
	for n in g.abilities:
		var ab: Dictionary = g.abilities[n]
		ab.v = float(g.player.get(n + "_cd")) / ab.max
		ab.ctl.visible = n != "pounce" or g.player.level >= g.player.POUNCE_LEVEL
		ab.ctl.queue_redraw()

## Ability slot: round button with its key, name under it, dark sweep for the cooldown left.
func draw_ability(n: String) -> void:
	var ab: Dictionary = g.abilities[n]
	var c: Control = ab.ctl
	var mid := Vector2(c.size.x / 2.0, 20)
	var font := ThemeDB.fallback_font
	c.draw_circle(mid, 19, Color(0.2, 0.45, 0.8) if ab.v <= 0.0 else Color(0.25, 0.25, 0.3))
	if ab.v > 0.0:  # clockwise from 12 o'clock; a thick arc avoids polygon triangulation at tiny slices
		c.draw_arc(mid, 9.5, -PI / 2.0, -PI / 2.0 + TAU * ab.v, 32, Color(0, 0, 0, 0.65), 19.0)
	c.draw_arc(mid, 19, 0, TAU, 32, Color(1, 1, 1, 0.7), 1.5)
	var key: String = Keys.label("bite" if n == "pounce" else n).get_slice(" / ", 0).left(5)  # follows rebinding
	c.draw_string_outline(font, Vector2(0, 25), key, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 13, 3, Color.BLACK)
	c.draw_string(font, Vector2(0, 25), key, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 13)
	c.draw_string_outline(font, Vector2(0, 51), n, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 10, 3, Color.BLACK)
	c.draw_string(font, Vector2(0, 51), n, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 10)

func draw_overlay() -> void:
	var xf = g.get_canvas_transform()  # world -> screen
	var font := ThemeDB.fallback_font
	if g.hedgehog.active:
		var bar = Rect2((g.overlay.size.x - 360.0) / 2.0, 34.0, 360.0, 14.0)
		g.overlay.draw_rect(bar.grow(2), Color(0, 0, 0, 0.7))
		g.overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * maxf(g.hedgehog.hp, 0.0) / g.hedgehog.max_hp, bar.size.y)), Color(0.85, 0.3, 0.9))
		g.overlay.draw_string_outline(font, Vector2(bar.position.x, 26.0), "BOSS HEDGEHOG   wave %d / %d" % [g.hedgehog.wave + 1, g.hedgehog.WAVES],
			HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 14, 4, Color.BLACK)
		g.overlay.draw_string(font, Vector2(bar.position.x, 26.0), "BOSS HEDGEHOG   wave %d / %d" % [g.hedgehog.wave + 1, g.hedgehog.WAVES],
			HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 14)
	if g.drinking:
		g.overlay.draw_arc(xf * g.player.position, 30.0, -PI / 2, -PI / 2 + TAU * g.player.thirst / 100.0, 40, Color(0.35, 0.7, 1), 4.0)
	if g.god_view:
		for poi in g.pois:
			if poi.text != "Drink":
				g.overlay.draw_circle(xf * poi.pos, 6.0, poi.color)
		for l in g.landmarks:
			g.overlay.draw_circle(xf * l.pos, 6.0, Color.WHITE)
		for r in get_tree().get_nodes_in_group("raccoon"):
			if r.visible:
				g.overlay.draw_circle(xf * r.position, 5.0, Color(1, 0.2, 0.2))
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

## Breed g.card: sprite, name, stat g.bars with a tick + delta against the previous breed.
func draw_card() -> void:
	var b: Dictionary = g.player.breed()
	var old: Dictionary = g.player.BREEDS[g.prev_skin]
	var font := ThemeDB.fallback_font
	var t: Texture2D = g.player.sprite.texture
	var frame := Vector2(t.get_width() / 2.0, t.get_height())
	g.card_art.draw_texture_rect_region(t, Rect2(4, 14, 64, 64 * frame.y / frame.x), Rect2(Vector2.ZERO, frame))
	g.card_art.draw_string(font, Vector2(84, 18), str(b.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var y := 32.0
	for stat in [["mph", "Speed"], ["hp", "HP"], ["atk", "Bite"]]:
		var k: String = stat[0]
		var top: float = g.player.BREEDS.map(func(x): return x[k]).max()
		var v: float = b[k]
		var was: float = old[k]
		g.card_art.draw_string(font, Vector2(84, y + 10), "%s %d" % [stat[1], int(v)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		g.card_art.draw_rect(Rect2(150, y, 90, 10), Color(0, 0, 0, 0.55))
		g.card_art.draw_rect(Rect2(150, y, 90 * v / top, 10), Color(0.6, 1, 0.7))
		g.card_art.draw_line(Vector2(150 + 90 * was / top, y - 2), Vector2(150 + 90 * was / top, y + 12), Color.WHITE, 2.0)
		if v != was:
			g.card_art.draw_string(font, Vector2(246, y + 10), "%+d" % int(v - was), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.5, 1, 0.5) if v > was else Color(1, 0.45, 0.45))
		y += 20.0
	g.card_art.draw_string(font, Vector2(84, 104), "[Tab] next breed   | = previous", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))

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
			g.mini.draw_circle(poi.pos * s, 3.0, poi.color)
	for l in g.landmarks:
		g.mini.draw_circle(l.pos * s, 3.0, Color.WHITE)
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
	var x := 6.0
	for e in [["shop", Color(1, 0.55, 0.15)], ["subway", Color(0.3, 0.6, 1)], ["sight", Color.WHITE], ["raccoon", Color(1, 0.2, 0.2)]]:
		var word: String = e[0]
		g.mini.draw_circle(Vector2(x + 3, h + 10), 3.0, e[1])
		g.mini.draw_string(font, Vector2(x + 9, h + 14), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		x += 16.0 + font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	g.mini.draw_string(font, Vector2(6, h + 28), "[M] god's-eye map   [Esc] pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
