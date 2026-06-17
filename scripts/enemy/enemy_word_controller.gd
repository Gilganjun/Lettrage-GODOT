class_name EnemyWordController
extends Node

## Enemy word orchestration — collection audio, completion, scoring.

signal debug_state_changed

const EnemyDictionaryServiceScript := preload("res://scripts/enemy/enemy_dictionary_service.gd")
const EnemyWordStateScript := preload("res://scripts/enemy/enemy_word_state.gd")

@export var collect_sound: AudioStream
@export_range(0.0, 1.0, 0.01) var collect_volume := 0.30
@export var word_complete_delay := 2.0

var dictionary: RefCounted = EnemyDictionaryServiceScript.new()
var word_state: EnemyWordState = EnemyWordState.new()
var debug_enabled := false

var _rng := RandomNumberGenerator.new()
var _audio: AudioStreamPlayer
var _complete_timer := 0.0
var _pending_complete := false


func _ready() -> void:
	_rng.randomize()
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	if not dictionary.load_dictionary():
		push_error(dictionary.error_message)
	word_state.word_changed.connect(func(_a, _b): debug_state_changed.emit())
	word_state.score_changed.connect(func(_s): debug_state_changed.emit())
	word_state.validation_changed.connect(func(_a, _b): debug_state_changed.emit())
	word_state.word_completed.connect(_on_word_completed)
	pick_new_target_word()


func _process(delta: float) -> void:
	if not _pending_complete:
		return
	_complete_timer -= delta
	if _complete_timer <= 0.0:
		_pending_complete = false
		pick_new_target_word()


func pick_new_target_word() -> void:
	var word: String = dictionary.pick_random_word(_rng)
	word_state.set_target_word(word)
	word_state.set_validation("new_word", "Target: %s" % word)


func on_letter_collected(character: String) -> void:
	word_state.append_letter(character)
	word_state.set_validation("collected", "Collected %s" % character)
	_play_collect_sound()


func debug_clear_word() -> void:
	word_state.clear_for_next_word()
	word_state.set_validation("debug", "Enemy word cleared (debug)")


func debug_force_validation() -> void:
	if word_state.target_word.is_empty():
		return
	word_state.collected_letters = word_state.target_word
	word_state.letter_index = word_state.target_word.length()
	_on_word_completed(word_state.target_word)


func _on_word_completed(word: String) -> void:
	var delta: int = word_state.add_score_for_completed_word()
	word_state.set_validation("valid", "+%d COMPLETE: %s" % [delta, word])
	_pending_complete = true
	_complete_timer = word_complete_delay


func _play_collect_sound() -> void:
	if collect_sound == null or _audio == null:
		return
	_audio.volume_db = linear_to_db(collect_volume)
	_audio.pitch_scale = _rng.randf_range(1.0, 1.15)
	_audio.stream = collect_sound
	_audio.play()
