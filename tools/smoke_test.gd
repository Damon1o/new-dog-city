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
	var boss: Node2D = game.hedgehog
	var spend := func():  # level-ups pause for a stat pick; spend so the game keeps running
		while player.points > 0:
			game.pick_stat(0)

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
	check(player.points > 0 and paused, "quest XP levels the dog and opens the stat picker")
	spend.call()
	check(not paused, "picker closes once points are spent")

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

	# losing to the boss keeps level (M1-5) and throws the dog back onto the street
	game.act = "enter_boss"
	game.interact()
	var before: int = player.level
	player.treats = 100
	player.take_damage(99999.0)
	check(player.level == before, "boss death keeps level")
	check(player.treats == 20, "boss keeps treats over 20")
	check(game.death_panel.visible and not boss.active, "death screen up, fight reset")
	game.respawn()
	check(game.inside == "", "respawn lands on the street")
	player.level = 30
	player.take_damage(99999.0)
	check(player.level == 30, "street deaths cost no levels")
	game.respawn()

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
