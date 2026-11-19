extends SceneTree
## Smoke test: bosses wake / die, the subway train kills, the death screen respawns.
## Run: godot --headless --fixed-fps 60 --path . -s tests/smoke.gd   (never saves)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	const SAVE := "user://smoke.cfg"  # throwaway save, the real one is never touched
	DirAccess.remove_absolute(SAVE)

	# home screen: Continue hidden with no save (or a ui-only file); shown once a dog is saved;
	# New Story over a save asks first; settings never turn "no save" into a save
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Home.tscn", "launch on the home screen")
	var home: Control = load("res://scenes/Home.tscn").instantiate()
	home.save_path = SAVE
	root.add_child(home)
	await frames(1)
	assert(not home.continue_btn.visible, "no save: Continue hidden")
	home.open_settings()
	home.vols.Music.value = 0.5
	home.save_settings()
	assert(not home.continue_btn.visible and home.menu.visible, "ui-only file is no save")
	var dog := ConfigFile.new()
	dog.load(SAVE)
	dog.set_value("dog", "level", 3)
	dog.save(SAVE)
	home.show_menu()
	assert(home.continue_btn.visible, "save: Continue shown")
	home.new_story()
	assert(home.confirm_panel.visible and not home.menu.visible, "New Story over a save confirms")
	home.show_menu()
	home.free()
	DirAccess.remove_absolute(SAVE)

	var game: Node2D = load("res://scenes/Main.tscn").instantiate()
	game.save_path = SAVE
	root.add_child(game)
	await frames(2)
	var player: CharacterBody2D = game.player

	# level-up: one stat point, game waits for the pick
	var hp_cap: float = player.max_hp
	player.add_xp(player.xp_needed())
	assert(player.points == 1 and paused and game.stat_panel.visible, "level-up opens the stat picker")
	game.pick_stat(0)
	assert(player.points == 0 and not paused and not game.stat_panel.visible)
	assert(player.max_hp == hp_cap + 12.0, "+10 from the point, +2 from the level")

	# cars: one per lane, and they hurt
	var cars := get_nodes_in_group("car")
	assert(cars.size() == 2 * (game.NX + 1) + 2 * (game.NY + 1))
	cars[0].position = Vector2(32, 1000)  # cars start at random spots; pin one mid-block, clear of steam and cross traffic
	player.position = cars[0].position
	await frames(2)
	assert(absf(player.max_hp - game.CAR_DMG - player.hp) < 1.0, "car hits once (regen may tick)")

	# raccoon special: winds up, then pounces
	var rac: Node2D = get_nodes_in_group("raccoon")[0]
	player.hp = player.max_hp
	player.position = rac.home + Vector2(80, 0)
	await frames(3)
	assert(rac.state == rac.State.WINDUP, "raccoon winds up")
	await frames(30)
	assert(rac.state == rac.State.LUNGE, "raccoon pounces")
	await frames(20)
	assert(player.hp < player.max_hp, "pounce bites")

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
		assert(b.cfg.specials.size() == 2)
		for i in 2:  # both specials fire without errors
			b.special(Vector2.RIGHT)
		var treats: int = player.treats
		b.hurt(1e9, player.position)
		assert(game.boss == null and not b.visible, "boss beaten")
		assert(player.treats >= treats + b.cfg.treats)  # quests may pay extra on the level-up
		while player.points > 0:  # boss XP levels the dog; spend so the game unpauses
			game.pick_stat(1)

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

	# Sound autoload: buses exist and route to Master; sfx plays on the SFX bus
	for bus in ["Music", "SFX", "Ambience"]:
		var bi := AudioServer.get_bus_index(bus)
		assert(bi > 0 and AudioServer.get_bus_send(bi) == "Master", "bus " + bus)
	var sound: Node = root.get_node("Sound")
	var before := sound.get_child_count()
	sound.sfx("bark")
	assert(sound.get_child_count() == before + 1 and sound.get_child(-1).bus == "SFX")

	# save v2: a v1-shaped file loads with defaults; a fully filled v2 save round-trips
	var Save: GDScript = load("res://scripts/systems/save.gd")
	var v1 := ConfigFile.new()
	v1.set_value("dog", "level", 5)
	v1.set_value("dog", "points", 0)
	v1.save(SAVE)
	game.load_game()
	assert(game.save_version == 1 and player.level == 5 and game.save_extra["world/city"] == "nyc")
	for k: String in Save.V2:
		game.save_extra[k] = {"synthetic": k}
	game.vols.Music.value = 0.25
	game.save_game()
	game.save_extra = {}
	game.vols.Music.value = 1.0
	game.load_game()
	assert(game.save_version == 2 and game.vols.Music.value == 0.25)
	for k: String in Save.V2:
		assert(game.save_extra[k] == {"synthetic": k}, "v2 round trip " + k)

	# restart: progress wiped, scene rebuilt
	assert(player.level > 1)
	current_scene = game
	game.restart()
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	assert(not paused and not cfg.has_section("dog") and cfg.has_section("ui"), "restart wipes the dog")
	await frames(3)
	assert(not is_instance_valid(game) and current_scene != null, "scene reloaded")
	DirAccess.remove_absolute(SAVE)
	print("smoke ok")
	quit()
