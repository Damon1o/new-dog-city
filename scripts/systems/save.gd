extends RefCounted
## Save / load the one save slot (ConfigFile at game.save_path). Every read has a default,
## so older saves load as-is.

const KEYS := ["level", "xp", "treats", "skin", "purina", "water", "collar", "hunger", "thirst",
	"points", "stat_hp", "stat_atk", "stat_spd", "armor", "armor_owned", "bag"]
const VERSION := 2
## Schema v2 keys ("section/key" -> default). Keys no system owns yet round-trip through
## game.save_extra; "story/*" keys belong to the Story autoload (Story.to_save / from_save).
const V2 := {
	"meta/rebirths": 0, "meta/true_ending": false,
	"dog/buffs": {},
	"world/city": "nyc", "world/tod": 0.33, "world/day": 1, "world/weather": {},
	"story/flags": [], "story/items": [], "story/keycards": [], "story/floors": {},
	"cats/points": {}, "cats/today": {},
	"trader/visit": {}, "trader/hinted": [],
	"territory/markers": [], "territory/rep": {},
	"wardrobe/owned": [], "wardrobe/equipped": {"collar": "name", "hat": "", "overlay": ""},
	"stocks/prices": {}, "stocks/history": {}, "stocks/held": {},
	"startup/state": {},
	"ui/reduce_motion": false, "ui/large_text": false, "ui/hotbar": ["purina", "water", "", ""], "ui/keys": {},
}
const VOLS := {"Music": "vol_music", "SFX": "vol_sfx", "Ambience": "vol_amb"}

static func write(g: Node) -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("dog", key, g.player.get(key))
	cfg.set_value("world", "pos", street_pos(g))
	cfg.set_value("dog", "bones", g.economy.bones)
	cfg.set_value("world", "seen", g.landmarks.filter(func(l): return l.seen).map(func(l): return l.name))
	cfg.set_value("ui", "volume", g.volume.value)
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("dog", "stats_v", 2)
	for bus in VOLS:
		cfg.set_value("ui", VOLS[bus], g.vols[bus].value)
	var owned: Dictionary = Story.to_save()
	for k: String in V2:
		var sk := k.split("/")
		cfg.set_value(sk[0], sk[1], owned[k] if owned.has(k) else g.save_extra.get(k, V2[k]))
	cfg.set_value("quests", "stats", g.stats)
	cfg.set_value("quests", "step", g.quest_step)
	cfg.save(g.save_path)

static func read(g: Node) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(g.save_path) != OK:
		Story.reset()
		return
	var player: Node = g.player
	for key in KEYS:
		player.set(key, cfg.get_value("dog", key, player.get(key)))
	if not cfg.has_section_key("dog", "points"):
		player.points = player.level - 1  # save from before stat points: pay them out now
	if not cfg.has_section_key("dog", "stats_v"):  # 1-point levels: refund as 3 smaller points per level
		player.points = (player.level - 1) * player.XP.POINTS_PER_LEVEL
		for st: Array in player.STATS:
			player.set(st[0], 0)
	if not player.Items.ARMOR.has(player.armor):
		player.armor = ""
	player.armor_owned = player.armor_owned.filter(func(a): return player.Items.ARMOR.has(a))
	g.economy.bones = maxi(int(cfg.get_value("dog", "bones", 0)), 0)
	player.skin = clampi(player.skin, 0, player.BREEDS.size() - 1)
	player.level = clampi(player.level, 1, 100)
	g.volume.value = cfg.get_value("ui", "volume", 1.0)
	g.save_version = cfg.get_value("meta", "version", 1)
	for bus in VOLS:
		g.vols[bus].value = cfg.get_value("ui", VOLS[bus], 1.0)
	g.save_extra = {}
	for k: String in V2:
		var sk := k.split("/")
		var d: Variant = V2[k]
		g.save_extra[k] = cfg.get_value(sk[0], sk[1], d.duplicate(true) if d is Dictionary or d is Array else d)
	var city_id: String = str(g.save_extra["world/city"])
	if not g.city.CITIES.has(city_id):
		city_id = "nyc"
	if city_id != g.city.id:  # M6-1: saved in another city
		g.city.build(city_id)
		g.spawn_park_bosses()
		var port: Array = g.doors.filter(func(d): return d.template == "airport")
		if port:
			g.player.position = g.city.fix_pos(port[0].pos + Vector2(0, 60))
			g.player.spawn_point = g.player.position
	var pos: Variant = cfg.get_value("world", "pos", false)
	if pos is Vector2 and g.inside == "":  # no pos (v1 save): stay at the park spawn
		g.player.position = g.city.fix_pos(pos)
	Story.from_save(g.save_extra)
	for k: String in Story.to_save():
		g.save_extra.erase(k)
	var seen: Array = cfg.get_value("world", "seen", [])
	for l in g.landmarks:
		l.seen = l.name in seen
	g.stats = cfg.get_value("quests", "stats", {})
	g.quest_step = cfg.get_value("quests", "step", {})
	g.stats.sights = maxi(g.stat("sights"), seen.size())  # saves from before quests existed
	player.apply_skin()
	player.hp = player.max_hp

## world/pos: the street spot, or indoors the door the dog went in through.
static func street_pos(g: Node) -> Vector2:
	return g.return_pos if g.inside != "" else g.player.position
