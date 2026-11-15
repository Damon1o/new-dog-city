extends CharacterBody2D
## Dog player: movement, sprint, bite, survival stats, breeds, inventory.

signal leveled
signal died
signal hit

const PX_PER_MPH := 16.0  # ideas.md top speed 15-20 mph -> 240-320 px/s
const BREEDS := [
	{"name": "Pug", "file": "pug", "scale": 2.4, "mph": 15.0, "hp": 90.0, "atk": 8.0, "scare": 0.8},
	{"name": "Husky", "file": "husky", "scale": 3.0, "mph": 20.0, "hp": 100.0, "atk": 10.0, "scare": 1.0},
	{"name": "Chihuahua", "file": "chihuahua", "scale": 2.0, "mph": 17.0, "hp": 70.0, "atk": 6.0, "scare": 0.6},
	{"name": "Great Dane", "file": "great_dane", "scale": 3.8, "mph": 19.0, "hp": 130.0, "atk": 14.0, "scare": 1.3},
	{"name": "Mastiff", "file": "mastiff", "scale": 3.6, "mph": 15.0, "hp": 160.0, "atk": 18.0, "scare": 1.4},
]

var hp := 100.0
var max_hp: float:
	get: return float(BREEDS[skin].hp) + (level - 1) * 2.0
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0
var level := 1
var xp := 0
var treats := 10
var skin := 0
var purina := 0
var water := 0
var collar := ""  # ideas.md: Dog Collar [Name]

var spawn_point := Vector2.ZERO
var frozen := false  # true while typing the collar name
var winded := false
var sprinting := false  # read by the HUD
var attack_cd := 0.0
var facing := Vector2.RIGHT
var anim_t := 0.0
var name_tag: Label

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite.hframes = 2
	name_tag = Label.new()
	name_tag.position = Vector2(-60, -44)
	name_tag.size = Vector2(120, 16)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_tag.add_theme_font_size_override("font_size", 11)
	name_tag.add_theme_color_override("font_outline_color", Color.BLACK)
	name_tag.add_theme_constant_override("outline_size", 3)
	add_child(name_tag)
	apply_skin()

func breed() -> Dictionary:
	return BREEDS[skin]

func display_name() -> String:
	return ("%s the %s" % [collar, breed().name]) if collar != "" else str(breed().name)

func attack_damage() -> float:
	return float(breed().atk) + level * 0.5

func _physics_process(delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	var dir := Vector2.ZERO
	if not frozen:
		dir = Vector2(
			float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
			- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
			- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		).normalized()
	var weak := hunger < 20.0 or thirst < 20.0
	sprinting = dir != Vector2.ZERO and Input.is_key_pressed(KEY_SHIFT) and not winded
	var top: float = float(breed().mph) * PX_PER_MPH * (0.75 if weak else 1.0)
	velocity = dir * (top if sprinting else top * 0.6)
	if dir != Vector2.ZERO:
		facing = dir
		anim_t += delta * (14.0 if sprinting else 8.0)
		sprite.frame = int(anim_t) % 2
	else:
		sprite.frame = 0
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0
	move_and_slide()

	if sprinting:
		stamina = maxf(stamina - delta * 28.0, 0.0)
		winded = stamina <= 0.0
	else:
		stamina = minf(stamina + delta * (6.0 if weak else 16.0), 100.0)
		winded = winded and stamina < 25.0
	hunger = maxf(hunger - delta * 0.5, 0.0)
	thirst = maxf(thirst - delta * (1.4 if sprinting else 0.7), 0.0)
	if hunger <= 0.0 or thirst <= 0.0:
		take_damage(delta * 4.0)
	elif hunger > 50.0 and thirst > 50.0 and hp < max_hp:
		hp = minf(hp + delta * 1.5, max_hp)  # well-fed dogs recover

func bite() -> void:
	if attack_cd > 0.0 or frozen:
		return
	attack_cd = 0.45
	# ideas.md reaction speed: 60-100 ms between input and the bite landing
	await get_tree().create_timer(randf_range(0.06, 0.10)).timeout
	var tw := create_tween()
	tw.tween_property(sprite, "position", facing * 10.0, 0.05)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.1)
	get_parent().on_bite(position + facing * 26.0, 46.0, attack_damage())

func take_damage(amount: float) -> void:
	hp -= amount
	if amount >= 1.0:
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
		hit.emit()
	if hp <= 0.0:
		treats = treats / 2
		hp = max_hp
		hunger = 60.0
		thirst = 60.0
		stamina = 100.0
		position = spawn_point
		died.emit()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed() and level < 100:
		xp -= xp_needed()
		level += 1
		hp = max_hp
		leveled.emit()

func xp_needed() -> int:
	return 20 + level * 10

func eat(hunger_gain: float, hp_gain: float) -> void:
	hunger = minf(hunger + hunger_gain, 100.0)
	hp = minf(hp + hp_gain, max_hp)

func drink(amount: float) -> void:
	thirst = minf(thirst + amount, 100.0)

func use_purina() -> bool:
	if purina <= 0:
		return false
	purina -= 1
	eat(50.0, 40.0)
	return true

func use_water() -> bool:
	if water <= 0:
		return false
	water -= 1
	drink(60.0)
	return true

func cycle_skin() -> void:
	var ratio := hp / max_hp
	skin = (skin + 1) % BREEDS.size()
	hp = max_hp * ratio
	apply_skin()

func apply_skin() -> void:
	sprite.texture = load("res://assets/dog_%s.png" % breed().file)
	sprite.scale = Vector2.ONE * float(breed().scale)
	name_tag.text = collar
