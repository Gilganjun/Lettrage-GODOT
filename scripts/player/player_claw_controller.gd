class_name PlayerClawController
extends Node2D

## Limited-charge deliberate letter grab — tap Q to target, cycle A/D, tap Q to fire.

signal claw_charge_changed(charges: int, max_charges: int)
signal claw_targeting_started()
signal claw_targeting_finished()

enum State { IDLE, PENDING_LAND, TARGETING, FIRING, RECOVER }

const CollectFx := preload("res://scripts/letters/letter_claw_collect_fx.gd")

@export var max_claw_charges: int = 3
@export var charges_per_pickup: int = 2
@export var claw_max_range: float = 500.0
@export var claw_snapshot_screen_inset: float = 24.0
@export var claw_off_screen_prune_margin: float = 40.0
@export var selected_out_of_range_grace: float = 5.0
@export var targeting_timeout: float = 8.0
@export var recover_duration: float = 0.3
@export var debug_infinite_claw: bool = false

var _charges := 0
var _state := State.IDLE
var _player: PlayerMovement
var _word_controller: WordGameController
var _combat_hud: Control
var _targets: Array[Letter] = []
var _selected_index := 0
var _selected_letter_id := -1
var _selected_grace_until := 0.0
var _targeting_time := 0.0
var _state_time := 0.0
var _confirm_armed := false
var _preview_line: Line2D
var _reticle: Line2D
var _letter_row: ClawTargetingLetterRow
var _highlight_restore: Dictionary = {}
var _decay_hold_letter_id := -1


func _ready() -> void:
	add_to_group("player_claw_controller")
	z_index = 120
	_preview_line = Line2D.new()
	_preview_line.name = "ClawPreviewLine"
	_preview_line.width = 3.0
	_preview_line.default_color = Color(0.45, 0.95, 1.0, 0.92)
	_preview_line.visible = false
	_preview_line.z_index = 1
	add_child(_preview_line)
	_reticle = Line2D.new()
	_reticle.name = "ClawReticle"
	_reticle.width = 2.0
	_reticle.default_color = Color(1.0, 0.92, 0.35, 0.95)
	_reticle.closed = true
	_reticle.visible = false
	_reticle.z_index = 2
	add_child(_reticle)


func configure(word_controller: WordGameController, combat_hud: Control) -> void:
	_word_controller = word_controller
	_combat_hud = combat_hud
	if combat_hud and combat_hud.has_method("get_claw_targeting_row"):
		_letter_row = combat_hud.get_claw_targeting_row()


func sync_to_body(center: Vector2 = Vector2.ZERO) -> void:
	position = center


func get_charges() -> int:
	return _charges


func is_active() -> bool:
	return _state == State.TARGETING or _state == State.FIRING or _state == State.RECOVER


func is_pending_land() -> bool:
	return _state == State.PENDING_LAND


func is_targeting() -> bool:
	return _state == State.TARGETING


func blocks_collection() -> bool:
	return _state != State.IDLE


func blocks_word_submit() -> bool:
	return _state != State.IDLE


func add_charge(amount: int = -1) -> void:
	var add_amount := charges_per_pickup if amount < 0 else amount
	if add_amount <= 0:
		return
	_charges = mini(max_claw_charges, _charges + add_amount)
	claw_charge_changed.emit(_charges, max_claw_charges)


func reset_for_round() -> void:
	_cancel_targeting(false)
	_state = State.IDLE
	_state_time = 0.0
	_charges = max_claw_charges if debug_infinite_claw else 0
	claw_charge_changed.emit(_charges, max_claw_charges)


func cancel_for_round_end() -> void:
	_ensure_targeting_visuals_hidden()
	_hide_letter_row()
	_release_claw_decay_hold()
	_targets.clear()
	_selected_index = 0
	_selected_letter_id = -1
	_selected_grace_until = 0.0
	_decay_hold_letter_id = -1
	_confirm_armed = false
	_state = State.IDLE
	_state_time = 0.0


func cancel_for_enemy_action_hit() -> void:
	if _state != State.TARGETING and _state != State.PENDING_LAND and _state != State.FIRING:
		return
	_cancel_targeting(true)


func sync_debug_infinite(enabled: bool) -> void:
	debug_infinite_claw = enabled
	if enabled:
		_charges = max_claw_charges
		claw_charge_changed.emit(_charges, max_claw_charges)


