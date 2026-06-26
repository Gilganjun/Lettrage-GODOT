class_name CharacterCombat
extends Node

## Health, injury, death and Phase 2C1 test respawn for Player or Enemy.

signal death_started(source: String)
signal respawn_completed

@export var owner_kind := "player"
@export var auto_respawn_on_death: bool = true
@export var death_respawn_delay := 2.5
@export var injury_knock_rotation := 90.0
@export var enemy_stun_idle_after_death := 2.0
@export var stun_slide_stop_offset := 26.0
@export var stun_slide_speed_min := 650.0
@export var stun_slide_speed_max := 2800.0
@export var stun_watchdog_buffer := 0.75
@export var action_injury_duration := 0.65
@export var action_knockback_speed := 280.0

var _body: CharacterBody2D
var _sprite: AnimatedSprite2D
var _spawn_position := Vector2.ZERO
var _death_timer := 0.0
var _pending_respawn := false
var _saved_sprite_rotation := 0.0
var _upright_rotation := 0.0
var _initialized := false
var _is_knocked := false
var _word_stun_active := false
var _word_stun_idle_timer := 0.0
var _stun_death_anim_active := false
var _stun_attacker_position := Vector2.ZERO
var _stun_slide_target_x := 0.0
var _stun_slide_started_at := 0.0
var _stun_slide_duration := 2.2
var _stun_attacker_body: Node2D = null
var _stun_slide_landed := false
var _stun_horizontal_done := false
var _stun_locked_x := 0.0
var _stun_watchdog_deadline := 0.0
var _last_word_hit_attacker_position := Vector2.INF
var _pending_action_death_source := ""


func _health() -> Node:
	return $Health


func _injury() -> Node:
	return $Injury


func _hit_feedback() -> Node:
	return $HitFeedback


var health: Node:
	get:
		return _health()


var injury: Node:
	get:
		return _injury()


func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_body = get_parent() as CharacterBody2D
	if _body:
		_spawn_position = _body.global_position
		_sprite = _body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _sprite:
			_upright_rotation = _sprite.rotation_degrees
			_saved_sprite_rotation = _upright_rotation
	var impact := load(
		"res://assets/530886__eflexmusic__incoming-artillery-strike-cinematic-explosion.wav"
	) as AudioStream
	_hit_feedback().setup(_sprite, impact)
	_health().damaged.connect(_on_damaged)
	_health().died.connect(_on_died)
	_injury().injury_started.connect(_on_injury_started)
	_injury().injury_ended.connect(_on_injury_ended)


func _ready() -> void:
	_ensure_initialized()


func configure_spawn(spawn_position: Vector2) -> void:
	_spawn_position = spawn_position


func blocks_movement() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions() or is_word_stun_active()


func blocks_collection() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions() or is_word_stun_active()


func blocks_word_submit() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions() or is_word_stun_active()


func blocks_ai() -> bool:
	_ensure_initialized()
	if _health().is_dead or _injury().blocks_actions():
		return true
	if owner_kind == "enemy" and _word_stun_active:
		return true
	return false


func is_dead() -> bool:
	_ensure_initialized()
	return _health().is_dead


func is_word_stun_active() -> bool:
	_ensure_initialized()
	return _word_stun_active


func has_pending_action_death() -> bool:
	_ensure_initialized()
	return not _pending_action_death_source.is_empty()


func owns_action_sprite_presentation() -> bool:
	_ensure_initialized()
	return _health().is_dead or not _pending_action_death_source.is_empty() or _word_stun_active


func is_enemy_stun_active() -> bool:
	_ensure_initialized()
	return owner_kind == "enemy" and _word_stun_active


func is_stun_position_locked() -> bool:
	_ensure_initialized()
	return _word_stun_active and _stun_horizontal_done


func is_stun_grounded() -> bool:
	_ensure_initialized()
	return _word_stun_active and _stun_slide_landed


func get_stun_locked_x() -> float:
	return _stun_locked_x


func apply_word_damage(
	amount: int,
	source: String,
	attacker_position: Vector2 = Vector2.INF,
	attacker_body: Node2D = null,
) -> int:
	_ensure_initialized()
	if _health().is_dead:
		return 0
	_last_word_hit_attacker_position = attacker_position
	_stun_attacker_body = attacker_body
	return _health().apply_damage(amount, source)


