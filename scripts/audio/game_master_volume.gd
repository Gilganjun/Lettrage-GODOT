extends Node

## Global master volume — / and * keys, 10% steps, hold to repeat.

signal volume_percent_changed(percent: float)

const MASTER_BUS := "Master"
const STEP_PERCENT := 10.0
const HOLD_REPEAT_DELAY := 0.35
const HOLD_REPEAT_INTERVAL := 0.05

var _volume_percent := 100.0
var _volume_down_hold := -1.0
var _volume_up_hold := -1.0


func _ready() -> void:
	_apply_volume()


func _process(delta: float) -> void:
	_volume_down_hold = _update_axis(_is_volume_down_held(), _volume_down_hold, delta, -STEP_PERCENT)
	_volume_up_hold = _update_axis(_is_volume_up_held(), _volume_up_hold, delta, STEP_PERCENT)


func get_volume_percent() -> float:
	return _volume_percent


func set_volume_percent(percent: float) -> void:
	var next := clampf(percent, 0.0, 100.0)
	if is_equal_approx(next, _volume_percent):
		return
	_volume_percent = next
	_apply_volume()
	volume_percent_changed.emit(_volume_percent)


func _apply_volume() -> void:
	var bus_idx := AudioServer.get_bus_index(MASTER_BUS)
	if bus_idx < 0:
		return
	if _volume_percent <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
		return
	AudioServer.set_bus_mute(bus_idx, false)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(_volume_percent / 100.0))


func _update_axis(held: bool, hold_time: float, delta: float, delta_percent: float) -> float:
	if not held:
		return -1.0
	if hold_time < 0.0:
		set_volume_percent(_volume_percent + delta_percent)
		return 0.0
	hold_time += delta
	if hold_time < HOLD_REPEAT_DELAY:
		return hold_time
	set_volume_percent(_volume_percent + delta_percent)
	return HOLD_REPEAT_DELAY - HOLD_REPEAT_INTERVAL


func _is_volume_down_held() -> bool:
	return (
		Input.is_physical_key_pressed(KEY_SLASH)
		or Input.is_physical_key_pressed(KEY_KP_DIVIDE)
	)


func _is_volume_up_held() -> bool:
	return (
		Input.is_physical_key_pressed(KEY_ASTERISK)
		or Input.is_physical_key_pressed(KEY_KP_MULTIPLY)
		or (
			Input.is_physical_key_pressed(KEY_8)
			and Input.is_key_pressed(KEY_SHIFT)
		)
	)
