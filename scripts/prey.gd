extends Node2D
## Prey (pigeon / rat / squirrel): wanders, flees the dog, tires out, gets caught.
## Pigeons and parrots take wing while fresh and move as a flock (spawner.gd); squirrels escape
## up trees, gophers back down the hole they popped out of (home).

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
var flock := {}  # spawner.gd flock {members, center, scatter}; {} = on its own
var fleeing := false
var home := Vector2.ZERO  # gopher hole

## Pixel art for the SF critters that have no PNG (G = green, R = red, Y = yellow beak, E = eye,
## B = brown, T = tan belly). Cached per kind.
const ART := {
	"parrot": ["...RG...", "..GGEY..", ".GGGGY..", "GGGGG...", ".GGGG...", "..G.G..."],
	"gopher": ["..BBBB..", ".BEBBEB.", ".BBTTBB.", "BBTTTTBB", ".BTTTTB.", ".B....B."],
}
const ART_PAL := {"G": Color(0.3, 0.75, 0.3), "R": Color(0.85, 0.2, 0.2), "Y": Color(0.95, 0.8, 0.3),
	"E": Color(0.05, 0.05, 0.05), "B": Color(0.5, 0.35, 0.2), "T": Color(0.8, 0.65, 0.45)}
static var art_cache := {}

static func art(k: String) -> Texture2D:
	if not art_cache.has(k):
		var rows: Array = ART[k]
		var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				img.set_pixel(x, y, ART_PAL.get(rows[y][x], Color(0, 0, 0, 0)))
		art_cache[k] = ImageTexture.create_from_image(img)
	return art_cache[k]

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
	home = position

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
		elif kind == "gopher":
			if tired > 0.6 and position.distance_to(home) < 14.0:
				game.on_prey_escaped(self)
				return
			dir = (dir * 0.3 + position.direction_to(home)).normalized()
		vel = dir.rotated(randf_range(-0.3, 0.3)) * spd * (1.5 if fresh else 0.85)
	else:
		tired = maxf(tired - delta * 0.5, 0.0)
		retarget_in -= delta
		if retarget_in <= 0.0 or position.distance_to(target) < 8.0:
			retarget_in = randf_range(1.5, 4.0)
			var r := 80.0 if not flock.is_empty() else 150.0  # spec 07: flock birds stay within 80 px of the center
			target = (flock.center if not flock.is_empty() else position) + Vector2(randf_range(-r, r), randf_range(-r, r))
		vel = position.direction_to(target) * spd * 0.4
	var airborne := kind in ["pigeon", "parrot"] and fleeing and fresh
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