func apply_action_damage(
	amount: int,
	source: String,
	attacker_position: Vector2 = Vector2.INF,
	skip_knockback: bool = false,
	is_finisher_hit: bool = false,
) -> int:
	_ensure_initialized()
	if _health().is_dead and not has_pending_action_death():
		return 0
	var dealt: int = (_health() as HealthComponent).apply_damage(amount, source)
	if dealt <= 0:
		return dealt
	_hit_feedback().play_hit(true)
	if has_pending_action_death() or _health().is_dead:
		return dealt
	if is_finisher_hit:
		return dealt
	_injury().start_injury(action_injury_duration)
	if not skip_knockback:
		_apply_action_knockback(attacker_position)
	return dealt


## Last ACTION strike — Death anim + word-stun slide when HP remains (not a kill).
func apply_action_finisher_reaction(attacker_position: Vector2) -> void:
	_ensure_initialized()
	if _health().is_dead or is_word_stun_active():
		return
	if owner_kind != "enemy":
		return
	_begin_word_stun(attacker_position)


func force_death(source: String = "debug") -> void:
	_ensure_initialized()
	if _health().is_dead:
		return
	_health().apply_damage(_health().current_health, source)


func debug_damage(amount: int) -> void:
	apply_word_damage(amount, "debug")


func debug_heal_full() -> void:
	_ensure_initialized()
	if _health().is_dead:
		return
	_health().heal_full()


func debug_set_health(remaining: int) -> void:
	_ensure_initialized()
	if _health().is_dead:
		return
	var hc := _health() as HealthComponent
	remaining = clampi(remaining, 1, hc.max_health)
	hc.current_health = remaining
	hc.health_changed.emit(hc.current_health, hc.max_health)


func commit_deferred_action_death() -> void:
	_ensure_initialized()
	if _pending_action_death_source.is_empty():
		return
	if _body is Enemy and (_body as Enemy).has_method("end_action_impact_sync_for_finisher"):
		(_body as Enemy).end_action_impact_sync_for_finisher()
	var source := _pending_action_death_source
	_pending_action_death_source = ""
	_execute_death_presentation(source)


func reset_combat() -> void:
	_ensure_initialized()
	_pending_respawn = false
	_death_timer = 0.0
	_pending_action_death_source = ""
	_word_stun_active = false
	_word_stun_idle_timer = 0.0
	_stun_death_anim_active = false
	_stun_attacker_position = Vector2.ZERO
	_stun_attacker_body = null
	_stun_slide_landed = false
	_stun_horizontal_done = false
	_stun_locked_x = 0.0
	_stun_watchdog_deadline = 0.0
	_last_word_hit_attacker_position = Vector2.INF
	_release_shield_after_stun()
	_injury().end_injury()
	_health().reset_health()
	if _sprite:
		if _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
			_sprite.animation_finished.disconnect(_on_sprite_animation_finished)
		if _sprite.animation_finished.is_connected(_on_real_death_pose_finished):
			_sprite.animation_finished.disconnect(_on_real_death_pose_finished)
		_restore_upright_pose()
		_sprite.speed_scale = 1.0
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Idle"):
			_sprite.play("Idle")
		_sprite.modulate = Color.WHITE
	respawn_completed.emit()


func _process(delta: float) -> void:
	if _word_stun_active:
		_tick_stun_watchdog()
		_tick_stun_grounding()
	if _word_stun_idle_timer > 0.0:
		_word_stun_idle_timer = maxf(0.0, _word_stun_idle_timer - delta)
		if _word_stun_idle_timer <= 0.0:
			_finish_word_stun()
	if not _pending_respawn:
		return
	_death_timer -= delta
	if _death_timer <= 0.0:
		_finish_respawn()


func _on_damaged(_amount: int, source: String) -> void:
	if _health().is_dead:
		return
	if source.begins_with("action_"):
		return
	_hit_feedback().play_hit()
	_begin_word_stun(_last_word_hit_attacker_position)
	_last_word_hit_attacker_position = Vector2.INF


