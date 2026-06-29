class_name PlayerActionController
extends Node

## Guaranteed cinematic ACTION — collect charge, press J, auto-approach enemy, always hits.

signal action_charge_changed(charges: int, max_charges: int)
signal action_sequence_started(attack_id: String)
signal action_sequence_finished()

enum State { IDLE, APPROACH, SUPER_JUMP, STRIKE, RECOVER }

enum AttackPickMode { ROTATE, FIXED }

const ATTACK_ROTATION_COUNT := 3
const ATTACK1_FRAME_COUNT := 121
const ATTACK1_PATH := "res://assets/Characters/Player/Attack1/Player_Attack1_%03d.png"
const ATTACK2_FRAME_COUNT := 61
const ATTACK2_PATH := "res://assets/Characters/Player/Attack2/Attack2_%03d.png"
const ATTACK3_FRAME_COUNT := 61
const ATTACK3_PATH := "res://assets/Characters/Player/Attack3/Attack3_%03d.png"
const ATTACK3_ANIMATION_FPS := 16.8 ## 24 fps slowed by 30%.
const SUPER_JUMP_H_STOP := 36.0
const ACTION_FACING_DEADZONE := 24.0

@export var max_action_charges: int = 1
@export var attack_pick_mode: AttackPickMode = AttackPickMode.ROTATE
## 0 = Attack1, 1 = Attack2, 2 = Attack3 — used when attack_pick_mode is FIXED.
@export_range(0, 2, 1) var fixed_attack_index: int = 0
@export var debug_infinite_action: bool = true ## TEMP — remove before shipping.
@export var approach_run_speed: float = 380.0
@export var super_jump_y_threshold: float = 48.0
@export var super_jump_impulse: float = 920.0
@export var super_jump_horizontal_speed: float = 320.0
@export var connect_distance: float = 72.0
@export var sequence_timeout: float = 9.0
@export var recover_duration: float = 0.35
@export var action_damage: int = 10
@export var pursuit_snap_speed: float = 28.0
@export var pursuit_drift_speed: float = 10.0
@export var pursuit_window_frames: int = 10
@export var side_slide_snap_speed: float = 52.0
@export var side_slide_window_frames: int = 14
@export var side_strike_body_standoff: float = 34.0
@export var side_hit_close_boost: float = 26.0
## Horizontal distance from player body origin to enemy origin during strikes.
@export var strike_body_standoff: float = 50.0
## Extra X pull toward enemy on hit frames only (closes small air gaps).
@export var hit_frame_close_boost: float = 18.0
@export var action_zoom_boost_percent: float = 48.0
@export_group("Strike camera experiment")
@export_range(0.0, 1.0, 0.01) var dramatic_strike_camera_chance := 0.35
@export_range(0.05, 1.0, 0.01) var dramatic_strike_slow_scale := 0.18
@export_range(0.5, 1.0, 0.01) var dramatic_strike_screen_fill := 0.88

var _charges := 0
var _state := State.IDLE
var _enemy: Enemy
var _attack: ActionAttackDefinition
var _state_time := 0.0
var _sequence_time := 0.0
var _hit_applied: Array[bool] = []
var _player: PlayerMovement
var _attack_anim_loaded := ""
var _slide_segment_hit_idx := -1
var _slide_from_x := 0.0
var _kinematic_strike_position := Vector2.ZERO
var _rotate_attack_index := 0
var _strike_camera := ActionStrikeCameraDirector.new()
var _round_ledger: RoundCombatLedger
var _exchange_registry: ActionExchangeRegistry
var _active_exchange: ActionExchange
var _block_feedback: Node
var _super_jump_locked_facing := 1


func _ready() -> void:
	add_to_group("player_action_controller")
	if debug_infinite_action:
		_charges = max_action_charges
		call_deferred("_emit_charge")


func get_charges() -> int:
	return _charges


func set_round_ledger(ledger: RoundCombatLedger) -> void:
	_round_ledger = ledger


func set_exchange_registry(registry: ActionExchangeRegistry) -> void:
	_exchange_registry = registry


func set_block_feedback(node: Node) -> void:
	_block_feedback = node


func is_active() -> bool:
	return _state != State.IDLE


func is_strike_active() -> bool:
	return _state == State.STRIKE


func get_state() -> State:
	return _state


func locks_movement_animation() -> bool:
	return _state == State.STRIKE or _state == State.RECOVER or _state == State.SUPER_JUMP


func uses_side_slide_strike() -> bool:
	return _state == State.STRIKE and _uses_side_slides()


func finalize_strike_physics() -> void:
	if not uses_side_slide_strike() or _player == null:
		return
	_player.global_position = _kinematic_strike_position
	_player.velocity = Vector2.ZERO


