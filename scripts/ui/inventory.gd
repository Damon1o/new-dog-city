extends Node
## Inventory (E, or K / the Stats corner box): panels like a survival-game bag.
##   ON THE GROUND  treats near the dog; click to grab
##   STATS          level, HP / bite / speed / armor / crit; + buttons spend stat points (no forced popup)
##   EQUIPMENT      dog preview, Head / Collar / Skin / Outfit / Armor slots, the 4-slot hotbar
##   INVENTORY      grid of carried items, Sam's things and keycards
## Drag an item onto a hotbar slot to bind it; right-click an item to use it, a hotbar slot to clear it.
## The hotbar also sits on the HUD (bottom right) and saves as save_extra["ui/hotbar"].

const Items := preload("res://scripts/data/items.gd")
const Gates := preload("res://scripts/data/gates.gd")
const Look := preload("res://scripts/ui/theme.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const Album := preload("res://scripts/ui/album.gd")
const CARRY := Items.CARRY  # bindable consumables: every shop food and drink
const ALBUM := 17
const CELL := 54.0
const GROUND_PX := 320.0

var g: Node2D
var root: HBoxContainer
var ground: GridContainer
var stats_box: VBoxContainer
var gear: VBoxContainer
var bag: GridContainer
var wallet: Label
var album: HBoxContainer  # ALBUM panel content, swapped in for the other three by its button
var hud_slots: Array[Dictionary] = []  # HUD hotbar: {icon, count, key}

func build() -> void:
	root = HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	ground = GridContainer.new()
	ground.columns = 4
	var left := VBoxContainer.new()  # ground + stats share the first column
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	section("ON THE GROUND", ground, left)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 3)
	section("STATS", stats_box, left)
	gear = VBoxContainer.new()
	gear.add_theme_constant_override("separation", 8)
	section("EQUIPMENT", gear)
	bag = GridContainer.new()
	bag.columns = 5
	var right := section("INVENTORY", bag)
	wallet = g.ui.hud_label(right, 13, Look.DIM)
	var open_album := Button.new()
	open_album.text = "Album"
	open_album.pressed.connect(show_album.bind(true))
	right.add_child(open_album)
	album = HBoxContainer.new()
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(show_album.bind(false))
	section("ALBUM", album).add_child(back)
	var c := CenterContainer.new()
	g.ui.full(c)
	c.add_child(root)
	root.hide()
	build_hud_hotbar()

## Titled panel; returns its column so callers can add under the content.
func section(title: String, content: Control, parent: Node = null) -> VBoxContainer:
	var p: PanelContainer = g.ui.panel(0.92)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	p.add_child(col)
	var t: Label = g.ui.hud_label(col, 20)
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if content is GridContainer:
		content.add_theme_constant_override("h_separation", 4)
		content.add_theme_constant_override("v_separation", 4)
	col.add_child(content)
	(parent if parent else root).add_child(p)
	return col

func is_open() -> bool:
	return root.visible

## Spec 11: a modal screen freezes the dog; never opens over another freeze or when dead.
func toggle() -> void:
	if root.visible:
		root.hide()
		g.player.frozen = false
	elif not g.player.frozen and not g.player.dead:
		refresh()
		show_album(false)
		root.show()
		g.player.frozen = true

# ---------- hotbar ----------

func hotbar() -> Array:
	return g.save_extra.get("ui/hotbar", ["purina", "water", "", ""])

func bind(item: String, slot: int) -> void:
	var h := hotbar().duplicate()
	for i in h.size():
		if h[i] == item:
			h[i] = ""
	h[slot] = item
	g.save_extra["ui/hotbar"] = h
	if root.visible:
		refresh()

## Carried count: purina / water are player fields, the other shop goods live in player.bag.
func count(item: String) -> int:
	return int(g.player.get(item)) if item in ["purina", "water"] else int(g.player.bag.get(item, 0))

func add(item: String, n: int) -> void:
	if item in ["purina", "water"]:
		g.player.set(item, g.player.get(item) + n)
	else:
		g.player.bag[item] = count(item) + n

func use(item: String) -> bool:
	var ok := false
	if item == "purina":
		ok = g.player.use_purina()
	elif item == "water":
		ok = g.player.use_water()
	elif count(item) > 0:
		add(item, -1)
		if count(item) <= 0:
			g.player.bag.erase(item)
		g.player.consume(item)
		g.show_msg("%s: %s" % [Items.ITEM_INFO[item].name, Items.ITEM_INFO[item].effect])
		ok = true
	if ok:
		g.sfx("pickup")
	return ok

## Hotbar key n on the street.
func use_slot(n: int) -> void:
	if n < hotbar().size() and hotbar()[n] != "":
		use(hotbar()[n])

