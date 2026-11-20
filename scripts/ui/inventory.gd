extends Node
## Inventory (I): three panels like a survival-game bag.
##   ON THE GROUND  treats near the dog; click to grab
##   EQUIPMENT      dog preview, Head / Collar / Skin / Outfit slots, the 4-slot hotbar
##   INVENTORY      grid of carried items, Sam's things and keycards
## Drag an item onto a hotbar slot to bind it; right-click an item to use it, a hotbar slot to clear it.
## The hotbar also sits on the HUD (bottom right) and saves as save_extra["ui/hotbar"].

const Items := preload("res://scripts/data/items.gd")
const Gates := preload("res://scripts/data/gates.gd")
const Look := preload("res://scripts/ui/theme.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const CARRY := ["purina", "water"]  # bindable consumables so far
const ALBUM := 17
const CELL := 54.0
const GROUND_PX := 320.0

var g: Node2D
var root: HBoxContainer
var ground: GridContainer
var gear: VBoxContainer
var bag: GridContainer
var wallet: Label
var hud_slots: Array[Dictionary] = []  # HUD hotbar: {icon, count, key}

func build() -> void:
	root = HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	ground = GridContainer.new()
	ground.columns = 4
	section("ON THE GROUND", ground)
	gear = VBoxContainer.new()
	gear.add_theme_constant_override("separation", 8)
	section("EQUIPMENT", gear)
	bag = GridContainer.new()
	bag.columns = 5
	var right := section("INVENTORY", bag)
	wallet = g.ui.hud_label(right, 13, Look.DIM)
	var c := CenterContainer.new()
	g.ui.full(c)
	c.add_child(root)
	root.hide()
	build_hud_hotbar()

## Titled panel; returns its column so callers can add under the content.
func section(title: String, content: Control) -> VBoxContainer:
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
	root.add_child(p)
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

func use(item: String) -> bool:
	var ok: bool = g.player.use_purina() if item == "purina" else g.player.use_water() if item == "water" else false
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
		hud_slots[s].count.text = "x%d" % int(g.player.get(item)) if item != "" else ""
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
	for box: Node in [ground, gear, bag]:
		for ch in box.get_children():
			ch.free()
	refresh_ground()
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
	var t: Texture2D = g.player.sprite.texture
	var frame := AtlasTexture.new()  # sprite sheet is 2 walk frames side by side; show the first
	frame.atlas = t
	frame.region = Rect2(0, 0, t.get_width() / 2.0, t.get_height())
	var breed: Dictionary = g.player.breed()
	on_click(cell(labeled(left, "Skin"), frame, "", "%s - click to change breed" % breed.name), next_breed)
	var preview := TextureRect.new()
	preview.texture = frame
	preview.custom_minimum_size = Vector2(150, 150)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mid := VBoxContainer.new()
	mid.add_child(preview)
	var name_l: Label = g.ui.hud_label(mid, 14)
	name_l.text = "%s   Lv %d" % [g.player.display_name(), g.player.level]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(mid)
	var right := VBoxContainer.new()
	top.add_child(right)
	cell(labeled(right, "Collar"), null, g.player.collar.left(6), "Name collar: %s" % (g.player.collar if g.player.collar != "" else "none"))
	worn(right, "Outfit", "overlay")
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var bar := labeled(gear, "Hotbar   (drag items here, right-click to clear)")
	bar.add_child(hb)
	for s in 4:
		var item: String = hotbar()[s]
		var p := cell(hb, icon_of(item), "x%d" % int(g.player.get(item)) if item != "" else "",
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

func next_breed() -> void:
	g.prev_skin = g.player.skin
	g.player.cycle_skin()
	refresh()

func refresh_bag() -> void:
	var n := 0
	for item: String in CARRY:
		if int(g.player.get(item)) <= 0:
			continue
		var info: Dictionary = Items.ITEM_INFO[item]
		var p := cell(bag, icon_of(item), "x%d" % int(g.player.get(item)),
			"%s  %s\nDrag to the hotbar, right-click to use" % [info.name, info.effect])
		p.set_drag_forwarding(func(_at): return drag(item), Callable(), Callable())
		on_click(p, Callable(), func(): use(item); refresh())
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

func drag(item: String) -> Variant:
	var t := TextureRect.new()
	t.texture = icon_of(item)
	t.custom_minimum_size = Vector2(40, 40)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.set_drag_preview(t)
	return {"item": item}
