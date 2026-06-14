class_name PlayerWordState
extends RefCounted

## Current player spelling and score (GDevelop SpellWord / PlayerScore / LLimit).

signal word_changed(current_word: String)
signal score_changed(score: int)
signal validation_changed(status: String, message: String)

const MAX_WORD_LETTERS := 20

var score: int = 0
var current_word: String = ""
var letter_limit: int = 0
var last_validation: String = "idle"
var last_collected_letter: String = ""


func append_letter(ch: String) -> void:
	var letter := ch.to_upper()
	if letter.length() != 1 or letter[0] < "A" or letter[0] > "Z":
		return
	current_word += letter
	letter_limit += 1
	last_collected_letter = letter
	if letter_limit >= MAX_WORD_LETTERS:
		clear_word()
		return
	word_changed.emit(current_word)


func delete_last_letter() -> bool:
	if current_word.is_empty():
		return false
	current_word = current_word.substr(0, current_word.length() - 1)
	word_changed.emit(current_word)
	return true


func clear_word() -> void:
	current_word = ""
	letter_limit = 0
	word_changed.emit(current_word)


func add_score_for_valid_word(word_len: int) -> int:
	# GDevelop: len/2 + len + len (integer division on first term)
	var delta := int(word_len / 2) + word_len + word_len
	score += delta
	score_changed.emit(score)
	return delta


func set_validation(status: String, message: String) -> void:
	last_validation = status
	validation_changed.emit(status, message)