func process_claw(player: PlayerMovement, delta: float) -> bool:
	_player = player
	if debug_infinite_claw and _state == State.IDLE:
		if _charges != max_claw_charges:
			_charges = max_claw_charges
			claw_charge_changed.emit(_charges, max_claw_charges)
	if _state == State.IDLE and Input.is_action_just_pressed("player_claw"):
		_try_enter_targeting()
	match _state:
		State.PENDING_LAND:
			return _tick_pending_land(delta)
		State.TARGETING:
			return _tick_targeting(delta)
		State.FIRING:
			_ensure_targeting_visuals_hidden()
			player.velocity = Vector2.ZERO
			return true
		State.RECOVER:
			_ensure_targeting_visuals_hidden()
			return _tick_recover(delta)
	return false


func get_debug_info() -> Dictionary:
	var selected := _get_selected_letter()
	return {
		"state": State.keys()[_state],
		"charges": _charges,
		"target_count": _targets.size(),
		"selected_letter": selected.character if selected else "",
		"targeting_time": _targeting_time,
		"confirm_armed": _confirm_armed,
	}


func _try_enter_targeting() -> void:
	if _charges <= 0 and not debug_infinite_claw:
		return
	if not _can_enter_targeting():
		return
	_cancel_player_aim(_player)
	_deactivate_player_shield(_player)
	if not _player.is_on_floor():
		_queue_targeting_until_landed()
		return
	_begin_targeting()


func _queue_targeting_until_landed() -> void:
	_state = State.PENDING_LAND
	_targeting_time = 0.0
	_confirm_armed = false
	_targets.clear()
	_selected_index = 0
	_selected_letter_id = -1
	_selected_grace_until = 0.0


func _begin_targeting() -> void:
	_snapshot_initial_targets()
	if _targets.is_empty():
		_cancel_targeting(false)
		return
	_selected_index = _pick_initial_index()
	_pin_selected_letter()
	_confirm_armed = false
	_state = State.TARGETING
	_targeting_time = 0.0
	_preview_line.visible = true
	_reticle.visible = true
	_show_letter_row()
	_update_targeting_visuals(0.0, true)
	_apply_highlights()
	claw_targeting_started.emit()


func _tick_pending_land(_delta: float) -> bool:
	if _player == null:
		_cancel_targeting(false)
		return false
	_targeting_time += _delta
	if _targeting_time >= targeting_timeout:
		_cancel_targeting(false)
		return false
	if Input.is_action_just_pressed("ui_cancel"):
		_cancel_targeting(false)
		return false
	if not _can_remain_queued():
		_cancel_targeting(false)
		return false
	if _player.is_on_floor() and not _player.is_on_ladder:
		_begin_targeting()
		if _state == State.TARGETING:
			return true
	return false


func _can_remain_queued() -> bool:
	if _player == null:
		return false
	if _player.movement_locked:
		return false
	if _player.is_on_ladder:
		return false
	if _player_combat_blocks():
		return false
	if _word_controller and _word_controller.is_garble_busy():
		return false
	if _player_special_move_active(_player):
		return false
	if _player.has_method("is_action_sequence_targeted") and _player.is_action_sequence_targeted():
		return false
	return _gameplay_allows_claw()


func _tick_targeting(delta: float) -> bool:
	if _player == null:
		_cancel_targeting(false)
		return false
	if not _can_remain_targeting():
		_cancel_targeting(true)
		return true
	_targeting_time += delta
	if _targeting_time >= targeting_timeout:
		_cancel_targeting(false)
		return true
	if Input.is_action_just_pressed("ui_cancel"):
		_cancel_targeting(false)
		return true
	_prune_snapshotted_targets()
	_tick_selected_grace()
	_sync_claw_decay_hold()
	var ids_before := _target_instance_ids()
	_discover_new_targets()
	var row_structure_changed := _target_instance_ids() != ids_before
	if _targets.is_empty():
		_cancel_targeting(false)
		return true
	_preserve_or_repick_selection()
	_handle_target_cycle_input()
	_handle_confirm_input()
	if _state != State.TARGETING:
		_ensure_targeting_visuals_hidden()
		_player.velocity = Vector2.ZERO
		return true
	_update_targeting_visuals(delta, row_structure_changed)
	_apply_highlights()
	_player.velocity = Vector2.ZERO
	return true


func _handle_target_cycle_input() -> void:
	if not _consume_cycle_press(-1):
		_consume_cycle_press(1)


