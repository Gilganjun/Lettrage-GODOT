class_name EnemyShieldController
extends Node

## AI-driven enemy shield — collection gate + destroy-on-contact.

signal state_changed

@export var reactivate_delay := 0.3
@export var collect_proximity := 100.0
@export var anti_pick_box_x := 10.0
@export var anti_pick_box_y_top := 10.0
@export var anti_pick_box_y_bottom := 5.0
@export var target_exempt_distance := 20.0

var shield: Node2D

var _reactivate_timer := 0.0
var _waiting_reactivate := false
var _word_stun_locked := false
var _intro_shield_forced := false
var _body: CharacterBody2D
var _targeting: Node


var last_activation_reason := "start_active"


func setup(body: CharacterBody2D, shield_component: Node2D, targeting: Node) -> void:
	_body = body
	shield = shield_component
	_targeting = targeting
	if shield:
		shield.start_active = true
		shield.owner_group = "enemy"
		shield.impact_source = "enemy_shield"
		if not shield.is_active:
			shield.activate("depart_scene")


func enter_word_stun_lock() -> void:
	_word_stun_locked = true
	_waiting_reactivate = false
	_reactivate_timer = 0.0
	if shield:
		shield.deactivate("word_stun")
	last_activation_reason = "word_stun"
	state_changed.emit()


func exit_word_stun_lock() -> void:
	_word_stun_locked = false


func set_intro_shield_forced(active: bool) -> void:
	_intro_shield_forced = active
	if shield == null:
		return
	if active:
		_waiting_reactivate = false
		_reactivate_timer = 0.0
		shield.activate("round_intro")
		last_activation_reason = "round_intro"
	else:
		shield.deactivate("round_intro")
		last_activation_reason = "round_intro_end"
	state_changed.emit()


func tick(delta: float, enemy_pos: Vector2) -> void:
	if _intro_shield_forced:
		if shield and not shield.is_active:
			shield.activate("round_intro")
		return
	if _word_stun_locked:
		if shield and shield.is_active:
			shield.deactivate("word_stun")
		return
	if _waiting_reactivate:
		_reactivate_timer -= delta
		if _reactivate_timer <= 0.0:
			_waiting_reactivate = false
			if shield:
				shield.activate("post_collect_cooldown")
				last_activation_reason = "post_collect_cooldown"
				state_changed.emit()
		return
	if shield == null or _body == null or _targeting == null:
		return
	var target: Letter = _targeting.get_valid_target() if _targeting.has_method("get_valid_target") else null
	var target_dist: float = _targeting.get_target_distance(enemy_pos)
	if target != null and is_instance_valid(target) and target_dist < collect_proximity:
		if shield.is_active:
			shield.deactivate("collect_proximity")
			last_activation_reason = "collect_proximity"
			state_changed.emit()
		return
	if _should_force_shield_on(enemy_pos, target):
		if not shield.is_active and not _waiting_reactivate:
			shield.activate("anti_double_pick")
			last_activation_reason = "anti_double_pick"
			state_changed.emit()


func notify_letter_collected() -> void:
	if shield:
		shield.deactivate("collected")
	_waiting_reactivate = true
	_reactivate_timer = reactivate_delay
	last_activation_reason = "collected"
	state_changed.emit()


func debug_force_shield(active: bool) -> void:
	if shield == null:
		return
	if active:
		shield.activate("debug_force")
	else:
		shield.deactivate("debug_force")
	last_activation_reason = "debug_force"
	state_changed.emit()


func get_debug_info() -> Dictionary:
	var info: Dictionary = shield.get_debug_info() if shield else {}
	info["last_activation_reason"] = last_activation_reason
	info["reactivate_timer"] = _reactivate_timer
	info["word_stun_locked"] = _word_stun_locked
	info["intro_shield_forced"] = _intro_shield_forced
	return info


func _should_force_shield_on(enemy_pos: Vector2, target: Letter) -> bool:
	for node in get_tree().get_nodes_in_group("letters"):
		if node == null or not is_instance_valid(node) or not node is Letter:
			continue
		var letter := node as Letter
		if letter.is_resolved():
			continue
		if target != null and is_instance_valid(target) and letter == target:
			if enemy_pos.distance_to(letter.global_position) < target_exempt_distance:
				continue
		var local := letter.global_position - enemy_pos
		if absf(local.x) <= anti_pick_box_x + 20.0 and local.y >= -anti_pick_box_y_top and local.y <= anti_pick_box_y_bottom + 40.0:
			if target == null or letter != target or enemy_pos.distance_to(letter.global_position) >= target_exempt_distance:
				return true
	return false
