extends CharacterBody2D
## Dog player: movement, sprint, bite, survival stats, breeds, inventory.

signal leveled
signal died
signal hit

const XP := preload("res://scripts/systems/xp.gd")
const Items := preload("res://scripts/data/items.gd")
const Wardrobe := preload("res://scripts/data/wardrobe.gd")
const PX_PER_MPH := 16.0  # ideas.md top speed 15-20 mph -> 240-320 px/s
const BREEDS := [
	{"name": "Pug", "file": "pug", "scale": 2.4, "mph": 15.0, "hp": 90.0, "atk": 8.0, "scare": 0.8},
	{"name": "Husky", "file": "husky", "scale": 3.0, "mph": 20.0, "hp": 100.0, "atk": 10.0, "scare": 1.0},
	{"name": "Chihuahua", "file": "chihuahua", "scale": 2.0, "mph": 17.0, "hp": 70.0, "atk": 6.0, "scare": 0.6},
	{"name": "Great Dane", "file": "great_dane", "scale": 3.8, "mph": 19.0, "hp": 130.0, "atk": 14.0, "scare": 1.3},
	{"name": "Mastiff", "file": "mastiff", "scale": 3.6, "mph": 15.0, "hp": 160.0, "atk": 18.0, "scare": 1.4},
]

# spec 05: dash (C) = 220 px along `facing` over 0.15 s, invulnerable, 25 stamina, 1.2 s cooldown
const DASH_PX := 220.0
const DASH_TIME := 0.15
const DASH_CD := 1.2
const DASH_COST := 25.0
# spec 05: bark (R) = ranged sound wave (bark_wave.gd, 520 px), 15 stamina, 6 s; pounce = hold Space 0.6 s, level 30, 160 px leap, 2x bite + 0.8 s stun
const BarkWave := preload("res://scripts/bark_wave.gd")
const BARK_DMG := 0.4  # x bite damage per wave hit
const BARK_CD := 6.0
const BARK_COST := 15.0
const POUNCE_LEVEL := 30
const POUNCE_HOLD := 0.6
const POUNCE_PX := 160.0
const POUNCE_TIME := 0.3
const POUNCE_CD := 4.0
const POUNCE_COST := 30.0
# specials: crunch bite (Q, level 5) = 2.5x bite + 0.6 s stun; tail whip (T, level 12) =
# spin hitting everything within 80 px for 1.2x bite, knocking foes twice as far
const CRUNCH_LEVEL := 5
const CRUNCH_DMG := 2.5
const CRUNCH_CD := 5.0
const CRUNCH_COST := 20.0
const TAIL_LEVEL := 12
const TAIL_DMG := 1.2
const TAIL_RADIUS := 80.0
const TAIL_CD := 7.0
const TAIL_COST := 25.0
const UNLOCK := {"pounce": POUNCE_LEVEL, "crunch": CRUNCH_LEVEL, "tail": TAIL_LEVEL}  # hud hides locked ones

## [var, label, gain per point]. 3 points per level, so each is a third of the old 10 HP / 2 bite / 1 mph.
const STATS := [["stat_hp", "Max HP", 3.0], ["stat_atk", "Bite", 0.6], ["stat_spd", "Speed (mph)", 0.3]]
const MAX_ARMOR := 0.5  # armor never cuts more than half a hit
const POISON_TIME := 4.0  # a poisoned hit (data/bosses.gd "poison") ticks once a second this long
const POISON_COL := Color(0.55, 1, 0.45)

var points := 0  # unspent stat points, 3 per level; spent in the bag's STATS panel
var stat_hp := 0
var stat_atk := 0
var stat_spd := 0
var hp := 100.0
var max_hp: float:
	get: return float(BREEDS[skin].hp) + (level - 1) * 2.0 + stat_hp * STATS[0][2]
var hunger := 100.0
var thirst := 100.0
var buffs := {}  # "food" / "drink" -> {id, t (s left), mods}; not saved, they last 1-2 min
var stamina := 100.0
var poison_t := 0.0    # seconds of poison left; another poisoned hit refreshes it
var poison_dps := 0.0
var poison_tick := 0.0
var level := 1
var xp := 0
var treats := 10
var skin := 0
var purina := 0
var water := 0
var collar := ""  # ideas.md: Dog Collar [Name]
var armor := "":  # worn armor id (data/items.gd ARMOR), "" = none; drawn on the dog
	set(v):
		armor = v
		if sprite:
			apply_skin()
var armor_owned: Array = []
var bag := {}  # carried shop food / drinks beyond purina + water: id -> count

var spawn_point := Vector2.ZERO
var frozen := false  # true while typing the collar name
var dead := false    # death screen is up (or the dog is mid-air off a train)
var winded := false
var sprinting := false  # read by the HUD
var attack_cd := 0.0
var dash_t := 0.0   # dash time left; > 0 means mid-dash and invulnerable
var dash_cd := 0.0  # read by the ability bar (M1-7)
var bark_cd := 0.0
var pounce_cd := 0.0
var pounce_t := 0.0  # leap time left
var crunch_cd := 0.0
var tail_cd := 0.0
var space_t := 0.0   # how long Space has been held
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
	return (float(breed().atk) + level * 0.5 + stat_atk * STATS[1][2]) * mod("damage")

