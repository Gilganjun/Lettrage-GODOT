class_name RoundCombatLedger
extends RefCounted

## Per-round log of words and ACTION attacks for the end-of-round victory declaration.

var _word_entries: Array[Dictionary] = []
var _attack_entries: Array[Dictionary] = []
var _pending_action: Dictionary = {}
var _word_seq := 0


func reset() -> void:
	_word_entries.clear()
	_attack_entries.clear()
	_pending_action.clear()
	_word_seq = 0


func record_word(attacker: String, word: String, damage: int) -> void:
	if damage <= 0 or word.is_empty():
		return
	_word_entries.append({
		"attacker": attacker,
		"word": word.to_upper(),
		"damage": damage,
		"order": _word_seq,
	})
	_word_seq += 1


func begin_action(attacker: String, attack_id: String, display_name: String) -> void:
	finalize_action(attacker)
	_pending_action = {
		"attacker": attacker,
		"attack_id": attack_id,
		"label": display_name,
		"damage": 0,
	}


func record_action_hit(attacker: String, damage: int) -> void:
	if damage <= 0:
		return
	if _pending_action.is_empty() or _pending_action.get("attacker", "") != attacker:
		return
	_pending_action["damage"] = int(_pending_action.get("damage", 0)) + damage


func finalize_action(attacker: String) -> void:
	if _pending_action.is_empty():
		return
	if _pending_action.get("attacker", "") != attacker:
		return
	var total := int(_pending_action.get("damage", 0))
	if total > 0:
		_attack_entries.append({
			"attacker": attacker,
			"label": str(_pending_action.get("label", "Attack")),
			"attack_id": str(_pending_action.get("attack_id", "")),
			"damage": total,
		})
	_pending_action.clear()


func build_report_for(attacker: String) -> Dictionary:
	finalize_action(attacker)
	var words: Array[Dictionary] = []
	var attacks: Array[Dictionary] = []
	var total := 0
	for entry in _word_entries:
		if entry.get("attacker", "") != attacker:
			continue
		words.append(entry)
		total += int(entry.get("damage", 0))
	for entry in _attack_entries:
		if entry.get("attacker", "") != attacker:
			continue
		attacks.append(entry)
		total += int(entry.get("damage", 0))
	return {
		"words": words,
		"attacks": attacks,
		"total_damage": total,
	}


func has_entries_for(attacker: String) -> bool:
	var report := build_report_for(attacker)
	return not report.get("words", []).is_empty() or not report.get("attacks", []).is_empty()
