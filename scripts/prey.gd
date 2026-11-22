extends Node2D
## Prey (pigeon / rat / squirrel): wanders, flees the dog, tires out, gets caught.
## Pigeons take wing while fresh and move as a flock (spawner.gd); squirrels escape up trees.

const Levels := preload("res://scripts/systems/levels.gd")
const Anim := preload("res://scripts/world/anim.gd")

var kind := "pigeon"
var level := 1
var cfg: Dictionary
var game: Node2D
var player: CharacterBody2D
var sprite: Sprite2D
var target := Vector2.ZERO
var retarget_in := 0.0
var tired := 0.0
var flock := {}  # spawner.gd flock {members, center, scatter}; {} = on its own
var fleeing := false
var walk := 0.0  # world/anim.gd hop clock
var fly_y := 0.0

func setup(p_kind: String, p_cfg: Dictionary, tex: Texture2D, p_game: Node2D, bonus := 0) -> void:
	kind = p_kind
	level = Levels.level_at(position, p_game.WORLD) + bonus  # bonus: night +2 (spec 06)
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
	if d < flee_dist and not flock.is_empty():
		game.spawner.scatter(flock)  # one bird spooked, the whole flock goes
	var scattered: bool = not flock.is_empty() and flock.scatter > 0.0
	fleeing = d < flee_dist or (scattered and d < flee_dist * 4.0)
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
			var r := 80.0 if not flock.is_empty() else 150.0  # spec 07: flock birds stay within 80 px of the center
			target = (flock.center if not flock.is_empty() else position) + Vector2(randf_range(-r, r), randf_range(-r, r))
		vel = position.direction_to(target) * spd * 0.4
	var airborne := kind == "pigeon" and fleeing and fresh
	fly_y = lerpf(fly_y, -16.0 if airborne else 0.0, delta * 10.0)
	walk = walk + delta * (1.6 if fleeing else 1.0) if vel != Vector2.ZERO and not airborne else 0.0
	Anim.pose(sprite, Vector2(2.5, 2.5), walk, 0.0, 0.0, Vector2.ZERO, false, fly_y)
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
