extends Node2D
## Daven the Hedgehog: waits in its den and fights in three waves, each with its own moves.
##   wave 1  stalks the dog, firing aimed fans of quills
##   wave 2  holds the middle, firing quill rings that turn a notch every burst
##   wave 3  sprays a double spiral, then curls up and rolls around the den shedding quills
## Every wave it keeps summoning hoglets (raccoon AI, hedgehog-brown) up to MINIONS[wave],
## and spikes burst from the floor after a red warning circle:
##   wave 1  under the dog and where it is running to
##   wave 2  a line racing from the hedgehog through the dog
##   wave 3  (resting only) a ring round the dog plus one under it: step out sideways
## Talks before the fight (once per save), at waves 2 and 3, and when beaten (once per save).
## Sits at the world origin and draws everything (body + quills) in world space.

const WAVES := 3
const RADIUS := 34.0
# tuning knobs
const Levels := preload("res://scripts/systems/levels.gd")
const Raccoon := preload("res://scripts/raccoon.gd")
const LEVEL := 15
const HARD := 5.0            # hp multiplier on top of BASE (the "5x harder" knob)
const BASE := {"hp": 100.0 * HARD, "dmg": 4.0}  # level 1; hp is per wave; dmg nerfed 8 -> 4
const WALK_SPEED := 85.0
const ROLL_SPEED := 480.0
const ROLL_TIME := 1.6
const REST_TIME := 1.8       # wave 3 spiral time between rolls
const WINDUP := 0.5          # tail end of the rest: shakes and shows the roll line
const MINIONS := [2, 3, 4]   # hoglets alive at once, per wave
const SUMMON_CD := 6.0
const SPIKE_R := 30.0
const SPIKE_WARN := 0.8      # red circle time before the spikes burst up
const SPIKE_UP := 0.45       # spikes stay up (drawn only; they hit once, as they burst)
const SPIKE_CD := [3.0, 3.5, 2.6]
var art: Texture2D = preload("res://assets/boss_hedgehog.png")  # tools/gen_bosses.py, faces right; per node: a const would leak at exit
const WAVE_LINES :=["", "You bite harder than you look. Hoglets, SURROUND it!", "ENOUGH! Curl up... and ROLL!"]

var level := LEVEL
var stats: Dictionary = Levels.scale_for_level(BASE, LEVEL)
var game: Node2D
var player: CharacterBody2D
var room: Rect2
var pos := Vector2.ZERO
var wave := 0  # 0-based
var hp := 0.0
var max_hp := 1.0
var active := false
var quills: Array[Dictionary] = []  # {p, v}
var minions: Array[Node2D] = []
var spikes: Array[Dictionary] = []  # {p, t}: t > 0 warning, t <= 0 up until -SPIKE_UP
var spike_cd := 0.0
var shot_cd := 0.0
var summon_cd := 0.0
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
	max_hp = stats.hp
	hp = max_hp
	pos = room.get_center() - Vector2(0, 80)
	begin_wave()
	active = true
	show()
	if not Story.has("cs_hedgehog_pre"):
		game.dialog.play("cs_hedgehog_pre")

func stop() -> void:
	active = false
	Sound.music("", Sound.BOSS)
	quills.clear()
	spikes.clear()
	clear_minions()
	hide()

func begin_wave() -> void:
	quills.clear()
	spikes.clear()
	clear_minions()
	if wave == WAVES - 1:  # the den plays battle 1 (Sound.ROOM_MUSIC "boss"); the last wave gets battle 2
		Sound.music("hedgehog_battle_2", Sound.BOSS)
	pause = 2.0
	shot_cd = 0.0
	spike_cd = 1.5
	summon_cd = 1.0
	rolling = false
	mode_t = REST_TIME
	game.show_banner("DAVEN THE HEDGEHOG   WAVE %d" % (wave + 1))
	if wave > 0:
		game.poof(pos, Color(0.9, 0.25, 0.15), 40, 260.0)
		game.shake_amt = 8.0
		game.dialog.play("hh_wave", [{"say": "Daven the Hedgehog", "text": WAVE_LINES[wave]}])

func fire(angle: float, speed: float) -> void:
	var dir := Vector2.from_angle(angle)
	quills.append({"p": pos + dir * RADIUS, "v": dir * speed})

## A spike patch at `p`, bursting after SPIKE_WARN (+ delay) seconds.
func spike(p: Vector2, delay := 0.0) -> void:
	spikes.append({"p": p.clamp(room.position + Vector2(0, game.WALL_H), room.end), "t": SPIKE_WARN + delay})

