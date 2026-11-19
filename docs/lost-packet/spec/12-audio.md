# 12 Audio

## Today

`tools/gen_assets.py` synthesizes every SFX with the stdlib (`sweep()`
square-wave pitch sweeps with noise and fade, `write_wav()`) into
`assets/sfx/`: bark, catch, hurt, buy, levelup, steam, subway, pickup.
`game.gd` loads `SFX_NAMES` and plays them with `sfx(name)`. No music yet.

## Buses

Add three buses in `default_bus_layout.tres`: **Music**, **SFX**,
**Ambience**. Settings gets a slider per bus; the existing volume slider
becomes Master.

## Music

### System
- One `Music` node with two `AudioStreamPlayer`s for 1.5 s crossfades.
- `Music.play(track)`; playing the current track again does nothing.
- Priority: cutscene/flashback > boss > city (day or night variant).
- OGG Vorbis, loop enabled on import. Budget about 2 MB per track. The web
  build already ships a 36 MB `index.wasm`, so keep loops 60-90 s.

### Track list

| Track | Use | Style |
|-------|-----|-------|
| home_theme | home screen | warm, mid-tempo, main motif |
| nyc_jazz / nyc_jazz_night | NYC | walking-bass jazz; night = brushes, slower |
| sf_synth / sf_synth_night | SF | mellow synth-pop, foggy pads |
| tokyo_lofi / tokyo_lofi_night | Tokyo | lo-fi hip hop with rain texture |
| shenzhen_electro / shenzhen_electro_night | Shenzhen | upbeat electronic, chiptune leads |
| interior_shop | shops | short cozy loop |
| hq_puzzle | HQ floors | minimal thinking music |
| tower_theme | Tower floors | tense mix of all city motifs |
| boss_fatcat | Fat Cat | swing big band |
| boss_seagull | Seagull King | surf rock |
| boss_claw | Claw King | arcade chiptune |
| boss_mecha | Mecha-Cat | industrial electronic |
| boss_nullcat_1 / boss_nullcat_2 | Null Cat | medley of the four boss themes, then glitch |
| piano_nyc / piano_sf / piano_tokyo / piano_shenzhen | flashbacks | solo piano versions of each city theme |
| credits | ending | piano and strings, main motif |
| pound_escape | breakout | sneaky pizzicato |

Source: original compositions (yours, a collaborator's, or commissioned) or
CC0/CC-BY tracks with credit. Record each file's source and license in
`assets/music/CREDITS.md`. No music taken from other games.

## Sound effects

Synth-friendly ones are new `write_wav()` lines in `gen_assets.py`. Ones that
need recordings (crowds, weather) come from CC0 libraries, listed in
`assets/sfx/CREDITS.md`.

| SFX | How | Notes |
|-----|-----|-------|
| bark (exists), bark_scare, bark_big | synth | scare bark (lower, longer) for R; big for Howl |
| dash, spin, pee | synth | moves |
| cat_hiss_tabby / _tom / _sphynx / _calico / _black | synth noise, different filters | per cat type |
| cat_yowl_tabby / _tom / _sphynx / _calico / _black | synth pitch bends | per cat type |
| rat_squeak, squirrel_chirp, seagull_cry, possum_hiss | synth | animal noises |
| pigeons_scatter | synth flutter bursts | flock scatter |
| car_horn_1, car_horn_2 | synth two-tone | random pick |
| siren | synth sweep loop | animal control van |
| whistle | synth | officer within 400 px |
| subway (exists), subway_arrive, subway_doors | synth | subway |
| bodega_bell | synth bell | shop door |
| konbini_chime | synth 3-note | Tokyo shops |
| step_concrete, step_grass, step_puddle, step_snow, step_wood | filtered noise bursts | footsteps |
| levelup (exists), levelup_jingle | synth | jingle every 10 levels |
| kaching | synth | buying; replaces `buy` |
| elevator_ding, door_open | synth | interiors |
| puzzle_solve, puzzle_fail, puzzle_click | synth | HQ floors |
| boss_roar_fatcat / _seagull / _claw / _mecha / _null | synth | phase changes |
| coin_throw, laser, missile, emp, claw_drop, wind_gust | synth | boss attacks |
| fog_horn, thunder, rain_loop, cicadas | CC0 recordings | weather |
| crowd_en, crowd_es, crowd_yue, crowd_ja, crowd_zh | CC0 recordings | city chatter by language |

### Footsteps by surface
Surface from Byte's position: road or sidewalk = concrete, park rect = grass,
puddle sprite or rain on a sidewalk = puddle, snow weather = snow, interior =
wood. One step every 0.28 s walking, 0.2 s sprinting, pitch 0.9-1.1.

### Ambience
One ambience loop per city at low volume: ducked -12 dB indoors, swapped for
a quiet night loop at night.
