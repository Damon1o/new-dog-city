extends Node
## Dialog box + cutscene runner (spec 11 "Dialog and cutscenes", spec 01 "Cutscene").
## play("cs_intro") runs a script from data/story.gd: letterbox bars slide in, HUD hides, dog frozen.
## Typewriter at 30 chars/s; any key completes the line, the next key advances. Esc skips the rest
## (its {flag} steps are still set). Own CanvasLayer above the HUD, so hiding g.hud keeps it.

const Look := preload("res://scripts/ui/theme.gd")
const CUTSCENES: Dictionary = preload("res://scripts/data/story.gd").CUTSCENES
const BOSSES: Array = preload("res://scripts/data/bosses.gd").BOSSES
const CPS := 30.0
const BAR := 80.0

var g: Node2D
var id := ""          # cutscene playing, "" = none
var steps: Array = [] # steps left
var wait_t := 0.0
var typed := 0.0
var bars: Array[ColorRect] = []
var box: PanelContainer
var portrait: TextureRect
var speaker: Label
var text: Label
var pan_tw: Tween

func build() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = g.hud.theme
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(r)
		r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			r.offset_bottom = BAR
		else:
			r.offset_top = -BAR
			r.pivot_offset.y = BAR  # grows up from the bottom edge
		r.scale.y = 0.0
		bars.append(r)
	box = g.ui.panel(0.92)
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -BAR - 10
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var col := VBoxContainer.new()
	row.add_child(col)
	speaker = g.ui.hud_label(col, 18, Look.ACCENT.lightened(0.35))
	text = g.ui.hud_label(col, 16, Look.TEXT)
	text.custom_minimum_size = Vector2(620, 48)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.hide()

func playing() -> bool:
	return id != ""

## `list` runs those steps under id `cs` instead of a data/story.gd script (flashback cards).
func play(cs: String, list := []) -> void:
	if playing():
		return
	id = cs
	steps = (list if list else CUTSCENES[cs]).duplicate()
	g.player.frozen = true
	g.hud.hide()
	letterbox(1.0)
	next()

## Runs instant steps until one that waits (a card, a pan, a wait); ends the cutscene when none are left.
func next() -> void:
	box.hide()
	while not steps.is_empty():
		var s: Dictionary = steps.pop_front()
		if s.has("say"):
			show_card(s.say, s.text)
			return
		if s.has("pan"):
			pan_tw = create_tween()
			pan_tw.tween_property(g.cam, "position", s.pan, s.t)
			wait_t = s.t
			return
		if s.has("wait"):
			wait_t = s.wait
			return
		if s.has("sfx"):
			Sound.sfx(s.sfx)
		elif s.has("music"):
			Sound.music(s.music, Sound.CUTSCENE)
		elif s.has("flag"):
			Story.set_flag(s.flag)
	finish()

## Esc: drop the rest, but keep every flag the cutscene would have set.
func skip() -> void:
	for s: Dictionary in steps:
		if s.has("flag"):
			Story.set_flag(s.flag)
	steps.clear()
	finish()

func finish() -> void:
	if pan_tw:
		pan_tw.kill()
	g.cam.position = Vector2.ZERO
	Sound.music("", Sound.CUTSCENE)
	box.hide()
	letterbox(0.0)
	g.hud.show()
	g.player.frozen = false
	wait_t = 0.0
	id = ""

func show_card(who: String, line: String) -> void:
	speaker.text = who
	text.text = line
	text.visible_characters = 0
	typed = 0.0
	portrait.texture = face(who)
	box.show()

## Byte's own sprite (first frame of the sheet); others get the cat art.
## ponytail: one stand-in face for every non-Byte speaker; real portraits once assets has them.
func face(who: String) -> Texture2D:
	if who in ["Sam", "Boss Hedgehog"]:
		return null  # Sam is drawn in code (scripts/world/flashback.gd), no texture to show
	for b: Dictionary in BOSSES:
		if b.name == who:
			return g.tex[b.tex]
	if who != "Byte":
		return g.tex.cat
	var sheet: Texture2D = g.player.sprite.texture
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(0, 0, sheet.get_width() / 2.0, sheet.get_height())
	return a

## Bars in (1) or out (0); instant with reduce motion. save_extra["ui/reduce_motion"] is the
## same ui/reduce_motion key the home screen's Settings writes, loaded by systems/save.gd.
func letterbox(to: float) -> void:
	var instant: bool = g.save_extra.get("ui/reduce_motion", false)
	for r in bars:
		if instant:
			r.scale.y = to
		else:
			create_tween().tween_property(r, "scale:y", to, 0.4).set_trans(Tween.TRANS_CUBIC)

func typing() -> bool:
	return box.visible and text.visible_characters < text.text.length()

func _process(delta: float) -> void:
	if not playing():
		return
	if typing():
		typed += delta * CPS
		text.visible_characters = int(typed)
	elif wait_t > 0.0:
		wait_t -= delta
		if wait_t <= 0.0:
			next()

## Keys go here first (before game.gd) so a cutscene eats them all, Esc included.
func _input(event: InputEvent) -> void:
	if not playing() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		skip()
	elif typing():
		text.visible_characters = text.text.length()
	elif box.visible:
		next()
