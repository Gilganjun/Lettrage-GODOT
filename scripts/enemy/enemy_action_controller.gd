class_name EnemyActionController
extends Node

## Cinematic ACTION for the enemy — collect fist icon, approach player, side-slide combo.

signal action_charge_changed(charges: int, max_charges: int)
signal action_sequence_started(attack_id: String)
signal action_sequence_finished()

enum State { IDLE, APPROACH, STRIKE, RECOVER }

const ATTACK_FRAME_COUNT := 61
const ATTACK_PATH := "res://assets/Characters/Alien01/Attack/attack1_%03d.png"
const ATTACK_ANIMATION_FPS := 24.0
const ICON_REACH_MAX_SECONDS := 3.0
const AUTO_ATTACK_DELAY_SECONDS := 10.0
const ICON_PICKUP_RANGE := 55.0
const ICON_JUMP_MAX_HORIZONTAL := 52.0
const ICON_JUMP_MIN_VERTICAL := 20.0

@export var max_action_charges: int = 1
## When false, enemy only runs under the icon (passive). Enable on later levels for aggressive jump pickup.
@export var icon_jump_enabled := true
@export var approach_run_speed: float = 320.0
@export var connect_distance: float = 72.0
@export var sequence_timeout: float = 9.0
@export var recover_duration: float = 0.35
@export var action_damage: int = 10
@export var side_slide_snap_speed: float = 52.0
@export var side_slide_window_frames: int = 14
@export var side_strike_body_standoff: float = 34.0
@export var side_hit_close_boost: float = 26.0
@export_group("Strike camera experiment")
@export_range(0.0, 1.0, 0.01) var dramatic_strike_camera_chance := 0.35
@export_range(0.05, 1.0, 0.01) var dramatic_strike_slow_scale := 0.18
@export_range(0.5, 1.0, 0.01) var dramatic_strike_screen_fill := 0.88

var _charges := 0
var _state := State.IDLE
var _player: PlayerMovement
var _enemy: CharacterBody2D
var _attack: ActionAttackDefinition
var _state_time := 0.0
var _sequence_time := 0.0
var _hit_applied: Array[bool] = []
var _attack_anim_loaded := ""
var _slide_segment_hit_idx := -1
var _slide_from_x := 0.0
var _kinematic_strike_position := Vector2.ZERO
var _auto_attack_timer := 0.0
var _strike_camera := ActionStrikeCameraDirector.new()
var _round_ledger: RoundCombatLedger


func _ready() -> void:
	add_to_group("enemy_action_controller")


func get_charges() -> int:
	return _charges


func set_round_ledger(ledger: RoundCombatLedger) -> void:
	_round_ledger = ledger


func is_active() -> bool:
	return _state != State.IDLE


func is_strike_active() -> bool:
	return _state == State.STRIKE


func blocks_ai() -> bool:
	return is_active()


func add_charge(amount: int = 1) -> void:
	if amount <= 0:
		return
	_charges = mini(max_action_charges, _charges + amount)
	_auto_attack_timer = AUTO_ATTACK_DELAY_SECONDS
	action_charge_changed.emit(_charges, max_action_charges)


func reset_for_round() -> void:
	if is_active():
		_finish_sequence()
	_state = State.IDLE
	_auto_attack_timer = 0.0
	_charges = 0
	action_charge_changed.emit(_charges, max_action_charges)


func should_prioritize_icon(collector_pos: Vector2, max_speed: float) -> bool:
	return is_icon_chase_active(collector_pos, max_speed)


func is_icon_chase_active(collector_pos: Vector2, max_speed: float) -> bool:
	if is_active() or _charges >= max_action_charges:
		return false
	var icon := _find_nearest_icon(collector_pos)
	if icon == null:
		return false
	var icon_pos := (icon as Node2D).global_position
	if collector_pos.distance_to(icon_pos) <= ICON_PICKUP_RANGE:
		return false
	return _estimate_reach_seconds(icon_pos, collector_pos, max_speed) <= ICON_REACH_MAX_SECONDS


func should_jump_for_icon(collector_pos: Vector2) -> bool:
	if not icon_jump_enabled or is_active() or _charges >= max_action_charges:
		return false
	var icon := _find_nearest_icon(collector_pos)
	if icon == null:
		return false
	var icon_pos := (icon as Node2D).global_position
	if collector_pos.distance_to(icon_pos) <= ICON_PICKUP_RANGE:
		return false
	var dx: float = absf(icon_pos.x - collector_pos.x)
	var dy: float = icon_pos.y - collector_pos.y
	if dx > ICON_JUMP_MAX_HORIZONTAL:
		return false
	return dy < -ICON_JUMP_MIN_VERTICAL


