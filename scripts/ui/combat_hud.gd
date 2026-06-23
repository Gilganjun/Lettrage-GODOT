extends Control

## Player + Enemy health bars, spell text under each bar, optional combat debug.

const WORD_FONT_SIZE := 28
const WORD_PANEL_PAD_X := 22.0
const WORD_PANEL_PAD_Y := 12.0
const WORD_COLLECT_POP_SCALE := 1.22
const WORD_COLLECT_POP_RISE_SEC := 0.14
const WORD_COLLECT_POP_FALL_SEC := 0.55
const WORD_COLLECT_SHAKE_ROT := 0.065

@onready var player_bar: Control = $TopRow/PlayerSide/PlayerHealthPanel/PlayerHealthBar
@onready var enemy_bar: Control = $TopRow/EnemySide/EnemyHealthPanel/EnemyHealthBar
@onready var player_word_panel: PanelContainer = $TopRow/PlayerSide/PlayerWordPanel
@onready var enemy_word_panel: PanelContainer = $TopRow/EnemySide/EnemyWordPanel
@onready var player_word_label: Label = $TopRow/PlayerSide/PlayerWordPanel/PlayerWordLabel
@onready var enemy_word_label: Label = $TopRow/EnemySide/EnemyWordPanel/EnemyWordLabel
@onready var player_ammo_label: Label = $PlayerAmmoLabel
@onready var action_charge_icon: Label = $ActionChargeIcon
@onready var enemy_action_charge_icon: Label = $TopRow/EnemySide/EnemyActionChargeIcon
@onready var status_label: Label = $StatusLabel
@onready var debug_label: Label = $CombatDebugLabel
@onready var _damage_number_layer: Control = $DamageNumberLayer

var _player_combat: Node
var _enemy_combat: Node
var _damage_bridge: Node
var _word_controller: WordGameController
var _enemy: Enemy
var _framed_word_ui := false
var _shooter: LetterShooter
var _action_controller: Node
var _enemy_action_controller: Node
var _player_damage_slot := 0
var _enemy_damage_slot := 0
var _last_player_word_len := 0
var _player_word_pop_tween: Tween


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
		player_combat.health.damaged.connect(_on_player_damaged)
		player_combat.injury.injury_started.connect(func(_d): refresh_debug())
		player_combat.injury.injury_ended.connect(refresh_debug)
		player_combat.health.died.connect(func(_s): refresh_debug())
		player_combat.respawn_completed.connect(refresh_debug)
	if enemy_combat:
		enemy_combat.health.health_changed.connect(func(_a, _b): refresh_debug())
		enemy_combat.health.damaged.connect(func(_a, _b): refresh_debug())
		enemy_combat.health.damaged.connect(_on_enemy_damaged)
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
		_word_controller.word_state.validation_changed.connect(func(a, b): _on_validation(a, b))
		_word_controller.valid_word_submitted.connect(func(_w, _l, _d): refresh_words())
	if _enemy and _enemy.has_method("get_word_controller"):
		var wc: Node = _enemy.get_word_controller()
		wc.word_state.word_changed.connect(func(_a, _b): refresh_words())
		wc.word_state.score_changed.connect(func(_s): refresh_words())
		wc.word_state.validation_changed.connect(func(_a, _b): refresh_words())
	_last_player_word_len = 0
	if _word_controller:
		_last_player_word_len = _word_controller.word_state.current_word.length()
	refresh_words()


func bind_combat_actions(shooter: LetterShooter, action_controller: Node) -> void:
	_shooter = shooter
	_action_controller = action_controller
	if _shooter:
		_shooter.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(_shooter.ammo, _shooter.max_ammo)
	if _action_controller:
		_action_controller.action_charge_changed.connect(_on_action_charge_changed)
		_on_action_charge_changed(_action_controller.get_charges(), _action_controller.max_action_charges)


func bind_enemy_action(action_controller: Node) -> void:
	_enemy_action_controller = action_controller
	if _enemy_action_controller:
		_enemy_action_controller.action_charge_changed.connect(_on_enemy_action_charge_changed)
		_on_enemy_action_charge_changed(
			_enemy_action_controller.get_charges(),
			_enemy_action_controller.max_action_charges,
		)


func _on_ammo_changed(current: int, maximum: int) -> void:
	if player_ammo_label == null:
		return
	player_ammo_label.visible = true
	player_ammo_label.text = "Ammo %d/%d" % [current, maximum]


func _on_action_charge_changed(charges: int, _max_charges: int) -> void:
	if action_charge_icon == null:
		return
	action_charge_icon.visible = charges > 0


