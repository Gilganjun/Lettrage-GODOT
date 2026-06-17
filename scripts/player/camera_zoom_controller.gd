class_name CameraZoomController
extends Camera2D

## Player follow camera zoom — +/- keys, 1% steps, hold to repeat.

signal zoom_percent_changed(percent: float)

@export var base_zoom_percent := 82.0
@export var min_zoom_percent := 50.0
@export var max_zoom_percent := 200.0
@export var zoom_step_percent := 1.0
@export var hold_repeat_delay := 0.35
@export var hold_repeat_interval := 0.05

var _zoom_percent := 100.0
var _zoom_in_hold := -1.0
var _zoom_out_hold := -1.0


func _ready() -> void:
	reset_to_base()


func _process(delta: float) -> void:
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


func _change_zoom(delta_percent: float) -> void:
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
