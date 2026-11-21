extends Node2D
## Scent trail (spec 01 Story mechanics): hold V (Keys "sniff") to draw glowing paw prints over the
## road grid from Byte to the target; they stay KEEP s after release. Weather sets how far the prints
## reach (weather.scent_range(): clear 1600, rain 700). Sniffing points the GPS waypoint at the target,
## so the HUD's GPS edge arrow shows it off screen, also past the trail's range. Indoors: straight to the exit.

const KEEP := 6.0   # s the trail stays after V is let go
const GAP := 36.0   # px between paw prints
const COLOR := Color(1.0, 0.85, 0.35)

var g: Node2D
var left := 0.0  # s of trail still showing
var trail := PackedVector2Array()  # full path, ends at the target; empty = nothing to follow

func _ready() -> void:
	g = get_parent()
	name = "Scent"
	z_index = -4  # on the ground, under sprites

## Biscuit's ball while it is out (world/dog_park.gd), else the story target.
func target() -> Vector2:
	for dp: Node in get_tree().get_nodes_in_group("dog_park"):
		if dp.ball != Vector2.ZERO:
			return dp.ball
	return Story.target()

func _process(delta: float) -> void:
	var held: bool = Input.is_action_pressed("sniff") and not g.player.frozen
	left = KEEP if held else maxf(left - delta, 0.0)
	trail = path(g.player.position, target()) if left > 0.0 else PackedVector2Array()
	if held and g.inside == "" and not trail.is_empty() and g.player.position.distance_to(trail[-1]) > 80.0 \
			and g.waypoint.get("pos", Vector2.INF) != trail[-1]:
		g.waypoint = {"pos": trail[-1], "text": "Scent", "color": COLOR}
	queue_redraw()

## Byte -> target: onto the nearest road, along it to a crossing, an L of crossings (every grid
## line is a road, so no navmesh), off the road to the target. Indoors: a straight line to the exit.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if to == Story.NO_TARGET:
		return PackedVector2Array()
	if g.inside != "":
		var exit: Vector2 = g.interior.spots.get("exit", Story.NO_TARGET)
		return PackedVector2Array() if exit == Story.NO_TARGET else PackedVector2Array([from, exit])
	var ra: Vector2 = g.city.nearest_road(from)
	var rb: Vector2 = g.city.nearest_road(to)
	var ca := crossing(ra, to)
	var cb := crossing(rb, from)
	return PackedVector2Array([from, ra, ca, Vector2(cb.x, ca.y), cb, rb, to])

## The crossing on r's road on the side facing `toward` (no doubling back to the other end).
func crossing(r: Vector2, toward: Vector2) -> Vector2:
	var step: Vector2 = g.BLOCK + Vector2(g.ROAD, g.ROAD)
	var c := Vector2.ZERO
	for i in 2:
		var f: float = (r[i] - g.ROAD / 2.0) / step[i]
		if absf(f - roundf(f)) < 0.01:  # already on this axis' road line
			f = roundf(f)
		f = floorf(f) if toward[i] < r[i] else ceilf(f)
		c[i] = clampf(f, 0, [g.NX, g.NY][i]) * step[i] + g.ROAD / 2.0
	return c

## Paw prints along the trail, [pos, dir] each, cut off at the weather's scent range.
func paws() -> Array:
	var out := []
	var reach: float = g.weather.scent_range() if g.inside == "" else INF
	var next := GAP / 2.0
	var done := 0.0
	for i in trail.size() - 1:
		var seg := trail[i].distance_to(trail[i + 1])
		var dir := trail[i].direction_to(trail[i + 1])
		while next <= done + seg and next <= reach:
			out.append([trail[i] + dir * (next - done), dir])
			next += GAP
		done += seg
	return out

func _draw() -> void:
	var a := clampf(left / KEEP * 2.0, 0.0, 1.0)  # fades over the last 3 s
	var still: bool = g.save_extra.get("ui/reduce_motion", false)
	var t := Time.get_ticks_msec() / 1000.0
	var ps := paws()
	for i in ps.size():
		var dir: Vector2 = ps[i][1]
		var at: Vector2 = ps[i][0] + dir.orthogonal() * (5.0 if i % 2 else -5.0)  # left, right, left...
		var glow := 1.0 if still else 0.65 + 0.35 * sin(i * 0.6 - t * 6.0)  # a pulse runs toward the target
		var c := Color(COLOR, a * glow)
		draw_circle(at, 8.0, Color(COLOR, c.a * 0.25))
		draw_circle(at, 3.5, c)
		for k in [-1, 0, 1]:
			draw_circle(at + dir.rotated(k * 0.7) * 6.0, 1.6, c)