func build_hud_hotbar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in 4:
		var p := cell(row, null, "", "", 46.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key: Label = g.ui.hud_label(p, 11, Look.DIM)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		hud_slots.append({"icon": p.get_child(0), "count": p.get_child(1), "key": key})
	g.ui.dock(row, true, 10, Control.SIZE_SHRINK_END)

func _process(_delta: float) -> void:
	for s in hud_slots.size():
		var item: String = hotbar()[s]
		hud_slots[s].icon.texture = icon_of(item)
		hud_slots[s].count.text = "x%d" % count(item) if item != "" else ""
		hud_slots[s].key.text = " " + Keys.label("hot_%d" % (s + 1)).get_slice(" / ", 0).left(3)

# ---------- cells ----------

func icon_of(item: String) -> Texture2D:
	var info: Dictionary = Items.ITEM_INFO.get(item, {})
	return g.tex.get(info.get("icon", "")) if info.get("icon", "") != "" else null

## Square slot: icon fills it, `corner` text bottom-right. Children ignore the mouse so the
## slot itself gets clicks and drags.
func cell(parent: Node, tex: Texture2D, corner := "", tip := "", size := CELL) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	var sb := Look.box(Color(0.1, 0.11, 0.16, 0.92), 6, Look.EDGE, 4)
	sb.shadow_size = 0
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = tip
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.texture = tex
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)
	var l: Label = g.ui.hud_label(p, 12)
	l.text = corner
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	l.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(p)
	return p

func on_click(p: Control, left: Callable, right := Callable()) -> void:
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT and left.is_valid():
				left.call()
			elif e.button_index == MOUSE_BUTTON_RIGHT and right.is_valid():
				right.call())

