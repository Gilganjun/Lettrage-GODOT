class_name EnemyObstacleResponse
extends Node

## Controlled randomized obstacle escape — one decision per encounter.

enum EscapeAction { NONE, JUMP, REVERSE, PAUSE_JUMP, PAUSE_REVERSE }

signal escape_action_chosen(action: EscapeAction)
signal encounter_cleared
signal stuck_fallback_triggered

@export var encounter_clear_distance := 64.0
@export var decision_cooldown_duration := 0.55
@export var post_jump_cooldown_duration := 0.85
@export var reversal_cooldown_duration := 0.35
@export var pause_min := 0.15
@export var pause_max := 0.45
@export var stuck_time_limit := 1.25
@export var snag_stuck_time_limit := 0.45
@export var encounter_stall_time_limit := 0.75
@export var stuck_velocity_threshold := 6.0
@export var failed_jump_block_radius := 28.0
@export var local_reverse_radius := 80.0
@export var jump_approach_min := 28.0
@export var jump_approach_max := 115.0
@export var hop_clearance := 14.0
@export var min_obstacle_hop_speed := 280.0
@export var max_obstacle_hop_speed := 520.0
@export var weight_jump_clear := 70
@export var weight_reverse_clear := 30
@export var weight_jump_uncertain := 30
@export var weight_reverse_uncertain := 70
@export var weight_jump_after_fail := 10
@export var weight_reverse_after_fail := 90
@export var weight_jump_early_bonus := 30
@export var weight_pause_vs_immediate := 25

var encounter_active := false
var selected_action: EscapeAction = EscapeAction.NONE
var obstacle_decision_cooldown := 0.0
var reversal_cooldown := 0.0
var last_blocked_x := 0.0
var last_obstacle_point := Vector2.ZERO
var failed_jump_count := 0
var repeated_reverse_count := 0
var pause_timer := 0.0
var stuck_timer := 0.0
var jump_suppressed := false
var last_escape_outcome := "none"
var total_decisions := 0
var jumps_chosen := 0
var reverses_chosen := 0
var stuck_fallbacks := 0
var max_stuck_duration := 0.0

var _pushing_block_timer := 0.0
var _pending_jump_impulse := 0.0
var _last_step_height := 40.0
var _jump_in_progress := false
var _jump_attempt_x := 0.0
var _was_airborne := false
var _executing := false
var _pause_then: EscapeAction = EscapeAction.NONE
var _last_reverse_x := 0.0
var _last_body_pos := Vector2.ZERO
var _encounter_stall_timer := 0.0
var _blocked_spot_jump_retries := 0
var _rng := RandomNumberGenerator.new()

const MAX_BLOCKED_SPOT_JUMP_RETRIES := 1
var _movement_controller: EnemyMovementController
var _movement_config: EnemyMovementConfig
var _last_sensor: Dictionary = {}


func _ready() -> void:
	_rng.randomize()


func setup(movement_controller: EnemyMovementController, config: EnemyMovementConfig = null) -> void:
	_movement_controller = movement_controller
	_movement_config = config


func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func reset_after_recovery() -> void:
	encounter_active = false
	selected_action = EscapeAction.NONE
	_executing = false
	_pause_then = EscapeAction.NONE
	_pending_jump_impulse = 0.0
	_jump_in_progress = false
	_was_airborne = false
	pause_timer = 0.0
	stuck_timer = 0.0
	_pushing_block_timer = 0.0
	_encounter_stall_timer = 0.0
	_blocked_spot_jump_retries = 0
	jump_suppressed = false
	failed_jump_count = 0
	obstacle_decision_cooldown = 0.35


