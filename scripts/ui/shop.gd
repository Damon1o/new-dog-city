extends Node
## Shop menu (spec 11 Shop): rows with icon, name, effect, price (struck-through list price
## when discounted) and owned count; footer with wallet and discount source.
## [1-4] buy x1, Shift + [1-4] buy x5. Shown while game.ctx == "bodega".
## Pizza (spec 08 Stealing): one more row steals a slice; the clerk turns to watch the counter
## every 3-6 s for 1.5 s ("!" over his head). Unwatched = a free slice in the bag; watched = pushed
## out. +25 heat. The clerk is a person (person_art.gd): bite him enough and he's gone for the visit
## (5 stars), nobody watches the counter.

const Items := preload("res://scripts/data/items.gd")
const Wardrobe := preload("res://scripts/data/wardrobe.gd")
const MAX_ROWS := 4

var g: Node2D
var box: PanelContainer
var head: Label
var rows: Array[Dictionary] = []  # {row, icon, name, price, owned}
var wallet: Label
var source: Label
var steal_row: Label
var clerk: Node2D  # pizza clerk, lives in the room (freed with it)
var clerk_room: Node  # room the clerk was killed in: no new clerk until the dog leaves it
var turn_t := 3.0   # s until the clerk turns to watch
var watch_t := 0.0  # s left watching the counter

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
	steal_row = ui.hud_label(col, 16, Color(1, 0.6, 0.5))
	box.hide()
	ui.dock(box, true, 60)

func _process(delta: float) -> void:
	# runs after game._process (child order), so ctx is this frame's
	box.visible = g.ctx == "bodega"
	if g.inside == "shop" and g.interior.room and template() == "pizza":
		clerk_watch(delta)
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
		r.icon.texture = g.tex.get(icon_key) if icon_key != "" else Wardrobe.icon(item)  # armor art
		r.name.text = "[%d]  %s   %s" % [i + 1, info.name, info.effect]
		r.price.text = ("[s]%d[/s] [color=#8f8]%d[/color] treats" % [full, now]) if now < full else "%d treats" % now
		r.owned.text = "own %d" % g.inventory.count(item) if item in Items.CARRY else ("owned" if item in g.player.armor_owned else "")
		r.row.modulate = Color.WHITE if g.player.treats >= now else Color(0.55, 0.55, 0.55)
	wallet.text = "Wallet: %d treats   %d bones        [1-%d] buy x1   Shift + number: x5" % [
		g.player.treats, eco.bones, st.size()]
	source.text = eco.discount_label()
	source.visible = source.text != ""
	steal_row.visible = template() == "pizza"
	steal_row.text = "[%d]  Steal slice  (+25 heat)      Clerk: %s" % [st.size() + 1, "WATCHING!" if watch_t > 0.0 else "back turned"]

## Buy item n, qty times (collar: always one). Returns how many were bought.
func buy(n: int, qty := 1) -> int:
	if n == stock().size() and template() == "pizza":
		steal()
		return 0
	if n < 0 or n >= stock().size():
		return 0
	var item: String = stock()[n][0]
	if item == "collar" or Items.ARMOR.has(item):
		qty = 1
	if item in g.player.armor_owned:
		g.show_msg("You already own that - wear it from the bag [%s]" % g.Keys.label("inventory"))
		return 0
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
	elif Items.ARMOR.has(item):
		g.player.armor_owned.append(item)
		g.player.armor = item  # wear it right away; swap in the bag's Armor slot
		g.show_msg("Wearing %s  (-%d%% damage)" % [Items.ARMOR[item][0], roundi(Items.ARMOR[item][1] * 100)])
	else:  # carried in the bag; drag onto the hotbar, keys 1-4 use it
		g.inventory.add(item, qty)
		g.show_msg("Bought %s%s - in your bag [%s]" % [Items.ITEM_INFO[item].name, " x%d" % qty if qty > 1 else "", g.Keys.label("inventory")])
	g.bump("bought")
	g.save_game()
	return qty

## Spec 08: +25 heat either way; a free slice only while the clerk looks away.
func steal() -> bool:
	g.wanted.add_heat(25, "steal")
	if watch_t > 0.0:
		g.show_msg("The clerk saw you! Out!")
		g.interior.leave()
		return false
	g.inventory.add("pizza", 1)
	g.show_msg("Stole a slice! - in your bag [%s]" % g.Keys.label("inventory"))
	g.save_game()
	return true

func clerk_watch(delta: float) -> void:
	if not is_instance_valid(clerk) or clerk.is_queued_for_deletion():
		if clerk_room == g.interior.room:  # killed this visit: the counter is unwatched
			watch_t = 0.0
			return
		clerk = Clerk.new()
		clerk.shop = self
		clerk.position = g.interior.O + Vector2(480, 196)  # behind the counter, drawn over its sprite
		clerk.z_index = 1
		g.interior.room.add_child(clerk)
	if watch_t > 0.0:
		watch_t -= delta
		if watch_t <= 0.0:
			turn_t = randf_range(3.0, 6.0)
	else:
		turn_t -= delta
		if turn_t <= 0.0:
			watch_t = 1.5
	clerk.queue_redraw()

## Pizza clerk: faces the oven (back turned) or the room (watching, "!"). 30 HP.
class Clerk extends Node2D:
	const P := preload("res://scripts/person_art.gd")
	const LOOK := {"skin": Color(0.88, 0.68, 0.5), "hair": Color(0.1, 0.08, 0.07), "style": "short", "shirt": Color(0.8, 0.15, 0.12),
		"pants": Color(0.15, 0.15, 0.18), "build": 1.1, "hat": "paper", "apron": Color(0.96, 0.96, 0.92)}
	var shop: Node
	var hp := 30.0

	func _ready() -> void:
		add_to_group("person")  # game.on_bite

	func hurt(dmg: float) -> void:
		hp -= dmg
		P.hit(self, shop.g, dmg, hp <= 0.0)
		if hp <= 0.0:
			shop.clerk_room = shop.g.interior.room
			queue_free()
		else:
			shop.watch_t = 2.0  # now he's watching

	func _draw() -> void:
		var watching: bool = shop.watch_t > 0.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if watching else 1.0, 1.0))  # oven is to his right
		P.draw(self, LOOK, 0.0, "reach" if watching else "walk", "angry" if watching else "")
		draw_set_transform(Vector2.ZERO)
		if watching:
			draw_string_outline(ThemeDB.fallback_font, Vector2(-4, -36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 3, Color.BLACK)
			draw_string(ThemeDB.fallback_font, Vector2(-4, -36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.3, 0.2))
