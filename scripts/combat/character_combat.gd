class_name CharacterCombat
extends Node

## Health, injury, death and Phase 2C1 test respawn for Player or Enemy.

signal death_started(source: String)
signal respawn_completed

@export var owner_kind := "player"
@export var death_respawn_delay := 2.5
@export var injury_knock_rotation := 90.0

var _body: CharacterBody2D
var _sprite: AnimatedSprite2D
var _spawn_position := Vector2.ZERO
var _death_timer := 0.0
var _pending_respawn := false
var _saved_sprite_rotation := 0.0
var _initialized := false


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
	return _health().is_dead or _injury().blocks_actions()


func blocks_word_submit() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions()


func blocks_ai() -> bool:
	_ensure_initialized()
	return _health().is_dead or _injury().blocks_actions()


func is_dead() -> bool:
	_ensure_initialized()
	return _health().is_dead


func apply_word_damage(amount: int, source: String) -> int:
	_ensure_initialized()
	if _health().is_dead:
		return 0
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
	_injury().end_injury()
	_health().reset_health()
	if _sprite:
		_sprite.rotation_degrees = _saved_sprite_rotation
		_sprite.modulate = Color.WHITE
	respawn_completed.emit()


func _process(delta: float) -> void:
	if not _pending_respawn:
		return
	_death_timer -= delta
	if _death_timer <= 0.0:
		_finish_respawn()


func _on_damaged(_amount: int, _source: String) -> void:
	if _health().is_dead:
		return
	_hit_feedback().play_hit()
	_injury().start_injury()


func _on_died(source: String) -> void:
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
	if _sprite:
		_saved_sprite_rotation = _sprite.rotation_degrees
		_sprite.rotation_degrees = injury_knock_rotation


func _on_injury_ended() -> void:
	if _health().is_dead:
		return
	if _sprite:
		_sprite.rotation_degrees = _saved_sprite_rotation


func _play_death_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _sprite.sprite_frames.has_animation("Death"):
		_sprite.play("Death")


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
		_sprite.rotation_degrees = 0.0
		_sprite.modulate = Color.WHITE
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("Idle"):
			_sprite.play("Idle")
	respawn_completed.emit()
