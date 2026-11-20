extends Node2D
## M5-7 Fat Cat arena (spec 03 NYSE, 06 Fat Cat): the bell podium on the trading floor.
## Built into the NYSE room (freed with it). Once the story is ready, Fat Cat waits up top;
## stepping on the podium plays cs_fatcat_pre, then the fight starts.

const FAT_CAT := preload("res://scripts/data/bosses.gd").FAT_CAT
const BossScript := preload("res://scripts/boss.gd")
const BELL_R := 36.0

var g: Node2D
var boss: Node2D
var pre_played := false

## ch1_fatcat_ready is the spec's gate; ch1_bodega also opens it until M5-8 sets the ready flag.
static func ready_to_fight() -> bool:
	return not Story.has(FAT_CAT.flag) and (Story.has("ch1_fatcat_ready") or Story.has("ch1_bodega"))

func _ready() -> void:
	if not ready_to_fight():
		return
	boss = BossScript.new()
	get_parent().add_child(boss)
	boss.setup(FAT_CAT, g.interior.spots.boss, g.tex.cat, g)
	boss.arena = g.interior.rect

func _process(_delta: float) -> void:
	if not is_instance_valid(boss) or boss.state != boss.State.IDLE or g.dialog.playing():
		return
	if g.player.position.distance_to(g.interior.spots.podium) < BELL_R:
		if pre_played:
			boss.wake()
		else:
			pre_played = true
			g.dialog.play("cs_fatcat_pre")

func _draw() -> void:  # wooden podium with a brass bell
	var p: Vector2 = g.interior.spots.podium
	draw_rect(Rect2(p + Vector2(-30, -16), Vector2(60, 28)), Color(0.35, 0.2, 0.1))
	draw_rect(Rect2(p + Vector2(-30, -16), Vector2(60, 28)), Color(0.85, 0.65, 0.25), false, 2.0)
	draw_rect(Rect2(p + Vector2(-2, -36), Vector2(4, 22)), Color(0.3, 0.3, 0.3))
	draw_circle(p + Vector2(0, -40), 10.0, Color(0.9, 0.72, 0.25))
