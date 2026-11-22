extends Node2D
## Boss: sleeps at its lair, wakes when the dog gets close (or bites it), chases,
## and uses one special attack. Leashed to the lair: heals if the dog gets away
## or dies. Comes back RESPAWN seconds after being beaten.
## Optional cfg keys (spec 06, story bosses): `phases`, `aggro`, `leash`, and the
## one-time drops `bones`, `keycard`, `flag`, `shock`, `post` (see drop()).

enum State { IDLE, CHASE, WINDUP, CHARGE, SLAM, RETURN, DEAD, PARACHUTE }

const AGGRO := 230.0
const LEASH := 650.0   # dog this far from the lair = fight over
const REACH := 40.0
const RESPAWN := 180.0
const SLAM_R := 120.0
const SLAM_TIME := 0.9
const AIR_TIME := 1.2      # golden_parachute: shadow on the floor this long before he lands
const WAVE_SPEED := 380.0  # ticker_wave sweep, px/s
const TICKER := "PURR-40 KIBL+5 BARK-12 MEOW+8 "
const ART_SCALE := 2.5     # assets/boss_<tex>.png (tools/gen_bosses.py); critter PNGs fall back to 7x
const MARK_R := 42.0       # ground hits: a red circle fills in, then it lands
const MARK_WARN := 0.9
const GUST_PUSH := 520.0   # gust: px/s the dog is blown back
const GUST_TIME := 0.6
const CLOAK_TIME := 2.5    # fog_cloak: nearly invisible this long, or until hit

const Levels := preload("res://scripts/systems/levels.gd")
const Raccoon := preload("res://scripts/raccoon.gd")
const Anim := preload("res://scripts/world/anim.gd")
const ATK_TIME := 0.3  # strike pose length: bites, throws, landings

var cfg: Dictionary  # data/bosses.gd entry scaled to its level
var level := 1
var state := State.IDLE
var home := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var t := 0.0           # timer for the current state
var special_cd := 0.0
var special_n := 0     # cycles through the current special list
var phase := 0         # index into cfg.phases
var bite_cd := 0.0
var knock := Vector2.ZERO
var stun_t := 0.0
var charge_dir := Vector2.ZERO
var briefcase := false  # the current charge is a briefcase_charge
var shots: Array[Dictionary] = []  # {s, vel, t, homing}
var marks: Array[Dictionary] = []  # {p, t, col}: telegraphed ground hits (trash_rain, droppings, sewer)
var minions: Array[Node2D] = []    # margin_call security cats
var arena := Rect2()   # ticker_wave sweeps across this; set by the spawner (default: around home)
var wave_x := INF      # ticker_wave line x, INF = no wave
var wave_dir := 1.0
var game: Node2D
var player: CharacterBody2D
var sprite: Sprite2D
var coin_tex: Texture2D  # per boss: a static ref would leak at exit
var fish_tex: Texture2D  # fish_rain flopping fish, drawn in code like coin_tex
var gust_t := 0.0        # gust: seconds left pushing the dog along gust_dir
var gust_dir := Vector2.ZERO
var cloak_t := 0.0       # fog_cloak: seconds left nearly invisible
var critter: Texture2D   # small critter PNG: shots and summons
var walk := 0.0       # seconds spent moving: the waddle (world/anim.gd)
var atk := 0.0        # 1 -> 0 over ATK_TIME: the strike pose
var atk_dir := Vector2.ZERO
var last_pos := Vector2.ZERO
var base_scale := Vector2.ONE
var body_col := Color.WHITE  # sprite modulate at rest: white over boss art, cfg.tint over the critter fallback

