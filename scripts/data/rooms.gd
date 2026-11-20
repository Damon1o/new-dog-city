extends RefCounted
## Interior room templates (spec 03), built one at a time by scripts/world/interior.gd.
##   kind   what game.inside becomes ("shop" / "subway" / "boss" keep their old behavior)
##   paint  [rect, texture name or Color, tint?] drawn in order under everything
##   props  [texture, base, scale, collider size (ZERO = none), lift?]
##   spots  room-local points: exit (F leaves), start (where the dog lands), counter, board
##   door / exit  [prompt head, prompt row]; {name} / {NAME} = the door's name
##   vary   props get a seeded tint per door

const ROOMS := {
	"bodega": {
		"size": Vector2(768, 448), "kind": "shop", "tint": Color(1, 0.96, 0.88),
		"paint": [[Rect2(0, 0, 768, 448), "shop_floor"], [Rect2(0, 0, 768, 96), "shop_wall"],
			[Rect2(344, 424, 80, 24), Color(0.55, 0.15, 0.15)]],
		"props": [["shelf", Vector2(80, 130), 2.0, Vector2(96, 24)], ["shelf", Vector2(190, 130), 2.0, Vector2(96, 24)],
			["shelf", Vector2(300, 130), 2.0, Vector2(96, 24)], ["shelf", Vector2(410, 130), 2.0, Vector2(96, 24)],
			["shelf", Vector2(150, 320), 2.0, Vector2(96, 24)], ["shelf", Vector2(330, 320), 2.0, Vector2(96, 24)],
			["counter", Vector2(620, 250), 2.0, Vector2(128, 40)], ["cat", Vector2(590, 251), 2.5, Vector2.ZERO, 22.0]],
		"spots": {"exit": Vector2(384, 432), "start": Vector2(384, 380), "counter": Vector2(620, 280)},
		"door": ["BODEGA", "[F]  Go inside"], "exit": ["BODEGA", "[F]  Back to the street"],
	},
	"subway": {
		"size": Vector2(1152, 448), "kind": "subway", "tint": Color(0.8, 0.86, 0.82),
		"paint": [[Rect2(0, 0, 1152, 448), "platform"], [Rect2(0, 0, 1152, 96), "station_wall"],
			[Rect2(0, 88, 1152, 8), Color(0.15, 0.4, 0.25)], [Rect2(0, 308, 1152, 12), Color(0.82, 0.7, 0.24)],
			[Rect2(0, 320, 1152, 128), "track"]],
		"props": [["stairs", Vector2(320, 100), 2.0, Vector2.ZERO], ["map_board", Vector2(576, 84), 2.0, Vector2.ZERO],
			["pillar", Vector2(200, 296), 2.5, Vector2(20, 10)], ["pillar", Vector2(456, 296), 2.5, Vector2(20, 10)],
			["pillar", Vector2(712, 296), 2.5, Vector2(20, 10)], ["pillar", Vector2(968, 296), 2.5, Vector2(20, 10)]],
		"spots": {"exit": Vector2(320, 112), "start": Vector2(320, 172), "board": Vector2(576, 112)},
		"door": ["SUBWAY   {name}", "[F]  Take the stairs down"], "exit": ["{NAME} STATION", "[F]  Stairs up to the street"],
	},
	"burrow": {
		"size": Vector2(960, 640), "kind": "boss", "tint": Color(0.85, 0.78, 0.7),
		"paint": [[Rect2(0, 0, 960, 640), "grass", Color(1.0, 0.8, 0.55)],
			[Rect2(0, 0, 960, 96), "station_wall", Color(0.5, 0.35, 0.25)], [Rect2(440, 616, 80, 24), Color(0.1, 0.07, 0.05)]],
		"props": [],
		"spots": {"exit": Vector2(480, 624), "start": Vector2(480, 572)},
		"door": ["HEDGEHOG BURROW   final boss, 3 waves", "[F]  Challenge the Boss Hedgehog  (it keeps treats over 20 if you fall)"],
		"exit": ["HEDGEHOG DEN", "[F]  Back to the street"],
	},
	"apartment": {
		"size": Vector2(640, 384), "kind": "apartment", "tint": Color(1, 0.95, 0.9), "vary": true,
		"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(0.9, 0.8, 0.7)], [Rect2(0, 0, 640, 96), "shop_wall", Color(0.8, 0.7, 0.9)],
			[Rect2(280, 360, 80, 24), Color(0.3, 0.35, 0.6)]],
		"props": [["shelf", Vector2(100, 130), 2.0, Vector2(96, 24)], ["shelf", Vector2(540, 130), 2.0, Vector2(96, 24)],
			["water_bowl", Vector2(200, 300), 2.5, Vector2.ZERO], ["cat", Vector2(450, 280), 2.5, Vector2.ZERO]],
		"spots": {"exit": Vector2(320, 368), "start": Vector2(320, 316), "elevator": Vector2(600, 200)},
		"door": ["APARTMENTS", "[F]  Go inside"], "exit": ["APARTMENT LOBBY", "[F]  Back to the street"],
	},
	"office": {
		"size": Vector2(768, 448), "kind": "office", "tint": Color(0.95, 0.97, 1), "vary": true,
		"paint": [[Rect2(0, 0, 768, 448), "sidewalk", Color(0.8, 0.82, 0.9)], [Rect2(0, 0, 768, 96), "station_wall", Color(0.6, 0.7, 0.9)],
			[Rect2(344, 424, 80, 24), Color(0.2, 0.25, 0.35)]],
		"props": [["counter", Vector2(180, 220), 2.0, Vector2(128, 40)], ["counter", Vector2(384, 220), 2.0, Vector2(128, 40)],
			["counter", Vector2(588, 220), 2.0, Vector2(128, 40)], ["cat", Vector2(600, 330), 2.5, Vector2.ZERO]],
		"spots": {"exit": Vector2(384, 432), "start": Vector2(384, 380), "elevator": Vector2(720, 140)},
		"door": ["OFFICES   {NAME}", "[F]  Go inside"], "exit": ["OFFICE LOBBY", "[F]  Back to the street"],
	},
	# M4-2 shops (spec 03 / 09): shop_small's layout; scripts/ui/shop.gd picks the stock by template
	"gas": {
		"size": Vector2(512, 384), "kind": "shop", "tint": Color(1, 0.95, 0.85),
		"paint": [[Rect2(0, 0, 512, 384), "sidewalk"], [Rect2(0, 0, 512, 96), "shop_wall", Color(1, 0.85, 0.6)],
			[Rect2(216, 360, 80, 24), Color(0.5, 0.2, 0.1)]],
		"props": [["shelf", Vector2(80, 130), 2.0, Vector2(96, 24)], ["shelf", Vector2(190, 130), 2.0, Vector2(96, 24)],
			["counter", Vector2(400, 250), 2.0, Vector2(128, 40)]],
		"spots": {"exit": Vector2(256, 368), "start": Vector2(256, 316), "counter": Vector2(400, 280)},
		"door": ["GAS STATION", "[F]  Go inside"], "exit": ["GAS STATION", "[F]  Back to the street"],
	},
	"pizza": {
		"size": Vector2(640, 384), "kind": "shop", "tint": Color(1, 0.9, 0.8),
		"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(1, 0.85, 0.8)], [Rect2(0, 0, 640, 96), "shop_wall", Color(1, 0.6, 0.5)],
			[Rect2(280, 360, 80, 24), Color(0.6, 0.15, 0.1)]],
		"props": [["counter", Vector2(480, 250), 2.0, Vector2(128, 40)], ["counter", Vector2(150, 200), 2.0, Vector2(128, 40)]],
		"spots": {"exit": Vector2(320, 368), "start": Vector2(320, 316), "counter": Vector2(480, 280)},
		"door": ["PIZZA", "[F]  Go inside"], "exit": ["PIZZA", "[F]  Back to the street"],
	},
	"cafe": {
		"size": Vector2(640, 384), "kind": "shop", "tint": Color(0.95, 0.9, 0.85),
		"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(0.85, 0.75, 0.65)], [Rect2(0, 0, 640, 96), "shop_wall", Color(0.7, 0.55, 0.45)],
			[Rect2(280, 360, 80, 24), Color(0.3, 0.2, 0.15)]],
		"props": [["counter", Vector2(480, 250), 2.0, Vector2(128, 40)], ["cat", Vector2(150, 280), 2.5, Vector2.ZERO]],
		"spots": {"exit": Vector2(320, 368), "start": Vector2(320, 316), "counter": Vector2(480, 280)},
		"door": ["CAFE", "[F]  Go inside"], "exit": ["CAFE", "[F]  Back to the street"],
	},
	"airport": {
		"size": Vector2(1152, 448), "kind": "airport", "tint": Color(0.95, 0.97, 1),
		"paint": [[Rect2(0, 0, 1152, 448), "platform", Color(0.9, 0.92, 1)], [Rect2(0, 0, 1152, 96), "station_wall", Color(0.7, 0.8, 0.95)],
			[Rect2(536, 424, 80, 24), Color(0.2, 0.25, 0.35)]],
		"props": [["counter", Vector2(576, 200), 2.0, Vector2(128, 40)],
			["pillar", Vector2(200, 296), 2.5, Vector2(20, 10)], ["pillar", Vector2(952, 296), 2.5, Vector2(20, 10)]],
		"spots": {"exit": Vector2(576, 432), "start": Vector2(576, 380), "gates": Vector2(576, 240)},
		"door": ["AIRPORT   {NAME}", "[F]  Go inside"], "exit": ["{NAME}", "[F]  Back to the street"],
	},
	"shop_small": {
		"size": Vector2(512, 384), "kind": "shop", "tint": Color(1, 0.96, 0.88), "vary": true,
		"paint": [[Rect2(0, 0, 512, 384), "shop_floor"], [Rect2(0, 0, 512, 96), "shop_wall", Color(0.8, 0.95, 0.8)],
			[Rect2(216, 360, 80, 24), Color(0.15, 0.4, 0.25)]],
		"props": [["shelf", Vector2(80, 130), 2.0, Vector2(96, 24)], ["shelf", Vector2(190, 130), 2.0, Vector2(96, 24)],
			["shelf", Vector2(130, 290), 2.0, Vector2(96, 24)],
			["counter", Vector2(400, 250), 2.0, Vector2(128, 40)], ["cat", Vector2(370, 251), 2.5, Vector2.ZERO, 22.0]],
		"spots": {"exit": Vector2(256, 368), "start": Vector2(256, 316), "counter": Vector2(400, 280)},
		"door": ["SHOP", "[F]  Go inside"], "exit": ["SHOP", "[F]  Back to the street"],
	},
	# M4-6 pound (spec 08): no street door, wanted.caught() sends the dog here. No exit spot:
	# scripts/world/pound.gd adds the cell walls, guard and fence and lets him out.
	"pound": {
		"size": Vector2(960, 448), "kind": "pound", "tint": Color(0.85, 0.88, 0.92),
		"paint": [[Rect2(0, 0, 960, 448), "platform", Color(0.75, 0.78, 0.8)], [Rect2(0, 0, 960, 96), "station_wall", Color(0.55, 0.6, 0.65)],
			[Rect2(0, 96, 200, 164), Color(0.35, 0.33, 0.3)], [Rect2(760, 96, 200, 352), "grass", Color(0.8, 0.85, 0.7)]],
		"props": [],
		"spots": {"start": Vector2(100, 200), "cell": Vector2(100, 236), "out": Vector2(100, 300), "fence": Vector2(900, 300)},
	},
	# M5-5 flashbacks (spec 04): the sepia is the tint (game.night is a CanvasModulate); props and
	# Sam come per flashback from data/story.gd. ponytail: the far-off exit spot keeps the street
	# prompt from ever showing; scripts/world/flashback.gd walks the dog back out instead.
	"flashback_room": {
		"size": Vector2(640, 384), "kind": "flashback", "tint": Color(1.0, 0.84, 0.6),
		"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(0.8, 0.72, 0.6)], [Rect2(0, 0, 640, 96), "shop_wall", Color(0.65, 0.55, 0.42)]],
		"props": [],
		"spots": {"exit": Vector2(-9999, -9999), "start": Vector2(320, 330)},
		"door": ["MEMORY", ""], "exit": ["MEMORY", ""],
	},
	# M5-4 HQ puzzle floors (spec 04): 15 x 10 tiles of 64 px. scripts/world/hq_floor.gd draws the
	# grid and moves the exit spot onto the floor's start tile.
	"hq_floor": {
		"size": Vector2(960, 640), "kind": "hq", "tint": Color(0.95, 0.97, 1),
		"paint": [[Rect2(0, 0, 960, 640), Color(0.12, 0.13, 0.18)]],
		"props": [],
		"spots": {"start": Vector2(480, 320)},
		"door": ["HACK CLUB HQ", "[F]  Go inside"], "exit": ["HACK CLUB HQ", "[F]  Leave the floor"],
	},
}

## Generic building sprite -> its template.
const BY_BUILDING := {"building_a": "apartment", "building_b": "office", "building_c": "shop_small"}