## This wave's spike pattern (see the header).
func spike_attack() -> void:
	match wave:
		0:
			spike(player.position)
			spike(player.position + player.velocity * 0.5, 0.15)
			spike(player.position + player.velocity * 0.9, 0.3)
		1:
			var dir := pos.direction_to(player.position)
			for i in 9:
				spike(pos + dir * (RADIUS + 30.0 + 50.0 * i), i * 0.06)
		2:
			spike(player.position)
			for i in 6:
				spike(player.position + Vector2.RIGHT.rotated(TAU * i / 6.0 + randf()) * 90.0, 0.1)

func update_spikes(delta: float) -> void:
	for i in range(spikes.size() - 1, -1, -1):
		var s: Dictionary = spikes[i]
		var was: float = s.t
		s.t -= delta
		if was > 0.0 and s.t <= 0.0:  # burst
			game.poof(s.p, Color(0.95, 0.9, 0.75), 10, 150.0)
			if s.p.distance_to(player.position) < SPIKE_R:
				player.take_damage(stats.dmg * 1.6)
				if not active:  # dog went down; the game already called stop()
					return
		if s.t < -SPIKE_UP:
			spikes.remove_at(i)

func clear_minions() -> void:
	for m in minions:
		if is_instance_valid(m):
			m.queue_free()
	minions.clear()

## Tops the hoglets back up to this wave's cap; beaten or bored ones hide, then go.
func summon() -> void:
	for i in range(minions.size() - 1, -1, -1):
		if not is_instance_valid(minions[i]) or minions[i].state == Raccoon.State.HIDDEN:
			if is_instance_valid(minions[i]):
				minions[i].queue_free()
			minions.remove_at(i)
	var n: int = MINIONS[wave] - minions.size()
	if n <= 0:
		return
	game.float_text(pos, "HOGLETS!", Color(1, 0.4, 0.2))
	for i in n:
		var at := (pos + Vector2.RIGHT.rotated(TAU * i / n + aim) * 70.0).clamp(
			room.position + Vector2(20, game.WALL_H + 20), room.end - Vector2(20, 20))
		var h: Node2D = Raccoon.new()
		game.add_child(h)
		h.setup(at, game.tex.rat, game)
		h.level = LEVEL
		h.stats = Levels.scale_for_level(Raccoon.BASE, LEVEL)
		h.tag.label.text = "Hoglet Lv %d" % LEVEL
		h.max_hp = h.stats.hp
		h.hp = h.max_hp
		h.sprite.modulate = Color(0.55, 0.38, 0.22)
		h.visible = true
		h.state = Raccoon.State.CHASE
		h.chase_left = 9999.0
		minions.append(h)
		game.poof(at, Color(0.55, 0.38, 0.22), 18, 150.0)

