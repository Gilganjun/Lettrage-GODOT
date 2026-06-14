class_name WordGameController
extends Node

## Orchestrates collection, validation, scoring and audio for Phase 2B1.

signal debug_state_changed

@export var collect_sounds: Array[AudioStream] = []
@export var valid_word_sound: AudioStream
@export var invalid_word_sound: AudioStream
@export var delete_letter_sound: AudioStream

var dictionary := DictionaryService.new()
var word_state := PlayerWordState.new()
var debug_enabled := false

var _audio: AudioStreamPlayer
var _last_collect_ms: int = 0
const COLLECT_COOLDOWN_MS := 80


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	if not dictionary.load_dictionary():
		push_error(dictionary.error_message)
	word_state.word_changed.connect(func(_w): debug_state_changed.emit())
	word_state.score_changed.connect(func(_s): debug_state_changed.emit())
	word_state.validation_changed.connect(func(_a, _b): debug_state_changed.emit())


func on_letter_collected(character: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_collect_ms < COLLECT_COOLDOWN_MS:
		return
	_last_collect_ms = now
	word_state.append_letter(character)
	word_state.set_validation("collected", "Collected %s" % character)
	_play_collect_sound()


func delete_last_letter() -> void:
	if word_state.delete_last_letter():
		word_state.set_validation("deleted", "Deleted last letter")
		_play_one_shot(delete_letter_sound)


func submit_word() -> void:
	var word := word_state.current_word.strip_edges().to_upper()
	if word.is_empty():
		word_state.set_validation("empty", "Nothing to submit")
		return
	if not dictionary.loaded:
		word_state.set_validation("error", "Dictionary not loaded")
		return
	if dictionary.contains_word(word):
		var delta := word_state.add_score_for_valid_word(word.length())
		word_state.set_validation("valid", "+%d  VALID: %s" % [delta, word])
		_play_one_shot(valid_word_sound)
		word_state.clear_word()
	else:
		word_state.set_validation("invalid", "INVALID: %s" % word)
		_play_one_shot(invalid_word_sound)


func debug_clear_word() -> void:
	word_state.clear_word()
	word_state.set_validation("debug", "Word cleared (debug)")


func _play_collect_sound() -> void:
	if collect_sounds.is_empty():
		return
	var stream := collect_sounds[randi() % collect_sounds.size()]
	_play_one_shot(stream)


func _play_one_shot(stream: AudioStream) -> void:
	if stream == null:
		return
	_audio.stream = stream
	_audio.play()
