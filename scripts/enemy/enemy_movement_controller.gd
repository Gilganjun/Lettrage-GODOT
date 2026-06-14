class_name EnemyMovementController
extends Node

## Patrol / obstacle response for Phase 2B2A — heallthbartest target-X wander (disabled in JSON, baseline design).

signal direction_changed(new_direction: int)
signal target_changed(new_target_x: float)

@export var patrol_min_x := 300.0
@export var patrol_max_x := 2000.0
@export var target_reach_threshold := 20.0
@export var target_deadband := 5.0
@export var jump_cooldown_duration := 0.35
@export var stuck_velocity_threshold := 8.0
@export var stuck_time_limit := 0.45

var target_x := 0.0
var direction := 1
var jump_cooldown := 0.0
var stuck_timer := 0.0

var letter_chase_active := false

var _rng := RandomNumberGenerator.new()
var _chase_direction := 0


func _ready() -> void:
	_rng.randomize()


func configure_patrol(min_x: float, max_x: float, initial_x: float) -> void:
	patrol_min_x = min_x
	patrol_max_x = max_x
	_pick_new_target(initial_x)


func tick(delta: float) -> void:
	if jump_cooldown > 0.0:
		jump_cooldown = maxf(0.0, jump_cooldown - delta)


func update_target(current_x: float) -> void:
	if absf(current_x - target_x) < target_reach_threshold:
		_pick_new_target(current_x)


func set_letter_chase_direction(direction: int) -> void:
	letter_chase_active = direction != 0
	_chase_direction = direction
	if direction != 0:
		set_direction(direction)


func clear_letter_chase() -> void:
	letter_chase_active = false
	_chase_direction = 0


func get_desired_direction(current_x: float) -> int:
	if letter_chase_active:
		return _chase_direction
	update_target(current_x)
	if current_x < target_x - target_deadband:
		return 1
	if current_x > target_x + target_deadband:
		return -1
	return direction


func set_direction(new_direction: int) -> void:
	if new_direction == 0:
		return
	if new_direction != direction:
		direction = new_direction
		direction_changed.emit(direction)


func reverse_direction() -> void:
	set_direction(-direction)


func request_jump() -> bool:
	if jump_cooldown > 0.0:
		return false
	jump_cooldown = jump_cooldown_duration
	return true


func update_stuck_timer(delta: float, on_floor: bool, horizontal_speed: float, blocked: bool) -> bool:
	if not on_floor or not blocked or horizontal_speed > stuck_velocity_threshold:
		stuck_timer = 0.0
		return false
	stuck_timer += delta
	return stuck_timer >= stuck_time_limit


func _pick_new_target(current_x: float) -> void:
	target_x = _rng.randf_range(patrol_min_x, patrol_max_x)
	if absf(target_x - current_x) < target_reach_threshold:
		target_x = _rng.randf_range(patrol_min_x, patrol_max_x)
	target_changed.emit(target_x)
