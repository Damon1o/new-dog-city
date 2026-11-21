extends Node2D
## Ranged bark: a sound wave that travels along the dog's facing, widening as it goes.
## Each foe it touches takes a light hit, then the spec-05 scare (flee / stun / ignore by level gap).

const SPEED := 650.0
const RANGE := 520.0
const R0 := 28.0  # hit radius at the muzzle
const R1 := 72.0  # hit radius at max range

var dir := Vector2.RIGHT
var dog_level := 1
var dmg := 0.0
var game: Node
var travelled := 0.0
var hit := {}  # instance id -> true, so a foe is hit once per bark

func radius() -> float:
	return lerpf(R0, R1, travelled / RANGE)

func _ready() -> void:
	rotation = dir.angle()
	z_index = 6
	add_to_group("bark")  # human.gd screams when one passes
	step()  # point-blank foes are hit on the frame of the bark

func _physics_process(delta: float) -> void:
	var d := minf(SPEED * delta, RANGE - travelled)
	position += dir * d
	travelled += d
	step()
	queue_redraw()
	if travelled >= RANGE:
		queue_free()

func step() -> void:
	var r := radius()
	for f in get_tree().get_nodes_in_group("raccoon") + get_tree().get_nodes_in_group("boss"):
		if hit.has(f.get_instance_id()) or f.position.distance_to(position) > r + (34.0 if f.is_in_group("boss") else 10.0):
			continue
		hit[f.get_instance_id()] = true
		if dmg > 0.0:
			f.hurt(dmg, position - dir * 40.0)
		f.scare(dog_level)  # after hurt, so a flee / stun wins over the hurt's chase
	if game and not hit.has(0) and game.hedgehog.pos.distance_to(position) < r + 20.0:
		hit[0] = true
		game.hedgehog.hurt(position, r + 20.0, dmg)

func _draw() -> void:
	var r := radius()
	var a := 1.0 - travelled / RANGE
	for k in 3:  # three nested arcs trailing back: ) ) )
		draw_arc(Vector2(-k * 14.0, 0), r * (0.55 + k * 0.25), -0.9, 0.9, 14,
			Color(1, 0.95, 0.75, a * (1.0 - k * 0.28)), 4.0 - k)
