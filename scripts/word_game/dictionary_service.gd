class_name DictionaryService
extends RefCounted

## Loads EnglishWords4.txt once for newline-wrapped word lookup (GDevelop StrFind style).

const DICTIONARY_PATH := "res://dictionary/EnglishWords4.txt"

var _words: Dictionary = {}
var word_count: int = 0
var load_time_ms: float = 0.0
var loaded: bool = false
var error_message: String = ""


func load_dictionary() -> bool:
	if loaded:
		return true
	var start := Time.get_ticks_msec()
	if not FileAccess.file_exists(DICTIONARY_PATH):
		error_message = "Dictionary missing: %s" % DICTIONARY_PATH
		return false
	var file := FileAccess.open(DICTIONARY_PATH, FileAccess.READ)
	if file == null:
		error_message = "Failed to open dictionary: %s" % DICTIONARY_PATH
		return false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		_words[line.to_upper()] = true
	file.close()
	word_count = _words.size()
	load_time_ms = float(Time.get_ticks_msec() - start)
	loaded = true
	return true


func contains_word(word: String) -> bool:
	if not loaded:
		return false
	var normalized := word.strip_edges().to_upper()
	if normalized.is_empty():
		return false
	return _words.has(normalized)
