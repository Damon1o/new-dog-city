extends CharacterBody2D
## Dog player: top-down movement, survival stats, skins.

const SKIN_NAMES := ["Pug", "Husky", "Chihuahua", "Great Dane", "Mastiff"]
const SKIN_TINTS := [
	Color(0.87, 0.72, 0.5),   # Pug fawn
	Color(0.75, 0.8, 0.9),    # Husky silver
	Color(0.78, 0.55, 0.35),  # Chihuahua brown
	Color(0.45, 0.45, 0.5),   # Great Dane blue-gray
	Color(0.8, 0.65, 0.45),   # Mastiff apricot
]
# ideas.md: 15-20 mph. 1 px = ~1 cm, so ~250 px/s walk feels right at this scale.
const BASE_SPEED := 250.0

var hp := 100.0
var max_hp := 100.0
var hunger := 100.0
var thirst := 100.0
var level := 1
var xp := 0
var treats := 10
var skin := 0
var spawn_point := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	spawn_point = position
	apply_skin()

func _physics_process(delta: float) -> void:
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	var speed := BASE_SPEED + float(level) * 2.0
	velocity = dir.normalized() * speed if dir != Vector2.ZERO else Vector2.ZERO
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0
	move_and_slide()

	hunger = maxf(hunger - delta * 0.7, 0.0)
	thirst = maxf(thirst - delta * 1.0, 0.0)
	if hunger <= 0.0 or thirst <= 0.0:
		take_damage(delta * 4.0)
	elif hunger > 50.0 and thirst > 50.0 and hp < max_hp:
		hp = minf(hp + delta * 1.5, max_hp)  # well-fed dogs recover

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		die()

func die() -> void:
	treats = treats / 2
	hp = max_hp
	hunger = 60.0
	thirst = 60.0
	position = spawn_point

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed() and level < 100:
		xp -= xp_needed()
		level += 1
		max_hp += 2.0
		hp = max_hp

func xp_needed() -> int:
	return 20 + level * 10

func eat(hunger_gain: float, hp_gain: float) -> void:
	hunger = minf(hunger + hunger_gain, 100.0)
	hp = minf(hp + hp_gain, max_hp)

func drink(amount: float) -> void:
	thirst = minf(thirst + amount, 100.0)

func cycle_skin() -> void:
	skin = (skin + 1) % SKIN_NAMES.size()
	apply_skin()

func apply_skin() -> void:
	sprite.modulate = SKIN_TINTS[skin]

func skin_name() -> String:
	return SKIN_NAMES[skin]
