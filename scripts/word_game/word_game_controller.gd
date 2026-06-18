class_name WordGameController
extends Node

## Orchestrates collection, validation, scoring and audio for Phase 2B1.

signal debug_state_changed
signal valid_word_submitted(word: String, word_length: int, score_delta: int)
signal word_garble_purged(word: String, message: String)

@export var collect_sounds: Array[AudioStream] = []
@export var valid_word_sound: AudioStream
@export var invalid_word_sound: AudioStream
@export var delete_letter_sound: AudioStream
@export var speak_letter_enabled := true
@export_range(0.0, 1.0, 0.01) var speak_letter_volume := SpokenAlphabetService.DEFAULT_VOLUME_LINEAR
@export_range(0.0, 1.0, 0.01) var collect_sound_volume := 0.30

var dictionary := DictionaryService.new()
var word_state := PlayerWordState.new()
var spoken_alphabet := SpokenAlphabetService.new()
var debug_enabled := false

var _audio: AudioStreamPlayer
var _spoken_audio: AudioStreamPlayer
var _last_collect_ms: int = 0
var _garble_busy := false
var _pending_garble_message := ""
const COLLECT_COOLDOWN_MS := 80


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_spoken_audio = AudioStreamPlayer.new()
	add_child(_spoken_audio)
	if not dictionary.load_dictionary():
		push_error(dictionary.error_message)
	word_state.word_changed.connect(func(_w): debug_state_changed.emit())
	word_state.score_changed.connect(func(_s): debug_state_changed.emit())
	word_state.validation_changed.connect(func(_a, _b): debug_state_changed.emit())


func on_letter_collected(character: String) -> void:
	if _garble_busy:
		return
	var now := Time.get_ticks_msec()
	if now - _last_collect_ms < COLLECT_COOLDOWN_MS:
		return
	_last_collect_ms = now
	word_state.append_letter(character)
	word_state.set_validation("collected", "Collected %s — Backspace to undo" % character)
	_play_collect_sound()
	_play_spoken_letter(character)
	_maybe_trigger_garble_check()


func delete_last_letter() -> void:
	if _garble_busy:
		return
	if word_state.current_word.is_empty():
		word_state.set_validation("empty", "Nothing to delete")
		return
	var used_free_undo := word_state.delete_last_letter()
	if used_free_undo:
		word_state.set_validation("undone", "Undone last letter")
	else:
		word_state.set_validation("deleted", "Deleted last letter")
		_play_one_shot(delete_letter_sound)


func submit_word() -> void:
	if _garble_busy:
		return
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
		valid_word_submitted.emit(word, word.length(), delta)
		word_state.clear_word()
	else:
		word_state.set_validation("invalid", "INVALID: %s" % word)
		_play_one_shot(invalid_word_sound)


func debug_clear_word() -> void:
	word_state.clear_word()
	word_state.set_validation("debug", "Word cleared (debug)")


func finish_garble_purge() -> void:
	_garble_busy = false
	word_state.clear_word()
	_pending_garble_message = ""


func is_garble_busy() -> bool:
	return _garble_busy


func _maybe_trigger_garble_check() -> void:
	if word_state.current_word.length() != WordGarbleConfig.CHECK_AT_LETTER_COUNT:
		return
	if not dictionary.loaded:
		return
	var prefix := word_state.current_word.substr(0, WordGarbleConfig.REQUIRED_PREFIX_LENGTH)
	if dictionary.has_dictionary_prefix(prefix):
		return
	_garble_busy = true
	_pending_garble_message = WordGarbleConfig.random_message()
	word_garble_purged.emit(word_state.current_word, _pending_garble_message)
	_play_one_shot(invalid_word_sound)


func _play_collect_sound() -> void:
	if collect_sounds.is_empty():
		return
	var stream := collect_sounds[randi() % collect_sounds.size()]
	_play_one_shot(stream, collect_sound_volume)


func _play_one_shot(stream: AudioStream, volume_linear: float = 1.0) -> void:
	if stream == null:
		return
	_audio.volume_db = linear_to_db(volume_linear)
	_audio.stream = stream
	_audio.play()


func _play_spoken_letter(character: String) -> void:
	if not speak_letter_enabled:
		return
	var path := spoken_alphabet.get_spoken_path(character)
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Spoken letter missing: %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("Spoken letter failed to load: %s" % path)
		return
	_spoken_audio.volume_db = linear_to_db(speak_letter_volume)
	_spoken_audio.stream = stream
	_spoken_audio.play()