func setup(p_cfg: Dictionary, p_home: Vector2, tex: Texture2D, p_game: Node2D) -> void:
	level = p_cfg.level
	cfg = Levels.scale_for_level(p_cfg, level)
	home = p_home
	position = home
	arena = Rect2(home - Vector2(560, 320), Vector2(1120, 640))
	game = p_game
	player = p_game.get_node("Player")
	critter = tex
	sprite = Sprite2D.new()
	var art := "res://assets/boss_%s.png" % cfg.tex
	if ResourceLoader.exists(art):
		sprite.texture = load(art)
		sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	else:
		sprite.texture = tex
		sprite.scale = Vector2(7, 7)
		body_col = cfg.tint
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)  # origin at the feet: squash keeps them planted
	base_scale = sprite.scale
	sprite.modulate = body_col
	add_child(sprite)
	add_to_group("boss")

func _process(delta: float) -> void:
	if game.dialog.playing():  # boss intro / outro lines: everyone holds still
		return
	bite_cd = maxf(bite_cd - delta, 0.0)
	if gust_t > 0.0:  # walls stop the push (move_and_collide), a dash rides through it
		gust_t -= delta
		if player.dash_t <= 0.0:
			player.move_and_collide(gust_dir * GUST_PUSH * delta)
	if cloak_t > 0.0:
		cloak_t -= delta
		sprite.self_modulate.a = 0.12 if cloak_t > 0.0 else 1.0
	update_shots(delta)
	if not marks.is_empty():
		update_marks(delta)
	if not minions.is_empty():
		prune_minions()
	if wave_x != INF:
		update_wave(delta)
	queue_redraw()  # slam ring
	animate(delta)
	position += knock * delta
	knock = knock.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
	if stun_t > 0.0:  # bark / pounce: frozen in place, timers paused
		stun_t -= delta
		return
	var was := position
	var to_player := player.position - position
	var d := to_player.length()
	var speed: float = cfg.speed * (float(cfg.phases[phase].get("speed_mult", 1.0)) if cfg.has("phases") else 1.0)
	match state:
		State.DEAD:
			t -= delta
			if t <= 0.0:
				position = home
				visible = true
				state = State.IDLE
		State.IDLE:
			if d < cfg.get("aggro", AGGRO):
				wake()
		State.RETURN:
			hp = minf(hp + max_hp * delta * 0.5, max_hp)
			if position.distance_to(home) < 8.0:
				position = home
				state = State.IDLE
			else:
				position += position.direction_to(home) * speed * 1.5 * delta
		State.CHASE:
			if player.position.distance_to(home) > cfg.get("leash", LEASH):
				state = State.RETURN
				clear_shots()
				game.on_boss_left(self)
				return
			if d > REACH * 0.6:
				position += to_player / d * speed * delta
			special_cd -= delta
			if special_cd <= 0.0:
				special(to_player / maxf(d, 1.0))
		State.WINDUP:  # telegraph before the charge
			t -= delta
			sprite.modulate = Color(1, 0.35, 0.35) if int(t * 16.0) % 2 == 0 else body_col
			if t <= 0.0:
				sprite.modulate = body_col
				charge_dir = to_player / maxf(d, 1.0)
				state = State.CHARGE
				t = 0.55
		State.CHARGE:
			t -= delta
			position += charge_dir * speed * 3.5 * delta
			if Engine.get_process_frames() % 3 == 0:  # dust trail
				game.poof(position, Color(0.6, 0.55, 0.5), 5, 60.0)
			if t <= 0.0:
				state = State.CHASE
		State.SLAM:  # stands still while the ring fills, then everything inside gets hit
			t -= delta
			if t <= 0.0:
				state = State.CHASE
				game.shake_amt = 10.0
				game.poof(position, cfg.tint)
				strike(Vector2.ZERO)  # lands: squashes flat
				if d < SLAM_R:
					var dmg: float = cfg.dmg
					player.take_damage(dmg * 1.8, cfg.get("poison", 0.0))
		State.PARACHUTE:  # off screen; the shadow marks where he lands
			t -= delta
			if t <= 0.0:
				state = State.CHASE
				game.shake_amt = 10.0  # game.gd zeroes shake under ui/reduce_motion
				game.poof(position, cfg.tint, 30, 200.0)
				strike(Vector2.ZERO)
				if d < SLAM_R:
					var dmg: float = cfg.dmg
					player.take_damage(dmg * 1.8, cfg.get("poison", 0.0))
				for i in 16:  # shockwave ring
					shoot(Vector2.RIGHT.rotated(TAU * i / 16.0) * 220.0, false, 2.0, coin())
	if absf(position.x - was.x) > 0.01:  # face where it's going (knockback excluded)
		sprite.flip_h = position.x < was.x
	if state in [State.CHASE, State.CHARGE] and d < REACH and bite_cd <= 0.0:
		var dmg: float = cfg.dmg
		player.take_damage(dmg * (2.0 if state == State.CHARGE else 1.0), cfg.get("poison", 0.0))
		bite_cd = 1.0
		strike(to_player / maxf(d, 1.0))