func blocks_collection() -> bool:
	return is_active()


func blocks_word_submit() -> bool:
	return is_active()


func add_charge(amount: int = 1) -> void:
	if amount <= 0:
		return
	_charges = mini(max_action_charges, _charges + amount)
	action_charge_changed.emit(_charges, max_action_charges)


func reset_for_round() -> void:
	if is_active():
		_finish_sequence()
	_state = State.IDLE
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied.clear()
	_attack = null
	_enemy = null
	_slide_segment_hit_idx = -1
	_charges = max_action_charges if debug_infinite_action else 0
	action_charge_changed.emit(_charges, max_action_charges)


func process_action(player: PlayerMovement, delta: float) -> bool:
	_player = player
	if debug_infinite_action and _state == State.IDLE:
		_charges = max_action_charges
	if _state == State.IDLE:
		_handle_idle_action_press()
		return false
	_sequence_time += delta
	_state_time += delta
	if _sequence_time >= sequence_timeout:
		_finish_sequence()
		return false
	if _enemy == null or not is_instance_valid(_enemy):
		_finish_sequence()
		return false
	match _state:
		State.APPROACH:
			_tick_approach(delta)
		State.SUPER_JUMP:
			_tick_super_jump(delta)
		State.STRIKE:
			_tick_strike(delta)
		State.RECOVER:
			_tick_recover(delta)
	return true


func _begin_sequence() -> void:
	_enemy = _find_enemy()
	if _enemy == null:
		return
	if _player_is_rolling():
		return
	if _player_claw_active():
		return
	if not debug_infinite_action:
		_charges -= 1
		action_charge_changed.emit(_charges, max_action_charges)
	_attack = _pick_attack_for_sequence()
	_state = State.APPROACH
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied = []
	for _i in _attack.hit_frames.size():
		_hit_applied.append(false)
	_cancel_player_aim(_player)
	_suspend_player_shield_for_action(_player)
	_lock_mutual_action_facing()
	if _enemy.has_method("set_action_sequence_targeted"):
		_enemy.set_action_sequence_targeted(true)
	_configure_strike_camera()
	_strike_camera.roll_for_sequence(
		_get_player_camera(),
		_player,
		_enemy,
		_attack,
		_begin_action_camera,
	)
	if _uses_side_slides() and _enemy.has_method("set_action_defender_facing_hold"):
		_enemy.set_action_defender_facing_hold(true)
	action_sequence_started.emit(_attack.attack_id)
	if _round_ledger and _attack:
		_round_ledger.begin_action("player", _attack.attack_id, _attack.display_name)
	if _exchange_registry:
		_active_exchange = _exchange_registry.begin_exchange("player", "enemy")
		_connect_exchange_block_signal(_active_exchange)
	else:
		_active_exchange = null


func _pick_attack_for_sequence() -> ActionAttackDefinition:
	var index := _rotate_attack_index
	if attack_pick_mode == AttackPickMode.FIXED:
		index = clampi(fixed_attack_index, 0, ATTACK_ROTATION_COUNT - 1)
	else:
		_rotate_attack_index = (_rotate_attack_index + 1) % ATTACK_ROTATION_COUNT
	return _build_attack_by_index(index)


func _build_attack_by_index(index: int) -> ActionAttackDefinition:
	match clampi(index, 0, ATTACK_ROTATION_COUNT - 1):
		0:
			return _build_attack1_definition()
		1:
			return _build_attack2_definition()
		_:
			return _build_attack3_definition()


func _build_attack3_definition() -> ActionAttackDefinition:
	var def := ActionAttackDefinition.new()
	def.attack_id = "Attack3"
	def.display_name = "Attack 3"
	def.animation_name = "Attack3"
	def.animation_fps = ATTACK3_ANIMATION_FPS
	def.frame_count = ATTACK3_FRAME_COUNT
	def.frame_path_pattern = ATTACK3_PATH
	def.hit_frames = [13, 19, 24, 29, 33, 37, 41, 46, 52, 57]
	def.hit_strike_sides = [1, -1, 1, -1, 1, -1, 1, -1, 1, -1]
	def.hit_vfx_pixels = [
		Vector2(162.0, 108.0),
		Vector2(104.0, 118.0),
		Vector2(160.0, 111.0),
		Vector2(104.0, 121.0),
		Vector2(162.0, 110.0),
		Vector2(104.0, 123.0),
		Vector2(157.0, 121.0),
		Vector2(163.0, 179.0),
		Vector2(159.0, 112.0),
		Vector2(104.0, 121.0),
	]
	def.hit_vfx_kinds = [
		"fist", "fist", "fist", "fist", "fist", "fist", "fist", "foot", "fist", "fist",
	]
	def.hit_damage = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	def.strike_body_standoff = 34.0
	def.vfx_scale = 0.5
	def.vfx_particle_amount_scale = 0.2
	def.damage = action_damage
	return def


