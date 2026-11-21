extends Node
## Stock app (spec 09 / 11): per ticker price, change since the last visit, 60-point sparkline,
## holdings and buy / sell buttons; footer with wallet and total value. Built by
## scripts/systems/stocks.gd on first open; P or Esc closes it.

const Look := preload("res://scripts/ui/theme.gd")
const Keys := preload("res://scripts/systems/keys.gd")

var g: Node2D
var s: Node  # scripts/systems/stocks.gd
var root: PanelContainer
var rows := {}  # id -> {price, change, spark, held}
var footer: Label
var seen := {}  # prices when the app last closed ("change since last visit")

func build() -> void:
	root = g.ui.panel(0.92)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)
	var t: Label = g.ui.hud_label(col, 20)
	t.text = "NYSE   KIBBLE EXCHANGE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 10)
	col.add_child(grid)
	for id: String in s.TICKERS:
		var r := {}
		g.ui.hud_label(grid, 15).text = "%s  %s" % [id, s.TICKERS[id][0]]
		r.price = g.ui.hud_label(grid, 15)
		r.change = g.ui.hud_label(grid, 14)
		r.spark = Control.new()
		r.spark.custom_minimum_size = Vector2(120, 26)
		r.spark.draw.connect(spark.bind(r.spark, id))
		grid.add_child(r.spark)
		r.held = g.ui.hud_label(grid, 14, Look.DIM)
		for b: Array in [["Buy 1", 1], ["Buy 10", 10], ["Sell 1", -1], ["Sell all", -s.MAX_HELD]]:
			var btn := Button.new()
			btn.text = b[0]
			btn.focus_mode = Control.FOCUS_NONE  # keys stay with the game (P / Esc)
			btn.pressed.connect(trade.bind(id, b[1]))
			grid.add_child(btn)
		rows[id] = r
	footer = g.ui.hud_label(col, 14, Color(1, 0.85, 0.5))
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
		for id: String in s.TICKERS:
			seen[id] = s.price(id)
	elif not g.player.frozen and not g.player.dead:
		root.show()
		g.player.frozen = true

## n > 0 buys n shares, n < 0 sells up to -n.
func trade(id: String, n: int) -> void:
	var done: int = s.buy(id, n) if n > 0 else s.sell(id, -n)
	g.sfx("buy" if done > 0 else "hurt")

func _process(_delta: float) -> void:
	if not root.visible:
		return
	for id: String in rows:
		var r: Dictionary = rows[id]
		var p: float = s.price(id)
		var before: float = seen.get(id, s.history(id)[0])
		var pct := (p / before - 1.0) * 100.0
		r.price.text = "%.2f" % p
		r.change.text = "%+.1f%%" % pct
		r.change.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if pct >= 0.0 else Color(1, 0.5, 0.45))
		r.held.text = "own %d" % s.held(id)
		r.spark.queue_redraw()
	footer.text = "Wallet: %d treats    Portfolio: %d treats    Sells pay a 2%% fee    [%s] / Esc close" % [
		g.player.treats, s.value(), Keys.label("stocks")]

func spark(c: Control, id: String) -> void:
	var h: Array = s.history(id)
	if h.size() < 2:
		return
	var lo: float = h.min()
	var hi: float = maxf(h.max(), lo + 0.01)
	var pts := PackedVector2Array()
	for i in h.size():
		pts.append(Vector2(c.size.x * i / (s.HISTORY - 1.0), c.size.y * (1.0 - (h[i] - lo) / (hi - lo))))
	c.draw_polyline(pts, Color(0.5, 1, 0.6) if h[-1] >= h[0] else Color(1, 0.5, 0.45), 1.5, true)