func labeled(parent: Node, title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	g.ui.hud_label(v, 12, Look.DIM).text = title
	parent.add_child(v)
	return v

# ---------- panels ----------

func refresh() -> void:
	for box: Node in [ground, stats_box, gear, bag, album]:
		for ch in box.get_children():
			ch.free()
	album.add_child(Album.grid(Story.flags, replay))
	refresh_ground()
	refresh_stats()
	refresh_gear()
	refresh_bag()

func refresh_ground() -> void:
	var near: Array = g.treat_sprites.filter(func(s): return s.position.distance_to(g.player.position) < GROUND_PX)
	for i in 16:
		if i < near.size():
			var s: Sprite2D = near[i]
			on_click(cell(ground, g.tex.treat, "", "Treat - click to grab"), grab.bind(s))
		else:
			cell(ground, null)

func grab(s: Sprite2D) -> void:
	if not is_instance_valid(s):
		return
	g.player.treats += 1
	g.sfx("pickup")
	g.treat_sprites.erase(s)
	s.queue_free()
	refresh()

func refresh_gear() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	gear.add_child(top)
	var left := VBoxContainer.new()
	top.add_child(left)
	worn(left, "Head", "hat")
	var preview := Control.new()  # the dog as worn: collar, hat, outfit and armor (same Gear as in game)
	preview.custom_minimum_size = Vector2(150, 150)
	var dog := Sprite2D.new()
	dog.texture = g.player.sprite.texture
	dog.hframes = 2
	dog.scale = Vector2.ONE * 9.0
	dog.position = Vector2(75, 75)
	dog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.add_child(dog)
	g.wardrobe.Wardrobe.dress(dog, g.player.breed().file, g.wardrobe.Wardrobe.worn(g.save_extra, g.player.collar, g.player.armor))
	var mid := VBoxContainer.new()
	mid.add_child(preview)
	var name_l: Label = g.ui.hud_label(mid, 14)
	name_l.text = "%s   Lv %d" % [g.player.display_name(), g.player.level]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(mid)
	var right := VBoxContainer.new()
	top.add_child(right)
	cell(labeled(right, "Collar"), icon_of("collar") if g.player.collar != "" else null, g.player.collar.left(6), "Name collar: %s" % (g.player.collar if g.player.collar != "" else "none"))
	worn(right, "Outfit", "overlay")
	var arm: String = g.player.armor
	on_click(cell(labeled(left, "Armor"), icon_of(arm), "",
		("%s  -%d%% damage\nClick to swap, right-click to take off" % [Items.ARMOR[arm][0], roundi(g.player.defense() * 100)])
		if arm != "" else "No armor - buy some at shops"), next_armor, wear.bind(""))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var bar := labeled(gear, "Hotbar   (drag items here, right-click to clear)")
	bar.add_child(hb)
	for s in 4:
		var item: String = hotbar()[s]
		var p := cell(hb, icon_of(item), "x%d" % count(item) if item != "" else "",
			Keys.label("hot_%d" % (s + 1)), 60.0)
		g.ui.hud_label(p, 11, Look.DIM).text = " " + Keys.label("hot_%d" % (s + 1)).get_slice(" / ", 0)
		p.get_child(-1).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		p.set_drag_forwarding(Callable(),
			func(_at, d): return d is Dictionary and d.get("item", "") in CARRY,
			func(_at, d): bind(d.item, s))
		on_click(p, Callable(), clear_slot.bind(s))

## Head / Outfit: the worn wardrobe item; click opens the wardrobe (B).
func worn(parent: Node, title: String, slot: String) -> void:
	var id: String = g.wardrobe.equipped().get(slot, "")
	var info: Dictionary = g.wardrobe.Wardrobe.ITEMS.get(id, {})
	on_click(cell(labeled(parent, title), g.wardrobe.Wardrobe.icon(id), "",
		"%s - click for the wardrobe" % info.get("name", "Nothing")), open_wardrobe)

func open_wardrobe() -> void:
	toggle()
	g.wardrobe.toggle()

func clear_slot(s: int) -> void:
	var h := hotbar().duplicate()
	h[s] = ""
	g.save_extra["ui/hotbar"] = h
	refresh()

## Armor slot click: wear the next owned piece.
func next_armor() -> void:
	var owned: Array = g.player.armor_owned
	if owned.is_empty():
		return
	wear(owned[(owned.find(g.player.armor) + 1) % owned.size()])

func wear(id: String) -> void:
	g.player.armor = id
	g.sfx("pickup")
	refresh.call_deferred()  # the clicked cell is mid-signal; free it next frame

func stat_row(text: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l: Label = g.ui.hud_label(row, 13, Look.DIM)
	l.text = text
	l.custom_minimum_size.x = 120
	g.ui.hud_label(row, 13).text = value
	stats_box.add_child(row)
	return row

func refresh_stats() -> void:
	var p: Node = g.player
	stat_row("Level", "%d   (%d / %d XP)" % [p.level, p.xp, p.xp_needed()])
	var pts: Label = g.ui.hud_label(stats_box, 14, Color(1, 0.85, 0.3) if p.points > 0 else Look.DIM)
	pts.text = "%d stat point%s to spend" % [p.points, "" if p.points == 1 else "s"]
	var shown := ["%d" % int(p.max_hp), "%.1f" % p.attack_damage(), "%.1f" % p.top_mph()]
	for i in p.STATS.size():
		var st: Array = p.STATS[i]
		var row := stat_row(st[1], "%s   (x%d)" % [shown[i], int(p.get(st[0]))])
		var plus := Button.new()
		plus.text = "+%s" % str(st[2])
		plus.focus_mode = Control.FOCUS_NONE
		plus.disabled = p.points <= 0
		plus.tooltip_text = "Spend 1 point: +%s %s" % [str(st[2]), st[1]]
		plus.pressed.connect(g.pick_stat.bind(i))
		row.add_child(plus)
	stat_row("Armor", "-%d%% damage" % roundi(p.defense() * 100))
	stat_row("Crit", "%.1f%%" % (p.crit_chance() * 100))

func refresh_bag() -> void:
	var n := 0
	for item: String in CARRY:
		if count(item) <= 0:
			continue
		var info: Dictionary = Items.ITEM_INFO[item]
		var p := cell(bag, icon_of(item), "x%d" % count(item),
			"%s  %s\nDrag to the hotbar, right-click to use" % [info.name, info.effect])
		p.set_drag_forwarding(func(_at): return drag(item), Callable(), Callable())
		on_click(p, Callable(), func(): use(item); refresh())
		n += 1
	for a: String in g.player.armor_owned:
		if a == g.player.armor:
			continue
		var c := cell(bag, icon_of(a), "", "%s  -%d%% damage\nRight-click to wear" % [Items.ARMOR[a][0], roundi(Items.ARMOR[a][1] * 100)])
		on_click(c, Callable(), wear.bind(a))
		n += 1
	for i: String in Story.items:
		cell(bag, null, i.left(6), "Sam's " + i.capitalize())
		n += 1
	for c: String in Story.keycards:
		cell(bag, null, "KEY", "%s HQ keycard" % Gates.CITIES[c][0])
		n += 1
	for i in range(n, 25):
		cell(bag, null)
	var shots: int = Story.flags.filter(func(f): return f.begins_with("fb_")).size()
	wallet.text = "%d treats   %d bones   Polaroids %d / %d" % [g.player.treats, g.economy.bones, shots, ALBUM]

## Album tab (spec 11): the polaroid grid in place of the other three panels.
func show_album(on: bool) -> void:
	for p: Control in root.get_children():
		p.visible = (p == album.get_parent().get_parent()) == on

func replay(fb: String) -> void:
	toggle()
	g.flashback.play(fb)

func drag(item: String) -> Variant:
	var t := TextureRect.new()
	t.texture = icon_of(item)
	t.custom_minimum_size = Vector2(40, 40)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.set_drag_preview(t)
	return {"item": item}
