extends Node
## Sound: sfx(name) from assets/sfx, the Music / SFX / Ambience buses (all send to Master),
## and music(track, layer): two players crossfading over FADE seconds.
## Music layers by priority: CUTSCENE > BOSS > CITY. The highest non-empty layer plays;
## at night a "<track>_night" variant replaces its day track when one exists.
## Tracks are placeholder synth loops built at runtime (no files, nothing added to the
## web build); see assets/music/CREDITS.md. Real OGGs later go in assets/music/<track>.ogg.

const BUSES := ["Music", "SFX", "Ambience"]
const SFX_NAMES := ["bark", "catch", "hurt", "buy", "levelup", "steam", "subway", "pickup"]

enum { CITY, BOSS, CUTSCENE }
const FADE := 1.5
const RATE := 11025  # placeholder loops are lo-fi on purpose: cheap to build, cheap to hold
const R := -99  # rest
const TABLE := 64  # wavetable length
## Placeholder loop recipes. lead: 8th notes, bass: quarter notes, both semitones above root.
## "from" makes a variant of another track with some fields replaced.
const TRACKS := {
	"home_theme": {"bpm": 100, "root": 60, "wave": "sq", "decay": 0.35, "hats": 0.5, "swing": 0.0,
		"lead": [0, R, 4, 7, 9, R, 7, 4, 5, R, 4, 2, 0, R, R, R, 0, R, 4, 7, 12, R, 11, 9, 7, R, 5, 4, 2, R, R, R],
		"bass": [0, 7, 5, 7, 9, 4, 5, 7]},
	"nyc_jazz": {"bpm": 132, "root": 53, "wave": "sq", "decay": 0.25, "hats": 0.7, "swing": 0.33,
		"lead": [9, R, 12, 9, 7, R, R, 4, 5, R, 7, R, 9, 7, 5, R, 4, R, 7, 9, 11, R, 12, R, 14, 12, R, 9, 7, R, R, R],
		"bass": [2, 5, 9, 12, 7, 11, 14, 11, 0, 4, 7, 9, 12, 9, 7, 4]},
	"nyc_jazz_night": {"from": "nyc_jazz", "bpm": 100, "wave": "tri", "decay": 0.4, "hats": 0.25},
	"interior_shop": {"bpm": 96, "root": 65, "wave": "tri", "decay": 0.3, "hats": 0.3, "swing": 0.2,
		"lead": [0, 4, 7, 4, 9, 7, 4, R, 5, 9, 12, 9, 7, R, R, R],
		"bass": [0, 7, 5, 7]},
	"hq_puzzle": {"bpm": 80, "root": 57, "wave": "sine", "decay": 0.5, "hats": 0.0, "swing": 0.0,
		"lead": [0, 7, 12, 7, 3, 10, 15, 10, 0, 7, 12, 7, 2, 8, 14, 8],
		"bass": [0, R, -2, R]},
	"boss_fatcat": {"bpm": 168, "root": 50, "wave": "sq", "decay": 0.15, "hats": 0.9, "swing": 0.33,
		"lead": [0, 0, 3, 5, 6, 5, 3, R, 0, 0, 3, 5, 3, R, -2, 0, 0, 0, 3, 5, 6, 5, 3, R, 10, 8, 7, 6, 5, 3, 0, R],
		"bass": [0, 0, 3, 5, 0, 0, 3, -2]},
	"piano_nyc": {"from": "nyc_jazz", "bpm": 72, "root": 65, "wave": "sine", "decay": 0.9, "hats": 0.0, "swing": 0.1},
	"pound_escape": {"bpm": 110, "root": 57, "wave": "saw", "decay": 0.08, "hats": 0.4, "swing": 0.0,
		"lead": [0, R, 0, R, 3, R, 2, R, 0, R, -1, R, 0, R, R, R, 0, R, 0, R, 5, R, 3, R, 2, R, 1, R, 0, R, R, R],
		"bass": [0, 0, -1, -1, 0, 0, -2, -1]},
}
## Room the dog enters -> its city-layer track. Rooms not listed keep the city track.
const ROOM_MUSIC := {"": "nyc_jazz", "subway": "nyc_jazz", "shop": "interior_shop", "boss": "boss_fatcat"}

var sounds := {}
var layers: Array[String] = ["", "", ""]  # indexed by CITY / BOSS / CUTSCENE
var current := ""  # track actually playing (night variant already resolved), "" = silence
var swaps := 0     # how many crossfades have started; tests use it to see no-ops
var night := false:
	set(v):
		if v != night:
			night = v
			_refresh()
var players: Array[AudioStreamPlayer] = []
var active := 0
var streams := {}  # track -> AudioStreamWAV, built on first play
var tables := {}   # wave name -> one-cycle PackedFloat32Array
var fade: Tween

func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for n in SFX_NAMES:
		sounds[n] = load("res://assets/sfx/%s.wav" % n)
	sounds["ding"] = sounds["pickup"]  # ponytail: elevator ding = pickup pitched up; own synth later
	sounds["bark_scare"] = sounds["bark"]  # ponytail: pitched-down bark (lower, longer); swap for its own synth/wav later
	# M4-4 animal control: one-shot synths off the music synth. ponytail: siren is one sweep, not a loop on the van
	for s: Array in [["whistle", {"bpm": 400, "root": 88, "wave": "sine", "lead": [0, 3, 0, 3, 0, 3]}],
			["siren", {"bpm": 90, "root": 72, "wave": "saw", "lead": [0, 1, 3, 5, 7, 5, 3, 1]}]]:
		var w := _synth(s[1].merged({"decay": 0.5, "hats": 0.0, "swing": 0.0, "bass": []}))
		w.loop_mode = AudioStreamWAV.LOOP_DISABLED
		sounds[s[0]] = w
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # music keeps going on pause and death screens
		add_child(p)
		players.append(p)

