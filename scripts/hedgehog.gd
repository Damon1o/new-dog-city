extends Node2D
## Boss Hedgehog: waits in its den and fights in three waves, each with its own moves.
##   wave 1  stalks the dog, firing aimed fans of quills
##   wave 2  holds the middle, firing quill rings that turn a notch every burst
##   wave 3  sprays a spiral, then curls up and rolls around the den shedding quills
## Sits at the world origin and draws everything (body + quills) in world space.

const WAVES := 3
const RADIUS := 34.0
# tuning knobs
const WAVE_HP := 100.0       # per wave, plus HP_PER_LEVEL * dog level
const HP_PER_LEVEL := 8.0
const WALK_SPEED := 70.0
const ROLL_SPEED := 430.0
const ROLL_TIME := 1.6
const REST_TIME := 2.2       # wave 3 spiral time between rolls
const WINDUP := 0.5          # tail end of the rest: shakes and shows the roll line

var game: Node2D
var player: CharacterBody2D
var room: Rect2
var pos := Vector2.ZERO
var wave := 0  # 0-based
var hp := 0.0
var max_hp := 1.0
var active := false
var quills: Array[Dictionary] = []  # {p, v}
var shot_cd := 0.0
var aim := 0.0       # ring / spiral firing angle
var pause := 0.0     # harmless, unhittable beat at the start of each wave
var rolling := false
var roll := Vector2.ZERO
var mode_t := 0.0    # wave 3: time left in the current roll or rest
var touch_cd := 0.0
var flash := 0.0

func setup(p_game: Node2D, p_room: Rect2) -> void:
	game = p_game
	player = p_game.get_node("Player")
	room = p_room
	z_index = 1
	hide()

func start() -> void:
	wave = 0
	max_hp = WAVE_HP + player.level * HP_PER_LEVEL
	hp = max_hp
	pos = room.get_center() - Vector2(0, 80)
	begin_wave()
	active = true
	show()

func stop() -> void:
	active = false
	quills.clear()
	hide()

func begin_wave() -> void:
	quills.clear()
	pause = 2.0
	shot_cd = 0.0
	rolling = false
	mode_t = REST_TIME
	game.show_banner("BOSS HEDGEHOG   WAVE %d" % (wave + 1))

func fire(angle: float, speed: float) -> void:
	var dir := Vector2.from_angle(angle)
	quills.append({"p": pos + dir * RADIUS, "v": dir * speed})

func _process(delta: float) -> void:
	if not active:
		return
	queue_redraw()
	flash = maxf(flash - delta, 0.0)
	touch_cd = maxf(touch_cd - delta, 0.0)
	var dmg: float = 8.0 + player.level * 0.3
	for i in range(quills.size() - 1, -1, -1):
		var q: Dictionary = quills[i]
		q.p += q.v * delta
		if not room.has_point(q.p):
			quills.remove_at(i)
		elif q.p.distance_to(player.position) < 16.0:
			quills.remove_at(i)
			player.take_damage(dmg)
			if not active:  # dog went down; the game already called stop()
				return
	if pause > 0.0:
		pause -= delta
		return

	shot_cd -= delta
	var to_dog := pos.angle_to_point(player.position)
	match wave:
		0:
			pos = pos.move_toward(player.position, WALK_SPEED * delta)
			if shot_cd <= 0.0:
				shot_cd = 1.1
				for a in [-0.3, 0.0, 0.3]:
					fire(to_dog + a, 230.0)
		1:
			pos = pos.move_toward(room.get_center(), WALK_SPEED * 2.0 * delta)
			if shot_cd <= 0.0:
				shot_cd = 0.9
				aim += 0.26  # half a gap: last burst's safe lanes are this burst's quills
				for k in 12:
					fire(aim + TAU * k / 12.0, 170.0)
		2:
			mode_t -= delta
			if rolling:
				pos += roll * delta
				if shot_cd <= 0.0:
					shot_cd = 0.14
					fire(roll.angle() + PI / 2, 140.0)
					fire(roll.angle() - PI / 2, 140.0)
				if mode_t <= 0.0:
					rolling = false
					mode_t = REST_TIME
			else:
				if shot_cd <= 0.0:
					shot_cd = 0.13
					aim += 0.45
					fire(aim, 190.0)
				if mode_t <= 0.0:
					rolling = true
					mode_t = ROLL_TIME
					roll = Vector2.from_angle(to_dog) * ROLL_SPEED
	var lo: Vector2 = room.position + Vector2(RADIUS, game.WALL_H + RADIUS)
	var hi := room.end - Vector2(RADIUS, RADIUS)
	if pos.x < lo.x or pos.x > hi.x:  # rolls bounce off the walls
		roll.x = -roll.x
	if pos.y < lo.y or pos.y > hi.y:
		roll.y = -roll.y
	pos = pos.clamp(lo, hi)

	if touch_cd <= 0.0 and pos.distance_to(player.position) < RADIUS + 10.0:
		touch_cd = 0.8
		player.take_damage(dmg * (2.5 if rolling else 1.5))

## Called for every dog bite; lands if the bite circle overlaps the body.
func hurt(center: Vector2, radius: float, dmg: float) -> void:
	if not active or pause > 0.0 or pos.distance_to(center) > radius + RADIUS:
		return
	hp -= dmg
	flash = 0.12
	game.float_text(pos, str(int(dmg)), Color.WHITE)
	if hp > 0.0:
		return
	wave += 1
	if wave >= WAVES:
		stop()
		game.on_hedgehog_beaten(pos)
	else:
		hp = max_hp
		begin_wave()

func _draw() -> void:
	for q in quills:
		var d: Vector2 = q.v.normalized()
		draw_line(q.p - d * 9.0, q.p + d * 9.0, Color(0.95, 0.9, 0.75), 3.0)
	var look := pos.direction_to(player.position)
	var winding := wave == 2 and not rolling and mode_t < WINDUP and pause <= 0.0
	var c := pos
	if winding:
		c += Vector2(randf_range(-2, 2), randf_range(-2, 2))
		draw_line(c, c + look * 500.0, Color(1, 0.1, 0.1, 0.22), RADIUS)
	var body := Color(0.45, 0.3, 0.18).lerp(Color(0.8, 0.2, 0.15), wave * 0.3)
	if flash > 0.0:
		body = Color.WHITE
	if pause > 0.0:  # blinks while it can't be hurt
		body.a = 0.45 + 0.35 * sin(Time.get_ticks_msec() / 60.0)
	var spin := Time.get_ticks_msec() / 60.0 if rolling else 0.0
	for i in 14:
		var dir := Vector2.from_angle(spin + TAU * i / 14.0)
		if rolling or dir.dot(look) < 0.45:  # spikes on the back, all round when curled up
			var side := dir.orthogonal() * 8.0
			draw_colored_polygon(PackedVector2Array([c + dir * RADIUS * 0.7 + side,
				c + dir * RADIUS * 0.7 - side, c + dir * (RADIUS + 16.0)]), Color(0.25, 0.17, 0.1, body.a))
	draw_circle(c, RADIUS, body)
	if not rolling:
		draw_circle(c + look * RADIUS * 0.6, RADIUS * 0.5, Color(0.85, 0.7, 0.55, body.a))
		draw_circle(c + look * RADIUS * 1.05, 5.0, Color.BLACK)
		for s in [-1.0, 1.0]:
			draw_circle(c + look * RADIUS * 0.5 + look.orthogonal() * 11.0 * s, 4.0,
				Color(0.9, 0.1, 0.1) if wave == 2 else Color.BLACK)
