extends RefCounted
## Wardrobe items (spec 05) and their pixel art. Hats / collars / outfits are child Sprite2Ds of
## the dog sprite ("Gear" node), drawn here from string grids so no asset files are needed.
## The breed is fixed per dog (no skin swapping). Armor (data/items.gd ARMOR) is drawn here too,
## slot "armor", layered over the outfit; it's worn from the bag, so it has no wardrobe tab.

const SLOTS := {"collar": "Collar", "hat": "Hat", "overlay": "Outfit"}
## id -> name, slot, start (owned from the start), cost [n, "treats" | "bones"] (buyable here),
## hint (how to unlock), at (top-left in dog-frame px; the frame is 16 x 10), art rows.
const ITEMS := {
	"name": {"name": "Name collar", "slot": "collar", "hint": "Bodega, 25 treats", "at": Vector2(9, 3),
		"art": ["RR", "RR", "YY"]},
	"lanyard": {"name": "Sam's lanyard", "slot": "collar", "start": true, "at": Vector2(9, 3),
		"art": ["B.", "B.", "BW"]},
	"lucky_paw": {"name": "Lucky Paw", "slot": "collar", "hint": "Find 8 Maneki Neko statues", "at": Vector2(9, 3),
		"art": ["YY", "YY", "RY"]},
	"spiked": {"name": "Spiked collar", "slot": "collar", "hint": "Sold by the trader, 4 bones", "at": Vector2(9, 3),
		"art": ["KW", "KK", "KW"]},
	"bell": {"name": "Bell collar", "slot": "collar", "hint": "A bodega cat at 5 hearts", "at": Vector2(9, 3),
		"art": ["BB", "BB", "YY"]},
	"bodega_cap": {"name": "Bodega cap", "slot": "hat", "cost": [40, "treats"], "at": Vector2(8, -2),
		"art": [".RRRR..", "RRRRRRR"]},
	"beanie": {"name": "Beanie", "slot": "hat", "hint": "Top Dog of NYC", "at": Vector2(9, -2),
		"art": ["..W..", "BBBBB"]},
	"fog_lamp": {"name": "Fog lamp hat", "slot": "hat", "hint": "Top Dog of San Francisco", "at": Vector2(9, -3),
		"art": ["..Y..", ".KKK.", "KKKKK"]},
	"sailor": {"name": "Sailor hat", "slot": "hat", "hint": "Dropped by the Seagull King", "at": Vector2(9, -2),
		"art": [".WWW.", "WBBBW"]},
	"rain_hood": {"name": "Rain hood", "slot": "hat", "hint": "Top Dog of Tokyo", "at": Vector2(8, -1),
		"art": [".YYYY.", "YY..YY"]},
	"bandana": {"name": "Thick Bandana", "slot": "armor", "at": Vector2(9, 5),
		"art": ["RWRR", "RRWR", ".RR.", "..R."]},
	"vest": {"name": "Padded Vest", "slot": "armor", "at": Vector2(4, 3),
		"art": ["OOOOOO", "ODOODO", "OOOOOO", "DDDDDD"]},
	"kevlar": {"name": "K9 Kevlar", "slot": "armor", "at": Vector2(3, 3),
		"art": ["NNNNNNA", "NYYNNNA", "NNNNNNA", "ANNNNNA"]},
	"hoodie": {"name": "Sam's hoodie", "slot": "overlay", "start": true, "at": Vector2(3, 3),
		"art": ["GGGGGGGGG", ".GGGGGGGG", ".GHHHHHHG", "GGGGGGGGG"]},
}
const PAL := {"R": Color(0.85, 0.2, 0.2), "Y": Color(0.95, 0.8, 0.25), "B": Color(0.25, 0.4, 0.85),
	"W": Color(0.95, 0.95, 0.95), "K": Color(0.2, 0.2, 0.22), "G": Color(0.35, 0.38, 0.42),
	"H": Color(0.55, 0.58, 0.62), "O": Color(0.82, 0.52, 0.22), "D": Color(0.55, 0.32, 0.14),
	"N": Color(0.2, 0.24, 0.32), "A": Color(0.45, 0.5, 0.42)}
## ponytail: every breed shares one DOG grid (tools/gen_assets.py), so these are all zero;
## nudge a breed here if its art ever changes.
const OFFSET := {"pug": Vector2.ZERO, "husky": Vector2.ZERO, "chihuahua": Vector2.ZERO,
	"great_dane": Vector2.ZERO, "mastiff": Vector2.ZERO}

static var cache := {}

static func icon(id: String) -> Texture2D:
	if not ITEMS.has(id):
		return null
	if not cache.has(id):
		var rows: Array = ITEMS[id].art
		var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				img.set_pixel(x, y, PAL.get(rows[y][x], Color(0, 0, 0, 0)))
		cache[id] = ImageTexture.create_from_image(img)
	return cache[id]

## Equipped items plus worn armor, minus the name collar while the dog has no name (`extra` = game.save_extra).
static func worn(extra: Variant, collar: String, armor := "") -> Dictionary:
	var eq: Dictionary = (extra.get("wardrobe/equipped", {"collar": "name"}) if extra is Dictionary else {}).duplicate()
	if eq.get("collar", "name") == "name" and collar == "":
		eq.collar = ""
	eq.armor = armor
	return eq

## Put the worn collar / hat / overlay on `sprite` (the dog's Sprite2D, frames centered).
static func dress(sprite: Sprite2D, breed_file: String, eq: Dictionary) -> void:
	var gear: Node2D = sprite.get_node_or_null("Gear")
	if gear == null:
		gear = Node2D.new()
		gear.name = "Gear"
		sprite.add_child(gear)
	for ch in gear.get_children():
		ch.free()
	for slot in ["overlay", "armor", "collar", "hat"]:
		var id: String = eq.get(slot, "")
		if ITEMS.has(id):
			var s := Sprite2D.new()
			s.texture = icon(id)
			s.centered = false
			s.position = ITEMS[id].at - Vector2(8, 5) + OFFSET.get(breed_file, Vector2.ZERO)
			gear.add_child(s)
	flip(sprite)

## flip_h doesn't reach children, so mirror the Gear node with the sprite.
static func flip(sprite: Sprite2D) -> void:
	var gear: Node2D = sprite.get_node_or_null("Gear")
	if gear:
		gear.scale.x = -1.0 if sprite.flip_h else 1.0
