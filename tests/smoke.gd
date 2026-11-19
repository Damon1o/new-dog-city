extends SceneTree
## Smoke test: bosses wake / die, the subway train kills, the death screen respawns.
## Run: godot --headless --fixed-fps 60 --path . -s tests/smoke.gd   (never saves)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	const SAVE := "user://smoke.cfg"  # throwaway save, the real one is never touched
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

	# dash (M1-3): 200-240 px burst, no damage mid-dash, cooldown + stamina cost
	player.position = Vector2(700, 64)  # top road, open to the right
	player.facing = Vector2.RIGHT
	player.hp = player.max_hp
	player.stamina = 100.0
	var dash_from: Vector2 = player.position
	assert(player.dash(), "dash fires")
	assert(not player.dash(), "dash on cooldown")
	await frames(3)
	player.take_damage(50.0)
	assert(player.hp == player.max_hp, "no damage mid-dash")
	await frames(12)
	var dash_len: float = player.position.distance_to(dash_from)
	assert(dash_len >= 200.0 and dash_len <= 240.0, "dash covers 200-240 px, got %f" % dash_len)
	assert(player.stamina < 100.0 - player.DASH_COST + 5.0, "dash costs stamina")
	player.take_damage(1.0)
	assert(player.hp < player.max_hp, "damage lands after the dash")
	player.dash_cd = 0.0
	player.stamina = 10.0
	assert(not player.dash(), "too winded to dash")
	player.stamina = 100.0
	# weather: snow sets sprint to 0.9; changes blend over 10 s; today's weather is saved
	var weather: Node = game.weather
	weather.set_weather("snow", false)
	assert(weather.current == "snow" and is_equal_approx(weather.sprint_mult(), 0.9), "snow sets sprint multiplier to 0.9")
	assert(is_equal_approx(weather.thirst_mult(), 0.8) and game.save_extra["world/weather"]["nyc"] == "snow")
	weather.set_weather("rain")
	await frames(60)
	assert(weather.scent_range() < 1400.0 and weather.scent_range() > 700.0, "rain blends in over 10 s")
	assert(weather.roll("nyc") in ["clear", "snow", "rain"])
	weather.set_weather("clear", false)

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

	# enemy levels: stats come from the enemy's level, not the dog's
	var Levels: GDScript = load("res://scripts/systems/levels.gd")
	var l20: Dictionary = Levels.scale_for_level(rac.BASE, 20)
	assert(is_equal_approx(l20.hp, rac.BASE.hp * (1.0 + 0.15 * 19)), "level 20 raccoon hp = base x (1 + 0.15 x 19)")
	assert(is_equal_approx(l20.dmg, rac.BASE.dmg * (1.0 + 0.08 * 19)) and l20.level == 20)
	assert(rac.max_hp == rac.stats.hp and rac.stats.level == rac.level, "popped raccoon uses its level's hp")
	for r in get_nodes_in_group("raccoon") + get_nodes_in_group("prey"):
		assert(r.level >= 1 and r.level <= 22, "NYC band 1-20, +-2")
	var boss_lv := {"King of Raccoons": 6, "The Pideon Queen": 8, "The Rat Meister": 10}
	for b in get_nodes_in_group("boss"):
		assert(b.level == boss_lv[b.cfg.name] and b.cfg.level == b.level, "park boss level")
	assert(game.hedgehog.level == 15)

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

	# M1-5 XP rules: new curve, bonus point every 10 levels, low-enemy half XP, catch-up
	var XP: GDScript = load("res://scripts/systems/xp.gd")
	var total := 0
	for lv in range(1, 100):
		total += XP.needed(lv)
	assert(total == 31185, "sum of xp_needed 1..99")
	assert(player.xp_needed() == XP.needed(player.level))
	assert(XP.points_for(9) == 1 and XP.points_for(10) == 2)
	var low := Node2D.new()  # no `level` property yet (M1-1): treated as level 1
	assert(XP.scaled(100, 6, 0, low) == 50 and XP.scaled(100, 5, 0, low) == 100, "low enemy gives 50%")
	low.free()
	assert(XP.scaled(100, 9, 20) == 125 and XP.scaled(100, 10, 20) == 100, "catch-up +25% below HQ-10")

	# Boss Hedgehog loss keeps level and XP, keeps at most 20 treats
	var lv_before: int = player.level
	var xp_before: int = player.xp
	game.set_inside("boss")
	player.treats = 100
	player.take_damage(1e9)
	assert(player.level == lv_before and player.xp == xp_before, "hedgehog loss keeps level")
	assert(player.treats == 20)
	game.respawn()

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
	# bigger map: 9 x 7, old saves inside a collider or off the map land on a road
	assert(game.NX == 9 and game.NY == 7 and game.WORLD == Vector2(9 * 512 + 10 * 128, 7 * 384 + 8 * 128))
	assert(game.SHOP_ROOM.grow(1200).position.x > game.WORLD.x, "interiors clear of the streets")
	var old_spots: Array[Vector2] = [game.building_rects[0].get_center(), Vector2(6100, 200), Vector2(-50, 9000)]
	for spot: Vector2 in old_spots:
		v1.set_value("world", "pos", spot)
		v1.save(SAVE)
		game.load_game()
		assert(game.city.on_road(player.position) and not game.city.blocked(player.position), "old save pos %s lands on a road" % spot)
	var walkable: Vector2 = game.block_origin(Vector2i(1, 0)) + Vector2(256, 300)  # sidewalk in front of a building
	if not game.city.blocked(walkable):
		v1.set_value("world", "pos", walkable)
		v1.save(SAVE)
		game.load_game()
		assert(player.position == walkable, "a free spot is kept")
	game.save_game()
	var saved := ConfigFile.new()
	saved.load(SAVE)
	assert(saved.get_value("world", "pos") == player.position, "street position saved")
	var story: Node = root.get_node("Story")
	assert(story.flags.is_empty() and story.keycards.is_empty(), "v1 save: empty story")
	for k: String in Save.V2:
		if not k.begins_with("story/"):  # owned by Story, filled below
			game.save_extra[k] = {"synthetic": k}
	story.set_flag("ch1_bodega")
	story.add_item("lanyard")
	story.add_keycard("nyc")
	story.clear_floor("nyc_1", 41.5)
	var story_saved: Dictionary = story.to_save()
	game.vols.Music.value = 0.25
	game.save_game()
	game.save_extra = {}
	story.reset()
	game.vols.Music.value = 1.0
	game.load_game()
	assert(game.save_version == 2 and game.vols.Music.value == 0.25)
	for k: String in Save.V2:
		if not k.begins_with("story/"):
			assert(game.save_extra[k] == {"synthetic": k}, "v2 round trip " + k)
	assert(story.to_save() == story_saved, "story round trip")

	# Story gates: G1 needs level 20 + the NYC keycard; popup shows why and Find XP sets a waypoint
	story.reset()
	assert(story.objective() == "Find Sam's things at the bodega" and story.target() == story.NO_TARGET)
	story.spots["bodega"] = Vector2(100, 200)
	assert(story.target() == Vector2(100, 200))
	story.set_flag("ch1_bodega")
	assert(story.objective().contains("Fat Cat"))
	assert(not story.gate_open("G1", 20) and story.gate_block("G1", 20).contains("keycard"))
	story.add_keycard("nyc")
	assert(not story.gate_open("G1", 19) and story.gate_block("G1", 19) == "Level 20 required (you are 19)")
	assert(story.gate_open("G1", 20), "G1 open at 20 with keycard")
	assert(not story.gate_open("G2", 99) and story.gate_open("G0", 1))
	player.level = 19
	var GatePopup: GDScript = load("res://scripts/ui/gate_popup.gd")
	var popup: Node = GatePopup.open(game, "G1")
	assert(player.frozen and popup.req.text == "Level 20 required (you are 19)")
	bosses[1].show()  # all bosses were beaten above; stand one back up as open side content
	popup.find_btn.pressed.emit()
	assert(not player.frozen and story.waypoint == bosses[1].home, "Find XP sets the waypoint")
	bosses[1].hide()
	await frames(1)
	assert(not is_instance_valid(popup))
	story.reset()
	player.level = 5

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
