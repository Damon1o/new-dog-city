extends Node
## Good Boy AI (Ch 2 side story, SF only): a small startup tycoon. Byte founds an AI company in a
## garage to build PawFinder, an AI that sniffs out lost humans.
##
## The company ticks every TICK seconds once founded (anywhere, any city):
##   dev points  <- engineers (+ Patch), espresso       -> spend at the desk to SHIP the next version
##   users       <- marketers, version, hype, ball pit  -> capped by servers, churn eased by designers / treat bar
##   bank        <- users^0.8 x ARPU (sales dogs, version) minus salaries; runs dry -> a hire quits
## At the founder's desk: hire (team cap = office), upgrade (office / servers / perks), ship, market,
## raise funding rounds (user + version milestones: lump of treats, unlock bigger offices), collect the bank.
## The garage redraws as the company grows: floor + wall per office, a desk + dog per hire, racks, perks.
## Saved as save_extra "startup/state" (systems/save.gd keeps the Dictionary as is).

const TICK := 3.0  # seconds; a 240 s day is 80 ticks
const NEAR := 60.0
const FOUND_COST := 150
const ARPU := 0.01  # treats per tick per users^0.8 (big audiences pay less each)
const QUIT_AT := -40.0  # bank below this: a hire quits

## role -> [name, base cost, salary per tick, blurb, dog breed at the desk]
const ROLES := {
	"eng": ["Engineer", 40, 0.12, "+dev", "chihuahua"],
	"des": ["Designer", 60, 0.12, "-churn +buzz", "husky"],
	"mkt": ["Marketer", 50, 0.12, "+users", "pug"],
	"sales": ["Sales dog", 70, 0.16, "+revenue", "great_dane"],
}
const ROLE_ORDER := ["eng", "des", "mkt", "sales"]
## [name, team cap, cost, funding rounds needed]
const OFFICES := [["Garage", 4, 0, 0], ["SoMa Loft", 8, 800, 1], ["Market St Office", 14, 3000, 2], ["Presidio Campus", 24, 9000, 3]]
## [name, user cap, cost]
const SERVERS := [["Old laptop", 300, 0], ["Server rack", 2500, 250], ["Cloud cluster", 20000, 1400], ["Fog City datacenter", 150000, 6000]]
## perk -> [name, cost, blurb]
const PERKS := {
	"espresso": ["Espresso machine", 200, "+30% dev"],
	"ballpit": ["Ball pit", 350, "+25% users"],
	"snacks": ["Treat bar", 500, "half churn"],
}
const PERK_ORDER := ["espresso", "ballpit", "snacks"]
## [name, users needed, version needed, treats raised (into the bank), cutscene]
const ROUNDS := [
	["Seed round", 250, 1, 600, "cs_startup_seed"],
	["Series A", 2000, 2, 2500, ""],
	["Series B", 15000, 3, 8000, "cs_startup_series_b"],
	["IPO", 100000, 4, 25000, "cs_startup_ipo"],
]
const VERSIONS := ["prototype", "PawFinder beta", "PawFinder 1.0", "PawFinder Pro", "PawFinder Everywhere"]
## [message, field, amount], rolled about once a day while live (version >= 1)
const EVENTS := [
	["PawFinder found a lost grandma! It went viral.", "hype", 2.0],
	["A celebrity corgi posted about PawFinder.", "hype", 1.2],
	["Server outage! Some users left.", "users", -0.1],
	["A rival poached your snack budget.", "bank", -25.0],
	["An angel investor left treats in the mailbox.", "bank", 60.0],
]
## Desk slots: 3 columns either side of the aisle x 4 rows, filled front to back.
const DESK_X := [80, 168, 256, 512, 600, 688]
const DESK_Y := [190, 258, 326, 394]

var g: Node2D
var page := "main"  # main | hire | up
var acc := 0.0
var office: Node2D  # y-sorted child of the startup room, rebuilt after every purchase
var rng := RandomNumberGenerator.new()

# ---------- state ----------
func state() -> Dictionary:
	if not g.save_extra.get("startup/state") is Dictionary:
		g.save_extra["startup/state"] = {}
	return g.save_extra["startup/state"]

func founded() -> bool:
	return bool(state().get("founded", false))

func n(key: String) -> int:
	return int(state().get(key, 0))

func f(key: String) -> float:
	return float(state().get(key, 0.0))

func staff(role: String) -> int:
	return int(state().get("staff", {}).get(role, 0))

func headcount() -> int:
	var t := 0
	for r: String in ROLE_ORDER:
		t += staff(r)
	return t

func has_perk(p: String) -> bool:
	return p in state().get("perks", [])

func hire_cost(role: String) -> int:
	return int(ROLES[role][1] * pow(1.35, staff(role)))

