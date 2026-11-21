extends RefCounted
## Park bosses (boss.gd reads each entry as cfg). intro / outro: data/story.gd cutscenes, once per save.

# One boss per park (index into PARKS; park 0 is the dog's spawn). special: see boss.gd.
const BOSSES := [
	{"name": "King of Raccoons", "tex": "raccoon", "intro": "cs_raccoon_pre", "outro": "cs_raccoon_post", "park": 3, "level": 6, "hp": 260.0, "speed": 150.0, "dmg": 14.0,
		"specials": ["charge", "trash_rain", "slam", "goons"], "tint": Color(1, 0.85, 0.4), "treats": 40, "xp": 150},
	{"name": "The Pideon Queen", "tex": "pigeon", "intro": "cs_pigeon_pre", "outro": "cs_pigeon_post", "park": 1, "level": 8, "hp": 180.0, "speed": 175.0, "dmg": 9.0,
		"specials": ["feathers", "droppings", "dive", "storm"], "tint": Color(1, 0.6, 0.9), "treats": 30, "xp": 120},
	{"name": "The Rat Meister", "tex": "rat", "intro": "cs_rat_pre", "outro": "cs_rat_post", "park": 2, "level": 10, "hp": 220.0, "speed": 135.0, "dmg": 11.0,
		"specials": ["rats", "sewer", "burrow", "pack"], "tint": Color(0.6, 1, 0.5), "treats": 35, "xp": 135},
]

# M5-7 story boss (spec 06 Fat Cat): lives in the NYSE room, not a park; scripts/world/nyse_arena.gd
# spawns it. `phases` swaps the special list once hp falls below each `at` (fraction of max hp).
# bones/keycard/flag/shock/post are one-time drops (boss.gd drop()); a story boss never respawns.
const FAT_CAT := {"name": "Fat Cat", "tex": "cat", "level": 20, "hp": 300.0, "speed": 140.0, "dmg": 12.0,
	"specials": ["coin_fan", "briefcase_charge"], "tint": Color(1, 0.82, 0.3), "treats": 103, "xp": 200,  # treats x2.9 at Lv 20 = 300
	"aggro": 0.0, "leash": 5000.0,  # the bell podium wakes him; leaving the room ends the fight
	"phases": [{"at": 1.0, "specials": ["coin_fan", "briefcase_charge"], "speed_mult": 1.0},
		{"at": 0.6, "specials": ["margin_call", "ticker_wave", "coin_fan"], "speed_mult": 1.15},
		{"at": 0.3, "specials": ["golden_parachute", "coin_fan", "ticker_wave"], "speed_mult": 1.3}],
	"bones": 5, "keycard": "nyc", "flag": "ch1_boss", "post": "cs_fatcat_post", "shock": ["PURR", -0.4, "Fat Cat ousted!"]}
