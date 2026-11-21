extends RefCounted
## Album (spec 04 / 11): all 17 polaroids in story order. Found ones (an fb_* Story flag) are
## sepia stills; the playable ones replay their flashback when pressed. Shown by the inventory's
## Album tab (the home screen's Album button opens that tab in game).

const Look := preload("res://scripts/ui/theme.gd")
const POLAROIDS: Dictionary = preload("res://scripts/data/story.gd").POLAROIDS
const FLASHBACKS: Dictionary = preload("res://scripts/data/story.gd").FLASHBACKS
const SIZE := Vector2(64, 78)

## One polaroid, drawn in code: white frame, a sepia still of Sam and Byte when found, a "?" when not.
## A flat Button so keyboard / gamepad focus can replay it too.
static func polaroid(id: String, found: bool) -> Button:
	var c := Button.new()
	c.flat = true
	c.custom_minimum_size = SIZE
	c.tooltip_text = POLAROIDS[id] if found else "Not found yet"
	c.disabled = not (found and FLASHBACKS.has(id))
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.96, 0.94, 0.88))
		var pic := Rect2(5, 5, SIZE.x - 10, SIZE.x - 10)
		c.draw_rect(pic, Color(0.62, 0.5, 0.36) if found else Color(0.25, 0.25, 0.28))
		if not found:
			c.draw_string(ThemeDB.fallback_font, Vector2(0, pic.get_center().y + 7), "?", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 20, Color(0.6, 0.6, 0.66))
			return
		var h := absi(hash(id))
		var y := pic.end.y - 10
		c.draw_rect(Rect2(pic.position.x, y, pic.size.x, 10), Color(0.42, 0.33, 0.22))
		var sx := pic.position.x + 14 + h % 10  # Sam: legs, hoodie, head
		c.draw_rect(Rect2(sx - 4, y - 10, 8, 10), Color(0.25, 0.2, 0.16))
		c.draw_rect(Rect2(sx - 6, y - 24, 12, 14), Color(0.78, 0.42, 0.32))
		c.draw_circle(Vector2(sx, y - 29), 5, Color(0.92, 0.8, 0.62))
		var bx := pic.end.x - 16 - (h >> 4) % 8  # Byte
		c.draw_rect(Rect2(bx - 7, y - 8, 14, 7), Color(0.88, 0.72, 0.48))
		c.draw_circle(Vector2(bx + 7, y - 10), 4, Color(0.88, 0.72, 0.48)))
	return c

## 6-wide grid of all 17; pick(id) on a replayable one.
static func grid(found: Array, pick: Callable) -> GridContainer:
	var gc := GridContainer.new()
	gc.columns = 6
	gc.add_theme_constant_override("h_separation", 6)
	gc.add_theme_constant_override("v_separation", 6)
	for id: String in POLAROIDS:
		var p := polaroid(id, id in found)
		if not p.disabled:
			p.tooltip_text += "\nPress to replay"
			p.pressed.connect(func(): pick.call(id))
		gc.add_child(p)
	return gc