func tick(
	delta: float,
	sensor: Dictionary,
	body_pos: Vector2,
	on_floor: bool,
	in_air: bool,
	horizontal_speed: float,
	intended_direction: int,
) -> void:
	_last_sensor = sensor
	_last_body_pos = body_pos
	if obstacle_decision_cooldown > 0.0:
		obstacle_decision_cooldown = maxf(0.0, obstacle_decision_cooldown - delta)
	if reversal_cooldown > 0.0:
		reversal_cooldown = maxf(0.0, reversal_cooldown - delta)
	if pause_timer > 0.0:
		pause_timer = maxf(0.0, pause_timer - delta)
		if pause_timer <= 0.0 and _pause_then != EscapeAction.NONE:
			_begin_execute(_pause_then)
		return
	if encounter_active and on_floor and absf(body_pos.x - last_blocked_x) > encounter_clear_distance:
		_clear_encounter("moved_away")
	if in_air:
		_was_airborne = true
	elif _was_airborne and on_floor:
		_on_landed(body_pos, sensor)
		_was_airborne = false
		_jump_in_progress = false
	if _executing:
		_tick_executing(delta, sensor, body_pos, on_floor, horizontal_speed, intended_direction)
		return
	if _jump_in_progress and in_air:
		return
	var dist := float(sensor.get("distance_to_obstacle", INF))
	var early_jump_zone := (
		bool(sensor.get("early_approach", false))
		and dist >= jump_approach_min
		and dist <= jump_approach_max
	)
	var blocked := (
		bool(sensor.get("blocked_wall", false))
		or bool(sensor.get("ledge_ahead", false))
		or early_jump_zone
	)
	var pushing_without_sensor := (
		not blocked
		and on_floor
		and intended_direction != 0
		and horizontal_speed < stuck_velocity_threshold
		and not bool(sensor.get("ahead_obstacle", false))
	)
	if pushing_without_sensor:
		_pushing_block_timer += delta
	else:
		_pushing_block_timer = 0.0
	if not blocked and _pushing_block_timer >= 0.22:
		blocked = true
		if last_obstacle_point == Vector2.ZERO:
			last_obstacle_point = body_pos + Vector2(float(intended_direction) * 20.0, 0.0)
	var movement_blocked := _is_movement_blocked(sensor, blocked, pushing_without_sensor)
	if blocked and not encounter_active and obstacle_decision_cooldown <= 0.0 and on_floor and not _jump_in_progress:
		_start_encounter(sensor, body_pos)
	elif (
		movement_blocked
		and on_floor
		and intended_direction != 0
		and horizontal_speed < stuck_velocity_threshold
	):
		stuck_timer += delta
		max_stuck_duration = maxf(max_stuck_duration, stuck_timer)
		if stuck_timer >= _stuck_time_for(sensor):
			_stuck_fallback(body_pos)
	else:
		stuck_timer = 0.0
	if encounter_active and not _executing and not _jump_in_progress and on_floor:
		if movement_blocked and intended_direction != 0 and horizontal_speed < stuck_velocity_threshold:
			_encounter_stall_timer += delta
			var stall_limit := encounter_stall_time_limit
			if bool(sensor.get("geometry_snag", false)):
				stall_limit = snag_stuck_time_limit
			if _encounter_stall_timer >= stall_limit:
				_stuck_fallback(body_pos)
		else:
			_encounter_stall_timer = 0.0


func is_jump_in_progress() -> bool:
	return _jump_in_progress


func is_paused() -> bool:
	return pause_timer > 0.0


func consume_jump_request() -> float:
	if _pending_jump_impulse <= 0.0:
		return 0.0
	var impulse := _pending_jump_impulse
	_pending_jump_impulse = 0.0
	return impulse


func get_debug_info(sensor: Dictionary) -> Dictionary:
	var detected := (
		bool(sensor.get("blocked_wall", false))
		or bool(sensor.get("geometry_snag", false))
		or bool(sensor.get("ledge_ahead", false))
		or bool(sensor.get("ahead_obstacle", false))
	)
	return {
		"obstacle_detected": detected,
		"geometry_snag": bool(sensor.get("geometry_snag", false)),
		"ahead_obstacle": bool(sensor.get("ahead_obstacle", false)),
		"distance_to_obstacle": sensor.get("distance_to_obstacle", INF),
		"early_approach": bool(sensor.get("early_approach", false)),
		"obstacle_point": last_obstacle_point,
		"selected_response": EscapeAction.keys()[selected_action],
		"jumpable": bool(sensor.get("jumpable", false)),
		"floor_beyond": bool(sensor.get("floor_beyond", false)),
		"obstacle_height": sensor.get("obstacle_height", 0.0),
		"pending_jump_impulse": _pending_jump_impulse,
		"jump_in_progress": _jump_in_progress,
		"encounter_active": encounter_active,
		"decision_cooldown": obstacle_decision_cooldown,
		"failed_jump_count": failed_jump_count,
		"jump_suppressed": jump_suppressed,
		"reverse_count": repeated_reverse_count,
		"stuck_timer": stuck_timer,
		"last_escape_outcome": last_escape_outcome,
		"total_decisions": total_decisions,
		"jumps_chosen": jumps_chosen,
		"reverses_chosen": reverses_chosen,
		"stuck_fallbacks": stuck_fallbacks,
		"max_stuck_duration": max_stuck_duration,
		"pushing_block_timer": _pushing_block_timer,
		"encounter_stall_timer": _encounter_stall_timer,
	}