func strike(dir: Vector2) -> void:
	atk = 1.0
	atk_dir = dir

## Pose for this frame from the state (world/anim.gd): waddle when moving, crouch on the windup,
## stretched out on a charge, crouch-then-leap on a slam, falling from the sky on a parachute.
func animate(delta: float) -> void:
	walk = walk + delta if position.distance_to(last_pos) > 0.05 and stun_t <= 0.0 else 0.0
	last_pos = position
	atk = maxf(atk - delta / ATK_TIME, 0.0)
	var wind := 0.0
	var y := 0.0
	var a := atk
	var dir := atk_dir
	match state:
		State.WINDUP:
			wind = 1.0
		State.CHARGE:
			a = 0.5  # held at full stretch, leaning into the run
			dir = charge_dir
		State.SLAM:  # crouch, then rise as the ring fills; the landing squash is strike()
			var k := 1.0 - t / SLAM_TIME
			wind = clampf(1.0 - absf(k - 0.15) / 0.15, 0.0, 1.0)
			y = -40.0 * smoothstep(0.3, 0.95, k)
		State.PARACHUTE:
			y = -1000.0 * maxf(t, 0.0) / AIR_TIME
	Anim.pose(sprite, base_scale, walk, wind, a, dir, stun_t > 0.0, y)

func wake() -> void:
	if state == State.IDLE:
		max_hp = cfg.hp
		hp = max_hp
		phase = 0
	state = State.CHASE
	special_cd = 2.0
	game.on_boss_woke(self)
	game.poof(position, cfg.tint, 24, 220.0)
	if cfg.has("intro") and not Story.has(cfg.intro):
		game.dialog.play(cfg.intro)
	if cfg.has("phases"):
		game.boss_name.text = "%s   Lv %d   %s" % [cfg.name, level, pips()]

func _draw() -> void:
	for m in marks:  # red ring fills in, then the hit lands
		var at: Vector2 = m.p - position
		var k := clampf(1.0 - m.t / MARK_WARN, 0.0, 1.0)
		draw_circle(at, MARK_R * k, Color(1, 0.2, 0.15, 0.25))
		draw_arc(at, MARK_R, 0, TAU, 32, Color(1, 0.3, 0.3, 0.4 + 0.6 * k), 2.0)
	if state == State.SLAM:
		draw_circle(Vector2.ZERO, SLAM_R * (1.0 - t / SLAM_TIME), Color(1, 0.2, 0.2, 0.3))
		draw_arc(Vector2.ZERO, SLAM_R, 0, TAU, 48, Color(1, 0.3, 0.3), 3.0)
	if state == State.PARACHUTE:  # landing shadow, grows as he falls
		draw_circle(Vector2.ZERO, SLAM_R * (1.0 - t / AIR_TIME), Color(0, 0, 0, 0.35))
		draw_arc(Vector2.ZERO, SLAM_R, 0, TAU, 48, Color(1, 0.3, 0.3), 3.0)
	if briefcase and state in [State.WINDUP, State.CHARGE]:  # held out in front
		var x := -60.0 if sprite.flip_h else 32.0
		draw_rect(Rect2(x, -46, 28, 20), Color(0.35, 0.2, 0.1))
		draw_rect(Rect2(x + 9, -52, 10, 6), Color(0.2, 0.12, 0.06), false, 2.0)
	if wave_x != INF:  # ticker letters in a column across the floor
		var font := ThemeDB.fallback_font
		var i := 0
		for y in range(int(arena.position.y), int(arena.end.y), 20):
			var c := TICKER[i % TICKER.length()]
			var col := Color(1, 0.35, 0.3) if c == "-" or i % 14 < 7 else Color(0.35, 1, 0.45)
			draw_string(font, Vector2(wave_x, y + 16) - position, c, HORIZONTAL_ALIGNMENT_CENTER, 16, 16, col)
			i += 1