func dev_need() -> float:
	return 30.0 * pow(1.8, n("version"))

func version_name(v: int) -> String:
	return VERSIONS[v] if v < VERSIONS.size() else "PawFinder %d" % (v - 2)

func user_cap() -> int:
	return SERVERS[n("servers")][1]

func team_cap() -> int:
	return OFFICES[n("office")][1]

func salaries() -> float:
	var t := 0.0
	for r: String in ROLE_ORDER:
		t += staff(r) * float(ROLES[r][2])
	return t

func revenue() -> float:
	if n("version") == 0:
		return 0.0
	return pow(f("users"), 0.8) * ARPU * (1.0 + 0.3 * staff("sales")) * (1.0 + 0.15 * n("version"))

func growth() -> float:
	if n("version") == 0:
		return 0.0
	var buzz := n("version") * (1.0 + 0.25 * staff("des"))  # word of mouth
	return ((1.0 + 2.0 * staff("mkt")) * (1.0 + 0.4 * n("version")) + f("users") * 0.004 * buzz) \
		* (1.0 + f("hype")) * (1.25 if has_perk("ballpit") else 1.0)

func churn() -> float:
	return f("users") * 0.003 / (1.0 + 0.15 * staff("des")) * (0.5 if has_perk("snacks") else 1.0)

## Profit waiting at the desk (whole treats).
func owed() -> int:
	return maxi(int(f("bank")), 0)

# ---------- simulation ----------
func _process(delta: float) -> void:
	if founded():
		acc += delta
		while acc >= TICK:
			acc -= TICK
			tick()
	if g.inside != "startup" or g.interior.room == null:
		return
	if not is_instance_valid(office):
		build_office()
	if g.player.frozen or g.act != "":
		return
	if g.player.position.distance_to(g.interior.spots.pitch) < NEAR:
		g.ctx = "startup"
		g.show_menu(head(), rows())
	else:
		page = "main"

func tick() -> void:
	var s := state()
	s.dev = f("dev") + (0.5 + staff("eng")) * (1.3 if has_perk("espresso") else 1.0)
	s.users = clampf(f("users") + growth() - churn(), 0.0, user_cap())
	s.hype = f("hype") * 0.97
	s.bank = f("bank") + revenue() - salaries()
	if f("bank") < QUIT_AT and headcount() > 0:
		for r: String in ROLE_ORDER:
			if staff(r) > 0:
				s.staff[r] = staff(r) - 1
				s.bank = 0.0
				if g.city.id == "sf":
					g.show_msg("Out of runway! A %s quit Good Boy AI." % ROLES[r][0])
				build_office()
				break
	if n("version") > 0 and rng.randf() < 1.0 / 80.0:
		var e: Array = EVENTS[rng.randi() % EVENTS.size()]
		if e[1] == "users":
			s.users = f("users") * (1.0 + e[2])
		else:
			s[e[1]] = f(e[1]) + e[2]
		if g.city.id == "sf":
			g.show_msg("Good Boy AI: " + e[0])

# ---------- desk menu ----------
static func fmt(x: float) -> String:
	if absf(x) >= 1000000.0:
		return "%.1fM" % (x / 1000000.0)
	if absf(x) >= 10000.0:
		return "%dk" % int(x / 1000.0)
	if absf(x) >= 1000.0:
		return "%.1fk" % (x / 1000.0)
	return str(int(x))

func head() -> String:
	if not founded():
		return "GOOD BOY AI"
	var net := revenue() - salaries()
	return "GOOD BOY AI  -  %s  -  %s\n%s / %s users   bank %s (%s%.1f a tick)   team %d / %d" % [
		OFFICES[n("office")][0], version_name(n("version")), fmt(f("users")), fmt(user_cap()),
		fmt(f("bank")), "+" if net >= 0.0 else "", net, headcount(), team_cap()]

## Menu rows for the founder's desk: [text, selectable].
func rows() -> Array:
	var t: int = g.player.treats
	var out := []
	if not founded():
		return [["[1]  Found Good Boy AI   %d treats" % FOUND_COST, t >= FOUND_COST]]
	if page == "hire":
		for i in ROLE_ORDER.size():
			var r: String = ROLE_ORDER[i]
			out.append(["[%d]  Hire %s (have %d)   %d treats   %s" % [i + 1, ROLES[r][0], staff(r), hire_cost(r), ROLES[r][3]],
				t >= hire_cost(r) and headcount() < team_cap()])
		out.append(["[5]  Back", true])
		return out
	if page == "up":
		var o := n("office") + 1
		if o < OFFICES.size():
			var ok: bool = n("round") >= OFFICES[o][3]
			out.append(["[1]  Move to %s (team %d)   %d treats%s" % [OFFICES[o][0], OFFICES[o][1], OFFICES[o][2],
				"" if ok else "   needs a " + ROUNDS[OFFICES[o][3] - 1][0]], ok and t >= OFFICES[o][2]])
		else:
			out.append(["[1]  Office: %s (max)" % OFFICES[-1][0], false])
		var sv := n("servers") + 1
		if sv < SERVERS.size():
			out.append(["[2]  Servers: %s (%s users)   %d treats" % [SERVERS[sv][0], fmt(SERVERS[sv][1]), SERVERS[sv][2]], t >= SERVERS[sv][2]])
		else:
			out.append(["[2]  Servers: %s (max)" % SERVERS[-1][0], false])
		for i in PERK_ORDER.size():
			var p: String = PERK_ORDER[i]
			out.append(["[%d]  %s   %s   %s" % [i + 3, PERKS[p][0], "owned" if has_perk(p) else "%d treats" % PERKS[p][1], PERKS[p][2]],
				not has_perk(p) and t >= PERKS[p][1]])
		out.append(["[6]  Back", true])
		return out
	out.append(["[1]  Team & hiring  >", true])
	out.append(["[2]  Office & upgrades  >", true])
	out.append(["[3]  Ship %s   dev %s / %s" % [version_name(n("version") + 1), fmt(f("dev")), fmt(dev_need())], f("dev") >= dev_need()])
	out.append(["[4]  Marketing push   %d treats" % push_cost(), n("version") > 0 and t >= push_cost()])
	if n("round") < ROUNDS.size():
		var rd: Array = ROUNDS[n("round")]
		out.append(["[5]  Raise %s: +%s   needs %s users + %s" % [rd[0], fmt(rd[3]), fmt(rd[1]), version_name(rd[2])], can_raise()])
	else:
		out.append(["[5]  Good Boy AI is public", false])
	out.append(["[6]  Collect bank   %d treats" % owed(), owed() > 0])
	return out

func push_cost() -> int:
	return 80 * (1 + n("round"))

func can_raise() -> bool:
	if n("round") >= ROUNDS.size():
		return false
	var rd: Array = ROUNDS[n("round")]
	return f("users") >= rd[1] and n("version") >= rd[2]

func choose(i: int) -> void:
	if g.dialog.playing():
		return
	var s := state()
	if not founded():
		if i == 0 and pay(FOUND_COST):
			s.merge({"founded": true, "staff": {}, "perks": [], "office": 0, "servers": 0, "version": 0,
				"dev": 0.0, "users": 0.0, "bank": 0.0, "hype": 0.0, "round": 0}, true)
			done("GOOD BOY AI FOUNDED", "cs_startup_found")
		return
	if page == "hire":
		if i == 4:
			page = "main"
		elif i < ROLE_ORDER.size():
			var r: String = ROLE_ORDER[i]
			if headcount() >= team_cap():
				g.show_msg("The office is full. Move somewhere bigger")
			elif pay(hire_cost(r)):
				s.staff[r] = staff(r) + 1
				done("HIRED A " + str(ROLES[r][0]).to_upper())
		return
	if page == "up":
		if i == 5:
			page = "main"
		elif i == 0 and n("office") + 1 < OFFICES.size():
			var o: Array = OFFICES[n("office") + 1]
			if n("round") < o[3]:
				g.show_msg("The landlord wants to see a " + ROUNDS[o[3] - 1][0])
			elif pay(o[2]):
				s.office = n("office") + 1
				done("MOVED TO " + str(o[0]).to_upper(), "cs_startup_campus" if n("office") == OFFICES.size() - 1 else "")
		elif i == 1 and n("servers") + 1 < SERVERS.size():
			if pay(SERVERS[n("servers") + 1][2]):
				s.servers = n("servers") + 1
				done(str(SERVERS[n("servers")][0]).to_upper())
		elif i >= 2 and i < 2 + PERK_ORDER.size():
			var p: String = PERK_ORDER[i - 2]
			if not has_perk(p) and pay(PERKS[p][1]):
				s.perks.append(p)
				done(str(PERKS[p][0]).to_upper())
		return
	match i:
		0:
			page = "hire"
		1:
			page = "up"
		2:
			if f("dev") < dev_need():
				g.show_msg("Need %s dev points" % fmt(dev_need()))
				return
			s.dev = f("dev") - dev_need()
			s.version = n("version") + 1
			s.users = maxf(f("users"), 10.0)  # launch-day users
			s.hype = f("hype") + 1.0
			done("SHIPPED " + version_name(n("version")).to_upper(), "cs_startup_beta" if n("version") == 1 else "")
		3:
			if n("version") == 0:
				g.show_msg("Ship something first")
			elif pay(push_cost()):
				s.hype = f("hype") + 1.5
				done("MARKETING PUSH")
		4:
			if not can_raise():
				g.show_msg("Investors want more traction")
				return
			var rd: Array = ROUNDS[n("round")]
			s.round = n("round") + 1
			s.bank = f("bank") + rd[3]
			done(str(rd[0]).to_upper() + " CLOSED", rd[4])
		5:
			collect()

func pay(cost: int) -> bool:
	if g.player.treats < cost:
		g.show_msg("Need %d treats" % cost)
		return false
	g.player.treats -= cost
	return true

func done(banner: String, cutscene := "") -> void:
	g.show_banner(banner)
	g.sfx("levelup" if cutscene != "" else "buy")
	build_office()
	if cutscene != "":
		g.dialog.play(cutscene)

func collect() -> void:
	var k := owed()
	if k > 0:
		state().bank = f("bank") - k
		g.player.treats += k
		g.show_msg("+%d treats from Good Boy AI" % k)
		g.sfx("buy")

# ---------- the office, drawn into the startup room ----------
func build_office() -> void:
	if is_instance_valid(office):
		office.free()
	office = null
	if g.inside != "startup" or g.interior.room == null:
		return
	office = Node2D.new()
	office.y_sort_enabled = true  # nested y-sort: props sort with the room's own props
	g.interior.room.add_child(office)
	var o: Vector2 = g.interior.O
	var size: Vector2 = g.interior.rect.size
	var tier := n("office")
	var deco := Node2D.new()  # floor + wall + neon, above the room paint, under every prop
	deco.z_index = -9
	deco.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	deco.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	deco.draw.connect(func():
		deco.draw_texture_rect(tex("su_floor_%d" % tier), Rect2(o + Vector2(0, 96), Vector2(size.x, size.y - 96)), true)
		deco.draw_texture_rect(tex("su_wall_%d" % tier), Rect2(o, Vector2(size.x, 96)), true)
		deco.draw_rect(Rect2(o + Vector2(0, 90), Vector2(size.x, 6)), Color(0, 0, 0, 0.3))
		deco.draw_rect(Rect2(o + Vector2(size.x / 2 - 40, size.y - 24), Vector2(80, 24)), Color(0.2, 0.3, 0.5))  # door mat
		if founded():
			var t := tex("su_neon")
			deco.draw_texture_rect(t, Rect2(o + Vector2(size.x / 2 - t.get_width(), 20), t.get_size() * 2.0), false))
	office.add_child(deco)
	if not founded():
		return
	var slot := 0
	for r: String in ROLE_ORDER:
		for k in staff(r):
			if slot >= DESK_X.size() * DESK_Y.size():
				break
			var at := Vector2(DESK_X[slot % DESK_X.size()], DESK_Y[slot / DESK_X.size()])
			prop("su_desk", at, 1.0)
			var dog := prop("dog_" + ROLES[r][4], at + Vector2(0, 12), 2.0)
			dog.hframes = 2
			dog.flip_h = slot % DESK_X.size() >= 3  # both halves face the aisle
			dog.add_to_group("startup_staff")
			slot += 1
	for k in [0, 1, 2, 4][n("servers")]:
		prop("su_server", Vector2(740 - k * 34, 140), 1.0)
	prop("su_board", Vector2(300, 140), 1.0)
	if has_perk("espresso"):
		prop("su_espresso", Vector2(36, 140), 1.25)
	if has_perk("snacks"):
		prop("su_treatbar", Vector2(130, 140), 1.25)
	if has_perk("ballpit"):
		prop("su_ballpit", Vector2(620, 446), 1.5)
	for k in tier:  # nicer offices get plants
		prop("su_plant", [Vector2(450, 140), Vector2(24, 446), Vector2(470, 446)][k], 1.0)
	if n("round") >= ROUNDS.size():
		prop("su_bell", Vector2(470, 236), 1.25)

func tex(name: String) -> Texture2D:
	if not g.tex.has(name):
		g.tex[name] = load("res://assets/%s.png" % name)
	return g.tex[name]

func prop(name: String, at: Vector2, k: float) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex(name)
	spr.scale = Vector2(k, k)
	spr.offset = Vector2(0, -spr.texture.get_height() / 2.0)
	spr.position = g.interior.O + at
	office.add_child(spr)
	return spr

## Staff dogs bob at their keyboards.
func _physics_process(_delta: float) -> void:
	if is_instance_valid(office):
		var beat := int(Time.get_ticks_msec() / 220)
		for i in office.get_child_count():
			var c := office.get_child(i)
			if c is Sprite2D and c.is_in_group("startup_staff"):
				c.frame = (beat + i) % 2
