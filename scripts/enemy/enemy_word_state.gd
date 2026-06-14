class_name EnemyWordState
extends RefCounted

## Enemy target word progress — independent from PlayerWordState.

signal word_changed(current_collected: String, target_word: String)
signal score_changed(score: int)
signal validation_changed(status: String, message: String)
signal word_completed(target_word: String)

var score: int = 0
var target_word: String = ""
var collected_letters: String = ""
var letter_index: int = 0
var last_collected_letter: String = ""
var last_validation: String = "idle"
var word_complete: bool = false


func set_target_word(word: String) -> void:
	target_word = word.to_upper()
	collected_letters = ""
	letter_index = 0
	word_complete = false
	last_validation = "new_word"
	word_changed.emit(collected_letters, target_word)


func current_needed_letter() -> String:
	if target_word.is_empty() or letter_index >= target_word.length():
		return ""
	return target_word[letter_index]


func append_letter(ch: String) -> void:
	var letter := ch.to_upper()
	if letter.length() != 1:
		return
	if letter != current_needed_letter():
		return
	collected_letters += letter
	letter_index += 1
	last_collected_letter = letter
	word_changed.emit(collected_letters, target_word)
	if collected_letters == target_word:
		word_complete = true
		word_completed.emit(target_word)


func add_score_for_completed_word() -> int:
	var word_len := target_word.length()
	var delta := (word_len >> 1) + word_len + word_len
	score += delta
	score_changed.emit(score)
	return delta


func clear_for_next_word() -> void:
	collected_letters = ""
	letter_index = 0
	word_complete = false
	last_collected_letter = ""


func set_validation(status: String, message: String) -> void:
	last_validation = status
	validation_changed.emit(status, message)