func _consume_cycle_press(direction: int) -> bool:
	var pressed := false
	if direction < 0:
		pressed = (
			Input.is_action_just_pressed("move_left")
			or Input.is_action_just_pressed("ui_left")
		)
	else:
		pressed = (
			Input.is_action_just_pressed("move_right")
			or Input.is_action_just_pressed("ui_right")
		)
	if not pressed or _targets.is_empty():
		return false
	if direction < 0:
		_selected_index = (_selected_index - 1 + _targets.size()) % _targets.size()
	else:
		_selected_index = (_selected_index + 1) % _targets.size()
	_pin_selected_letter()
	return true


func _handle_confirm_input() -> void:
	if not _confirm_armed:
		if not Input.is_action_pressed("player_claw"):
			_confirm_armed = true
		return
	if Input.is_action_just_pressed("player_claw"):
		_fire_selected()


func _tick_recover(delta: float) -> bool:
	_state_time += delta
	if _player:
		_player.velocity = Vector2.ZERO
	if _state_time >= recover_duration:
		_state = State.IDLE
		_state_time = 0.0
		claw_targeting_finished.emit()
		return false
	return true


func _fire_selected() -> void:
	var letter := _get_selected_letter()
	if letter == null or not _can_collect_letter(letter):
		return
	if _word_controller and _word_controller.is_garble_busy():
		return
	if not debug_infinite_claw:
		_charges -= 1
		claw_charge_changed.emit(_charges, max_claw_charges)
	_targets.clear()
	_selected_index = 0
	_selected_letter_id = -1
	_selected_grace_until = 0.0
	_release_claw_decay_hold()
	_clear_targeting_visuals()
	_state = State.FIRING
	_state_time = 0.0
	var origin := _claw_origin()
	CollectFx.play(
		letter,
		_word_controller,
		_combat_hud,
		origin,
		_on_claw_fx_finished,
	)


func _on_claw_fx_finished(_success: bool) -> void:
	_ensure_targeting_visuals_hidden()
	_state = State.RECOVER
	_state_time = 0.0


func _cancel_targeting(emit_finished: bool) -> void:
	var was_engaged := _state == State.TARGETING or _state == State.PENDING_LAND
	_release_claw_decay_hold()
	_clear_targeting_visuals()
	_targets.clear()
	_selected_index = 0
	_selected_letter_id = -1
	_selected_grace_until = 0.0
	_targeting_time = 0.0
	_confirm_armed = false
	if was_engaged and emit_finished:
		claw_targeting_finished.emit()
	if _state == State.TARGETING or _state == State.FIRING or _state == State.PENDING_LAND:
		_state = State.IDLE


func _clear_targeting_visuals() -> void:
	_clear_highlights()
	if _preview_line:
		_preview_line.visible = false
		_preview_line.clear_points()
	if _reticle:
		_reticle.visible = false
		_reticle.clear_points()
	_hide_letter_row()


func _show_letter_row() -> void:
	if _letter_row:
		_letter_row.show_for_targeting()


func _hide_letter_row() -> void:
	if _letter_row:
		_letter_row.hide_row()


func _ensure_targeting_visuals_hidden() -> void:
	if _state == State.TARGETING:
		return
	if _preview_line:
		_preview_line.visible = false
	if _reticle:
		_reticle.visible = false
	_hide_letter_row()


func _can_remain_targeting() -> bool:
	return _can_enter_targeting()


func _can_enter_targeting() -> bool:
	if _player == null:
		return false
	if _player.movement_locked:
		return false
	if _player.is_on_ladder:
		return false
	if _player_combat_blocks():
		return false
	if _word_controller and _word_controller.is_garble_busy():
		return false
	if _player_special_move_active(_player):
		return false
	if _player.has_method("is_action_sequence_targeted") and _player.is_action_sequence_targeted():
		return false
	return _gameplay_allows_claw()


func _gameplay_allows_claw() -> bool:
	for node in get_tree().get_nodes_in_group("match_controller"):
		if node.has_method("allows_action_start") and not node.call("allows_action_start"):
			return false
	return true


func _snapshot_initial_targets() -> void:
	_targets.clear()
	if _player == null:
		return
	var origin := _claw_origin()
	for node in get_tree().get_nodes_in_group("letters"):
		if node == null or not is_instance_valid(node) or not node is Letter:
			continue
		var letter := node as Letter
		if not _is_letter_targetable(letter):
			continue
		if origin.distance_to(letter.global_position) > claw_max_range:
			continue
		if not _is_letter_on_screen_at_activation(letter):
			continue
		_targets.append(letter)
	_sort_targets()


