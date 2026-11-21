extends Node
## Subway: through-trains, riding between stations, getting flung (moved from game.gd).

var g: Node2D

## Train pulls in, screen fades, the station room becomes station n, g.train leaves.
func travel(n: int) -> void:
	g.player.frozen = true
	g.sfx("subway")
	if g.train_tw:
		g.train_tw.kill()
	g.train_t = g.TRAIN_EVERY
	g.train.position.x = g.interior.O.x - 600
	var tw = g.create_tween()
	tw.tween_property(g.train, "position:x", g.interior.O.x + 576, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(g.fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		if g.inside == "subway":  # dog may have blacked out mid-ride
			g.station_i = n
			g.station_sign.text = g.stations[n].name
			g.interior.door = g.stations[n].door  # the stairs now lead up to this station
			g.return_pos = g.stations[n].pos
			g.bump("rides")
			g.player.position = g.interior.spots.board + Vector2(0, 40)
			g.cam.reset_smoothing())
	tw.tween_property(g.fade, "color:a", 0.0, 0.3)
	tw.tween_property(g.train, "position:x", g.interior.O.x + 2400, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		g.player.frozen = false
		if g.inside == "subway":
			g.show_msg("Arrived at %s. Stairs lead up to the street." % g.stations[n].name))

## A g.train runs through the station every g.TRAIN_EVERY seconds; a dog on the tracks gets flung.
func update_train(delta: float) -> void:
	if g.inside != "subway":
		return
	if g.train_tw and g.train_tw.is_running() and not g.player.dead and g.player.position.y > g.interior.O.y + 322 \
			and absf(g.player.position.x - g.train.position.x) < g.TRAIN_HALF + 10.0:
		train_hit()
	if g.player.frozen:
		return  # riding / dead: the schedule waits
	var before = g.train_t
	g.train_t -= delta
	if before > 3.0 and g.train_t <= 3.0:
		g.show_msg("Train approaching - stay off the tracks!")
	if g.train_t <= 0.0:
		g.train_t = g.TRAIN_EVERY
		g.sfx("subway")
		g.train.position.x = g.interior.O.x - 600
		g.train_tw = g.create_tween()
		g.train_tw.tween_property(g.train, "position:x", g.interior.O.x + 2400, 1.5)

func train_hit() -> void:
	g.player.dead = true  # no other damage while airborne; die() fires on landing
	g.player.frozen = true
	g.death_cause = "Flung by the g.train."
	g.shake_amt = 14.0
	g.sfx("hurt")
	var land = g.player.position + Vector2(420, -150)
	land.x = minf(land.x, g.interior.rect.end.x - 30)
	var tw = g.create_tween()
	tw.tween_property(g.player, "position", land, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g.player.sprite, "rotation", TAU * 3, 0.6)
	tw.tween_callback(g.player.die)
