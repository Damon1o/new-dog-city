# Lost Packet: open design questions

Questions for Damon that came up during wave 3. Each one lists the current default, so work keeps going until it's answered.

1. **Floor clear hook (M5-5, affects M5-4 and M5-6).** When a floor is solved, code calls `g.flashback.clear_floor(id, time)`. That records the time in `Story`, plays the flashback and adds the polaroid. Calling `Story.clear_floor` directly records the time but plays no flashback. Should `Story` emit a `floor_cleared` signal that the flashback listens to instead? Default: call through `g.flashback`.
2. **Album with no save.** The home screen's Wardrobe button is disabled until a save exists. Album isn't, so with no save it starts a new dog with the intro. Disable it too? Default: leave it enabled.
3. **Flashback data.** Only nyc_1..3 have playable flashbacks. The other 14 polaroids show as "?". Who writes the remaining 14 scripts, and with which props? Default: blank until M5-8 content.
4. **Flashback vignette.** The spec asks for a soft vignette. It was skipped; the sepia comes only from the room tint. Default: skip.
5. **Wardrobe item bonuses and unlocks.** Items are cosmetic. The spec prices the hoodie at 6 bones, but the unlock sources aren't set. Default: cosmetic only.
6. **Territory claim perks and the Top Dog hat.** Claiming a block has no perk yet. Default: none.
7. **Pound building (M4-6).** The street map has no pound building, so after paying the fine or escaping, the dog comes out at his park spawn. Should the pound have its own place on the map? Default: park spawn. (HP 0 at 1+ stars now sends the dog to the pound, as spec 08 says.)
8. **Pound extras.** The "Lost pets" board is only a text label, and there's no adoptable-dogs kennel. The "I've gotten out of here before" thought is left for M5-11. Default: leave them for later.
9. **Bodega cats (M4-3).**
   - NYC has 5 bodegas but the spec names 4 cats. Default: bodega 4's cat is plain art.
   - Is the 3-gifts-per-day limit per cat or across all cats? Default: per cat.
   - Gifts past the limit are refused and the item is kept.
   - The gift is chosen automatically (rat, then Purina, then 5 treats); there's no gift menu.
   - Hints are built from the current story objective, not hand-written per cat.
   - At 5 hearts, the first cat gives the Bell collar and the others give 2 bones.
   - The Bell collar's "+1 extra heart progress" is read as +1 point per gift.
   - "Bite a bodega cat = +15 heat" (spec 08) isn't built yet.
10. **NYSE (M4-9).**
    - The NYSE is at NYC block (1, 5), downtown.
    - Buys round up and sells round down after the 2% fee, so a same-tick round trip always loses.
    - P opens the stock app anywhere only after a first visit to an NYSE terminal.
    - Prices keep ticking while the app is open.
    - Headlines are placeholder text.
    - KIBL rallies once, when 10+ NYC blocks are claimed.
    - The next news day isn't saved, so it's re-rolled each session.
    - There's no bell podium; that's for the Fat Cat arena (M5-7).
11. **HQ puzzles (M5-4).**
    - Byte moves one tile per key on puzzle floors, with no free movement. Hunger and thirst pause there.
    - The door opens and closes live as the floor's solved state changes; it doesn't stay open once solved.
    - XP and 5 treats are given on the first clear; a bone the first time a clear beats par.
    - F on the start tile leaves a floor. On program floors this works only while the command bar is empty.
    - On program floors Byte starts facing up, and bark opens a gate only when it's directly ahead.
    - Backspace undoes the last program slot. The spec doesn't list this key.
    - Reset counts aren't saved, and there's no repeat slot (nyc_3 doesn't need one).
12. **Hack Club HQ (M5-6).**
    - The NYC HQ is the first door of block (6, 4), set through the `shops` table.
    - Gate G1 (level 20 + NYC keycard) locks floors 1-3 in the elevator. Picking a locked floor opens the gate popup.
    - Floor 4 opens once nyc_1-3 are cleared. Until the M5-8 clue room, it only shows a "coming soon" message.
    - Leaving a floor (by the start tile or by clearing it) puts the dog on the street, not back in the lobby.
    - The receptionist uses the cat sprite and gives the hint for the next floor not yet cleared.
    - The `hq_nyc` story spot isn't registered yet, so the objective has no waypoint.
13. **Dog park and quest dogs (M4-7).**
    - The dog park is the spawn park (park 0), so the dog starts in the safe zone and is let out of the pound there.
    - "Meet the dog" is an extra first step, so each quest line has 4 steps instead of the spec's 3.
    - A quest dog's line stays hidden in the tracker until you meet that dog.
    - Squirrels (prey) still spawn in the dog park; foes don't.
    - Biscuit's ball uses the GPS waypoint until the scent trail (M5-3) exists.
    - Duchess's cup step completes on any cafe visit, and in the race she doesn't actually run.
    - Ball, escort and race progress isn't saved.
14. **Fat Cat (M5-7).**
    - The podium opens with `ch1_fatcat_ready` or `ch1_bodega`, because nothing sets the ready flag until M5-8.
    - `coin_fan` is added to phase 2, and `coin_fan` + `ticker_wave` to phase 3.
    - Stats: HP 300, speed 140, damage 12, about 300 treats at level 20.
    - Drops go straight to the dog; nothing lands on the floor.
    - Biting him before ringing the bell starts the fight without the intro.
    - The security cats are tinted raccoons; they could switch to the M3-2 cat enemy now that it's merged.
    - The roar reuses the bark sound.
    - The old windup blink and hit flash still play under reduce motion.
15. **Street foes (M3-2).**
    - The hostile cats share the `raccoon` group, because `bark_wave.gd` reads it.
    - The city has a flat cap of 8 foes.
    - Sphynx isn't in any spawn table yet.
    - The alley tom's knockback can push the dog into a wall.
16. **Footsteps and ambience (M3-5).**
    - Snow takes priority over park grass, and rain on grass stays grass.
    - Rain counts as puddles everywhere else, because there are no puddle sprites.
    - Every interior is wood, including the subway, pound and flashback rooms.
    - Ambience plays at -10 dB, ducks 12 dB indoors, and uses one city/night pair for every city.
    - All sounds are synthesized placeholders. Swap in real CC0 sounds later and list them in `assets/sfx/CREDITS.md`.
