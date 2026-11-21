extends Node
## One-shot world effects: floating text, poofs, claw scratches (moved from game.gd).

var g: Node2D

func float_text(pos: Vector2, text: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-20, -44)
	l.z_index = 20
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	g.add_child(l)
	var tw = g.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)

## Burst of dots; also crit sparks (yellow, fast) and dash dust (grey, slow).
func poof(pos: Vector2, color: Color, amount := 14, speed := 110.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 5
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.5
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.damping_min = speed * 0.8  # dots slow to a stop instead of flying off
	p.damping_max = speed
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	g.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Three claw marks that pop at the hit point, facing the attack, then g.fade.
func scratch(center: Vector2, dir: Vector2) -> void:
	var n := Node2D.new()
	n.position = center
	n.rotation = dir.angle()
	n.z_index = 6
	n.scale = Vector2(0.4, 0.4)
	for i in 3:
		var x := (i - 1) * 10.0
		for stroke in [[6.0, Color(0.75, 0.1, 0.1)], [3.0, Color(1, 0.96, 0.9)]]:  # red edge, white core
			var l := Line2D.new()
			l.points = PackedVector2Array([Vector2(x + 12, -18), Vector2(x - 12, 18)])
			l.width = stroke[0]
			l.default_color = stroke[1]
			l.begin_cap_mode = Line2D.LINE_CAP_ROUND
			l.end_cap_mode = Line2D.LINE_CAP_ROUND
			n.add_child(l)
	g.add_child(n)
	var tw = g.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(n, "modulate:a", 0.0, 0.2)
	tw.tween_callback(n.queue_free)
