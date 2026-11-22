extends RefCounted
## Code-drawn people: street pedestrians (human.gd), animal control (enemies/officer.gd) and the
## pizza clerk (ui/shop.gd) share one outlined figure. Origin at the hips, feet at y 12, head
## centre at y -22; drawn facing right, callers flip with scale.x / draw_set_transform.
##   look  {skin, hair, style, shirt, pants, shoes, build, hat, hat_col, stripe, badge, apron, bag}
##   swing leg / arm swing in px (sin of the walk clock)
##   arms  "walk" | "up" (screaming) | "reach" (grab / point)
##   face  "" | "scream" | "angry" | "dead"

const OUT := Color(0.07, 0.06, 0.09)
const SKIN := [Color(0.98, 0.84, 0.7), Color(0.88, 0.68, 0.5), Color(0.66, 0.46, 0.32), Color(0.42, 0.28, 0.2)]
const HAIR := [Color(0.1, 0.08, 0.07), Color(0.32, 0.2, 0.1), Color(0.6, 0.38, 0.16), Color(0.86, 0.72, 0.4), Color(0.7, 0.7, 0.72), Color(0.6, 0.15, 0.1)]
const PANTS := [Color(0.22, 0.3, 0.5), Color(0.15, 0.15, 0.18), Color(0.6, 0.52, 0.36), Color(0.35, 0.36, 0.4), Color(0.3, 0.42, 0.3)]
const STYLES := ["short", "short", "long", "bun", "curly", "bald", "beanie", "cap"]

## A random street look, from the human's own rng so a seed always dresses the same.
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var style: String = STYLES[rng.randi() % STYLES.size()]
	return {"skin": SKIN[rng.randi() % SKIN.size()], "hair": HAIR[rng.randi() % HAIR.size()], "style": style,
		"shirt": Color.from_hsv(rng.randf(), rng.randf_range(0.35, 0.7), rng.randf_range(0.55, 0.9)),
		"pants": PANTS[rng.randi() % PANTS.size()], "shoes": Color(0.95, 0.95, 0.95) if rng.randf() < 0.4 else Color(0.2, 0.14, 0.1),
		"build": rng.randf_range(0.85, 1.2), "hat_col": Color.from_hsv(rng.randf(), 0.6, 0.6),
		"bag": rng.randf() < 0.3}

static func box(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(r.grow(1.0), OUT)
	ci.draw_rect(r, col)

static func disc(ci: CanvasItem, at: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(at, rad + 1.0, OUT)
	ci.draw_circle(at, rad, col)

static func limb(ci: CanvasItem, from: Vector2, to: Vector2, sleeve: Color, skin: Color) -> void:
	var mid := from.lerp(to, 0.5)
	ci.draw_line(from, to, OUT, 5.0)
	ci.draw_line(from, mid, sleeve, 3.0)
	ci.draw_line(mid, to, skin, 3.0)
	disc(ci, to, 1.8, skin)

static func draw(ci: CanvasItem, lk: Dictionary, swing := 0.0, arms := "walk", face := "") -> void:
	var skin: Color = lk.skin
	var shirt: Color = lk.shirt
	var pants: Color = lk.pants
	var w: float = 7.0 * float(lk.get("build", 1.0))  # half torso width
	ci.draw_colored_polygon(ellipse(Vector2(0, 13), w + 3.0, 2.5), Color(0, 0, 0, 0.25))  # ground shadow
	for k in [[-swing, pants.darkened(0.25)], [swing, pants]]:  # legs: back leg darker, shoes point forward
		var x: float = k[0] - 2.0
		box(ci, Rect2(x - 1.5, -1, 4, 11), k[1])
		box(ci, Rect2(x - 1.5, 10, 6, 2.5), lk.get("shoes", Color(0.2, 0.14, 0.1)))
	var shoulder := Vector2(0, -14)
	var hands: Array = {"walk": [Vector2(-3 - swing, -2), Vector2(3 + swing, -2)],
		"up": [Vector2(-7 + swing, -30), Vector2(8 - swing, -31)],
		"reach": [Vector2(10, -13), Vector2(14, -11)]}[arms]
	limb(ci, shoulder + Vector2(-1, 0), hands[0], shirt.darkened(0.3), skin.darkened(0.15))  # back arm
	if lk.get("bag", false):
		box(ci, Rect2(-w - 3, -8, 5, 7), Color(0.55, 0.35, 0.2))
	box(ci, Rect2(-w, -17, w * 2.0, 17), shirt)  # torso: lit left edge, shaded right edge
	ci.draw_rect(Rect2(-w, -17, 3, 17), shirt.lightened(0.18))
	ci.draw_rect(Rect2(w - 3, -17, 3, 17), shirt.darkened(0.2))
	ci.draw_rect(Rect2(-w, -2, w * 2.0, 2), pants.darkened(0.35))  # belt
	if lk.has("apron"):
		ci.draw_rect(Rect2(-w + 3, -12, w * 2.0 - 6, 14), lk.apron)
		ci.draw_line(Vector2(-w + 3, -12), Vector2(-2, -17), lk.apron, 1.5)
	if lk.has("stripe"):
		ci.draw_rect(Rect2(-w, -8, w * 2.0, 2.5), lk.stripe)
	if lk.get("badge", false):
		ci.draw_circle(Vector2(w - 4, -12), 2.0, Color(1, 0.85, 0.2))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -17), Vector2(3, -17), Vector2(0, -13)]), skin)  # neck V
	limb(ci, shoulder + Vector2(1, 0), hands[1], shirt.darkened(0.08), skin)  # front arm
	draw_head(ci, lk, face)

