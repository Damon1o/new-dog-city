extends Node
## Shop menu (spec 11 Shop): rows with icon, name, effect, price (struck-through list price
## when discounted) and owned count; footer with wallet and discount source.
## [1-4] buy x1, Shift + [1-4] buy x5. Shown while game.ctx == "bodega".

const Items := preload("res://scripts/data/items.gd")
const MAX_ROWS := 4

var g: Node2D
var box: PanelContainer
var head: Label
var rows: Array[Dictionary] = []  # {row, icon, name, price, owned}
var wallet: Label
var source: Label

func build() -> void:
	var ui: Node = g.ui
	box = ui.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	head = ui.hud_label(col, 18, Color(1, 0.9, 0.4))
	for i in MAX_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var item_name: Label = ui.hud_label(row, 16)
		item_name.custom_minimum_size.x = 300
		var price := RichTextLabel.new()
		price.bbcode_enabled = true
		price.fit_content = true
		price.scroll_active = false
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		price.custom_minimum_size.x = 120
		price.add_theme_font_size_override("normal_font_size", 16)
		price.add_theme_color_override("font_outline_color", Color.BLACK)
		price.add_theme_constant_override("outline_size", 4)
		row.add_child(price)
		var owned: Label = ui.hud_label(row, 14, Color(0.8, 0.8, 0.8))
		rows.append({"row": row, "icon": icon, "name": item_name, "price": price, "owned": owned})
	wallet = ui.hud_label(col, 14, Color(1, 0.85, 0.5))
	source = ui.hud_label(col, 13, Color(0.6, 1, 0.7))
	box.hide()
	ui.dock(box, true, 60)

func _process(_delta: float) -> void:
	# runs after game._process (child order), so ctx is this frame's
	box.visible = g.ctx == "bodega"
	if box.visible:
		refresh()

const TITLES := {"bodega": "BODEGA", "shop_small": "SHOP", "gas": "GAS STATION", "pizza": "PIZZA", "cafe": "CAFE"}

func template() -> String:
	var t: String = g.interior.door.get("template", "bodega")
	return t if Items.SHOPS.has(t) else "bodega"

## Rows for the shop the dog is in (spec 09 "Sold at").
func stock() -> Array:
	return Items.SHOPS[template()]

## Door id of the shop the dog is in, for its price roll. Bodegas keep their old
## nearest-bodega id so their rolls (and saves) don't move.
func door_id() -> String:
	if template() != "bodega":
		return str(g.interior.door.id)
	var best := 0
	for i in g.bodega_doors.size():
		if g.return_pos.distance_squared_to(g.bodega_doors[i]) < g.return_pos.distance_squared_to(g.bodega_doors[best]):
			best = i
	return "%s_bodega_%d" % [str(g.save_extra.get("world/city", "nyc")), best]

func price_of(n: int) -> int:
	return g.economy.price(int(stock()[n][1]), door_id())

func refresh() -> void:
	var eco: Node = g.economy
	var door := door_id()
	var st := stock()
	head.text = TITLES[template()]
	for i in rows.size():
		var r: Dictionary = rows[i]
		r.row.visible = i < st.size()
		if not r.row.visible:
			continue
		var item: String = st[i][0]
		var info: Dictionary = Items.ITEM_INFO.get(item, {"name": item, "effect": "", "icon": ""})
		var base: int = st[i][1]
		var full: int = eco.list_price(base, door)
		var now: int = eco.price(base, door)
		var icon_key: String = info.icon
		r.icon.texture = g.tex.get(icon_key) if icon_key != "" else null
		r.name.text = "[%d]  %s   %s" % [i + 1, info.name, info.effect]
		r.price.text = ("[s]%d[/s] [color=#8f8]%d[/color] treats" % [full, now]) if now < full else "%d treats" % now
		r.owned.text = "own %d" % int(g.player.get(item)) if item in ["purina", "water"] else ""
		r.row.modulate = Color.WHITE if g.player.treats >= now else Color(0.55, 0.55, 0.55)
	wallet.text = "Wallet: %d treats   %d bones        [1-%d] buy x1   Shift + number: x5" % [
		g.player.treats, eco.bones, st.size()]
	source.text = eco.discount_label()
	source.visible = source.text != ""

## Buy item n, qty times (collar: always one). Returns how many were bought.
func buy(n: int, qty := 1) -> int:
	if n < 0 or n >= stock().size():
		return 0
	var item: String = stock()[n][0]
	if item == "collar":
		qty = 1
	var each := price_of(n)
	var total := each * qty
	if not g.economy.spend_treats(total):
		g.show_msg("Need %d treats for that" % total)
		return 0
	g.sfx("buy")
	if item == "collar":
		g.player.frozen = true
		g.name_edit.text = g.player.collar
		g.name_edit.show()
		g.name_edit.grab_focus()
	elif item in ["purina", "water"]:  # carried; Q / E use them later
		g.player.set(item, g.player.get(item) + qty)
		g.show_msg("Bought %s%s" % [item, " x%d" % qty if qty > 1 else ""])
	else:  # eaten / drunk on the spot
		for i in qty:
			g.player.consume(item)
		g.show_msg("Ate %s" % Items.ITEM_INFO[item].name)
	g.bump("bought")
	g.save_game()
	return qty
