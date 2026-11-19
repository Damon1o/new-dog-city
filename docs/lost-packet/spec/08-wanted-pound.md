# 08 Wanted level, animal control and the pound

## Wanted level

- Hidden value `heat` 0-125. Stars = `heat / 25`, 0-5, shown top-right.
- Lives in `systems/wanted.gd` (`add_heat(n, reason)`, `stars()`, `clear()`).

| Action | Heat |
|--------|------|
| Steal a pizza slice | +25 (1 star) |
| Steal from any shop counter with a clerk | +25 |
| Bite a friendly pet or bodega cat (no damage, still counts) | +15 |
| Bark within 300 px of an officer | +5 |
| Pee within 300 px of an officer | +10 |
| Break out of an officer's grab | +10 |
| In Shenzhen | all gains x1.5 |

Decay: once no officer has seen Byte for 10 s, heat drops 2/s (Shenzhen
x0.75). Dog park decay x3. Inside a non-shop interior decay x2. Fake mustache
(trader item): -25 heat at once.

## Stealing a pizza slice

At the pizza counter, F shows "Buy slice" and "Steal slice". The clerk turns
around every 3-6 s for 1.5 s (a "!" shows when facing the counter). Steal
while the clerk faces away: free slice, +25 heat. Steal while watched: no
slice, +25 heat, and Byte is pushed out of the shop.

## Animal control

| Stars | Response |
|-------|----------|
| 1 | 1 officer on foot, spawns 500 px away off screen |
| 2 | 2 officers; lobby guards join |
| 3 | 2 officers + a van on the roads (reuses `car.gd`) that drops 1 more officer |
| 4 | 2 vans + net-gun officers (slow projectile, 2 s root) |
| 5 | All of the above + a drone spotlight that follows Byte and reveals him in fog and at night |

- Officers move 230 px/s (faster than walking, slower than sprinting). They
  can't be damaged. Bark stuns them 0.5 s (and adds heat). Dash passes through.
- Night: patrol counts halved (round up).
- **Whistle SFX** when an officer comes within 400 px (once per approach), plus
  a red screen-edge flash toward the officer.
- Officers never enter dog parks. At the fence they wait 5 s, then leave.
- Story spots: at 1+ stars, officers spawn within 600 px of the story target.

## Getting caught

Caught when an officer stays within 24 px for 1.2 s (grab bar over Byte;
mashing C breaks free once per officer), or when a net roots Byte and an
officer reaches him, or when HP hits 0 at 1+ stars.

Result: fade, Byte wakes in the current city's pound cell. Heat set to 0.
Treats kept. No XP loss.

## The pound

Two ways out, chosen at the cell door:

1. **Pay the fine:** `15 * stars_when_caught * city_price_mult` treats
   (minimum 10). Greyed if Byte can't pay.
2. **Break out** (minigame, three stages, about 60-90 s):
   - **Sneak:** leave the cell block while a guard walks a patrol with a
     visible vision cone. Seen = this stage restarts.
   - **Dig:** at the yard fence, a rhythm bar: press G when the marker hits
     the zone, 6 hits. 3 misses refill the hole.
   - **Squeeze:** under the fence, mash C for 3 s against a shrinking timer.
   - Success: out the pound's street door, +50 XP, `escapes` stat +1.
     After the Ch 1 key flashback, the next breakout shows Byte's thought
     "I've gotten out of here before."
   - Fail: back in the cell; retry or pay.

Flavor: a kennel of adoptable NPC dogs and a "Lost pets" bulletin board
(foreshadows Sam's lost-pet AI).
