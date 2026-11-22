extends Node
## Weather: one roll per in-game day per city, 10 s blend between states, read-only
## modifiers for other systems, snow and rain visuals. Nothing else checks weather ids:
## read sprint_mult(), thirst_mult(), scent_range(), dash_slide(), sight_radius().

const BLEND := 10.0
const NO_LIMIT := 100000.0  # sight radius when nothing hides enemies
## ponytail: M2-2 moves these odds into the "weather table" field of data/cities.gd.
const ODDS := {
	"nyc": {"clear": 50, "snow": 30, "rain": 20},
	"sf": {"fog": 60, "clear": 30, "rain": 10},
	"tokyo": {"rain": 70, "clear": 30},
	"shenzhen": {"haze": 40, "clear": 40, "storm": 20},
}
## Gameplay modifiers per weather (spec 02 Weather; scent ranges from spec 01 Scent trail).
## dash_slide: dash distance multiplier (rain: +30%, steering halves, see dash_steer()).
const MODS := {
	"clear": {"sprint": 1.0, "thirst": 1.0, "scent": 1600.0, "dash": 1.0, "steer": 1.0, "sight": NO_LIMIT},
	"snow": {"sprint": 0.9, "thirst": 0.8, "scent": 1400.0, "dash": 1.0, "steer": 1.0, "sight": NO_LIMIT},
	"fog": {"sprint": 1.0, "thirst": 1.0, "scent": 900.0, "dash": 1.0, "steer": 1.0, "sight": 260.0},  # officers lose the dog past this
	"rain": {"sprint": 1.0, "thirst": 1.0, "scent": 700.0, "dash": 1.3, "steer": 0.5, "sight": NO_LIMIT},
	"haze": {"sprint": 1.0, "thirst": 1.3, "scent": 1600.0, "dash": 1.0, "steer": 1.0, "sight": NO_LIMIT},
	"storm": {"sprint": 1.0, "thirst": 1.0, "scent": 700.0, "dash": 1.3, "steer": 0.5, "sight": NO_LIMIT},
}
## Which particle look each weather uses; fog / haze / storm-lightning visuals ship with their cities.
const LOOK := {"snow": "snow", "rain": "rain", "storm": "rain", "fog": "fog"}
const FOG_FAR := 2400.0  # fog veil radius in px; past the view at any zoom
const SAY := {"clear": "The sky clears up.", "snow": "It's snowing!", "rain": "It's raining.",
	"fog": "Fog rolls in.", "haze": "A hot haze hangs over the city.", "storm": "A storm is coming!"}
const PRINT_EVERY := 28.0  # px walked between snow paw prints
const PRINT_LIFE := 8.0

var g: Node2D
var current := "clear"
var previous := "clear"
var blend_t := BLEND  # seconds since the last change; >= BLEND means fully blended
var started := false
var last_tod := 0.0
var snow: CPUParticles2D
var rain: CPUParticles2D
var fog: Sprite2D  # radial veil around the dog: clear inside sight_radius, white past it
var banks: CPUParticles2D  # slow fog banks rolling across the view
var last_print := Vector2.ZERO
var print_side := 1.0

func _ready() -> void:
	snow = _particles(_dot_tex(4), 300, 6.0, Vector2(20, 45), Vector2(-10, 0))
	snow.scale_amount_min = 1.0
	snow.scale_amount_max = 2.0
	snow.color = Color(1, 1, 1, 0.9)
	rain = _particles(_streak_tex(), 400, 0.9, Vector2(600, 900), Vector2(-60, 0))
	rain.particle_flag_align_y = true
	rain.color = Color(0.7, 0.8, 1.0, 0.55)
	var veil := Gradient.new()
	var clear: float = MODS.fog.sight / FOG_FAR
	veil.offsets = PackedFloat32Array([0.0, clear * 0.45, clear, 1.0])
	veil.colors = PackedColorArray([Color(0.86, 0.88, 0.92, 0.0), Color(0.86, 0.88, 0.92, 0.0), Color(0.86, 0.88, 0.92, 0.78), Color(0.86, 0.88, 0.92, 0.9)])
	var vt := GradientTexture2D.new()
	vt.gradient = veil
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.0, 0.5)
	vt.width = 512
	vt.height = 512
	fog = Sprite2D.new()
	fog.texture = vt
	fog.scale = Vector2.ONE * FOG_FAR * 2.0 / 512.0
	fog.z_index = 49
	fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # the project is pixel-art nearest; a stretched gradient must be smooth
	add_child(fog)
	var puff := Gradient.new()
	puff.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var pt := GradientTexture2D.new()
	pt.gradient = puff
	pt.fill = GradientTexture2D.FILL_RADIAL
	pt.fill_from = Vector2(0.5, 0.5)
	pt.fill_to = Vector2(1.0, 0.5)
	banks = _particles(pt, 36, 24.0, Vector2(12, 30), Vector2.ZERO)
	banks.direction = Vector2.RIGHT
	banks.spread = 15.0
	banks.scale_amount_min = 3.0
	banks.scale_amount_max = 6.0
	banks.color = Color(0.9, 0.92, 0.95, 0.22)
	banks.z_index = 49
	banks.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

