class_name EnemyDictionaryService
extends RefCounted

## Loads EnemyDictionary.txt once for enemy target words.

const DICTIONARY_PATH := "res://dictionary/EnemyDictionary.txt"

var _words: PackedStringArray = []
var loaded: bool = false
var error_message: String = ""


func load_dictionary() -> bool:
	if loaded:
		return true
	if not FileAccess.file_exists(DICTIONARY_PATH):
		error_message = "Enemy dictionary missing: %s" % DICTIONARY_PATH
		return false
	var text := FileAccess.get_file_as_string(DICTIONARY_PATH)
	for part in text.split(","):
		var word := part.strip_edges().to_upper()
		if not word.is_empty():
			_words.append(word)
	loaded = _words.size() > 0
	return loaded


func pick_random_word(rng: RandomNumberGenerator) -> String:
	if not loaded or _words.is_empty():
		return "CAT"
	return _words[rng.randi_range(0, _words.size() - 1)]


func word_count() -> int:
	return _words.size()
