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
@export var intro_follow_smoothing_speed := 14.0

var _zoom_percent := 100.0
var _zoom_in_hold := -1.0
var _zoom_out_hold := -1.0
var _action_cinematic_active := false
var _round_intro_active := false
var _round_intro_start_zoom := 82.0
var _round_intro_end_zoom := 82.0
var _default_position_smoothing_speed := 9.5
var _saved_zoom_percent := 82.0
var _zoom_anim_elapsed := 0.0
var _zoom_anim_duration := 0.5
var _zoom_anim_from := 82.0
var _zoom_anim_to := 82.0
var _zoom_anim_done := false
var _shake_time_left := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _finisher_kill_cam_active := false
var _finisher_focus: Node2D = null
var _finisher_partner: Node2D = null
var _finisher_saved_time_scale := 1.0
var _finisher_saved_zoom_percent := 82.0
var _finisher_focus_lift := 36.0
var _finisher_saved_position_smoothing := false


func _ready() -> void:
	_default_position_smoothing_speed = position_smoothing_speed
	reset_to_base()


func _process(delta: float) -> void:
	if _finisher_kill_cam_active:
		_tick_finisher_kill_cam()
		return
	if _round_intro_active:
		offset = Vector2.ZERO
		return
	if _action_cinematic_active:
		_tick_action_zoom(delta)
		_tick_hit_shake(delta)
	else:
		offset = Vector2.ZERO
		_zoom_in_hold = _update_zoom_axis(_is_zoom_in_held(), _zoom_in_hold, delta, zoom_step_percent)
		_zoom_out_hold = _update_zoom_axis(_is_zoom_out_held(), _zoom_out_hold, delta, -zoom_step_percent)


func reset_to_base() -> void:
	end_finisher_kill_cam()
	end_round_intro_cinematic()
	Engine.time_scale = 1.0
	offset = Vector2.ZERO
	_zoom_percent = base_zoom_percent
	_zoom_in_hold = -1.0
	_zoom_out_hold = -1.0
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)


func get_zoom_percent() -> float:
	return _zoom_percent


func is_action_cinematic_active() -> bool:
	return _action_cinematic_active


func is_round_intro_active() -> bool:
	return _round_intro_active


func begin_round_intro_cinematic(start_zoom_percent: float, end_zoom_percent: float = -1.0) -> void:
	if end_zoom_percent < 0.0:
		end_zoom_percent = base_zoom_percent
	_round_intro_active = true
	_round_intro_start_zoom = clampf(start_zoom_percent, min_zoom_percent, max_zoom_percent)
	_round_intro_end_zoom = clampf(end_zoom_percent, min_zoom_percent, max_zoom_percent)
	_zoom_percent = _round_intro_start_zoom
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)
	position_smoothing_enabled = true
	position_smoothing_speed = intro_follow_smoothing_speed
	offset = Vector2.ZERO


func tick_round_intro_cinematic(progress: float) -> void:
	if not _round_intro_active:
		return
	var t := clampf(progress, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_zoom_percent = lerpf(_round_intro_start_zoom, _round_intro_end_zoom, t)
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)


func end_round_intro_cinematic() -> void:
	if not _round_intro_active:
		return
	_round_intro_active = false
	_zoom_percent = base_zoom_percent
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)
	position_smoothing_speed = _default_position_smoothing_speed
	offset = Vector2.ZERO


func begin_action_cinematic(duration: float, zoom_boost_percent: float) -> void:
	if _finisher_kill_cam_active:
		return
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


func set_zoom_percent(percent: float) -> void:
	_zoom_percent = clampf(percent, min_zoom_percent, max_zoom_percent)
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)


func reset_strike_presentation() -> void:
	end_finisher_kill_cam()
	Engine.time_scale = 1.0
	end_action_cinematic()
	offset = Vector2.ZERO
	reset_to_base()


func is_finisher_kill_cam_active() -> bool:
	return _finisher_kill_cam_active


func begin_finisher_kill_cam(
	focus: Node2D,
	partner: Node2D,
	zoom_percent: float,
	slow_scale: float,
) -> void:
	if focus == null or not is_instance_valid(focus):
		return
	end_round_intro_cinematic()
	end_action_cinematic()
	_finisher_kill_cam_active = true
	_finisher_focus = focus
	_finisher_partner = partner if partner != null and is_instance_valid(partner) else null
	_finisher_saved_time_scale = Engine.time_scale
	_finisher_saved_zoom_percent = _zoom_percent
	_finisher_saved_position_smoothing = position_smoothing_enabled
	_action_cinematic_active = false
	_shake_time_left = 0.0
	Engine.time_scale = clampf(slow_scale, 0.05, 1.0)
	SlowMotionNotifier.notify()
	_zoom_percent = clampf(zoom_percent, min_zoom_percent, max_zoom_percent)
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)
	position_smoothing_enabled = false
	enabled = true
	make_current()
	_snap_finisher_focus()


func end_finisher_kill_cam() -> void:
	if not _finisher_kill_cam_active:
		return
	_finisher_kill_cam_active = false
	_finisher_focus = null
	_finisher_partner = null
	Engine.time_scale = 1.0
	_zoom_percent = _finisher_saved_zoom_percent
	_apply_zoom()
	zoom_percent_changed.emit(_zoom_percent)
	offset = Vector2.ZERO
	position_smoothing_enabled = _finisher_saved_position_smoothing
	position_smoothing_speed = _default_position_smoothing_speed


func _tick_finisher_kill_cam() -> void:
	_snap_finisher_focus()


func _snap_finisher_focus() -> void:
	if _finisher_focus == null or not is_instance_valid(_finisher_focus):
		return
	var focus_pos := _fighter_visual_center(_finisher_focus)
	if _finisher_partner != null and is_instance_valid(_finisher_partner):
		focus_pos = (
			_fighter_visual_center(_finisher_focus) + _fighter_visual_center(_finisher_partner)
		) * 0.5
	focus_pos.y -= _finisher_focus_lift
	var anchor := get_parent()
	if anchor is Node2D:
		offset = focus_pos - (anchor as Node2D).global_position
	else:
		offset = focus_pos - global_position


func _fighter_visual_center(body: Node2D) -> Vector2:
	if body == null:
		return Vector2.ZERO
	var sprite := body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return body.global_position
	var local_visual := sprite.position + Vector2(
		sprite.offset.x * sprite.scale.x,
		sprite.offset.y * sprite.scale.y,
	)
	return body.global_position + local_visual


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
	if _action_cinematic_active or _round_intro_active or _finisher_kill_cam_active:
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
