class_name WordCelebrationPlayer
extends CanvasLayer

## Queued valid-word celebrations: HUD anchor → center hold → random exit.

const WordCelebrationEffect := preload("res://scripts/ui/word_celebration_effect.gd")

signal celebration_started(side: String, word: String, style_name: String)
signal celebration_finished(side: String)

@export var vary_accent := true
@export_range(-1, 2, 1) var explicit_accent := -1

var _combat_hud: Control
var _player_last_accent_index := -1
var _enemy_last_accent_index := -1
var _player_queue: Array[Dictionary] = []
var _enemy_queue: Array[Dictionary] = []
var _player_active := false
var _enemy_active := false

const PLAYER_COLOR := Color(0.95, 0.97, 0.2, 1.0)
const ENEMY_COLOR := Color(1.0, 0.82, 0.72, 1.0)
const MAX_QUEUE_SIZE := 4


func _ready() -> void:
	layer = 20


func setup(combat_hud: Control) -> void:
	_combat_hud = combat_hud


func bind_player_words(word_controller: WordGameController) -> void:
	if word_controller == null:
		return
	if not word_controller.valid_word_submitted.is_connected(_on_player_valid_word):
		word_controller.valid_word_submitted.connect(_on_player_valid_word)


func bind_enemy_words(enemy: Enemy) -> void:
	if enemy == null or not enemy.has_method("get_word_controller"):
		return
	var wc: Node = enemy.get_word_controller()
	if wc and wc.word_state:
		if not wc.word_state.word_completed.is_connected(_on_enemy_word_completed):
			wc.word_state.word_completed.connect(_on_enemy_word_completed)


func play_player_word(word: String) -> void:
	_enqueue_word(word, true)


func play_enemy_word(word: String) -> void:
	_enqueue_word(word, false)


func is_side_playing(is_player: bool) -> bool:
	return _player_active if is_player else _enemy_active


func _on_player_valid_word(word: String, _word_length: int, _score_delta: int) -> void:
	_enqueue_word(word, true)


func _on_enemy_word_completed(word: String) -> void:
	_enqueue_word(word, false)


func _enqueue_word(word: String, is_player: bool) -> void:
	if word.is_empty() or _combat_hud == null:
		return
	var queue := _player_queue if is_player else _enemy_queue
	if queue.size() >= MAX_QUEUE_SIZE:
		queue.pop_front()
	queue.append({
		"word": word,
		"anchor": _combat_hud.get_word_celebration_anchor(is_player, word),
	})
	_pump_queue(is_player)


func _pump_queue(is_player: bool) -> void:
	if is_player and _player_active:
		return
	if not is_player and _enemy_active:
		return
	var queue := _player_queue if is_player else _enemy_queue
	if queue.is_empty():
		return
	var item: Dictionary = queue.pop_front()
	_start_celebration(str(item.get("word", "")), item.get("anchor", _get_screen_center()), is_player)


func _start_celebration(word: String, anchor: Vector2, is_player: bool) -> void:
	if word.is_empty():
		_pump_queue(is_player)
		return
	if is_player:
		_player_active = true
	else:
		_enemy_active = true
	_combat_hud.set_side_word_visible(is_player, false)
	var accent := _pick_accent(is_player)
	var accent_name: String = WordCelebrationEffect.accent_name(accent)
	celebration_started.emit("player" if is_player else "enemy", word, accent_name)
	WordCelebrationEffect.play(
		self,
		word,
		anchor,
		_get_screen_center(),
		PLAYER_COLOR if is_player else ENEMY_COLOR,
		accent,
		func() -> void:
			_on_celebration_complete(is_player),
	)


func _on_celebration_complete(is_player: bool) -> void:
	celebration_finished.emit("player" if is_player else "enemy")
	var queue := _player_queue if is_player else _enemy_queue
	if not queue.is_empty():
		_pump_queue(is_player)
		return
	if is_player:
		_player_active = false
	else:
		_enemy_active = false
	if _combat_hud:
		_combat_hud.set_side_word_visible(is_player, true)
		_combat_hud.refresh_words()


func _pick_accent(is_player: bool) -> WordCelebrationEffect.Accent:
	if explicit_accent >= 0 and explicit_accent < WordCelebrationEffect.accent_count():
		return explicit_accent as WordCelebrationEffect.Accent
	if not vary_accent:
		return WordCelebrationEffect.Accent.GLIDE
	var last_index := _player_last_accent_index if is_player else _enemy_last_accent_index
	var accent := WordCelebrationEffect.pick_accent(last_index)
	if is_player:
		_player_last_accent_index = accent as int
	else:
		_enemy_last_accent_index = accent as int
	return accent


func _get_screen_center() -> Vector2:
	var viewport := get_viewport().get_visible_rect()
	return viewport.position + viewport.size * 0.5
