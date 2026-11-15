extends Node2D
## Raccoon hiding in a trash can: pops out when the dog gets close, chases, bites.
## Has HP that scales with the dog's level; beat it for treats.

enum State { HIDDEN, CHASE, RETURN }

const POP_DIST := 90.0
const CHASE_SPEED := 190.0
const CHASE_TIME := 4.0
const BITE_DIST := 24.0

var state := State.HIDDEN
var home := Vector2.ZERO
var chase_left := 0.0
var bite_cooldown := 0.0
var hide_cooldown := 0.0
var hp := 0.0
var knock := Vector2.ZERO
var game: Node2D
var player: CharacterBody2D
var sprite: Sprite2D

func setup(p_home: Vector2, tex: Texture2D, p_game: Node2D) -> void:
	home = p_home
	position = home
	game = p_game
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
				hp = 24.0 + player.level * 4.0
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
				player.take_damage(8.0 + player.level * 0.3)
				bite_cooldown = 1.0
			if chase_left <= 0.0:
				state = State.RETURN
		State.RETURN:
			var to_home := home - position
			if to_home.length() < 6.0:
				go_home(0.0)
			else:
				position += to_home.normalized() * CHASE_SPEED * 0.7 * delta

func go_home(cooldown: float) -> void:
	position = home
	visible = false
	state = State.HIDDEN
	hide_cooldown = cooldown

func hurt(dmg: float, from: Vector2) -> void:
	if state == State.HIDDEN:
		return
	hp -= dmg
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
