extends Node
## Sound: sfx(name) from assets/sfx, and the Music / SFX / Ambience buses (all send to Master).

const BUSES := ["Music", "SFX", "Ambience"]
const SFX_NAMES := ["bark", "catch", "hurt", "buy", "levelup", "steam", "subway", "pickup"]

var sounds := {}

func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for n in SFX_NAMES:
		sounds[n] = load("res://assets/sfx/%s.wav" % n)

func sfx(sound: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[sound]
	p.bus = "SFX"
	p.pitch_scale = randf_range(0.92, 1.08)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## Linear 0..1 volume for a bus by name ("Master" included).
func set_volume(bus: String, v: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(v, 0.0001)))
