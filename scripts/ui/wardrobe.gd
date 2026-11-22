extends Node
## Wardrobe (B), spec 11: live dog preview on the left (turns every 2 s); tabs Collar / Hat /
## Outfit on the right with a grid of owned, buyable (price) and locked (hint) items,
## one Equip / Buy button, treats and bones. Saves as save_extra "wardrobe/owned" / "wardrobe/equipped".
## Reuses the inventory's cell() / on_click(). ponytail: item bonuses (spec 05) not applied yet,
## every unlockable is locked until its source (Top Dog, trader, cats) exists.

const Wardrobe := preload("res://scripts/data/wardrobe.gd")
const Save := preload("res://scripts/systems/save.gd")
const Look := preload("res://scripts/ui/theme.gd")

var g: Node2D
var root: HBoxContainer
var tabs: TabContainer
var dog: Sprite2D  # preview
var info: Label
var wallet: Label
var button: Button
var sel := ""  # selected item id
var turn_t := 0.0

func build() -> void:
	root = HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	var left: PanelContainer = g.ui.panel(0.92)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(220, 220)
	left.add_child(stage)
	dog = Sprite2D.new()
	dog.hframes = 2
	dog.scale = Vector2.ONE * 10.0
	dog.position = Vector2(110, 120)
	dog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(dog)
	root.add_child(left)
	var right: PanelContainer = g.ui.panel(0.92)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	right.add_child(col)
	var t: Label = g.ui.hud_label(col, 20)
	t.text = "WARDROBE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(300, 190)
	for slot: String in Wardrobe.SLOTS:
		var grid := GridContainer.new()
		grid.name = Wardrobe.SLOTS[slot]
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		tabs.add_child(grid)
	col.add_child(tabs)
	info = g.ui.hud_label(col, 14)
	button = Button.new()
	button.pressed.connect(press)
	col.add_child(button)
	wallet = g.ui.hud_label(col, 13, Look.DIM)
	root.add_child(right)
	var c := CenterContainer.new()
	g.ui.full(c)
	c.add_child(root)
	root.hide()

func is_open() -> bool:
	return root.visible

## Same freeze rules as the inventory (spec 11).
func toggle() -> void:
	if root.visible:
		root.hide()
		g.player.frozen = false
	elif not g.player.frozen and not g.player.dead:
		refresh()
		root.show()
		g.player.frozen = true

func _process(delta: float) -> void:
	if not root.visible:
		return
	turn_t += delta
	if turn_t >= 2.0:
		turn_t = 0.0
		dog.flip_h = not dog.flip_h
		Wardrobe.flip(dog)

# ---------- state ----------

func owned_list() -> Array:
	return g.save_extra.get("wardrobe/owned", [])

func equipped() -> Dictionary:
	return g.save_extra.get("wardrobe/equipped", Save.V2["wardrobe/equipped"].duplicate())

func owns(id: String) -> bool:
	if id == "name":
		return g.player.collar != ""  # bought at the bodega
	return Wardrobe.ITEMS[id].get("start", false) or id in owned_list()

## Owned too: the default "name" collar sits in the save before the dog has a name.
func is_worn(id: String) -> bool:
	return owns(id) and equipped().get(Wardrobe.ITEMS[id].slot, "") == id

func price(id: String) -> Array:
	return Wardrobe.ITEMS[id].get("cost", [])

func can_pay(cost: Array) -> bool:
	return (g.player.treats if cost[1] == "treats" else g.economy.bones) >= cost[0]

## Equip / Buy button: buy if buyable, else toggle the item on (or off).
func press() -> void:
	if sel == "":
		return
	if not owns(sel):
		var cost := price(sel)
		if cost.is_empty() or not can_pay(cost):
			return
		if cost[1] == "treats":
			g.player.treats -= cost[0]
		else:
			g.economy.bones -= cost[0]
		g.save_extra["wardrobe/owned"] = owned_list() + [sel]
		g.sfx("pickup")
	equip(sel)

func equip(id: String) -> void:
	var eq := equipped().duplicate()
	var slot: String = Wardrobe.ITEMS[id].slot
	eq[slot] = "" if eq.get(slot, "") == id else id
	g.save_extra["wardrobe/equipped"] = eq
	g.player.apply_skin()
	if root.visible:
		refresh()

# ---------- view ----------

func refresh() -> void:
	var p: Node = g.player
	dog.texture = p.sprite.texture
	Wardrobe.dress(dog, p.breed().file, Wardrobe.worn(g.save_extra, p.collar, p.armor))
	for slot: String in Wardrobe.SLOTS:
		var grid: GridContainer = tabs.get_node(Wardrobe.SLOTS[slot])
		for ch in grid.get_children():
			ch.free()
		var ids: Array = Wardrobe.ITEMS.keys().filter(func(id): return Wardrobe.ITEMS[id].slot == slot)
		for id: String in ids:
			var cell: PanelContainer = g.inventory.cell(grid, Wardrobe.icon(id), tag(id), title(id))
			if tag(id) == "?":
				cell.modulate = Color(1, 1, 1, 0.45)  # locked
			g.inventory.on_click(cell, pick.bind(id))
	button.disabled = true
	button.text = "Pick an item"
	info.text = ""
	if sel != "":
		var cost := price(sel)
		button.disabled = not owns(sel) and (cost.is_empty() or not can_pay(cost))
		if owns(sel):
			button.text = "Unequip" if is_worn(sel) else "Equip"
		else:
			button.text = "Locked" if cost.is_empty() else "Buy (%d %s)" % cost
		info.text = title(sel) + ("\nLocked: " + Wardrobe.ITEMS[sel].hint if tag(sel) == "?" else "")
	wallet.text = "%d treats   %d bones" % [p.treats, g.economy.bones]

## Cell corner: ON (worn), blank (owned), price (buyable) or ? (locked).
func tag(id: String) -> String:
	if is_worn(id):
		return "ON"
	if owns(id):
		return ""
	var cost := price(id)
	return "?" if cost.is_empty() else "%d%s" % [cost[0], "t" if cost[1] == "treats" else "b"]

func pick(id: String) -> void:
	sel = id
	refresh()

func title(id: String) -> String:
	return str(Wardrobe.ITEMS[id].name)
