# 09 Economy

## Currencies

| Currency | Source | Spent on |
|----------|--------|----------|
| Treats (existing) | prey, quests, puzzles, loot, selling stocks | shops, fines, claw machines, stocks |
| Bones (rare, new) | bosses, plus the few quest and puzzle par-time rewards listed | Sam-themed wardrobe, trader rare items |
| Kibble shares | bought in the NYSE app | sold back for treats |

`MAX_TREATS := 25` limits treat pickups on the map, not the wallet; keep it.
Bones are kept on rebirth.

## Prices that differ

Final price = `base * city_mult * shop_roll * (1 - discount)`, rounded, min 1.

- `city_mult`: NYC 1.0, SF 1.4, Tokyo 1.2, Shenzhen 0.8.
- `shop_roll`: per shop, seeded from the door id, 0.85-1.15. Stable across
  sessions.
- `discount` = bodega cat hearts (2% each, max 10%) + claimed block (5%),
  capped at 25%.
- Shop UI strikes through the base price when discounted.

## Base price table (NYC, before rolls)

| Item | Base | Effect | Sold at |
|------|------|--------|---------|
| Purina | 5 | +50 food, +40 HP (existing) | bodegas, konbini, stalls |
| Water | 3 | +60 thirst (existing) | bodegas; gas station x0.7 |
| Name collar | 25 | existing | NYC bodegas |
| Pizza slice | 4 | +30 food, "Carb Rush" +15% speed 60 s | pizza shop |
| Pepperoni slice | 6 | +30 food, +10% damage 60 s | pizza shop |
| Hot dog | 4 | +35 food | gas station |
| Jerky | 6 | thirst drain -50% for 120 s | gas station |
| Puppuccino | 5 | stamina regen +50% 120 s | cafe |
| Bark Brew | 6 | bark cooldown -50% 120 s | cafe |
| Matcha Mutt | 6 | dash cooldown -30% 120 s | Tokyo cafe |
| Onigiri | 4 | +40 food | konbini |
| Battery treat | 8 | +20 HP, full stamina | Shenzhen stalls |
| Claw machine try | 15 | random hat/collar from the claw table | Tokyo arcade |

Food buffs (pizza) and drink buffs (cafe) are separate slots: one of each at a time.

## Wandering trader (Pocket)

| Item | Price |
|------|-------|
| XP snack (+10% XP for 5 min) | 30 treats |
| Fake mustache (-1 star) | 20 treats |
| Spiked collar | 4 bones |
| Rare skin color variant (one per breed) | 5 bones |
| Mega Purina (full HP, food, thirst) | 25 treats |
| Map scrap (marks all bodega cats in the city) | 15 treats |

Pocket shows 4 random entries per visit.

## Bones

| Source | Bones |
|--------|-------|
| King of Raccoons / Pigeon Queen / Rat Meister | 1 each, first kill |
| Daven the Hedgehog | 2, first kill |
| Fat Cat | 5 |
| Seagull King | 8 |
| Claw King | 10 |
| Mecha-Cat | 12 |
| Null Cat | 25 |
| Puzzle par time | 1 per puzzle floor (17) |
| Dog park quests | as listed in `07-npcs-animals.md` (13) |

About 100 bones on a first run. Bone items cost about 60 in total.

## Bodega loyalty discounts

From bodega cat hearts (`07-npcs-animals.md`), applied through `discount` above.

## Stock market minigame (NYSE)

| Ticker | Name | Start | Volatility per tick | Drift per tick |
|--------|------|-------|---------------------|----------------|
| KIBL | Kibble Corp | 20 | 2% | +0.2% |
| BONE | Bone Holdings | 50 | 4% | +0.1% |
| SQRL | Squirrel Futures | 8 | 9% | 0% |
| PURR | Purr Industries (cat-owned) | 30 | 5% | -0.1% |
| CHEW | Chew Toy Tech | 12 | 7% | +0.3% |

- Tick every 10 real seconds while playing (not paused, not offline):
  `p *= 1 + drift + randfn(0, vol)`, clamp to [1, 999].
- News: every 2-3 in-game days a headline moves one ticker 15-30%
  ("Squirrel shortage in the park!"). Play-linked events: beating Fat Cat
  drops PURR 40%; claiming 10 NYC blocks lifts KIBL 20%.
- Buy and sell with treats, 2% fee on sells, max 999 shares per ticker.
- UI: per ticker price, change since last visit, 60-point sparkline, holdings;
  total value. Opens at NYSE terminals, then anywhere with P after the first visit.
- Prices, history and holdings are saved.
- Self-check (in tests): seeded 10,000-tick run keeps every price in
  [1, 999], and buy-then-sell on the same tick always loses treats.
