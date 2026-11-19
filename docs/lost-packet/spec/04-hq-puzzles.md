# 04 Hack Club HQ puzzles and flashbacks

## Puzzle framework

- Every puzzle is a grid room: 15 x 10 tiles of 64 px inside an `hq_floor` room.
- Puzzle data: `data/puzzles.gd`, one entry per floor id (`nyc_1` ... `tower_5`):
  `{type, grid: Array[String], params: Dictionary, par_time: float}`.
  `grid` rows use one char per tile (`#` wall, `.` floor, `S` start, `D` exit
  door, plus type-specific chars).
- One script per puzzle type in `scripts/puzzles/` with the same three methods:
  `setup(data, room)`, `_process(delta)`, `is_solved() -> bool`. The floor room
  owns the exit door and opens it when `is_solved()` turns true.
- Hold R for 1 s: reset the puzzle (R is bark everywhere else).
- Hints: after 3 resets on one floor, the front desk (later the GPS helper)
  shows one hint line from `params.hint`.
- Clear rewards: XP = 200 x city index (NYC 1 ... Tower 5), 5 treats, the floor's
  flashback. Beating `par_time` gives +1 bone.
- Enemies: none on city HQ floors. Tower floors spawn 2-4 security drones
  (level 90-100) that chase and stun for 1 s.

## Puzzle types

| Type | Coding idea | Rules |
|------|-------------|-------|
| sort | Sorting | Numbered crates (`1`-`9`). Push crates (walk into them) onto pad row `_` so they read in ascending order left to right. |
| logic | Boolean logic | Pressure plates (`a`,`b`,`c`) feed gate tiles (`&` AND, `|` OR, `!` NOT) drawn as wires to the door. Byte stands on a plate or pushes a crate onto it to keep it on. |
| program | Loops / instructions | Byte cannot walk freely. A command bar holds up to 8 slots: `forward`, `left`, `right`, `bark` (opens a gate tile), `repeat x2/x3` (wraps the next slot). Fill with 1-4, press F to run. Reach the key `k`, then the door. |
| debug | Debugging | A robot vacuum (`v`) runs a given 8-step program and crashes. Byte swaps exactly one step (pick slot, pick new command). Correct fix lets the vacuum reach and press the door button `o`. |
| merge | Merge conflicts | Room split in two mirrored halves with differing tiles. Byte flips lever tiles `L` to choose "ours" or "theirs" for each conflict row; door opens when the merged column of tiles forms a walkable path. |
| ping | Network ping / echo | Dark room (sight 128 px). Tap R to bark: a ring reveals hidden floor tiles for 2 s. Walk the hidden path; off-path tiles drop Byte back to start. |
| pattern | Regex / pattern matching | Stepping stones show symbols. A sign shows a pattern like `^A.B*C$`. Byte crosses only on a sequence of stones that matches. Wrong stone = splash back to start. |
| stack | Stacks (LIFO) | Three pedestals hold plate stacks. Pick up / drop the top plate only (F). Rebuild the target stack shown on the wall. Larger plate can't go on a smaller one (Hanoi rule, 3-4 plates). |
| memory | Caching / memory | Puddle tiles flash a 4-7 step sequence of colors. Step on tiles in the same order. Each wrong step replays a shorter hint. |
| binary | Binary numbers | Row of 8 light switches (bits). Toggle to match the decimal number on the door. Several doors in a row, numbers get bigger. |
| circuit | Circuits | Rotatable wire tiles (`+`, `L`, `-`, `T`). Rotate with F until power flows from source to door. |
| route | Packet routing | Packets spawn on a timer and move along tracks. Byte flips switch tiles to send each packet to its matching colored port. 3 collisions = reset. Deliver 8. |

## Floors

| Floor | Type | Notes | Flashback |
|-------|------|-------|-----------|
| nyc_1 | sort | 4 crates | fb_nyc_1: Sam buying Byte's first collar |
| nyc_2 | logic | AND + NOT only | fb_nyc_2: Byte's first snowfall with Sam |
| nyc_3 | program | no repeat slot | fb_nyc_3 (key): Sam adopting Byte from the pound |
| nyc_4 | clue room | Sam's laptop sticker "SF" | none |
| sf_1 | debug | one wrong turn | fb_sf_1: hackathon demo day, Byte under the table |
| sf_2 | merge | 3 conflict rows | fb_sf_2: Sam's late bus, Byte waiting at the door |
| sf_3 | ping | fog theme | fb_sf_3 (key): Sam coding late, Byte asleep on their feet |
| sf_4 | clue room | half-finished project, Tokyo coordinates | none |
| tokyo_1 | pattern | `.`, `*` only | fb_tokyo_1: rainy walk, shared umbrella |
| tokyo_2 | stack | 3 plates | fb_tokyo_2: Sam teaching Byte "sit" with a treat |
| tokyo_3 | memory | rain puddles | fb_tokyo_3 (key): Sam teaching Byte the spin trick (unlocks Spin) |
| tokyo_4 | clue room | Sam's badge, last scan "Shenzhen" | none |
| shenzhen_1 | binary | 3 doors, up to 8 bits | fb_shenzhen_1: Sam soldering, Byte watching sparks |
| shenzhen_2 | circuit | 6 x 4 board | fb_shenzhen_2: Sam showing Byte the lost-pet finder prototype |
| shenzhen_3 | route | 2 colors | fb_shenzhen_3 (key): Sam's goodbye on the day they left |
| shenzhen_4 | clue room | Sam's message about the Tower and the rogue AI | none |
| tower_1 | sort + logic | crates are also plate weights | fb_tower_1: the AI's first successful pet match |
| tower_2 | debug + ping | dark room, vacuum program | fb_tower_2: the AI starts ignoring Sam's commands |
| tower_3 | pattern + stack | plates carry symbols | fb_tower_3: Sam locked out of their own lab |
| tower_4 | binary + circuit | wire tiles need bit power | fb_tower_4: Sam sending the message to Byte |
| tower_5 (level 100) | route + program under timer | 180 s, drones active | fb_tower_5: Sam's note "Byte will find me" |
| roof | boss | Null Cat | none |

Total flashbacks: 12 city + 5 Tower = **17** (true ending needs all 17).

Combined Tower floors reuse two type scripts in one room: the room runs both
`setup()` calls on separate tile layers and is solved when both report solved.

## Flashback playback

- Uses the `flashback_room` template, props listed per flashback in
  `data/story.gd`.
- Byte walks in; Sam is an NPC sprite (simple 2-frame idle). 1-3 interactable
  props, each shows one dialog card.
- Sepia via `CanvasModulate` color, plus a soft vignette.
- Music: the city's piano theme.
- End: fade, polaroid slides into the album with its title. Story flag
  `fb_<id>` set.
- Album (inventory tab): grid of 17 polaroids; replay any collected one.
