extends RefCounted
## Park bosses (boss.gd reads each entry as cfg).

# One boss per park (index into PARKS; park 0 is the dog's spawn). special: see boss.gd.
const BOSSES := [
	{"name": "King of Raccoons", "tex": "raccoon", "park": 3, "level": 6, "hp": 260.0, "speed": 150.0, "dmg": 14.0,
		"specials": ["charge", "slam"], "tint": Color(1, 0.85, 0.4), "treats": 40, "xp": 150},
	{"name": "The Pideon Queen", "tex": "pigeon", "park": 1, "level": 8, "hp": 180.0, "speed": 175.0, "dmg": 9.0,
		"specials": ["feathers", "storm"], "tint": Color(1, 0.6, 0.9), "treats": 30, "xp": 120},
	{"name": "The Rat Meister", "tex": "rat", "park": 2, "level": 10, "hp": 220.0, "speed": 135.0, "dmg": 11.0,
		"specials": ["rats", "burrow"], "tint": Color(0.6, 1, 0.5), "treats": 35, "xp": 135},
]
