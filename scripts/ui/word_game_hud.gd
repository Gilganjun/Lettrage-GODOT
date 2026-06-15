extends Control

## Phase 2B1 word-game HUD — fixed to screen.

@onready var word_label: Label = $Margin/VBox/WordLabel
@onready var score_label: Label = $Margin/VBox/ScoreLabel
@onready var enemy_word_label: Label = $Margin/VBox/EnemyWordLabel
@onready var enemy_score_label: Label = $Margin/VBox/EnemyScoreLabel
@onready var shield_label: Label = $Margin/VBox/ShieldLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var controls_label: Label = $Margin/VBox/ControlsLabel
@onready var debug_label: Label = $Margin/VBox/DebugLabel
@onready var enemy_debug_label: Label = $Margin/VBox/EnemyDebugLabel

var _controller: WordGameController
var _spawner: LetterSpawner
var _enemy: Enemy
var _player_shield: PlayerShield
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
		"Shift+F2 HUD | Enter/C submit | Backspace delete | LCtrl shield | A/D move Space jump | F3/V collision debug"
	)
	refresh_combat_hud()


func refresh_combat_hud() -> void:
	if _controller:
		var ws := _controller.word_state
		word_label.text = "Player word: %s" % (ws.current_word if not ws.current_word.is_empty() else "—")
		score_label.text = "Player score: %d" % ws.score
	var player_shield_on := _player_shield != null and _player_shield.is_active
	var enemy_shield_on := false
	var enemy_word := "—"
	var enemy_target := ""
	var enemy_score := 0
	var enemy_needed := ""
	var enemy_validation := ""
	if _enemy:
		var info := _enemy.get_debug_info()
		enemy_shield_on = bool(info.get("active", false))
		enemy_word = str(info.get("enemy_word", ""))
		enemy_target = str(info.get("enemy_target_word", ""))
		enemy_score = int(info.get("enemy_score", 0))
		enemy_needed = str(info.get("enemy_needed_letter", ""))
		enemy_validation = str(info.get("enemy_validation", ""))
	enemy_word_label.text = (
		"Enemy word: %s / %s (need %s)"
		% [enemy_word if not enemy_word.is_empty() else "—", enemy_target, enemy_needed]
	)
	enemy_score_label.text = "Enemy score: %d | %s" % [enemy_score, enemy_validation]
	shield_label.text = "Player shield: %s | Enemy shield: %s" % [
		"ON" if player_shield_on else "OFF",
		"ON" if enemy_shield_on else "OFF",
	]


func set_enemy(enemy: Enemy) -> void:
	_enemy = enemy
	if _enemy and _enemy.has_method("get_word_controller"):
		var wc: Node = _enemy.get_word_controller()
		wc.word_state.word_changed.connect(func(_a, _b): refresh_combat_hud())
		wc.word_state.score_changed.connect(func(_s): refresh_combat_hud())
		wc.word_state.validation_changed.connect(func(_a, _b): refresh_combat_hud())
	refresh_combat_hud()


func set_player_shield(shield: PlayerShield) -> void:
	_player_shield = shield
	if _player_shield:
		_player_shield.shield_toggled.connect(func(_a): refresh_combat_hud())
	refresh_combat_hud()


func set_debug_visible(enabled: bool) -> void:
	_show_debug = enabled
	word_label.visible = true
	score_label.visible = enabled
	enemy_word_label.visible = enabled
	enemy_score_label.visible = enabled
	shield_label.visible = enabled
	status_label.visible = enabled
	controls_label.visible = enabled
	debug_label.visible = enabled
	enemy_debug_label.visible = enabled and _enemy != null
	_refresh()
	if enabled:
		refresh_enemy_debug()


func _refresh(_arg = null) -> void:
	if _controller == null:
		return
	refresh_combat_hud()
	if _show_debug and _spawner:
		var ws := _controller.word_state
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
		+ "Look-ahead: %s dist: %.0f early: %s height: %.0f hop: %.0f\n"
		% [
			str(info.get("ahead_obstacle", false)),
			float(info.get("distance_to_obstacle", INF)),
			str(info.get("early_approach", false)),
			float(info.get("obstacle_height", 0.0)),
			float(info.get("pending_jump_impulse", 0.0)),
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
		+ "Shield reason: %s | target: %s dist: %.0f age: %.1f\n"
		% [
			str(info.get("last_activation_reason", "")),
			str(info.get("target_letter", "")),
			float(info.get("target_distance", INF)),
			float(info.get("target_age", 0.0)),
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
