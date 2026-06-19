class_name FontSetRegistry
extends RefCounted

## Discovers letter font sets (original + assets/fonts/*) and applies them to AlphabetCatalog.

const ORIGINAL_ID := "original"
const ORIGINAL_DIR := "res://images/Alphabet/"
const FONTS_ROOT := "res://assets/fonts/"


class FontSet:
	var id: String = ""
	var display_name: String = ""
	var texture_dir: String = ""
	var legacy_naming: bool = false
	var export_files: Dictionary = {}
	var use_tint_shader: bool = true


var _sets: Array[FontSet] = []
var _index: int = 0


static func create() -> FontSetRegistry:
	var registry := FontSetRegistry.new()
	registry.discover()
	return registry


func discover() -> void:
	_sets.clear()
	_add_original()
	var dir := DirAccess.open(FONTS_ROOT)
	if dir == null:
		_index = 0
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("."):
			_try_add_font_folder(folder)
		folder = dir.get_next()
	dir.list_dir_end()
	_index = 0


func get_set_count() -> int:
	return _sets.size()


func get_current_name() -> String:
	if _sets.is_empty():
		return "Unknown"
	return _sets[_index].display_name


func get_current_id() -> String:
	if _sets.is_empty():
		return ""
	return _sets[_index].id


func cycle_next() -> String:
	if _sets.is_empty():
		return ""
	_index = (_index + 1) % _sets.size()
	return get_current_name()


func apply_to_catalog(catalog: AlphabetCatalog) -> void:
	if catalog == null or _sets.is_empty():
		return
	var font_set := _sets[_index]
	catalog.apply_font_set(
		font_set.texture_dir,
		font_set.legacy_naming,
		font_set.export_files,
		font_set.id,
		font_set.use_tint_shader,
	)


func _add_original() -> void:
	var font_set := FontSet.new()
	font_set.id = ORIGINAL_ID
	font_set.display_name = "Original"
	font_set.texture_dir = ORIGINAL_DIR
	font_set.legacy_naming = true
	_sets.append(font_set)


func _try_add_font_folder(folder_name: String) -> void:
	var base := FONTS_ROOT + folder_name + "/"
	var meta_path := base + "metadata.json"
	if not FileAccess.file_exists(meta_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.get("type", "") != "lettrage_font_set":
		return
	var font_set_name := str(data.get("font_set_name", folder_name))
	var font_set := FontSet.new()
	font_set.id = folder_name
	font_set.display_name = font_set_name
	font_set.texture_dir = base
	font_set.legacy_naming = false
	var letters: Dictionary = data.get("letters", {})
	for letter in AlphabetCatalog.all_letters_static():
		var entry: Dictionary = letters.get(letter, {})
		var export_file := str(entry.get("export_file", ""))
		if export_file.is_empty():
			export_file = "%s_%s.png" % [font_set_name, letter]
		font_set.export_files[letter] = export_file
	_sets.append(font_set)
	_add_raw_variant(font_set, font_set_name)


func _add_raw_variant(source: FontSet, font_set_name: String) -> void:
	var raw := FontSet.new()
	raw.id = source.id + "_raw"
	raw.display_name = "%s Original" % font_set_name
	raw.texture_dir = source.texture_dir
	raw.legacy_naming = source.legacy_naming
	raw.export_files = source.export_files.duplicate()
	raw.use_tint_shader = false
	_sets.append(raw)
