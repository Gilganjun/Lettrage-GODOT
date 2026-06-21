class_name IntroFallFx
extends Node2D

## Upward streak particles + parallax layers during the round-intro drop.

const LAYER_SPECS := [
	{
		"z": -3,
		"amount": 22,
		"speed_min": 620.0,
		"speed_max": 920.0,
		"scale_min": 0.45,
		"scale_max": 0.9,
		"alpha": 0.28,
		"extents": Vector2(30.0, 78.0),
	},
	{
		"z": -2,
		"amount": 34,
		"speed_min": 900.0,
		"speed_max": 1380.0,
		"scale_min": 0.65,
		"scale_max": 1.2,
		"alpha": 0.46,
		"extents": Vector2(24.0, 64.0),
	},
	{
		"z": -1,
		"amount": 16,
		"speed_min": 1180.0,
		"speed_max": 1760.0,
		"scale_min": 0.95,
		"scale_max": 1.65,
		"alpha": 0.62,
		"extents": Vector2(18.0, 48.0),
	},
]

var _layers: Array[CPUParticles2D] = []
var _active := false
var _add_material: CanvasItemMaterial


func _ready() -> void:
	visible = false
	z_index = -10
	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_layers()


func begin() -> void:
	_active = true
	visible = true
	for layer in _layers:
		layer.speed_scale = 1.0
		layer.emitting = true
		layer.restart()


func tick(progress: float) -> void:
	if not _active:
		return
	var t := clampf(progress, 0.0, 1.0)
	for i in _layers.size():
		var layer := _layers[i]
		var parallax := 1.0 + float(i) * 0.24
		layer.speed_scale = lerpf(0.95, 2.6, t) * parallax


func end() -> void:
	_active = false
	for layer in _layers:
		layer.emitting = false
	visible = false


func _build_layers() -> void:
	for spec in LAYER_SPECS:
		_layers.append(_make_layer(spec))


func _make_layer(spec: Dictionary) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "FallStreakLayer"
	particles.z_index = int(spec["z"])
	particles.material = _add_material
	particles.emitting = false
	particles.one_shot = false
	particles.local_coords = false
	particles.amount = int(spec["amount"])
	particles.lifetime = 0.48
	particles.preprocess = 0.4
	particles.explosiveness = 0.0
	particles.randomness = 0.35
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 14.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = float(spec["speed_min"])
	particles.initial_velocity_max = float(spec["speed_max"])
	particles.angular_velocity_min = -12.0
	particles.angular_velocity_max = 12.0
	particles.scale_amount_min = float(spec["scale_min"])
	particles.scale_amount_max = float(spec["scale_max"])
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = spec["extents"]
	var alpha := float(spec["alpha"])
	particles.color = Color(0.86, 0.95, 1.0, alpha)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.95, 0.98, 1.0, alpha))
	gradient.set_color(1, Color(0.55, 0.78, 1.0, 0.0))
	particles.color_ramp = gradient
	add_child(particles)
	return particles
