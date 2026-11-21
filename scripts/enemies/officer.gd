extends Node2D
## Animal control officer (spec 08): chases on foot at 230 px/s, can't be hurt, grabs the
## dog after 1.2 s within 24 px. Bark stuns 0.5 s (systems/wanted.gd), dash slips past.
## Net-gun officers (4+ stars) fire a slow net that roots the dog 2 s. Drawn in code.

const SPEED := 230.0
const GRAB_DIST := 24.0
const GRAB_TIME := 1.2
const NET_RANGE := 320.0
const NET_CD := 3.0
const PARK_WAIT := 5.0

var g: Node2D
var wanted: Node
var net := false       # carries a net gun (set by wanted at 4+ stars)
var van_drop := false  # came out of a van; the van takes it away again
var whistled := false  # whistle played for this approach (wanted.gd)
var stun_t := 0.0
var grab_t := 0.0
var broke_free := false  # spec 08: mashing C breaks a grab once per officer
var net_cd := 1.5
var fence_t := 0.0  # waiting at a dog park fence

func setup(p_game: Node2D, at: Vector2) -> void:
	g = p_game
	wanted = g.wanted
	position = at
	add_to_group("officer")

func stun(time: float) -> void:
	stun_t = maxf(stun_t, time)
	grab_t = 0.0

func _process(delta: float) -> void:
	if g.inside != "":
		return  # officers wait on the street
	var p: CharacterBody2D = g.player
	stun_t -= delta
	queue_redraw()
	if stun_t > 0.0:
		return
	var to := p.position - position
	if grab_t > 0.0 and p.dash_t > 0.0 and not broke_free:  # ponytail: one dash (C) out of a grab = the mash
		broke_free = true
		stun(0.6)
		wanted.add_heat(10, "break_free")
		return
	if to.length() < GRAB_DIST and p.dash_t <= 0.0:
		if wanted.root_t > 0.0:
			wanted.caught()  # netted dog + officer on him = caught
			return
		grab_t += delta
		if grab_t >= GRAB_TIME:
			wanted.caught()
		return
	grab_t = 0.0
	net_cd -= delta
	if net and net_cd <= 0.0 and to.length() < NET_RANGE:
		net_cd = NET_CD
		var n := Net.new()
		n.position = position
		n.vel = to.normalized() * 200.0
		n.wanted = wanted
		g.add_child(n)
	var step := to.normalized() * SPEED * delta
	if g.city.in_dog_park(position + step):
		fence_t += delta  # officers never enter dog parks: wait at the fence, then leave
		if fence_t >= PARK_WAIT:
			queue_free()
		return
	fence_t = 0.0
	if not g.blocked(position + step):  # ponytail: same wall slide as prey.gd, no pathfinding
		position += step
	elif not g.blocked(position + Vector2(step.x, 0)):
		position.x += step.x
	elif not g.blocked(position + Vector2(0, step.y)):
		position.y += step.y

func _draw() -> void:
	var navy := Color(0.12, 0.2, 0.4) if stun_t <= 0.0 else Color(0.5, 0.5, 0.7)
	draw_rect(Rect2(-9, -14, 18, 22), navy)                 # uniform
	draw_rect(Rect2(-8, 8, 6, 8), Color(0.1, 0.1, 0.12))    # legs
	draw_rect(Rect2(2, 8, 6, 8), Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(0, -20), 7, Color(0.95, 0.78, 0.62))  # head
	draw_rect(Rect2(-8, -29, 16, 5), navy.darkened(0.3))      # cap
	draw_rect(Rect2(-2, -25, 12, 2), navy.darkened(0.5))      # brim
	draw_circle(Vector2(-4, -8), 2.5, Color(1, 0.85, 0.2))    # badge
	draw_rect(Rect2(-6, -2, 12, 3), Color(0.9, 0.5, 0.1))     # hi-vis stripe
	if net:
		draw_rect(Rect2(8, -6, 14, 5), Color(0.45, 0.45, 0.5))  # net gun
	if grab_t > 0.0:  # grab bar over the dog
		var at: Vector2 = g.player.position - position + Vector2(-20, -40)
		draw_rect(Rect2(at, Vector2(40, 5)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(at, Vector2(40 * grab_t / GRAB_TIME, 5)), Color(1, 0.3, 0.2))

## Net-gun shot: slow, 2 s life, roots the dog 2 s on contact (dash dodges it).
class Net extends Node2D:
	var vel := Vector2.ZERO
	var wanted: Node
	var life := 2.0

	func _process(delta: float) -> void:
		position += vel * delta
		life -= delta
		queue_redraw()
		var p: CharacterBody2D = wanted.g.player
		if position.distance_to(p.position) < 18.0 and p.dash_t <= 0.0:
			wanted.root(2.0)
			queue_free()
		elif life <= 0.0:
			queue_free()

	func _draw() -> void:
		for i in 3:
			draw_line(Vector2(-8, -8 + i * 8), Vector2(8, -8 + i * 8), Color(0.85, 0.85, 0.8), 1.5)
			draw_line(Vector2(-8 + i * 8, -8), Vector2(-8 + i * 8, 8), Color(0.85, 0.85, 0.8), 1.5)
