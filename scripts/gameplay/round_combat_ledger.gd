class_name RoundCombatLedger
extends RefCounted

## Per-round log of words and ACTION attacks for the end-of-round victory declaration.

var _word_entries: Array[Dictionary] = []
var _attack_entries: Array[Dictionary] = []
var _pending_by_attacker: Dictionary = {}
var _word_seq := 0


func reset() -> void:
	_word_entries.clear()
	_attack_entries.clear()
	_pending_by_attacker.clear()
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
	_pending_by_attacker[attacker] = {
		"attacker": attacker,
		"attack_id": attack_id,
		"label": display_name,
		"damage": 0,
	}


func record_action_hit(attacker: String, damage: int) -> void:
	if damage <= 0:
		return
	if not _pending_by_attacker.has(attacker):
		return
	var pending: Dictionary = _pending_by_attacker[attacker]
	pending["damage"] = int(pending.get("damage", 0)) + damage


func finalize_action(attacker: String) -> void:
	if not _pending_by_attacker.has(attacker):
		return
	var pending: Dictionary = _pending_by_attacker[attacker]
	var total := int(pending.get("damage", 0))
	if total > 0:
		_attack_entries.append({
			"attacker": attacker,
			"label": str(pending.get("label", "Attack")),
			"attack_id": str(pending.get("attack_id", "")),
			"damage": total,
		})
	_pending_by_attacker.erase(attacker)


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