func _prune_snapshotted_targets() -> void:
	_purge_invalid_targets()
	if _targets.is_empty():
		return
	var kept: Array[Letter] = []
	for letter in _targets:
		if letter == null or not is_instance_valid(letter):
			continue
		if _should_prune_snapshotted_letter(letter):
			continue
		kept.append(letter)
	if kept.size() == _targets.size():
		_sync_selected_index_to_pin()
		return
	_targets = kept
	_sync_selected_index_to_pin()


func _target_instance_ids() -> Array[int]:
	var ids: Array[int] = []
	for letter in _targets:
		if letter != null and is_instance_valid(letter):
			ids.append(letter.get_instance_id())
	return ids


func _discover_new_targets() -> void:
	if _player == null:
		return
	var tracked: Dictionary = {}
	for letter in _targets:
		if letter != null and is_instance_valid(letter):
			tracked[letter.get_instance_id()] = true
	var origin := _claw_origin()
	var newcomers: Array[Letter] = []
	for node in get_tree().get_nodes_in_group("letters"):
		if node == null or not is_instance_valid(node) or not node is Letter:
			continue
		var letter := node as Letter
		var letter_id := letter.get_instance_id()
		if tracked.has(letter_id):
			continue
		if not _is_letter_targetable(letter):
			continue
		if origin.distance_to(letter.global_position) > claw_max_range:
			continue
		if not _is_letter_on_screen_at_activation(letter):
			continue
		newcomers.append(letter)
	if newcomers.is_empty():
		return
	newcomers.sort_custom(func(a: Letter, b: Letter) -> bool:
		var pa := a.global_position
		var pb := b.global_position
		if absf(pa.x - pb.x) > 4.0:
			return pa.x < pb.x
		return pa.y < pb.y
	)
	for letter in newcomers:
		_insert_target_sorted(letter)


func _insert_target_sorted(letter: Letter) -> void:
	var pos := letter.global_position
	var insert_at := _targets.size()
	for i in _targets.size():
		var other_pos := _targets[i].global_position
		if absf(pos.x - other_pos.x) > 4.0:
			if pos.x < other_pos.x:
				insert_at = i
				break
		elif pos.y < other_pos.y:
			insert_at = i
			break
	_targets.insert(insert_at, letter)


func _should_prune_snapshotted_letter(letter: Letter) -> bool:
	if letter == null or not is_instance_valid(letter):
		return true
	if not _is_letter_targetable(letter):
		return true
	var selected := _get_selected_letter()
	var is_selected: bool = (
		selected != null
		and letter.get_instance_id() == selected.get_instance_id()
	)
	if is_selected:
		if _is_letter_in_normal_range(letter):
			return false
		if letter.has_method("is_claw_decay_held") and letter.is_claw_decay_held():
			return false
		return not _selected_has_active_grace()
	if not _is_letter_in_claw_range(letter):
		return true
	return _is_letter_past_screen_edge(letter)


func _purge_invalid_targets() -> void:
	if _targets.is_empty():
		return
	var kept: Array[Letter] = []
	for letter in _targets:
		if letter != null and is_instance_valid(letter):
			kept.append(letter)
	if kept.size() != _targets.size():
		_targets = kept
		_preserve_or_repick_selection()


func _is_letter_on_screen_at_activation(letter: Letter) -> bool:
	return _is_letter_inside_screen_rect(letter, claw_snapshot_screen_inset)


func _is_letter_past_screen_edge(letter: Letter) -> bool:
	return not _is_letter_inside_screen_rect(letter, claw_off_screen_prune_margin)


func _is_letter_inside_screen_rect(letter: Letter, inset: float) -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return true
	var screen_pos := viewport.get_canvas_transform() * letter.global_position
	var rect := viewport.get_visible_rect().grow(-inset)
	return rect.has_point(screen_pos)


func _preserve_or_repick_selection() -> void:
	if _targets.is_empty():
		_selected_index = 0
		_selected_letter_id = -1
		_selected_grace_until = 0.0
		return
	if _sync_selected_index_to_pin():
		return
	_selected_index = _pick_initial_index()
	_pin_selected_letter()


