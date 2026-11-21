extends Node
## Spec 12: footsteps by surface and the city ambience loop (ducked indoors, quiet at night).
## One Sound.sfx per step on a timer, never per frame. Sounds are synths in autoload/sound.gd.
## ponytail: one ambience pair for every city; per-city loops go in Sound when other cities ship.

const WALK_EVERY := 0.28
const SPRINT_EVERY := 0.2
const AMB_DB := -10.0  # low under the music
const DUCK_DB := -12.0  # indoors

var g: Node2D
var step_t := 0.0
var amb: AudioStreamPlayer

func _ready() -> void:
	amb = AudioStreamPlayer.new()
	amb.bus = "Ambience"
	add_child(amb)

## What Byte's paws are on at pos: wood / snow / grass / puddle / concrete.
## ponytail: no puddle sprites yet, so rain anywhere but grass is puddle.
func surface(pos: Vector2) -> String:
	if g.inside != "":
		return "wood"
	if g.weather.look("snow") > 0.5:
		return "snow"
	for p: Rect2 in g.parks:
		if p.has_point(pos):
			return "grass"
	return "puddle" if g.weather.look("rain") > 0.5 else "concrete"

func _process(delta: float) -> void:
	var want: AudioStream = Sound.sounds["amb_night" if Sound.night else "amb_city"]
	if amb.stream != want:
		amb.stream = want
		amb.play()
	amb.volume_db = AMB_DB + (DUCK_DB if g.inside != "" else 0.0)
	var p: CharacterBody2D = g.player
	if p.dead or p.frozen or p.velocity.length() < 1.0:
		step_t = 0.0  # first step lands as soon as Byte moves again
		return
	step_t -= delta
	if step_t <= 0.0:
		step_t = SPRINT_EVERY if p.sprinting else WALK_EVERY
		Sound.sfx("step_" + surface(p.position))
