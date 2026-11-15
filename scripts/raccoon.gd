extends Node2D
## Raccoon hiding in a trash can: pops out when the dog gets close, chases, bites.

enum State { HIDDEN, CHASE, RETURN }

var state := State.HIDDEN
var home := Vector2.ZERO
var chase_left := 0.0
var bite_cooldown := 0.0
var player: Node2D

const POP_DIST := 90.0
const CHASE_SPEED := 190.0
const CHASE_TIME := 4.0
const BITE_DIST := 22.0
const BITE_DAMAGE := 10.0

func setup(p_home: Vector2, tex: Texture2D, game: Node2D) -> void:
	home = p_home
	position = home
	player = game.get_node("Player")
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(2.5, 2.5)
	add_child(s)
	visible = false

func _process(delta: float) -> void:
	bite_cooldown = maxf(bite_cooldown - delta, 0.0)
	match state:
		State.HIDDEN:
			if player.position.distance_to(home) < POP_DIST:
				visible = true
				state = State.CHASE
				chase_left = CHASE_TIME
		State.CHASE:
			chase_left -= delta
			var to_player := player.position - position
			position += to_player.normalized() * CHASE_SPEED * delta
			get_child(0).flip_h = to_player.x < 0.0
			if to_player.length() < BITE_DIST and bite_cooldown <= 0.0:
				player.take_damage(BITE_DAMAGE)
				bite_cooldown = 1.0
			if chase_left <= 0.0:
				state = State.RETURN
		State.RETURN:
			var to_home := home - position
			if to_home.length() < 6.0:
				position = home
				visible = false
				state = State.HIDDEN
			else:
				position += to_home.normalized() * CHASE_SPEED * 0.7 * delta
