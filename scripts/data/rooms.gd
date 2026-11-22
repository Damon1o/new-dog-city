extends RefCounted
## Interior room templates (spec 03), built one at a time by scripts/world/interior.gd.
##   kind   what game.inside becomes ("shop" / "subway" / "boss" keep their old behavior)
##   paint  [rect, texture name or Color, tint?] drawn in order under everything
##   props  [texture, base, scale, collider size (ZERO = none), lift?]
##   spots  room-local points: exit (F leaves), start (where the dog lands), counter, board
##   door / exit  [prompt head, prompt row]; {name} / {NAME} = the door's name
##   vary   props get a seeded tint per door
##   upper  floors above the lobby: {paint, props, units (x of numbered unit doors on the back wall)}
##   An "elevator" spot gets elevator doors drawn in the back wall above it (scripts/world/interior.gd).

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
		"size": Vector2(1152, 448), "kind": "subway", "tint": Color(0.88, 0.9, 0.86),
		"paint": [[Rect2(0, 0, 1152, 448), "subway_floor"], [Rect2(0, 0, 1152, 96), "subway_wall"],
			[Rect2(0, 92, 1152, 4), Color(0.08, 0.1, 0.09)], [Rect2(0, 96, 1152, 10), Color(0, 0, 0, 0.18)],
			[Rect2(0, 304, 1152, 16), "platform_edge"], [Rect2(0, 320, 1152, 128), "track"],
			[Rect2(0, 320, 56, 128), Color(0, 0, 0, 0.6)], [Rect2(1096, 320, 56, 128), Color(0, 0, 0, 0.6)]],  # tunnel mouths
		"props": [["stairs", Vector2(320, 100), 1.0, Vector2.ZERO], ["map_board", Vector2(576, 84), 1.0, Vector2.ZERO],
			["subway_ad_0", Vector2(140, 92), 1.0, Vector2.ZERO], ["subway_ad_1", Vector2(800, 92), 1.0, Vector2.ZERO],
			["subway_ad_2", Vector2(1010, 92), 1.0, Vector2.ZERO],
			["bench", Vector2(800, 132), 1.0, Vector2(64, 10)], ["bench", Vector2(1010, 132), 1.0, Vector2(64, 10)],
			["subway_column", Vector2(200, 296), 1.25, Vector2(20, 10)], ["subway_column", Vector2(456, 296), 1.25, Vector2(20, 10)],
			["subway_column", Vector2(712, 296), 1.25, Vector2(20, 10)], ["subway_column", Vector2(968, 296), 1.25, Vector2(20, 10)]],
		"spots": {"exit": Vector2(320, 112), "start": Vector2(320, 172), "board": Vector2(576, 112)},
		"door": ["SUBWAY   {name}", "[F]  Take the stairs down"], "exit": ["{NAME} STATION", "[F]  Stairs up to the street"],
	},
	"burrow": {
		"size": Vector2(960, 640), "kind": "boss", "tint": Color(0.85, 0.78, 0.7),
		"paint": [[Rect2(0, 0, 960, 640), "grass", Color(1.0, 0.8, 0.55)],
			[Rect2(0, 0, 960, 96), "station_wall", Color(0.5, 0.35, 0.25)], [Rect2(440, 616, 80, 24), Color(0.1, 0.07, 0.05)]],
		"props": [],
		"spots": {"exit": Vector2(480, 624), "start": Vector2(480, 572)},
		"door": ["HEDGEHOG BURROW   final boss, 3 waves", "[F]  Challenge Daven the Hedgehog  (it keeps treats over 20 if you fall)"],
		"exit": ["HEDGEHOG DEN", "[F]  Back to the street"],
	},
	"apartment": {
		"size": Vector2(640, 384), "kind": "apartment", "tint": Color(1, 0.95, 0.9), "vary": true,
		"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(0.9, 0.8, 0.7)], [Rect2(0, 0, 640, 96), "shop_wall", Color(0.8, 0.7, 0.9)],
			[Rect2(280, 360, 80, 24), Color(0.3, 0.35, 0.6)], [Rect2(220, 190, 200, 110), Color(0.45, 0.22, 0.28, 0.7)],
			[Rect2(232, 202, 176, 86), Color(0.6, 0.35, 0.3, 0.5)]],
		"props": [["shelf", Vector2(90, 130), 2.0, Vector2(96, 24)], ["shelf", Vector2(210, 130), 2.0, Vector2(96, 24)],
			["water_bowl", Vector2(140, 300), 1.25, Vector2.ZERO], ["cat", Vector2(450, 280), 2.5, Vector2.ZERO]],
		"spots": {"exit": Vector2(320, 368), "start": Vector2(320, 316), "elevator": Vector2(540, 130)},
		"upper": {
			"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(0.78, 0.62, 0.55)], [Rect2(0, 0, 640, 96), "shop_wall", Color(0.88, 0.82, 0.7)],
				[Rect2(20, 150, 470, 56), Color(0.5, 0.18, 0.2, 0.85)], [Rect2(20, 158, 470, 4), Color(0.85, 0.7, 0.3, 0.8)],
				[Rect2(20, 194, 470, 4), Color(0.85, 0.7, 0.3, 0.8)]],
			"props": [["water_bowl", Vector2(120, 320), 1.25, Vector2.ZERO], ["shelf", Vector2(300, 340), 2.0, Vector2(96, 24)],
				["cat", Vector2(440, 300), 2.5, Vector2.ZERO]],
			"units": [70, 170, 270, 370],
		},
		"door": ["APARTMENTS", "[F]  Go inside"], "exit": ["APARTMENT LOBBY", "[F]  Back to the street"],
	},
	"office": {
		"size": Vector2(768, 448), "kind": "office", "tint": Color(0.95, 0.97, 1), "vary": true,
		"paint": [[Rect2(0, 0, 768, 448), "sidewalk", Color(0.8, 0.82, 0.9)], [Rect2(0, 0, 768, 96), "station_wall", Color(0.6, 0.7, 0.9)],
			[Rect2(344, 424, 80, 24), Color(0.2, 0.25, 0.35)]],
		"props": [["counter", Vector2(180, 220), 2.0, Vector2(128, 40)], ["counter", Vector2(384, 220), 2.0, Vector2(128, 40)],
			["counter", Vector2(588, 220), 2.0, Vector2(128, 40)], ["cat", Vector2(600, 330), 2.5, Vector2.ZERO],
			["map_board", Vector2(200, 84), 1.0, Vector2.ZERO], ["pillar", Vector2(90, 410), 2.5, Vector2(20, 10)],
			["pillar", Vector2(678, 410), 2.5, Vector2(20, 10)]],
		"spots": {"exit": Vector2(384, 432), "start": Vector2(384, 380), "elevator": Vector2(720, 140)},
		"upper": {
			"paint": [[Rect2(0, 0, 768, 448), "sidewalk", Color(0.72, 0.76, 0.84)], [Rect2(0, 0, 768, 96), "station_wall", Color(0.55, 0.6, 0.78)],
				[Rect2(50, 150, 580, 270), Color(0.3, 0.36, 0.48, 0.55)]],
			"props": [["counter", Vector2(140, 210), 1.5, Vector2(96, 30)], ["counter", Vector2(330, 210), 1.5, Vector2(96, 30)],
				["counter", Vector2(520, 210), 1.5, Vector2(96, 30)], ["counter", Vector2(140, 350), 1.5, Vector2(96, 30)],
				["counter", Vector2(330, 350), 1.5, Vector2(96, 30)], ["counter", Vector2(520, 350), 1.5, Vector2(96, 30)],
				["map_board", Vector2(330, 84), 1.0, Vector2.ZERO], ["shelf", Vector2(80, 120), 2.0, Vector2(96, 24)],
				["pillar", Vector2(690, 410), 2.5, Vector2(20, 10)]],
		},
		"door": ["OFFICES   {NAME}", "[F]  Go inside"], "exit": ["OFFICE LOBBY", "[F]  Back to the street"],
	},
	# M4-2 shops (spec 03 / 09): shop_small's layout; scripts/ui/shop.gd picks the stock by template
	"gas": {
		"size": Vector2(512, 384), "kind": "shop", "tint": Color(1, 0.97, 0.92),
		"paint": [[Rect2(0, 0, 512, 384), "gas_floor"], [Rect2(0, 0, 512, 96), "gas_wall"],
			[Rect2(216, 360, 80, 24), Color(0.15, 0.3, 0.55)]],
		"props": [["price_board", Vector2(300, 92), 2.0, Vector2.ZERO], ["cooler", Vector2(60, 165), 2.0, Vector2(96, 30)],
			["cooler", Vector2(160, 165), 2.0, Vector2(96, 30)], ["snack_rack", Vector2(80, 300), 2.0, Vector2(76, 24)],
			["snack_rack", Vector2(180, 300), 2.0, Vector2(76, 24)], ["gas_counter", Vector2(400, 250), 2.0, Vector2(128, 40)],
			["trashcan", Vector2(470, 360), 1.0, Vector2(24, 12)]],
	"spots": {"exit": Vector2(256, 368), "start": Vector2(256, 316), "counter": Vector2(400, 280)},
		"door": ["GAS STATION", "[F]  Go inside"], "exit": ["GAS STATION", "[F]  Back to the street"],
	},
	"pizza": {
		"size": Vector2(640, 384), "kind": "shop", "tint": Color(1, 0.95, 0.9),
		"paint": [[Rect2(0, 0, 640, 384), "pizza_floor"], [Rect2(0, 0, 640, 96), "pizza_wall"],
			[Rect2(280, 360, 80, 24), Color(0.6, 0.15, 0.1)]],
		"props": [["pizza_sign", Vector2(240, 90), 2.0, Vector2.ZERO], ["pizza_oven", Vector2(570, 150), 2.0, Vector2(110, 30)],
			["pizza_counter", Vector2(480, 250), 2.0, Vector2(128, 40)], ["pizza_table", Vector2(100, 190), 2.0, Vector2(64, 24)],
			["pizza_table", Vector2(240, 190), 2.0, Vector2(64, 24)], ["pizza_table", Vector2(100, 310), 2.0, Vector2(64, 24)],
			["trashcan", Vector2(30, 130), 1.0, Vector2(24, 12)]],
	"spots": {"exit": Vector2(320, 368), "start": Vector2(320, 316), "counter": Vector2(480, 280)},
		"door": ["PIZZA", "[F]  Go inside"], "exit": ["PIZZA", "[F]  Back to the street"],
	},
	"cafe": {
		"size": Vector2(640, 384), "kind": "shop", "tint": Color(1, 0.95, 0.9),
		"paint": [[Rect2(0, 0, 640, 384), "cafe_floor"], [Rect2(0, 0, 640, 96), "cafe_wall"],
			[Rect2(280, 360, 80, 24), Color(0.3, 0.2, 0.15)]],
		"props": [["chalk_menu", Vector2(480, 92), 2.0, Vector2.ZERO], ["espresso_counter", Vector2(480, 250), 2.0, Vector2(128, 40)],
			["pastry_case", Vector2(340, 250), 2.0, Vector2(90, 30)], ["cafe_table", Vector2(90, 180), 2.0, Vector2(52, 20)],
			["cafe_table", Vector2(210, 180), 2.0, Vector2(52, 20)], ["cafe_table", Vector2(90, 300), 2.0, Vector2(52, 20)],
			["cat", Vector2(200, 310), 2.5, Vector2.ZERO], ["plant", Vector2(24, 130), 2.0, Vector2(20, 10)],
			["plant", Vector2(616, 130), 2.0, Vector2(20, 10)]],
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
		"paint": [[Rect2(0, 0, 512, 384), "store_floor"], [Rect2(0, 0, 512, 96), "store_wall"],
			[Rect2(216, 360, 80, 24), Color(0.15, 0.4, 0.25)]],
		"props": [["sale_sign", Vector2(400, 90), 2.0, Vector2.ZERO], ["gondola", Vector2(80, 130), 2.0, Vector2(96, 24)],
			["gondola", Vector2(190, 130), 2.0, Vector2(96, 24)], ["gondola", Vector2(130, 290), 2.0, Vector2(96, 24)],
			["shop_counter", Vector2(400, 250), 2.0, Vector2(128, 40)], ["cat", Vector2(360, 251), 2.5, Vector2.ZERO, 19.0]],
	"spots": {"exit": Vector2(256, 368), "start": Vector2(256, 316), "counter": Vector2(400, 280)},
		"door": ["SHOP", "[F]  Go inside"], "exit": ["SHOP", "[F]  Back to the street"],
	},
	# M4-9 NYSE (spec 03 / 09): trading floor; scripts/systems/stocks.gd draws the ticker tape and
	# terminals and opens the stock app at the terminal spot. The Fat Cat arena (M5-7) adds the podium.
	"nyse": {
		"size": Vector2(1152, 640), "kind": "nyse", "tint": Color(1, 0.97, 0.9),
		"paint": [[Rect2(0, 0, 1152, 640), "platform", Color(0.75, 0.6, 0.45)], [Rect2(0, 0, 1152, 96), "station_wall", Color(0.45, 0.35, 0.3)],
			[Rect2(536, 616, 80, 24), Color(0.25, 0.15, 0.1)]],
		"props": [["counter", Vector2(300, 260), 2.0, Vector2(128, 40)], ["counter", Vector2(852, 260), 2.0, Vector2(128, 40)],
			["counter", Vector2(300, 440), 2.0, Vector2(128, 40)], ["counter", Vector2(852, 440), 2.0, Vector2(128, 40)],
			["pillar", Vector2(120, 600), 2.5, Vector2(20, 10)], ["pillar", Vector2(1032, 600), 2.5, Vector2(20, 10)]],
		"spots": {"exit": Vector2(576, 624), "start": Vector2(576, 572), "terminal": Vector2(576, 170),
			"podium": Vector2(576, 480), "boss": Vector2(576, 330)},  # M5-7 bell podium + Fat Cat (scripts/world/nyse_arena.gd)
		"door": ["NYSE   stock exchange", "[F]  Go inside"], "exit": ["NYSE TRADING FLOOR", "[F]  Back to the street"],
	},
	# M4-6 pound (spec 08), redesigned: kennel row (the dog's cell + three caged strays) top left,
	# the warden's office top right, the exercise yard bottom right, a lit corridor between. No
	# street door: wanted.caught() sends the dog here, scripts/world/pound.gd adds the walls, bars,
	# fences and the Warden Brutus boss, and lets him out. No exit spot.
	"pound": {
		"size": Vector2(1280, 640), "kind": "pound", "tint": Color(0.85, 0.88, 0.92),
		"paint": [[Rect2(0, 0, 1280, 640), "platform", Color(0.7, 0.73, 0.76)], [Rect2(0, 0, 1280, 96), "station_wall", Color(0.5, 0.55, 0.6)],
			[Rect2(0, 96, 640, 200), Color(0.36, 0.34, 0.31)], [Rect2(960, 96, 320, 224), Color(0.5, 0.38, 0.26)],
			[Rect2(960, 320, 320, 320), "grass", Color(0.78, 0.85, 0.66)], [Rect2(0, 304, 960, 4), Color(0.9, 0.75, 0.2)],
			[Rect2(0, 632, 960, 4), Color(0.9, 0.75, 0.2)]],
		"props": [["water_bowl", Vector2(60, 270), 1.25, Vector2.ZERO], ["water_bowl", Vector2(220, 270), 1.25, Vector2.ZERO],
			["water_bowl", Vector2(380, 270), 1.25, Vector2.ZERO], ["water_bowl", Vector2(540, 270), 1.25, Vector2.ZERO],
			["bench", Vector2(780, 140), 1.0, Vector2(64, 10)]],
		"spots": {"start": Vector2(100, 200), "cell": Vector2(100, 240), "out": Vector2(100, 344), "fence": Vector2(1236, 520),
			"boss": Vector2(1100, 210)},
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
	# M5-6 Hack Club HQ lobby (spec 03): front desk (scripts/world/hq_floor.gd talks), elevator to
	# floors 1-4 (scripts/world/interior.gd ride_hq). The puzzle floors are the hq_floor template.
	"hq": {
		"size": Vector2(768, 448), "kind": "hq_lobby", "tint": Color(0.97, 0.97, 1),
		"paint": [[Rect2(0, 0, 768, 448), "platform", Color(0.85, 0.85, 0.92)], [Rect2(0, 0, 768, 96), "station_wall", Color(0.85, 0.35, 0.4)],
			[Rect2(344, 424, 80, 24), Color(0.6, 0.15, 0.2)]],
		"props": [["counter", Vector2(384, 220), 2.0, Vector2(128, 40)], ["cat", Vector2(384, 181), 2.5, Vector2.ZERO],
			["pillar", Vector2(120, 400), 2.5, Vector2(20, 10)], ["pillar", Vector2(648, 400), 2.5, Vector2(20, 10)]],
		"spots": {"exit": Vector2(384, 432), "start": Vector2(384, 380), "desk": Vector2(384, 250), "elevator": Vector2(712, 140)},
		"door": ["HACK CLUB HQ", "[F]  Go inside"], "exit": ["HACK CLUB HQ LOBBY", "[F]  Back to the street"],
	},
	# M6-4 SF pier (spec 06 Seagull King): planks over the bay; scripts/world/nyse_arena.gd puts the
	# bait crate at "podium" and the Seagull King at "boss".
	"pier": {
		"size": Vector2(1152, 640), "kind": "pier", "tint": Color(0.95, 0.97, 1),
		"paint": [[Rect2(0, 0, 1152, 640), Color(0.22, 0.42, 0.6)], [Rect2(96, 0, 960, 640), "platform", Color(0.62, 0.48, 0.34)],
			[Rect2(96, 0, 960, 8), Color(0.3, 0.22, 0.14)], [Rect2(536, 616, 80, 24), Color(0.3, 0.22, 0.14)]],
		"props": [["bench", Vector2(220, 560), 1.5, Vector2(80, 20)], ["bench", Vector2(932, 560), 1.5, Vector2(80, 20)],
			["trashcan", Vector2(160, 200), 1.0, Vector2(20, 12)], ["trashcan", Vector2(992, 200), 1.0, Vector2(20, 12)]],
		"spots": {"exit": Vector2(576, 624), "start": Vector2(576, 560), "podium": Vector2(576, 470), "boss": Vector2(576, 260)},
		"door": ["THE PIER", "[F]  Walk out on the pier"], "exit": ["THE PIER", "[F]  Back to the street"],
	},
	# Ch 2 SF: Good Boy AI startup garage (scripts/systems/startup.gd runs the founder's desk at "pitch")
	"startup": {
		"size": Vector2(768, 448), "kind": "startup", "tint": Color(0.95, 0.98, 1),
		"paint": [[Rect2(0, 0, 768, 448), "platform", Color(0.7, 0.72, 0.78)], [Rect2(0, 0, 768, 96), "station_wall", Color(0.35, 0.55, 0.85)],
			[Rect2(344, 424, 80, 24), Color(0.2, 0.3, 0.5)]],
		"props": [["su_founder", Vector2(384, 220), 2.0, Vector2(128, 40)], ["water_bowl", Vector2(450, 330), 1.25, Vector2.ZERO]],  # desks, racks, perks: startup.gd
		"spots": {"exit": Vector2(384, 432), "start": Vector2(384, 380), "pitch": Vector2(384, 260)},
		"door": ["GOOD BOY AI   startup garage", "[F]  Go inside"], "exit": ["GOOD BOY AI GARAGE", "[F]  Back to the street"],
	},
}

## Generic building sprite -> its template.
const BY_BUILDING := {"building_a": "apartment", "building_b": "office", "building_c": "shop_small"}
