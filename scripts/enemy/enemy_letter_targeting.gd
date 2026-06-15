class_name EnemyLetterTargeting
extends Node

## Selects one letter target at a time for the enemy chase AI.

signal target_changed(letter: Letter)
signal target_dropped(reason: String)

@export var search_radius := 2000.0
@export var target_lock_min := 1.5
@export var delete_boundary_y := 648.0
@export var patrol_min_x := 100.0
@export var patrol_max_x := 2000.0
@export var unreachable_timeout := 4.0
@export var collect_proximity := 100.0

var current_target: Letter
var target_age := 0.0
var selection_reason := "none"
var drop_reason := "none"

var _needed_letter := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func tick(
	delta: float,
	enemy_pos: Vector2,
	needed_letter: String,
_shield_blocks_collection: bool,
) -> void:
	_needed_letter = needed_letter
	if needed_letter.is_empty():
		_drop_target("word_complete")
		return
	if current_target != null and not is_instance_valid(current_target):
		_drop_target("target_freed")
	elif current_target != null and current_target.is_resolved():
		_drop_target("target_resolved")
	elif current_target != null:
		target_age += delta
		if not _is_letter_valid_target(current_target, enemy_pos):
			_drop_target("target_invalid")
		elif target_age >= unreachable_timeout and enemy_pos.distance_to(current_target.global_position) > search_radius * 0.5:
			_drop_target("unreachable_timeout")
		return
	if needed_letter.is_empty():
		return
	if current_target == null:
		_pick_target(enemy_pos)


func get_chase_direction(enemy_pos: Vector2) -> int:
	if current_target == null or not is_instance_valid(current_target):
		return 0
	var dx := current_target.global_position.x - enemy_pos.x
	if absf(dx) < 8.0:
		return 0
	return 1 if dx > 0.0 else -1


func get_target_distance(enemy_pos: Vector2) -> float:
	if current_target == null or not is_instance_valid(current_target):
		return INF
	return enemy_pos.distance_to(current_target.global_position)


func is_within_collect_proximity(enemy_pos: Vector2) -> bool:
	return get_target_distance(enemy_pos) <= collect_proximity


func should_request_chase_jump(enemy_pos: Vector2, on_floor: bool) -> bool:
	if not on_floor or current_target == null:
		return false
	if get_target_distance(enemy_pos) > 200.0:
		return false
	return _rng.randi_range(1, 4) == 1


func get_debug_info(enemy_pos: Vector2) -> Dictionary:
	return {
		"target_letter": current_target.character if current_target else "",
		"target_position": current_target.global_position if current_target else Vector2.ZERO,
		"target_distance": get_target_distance(enemy_pos),
		"target_age": target_age,
		"selection_reason": selection_reason,
		"drop_reason": drop_reason,
		"needed_letter": _needed_letter,
	}


func _pick_target(enemy_pos: Vector2) -> void:
	var best: Letter = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("letters"):
		if node == null or not is_instance_valid(node):
			continue
		if not node is Letter:
			continue
		var letter := node as Letter
		if letter.is_resolved() or letter.character != _needed_letter:
			continue
		if not _is_letter_valid_target(letter, enemy_pos):
			continue
		var dist := enemy_pos.distance_to(letter.global_position)
		if dist < best_dist:
			best_dist = dist
			best = letter
	if best == null:
		selection_reason = "none_found"
		return
	current_target = best
	target_age = 0.0
	selection_reason = "nearest_%s" % best.character
	drop_reason = "none"
	target_changed.emit(best)


func _is_letter_valid_target(letter: Letter, enemy_pos: Vector2) -> bool:
	if letter.global_position.y >= delete_boundary_y - 8.0:
		return false
	if letter.global_position.x < patrol_min_x - 40.0 or letter.global_position.x > patrol_max_x + 40.0:
		return false
	if enemy_pos.distance_to(letter.global_position) > search_radius:
		return false
	return letter.character == _needed_letter


func drop_target(reason: String) -> void:
	_drop_target(reason)


func _drop_target(reason: String) -> void:
	if current_target != null:
		drop_reason = reason
		target_dropped.emit(reason)
	current_target = null
	target_age = 0.0
