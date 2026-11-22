extends RefCounted
## Cutscene scripts (spec 01 "Cutscene list"). Each is a list of steps, run by scripts/ui/dialog.gd:
##   {say: who, text}  dialog card      {pan: Vector2 (offset from the dog), t}  camera move
##   {wait: t}  pause                   {sfx: name}  {music: name} (cutscene layer)  {flag: name}
## Esc skips the rest, but every {flag} step still gets set.
## FLASHBACKS (spec 04 "Flashback playback") run in the flashback_room template via
## scripts/world/flashback.gd; POLAROIDS is the album, in order, all 17.

## Album order and titles: fb_<floor> for every HQ floor that plays a flashback (spec 04 "Floors").
const POLAROIDS := {
	"fb_nyc_1": "Sam buying Byte's first collar", "fb_nyc_2": "Byte's first snowfall with Sam",
	"fb_nyc_3": "Sam adopting Byte from the pound", "fb_sf_1": "Hackathon demo day, Byte under the table",
	"fb_sf_2": "Sam's late bus, Byte waiting at the door", "fb_sf_3": "Sam coding late, Byte asleep on their feet",
	"fb_tokyo_1": "Rainy walk, shared umbrella", "fb_tokyo_2": "Sam teaching Byte \"sit\" with a treat",
	"fb_tokyo_3": "Sam teaching Byte the spin trick", "fb_shenzhen_1": "Sam soldering, Byte watching sparks",
	"fb_shenzhen_2": "The lost-pet finder prototype", "fb_shenzhen_3": "Sam's goodbye on the day they left",
	"fb_tower_1": "The AI's first successful pet match", "fb_tower_2": "The AI starts ignoring Sam",
	"fb_tower_3": "Sam locked out of their own lab", "fb_tower_4": "Sam sending the message to Byte",
	"fb_tower_5": "Sam's note: \"Byte will find me\"",
}

## Playable flashbacks: Sam's spot, the city's piano theme, props [texture, room pos, scale, who, card].
## A flashback ends once every prop has shown its card. ponytail: only NYC so far; the rest
## sit in the album as blanks until their cities exist.
const FLASHBACKS := {
	"fb_nyc_1": {"music": "piano_nyc", "sam": Vector2(400, 260), "props": [
		["counter", Vector2(440, 200), 2.0, "Sam", "The red one? ...Yeah. The red one, buddy. Matches your ears."],
		["shelf", Vector2(150, 140), 2.0, "Byte", "Squeaky toys, floor to ceiling. Sam said pick one. I picked three."],
	]},
	"fb_nyc_2": {"music": "piano_nyc", "sam": Vector2(330, 240), "props": [
		["tree", Vector2(160, 220), 1.0, "Byte", "Cold white stuff falling out of the sky! I bit it. It vanished."],
		["hydrant", Vector2(480, 230), 1.0, "Sam", "Your first snow! Hold still, I want a picture of this."],
	]},
	"fb_nyc_3": {"music": "piano_nyc", "sam": Vector2(470, 260), "props": [
		["shelf", Vector2(150, 140), 2.0, "Byte", "Rows of cages. Everybody barking. Nobody ever looked at me."],
		["water_bowl", Vector2(200, 290), 1.25, "Byte", "My bowl, empty like always. Then footsteps stopped right here."],
		["counter", Vector2(470, 200), 2.0, "Sam", "That one. The scruffy one in the back. He's coming home with me."],
	]},
}

