class_name DefinitionService
extends RefCounted

## Loads Definitions.txt (WORD<TAB>sense1|sense2|...) for valid-word popups.

const DEFINITIONS_PATH := "res://dictionary/Definitions.txt"
const SENSE_DELIMITER := "|"

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
		var payload := line.substr(tab + 1).strip_edges()
		if word.is_empty() or payload.is_empty():
			continue
		if _definitions.has(word):
			continue
		var senses: PackedStringArray = PackedStringArray()
		for part in payload.split(SENSE_DELIMITER):
			var sense := part.strip_edges()
			if sense.is_empty() or _should_skip_sense(sense):
				continue
			senses.append(sense)
		if not senses.is_empty():
			_definitions[word] = senses
	file.close()
	definition_count = _definitions.size()
	load_time_ms = float(Time.get_ticks_msec() - start)
	loaded = true
	return true


func get_senses(word: String) -> PackedStringArray:
	if not loaded:
		return PackedStringArray()
	var normalized := word.strip_edges().to_upper()
	if normalized.is_empty():
		return PackedStringArray()
	return _definitions.get(normalized, PackedStringArray())


func has_definition(word: String) -> bool:
	return get_senses(word).size() > 0


func _should_skip_sense(sense: String) -> bool:
	return sense.to_lower().begins_with("paper size")
