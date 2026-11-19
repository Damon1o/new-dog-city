# 02 Cities and world

## City data

One const table, `data/cities.gd`. The world builder reads it. Adding a city is
a new entry plus art and audio.

| Field | NYC | San Francisco | Tokyo | Shenzhen |
|-------|-----|---------------|-------|----------|
| id | nyc | sf | tokyo | shenzhen |
| seed | 20261115 (current CITY_SEED) | 20261116 | 20261117 | 20261118 |
| grid NX x NY | 9 x 7 | 8 x 7 (hill tiles slow sprint 10%) | 9 x 8 | 10 x 7 |
| block size | 512 x 384 | 512 x 384 | 384 x 320 (narrow streets) | 512 x 384 |
| reachable | always | flag ch1_clue | flag ch2_clue | flag ch3_clue |
| HQ level | 20 | 40 | 60 | 80 |
| enemy level band | 1-20 | 20-40 | 40-60 | 60-80 (Tower 80-100) |
| price multiplier | 1.0 | 1.4 | 1.2 | 0.8 |
| weather table | clear 50, snow 30, rain 20 | fog 60, clear 30, rain 10 | rain 70, clear 30 | haze 40, clear 40, storm 20 |
| music | nyc_jazz | sf_synth | tokyo_lofi | shenzhen_electro |
| ambient chatter | English | English, Spanish, Cantonese | Japanese | Mandarin |
| landmarks | NYSE, bodegas x4, dog park, airport, pound, NYC HQ (Tower), pizza shop, gas station, cafe, Sam's apartment | pier, cable car stop, corner stores x3, dog park, airport, pound, SF HQ, cafe, gas station, pizza shop | arcade, konbini x3, shrine park (dog park), airport, pound, Tokyo HQ, cafe, Maneki Neko shrine | electronics market, night-market stalls x3, rooftop arena, dog park, airport, pound, Shenzhen HQ, gas station, cafe |
| boss | Fat Cat (NYSE) | Seagull King (pier) | Claw King (arcade) | Mecha-Cat (rooftop) |
| palette | current tiles | pastel facades, blue-grey ground | dark asphalt, neon signs | grey concrete, LED green/magenta |
| fast travel | subway (existing) | cable car (subway logic, new sprite) | train (subway logic) | metro (subway logic) |

## Bigger map

- NYC grows from 6 x 5 to 9 x 7 blocks: world about 5,888 x 4,480 px (same
  formula: `NX*512 + (NX+1)*128`).
- Landmarks sit on fixed block coordinates from the city table, so saves,
  quests and subway stops stay valid. Filler blocks stay seeded-random.
- The old 6 x 5 layout stays the top-left corner of the new NYC, so old save
  positions still work. On load, if the saved position is inside a collider,
  move the player to the nearest road point.
- Only the current city exists in the scene tree. Travel frees the old city
  node and builds the new one behind a fade.
- Performance: a 9 x 7 city is about 2x today's node count. Measure in task
  M2-1. If web-export frame time passes 8 ms, hide blocks more than 2 blocks
  from the camera (`visible = false`). Nothing fancier.
- Interior rooms already live at far offsets (`SHOP_O := Vector2(6000, 0)`).
  With the bigger world, move the interior origin to `Vector2(20000, 0)` so
  rooms never overlap streets.

## City travel

- Airport interior: one gate per city. Locked gates are greyed with the unlock
  hint ("Find the next clue at the NYC Hack Club HQ").
- Boarding with wanted level > 0: security turns Byte away ("Lose the heat first").
- Flight: 3 s cutscene (plane crossing a map card), then the arrival cutscene
  the first time, then spawn at that city's airport door.
- Flights are free in story mode.

## Day/night cycle

Existing: `DAY_LENGTH := 240.0` and `sun()`. Kept as is.

| Phase | sun() | Effects |
|-------|-------|---------|
| Day | >= 0.6 | Pigeon flocks, squirrels, bodega cats sit out front, animal control normal |
| Dusk / dawn | 0.3-0.6 | Mixed spawns, streetlights on below 0.5 |
| Night | < 0.3 | Rats x2, raccoons x2, black cats (night only), possums. Enemies +2 levels. Animal control patrols halved. Pizza shop open, cafes closed. |

Spawn tables per city and phase live in `data/spawns.gd`. The current
`MAX_PREY := 36` cap scales with city area (`36 * area / old_area`).

## Weather

One weather roll per in-game day per city from the table above. Changes blend
over 10 s.

| Weather | Visual | Gameplay | Audio |
|---------|--------|----------|-------|
| Clear | none | none | city ambience |
| Snow (NYC) | snow particles, white ground tint, paw prints fade after 8 s | sprint -10%, thirst drains 20% slower | snow footsteps, muffled traffic |
| Fog (SF) | radial screen fade, sight radius 420 px; enemies and name tags outside it hidden | scent range 900 px; enemies outside the radius do not aggro | fog horn every 60-90 s |
| Rain (Tokyo; rare in NYC/SF) | rain streaks, puddle sprites, darker tint | dash slides 30% further with 50% less steering; scent range 700 px | rain loop, puddle footsteps |
| Haze (Shenzhen) | yellow-grey tint, heat shimmer | thirst drains 30% faster | cicadas, AC units |
| Storm (Shenzhen) | rain plus lightning flashes every 10-20 s | rain rules; a flash reveals hidden enemies for 1 s | thunder |

Weather is one node (`systems/weather.gd`): `current`, `set_weather(id)`, and
read-only modifiers `scent_range()`, `sprint_mult()`, `thirst_mult()`,
`dash_slide()`, `sight_radius()`. Other systems read modifiers. Nothing else
checks weather ids.

## Maneki Neko (Japan)

- Tokyo only. A shrine NPC near the Tokyo airport, plus 8 small statues hidden
  across Tokyo blocks.
- Story: guide with one cryptic hint per Ch 3 step.
- Collectible: petting all 8 statues (F) gives the "Lucky Paw" collar
  (+5% treats from prey).

## Alternative Tower placement (not default)

If you want the Tower as its own place: add a fifth city entry `tower`
(1 x 1 grid, single landmark) reachable by flag `ch4_clue` from the Shenzhen
airport. Everything else in the spec stays the same.
