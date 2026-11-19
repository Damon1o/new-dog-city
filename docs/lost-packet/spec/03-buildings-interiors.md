# 03 Buildings and interiors

## Today

`game.gd` has three hand-built rooms (`SHOP_ROOM`, `SUB_ROOM`, `BOSS_ROOM`) at
fixed far-off offsets. `set_inside(room)` looks the rect up in a literal dict
and `interact()` has one `match` arm per door type. That does not scale to
"every building has an inside".

## Interior system

- **Room templates**, not unique rooms. `data/rooms.gd` holds one entry per
  template: size, wall/floor textures, prop list (texture, position, collider
  size), spots (`exit`, `counter`, `elevator`, `npc`, custom), and a `kind`
  that picks behavior.
- **Lazy build.** A single `Interior` node builds the room on enter and frees
  it on exit. Only one interior exists at a time, at origin
  `Vector2(20000, 0)`. This replaces the always-built rooms.
- **Doors.** Every building in the city gets a door spot at its base.
  `doors: Array[Dictionary]` with `{pos, template, id, seed, floors}`.
  The F prompt reads the door under the player. One code path for all doors.
- **Variety from seed.** Generic buildings pick a template from their building
  type and seed (prop tint, shelf count, NPC). Door `id` is stable
  (`"<city>:<block>:<slot>"`) so loot and friendship can be saved per room.
- **Exit.** `exit` spot returns the player to the door they came in by
  (`return_pos` exists today; keep it).
- Camera clamp: `set_inside` reads the rect from the built room instead of the
  literal dict.

### Template list

| Template | Used by | Size (px) | Behavior (`kind`) |
|----------|---------|-----------|-------------------|
| apartment_lobby | generic building_a | 640 x 384 | Elevator to 2-4 apartment floors; small loot (treat, water) once per in-game day per door |
| apartment_floor | elevator target | 640 x 384 | 1-2 friendly NPC pets, a loot spot |
| office_lobby | generic building_b | 768 x 448 | Elevator; security guard (at wanted 2+ he calls animal control) |
| office_floor | elevator target | 768 x 448 | Office cat, desks, snack loot |
| shop_small | generic building_c | 512 x 384 | Shop UI with 3 random items from the city table |
| sams_apartment | NYC story | 640 x 384 | Story start, bed = save point, Sam's bowl |
| bodega | NYC bodegas | 768 x 448 | Existing bodega room (shelves, counter, cat). Shop + bodega cat |
| corner_store | SF | 768 x 448 | Bodega variant: different props, SF stock |
| konbini | Tokyo | 768 x 448 | Bodega variant: bright floor, onigiri/water stock, door chime |
| market_stall | Shenzhen | 512 x 320 | Bodega variant: open-front stall, gadget stock |
| gas_station | NYC, SF, Shenzhen | 640 x 384 | Shop (below). Car horns outside. |
| cafe | all | 640 x 384 | Drinks with buffs. Closed at night (door shows "Closed"). |
| pizza_shop | NYC, SF | 640 x 384 | Buy slices; steal a slice (`08-wanted-pound.md`) |
| nyse_floor | NYC | 1152 x 640 | Stock terminals, Fat Cat arena |
| airport | all | 1152 x 448 | City gates (`02-cities-world.md`), security check |
| pound | all | 960 x 640 | Cell + breakout minigame (`08-wanted-pound.md`) |
| arcade | Tokyo | 1152 x 640 | Claw King arena, 3 claw machines (spend treats for a random wardrobe item) |
| pier | SF (outdoor arena) | 1152 x 640 | Seagull King arena |
| rooftop | Shenzhen (outdoor arena) | 1152 x 640 | Mecha-Cat arena, reached by elevator from the electronics market |
| electronics_market | Shenzhen | 1152 x 448 | Gadget shop, elevator to rooftop |
| hq_lobby | each HQ | 960 x 448 | Level gate door, elevator to puzzle floors |
| hq_floor | each HQ | 960 x 640 | Loads a puzzle (`04-hq-puzzles.md`) |
| flashback_room | all | 640 x 384 | Sepia tint, scripted props |
| subway_platform | all | 1152 x 448 | Existing subway room; sprite set swaps per city |
| burrow | NYC | 960 x 640 | Existing Boss Hedgehog den |

Landmark buildings (Empire State, Chrysler) use `office_lobby` with 6 floors
and a rooftop view (camera zooms out; landmark counts as "seen").

## Elevators

- An elevator spot opens a floor list: `["Lobby", "2", "3", ...]`. Locked
  floors show why ("Level 60", "Keycard needed").
- Choosing a floor: 0.6 s fade, ding SFX, build the target room, place the
  player at its elevator spot.
- Floor rooms use the door `id` plus `:fN`, so per-floor state saves.
- Input: arrow keys + F, or number keys 1-9.

## Special places

### Gas station
Water cheap (2 treats at NYC price), hot dog (food +35, 4 treats), jerky
(thirst drain -50% for 120 s, 6 treats). Parked cars at pumps (reuse `car.gd`
with speed 0).

### NYSE
Trading floor room. Terminals open the stock app (`09-economy.md`); after the
first visit the app also opens anywhere with P. The Fat Cat fight starts when
Byte steps on the bell podium once story flag `ch1_fatcat_ready` is set.

### Bodegas (different per city)
Same shop logic, different template and stock table per city. Each bodega has
its own bodega cat (`07-npcs-animals.md`) and its own price roll
(`09-economy.md`).

### Airport
Gates per city, security (wanted must be 0), flight cutscene.

### Cafes
"Puppuccino" (stamina regen +50% for 120 s), "Bark Brew" (bark cooldown -50%
for 120 s), "Matcha Mutt" (Tokyo only, dash cooldown -30% for 120 s). One
drink buff at a time; a new one replaces the old.

### Pizza shop
Cheap food buffs; stealing a slice raises wanted level. Rules in
`08-wanted-pound.md`, prices in `09-economy.md`.

### Dog park
Outdoor; reuses park blocks (`PARKS`). Fence sprite around the block edge.
Safe zone: no enemy spawns, animal control cannot enter, HP regen 5/s, wanted
decay x3. Three friendly quest dogs per city (`07-npcs-animals.md`).
Park bosses (King of Raccoons, Pigeon Queen, Rat Meister) move to the
non-dog-park park blocks so the dog park stays safe.

### Pound
Cell, guard patrol and fenced yard. Rules in `08-wanted-pound.md`.

### Hack Club HQ
- One per city, in a fixed block. Tall building sprite with original art
  (see Risks in `PLAN.md` about the real name and logo).
- Lobby: front desk NPC, level gate door, elevator.
- Floors 1-3: puzzle floors. Floor 4: clue room with Sam's item.
- NYC HQ also has Tower floors T1-T5 and the roof, hidden until `ch4_clue`.
- Leaving mid-floor resets that puzzle. Cleared floors stay cleared.
