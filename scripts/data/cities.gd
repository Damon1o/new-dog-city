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
			Vector2i(1, 5): "nyse"},  # first door of a generic block
		"airport": Vector2i(8, 6),  # last block built, so it shifts no earlier random rolls
		"stations": {Vector2i(4, 0): "Uptown", Vector2i(2, 1): "Midtown",
			Vector2i(1, 4): "Downtown", Vector2i(5, 2): "East Side"},
	},
}
