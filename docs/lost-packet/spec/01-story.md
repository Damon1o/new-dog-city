# 01 Story mode: "Lost Packet"

## Premise

Byte lives in NYC with his owner, Sam, who works at Hack Club. One morning Sam
leaves for a work trip and doesn't come back. Sam's badge lanyard, a laptop
sticker and a half-eaten bagel are left by the bodega. Byte follows the scent.
Each city's Hack Club HQ holds the next clue. Each HQ opens once Byte reaches a
set level.

## Modes

| Mode | Description |
|------|-------------|
| Story | Default for a new save. Chapters, gates and cutscenes are on. |
| Free roam | Unlocked after the Ch 1 clue, or straight away on a rebirth save. Same world, story markers hidden, all reached cities open. |

Story state lives in one autoload, `Story` (see `14-architecture.md`). The world
never checks chapter numbers directly. It reads flags such as `Story.has("ch1_clue")`.

## Unlock schedule

| Gate | Requirement | Opens |
|------|-------------|-------|
| G0 | New game | NYC streets, tutorial |
| G1 | Level 20 + NYC keycard (from Fat Cat) | NYC HQ floors 1-3 |
| G2 | Flag `ch1_clue` | Airport gate to SF; SF streets |
| G3 | Level 40 + SF keycard (Seagull King) | SF HQ floors 1-3 |
| G4 | Flag `ch2_clue` | Airport gate to Tokyo |
| G5 | Level 60 + Tokyo keycard (Claw King) | Tokyo HQ floors 1-3 |
| G6 | Flag `ch3_clue` | Airport gate to Shenzhen |
| G7 | Level 80 + Shenzhen keycard (Mecha-Cat) | Shenzhen HQ floors 1-3 |
| G8 | Flag `ch4_clue` | NYC HQ elevator shows Tower floors T1-T4 |
| G9 | Level 100 + T1-T4 cleared | Tower floor T5 and the roof (Null Cat) |

Boss fights are not level-gated, so a skilled player can get a keycard early.
The HQ door still checks level.

Gate failure UI: the door shows "Level 40 required (you are 33)" and a "Find XP"
button that sets the GPS to the nearest open side quest.

## Chapter template (same for each city)

1. **Arrive.** Short cutscene (letterbox, 3-6 dialog cards, camera pan). New
   city music and weather start.
2. **Scent trail.** Hold V to sniff. A glowing paw-print trail draws from Byte
   to the current story target. The GPS waypoint updates to match.
3. **Side quests.** Bodega cats, dog park dogs and the wandering trader give
   hints and XP. The HQ gate level is the pacing target.
4. **City boss.** Beat them for the HQ keycard plus bones.
5. **HQ floors.** Three coding-themed puzzle floors (`04-hq-puzzles.md`). Each
   cleared floor plays one flashback.
6. **Clue.** Top floor: one of Sam's items and a hint toward the next city.
   Autosave, then set the `chN_clue` flag.

## Chapters

### Ch 1: NYC "Missing" (levels 1-20)

- Opening: Byte wakes in Sam's apartment. Sam's bowl is empty. Walk to the
  bodega, find lanyard + sticker + bagel. First sniff tutorial.
- Tutorial beats, in order, each a quest step with an on-screen prompt:
  move, sprint, bite, bark (R), dash (C), sniff (V), pee on a tree (G),
  buy Purina at the bodega, ride the subway once.
- Existing content kept as Ch 1 side content: raccoon boss and the Boss
  Hedgehog questline (PR #2).
- Story spots: Sam's apartment, bodega, dog park, NYSE, airport, NYC HQ.
- Boss: NYSE "Fat Cat" banker. After the fight he says he saw Sam boarding an
  airport shuttle.
- HQ clue: Sam's laptop sticker with "SF" scrawled on it. Opens the airport SF gate.
- Key flashback (top floor): Sam adopting Byte from the pound. Afterwards, the
  pound breakout shows a Byte thought: "I've gotten out of here before."

### Ch 2: San Francisco "Fog" (levels 20-40)

- Fog cuts sight radius (see `02-cities-world.md`). The scent trail matters more.
- Story spots: airport arrival, pier, cable-car stop, SF HQ.
- Boss: Seagull King, who stole Sam's backpack. Drop: backpack (Sam's item).
- HQ clue: a half-finished hackathon project on a laptop showing Tokyo coordinates.
- Key flashback: Sam coding late with Byte asleep on their feet.

### Ch 3: Tokyo "Rain" (levels 40-60)