func specials() -> Array:
	return cfg.phases[phase].specials if cfg.has("phases") else cfg.specials

func special(dir: Vector2) -> void:
	special_n += 1
	var list := specials()
	match list[special_n % list.size()]:
		"slam":
			state = State.SLAM
			t = SLAM_TIME
			special_cd = 4.0
			game.float_text(position, "!", Color(1, 0.3, 0.3))
		"storm":  # feathers in every direction
			for i in 12:
				shoot(Vector2.RIGHT.rotated(TAU * i / 12.0) * 240.0, false, 2.5)
			special_cd = 3.0
		"burrow":  # digs under and pops up on the far side of the dog
			game.poof(position, cfg.tint)
			position = player.position + dir * 70.0
			game.poof(position, cfg.tint)
			bite_cd = 0.5  # a beat to react before it bites
			special_cd = 4.0
		"charge", "briefcase_charge", "dive":  # dive: the queen's quicker swoop
			briefcase = list[special_n % list.size()] == "briefcase_charge"
			state = State.WINDUP
			t = 0.4 if list[special_n % list.size()] == "dive" else 0.6
			special_cd = 4.0
			game.float_text(position, "!", Color(1, 0.3, 0.3))
		"feathers":  # fast straight fan
			for a in [-0.35, 0.0, 0.35]:
				shoot(dir.rotated(a) * 330.0, false, 3.0)
			special_cd = 2.5
		"rats":  # slow homing swarm
			for a in [-0.8, 0.0, 0.8]:
				shoot(dir.rotated(a) * 170.0, true, 4.0)
			special_cd = 5.0
		"coin_fan":  # 7 gold coins over 60 degrees
			for i in 7:
				shoot(dir.rotated(deg_to_rad(-30.0 + 10.0 * i)) * 300.0, false, 2.5, coin())
			special_cd = 2.5
		"margin_call":  # security cats (level 18), up to 3 at once
			game.float_text(position, "SECURITY!", Color(1, 0.3, 0.3))
			summon(3, game.tex.cat, 18, "Security cat", Color(0.45, 0.5, 0.65))
			special_cd = 5.0
		"goons":  # the king's royal guard, up to 2
			game.float_text(position, "GUARDS!", Color(1, 0.3, 0.3))
			summon(2, critter, level, "Royal guard", Color(0.75, 0.7, 0.9))
			special_cd = 5.0
		"pack":  # rat pack, up to 3
			game.float_text(position, "SQUEAK!", Color(1, 0.3, 0.3))
			summon(3, critter, level, "Pack rat", Color(0.7, 0.9, 0.6))
			special_cd = 5.0
		"trash_rain":  # trash cans land on the dog and around it
			game.float_text(position, "TRASH DAY!", Color(1, 0.3, 0.3))
			for i in 4:
				var off := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 110.0)
				mark(player.position + off, Color(0.55, 0.55, 0.6), i * 0.1)
			special_cd = 3.5
		"droppings":  # bombing run: splats scattered around the dog
			for i in 6:
				var off := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(TAU * i / 5.0 + randf()) * 85.0
				mark(player.position + off, Color(0.95, 0.95, 0.9), i * 0.08)
			special_cd = 3.5
		"sewer":  # geysers burst up in a line through the dog
			game.float_text(position, "!", Color(1, 0.3, 0.3))
			for i in 7:
				mark(position + dir * (60.0 + 55.0 * i), Color(0.45, 0.7, 0.35), i * 0.07)
			special_cd = 4.0
		"ticker_wave":  # a column of ticker letters sweeps the floor from the far side; dash through it
			wave_dir = 1.0 if player.position.x > arena.get_center().x else -1.0
			wave_x = arena.position.x if wave_dir > 0.0 else arena.end.x
			game.float_text(position, "SELL!", Color(1, 0.3, 0.3))
			special_cd = 4.0
		"fish_rain":  # fish drop on marked spots round the dog, then flop outward
			game.float_text(position, "FISH!", Color(0.6, 0.8, 1))
			for i in 7:
				var off := Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(randf() * TAU) * randf_range(50.0, 140.0)
				mark(player.position + off, Color(0.6, 0.75, 0.9), i * 0.1, 2)
			special_cd = 4.0
		"gust":  # wing flap: blows the dog back, feathers ride the wind
			game.float_text(position, "GUST!", Color(0.8, 0.9, 1))
			gust_dir = dir
			gust_t = GUST_TIME
			for a in [-0.2, -0.1, 0.0, 0.1, 0.2]:
				shoot(dir.rotated(a) * 420.0, false, 1.5)
			game.poof(position + dir * 40.0, Color(0.9, 0.95, 1), 20, 260.0)
			special_cd = 4.5
		"flock_call":  # seagull minions, up to 3
			game.float_text(position, "FLOCK!", Color(1, 0.3, 0.3))
			summon(3, critter, maxi(level - 4, 1), "Seagull", Color(1, 1, 1))
			special_cd = 5.0
		"wave_splash":  # belly flop: three rings of splashes roll outward
			game.float_text(position, "SPLASH!", Color(0.4, 0.7, 1))
			for r in 3:
				for i in 8:
					mark(position + Vector2.RIGHT.rotated(TAU * i / 8.0 + r * 0.4) * (90.0 + 80.0 * r), Color(0.4, 0.65, 0.95), r * 0.3)
			special_cd = 4.5
		"fog_cloak":  # fades into the fog; a hit (or 2.5 s) brings it back
			game.poof(position, Color(0.8, 0.82, 0.86), 30, 120.0)
			cloak_t = CLOAK_TIME
			special_cd = 4.0
		"howl":  # calls two pups and sends out a ring of sound
			game.float_text(position, "AWOOO!", Color(1, 0.8, 0.4))
			summon(2, critter, maxi(level - 4, 1), "Coyote pup", Color(0.95, 0.7, 0.45))
			for i in 10:
				shoot(Vector2.RIGHT.rotated(TAU * i / 10.0) * 160.0, false, 2.0)
			special_cd = 5.0
		"golden_parachute":  # jumps off screen, lands where the dog stood
			game.poof(position, cfg.tint)
			position = player.position
			state = State.PARACHUTE
			t = AIR_TIME
			special_cd = 4.5
	if state == State.CHASE:  # throws, summons, burrows: a quick strike toward the dog
		strike(dir)

