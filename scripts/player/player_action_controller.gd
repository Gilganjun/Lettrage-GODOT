class_name PlayerActionController
extends Node

## Guaranteed cinematic ACTION — collect charge, press J, auto-approach enemy, always hits.

signal action_charge_changed(charges: int, max_charges: int)
signal action_sequence_started(attack_id: String)
signal action_sequence_finished()

enum State { IDLE, APPROACH, SUPER_JUMP, STRIKE, RECOVER }

const ATTACK1_FRAME_COUNT := 121
const ATTACK1_PATH := "res://assets/Characters/Player/Attack1/Player_Attack1_%03d.png"
const ATTACK2_FRAME_COUNT := 61
const ATTACK2_PATH := "res://assets/Characters/Player/Attack2/Attack2_%03d.png"

@export var max_action_charges: int = 1
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
## Horizontal distance from player body origin to enemy origin during strikes.
@export var strike_body_standoff: float = 50.0
## Extra X pull toward enemy on hit frames only (closes small air gaps).
@export var hit_frame_close_boost: float = 18.0

var _charges := 0
var _state := State.IDLE
var _enemy: Enemy
var _attack: ActionAttackDefinition
var _state_time := 0.0
var _sequence_time := 0.0
var _hit_applied: Array[bool] = []
var _player: PlayerMovement
var _attack_anim_loaded := ""


func _ready() -> void:
	add_to_group("player_action_controller")
	if debug_infinite_action:
		_charges = max_action_charges
		call_deferred("_emit_charge")


func get_charges() -> int:
	return _charges


func is_active() -> bool:
	return _state != State.IDLE


func get_state() -> State:
	return _state


func locks_movement_animation() -> bool:
	return _state == State.STRIKE or _state == State.RECOVER


func blocks_collection() -> bool:
	return is_active()


func blocks_word_submit() -> bool:
	return is_active()


func add_charge(amount: int = 1) -> void:
	if amount <= 0:
		return
	_charges = mini(max_action_charges, _charges + amount)
	action_charge_changed.emit(_charges, max_action_charges)


func process_action(player: PlayerMovement, delta: float) -> bool:
	_player = player
	if debug_infinite_action and _state == State.IDLE:
		_charges = max_action_charges
	if _state == State.IDLE:
		if Input.is_action_just_pressed("player_action") and _charges > 0:
			if _player_combat_blocks():
				return false
			_begin_sequence()
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
	if not debug_infinite_action:
		_charges -= 1
		action_charge_changed.emit(_charges, max_action_charges)
	_attack = _build_attack2_definition()
	_state = State.APPROACH
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied = []
	for _i in _attack.hit_frames.size():
		_hit_applied.append(false)
	_cancel_player_aim(_player)
	_deactivate_player_shield(_player)
	if _enemy.has_method("set_action_sequence_targeted"):
		_enemy.set_action_sequence_targeted(true)
	action_sequence_started.emit(_attack.attack_id)


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
	var target := _enemy.global_position
	var to := target - _player.global_position
	_player.facing = 1 if to.x >= 0.0 else -1
	if to.length() <= connect_distance:
		_begin_strike()
		return
	if _player.is_on_floor() and to.y < -super_jump_y_threshold:
		_state = State.SUPER_JUMP
		_state_time = 0.0
		var horiz := signf(to.x) if absf(to.x) > 4.0 else float(_player.facing)
		_player.velocity = Vector2(horiz * super_jump_horizontal_speed, -super_jump_impulse)
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
	_player.facing = 1 if to.x >= 0.0 else -1
	var cfg := _player.movement_config
	if cfg == null:
		cfg = load("res://resources/player/movement_config.tres")
	var horiz := signf(to.x) if absf(to.x) > 4.0 else float(_player.facing)
	_player.velocity.x = horiz * super_jump_horizontal_speed
	_player.velocity.y = minf(
		_player.velocity.y + cfg.gravity * delta,
		cfg.max_falling_speed * 0.35,
	)
	if to.length() <= connect_distance or (_player.is_on_floor() and _state_time > 0.2):
		_begin_strike()


func _begin_strike() -> void:
	_state = State.STRIKE
	_state_time = 0.0
	_player.velocity = Vector2.ZERO
	_update_facing_toward_enemy()
	_ensure_attack_animation()
	if _attack and _player.sprite and _player.sprite.sprite_frames:
		if _player.sprite.sprite_frames.has_animation(_attack.animation_name):
			_player.sprite.sprite_frames.set_animation_speed(
				_attack.animation_name,
				_attack.animation_fps,
			)
			_player.sprite.play(_attack.animation_name)
	_align_player_for_upcoming_hit()