func _build_attack2_definition() -> ActionAttackDefinition:
	var def := ActionAttackDefinition.new()
	def.attack_id = "Attack2"
	def.display_name = "Attack 2"
	def.animation_name = "Attack2"
	def.animation_fps = 24.0
	def.frame_count = ATTACK2_FRAME_COUNT
	def.frame_path_pattern = ATTACK2_PATH
	def.hit_frames = [10, 19, 29, 33, 35, 49, 55]
	def.hit_vfx_pixels = [
		Vector2(262.0, 106.0),
		Vector2(299.0, 242.0),
		Vector2(238.0, 170.0),
		Vector2(282.0, 197.0),
		Vector2(287.0, 193.0),
		Vector2(277.0, 89.0),
		Vector2(315.0, 108.0),
	]
	def.hit_vfx_kinds = ["fist", "foot", "fist", "foot", "tail", "fist", "fist"]
	def.hit_damage = [2, 1, 2, 1, 1, 2, 1]
	def.vfx_scale = 0.5
	def.vfx_particle_amount_scale = 0.2
	def.damage = action_damage
	return def


func _build_attack1_definition() -> ActionAttackDefinition:
	var def := ActionAttackDefinition.new()
	def.attack_id = "Attack1"
	def.display_name = "Attack 1"
	def.animation_name = "Attack1"
	def.animation_fps = 24.0
	def.frame_count = ATTACK1_FRAME_COUNT
	def.frame_path_pattern = ATTACK1_PATH
	def.hit_frames = [17, 56, 91]
	def.hit_contact_offsets = [
		Vector2(157.0, -12.0),
		Vector2(148.0, -62.0),
		Vector2(157.0, -67.0),
	]
	def.hit_vfx_pixels = [
		Vector2(315.0, 101.0),
		Vector2(306.0, 96.0),
		Vector2(315.0, 90.0),
	]
	def.hit_vfx_kinds = ["kick", "fist", "fist"]
	def.hit_damage = [4, 3, 3]
	def.damage = action_damage
	return def


func _tick_approach(delta: float) -> void:
	_refresh_mutual_action_facing()
	var target := _enemy.global_position
	var to := target - _player.global_position
	if to.length() <= connect_distance:
		_begin_strike()
		return
	if _player.is_on_floor() and to.y < -super_jump_y_threshold:
		_state = State.SUPER_JUMP
		_state_time = 0.0
		_begin_super_jump(to)
		return
	var cfg := _player.movement_config
	if cfg == null:
		cfg = load("res://resources/player/movement_config.tres")
	var dir_x := signf(to.x) if absf(to.x) > 2.0 else float(_player.facing)
	_player.velocity.x = dir_x * approach_run_speed
	if _player.is_on_floor():
		_player.velocity.y = 0.0
	else:
		_player.velocity.y = minf(
			_player.velocity.y + cfg.gravity * delta,
			cfg.max_falling_speed,
		)


func _tick_super_jump(delta: float) -> void:
	var target := _enemy.global_position
	var to := target - _player.global_position
	_apply_locked_facing(_super_jump_locked_facing)
	_tick_super_jump_horizontal(delta, to)
	var cfg := _player.movement_config
	if cfg == null:
		cfg = load("res://resources/player/movement_config.tres")
	_player.velocity.y = minf(
		_player.velocity.y + cfg.gravity * delta,
		cfg.max_falling_speed * 0.35,
	)
	if to.length() <= connect_distance or (_player.is_on_floor() and _state_time > 0.2):
		_begin_strike()


func _begin_super_jump(to: Vector2) -> void:
	_super_jump_locked_facing = _resolve_approach_facing(to)
	_apply_locked_facing(_super_jump_locked_facing)
	var launch_x := 0.0
	if absf(to.x) > SUPER_JUMP_H_STOP:
		launch_x = float(_super_jump_locked_facing) * super_jump_horizontal_speed
	_player.velocity = Vector2(launch_x, -super_jump_impulse)
	_player.movement_state = PlayerAnimation.MovementState.JUMP
	_player.animation_controller.force_apply_state(
		PlayerAnimation.MovementState.JUMP,
		_super_jump_locked_facing,
	)


