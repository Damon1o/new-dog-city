extends RefCounted
## Quest tracking. State lives on game (stats, quest_step) so save and tests see it there.

const QUESTS := preload("res://scripts/data/quests.gd").QUESTS

## Count a quest event; once = only the first time ever (tutorial flags).
static func bump(g: Node, key: String, once := false) -> void:
	if once and g.stats.has(key):
		return
	g.stats[key] = int(g.stats.get(key, 0)) + 1
	check(g)

static func stat(g: Node, key: String) -> int:
	return g.player.level if key == "level" else int(g.stats.get(key, 0))

static func tutorial_on(g: Node) -> bool:
	return int(g.quest_step.get("Tutorial", 0)) < QUESTS.Tutorial.size()

static func check(g: Node) -> void:
	for line: String in QUESTS:
		var steps: Array = QUESTS[line]
		while int(g.quest_step.get(line, 0)) < steps.size():
			var i := int(g.quest_step.get(line, 0))
			var s: Array = steps[i]
			if stat(g, s[1]) < int(s[2]):
				break
			g.quest_step[line] = i + 1  # advance first: the xp below can level up and re-enter
			g.player.treats += int(s[3])
			g.sfx("pickup")
			g.show_msg("%s: %s  -  done!  +%d treats  +%d XP" % [line, str(s[0]).replace("\n", " "), s[3], s[4]])
			if i + 1 == steps.size():
				g.show_banner("%s COMPLETE" % line.to_upper())
			g.player.add_xp(int(s[4]))

## Tracker text: the tutorial on its own until it is finished, then every other line.
static func text(g: Node) -> String:
	var out := PackedStringArray()
	for line: String in QUESTS:
		if (line == "Tutorial") != tutorial_on(g):
			continue
		var steps: Array = QUESTS[line]
		var i := int(g.quest_step.get(line, 0))
		if i >= steps.size():
			out.append("%s  -  complete" % line.to_upper())
			continue
		var s: Array = steps[i]
		var count := "  (%d/%d)" % [mini(stat(g, s[1]), s[2]), s[2]] if int(s[2]) > 1 else ""
		out.append("%s  %d/%d\n%s%s" % [line.to_upper(), i + 1, steps.size(), s[0], count])
	return "\n\n".join(out)
