# 05 Byte (main character)

Existing in `player.gd`: hp/max_hp, hunger, thirst, stamina, sprint, bite
with `attack_cd`, level/xp/points, stats `stat_hp`/`stat_atk`/`stat_spd`,
5 breeds (skins), collar name, death and respawn.

## Special attacks and moves

| Move | Key | Unlock | Cost | Cooldown | Effect |
|------|-----|--------|------|----------|--------|
| Bite | Space / mouse | start | none | existing | existing |
| Dash | C | Ch 1 tutorial | 25 stamina | 1.2 s | 220 px burst along `facing` over 0.15 s. Invulnerable during dash. Passes through small prey, not walls. Rain: slides 30% further, 50% less steering. |
| Bark | R | Ch 1 tutorial | 15 stamina | 6 s | Ring of 180 px. Enemies 5+ levels below Byte flee for 4 s. Enemies within 4 levels are stunned 0.5 s. Higher ones ignore it. Pigeon flocks scatter. Bodega cats hiss. Plays `bark` SFX (exists: `assets/sfx/bark.wav`). Wanted heat +5 if an officer is within 300 px. |
| Pounce | hold Space 0.6 s | level 30 | 30 stamina | 4 s | Leap 160 px, lands for 2x bite damage + 0.8 s stun |
| Spin | X | Ch 3 key flashback | 35 stamina | 8 s | 360-degree hit, 90 px radius, 1.5x bite damage, knockback 140 px |
| Howl | H | level 60 | 50 stamina | 30 s | For 10 s: +25% damage; dog park friends within 600 px join the fight for 10 s |

All move damage goes through one function:
`damage(mult) = bite_damage() * mult * crit`, crit chance 5% (+1% per 10
`stat_atk`), crit x1.75. Shown by the overhead UI in `06-enemies-bosses.md`.

## Territory and reputation (peeing)

- Hold G 1.2 s within 40 px of a tree, hydrant, lamp post or building corner.
  Costs 10 thirst. Not allowed below 15 thirst.
- Creates a marker (small yellow paw icon, visible on the map).
- A district is one city block. A block is **claimed** at 3 markers.
- Markers fade after 3 in-game days (12 real minutes) unless re-marked.
- Reputation per city: +2 per new marker, +10 when a block becomes claimed,
  -2 when a marker fades.
- Claimed block effects: prices in that block -5%, prey there +10% XP,
  enemies spawning there start 1 level lower.
- Reputation tiers per city: Stray 0, Local 50, Regular 150, Top Dog 400.
  Top Dog in a city unlocks that city's hat.
- Rival dog: at night, one per city walks claimed blocks and overwrites one
  marker per night unless Byte beats it (level = city band max).
- Quest hooks: "Claim 3 blocks", "Reach Regular in SF".
- Peeing near an officer: wanted heat +10. Indoors: "Not here!" and no marker.

## Wardrobe

- Slots: **skin** (breed + color variant), **collar**, **hat**, plus one
  **overlay** slot (outfits such as Sam's hoodie).
- Mostly cosmetic. Breeds keep their existing stat tweaks. A few collars and
  hats have small listed bonuses.
- Open with B or from the home screen. Live preview, slot tabs, item grid,
  price, equip/buy.
- Tab still quick-cycles owned skins.

### Item list (first pass)

| Item | Slot | Source | Cost | Bonus |
|------|------|--------|------|-------|
| Pug, Husky, Chihuahua, Great Dane, Mastiff | skin | owned | 0 | existing breed stats |
| Snow coat variant (any breed) | skin | NYC Top Dog | 0 | none |
| Name collar | collar | bodega | 25 treats (existing) | name tag |
| Lucky Paw | collar | 8 Maneki Neko statues | 0 | +5% treats from prey |
| Spiked collar | collar | trader | 4 bones | +3% damage |
| Bell collar | collar | any bodega cat at 5 hearts | 0 | bodega cat gifts give +1 extra heart progress |
| Sam's lanyard | collar | Ch 1 start | 0 | none (story) |
| Bodega cap | hat | NYC bodega | 40 treats | none |
| Beanie | hat | NYC Top Dog | 0 | none |
| Fog lamp hat | hat | SF Top Dog | 0 | sight +60 px in fog |
| Sailor hat | hat | Seagull King drop | 0 | none |
| Rain hood | hat | Tokyo Top Dog | 0 | rain dash slide -50% |
| Claw prize crown | hat | claw machine, random | 15 treats per try | none |
| LED visor | hat | Shenzhen Top Dog | 0 | none |
| Sam's hoodie | overlay | wardrobe shop | 6 bones | none |
| Sam's beanie | hat | wardrobe shop | 8 bones | none |
| Hackathon badge | collar | wardrobe shop | 10 bones | none |
| Sam outfit NYC / SF / Tokyo / Shenzhen | overlay | NG+ hidden collectible per city | 0 | none |
| Null crown | hat | beat Null Cat | 0 | none |

Rendering: hats, collars and overlays are child sprites of the player sprite
with a per-breed offset added to `BREEDS` in `player.gd`.
