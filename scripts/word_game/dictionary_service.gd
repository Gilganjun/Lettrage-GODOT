class_name DictionaryService
extends RefCounted

## Loads EnglishWords5.txt once for newline-wrapped word lookup (GDevelop StrFind style).
## Built from EnglishWords4.txt minus dictionary/OmissionList.txt, plus Oxford additions.

const DICTIONARY_PATH := "res://dictionary/EnglishWords5.txt"

var _words: Dictionary = {}
var _prefixes: Dictionary = {}
var _word_list: PackedStringArray = PackedStringArray()
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
		var word := line.to_upper()
		_words[word] = true
		_word_list.append(word)
		for i in range(1, word.length() + 1):
			_prefixes[word.substr(0, i)] = true
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


## True when some dictionary word starts with `prefix` (used at 20-letter garble check).
func has_dictionary_prefix(prefix: String) -> bool:
	if not loaded:
		return false
	var normalized := prefix.strip_edges().to_upper()
	if normalized.is_empty():
		return false
	return _prefixes.has(normalized)


func pick_random_word(rng: RandomNumberGenerator) -> String:
	if not loaded or _word_list.is_empty():
		return ""
	return _word_list[rng.randi_range(0, _word_list.size() - 1)]
