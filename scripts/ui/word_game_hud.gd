extends Control

## Phase 2B1 word-game HUD — fixed to screen.

@onready var word_label: Label = $Margin/VBox/WordLabel
@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var controls_label: Label = $Margin/VBox/ControlsLabel
@onready var debug_label: Label = $Margin/VBox/DebugLabel

var _controller: WordGameController
var _spawner: LetterSpawner
var _show_debug := false


func setup(controller: WordGameController, spawner: LetterSpawner) -> void:
	_controller = controller
	_spawner = spawner
	if _controller:
		_controller.word_state.word_changed.connect(_refresh)
		_controller.word_state.score_changed.connect(_refresh)
		_controller.word_state.validation_changed.connect(_on_validation)
		_controller.debug_state_changed.connect(_refresh)
	_refresh()
	controls_label.text = (
		"Enter/C submit | Backspace delete | A/D move Space jump | F3/V collision debug"
	)


func set_debug_visible(enabled: bool) -> void:
	_show_debug = enabled
	debug_label.visible = enabled
	_refresh()


func _refresh(_arg = null) -> void:
	if _controller == null:
		return
	var ws := _controller.word_state
	word_label.text = "Word: %s" % (ws.current_word if not ws.current_word.is_empty() else "—")
	score_label.text = "Score: %d" % ws.score
	if _show_debug and _spawner:
		debug_label.text = (
			"Dict: %s (%d words, %.1fms) | Active: %d | Spawn in: %.2fs | Last: %s\n"
			+ "Spawned %d | Collected %d | Boundary del %d | Last val: %s"
			% [
				str(_controller.dictionary.loaded),
				_controller.dictionary.word_count,
				_controller.dictionary.load_time_ms,
				_spawner.get_active_count(),
				_spawner.get_spawn_timer_remaining(),
				_spawner.last_spawned_letter,
				_spawner.total_spawned,
				_spawner.total_collected,
				_spawner.total_deleted_boundary,
				ws.last_validation,
			]
		)


func _on_validation(status: String, message: String) -> void:
	match status:
		"valid":
			status_label.modulate = Color(0.4, 1.0, 0.5)
		"invalid":
			status_label.modulate = Color(1.0, 0.45, 0.4)
		"collected", "deleted":
			status_label.modulate = Color(0.85, 0.9, 1.0)
		_:
			status_label.modulate = Color(1, 1, 1)
	status_label.text = message
	_refresh()
