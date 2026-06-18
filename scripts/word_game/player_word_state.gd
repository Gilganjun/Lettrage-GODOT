class_name PlayerWordState
extends RefCounted

## Current player spelling and score (GDevelop SpellWord / PlayerScore / LLimit).

signal word_changed(current_word: String)
signal score_changed(score: int)
signal validation_changed(status: String, message: String)

var score: int = 0
var current_word: String = ""
var letter_limit: int = 0
var last_validation: String = "idle"
var last_collected_letter: String = ""
var free_undo_available: bool = true


func append_letter(ch: String) -> void:
	var letter := ch.to_upper()
	if letter.length() != 1 or letter[0] < "A" or letter[0] > "Z":
		return
	current_word += letter
	letter_limit += 1
	last_collected_letter = letter
	word_changed.emit(current_word)


func delete_last_letter() -> bool:
	if current_word.is_empty():
		return false
	var used_free_undo := free_undo_available
	if free_undo_available:
		free_undo_available = false
	current_word = current_word.substr(0, current_word.length() - 1)
	letter_limit = maxi(0, letter_limit - 1)
	last_collected_letter = current_word[-1] if not current_word.is_empty() else ""
	word_changed.emit(current_word)
	return used_free_undo


func clear_word() -> void:
	current_word = ""
	letter_limit = 0
	free_undo_available = true
	last_collected_letter = ""
	word_changed.emit(current_word)


func add_score_for_valid_word(word_len: int) -> int:
	# GDevelop: len/2 + len + len (integer division on first term)
	var delta := (word_len >> 1) + word_len + word_len
	score += delta
	score_changed.emit(score)
	return delta


func set_validation(status: String, message: String) -> void:
	last_validation = status
	validation_changed.emit(status, message)