## Weather starts once game._ready has loaded the save, so save_extra holds today's roll.
func _process(delta: float) -> void:
	if not started:
		started = true
		last_tod = g.tod
		var saved: String = g.save_extra.get("world/weather", {}).get(city(), "")
		set_weather(saved if saved in MODS else roll(city()), false)
	if g.tod < last_tod:  # the clock wrapped: a new day
		set_weather(roll(city()))
	last_tod = g.tod
	blend_t += delta
	_update_visuals()

func city() -> String:
	return str(g.save_extra.get("world/city", "nyc"))

## Weighted pick from the city's odds; unknown cities are always clear.
static func roll(city_id: String) -> String:
	var odds: Dictionary = ODDS.get(city_id, {"clear": 1})
	var total := 0
	for id: String in odds:
		total += int(odds[id])
	var r := randi() % total
	for id: String in odds:
		r -= int(odds[id])
		if r < 0:
			return id
	return "clear"

## Change weather; blend=false snaps (load, tests). Remembers today's weather in the save.
func set_weather(id: String, blend := true) -> void:
	assert(id in MODS, "unknown weather " + id)
	if blend and id != current:
		g.show_msg(SAY[id])
	previous = current if blend else id
	current = id
	blend_t = 0.0 if blend else BLEND
	var per_city: Dictionary = g.save_extra.get("world/weather", {}).duplicate()
	per_city[city()] = id
	g.save_extra["world/weather"] = per_city

## 0 = all previous weather, 1 = all current.
func blend() -> float:
	return clampf(blend_t / BLEND, 0.0, 1.0)

func _mod(key: String) -> float:
	return lerpf(float(MODS[previous][key]), float(MODS[current][key]), blend())

func sprint_mult() -> float:
	return _mod("sprint")

func thirst_mult() -> float:
	return _mod("thirst")

func scent_range() -> float:
	return _mod("scent")

func dash_slide() -> float:
	return _mod("dash")

func dash_steer() -> float:
	return _mod("steer")

func sight_radius() -> float:
	return _mod("sight")

## How strongly a particle look shows right now (0..1), following the blend.
func look(kind: String) -> float:
	var was := 1.0 if LOOK.get(previous, "") == kind else 0.0
	var now := 1.0 if LOOK.get(current, "") == kind else 0.0
	return lerpf(was, now, blend())

func _update_visuals() -> void:
	var outdoors: bool = g.inside == "" and not g.god_view
	var half: Vector2 = get_viewport().get_visible_rect().size / (2.0 * g.cam.zoom)
	for p: CPUParticles2D in [snow, rain, banks]:
		var k := look("snow" if p == snow else "rain" if p == rain else "fog")
		p.emitting = outdoors and k > 0.0
		p.visible = outdoors
		p.modulate.a = k
		p.position = g.cam.get_screen_center_position()  # emit over the whole view; drops stay in the world
		p.emission_rect_extents = half * 1.1
	fog.visible = outdoors and look("fog") > 0.0
	fog.modulate.a = look("fog")
	fog.position = g.player.position
	# snow whitens the ground, rain darkens it
	var s := look("snow")
	var r := look("rain")
	g.ground.modulate = Color.WHITE.lerp(Color(1.15, 1.17, 1.25), s).lerp(Color(0.78, 0.8, 0.9), r)
	if s > 0.5 and outdoors and g.player.position.distance_to(last_print) > PRINT_EVERY:
		_paw_print()

func _paw_print() -> void:
	var pl: Node2D = g.player
	last_print = pl.position
	if pl.velocity == Vector2.ZERO:
		return
	print_side = -print_side
	var dot := Sprite2D.new()
	dot.texture = snow.texture
	dot.modulate = Color(0.45, 0.5, 0.6, 0.6)
	dot.scale = Vector2(2.0, 1.4)
	dot.position = pl.position + Vector2(0, 14) + pl.velocity.normalized().orthogonal() * 5.0 * print_side
	dot.rotation = pl.velocity.angle()
	dot.z_index = -5
	g.add_child(dot)
	var tw := dot.create_tween()
	tw.tween_property(dot, "modulate:a", 0.0, PRINT_LIFE)
	tw.tween_callback(dot.queue_free)

func _particles(t: Texture2D, n: int, life: float, fall: Vector2, drift: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = t
	p.amount = n
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.z_index = 50
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2.DOWN
	p.spread = 8.0
	p.gravity = drift
	p.initial_velocity_min = fall.x
	p.initial_velocity_max = fall.y
	p.emitting = false
	add_child(p)
	return p

func _dot_tex(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			if Vector2(x - c, y - c).length() <= c + 0.5:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _streak_tex() -> ImageTexture:
	var img := Image.create(1, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		img.set_pixel(0, y, Color(1, 1, 1, y / 11.0))
	return ImageTexture.create_from_image(img)
