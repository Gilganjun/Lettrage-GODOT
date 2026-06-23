class_name RoundIntroBackdrop
extends CanvasLayer

## Black starfield during the intro drop; level fades in as the starfield fades out.

@export var starfall_speed_min := 720.0
@export var starfall_speed_max := 1480.0

@onready var _black: ColorRect = $Black
@onready var _stars: CPUParticles2D = $Stars

var _level_root: Node2D
var _enemy_root: Node2D
var _active := false
var _saved_level_modulate := Color.WHITE
var _saved_enemy_modulate := Color.WHITE


func _ready() -> void:
	layer = 45
	visible = false
	_configure_stars()


func begin(level_root: Node2D, enemy_root: Node2D = null) -> void:
	_level_root = level_root
	_enemy_root = enemy_root
	_active = true
	visible = true
	if _black:
		_black.color = Color.BLACK
	if _level_root:
		_saved_level_modulate = _level_root.modulate
		_level_root.modulate = Color(_saved_level_modulate.r, _saved_level_modulate.g, _saved_level_modulate.b, 0.0)
	if _enemy_root:
		_saved_enemy_modulate = _enemy_root.modulate
		_enemy_root.modulate = Color(_saved_enemy_modulate.r, _saved_enemy_modulate.g, _saved_enemy_modulate.b, 0.0)
	if _stars:
		_stars.emitting = true
		_stars.speed_scale = 1.35
		_stars.restart()


func tick(progress: float) -> void:
	if not _active:
		return
	var p := clampf(progress, 0.0, 1.0)
	var level_t := _smoothstep(clampf((p - 0.08) / 0.72, 0.0, 1.0))
	var star_t := _smoothstep(clampf((p - 0.05) / 0.8, 0.0, 1.0))
	if _level_root:
		_level_root.modulate.a = lerpf(0.0, _saved_level_modulate.a, level_t)
	if _enemy_root:
		_enemy_root.modulate.a = lerpf(0.0, _saved_enemy_modulate.a, level_t)
	if _black:
		_black.color.a = lerpf(1.0, 0.0, level_t)
	if _stars:
		_stars.modulate.a = lerpf(1.0, 0.0, star_t)
		_stars.speed_scale = lerpf(1.35, 2.8, p)


func end() -> void:
	_active = false
	visible = false
	if _level_root:
		_level_root.modulate = _saved_level_modulate
	if _enemy_root:
		_enemy_root.modulate = _saved_enemy_modulate
	if _stars:
		_stars.emitting = false
		_stars.modulate.a = 1.0
	if _black:
		_black.color = Color.BLACK


func _configure_stars() -> void:
	if _stars == null:
		return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_stars.material = mat
	_stars.emitting = false
	_stars.amount = 120
	_stars.lifetime = 0.55
	_stars.preprocess = 0.5
	_stars.direction = Vector2(0.0, 1.0)
	_stars.spread = 8.0
	_stars.gravity = Vector2.ZERO
	_stars.initial_velocity_min = starfall_speed_min
	_stars.initial_velocity_max = starfall_speed_max
	_stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var viewport := get_viewport().get_visible_rect().size
	_stars.emission_rect_extents = Vector2(viewport.x * 0.55, 24.0)
	_stars.position = viewport * 0.5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
	gradient.set_color(1, Color(0.6, 0.8, 1.0, 0.0))
	_stars.color_ramp = gradient
	_stars.color = Color(0.92, 0.96, 1.0, 0.7)


func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