func _on_enemy_action_charge_changed(charges: int, _max_charges: int) -> void:
	if enemy_action_charge_icon == null:
		return
	enemy_action_charge_icon.visible = charges > 0


func _on_validation(status: String, message: String) -> void:
	if status_label == null or not _framed_word_ui:
		return
	match status:
		"valid":
			status_label.modulate = Color(0.4, 1.0, 0.5)
		"invalid":
			status_label.modulate = Color(1.0, 0.45, 0.4)
		"garble":
			status_label.modulate = Color(1.0, 0.72, 0.45)
		"collected", "deleted", "undone":
			status_label.modulate = Color(0.85, 0.9, 1.0)
		_:
			status_label.modulate = Color(0.88, 0.92, 1.0)
	status_label.text = message


func set_word_slots_enabled(enabled: bool) -> void:
	_framed_word_ui = enabled
	if status_label:
		status_label.visible = enabled
	refresh_words()


func refresh_words() -> void:
	var player_word := ""
	var enemy_word := ""
	if _word_controller:
		player_word = _word_controller.word_state.current_word
	if _enemy:
		var info := _enemy.get_debug_info()
		enemy_word = str(info.get("enemy_word", ""))
	var grew := player_word.length() > _last_player_word_len
	_update_letter_hub(player_word_panel, player_word_label, player_word, _player_word_hidden)
	if grew and not player_word.is_empty():
		_play_player_word_collect_pop()
	_last_player_word_len = player_word.length()
	_update_letter_hub(enemy_word_panel, enemy_word_label, enemy_word, _enemy_word_hidden)


func _update_letter_hub(panel: PanelContainer, label: Label, word: String, force_hidden: bool) -> void:
	if panel == null or label == null:
		return
	var show := (
		_framed_word_ui
		and not force_hidden
		and not word.is_empty()
	)
	panel.visible = show
	if not show:
		label.text = ""
		panel.custom_minimum_size = Vector2.ZERO
		return
	label.text = word
	var text_w := _measure_word_width(label, word)
	var text_h := _measure_word_height(label)
	panel.custom_minimum_size = Vector2(text_w + WORD_PANEL_PAD_X, text_h + WORD_PANEL_PAD_Y)


func _play_player_word_collect_pop() -> void:
	call_deferred("_run_player_word_collect_pop")


