extends SceneTree
## Smoke test: bosses wake / die, the subway train kills, the death screen respawns.
## Run: godot --headless --fixed-fps 60 --path . -s tests/smoke.gd   (never saves)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	var game: Node2D = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	var player: CharacterBody2D = game.player

	var bosses := get_nodes_in_group("boss")
	assert(bosses.size() == 3)
	var names := bosses.map(func(b): return b.cfg.name)
	for n in ["King of Raccoons", "The Pideon Queen", "The Rat Meister"]:
		assert(n in names, n)
	for b in bosses:
		player.hp = player.max_hp
		player.position = b.home + Vector2(120, 0)
		await frames(3)
		assert(game.boss == b, "boss wakes when the dog is near")
		assert(game.boss_box.visible)
		var treats: int = player.treats
		b.hurt(1e9, player.position)
		assert(game.boss == null and not b.visible, "boss beaten")
		assert(player.treats == treats + b.cfg.treats)

	# subway: stand on the tracks, wait for the train
	player.hp = player.max_hp
	player.treats = 10
	game.act = "enter_subway"
	game.act_i = 0
	game.interact()
	assert(game.inside == "subway")
	player.position = game.SUB_O + Vector2(600, 380)
	await frames(2)
	assert(player.position.y > game.SUB_O.y + 370, "tracks are walkable")
	assert(game.train_t > 19.0 and game.train_t <= 20.0, "train on a 20 s schedule")
	game.train_t = 0.1
	await frames(180)
	assert(player.dead and paused and game.death_panel.visible, "train kills, death screen shows")
	assert(player.treats == 5)
	assert(player.position.y < game.SUB_O.y + 322, "dog was flung off the tracks")

	game.respawn()
	assert(not paused and not player.dead and not player.frozen and not game.death_panel.visible)
	assert(game.inside == "" and player.position == player.spawn_point and player.hp == player.max_hp)

	# ordinary death also raises the screen
	player.take_damage(1e9)
	assert(paused and game.death_panel.visible)
	print("smoke ok")
	quit()