## Tops minions up to `cap` (raccoon AI wearing `tex`), placed in a ring around the boss.
func summon(cap: int, tex: Texture2D, lv: int, label: String, col: Color) -> void:
	var n := cap - minions.size()
	for i in n:
		var m: Node2D = Raccoon.new()
		get_parent().add_child(m)  # the room / world, so they go when it does
		m.setup(position + Vector2.RIGHT.rotated(TAU * i / n) * 80.0, tex, game)
		m.level = lv
		m.stats = Levels.scale_for_level(Raccoon.BASE, lv)
		m.stats.poison = cfg.get("poison", 0.0)  # the Rat Meister's pack bites poison too
		m.tag.label.text = "%s Lv %d" % [label, lv]
		m.max_hp = m.stats.hp
		m.hp = m.max_hp
		m.sprite.modulate = col
		m.visible = true
		m.state = Raccoon.State.CHASE
		m.chase_left = 9999.0
		minions.append(m)
		game.poof(m.position, col, 12, 140.0)

## A ground hit at `p`: warns for MARK_WARN (+ delay) seconds, then lands once; `fish` flop out after.
func mark(p: Vector2, col: Color, delay := 0.0, fish := 0) -> void:
	marks.append({"p": p, "t": MARK_WARN + delay, "col": col, "fish": fish})

