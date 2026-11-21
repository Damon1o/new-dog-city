# SFX credits

The `.wav` files in this folder come from `tools/gen_assets.py` (stdlib synth, no recordings).

Everything else is synthesized in code at startup by `_synth` in `autoload/sound.gd`:
footsteps (`step_concrete`, `step_grass`, `step_puddle`, `step_snow`, `step_wood`),
the ambience loops (`amb_city`, `amb_night`), whistle, siren, rat squeak, and the cat and
possum hisses and yowls. No third-party audio is used, so there is nothing to license.
When a real CC0 recording replaces a synth, add a line here: file, source URL, license.
