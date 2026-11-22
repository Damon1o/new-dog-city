extends RefCounted
## Quest table, read by systems/quests.gd.

# Quest lines run side by side, one step each at a time: [text, stat, target, treats, xp].
# Stats are lifetime counters (see bump); "level" reads the dog's level.
# The tutorial is just the first line — the tracker shows it alone until it is done.
const QUESTS := {
	"Tutorial": [
		["Move with WASD or the arrow keys", "moved", 1, 0, 5],
		["Hold Shift while moving to sprint", "sprinted", 1, 0, 5],
		["Catch a pigeon, rat or squirrel:\nrun into it or bite with Space", "prey", 1, 2, 10],
		["Stand by a fountain, hydrant or\nwater bowl to drink", "drank", 1, 2, 10],
		["Find a bodega (orange dot on the\nmap) and press F at its door", "shop", 1, 5, 10],
		["Press M for the god's-eye map", "map", 1, 5, 10],
	],
	"Street Hunter": [
		["Catch 5 critters", "prey", 5, 5, 20],
		["Catch 3 squirrels", "squirrels", 3, 10, 40],
		["Beat 3 raccoons", "raccoons", 3, 15, 60],
		["Catch 40 critters", "prey", 40, 40, 150],
	],
	"City Explorer": [
		["Discover a skyscraper", "sights", 1, 5, 20],
		["Ride the subway", "rides", 1, 5, 30],
		["Discover both skyscrapers", "sights", 2, 15, 60],
		["Ride the subway 5 times", "rides", 5, 20, 80],
	],
	"Top Dog": [
		["Reach level 5", "level", 5, 10, 0],
		["Buy something at a bodega", "bought", 1, 5, 30],
		["Reach level 12", "level", 12, 25, 0],
		["Enter the hedgehog burrow in\nthe south-east park", "burrow", 1, 0, 50],
		["Defeat Daven the Hedgehog", "boss", 1, 100, 500],
	],
	# Dog park dogs (spec 07). Optional columns: bones, wardrobe item. Step 0 = talk to the dog.
	"Biscuit": [
		["Meet Biscuit at the dog park", "met_biscuit", 1, 0, 0],
		["Find Biscuit's ball (GPS)", "ball", 1, 0, 30],
		["Scatter 10 pigeons", "pigeons", 10, 0, 40],
		["Claim 3 blocks", "blocks", 3, 0, 80, 0, "bodega_cap"],
	],
	"Duchess": [
		["Meet Duchess at the dog park", "met_duchess", 1, 0, 0],
		["Get Duchess a cup at the cafe", "cafe", 1, 0, 40],
		["Walk Duchess across 2 roads", "escort", 2, 0, 60],
		["Race Duchess to the
Empire State Building", "race", 1, 20, 100],
	],
	# SF dog park dogs (M6-6)
	"Pixel": [
		["Meet Pixel at the SF dog park", "met_pixel", 1, 0, 0],
		["Ride the cable car 3 times", "sf_rides", 3, 20, 80],
		["Beat Sea Lion Sal", "park_boss_sealion", 1, 40, 200],
		["Ship the PawFinder beta", "su_ships", 1, 60, 200, 2],
	],
	"Fogarty": [
		["Meet Fogarty at the SF dog park", "met_fogarty", 1, 0, 0],
		["Beat The Twin Peaks Coyote", "park_boss_coyote", 1, 40, 200],
		["Claim 8 blocks", "blocks", 8, 30, 150],
		["Catch 60 critters", "prey", 60, 50, 200, 3],
	],
	"Captain": [
		["Meet Captain at the SF dog park", "met_captain", 1, 0, 0],
		["Beat the Seagull King on the pier", "park_boss_seagull", 1, 60, 300],
		["Buy 10 things in shops", "bought", 10, 30, 120],
		["Ride the cable car 8 times", "sf_rides", 8, 80, 250, 3],
	],
	# SF critter boom (spawns.gd "sf", enemies/cat.gd skunk / coyote, weather.gd quakes). Shows on landing
	# in SF; the last step plays cs_done_sf_pest_patrol (systems/quests.gd).
	"SF Pest Patrol": [
		["Land in San Francisco", "met_sf", 1, 0, 0],
		["Run 5 skunks off the streets", "skunks", 5, 15, 80],
		["Catch 4 gophers before they dig
up the whole park", "gophers", 4, 15, 80],
		["Scatter 20 wild parrots by
Coit Tower", "parrots", 20, 15, 80],
		["Ride out an earthquake", "quakes", 1, 20, 60],
		["Beat 6 coyotes (packs roam
at night)", "coyotes", 6, 40, 200, 2],
	],
	# Good Boy AI startup tycoon (systems/startup.gd), shows once Patch has pitched it in SF
	"Good Boy AI": [
		["Meet Patch in the SF startup garage", "met_patch", 1, 0, 0],
		["Found Good Boy AI at the desk", "su_found", 1, 0, 40],
		["Hire 3 dogs", "su_hires", 3, 30, 60],
		["Ship the PawFinder beta", "su_ships", 1, 40, 100],
		["Close a Seed round", "su_rounds", 1, 60, 150],
		["Move into the SoMa Loft", "su_moves", 1, 80, 200],
		["Ship PawFinder Pro", "su_ships", 3, 150, 400],
		["Take Good Boy AI public", "su_rounds", 4, 500, 1000],
	],
	"Old Rex": [
		["Meet Old Rex at the dog park", "met_old_rex", 1, 0, 0],
		["Beat the King of Raccoons", "park_boss_raccoon", 1, 0, 100],
		["Beat 3 black cats at night", "black_cats_night", 3, 0, 100],
		["Visit the pound", "pound", 1, 0, 100, 2],
	],
}
