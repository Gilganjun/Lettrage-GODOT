class_name LetterBackdropRegistry
extends RefCounted

## Letter readability circle backdrops — cycle with key 9 in phase2c1 test scene.

const ENTRIES := [
	{
		"id": "bg1",
		"path": "res://assets/Letter_Circle_BG1.png",
		"name": "Circle BG1",
	},
	{
		"id": "bg2",
		"path": "res://assets/Letter_Circle_BG2.png",
		"name": "Circle BG2",
	},
	{
		"id": "bg3",
		"path": "res://assets/Letter_Circle_BG3.png",
		"name": "Circle BG3",
	},
	{
		"id": "bg4",
		"path": "res://assets/Letter_Crcle_BG4.png",
		"name": "Circle BG4",
	},
]

var _index := 0


static func create() -> LetterBackdropRegistry:
	return LetterBackdropRegistry.new()


func get_current_path() -> String:
	return str(ENTRIES[_index].get("path", ""))


func get_current_name() -> String:
	return str(ENTRIES[_index].get("name", "Unknown"))


func cycle_next() -> String:
	if ENTRIES.is_empty():
		return ""
	_index = (_index + 1) % ENTRIES.size()
	return get_current_name()


func apply_to_letters() -> void:
	Letter.set_readability_backdrop_path(get_current_path())