func _begin_word_stun(attacker_position: Vector2 = Vector2.INF) -> void:
	if _word_stun_active:
		return
	_word_stun_active = true
	_word_stun_idle_timer = 0.0
	_stun_death_anim_active = true
	_stun_slide_landed = false
	_stun_horizontal_done = false
	if _stun_attacker_body and is_instance_valid(_stun_attacker_body):
		_stun_attacker_position = _stun_attacker_body.global_position
	elif attacker_position != Vector2.INF:
		_stun_attacker_position = attacker_position
	elif _last_word_hit_attacker_position != Vector2.INF:
		_stun_attacker_position = _last_word_hit_attacker_position
	_stun_slide_target_x = _compute_stun_slide_target_x()
	_stun_attacker_body = null
	_stun_slide_duration = _get_death_anim_duration()
	_stun_slide_started_at = Time.get_ticks_msec() / 1000.0
	_set_stun_facing_toward_attacker()
	_injury().start_injury(120.0)
	_deactivate_shield_for_stun()
	_stun_watchdog_deadline = (
		Time.get_ticks_msec() / 1000.0
		+ _stun_slide_duration
		+ enemy_stun_idle_after_death
		+ stun_watchdog_buffer
	)
	_play_word_stun_death()


func _set_stun_facing_toward_attacker() -> void:
	if _stun_attacker_position == Vector2.INF or _body == null:
		return
	var facing_val := -1 if _stun_attacker_position.x < _body.global_position.x else 1
	if _body is Enemy:
		(_body as Enemy).facing = facing_val
	elif _body is PlayerMovement:
		(_body as PlayerMovement).facing = facing_val
	if _sprite:
		_sprite.flip_h = facing_val < 0


func compute_stun_slide_velocity() -> Vector2:
	if not _stun_death_anim_active or _body == null or _stun_horizontal_done:
		return Vector2.ZERO
	var dx := _stun_slide_target_x - _body.global_position.x
	if absf(dx) < 10.0:
		_land_stun_slide()
		return Vector2.ZERO
	var remaining := maxf(_stun_slide_time_remaining(), 0.12)
	var speed := absf(dx) / remaining
	speed = clampf(speed, stun_slide_speed_min, stun_slide_speed_max)
	return Vector2(signf(dx) * speed, 0.0)


func _land_stun_slide() -> void:
	if _stun_horizontal_done:
		return
	_stun_horizontal_done = true
	if _body:
		_stun_locked_x = _body.global_position.x
		if _body.is_on_floor():
			_finalize_stun_ground_lock()
	else:
		_stun_locked_x = _stun_slide_target_x
	_stun_attacker_body = null


func _lock_stun_at_current_x() -> void:
	if _stun_horizontal_done or _body == null:
		return
	_stun_horizontal_done = true
	_stun_locked_x = _body.global_position.x
	if _body.is_on_floor():
		_finalize_stun_ground_lock()
	else:
		_body.velocity.x = 0.0
	_stun_attacker_body = null


func _finalize_stun_ground_lock() -> void:
	if _stun_slide_landed or _body == null:
		return
	_stun_slide_landed = true
	_body.velocity = Vector2.ZERO


func _tick_stun_grounding() -> void:
	if not _stun_horizontal_done or _stun_slide_landed or _body == null:
		return
	if _body.is_on_floor():
		_finalize_stun_ground_lock()


func _stun_slide_time_remaining() -> float:
	var elapsed := Time.get_ticks_msec() / 1000.0 - _stun_slide_started_at
	return maxf(_stun_slide_duration - elapsed, 0.05)


func _get_death_anim_duration() -> float:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Death"):
		var frame_count := _sprite.sprite_frames.get_frame_count("Death")
		var anim_speed := _sprite.sprite_frames.get_animation_speed("Death")
		if anim_speed > 0.0:
			return float(frame_count) / anim_speed
	return 2.2


func _compute_stun_slide_target_x() -> float:
	if _body == null:
		return 0.0
	if _stun_attacker_position == Vector2.INF:
		return _body.global_position.x
	var side := signf(_body.global_position.x - _stun_attacker_position.x)
	if side == 0.0:
		side = 1.0
	return _stun_attacker_position.x + side * stun_slide_stop_offset


