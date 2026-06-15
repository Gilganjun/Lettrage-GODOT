class_name InjuryComponent
extends Node

signal injury_started(duration: float)
signal injury_ended

@export var default_duration := 3.0

var is_injured := false
var time_remaining := 0.0


func _process(delta: float) -> void:
	if not is_injured:
		return
	time_remaining -= delta
	if time_remaining <= 0.0:
		end_injury()


func start_injury(duration: float = -1.0) -> void:
	var dur := default_duration if duration < 0.0 else duration
	is_injured = true
	time_remaining = dur
	injury_started.emit(dur)


func end_injury() -> void:
	if not is_injured:
		return
	is_injured = false
	time_remaining = 0.0
	injury_ended.emit()


func blocks_actions() -> bool:
	return is_injured
