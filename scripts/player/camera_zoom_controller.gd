class_name CameraZoomController
extends Camera2D

## Player follow camera zoom — +/- keys, 1% steps, hold to repeat.
## ACTION cinematic: smooth zoom-in during approach, hit shake, snap restore.

signal zoom_percent_changed(percent: float)

@export var base_zoom_percent := 82.0
@export var min_zoom_percent := 50.0
@export var max_zoom_percent := 200.0
@export var zoom_step_percent := 1.0
@export var hold_repeat_delay := 0.35
@export var hold_repeat_interval := 0.05
@export var action_zoom_min_duration := 0.28
@export var action_zoom_max_duration := 1.35
@export var hit_shake_duration := 0.22
@export var hit_shake_fist_strength := 11.0
@export var hit_shake_heavy_strength := 17.0

var _zoom_percent := 100.0
var _zoom_in_hold := -1.0
var _zoom_out_hold := -1.0
var _action_cinematic_active := false
var _saved_zoom_percent := 82.0
var _zoom_anim_elapsed := 0.0
var _zoom_anim_duration := 0.5
var _zoom_anim_from := 82.0
var _zoom_anim_to := 82.0
var _zoom_anim_done := false
var _shake_time_left := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	reset_to_base()


func _process(delta: float) -> void:
	if _action_cinematic_active:
		_tick_action_zoom(delta)
		_tick_hit_shake(delta)
	else:
		offset = Vector2.ZERO
		_zoom_in_hold = _update_zoom_axis(_is_zoom_in_held(), _zoom_in_hold, delta, zoom_step_percent)
		_zoom_out_hold = _update_zoom_axis(_is_zoom_out_held(), _zoom_out_hold, delta, -zoom_step_percent)


func reset_to_base() -> void:
	_zoom_percent = base_zoom_percent
	_zoom_in_hold = -1.0
	_zoom_out_hold = -1.0
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)


func get_zoom_percent() -> float:
	return _zoom_percent


func is_action_cinematic_active() -> bool:
	return _action_cinematic_active


func begin_action_cinematic(duration: float, zoom_boost_percent: float) -> void:
	_saved_zoom_percent = _zoom_percent
	_zoom_anim_from = _zoom_percent
	_zoom_anim_to = clampf(_zoom_percent + zoom_boost_percent, min_zoom_percent, max_zoom_percent)
	_zoom_anim_duration = clampf(duration, action_zoom_min_duration, action_zoom_max_duration)
	_zoom_anim_elapsed = 0.0
	_zoom_anim_done = false
	_action_cinematic_active = true
	_shake_time_left = 0.0
	offset = Vector2.ZERO


func trigger_hit_shake(strength: float = -1.0) -> void:
	if not _action_cinematic_active:
		return
	_shake_strength = hit_shake_fist_strength if strength < 0.0 else strength
	_shake_duration = hit_shake_duration
	_shake_time_left = hit_shake_duration


func end_action_cinematic() -> void:
	if not _action_cinematic_active:
		return
	_zoom_percent = _saved_zoom_percent
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)
	_action_cinematic_active = false
	_zoom_anim_done = false
	_shake_time_left = 0.0
	offset = Vector2.ZERO


func _tick_action_zoom(delta: float) -> void:
	if _zoom_anim_done:
		return
	_zoom_anim_elapsed += delta
	var t := clampf(_zoom_anim_elapsed / _zoom_anim_duration, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_zoom_percent = lerpf(_zoom_anim_from, _zoom_anim_to, t)
	_apply_zoom()
	if t >= 1.0:
		_zoom_anim_done = true


func _tick_hit_shake(delta: float) -> void:
	if _shake_time_left <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_time_left = maxf(0.0, _shake_time_left - delta)
	var factor := 1.0
	if _shake_duration > 0.0:
		factor = _shake_time_left / _shake_duration
	offset = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
	) * _shake_strength * factor


func _change_zoom(delta_percent: float) -> void:
	if _action_cinematic_active:
		return
	var next := clampf(_zoom_percent + delta_percent, min_zoom_percent, max_zoom_percent)
	if is_equal_approx(next, _zoom_percent):
		return
	_zoom_percent = next
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)


func _apply_zoom() -> void:
	var factor := _zoom_percent / 100.0
	zoom = Vector2(factor, factor)


func _update_zoom_axis(held: bool, hold_time: float, delta: float, delta_percent: float) -> float:
	if not held:
		return -1.0
	if hold_time < 0.0:
		_change_zoom(delta_percent)
		return 0.0
	hold_time += delta
	if hold_time < hold_repeat_delay:
		return hold_time
	_change_zoom(delta_percent)
	return hold_repeat_delay - hold_repeat_interval


func _is_zoom_in_held() -> bool:
	return (
		Input.is_physical_key_pressed(KEY_KP_ADD)
		or (
			Input.is_physical_key_pressed(KEY_EQUAL)
			and Input.is_key_pressed(KEY_SHIFT)
		)
	)


func _is_zoom_out_held() -> bool:
	return (
		Input.is_physical_key_pressed(KEY_MINUS)
		or Input.is_physical_key_pressed(KEY_KP_SUBTRACT)
	)
