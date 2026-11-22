extends SceneTree
## Smoke test: bosses wake / die, the subway train kills, the death screen respawns.
## Run: godot --headless --fixed-fps 60 --path . -s tests/smoke.gd   (never saves)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	seed(7)  # same spawns and rolls every run: a failure reproduces instead of flaking
	var SAVE := "user://smoke_%d.cfg" % OS.get_process_id()  # throwaway save per run: parallel worktrees share user://
	DirAccess.remove_absolute(SAVE)

	# home screen: Continue hidden with no save (or a ui-only file); shown once a dog is saved;
	# New Story over a save asks first; settings never turn "no save" into a save
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Home.tscn", "launch on the home screen")
	var home: Control = load("res://scenes/Home.tscn").instantiate()
	home.save_path = SAVE
	root.add_child(home)
	await frames(1)
	assert(not home.continue_btn.visible, "no save: Continue hidden")
	assert(home.wardrobe_btn.disabled, "no save: home Wardrobe disabled")
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
	assert(home.free_roam.disabled, "Free Roam locked before ch1_clue")
	assert(not home.wardrobe_btn.disabled, "save: home Wardrobe opens")
	dog.set_value("story", "flags", ["ch1_clue"])
	dog.save(SAVE)
	home.show_menu()
	assert(not home.free_roam.disabled, "Free Roam opens at ch1_clue")
	home.new_story()
	assert(home.confirm_panel.visible and not home.menu.visible, "New Story over a save confirms")
	home.show_menu()
	home.free()
	DirAccess.remove_absolute(SAVE)

	var game: Node2D = load("res://scenes/Main.tscn").instantiate()
	game.save_path = SAVE
	game.rng_seed = 7  # game.gd reseeds after city.build; without this seed(7) above is thrown away
	root.add_child(game)
	await frames(2)
	var player: CharacterBody2D = game.player
	# quiet street: ambient prey / treats / traffic wander into the checks below (a stray catch
	# levels the dog and pauses the tree, a pickup shifts treat counts, a car knocks hp off)
	game.spawn_timer = INF
	for n: Node in get_nodes_in_group("prey") + get_nodes_in_group("foe") + game.treat_sprites:
		n.queue_free()
	game.treat_sprites.clear()
	for c: Node in get_nodes_in_group("car"):
		c.set_process(false)

	# cutscenes (M5-2): a new dog gets the intro; typewriter completes on a key, the next key
	# advances, Esc skips the rest and still sets the cutscene's flags
	var dlg: Node = game.dialog
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	assert(dlg.id == "cs_intro" and player.frozen and not game.hud.visible, "intro plays, dog frozen, HUD hidden")
	assert(root.get_node("Sound").layers[root.get_node("Sound").CUTSCENE] == "piano_nyc", "cutscene music layer")
	assert(dlg.typing() and dlg.text.visible_characters < dlg.text.text.length(), "typewriter types")
	var first: String = dlg.text.text
	root.push_input(key)
	assert(not dlg.typing() and dlg.text.text == first, "key completes the line")
	root.push_input(key)
	assert(dlg.text.text != first and dlg.typing(), "next key advances")
	await frames(30)  # 30 chars/s
	assert(dlg.text.visible_characters >= 13 and dlg.text.visible_characters <= 17, "about 30 chars/s")
	root.push_input(esc)
	assert(dlg.id == "" and root.get_node("Story").has("cs_intro"), "Esc skip still sets the flag")
	assert(not player.frozen and game.hud.visible and not paused, "skip hands control back")
	assert(root.get_node("Sound").layers[root.get_node("Sound").CUTSCENE] == "", "cutscene music cleared")
	game.save_extra["ui/reduce_motion"] = true
	dlg.play("cs_ch1_clue")
	assert(dlg.bars[0].scale.y == 1.0, "reduce motion: letterbox instant")
	root.push_input(esc)
	assert(root.get_node("Story").has("ch1_clue") and dlg.bars[1].scale.y < 0.01, "skip: bars gone")
	game.save_extra.erase("ui/reduce_motion")
	root.get_node("Story").reset()

	# flashbacks (M5-5): clearing nyc_1 plays fb_nyc_1 in the sepia room; F on each prop shows its
	# card; after the last one the dog is back where it was, fb_nyc_1 set = one polaroid; replay adds none
	var fb: Node = game.flashback
	var fb_story: Node = root.get_node("Story")
	var shots := func(): return fb_story.flags.filter(func(f): return f.begins_with("fb_")).size()
	var fb_at: Vector2 = player.position
	game.save_extra["ui/reduce_motion"] = true
	fb.clear_floor("nyc_1", 30.0)
	await frames(1)
	assert(game.inside == "flashback" and fb.playing() and game.night.color == game.interior.tint, "sepia flashback room")
	assert(is_instance_valid(fb.sam) and not fb_story.has("fb_nyc_1"), "Sam is there, no polaroid yet")
	for k in fb.props.size():
		player.position = game.interior.O + fb.props[k][1]
		await frames(1)
		assert(game.menu.visible and fb.near() == k, "prop prompt")
		var f_key := InputEventKey.new()
		f_key.keycode = KEY_F
		f_key.pressed = true
		root.push_input(f_key)
		assert(dlg.playing() and dlg.text.text == fb.props[k][4], "F shows the prop card")
		root.push_input(esc)
	await frames(2)
	assert(game.inside == "" and player.position == fb_at and not fb.playing() and not player.frozen, "back on the street")
	assert(fb_story.has("fb_nyc_1") and shots.call() == 1, "clearing nyc_1 sets fb_nyc_1, one polaroid")
	assert(fb_story.floors.has("nyc_1"))
	game.inventory.toggle()
	var album_grid: GridContainer = game.inventory.album.get_child(0)
	assert(album_grid.get_child_count() == 17 and not album_grid.get_child(0).disabled and album_grid.get_child(1).disabled, "album: 17, found one replayable")
	album_grid.get_child(0).pressed.emit()
	assert(not game.inventory.is_open() and game.inside == "flashback", "album replay")
	for k in fb.props.size():
		fb.inspect(k)
		root.push_input(esc)
	await frames(2)
	assert(game.inside == "" and shots.call() == 1, "replay adds no polaroid")
	game.save_extra.erase("ui/reduce_motion")
	fb_story.reset()

	# level-up: three stat points, no popup, game keeps running; spent from the bag's STATS panel
	var hp_cap: float = player.max_hp
	player.add_xp(player.xp_needed())
	assert(player.points == 3 and not paused, "level-up gives 3 points and never pauses")
	game.pick_stat(0)
	assert(player.points == 2 and player.max_hp == hp_cap + 5.0, "+3 from the point, +2 from the level")
	game.inventory.toggle()
	assert(game.inventory.stats_box.get_child_count() > 3, "bag shows the STATS panel")
	game.inventory.toggle()
	while player.points > 0:
		game.pick_stat(1)
	game.pick_stat(1)  # no points: no-op
	assert(player.stat_atk == 2)
	# armor: buying wears it, hits are cut, starving ticks are not
	player.armor_owned = ["vest"]
	player.armor = "vest"
	var hp0: float = player.hp
	player.take_damage(10.0)
	assert(is_equal_approx(hp0 - player.hp, 8.8), "vest cuts 12% of a hit")
	var vest_art: Texture2D = load("res://scripts/data/wardrobe.gd").icon("vest")
	assert(player.sprite.get_node("Gear").get_children().any(func(s): return s.texture == vest_art), "worn vest drawn on the dog")
	player.hp = player.max_hp
	player.armor = ""
	assert(not player.sprite.get_node("Gear").get_children().any(func(s): return s.texture == vest_art), "vest off the dog")
	player.armor_owned = []
	# keys: E bag, K stats, no Q / E quick use (hotbar 1-4 does that)
	var keys: GDScript = load("res://scripts/systems/keys.gd")
	assert(keys.keys_of("inventory") == [KEY_E] and not keys.DEFAULTS.has("purina") and not keys.DEFAULTS.has("water"))
	keys.apply({"inventory": [KEY_I], "water": [KEY_E]})  # old save layout migrates to E
	assert(keys.keys_of("inventory") == [KEY_E], "old I / E layout moves the bag to E")
	keys.apply({})
	# loading card on doors; corner boxes exist; map key only on the big map
	assert(game.ui.corner.size() == 6 and game.ui.corner.has("stats"))
	# full map hides the HUD (stats, minimap, quests, docks); quest tracker minimizes
	game.toggle_map()
	await frames(2)
	assert(not game.mini.visible and game.ui.map_hide.all(func(n): return not n.visible), "map hides the HUD")
	game.toggle_map()
	await frames(2)
	assert(game.mini.visible and game.ui.map_hide.all(func(n): return n.visible), "HUD back after the map")
	game.ui.quest_btn.pressed.emit()
	assert(not game.quest_label.visible, "quest tracker minimizes")
	game.ui.quest_btn.pressed.emit()
	assert(game.quest_label.visible, "quest tracker expands")

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
	# reduce motion (spec 11): shake is tracked but the camera stays still
	game.save_extra["ui/reduce_motion"] = true
	game.shake_amt = 10.0
	await frames(1)
	assert(game.cam.offset == Vector2.ZERO, "reduce motion: no screen shake")
	game.save_extra["ui/reduce_motion"] = false
	# large text (spec 11): existing and newly built labels scale 1.25x, and back
	var lbl: Label = game.ui.hud_label(game.hud, 16)
	game.save_extra["ui/large_text"] = true
	game.Look.set_big_text(game, true)
	assert(lbl.get_theme_font_size("font_size") == 20, "large text scales labels")
	var later: Label = game.ui.hud_label(game.hud, 16)
	assert(later.get_theme_font_size("font_size") == 20, "large text scales new labels")
	game.save_extra["ui/large_text"] = false
	game.Look.set_big_text(game, false)
	assert(lbl.get_theme_font_size("font_size") == 16, "large text off restores size")
	lbl.free()
	later.free()
	var kids: int = game.get_child_count()
	game.poof(player.position, Color.WHITE, 10, 70.0)
	assert(game.get_child_count() == kids + 1 and game.get_child(-1).amount == 10, "poof takes amount")
	# weather: snow sets sprint to 0.9; changes blend over 10 s; today's weather is saved
	var weather: Node = game.weather
	weather.set_weather("snow", false)
	assert(weather.current == "snow" and is_equal_approx(weather.sprint_mult(), 0.9), "snow sets sprint multiplier to 0.9")
	assert(is_equal_approx(weather.thirst_mult(), 0.8) and game.save_extra["world/weather"]["nyc"] == "snow")
	weather.set_weather("rain")
	await frames(60)
	assert(weather.scent_range() < 1400.0 and weather.scent_range() > 700.0, "rain blends in over 10 s")
	assert(weather.roll("nyc") in ["clear", "snow", "rain"])
	# M6-2 fog: veil around the dog, fog banks roll, sight drops to 260
	weather.set_weather("fog", false)
	await frames(2)
	assert(weather.fog.visible and weather.banks.emitting and weather.fog.position == player.position, "fog veil follows the dog")
	assert(is_equal_approx(weather.sight_radius(), 260.0), "fog limits sight")
	weather.set_weather("clear", false)
	await frames(2)
	assert(not weather.fog.visible and not weather.banks.emitting, "clear skies, no fog")
	# M3-5 audio: surface lookup (grass inside a park), one step sound per step, ambience ducks indoors
	var au_steps: Node = game.steps
	var au_park: Rect2 = game.parks[0]
	var au_street: Vector2 = au_park.position - Vector2(8, 8)
	assert(game.parks.all(func(r: Rect2) -> bool: return not r.has_point(au_street)))
	assert(au_steps.surface(au_park.get_center()) == "grass", "surface lookup is grass inside a park")
	assert(au_steps.surface(au_street) == "concrete", "street is concrete")
	weather.set_weather("rain", false)
	assert(au_steps.surface(au_street) == "puddle" and au_steps.surface(au_park.get_center()) == "grass", "rain: puddles off the grass")
	weather.set_weather("snow", false)
	assert(au_steps.surface(au_park.get_center()) == "snow", "snow covers everything")
	weather.set_weather("clear", false)
	var au_snd: Node = root.get_node("Sound")
	for au_s in ["concrete", "grass", "puddle", "snow", "wood"]:
		assert(au_snd.sounds["step_" + au_s] is AudioStreamWAV)
	var au_kids := au_snd.get_child_count()
	player.velocity = Vector2(100, 0)
	au_steps.step_t = 0.0
	au_steps._process(0.0)
	au_steps._process(0.1)
	assert(au_snd.get_child_count() == au_kids + 1, "one step, then wait 0.28 s")
	au_steps._process(0.2)
	assert(au_snd.get_child_count() == au_kids + 2, "second step after 0.28 s")
	player.velocity = Vector2.ZERO
	assert(au_steps.amb.playing and au_steps.amb.bus == "Ambience" and is_equal_approx(au_steps.amb.volume_db, au_steps.AMB_DB))
	game.inside = "shop"
	assert(au_steps.surface(player.position) == "wood", "interiors are wood")
	au_steps._process(0.0)
	assert(is_equal_approx(au_steps.amb.volume_db, au_steps.AMB_DB + au_steps.DUCK_DB), "ambience ducks 12 dB indoors")
	game.inside = ""
	au_steps._process(0.0)

	# scent trail (M5-3): hold V, the road-grid path ends at the story target, the GPS edge
	# arrow points at it off screen, rain cuts the range; prints stay after release; Biscuit's ball wins
	var sc: Node2D = game.get_node("Scent")
	var sc_pos: Vector2 = player.position
	var sc_to: Vector2 = root.get_node("Story").target()
	assert(sc_to == game.bodega_doors[0], "story target: the bodega")
	player.position = game.city.fix_pos(sc_to + Vector2(3000, 2000))
	game.cam.reset_smoothing()
	Input.action_press("sniff")
	await frames(2)
	var sc_path: PackedVector2Array = sc.trail
	assert(sc_path[-1] == sc_to, "scent path ends at the target")
	for i in sc_path.size() - 1:
		var sc_d: Vector2 = (sc_path[i + 1] - sc_path[i]).abs()
		assert(minf(sc_d.x, sc_d.y) < 0.5, "scent path runs along the grid")
		assert(i == 0 or game.city.on_road(sc_path[i]), "scent path walks the roads")
	assert(game.waypoint.pos == sc_to and not game.ui.waypoint_arrow().is_empty(), "edge arrow at the off-screen target")
	var sc_clear: int = sc.paws().size()
	weather.set_weather("rain", false)
	var sc_rain: int = sc.paws().size()
	assert(sc_clear * sc.GAP > 1500.0 and sc_rain * sc.GAP <= 700.0 and sc_rain > 0, "shorter scent range in rain")
	Input.action_release("sniff")
	await frames(1)
	assert(not sc.trail.is_empty(), "trail stays after V is let go")
	sc.left = 0.01
	await frames(2)
	assert(sc.trail.is_empty(), "trail fades out")
	var sc_park: Node = get_nodes_in_group("dog_park")[0]
	sc_park.ball = sc_to + Vector2(0, 200)
	assert(sc.target() == sc_park.ball, "scent leads to Biscuit's ball while it is out")
	sc_park.ball = Vector2.ZERO
	weather.set_weather("clear", false)
	game.waypoint = {}
	player.position = sc_pos
	game.cam.reset_smoothing()

	# cars: one per lane, and they hurt
	var cars := get_nodes_in_group("car")
	assert(cars.size() == 2 * (game.NX + 1) + 2 * (game.NY + 1))
	cars[0].position = Vector2(32, 1000)  # cars start at random spots; pin one mid-block, clear of steam and cross traffic
	cars[0].set_process(true)
	player.hp = player.max_hp
	player.position = cars[0].position
	await frames(2)
	cars[0].set_process(false)
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
	# facing follows travel, not the dog: walking home (left, dog to the right) faces left
	rac.position = rac.home + Vector2(120, 0)
	rac.state = rac.State.RETURN
	await frames(2)
	assert(rac.sprite.flip_h, "raccoon walking home faces the way it walks")
	rac.state = rac.State.CHASE

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
		assert(r.level >= 1 and r.level <= 24, "NYC band 1-20, +-2, night +2")
	# spawns (M3-1): night table has no pigeons, phases split on sun(), prey cap scales with area
	var Spawns = load("res://scripts/data/spawns.gd")
	for i in 200:
		assert(Spawns.pick("nyc", 0.1) != "pigeon", "night spawns have no pigeons")
	assert(Spawns.phase(0.7) == "day" and Spawns.phase(0.4) == "dusk" and Spawns.phase(0.1) == "night")
	assert(Spawns.cap(36, Vector2i(9, 7)) == 75, "cap 36 x 63 / 30 blocks")
	# pigeon flocks (M3-4): 5-12 birds; catch one and the rest flee; regroup at a new center
	var flock: Dictionary = game.spawner.spawn_flock(player.position + Vector2(300, 0))
	assert(flock.members.size() >= 5 and flock.members.size() <= 12, "flock of 5-12")
	await frames(1)
	assert(flock.members.all(func(p): return not p.fleeing), "calm flock 300 px away")
	var caught: Node2D = flock.members[0]
	game.on_prey_caught(caught)
	await frames(2)
	assert(flock.members.size() >= 4 and not caught in flock.members and flock.members.all(func(p): return p.fleeing), "catch one, all flock members flee")
	var old_center: Vector2 = flock.center
	flock.scatter = 0.01
	await frames(2)
	assert(flock.scatter <= 0.0 and flock.center != old_center, "flock regroups at a new center")
	for p in flock.members:
		p.queue_free()
	# elevators (M2-4): lobby to floor 3 and back; landmarks have 6 floors and a roof
	var tall: Dictionary = game.doors.filter(func(d): return d.template in ["apartment", "office"] and d.floors >= 3)[0]
	assert(game.doors.filter(func(d): return d.floors == 6).size() == 2, "both landmarks have 6 floors")
	game.interior.enter(tall)
	assert(game.ui.loading.visible, "door shows a loading card")
	player.position = game.interior.spots.elevator
	await frames(1)
	assert(game.ctx == "elevator", "elevator menu at the elevator spot")
	game.on_number(2)
	await frames(45)
	assert(game.interior.floor_n == 2 and player.position == game.interior.spots.elevator and not player.frozen, "rode to floor 3")
	player.position = game.interior.spots.exit
	await frames(1)
	assert(game.act != "exit", "no street exit above the lobby")
	player.position = game.interior.spots.elevator
	await frames(1)
	game.on_number(0)
	await frames(45)
	assert(game.interior.floor_n == 0, "back in the lobby")
	game.interior.leave()
	# airport (M2-6): NYC gate is "here", SF is locked with its hint until ch1_clue
	var port: Dictionary = game.doors.filter(func(d): return d.template == "airport")[0]
	game.interior.enter(port)
	player.position = game.interior.spots.gates
	await frames(1)
	assert(game.ctx == "airport", "gate menu at the desk")
	var gates: Array = game.interior.gate_rows()
	assert(not gates[0][1] and "here" in gates[0][0], "NYC gate is where you are")
	assert(not gates[1][1] and "NYC Hack Club HQ" in gates[1][0], "locked gate shows its hint")
	var st: Node = root.get_node("Story")  # -s scripts can't see autoload names at compile time
	st.set_flag("ch1_clue")
	assert(game.interior.gate_rows()[1][1], "ch1_clue opens the SF gate")
	# M6-1: fly to SF, land at SFO, arrival cutscene once, then fly home
	var nyc_hq: Vector2 = game.doors.filter(func(d): return d.template == "hq")[0].pos
	game.on_number(1)
	await frames(50)
	assert(game.city.id == "sf" and game.inside == "", "landed in SF on the street")
	assert(game.save_extra["world/city"] == "sf", "save knows the city")
	assert(game.landmarks.size() == 2 and game.landmarks.any(func(l): return l.name == "Coit Tower"), "SF landmarks")
	assert(game.stations.size() == 4 and game.bodega_doors.size() == 3, "4 cable car stops, 3 corner stores")
	var sfo: Array = game.doors.filter(func(d): return d.template == "airport")
	assert(sfo.size() == 1 and sfo[0].name == "SFO Airport" and player.position.distance_to(sfo[0].pos) < 200.0, "dog at SFO")
	assert(not game.doors.any(func(d): return d.template in ["burrow", "nyse"]), "no NYC-only doors in SF")
	var sf_store: Dictionary = game.doors.filter(func(d): return d.template == "bodega" and d.pos == game.bodega_doors[0])[0]
	game.interior.enter(sf_store)
	assert(game.cats.here() == ["sf_sourdough", "Sourdough"], "M6-3: SF corner store 0 has Sourdough")
	var sf_park: Node = get_nodes_in_group("dog_park")[0]
	assert(sf_park.dogs.keys() == ["Pixel", "Fogarty", "Captain"], "M6-6: SF dog park dogs")
	assert(sf_park.lines_for("Pixel")[0].contains("cable car") and game.stats.get("met_pixel") == 1, "Pixel starts the cable car line")
	game.stats.erase("met_pixel")
	game.interior.leave()
	await frames(2)
	var sf_bosses: Array = game.park_bosses.get_children().map(func(b): return b.cfg.name)
	assert(sf_bosses == ["Sea Lion Sal", "The Twin Peaks Coyote"], "SF park bosses, NYC's stay home: %s" % [sf_bosses])
	assert(st.spots.get("sf_pier", Vector2.ZERO) != Vector2.ZERO, "the pier is a story spot")
	assert(st.spots.get("hq_sf", Vector2.ZERO) != Vector2.ZERO, "SF HQ is a story spot")
	assert(game.dialog.playing(), "cs_arrive_sf plays on the first landing")
	game.dialog.skip()
	await frames(2)
	assert(st.has("cs_arrive_sf"), "skip still sets the arrival flag")
	# SF Pest Patrol: SF critters, skunk stink, coyote packs, quakes, the line shows on landing
	assert(game.stats.get("met_sf") == 1 and game.quest_step.get("SF Pest Patrol") == 1, "Pest Patrol starts on landing: %s %s" % [game.stats.get("met_sf"), game.quest_step.get("SF Pest Patrol")])
	var sf_day: Dictionary = game.Spawns.SPAWNS.sf.day
	assert(sf_day.has("parrot") and sf_day.has("gopher") and game.Spawns.SPAWNS.sf.night.has("coyotes"), "SF spawn table")
	var pest_keep := [player.level, player.xp, player.treats]  # put back after: later checks count exact treats
	var pack: Array = game.spawner.spawn_foe("coyotes", player.position + Vector2(900, 0))
	assert(pack.size() == 3 and pack.all(func(c): return c.kind == "coyote"), "coyotes come in packs of 3")
	var skunk: Node2D = game.spawner.spawn_foe("skunk", player.position + Vector2(900, 60))[0]
	var skunk_hp0: float = player.hp
	skunk.swipe(player.position - skunk.position)
	assert(player.hp < skunk_hp0 and player.poison_t > 0.0, "skunk spray stinks (poison)")
	player.poison_t = 0.0
	player.hp = player.max_hp
	skunk.hurt(9999.0, player.position)
	assert(game.stats.get("skunks") == 1, "beaten skunk counts for the patrol")
	for c in pack:
		c.queue_free()
	var parrots: Dictionary = game.spawner.spawn_flock(player.position + Vector2(-900, 0), 0, "parrot")
	assert(parrots.members[0].kind == "parrot" and parrots.members[0].sprite.texture != null, "parrot flock, baked art")
	var gopher: Node2D = game.PreyScript.new()
	gopher.position = player.position + Vector2(-900, 200)
	game.add_child(gopher)
	gopher.setup("gopher", game.PREY.gopher, game.spawner.tex_for("gopher"), game)
	assert(gopher.home == gopher.position, "gopher remembers its hole")
	game.on_prey_caught(gopher)
	assert(game.stats.get("gophers") == 1, "gopher catch counts")
	var parrots_before := int(game.stats.get("parrots", 0))
	game.weather.quake()
	assert(game.weather.quake_t > 0.0 and game.stats.get("quakes") == 1, "SF quake")
	assert(int(game.stats.get("parrots", 0)) == parrots_before + parrots.members.size(), "quake scatters the parrots")
	game.weather.quake_t = 0.0
	for p in parrots.members:
		p.queue_free()
	player.level = pest_keep[0]
	player.xp = pest_keep[1]
	player.treats = pest_keep[2]
	var sal: Node2D = game.park_bosses.get_child(0)
	sal.special_n = -1
	sal.special(Vector2.RIGHT)  # wave_splash
	assert(sal.marks.size() == 24, "wave splash: 3 rings of 8")
	sal.clear_shots()
	var yote: Node2D = game.park_bosses.get_child(1)
	yote.special_n = -1
	yote.special(Vector2.RIGHT)  # fog_cloak
	await frames(2)
	assert(yote.cloak_t > 0.0 and yote.sprite.self_modulate.a < 0.5, "coyote fades into the fog")
	yote.hurt(1.0, player.position)
	assert(yote.cloak_t == 0.0 and yote.sprite.self_modulate.a == 1.0, "a hit reveals it")
	if game.dialog.playing():  # the hit woke it: intro
		game.dialog.skip()
	yote.special(Vector2.RIGHT)  # charge
	yote.special(Vector2.RIGHT)  # howl
	assert(yote.minions.size() == 2 and yote.shots.size() == 10, "howl: 2 pups + a ring")
	yote.clear_shots()
	yote.state = yote.State.IDLE
	game.on_boss_left(yote)
	st.flags.erase("cs_coyote_pre")
	# Good Boy AI tycoon: Patch's pitch once, found, hire, ship the beta, grow, raise, move, collect
	var garage: Array = game.doors.filter(func(d): return d.template == "startup")
	assert(garage.size() == 1, "one startup garage in SF")
	game.interior.enter(garage[0])
	assert(game.inside == "startup" and game.dialog.playing(), "Patch pitches on the first visit")
	game.dialog.skip()
	player.position = game.interior.spots.pitch
	await frames(2)
	var su: Node = game.startup
	su.rng.seed = 7  # random company events stay the same every run
	assert(game.ctx == "startup" and su.rows()[0][0].contains("Found"), "founder's desk menu")
	var su_treats: int = player.treats
	player.treats = 20000
	game.on_number(0)
	assert(su.founded() and player.treats == 19850 and game.dialog.playing(), "founded for 150, cutscene")
	game.dialog.skip()
	assert(su.revenue() == 0.0 and su.growth() == 0.0, "no product, no users")
	game.on_number(0)  # Team & hiring
	game.on_number(0)  # engineer
	assert(su.staff("eng") == 1 and su.page == "hire", "hired an engineer")
	for i in 3:
		game.on_number(2)  # marketers
	game.on_number(1)  # designer: the garage holds 4
	assert(su.headcount() == 4 and su.staff("des") == 0, "garage team cap is 4")
	game.on_number(4)  # back
	assert(su.page == "main", "back to the main page")
	await frames(1)
	assert(su.office.get_children().filter(func(c): return c.is_in_group("startup_staff")).size() == 4, "a dog at each desk")
	for i in 30:
		su.tick()
	assert(su.f("dev") >= su.dev_need() and su.f("users") == 0.0, "dev points pile up, still no users")
	game.on_number(2)  # ship the beta
	assert(su.n("version") == 1 and game.dialog.playing(), "PawFinder beta cutscene")
	game.dialog.skip()
	assert(st.has("startup_lead"), "the beta points at the pier")
	for i in 200:
		su.tick()
	assert(su.f("users") == su.user_cap(), "users grow until the laptop is full")
	assert(su.revenue() > su.salaries(), "the beta pays its way")
	game.on_number(1)  # upgrades
	game.on_number(1)  # server rack
	assert(su.user_cap() == 2500 and su.office.get_children().any(func(c): return c is Sprite2D and c.texture == su.tex("su_server")), "rack bought and drawn")
	game.on_number(0)  # the loft needs a seed round first
	assert(su.n("office") == 0, "no move before the seed round")
	game.on_number(5)
	game.on_number(4)  # raise seed
	assert(su.n("round") == 1 and su.f("bank") > 600.0 and game.dialog.playing(), "seed round lands in the bank")
	game.dialog.skip()
	game.on_number(1)
	game.on_number(0)  # move to the loft
	assert(su.n("office") == 1 and su.team_cap() == 8, "moved to the SoMa loft")
	assert(is_instance_valid(su.front) and su.front.texture.resource_path.ends_with("startup_1.png"), "the street front becomes the loft")
	assert(int(game.quest_step.get("Good Boy AI", 0)) == 6, "Good Boy AI quest line follows the company")
	game.on_number(5)
	var su_bank: int = su.owed()
	var su_before: int = player.treats
	game.on_number(5)  # collect
	assert(player.treats == su_before + su_bank and su.owed() == 0, "collected the bank")
	su.state().bank = -100.0
	su.state().users = 0.0
	su.tick()
	assert(su.headcount() == 3, "out of runway: a hire quits")
	player.treats = su_treats
	game.save_extra.erase("startup/state")
	game.quest_step.erase("Good Boy AI")
	for k: String in ["met_patch", "su_found", "su_hires", "su_ships", "su_rounds", "su_moves"]:
		game.stats.erase(k)
	for f: String in ["cs_startup_intro", "cs_startup_found", "startup_lead", "cs_startup_seed"]:
		st.flags.erase(f)
	game.interior.leave()
	await frames(2)
	# M6-4 Seagull King: pier bait crate plays the intro, the kill drops the SF keycard + Sam's backpack
	var pier: Array = game.doors.filter(func(d): return d.template == "pier")
	assert(pier.size() == 1, "one pier in SF")
	game.interior.enter(pier[0])
	var gull: Array = get_nodes_in_group("boss").filter(func(b): return b.cfg.name == "Seagull King")
	assert(gull.size() == 1 and gull[0].state == gull[0].State.IDLE, "Seagull King waits on the pier")
	player.hp = player.max_hp
	player.position = game.interior.spots.podium
	await frames(2)
	assert(game.dialog.id == "cs_seagull_pre", "bait crate plays the intro")
	game.dialog.skip()
	await frames(2)
	assert(gull[0].state == gull[0].State.CHASE, "then the fight starts")
	for i in 3:  # dive, feathers, gust (any order)
		gull[0].special(Vector2.RIGHT)
	gull[0].state = gull[0].State.CHASE
	var gust_from: Vector2 = player.position
	assert(gull[0].gust_t > 0.0, "gust blows")
	await frames(10)
	assert(player.position.x > gust_from.x + 20.0, "gust pushes the dog back")
	gull[0].hurt(gull[0].max_hp * 0.45, player.position)
	assert(gull[0].phase == 1 and "storm" in gull[0].specials(), "phase 2 below 60%")
	for i in 4:  # fish_rain, dive, flock_call, storm
		gull[0].special(Vector2.RIGHT)
	gull[0].state = gull[0].State.CHASE
	assert(gull[0].marks.any(func(m): return m.fish == 2) and gull[0].minions.size() == 3, "fish rain + flock")
	for m in gull[0].minions:  # only the fish matter here: no flock, no feathers, boss held still
		m.queue_free()
	gull[0].minions.clear()
	for sh in gull[0].shots:
		sh.s.queue_free()
	gull[0].shots.clear()
	gull[0].stun_t = 5.0
	player.position = game.interior.rect.position + Vector2(60, 60)  # far corner while the fish land
	await frames(int((gull[0].MARK_WARN + 0.7) * 60.0))
	assert(gull[0].shots.any(func(s): return s.s.texture == gull[0].fish()), "landed fish flop out")
	player.position = game.interior.spots.podium
	player.hp = player.max_hp
	gull[0].hurt(1e9, player.position)
	assert(st.has_keycard("sf") and "backpack" in st.items and st.has("ch2_boss"), "SF keycard + backpack")
	assert(game.dialog.id == "cs_seagull_post", "post-fight cutscene")
	game.dialog.skip()
	while player.points > 0:
		game.pick_stat(1)
	await frames(2)
	game.interior.leave()
	game.interior.enter(pier[0])
	assert(get_nodes_in_group("boss").filter(func(b): return b.cfg.name == "Seagull King").is_empty(), "beaten: gone for good")
	game.interior.leave()
	await frames(2)
	for f: String in ["ch2_boss", "cs_seagull_post"]:
		st.flags.erase(f)
	st.keycards.erase("sf")
	st.items.erase("backpack")
	player.points = 0  # the Seagull's XP levels the dog; close the stat picker (it pauses the tree)
	game.show_stats()
	await frames(1)
	game.interior.enter(sfo[0])
	player.position = game.interior.spots.gates
	await frames(1)
	assert(game.interior.gate_rows()[1][0].contains("here"), "SF gate is where you are")
	assert(game.ctx == "airport", "gate menu up: ctx=%s inside=%s dialog=%s paused=%s act=%s" % [game.ctx, game.inside, game.dialog.playing(), paused, game.act])
	game.on_number(0)
	await frames(50)
	assert(game.city.id == "nyc" and game.park_bosses.get_child_count() == 3, "flew home to NYC, its 3 park bosses back: %s %s stars=%d frozen=%s" % [game.city.id, game.park_bosses.get_children().map(func(n): return n.name), game.wanted.stars(), player.frozen])
	assert(game.doors.filter(func(d): return d.template == "hq")[0].pos == nyc_hq, "NYC rebuilt the same")
	assert(not game.dialog.playing(), "no arrival cutscene for NYC")
	st.flags.erase("ch1_clue")
	st.flags.erase("cs_arrive_sf")
	# NYC shops (M4-2): gas / pizza / cafe exist; cafe locked at night; a buff times out
	for t in ["gas", "pizza", "cafe"]:
		assert(game.doors.any(func(d): return d.template == t), "NYC has a " + t)
	var cafe: Dictionary = game.doors.filter(func(d): return d.template == "cafe")[0]
	var tod0: float = game.tod
	game.tod = 0.0  # midnight
	player.position = cafe.pos
	await frames(1)
	assert(game.act == "closed", "cafe locked at night")
	game.tod = 0.5  # noon
	await frames(1)
	assert(game.act == "enter", "cafe open by day")
	game.tod = tod0
	game.interior.enter(cafe)
	assert(game.shop.stock()[0][0] == "puppuccino", "cafe sells drinks")
	player.treats = 100
	assert(game.shop.buy(0) == 1 and game.inventory.count("puppuccino") == 1 and not player.buffs.has("drink"), "bought drink goes in the bag")
	assert(game.inventory.icon_of("puppuccino") != null and game.inventory.icon_of("kevlar") != null, "shop items have icons")
	game.inventory.bind("puppuccino", 2)
	game.inventory.use_slot(2)  # in a shop 1-4 buy, so drive the slot directly
	assert(game.inventory.count("puppuccino") == 0 and not player.bag.has("puppuccino"), "hotbar slot 3 uses it up")
	assert(player.buffs.drink.id == "puppuccino" and player.mod("stamina") == 1.5, "drink buff on")
	game.inventory.clear_slot(2)
	await frames(1)
	assert(game.ui.buff_row.get_node("drink").visible, "buff chip shows")
	player.buffs.drink.t = 0.05
	await frames(6)
	assert(not player.buffs.has("drink") and player.mod("stamina") == 1.0, "buff timer runs down")
	game.interior.leave()
	# UI overhaul: inventory opens / freezes / closes; hotbar binds and uses a slot; long menus fit
	assert(game.hud.theme != null, "HUD theme set")
	game.inventory.toggle()
	assert(game.inventory.is_open() and player.frozen, "E opens the inventory")
	assert(game.inventory.root.get_child_count() == 4 and game.inventory.ground.get_child_count() == 16
		and game.inventory.bag.get_child_count() == 25, "ground / equipment / inventory panels (+ hidden album)")
	game.inventory.bind("water", 3)
	game.inventory.toggle()
	assert(not game.inventory.is_open() and not player.frozen, "E closes it")
	assert(game.inventory.hotbar()[3] == "water" and game.inventory.hotbar()[1] == "", "bind moves water to slot 4")
	player.water = 1
	player.thirst = 10.0
	game.on_number(3)
	assert(player.water == 0 and player.thirst > 10.0, "hotbar slot 4 drinks")
	assert(game.menu_rows.size() >= 7, "menu fits a landmark elevator")
	await frames(1)  # HUD hotbar refreshes in _process
	assert(game.inventory.hud_slots[3].icon.texture != null, "HUD hotbar slot 4 shows water")
	# wardrobe (M4-11): B opens it, buy + equip the bodega cap, locked items stay locked, hat survives save / load
	var wr: Node = game.wardrobe
	wr.toggle()
	assert(wr.is_open() and player.frozen and wr.tabs.get_child_count() == 3, "B opens the wardrobe (no skin tab)")
	assert(not wr.Wardrobe.SLOTS.has("skin") and not game.Keys.DEFAULTS.has("breed"), "no breed swapping")
	player.treats = 50
	wr.pick("bodega_cap")
	wr.press()
	assert(player.treats == 10 and wr.equipped().hat == "bodega_cap", "buy + equip the bodega cap")
	wr.pick("beanie")
	wr.press()
	assert(wr.equipped().hat == "bodega_cap" and not wr.owns("beanie") and wr.button.disabled, "beanie is locked")
	wr.toggle()
	assert(not wr.is_open() and not player.frozen)
	var gear: Node2D = player.sprite.get_node("Gear")
	var cap: Texture2D = wr.Wardrobe.icon("bodega_cap")
	assert(gear.get_children().any(func(s): return s.texture == cap), "cap drawn on the dog")
	player.sprite.flip_h = true
	await physics_frame
	await physics_frame
	assert(gear.scale.x == -1.0, "gear flips with the dog")
	game.save_game()
	game.save_extra["wardrobe/equipped"] = {}
	player.apply_skin()
	assert(player.sprite.get_node("Gear").get_child_count() == 0)
	game.load_game()
	assert(wr.equipped().hat == "bodega_cap" and "bodega_cap" in wr.owned_list(), "hat saved")
	assert(player.sprite.get_node("Gear").get_children().any(func(s): return s.texture == cap), "hat still on after reload")
	# key bindings: rebind dash to V, V dashes, C no longer does; reset brings C back
	var Keys = load("res://scripts/systems/keys.gd")
	Keys.rebind("dash", KEY_V)
	var press := func(k: Key):
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		game._unhandled_key_input(ev)
	player.stamina = 100.0
	player.dash_cd = 0.0
	press.call(KEY_C)
	assert(player.dash_cd == 0.0, "old key unbound")
	press.call(KEY_V)
	assert(player.dash_cd > 0.0, "rebound key dashes")
	Keys.reset()
	assert(Keys.keys_of("dash") == [KEY_C] and Keys.keys_of("move_up") == [KEY_W, KEY_UP], "reset to defaults")
	await frames(20)  # let the dash finish
	# GPS (M2-5): clicking near a bodega sets the waypoint; far away the edge arrow points at it
	game.set_waypoint(game.bodega_doors[0] + Vector2(20, 0))
	assert(not game.waypoint.is_empty() and game.waypoint.pos.distance_to(game.bodega_doors[0]) < 250.0, "waypoint on a bodega")
	var wp: Vector2 = game.waypoint.pos
	var off: Vector2 = wp.direction_to(game.WORLD / 2.0) * 2000.0
	player.position = wp + off
	game.cam.reset_smoothing()
	await frames(2)
	var arrow: Dictionary = game.ui.waypoint_arrow()
	assert(not arrow.is_empty() and arrow.dir.dot(-off.normalized()) > 0.8, "edge arrow points at the waypoint")
	player.position = wp
	await frames(1)
	assert(game.waypoint.is_empty(), "arriving clears the waypoint")
	st.set_waypoint(wp + Vector2(500, 0))
	assert(game.waypoint.pos == wp + Vector2(500, 0), "Find XP waypoint shows on the GPS")
	st.set_waypoint(st.NO_TARGET)
	assert(game.waypoint.is_empty())
	var boss_lv := {"King of Raccoons": 6, "The Pideon Queen": 8, "The Rat Meister": 10}
	for b in get_nodes_in_group("boss"):
		assert(b.level == boss_lv[b.cfg.name] and b.cfg.level == b.level, "park boss level")
	assert(game.hedgehog.level == 15)

	# bark (M1-4): low raccoon flees, close one is stunned, higher one ignores it
	var racs := get_nodes_in_group("raccoon")
	var rac_lv: Array = racs.map(func(r): return r.level)
	player.position = Vector2(700, 64)
	player.stamina = 100.0
	player.level = 10
	player.facing = Vector2.RIGHT  # ranged: the wave flies along facing
	for i in 3:
		racs[i].position = player.position + Vector2([300, 60, 50][i], 0)
		racs[i].state = racs[i].State.CHASE
		racs[i].level = [1, 20, 12][i]
		racs[i].hp = 500.0  # hidden raccoons have 0 hp until they pop; the wave also hits
	var boss: Node2D = get_nodes_in_group("boss")[0]
	var boss_at: Vector2 = boss.position
	for b in get_nodes_in_group("boss"):  # intros freeze the dog; this test is about the bark
		root.get_node("Story").set_flag(b.cfg.intro)
	boss.position = player.position + Vector2(-150, 0)  # behind the dog
	assert(player.bark(), "bark fires")
	assert(racs[2].state == racs[2].State.STUN, "raccoon within 4 levels is stunned point-blank")
	assert(not player.bark(), "bark on cooldown")
	for k in 40:
		await physics_frame
		if racs[0].state == racs[0].State.FLEE:
			break
	assert(racs[0].state == racs[0].State.FLEE, "raccoon 9 levels below, 300 px out, flees the wave")
	assert(racs[1].state == racs[1].State.CHASE, "raccoon 10 levels above ignores the bark")
	assert(boss.stun_t == 0.0, "boss behind the dog is not hit")
	boss.position = player.position + Vector2(0, 200)
	player.bark_cd = 0.0
	player.facing = Vector2.DOWN
	assert(player.bark(), "bark fires down")
	for k in 40:
		await physics_frame
		if boss.stun_t > 0.0:
			break
	assert(boss.stun_t > 0.0, "boss within 4 levels is stunned by the wave")
	boss.position = boss_at
	# pedestrians: a bark wave makes one scream and run; so does a raccoon close by; a cat does not
	var human: Node2D = get_nodes_in_group("human")[0]
	while not get_nodes_in_group("bark").is_empty():
		await physics_frame
	human.position = player.position + Vector2(0, 160)
	human.scream_cd = 0.0
	assert(human.threat() == null, "nothing near the pedestrian yet")
	player.bark_cd = 0.0
	player.stamina = 100.0
	assert(player.bark(), "bark toward a pedestrian")
	for k in 20:
		await process_frame
		if human.scream_t > 0.0:
			break
	assert(human.scream_t > 0.0, "pedestrian screams at a bark")
	assert(human.flee.y > 0.9, "and runs away from it")
	while not get_nodes_in_group("bark").is_empty():
		await physics_frame
	human.scream_t = 0.0
	human.scream_cd = 0.0
	var rac_at: Vector2 = racs[2].position
	var rac_vis: bool = racs[2].visible
	racs[2].visible = true  # popped out of its can
	racs[2].position = human.position + Vector2(40, 0)
	assert(human.threat() != null, "pedestrian sees a raccoon close by")
	racs[2].position = rac_at
	racs[2].visible = rac_vis
	# killing a pedestrian = 5 stars; the 5-star drone loses the dog in the dog park, so heat can decay
	var bite_at: Vector2 = player.position + player.facing * 26.0
	human.position = bite_at
	human.hp = 1.0
	game.on_bite(bite_at, 46.0, 1.0)
	assert(human.is_queued_for_deletion() and game.wanted.stars() == 5, "killing a pedestrian = 5 stars")
	game.wanted.staff_t = 0.0
	await frames(2)
	assert(game.wanted.drone != null, "5 stars: drone")
	var street_at: Vector2 = player.position
	player.position = game.city.dog_park.get_center()
	game.wanted.unseen = 0.0
	await frames(2)
	assert(game.wanted.unseen > 0.0, "drone can't see the dog in the dog park: escape")
	player.position = street_at
	game.wanted.clear()
	boss.stun_t = 0.0
	player.facing = Vector2.RIGHT
	player.bark_cd = player.BARK_CD  # the wave waits drained it; the ability-bar check below wants a fresh one
	# pounce (M1-8): 160 px leap, landing hit = 2x bite damage
	assert(not player.pounce(), "pounce needs level 30")
	player.level = 30
	player.facing = Vector2.RIGHT
	var target: Node2D = racs[0]
	target.position = player.position + Vector2(player.POUNCE_PX + 26.0, 0)
	target.stun(10.0)
	target.hp = 1000.0
	assert(player.pounce(), "pounce fires at level 30")
	await frames(25)
	var dealt: float = 1000.0 - target.hp
	assert(is_equal_approx(dealt, player.attack_damage() * 2.0) or is_equal_approx(dealt, player.attack_damage() * 3.5),
		"pounce lands 2x bite (x1.75 on crit), got %f" % dealt)
	player.stat_atk = 0
	assert(is_equal_approx(player.crit_chance(), 0.05), "base crit 5%")
	player.stat_atk = 30
	assert(is_equal_approx(player.crit_chance(), 0.06), "+1% crit per 30 stat_atk")
	player.stat_atk = 2850  # 5% + 95% = always crit
	assert(player.roll_crit(), "crit chance grows with stat_atk")
	player.stat_atk = 0
	assert(target.state == target.State.STUN, "pounce stuns")
	# ability bar (M1-7): exists, cooldown sweep follows <name>_cd, pounce hidden below level 30
	await frames(1)
	assert(game.abilities.has("dash") and game.abilities.has("bark"), "ability bar built")
	assert(game.abilities.bark.v > 0.9 and game.abilities.bark.v < 1.0, "bark cooldown on the bar")
	assert(game.abilities.pounce.ctl.visible, "pounce shown at level 30")
	player.level = 1
	await frames(1)
	assert(not game.abilities.pounce.ctl.visible, "pounce locked below level 30")
	for i in racs.size():
		racs[i].level = rac_lv[i]
		racs[i].go_home(0.0)

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
		if game.dialog.playing():  # first wake this save: the boss intro
			game.dialog.skip()
		assert(game.boss_box.visible)
		assert(root.get_node("Sound").current == "boss_fatcat", "boss fight takes over the music")
		assert(b.cfg.specials.size() == 4)
		assert(b.sprite.texture.resource_path.ends_with("boss_%s.png" % b.cfg.tex), "boss uses its own art")
		for i in 4:  # every special fires without errors
			b.special(Vector2.RIGHT)
			b.state = b.State.CHASE
		assert(b.minions.is_empty() != ("goons" in b.cfg.specials or "pack" in b.cfg.specials), "goons / pack summon minions")
		b.marks.clear()
		b.mark(player.position, Color.WHITE, 0.01 - b.MARK_WARN)
		var hp_before: float = player.hp
		await frames(2)
		assert(b.marks.is_empty() and player.hp < hp_before, "a ground mark under the dog hits it")
		assert((player.poison_t > 0.0) == (b.cfg.name == "The Rat Meister"), "only the Rat Meister poisons")
		if player.poison_t > 0.0:
			hp_before = player.hp
			player.poison_tick = 0.99
			await frames(2)
			assert(player.hp < hp_before - b.cfg.poison + 0.5, "poison ticks for cfg.poison (minus a frame of regen)")
			player.poison_t = 0.0
		player.hp = player.max_hp
		var treats: int = player.treats
		b.hurt(1e9, player.position)
		assert(game.boss == null and not b.visible, "boss beaten")
		assert(root.get_node("Sound").current == ("park" if game.in_park else "nyc_jazz"), "city music back after the boss")
		assert(game.dialog.id == b.cfg.outro, "boss outro plays")
		game.dialog.skip()
		assert(player.treats >= treats + b.cfg.treats)  # quests may pay extra on the level-up
		while player.points > 0:  # boss XP levels the dog; spend so the game unpauses
			game.pick_stat(1)

	# subway ride: pick a stop, wait for the train, ride it, step off at the new station
	player.hp = player.max_hp
	game.interior.enter(game.stations[0].door)
	assert(game.inside == "subway" and game.station_i == 0)
	assert(game.subway.rats.size() >= 4 and game.subway.rats.all(func(r): return r.is_in_group("foe")), "rats in the subway")
	var rides: int = game.stat("rides")
	player.position = game.interior.O + Vector2(576, 200)
	game.travel(1)
	await frames(30)
	assert(game.station_i == 0 and not player.frozen, "no train yet: the dog waits on the platform")
	game.train_t = 0.1
	for i in 900:
		await frames(1)
		if game.station_i == 1 and not player.frozen:
			break
	assert(game.station_i == 1 and game.inside == "subway", "rode the train to station 2")
	# >= 2: the tunnel-mouth pack spawns on the tracks and the arriving train flattens it; the platform pack (2-4) stays
	assert(game.subway.rats.filter(func(r): return is_instance_valid(r)).size() >= 2, "fresh rats at the new station")
	assert(game.interior.door == game.stations[1].door and game.stat("rides") == rides + 1)
	assert(not player.dead and player.position.y < game.interior.O.y + 320, "stepped off onto the platform")
	game.set_inside("", game.stations[1].pos)

	# subway: stand on the tracks, wait for the train
	player.hp = player.max_hp
	player.treats = 10
	game.interior.enter(game.stations[0].door)
	assert(game.inside == "subway")
	player.position = game.interior.O + Vector2(600, 380)
	await frames(2)
	assert(player.position.y > game.interior.O.y + 370, "tracks are walkable")
	assert(game.train_t > 19.0 and game.train_t <= 20.0, "train on a 20 s schedule")
	game.train_t = 0.1
	await frames(180)
	assert(player.dead and paused and game.death_panel.visible, "train kills, death screen shows")
	assert(player.treats == 5)
	assert(player.position.y < game.interior.O.y + 322, "dog was flung off the tracks")

	game.respawn()
	assert(not paused and not player.dead and not player.frozen and not game.death_panel.visible)
	assert(game.inside == "" and player.position == player.spawn_point and player.hp == player.max_hp)
	assert(get_nodes_in_group("interior").is_empty(), "dying indoors frees the room")

	# interiors (M2-3): every building has a door; 20 random doors in and out land back on the
	# right street door, with at most one interior node alive
	var ROOMS: Dictionary = load("res://scripts/data/rooms.gd").ROOMS
	var ids := {}
	for d: Dictionary in game.doors:
		assert(ROOMS.has(d.template) and not game.city.blocked(d.pos), "door %s on open ground" % d.id)
		ids[d.id] = true
	assert(ids.size() == game.doors.size(), "door ids unique")
	for t in ["bodega", "subway", "burrow", "apartment", "office", "shop_small"]:
		assert(game.doors.any(func(d): return d.template == t), "some door uses " + t)
	for i in 20:
		var d: Dictionary = game.doors.filter(func(x): return x.template != "hq").pick_random()  # HQ door is gated, tested below
		player.hp = player.max_hp
		player.position = d.pos
		await frames(1)
		assert(game.act == "enter" and game.door == d, "F prompt reads the door under the dog")
		game.interact()
		if game.dialog.playing():  # first visits (Daven's den) open with a cutscene
			game.dialog.skip()
		assert(game.inside == ROOMS[d.template].kind and get_nodes_in_group("interior").size() == 1, "one interior")
		assert(game.Save.street_pos(game) == d.pos, "saving indoors keeps the street door")
		player.points = 0  # a door quest can level the dog up; the stat picker would pause the game
		game.show_stats()
		player.position = game.interior.spots.exit
		await frames(1)
		assert(game.act == "exit", "exit prompt in %s, got '%s'" % [d.template, game.act])
		game.interact()
		assert(game.inside == "" and player.position == d.pos, "back at door %s" % d.id)
		assert(get_nodes_in_group("interior").is_empty() and not game.hedgehog.active)
	await frames(1)

	# M1-5 XP rules: new curve, bonus point every 10 levels, low-enemy half XP, catch-up
	var XP: GDScript = load("res://scripts/systems/xp.gd")
	var total := 0
	for lv in range(1, 100):
		total += XP.needed(lv)
	assert(total == 31185, "sum of xp_needed 1..99")
	assert(player.xp_needed() == XP.needed(player.level))
	assert(XP.points_for(9) == 3 and XP.points_for(10) == 3)
	var low := Node2D.new()  # no `level` property yet (M1-1): treated as level 1
	assert(XP.scaled(100, 6, 0, low) == 50 and XP.scaled(100, 5, 0, low) == 100, "low enemy gives 50%")
	low.free()
	assert(XP.scaled(100, 9, 20) == 125 and XP.scaled(100, 10, 20) == 100, "catch-up +25% below HQ-10")

	# Daven the Hedgehog loss keeps level and XP, keeps at most 20 treats
	var lv_before: int = player.level
	var xp_before: int = player.xp
	game.set_inside("boss")
	var hh: Node2D = game.hedgehog  # ground spikes: every wave's pattern spawns, a burst under the dog hits
	player.position = hh.room.get_center() + Vector2(0, 120)
	hh.start()
	if game.dialog.playing():
		game.dialog.skip()
	for w in 3:
		hh.wave = w
		var n: int = hh.spikes.size()
		hh.spike_attack()
		assert(hh.spikes.size() > n, "wave %d spikes" % w)
	hh.wave = 0
	hh.spikes.clear()
	hh.spike(player.position, 0.01 - hh.SPIKE_WARN)
	player.hp = player.max_hp
	await frames(2)
	assert(player.hp < player.max_hp, "spikes bursting under the dog hit it")
	hh.stop()
	assert(hh.spikes.is_empty())
	player.hp = player.max_hp
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
	for t: String in sound.FILES:  # every recording imports and loops
		var rec: AudioStream = sound.stream(t)
		assert(rec != null and rec.loop, t)
	assert(sound.sounds["amb_rain"].loop, "rain ambience loops")
	game.set_inside("")
	player.position = game.parks[0].get_center()
	var was_paused := paused
	paused = false  # game._process runs the park check
	await frames(2)
	paused = was_paused
	assert(game.in_park and sound.current == "park", "parks play the park theme")
	game.set_inside("boss")
	assert(sound.current == "hedgehog_battle_1", "hedgehog den plays battle 1")
	game.set_inside("")

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
	assert(game.interior.O.x - 1200 > game.WORLD.x, "interiors clear of the streets")
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

	# Story gates: G1 needs level 30 + every NYC boss beaten; popup shows why and Find XP sets a waypoint
	story.reset()
	assert(story.objective() == "Find Sam's things at the bodega" and story.target() == game.bodega_doors[0], "the city registers story spots")
	story.spots["bodega"] = Vector2(100, 200)
	assert(story.target() == Vector2(100, 200))
	story.set_flag("ch1_bodega")
	assert(story.objective().contains("Fat Cat"))
	assert(not story.gate_open("G1", 30) and story.gate_block("G1", 30).contains("Fat Cat"), "names the bosses left")
	for f: String in ["cs_raccoon_post", "cs_pigeon_post", "cs_rat_post", "cs_hedgehog_post", "ch1_boss"]:
		story.set_flag(f)
	assert(not story.gate_open("G1", 29) and story.gate_block("G1", 29) == "Level 30 required (you are 29)")
	assert(story.gate_open("G1", 30), "G1 open at 30 with every boss beaten")
	assert(not story.gate_open("G2", 99) and story.gate_open("G0", 1))
	assert(story.gate_block("G3", 49) == "Level 50 required (you are 49)", "SF HQ opens at 50")
	player.level = 19
	var GatePopup: GDScript = load("res://scripts/ui/gate_popup.gd")
	var popup: Node = GatePopup.open(game, "G1")
	assert(player.frozen and popup.req.text == "Level 30 required (you are 19)")
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

	# bodega cats (M4-3): talk once a day, 3 gifts a day count, hearts = 2% off, hint at 3, gift at 5, saved
	var cats: Node = game.cats
	var mango_door: Dictionary = game.doors.filter(func(d): return d.template == "bodega" and d.pos == game.bodega_doors[0])[0]
	game.interior.enter(mango_door)
	assert(cats.here() == ["nyc_mango", "Mango"], "bodega 0 has Mango")
	game.save_extra["world/day"] = 1
	player.purina = 0
	player.treats = 100
	cats.rat = false
	game.ctx = "bodega"
	game.act = ""
	game.interact()  # F at the counter goes through game.gd's hook
	assert(cats.points("nyc_mango") == 1 and game.dialog.playing(), "talk +1, the cat speaks")
	assert(game.dialog.portrait.texture == game.tex.cat and not game.dialog.face_fn.is_valid(), "a cat speaker shows the cat")
	game.dialog.skip()
	for i in 5:
		cats.interact()
		game.dialog.skip()
	assert(cats.points("nyc_mango") == 1 + 3 * 2 and player.treats == 85, "5 gifts in a day: only 3 count")
	game.save_extra["world/day"] = 2
	cats.rat = true
	cats.interact()  # new day: talk counts again
	game.dialog.skip()
	cats.interact()
	game.dialog.skip()
	assert(cats.points("nyc_mango") == 12 and not cats.rat, "new day talk +1, rat gift +4")
	cats._process(0.0)
	assert(is_equal_approx(eco.discount(), 0.02) and "Mango likes you: -2%" in eco.discount_label(), "1 heart = 2% off")
	cats.on_bark()
	cats.on_pee(game.bodega_doors[0])
	assert(cats.points("nyc_mango") == 4, "bark -3, pee at the door -5")
	game.save_extra["cats/points"]["nyc_mango"] = 29
	game.save_extra["world/day"] = 3
	cats.interact()
	assert(story.objective() in game.dialog.text.text, "3 hearts: story hint")
	game.dialog.skip()
	game.save_extra["cats/points"]["nyc_mango"] = 49
	game.save_extra["world/day"] = 4
	var bones0: int = eco.bones
	cats.interact()
	game.dialog.skip()
	assert(cats.hearts("nyc_mango") == 5 and "bell" in game.save_extra["wardrobe/owned"] and story.has("cat_gift_nyc_mango"), "5 hearts: Bell collar")
	cats._process(0.0)
	assert(is_equal_approx(eco.discount(), 0.10), "5 hearts = 10% off (max)")
	cats.on_bark()
	cats.rat = true
	cats.interact()  # back to 5 hearts: no second gift
	game.dialog.skip()
	assert(cats.points("nyc_mango") == 50 and eco.bones == bones0, "gift only once")
	game.save_extra["cats/points"]["nyc_pepper"] = 49
	cats.add(["nyc_pepper", "Pepper"], 1)
	assert(eco.bones == bones0 + 2, "later cats give bones")
	game.save_game()
	game.save_extra["cats/points"] = {}
	game.save_extra["cats/today"] = {}
	game.load_game()
	assert(game.save_extra["cats/points"].nyc_mango == 50 and game.save_extra["cats/today"].nyc_mango[2], "cats saved")
	game.interior.leave()
	cats._process(0.0)
	assert(eco.discount() == 0.0, "cat discount only in its bodega")
	story.flags.erase("cat_gift_nyc_mango")
	story.flags.erase("cat_gift_nyc_pepper")
	game.save_extra["wardrobe/owned"] = []
	eco.bones = 0

	# Pocket the trader (M4-8): ~50% daily spawn on a sidewalk, 4 distinct table entries, ping, buy, hint, saved
	var tr: Node = game.trader
	var tr_items: Dictionary = preload("res://scripts/data/items.gd").TRADER
	var tr_spawns := 0
	var tr_day := 0
	for d in range(1, 201):
		var v: Dictionary = tr.roll(d, "nyc")
		assert(v.stock.size() == 4 and v.stock.all(func(id): return tr_items.has(id) and v.stock.count(id) == 1), "stock = 4 entries from the table")
		if v.pos.x >= 0.0:
			tr_spawns += 1
			tr_day = d if tr_day == 0 else tr_day
			assert(not game.city.blocked(v.pos) and not game.city.on_road(v.pos), "Pocket on a sidewalk")
	assert(tr_spawns > 70 and tr_spawns < 130 and tr.roll(tr_day, "nyc") == tr.roll(tr_day, "nyc"), "50% a day, same roll per day")
	game.save_extra["world/day"] = tr_day
	game.save_extra["trader/visit"] = {}
	assert(tr.visit().pos.x >= 0.0, "today's visit rolled")
	tr.visit().stock = ["mega_purina", "spiked", "mustache", "xp_snack"]
	tr._process(0.0)
	assert(game.pois.any(func(p): return p.text == "Pocket"), "Pocket on the map")
	var tr_back: Vector2 = player.position
	player.position = tr.spot()
	game.update_prompts(0.0)
	assert(game.ctx == "trader" and game.menu.visible, "next to Pocket: his menu")
	player.treats = 100
	eco.bones = 4
	player.hp = 1.0
	game.on_number(0)
	assert(player.hp == player.max_hp and player.treats < 100, "Mega Purina: full HP, paid (a 'bought' quest may refund some)")
	assert(tr.buy(1) and eco.bones == 0 and "spiked" in game.save_extra["wardrobe/owned"] and not tr.buy(1), "spiked collar once, 4 bones")
	game.wanted.add_heat(30.0)
	assert(tr.buy(2) and game.wanted.stars() == 0, "mustache: -1 star")
	game.wanted.clear()
	game.wanted.flash_t = 0.0
	assert(tr.buy(3), "XP snack")
	var tr_xp: int = player.xp
	player.xp = 0
	player.add_xp(10)
	assert(player.xp == 11, "XP snack: +10% XP")
	player.xp = tr_xp
	player.buffs.erase("snack")
	game.act = ""
	game.interact()
	assert(story.objective() in game.dialog.text.text and game.save_extra["trader/hinted"] == ["nyc"], "first chat in a city: story hint")
	assert(game.dialog.face_fn.is_valid() and game.dialog.portrait.texture == null, "Pocket's portrait is Pocket, not the cat")
	game.dialog.skip()
	tr.talk()
	assert(not story.objective() in game.dialog.text.text, "one hint per city")
	game.dialog.skip()
	game.save_game()
	game.save_extra["trader/visit"] = {}
	game.load_game()
	assert(tr.stock() == ["mega_purina", "spiked", "mustache", "xp_snack"], "visit saved")
	player.position = tr_back
	game.save_extra["wardrobe/owned"] = []
	game.save_extra["trader/hinted"] = []
	eco.bones = 0

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

	# wanted (M4-4): stars = heat / 25, flash on gain (none with reduce motion), decay after 10 s
	# unseen, officers + a van at 3 stars, a 1.2 s grab = caught (fine, heat cleared)
	var wanted: Node = game.wanted
	assert(wanted.stars() == 0 and wanted.stars_ui != null, "stars HUD built")
	wanted.add_heat(24)
	assert(wanted.stars() == 0 and wanted.flash_t == 0.0)
	wanted.add_heat(26)
	assert(wanted.stars() == 2 and wanted.flash_t > 0.0, "stars = heat / 25, flash on gain")
	game.save_extra["ui/reduce_motion"] = true
	wanted.flash_t = 0.0
	wanted.add_heat(25)
	assert(wanted.stars() == 3 and wanted.flash_t == 0.0, "reduce motion: no flash")
	game.save_extra["ui/reduce_motion"] = false
	wanted.add_heat(1000)
	assert(wanted.heat == 125.0 and wanted.stars() == 5, "heat caps at 125")
	wanted.clear()
	game.set_inside("", Vector2(700, 64))
	wanted.staff_t = 1e9  # no officers: nobody sees the dog
	wanted.add_heat(50)
	await frames(570)
	assert(wanted.heat == 50.0, "no decay before 10 s unseen")
	await frames(60)
	assert(wanted.heat < 50.0 and wanted.heat > 45.0, "decay after 10 s unseen, got %f" % wanted.heat)
	wanted.add_heat(75.0 - wanted.heat)
	wanted.staff_t = 0.0
	await frames(1)
	assert(wanted.stars() == 3 and wanted.vans().size() == 1 and wanted.officers().size() == 1, "3 stars: officer + van")
	var cop: Node2D = wanted.officers()[0]
	assert(cop.position.distance_to(player.position) >= 480.0, "officer spawns ~500 px away")
	player.treats = 100
	cop.position = player.position + Vector2(10, 0)
	await frames(2)
	assert(wanted.warn_t > 0.0, "whistle + edge warning when an officer closes in")
	await frames(75)
	assert(wanted.caught_n == 1 and wanted.stars() == 0 and wanted.heat == 0.0 and game.inside == "pound" and player.treats == 100, "grab = pound, heat 0, treats kept")
	await frames(1)
	assert(wanted.officers().is_empty() and wanted.vans().is_empty(), "caught clears animal control")
	# pound (M4-6): fine 15 x stars x city mult (min 10) at the cell door; breakout sneak / dig / squeeze
	var pound: Node = game.pound
	assert(pound.fine == 45 and game.ctx == "pound", "fine is 15 x 3 stars, cell door menu")
	pound.choose(0)
	assert(game.inside == "" and player.treats == 55, "paid the fine, back on the street")
	while player.points > 0:  # the level-up picker pauses the tree
		game.pick_stat(0)
	game.show_stats()
	game.respawn()  # still dead from "ordinary death also raises the screen"
	wanted.add_heat(25)
	player.take_damage(1e6)
	await frames(1)
	assert(game.inside == "pound" and not player.dead and not paused and not game.death_panel.visible and player.treats == 55 and pound.fine == 15, "HP 0 at 1 star = pound, treats kept")
	pound.choose(1)
	assert(pound.stage == "sneak", "break out")
	player.position = pound.guard.position + pound.guard_dir * 60.0
	await frames(1)
	assert(player.position == game.interior.spots.out, "guard sees the dog: sneak restarts")
	player.position = game.interior.spots.fence
	await frames(1)
	assert(pound.stage == "dig" and player.frozen, "fence reached: dig")
	pound.hits = 5
	pound.mark = 0.0
	for i in 3:
		pound.press("pee")
	assert(pound.hits == 0 and pound.misses == 0, "3 misses refill the hole")
	for i in 6:
		pound.mark = 0.5
		pound.press("pee")
	assert(pound.stage == "squeeze", "6 hits: squeeze")
	await frames(200)
	assert(game.inside == "pound" and pound.stage == "" and not player.frozen, "squeeze timer out: back in the cell")
	pound.choose(1)
	player.position = game.interior.spots.fence
	await frames(1)
	for i in 6:
		pound.mark = 0.5
		pound.press("pee")
	var xp0: int = player.xp + player.level * 1000
	for i in pound.MASH:
		pound.press("dash")
	assert(game.inside == "" and game.stat("escapes") == 1 and player.xp + player.level * 1000 > xp0 and not player.frozen, "breakout: out, +XP, escapes +1")
	while player.points > 0:
		game.pick_stat(0)
	# pizza steal (M4-5): +25 heat; unwatched = free slice, watched = pushed out
	game.interior.enter(game.doors.filter(func(d): return d.template == "pizza")[0])
	game.shop.watch_t = 0.0
	game.shop.turn_t = 99.0
	player.buffs.erase("food")
	game.shop.buy(game.shop.stock().size())
	assert(wanted.heat == 25.0 and player.buffs.food.id == "pizza" and game.inside == "shop", "steal adds 25 heat, free slice")
	game.shop.watch_t = 1.0
	assert(not game.shop.steal() and wanted.heat == 50.0 and game.inside == "", "watched: +25 heat, pushed out")
	wanted.clear()
	# territory (M3-6): 3 markers claim a block (+2 each, +10 claim), markers fade after 3 days
	var terr: Node2D = game.territory
	var bld: Rect2 = game.building_rects.filter(func(r): return r.size.x > 100 and r.size.x < game.BLOCK.x and r.size.y > 100 and terr.block_of(r.position) == terr.block_of(r.end))[0]
	var blk: Vector2i = terr.block_of(bld.get_center())
	var rep0: int = terr.rep().get("nyc", 0)
	var marks0: int = terr.markers().size()
	game.inside = "shop"
	player.thirst = 100.0
	assert(not terr.pee(bld.position) and terr.markers().size() == marks0, "indoors: Not here!, no marker")
	game.inside = ""
	player.thirst = 10.0
	assert(not terr.pee(bld.position), "too thirsty to pee")
	player.thirst = 100.0
	for c: Vector2 in [bld.position, Vector2(bld.end.x, bld.position.y), bld.end]:
		assert(terr.pee(c), "pee at a building corner")
	assert(terr.claimed(blk) and terr.rep().nyc == rep0 + 16 and player.thirst == 70.0, "3 markers = claimed")
	terr.rival_night()
	assert(terr.rival.level == 20 and is_equal_approx(terr.rival.stats.hp, 120.0 * (1.0 + 0.15 * 19)), "rival dog at the city band max")
	terr.rival_dawn()
	assert(terr.rival == null and terr.markers().size() == marks0 + 2, "unbeaten rival overwrites a marker")
	assert(terr.pee(terr.rival_mark.pos), "re-claim the block")
	for i in 3:
		terr.new_day()
	assert(not terr.claimed(blk) and terr.markers().size() == marks0 and terr.rep().nyc == rep0 + 22, "markers fade after 3 days")

	# NYSE stocks (M4-9): seeded 10,000-tick sim stays in [1, 999]; a same-tick round trip
	# loses treats; P only after a terminal visit; prices, history and holdings save
	var stk: Node = game.stocks
	var sim := RandomNumberGenerator.new()
	sim.seed = 7
	for id: String in stk.TICKERS:
		var t: Array = stk.TICKERS[id]
		var sp: float = t[1]
		for i in 10000:
			sp = stk.step(sp, t[3], t[2], sim)
			assert(sp >= 1.0 and sp <= 999.0, "%s price %f out of [1, 999]" % [id, sp])
	for sp: float in [1.0, 1.37, 20.0, 998.99]:
		stk.book("stocks/prices").KIBL = sp
		for n in [1, 7, 999]:
			assert(stk.cost("KIBL", n) > stk.payout("KIBL", n), "round trip at %f x%d loses" % [sp, n])
	stk.book("stocks/prices").KIBL = 20.0
	player.treats = 500
	assert(stk.buy("KIBL", 10) == 10 and stk.held("KIBL") == 10 and player.treats == 300, "buy 10 at 20")
	assert(stk.sell("KIBL", 99) == 10 and stk.held("KIBL") == 0 and player.treats == 496, "sell all, 2% fee")
	stk.toggle()
	assert(not stk.is_open(), "P is locked before the first terminal visit")
	var nyse: Dictionary = game.doors.filter(func(d): return d.template == "nyse")[0]
	game.interior.enter(nyse)
	player.position = game.interior.spots.terminal
	await frames(1)
	assert(game.inside == "nyse" and game.act == "stocks", "NYSE terminal prompt")
	game.interact()
	assert(stk.is_open() and player.frozen, "terminal opens the app")
	root.push_input(esc)
	assert(not stk.is_open() and not player.frozen, "Esc closes the app")
	game.interior.leave()
	var pkey := InputEventKey.new()
	pkey.keycode = KEY_P
	pkey.pressed = true
	root.push_input(pkey)
	assert(stk.is_open(), "P opens the app anywhere after the visit")
	root.push_input(pkey)
	assert(not stk.is_open() and not player.frozen, "P closes it")
	for i in stk.HISTORY + 5:
		stk.tick()
	assert(stk.history("SQRL").size() == stk.HISTORY, "history keeps 60 points")
	stk.buy("BONE", 2)
	var held_save := ConfigFile.new()
	held_save.load(SAVE)
	assert(held_save.get_value("stocks", "held").BONE == 2 and held_save.get_value("stocks", "prices").BONE == stk.price("BONE") 		and held_save.get_value("stocks", "history").BONE.size() == stk.HISTORY, "prices, history and holdings saved")
	# HQ puzzles (M5-4): each NYC floor solved by a scripted input list (U D L R steps, 1-4 program
	# slots, F run, < undo); hold R 1 s resets, 3 resets show the hint; the door clears the floor
	# (rewards, fb_<id> flashback via flashback.clear_floor)
	var hq: Node = game.hq
	var pz_story: Node = root.get_node("Story")
	pz_story.reset()
	game.save_extra["ui/reduce_motion"] = true
	var pz_keys := {"U": KEY_W, "D": KEY_S, "L": KEY_A, "R": KEY_D, "F": KEY_F, "<": KEY_BACKSPACE,
		"1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4}
	var pz_press := func(s: String):
		for ch in s:
			var ev := InputEventKey.new()
			ev.keycode = pz_keys[ch]
			ev.pressed = true
			root.push_input(ev)
			var up: InputEventKey = ev.duplicate()
			up.pressed = false
			root.push_input(up)
	var pz_street: Vector2 = player.position
	var finish_floor := func(fid: String):  # after the door: spend level-up points, walk the flashback
		assert(pz_story.floors.has(fid) and fb.playing() and fb.id == "fb_" + fid, fid + " cleared, flashback plays")
		while player.points > 0:
			game.pick_stat(0)
		for k in fb.props.size():
			fb.inspect(k)
			root.push_input(esc)
	var treats0: int = player.treats
	var pz_bones0: int = game.economy.bones
	var lvl0: int = player.level
	hq.enter("nyc_1")
	assert(game.inside == "hq" and hq.at == hq.start and not player.is_physics_processing(), "on the sort floor, grid steps")
	pz_press.call("UU")
	assert(hq.at == hq.start + Vector2i(0, -2), "one tile per key")
	pz_press.call("RRRRRRRRRRRRRRRR")
	assert(hq.at == Vector2i(13, 6), "walls stop Byte")
	for i in 3:
		Input.action_press("bark")
		await frames(64)
		Input.action_release("bark")
		await frames(1)
		assert(hq.at == hq.start and hq.resets.nyc_1 == i + 1, "hold R resets")
		assert(hq.hint.visible == (i == 2), "hint after 3 resets")
	assert(hq.hint.text.contains("crate"))
	pz_press.call("LUUUUU" + "LLLLDDRRDRUUU" + "RRRRRDDLLDLUUU" + "DDDDDRUUUUU")
	assert(hq.puzzle.is_solved() and [hq.crates[Vector2i(5, 2)], hq.crates[Vector2i(8, 2)]] == ["1", "4"], "crates sorted")
	pz_press.call("RRRRRDR")
	await frames(1)
	finish_floor.call("nyc_1")
	await frames(2)
	assert(game.inside == "" and player.position == pz_street and player.is_physics_processing(), "back on the street")
	assert(player.treats == treats0 + 5 and game.economy.bones == pz_bones0 + 1 and player.level > lvl0, "rewards: XP, 5 treats, par bone")
	hq.enter("nyc_2")
	pz_press.call("RRRRUUU")
	assert(not hq.puzzle.is_solved() and not hq.passable(Vector2i(7, 0)), "crate on b: NOT b off, door shut")
	pz_press.call("LLLLLL")
	assert(hq.puzzle.is_solved() and hq.crates.has(Vector2i(4, 5)), "a on, b off: door open")
	pz_press.call("UUUURRU")
	await frames(1)
	finish_floor.call("nyc_2")
	await frames(2)
	hq.enter("nyc_3")
	pz_press.call("UU")
	assert(hq.at == hq.start, "program: no free walking")
	pz_press.call("11F")
	await frames(60)
	assert(hq.at == hq.start and not hq.puzzle.running, "short program ends, Byte back at the start")
	pz_press.call("<<<11341121F")
	assert(hq.puzzle.bar.size() == 8, "undo, then 8 slots")
	await frames(200)
	finish_floor.call("nyc_3")
	await frames(2)
	assert(game.inside == "" and ["fb_nyc_1", "fb_nyc_2", "fb_nyc_3"].all(pz_story.has), "three NYC floors, three polaroids")
	game.save_extra.erase("ui/reduce_motion")

	# Hack Club HQ (M5-6): street door, lobby front desk, elevator to floors 1-4; floor 4 locked until 1-3 cleared
	var hqb_doors: Array = game.doors.filter(func(d): return d.template == "hq")
	assert(hqb_doors.size() == 1, "one HQ door in NYC")
	var hqb_floors: Dictionary = pz_story.floors.duplicate()
	var hqb_keys: Array = pz_story.keycards.duplicate()
	var hqb_level: int = player.level
	var hqb_it: Node = game.interior
	var hqb_flags: Array = pz_story.flags.duplicate()
	pz_story.flags.erase("ch1_clue")
	player.level = 1
	game.door = hqb_doors[0]
	game.act = "enter"
	game.interact()
	await frames(1)
	var hqb_pop: Array = game.hud.get_children().filter(func(n): return n.get_script() == load("res://scripts/ui/gate_popup.gd"))
	assert(game.inside == "" and hqb_pop.size() == 1 and hqb_pop[0].req.text.begins_with("Level 30"), "HQ door shut below 30: gate popup")
	hqb_pop[0].free()
	player.frozen = false
	hqb_it.enter(hqb_doors[0])
	assert(game.inside == "hq_lobby" and hqb_it.spots.has("elevator"), "HQ lobby")
	assert(game.dialog.playing(), "first time in: Sam's SF clue plays")
	game.dialog.skip()
	assert(pz_story.has("ch1_clue"), "the clue opens the SF gate")
	pz_story.floors = {}
	pz_story.keycards.clear()
	player.level = 1
	assert(not hqb_it.floor_rows()[0][1] and not hqb_it.floor_rows()[3][1], "G1 shut: every floor locked")
	player.level = 30
	for f: String in ["cs_raccoon_post", "cs_pigeon_post", "cs_rat_post", "cs_hedgehog_post", "ch1_boss"]:
		pz_story.set_flag(f)
	assert(hqb_it.floor_rows()[0][1] and not hqb_it.floor_rows()[3][1], "G1 open: floors 1-3, not 4")
	pz_story.floors = {"nyc_1": 50.0, "nyc_2": 50.0}
	assert(not hqb_it.floor_rows()[3][1], "two floors cleared: floor 4 still locked")
	pz_story.floors.nyc_3 = 50.0
	assert(hqb_it.floor_rows()[3][1] and hqb_it.floor_rows()[0][0].contains("cleared"), "1-3 cleared: floor 4 open")
	assert(hqb_it.floor_rows().size() == 4, "Tower floors hidden")
	player.position = hqb_it.spots.desk
	await frames(2)
	assert(game.act == "desk", "front desk prompt")
	game.interact()
	assert(game.dialog.playing() and game.dialog.text.text.contains("clue room"), "receptionist talks")
	game.dialog.skip()
	hqb_it.ride(0)
	await frames(50)
	assert(game.inside == "hq" and hq.id == "nyc_1" and not player.frozen, "elevator to floor 1")
	game.interior.leave()
	await frames(2)
	assert(game.inside == "" and player.is_physics_processing(), "off the floor, back on the street")
	pz_story.floors = hqb_floors
	pz_story.keycards.assign(hqb_keys)
	pz_story.flags.assign(hqb_flags)
	player.level = hqb_level

	# street foes (M3-2): night table has them; each kind spawns with its hiss / yowl and is beaten through on_bite
	var foe_night_kinds := {}
	for i in 400:
		foe_night_kinds[Spawns.pick("nyc", 0.1)] = true
	assert(foe_night_kinds.has("black") and foe_night_kinds.has("possum") and foe_night_kinds.has("rats"), "night: black cats, possums, rat swarms")
	var foe_snd: Node = root.get_node("Sound")
	for kind in ["tabby", "tom", "sphynx", "calico", "black", "possum", "rats"]:
		var foe_made: Array = game.spawner.spawn_foe(kind, player.position + Vector2(400, 0))
		var foe_f: Node2D = foe_made[0]
		assert(foe_made.size() == (5 if kind == "rats" else 1) and foe_f in player.foes(), kind + " spawns as a foe")
		assert(foe_snd.sounds.has(foe_f.cfg.hiss) and foe_snd.sounds.has(foe_f.cfg.yowl), kind + " has a hiss and a yowl")
		await frames(1)
		if kind == "black":
			assert(not foe_f.visible, "black cat unseen 400 px off")
		foe_f.position = player.position + Vector2(20, 0)
		if kind == "tabby":  # the bark wave hits foes too: a dog 5+ levels up sends it running
			player.level = foe_f.level + 10
			player.facing = Vector2.RIGHT
			player.bark_cd = 0.0
			player.stamina = 100.0
			assert(player.bark())
			await frames(2)
			assert(foe_f.state == "flee" and foe_f.hp < foe_f.max_hp, "bark wave hurts and scares a cat")
			await frames(60)  # let the wave run out its 520 px before the next kind spawns in its path
		if kind == "calico":
			game.on_bite(foe_f.position, 20.0, 5.0)
			assert(foe_f.dodged and foe_f.hp == foe_f.max_hp, "calico dodges the first bite")
		if kind == "possum":
			foe_f.hurt(foe_f.max_hp * 0.8, player.position)
			foe_f.hurt(foe_f.max_hp, player.position)
			assert(foe_f.state == "dead" and foe_f.hp > 0.0, "possum plays dead at 25%, bites pass over")
		var foe_treats0: int = player.treats
		for i in 300:
			if not is_instance_valid(foe_f):
				break
			player.hp = player.max_hp
			while player.points > 0:  # an earlier kill can level up; the picker pauses the tree
				game.pick_stat(0)
			game.show_stats()
			foe_f.position = player.position + Vector2(20, 0)
			game.on_bite(foe_f.position, 20.0, foe_f.max_hp * 0.3)
			await frames(3)
		assert(not is_instance_valid(foe_f) and player.treats > foe_treats0, kind + " beaten")
	var foe_tod: float = game.tod
	game.tod = 0.0  # midnight: sun() == 0, night
	var foe_bc0: int = game.stat("black_cats_night")
	game.spawner.spawn_foe("black", player.position + Vector2(400, 0))[0].beaten()
	assert(game.stat("black_cats_night") == foe_bc0 + 1, "black cat beaten at night counts for Old Rex")
	game.tod = foe_tod
	while player.points > 0:  # beaten() awards XP; a level-up picker pauses the tree
		game.pick_stat(0)
	game.show_stats()

	# dog park (M4-7): no boss on it, 3 quest dogs, HP regen inside, an officer stops at the
	# fence and leaves after 5 s, talking starts a quest line, optional bones / item columns pay
	var dp_park: Rect2 = game.city.dog_park
	assert(dp_park == Rect2(game.block_origin(game.PARKS[game.NYC.dog_park]), game.BLOCK), "dog park block")
	assert(game.BOSSES.all(func(b): return b.park != game.NYC.dog_park), "no park boss in the dog park")
	assert(get_nodes_in_group("npc").size() == 3, "3 NYC quest dogs")
	game.set_inside("", dp_park.position + Vector2(60, 40))
	player.hunger = 10.0  # starving: no well-fed regen, so only the park heals
	player.hp = 50.0
	await frames(60)
	assert(player.hp > 54.0 and player.hp < 56.0, "HP regen 5/s in the dog park, got %f" % player.hp)
	player.hunger = 100.0
	wanted.staff_t = 1e9
	var dp_caught0: int = wanted.caught_n
	var dp_fence_cop: Node2D = wanted.spawn_officer(player.position - Vector2(160, 0), false)
	await frames(60)
	assert(is_instance_valid(dp_fence_cop) and not dp_park.has_point(dp_fence_cop.position) \
			and dp_park.position.x - dp_fence_cop.position.x < 6.0 and dp_fence_cop.fence_t > 0.0, "officer stops at the fence")
	await frames(300)
	assert(not is_instance_valid(dp_fence_cop) and wanted.caught_n == dp_caught0, "officer leaves after 5 s, no catch")
	var dp_biscuit: Node2D = game.city.root.get_children().filter(func(n): return n.has_method("lines_for"))[0].dogs.Biscuit
	player.position = dp_biscuit.position
	await frames(1)
	assert(game.act == "talk", "F prompt by a quest dog")
	assert(not game.quest_text().contains("BISCUIT"), "dog lines hidden until you meet the dog")
	dp_biscuit.talk()
	assert(game.dialog.playing() and game.quest_step.Biscuit == 1 and game.waypoint.text == "Biscuit's ball", "talk starts the line")
	assert(game.dialog.face_fn.is_valid() and game.dialog.portrait.texture == null, "a quest dog's portrait is that dog, not the cat")
	game.dialog.skip()
	player.position = game.waypoint.pos
	await frames(1)
	assert(game.quest_step.Biscuit == 2, "ball found")
	var dp_bones0: int = game.economy.bones
	for k in ["met_old_rex", "park_boss_raccoon", "black_cats_night", "black_cats_night", "black_cats_night", "pound"]:
		game.bump(k)
	for i in 10:
		game.bump("pigeons")
	for i in 3:
		game.bump("blocks")
	assert(game.economy.bones == dp_bones0 + 2 and game.wardrobe.owns("bodega_cap"), "Old Rex pays 2 bones, Biscuit the cap")
	while player.points > 0:
		game.pick_stat(0)
	game.show_stats()

	# Fat Cat (M5-7): NYSE bell podium plays cs_fatcat_pre, then the fight; phases at 60% and 30%;
	# every special fires; the kill drops the NYC keycard, 5 bones, PURR -40% and ch1_boss, once
	var fc_story: Node = root.get_node("Story")
	fc_story.reset()
	fc_story.set_flag("ch1_fatcat_ready")
	var fc_door: Dictionary = game.doors.filter(func(d): return d.template == "nyse")[0]
	game.interior.enter(fc_door)
	var fc_boss: Node2D = get_nodes_in_group("boss").filter(func(b): return b.cfg.name == "Fat Cat")[0]
	assert(fc_boss.state == fc_boss.State.IDLE and fc_boss.level == 20, "Fat Cat waits for the bell")
	player.hp = player.max_hp
	player.position = game.interior.spots.podium
	await frames(2)
	assert(game.dialog.id == "cs_fatcat_pre" and fc_boss.state == fc_boss.State.IDLE, "podium plays the intro first")
	game.dialog.skip()
	await frames(2)
	assert(fc_boss.state == fc_boss.State.CHASE and game.boss == fc_boss and fc_boss.phase == 0, "then the fight starts")
	for i in 2:  # coin_fan, briefcase_charge
		fc_boss.special(Vector2.RIGHT)
	assert(fc_boss.briefcase and fc_boss.state == fc_boss.State.WINDUP, "briefcase charge winds up")
	fc_boss.state = fc_boss.State.CHASE
	fc_boss.hurt(fc_boss.max_hp * 0.39, player.position)
	assert(fc_boss.phase == 0, "61%: still phase 1")
	fc_boss.hurt(fc_boss.max_hp * 0.02, player.position)
	assert(fc_boss.phase == 1 and "margin_call" in fc_boss.specials(), "phase 2 below 60%")
	for i in 3:  # margin_call, ticker_wave, coin_fan
		fc_boss.special(Vector2.RIGHT)
	assert(fc_boss.minions.size() == 3 and fc_boss.minions[0].level == 18 and fc_boss.wave_x != INF, "security cats + ticker wave")
	fc_boss.hurt(fc_boss.max_hp * 0.3, player.position)
	assert(fc_boss.phase == 2 and "golden_parachute" in fc_boss.specials(), "phase 3 below 30%")
	player.hp = player.max_hp
	fc_boss.special(Vector2.RIGHT)
	assert(fc_boss.state == fc_boss.State.PARACHUTE, "golden parachute jumps")
	player.position += Vector2(400, 0)  # out of the landing ring
	await frames(int(fc_boss.AIR_TIME * 60.0) + 5)
	assert(fc_boss.state != fc_boss.State.PARACHUTE and fc_boss.sprite.position.y > -10.0, "and lands")  # walk hop (world/anim.gd) is a few px
	var fc_bones: int = game.economy.bones
	var fc_purr: float = game.stocks.price("PURR")
	player.hp = player.max_hp
	fc_boss.hurt(1e9, player.position)
	assert(fc_story.has_keycard("nyc") and game.economy.bones == fc_bones + 5 and fc_story.has("ch1_boss"), "keycard + 5 bones dropped")
	assert(is_equal_approx(game.stocks.price("PURR"), clampf(fc_purr * 0.6, game.stocks.LO, game.stocks.HI)), "PURR -40%")
	assert(game.boss == null and game.dialog.id == "cs_fatcat_post", "post-fight cutscene")
	game.dialog.skip()
	while player.points > 0:
		game.pick_stat(1)
	await frames(2)
	assert(not is_instance_valid(fc_boss), "story boss never respawns")
	game.interior.leave()
	game.interior.enter(fc_door)
	assert(get_nodes_in_group("boss").size() == 3, "beaten: no Fat Cat on the floor")
	game.interior.leave()
	fc_story.reset()

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
