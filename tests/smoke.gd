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
	for n: Node in get_nodes_in_group("prey") + game.treat_sprites:
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
	weather.set_weather("clear", false)

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
	st.flags.erase("ch1_clue")
	game.interior.leave()
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
	assert(game.shop.buy(0) == 1 and player.buffs.drink.id == "puppuccino" and player.mod("stamina") == 1.5, "drink buff on")
	await frames(1)
	assert(game.ui.buff_row.get_node("drink").visible, "buff chip shows")
	player.buffs.drink.t = 0.05
	await frames(6)
	assert(not player.buffs.has("drink") and player.mod("stamina") == 1.0, "buff timer runs down")
	game.interior.leave()
	# UI overhaul: inventory opens / freezes / closes; hotbar binds and uses a slot; long menus fit
	assert(game.hud.theme != null, "HUD theme set")
	game.inventory.toggle()
	assert(game.inventory.is_open() and player.frozen, "I opens the inventory")
	assert(game.inventory.root.get_child_count() == 4 and game.inventory.ground.get_child_count() == 16
		and game.inventory.bag.get_child_count() == 25, "ground / equipment / inventory panels (+ hidden album)")
	game.inventory.bind("water", 3)
	game.inventory.toggle()
	assert(not game.inventory.is_open() and not player.frozen, "I closes it")
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
	assert(wr.is_open() and player.frozen and wr.tabs.get_child_count() == 4, "B opens the wardrobe")
	assert(wr.tabs.get_child(0).get_child_count() == player.BREEDS.size(), "one skin per breed")
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
	player.stat_atk = 950  # 5% + 95% = always crit
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
		var d: Dictionary = game.doors.pick_random()
		player.hp = player.max_hp
		player.position = d.pos
		await frames(1)
		assert(game.act == "enter" and game.door == d, "F prompt reads the door under the dog")
		game.interact()
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
	assert(player.hp == player.max_hp and player.treats == 75, "Mega Purina: full HP, 25 treats")
	assert(tr.buy(1) and eco.bones == 0 and "spiked" in game.save_extra["wardrobe/owned"] and not tr.buy(1), "spiked collar once, 4 bones")
	wanted.add_heat(30.0)
	assert(tr.buy(2) and wanted.stars() == 0, "mustache: -1 star")
	wanted.clear()
	var tr_xp: int = player.xp
	assert(tr.buy(3), "XP snack")
	player.add_xp(10)
	assert(player.xp == tr_xp + 11, "XP snack: +10% XP")
	player.buffs.erase("snack")
	game.act = ""
	game.interact()
	assert(story.objective() in game.dialog.text.text and game.save_extra["trader/hinted"] == ["nyc"], "first chat in a city: story hint")
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