func update_marks(delta: float) -> void:
	for i in range(marks.size() - 1, -1, -1):
		var m: Dictionary = marks[i]
		m.t -= delta
		if m.t > 0.0:
			continue
		marks.remove_at(i)
		game.poof(m.p, m.col, 14, 170.0)
		for k in m.fish:
			shoot(Vector2.RIGHT.rotated(randf() * TAU) * 140.0, false, 1.2, fish(), m.p)
		if m.p.distance_to(player.position) < MARK_R:
			var dmg: float = cfg.dmg
			player.take_damage(dmg * 1.3, cfg.get("poison", 0.0))
			return  # a downed dog may have ended the fight and cleared the marks

## Gold coin drawn in code, shared by every coin shot.
func coin() -> Texture2D:
	if not coin_tex:
		var img := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
		for x in 7:
			for y in 7:
				var r := Vector2(x - 3, y - 3).length()
				if r < 3.4:
					img.set_pixel(x, y, Color(0.75, 0.5, 0.1) if r > 2.3 else Color(1, 0.88, 0.3))
		coin_tex = ImageTexture.create_from_image(img)
	return coin_tex

## Silver fish drawn in code (fish_rain).
func fish() -> Texture2D:
	if not fish_tex:
		var img := Image.create_empty(9, 5, false, Image.FORMAT_RGBA8)
		for x in 9:
			for y in 5:
				var body := Vector2((x - 3.5) / 3.5, (y - 2.0) / 2.2).length() < 1.0 and x < 7
				var tail := x >= 7 and absi(y - 2) <= x - 6
				if body or tail:
					img.set_pixel(x, y, Color(0.55, 0.7, 0.85) if y > 2 else Color(0.8, 0.88, 0.95))
		img.set_pixel(1, 1, Color(0.1, 0.1, 0.15))
		fish_tex = ImageTexture.create_from_image(img)
	return fish_tex

func shoot(vel: Vector2, homing: bool, life: float, tex: Texture2D = null, at := Vector2.INF) -> void:
	var s := Sprite2D.new()
	s.texture = tex if tex else critter
	s.scale = Vector2(2, 2)
	s.modulate = Color.WHITE if tex else cfg.tint
	s.position = position if at == Vector2.INF else at
	game.add_child(s)  # world space, so shots don't follow the boss
	shots.append({"s": s, "vel": vel, "t": life, "homing": homing})

func update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var sh: Dictionary = shots[i]
		var s: Sprite2D = sh.s
		var vel: Vector2 = sh.vel
		if sh.homing:
			vel = s.position.direction_to(player.position) * vel.length()
		s.position += vel * delta
		s.flip_h = vel.x < 0.0
		sh.t -= delta
		var hit := s.position.distance_to(player.position) < 20.0
		if hit:
			var dmg: float = cfg.dmg
			player.take_damage(dmg * 0.6, cfg.get("poison", 0.0))
		if hit or sh.t <= 0.0:
			s.queue_free()
			shots.remove_at(i)

## The line hits once as it crosses the dog (a dash's i-frames let him through).
func update_wave(delta: float) -> void:
	var was := wave_x
	wave_x += wave_dir * WAVE_SPEED * delta
	if signf(was - player.position.x) != signf(wave_x - player.position.x):
		var dmg: float = cfg.dmg
		player.take_damage(dmg * 1.2, cfg.get("poison", 0.0))
	if wave_x < arena.position.x or wave_x > arena.end.x:
		wave_x = INF

func clear_shots() -> void:
	for sh in shots:
		sh.s.queue_free()
	shots.clear()
	marks.clear()
	wave_x = INF
	gust_t = 0.0
	cloak_t = 0.0
	if sprite:
		sprite.self_modulate.a = 1.0
	for m in minions:
		if is_instance_valid(m):
			m.queue_free()
	minions.clear()

