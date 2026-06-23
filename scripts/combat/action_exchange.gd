class_name ActionExchange
extends RefCounted

## Per-ACTION-sequence context: first-hit tracking and defender block state.

signal defender_block_activated(defender: String)
signal strike_blocked(defender: String, hit_index: int)

var attacker: String = ""
var defender: String = ""
var first_hit_landed := false
var defender_block_active := false
var _sequence_id: int = 0

static var _next_sequence_id := 1


func _init(attacker_side: String, defender_side: String) -> void:
	attacker = attacker_side
	defender = defender_side
	_sequence_id = _next_sequence_id
	_next_sequence_id += 1


func get_sequence_id() -> int:
	return _sequence_id


func can_offer_block() -> bool:
	return first_hit_landed and not defender_block_active


func try_activate_defender_block() -> bool:
	if not can_offer_block():
		return false
	defender_block_active = true
	defender_block_activated.emit(defender)
	return true


func notify_hit_landed(hit_idx: int) -> void:
	if hit_idx == 0:
		first_hit_landed = true


func is_hit_blocked(hit_idx: int) -> bool:
	return defender_block_active and hit_idx > 0


func notify_hit_blocked(hit_idx: int) -> void:
	strike_blocked.emit(defender, hit_idx)
