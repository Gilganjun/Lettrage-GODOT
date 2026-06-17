class_name LetterBulletExplosionEffect
extends Node2D

## Shielded bullet hit — layered burst, shockwave, fire, smoke, sparks, and letter debris.

const LetterTint := preload("res://scripts/letters/letter_tint.gd")

const LIFETIME := 0.85

var _elapsed := 0.0
var _core_radius := 6.0
var _core_alpha := 1.0
var _shock_a := 0.0
var _shock_b := 0.0
var _hot := Color(1.0, 0.92, 0.55, 1.0)
var _accent := Color.WHITE


static func spawn(
	parent: Node,
	global_pos: Vector2,
	accent: Color,
	debris_texture: Texture2D = null,
	debris_scale: Vector2 = Vector2.ONE,
) -> Node2D:
	if parent == null:
		return null
	var effect: Node2D = LetterBulletExplosionEffect.new()
	effect.z_index = 120
	parent.add_child(effect)
	effect.global_position = global_pos
	effect.start(accent, debris_texture, debris_scale)
	return effect


func start(accent: Color, debris_texture: Texture2D, debris_scale: Vector2) -> void:
	_accent = accent
	_hot = Color(
		lerpf(1.0, accent.r, 0.25),
		lerpf(0.9, accent.g, 0.2),
		lerpf(0.45, accent.b, 0.15),
		1.0,
	)
	_spawn_core_burst()
	_spawn_fire_plume()
	_spawn_sparks()
	_spawn_smoke()
	_spawn_shockwave_particles()
	if debris_texture != null:
		_spawn_letter_debris(debris_texture, accent, debris_scale)
	set_process(true)
	var timer := get_tree().create_timer(LIFETIME)
	timer.timeout.connect(queue_free)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / LIFETIME, 0.0, 1.0)
	_core_radius = lerpf(6.0, 52.0, 1.0 - pow(1.0 - t, 3.0))
	_core_alpha = lerpf(1.0, 0.0, pow(t, 1.6))
	_shock_a = lerpf(0.0, 78.0, ease_out(t * 1.15))
	_shock_b = lerpf(0.0, 110.0, ease_out(maxf(0.0, t - 0.06) * 1.05))
	queue_redraw()


func _draw() -> void:
	if _core_alpha <= 0.01:
		return
	# Hot core bloom
	draw_circle(Vector2.ZERO, _core_radius * 0.22, Color(1.0, 1.0, 0.92, _core_alpha * 0.95))
	draw_circle(Vector2.ZERO, _core_radius * 0.48, Color(_hot.r, _hot.g, _hot.b, _core_alpha * 0.72))
	draw_circle(Vector2.ZERO, _core_radius * 0.78, Color(1.0, 0.45, 0.12, _core_alpha * 0.38))
	draw_circle(Vector2.ZERO, _core_radius, Color(0.85, 0.18, 0.05, _core_alpha * 0.18))
	# Expanding shock rings
	_draw_shock_ring(_shock_a, 0.55)
	_draw_shock_ring(_shock_b, 0.32)


func _draw_shock_ring(radius: float, strength: float) -> void:
	if radius < 4.0:
		return
	var alpha := _core_alpha * strength
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.82, 0.45, alpha * 0.85), 2.5, true)
	draw_arc(Vector2.ZERO, radius * 0.92, 0.0, TAU, 36, Color(1.0, 0.55, 0.15, alpha * 0.45), 5.0, true)


func _spawn_core_burst() -> void:
	var p := _make_particles()
	p.amount = 22
	p.lifetime = 0.18
	p.lifetime_randomness = 0.2
	p.explosiveness = 1.0
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 420.0
	p.spread = 180.0
	p.gravity = Vector2(0.0, 60.0)
	p.scale_amount_min = 3.5
	p.scale_amount_max = 7.0
	p.color = Color(1.0, 0.98, 0.82, 1.0)
	p.emission_sphere_radius = 4.0
	add_child(p)


func _spawn_fire_plume() -> void:
	var p := _make_particles()
	p.amount = 36
	p.lifetime = 0.42
	p.lifetime_randomness = 0.35
	p.explosiveness = 0.92
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 280.0
	p.spread = 180.0
	p.gravity = Vector2(0.0, 140.0)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 11.0
	p.color = Color(1.0, 0.55, 0.1, 0.95)
	p.emission_sphere_radius = 6.0
	add_child(p)
	var embers := _make_particles()
	embers.amount = 18
	embers.lifetime = 0.55
	embers.lifetime_randomness = 0.4
	embers.explosiveness = 0.88
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 160.0
	embers.spread = 180.0
	embers.gravity = Vector2(0.0, 80.0)
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 5.0
	embers.color = Color(_hot.r, _hot.g * 0.7, 0.08, 0.9)
	embers.emission_sphere_radius = 8.0
	add_child(embers)


func _spawn_sparks() -> void:
	var p := _make_particles()
	p.amount = 30
	p.lifetime = 0.35
	p.lifetime_randomness = 0.45
	p.explosiveness = 1.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 520.0
	p.spread = 180.0
	p.gravity = Vector2(0.0, 320.0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.8
	p.color = Color(1.0, 0.95, 0.7, 1.0)
	p.emission_sphere_radius = 3.0
	add_child(p)


func _spawn_smoke() -> void:
	var p := _make_particles()
	p.amount = 24
	p.lifetime = 0.72
	p.lifetime_randomness = 0.3
	p.explosiveness = 0.75
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 110.0
	p.spread = 180.0
	p.gravity = Vector2(0.0, -35.0)
	p.scale_amount_min = 6.0
	p.scale_amount_max = 16.0
	p.color = Color(0.22, 0.2, 0.22, 0.55)
	p.emission_sphere_radius = 10.0
	add_child(p)


func _spawn_shockwave_particles() -> void:
	var p := _make_particles()
	p.amount = 16
	p.lifetime = 0.28
	p.lifetime_randomness = 0.15
	p.explosiveness = 1.0
	p.direction = Vector2(1.0, 0.0)
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 340.0
	p.spread = 8.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.78, 0.35, 0.85)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 8.0
	p.emission_ring_inner_radius = 6.0
	add_child(p)


func _spawn_letter_debris(texture: Texture2D, modulate: Color, scale: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = texture
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 20
	p.lifetime = 0.55
	p.lifetime_randomness = 0.35
	p.randomness = 0.5
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2(0.0, 280.0)
	p.initial_velocity_min = 120.0 * scale.x
	p.initial_velocity_max = 340.0 * scale.x
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = scale.x * 0.12
	p.scale_amount_max = scale.x * 0.32
	LetterTint.apply_particles(p, modulate)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0 * scale.x
	p.local_coords = true
	add_child(p)


func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.direction = Vector2(0.0, -1.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 5.0
	p.local_coords = true
	return p


static func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.2)