## A beaten or bored security cat hides like a raccoon; summons just go.
func prune_minions() -> void:
	for i in range(minions.size() - 1, -1, -1):
		var m := minions[i]
		if not is_instance_valid(m) or m.state == Raccoon.State.HIDDEN:
			if is_instance_valid(m):
				m.queue_free()
			minions.remove_at(i)

## Bosses never flee a bark; within 4 levels they get the 0.5 s stun.
func scare(dog_level: int) -> void:
	if dog_level - level >= -4:
		stun(0.5)

func stun(time: float) -> void:
	if state != State.DEAD:
		stun_t = maxf(stun_t, time)

func hurt(dmg: float, from: Vector2, crit := false) -> void:
	if state in [State.DEAD, State.PARACHUTE]:
		return
	if state in [State.IDLE, State.RETURN]:
		wake()
	hp -= dmg
	knock = from.direction_to(position) * 120.0
	if state != State.WINDUP:  # windup owns the flash
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", body_col, 0.2)
	if cloak_t > 0.0:  # fog_cloak: a hit shakes it out of the fog
		cloak_t = 0.0
		sprite.self_modulate.a = 1.0
	game.float_text(position, str(int(dmg)), Color.WHITE, crit)
	game.poof(position.move_toward(from, 30.0), Color(1, 0.85, 0.4) if crit else cfg.tint, 10, 160.0)  # hit sparks
	if hp <= 0.0:
		state = State.DEAD
		t = RESPAWN
		visible = false
		sprite.modulate = body_col
		clear_shots()
		game.bump("park_boss_" + cfg.tex)  # Old Rex: "park_boss_raccoon"
		game.on_boss_beaten(self)
		if cfg.has("flag"):
			drop()
	elif cfg.has("phases"):
		next_phase()

## spec 06: below the next phase's `at` the boss swaps special lists, flashes and roars.
func next_phase() -> void:
	var ph: Array = cfg.phases
	var was := phase
	while phase + 1 < ph.size() and hp <= max_hp * float(ph[phase + 1].at):
		phase += 1
	if phase == was:
		return
	special_n = -1  # the new list starts at its first special
	special_cd = 1.0
	game.boss_name.text = "%s   Lv %d   %s" % [cfg.name, level, pips()]
	game.show_banner("%s  PHASE %d" % [str(cfg.name).to_upper(), phase + 1])
	game.float_text(position, "RAWR!", Color(1, 0.3, 0.3))
	game.poof(position, cfg.tint, 30, 200.0)
	game.sfx("bark")
	if not game.save_extra.get("ui/reduce_motion", false):
		sprite.modulate = Color(1.8, 1.8, 1.8)
		create_tween().tween_property(sprite, "modulate", body_col, 0.4)

## Phase pips for the HUD boss bar title: filled = phases reached.
func pips() -> String:
	return "*".repeat(phase + 1) + "-".repeat(cfg.phases.size() - phase - 1)

## Story boss drops (spec 06 / 09): bones, the city keycard, the PURR hit, the story flag,
## then the post-fight cutscene. Story bosses don't respawn.
func drop() -> void:
	game.economy.add_bones(cfg.get("bones", 0))
	if cfg.has("keycard"):
		Story.add_keycard(cfg.keycard)
	if cfg.has("item"):  # Sam's things (Seagull King: the backpack)
		Story.add_item(cfg.item)
	if cfg.has("shock"):
		game.stocks.shock(cfg.shock[0], cfg.shock[1], cfg.shock[2])
	game.float_text(position + Vector2(0, -40), "+%s keycard  +%d bones" % [str(cfg.get("keycard", "")).to_upper(), cfg.get("bones", 0)], Color(1, 0.85, 0.3))
	Story.set_flag(cfg.flag)
	if cfg.has("post"):
		game.dialog.play(cfg.post)
	queue_free()

func _exit_tree() -> void:  # a room boss goes with its room: drop the fight and its shots
	clear_shots()
	if game and game.boss == self:
		game.on_boss_left(self)
