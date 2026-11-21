extends Node2D
## Boss: sleeps at its lair, wakes when the dog gets close (or bites it), chases,
## and uses one special attack. Leashed to the lair: heals if the dog gets away
## or dies. Comes back RESPAWN seconds after being beaten.
## Optional cfg keys (spec 06, story bosses): `phases`, `aggro`, `leash`, and the
## one-time drops `bones`, `keycard`, `flag`, `shock`, `post` (see drop()).

enum State { IDLE, CHASE, WINDUP, CHARGE, SLAM, RETURN, DEAD, PARACHUTE }

const AGGRO := 230.0
const LEASH := 650.0   # dog this far from the lair = fight over
const REACH := 40.0
const RESPAWN := 180.0
const SLAM_R := 120.0
const SLAM_TIME := 0.9
const AIR_TIME := 1.2      # golden_parachute: shadow on the floor this long before he lands
const WAVE_SPEED := 380.0  # ticker_wave sweep, px/s
const TICKER := "PURR-40 KIBL+5 BARK-12 MEOW+8 "

const Levels := preload("res://scripts/systems/levels.gd")
const Raccoon := preload("res://scripts/raccoon.gd")

var cfg: Dictionary  # data/bosses.gd entry scaled to its level
var level := 1
var state := State.IDLE
var home := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var t := 0.0           # timer for the current state
var special_cd := 0.0
var special_n := 0     # cycles through the current special list
var phase := 0         # index into cfg.phases
var bite_cd := 0.0
var knock := Vector2.ZERO
var stun_t := 0.0
var charge_dir := Vector2.ZERO
var briefcase := false  # the current charge is a briefcase_charge
var shots: Array[Dictionary] = []  # {s, vel, t, homing}
var minions: Array[Node2D] = []    # margin_call security cats
var arena := Rect2()   # ticker_wave sweeps across this; set by the spawner (default: around home)
var wave_x := INF      # ticker_wave line x, INF = no wave
var wave_dir := 1.0
var game: Node2D
var player: CharacterBody2D
var sprite: Sprite2D
var coin_tex: Texture2D  # per boss: a static ref would leak at exit

func setup(p_cfg: Dictionary, p_home: Vector2, tex: Texture2D, p_game: Node2D) -> void:
	level = p_cfg.level
	cfg = Levels.scale_for_level(p_cfg, level)
	home = p_home
	position = home
	arena = Rect2(home - Vector2(560, 320), Vector2(1120, 640))
	game = p_game
	player = p_game.get_node("Player")
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(7, 7)
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	sprite.modulate = cfg.tint
	add_child(sprite)
	add_to_group("boss")

