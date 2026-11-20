extends Node
## Inventory (spec 11, I): tabs Items / Sam / Album / Keys / Stocks. Items can be used and
## bound to hotbar slots 1-4 (number keys on the street). Hotbar saves in save_extra["ui/hotbar"].

const Items := preload("res://scripts/data/items.gd")
const Gates := preload("res://scripts/data/gates.gd")
const Look := preload("res://scripts/ui/theme.gd")
const CARRY := ["purina", "water"]  # the only carried consumables so far
const ALBUM := 17

var g: Node2D
var box: PanelContainer
var tabs: TabContainer
var pages := {}  # tab name -> VBoxContainer

func build() -> void:
	box = g.ui.panel()
	box.custom_minimum_size = Vector2(560, 340)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	g.ui.hud_label(col, 20, Look.ACCENT.lightened(0.35)).text = "INVENTORY        [I] close"
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	for t in ["Items", "Sam", "Album", "Keys", "Stocks"]:
		var v := VBoxContainer.new()
		v.name = t
		v.add_theme_constant_override("separation", 6)
		tabs.add_child(v)
		pages[t] = v
	var c := CenterContainer.new()
	g.ui.full(c)
	c.add_child(box)
	box.hide()

func is_open() -> bool:
	return box.visible

## Spec 11 rule: a modal screen freezes the dog; only opens when nothing else has it frozen.
func toggle() -> void:
	if box.visible:
		box.hide()
		g.player.frozen = false
	elif not g.player.frozen and not g.player.dead:
		refresh()
		box.show()
		g.player.frozen = true

func hotbar() -> Array:
	return g.save_extra.get("ui/hotbar", ["purina", "water", "", ""])

func bind(item: String, slot: int) -> void:
	var h := hotbar().duplicate()
	for i in h.size():
		if h[i] == item:
			h[i] = ""
	h[slot] = item
	g.save_extra["ui/hotbar"] = h
	refresh()

func use(item: String) -> bool:
	var ok: bool = g.player.use_purina() if item == "purina" else g.player.use_water() if item == "water" else false
	if ok:
		g.sfx("pickup")
	return ok

## Number key n on the street.
func use_slot(n: int) -> void:
	if n < hotbar().size() and hotbar()[n] != "":
		use(hotbar()[n])

func refresh() -> void:
	for p: Node in pages.values():
		for ch in p.get_children():
			ch.free()
	for item: String in CARRY:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		pages.Items.add_child(row)
		var info: Dictionary = Items.ITEM_INFO[item]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = g.tex.get(info.icon)
		row.add_child(icon)
		var l: Label = g.ui.hud_label(row, 15)
		l.text = "%s  x%d     %s" % [info.name, int(g.player.get(item)), info.effect]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var u := Button.new()
		u.text = "Use"
		u.disabled = int(g.player.get(item)) <= 0
		u.pressed.connect(func(): use(item); refresh())
		row.add_child(u)
		for s in 4:
			var b := Button.new()
			b.text = str(s + 1)
			b.tooltip_text = "Bind to %d" % (s + 1)
			b.modulate = Color.WHITE if hotbar()[s] == item else Color(1, 1, 1, 0.45)
			b.pressed.connect(bind.bind(item, s))
			row.add_child(b)
	for slot in g.player.buffs:
		var bf: Dictionary = g.player.buffs[slot]
		note(pages.Items, "%s buff: %s  %ds left" % [slot.capitalize(), Items.ITEM_INFO[bf.id].name, ceili(bf.t)], Look.ACCENT.lightened(0.3))
	note(pages.Items, "Bound items: number keys 1-4 on the street.", Look.DIM)
	lines(pages.Sam, Story.items.map(func(i): return i.capitalize()), "Nothing of Sam's yet. Story items land here.")
	var shots: Array = Story.flags.filter(func(f): return f.begins_with("fb_"))
	note(pages.Album, "Polaroids  %d / %d" % [shots.size(), ALBUM], Look.ACCENT.lightened(0.3))
	lines(pages.Album, shots.map(func(f): return f.trim_prefix("fb_").replace("_", " ").capitalize()), "Clear an HQ floor to find a flashback.")
	lines(pages.Keys, Story.keycards.map(func(c): return "%s HQ keycard" % Gates.CITIES[c][0]), "No keycards yet. Each city boss drops one.")
	var held: Dictionary = g.save_extra.get("stocks/held", {})
	lines(pages.Stocks, held.keys().map(func(k): return "%s   x%s" % [k, held[k]]), "No stocks held. The stock app opens at the NYSE.")

func note(page: Node, text: String, color := Color.WHITE) -> void:
	g.ui.hud_label(page, 14, color).text = text

func lines(page: Node, rows: Array, empty: String) -> void:
	if rows.is_empty():
		note(page, empty, Look.DIM)
	for r in rows:
		note(page, "•  " + str(r))
