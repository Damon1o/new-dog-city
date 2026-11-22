extends Node
## Good Boy AI (Ch 2 side story, SF only): Byte founds an AI startup in a garage to build PawFinder,
## an AI that sniffs out lost humans. Pay treats at the founder's desk to grow it one stage at a
## time; each stage earns treats per in-game day, collected at the desk (at most MAX_DAYS banked).
## Saved as save_extra "startup/state" {stage, paid (day of the last payout)}.

## [menu text, cost in treats, treats per day once bought, cutscene (data/story.gd)]
const STAGES := [
	["Found Good Boy AI", 150, 10, "cs_startup_found"],
	["Hire Sam's hackathon friends", 300, 25, ""],
	["Ship the PawFinder beta", 600, 45, "cs_startup_beta"],
	["Raise a seed round", 1000, 70, ""],
	["Take Good Boy AI public", 1800, 110, "cs_startup_ipo"],
]
const MAX_DAYS := 3
const NEAR := 60.0

var g: Node2D

func state() -> Dictionary:
	if not g.save_extra.get("startup/state") is Dictionary:
		g.save_extra["startup/state"] = {}
	return g.save_extra["startup/state"]

func stage() -> int:
	return int(state().get("stage", 0))

func per_day() -> int:
	return 0 if stage() == 0 else int(STAGES[stage() - 1][2])

## Profit waiting at the desk.
func owed() -> int:
	var days: int = g.territory.day() - int(state().get("paid", g.territory.day()))
	return per_day() * clampi(days, 0, MAX_DAYS)

## Menu rows for the founder's desk: [text, selectable].
func rows() -> Array:
	var out := []
	if stage() < STAGES.size():
		var s: Array = STAGES[stage()]
		out.append(["[1]  %s   %d treats" % [s[0], s[1]], g.player.treats >= s[1]])
	else:
		out.append(["[1]  Good Boy AI is public", false])
	if stage() > 0:
		out.append(["[2]  Collect profit   %d treats   (%d a day)" % [owed(), per_day()], owed() > 0])
	return out

func choose(n: int) -> void:
	if g.dialog.playing():
		return
	if n == 1 and stage() > 0:
		collect()
	elif n == 0 and stage() < STAGES.size():
		var s: Array = STAGES[stage()]
		if g.player.treats < s[1]:
			g.show_msg("Need %d treats" % s[1])
			return
		collect()  # bank profit at the old rate first
		g.player.treats -= s[1]
		state().stage = stage() + 1
		state().paid = g.territory.day()
		g.show_banner(str(s[0]).to_upper())
		g.sfx("levelup")
		if s[3] != "":
			g.dialog.play(s[3])

func collect() -> void:
	var n := owed()
	state().paid = g.territory.day()
	if n > 0:
		g.player.treats += n
		g.show_msg("+%d treats from Good Boy AI" % n)

func _process(_delta: float) -> void:
	if g.inside != "startup" or g.interior.room == null or g.player.frozen or g.act != "":
		return
	if g.player.position.distance_to(g.interior.spots.pitch) < NEAR:
		g.ctx = "startup"
		g.show_menu("GOOD BOY AI", rows())
