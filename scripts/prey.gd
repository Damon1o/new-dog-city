extends Node2D
## Prey animal (pigeon / rat / squirrel): wanders, flees the dog, caught on contact.

var kind := "pigeon"
var speed := 120.0
var flee_dist := 140.0
var treat_reward := 2
var xp_reward := 10
var hunger_reward := 8.0

var game: Node2D
var player: Node2D
var target := Vector2.ZERO
var retarget_in := 0.0
var world_rect := Rect2()

func setup(p_kind: String, tex: Texture2D, p_speed: float, p_treats: int, p_xp: int, p_game: Node2D) -> void:
	kind = p_kind
	speed = p_speed
	treat_reward = p_treats
	xp_reward = p_xp
	game = p_game
	player = p_game.get_node("Player")
	world_rect = p_game.world_rect()
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(2.5, 2.5)
	add_child(s)
	target = position

func _process(delta: float) -> void:
	var to_player := player.position - position
	var d := to_player.length()
	if d < 20.0:
		game.on_prey_caught(self)
		return
	var dir := Vector2.ZERO
	if d < flee_dist:
		dir = -to_player.normalized()
		dir = (dir + Vector2(randf() - 0.5, randf() - 0.5) * 0.4).normalized()
		position += dir * speed * 1.4 * delta
	else:
		retarget_in -= delta
		if retarget_in <= 0.0 or position.distance_to(target) < 8.0:
			retarget_in = randf_range(1.5, 4.0)
			target = position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
			target = target.clamp(world_rect.position + Vector2(32, 32), world_rect.end - Vector2(32, 32))
		dir = (target - position).normalized()
		position += dir * speed * 0.4 * delta
	position = position.clamp(world_rect.position + Vector2(16, 16), world_rect.end - Vector2(16, 16))
	if dir.x != 0.0:
		get_child(0).flip_h = dir.x < 0.0