func sfx(sound: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sounds[sound]
	p.bus = "SFX"
	p.pitch_scale = randf_range(0.92, 1.08) * (0.7 if sound == "bark_scare" else 1.5 if sound == "ding" else 1.0)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## Linear 0..1 volume for a bus by name ("Master" included).
func set_volume(bus: String, v: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(v, 0.0001)))

# ---------- music ----------

## Set the track for a priority layer ("" clears it). Same resulting track = no-op.
func music(track: String, layer := CITY) -> void:
	assert(track == "" or TRACKS.has(track), "unknown music track " + track)
	layers[layer] = track
	_refresh()

## The dog entered a room ("" = street): swap the city-layer track to match.
func room(room_name: String) -> void:
	music(ROOM_MUSIC.get(room_name, layers[CITY]))

## What should be playing right now, given layers and night.
func wanted() -> String:
	for i in range(layers.size() - 1, -1, -1):
		var t := layers[i]
		if t != "":
			return t + "_night" if night and TRACKS.has(t + "_night") else t
	return ""

func _refresh() -> void:
	var t := wanted()
	if t == current:
		return
	current = t
	swaps += 1
	if fade:
		fade.kill()
	var old := players[active]
	active = 1 - active
	var nw := players[active]
	fade = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if t != "":
		nw.stream = stream(t)
		nw.volume_db = -40.0
		nw.play()
		fade.tween_property(nw, "volume_db", 0.0, FADE)
	else:
		nw.stop()
	fade.tween_property(old, "volume_db", -60.0, FADE)
	fade.chain().tween_callback(old.stop)

## Looping stream for a track, synthesized once and cached.
func stream(track: String) -> AudioStreamWAV:
	if not streams.has(track):
		streams[track] = _synth(_recipe(track))
	return streams[track]

func _recipe(track: String) -> Dictionary:
	var d: Dictionary = TRACKS[track]
	if d.has("from"):
		var base: Dictionary = TRACKS[d.from].duplicate()
		base.merge(d, true)
		return base
	return d

## Placeholder synth: lead + walking bass + noise hats, mixed to one 16-bit mono loop.
func _synth(d: Dictionary) -> AudioStreamWAV:
	var lead: Array = d.lead
	var bass: Array = d.bass
	var step := 30.0 / float(d.bpm)  # one 8th note
	var steps := maxi(lead.size(), bass.size() * 2)
	var n := int(steps * step * RATE) & ~1  # even, for the sample packing below
	var buf := PackedFloat32Array()
	buf.resize(n)
	var root: int = d.root
	var swing: float = d.swing
	for i in lead.size():
		if lead[i] != R:
			var at := (i + (swing if i % 2 == 1 else 0.0)) * step
			_note(buf, at, step * 1.8, root + int(lead[i]), d.wave, d.decay, 0.22)
	for i in bass.size():
		if bass[i] != R:
			_note(buf, i * 2 * step, step * 2.0, root - 12 + int(bass[i]), "tri", 0.6, 0.3)
	var hats: float = d.hats
	if hats > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var hn := int(0.04 * RATE)
		for i in steps:
			var s := int((i + (swing if i % 2 == 1 else 0.0)) * step * RATE)
			for k in hn:
				if s + k < n:
					buf[s + k] += rng.randf_range(-1.0, 1.0) * 0.06 * hats * (1.0 - float(k) / hn) * (1.0 if i % 2 == 1 else 0.6)
	var words := PackedInt32Array()  # two 16-bit samples per int: half the loop of encode_s16
	words.resize(n / 2)
	for i in n / 2:
		var a := int(clampf(buf[i * 2], -1.0, 1.0) * 32000.0)
		var b := int(clampf(buf[i * 2 + 1], -1.0, 1.0) * 32000.0)
		words[i] = (a & 0xFFFF) | (b << 16)
	var data := words.to_byte_array()
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _note(buf: PackedFloat32Array, at: float, length: float, midi: int, wave: String, decay: float, vol: float) -> void:
	var tab := _table(wave)
	var inc := 440.0 * pow(2.0, (midi - 69) / 12.0) / RATE * TABLE
	var s0 := int(at * RATE)
	var cnt := mini(int(minf(length, decay * 4.0) * RATE), buf.size() - s0)  # past 4 decays it is silent
	var tail := cnt - 200  # short release so notes never click off
	var fall := exp(-1.0 / (decay * RATE))
	var env := vol
	var p := 0.0
	for k in cnt:
		var e := env
		if k < 55:
			e *= k / 55.0
		elif k > tail:
			e *= (cnt - k) / 200.0
		buf[s0 + k] += tab[int(p)] * e
		env *= fall
		p += inc
		if p >= TABLE:
			p -= TABLE

## One cycle of a waveform, TABLE samples long.
func _table(wave: String) -> PackedFloat32Array:
	if not tables.has(wave):
		var t := PackedFloat32Array()
		t.resize(TABLE)
		for i in TABLE:
			var p := float(i) / TABLE
			match wave:
				"sq": t[i] = 0.6 if p < 0.5 else -0.6
				"saw": t[i] = 2.0 * p - 1.0
				"tri": t[i] = 4.0 * absf(p - 0.5) - 1.0
				_: t[i] = sin(TAU * p)
		tables[wave] = t
	return tables[wave]
