# 07 NPCs and animals

## NPC base

One small script `scripts/npc.gd`: sprite, idle wander inside a rect, `talk()`
that opens the shared dialog box (`11-ui-ux.md`), optional quest-giver hook.
Friendly NPCs are never damaged (bites pass through).

## Cats

Hostile street cats are in `06-enemies-bosses.md` (tabby, alley tom, sphynx,
calico, black cat). Each type has its own tint/sprite and hiss/yowl SFX pair.

## Bodega cats (friendship and discounts)

- One named cat per bodega-type shop: NYC 4, SF 3, Tokyo 3, Shenzhen 3 =
  **13 cats**. The existing counter cat in the bodega room becomes NYC cat #1.
- Friendship 0-5 hearts per cat id. Each heart needs 10 points.

| Action | Points | Limit |
|--------|--------|-------|
| Talk (F) | +1 | once per in-game day |
| Gift a caught rat (carry it in, F at counter) | +4 | 3 gifts per day total |
| Gift 5 treats | +2 | counts toward the 3 |
| Gift Purina | +3 | counts toward the 3 |
| Bark inside the shop | -3 | |
| Pee near the shop door | -5 | |

- Discount: 2% per heart at that cat's shop (max 10%), shown in the shop UI.
- 3 hearts: the cat gives a story hint for the current chapter.
- 5 hearts: one-time gift (first cat to 5 gives the Bell collar; others give
  bones or rare consumables). All 13 at 5 hearts is a true-ending condition.
- Names: NYC Mango, Pepper, Lotto, Big Sal. SF Sourdough, Karl, Mochi.
  Tokyo Kinako, Tama, Ramune. Shenzhen Doudou, Lychee, Pixel.

## Pigeons (groups)

- Pigeons spawn as flocks of 5-12 around a center.
- Each pigeon wanders within 80 px of the flock center.
- When any pigeon flees (Byte close, a catch, a bark), the whole flock scatters
  with the `pigeons_scatter` SFX, then regroups 15-25 s later at a new center
  on a nearby sidewalk.
- `prey.gd` gets a `flock` reference; a flock is a plain Array plus a center,
  owned by the spawner. No new node type.

## Friendly dogs at the dog park (quests)

Three per city, each with a 3-step quest chain.

| City | Dog | Quest chain | Reward |
|------|-----|-------------|--------|
| NYC | Biscuit (beagle) | Find my ball (sniff trail), chase off 10 pigeons, claim 3 blocks | 150 XP, Bodega cap |
| NYC | Duchess (poodle) | Fetch a cup from the cafe, escort her across 2 roads, win a race | 200 XP, 20 treats |
| NYC | Old Rex (shepherd) | Beat the King of Raccoons, beat 3 black cats at night, visit the pound | 300 XP, 2 bones |
| SF | Fogo (lab) | Find 3 lost tennis balls in fog | 400 XP |
| SF | Chip (corgi) | Ride the cable car 3 times, deliver a sourdough | 400 XP, 30 treats |
| SF | Luna (husky) | Survive the pier at night (5 seagulls) | 500 XP, 2 bones |
| Tokyo | Hachi (akita) | Wait at the station 60 s, find 3 Maneki statues | 700 XP |
| Tokyo | Pom (pomeranian) | Win 2 claw machine prizes, deliver onigiri | 700 XP, 50 treats |
| Tokyo | Sumo (shiba) | Beat 5 sphynx cats in rain | 800 XP, 3 bones |
| Shenzhen | Dumpling (chow) | Deliver 3 gadgets across the market | 1000 XP |
| Shenzhen | Volt (shepherd) | Escape animal control at 3 stars | 1000 XP, 60 treats |
| Shenzhen | Kite (whippet) | Beat 6 drones, reach Regular reputation | 1200 XP, 3 bones |

Chains go into the existing `QUESTS` table (row format
`[text, stat, target, treats, xp]`). New stats get `bump()` calls. Bones
rewards need one extra optional column.

## Maneki Neko (Tokyo)

Guide NPC at the shrine near the Tokyo airport. One cryptic hint per Ch 3
story step, for example "The claw that takes never gives, unless it is fed a
coin." Plus 8 hidden statues (`02-cities-world.md`).

## Wandering trader

- Original character: **Pocket**, an old opossum with a shopping cart.
- Each in-game day, 50% chance Pocket spawns on a random sidewalk in the
  current city for that day. GPS pings "Pocket is in town" with a map icon.
- Stock: 4 random items from the trader table, priced in treats or bones
  (`09-economy.md`). Trader-only items: Spiked collar, XP snack, rare skin
  color variants, "Fake mustache" (drops wanted level by 1 star).
- Pocket gives one hint per city about the current story target.

## Other NPCs

| NPC | Where | Role |
|-----|-------|------|
| Pedestrians | streets, day | Ambient life on sidewalks; cannot be hurt |
| Front desk human | each HQ lobby | Level gate text, puzzle hints |
| Shop clerks | pizza, cafe, gas station | Shop UI; pizza clerk watches the counter |
| Security guard | office lobbies, airport | Calls animal control at 2+ stars |
| Sam | flashbacks, reunion | Story only |
