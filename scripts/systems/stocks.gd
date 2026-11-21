extends Node
## NYSE stock market (spec 09): 5 tickers tick every 10 real seconds while playing,
## p *= 1 + drift + randfn(0, vol), clamped to [1, 999]. A headline moves one ticker 15-30%
## every 2-3 in-game days. Buy with treats (rounded up), sell with a 2% fee (rounded down),
## max 999 shares each. State lives in g.save_extra "stocks/prices" / "stocks/history" /
## "stocks/held", so systems/save.gd saves it as is. The app is scripts/ui/stocks.gd (P).

const App := preload("res://scripts/ui/stocks.gd")
const TICKERS := {  # id -> [name, start, volatility, drift] per tick
	"KIBL": ["Kibble Corp", 20.0, 0.02, 0.002],
	"BONE": ["Bone Holdings", 50.0, 0.04, 0.001],
	"SQRL": ["Squirrel Futures", 8.0, 0.09, 0.0],
	"PURR": ["Purr Industries", 30.0, 0.05, -0.001],
	"CHEW": ["Chew Toy Tech", 12.0, 0.07, 0.003],
}
const NEWS := {  # id -> [good headline, bad headline]
	"KIBL": ["Vets say kibble is the new superfood!", "Kibble recall: bags full of cardboard"],
	"BONE": ["Bone shortage: buried stock up!", "Dog digs up a warehouse of bones"],
	"SQRL": ["Squirrel shortage in the park!", "Squirrels everywhere: futures crash"],
	"PURR": ["Cats win the yarn contract", "Laser pointer recall hits Purr"],
	"CHEW": ["Squeaky toy goes viral!", "Chew Toy Tech recalls exploding squeakers"],
}
const TICK := 10.0
const HISTORY := 60
const FEE := 0.02
const MAX_HELD := 999
const LO := 1.0
const HI := 999.0
const VISITED := "nyse_visited"  # story flag: P opens the app anywhere after the first terminal

var g: Node2D
var rng := RandomNumberGenerator.new()  # own stream: ticks never shift the game's seeded rolls
var tick_t := TICK
var news_day := -1  # in-game day of the next headline. ponytail: not saved, rerolled per session
var app: Node  # scripts/ui/stocks.gd, built on first open
var art: Node2D  # tape + terminals, lives in the NYSE room (freed with it)

func _ready() -> void:
	if g.rng_seed:
		rng.seed = g.rng_seed

static func step(p: float, drift: float, vol: float, r: RandomNumberGenerator) -> float:
	return clampf(p * (1.0 + drift + r.randfn(0.0, vol)), LO, HI)

func book(key: String) -> Dictionary:
	if not (g.save_extra.get(key) is Dictionary):
		g.save_extra[key] = {}
	return g.save_extra[key]

func price(id: String) -> float:
	return float(book("stocks/prices").get(id, TICKERS[id][1]))

func history(id: String) -> Array:
	var h := book("stocks/history")
	if not (h.get(id) is Array):
		h[id] = [price(id)]
	return h[id]

func held(id: String) -> int:
	return int(book("stocks/held").get(id, 0))

func set_price(id: String, p: float) -> void:
	book("stocks/prices")[id] = p
	var h := history(id)
	h.append(p)
	while h.size() > HISTORY:
		h.pop_front()

func _process(delta: float) -> void:
	tick_t -= delta
	if tick_t <= 0.0:
		tick_t = TICK
		tick()
	if g.inside == "nyse" and g.interior.room:
		room_art()
		if g.act == "" and not g.player.frozen and g.player.position.distance_to(g.interior.spots.terminal) < 70.0:
			g.set_act("stocks", "NYSE TERMINAL", "[F]  Open the stock app")