func _play_word_stun_death() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		_finish_word_stun()
		return
	if not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
	if _sprite.sprite_frames.has_animation("Death"):
		_sprite.play("Death")
	elif _sprite.sprite_frames.has_animation("Idle"):
		_sprite.play("Idle")
		_word_stun_idle_timer = enemy_stun_idle_after_death


func _tick_stun_watchdog() -> void:
	if _stun_watchdog_deadline <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var death_phase_end := _stun_slide_started_at + _stun_slide_duration
	if (
		_stun_death_anim_active
		and _word_stun_idle_timer <= 0.0
		and now >= death_phase_end
	):
		_recover_stun_after_death_phase()
	if now >= _stun_watchdog_deadline:
		_stun_watchdog_deadline = 0.0
		_finish_word_stun()


func _recover_stun_after_death_phase() -> void:
	if not _word_stun_active:
		return
	_stun_death_anim_active = false
	if not _stun_horizontal_done:
		_lock_stun_at_current_x()
	_hold_death_pose_at_last_frame()
	_word_stun_idle_timer = enemy_stun_idle_after_death


func _on_sprite_animation_finished() -> void:
	if not _word_stun_active:
		return
	if _sprite == null or _sprite.animation != "Death":
		return
	_stun_death_anim_active = false
	if not _stun_horizontal_done:
		_lock_stun_at_current_x()
	_hold_death_pose_at_last_frame()
	_word_stun_idle_timer = enemy_stun_idle_after_death


func _hold_death_pose_at_last_frame() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation("Death"):
		return
	var last_frame := _sprite.sprite_frames.get_frame_count("Death") - 1
	if last_frame < 0:
		return
	_sprite.play("Death")
	_sprite.frame = last_frame
	_sprite.pause()


func _finish_word_stun() -> void:
	_stun_watchdog_deadline = 0.0
	_word_stun_active = false
	_word_stun_idle_timer = 0.0
	_stun_death_anim_active = false
	_stun_slide_landed = false
	_stun_horizontal_done = false
	_stun_locked_x = 0.0
	_stun_attacker_body = null
	if _sprite and _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	if _health().is_dead:
		return
	_release_shield_after_stun()
	_injury().end_injury()
	_restore_enemy_locomotion_animation()


func _apply_action_knockback(attacker_position: Vector2) -> void:
	if _body == null:
		return
	var kb_dir := signf(_body.global_position.x - attacker_position.x)
	if kb_dir == 0.0:
		kb_dir = 1.0
	_body.velocity.x = kb_dir * action_knockback_speed


func _on_died(source: String) -> void:
	if _should_present_action_death_later(source):
		_pending_action_death_source = source
		return
	_execute_death_presentation(source)


func _should_present_action_death_later(source: String) -> bool:
	if not source.begins_with("action_") and not source.begins_with("enemy_action_"):
		return false
	if owner_kind == "enemy" and source.begins_with("action_"):
		if not _is_enemy_in_active_action_sequence():
			return false
		for node in get_tree().get_nodes_in_group("player_action_controller"):
			if node.has_method("is_strike_active") and node.call("is_strike_active"):
				return true
		return false
	if owner_kind == "player" and source.begins_with("enemy_action_"):
		if not _is_player_in_enemy_action_sequence():
			return false
		for node in get_tree().get_nodes_in_group("enemy_action_controller"):
			if node.has_method("is_strike_active") and node.call("is_strike_active"):
				return true
		return false
	return false


func _is_player_in_enemy_action_sequence() -> bool:
	if _body is PlayerMovement:
		var player := _body as PlayerMovement
		return player.is_action_sequence_targeted() or player.is_action_strike_frozen()
	return false


func _is_enemy_in_active_action_sequence() -> bool:
	if _body is Enemy:
		var enemy := _body as Enemy
		return enemy.is_action_sequence_targeted() or enemy.is_action_strike_frozen()
	return false