func top_mph() -> float:
	return float(breed().mph) + stat_spd * STATS[2][2]

## Fraction of each hit the worn armor soaks up.
func defense() -> float:
	return minf(float(Items.ARMOR.get(armor, ["", 0.0])[1]), MAX_ARMOR)

## Shop food / drinks (spec 09): FOOD fills hunger now; BUFFS take the food or drink slot,
## replacing whatever was there.
func consume(item: String) -> void:
	hunger = minf(hunger + float(Items.FOOD.get(item, 0.0)), 100.0)
	if Items.BUFFS.has(item):
		var b: Array = Items.BUFFS[item]
		buffs[b[0]] = {"id": item, "t": b[1], "mods": b[2]}

## Product of active buff multipliers for `stat` (1.0 with none).
func mod(stat: String) -> float:
	var m := 1.0
	for b in buffs.values():
		m *= float(b.mods.get(stat, 1.0))
	return m

func spend(i: int) -> void:
	if points <= 0:
		return
	points -= 1
	var before := max_hp
	set(STATS[i][0], get(STATS[i][0]) + 1)
	hp += max_hp - before

func _physics_process(delta: float) -> void:
	Wardrobe.flip(sprite)  # hats / collars follow flip_h (set here and by game.gd's mouse bite)
	attack_cd = maxf(attack_cd - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	bark_cd = maxf(bark_cd - delta, 0.0)
	pounce_cd = maxf(pounce_cd - delta, 0.0)
	crunch_cd = maxf(crunch_cd - delta, 0.0)
	tail_cd = maxf(tail_cd - delta, 0.0)
	for slot in buffs.keys():
		buffs[slot].t -= delta
		if buffs[slot].t <= 0.0:
			buffs.erase(slot)
	if poison_t > 0.0 and not dead:
		poison_t -= delta
		poison_tick += delta
		if poison_tick >= 1.0:  # ignores armor and dash i-frames: it's already in the blood
			poison_tick -= 1.0
			hp -= poison_dps
			get_parent().float_text(position, str(int(poison_dps)), POISON_COL)
			if hp <= 0.0:
				die()
		sprite.self_modulate = POISON_COL if poison_t > 0.0 else Color.WHITE  # self_: hit flash tweens modulate
	if Input.is_action_pressed("bite") and not frozen:
		space_t += delta
		if space_t >= POUNCE_HOLD and space_t - delta < POUNCE_HOLD:
			pounce()
	else:
		space_t = 0.0
	if pounce_t > 0.0:
		var leap: float = minf(delta, pounce_t)
		pounce_t -= leap
		velocity = facing * (POUNCE_PX / POUNCE_TIME) * (leap / delta)
		move_and_slide()
		if pounce_t <= 0.0:
			land()
		return
	if dash_t > 0.0:
		# last step is clamped so the burst covers exactly DASH_PX; walls still stop it
		var step: float = minf(delta, dash_t)
		dash_t -= step
		velocity = facing * (DASH_PX / DASH_TIME) * (step / delta)
		move_and_slide()
		return
	var dir := Vector2.ZERO
	if not frozen:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()  # scripts/systems/keys.gd
	var weak := hunger < 20.0 or thirst < 20.0
	sprinting = dir != Vector2.ZERO and Input.is_action_pressed("sprint") and not winded
	var top: float = top_mph() * PX_PER_MPH * (0.75 if weak else 1.0) * mod("speed")
	var w: Node = get_parent().get("weather")  # scripts/systems/weather.gd modifiers
	velocity = dir * (top * (w.sprint_mult() if w else 1.0) if sprinting else top * 0.6)
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
		stamina = minf(stamina + delta * (6.0 if weak else 16.0) * mod("stamina"), 100.0)
		winded = winded and stamina < 25.0
	hunger = maxf(hunger - delta * 0.5, 0.0)
	thirst = maxf(thirst - delta * (1.4 if sprinting else 0.7) * (w.thirst_mult() if w else 1.0) * mod("thirst"), 0.0)
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

## C key. Prey are plain Node2Ds, so the dash already passes through them.
## ponytail: rain slide (+30%, less steering) waits for weather (M3).
func dash() -> bool:
	if frozen or dash_cd > 0.0 or dash_t > 0.0 or stamina < DASH_COST:
		return false
	stamina -= DASH_COST
	dash_cd = DASH_CD
	dash_t = DASH_TIME
	return true

## R key: fires a sound wave along `facing`. Foes it hits take a light hit, then
## 5+ levels below flee, within 4 levels get stunned, higher ones ignore the scare.
func bark() -> bool:
	if frozen or bark_cd > 0.0 or stamina < BARK_COST:
		return false
	stamina -= BARK_COST
	bark_cd = BARK_CD * mod("bark_cd")
	Sound.sfx("bark_scare")
	var w := BarkWave.new()
	w.dir = facing
	w.dog_level = level
	w.dmg = attack_damage() * BARK_DMG
	w.game = get_parent()
	w.position = position + facing * 20.0
	get_parent().add_child(w)
	return true

## Hold Space (level 30). The leap itself lands the hit, see land().
func pounce() -> bool:
	if frozen or level < POUNCE_LEVEL or pounce_cd > 0.0 or pounce_t > 0.0 or dash_t > 0.0 or stamina < POUNCE_COST:
		return false
	stamina -= POUNCE_COST
	pounce_cd = POUNCE_CD
	pounce_t = POUNCE_TIME
	return true

func land() -> void:
	var center := position + facing * 26.0
	get_parent().on_bite(center, 46.0, attack_damage() * 2.0)
	stun_near(center, 0.8)

## Q key (level 5): a heavy lunging bite, no reaction delay. Hits like 2.5 bites and stuns.
func crunch() -> bool:
	if frozen or level < CRUNCH_LEVEL or crunch_cd > 0.0 or stamina < CRUNCH_COST:
		return false
	stamina -= CRUNCH_COST
	crunch_cd = CRUNCH_CD
	var tw := create_tween()
	tw.tween_property(sprite, "position", facing * 18.0, 0.06)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.14)
	var center := position + facing * 26.0
	get_parent().on_bite(center, 46.0, attack_damage() * CRUNCH_DMG)
	stun_near(center, 0.6)
	return true

