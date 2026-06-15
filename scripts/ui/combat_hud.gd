extends Control

## Player + Enemy health bars and optional combat debug readout.

@onready var player_bar: Control = $Margin/Row/PlayerHealthBar
@onready var enemy_bar: Control = $Margin/Row/EnemyHealthBar
@onready var debug_label: Label = $Margin/CombatDebugLabel

var _player_combat: Node
var _enemy_combat: Node
var _damage_bridge: Node


func setup(
	player_combat: Node,
	enemy_combat: Node,
	damage_bridge: Node = null,
) -> void:
	_player_combat = player_combat
	_enemy_combat = enemy_combat
	_damage_bridge = damage_bridge
	if player_bar.has_method("setup") and player_combat:
		player_bar.setup("Player HP", player_combat.health, Color(0.35, 0.92, 0.55, 1.0))
	if enemy_bar.has_method("setup") and enemy_combat:
		enemy_bar.setup("Enemy HP", enemy_combat.health, Color(1.0, 0.55, 0.32, 1.0))
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
