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
