class_name PlayerRoll
extends Node

## Short defensive roll — reposition without collecting letters.

signal roll_started
signal roll_ended

@export var roll_speed: float = 520.0
@export var roll_duration: float = 0.28
@export var roll_cooldown: float = 0.55

var _rolling := false
var _cooldown_left := 0.0
var _time_left := 0.0
var _direction := 0


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)


func is_rolling() -> bool:
	return _rolling


func blocks_collection() -> bool:
	return _rolling


func try_start_roll(player: PlayerMovement) -> bool:
	if _rolling or _cooldown_left > 0.0 or player == null:
		return false
	if _player_action_active(player):
		return false
	if not player.is_on_floor() or player.is_on_ladder:
		return false
	var input_x := Input.get_axis("move_left", "move_right")
	var dir := int(signf(input_x)) if absf(input_x) > 0.1 else player.facing
	if dir == 0:
		dir = player.facing
	_direction = dir
	_rolling = true
	_time_left = roll_duration
	_cooldown_left = roll_cooldown
	_cancel_player_aim(player)
	roll_started.emit()
	return true


func process_roll(player: PlayerMovement, delta: float) -> bool:
	if not _rolling:
		if Input.is_action_just_pressed("player_roll"):
			return try_start_roll(player)
		return false
	_time_left -= delta
	var cfg := player.movement_config
	if cfg == null:
		cfg = load("res://resources/player/movement_config.tres")
	player.velocity.x = float(_direction) * roll_speed
	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		player.velocity.y = minf(
			player.velocity.y + cfg.gravity * delta,
			cfg.max_falling_speed,
		)
	player.facing = _direction
	if _time_left <= 0.0:
		_end_roll()
	return true


func _end_roll() -> void:
	if not _rolling:
		return
	_rolling = false
	roll_ended.emit()


func _cancel_player_aim(player: PlayerMovement) -> void:
	for child in player.get_children():
		if child is LetterShooter:
			(child as LetterShooter).cancel_aim()


func _player_action_active(player: PlayerMovement) -> bool:
	for child in player.get_children():
		if child.has_method("is_active") and child.call("is_active"):
			return true
	return false
