extends RefCounted
## Prey and shop tables.

const PREY := {
	"pigeon": {"speed": 120.0, "flee": 150.0, "treats": 2, "xp": 8, "food": 8.0},
	"rat": {"speed": 105.0, "flee": 110.0, "treats": 1, "xp": 5, "food": 5.0},
	"squirrel": {"speed": 150.0, "flee": 190.0, "treats": 4, "xp": 14, "food": 10.0},
}

const SHOP := [["purina", 5], ["water", 3], ["collar", 25]]
## Stock per shop template (spec 09 base prices, NYC). Bodegas / shop_small sell SHOP.
const SHOPS := {"bodega": SHOP, "shop_small": SHOP,
	"gas": [["water", 2], ["hotdog", 4], ["jerky", 6]],
	"pizza": [["pizza", 4], ["pepperoni", 6]],
	"cafe": [["puppuccino", 5], ["barkbrew", 6]]}
## Eaten on the spot: food gained.
const FOOD := {"hotdog": 35.0, "pizza": 30.0, "pepperoni": 30.0}
## Item -> [slot, seconds, {stat: multiplier}]. One food and one drink buff at a time (spec 09).
const BUFFS := {"pizza": ["food", 60.0, {"speed": 1.15}], "pepperoni": ["food", 60.0, {"damage": 1.1}],
	"jerky": ["food", 120.0, {"thirst": 0.5}],
	"puppuccino": ["drink", 120.0, {"stamina": 1.5}], "barkbrew": ["drink", 120.0, {"bark_cd": 0.5}]}
## Shop rows (spec 11 Shop): display name, effect line, icon (game.tex key, "" = none).
const ITEM_INFO := {
	"purina": {"name": "Purina", "effect": "+50 food, +40 HP", "icon": "purina"},
	"water": {"name": "Water", "effect": "+60 thirst", "icon": "water_bowl"},
	"collar": {"name": "Name Collar", "effect": "rename your dog", "icon": ""},
	"hotdog": {"name": "Hot Dog", "effect": "+35 food", "icon": ""},
	"jerky": {"name": "Jerky", "effect": "thirst drain -50% for 120 s", "icon": ""},
	"pizza": {"name": "Pizza Slice", "effect": "+30 food, Carb Rush +15% speed 60 s", "icon": ""},
	"pepperoni": {"name": "Pepperoni Slice", "effect": "+30 food, +10% damage 60 s", "icon": ""},
	"puppuccino": {"name": "Puppuccino", "effect": "stamina regen +50% 120 s", "icon": ""},
	"barkbrew": {"name": "Bark Brew", "effect": "bark cooldown -50% 120 s", "icon": ""},
}
const SHOP_INFO :={"purina": "Purina  (+50 food, +40 HP)", "water": "Water  (+60 thirst)", "collar": "Name Collar"}