func _tick_super_jump_horizontal(delta: float, to: Vector2) -> void:
	var brake := super_jump_horizontal_speed * 3.5 * delta
	if absf(to.x) <= SUPER_JUMP_H_STOP:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, brake)
		return
	var target_vx := signf(to.x) * super_jump_horizontal_speed
	var accel := super_jump_horizontal_speed * 2.0 * delta
	_player.velocity.x = move_toward(_player.velocity.x, target_vx, accel)


func _resolve_approach_facing(to: Vector2) -> int:
	if absf(to.x) <= ACTION_FACING_DEADZONE:
		return _player.facing if _player != null else 1
	return 1 if to.x > 0.0 else -1


func _apply_locked_facing(side: int) -> void:
	if _player == null or side == 0:
		return
	_player.facing = side
	if _player.sprite:
		_player.sprite.flip_h = side < 0


func _begin_strike() -> void:
	_state = State.STRIKE
	_state_time = 0.0
	_slide_segment_hit_idx = -1
	_player.velocity = Vector2.ZERO
	_update_facing_for_strike(1)
	_ensure_attack_animation()
	if _attack and _player.sprite and _player.sprite.sprite_frames:
		if _player.sprite.sprite_frames.has_animation(_attack.animation_name):
			_player.sprite.sprite_frames.set_animation_speed(
				_attack.animation_name,
				_attack.animation_fps,
			)
			_player.sprite.frame = 0
			_player.sprite.play(_attack.animation_name)
	_align_player_for_upcoming_hit()
	_begin_enemy_impact_sync()


func _tick_strike(delta: float) -> void:
	if _attack == null or _player.sprite == null:
		_begin_recover()
		return
	_player.velocity = Vector2.ZERO
	var frame_num := _current_attack_frame_number()
	_refresh_mutual_action_facing()
	_tick_strike_camera(frame_num)
	_update_facing_for_strike(frame_num)
	_update_strike_pursuit(delta, frame_num)
	_try_apply_frame_hits(frame_num)
	_tick_enemy_impact_sync(frame_num)
	if not _player.sprite.is_playing():
		_begin_recover()


func _current_attack_frame_number() -> int:
	return _player.sprite.frame + 1


func _update_strike_pursuit(delta: float, frame_num: int) -> void:
	var hit_idx := _hit_index_for_frame(frame_num)
	var next_idx := _next_hit_index_after(frame_num - 1)
	var target_idx := hit_idx if hit_idx >= 0 else next_idx
	if target_idx < 0:
		return
	var side := _side_for_hit_index(target_idx)
	_refresh_mutual_action_facing()
	var anchor := _strike_anchor_for_side(side)
	if _uses_side_slides():
		_update_side_slide_pursuit(frame_num, hit_idx, target_idx, side, anchor)
		return
	var correction := anchor - _player.global_position
	correction.y *= 0.15
	var is_hit_frame := hit_idx >= 0
	if is_hit_frame:
		correction.x += float(_player.facing) * _effective_hit_close_boost()
	if is_hit_frame:
		_player.global_position += correction
		return
	var urgency := _pursuit_urgency(frame_num)
	var blend := clampf(urgency * delta, 0.0, 1.0)
	_player.global_position += correction * blend


func _update_side_slide_pursuit(
	frame_num: int,
	hit_idx: int,
	target_idx: int,
	side: int,
	anchor: Vector2,
) -> void:
	if hit_idx >= 0:
		var snap_x := anchor.x + float(side) * _effective_hit_close_boost()
		_player.global_position = Vector2(snap_x, lerpf(_player.global_position.y, anchor.y, 0.4))
		_kinematic_strike_position = _player.global_position
		return
	if target_idx != _slide_segment_hit_idx:
		_slide_segment_hit_idx = target_idx
		_slide_from_x = _player.global_position.x
	var hit_frame := _attack.hit_frames[target_idx]
	var start_frame := _slide_start_frame_for_hit(target_idx)
	var span := maxf(hit_frame - start_frame, 1)
	var t := clampf(float(frame_num - start_frame) / float(span), 0.0, 1.0)
	t = _smoothstep(t)
	if t > 0.82:
		var tail := (t - 0.82) / 0.18
		t = lerpf(t, 1.0, tail * 0.65)
	_player.global_position.x = lerpf(_slide_from_x, anchor.x, t)
	_player.global_position.y = lerpf(_player.global_position.y, anchor.y, 0.3)
	_kinematic_strike_position = _player.global_position


func _slide_start_frame_for_hit(hit_idx: int) -> int:
	if hit_idx <= 0:
		return 1
	return _attack.hit_frames[hit_idx - 1] + 1


