class_name DefinitionService
extends RefCounted

## Loads Definitions.txt (WORD<TAB>short definition) for valid-word popups.

const DEFINITIONS_PATH := "res://dictionary/Definitions.txt"

var _definitions: Dictionary = {}
var definition_count: int = 0
var load_time_ms: float = 0.0
var loaded: bool = false
var error_message: String = ""


func load_definitions() -> bool:
	if loaded:
		return true
	var start := Time.get_ticks_msec()
	if not FileAccess.file_exists(DEFINITIONS_PATH):
		error_message = "Definitions missing: %s" % DEFINITIONS_PATH
		return false
	var file := FileAccess.open(DEFINITIONS_PATH, FileAccess.READ)
	if file == null:
		error_message = "Failed to open definitions: %s" % DEFINITIONS_PATH
		return false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var tab := line.find("\t")
		if tab < 1:
			continue
		var word := line.substr(0, tab).strip_edges().to_upper()
		var definition := line.substr(tab + 1).strip_edges()
		if word.is_empty() or definition.is_empty():
			continue
		if not _definitions.has(word):
			_definitions[word] = definition
	file.close()
	definition_count = _definitions.size()
	load_time_ms = float(Time.get_ticks_msec() - start)
	loaded = true
	return true


func get_definition(word: String) -> String:
	if not loaded:
		return ""
	var normalized := word.strip_edges().to_upper()
	if normalized.is_empty():
		return ""
	return str(_definitions.get(normalized, ""))


func has_definition(word: String) -> bool:
	return not get_definition(word).is_empty()
