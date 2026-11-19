extends Node2D
## Raccoon hiding in a trash can: pops out when the dog gets close, chases, bites.
## Has a level from where its can sits (systems/levels.gd); beat it for treats.

enum State { HIDDEN, CHASE, WINDUP, LUNGE, RETURN, FLEE, STUN }

const POP_DIST := 90.0
const CHASE_SPEED := 190.0
const CHASE_TIME := 4.0
const BITE_DIST := 24.0
const BASE := {"hp": 28.0, "dmg": 8.0, "xp": 21, "treats": 3}  # level 1
const Levels := preload("res://scripts/systems/levels.gd")

var state := State.HIDDEN
var home := Vector2.ZERO
var chase_left := 0.0
var bite_cooldown := 0.0
var hide_cooldown := 0.0
var special_cd := 0.0
var t := 0.0  # windup / lunge timer
var lunge_dir := Vector2.ZERO
var level := 1
var stats: Dictionary = BASE  # BASE scaled to level
var hp := 0.0
var max_hp := 1.0
var knock := Vector2.ZERO
var game: Node2D
var player: CharacterBody2D
var sprite: Sprite2D

func setup(p_home: Vector2, tex: Texture2D, p_game: Node2D) -> void:
	home = p_home
	position = home
	game = p_game
	level = Levels.level_at(home, p_game.WORLD)
	stats = Levels.scale_for_level(BASE, level)
	player = p_game.get_node("Player")
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(2.5, 2.5)
	add_child(sprite)
	add_to_group("raccoon")
	visible = false

func _process(delta: float) -> void:
	bite_cooldown = maxf(bite_cooldown - delta, 0.0)
	hide_cooldown = maxf(hide_cooldown - delta, 0.0)
	if state != State.HIDDEN:
		position += knock * delta
		knock = knock.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	match state:
		State.HIDDEN:
			if hide_cooldown <= 0.0 and player.position.distance_to(home) < POP_DIST:
				max_hp = stats.hp
				hp = max_hp
				queue_redraw()
				visible = true
				state = State.CHASE
				chase_left = CHASE_TIME
				game.float_text(home, "!", Color(1, 0.3, 0.3))
		State.CHASE:
			chase_left -= delta
			var to_player := player.position - position
			position += to_player.normalized() * CHASE_SPEED * delta
			sprite.flip_h = to_player.x < 0.0
			if to_player.length() < BITE_DIST and bite_cooldown <= 0.0:
				player.take_damage(stats.dmg)
				bite_cooldown = 1.0
			special_cd -= delta
			if special_cd <= 0.0 and to_player.length() > 50.0 and to_player.length() < 170.0:
				state = State.WINDUP  # special: pounce at a dog that keeps its distance
				t = 0.4
				special_cd = 3.0
			if chase_left <= 0.0:
				state = State.RETURN
		State.WINDUP:  # flashes in place; a bite interrupts it (see hurt)
			t -= delta
			sprite.modulate = Color.WHITE if int(t * 20.0) % 2 == 0 else Color(1, 0.5, 0.2)
			if t <= 0.0:
				sprite.modulate = Color.WHITE
				lunge_dir = position.direction_to(player.position)
				state = State.LUNGE
				t = 0.3
		State.LUNGE:
			t -= delta
			position += lunge_dir * CHASE_SPEED * 3.2 * delta
			if position.distance_to(player.position) < BITE_DIST + 6.0 and bite_cooldown <= 0.0:
				player.take_damage(stats.dmg * 1.5)
				bite_cooldown = 1.0
			if t <= 0.0:
				state = State.CHASE
		State.FLEE:  # scared by a bark: run from the dog, then go home
			t -= delta
			position += player.position.direction_to(position) * CHASE_SPEED * delta
			if t <= 0.0:
				state = State.RETURN
		State.STUN:
			t -= delta
			if t <= 0.0:
				state = State.CHASE
				chase_left = CHASE_TIME
		State.RETURN:
			var to_home := home - position
			if to_home.length() < 6.0:
				go_home(0.0)
			else:
				position += to_home.normalized() * CHASE_SPEED * 0.7 * delta

func _draw() -> void:  # health bar over the head; node is only visible out of the can
	draw_rect(Rect2(-19, -31, 38, 6), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-18, -30, 36.0 * clampf(hp / max_hp, 0.0, 1.0), 4), Color(0.9, 0.2, 0.2))

func go_home(cooldown: float) -> void:
	position = home
	visible = false
	state = State.HIDDEN
	hide_cooldown = cooldown

## Bark (spec 05): flee 4 s if the dog is 5+ levels above, stun 0.5 s within 4 levels, else ignore.
func scare(dog_level: int) -> void:
	var gap := dog_level - level
	if state == State.HIDDEN:
		return
	if gap >= 5:
		stun(4.0)
		state = State.FLEE
	elif gap >= -4:
		stun(0.5)

func stun(time: float) -> void:
	if state == State.HIDDEN:
		return
	sprite.modulate = Color.WHITE  # a stunned windup must not stay orange
	state = State.STUN
	t = time

func hurt(dmg: float, from: Vector2) -> void:
	if state == State.HIDDEN:
		return
	hp -= dmg
	queue_redraw()
	knock = from.direction_to(position) * 260.0
	sprite.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	game.float_text(position, str(int(dmg)), Color.WHITE)
	if hp <= 0.0:
		game.on_raccoon_beaten(self)
		go_home(25.0)
	else:
		state = State.CHASE  # hitting it keeps it angry
		chase_left = CHASE_TIME
