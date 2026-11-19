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

	# enemy tag (M1-2): shows after a hit, hides 3 s later; Lv colors; crit numbers
	rac.set_process(false)  # hold it still, away from the dog
	player.position = rac.position + Vector2(600, 0)
	await frames(1)
	assert(not rac.tag.visible, "tag hidden: far and unhurt")
	var rac_hp: float = rac.hp
	rac.hurt(1.0, player.position, true)
	assert(rac.tag.visible and rac.hp == rac_hp - 1.0, "tag shows after a hit")
	assert(game.get_child(-1).text == "1!", "crit number gets a !")
	await frames(170)
	assert(rac.tag.visible, "tag still up before 3 s")
	await frames(15)
	assert(not rac.tag.visible, "tag hides 3 s after the hit")
	rac.set_process(true)
	var Tag: GDScript = load("res://scripts/ui/enemy_tag.gd")
	assert(Tag.level_color(-5) != Color.WHITE and Tag.level_color(4) == Color.WHITE and Tag.level_color(9) != Tag.level_color(10))

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
		assert(root.get_node("Sound").current == "boss_fatcat", "boss fight takes over the music")
		assert(b.cfg.specials.size() == 2)
		for i in 2:  # both specials fire without errors
			b.special(Vector2.RIGHT)
		var treats: int = player.treats
		b.hurt(1e9, player.position)
		assert(game.boss == null and not b.visible, "boss beaten")
		assert(root.get_node("Sound").current == "nyc_jazz", "city music back after the boss")
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

	# music: room enter swaps the track with a crossfade; the same track again is a no-op
	assert(sound.current == "nyc_jazz", "street plays the city theme")
	var swaps: int = sound.swaps
	game.set_inside("shop")
	assert(sound.current == "interior_shop" and sound.swaps == swaps + 1, "shop swaps track")
	var p: AudioStreamPlayer = sound.players[sound.active]
	assert(p.playing and p.bus == "Music" and p.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	game.set_inside("shop")
	sound.music("interior_shop")
	assert(sound.swaps == swaps + 1 and sound.players[sound.active] == p, "same track is a no-op")
	sound.music("piano_nyc", sound.CUTSCENE)
	sound.music("boss_fatcat", sound.BOSS)
	assert(sound.current == "piano_nyc", "cutscene outranks boss")
	sound.music("", sound.CUTSCENE)
	assert(sound.current == "boss_fatcat", "boss outranks city")
	sound.music("", sound.BOSS)
	game.set_inside("")
	sound.night = true
	assert(sound.current == "nyc_jazz_night", "night variant")
	sound.night = false
	for t: String in sound.TRACKS:  # every placeholder loop builds
		assert(sound.stream(t).data.size() > 0, t)

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

	# economy (M4-1): discount never above 25%, stable shop rolls, struck price, x5 buy, bones saved
	var Economy: GDScript = load("res://scripts/systems/economy.gd")
	var eco: Node = game.economy
	for d: float in [-1.0, 0.0, 0.1, 0.25, 0.26, 0.9, 5.0]:
		for base: int in [1, 3, 5, 25, 100]:
			assert(Economy.final_price(base, 1.0, 1.0, d) >= maxi(1, roundi(base * 0.75)), "discount capped at 25%")
			assert(Economy.final_price(base, 1.0, 1.0, d) >= 1, "price min 1")
	for i in 50:
		var roll: float = Economy.shop_roll("nyc_bodega_%d" % i)
		assert(roll >= 0.85 and roll <= 1.15 and roll == Economy.shop_roll("nyc_bodega_%d" % i), "shop roll stable, in range")
	eco.set_discount("cat_mango", 0.10, "Mango likes you")
	eco.set_discount("block", 0.05, "Your block")
	eco.set_discount("test_extra", 0.30, "Test")
	assert(eco.discount() == 0.25 and "capped" in eco.discount_label(), "discount never above 25%")
	var roll0: float = Economy.shop_roll("nyc_bodega_0")
	assert(eco.price(100, "nyc_bodega_0") == roundi(100 * roll0 * 0.75))
	game.save_extra["world/city"] = "nyc"
	game.return_pos = game.bodega_doors[0]
	game.shop.refresh()
	var row0: Dictionary = game.shop.rows[0]
	assert("[s]" in row0.price.text, "discounted price strikes the list price")
	player.treats = 1000
	game.shop.buy(0, 1)  # first purchase pays the "Buy something" quest; get it out of the way
	player.treats = 1000
	var purina: int = player.purina
	var each: int = game.shop.price_of(0)
	assert(game.shop.buy(0, 5) == 5 and player.treats == 1000 - 5 * each and player.purina == purina + 5, "buy x5")
	player.treats = each - 1
	assert(game.shop.buy(0, 1) == 0 and player.treats == each - 1, "can't buy what you can't afford")
	for id in ["cat_mango", "block", "test_extra"]:
		eco.clear_discount(id)
	game.shop.refresh()
	assert(not "[s]" in row0.price.text and eco.discount_label() == "")
	eco.bones = 7
	game.save_game()
	eco.bones = 0
	game.load_game()
	assert(eco.bones == 7, "bones saved")
	var v1b := ConfigFile.new()
	v1b.set_value("dog", "level", 5)
	v1b.set_value("dog", "points", 0)
	v1b.save(SAVE)
	game.load_game()
	assert(eco.bones == 0, "v1 save: bones default 0")

	# city data (M2-2): rebuilding frees the old city, same layout, no leak
	var rects: int = game.building_rects.size()
	game.landmarks[0].seen = true
	game.city.build("nyc")
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	game.city.build("nyc")
	assert(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == nodes, "build twice, same node count")
	assert(game.building_rects.size() == rects and game.landmarks[0].seen, "same city, sights kept")
	paused = false  # the shop checks above leave the tree paused
	game.city.travel("nyc")
	await frames(45)
	assert(game.fade.color.a == 0.0 and not player.frozen and is_instance_valid(game.city.root), "travel fades back in")

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
