class_name CharacterCombat
extends Node

## Health, injury, death and Phase 2C1 test respawn for Player or Enemy.

signal death_started(source: String)
signal respawn_completed

@export var owner_kind := "player"
@export var death_respawn_delay := 2.5
@export var injury_knock_rotation := 90.0
@export var enemy_stun_idle_after_death := 2.0
@export var stun_slide_stop_offset := 26.0
@export var stun_slide_speed_min := 650.0
@export var stun_slide_speed_max := 2800.0
@export var stun_watchdog_buffer := 0.75

var _body: CharacterBody2D
var _sprite: AnimatedSprite2D
var _spawn_position := Vector2.ZERO
var _death_timer := 0.0
var _pending_respawn := false
var _saved_sprite_rotation := 0.0
var _upright_rotation := 0.0
var _initialized := false
var _is_knocked := false
var _enemy_stun_active := false
var _enemy_stun_idle_timer := 0.0
var _stun_death_anim_active := false
var _stun_attacker_position := Vector2.ZERO
var _stun_slide_target_x := 0.0
var _stun_slide_started_at := 0.0
var _stun_slide_duration := 2.2
var _stun_attacker_body: Node2D = null
var _stun_slide_landed := false
var _stun_locked_x := 0.0
var _stun_watchdog_deadline := 0.0
var _last_word_hit_attacker_position := Vector2.INF


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


func configure_spawn(position: Vector2) -> void:
	_spawn_position = position


func blocks_movement() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions()


func blocks_collection() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions() or is_enemy_stun_active()


func blocks_word_submit() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions()


func blocks_ai() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions()


func is_dead() -> bool:
	_ensure_initialized()
	return _health().is_dead


func is_enemy_stun_active() -> bool:
	_ensure_initialized()
	return owner_kind == "enemy" and _enemy_stun_active


func is_stun_position_locked() -> bool:
	_ensure_initialized()
	return owner_kind == "enemy" and _enemy_stun_active and _stun_slide_landed


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
	if owner_kind == "enemy":
		_last_word_hit_attacker_position = attacker_position
		_stun_attacker_body = attacker_body
	return _health().apply_damage(amount, source)


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


func reset_combat() -> void:
	_ensure_initialized()
	_pending_respawn = false
	_death_timer = 0.0
	_enemy_stun_active = false
	_enemy_stun_idle_timer = 0.0
	_stun_death_anim_active = false
	_stun_attacker_position = Vector2.ZERO
	_stun_attacker_body = null
	_stun_slide_landed = false
	_stun_locked_x = 0.0
	_stun_watchdog_deadline = 0.0
	_last_word_hit_attacker_position = Vector2.INF
	_release_enemy_shield_after_stun()
	_injury().end_injury()
	_health().reset_health()
	if _sprite:
		_restore_upright_pose()
		_sprite.modulate = Color.WHITE
	respawn_completed.emit()


func _process(delta: float) -> void:
	if _enemy_stun_active and owner_kind == "enemy":
		_tick_stun_watchdog()
	if _enemy_stun_idle_timer > 0.0:
		_enemy_stun_idle_timer = maxf(0.0, _enemy_stun_idle_timer - delta)
		if _enemy_stun_idle_timer <= 0.0:
			_finish_enemy_stun()
	if not _pending_respawn:
		return
	_death_timer -= delta
	if _death_timer <= 0.0:
		_finish_respawn()


func _on_damaged(_amount: int, _source: String) -> void:
	if _health().is_dead:
		return
	_hit_feedback().play_hit()
	if owner_kind == "enemy":
		_begin_enemy_word_stun(_last_word_hit_attacker_position)
		_last_word_hit_attacker_position = Vector2.INF
		return
	_injury().start_injury()


func _begin_enemy_word_stun(attacker_position: Vector2 = Vector2.INF) -> void:
	if _enemy_stun_active:
		return
	_enemy_stun_active = true
	_enemy_stun_idle_timer = 0.0
	_stun_death_anim_active = true
	_stun_slide_landed = false
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
	if _body is Enemy and _stun_attacker_position != Vector2.INF:
		var enemy := _body as Enemy
		enemy.facing = -1 if _stun_attacker_position.x < _body.global_position.x else 1
		if _sprite:
			_sprite.flip_h = enemy.facing < 0
	_injury().start_injury(120.0)
	_deactivate_enemy_shield_for_stun()
	_stun_watchdog_deadline = (
		Time.get_ticks_msec() / 1000.0
		+ _stun_slide_duration
		+ enemy_stun_idle_after_death
		+ stun_watchdog_buffer
	)
	_play_enemy_stun_death()


