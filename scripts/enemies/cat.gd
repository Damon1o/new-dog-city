extends Node2D
## Common street foes (spec 06): five cat types, a possum and swarm rats, one script keyed by kind.
## Wakes when Byte comes within AGGRO, chases, swipes; each kind adds one trick (TYPES.trick).
## Joins the "raccoon" group so game.on_bite, the bark wave, player.foes() and the minimap find it.
## Also "foe", to tell it from a real raccoon. Beaten = treats + XP, then gone.

const Levels := preload("res://scripts/systems/levels.gd")
const EnemyTag := preload("res://scripts/ui/enemy_tag.gd")
const XP := preload("res://scripts/systems/xp.gd")

const AGGRO := 220.0
const SWIPE_DIST := 26.0
## kind -> name, level-1 stats (spec 06 table), speed, tint, trick, hiss / yowl sfx (autoload/sound.gd).
const TYPES := {
	"tabby": {"name": "Tabby cat", "hp": 40.0, "dmg": 6.0, "xp": 12, "treats": 3, "speed": 150.0,
		"tint": Color(0.95, 0.6, 0.25), "trick": "retreat", "hiss": "cat_hiss_tabby", "yowl": "cat_yowl_tabby"},
	"tom": {"name": "Alley tom", "hp": 80.0, "dmg": 10.0, "xp": 20, "treats": 5, "speed": 100.0,
		"tint": Color(0.5, 0.5, 0.55), "trick": "knock", "hiss": "cat_hiss_tom", "yowl": "cat_yowl_tom"},
	"sphynx": {"name": "Sphynx", "hp": 35.0, "dmg": 8.0, "xp": 18, "treats": 4, "speed": 200.0,
		"tint": Color(0.95, 0.75, 0.7), "trick": "dash", "hiss": "cat_hiss_sphynx", "yowl": "cat_yowl_sphynx"},
	"calico": {"name": "Calico", "hp": 45.0, "dmg": 7.0, "xp": 16, "treats": 4, "speed": 150.0,
		"tint": Color(1, 0.92, 0.82), "trick": "dodge", "hiss": "cat_hiss_calico", "yowl": "cat_yowl_calico"},
	"black": {"name": "Black cat", "hp": 50.0, "dmg": 12.0, "xp": 25, "treats": 5, "speed": 160.0,
		"tint": Color(0.18, 0.18, 0.22), "trick": "stealth", "hiss": "cat_hiss_black", "yowl": "cat_yowl_black"},
	"possum": {"name": "Possum", "hp": 60.0, "dmg": 5.0, "xp": 15, "treats": 4, "speed": 110.0,
		"tint": Color(0.72, 0.72, 0.75), "trick": "play_dead", "hiss": "possum_hiss", "yowl": "possum_yowl"},
	"rat": {"name": "Rat", "hp": 8.0, "dmg": 3.0, "xp": 4, "treats": 1, "speed": 170.0,
		"tint": Color(0.45, 0.4, 0.38), "trick": "", "hiss": "rat_squeak", "yowl": "rat_squeak"},
}
## Facing right. X = fur (tint), E = eye, P = pink (nose / tail).
const CAT := [
	"........X..X",
	"........XXXX",
	"X.......XEXE",
	"X.......XXPX",
	".XXXXXXXXXX.",
	"..XXXXXXXX..",
	"..X.X..X.X..",
	"..X.X..X.X..",
]
const RAT := [
	"....XXX.",
	"..XXXXEX",
	"PXXXXXXP",
	"...X.X..",
]
const STEALTH_DIST := 120.0

static var cache := {}

var kind := "tabby"
var cfg: Dictionary
var stats: Dictionary
var level := 1
var hp := 1.0
var max_hp := 1.0
var state := "idle"  # idle, chase, dash, retreat, flee, stun, dead (possum playing dead)
var t := 0.0
var cd := 0.0  # swipe cooldown
var dir := Vector2.ZERO
var knock := Vector2.ZERO
var dodged := false
var played := false
var revealed := false
var game: Node2D
var player: Node2D
var sprite: Sprite2D
var tag: Node2D

func setup(p_kind: String, pos: Vector2, p_game: Node2D, bonus := 0) -> void:
	kind = p_kind
	cfg = TYPES[kind]
	position = pos
	game = p_game
	player = game.player
	level = clampi(Levels.level_at(pos, game.WORLD) + bonus, 1, 100)
	stats = Levels.scale_for_level(cfg, level)
	max_hp = stats.hp
	hp = max_hp
	sprite = Sprite2D.new()
	sprite.texture = art(kind)
	sprite.scale = Vector2(2.5, 2.5)
	add_child(sprite)
	tag = EnemyTag.new()
	add_child(tag)
	tag.setup(cfg.name, player)
	add_to_group("raccoon")  # ponytail: hostile group is still named "raccoon"; rename to "foe" across callers when it bites
	add_to_group("foe")