func _sync_selected_index_to_pin() -> bool:
	if _selected_letter_id < 0:
		_selected_index = clampi(_selected_index, 0, _targets.size() - 1)
		_pin_selected_letter()
		return true
	for i in _targets.size():
		var letter := _targets[i]
		if letter != null and is_instance_valid(letter) and letter.get_instance_id() == _selected_letter_id:
			if _is_letter_targetable(letter):
				_selected_index = i
				return true
	return false


func _pin_selected_letter() -> void:
	if _targets.is_empty():
		_selected_letter_id = -1
		_selected_grace_until = 0.0
		return
	_selected_index = clampi(_selected_index, 0, _targets.size() - 1)
	var letter := _targets[_selected_index]
	if letter != null and is_instance_valid(letter):
		_selected_letter_id = letter.get_instance_id()
	else:
		_selected_letter_id = -1
	_selected_grace_until = 0.0


func _tick_selected_grace() -> void:
	var letter := _get_selected_letter()
	if letter == null:
		_selected_grace_until = 0.0
		return
	if _is_letter_in_normal_range(letter):
		_selected_grace_until = 0.0
		return
	if _selected_grace_until <= 0.0:
		_selected_grace_until = Time.get_ticks_msec() / 1000.0 + selected_out_of_range_grace


func _selected_has_active_grace() -> bool:
	if _selected_grace_until <= 0.0:
		return false
	return Time.get_ticks_msec() / 1000.0 < _selected_grace_until


func _sync_claw_decay_hold() -> void:
	var selected := _get_selected_letter()
	var new_id := selected.get_instance_id() if selected != null else -1
	if new_id == _decay_hold_letter_id:
		if selected != null and selected.has_method("set_claw_decay_hold"):
			selected.set_claw_decay_hold(true)
		return
	_release_claw_decay_hold()
	if selected != null and selected.has_method("set_claw_decay_hold"):
		selected.set_claw_decay_hold(true)
		_decay_hold_letter_id = new_id


func _release_claw_decay_hold() -> void:
	if _decay_hold_letter_id < 0:
		return
	var letter := instance_from_id(_decay_hold_letter_id)
	if letter is Letter and letter.has_method("set_claw_decay_hold"):
		(letter as Letter).set_claw_decay_hold(false)
	_decay_hold_letter_id = -1


func _is_letter_in_claw_range(letter: Letter) -> bool:
	if _player == null or letter == null:
		return false
	return _claw_origin().distance_to(letter.global_position) <= claw_max_range


func _is_letter_in_normal_range(letter: Letter) -> bool:
	if letter == null:
		return false
	return _is_letter_in_claw_range(letter) and _is_letter_on_screen_at_activation(letter)


func _can_collect_letter(letter: Letter) -> bool:
	if not _is_letter_targetable(letter):
		return false
	if _is_letter_in_normal_range(letter):
		return true
	var selected := _get_selected_letter()
	if selected == null or letter.get_instance_id() != selected.get_instance_id():
		return false
	return _selected_has_active_grace()


func _sort_targets() -> void:
	_purge_invalid_targets()
	if _targets.is_empty():
		return
	_targets.sort_custom(func(a: Letter, b: Letter) -> bool:
		var pa := a.global_position
		var pb := b.global_position
		if absf(pa.x - pb.x) > 4.0:
			return pa.x < pb.x
		return pa.y < pb.y
	)


func _pick_initial_index() -> int:
	if _targets.is_empty():
		return 0
	if _player == null:
		return 0
	var origin := _claw_origin()
	var facing_dir := Vector2(float(_player.facing), 0.0)
	if facing_dir.length_squared() < 0.01:
		facing_dir = Vector2.RIGHT
	var best_angle := INF
	var best_idx := 0
	for i in _targets.size():
		var to_letter := _targets[i].global_position - origin
		if to_letter.length_squared() < 1.0:
			continue
		to_letter = to_letter.normalized()
		var abs_angle := absf(facing_dir.angle_to(to_letter))
		if abs_angle < best_angle:
			best_angle = abs_angle
			best_idx = i
	if best_angle <= deg_to_rad(75.0):
		return best_idx
	return _pick_screen_center_index()


func _pick_screen_center_index() -> int:
	var center := _screen_center_world()
	var best_dist := INF
	var best_idx := 0
	for i in _targets.size():
		var dist := center.distance_squared_to(_targets[i].global_position)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


