class_name WordGarblePlayer
extends CanvasLayer

## Plays the gibberish purge animation when the 20-letter dictionary check fails.

var _combat_hud: Control
var _word_controller: WordGameController
var _busy := false


func _ready() -> void:
	layer = 21


func setup(combat_hud: Control, word_controller: WordGameController) -> void:
	_combat_hud = combat_hud
	_word_controller = word_controller
	if _word_controller and not _word_controller.word_garble_purged.is_connected(_on_word_garble_purged):
		_word_controller.word_garble_purged.connect(_on_word_garble_purged)


func _on_word_garble_purged(word: String, message: String) -> void:
	if _busy or word.is_empty() or _combat_hud == null:
		return
	_busy = true
	var positions: PackedVector2Array = []
	if _combat_hud.has_method("get_player_word_letter_positions"):
		positions = _combat_hud.get_player_word_letter_positions(word)
	if positions.is_empty() and _combat_hud.has_method("get_word_anchor_center"):
		var center: Vector2 = _combat_hud.get_word_anchor_center(true)
		for _i in word.length():
			positions.append(center)
	var message_anchor := Vector2(10.0, 72.0)
	if _combat_hud.has_method("get_garble_message_anchor"):
		message_anchor = _combat_hud.get_garble_message_anchor()
	_combat_hud.set_side_word_visible(true, false)
	WordGarblePurgeEffect.play(self, word, positions, message, message_anchor, _finish_purge)


func _finish_purge() -> void:
	_busy = false
	if _word_controller:
		_word_controller.finish_garble_purge()
	if _combat_hud:
		_combat_hud.set_side_word_visible(true, true)
		_combat_hud.refresh_words()