func get_icon_chase_direction(collector_pos: Vector2, max_speed: float) -> int:
	if not is_icon_chase_active(collector_pos, max_speed):
		return 0
	if should_jump_for_icon(collector_pos):
		return 0
	var icon := _find_nearest_icon(collector_pos)
	if icon == null:
		return 0
	var icon_pos := (icon as Node2D).global_position
	var dx: float = icon_pos.x - collector_pos.x
	return 1 if dx > 0.0 else -1


func process_action(enemy: Node, delta: float) -> bool:
	_enemy = enemy as CharacterBody2D
	_tick_auto_attack(delta)
	if _state == State.IDLE:
		return false
	_sequence_time += delta
	_state_time += delta
	if _sequence_time >= sequence_timeout:
		_finish_sequence()
		return true
	_player = _find_player()
	if _player == null or not is_instance_valid(_player):
		_finish_sequence()
		return true
	match _state:
		State.APPROACH:
			_tick_approach(delta)
		State.STRIKE:
			_tick_strike(delta)
		State.RECOVER:
			_tick_recover(delta)
	return true


func _tick_auto_attack(delta: float) -> void:
	if _charges <= 0 or is_active() or _auto_attack_timer <= 0.0:
		return
	_auto_attack_timer -= delta
	if _auto_attack_timer <= 0.0:
		_begin_sequence()


func _estimate_reach_seconds(target_pos: Vector2, enemy_pos: Vector2, max_speed: float) -> float:
	return enemy_pos.distance_to(target_pos) / maxf(max_speed, 1.0)


func _find_nearest_icon(collector_pos: Vector2) -> Node:
	var best: Node = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("action_collectible"):
		if node == null or not is_instance_valid(node):
			continue
		var icon := node as Node2D
		if icon == null:
			continue
		var dist: float = collector_pos.distance_to(icon.global_position)
		if dist < best_dist:
			best_dist = dist
			best = icon
	return best


func _sprite() -> AnimatedSprite2D:
	if _enemy == null:
		return null
	return _enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _facing() -> int:
	if _enemy == null:
		return 1
	return int(_enemy.get("facing"))


func _set_facing(value: int) -> void:
	if _enemy:
		_enemy.set("facing", value)


func _movement_config() -> EnemyMovementConfig:
	if _enemy == null:
		return null
	return _enemy.get("movement_config") as EnemyMovementConfig


func _begin_sequence() -> void:
	if _charges <= 0 or _enemy == null:
		return
	var combat := _enemy.get_node_or_null("CharacterCombat")
	if combat and combat.has_method("blocks_ai") and combat.call("blocks_ai"):
		return
	_player = _find_player()
	if _player == null:
		return
	_charges -= 1
	action_charge_changed.emit(_charges, max_action_charges)
	_auto_attack_timer = 0.0
	_attack = _build_attack_definition()
	_state = State.APPROACH
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied = []
	for _i in _attack.hit_frames.size():
		_hit_applied.append(false)
	if _player.has_method("set_action_sequence_targeted"):
		_player.set_action_sequence_targeted(true)
	_configure_strike_camera()
	_strike_camera.roll_for_sequence(
		_get_fight_camera(),
		_enemy,
		_player,
		_attack,
		func() -> void: pass,
	)
	action_sequence_started.emit(_attack.attack_id)
	if _round_ledger and _attack:
		_round_ledger.begin_action("enemy", _attack.attack_id, _attack.display_name)


func _build_attack_definition() -> ActionAttackDefinition:
	var def := ActionAttackDefinition.new()
	def.attack_id = "AlienAttack1"
	def.display_name = "Alien Attack 1"
	def.animation_name = "EnemyAttack1"
	def.animation_fps = ATTACK_ANIMATION_FPS
	def.frame_count = ATTACK_FRAME_COUNT
	def.frame_path_pattern = ATTACK_PATH
	def.native_frame_size = Vector2(388.0, 258.0)
	def.hit_frames = [9, 19, 27, 35, 41, 48]
	# -1 = strike from player's right (enemy on right), 1 = from player's left.
	def.hit_strike_sides = [-1, -1, -1, 1, -1, 1]
	def.hit_vfx_pixels = [
		Vector2(337.0, 91.0),
		Vector2(387.0, 113.0),
		Vector2(387.0, 124.0),
		Vector2(286.0, 131.0),
		Vector2(355.0, 151.0),
		Vector2(270.0, 130.0),
	]
	def.hit_vfx_kinds = ["kick", "kick", "fist", "fist", "kick", "fist"]
	def.hit_damage = [2, 2, 2, 1, 2, 1]
	def.strike_body_standoff = side_strike_body_standoff
	def.vfx_scale = 0.5
	def.vfx_particle_amount_scale = 0.2
	def.damage = action_damage
	return def


