extends Node2D
## Story boss arena: M5-7 Fat Cat (NYSE bell podium) and M6-4 Seagull King (SF pier bait crate).
## Built into the room (freed with it). Once the story is ready, the boss waits up top;
## stepping on the podium plays the `pre` cutscene, then the fight starts.

const FAT_CAT := preload("res://scripts/data/bosses.gd").FAT_CAT
const BossScript := preload("res://scripts/boss.gd")
const BELL_R := 36.0

var g: Node2D
var boss: Node2D
var pre_played := false
var cfg: Dictionary = FAT_CAT
var pre := "cs_fatcat_pre"
var ready_flags := ["ch1_fatcat_ready", "ch1_bodega"]  # any one of them opens the fight
var crate := false  # draw a bait crate instead of the bell

## ch1_fatcat_ready is the spec's gate; ch1_bodega also opens it until M5-8 sets the ready flag.
static func ready_to_fight() -> bool:
	return not Story.has(FAT_CAT.flag) and (Story.has("ch1_fatcat_ready") or Story.has("ch1_bodega"))

func _ready() -> void:
	if Story.has(cfg.flag) or not ready_flags.any(func(f): return Story.has(f)):
		return
	boss = BossScript.new()
	get_parent().add_child(boss)
	boss.setup(cfg, g.interior.spots.boss, g.tex[cfg.get("critter", cfg.tex)], g)
	boss.arena = g.interior.rect

func _process(_delta: float) -> void:
	if not is_instance_valid(boss) or boss.state != boss.State.IDLE or g.dialog.playing():
		return
	if g.player.position.distance_to(g.interior.spots.podium) < BELL_R:
		if pre_played:
			boss.wake()
		else:
			pre_played = true
			g.dialog.play(pre)

func _draw() -> void:  # wooden podium with a brass bell, or a fish crate on the pier
	var p: Vector2 = g.interior.spots.podium
	if crate:
		draw_rect(Rect2(p + Vector2(-26, -20), Vector2(52, 32)), Color(0.5, 0.36, 0.2))
		draw_rect(Rect2(p + Vector2(-26, -20), Vector2(52, 32)), Color(0.3, 0.2, 0.1), false, 2.0)
		for k in 3:
			draw_circle(p + Vector2(-14 + k * 14, -22), 7.0, Color(0.75, 0.8, 0.85))
		return
	draw_rect(Rect2(p + Vector2(-30, -16), Vector2(60, 28)), Color(0.35, 0.2, 0.1))
	draw_rect(Rect2(p + Vector2(-30, -16), Vector2(60, 28)), Color(0.85, 0.65, 0.25), false, 2.0)
	draw_rect(Rect2(p + Vector2(-2, -36), Vector2(4, 22)), Color(0.3, 0.3, 0.3))
	draw_circle(p + Vector2(0, -40), 10.0, Color(0.9, 0.72, 0.25))
