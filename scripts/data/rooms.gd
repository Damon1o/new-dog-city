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
			["map_board", Vector2(200, 84), 2.0, Vector2.ZERO], ["pillar", Vector2(90, 410), 2.5, Vector2(20, 10)],
			["pillar", Vector2(678, 410), 2.5, Vector2(20, 10)]],
		"spots": {"exit": Vector2(384, 432), "start": Vector2(384, 380), "elevator": Vector2(720, 140)},
		"upper": {
			"paint": [[Rect2(0, 0, 768, 448), "sidewalk", Color(0.72, 0.76, 0.84)], [Rect2(0, 0, 768, 96), "station_wall", Color(0.55, 0.6, 0.78)],
				[Rect2(50, 150, 580, 270), Color(0.3, 0.36, 0.48, 0.55)]],
			"props": [["counter", Vector2(140, 210), 1.5, Vector2(96, 30)], ["counter", Vector2(330, 210), 1.5, Vector2(96, 30)],
				["counter", Vector2(520, 210), 1.5, Vector2(96, 30)], ["counter", Vector2(140, 350), 1.5, Vector2(96, 30)],
				["counter", Vector2(330, 350), 1.5, Vector2(96, 30)], ["counter", Vector2(520, 350), 1.5, Vector2(96, 30)],
				["map_board", Vector2(330, 84), 2.0, Vector2.ZERO], ["shelf", Vector2(80, 120), 2.0, Vector2(96, 24)],
				["pillar", Vector2(690, 410), 2.5, Vector2(20, 10)]],
		},
		"door": ["OFFICES   {NAME}", "[F]  Go inside"], "exit": ["OFFICE LOBBY", "[F]  Back to the street"],
	},
	# M4-2 shops (spec 03 / 09): shop_small's layout; scripts/ui/shop.gd picks the stock by template
	"gas": {
		"size": Vector2(512, 384), "kind": "shop", "tint": Color(1, 0.95, 0.85),
		"paint": [[Rect2(0, 0, 512, 384), "sidewalk"], [Rect2(0, 0, 512, 96), "shop_wall", Color(1, 0.85, 0.6)],
			[Rect2(216, 360, 80, 24), Color(0.5, 0.2, 0.1)]],
		"props": [["shelf", Vector2(80, 130), 2.0, Vector2(96, 24)], ["shelf", Vector2(190, 130), 2.0, Vector2(96, 24)],
			["counter", Vector2(400, 250), 2.0, Vector2(128, 40)], ["trashcan", Vector2(470, 360), 1.0, Vector2(24, 12)],
			["hydrant", Vector2(40, 360), 1.0, Vector2(20, 10)]],
		"spots": {"exit": Vector2(256, 368), "start": Vector2(256, 316), "counter": Vector2(400, 280)},
		"door": ["GAS STATION", "[F]  Go inside"], "exit": ["GAS STATION", "[F]  Back to the street"],
	},
	"pizza": {
		"size": Vector2(640, 384), "kind": "shop", "tint": Color(1, 0.9, 0.8),
		"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(1, 0.85, 0.8)], [Rect2(0, 0, 640, 96), "shop_wall", Color(1, 0.6, 0.5)],
			[Rect2(280, 360, 80, 24), Color(0.6, 0.15, 0.1)]],
		"props": [["counter", Vector2(480, 250), 2.0, Vector2(128, 40)], ["counter", Vector2(150, 200), 2.0, Vector2(128, 40)],
			["counter", Vector2(110, 320), 1.2, Vector2(76, 24)], ["counter", Vector2(560, 130), 1.2, Vector2(76, 24)],
			["trashcan", Vector2(40, 140), 1.0, Vector2(24, 12)]],
		"spots": {"exit": Vector2(320, 368), "start": Vector2(320, 316), "counter": Vector2(480, 280)},
		"door": ["PIZZA", "[F]  Go inside"], "exit": ["PIZZA", "[F]  Back to the street"],
	},
	"cafe": {
		"size": Vector2(640, 384), "kind": "shop", "tint": Color(0.95, 0.9, 0.85),
		"paint": [[Rect2(0, 0, 640, 384), "shop_floor", Color(0.85, 0.75, 0.65)], [Rect2(0, 0, 640, 96), "shop_wall", Color(0.7, 0.55, 0.45)],
			[Rect2(280, 360, 80, 24), Color(0.3, 0.2, 0.15)]],
		"props": [["counter", Vector2(480, 250), 2.0, Vector2(128, 40)], ["cat", Vector2(150, 280), 2.5, Vector2.ZERO],
			["counter", Vector2(140, 170), 1.2, Vector2(76, 24)], ["counter", Vector2(300, 170), 1.2, Vector2(76, 24)],
			["shelf", Vector2(580, 120), 2.0, Vector2(96, 24)], ["tree", Vector2(40, 340), 0.4, Vector2(20, 10)]],
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
}

## Generic building sprite -> its template.
const BY_BUILDING := {"building_a": "apartment", "building_b": "office", "building_c": "shop_small"}
