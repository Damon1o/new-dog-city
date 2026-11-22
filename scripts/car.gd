extends Node2D
## Car: drives one lane end to end, wraps around the map, runs the dog over.
# ponytail: no braking, turning or traffic lights. Every car shares one speed so
# cars in a lane never meet; add steering/yielding if intersections need to matter.

const SPEED := 230.0
## half length / half width per body, car pointing +x. Also the hit box.
const HALF := {"sedan": Vector2(30, 14), "taxi": Vector2(30, 14), "hatch": Vector2(25, 13), "van": Vector2(36, 15), "bus": Vector2(56, 17)}
const KIND_ODDS := [["taxi", 0.3], ["sedan", 0.3], ["hatch", 0.2], ["van", 0.12], ["bus", 0.08]]
const BUS := Color(0.93, 0.94, 0.95)
const BUS_STRIPE := Color(0.1, 0.35, 0.75)
const PAINT := [Color(0.75, 0.77, 0.8), Color(0.12, 0.13, 0.15), Color(0.92, 0.92, 0.9), Color(0.72, 0.12, 0.12),
	Color(0.14, 0.24, 0.48), Color(0.2, 0.4, 0.28), Color(0.78, 0.7, 0.55), Color(0.3, 0.55, 0.75), Color(0.85, 0.45, 0.12)]
const TAXI := Color(1.0, 0.78, 0.1)
const GLASS := Color(0.16, 0.22, 0.32)
const TIRE := Color(0.07, 0.07, 0.08)

var dir := Vector2.RIGHT
var kind := "sedan"
var color := Color.WHITE
var hit_cd := 0.0
var game: Node2D
var player: CharacterBody2D

func setup(p_dir: Vector2, p_game: Node2D) -> void:
	dir = p_dir
	game = p_game
	player = p_game.get_node("Player")
	rotation = dir.angle()
	var r := randf()
	for k: Array in KIND_ODDS:
		r -= k[1]
		kind = k[0]
		if r < 0.0:
			break
	color = TAXI if kind == "taxi" else BUS if kind == "bus" else PAINT.pick_random()
	add_to_group("car")

func _process(delta: float) -> void:
	position += dir * SPEED * delta
	var world: Vector2 = game.WORLD
	position = Vector2(fposmod(position.x, world.x), fposmod(position.y, world.y))
	hit_cd -= delta
	var h: Vector2 = HALF[kind]
	var local := (player.position - position).rotated(-rotation)
	if hit_cd <= 0.0 and absf(local.x) < h.x + 6.0 and absf(local.y) < h.y + 6.0:
		hit_cd = 1.0
		game.on_car_hit(self)

## Rounded rectangle: two crossed rects plus four corner circles.
func rrect(r: Rect2, rad: float, c: Color) -> void:
	draw_rect(r.grow_individual(-rad, 0, -rad, 0), c)
	draw_rect(r.grow_individual(0, -rad, 0, -rad), c)
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		draw_circle(p + (r.get_center() - p).sign() * rad, rad, c)

func _draw() -> void:
	var h: Vector2 = HALF[kind]
	var body := Rect2(-h, h * 2.0)
	rrect(Rect2(body.position + Vector2(2, 4), body.size), 7, Color(0, 0, 0, 0.3))  # shadow
	for ax: float in [h.x * 0.58, -h.x * 0.58]:  # tyres poke out past the body
		draw_rect(Rect2(ax - 6, -h.y - 2, 12, 5), TIRE)
		draw_rect(Rect2(ax - 6, h.y - 3, 12, 5), TIRE)
	rrect(body, 7, color.darkened(0.4))  # outline
	rrect(body.grow(-1.5), 6, color)
	draw_rect(Rect2(-h.x + 7, -h.y + 2, h.x * 2 - 14, 2.5), color.lightened(0.3))  # sun glint on one flank
	if kind == "van":
		draw_van(h)
	elif kind == "bus":
		draw_bus(h)
	else:
		draw_cabin(h, -h.x + 4.0 if kind == "hatch" else -14.0, 8.0 if kind == "hatch" else 12.0)
	for s: float in [-1.0, 1.0]:
		draw_rect(Rect2(h.x - 3.5, s * (h.y - 5.5) - 2.5, 3, 5), Color(1, 0.96, 0.7))   # headlights
		draw_rect(Rect2(-h.x + 0.5, s * (h.y - 5.5) - 2.5, 2.5, 5), Color(0.9, 0.12, 0.12))  # tail lights

## Glass greenhouse from x=back to x=front, roof set rearward so the windshield reads bigger.
func draw_cabin(h: Vector2, back: float, front: float) -> void:
	rrect(Rect2(back, -h.y + 3, front - back, h.y * 2 - 6), 4, GLASS)
	var roof := Rect2(back + 4, -h.y + 4.5, front - back - 11, h.y * 2 - 9)
	rrect(roof, 3, color.lightened(0.12))
	draw_line(Vector2(front - 5, -h.y + 5), Vector2(front - 2, -h.y + 10), Color(1, 1, 1, 0.35), 1.5)  # windshield glare
	for s: float in [-1.0, 1.0]:
		draw_rect(Rect2(front - 3, s * (h.y + 0.5) - 1.5, 4, 3), color.darkened(0.25))  # mirrors
	if kind == "taxi":
		var c := roof.get_center()
		draw_rect(Rect2(c.x - 3, c.y - 6, 6, 12), Color(1, 1, 0.88))  # roof sign
		for i in range(int((front - back) / 4.0)):  # checker stripe down both sides
			for s: float in [-1.0, 1.0]:
				draw_rect(Rect2(back + i * 4, s * (h.y - 3.0) - 1.25, 4, 2.5), Color.BLACK if i % 2 else Color.WHITE)

## City bus: blue side stripes, wide windshield, roof AC unit and two escape hatches.
func draw_bus(h: Vector2) -> void:
	for s: float in [-1.0, 1.0]:
		draw_rect(Rect2(-h.x + 3, s * (h.y - 4) - 1.5, h.x * 2 - 6, 3), BUS_STRIPE)
		draw_rect(Rect2(h.x - 7, s * (h.y + 1) - 1.5, 4, 3), color.darkened(0.3))  # mirrors
	draw_rect(Rect2(h.x - 7, -h.y + 3, 4, h.y * 2 - 6), GLASS)
	rrect(Rect2(-14, -6, 24, 12), 2, color.darkened(0.15))  # AC unit
	for x: float in [20.0, -38.0]:
		draw_rect(Rect2(x, -4, 8, 8), color.darkened(0.25))

## Box van: short cab up front, cargo box with roof ribs behind it.
func draw_van(h: Vector2) -> void:
	var cab := h.x - 16.0
	draw_rect(Rect2(cab, -h.y + 3, 6, h.y * 2 - 6), GLASS)
	rrect(Rect2(-h.x + 2, -h.y + 2, cab + h.x - 4, h.y * 2 - 4), 3, color.lightened(0.1))
	for x in range(int(-h.x) + 10, int(cab) - 4, 9):
		draw_line(Vector2(x, -h.y + 3), Vector2(x, h.y - 3), color.darkened(0.15), 1.0)
	for s: float in [-1.0, 1.0]:
		draw_rect(Rect2(cab + 2, s * (h.y + 0.5) - 1.5, 4, 3), color.darkened(0.25))