func _tick_strike(delta: float) -> void:
	if _attack == null or _player.sprite == null:
		_begin_recover()
		return
	_player.velocity = Vector2.ZERO
	_update_facing_toward_enemy()
	var frame_num := _current_attack_frame_number()
	_update_strike_pursuit(delta, frame_num)
	_try_apply_frame_hits(frame_num)
	if not _player.sprite.is_playing():
		_begin_recover()


func _current_attack_frame_number() -> int:
	return _player.sprite.frame + 1


func _update_strike_pursuit(delta: float, frame_num: int) -> void:
	var anchor := _strike_anchor_position()
	var correction := anchor - _player.global_position
	correction.y *= 0.15
	var is_hit_frame := frame_num in _attack.hit_frames
	if is_hit_frame:
		correction.x += float(_player.facing) * hit_frame_close_boost
	if is_hit_frame:
		_player.global_position += correction
		return
	var urgency := _pursuit_urgency(frame_num)
	var blend := clampf(urgency * delta, 0.0, 1.0)
	_player.global_position += correction * blend


func _strike_anchor_position() -> Vector2:
	var enemy_pos := _enemy.global_position
	var anchor_x := enemy_pos.x - float(_player.facing) * strike_body_standoff
	return Vector2(anchor_x, enemy_pos.y)


func _pursuit_urgency(frame_num: int) -> float:
	var next_hit := _next_hit_frame_after(frame_num - 1)
	if next_hit < 0:
		return pursuit_drift_speed
	var frames_until := next_hit - frame_num
	if frames_until <= 0:
		return pursuit_snap_speed
	if frames_until <= pursuit_window_frames:
		var t := 1.0 - float(frames_until) / float(pursuit_window_frames)
		return lerpf(pursuit_drift_speed, pursuit_snap_speed, t)
	return pursuit_drift_speed


func _next_hit_frame_after(frame_num: int) -> int:
	for hit_frame in _attack.hit_frames:
		if hit_frame > frame_num:
			return hit_frame
	return -1


func _align_player_for_upcoming_hit() -> void:
	var anchor := _strike_anchor_position()
	_player.global_position.x = anchor.x
	_player.global_position.y = anchor.y


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
	var enemy_combat := _enemy.get_node_or_null("CharacterCombat")
	if enemy_combat is CharacterCombat and not (enemy_combat as CharacterCombat).is_dead():
		(enemy_combat as CharacterCombat).apply_action_damage(
			damage,
			"action_%s_hit%d" % [_attack.attack_id, hit_index],
			_player.global_position,
		)
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


func _strike_vfx_world_for_hit(hit_idx: int) -> Vector2:
	if _player == null or _player.sprite == null or _attack == null:
		return _enemy.global_position + _attack.enemy_contact_offset
	var pixel := _attack.hit_vfx_pixels[mini(hit_idx, _attack.hit_vfx_pixels.size() - 1)]
	var sprite := _player.sprite
	var local := sprite.offset + Vector2(pixel.x * sprite.scale.x, pixel.y * sprite.scale.y)
	return sprite.global_transform * local


func _begin_recover() -> void:
	_state = State.RECOVER
	_state_time = 0.0
	_player.velocity = Vector2.ZERO


func _tick_recover(_delta: float) -> void:
	_player.velocity = Vector2.ZERO
	if _state_time >= recover_duration:
		_finish_sequence()


func _finish_sequence() -> void:
	if _enemy and is_instance_valid(_enemy) and _enemy.has_method("set_action_sequence_targeted"):
		_enemy.set_action_sequence_targeted(false)
	_state = State.IDLE
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied.clear()
	_attack = null
	_enemy = null
	if _player:
		_player.velocity = Vector2.ZERO
	if debug_infinite_action:
		_charges = max_action_charges
		_emit_charge()
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


func _deactivate_player_shield(player: PlayerMovement) -> void:
	var shield := player.get_node_or_null("PlayerShield")
	if shield and shield.has_method("set_active"):
		shield.set_active(false)


func _player_is_rolling() -> bool:
	if _player == null:
		return false
	for child in _player.get_children():
		if child.has_method("is_rolling") and child.call("is_rolling"):
			return true
	return false


func _player_combat_blocks() -> bool:
	if _player == null:
		return true
	var combat := _player.get_node_or_null("CharacterCombat")
	if combat and combat.has_method("blocks_movement") and combat.blocks_movement():
		return true
	return false
