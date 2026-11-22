extends RefCounted
## City table (spec 02 "City data"). city_builder.gd builds a city from its entry.
## Landmarks sit on fixed block coords so saves, quests and subway stops stay valid.

const CITIES := {
	"nyc": {
		"name": "New York",
		"seed": 20261115,  # fixed layout (the old CITY_SEED)
		"grid": Vector2i(9, 7),
		"block": Vector2(512, 384),
		"parks": [Vector2i(2, 2), Vector2i(5, 0), Vector2i(0, 3), Vector2i(4, 4), Vector2i(7, 5)],
		"dog_park": 0,  # index into parks (spec 03): safe zone + quest dogs; the spawn park, no boss on it
		"bodegas": [Vector2i(3, 2), Vector2i(0, 0), Vector2i(5, 3), Vector2i(7, 1), Vector2i(2, 6)],
		"landmarks": {Vector2i(3, 1): ["empire_state", "Empire State Building"],
			Vector2i(1, 1): ["chrysler", "Chrysler Building"]},
		"shops": {Vector2i(6, 2): "cafe", Vector2i(1, 2): "pizza", Vector2i(8, 3): "gas",
			Vector2i(6, 4): "hq",  # M5-6 Hack Club HQ
			Vector2i(1, 5): "nyse"},  # first door of a generic block
		"airport": Vector2i(8, 6),  # last block built, so it shifts no earlier random rolls
		"airport_name": "JFK Airport",
		"stations": {Vector2i(4, 0): "Uptown", Vector2i(2, 1): "Midtown",
			Vector2i(1, 4): "Downtown", Vector2i(5, 2): "East Side"},
	},
	# M6-1 Ch 2. ponytail: same 9 x 7 grid as NYC (spec says 8 x 7) so WORLD / NX / NY stay consts;
	# hill slowdown skipped until hill tiles exist. Pier (Seagull King) comes with M6-4.
	"sf": {
		"name": "San Francisco",
		"seed": 20261116,
		"grid": Vector2i(9, 7),
		"block": Vector2(512, 384),
		"tint": Color(1.0, 0.93, 0.97),  # pastel facades (city root modulate)
		"ground_tint": Color(0.84, 0.9, 1.0),  # blue-grey ground
		"parks": [Vector2i(1, 1), Vector2i(6, 1), Vector2i(3, 4), Vector2i(0, 6), Vector2i(7, 4)],
		"dog_park": 0,
		"bodegas": [Vector2i(2, 0), Vector2i(5, 5), Vector2i(8, 2)],  # the 3 corner stores
		"landmarks": {Vector2i(4, 2): ["transamerica", "Transamerica Pyramid"],
			Vector2i(6, 5): ["coit_tower", "Coit Tower"]},
		"shops": {Vector2i(0, 2): "cafe", Vector2i(3, 6): "pizza", Vector2i(7, 0): "gas",
			Vector2i(5, 3): "hq"},  # SF Hack Club HQ
		"airport": Vector2i(8, 6),
		"airport_name": "SFO Airport",
		"stations": {Vector2i(1, 0): "Powell St", Vector2i(4, 1): "Nob Hill",
			Vector2i(2, 5): "Mission", Vector2i(7, 3): "Fisherman's Wharf"},  # cable car stops
	},
}
