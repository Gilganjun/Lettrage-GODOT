class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: String)
signal healed(amount: int)
signal died(source: String)
signal reset_completed

@export var max_health: int = 50

var current_health: int = 50
var is_dead := false


func _ready() -> void:
	reset_health()


func reset_health() -> void:
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health)
	reset_completed.emit()


func apply_damage(amount: int, source: String = "") -> int:
	if is_dead or amount <= 0:
		return 0
	var applied := mini(amount, current_health)
	if applied <= 0:
		return 0
	current_health -= applied
	damaged.emit(applied, source)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		is_dead = true
		died.emit(source)
	return applied


func heal(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var before := current_health
	current_health = mini(max_health, current_health + amount)
	var applied := current_health - before
	if applied > 0:
		healed.emit(applied)
		health_changed.emit(current_health, max_health)
	return applied


func heal_full() -> void:
	heal(max_health)


func get_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return clampf(float(current_health) / float(max_health), 0.0, 1.0)