func tick() -> void:
	for id: String in TICKERS:
		set_price(id, step(price(id), TICKERS[id][3], TICKERS[id][2], rng))
	var day: int = g.territory.day()
	if news_day < 0:
		news_day = day + rng.randi_range(2, 3)
	elif day >= news_day:
		news_day = day + rng.randi_range(2, 3)
		var id: String = TICKERS.keys()[rng.randi() % TICKERS.size()]
		var up := rng.randf() < 0.5
		shock(id, rng.randf_range(0.15, 0.3) * (1.0 if up else -1.0), NEWS[id][0 if up else 1])
	if not Story.has("nyse_kibl_10") and claimed_nyc() >= 10:  # spec 09 play-linked event
		Story.set_flag("nyse_kibl_10")
		shock("KIBL", 0.2, "Top dog claims 10 blocks!")

## News and play events, e.g. Fat Cat (M5-7) beaten: shock("PURR", -0.4, "Fat Cat ousted!").
func shock(id: String, pct: float, headline: String) -> void:
	set_price(id, clampf(price(id) * (1.0 + pct), LO, HI))
	g.show_msg("NYSE: %s  %s %+d%%" % [headline, id, roundi(pct * 100.0)])

func claimed_nyc() -> int:
	if g.city.id != "nyc":
		return 0
	var n := 0
	for x in g.NX:
		for y in g.NY:
			n += int(g.territory.claimed(Vector2i(x, y)))
	return n

func cost(id: String, n: int) -> int:
	return ceili(price(id) * n)

func payout(id: String, n: int) -> int:
	return floori(price(id) * n * (1.0 - FEE))

## Returns shares bought (0 = can't afford / at the cap).
func buy(id: String, n: int) -> int:
	n = mini(n, MAX_HELD - held(id))
	if n <= 0 or not g.economy.spend_treats(cost(id, n)):
		return 0
	book("stocks/held")[id] = held(id) + n
	g.save_game()
	return n

func sell(id: String, n: int) -> int:
	n = mini(n, held(id))
	if n <= 0:
		return 0
	g.player.treats += payout(id, n)
	book("stocks/held")[id] = held(id) - n
	g.save_game()
	return n

## Market value of everything held, before the sell fee.
func value() -> int:
	var v := 0.0
	for id: String in TICKERS:
		v += price(id) * held(id)
	return roundi(v)

func is_open() -> bool:
	return app != null and app.is_open()

## P anywhere after the first terminal visit; the terminal (F) always works and marks the visit.
func toggle(at_terminal := false) -> void:
	if not is_open() and not at_terminal and not Story.has(VISITED):
		g.show_msg("Visit a terminal at the NYSE first")
		return
	if at_terminal:
		Story.set_flag(VISITED)
	if app == null:
		app = App.new()
		app.g = g
		app.s = self
		add_child(app)
		app.build()
	app.toggle()

## Scrolling ticker tape on the back wall (still with reduce motion) and the terminal desk.
func room_art() -> void:
	if is_instance_valid(art) and not art.is_queued_for_deletion():
		art.queue_redraw()
		return
	art = Node2D.new()
	art.position = g.interior.O
	art.z_index = -5
	art.draw.connect(func():
		var font := ThemeDB.fallback_font
		art.draw_rect(Rect2(0, 24, 1152, 34), Color(0.05, 0.05, 0.07))
		var tape := ""
		for id: String in TICKERS:
			var h := history(id)
			tape += "%s %.2f %s     " % [id, price(id), "+" if h.size() < 2 or h[-1] >= h[-2] else "-"]
		var w := font.get_string_size(tape, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var x := 0.0 if g.save_extra.get("ui/reduce_motion", false) else -fmod(Time.get_ticks_msec() * 0.06, w)
		while x < 1152.0:
			art.draw_string(font, Vector2(x, 48), tape, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.3, 1, 0.45))
			x += w
		var t: Vector2 = g.interior.spots.terminal - g.interior.O  # terminal desk with a green chart
		art.draw_rect(Rect2(t + Vector2(-60, -40), Vector2(120, 34)), Color(0.25, 0.2, 0.18))
		art.draw_rect(Rect2(t + Vector2(-26, -72), Vector2(52, 34)), Color(0.1, 0.12, 0.15))
		art.draw_polyline(PackedVector2Array([t + Vector2(-22, -44), t + Vector2(-10, -52), t + Vector2(2, -48), t + Vector2(22, -66)]), Color(0.3, 1, 0.45), 2.0))
	g.interior.room.add_child(art)