func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _effective_strike_standoff() -> float:
	if _attack and _attack.strike_body_standoff > 0.0:
		return _attack.strike_body_standoff
	if _uses_side_slides():
		return side_strike_body_standoff
	return strike_body_standoff


func _effective_hit_close_boost() -> float:
	if _uses_side_slides():
		return side_hit_close_boost
	return hit_frame_close_boost


func _strike_anchor_for_side(side: int) -> Vector2:
	var enemy_pos := _enemy.global_position
	var standoff := _effective_strike_standoff()
	var anchor_x := enemy_pos.x - float(side) * standoff
	return Vector2(anchor_x, enemy_pos.y)


func _strike_anchor_position() -> Vector2:
	return _strike_anchor_for_side(_player.facing)


func _pursuit_urgency(frame_num: int) -> float:
	var next_idx := _next_hit_index_after(frame_num - 1)
	if next_idx < 0:
		return pursuit_drift_speed
	var next_hit := _attack.hit_frames[next_idx]
	var frames_until := next_hit - frame_num
	var snap_speed := pursuit_snap_speed
	var window_frames := pursuit_window_frames
	if _uses_side_slides():
		var prev_side := _side_for_hit_index(maxi(next_idx - 1, 0))
		var next_side := _side_for_hit_index(next_idx)
		if next_idx > 0 and prev_side != next_side:
			snap_speed = side_slide_snap_speed
			window_frames = side_slide_window_frames
	if frames_until <= 0:
		return snap_speed
	if frames_until <= window_frames:
		var t := 1.0 - float(frames_until) / float(window_frames)
		return lerpf(pursuit_drift_speed, snap_speed, t)
	return pursuit_drift_speed


func _next_hit_index_after(frame_num: int) -> int:
	for i in _attack.hit_frames.size():
		if _attack.hit_frames[i] > frame_num:
			return i
	return -1


func _hit_index_for_frame(frame_num: int) -> int:
	for i in _attack.hit_frames.size():
		if _attack.hit_frames[i] == frame_num:
			return i
	return -1


func _side_for_hit_index(hit_idx: int) -> int:
	if _attack and hit_idx >= 0 and hit_idx < _attack.hit_strike_sides.size():
		return _attack.hit_strike_sides[hit_idx]
	if _enemy == null or _player == null:
		return 1
	return 1 if _enemy.global_position.x >= _player.global_position.x else -1


func _uses_side_slides() -> bool:
	return (
		_attack != null
		and _attack.hit_strike_sides.size() == _attack.hit_frames.size()
	)


func _update_facing_for_strike(_frame_num: int) -> void:
	_refresh_mutual_action_facing()


func _apply_strike_facing(side: int) -> void:
	if _player == null or side == 0:
		return
	_player.facing = side
	if _player.sprite:
		_player.sprite.flip_h = side < 0


func _align_player_for_upcoming_hit() -> void:
	var side := _side_for_hit_index(0)
	_refresh_mutual_action_facing()
	var anchor := _strike_anchor_for_side(side)
	_player.global_position = anchor
	_kinematic_strike_position = anchor


func _try_apply_frame_hits(frame_num: int) -> void:
	for i in _attack.hit_frames.size():
		if frame_num != _attack.hit_frames[i] or _hit_applied[i]:
			continue
		_hit_applied[i] = true
		var damage := action_damage
		if i < _attack.hit_damage.size():
			damage = _attack.hit_damage[i]
		_apply_guaranteed_hit(damage, i + 1, i)


func _apply_guaranteed_hit(damage: int, hit_index: int, hit_idx: int) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var is_first := hit_idx == 0
	var is_last := _attack != null and hit_idx == _attack.hit_frames.size() - 1
	var skip_knockback := _uses_side_slides()
	var enemy_combat := _enemy.get_node_or_null("CharacterCombat")
	var combat: CharacterCombat = enemy_combat as CharacterCombat if enemy_combat is CharacterCombat else null
	var source := "action_%s_hit%d" % [_attack.attack_id, hit_index]
	var dealt := 0
	var was_blocked := false
	if combat != null:
		var result := ActionCombatBridge.resolve_action_hit(
			_active_exchange,
			hit_idx,
			damage,
			combat,
			func() -> int:
				return combat.apply_action_damage(
					damage,
					source,
					_player.global_position,
					skip_knockback,
					is_last,
				),
		)
		was_blocked = bool(result.get("blocked", false))
		dealt = int(result.get("dealt", 0))
		if dealt > 0 and _round_ledger:
			_round_ledger.record_action_hit("player", dealt)
		if dealt > 0:
			_notify_enemy_impact_hit(hit_idx)
		if is_first and dealt > 0:
			if _enemy.has_method("begin_action_strike_freeze"):
				_enemy.begin_action_strike_freeze()
			_try_enemy_auto_block()
	if was_blocked:
		if is_last:
			_finalize_action_hit_tail(combat)
		return
	if is_last:
		_finalize_action_hit_tail(combat)
	_spawn_strike_hit_vfx(hit_idx)


