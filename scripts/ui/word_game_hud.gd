extends Control

## Phase 2B1 word-game HUD — fixed to screen.

@onready var word_label: Label = $Margin/VBox/WordLabel
@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var controls_label: Label = $Margin/VBox/ControlsLabel
@onready var debug_label: Label = $Margin/VBox/DebugLabel
@onready var enemy_debug_label: Label = $Margin/VBox/EnemyDebugLabel

var _controller: WordGameController
var _spawner: LetterSpawner
var _enemy: Enemy
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


func set_enemy(enemy: Enemy) -> void:
	_enemy = enemy


func set_debug_visible(enabled: bool) -> void:
	_show_debug = enabled
	debug_label.visible = enabled
	enemy_debug_label.visible = enabled and _enemy != null
	_refresh()
	refresh_enemy_debug()


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


func refresh_enemy_debug() -> void:
	if not _show_debug or _enemy == null:
		return
	var info: Dictionary = _enemy.get_debug_info()
	var state_names := ["IDLE", "RUN", "JUMP", "FALL", "CLIMB"]
	var state: int = int(info.get("state", 0))
	enemy_debug_label.text = (
		"Enemy pos: (%.0f, %.0f) vel: (%.0f, %.0f) state: %s anim: %s\n"
		% [info["position"].x, info["position"].y, info["velocity"].x, info["velocity"].y,
			state_names[state], info.get("animation", "?")]
		+ "dir: %s on_floor: %s ladder: %s target: %.0f patrol: %.0f-%.0f\n"
		% [
			str(info.get("direction", 0)),
			str(info.get("on_floor", false)),
			str(info.get("on_ladder", false)),
			float(info.get("target_x", 0.0)),
			float(info.get("patrol_min_x", 0.0)),
			float(info.get("patrol_max_x", 0.0)),
		]
		+ "Obstacle: %s @ %s | response: %s | jumpable: %s floor_beyond: %s\n"
		% [
			str(info.get("obstacle_detected", false)),
			str(info.get("obstacle_point", Vector2.ZERO)),
			str(info.get("selected_response", "NONE")),
			str(info.get("jumpable", false)),
			str(info.get("floor_beyond", false)),
		]
		+ "encounter: %s cd: %.2f fail_jumps: %d rev_count: %d stuck: %.2f outcome: %s\n"
		% [
			str(info.get("encounter_active", false)),
			float(info.get("decision_cooldown", 0.0)),
			int(info.get("failed_jump_count", 0)),
			int(info.get("reverse_count", 0)),
			float(info.get("stuck_timer", 0.0)),
			str(info.get("last_escape_outcome", "none")),
		]
		+ "decisions: %d jumps: %d reverses: %d fallbacks: %d max_stuck: %.2f"
		% [
			int(info.get("total_decisions", 0)),
			int(info.get("jumps_chosen", 0)),
			int(info.get("reverses_chosen", 0)),
			int(info.get("stuck_fallbacks", 0)),
			float(info.get("max_stuck_duration", 0.0)),
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
