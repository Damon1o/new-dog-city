extends Node2D
## Boss: sleeps at its lair, wakes when the dog gets close (or bites it), chases,
## and uses one special attack. Leashed to the lair: heals if the dog gets away
## or dies. Comes back RESPAWN seconds after being beaten.

enum State { IDLE, CHASE, WINDUP, CHARGE, SLAM, RETURN, DEAD }

const AGGRO := 230.0
const LEASH := 650.0   # dog this far from the lair = fight over
const REACH := 40.0
const RESPAWN := 180.0
const SLAM_R := 120.0
const SLAM_TIME := 0.9

const Levels := preload("res://scripts/systems/levels.gd")

var cfg: Dictionary  # data/bosses.gd entry scaled to its level
var level := 1
var state := State.IDLE
var home := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var t := 0.0           # timer for the current state
var special_cd := 0.0
var special_n := 0     # cycles through cfg.specials
var bite_cd := 0.0
var knock := Vector2.ZERO
var stun_t := 0.0
var charge_dir := Vector2.ZERO
var shots: Array[Dictionary] = []  # {s, vel, t, homing}
var game: Node2D
var player: CharacterBody2D
var sprite: Sprite2D

func setup(p_cfg: Dictionary, p_home: Vector2, tex: Texture2D, p_game: Node2D) -> void:
	level = p_cfg.level
	cfg = Levels.scale_for_level(p_cfg, level)
	home = p_home
	position = home
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
	bite_cd = maxf(bite_cd - delta, 0.0)
	update_shots(delta)
	queue_redraw()  # slam ring
	position += knock * delta
	knock = knock.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	if stun_t > 0.0:  # bark / pounce: frozen in place, timers paused
		stun_t -= delta
		return
	var to_player := player.position - position
	var d := to_player.length()
	var speed: float = cfg.speed
	match state:
		State.DEAD:
			t -= delta
			if t <= 0.0:
				position = home
				visible = true
				state = State.IDLE
		State.IDLE:
			if d < AGGRO:
				wake()
		State.RETURN:
			hp = minf(hp + max_hp * delta * 0.5, max_hp)
			if position.distance_to(home) < 8.0:
				position = home
				state = State.IDLE
			else:
				position += position.direction_to(home) * speed * 1.5 * delta
		State.CHASE:
			if player.position.distance_to(home) > LEASH:
				state = State.RETURN
				clear_shots()
				game.on_boss_left(self)
				return
			if d > REACH * 0.6:
				position += to_player / d * speed * delta
			sprite.flip_h = to_player.x < 0.0
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
	if state in [State.CHASE, State.CHARGE] and d < REACH and bite_cd <= 0.0:
		var dmg: float = cfg.dmg
		player.take_damage(dmg * (2.0 if state == State.CHARGE else 1.0))
		bite_cd = 1.0

func wake() -> void:
	if state == State.IDLE:
		max_hp = cfg.hp
		hp = max_hp
	state = State.CHASE
	special_cd = 2.0
	game.on_boss_woke(self)

func _draw() -> void:
	if state == State.SLAM:
		draw_circle(Vector2.ZERO, SLAM_R * (1.0 - t / SLAM_TIME), Color(1, 0.2, 0.2, 0.3))
		draw_arc(Vector2.ZERO, SLAM_R, 0, TAU, 48, Color(1, 0.3, 0.3), 3.0)

func special(dir: Vector2) -> void:
	special_n += 1
	match cfg.specials[special_n % cfg.specials.size()]:
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
		"charge":
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

func shoot(vel: Vector2, homing: bool, life: float) -> void:
	var s := Sprite2D.new()
	s.texture = sprite.texture
	s.scale = Vector2(2, 2)
	s.modulate = cfg.tint
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

func clear_shots() -> void:
	for sh in shots:
		sh.s.queue_free()
	shots.clear()

## Bosses never flee a bark; within 4 levels they get the 0.5 s stun.
func scare(dog_level: int) -> void:
	if dog_level - level >= -4:
		stun(0.5)

func stun(time: float) -> void:
	if state != State.DEAD:
		stun_t = maxf(stun_t, time)

func hurt(dmg: float, from: Vector2, crit := false) -> void:
	if state == State.DEAD:
		return
	if state in [State.IDLE, State.RETURN]:
		wake()
	hp -= dmg
	knock = from.direction_to(position) * 120.0
	if state != State.WINDUP:  # windup owns the flash
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color(cfg.tint), 0.2)
	game.float_text(position, str(int(dmg)), Color.WHITE, crit)
	if hp <= 0.0:
		state = State.DEAD
		t = RESPAWN
		visible = false
		sprite.modulate = cfg.tint
		clear_shots()
		game.bump("park_boss_" + cfg.tex)  # Old Rex: "park_boss_raccoon"
		game.on_boss_beaten(self)