func _process(delta: float) -> void:
	if game.dialog.playing():  # boss intro / outro lines: everyone holds still
		return
	bite_cd = maxf(bite_cd - delta, 0.0)
	update_shots(delta)
	if not minions.is_empty():
		prune_minions()
	if wave_x != INF:
		update_wave(delta)
	queue_redraw()  # slam ring
	position += knock * delta
	knock = knock.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	if stun_t > 0.0:  # bark / pounce: frozen in place, timers paused
		stun_t -= delta
		return
	var was := position
	var to_player := player.position - position
	var d := to_player.length()
	var speed: float = cfg.speed * (float(cfg.phases[phase].get("speed_mult", 1.0)) if cfg.has("phases") else 1.0)
	match state:
		State.DEAD:
			t -= delta
			if t <= 0.0:
				position = home
				visible = true
				state = State.IDLE
		State.IDLE:
			if d < cfg.get("aggro", AGGRO):
				wake()
		State.RETURN:
			hp = minf(hp + max_hp * delta * 0.5, max_hp)
			if position.distance_to(home) < 8.0:
				position = home
				state = State.IDLE
			else:
				position += position.direction_to(home) * speed * 1.5 * delta
		State.CHASE:
			if player.position.distance_to(home) > cfg.get("leash", LEASH):
				state = State.RETURN
				clear_shots()
				game.on_boss_left(self)
				return
			if d > REACH * 0.6:
				position += to_player / d * speed * delta
			special_cd -= delta
			if special_cd <= 0.0:
				special(to_player / maxf(d, 1.0))
		State.WINDUP:  # telegraph before the charge
			t -= delta
			sprite.modulate = Color.WHITE if int(t * 16.0) % 2 == 0 else Color(cfg.tint)
			if t <= 0.0:
				sprite.modulate = cfg.tint
				charge_dir = to_player / maxf(d, 1.0)
				state = State.CHARGE
				t = 0.55
		State.CHARGE:
			t -= delta
			position += charge_dir * speed * 3.5 * delta
			if Engine.get_process_frames() % 3 == 0:  # dust trail
				game.poof(position, Color(0.6, 0.55, 0.5), 5, 60.0)
			if t <= 0.0:
				state = State.CHASE
		State.SLAM:  # stands still while the ring fills, then everything inside gets hit
			t -= delta
			if t <= 0.0:
				state = State.CHASE
				game.shake_amt = 10.0
				game.poof(position, cfg.tint)
				if d < SLAM_R:
					var dmg: float = cfg.dmg
					player.take_damage(dmg * 1.8)
		State.PARACHUTE:  # off screen; the shadow marks where he lands
			t -= delta
			sprite.position.y = -1000.0 * maxf(t, 0.0) / AIR_TIME
			if t <= 0.0:
				state = State.CHASE
				game.shake_amt = 10.0  # game.gd zeroes shake under ui/reduce_motion
				game.poof(position, cfg.tint, 30, 200.0)
				if d < SLAM_R:
					var dmg: float = cfg.dmg
					player.take_damage(dmg * 1.8)
				for i in 16:  # shockwave ring
					shoot(Vector2.RIGHT.rotated(TAU * i / 16.0) * 220.0, false, 2.0, coin())
	if absf(position.x - was.x) > 0.01:  # face where it's going (knockback excluded)
		sprite.flip_h = position.x < was.x
	if state in [State.CHASE, State.CHARGE] and d < REACH and bite_cd <= 0.0:
		var dmg: float = cfg.dmg
		player.take_damage(dmg * (2.0 if state == State.CHARGE else 1.0))
		bite_cd = 1.0

func wake() -> void:
	if state == State.IDLE:
		max_hp = cfg.hp
		hp = max_hp
		phase = 0
	state = State.CHASE
	special_cd = 2.0
	game.on_boss_woke(self)
	game.poof(position, cfg.tint, 24, 220.0)
	if cfg.has("intro") and not Story.has(cfg.intro):
		game.dialog.play(cfg.intro)
	if cfg.has("phases"):
		game.boss_name.text = "%s   Lv %d   %s" % [cfg.name, level, pips()]

func _draw() -> void:
	if state == State.SLAM:
		draw_circle(Vector2.ZERO, SLAM_R * (1.0 - t / SLAM_TIME), Color(1, 0.2, 0.2, 0.3))
		draw_arc(Vector2.ZERO, SLAM_R, 0, TAU, 48, Color(1, 0.3, 0.3), 3.0)
	if state == State.PARACHUTE:  # landing shadow, grows as he falls
		draw_circle(Vector2.ZERO, SLAM_R * (1.0 - t / AIR_TIME), Color(0, 0, 0, 0.35))
		draw_arc(Vector2.ZERO, SLAM_R, 0, TAU, 48, Color(1, 0.3, 0.3), 3.0)
	if briefcase and state in [State.WINDUP, State.CHARGE]:  # held out in front
		var x := -60.0 if sprite.flip_h else 32.0
		draw_rect(Rect2(x, -46, 28, 20), Color(0.35, 0.2, 0.1))
		draw_rect(Rect2(x + 9, -52, 10, 6), Color(0.2, 0.12, 0.06), false, 2.0)
	if wave_x != INF:  # ticker letters in a column across the floor
		var font := ThemeDB.fallback_font
		var i := 0
		for y in range(int(arena.position.y), int(arena.end.y), 20):
			var c := TICKER[i % TICKER.length()]
			var col := Color(1, 0.35, 0.3) if c == "-" or i % 14 < 7 else Color(0.35, 1, 0.45)
			draw_string(font, Vector2(wave_x, y + 16) - position, c, HORIZONTAL_ALIGNMENT_CENTER, 16, 16, col)
			i += 1

func specials() -> Array:
	return cfg.phases[phase].specials if cfg.has("phases") else cfg.specials

func special(dir: Vector2) -> void:
	special_n += 1
	var list := specials()
	match list[special_n % list.size()]:
		"slam":
			state = State.SLAM
			t = SLAM_TIME
			special_cd = 4.0
			game.float_text(position, "!", Color(1, 0.3, 0.3))
		"storm":  # feathers in every direction
			for i in 12:
				shoot(Vector2.RIGHT.rotated(TAU * i / 12.0) * 240.0, false, 2.5)
			special_cd = 3.0
		"burrow":  # digs under and pops up on the far side of the dog
			game.poof(position, cfg.tint)
			position = player.position + dir * 70.0
			game.poof(position, cfg.tint)
			bite_cd = 0.5  # a beat to react before it bites
			special_cd = 4.0
		"charge", "briefcase_charge":
			briefcase = list[special_n % list.size()] == "briefcase_charge"
			state = State.WINDUP
			t = 0.6
			special_cd = 4.0
			game.float_text(position, "!", Color(1, 0.3, 0.3))
		"feathers":  # fast straight fan
			for a in [-0.35, 0.0, 0.35]:
				shoot(dir.rotated(a) * 330.0, false, 3.0)
			special_cd = 2.5
		"rats":  # slow homing swarm
			for a in [-0.8, 0.0, 0.8]:
				shoot(dir.rotated(a) * 170.0, true, 4.0)
			special_cd = 5.0
		"coin_fan":  # 7 gold coins over 60 degrees
			for i in 7:
				shoot(dir.rotated(deg_to_rad(-30.0 + 10.0 * i)) * 300.0, false, 2.5, coin())
			special_cd = 2.5
		"margin_call":  # security cats (level 18), up to 3 at once
			game.float_text(position, "SECURITY!", Color(1, 0.3, 0.3))
			for i in 3 - minions.size():
				var cat: Node2D = Raccoon.new()
				get_parent().add_child(cat)  # the room, so they go when it does
				cat.setup(position + Vector2.RIGHT.rotated(TAU * i / 3.0) * 80.0, game.tex.cat, game)
				cat.level = 18
				cat.stats = Levels.scale_for_level(Raccoon.BASE, 18)
				cat.tag.label.text = "Security cat Lv 18"
				cat.max_hp = cat.stats.hp
				cat.hp = cat.max_hp
				cat.sprite.modulate = Color(0.45, 0.5, 0.65)
				cat.visible = true
				cat.state = Raccoon.State.CHASE
				cat.chase_left = 9999.0
				minions.append(cat)
			special_cd = 5.0
		"ticker_wave":  # a column of ticker letters sweeps the floor from the far side; dash through it
			wave_dir = 1.0 if player.position.x > arena.get_center().x else -1.0
			wave_x = arena.position.x if wave_dir > 0.0 else arena.end.x
			game.float_text(position, "SELL!", Color(1, 0.3, 0.3))
			special_cd = 4.0
		"golden_parachute":  # jumps off screen, lands where the dog stood
			game.poof(position, cfg.tint)
			position = player.position
			state = State.PARACHUTE
			t = AIR_TIME
			special_cd = 4.5

## Gold coin drawn in code, shared by every coin shot.
func coin() -> Texture2D:
	if not coin_tex:
		var img := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
		for x in 7:
			for y in 7:
				var r := Vector2(x - 3, y - 3).length()
				if r < 3.4:
					img.set_pixel(x, y, Color(0.75, 0.5, 0.1) if r > 2.3 else Color(1, 0.88, 0.3))
		coin_tex = ImageTexture.create_from_image(img)
	return coin_tex

func shoot(vel: Vector2, homing: bool, life: float, tex: Texture2D = null) -> void:
	var s := Sprite2D.new()
	s.texture = tex if tex else sprite.texture
	s.scale = Vector2(2, 2)
	s.modulate = Color.WHITE if tex else cfg.tint
	s.position = position
	game.add_child(s)  # world space, so shots don't follow the boss
	shots.append({"s": s, "vel": vel, "t": life, "homing": homing})

func update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var sh: Dictionary = shots[i]
		var s: Sprite2D = sh.s
		var vel: Vector2 = sh.vel
		if sh.homing:
			vel = s.position.direction_to(player.position) * vel.length()
		s.position += vel * delta
		s.flip_h = vel.x < 0.0
		sh.t -= delta
		var hit := s.position.distance_to(player.position) < 20.0
		if hit:
			var dmg: float = cfg.dmg
			player.take_damage(dmg * 0.6)
		if hit or sh.t <= 0.0:
			s.queue_free()
			shots.remove_at(i)

## The line hits once as it crosses the dog (a dash's i-frames let him through).
func update_wave(delta: float) -> void:
	var was := wave_x
	wave_x += wave_dir * WAVE_SPEED * delta
	if signf(was - player.position.x) != signf(wave_x - player.position.x):
		var dmg: float = cfg.dmg
		player.take_damage(dmg * 1.2)
	if wave_x < arena.position.x or wave_x > arena.end.x:
		wave_x = INF

func clear_shots() -> void:
	for sh in shots:
		sh.s.queue_free()
	shots.clear()
	wave_x = INF
	for m in minions:
		if is_instance_valid(m):
			m.queue_free()
	minions.clear()

## A beaten or bored security cat hides like a raccoon; summons just go.
func prune_minions() -> void:
	for i in range(minions.size() - 1, -1, -1):
		var m := minions[i]
		if not is_instance_valid(m) or m.state == Raccoon.State.HIDDEN:
			if is_instance_valid(m):
				m.queue_free()
			minions.remove_at(i)

## Bosses never flee a bark; within 4 levels they get the 0.5 s stun.
func scare(dog_level: int) -> void:
	if dog_level - level >= -4:
		stun(0.5)

func stun(time: float) -> void:
	if state != State.DEAD:
		stun_t = maxf(stun_t, time)

func hurt(dmg: float, from: Vector2, crit := false) -> void:
	if state in [State.DEAD, State.PARACHUTE]:
		return
	if state in [State.IDLE, State.RETURN]:
		wake()
	hp -= dmg
	knock = from.direction_to(position) * 120.0
	if state != State.WINDUP:  # windup owns the flash
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color(cfg.tint), 0.2)
	game.float_text(position, str(int(dmg)), Color.WHITE, crit)
	game.poof(position.move_toward(from, 30.0), Color(1, 0.85, 0.4) if crit else cfg.tint, 10, 160.0)  # hit sparks
	if hp <= 0.0:
		state = State.DEAD
		t = RESPAWN
		visible = false
		sprite.modulate = cfg.tint
		clear_shots()
		game.bump("park_boss_" + cfg.tex)  # Old Rex: "park_boss_raccoon"
		game.on_boss_beaten(self)
		if cfg.has("flag"):
			drop()
	elif cfg.has("phases"):
		next_phase()

## spec 06: below the next phase's `at` the boss swaps special lists, flashes and roars.
func next_phase() -> void:
	var ph: Array = cfg.phases
	var was := phase
	while phase + 1 < ph.size() and hp <= max_hp * float(ph[phase + 1].at):
		phase += 1
	if phase == was:
		return
	special_n = -1  # the new list starts at its first special
	special_cd = 1.0
	game.boss_name.text = "%s   Lv %d   %s" % [cfg.name, level, pips()]
	game.show_banner("%s  PHASE %d" % [str(cfg.name).to_upper(), phase + 1])
	game.float_text(position, "RAWR!", Color(1, 0.3, 0.3))
	game.poof(position, cfg.tint, 30, 200.0)
	game.sfx("bark")
	if not game.save_extra.get("ui/reduce_motion", false):
		sprite.modulate = Color.WHITE
		create_tween().tween_property(sprite, "modulate", Color(cfg.tint), 0.4)

## Phase pips for the HUD boss bar title: filled = phases reached.
func pips() -> String:
	return "*".repeat(phase + 1) + "-".repeat(cfg.phases.size() - phase - 1)

## Story boss drops (spec 06 / 09): bones, the city keycard, the PURR hit, the story flag,
## then the post-fight cutscene. Story bosses don't respawn.
func drop() -> void:
	game.economy.add_bones(cfg.get("bones", 0))
	if cfg.has("keycard"):
		Story.add_keycard(cfg.keycard)
	if cfg.has("shock"):
		game.stocks.shock(cfg.shock[0], cfg.shock[1], cfg.shock[2])
	game.float_text(position + Vector2(0, -40), "+%s keycard  +%d bones" % [str(cfg.get("keycard", "")).to_upper(), cfg.get("bones", 0)], Color(1, 0.85, 0.3))
	Story.set_flag(cfg.flag)
	if cfg.has("post"):
		game.dialog.play(cfg.post)
	queue_free()

func _exit_tree() -> void:  # a room boss goes with its room: drop the fight and its shots
	clear_shots()
	if game and game.boss == self:
		game.on_boss_left(self)
