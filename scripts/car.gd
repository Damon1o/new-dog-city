extends Node2D
## Car: drives one lane end to end, wraps around the map, runs the dog over.
# ponytail: no braking, turning or traffic lights. Every car shares one speed so
# cars in a lane never meet; add steering/yielding if intersections need to matter.

const SPEED := 230.0
const HALF := Vector2(30, 15)  # half length / half width, car pointing +x

var dir := Vector2.RIGHT
var color := Color.WHITE
var hit_cd := 0.0
var game: Node2D
var player: CharacterBody2D

func setup(p_dir: Vector2, p_game: Node2D) -> void:
	dir = p_dir
	game = p_game
	player = p_game.get_node("Player")
	rotation = dir.angle()
	color = Color.from_hsv(randf(), 0.6, 0.9)
	add_to_group("car")

func _process(delta: float) -> void:
	position += dir * SPEED * delta
	var world: Vector2 = game.WORLD
	position = Vector2(fposmod(position.x, world.x), fposmod(position.y, world.y))
	hit_cd -= delta
	var local := (player.position - position).rotated(-rotation)
	if hit_cd <= 0.0 and absf(local.x) < HALF.x + 6.0 and absf(local.y) < HALF.y + 6.0:
		hit_cd = 1.0
		game.on_car_hit(self)

func _draw() -> void:
	draw_rect(Rect2(-HALF, HALF * 2.0), color)
	draw_rect(Rect2(-12, -12, 22, 24), Color(0.15, 0.2, 0.3))  # cabin glass
	draw_rect(Rect2(-8, -12, 12, 24), color.darkened(0.2))     # roof
	for y in [-13.0, 7.0]:
		draw_rect(Rect2(26, y, 4, 6), Color(1, 0.95, 0.6))     # headlights
		draw_rect(Rect2(-30, y, 3, 6), Color(0.9, 0.15, 0.15)) # tail lights