func _run_player_word_collect_pop() -> void:
	if player_word_panel == null or not player_word_panel.visible:
		return
	var panel := player_word_panel
	if _player_word_pop_tween and _player_word_pop_tween.is_valid():
		_player_word_pop_tween.kill()
	panel.scale = Vector2.ONE
	panel.rotation = 0.0
	panel.pivot_offset = panel.size * 0.5
	_player_word_pop_tween = create_tween()
	_player_word_pop_tween.tween_property(
		panel,
		"scale",
		Vector2.ONE * WORD_COLLECT_POP_SCALE,
		WORD_COLLECT_POP_RISE_SEC,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_player_word_pop_tween.chain().set_parallel(true)
	_player_word_pop_tween.tween_property(
		panel,
		"scale",
		Vector2.ONE,
		WORD_COLLECT_POP_FALL_SEC,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_player_word_pop_tween.tween_method(
		_apply_player_word_collect_shake.bind(panel),
		0.0,
		1.0,
		WORD_COLLECT_POP_FALL_SEC,
	)
	_player_word_pop_tween.chain().tween_property(panel, "rotation", 0.0, 0.08)


func _apply_player_word_collect_shake(panel: PanelContainer, progress: float) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var falloff := 1.0 - progress
	panel.rotation = sin(progress * TAU * 4.2) * WORD_COLLECT_SHAKE_ROT * falloff


func _measure_word_width(label: Label, word: String) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font == null or word.is_empty():
		return 8.0
	return font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _measure_word_height(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font:
		return font.get_height(font_size)
	return float(WORD_FONT_SIZE)


var _player_word_hidden := false
var _enemy_word_hidden := false


func get_player_word_insert_position(current_word: String) -> Vector2:
	if player_word_panel == null or not player_word_panel.visible or player_word_label == null:
		return get_word_anchor_center(true)
	var rect := player_word_label.get_global_rect()
	var font: Font = player_word_label.get_theme_font("font")
	var font_size := player_word_label.get_theme_font_size("font_size")
	if font == null:
		return rect.get_center()
	var text_w := font.get_string_size(current_word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var char_w := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(rect.position.x + text_w + char_w * 0.5, rect.get_center().y)


func get_player_word_letter_positions(word: String) -> PackedVector2Array:
	var positions := PackedVector2Array()
	if player_word_panel == null or player_word_label == null or word.is_empty():
		return positions
	if not player_word_panel.visible:
		return positions
	var font: Font = player_word_label.get_theme_font("font")
	var font_size := player_word_label.get_theme_font_size("font_size")
	if font == null:
		return positions
	var rect := player_word_label.get_global_rect()
	var x := rect.position.x
	var center_y := rect.get_center().y
	for i in word.length():
		var ch := word.substr(i, 1)
		var char_w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		positions.append(Vector2(x + char_w * 0.5, center_y))
		x += char_w
	return positions


func get_garble_message_anchor() -> Vector2:
	if player_word_panel != null and player_word_panel.visible:
		var word_rect := player_word_panel.get_global_rect()
		return Vector2(word_rect.position.x, word_rect.end.y + 8.0)
	if player_bar != null:
		var hp_rect := player_bar.get_global_rect()
		return Vector2(hp_rect.position.x, hp_rect.end.y + 8.0)
	return Vector2(10.0, 72.0)


func show_garble_message(_message: String) -> void:
	# Garble quips render under the letter hub via WordGarblePurgeEffect.
	pass


func get_health_bar_damage_target(for_player: bool) -> Vector2:
	var bar := player_bar if for_player else enemy_bar
	if bar == null:
		var viewport := get_viewport().get_visible_rect()
		if for_player:
			return Vector2(viewport.position.x + 72.0, viewport.position.y + 28.0)
		return Vector2(viewport.end.x - 72.0, viewport.position.y + 28.0)
	var rect := bar.get_global_rect()
	return Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.58)


func get_word_anchor_center(for_player: bool) -> Vector2:
	var panel := player_word_panel if for_player else enemy_word_panel
	var label := player_word_label if for_player else enemy_word_label
	if panel != null and panel.visible and label != null:
		return label.get_global_rect().get_center()
	if for_player and player_bar != null:
		var hp_rect := player_bar.get_global_rect()
		return Vector2(hp_rect.position.x + 40.0, hp_rect.end.y + 28.0)
	var viewport := get_viewport().get_visible_rect()
	return Vector2(viewport.end.x - 40.0, 56.0)


func get_word_exit_target(for_player: bool) -> Vector2:
	var viewport := get_viewport().get_visible_rect()
	var margin := 48.0
	if for_player:
		return Vector2(viewport.end.x + margin, viewport.position.y + viewport.size.y * 0.35)
	return Vector2(viewport.position.x - margin, viewport.position.y + viewport.size.y * 0.35)


func set_side_word_visible(for_player: bool, visible: bool) -> void:
	if for_player:
		_player_word_hidden = not visible
	else:
		_enemy_word_hidden = not visible
	refresh_words()


func set_debug_visible(enabled: bool) -> void:
	debug_label.visible = false
	if player_bar.has_method("set_debug_numeric_visible"):
		player_bar.set_debug_numeric_visible(false)
	if enemy_bar.has_method("set_debug_numeric_visible"):
		enemy_bar.set_debug_numeric_visible(false)
	if enabled:
		refresh_debug()


func get_debug_text() -> String:
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
	return "\n".join(lines)


func refresh_debug() -> void:
	if not debug_label.visible:
		return
	debug_label.text = get_debug_text()


func _on_player_damaged(amount: int, _source: String) -> void:
	_spawn_damage_number(amount, true)


func _on_enemy_damaged(amount: int, _source: String) -> void:
	_spawn_damage_number(amount, false)


func _spawn_damage_number(amount: int, for_player: bool) -> void:
	if amount <= 0 or _damage_number_layer == null:
		return
	var combat: Node = _player_combat if for_player else _enemy_combat
	if combat == null:
		return
	var body := combat.get_parent() as Node2D
	if body == null:
		return
	var start_screen := _world_to_screen(_resolve_damage_origin(body))
	var target_screen := get_health_bar_damage_target(for_player)
	var color := Color(1.0, 0.4, 0.34, 1.0) if for_player else Color(1.0, 0.78, 0.28, 1.0)
	var slot_index := _next_damage_slot(for_player)
	DamageNumberPopup.spawn(_damage_number_layer, amount, start_screen, target_screen, color, slot_index)


func _next_damage_slot(for_player: bool) -> int:
	var slot_count := DamageNumberPopup.slot_count()
	if for_player:
		var slot := _player_damage_slot
		_player_damage_slot = (_player_damage_slot + 1) % slot_count
		return slot
	var slot := _enemy_damage_slot
	_enemy_damage_slot = (_enemy_damage_slot + 1) % slot_count
	return slot


func _resolve_damage_origin(body: Node2D) -> Vector2:
	if body.has_method("get_action_pickup_point"):
		return body.call("get_action_pickup_point") as Vector2
	return body.global_position + Vector2(0.0, -36.0)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos
