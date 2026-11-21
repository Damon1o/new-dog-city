extends Node
## Subway: trains stop at the platform on a schedule; pick a stop at the map board, wait,
## board the train, ride it out of the station and step off at the next one.

var g: Node2D

const STOP_X := 576.0      # room-local x the train's centre stops at (the map board)
const DWELL := 4.0         # seconds the doors stay open
const RIDE_Y := 380.0      # dog's room-local y aboard (just below the train's centre: y-sorts on top)
const PLATFORM_Y := 290.0  # where the dog steps off, behind the yellow line

var ride_to := -1   # station picked at the map board, waiting for the train
var riding := false
var last_x := 0.0   # train x last frame: only a moving train flings dogs

## Map board pick: wait on the platform for the next train.
func travel(n: int) -> void:
	ride_to = n
	g.show_msg("Waiting for the train to %s. Next train in %ds - stay behind the yellow line." \
		% [g.stations[n].name, ceili(maxf(g.train_t, 0.0))])

func busy() -> bool:
	return g.train_tw != null and g.train_tw.is_running()

## Schedule: every g.TRAIN_EVERY seconds a train pulls in, stops, and leaves.
func update_train(delta: float) -> void:
	if g.inside != "subway":
		ride_to = -1
		riding = false
		return
	var moving: bool = absf(g.train.position.x - last_x) > 0.5
	last_x = g.train.position.x
	if moving and not riding and not g.player.dead and g.player.position.y > g.interior.O.y + 322 \
			and absf(g.player.position.x - g.train.position.x) < g.TRAIN_HALF + 10.0:
		train_hit()
	if busy() or g.player.dead:
		return  # a train is in, or the death screen is up: the schedule waits
	var before = g.train_t
	g.train_t -= delta
	if before > 3.0 and g.train_t <= 3.0:
		g.show_msg("Train approaching - stay off the tracks!")
	if g.train_t <= 0.0:
		arrive()

func arrive() -> void:
	var O: Vector2 = g.interior.O
	g.train_t = g.TRAIN_EVERY
	g.sfx("subway")
	g.train.position.x = O.x - 600
	last_x = g.train.position.x
	g.train_tw = g.create_tween()
	g.train_tw.tween_property(g.train, "position:x", O.x + STOP_X, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	g.train_tw.tween_callback(func():
		if ride_to >= 0 and not g.player.dead and g.player.position.y < O.y + 320:
			board()
		elif ride_to < 0:
			g.show_msg("Train stopped. Pick a stop at the map board to ride."))
	g.train_tw.tween_interval(DWELL)
	g.train_tw.tween_callback(func():
		if ride_to >= 0 and not riding:
			g.show_msg("Missed it - next train in %ds." % int(g.TRAIN_EVERY)))
	g.train_tw.tween_property(g.train, "position:x", O.x + 2400, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Doors open: the dog hops on and rides the train out (the dog's x follows the train).
func board() -> void:
	riding = true
	g.player.frozen = true
	var O: Vector2 = g.interior.O
	var seat := clampf(g.player.position.x, g.train.position.x - g.TRAIN_HALF + 40, g.train.position.x + g.TRAIN_HALF - 40)
	var off: float = seat - g.train.position.x
	var tw = g.create_tween()
	tw.tween_property(g.player, "position", Vector2(seat, O.y + RIDE_Y), 0.4)
	tw.tween_interval(DWELL - 0.4)  # doors close as the train's own tween departs
	tw.tween_method(func(_t: float):
		if is_instance_valid(g.train):
			g.player.position.x = g.train.position.x + off, 0.0, 1.0, 1.2)  # pulling out
	tw.parallel().tween_property(g.fade, "color:a", 1.0, 0.4).set_delay(0.8)
	tw.tween_callback(func():
		if g.inside == "subway" and riding:
			next_station(off))

## Blackout tunnel, then the same train pulls into station n with the dog aboard.
func next_station(off: float) -> void:
	var n := ride_to
	var O: Vector2 = g.interior.O
	if g.train_tw:
		g.train_tw.kill()
	g.station_i = n
	g.station_sign.text = g.stations[n].name
	g.interior.door = g.stations[n].door  # the stairs now lead up to this station
	g.return_pos = g.stations[n].pos
	g.bump("rides")
	g.train.position.x = O.x - 600
	last_x = g.train.position.x
	g.player.position = Vector2(g.train.position.x + off, O.y + RIDE_Y)
	g.cam.reset_smoothing()
	g.sfx("subway")
	g.train_tw = g.create_tween()
	g.train_tw.tween_property(g.fade, "color:a", 0.0, 0.4)
	g.train_tw.parallel().tween_method(func(x: float):
		g.train.position.x = x
		g.player.position.x = x + off, O.x - 600, O.x + STOP_X, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	g.train_tw.tween_property(g.player, "position:y", O.y + PLATFORM_Y, 0.4)  # step off
	g.train_tw.tween_callback(func():
		riding = false
		ride_to = -1
		g.player.frozen = false
		g.train_t = g.TRAIN_EVERY
		g.show_msg("Arrived at %s. Stairs lead up to the street." % g.stations[n].name))
	g.train_tw.tween_interval(1.0)
	g.train_tw.tween_property(g.train, "position:x", O.x + 2400, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func train_hit() -> void:
	g.player.dead = true  # no other damage while airborne; die() fires on landing
	g.player.frozen = true
	g.death_cause = "Flung by the train."
	g.shake_amt = 14.0
	g.sfx("hurt")
	var land = g.player.position + Vector2(420, -150)
	land.x = minf(land.x, g.interior.rect.end.x - 30)
	var tw = g.create_tween()
	tw.tween_property(g.player, "position", land, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g.player.sprite, "rotation", TAU * 3, 0.6)
	tw.tween_callback(g.player.die)