func _process(delta: float) -> void:
	if not active or game.dialog.playing():
		return
	queue_redraw()
	flash = maxf(flash - delta, 0.0)
	touch_cd = maxf(touch_cd - delta, 0.0)
	var dmg: float = stats.dmg
	for i in range(quills.size() - 1, -1, -1):
		var q: Dictionary = quills[i]
		q.p += q.v * delta
		if not room.has_point(q.p):
			quills.remove_at(i)
		elif q.p.distance_to(player.position) < 16.0:
			quills.remove_at(i)
			game.poof(q.p, Color(0.95, 0.9, 0.75), 6, 90.0)
			player.take_damage(dmg)
			if not active:  # dog went down; the game already called stop()
				return
	update_spikes(delta)
	if not active:
		return
	if pause > 0.0:
		pause -= delta
		return

	summon_cd -= delta
	if summon_cd <= 0.0:
		summon_cd = SUMMON_CD
		summon()
	spike_cd -= delta
	if spike_cd <= 0.0 and not rolling:
		spike_cd = SPIKE_CD[wave]
		spike_attack()
	shot_cd -= delta
	var to_dog := pos.angle_to_point(player.position)
	match wave:
		0:
			pos = pos.move_toward(player.position, WALK_SPEED * delta)
			if shot_cd <= 0.0:
				shot_cd = 0.8
				for a in [-0.5, -0.25, 0.0, 0.25, 0.5]:
					fire(to_dog + a, 250.0)
		1:
			pos = pos.move_toward(room.get_center(), WALK_SPEED * 2.0 * delta)
			if shot_cd <= 0.0:
				shot_cd = 0.7
				aim += 0.2  # half a gap: last burst's safe lanes are this burst's quills
				for k in 16:
					fire(aim + TAU * k / 16.0, 185.0)
		2:
			mode_t -= delta
			if rolling:
				pos += roll * delta
				if Engine.get_process_frames() % 3 == 0:  # dust trail
					game.poof(pos + Vector2(0, RADIUS * 0.6), Color(0.6, 0.55, 0.5), 5, 60.0)
				if shot_cd <= 0.0:
					shot_cd = 0.1
					fire(roll.angle() + PI / 2, 150.0)
					fire(roll.angle() - PI / 2, 150.0)
				if mode_t <= 0.0:
					rolling = false
					mode_t = REST_TIME
			else:
				if shot_cd <= 0.0:
					shot_cd = 0.1
					aim += 0.45
					fire(aim, 200.0)
					fire(aim + PI, 200.0)
				if mode_t <= 0.0:
					rolling = true
					mode_t = ROLL_TIME
					roll = Vector2.from_angle(to_dog) * ROLL_SPEED
	var lo: Vector2 = room.position + Vector2(RADIUS, game.WALL_H + RADIUS)
	var hi := room.end - Vector2(RADIUS, RADIUS)
	var bounced := false
	if pos.x < lo.x or pos.x > hi.x:  # rolls bounce off the walls
		roll.x = -roll.x
		bounced = true
	if pos.y < lo.y or pos.y > hi.y:
		roll.y = -roll.y
		bounced = true
	if bounced and rolling:
		game.poof(pos, Color(0.95, 0.9, 0.75), 12, 180.0)
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
	game.poof(pos.move_toward(center, RADIUS), Color(1, 0.85, 0.4), 10, 160.0)  # hit sparks
	if hp > 0.0:
		return
	wave += 1
	if wave >= WAVES:
		var at := pos
		stop()
		game.on_hedgehog_beaten(at)
		if not Story.has("cs_hedgehog_post"):
			game.dialog.play("cs_hedgehog_post")
	else:
		hp = max_hp
		begin_wave()

func _draw() -> void:
	for s in spikes:
		var p: Vector2 = s.p
		if s.t > 0.0:  # warning: ring fills in
			var k: float = 1.0 - s.t / (SPIKE_WARN + 0.5)
			draw_circle(p, SPIKE_R * clampf(k, 0.1, 1.0), Color(1, 0.2, 0.1, 0.25))
			draw_arc(p, SPIKE_R, 0, TAU, 24, Color(1, 0.3, 0.2, 0.7), 2.0)
		else:  # up: five quills out of the floor, sinking back
			var h: float = 30.0 * (1.0 + s.t / SPIKE_UP)
			draw_circle(p, SPIKE_R * 0.8, Color(0.2, 0.13, 0.08, 0.45))
			for j in 5:
				var x := p.x + (j - 2) * 9.0
				var y := p.y + (4.0 if j % 2 else 0.0)
				var tip: float = h * (0.7 if j % 2 else 1.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 4, y), Vector2(x + 4, y), Vector2(x, y - tip)]),
					Color(0.35, 0.24, 0.14))
				draw_line(Vector2(x, y - tip), Vector2(x, y - tip + 6.0), Color(0.95, 0.9, 0.75), 2.0)
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
	if not rolling:  # sprite art, turned toward the dog, redder each wave
		var mod := Color.WHITE.lerp(Color(1, 0.55, 0.5), wave * 0.4)
		if flash > 0.0:
			mod = Color(2, 2, 2)
		mod.a = body.a
		draw_set_transform(c - Vector2(0, 10), 0.0, Vector2(-2.0 if look.x < 0.0 else 2.0, 2.0))
		draw_texture(art, -art.get_size() / 2.0, mod)
		draw_set_transform(Vector2.ZERO)
		return
	var spin := Time.get_ticks_msec() / 60.0
	for i in 14:  # curled up: spikes all round
		var dir := Vector2.from_angle(spin + TAU * i / 14.0)
		var side := dir.orthogonal() * 8.0
		draw_colored_polygon(PackedVector2Array([c + dir * RADIUS * 0.7 + side,
			c + dir * RADIUS * 0.7 - side, c + dir * (RADIUS + 16.0)]), Color(0.25, 0.17, 0.1, body.a))
	draw_circle(c, RADIUS, body)
