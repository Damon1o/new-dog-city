extends RefCounted
## Save / load the one save slot (ConfigFile at game.save_path). Every read has a default,
## so older saves load as-is.

const KEYS := ["level", "xp", "treats", "skin", "purina", "water", "collar", "hunger", "thirst",
	"points", "stat_hp", "stat_atk", "stat_spd"]

static func write(g: Node) -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("dog", key, g.player.get(key))
	cfg.set_value("world", "seen", g.landmarks.filter(func(l): return l.seen).map(func(l): return l.name))
	cfg.set_value("ui", "volume", g.volume.value)
	cfg.set_value("quests", "stats", g.stats)
	cfg.set_value("quests", "step", g.quest_step)
	cfg.save(g.save_path)

static func read(g: Node) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(g.save_path) != OK:
		return
	var player: Node = g.player
	for key in KEYS:
		player.set(key, cfg.get_value("dog", key, player.get(key)))
	if not cfg.has_section_key("dog", "points"):
		player.points = player.level - 1  # save from before stat points: pay them out now
	player.skin = clampi(player.skin, 0, player.BREEDS.size() - 1)
	player.level = clampi(player.level, 1, 100)
	g.volume.value = cfg.get_value("ui", "volume", 1.0)
	var seen: Array = cfg.get_value("world", "seen", [])
	for l in g.landmarks:
		l.seen = l.name in seen
	g.stats = cfg.get_value("quests", "stats", {})
	g.quest_step = cfg.get_value("quests", "step", {})
	g.stats.sights = maxi(g.stat("sights"), seen.size())  # saves from before quests existed
	player.apply_skin()
	player.hp = player.max_hp
