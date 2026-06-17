class_name WordCelebrationPlayer
extends CanvasLayer

## Plays valid-word celebration tweens from HUD anchor → center → exit.

const WordCelebrationEffect := preload("res://scripts/ui/word_celebration_effect.gd")

signal celebration_started(side: String, word: String, style_name: String)
signal celebration_finished(side: String)

@export var rotate_styles := true
@export var explicit_style := -1

var _combat_hud: Control
var _last_style_index := -1
var _player_busy := false
var _enemy_busy := false

const PLAYER_COLOR := Color(0.95, 0.97, 0.2, 1.0)
const ENEMY_COLOR := Color(1.0, 0.82, 0.72, 1.0)


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
	_play_word(word, true)


func play_enemy_word(word: String) -> void:
	_play_word(word, false)


func _on_player_valid_word(word: String, _word_length: int, _score_delta: int) -> void:
	play_player_word(word)


func _on_enemy_word_completed(word: String) -> void:
	play_enemy_word(word)


func _play_word(word: String, is_player: bool) -> void:
	if word.is_empty() or _combat_hud == null:
		return
	if is_player and _player_busy:
		return
	if not is_player and _enemy_busy:
		return
	var anchor: Vector2 = _combat_hud.get_word_anchor_center(is_player)
	var exit_target: Vector2 = _combat_hud.get_word_exit_target(is_player)
	var opponent_anchor: Vector2 = _combat_hud.get_word_anchor_center(not is_player)
	var style: WordCelebrationEffect.Style = WordCelebrationEffect.pick_style(rotate_styles, _last_style_index, explicit_style)
	_last_style_index = style as int
	if is_player:
		_player_busy = true
	else:
		_enemy_busy = true
	_combat_hud.set_side_word_visible(is_player, false)
	var color := PLAYER_COLOR if is_player else ENEMY_COLOR
	var style_name: String = WordCelebrationEffect.style_name(style)
	celebration_started.emit("player" if is_player else "enemy", word, style_name)
	WordCelebrationEffect.play(
		self,
		word,
		anchor,
		_get_screen_center(),
		exit_target,
		opponent_anchor,
		color,
		style,
	)
	var timer := get_tree().create_timer(_duration_for_style(style))
	timer.timeout.connect(func(): _finish_side(is_player))


func _finish_side(is_player: bool) -> void:
	if is_player:
		_player_busy = false
	else:
		_enemy_busy = false
	if _combat_hud:
		_combat_hud.set_side_word_visible(is_player, true)
		_combat_hud.refresh_words()
	celebration_finished.emit("player" if is_player else "enemy")


func _get_screen_center() -> Vector2:
	var viewport := get_viewport().get_visible_rect()
	return viewport.position + viewport.size * 0.5


func _duration_for_style(style: WordCelebrationEffect.Style) -> float:
	match style:
		WordCelebrationEffect.Style.CENTER_SLIDE:
			return 1.35
		WordCelebrationEffect.Style.BIG_BOUNCE:
			return 1.8
		WordCelebrationEffect.Style.PUNCH_FLASH:
			return 1.2
		WordCelebrationEffect.Style.OPPONENT_SLIDE:
			return 1.2
	return 1.35