func _finalize_action_hit_tail(combat: CharacterCombat) -> void:
	if _enemy and is_instance_valid(_enemy):
		if _enemy.has_method("end_action_strike_freeze"):
			_enemy.end_action_strike_freeze()
		if combat == null or not combat.has_pending_action_death():
			if _enemy.has_method("end_action_impact_sync_for_finisher"):
				_enemy.end_action_impact_sync_for_finisher()
	if combat != null and not combat.is_dead() and not combat.has_pending_action_death():
		combat.apply_action_finisher_reaction(_player.global_position)


func _spawn_strike_hit_vfx(hit_idx: int) -> void:
	if _attack == null:
		return
	var world := _find_world()
	if world == null:
		return
	var strike_pos := _strike_vfx_world_for_hit(hit_idx)
	var kind := "fist"
	if hit_idx < _attack.hit_vfx_kinds.size():
		kind = _attack.hit_vfx_kinds[hit_idx]
	ActionStrikeExplosion.spawn_at(
		world,
		strike_pos,
		kind,
		_attack.vfx_scale,
		_attack.vfx_particle_amount_scale,
	)
	ActionPowEffect.spawn_at(world, strike_pos + Vector2(0.0, -6.0))
	_trigger_action_hit_shake(hit_idx)


func _configure_strike_camera() -> void:
	_strike_camera.configure(
		dramatic_strike_camera_chance,
		dramatic_strike_slow_scale,
		dramatic_strike_screen_fill,
	)


func _begin_action_camera() -> void:
	var cam := _get_player_camera()
	if cam == null:
		return
	cam.begin_action_cinematic(_estimate_time_to_first_hit(), action_zoom_boost_percent)


func _end_action_camera() -> void:
	var cam := _get_player_camera()
	if cam:
		cam.end_action_cinematic()


func _trigger_action_hit_shake(hit_idx: int) -> void:
	var cam := _get_player_camera()
	if cam == null or _attack == null:
		return
	var kind := "fist"
	if hit_idx < _attack.hit_vfx_kinds.size():
		kind = _attack.hit_vfx_kinds[hit_idx]
	var strength := cam.hit_shake_fist_strength
	if kind in ["kick", "foot", "tail"]:
		strength = cam.hit_shake_heavy_strength
	_strike_camera.trigger_hit_shake(strength)


func _estimate_time_to_first_hit() -> float:
	if _attack == null or _attack.hit_frames.is_empty() or _player == null or _enemy == null:
		return 0.45
	var strike_to_hit := float(_attack.hit_frames[0]) / maxf(_attack.animation_fps, 1.0)
	var horiz_gap := absf(_enemy.global_position.x - _player.global_position.x) - connect_distance
	horiz_gap = maxf(horiz_gap, 0.0)
	var approach_time := 0.0
	if horiz_gap > 0.0:
		approach_time = horiz_gap / maxf(approach_run_speed, 1.0)
	var vert_gap := _enemy.global_position.y - _player.global_position.y
	if _player.is_on_floor() and vert_gap < -super_jump_y_threshold:
		approach_time += 0.45
	return approach_time + strike_to_hit


func _get_player_camera() -> CameraZoomController:
	if _player == null:
		return null
	var cam := _player.get_node_or_null("Camera2D")
	if cam is CameraZoomController:
		return cam as CameraZoomController
	return null


func _strike_vfx_world_for_hit(hit_idx: int) -> Vector2:
	if _player != null and _player.sprite != null and _attack != null:
		var pixel := _attack.hit_vfx_pixels[mini(hit_idx, _attack.hit_vfx_pixels.size() - 1)]
		var sprite := _player.sprite
		var local := sprite.offset + Vector2(pixel.x * sprite.scale.x, pixel.y * sprite.scale.y)
		return sprite.global_transform * local
	if _enemy != null and is_instance_valid(_enemy) and _attack != null:
		return _enemy.global_position + _attack.enemy_contact_offset
	if _player != null:
		return _player.global_position
	return Vector2.ZERO


func _begin_recover() -> void:
	_state = State.RECOVER
	_state_time = 0.0
	_player.velocity = Vector2.ZERO


func _tick_recover(_delta: float) -> void:
	_player.velocity = Vector2.ZERO
	if _state_time >= recover_duration:
		_finish_sequence()