func _tick_approach(delta: float) -> void:
	var target := _player.global_position
	var to := target - _enemy.global_position
	_set_facing(1 if to.x >= 0.0 else -1)
	if to.length() <= connect_distance:
		_begin_strike()
		return
	var dir_x := 1 if to.x >= 0.0 else -1
	if absf(to.x) <= 2.0:
		dir_x = _facing()
	if _enemy.has_method("tick_action_approach_movement"):
		_enemy.call("tick_action_approach_movement", delta, dir_x, approach_run_speed)
		return
	var cfg := _movement_config()
	if cfg == null:
		return
	_enemy.velocity.x = float(dir_x) * approach_run_speed
	if _enemy.is_on_floor():
		_enemy.velocity.y = 0.0
	else:
		_enemy.velocity.y = minf(
			_enemy.velocity.y + cfg.gravity * delta,
			cfg.max_falling_speed,
		)


func _begin_strike() -> void:
	_state = State.STRIKE
	_state_time = 0.0
	_slide_segment_hit_idx = -1
	_enemy.velocity = Vector2.ZERO
	_update_facing_for_strike(1)
	_ensure_attack_animation()
	var sprite := _sprite()
	if _attack and sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(_attack.animation_name):
			sprite.sprite_frames.set_animation_speed(
				_attack.animation_name,
				_attack.animation_fps,
			)
			sprite.frame = 0
			sprite.play(_attack.animation_name)
	_align_enemy_for_upcoming_hit()


func _tick_strike(_delta: float) -> void:
	var sprite := _sprite()
	if _attack == null or sprite == null:
		_begin_recover()
		return
	_enemy.velocity = Vector2.ZERO
	var frame_num := sprite.frame + 1
	_strike_camera.tick_strike_frame(frame_num)
	_update_facing_for_strike(frame_num)
	_update_strike_pursuit(frame_num)
	_try_apply_frame_hits(frame_num)
	if not sprite.is_playing():
		_begin_recover()


func _update_strike_pursuit(frame_num: int) -> void:
	var hit_idx := _hit_index_for_frame(frame_num)
	var next_idx := _next_hit_index_after(frame_num - 1)
	var target_idx := hit_idx if hit_idx >= 0 else next_idx
	if target_idx < 0:
		return
	var side := _side_for_hit_index(target_idx)
	_apply_strike_facing(side)
	var anchor := _strike_anchor_for_side(side)
	_update_side_slide_pursuit(frame_num, hit_idx, target_idx, side, anchor)


func _update_side_slide_pursuit(
	frame_num: int,
	hit_idx: int,
	target_idx: int,
	side: int,
	anchor: Vector2,
) -> void:
	if hit_idx >= 0:
		var snap_x := anchor.x + float(side) * side_hit_close_boost
		_enemy.global_position = Vector2(snap_x, lerpf(_enemy.global_position.y, anchor.y, 0.4))
		_kinematic_strike_position = _enemy.global_position
		return
	if target_idx != _slide_segment_hit_idx:
		_slide_segment_hit_idx = target_idx
		_slide_from_x = _enemy.global_position.x
	var hit_frame := _attack.hit_frames[target_idx]
	var start_frame := _slide_start_frame_for_hit(target_idx)
	var span := maxf(hit_frame - start_frame, 1)
	var t := clampf(float(frame_num - start_frame) / float(span), 0.0, 1.0)
	t = _smoothstep(t)
	if t > 0.82:
		var tail := (t - 0.82) / 0.18
		t = lerpf(t, 1.0, tail * 0.65)
	_enemy.global_position.x = lerpf(_slide_from_x, anchor.x, t)
	_enemy.global_position.y = lerpf(_enemy.global_position.y, anchor.y, 0.3)
	_kinematic_strike_position = _enemy.global_position


func _slide_start_frame_for_hit(hit_idx: int) -> int:
	if hit_idx <= 0:
		return 1
	return _attack.hit_frames[hit_idx - 1] + 1


func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _strike_anchor_for_side(side: int) -> Vector2:
	var player_pos := _player.global_position
	var standoff := side_strike_body_standoff
	if _attack and _attack.strike_body_standoff > 0.0:
		standoff = _attack.strike_body_standoff
	var anchor_x := player_pos.x - float(side) * standoff
	return Vector2(anchor_x, player_pos.y)


func _side_for_hit_index(hit_idx: int) -> int:
	if _attack and hit_idx >= 0 and hit_idx < _attack.hit_strike_sides.size():
		return _attack.hit_strike_sides[hit_idx]
	if _player == null:
		return 1
	return 1 if _player.global_position.x >= _enemy.global_position.x else -1


