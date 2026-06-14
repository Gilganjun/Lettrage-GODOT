class_name SpokenAlphabetService
extends RefCounted

## Maps collected letters to spoken WAV clips (GDevelop group #13 Speak* vars).

const AUDIO_DIR := "res://assets/AlphabetSpoken/"
const VOICE_PACKS := "ABC"
const DEFAULT_VOLUME_LINEAR := 0.70

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func get_spoken_path(letter: String) -> String:
	var ch := letter.strip_edges().to_upper()
	if ch.length() != 1:
		return ""
	var code := ch.unicode_at(0)
	if code < "A".unicode_at(0) or code > "Z".unicode_at(0):
		return ""
	var index := code - "A".unicode_at(0)
	var pack := VOICE_PACKS[_rng.randi_range(0, 2)]
	return AUDIO_DIR + "Alp%s%03d.wav" % [pack, index]


func path_for_letter(letter: String, voice_index: int) -> String:
	var ch := letter.strip_edges().to_upper()
	if ch.length() != 1:
		return ""
	var code := ch.unicode_at(0)
	if code < "A".unicode_at(0) or code > "Z".unicode_at(0):
		return ""
	var letter_index := code - "A".unicode_at(0)
	var pack_index := clampi(voice_index, 0, 2)
	return AUDIO_DIR + "Alp%s%03d.wav" % [VOICE_PACKS[pack_index], letter_index]