func compute_stun_slide_velocity() -> Vector2:
	if not _stun_death_anim_active or _body == null or _stun_slide_landed:
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
	if _stun_slide_landed:
		return
	_stun_slide_landed = true
	_stun_locked_x = _stun_slide_target_x
	if _body:
		_body.global_position.x = _stun_locked_x
		_body.velocity = Vector2.ZERO
	_stun_attacker_body = null


func _lock_stun_at_current_x() -> void:
	if _stun_slide_landed or _body == null:
		return
	_stun_slide_landed = true
	_stun_locked_x = _body.global_position.x
	_body.velocity = Vector2.ZERO
	_stun_attacker_body = null


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


func _play_enemy_stun_death() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		_finish_enemy_stun()
		return
	if not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
	if _sprite.sprite_frames.has_animation("Death"):
		_sprite.play("Death")
	elif _sprite.sprite_frames.has_animation("Idle"):
		_sprite.play("Idle")
		_enemy_stun_idle_timer = enemy_stun_idle_after_death


func _tick_stun_watchdog() -> void:
	if _stun_watchdog_deadline <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var death_phase_end := _stun_slide_started_at + _stun_slide_duration
	if (
		_stun_death_anim_active
		and _enemy_stun_idle_timer <= 0.0
		and now >= death_phase_end
	):
		_recover_stun_after_death_phase()
	if now >= _stun_watchdog_deadline:
		_stun_watchdog_deadline = 0.0
		_finish_enemy_stun()


func _recover_stun_after_death_phase() -> void:
	if not _enemy_stun_active:
		return
	_stun_death_anim_active = false
	if not _stun_slide_landed:
		_lock_stun_at_current_x()
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Idle"):
		_sprite.play("Idle")
	_enemy_stun_idle_timer = enemy_stun_idle_after_death


func _on_sprite_animation_finished() -> void:
	if not _enemy_stun_active or owner_kind != "enemy":
		return
	if _sprite == null or _sprite.animation != "Death":
		return
	_stun_death_anim_active = false
	if not _stun_slide_landed:
		_lock_stun_at_current_x()
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Idle"):
		_sprite.play("Idle")
	_enemy_stun_idle_timer = enemy_stun_idle_after_death


func _finish_enemy_stun() -> void:
	_stun_watchdog_deadline = 0.0
	_enemy_stun_active = false
	_enemy_stun_idle_timer = 0.0
	_stun_death_anim_active = false
	_stun_slide_landed = false
	_stun_locked_x = 0.0
	_stun_attacker_body = null
	if _sprite and _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	if _health().is_dead:
		return
	_release_enemy_shield_after_stun()
	_injury().end_injury()
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Idle"):
		_sprite.play("Idle")


func _on_died(source: String) -> void:
	_stun_watchdog_deadline = 0.0
	_enemy_stun_active = false
	_enemy_stun_idle_timer = 0.0
	_stun_death_anim_active = false
	_stun_slide_landed = false
	_stun_locked_x = 0.0
	_stun_attacker_body = null
	if _sprite and _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.disconnect(_on_sprite_animation_finished)
	_release_enemy_shield_after_stun()
	_injury().end_injury()
	_disable_combat_actions()
	death_started.emit(source)
	_play_death_animation()
	_pending_respawn = true
	_death_timer = death_respawn_delay


func _disable_combat_actions() -> void:
	if _body == null:
		return
	if owner_kind == "player":
		var shield := _body.get_node_or_null("PlayerShield")
		if shield and shield.has_method("set_active"):
			shield.set_active(false)
	elif owner_kind == "enemy":
		var shield := _body.get_node_or_null("ShieldComponent")
		if shield and shield.get("is_active") and shield.has_method("deactivate"):
			shield.deactivate("death")
		var collector := _body.get_node_or_null("EnemyLetterCollector") as Area2D
		if collector:
			collector.set_deferred("monitoring", false)


func _on_injury_started(_duration: float) -> void:
	if owner_kind == "enemy":
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
	if _sprite.sprite_frames.has_animation("Death"):
		_sprite.play("Death")


func _deactivate_enemy_shield_for_stun() -> void:
	if _body == null or owner_kind != "enemy":
		return
	var shield_ctrl := _body.get_node_or_null("EnemyShieldController")
	if shield_ctrl and shield_ctrl.has_method("enter_word_stun_lock"):
		shield_ctrl.enter_word_stun_lock()
	var shield_comp := _body.get_node_or_null("ShieldComponent")
	if shield_comp and shield_comp.has_method("deactivate"):
		shield_comp.deactivate("word_stun")


func _release_enemy_shield_after_stun() -> void:
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
