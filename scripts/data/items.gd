extends RefCounted
## Prey and shop tables.

const PREY := {
	"pigeon": {"speed": 120.0, "flee": 150.0, "treats": 2, "xp": 8, "food": 8.0},
	"rat": {"speed": 105.0, "flee": 110.0, "treats": 1, "xp": 5, "food": 5.0},
	"squirrel": {"speed": 150.0, "flee": 190.0, "treats": 4, "xp": 14, "food": 10.0},
}

const SHOP := [["purina", 5], ["water", 3], ["collar", 25]]
const SHOP_INFO := {"purina": "Purina  (+50 food, +40 HP)", "water": "Water  (+60 thirst)", "collar": "Name Collar"}