func _screen_center_world() -> Vector2:
	if _player and _player.camera:
		return _player.camera.get_screen_center_position()
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var canvas := viewport.get_visible_rect()
	var xform := viewport.get_canvas_transform().affine_inverse()
	return xform * (canvas.position + canvas.size * 0.5)


func _is_letter_targetable(letter: Letter) -> bool:
	if letter == null or not is_instance_valid(letter):
		return false
	return not letter.is_resolved()


func _get_selected_letter() -> Letter:
	if _targets.is_empty():
		return null
	if _selected_letter_id >= 0:
		for i in _targets.size():
			var letter := _targets[i]
			if letter != null and is_instance_valid(letter) and letter.get_instance_id() == _selected_letter_id:
				_selected_index = i
				return letter
	_selected_index = clampi(_selected_index, 0, _targets.size() - 1)
	var fallback := _targets[_selected_index]
	if fallback != null and is_instance_valid(fallback):
		_selected_letter_id = fallback.get_instance_id()
	return fallback


func _claw_origin() -> Vector2:
	return global_position


func _letter_row_anchor() -> Vector2:
	if _player == null:
		return _claw_origin()
	var anchor := _player.global_position
	var body_shape := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape and body_shape.shape is RectangleShape2D:
		var rect := body_shape.shape as RectangleShape2D
		anchor += body_shape.position + Vector2(0.0, rect.size.y * 0.5)
	return anchor


func _apply_highlights() -> void:
	_clear_highlights()
	for i in _targets.size():
		var letter := _targets[i]
		if letter == null or not is_instance_valid(letter):
			continue
		var sprite := letter.get_sprite()
		if sprite == null:
			continue
		var id := letter.get_instance_id()
		if not _highlight_restore.has(id):
			_highlight_restore[id] = sprite.modulate
		if i == _selected_index:
			sprite.modulate = Color(1.42, 1.32, 0.42, 1.0)
		else:
			sprite.modulate = Color(1.04, 1.06, 1.1, 0.78)


func _clear_highlights() -> void:
	for id in _highlight_restore:
		var letter := instance_from_id(int(id))
		if letter is Letter:
			var sprite := (letter as Letter).get_sprite()
			if sprite:
				sprite.modulate = _highlight_restore[id]
	_highlight_restore.clear()


func _update_targeting_visuals(_delta: float, row_structure_changed: bool = false) -> void:
	if _state != State.TARGETING:
		_ensure_targeting_visuals_hidden()
		return
	_update_preview_line()
	if _letter_row:
		_letter_row.sync(_targets, _selected_index, _letter_row_anchor(), row_structure_changed)


func _update_preview_line() -> void:
	var letter := _get_selected_letter()
	if letter == null:
		_preview_line.clear_points()
		_reticle.clear_points()
		return
	var target_local := to_local(letter.global_position)
	_preview_line.points = PackedVector2Array([Vector2.ZERO, target_local])
	_reticle.points = _build_reticle_points(target_local, _reticle_radius_for(letter))


func _reticle_radius_for(letter: Letter) -> float:
	var sprite := letter.get_sprite()
	if sprite == null or sprite.texture == null:
		return 24.0
	var tex_size := sprite.texture.get_size() * letter.get_display_scale()
	return maxf(20.0, maxf(tex_size.x, tex_size.y) * 0.55)


func _build_reticle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments := 16
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		pts.append(center + Vector2.from_angle(angle) * radius)
	return pts


func _cancel_player_aim(player: PlayerMovement) -> void:
	for child in player.get_children():
		if child is LetterShooter:
			(child as LetterShooter).cancel_aim()


func _deactivate_player_shield(player: PlayerMovement) -> void:
	var shield := PlayerShield.find_on_body(player)
	if shield:
		shield.set_active(false)


func _player_special_move_active(player: PlayerMovement) -> bool:
	for child in player.get_children():
		if child == self:
			continue
		if child.has_method("is_active") and child.call("is_active"):
			return true
		if child.has_method("is_rolling") and child.call("is_rolling"):
			return true
	return false


func _player_combat_blocks() -> bool:
	if _player == null:
		return true
	var combat := _player.get_node_or_null("CharacterCombat")
	if combat and combat.has_method("blocks_movement") and combat.blocks_movement():
		return true
	if combat and combat.has_method("is_dead") and combat.call("is_dead"):
		return true
	return false
