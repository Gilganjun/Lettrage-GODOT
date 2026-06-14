class_name PlayerShield
extends Node

## Placeholder for Phase 2B+ shield behaviour — independent from player movement.

signal shield_toggled(active: bool)

var is_active := false


func set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	shield_toggled.emit(active)


func blocks_letter_collection() -> bool:
	return is_active
