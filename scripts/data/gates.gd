extends RefCounted
## Story gates (spec 01 "Unlock schedule") and the main objective line. Read by the Story autoload.

## Gate id -> needs. level: dog level; keycard: city id; flag: story flag; floors: cleared floor ids;
## flags: story flags that must all be set (BOSS_NAMES names the boss behind each).
const GATES := {
	"G0": {"opens": "NYC streets"},
	"G1": {"level": 30, "flags": ["cs_raccoon_post", "cs_pigeon_post", "cs_rat_post", "cs_hedgehog_post", "ch1_boss"],
		"opens": "NYC Hack Club HQ"},  # level 30 + every NYC boss beaten
	"G2": {"flag": "ch1_clue", "opens": "Airport gate to San Francisco"},
	"G3": {"level": 50, "keycard": "sf", "opens": "SF Hack Club HQ"},
	"G4": {"flag": "ch2_clue", "opens": "Airport gate to Tokyo"},
	"G5": {"level": 60, "keycard": "tokyo", "opens": "Tokyo HQ floors 1-3"},
	"G6": {"flag": "ch3_clue", "opens": "Airport gate to Shenzhen"},
	"G7": {"level": 80, "keycard": "shenzhen", "opens": "Shenzhen HQ floors 1-3"},
	"G8": {"flag": "ch4_clue", "opens": "Tower floors T1-T4"},
	"G9": {"level": 100, "floors": ["tower_1", "tower_2", "tower_3", "tower_4"], "opens": "Tower T5 and the roof"},
}

## Beaten-boss flag -> boss name, for "Beat first: ...".
const BOSS_NAMES := {"cs_raccoon_post": "King of Raccoons", "cs_pigeon_post": "The Pideon Queen",
	"cs_rat_post": "The Rat Meister", "cs_hedgehog_post": "Daven the Hedgehog", "ch1_boss": "Fat Cat"}

## City id -> the gate on its Hack Club HQ door.
const HQ_GATE := {"nyc": "G1", "sf": "G3", "tokyo": "G5", "shenzhen": "G7"}

## City id -> [name, boss that drops its HQ keycard].
const CITIES := {"nyc": ["NYC", "Fat Cat"], "sf": ["SF", "Seagull King"],
	"tokyo": ["Tokyo", "Claw King"], "shenzhen": ["Shenzhen", "Mecha-Cat"]}

## Airport gates (spec 02 City travel): [city id, gate id ("" = always open), locked hint].
const AIRPORT := [["nyc", "", ""], ["sf", "G2", "Find the next clue at the NYC Hack Club HQ"],
	["tokyo", "G4", "Find the next clue at the SF Hack Club HQ"],
	["shenzhen", "G6", "Find the next clue at the Tokyo Hack Club HQ"]]

## Main story line, in order: [flag that ends the step, objective text, story spot id].
## objective() shows the first step whose flag is not set yet.
const OBJECTIVES := [
	["ch1_bodega", "Find Sam's things at the bodega", "bodega"],
	["ch1_boss", "Beat the Fat Cat at the NYSE", "nyse"],
	["ch1_clue", "Reach level 30, beat every NYC boss, enter the Hack Club HQ", "hq_nyc"],
	["ch2_boss", "Beat the Seagull King at the pier", "sf_pier"],
	["ch2_clue", "Reach level 50 and enter the SF Hack Club HQ", "hq_sf"],
	["ch3_boss", "Beat the Claw King in the arcade", "tokyo_arcade"],
	["ch3_clue", "Reach level 60 and climb the Tokyo HQ", "hq_tokyo"],
	["ch4_boss", "Beat the Mecha-Cat", "shenzhen_market"],
	["ch4_clue", "Reach level 80 and climb the Shenzhen HQ", "hq_shenzhen"],
	["ending", "Climb the Tower and find Sam", "hq_nyc"],
]