## Sprite from the string grid, tint baked in so hit flashes (modulate) still read. Cached per kind.
static func art(k: String) -> Texture2D:
	if not cache.has(k):
		var rows: Array = RAT if k == "rat" else CAT  # ponytail: possum borrows the cat grid; own snouty grid later
		var pal := {"X": TYPES[k].tint, "E": Color(0.95, 0.85, 0.2), "P": Color(0.95, 0.6, 0.65)}
		var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				img.set_pixel(x, y, pal.get(rows[y][x], Color(0, 0, 0, 0)))
		cache[k] = ImageTexture.create_from_image(img)
	return cache[k]

func _process(delta: float) -> void:
	cd = maxf(cd - delta, 0.0)
	t -= delta
	position += knock * delta
	knock = knock.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	var to := player.position - position
	var d := to.length()
	if cfg.trick == "stealth":  # invisible until Byte is close; once seen, stays seen
		revealed = revealed or d < STEALTH_DIST
		visible = revealed  # also keeps it off the minimap
	var was := position
	match state:
		"idle":
			if d < AGGRO:
				state = "chase"
				Sound.sfx(cfg.hiss)
		"chase":
			if d > AGGRO * 2.5:
				state = "idle"
			# tabby circles in instead of running straight at the dog
			position += to.normalized().rotated(0.7 if cfg.trick == "retreat" else 0.0) * stats.speed * delta
			if d < SWIPE_DIST and cd <= 0.0:
				swipe(to)
			elif cfg.trick == "dash" and d < 140.0 and cd <= 0.0:
				state = "dash"
				dir = to.normalized()
				t = 0.25
		"dash":
			position += dir * stats.speed * 3.0 * delta
			if d < SWIPE_DIST + 6.0 and cd <= 0.0:
				swipe(to)
			if t <= 0.0:
				state = "chase"
		"retreat", "flee":
			position -= to.normalized() * stats.speed * delta
			if t <= 0.0:
				state = "chase" if state == "retreat" else "idle"
		"stun":
			if t <= 0.0:
				state = "chase"
		"dead":  # possum: up after 3 s and straight into a bite
			if t <= 0.0:
				sprite.flip_v = false
				state = "dash"
				dir = to.normalized()
				t = 0.3
	if absf(position.x - was.x) > 0.01:  # face where it's going (knockback excluded)
		sprite.flip_h = position.x < was.x

func swipe(to: Vector2) -> void:
	cd = 1.0
	var crit: bool = cfg.trick == "stealth" and randf() < 0.3
	player.take_damage(stats.dmg * (1.75 if crit else 1.0))
	if cfg.trick == "knock":  # ponytail: shoves the body straight; can nudge Byte into a wall edge
		player.position += to.normalized() * 40.0
	elif cfg.trick == "retreat":
		state = "retreat"
		t = 0.8

## Bark (spec 05): flee 4 s if the dog is 5+ levels above, stun 0.5 s within 4 levels, else ignore.
func scare(dog_level: int) -> void:
	var gap := dog_level - level
	if gap >= 5 and state != "dead":
		state = "flee"
		t = 4.0
	elif gap >= -4:
		stun(0.5)

func stun(time: float) -> void:
	if state != "dead":
		state = "stun"
		t = time

func hurt(dmg: float, from: Vector2, crit := false) -> void:
	if is_queued_for_deletion() or state == "dead":  # playing dead: bites pass right over it
		return
	revealed = true
	if cfg.trick == "dodge" and not dodged:  # calico sidesteps the first bite of the fight
		dodged = true
		position += from.direction_to(position).orthogonal() * 40.0
		game.float_text(position, "dodge!", Color(0.8, 0.9, 1))
		state = "chase"
		return
	hp -= dmg
	tag.hit()
	knock = from.direction_to(position) * 260.0
	sprite.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	game.float_text(position, str(int(dmg)), Color.WHITE, crit)
	if hp <= 0.0:
		beaten()
	elif cfg.trick == "play_dead" and not played and hp < max_hp * 0.25:
		played = true
		state = "dead"
		t = 3.0
		sprite.flip_v = true
		game.float_text(position, "x_x", Color(0.8, 0.8, 0.8))
	else:
		state = "chase"
		Sound.sfx(cfg.yowl)

func beaten() -> void:
	remove_from_group("foe")
	if kind == "black" and game.Spawns.phase(game.sun()) == "night":
		game.bump("black_cats_night")  # Old Rex quest (M4-7)
	player.treats += stats.treats
	XP.award(game, stats.xp, self)
	game.float_text(position, "%s beaten! +%d treats" % [cfg.name, stats.treats], Color(1, 0.85, 0.5))
	game.poof(position, cfg.tint)
	Sound.sfx(cfg.yowl)
	queue_free()
