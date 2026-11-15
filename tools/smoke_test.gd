extends SceneTree
## Smoke test for quests + Boss Hedgehog. Uses its own save file, never the real one.
##   godot --headless --path . -s tools/smoke_test.gd

const SAVE := "user://smoke_test.cfg"
var failed := false

func check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		printerr("SMOKE TEST FAILED: ", what)
		quit(1)

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var game: Node2D = load("res://scenes/Main.tscn").instantiate()
	game.save_path = SAVE
	root.add_child(game)
	await process_frame
	var player: CharacterBody2D = game.player
	var boss: Node2D = game.boss

	# tutorial is the only tracked line until done; steps pay out in order
	check(game.tutorial_on(), "tutorial starts on")
	check(game.quest_text().begins_with("TUTORIAL  1/6"), "tracker shows tutorial step 1")
	for key in ["moved", "sprinted", "prey", "drank", "shop"]:
		game.bump(key, true)
	check(game.quest_step.Tutorial == 5 and game.tutorial_on(), "five tutorial steps done")
	game.bump("map", true)
	check(not game.tutorial_on(), "tutorial finishes")
	check(game.quest_text().begins_with("STREET HUNTER  1/4"), "tracker switches to quest lines")
	for i in 4:
		game.bump("prey")
	check(game.quest_step["Street Hunter"] == 1, "catch-5 step completes")

	# boss: three waves, each needs its HP bitten off; unhittable during the wave intro
	player.level = 25
	game.act = "enter_boss"
	game.interact()
	check(game.inside == "boss" and boss.active and boss.wave == 0, "boss fight starts")
	boss.hurt(boss.pos, 46.0, 9999.0)
	check(boss.wave == 0, "intro pause blocks damage")
	for w in 3:
		boss.pause = 0.0
		for i in 90:  # let it move and fire; park the dog in a corner and keep it alive
			player.position = game.BOSS_EXIT - Vector2(0, 30)
			player.hp = player.max_hp
			await process_frame
		check(boss.quills.size() > 0, "wave %d shoots" % (w + 1))
		check(boss.wave == w, "still on wave %d" % (w + 1))
		boss.hurt(boss.pos, 46.0, 9999.0)
	check(not boss.active and game.stat("boss") == 1, "boss beaten after 3 waves")

	# losing to the boss costs 10 levels and throws the dog back onto the street
	game.act = "enter_boss"
	game.interact()
	var before: int = player.level
	player.take_damage(99999.0)
	check(player.level == before - 10, "boss death costs 10 levels")
	check(game.inside == "" and not boss.active, "back on the street, fight reset")
	player.level = 4
	game.act = "enter_boss"
	game.interact()
	player.take_damage(99999.0)
	check(player.level == 1, "never below level 1")
	player.level = 30
	player.take_damage(99999.0)
	check(player.level == 30, "street deaths cost no levels")

	# quest progress survives a save / load
	game.save_game()
	game.stats = {}
	game.quest_step = {}
	game.load_game()
	check(not game.tutorial_on() and game.stat("boss") == 1, "quests saved and loaded")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if not failed:
		print("SMOKE TEST PASSED")
	quit(int(failed))
