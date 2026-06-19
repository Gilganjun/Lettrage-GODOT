class_name Letter
extends Area2D

## Single collectible letter (A–Z) with velocity-based motion and authoritative resolution.

const LetterShatterEffectScript := preload("res://scripts/letters/letter_shatter_effect.gd")
const LetterReboundEffectScript := preload("res://scripts/letters/letter_rebound_effect.gd")
const LetterTint := preload("res://scripts/letters/letter_tint.gd")

## Shield breaks only: chance per collision for spin-away rebound instead of standard shatter.
const SHIELD_REBOUND_CHANCE := 0.3

enum Resolution {
	NONE,
	PLAYER_COLLECT,
	ENEMY_COLLECT,
	PLAYER_SHIELD,
	ENEMY_SHIELD,
	BULLET_COLLECT,
	BOUNDARY,
	EXPIRED,
}

signal resolved(letter_node: Letter, outcome: Resolution, character: String)

@export var catalog: AlphabetCatalog
@export var shatter_on_resolve := true

var character: String = "A"
var spawn_id: int = -1
var is_vowel: bool = false
## Legacy read-only mirror of downward speed when using rain-style drops.
var fall_speed: float = 180.0
var velocity: Vector2 = Vector2.ZERO
## Downward acceleration for arcing paths (not Area2D.gravity).
var motion_gravity: float = 0.0
var field_speed_multiplier: float = 1.0
var lifetime_max: float = -1.0
var lifetime_fade_start: float = 8.0
var age: float = 0.0
var resolution: Resolution = Resolution.NONE
var resolution_source: String = ""
var tint_color: Color = Color.WHITE

var _base_modulate: Color = Color.WHITE
var _sprite: Sprite2D
var _pending_resolve_finish := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_to_group("letters")
	_sprite = $Sprite2D as Sprite2D


func configure(
	p_character: String,
	p_spawn_id: int,
	p_scale_factor: float,
	p_modulate: Color,
	p_fall_speed: float,
	p_initial_velocity: Vector2 = Vector2.ZERO,
	p_use_initial_velocity: bool = false,
	p_lifetime_max: float = -1.0,
	p_lifetime_fade_start: float = 8.0,
	p_motion_gravity: float = 0.0,
) -> void:
	character = p_character.to_upper()
	spawn_id = p_spawn_id
	is_vowel = catalog.is_vowel(character) if catalog else false
	fall_speed = p_fall_speed
	motion_gravity = p_motion_gravity
	lifetime_max = p_lifetime_max
	lifetime_fade_start = p_lifetime_fade_start
	age = 0.0
	field_speed_multiplier = 1.0
	if p_use_initial_velocity:
		velocity = p_initial_velocity
	else:
		velocity = Vector2(0.0, p_fall_speed)
	tint_color = p_modulate
	_base_modulate = p_modulate
	if _sprite == null:
		_sprite = $Sprite2D as Sprite2D
	_apply_sprite_texture(p_scale_factor)


func refresh_texture() -> void:
	if catalog == null or _sprite == null:
		return
	_apply_sprite_texture(_sprite.scale.x)


func _apply_sprite_texture(scale_factor: float) -> void:
	var path := catalog.get_texture_path(character) if catalog else ""
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	_apply_letter_visual()
	_sprite.scale = Vector2.ONE * scale_factor
	var shape := $CollisionShape2D.shape as RectangleShape2D
	if shape and _sprite.texture:
		var tex_size := _sprite.texture.get_size() * _sprite.scale
		shape.size = tex_size * 0.55


func _apply_letter_visual() -> void:
	if catalog and not catalog.uses_tint_shader():
		LetterTint.clear_tint(_sprite)
		return
	LetterTint.apply(_sprite, tint_color)
	_sprite.modulate = _base_modulate


func _physics_process(delta: float) -> void:
	if is_resolved():
		return
	var scaled_delta := delta * field_speed_multiplier
	age += delta
	if motion_gravity != 0.0:
		velocity.y += motion_gravity * scaled_delta
	position += velocity * scaled_delta
	_update_lifetime_fade()


func is_resolved() -> bool:
	return resolution != Resolution.NONE


func is_expired() -> bool:
	return lifetime_max > 0.0 and age >= lifetime_max


func should_warn_fade() -> bool:
	return lifetime_max > 0.0 and age >= lifetime_fade_start and age < lifetime_max


func try_resolve(outcome: Resolution, source: String = "", knockback_from: Vector2 = Vector2.ZERO) -> bool:
	if is_resolved():
		return false
	resolution = outcome
	resolution_source = source
	set_deferred("monitoring", false)
	if shatter_on_resolve and _should_shatter(outcome):
		_play_resolve_vfx(outcome, knockback_from)
	resolved.emit(self, outcome, character)
	queue_free()
	return true


func begin_pending_resolve(outcome: Resolution, source: String = "") -> void:
	if is_resolved():
		return
	resolution = outcome
	resolution_source = source
	set_deferred("monitoring", false)
	freeze_motion()


func finish_pending_resolve() -> void:
	if not is_resolved() or _pending_resolve_finish:
		return
	_pending_resolve_finish = true
	resolved.emit(self, resolution, character)
	queue_free()


func freeze_motion() -> void:
	velocity = Vector2.ZERO
	field_speed_multiplier = 0.0
	set_physics_process(false)


func get_sprite() -> Sprite2D:
	return _sprite


func get_display_scale() -> Vector2:
	return _sprite.scale if _sprite else Vector2.ONE


func _update_lifetime_fade() -> void:
	if _sprite == null or lifetime_max <= 0.0:
		return
	if age < lifetime_fade_start:
		_apply_letter_visual()
		return
	var t := inverse_lerp(lifetime_fade_start, lifetime_max, age)
	t = clampf(t, 0.0, 1.0)
	var pulse := 0.85 + 0.15 * sin(age * 12.0)
	if catalog and not catalog.uses_tint_shader():
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - t * pulse * 0.65)
		return
	_sprite.modulate = _base_modulate.lerp(Color(1.0, 0.35, 0.35, 0.35), t * pulse)


func _should_shatter(outcome: Resolution) -> bool:
	return (
		outcome == Resolution.PLAYER_COLLECT
		or outcome == Resolution.ENEMY_COLLECT
		or outcome == Resolution.BULLET_COLLECT
		or outcome == Resolution.PLAYER_SHIELD
		or outcome == Resolution.ENEMY_SHIELD
	)


func _should_use_shield_rebound(outcome: Resolution) -> bool:
	if outcome != Resolution.PLAYER_SHIELD and outcome != Resolution.ENEMY_SHIELD:
		return false
	return randf() < SHIELD_REBOUND_CHANCE


func _play_resolve_vfx(outcome: Resolution, knockback_from: Vector2) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	_sprite.visible = false
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if _should_use_shield_rebound(outcome):
		var knock_dir := global_position - knockback_from
		LetterReboundEffectScript.spawn(
			parent,
			global_position,
			_sprite.texture,
			tint_color,
			_sprite.scale,
			knock_dir,
		)
	else:
		_play_shatter_vfx(_sprite, parent)


func _play_shatter_vfx(sprite: Sprite2D = null, parent: Node = null) -> void:
	if sprite == null:
		sprite = $Sprite2D as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	sprite.visible = false
	if parent == null:
		parent = get_parent()
		if parent == null:
			parent = get_tree().current_scene
	LetterShatterEffectScript.spawn(
		parent,
		global_position,
		sprite.texture,
		tint_color,
		sprite.scale,
	)


func get_center_global() -> Vector2:
	return global_position