## T key (level 12): spins and sweeps the tail all the way round.
func tail_whip() -> bool:
	if frozen or level < TAIL_LEVEL or tail_cd > 0.0 or stamina < TAIL_COST:
		return false
	stamina -= TAIL_COST
	tail_cd = TAIL_CD
	create_tween().tween_property(sprite, "rotation", TAU, 0.25).from(0.0)
	get_parent().on_bite(position, TAIL_RADIUS, attack_damage() * TAIL_DMG)
	for r in foes():
		if r.position.distance_to(position) < TAIL_RADIUS + 34.0:
			r.knock *= 2.0  # hurt() already shoved it away from the dog
	return true

func stun_near(center: Vector2, time: float) -> void:
	for r in foes():
		if r.position.distance_to(center) < (80.0 if r.is_in_group("boss") else 56.0):  # same reach as on_bite
			r.stun(time)

func foes() -> Array:
	return get_tree().get_nodes_in_group("raccoon") + get_tree().get_nodes_in_group("boss")

## Spec 05: 5% crit, +1% per 30 stat_atk (points are a third the size they were).
func crit_chance() -> float:
	return 0.05 + stat_atk / 3000.0

func roll_crit() -> bool:
	return randf() < crit_chance()

func take_damage(amount: float, poison := 0.0) -> void:
	if dead or dash_t > 0.0:
		return
	if poison > 0.0:
		poison_dps = maxf(poison_dps if poison_t > 0.0 else 0.0, poison)
		poison_t = POISON_TIME
	if amount >= 1.0:  # hits, not the per-frame starving tick
		amount *= 1.0 - defense()
	hp -= amount
	if amount >= 1.0:
		get_parent().float_text(position, str(int(amount)), Color(1, 0.3, 0.3))  # red: damage to Byte (spec 06)
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
		hit.emit()
	if hp <= 0.0:
		die()

## Game shows the death screen on `died`; respawn() brings the dog back.
func die() -> void:
	dead = true
	frozen = true
	hp = 0.0
	if not get_parent().wanted.jails_on_death():  # caught instead: treats kept (spec 08)
		treats = treats / 2
	died.emit()

func respawn() -> void:
	dead = false
	frozen = false
	hp = max_hp
	hunger = 60.0
	thirst = 60.0
	stamina = 100.0
	poison_t = 0.0
	sprite.self_modulate = Color.WHITE
	sprite.rotation = 0.0
	position = spawn_point

func add_xp(amount: int) -> void:
	xp += roundi(amount * mod("xp"))  # Pocket's XP snack
	while xp >= xp_needed() and level < 100:
		xp -= xp_needed()
		level += 1
		points += XP.points_for(level)
		hp = max_hp
		leveled.emit()

func xp_needed() -> int:
	return XP.needed(level)

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

func apply_skin() -> void:
	sprite.texture = load("res://assets/dog_%s.png" % breed().file)
	sprite.scale = Vector2.ONE * float(breed().scale)
	var eq := Wardrobe.worn(get_parent().get("save_extra"), collar, armor)  # scripts/data/wardrobe.gd
	name_tag.text = collar if eq.get("collar", "name") == "name" else ""
	Wardrobe.dress(sprite, breed().file, eq)
