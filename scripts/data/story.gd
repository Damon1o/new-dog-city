extends RefCounted
## Cutscene scripts (spec 01 "Cutscene list"). Each is a list of steps, run by scripts/ui/dialog.gd:
##   {say: who, text}  dialog card      {pan: Vector2 (offset from the dog), t}  camera move
##   {wait: t}  pause                   {sfx: name}  {music: name} (cutscene layer)  {flag: name}
## Esc skips the rest, but every {flag} step still gets set.

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
	"cs_ch1_clue": [
		{"say": "Byte", "text": "Sam's desk. The laptop's gone, but the sticker's here."},
		{"say": "Byte", "text": "Someone scrawled on it. \"SF\"."},
		{"say": "Byte", "text": "San Francisco. Sam went west."},
		{"say": "Byte", "text": "Airport, here I come."},
		{"flag": "ch1_clue"},
	],
}