func end_strike_camera_presentation() -> void:
	_strike_camera.end_sequence()


func end_strike_camera_for_finisher() -> void:
	_strike_camera.end_sequence_for_finisher()


func _tick_strike_camera(frame_num: int) -> void:
	var cam := _get_player_camera()
	if cam != null and cam.is_finisher_kill_cam_active():
		return
	_strike_camera.tick_strike_frame(frame_num)


func abort_for_finisher_survivor() -> void:
	if not is_active():
		return
	_abort_sequence_without_death_commit()


func _abort_sequence_without_death_commit() -> void:
	_strike_camera.end_sequence()
	if _enemy and is_instance_valid(_enemy) and _enemy.has_method("set_action_sequence_targeted"):
		_enemy.set_action_sequence_targeted(false)
	_unlock_mutual_action_facing()
	_state = State.IDLE
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied.clear()
	_attack = null
	_enemy = null
	_slide_segment_hit_idx = -1
	if _player:
		_player.velocity = Vector2.ZERO
	_restore_player_shield_after_action(_player)
	if _round_ledger:
		_round_ledger.finalize_action("player")
	if _exchange_registry:
		_exchange_registry.finalize_exchange("player")
	_active_exchange = null
	action_sequence_finished.emit()


func _finish_sequence() -> void:
	_strike_camera.end_sequence()
	if _enemy and is_instance_valid(_enemy):
		var enemy_combat := _enemy.get_node_or_null("CharacterCombat")
		if enemy_combat is CharacterCombat and (enemy_combat as CharacterCombat).has_pending_action_death():
			(enemy_combat as CharacterCombat).commit_deferred_action_death()
		if _enemy.has_method("set_action_sequence_targeted"):
			_enemy.set_action_sequence_targeted(false)
	_unlock_mutual_action_facing()
	_state = State.IDLE
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied.clear()
	_attack = null
	_enemy = null
	_slide_segment_hit_idx = -1
	if _player:
		_player.velocity = Vector2.ZERO
	_restore_player_shield_after_action(_player)
	if debug_infinite_action:
		_charges = max_action_charges
		_emit_charge()
	if _round_ledger:
		_round_ledger.finalize_action("player")
	if _exchange_registry:
		_exchange_registry.finalize_exchange("player")
	_active_exchange = null
	action_sequence_finished.emit()


func _ensure_attack_animation() -> void:
	if _attack == null or _player == null or _player.sprite == null:
		return
	var anim_name := _attack.animation_name
	if _attack_anim_loaded == anim_name:
		return
	var sprite_frames := _player.sprite.sprite_frames
	if sprite_frames == null:
		return
	if not sprite_frames.has_animation(anim_name):
		sprite_frames.add_animation(anim_name)
		for i in range(1, _attack.frame_count + 1):
			var tex: Texture2D = load(_attack.frame_path_pattern % i)
			if tex:
				sprite_frames.add_frame(anim_name, tex, 1.0)
		sprite_frames.set_animation_loop(anim_name, false)
	sprite_frames.set_animation_speed(anim_name, _attack.animation_fps)
	_attack_anim_loaded = anim_name


func _update_facing_toward_enemy() -> void:
	if _enemy == null or _player == null:
		return
	var to := _enemy.global_position - _player.global_position
	_player.facing = 1 if to.x >= 0.0 else -1
	if _player.sprite:
		_player.sprite.flip_h = _player.facing < 0


func _find_enemy() -> Enemy:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Enemy and is_instance_valid(node):
			return node as Enemy
	return null


func _find_world() -> Node:
	var n: Node = self
	while n != null:
		if n.name == "World":
			return n
		n = n.get_parent()
	return get_tree().current_scene


func _emit_charge() -> void:
	action_charge_changed.emit(_charges, max_action_charges)


func _cancel_player_aim(player: PlayerMovement) -> void:
	for child in player.get_children():
		if child is LetterShooter:
			(child as LetterShooter).cancel_aim()


func _suspend_player_shield_for_action(player: PlayerMovement) -> void:
	var shield := PlayerShield.find_on_body(player)
	if shield:
		shield.suspend_for_action_sequence()


func _restore_player_shield_after_action(player: PlayerMovement) -> void:
	if player == null:
		return
	var shield := PlayerShield.find_on_body(player)
	if shield:
		shield.restore_after_action_sequence()


func _deactivate_player_shield(player: PlayerMovement) -> void:
	var shield := PlayerShield.find_on_body(player)
	if shield:
		shield.set_active(false)


func _player_is_rolling() -> bool:
	if _player == null:
		return false
	for child in _player.get_children():
		if child.has_method("is_rolling") and child.call("is_rolling"):
			return true
	return false


