extends Node
## Flashbacks (spec 04 "Flashback playback"): a small sepia room (rooms.gd flashback_room) built
## like an interior. Byte walks between 1-3 props beside Sam (drawn in code, 2-frame idle); F on a
## prop shows its one dialog card. After the last card: fade, back where the dog was, Story flag
## fb_<floor> set (that flag is the album polaroid) and a polaroid slides in with its title.
## Album replays run the same room; the flag is already set, so nothing new is added.

const Album := preload("res://scripts/ui/album.gd")
const Keys := preload("res://scripts/systems/keys.gd")
const FLASHBACKS: Dictionary = preload("res://scripts/data/story.gd").FLASHBACKS
const NEAR := 56.0

var g: Node2D
var id := ""           # flashback playing, "" = none
var props: Array = []  # this flashback's prop rows (data/story.gd)
var seen := {}         # prop index -> true once its card was shown
var back := {}         # where the dog was: inside, door, floor, pos
var sam: Node2D
var sam_frame := 0
var sam_t := 0.0
var ending := false

func playing() -> bool:
	return id != ""

## HQ floors call this when solved: records the time, then plays that floor's flashback if it has one.
func clear_floor(floor_id: String, time: float) -> void:
	Story.clear_floor(floor_id, time)
	if FLASHBACKS.has("fb_" + floor_id):
		play("fb_" + floor_id)

func play(fb: String) -> void:
	if playing() or g.dialog.playing() or not FLASHBACKS.has(fb):
		return
	id = fb
	props = FLASHBACKS[fb].props
	seen = {}
	ending = false
	back = {"inside": g.inside, "door": g.interior.door, "floor": g.interior.floor_n, "pos": g.player.position}
	if g.inside == "":
		g.return_pos = g.player.position  # a save mid-memory puts the dog back here
	fade(build_room)

func build_room() -> void:
	var it: Node = g.interior
	it.door = {"template": "flashback_room", "id": id, "name": "", "floors": 1, "pos": g.return_pos}
	it.floor_n = 0
	it.build("flashback_room")
	for p: Array in props:
		var spr := Sprite2D.new()
		var t: Texture2D = g.tex[p[0]]
		spr.texture = t
		spr.scale = Vector2(p[2], p[2])
		spr.offset.y = -t.get_height() / 2.0
		spr.position = it.O + p[1]
		it.room.add_child(spr)
	sam = Node2D.new()
	sam.position = it.O + FLASHBACKS[id].sam
	sam.draw.connect(draw_sam)
	it.room.add_child(sam)
	g.set_inside("flashback", it.spots.start)
	Sound.music(FLASHBACKS[id].music)  # city layer; leaving calls Sound.room() and restores it

## Sam: jeans, Hack Club red hoodie, head, hair. Frame 1 breathes up a pixel and lifts an arm.
func draw_sam() -> void:
	var up := -2.0 if sam_frame == 1 else 0.0
	sam.draw_circle(Vector2(0, 2), 12, Color(0, 0, 0, 0.25))
	sam.draw_rect(Rect2(-9, -24, 8, 24), Color(0.2, 0.25, 0.45))
	sam.draw_rect(Rect2(1, -24, 8, 24), Color(0.2, 0.25, 0.45))
	sam.draw_rect(Rect2(-13, -52 + up, 26, 30), Color(0.93, 0.2, 0.27))
	sam.draw_rect(Rect2(-18, -50 + up, 6, 22 + up * 2), Color(0.85, 0.17, 0.24))
	sam.draw_rect(Rect2(12, -50 + up, 6, 22), Color(0.85, 0.17, 0.24))
	sam.draw_circle(Vector2(0, -62 + up), 11, Color(0.96, 0.8, 0.65))
	sam.draw_rect(Rect2(-11, -74 + up, 22, 7), Color(0.3, 0.2, 0.12))
	sam.draw_rect(Rect2(-5, -64 + up, 2, 3), Color.BLACK)
	sam.draw_rect(Rect2(3, -64 + up, 2, 3), Color.BLACK)

## Index of the nearest unseen prop in reach (Sam's own lines are on props), or -1.
func near() -> int:
	for k in props.size():
		if not seen.has(k) and g.player.position.distance_to(g.interior.O + props[k][1]) < NEAR:
			return k
	return -1

func inspect(k: int) -> void:
	seen[k] = true
	g.dialog.play(id, [{"say": props[k][3], "text": props[k][4]}])

func _process(delta: float) -> void:
	if playing() and g.inside != "flashback" and not g.player.frozen:
		id = ""  # blacked out mid-memory (respawn left the room): drop it, no polaroid
	if not playing() or g.inside != "flashback":
		return
	sam_t += delta
	if sam_t >= 0.5:
		sam_t = 0.0
		sam_frame = 1 - sam_frame
		sam.queue_redraw()
	if g.dialog.playing() or g.player.frozen or ending:
		return
	if seen.size() == props.size():
		ending = true
		fade(finish)
	elif near() >= 0:
		g.show_menu("MEMORY", [["[%s]  Look" % Keys.label("interact").get_slice(" / ", 0), true]])

func _unhandled_key_input(event: InputEvent) -> void:
	if playing() and g.inside == "flashback" and not g.player.frozen and not g.dialog.playing() \
			and event.is_pressed() and not event.is_echo() and Keys.action_of(event) == "interact" and near() >= 0:
		get_viewport().set_input_as_handled()
		inspect(near())

## Back where the dog was (the street, or the room it came from), flag set, polaroid shown.
func finish() -> void:
	var was := id
	var it: Node = g.interior
	if back.inside == "":
		g.set_inside("", back.pos)
	else:
		it.door = back.door
		it.floor_n = back.floor
		it.build(back.door.template)
		g.set_inside(back.inside, back.pos)
	sam = null
	id = ""
	var first := not Story.has(was)
	Story.set_flag(was)
	if first:
		show_polaroid(was)

## Polaroid slides up into the bottom-right corner with its title; still with reduce motion.
func show_polaroid(fb: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var box := VBoxContainer.new()
	box.add_child(Album.polaroid(fb, true))
	var l: Label = g.ui.hud_label(box, 13)
	l.text = "New polaroid\n" + Album.POLAROIDS[fb]
	layer.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.position = Vector2(box.position.x - 240, box.position.y - 170)
	g.show_msg("Polaroid added to the album")
	var tw := layer.create_tween()
	if not g.save_extra.get("ui/reduce_motion", false):
		var at := box.position
		box.position.y += 200
		tw.tween_property(box, "position", at, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_callback(layer.queue_free)

## Fade to black, run mid, fade back; dog frozen throughout. Instant with reduce motion (spec 11).
func fade(mid: Callable) -> void:
	g.player.frozen = true
	if g.save_extra.get("ui/reduce_motion", false):
		mid.call()
		g.player.frozen = false
		return
	var tw := g.create_tween()
	tw.tween_property(g.fade, "color:a", 1.0, 0.4)
	tw.tween_callback(mid)
	tw.tween_property(g.fade, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): g.player.frozen = false)