func _update_facing_for_strike(frame_num: int) -> void:
	var hit_idx := _hit_index_for_frame(frame_num)
	if hit_idx < 0:
		hit_idx = _next_hit_index_after(frame_num - 1)
	if hit_idx < 0:
		hit_idx = _attack.hit_frames.size() - 1
	_apply_strike_facing(_side_for_hit_index(hit_idx))


func _apply_strike_facing(side: int) -> void:
	if _enemy == null or side == 0:
		return
	_set_facing(side)
	var sprite := _sprite()
	if sprite:
		sprite.flip_h = side < 0


func _align_enemy_for_upcoming_hit() -> void:
	var side := _side_for_hit_index(0)
	_apply_strike_facing(side)
	var anchor := _strike_anchor_for_side(side)
	_enemy.global_position = anchor
	_kinematic_strike_position = anchor


func _hit_index_for_frame(frame_num: int) -> int:
	for i in _attack.hit_frames.size():
		if _attack.hit_frames[i] == frame_num:
			return i
	return -1


func _next_hit_index_after(frame_num: int) -> int:
	for i in _attack.hit_frames.size():
		if _attack.hit_frames[i] > frame_num:
			return i
	return -1


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
	if _player == null or not is_instance_valid(_player):
		return
	var is_first := hit_idx == 0
	var is_last := hit_idx == _attack.hit_frames.size() - 1
	var player_combat := _player.get_node_or_null("CharacterCombat")
	var combat: CharacterCombat = player_combat as CharacterCombat if player_combat is CharacterCombat else null
	if combat != null and _can_apply_action_hit(combat):
		var source := "enemy_action_%s_hit%d" % [_attack.attack_id, hit_index]
		var dealt := combat.apply_action_damage(
			damage,
			source,
			_enemy.global_position,
			true,
			is_last,
		)
		if dealt > 0 and _round_ledger:
			_round_ledger.record_action_hit("enemy", dealt)
		if is_first and _player.has_method("begin_action_strike_freeze"):
			_player.begin_action_strike_freeze()
	if is_last:
		if _player.has_method("end_action_strike_freeze"):
			_player.end_action_strike_freeze()
		if combat != null:
			if combat.has_pending_action_death():
				combat.commit_deferred_action_death()
			elif not combat.is_dead():
				combat.apply_action_finisher_reaction(_enemy.global_position)
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
	var sprite := _sprite()
	if _enemy == null or sprite == null or _attack == null:
		return _player.global_position
	var pixel := _attack.hit_vfx_pixels[mini(hit_idx, _attack.hit_vfx_pixels.size() - 1)]
	var local := sprite.offset + Vector2(pixel.x * sprite.scale.x, pixel.y * sprite.scale.y)
	return sprite.global_transform * local


func _begin_recover() -> void:
	_state = State.RECOVER
	_state_time = 0.0
	_enemy.velocity = Vector2.ZERO


func _tick_recover(_delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	if _state_time >= recover_duration:
		_finish_sequence()


func _finish_sequence() -> void:
	_strike_camera.end_sequence()
	if _player and is_instance_valid(_player):
		if _player.has_method("end_action_strike_freeze"):
			_player.end_action_strike_freeze()
		if _player.has_method("set_action_sequence_targeted"):
			_player.set_action_sequence_targeted(false)
	_state = State.IDLE
	_state_time = 0.0
	_sequence_time = 0.0
	_hit_applied.clear()
	_attack = null
	_slide_segment_hit_idx = -1
	if _enemy:
		_enemy.velocity = Vector2.ZERO
	if _round_ledger:
		_round_ledger.finalize_action("enemy")
	action_sequence_finished.emit()


func _ensure_attack_animation() -> void:
	var sprite := _sprite()
	if _attack == null or _enemy == null or sprite == null:
		return
	var anim_name := _attack.animation_name
	if _attack_anim_loaded == anim_name:
		return
	var sprite_frames := sprite.sprite_frames
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


func _find_player() -> PlayerMovement:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerMovement and is_instance_valid(node):
			return node as PlayerMovement
	return null


func _get_fight_camera() -> CameraZoomController:
	var player := _find_player()
	if player == null:
		return null
	var cam := player.get_node_or_null("Camera2D")
	if cam is CameraZoomController:
		return cam as CameraZoomController
	return null


func _configure_strike_camera() -> void:
	_strike_camera.configure(
		dramatic_strike_camera_chance,
		dramatic_strike_slow_scale,
		dramatic_strike_screen_fill,
	)


func _find_world() -> Node:
	var n: Node = _enemy
	while n != null:
		if n.name == "World":
			return n
		n = n.get_parent()
	return get_tree().current_scene


func _can_apply_action_hit(combat: CharacterCombat) -> bool:
	if combat == null:
		return false
	if combat.has_pending_action_death():
		return true
	return not combat.is_dead()
