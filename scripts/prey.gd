extends Node2D
## Prey (pigeon / rat / squirrel): wanders, flees the dog, tires out, gets caught.
## Pigeons take wing while fresh; squirrels escape up trees.

const Levels := preload("res://scripts/systems/levels.gd")

var kind := "pigeon"
var level := 1
var cfg: Dictionary
var game: Node2D
var player: CharacterBody2D
var sprite: Sprite2D
var target := Vector2.ZERO
var retarget_in := 0.0
var tired := 0.0

func setup(p_kind: String, p_cfg: Dictionary, tex: Texture2D, p_game: Node2D) -> void:
	kind = p_kind
	level = Levels.level_at(position, p_game.WORLD)
	cfg = Levels.scale_for_level(p_cfg, level)  # treats and xp
	game = p_game
	player = p_game.get_node("Player")
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(2.5, 2.5)
	add_child(sprite)
	add_to_group("prey")
	target = position

func _process(delta: float) -> void:
	var to_player := player.position - position
	var d := to_player.length()
	if d < 22.0:
		game.on_prey_caught(self)
		return
	var spd: float = cfg.speed
	var flee_dist: float = float(cfg.flee) * float(player.breed().scare)
	var fleeing := d < flee_dist
	var fresh := tired < 2.5
	var vel := Vector2.ZERO
	if fleeing:
		tired = minf(tired + delta, 6.0)
		var dir := -to_player / d
		if kind == "squirrel":
			var tree: Vector2 = game.nearest_tree(position)
			if position.distance_to(tree) < 14.0:
				game.on_prey_escaped(self)
				return
			if tree.distance_to(player.position) > position.distance_to(tree):
				dir = (dir * 0.4 + position.direction_to(tree)).normalized()
		vel = dir.rotated(randf_range(-0.3, 0.3)) * spd * (1.5 if fresh else 0.85)
	else:
		tired = maxf(tired - delta * 0.5, 0.0)
		retarget_in -= delta
		if retarget_in <= 0.0 or position.distance_to(target) < 8.0:
			retarget_in = randf_range(1.5, 4.0)
			target = position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		vel = position.direction_to(target) * spd * 0.4
	var airborne := kind == "pigeon" and fleeing and fresh
	sprite.position.y = lerpf(sprite.position.y, -16.0 if airborne else 0.0, delta * 10.0)
	var step := vel * delta
	if not game.blocked(position + step):
		position += step
	elif not game.blocked(position + Vector2(step.x, 0)):
		position.x += step.x
	elif not game.blocked(position + Vector2(0, step.y)):
		position.y += step.y
	else:
		retarget_in = 0.0
	var world: Vector2 = game.WORLD
	position = position.clamp(Vector2(16, 16), world - Vector2(16, 16))
	if vel.x != 0.0:
		sprite.flip_h = vel.x < 0.0
