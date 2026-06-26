class_name ActionStrikeCameraDirector
extends RefCounted

## Experimental per-hit strike camera — randomly alternates with the primary ACTION cinematic.
## PRIMARY: existing smooth approach zoom + hit shake (CameraZoomController.begin_action_cinematic).
## DRAMATIC: 4 frames before each hit → slow-mo + tight zoom; 2 frames after → snap back.

enum Style { PRIMARY, DRAMATIC }

const FRAMES_BEFORE_HIT := 4
const FRAMES_AFTER_HIT := 2

var dramatic_chance := 0.35
var dramatic_slow_scale := 0.18
var dramatic_screen_fill := 0.88
var fighter_height_estimate := 130.0
var fighter_width_estimate := 100.0

var style := Style.PRIMARY

var _cam: CameraZoomController
var _attacker: Node2D
var _defender: Node2D
var _windows: Array[Vector2i] = []
var _in_pulse := false
var _active := false
var _saved_time_scale := 1.0
var _saved_zoom_percent := 82.0
var _primary_begin: Callable


func configure(chance: float, slow_scale: float, screen_fill: float) -> void:
	dramatic_chance = chance
	dramatic_slow_scale = slow_scale
	dramatic_screen_fill = screen_fill


func roll_for_sequence(
	cam: CameraZoomController,
	attacker: Node2D,
	defender: Node2D,
	attack: ActionAttackDefinition,
	primary_begin: Callable,
) -> Style:
	_reset_internal()
	_cam = cam
	_attacker = attacker
	_defender = defender
	_saved_time_scale = Engine.time_scale
	if _cam != null:
		_saved_zoom_percent = _cam.get_zoom_percent()
	_primary_begin = primary_begin
	style = Style.DRAMATIC if randf() < dramatic_chance else Style.PRIMARY
	_build_windows(attack)
	_active = true
	if style == Style.PRIMARY and _primary_begin.is_valid():
		_primary_begin.call()
	return style


func uses_dramatic_style() -> bool:
	return style == Style.DRAMATIC


func uses_primary_style() -> bool:
	return style == Style.PRIMARY


func tick_strike_frame(frame_num: int) -> void:
	if not _active or style != Style.DRAMATIC or _cam == null:
		return
	if _cam.is_finisher_kill_cam_active():
		return
	var in_window := _is_in_window(frame_num)
	if in_window and not _in_pulse:
		_enter_pulse()
	elif not in_window and _in_pulse:
		_exit_pulse()


func trigger_hit_shake(strength: float) -> void:
	if not _active or _cam == null or style != Style.PRIMARY:
		return
	_cam.trigger_hit_shake(strength)


func end_sequence() -> void:
	if not _active:
		return
	if _in_pulse:
		_exit_pulse()
	if style == Style.PRIMARY:
		if _cam != null and not _cam.is_finisher_kill_cam_active():
			_cam.end_action_cinematic()
	else:
		_restore_baseline()
	_reset_internal()


func end_sequence_for_finisher() -> void:
	if not _active:
		return
	_in_pulse = false
	_reset_internal()


static func clear_strike_presentation(cam: CameraZoomController = null) -> void:
	Engine.time_scale = 1.0
	if cam == null:
		return
	cam.offset = Vector2.ZERO
	if cam.has_method("end_action_cinematic"):
		cam.end_action_cinematic()


static func force_reset_presentation(cam: CameraZoomController = null) -> void:
	clear_strike_presentation(cam)
	if cam != null and cam.has_method("reset_to_base"):
		cam.reset_to_base()


func _build_windows(attack: ActionAttackDefinition) -> void:
	_windows.clear()
	if attack == null:
		return
	for hit_frame in attack.hit_frames:
		_windows.append(
			Vector2i(hit_frame - FRAMES_BEFORE_HIT, hit_frame + FRAMES_AFTER_HIT)
		)


func _is_in_window(frame_num: int) -> bool:
	for window in _windows:
		if frame_num >= window.x and frame_num <= window.y:
			return true
	return false


func _enter_pulse() -> void:
	if _cam != null and _cam.is_finisher_kill_cam_active():
		return
	_in_pulse = true
	Engine.time_scale = dramatic_slow_scale
	SlowMotionNotifier.notify()
	_center_on_fighters()
	_cam.set_zoom_percent(_compute_fill_zoom_percent())


func _exit_pulse() -> void:
	_in_pulse = false
	_restore_baseline()


func _restore_baseline() -> void:
	Engine.time_scale = _saved_time_scale
	if _cam == null or _cam.is_finisher_kill_cam_active():
		return
	_cam.offset = Vector2.ZERO
	_cam.set_zoom_percent(_saved_zoom_percent)


func _center_on_fighters() -> void:
	if _cam == null or _attacker == null or _defender == null:
		return
	if _cam.is_finisher_kill_cam_active():
		return
	var mid := (_attacker.global_position + _defender.global_position) * 0.5
	var anchor := _cam.get_parent()
	if anchor is Node2D:
		_cam.offset = mid - (anchor as Node2D).global_position
	else:
		_cam.offset = mid - _cam.global_position


func _compute_fill_zoom_percent() -> float:
	if _cam == null or _attacker == null or _defender == null:
		return _saved_zoom_percent
	var vp := _cam.get_viewport().get_visible_rect().size
	if vp.y <= 1.0:
		return _saved_zoom_percent
	var min_x := minf(_attacker.global_position.x, _defender.global_position.x)
	var max_x := maxf(_attacker.global_position.x, _defender.global_position.x)
	var min_y := minf(_attacker.global_position.y, _defender.global_position.y)
	var max_y := maxf(_attacker.global_position.y, _defender.global_position.y)
	var world_w := maxf(max_x - min_x + fighter_width_estimate, fighter_width_estimate)
	var world_h := maxf(
		max_y - min_y + fighter_height_estimate,
		fighter_height_estimate * 0.75,
	)
	var zoom_factor := maxf(
		vp.y / (world_h * dramatic_screen_fill),
		vp.x / (world_w * dramatic_screen_fill),
	)
	return clampf(zoom_factor * 100.0, _cam.min_zoom_percent, _cam.max_zoom_percent)


func _reset_internal() -> void:
	_cam = null
	_attacker = null
	_defender = null
	_windows.clear()
	_in_pulse = false
	_active = false
	_primary_begin = Callable()
	style = Style.PRIMARY