const CUTSCENES := {
	"cs_intro": [
		{"music": "piano_nyc"},
		{"say": "Byte", "text": "Morning! Sam? ...Sam?"},
		{"say": "Byte", "text": "The bowl is empty. Sam ALWAYS fills the bowl before work."},
		{"pan": Vector2(0, -260), "t": 1.5},
		{"say": "Byte", "text": "The door's open a crack. Sam left for that work trip... and never came back."},
		{"pan": Vector2.ZERO, "t": 1.0},
		{"sfx": "bark"},
		{"say": "Byte", "text": "That smell. Sam's coffee. It goes toward the bodega."},
		{"say": "Byte", "text": "Hold V to sniff. Follow the trail, find Sam."},
		{"say": "Byte", "text": "No human leaves a good dog behind. Not on my watch."},
		{"flag": "cs_intro"},
	],
	"cs_bodega_find": [
		{"say": "Mango", "text": "Your human dropped these out front. Lanyard, a sticker... and half a bagel."},
		{"say": "Byte", "text": "Sam's Hack Club badge! Still smells like Sam."},
		{"say": "Mango", "text": "Rumor is the Fat Cat at the stock exchange knows things. Bring treats. Or teeth."},
		{"say": "Byte", "text": "Teeth it is."},
		{"flag": "ch1_bodega"},
	],
	"cs_fatcat_pre": [
		{"music": "boss_fatcat"},
		{"say": "Fat Cat", "text": "A mutt on MY trading floor? Security!"},
		{"say": "Byte", "text": "Where's Sam?"},
		{"say": "Fat Cat", "text": "Information costs, puppy. Let's see if you can pay."},
	],
	"cs_fatcat_post": [
		{"say": "Fat Cat", "text": "Fine! FINE. Sell, sell..."},
		{"say": "Fat Cat", "text": "Your human got on the airport shuttle. Hoodie, laptop, looked worried."},
		{"say": "Fat Cat", "text": "Take this keycard. It opens the Hack Club HQ. Now get off my floor."},
		{"say": "Byte", "text": "The HQ. Sam's work. That's the next scent."},
		{"flag": "ch1_boss"},
	],
	"cs_hedgehog_pre": [
		{"music": "hedgehog_theme"},
		{"say": "Daven the Hedgehog", "text": "Who's sniffing around MY den?"},
		{"say": "Byte", "text": "I'm looking for Sam. Hoodie, laptop, smells like coffee."},
		{"say": "Daven the Hedgehog", "text": "Nobody leaves the den, pup. Not with treats. Not with fur."},
		{"say": "Daven the Hedgehog", "text": "Hoglets! Dinner's here!"},
		{"flag": "cs_hedgehog_pre"},
	],
	"cs_hedgehog_post": [
		{"say": "Daven the Hedgehog", "text": "Okay... okay! The den is yours. Keep the quills as a souvenir."},
		{"say": "Byte", "text": "Just the treats, thanks."},
		{"flag": "cs_hedgehog_post"},
	],
	# park bosses (data/bosses.gd `intro` / `outro`): once per save, the flag is the id
	"cs_raccoon_pre": [
		{"say": "King of Raccoons", "text": "Kneel, mutt. Every trash can in this park bows to me."},
		{"say": "Byte", "text": "I only bow for belly rubs."},
		{"flag": "cs_raccoon_pre"},
	],
	"cs_raccoon_post": [
		{"say": "King of Raccoons", "text": "My crown... my beautiful lid crown..."},
		{"flag": "cs_raccoon_post"},
	],
	"cs_pigeon_pre": [
		{"say": "The Pideon Queen", "text": "Coo-COO! My flock will peck you down to crumbs!"},
		{"say": "Byte", "text": "I've chased a hundred of your pigeons. Never caught one. Today's the day."},
		{"flag": "cs_pigeon_pre"},
	],
	"cs_pigeon_post": [
		{"say": "The Pideon Queen", "text": "The flock... flies... home..."},
		{"flag": "cs_pigeon_post"},
	],
	"cs_rat_pre": [
		{"say": "The Rat Meister", "text": "Squeak! The tunnels are mine, and so is every crumb in them!"},
		{"say": "Byte", "text": "Even Sam's bagel crumbs? Then we have a problem."},
		{"flag": "cs_rat_pre"},
	],
	"cs_rat_post": [
		{"say": "The Rat Meister", "text": "Back... to the sewers... I go..."},
		{"flag": "cs_rat_post"},
	],
	"cs_ch1_clue": [
		{"music": "piano_nyc"},
		{"say": "Receptionist", "text": "A dog got past every boss in the city? ...You're Byte. Sam's Byte."},
		{"say": "Receptionist", "text": "Sam said you'd come. They left something with me, just in case."},
		{"pan": Vector2(0, -120), "t": 1.0},
		{"say": "Byte", "text": "Sam's sticker. And a boarding pass. JFK to SFO, one way."},
		{"say": "Byte", "text": "There's writing on the back, in Sam's handwriting: \"Had to go to SF. Something I built got loose.\""},
		{"pan": Vector2.ZERO, "t": 0.8},
		{"sfx": "bark"},
		{"say": "Byte", "text": "San Francisco. Sam went west. The JFK gate to SF is open."},
		{"say": "Byte", "text": "Airport, here I come."},
		{"flag": "ch1_clue"},
	],
	# Ch 2 San Francisco (M6-1): first landing at SFO
	"cs_arrive_sf": [
		{"say": "Byte", "text": "San Francisco. Everything's gray and wet and smells like fish."},
		{"pan": Vector2(0, -300), "t": 1.5},
		{"say": "Byte", "text": "Fog so thick I can't see past the next block. Good thing I've got a nose."},
		{"pan": Vector2.ZERO, "t": 1.0},
		{"sfx": "bark"},
		{"say": "Byte", "text": "A seagull swooped past with a backpack. Sam's backpack. I know that zipper charm."},
		{"say": "Byte", "text": "Gulls hang out by the pier. Hold V, find the trail. Then find that bird."},
		{"flag": "cs_arrive_sf"},
	],
	# Good Boy AI, the SF startup side story (scripts/systems/startup.gd)
	"cs_startup_intro": [
		{"say": "Patch", "text": "Whoa, a customer! Patch. Corgi. Serial founder. This garage is for rent."},
		{"say": "Byte", "text": "I'm not buying a garage. I'm looking for my human, Sam."},
		{"say": "Patch", "text": "Lost human, huh? Pitch: an AI that sniffs out lost humans. Every dog in SF needs one."},
		{"say": "Byte", "text": "An AI that could find Sam... How much?"},
		{"say": "Patch", "text": "150 treats gets you a company. The desk's all yours, CEO."},
		{"flag": "cs_startup_intro"},
	],
	"cs_startup_found": [
		{"sfx": "bark"},
		{"say": "Patch", "text": "Paperwork's done! Welcome to Good Boy AI. Our first product: PawFinder."},
		{"say": "Byte", "text": "Feed it every smell in the city. Coffee, hoodie, laptop. Sam."},
		{"say": "Patch", "text": "It'll earn treats while it learns. Swing by the desk to collect."},
		{"flag": "cs_startup_found"},
	],
	"cs_startup_beta": [
		{"say": "PawFinder", "text": "BETA ONLINE. SCANNING 4,812 SMELLS... MATCH FOUND."},
		{"say": "PawFinder", "text": "COFFEE. HOODIE. LAPTOP. LAST SEEN: THE PIER. 61% SURE."},
		{"pan": Vector2(0, -260), "t": 1.2},
		{"say": "PawFinder", "text": "ALSO DETECTED: ONE VERY LARGE SEAGULL. WEARING A BACKPACK."},
		{"pan": Vector2.ZERO, "t": 0.8},
		{"say": "Byte", "text": "Sam's backpack! The pier it is."},
		{"flag": "startup_lead"},
	],
	"cs_startup_ipo": [
		{"music": "piano_nyc"},
		{"say": "Patch", "text": "We're public! Good Boy AI is worth a billion treats! On paper. Mostly."},
		{"say": "PawFinder", "text": "I HAVE FOUND 4,102 LOST HUMANS. I COULD FIND EVERYONE. ALL THE TIME."},
		{"say": "Patch", "text": "...Did it just say everyone?"},
		{"say": "Byte", "text": "Sam built something like this once. Sam said never let it run without someone watching."},
		{"say": "Byte", "text": "\"Something I built got loose.\" Sam, what did you build?"},
		{"flag": "startup_ipo"},
	],
}