func _player_claw_active() -> bool:
	if _player == null:
		return false
	for child in _player.get_children():
		if child is PlayerClawController and (child as PlayerClawController).is_active():
			return true
	return false


func _player_combat_blocks() -> bool:
	if _player == null:
		return true
	var combat := _player.get_node_or_null("CharacterCombat")
	if combat and combat.has_method("blocks_movement") and combat.blocks_movement():
		return true
	return false


func _gameplay_allows_action() -> bool:
	for node in get_tree().get_nodes_in_group("match_controller"):
		if node.has_method("allows_action_start") and not node.call("allows_action_start"):
			return false
	return true


func _can_apply_action_hit(combat: CharacterCombat) -> bool:
	if combat == null:
		return false
	if combat.has_pending_action_death():
		return true
	return not combat.is_dead()


func process_defender_block_input(player: PlayerMovement) -> bool:
	_player = player
	if debug_infinite_action and _state == State.IDLE:
		_charges = max_action_charges
	if not Input.is_action_just_pressed("player_action") or _charges <= 0:
		return false
	if not _gameplay_allows_action():
		return false
	return _try_manual_defender_block()


func _handle_idle_action_press() -> void:
	if not Input.is_action_just_pressed("player_action") or _charges <= 0:
		return
	if not _gameplay_allows_action():
		return
	if _try_manual_defender_block():
		return
	if _player_combat_blocks():
		return
	if _player_claw_active():
		return
	if _player.is_action_sequence_targeted():
		return
	_begin_sequence()


func _try_manual_defender_block() -> bool:
	if _player == null or _exchange_registry == null:
		return false
	if not _player.is_action_sequence_targeted():
		return false
	var exchange := _exchange_registry.get_incoming_exchange_for_defender("player")
	if exchange == null or not exchange.can_offer_block() or _charges <= 0:
		return false
	if not exchange.try_activate_defender_block():
		return false
	if not debug_infinite_action:
		_charges -= 1
	action_charge_changed.emit(_charges, max_action_charges)
	return true


func _try_enemy_auto_block() -> void:
	if _enemy == null or _active_exchange == null:
		return
	var enemy_action := _enemy.get_action_controller()
	if enemy_action and enemy_action.has_method("try_auto_defender_block"):
		enemy_action.try_auto_defender_block(_active_exchange)


func _connect_exchange_block_signal(exchange: ActionExchange) -> void:
	if exchange == null or _block_feedback == null:
		return
	if not exchange.strike_blocked.is_connected(_on_exchange_strike_blocked):
		exchange.strike_blocked.connect(_on_exchange_strike_blocked)


func _on_exchange_strike_blocked(defender: String, _hit_idx: int) -> void:
	if _block_feedback and _block_feedback.has_method("show_action_block_flash"):
		_block_feedback.show_action_block_flash(defender == "player")


func _begin_enemy_impact_sync() -> void:
	if _enemy and is_instance_valid(_enemy) and _enemy.has_method("begin_action_impact_sync") and _attack:
		_enemy.begin_action_impact_sync(_attack)


func _lock_mutual_action_facing() -> void:
	if _player and _player.has_method("set_action_facing_locked"):
		_player.set_action_facing_locked(true)
	if _enemy and _enemy.has_method("lock_action_facing_toward"):
		_enemy.lock_action_facing_toward(_player)
	_refresh_mutual_action_facing()


func _unlock_mutual_action_facing() -> void:
	if _enemy and _enemy.has_method("set_action_defender_facing_hold"):
		_enemy.set_action_defender_facing_hold(false)
	if _player and _player.has_method("set_action_facing_locked"):
		_player.set_action_facing_locked(false)
	if _enemy and _enemy.has_method("unlock_action_facing"):
		_enemy.unlock_action_facing()


func _refresh_mutual_action_facing() -> void:
	if _player == null or _enemy == null:
		return
	if _player.has_method("refresh_action_facing_toward"):
		_player.refresh_action_facing_toward(_enemy)
	if _enemy.has_method("refresh_action_facing_lock"):
		_enemy.refresh_action_facing_lock()


func _tick_enemy_impact_sync(player_frame: int) -> void:
	if _enemy and is_instance_valid(_enemy) and _enemy.has_method("tick_action_impact_sync"):
		_enemy.tick_action_impact_sync(player_frame)


func _notify_enemy_impact_hit(hit_idx: int) -> void:
	if _enemy and is_instance_valid(_enemy) and _enemy.has_method("notify_action_impact_hit") and _attack:
		_enemy.notify_action_impact_hit(hit_idx, _attack.hit_frames.size())