func _execute_death_presentation(source: String) -> void:
	_stun_watchdog_deadline = 0.0
	_word_stun_active = false
	_word_stun_idle_timer = 0.0
	_stun_death_anim_active = false
	_stun_slide_landed = false
	_stun_horizontal_done = false
	_stun_locked_x = 0.0
	_stun_attacker_body = null
	if _sprite and _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	if _sprite and _sprite.animation_finished.is_connected(_on_real_death_pose_finished):
		_sprite.animation_finished.disconnect(_on_real_death_pose_finished)
	_release_shield_after_stun()
	_injury().end_injury()
	_disable_combat_actions()
	death_started.emit(source)
	_play_death_animation()
	_connect_real_death_pose_hold()
	if not auto_respawn_on_death:
		return
	_pending_respawn = true
	_death_timer = death_respawn_delay


func _disable_combat_actions() -> void:
	if _body == null:
		return
	if owner_kind == "player":
		var shield := PlayerShield.find_on_body(_body)
		if shield:
			shield.set_active(false)
	elif owner_kind == "enemy":
		var shield := _body.get_node_or_null("ShieldComponent")
		if shield and shield.get("is_active") and shield.has_method("deactivate"):
			shield.deactivate("death")
		var collector := _body.get_node_or_null("EnemyLetterCollector") as Area2D
		if collector:
			collector.set_deferred("monitoring", false)


func _on_injury_started(_duration: float) -> void:
	if owner_kind == "enemy" or is_word_stun_active():
		return
	if _sprite == null or _is_knocked:
		return
	_is_knocked = true
	_sprite.rotation_degrees = injury_knock_rotation


func _on_injury_ended() -> void:
	if _health().is_dead:
		return
	_restore_upright_pose()


func _restore_upright_pose() -> void:
	_is_knocked = false
	if _body:
		_body.rotation = 0.0
	if _sprite:
		_sprite.rotation = 0.0
		_sprite.rotation_degrees = _upright_rotation


func _play_death_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	_sprite.speed_scale = 1.0
	if _sprite.sprite_frames.has_animation("Death"):
		_sprite.play("Death")


func _connect_real_death_pose_hold() -> void:
	if _sprite == null:
		return
	if not _sprite.animation_finished.is_connected(_on_real_death_pose_finished):
		_sprite.animation_finished.connect(_on_real_death_pose_finished)


func _on_real_death_pose_finished() -> void:
	if _sprite == null or _sprite.animation != "Death":
		return
	if not _health().is_dead:
		return
	_hold_death_pose_at_last_frame()
	if _sprite.animation_finished.is_connected(_on_real_death_pose_finished):
		_sprite.animation_finished.disconnect(_on_real_death_pose_finished)


func _deactivate_shield_for_stun() -> void:
	if _body == null:
		return
	if owner_kind == "player":
		var shield := PlayerShield.find_on_body(_body)
		if shield:
			shield.set_active(false)
	elif owner_kind == "enemy":
		var shield_ctrl := _body.get_node_or_null("EnemyShieldController")
		if shield_ctrl and shield_ctrl.has_method("enter_word_stun_lock"):
			shield_ctrl.enter_word_stun_lock()
		var shield_comp := _body.get_node_or_null("ShieldComponent")
		if shield_comp and shield_comp.has_method("deactivate"):
			shield_comp.deactivate("word_stun")


func _restore_enemy_locomotion_animation() -> void:
	if _body == null or owner_kind != "enemy":
		return
	if _sprite:
		_sprite.speed_scale = 1.0
	if _body.has_method("refresh_movement_animation"):
		_body.call("refresh_movement_animation")
	elif _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Idle"):
		_sprite.play("Idle")


func _release_shield_after_stun() -> void:
	if _body == null or owner_kind != "enemy":
		return
	var shield_ctrl := _body.get_node_or_null("EnemyShieldController")
	if shield_ctrl and shield_ctrl.has_method("exit_word_stun_lock"):
		shield_ctrl.exit_word_stun_lock()


func _finish_respawn() -> void:
	_pending_respawn = false
	if _body:
		_body.global_position = _spawn_position
		_body.velocity = Vector2.ZERO
	_health().reset_health()
	if owner_kind == "enemy":
		var collector := _body.get_node_or_null("EnemyLetterCollector") as Area2D
		if collector:
			collector.set_deferred("monitoring", true)
	if _sprite:
		_restore_upright_pose()
		_sprite.modulate = Color.WHITE
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Idle"):
			_sprite.play("Idle")
	respawn_completed.emit()
