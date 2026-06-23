class_name YouWinSplashFx
extends Control

## Round-win YOU WIN graphic — intro pop, hold, then discordant orbit (upright image).

const SPLASH_TEXTURE_PATHS: Array[String] = [
	"res://assets/GFX_End_of_Round/YouWin.png",
	"res://assets/GFX_End_of_Round/YouWIN1.png",
]

enum Mode {
	IDLE,
	INTRO,
	HOLD,
	ORBIT,
}

@export var display_width: float = 340.0
@export var intro_duration: float = 0.58
@export var start_scale: float = 0.06
@export var overshoot_scale: float = 1.14
@export var orbit_radius_x: float = 230.0
@export var orbit_radius_y: float = 175.0

@onready var _pivot: Control = $Pivot
@onready var _texture: TextureRect = $Pivot/TextureRect

var _splash_texture: Texture2D
var _display_size := Vector2.ZERO
var _mode := Mode.IDLE
var _hold_time := 0.0
var _orbit_time := 0.0
var _orbit_angle := 0.0
var _orbit_center_local := Vector2.ZERO
var _intro_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_texture = _load_splash_texture()
	if _splash_texture == null:
		push_error("YouWinSplashFx: could not load splash texture")
		return
	_layout_texture()
	visible = false


func _layout_texture() -> void:
	_texture.texture = _splash_texture
	var tex_size := _splash_texture.get_size()
	if tex_size.x <= 0.0:
		return
	var scale_factor := display_width / tex_size.x
	_display_size = tex_size * scale_factor
	custom_minimum_size = _display_size
	size = _display_size
	_pivot.custom_minimum_size = _display_size
	_pivot.size = _display_size
	_texture.custom_minimum_size = _display_size
	_texture.size = _display_size
	_pivot.pivot_offset = _display_size * 0.5
	_pivot.position = Vector2.ZERO


func play_splash_centered() -> void:
	if _splash_texture == null:
		return
	_layout_texture()
	_mode = Mode.INTRO
	_hold_time = 0.0
	_orbit_time = 0.0
	visible = true
	_center_on_parent()
	_pivot.scale = Vector2(start_scale, start_scale)
	_pivot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(
		_pivot,
		"scale",
		Vector2(overshoot_scale, overshoot_scale),
		intro_duration * 0.62,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(
		_pivot,
		"modulate:a",
		1.0,
		intro_duration * 0.28,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.chain().tween_property(
		_pivot,
		"scale",
		Vector2.ONE,
		intro_duration * 0.38,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)


func begin_orbit(orbit_center_global: Vector2) -> void:
	if not visible:
		return
	_mode = Mode.ORBIT
	_orbit_time = 0.0
	_orbit_angle = randf() * TAU
	_orbit_center_local = _global_to_local(orbit_center_global)
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	_tick_orbit(0.0)


func stop_splash() -> void:
	_mode = Mode.IDLE
	_hold_time = 0.0
	_orbit_time = 0.0
	visible = false
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_pivot.scale = Vector2.ONE
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	_pivot.modulate = Color.WHITE


func _on_intro_finished() -> void:
	_mode = Mode.HOLD
	_pivot.scale = Vector2.ONE
	_hold_time = 0.0


func _process(delta: float) -> void:
	match _mode:
		Mode.HOLD:
			_tick_hold(delta)
		Mode.ORBIT:
			_tick_orbit(delta)


func _tick_hold(delta: float) -> void:
	_hold_time += delta
	var breathe := 1.0 + sin(_hold_time * 4.2) * 0.018
	_pivot.scale = Vector2.ONE * breathe
	_pivot.rotation = 0.0


func _tick_orbit(delta: float) -> void:
	_orbit_time += delta
	var speed := (
		0.82
		+ sin(_orbit_time * 2.05) * 0.34
		+ sin(_orbit_time * 5.15) * 0.16
		+ cos(_orbit_time * 8.4) * 0.09
	)
	_orbit_angle += speed * delta
	var rx := (
		orbit_radius_x
		+ sin(_orbit_time * 3.05) * 42.0
		+ sin(_orbit_time * 7.25) * 16.0
	)
	var ry := (
		orbit_radius_y
		+ cos(_orbit_time * 2.65) * 34.0
		+ cos(_orbit_time * 6.05) * 13.0
	)
	var offset := Vector2(cos(_orbit_angle) * rx, sin(_orbit_angle) * ry)
	var jitter := Vector2(
		sin(_orbit_time * 19.3) * 5.5,
		cos(_orbit_time * 14.7) * 4.5,
	)
	position = _orbit_center_local - _display_size * 0.5 + offset + jitter
	_pivot.rotation = 0.0
	_pivot.position = Vector2.ZERO
	var breathe := 1.0 + sin(_orbit_time * 6.1) * 0.022 + sin(_orbit_time * 11.8) * 0.011
	_pivot.scale = Vector2.ONE * breathe


func _center_on_parent() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl:
		var area := parent_ctrl.get_rect()
		position = area.position + (area.size - _display_size) * 0.5
		return
	var vp := get_viewport().get_visible_rect()
	position = (vp.size - _display_size) * 0.5


func _global_to_local(global_pos: Vector2) -> Vector2:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl:
		return parent_ctrl.get_global_transform_with_canvas().affine_inverse() * global_pos
	return global_pos


func _load_splash_texture() -> Texture2D:
	for path in SPLASH_TEXTURE_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null
