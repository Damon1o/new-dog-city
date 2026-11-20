# Lost Packet: open design questions

Questions for Damon that came up during wave 3. Each one lists the current default, so work keeps going until it's answered.

1. **Floor clear hook (M5-5, affects M5-4 and M5-6).** When a floor is solved, code calls `g.flashback.clear_floor(id, time)`. That records the time in `Story`, plays the flashback and adds the polaroid. Calling `Story.clear_floor` directly records the time but plays no flashback. Should `Story` emit a `floor_cleared` signal that the flashback listens to instead? Default: call through `g.flashback`.
2. **Album with no save.** The home screen's Wardrobe button is disabled until a save exists. Album isn't, so with no save it starts a new dog with the intro. Disable it too? Default: leave it enabled.
3. **Flashback data.** Only nyc_1..3 have playable flashbacks. The other 14 polaroids show as "?". Who writes the remaining 14 scripts, and with which props? Default: blank until M5-8 content.
4. **Flashback vignette.** The spec asks for a soft vignette. It was skipped; the sepia comes only from the room tint. Default: skip.
5. **Wardrobe item bonuses and unlocks.** Items are cosmetic. The spec prices the hoodie at 6 bones, but the unlock sources aren't set. Default: cosmetic only.
6. **Territory claim perks and the Top Dog hat.** Claiming a block has no perk yet. Default: none.
7. **Pound on HP 0.** At 1+ stars, should dropping to 0 HP send the dog to the pound instead of the normal faint? Default: being caught (by officers) is the only way into the pound.
