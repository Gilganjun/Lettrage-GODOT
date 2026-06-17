extends Control

## Player + Enemy health bars, spell text under each bar, optional combat debug.

@onready var player_bar: Control = $TopRow/PlayerColumn/PlayerHealthBar
@onready var enemy_bar: Control = $TopRow/EnemyColumn/EnemyHealthBar
@onready var player_word_label: Label = $TopRow/PlayerColumn/PlayerWordLabel
@onready var enemy_word_label: Label = $TopRow/EnemyColumn/EnemyWordLabel
@onready var debug_label: Label = $CombatDebugLabel

const WORD_OUTLINE_SIZE := 3
const WORD_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)

var _player_combat: Node
var _enemy_combat: Node
var _damage_bridge: Node
var _word_controller: WordGameController
var _enemy: Enemy


func _ready() -> void:
	_apply_word_label_outline(player_word_label)
	_apply_word_label_outline(enemy_word_label)


func _apply_word_label_outline(label: Label) -> void:
	if label == null:
		return
	label.add_theme_constant_override("outline_size", WORD_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", WORD_OUTLINE_COLOR)


func setup(
	player_combat: Node,
	enemy_combat: Node,
	damage_bridge: Node = null,
) -> void:
	_player_combat = player_combat
	_enemy_combat = enemy_combat
	_damage_bridge = damage_bridge
	if player_bar.has_method("setup") and player_combat:
		player_bar.setup(
			"Player HP",
			player_combat.health,
			Color(0.35, 0.92, 0.55, 1.0),
			Color(0.12, 0.42, 0.22, 1.0),
		)
	if enemy_bar.has_method("setup") and enemy_combat:
		enemy_bar.setup(
			"Enemy HP",
			enemy_combat.health,
			Color(1.0, 0.55, 0.32, 1.0),
			Color(0.55, 0.18, 0.08, 1.0),
		)
	if player_combat:
		player_combat.health.health_changed.connect(func(_a, _b): refresh_debug())
		player_combat.health.damaged.connect(func(_a, _b): refresh_debug())
		player_combat.injury.injury_started.connect(func(_d): refresh_debug())
		player_combat.injury.injury_ended.connect(refresh_debug)
		player_combat.health.died.connect(func(_s): refresh_debug())
		player_combat.respawn_completed.connect(refresh_debug)
	if enemy_combat:
		enemy_combat.health.health_changed.connect(func(_a, _b): refresh_debug())
		enemy_combat.health.damaged.connect(func(_a, _b): refresh_debug())
		enemy_combat.injury.injury_started.connect(func(_d): refresh_debug())
		enemy_combat.injury.injury_ended.connect(refresh_debug)
		enemy_combat.health.died.connect(func(_s): refresh_debug())
		enemy_combat.respawn_completed.connect(refresh_debug)
	if damage_bridge:
		damage_bridge.word_damage_applied.connect(func(_e): refresh_debug())
	refresh_debug()


func bind_words(word_controller: WordGameController, enemy: Enemy) -> void:
	_word_controller = word_controller
	_enemy = enemy
	if _word_controller:
		_word_controller.word_state.word_changed.connect(func(_w): refresh_words())
		_word_controller.word_state.score_changed.connect(func(_s): refresh_words())
		_word_controller.word_state.validation_changed.connect(func(_a, _b): refresh_words())
	if _enemy and _enemy.has_method("get_word_controller"):
		var wc: Node = _enemy.get_word_controller()
		wc.word_state.word_changed.connect(func(_a, _b): refresh_words())
		wc.word_state.score_changed.connect(func(_s): refresh_words())
		wc.word_state.validation_changed.connect(func(_a, _b): refresh_words())
	refresh_words()


func refresh_words() -> void:
	if _player_word_hidden:
		player_word_label.text = ""
	elif _word_controller:
		player_word_label.text = _word_controller.word_state.current_word
	if _enemy_word_hidden:
		enemy_word_label.text = ""
	elif _enemy:
		var info := _enemy.get_debug_info()
		enemy_word_label.text = str(info.get("enemy_word", ""))
	else:
		enemy_word_label.text = ""


var _player_word_hidden := false
var _enemy_word_hidden := false


func get_word_anchor_center(for_player: bool) -> Vector2:
	var label := player_word_label if for_player else enemy_word_label
	if label == null:
		return Vector2(80.0, 56.0) if for_player else Vector2(880.0, 56.0)
	return label.get_global_rect().get_center()


func get_word_exit_target(for_player: bool) -> Vector2:
	var viewport := get_viewport().get_visible_rect()
	var margin := 48.0
	if for_player:
		return Vector2(viewport.end.x + margin, viewport.position.y + viewport.size.y * 0.35)
	return Vector2(viewport.position.x - margin, viewport.position.y + viewport.size.y * 0.35)


func set_side_word_visible(for_player: bool, visible: bool) -> void:
	if for_player:
		_player_word_hidden = not visible
		player_word_label.visible = visible
	else:
		_enemy_word_hidden = not visible
		enemy_word_label.visible = visible
	if visible:
		refresh_words()


func set_debug_visible(enabled: bool) -> void:
	debug_label.visible = enabled
	if player_bar.has_method("set_debug_numeric_visible"):
		player_bar.set_debug_numeric_visible(enabled)
	if enemy_bar.has_method("set_debug_numeric_visible"):
		enemy_bar.set_debug_numeric_visible(enabled)
	refresh_debug()


func refresh_debug() -> void:
	if not debug_label.visible:
		return
	var lines: PackedStringArray = []
	if _player_combat:
		lines.append(
			"Player HP %d/%d | injured %s | dead %s"
			% [
				_player_combat.health.current_health,
				_player_combat.health.max_health,
				str(_player_combat.injury.is_injured),
				str(_player_combat.health.is_dead),
			]
		)
		if _player_combat.injury.is_injured:
			lines.append("  injury timer %.2fs" % _player_combat.injury.time_remaining)
	if _enemy_combat:
		lines.append(
			"Enemy HP %d/%d | injured %s | dead %s"
			% [
				_enemy_combat.health.current_health,
				_enemy_combat.health.max_health,
				str(_enemy_combat.injury.is_injured),
				str(_enemy_combat.health.is_dead),
			]
		)
		if _enemy_combat.injury.is_injured:
			lines.append("  injury timer %.2fs" % _enemy_combat.injury.time_remaining)
	if _damage_bridge and not _damage_bridge.last_damage_event.is_empty():
		var e: Dictionary = _damage_bridge.last_damage_event
		lines.append(
			"Last dmg: %s -> %s word=%s len=%s dmg=%s"
			% [e.get("attacker", "?"), e.get("defender", "?"), e.get("word", ""), e.get("word_length", 0), e.get("damage", 0)]
		)
	debug_label.text = "\n".join(lines)