static func draw_head(ci: CanvasItem, lk: Dictionary, face: String) -> void:
	var skin: Color = lk.skin
	var hair: Color = lk.get("hair", Color.BLACK)
	var style: String = lk.get("style", "short")
	var c := Vector2(0, -23)
	if style == "long":  # hair hanging behind the head
		box(ci, Rect2(-7, -28, 7, 13), hair)
	elif style == "bun":
		disc(ci, c + Vector2(-6, -5), 3.0, hair)
	disc(ci, c, 6.5, skin)
	ci.draw_circle(c + Vector2(-2, 1), 1.6, skin.darkened(0.15))  # ear
	match style:
		"short", "long", "bun":
			ci.draw_rect(Rect2(-7, -30, 13, 4), hair)
			ci.draw_rect(Rect2(-7, -27, 4, 4), hair)
		"curly":
			for p in [Vector2(-5, -28), Vector2(-1, -30), Vector2(3, -29), Vector2(-6, -24)]:
				ci.draw_circle(p, 3.0, hair)
	var hat: String = lk.get("hat", "cap" if style == "cap" else ("beanie" if style == "beanie" else ""))
	var hc: Color = lk.get("hat_col", Color(0.2, 0.3, 0.6))
	match hat:
		"cap":
			box(ci, Rect2(-7, -31, 13, 5), hc)
			ci.draw_rect(Rect2(4, -27, 6, 2), hc.darkened(0.35))  # brim
		"beanie":
			box(ci, Rect2(-7, -32, 14, 6), hc)
			ci.draw_rect(Rect2(-7, -27, 14, 2), hc.darkened(0.25))
		"paper":
			box(ci, Rect2(-7, -31, 14, 4), Color.WHITE)
			ci.draw_rect(Rect2(-7, -29, 14, 1), Color(0.85, 0.2, 0.15))
	var eye := c + Vector2(3, -1)  # face looks right
	match face:
		"dead":
			ci.draw_line(eye + Vector2(-1.5, -1.5), eye + Vector2(1.5, 1.5), OUT, 1.0)
			ci.draw_line(eye + Vector2(-1.5, 1.5), eye + Vector2(1.5, -1.5), OUT, 1.0)
		"scream":
			ci.draw_circle(eye, 1.6, Color.WHITE)
			ci.draw_circle(eye, 0.8, OUT)
			ci.draw_circle(c + Vector2(3.5, 3.5), 2.0, OUT)
		"angry":
			ci.draw_rect(Rect2(eye - Vector2(1, 1), Vector2(2, 2)), OUT)
			ci.draw_line(eye + Vector2(-2, -3), eye + Vector2(2, -2), OUT, 1.0)
			ci.draw_line(c + Vector2(2, 4), c + Vector2(5, 3.5), OUT, 1.0)
		_:
			ci.draw_rect(Rect2(eye - Vector2(1, 1), Vector2(2, 2)), OUT)
			ci.draw_line(c + Vector2(2, 3.5), c + Vector2(5, 3), skin.darkened(0.4), 1.0)

static func ellipse(at: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(at + Vector2(cos(TAU * i / 12.0) * rx, sin(TAU * i / 12.0) * ry))
	return pts

## Shared hit / death feedback for every person: red flash and damage number; on death a
## 5-star wanted spike and a blood poof. The caller frees the node.
static func hit(person: Node2D, g: Node2D, dmg: float, dead: bool) -> void:
	g.float_text(person.position, "-%d" % dmg, Color(1, 0.4, 0.4))
	person.modulate = Color(1, 0.35, 0.35)
	person.create_tween().tween_property(person, "modulate", Color.WHITE, 0.2)
	if not dead:
		return
	g.poof(person.position, Color(0.8, 0.1, 0.1))
	g.float_text(person.position + Vector2(0, -20), "WANTED!", Color(1, 0.2, 0.2))
	g.wanted.add_heat(g.wanted.MAX_HEAT, "human")  # 5 stars
