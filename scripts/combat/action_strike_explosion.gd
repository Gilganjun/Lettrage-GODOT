class_name ActionStrikeExplosion
extends Node2D

## Large burst at ACTION fist/foot contact — complements the in-frame art sparks.

const LIFETIME := 0.65


static func spawn_at(world_parent: Node, global_pos: Vector2, kind: String = "fist") -> void:
	if world_parent == null:
		return
	var fx := ActionStrikeExplosion.new()
	world_parent.add_child(fx)
	fx.global_position = global_pos
	fx._play(kind)


func _play(kind: String) -> void:
	z_index = 135
	var is_kick := kind == "kick"
	_add_shockwave(is_kick)
	_add_burst_particles(is_kick, Color(1.0, 0.95, 0.55, 1.0), 0.0, is_kick)
	_add_burst_particles(is_kick, Color(1.0, 0.55, 0.12, 1.0), 0.04, not is_kick)
	_add_burst_particles(is_kick, Color(1.0, 0.32, 0.08, 0.85), 0.08, false)
	var timer := get_tree().create_timer(LIFETIME + 0.15)
	timer.timeout.connect(queue_free)


func _add_shockwave(is_kick: bool) -> void:
	var ring := Line2D.new()
	ring.width = 5.0 if is_kick else 4.0
	ring.default_color = Color(1.0, 0.88, 0.35, 0.95)
	ring.closed = true
	var radius := 10.0
	var segments := 24
	var pts := PackedVector2Array()
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	ring.points = pts
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3.8, 3.8) if is_kick else Vector2(3.2, 3.2), 0.38)
	tween.tween_property(ring, "modulate:a", 0.0, 0.42)
	var flash := Polygon2D.new()
	flash.color = Color(1.0, 0.98, 0.7, 0.85)
	flash.polygon = PackedVector2Array([
		Vector2(-14, -14), Vector2(14, -14), Vector2(14, 14), Vector2(-14, 14),
	])
	add_child(flash)
	var flash_tween := create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(2.6, 2.6) if is_kick else Vector2(2.2, 2.2), 0.18)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.28)


func _add_burst_particles(is_kick: bool, color: Color, delay: float, is_primary: bool) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.5 if is_primary else 0.62
	particles.amount = 64 if is_kick and is_primary else (42 if is_primary else 28)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0 if is_kick else 4.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 180)
	particles.initial_velocity_min = 140.0 if is_kick else 100.0
	particles.initial_velocity_max = 320.0 if is_kick else 260.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 5.0 if is_kick else 3.5
	particles.scale_amount_max = 12.0 if is_kick else 9.0
	particles.color = color
	add_child(particles)
	if delay <= 0.0:
		particles.emitting = true
	else:
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func(): particles.emitting = true)