- Rainy season: puddle footsteps, slippery dash, weaker scent.
- Maneki Neko is a guide NPC with cryptic hints, one per story step.
- Story spots: konbini, arcade, shrine-style park, Tokyo HQ.
- Boss: Claw King, a claw-machine cat in the arcade.
- HQ clue: Sam's badge, last scanned in Shenzhen.
- Key flashback: Sam teaching Byte the "spin" trick. Unlocks Spin (X) when the
  flashback ends.

### Ch 4: Shenzhen "Signal" (levels 60-80)

- Hardware markets. Animal control is toughest here (wanted heat gain x1.5,
  decay x0.75).
- Story spots: electronics market, night market, rooftop, Shenzhen HQ.
- Boss: Mecha-Cat. Post-fight reveal: a shipping label shows someone built it
  to guard "the Tower".
- HQ clue: a message from Sam: they're trapped at the top of the Hack Club
  Tower, locked out by a rogue AI.
- Key flashback: Sam's goodbye on the day they left. Byte realizes Sam meant to
  come back.

### Ch 5: Finale "Root Access" (levels 80-100)

- Fly home to NYC. The NYC HQ elevator now shows floors T1-T5.
- T1-T4 remix every city's puzzle mechanics. T5 needs level 100.
- Roof: Null Cat. Phase 1 uses each city boss's attacks, phase 2 is its own.
- Win: reunion cutscene. Sam hugs Byte. Credits roll over the collected
  flashback stills (missing ones show as blank polaroids).

## Endings and post-game

| Ending | Condition | Content |
|--------|-----------|---------|
| Normal | Beat Null Cat | Reunion, credits |
| True | Beat Null Cat with all 17 flashbacks + all 13 bodega cats at 5 hearts | Extra scene: Sam reveals the AI was a project to find lost pets that went wrong. Sam fixes it. It becomes the GPS helper (GPS voice lines and a small cat icon on the minimap from then on). |

After a normal ending, a post-credits card says how many flashbacks and cats
remain. The roof fight can be replayed from the Tower elevator. Winning again
after meeting the true conditions plays the true ending.

Post-game: Rebirth / New Game+ in `10-progression.md`. A Sam outfit collectible
is hidden in each city on New Game+.

## Story mechanics

| Mechanic | Spec |
|----------|------|
| Scent trail | Hold V. Free. Draws paw prints toward `Story.target()` and keeps them 6 s after release. Range by weather: clear 1600 px, snow 1400, fog 900, rain 700. Past range, only an edge-of-screen arrow shows. Path: chain of road intersections from Byte to the target (the city is a grid, so walk the grid; no navmesh). Inside interiors: straight line to the target door. |
| Flashbacks | Playable memory, 30-60 s, in a small sepia room built like an interior. Byte walks and interacts with 1-3 objects, one dialog card each. Music: city theme piano version. Ends with a fade and a polaroid added to the album. Replayable from the album. |
| Sam's items | Key items in the inventory "Sam" tab: lanyard, sticker, backpack, project laptop, badge, message. One-paragraph description each. Not sellable, not droppable. |
| Level gate | Door UI above. |
| Cutscene | Data list of steps: `{say: who, text}`, `{pan: Vector2, t}`, `{wait: t}`, `{sfx: name}`, `{music: name}`, `{flag: name}`. Player frozen, letterbox bars, any key advances text, Esc skips the rest. |

## Ties to existing features

- Animal control patrols near story spots: at 1+ stars, officers spawn within
  600 px of the current story target.
- Pound breakout gets meaning from the Ch 1 flashback.
- Bones from bosses buy Sam-themed wardrobe items.
- Each city's music theme has a piano version for flashbacks.

## Cutscene list

| ID | When | Cards |
|----|------|-------|
| cs_intro | New game | 6 |
| cs_bodega_find | Reach bodega | 4 |
| cs_fatcat_pre / cs_fatcat_post | Boss start / end | 3 / 4 |
| cs_ch1_clue | NYC HQ top | 4 |
| cs_arrive_sf | First SF arrival | 4 |
| cs_seagull_pre / cs_seagull_post | | 3 / 3 |
| cs_ch2_clue | | 4 |
| cs_arrive_tokyo | | 4 |
| cs_maneki_meet | First Maneki Neko | 3 |
| cs_claw_pre / cs_claw_post | | 3 / 3 |
| cs_ch3_clue | | 4 |
| cs_arrive_shenzhen | | 4 |
| cs_mecha_pre / cs_mecha_post | label reveal | 3 / 5 |
| cs_ch4_clue | Sam's message | 5 |
| cs_tower_open | Back in NYC HQ | 3 |
| cs_nullcat_pre / cs_nullcat_phase2 / cs_nullcat_post | | 3 / 2 / 3 |
| cs_reunion | Normal ending | 6 |
| cs_true_ending | True ending | 8 |

Dialog text for all cutscenes lives in `data/story.gd` (task M5-2 onward).