func _start_encounter(sensor: Dictionary, body_pos: Vector2) -> void:
	encounter_active = true
	last_blocked_x = body_pos.x
	_last_step_height = maxf(float(sensor.get("obstacle_height", 0.0)), 24.0)
	if sensor.get("wall_point", Vector2.ZERO) != Vector2.ZERO:
		last_obstacle_point = sensor.get("wall_point", Vector2.ZERO)
	elif sensor.get("ledge_ahead", false):
		last_obstacle_point = body_pos + Vector2(float(sensor.get("direction", 1)) * 24.0, 0.0)
	var action := _pick_action(sensor)
	selected_action = action
	total_decisions += 1
	escape_action_chosen.emit(action)
	if action == EscapeAction.PAUSE_JUMP or action == EscapeAction.PAUSE_REVERSE:
		pause_timer = _rng.randf_range(pause_min, pause_max)
		_pause_then = (
			EscapeAction.JUMP if action == EscapeAction.PAUSE_JUMP else EscapeAction.REVERSE
		)
		last_escape_outcome = "pause_%s" % EscapeAction.keys()[_pause_then]
	else:
		_begin_execute(action)


func _pick_action(sensor: Dictionary) -> EscapeAction:
	var jumpable: bool = sensor.get("jumpable", false)
	var early: bool = bool(sensor.get("early_approach", false))
	var jump_weight := weight_jump_clear if jumpable else weight_jump_uncertain
	var reverse_weight := weight_reverse_clear if jumpable else weight_reverse_uncertain
	if bool(sensor.get("geometry_snag", false)) and not jumpable:
		jump_weight = 5
		reverse_weight = 95
	elif jumpable:
		jump_weight += 20
		reverse_weight = maxi(10, reverse_weight - 15)
	if early and jumpable:
		jump_weight += weight_jump_early_bonus
		reverse_weight = maxi(10, reverse_weight - 15)
	if failed_jump_count > 0 or jump_suppressed:
		jump_weight = weight_jump_after_fail
		reverse_weight = weight_reverse_after_fail
	if repeated_reverse_count >= 2 and jumpable and not jump_suppressed:
		jump_weight += 35
		reverse_weight = maxi(5, reverse_weight - 25)
	var pick_jump := _rng.randi_range(0, jump_weight + reverse_weight - 1) < jump_weight
	var base := EscapeAction.JUMP if pick_jump else EscapeAction.REVERSE
	if early and jumpable and pick_jump:
		return EscapeAction.JUMP
	if early and jumpable and not pick_jump:
		return EscapeAction.REVERSE
	if pick_jump and jumpable:
		return EscapeAction.JUMP
	if _rng.randi_range(0, 99) < weight_pause_vs_immediate and not jumpable:
		return EscapeAction.PAUSE_JUMP if base == EscapeAction.JUMP else EscapeAction.PAUSE_REVERSE
	return base


func _begin_execute(action: EscapeAction) -> void:
	_executing = true
	selected_action = action
	match action:
		EscapeAction.JUMP:
			if jump_suppressed or _movement_controller == null:
				_execute_reverse()
			elif _movement_controller.request_jump():
				_pending_jump_impulse = _compute_hop_speed(_last_step_height)
				_jump_attempt_x = last_blocked_x
				_jump_in_progress = true
				jumps_chosen += 1
				last_escape_outcome = "jump"
				obstacle_decision_cooldown = post_jump_cooldown_duration
			else:
				_execute_reverse()
		EscapeAction.REVERSE:
			_execute_reverse()
		_:
			_executing = false


func _compute_hop_speed(step_height: float) -> float:
	var gravity := _movement_config.gravity if _movement_config else 1700.0
	var target_height := maxf(step_height + hop_clearance, 20.0)
	var speed := sqrt(2.0 * gravity * target_height)
	return clampf(speed, min_obstacle_hop_speed, max_obstacle_hop_speed)


func _execute_reverse() -> void:
	var block_dir := _movement_controller.direction if _movement_controller else 1
	if _movement_controller:
		_movement_controller.reverse_direction()
		_movement_controller.retreat_from_obstacle(_last_body_pos.x, block_dir)
		if absf(_last_reverse_x) > 0.01 and absf(_movement_controller.direction) > 0:
			if absf(last_blocked_x - _last_reverse_x) < local_reverse_radius:
				repeated_reverse_count += 1
		_last_reverse_x = last_blocked_x
		reverses_chosen += 1
	reversal_cooldown = reversal_cooldown_duration
	obstacle_decision_cooldown = decision_cooldown_duration
	last_escape_outcome = "reverse"
	_clear_encounter("reverse")


func _tick_executing(
	delta: float,
	sensor: Dictionary,
	body_pos: Vector2,
	on_floor: bool,
	_horizontal_speed: float,
	_intended_direction: int,
) -> void:
	if selected_action == EscapeAction.JUMP and on_floor and _pending_jump_impulse <= 0.0:
		if bool(sensor.get("blocked_wall", false)) and absf(body_pos.x - last_blocked_x) < failed_jump_block_radius:
			if _blocked_spot_jump_retries >= MAX_BLOCKED_SPOT_JUMP_RETRIES:
				_execute_reverse()
			else:
				_blocked_spot_jump_retries += 1
				_stuck_fallback(body_pos)
		else:
			_clear_encounter("jump_complete")


func _on_landed(body_pos: Vector2, sensor: Dictionary) -> void:
	if selected_action != EscapeAction.JUMP:
		return
	if absf(body_pos.x - _jump_attempt_x) < failed_jump_block_radius and bool(sensor.get("blocked_wall", false)):
		failed_jump_count += 1
		jump_suppressed = true
		last_escape_outcome = "jump_failed"
		if _movement_controller:
			_movement_controller.reverse_direction()
			reverses_chosen += 1
		_clear_encounter("jump_failed_reverse")
	elif body_pos.x > last_blocked_x + failed_jump_block_radius * 0.5 or body_pos.x < last_blocked_x - failed_jump_block_radius * 0.5:
		failed_jump_count = 0
		jump_suppressed = false
		_clear_encounter("jump_passed")


func _stuck_fallback(body_pos: Vector2) -> void:
	if (
		bool(_last_sensor.get("jumpable", false))
		and not jump_suppressed
		and _blocked_spot_jump_retries < MAX_BLOCKED_SPOT_JUMP_RETRIES
		and _movement_controller != null
		and _movement_controller.request_jump()
	):
		_blocked_spot_jump_retries += 1
		_pending_jump_impulse = _compute_hop_speed(
			maxf(float(_last_sensor.get("obstacle_height", 0.0)), 24.0)
		)
		_jump_attempt_x = body_pos.x
		_jump_in_progress = true
		jumps_chosen += 1
		last_escape_outcome = "stuck_jump"
		obstacle_decision_cooldown = post_jump_cooldown_duration
		stuck_timer = 0.0
		_encounter_stall_timer = 0.0
		return
	stuck_fallbacks += 1
	stuck_fallback_triggered.emit()
	last_escape_outcome = "stuck_fallback_reverse"
	var block_dir := _movement_controller.direction if _movement_controller else 1
	if _movement_controller:
		_movement_controller.reverse_direction()
		_movement_controller.retreat_from_obstacle(body_pos.x, block_dir)
		reverses_chosen += 1
	reversal_cooldown = reversal_cooldown_duration
	obstacle_decision_cooldown = decision_cooldown_duration
	stuck_timer = 0.0
	_encounter_stall_timer = 0.0
	last_blocked_x = body_pos.x
	_clear_encounter("stuck_fallback")


func _clear_encounter(reason: String) -> void:
	if encounter_active:
		encounter_cleared.emit()
	last_escape_outcome = reason
	encounter_active = false
	selected_action = EscapeAction.NONE
	_executing = false
	_pause_then = EscapeAction.NONE
	_encounter_stall_timer = 0.0
	if reason in ["moved_away", "jump_passed", "reverse", "jump_complete", "stuck_fallback"]:
		jump_suppressed = false
		if reason in ["moved_away", "jump_passed"]:
			failed_jump_count = 0
			repeated_reverse_count = 0
			_blocked_spot_jump_retries = 0


func _is_movement_blocked(sensor: Dictionary, blocked: bool, pushing_without_sensor: bool) -> bool:
	return (
		blocked
		or bool(sensor.get("geometry_snag", false))
		or pushing_without_sensor
	)


func _stuck_time_for(sensor: Dictionary) -> float:
	if bool(sensor.get("geometry_snag", false)):
		return snag_stuck_time_limit
	return stuck_time_limit
