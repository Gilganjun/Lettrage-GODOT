class_name Letter
extends Area2D

## Single collectible letter (A–Z) with velocity-based motion and authoritative resolution.

const LetterShatterEffectScript := preload("res://scripts/letters/letter_shatter_effect.gd")
const LetterReboundEffectScript := preload("res://scripts/letters/letter_rebound_effect.gd")

## Shield breaks only: chance per collision for spin-away rebound instead of standard shatter.
const SHIELD_REBOUND_CHANCE := 0.3

enum Resolution {
	NONE,
	PLAYER_COLLECT,
	ENEMY_COLLECT,
	PLAYER_SHIELD,
	ENEMY_SHIELD,
	BULLET_COLLECT,
	CLAW_COLLECT,
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

const READABILITY_BACKDROP_PADDING := 2.05
const READABILITY_BACKDROP_ALPHA := 0.62
const READABILITY_BACKDROP_STATIC_CHANCE := 0.10
const READABILITY_BACKDROP_ROTATION_SPEED_MIN := 0.5
const READABILITY_BACKDROP_ROTATION_SPEED_MAX := 2.8
const DEFAULT_READABILITY_BACKDROP_PATH := "res://assets/Letter_Circle_BG1.png"

static var _readability_backdrop_path := DEFAULT_READABILITY_BACKDROP_PATH

var _base_modulate: Color = Color.WHITE
var _sprite: Sprite2D
var _backdrop: Sprite2D
var _backdrop_rotation_speed: float = 0.0
var _backdrop_rotation_assigned := false
var _pending_resolve_finish := false
## Intended on-screen width (px) — used to recompute scale when the font set changes.
var _target_world_size: float = 0.0


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
	p_target_world_size: float = -1.0,
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
	if p_target_world_size > 0.0:
		_target_world_size = p_target_world_size
	elif catalog:
		_target_world_size = (
			p_scale_factor * catalog.get_spawn_ref_size() / catalog.get_display_scale()
		)
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
	var scale_factor := _sprite.scale.x
	if _target_world_size > 0.0:
		scale_factor = catalog.compute_spawn_scale(_target_world_size)
	_apply_sprite_texture(scale_factor)


static func set_readability_backdrop_path(path: String) -> void:
	if path.is_empty():
		return
	_readability_backdrop_path = path


static func get_readability_backdrop_path() -> String:
	return _readability_backdrop_path


func refresh_backdrop() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var backdrop := _ensure_backdrop()
	backdrop.texture = _load_backdrop_texture()
	_update_readability_backdrop()


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
		_update_readability_backdrop()


func _ensure_backdrop() -> Sprite2D:
	if _backdrop != null:
		return _backdrop
	_backdrop = get_node_or_null("ReadabilityBackdrop") as Sprite2D
	if _backdrop == null:
		_backdrop = Sprite2D.new()
		_backdrop.name = "ReadabilityBackdrop"
		_backdrop.centered = true
		_backdrop.texture = _load_backdrop_texture()
		add_child(_backdrop)
		move_child(_backdrop, 0)
	return _backdrop


func _load_backdrop_texture() -> Texture2D:
	var path := _readability_backdrop_path
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	var image := Image.new()
	if image.load(path) == OK:
		return ImageTexture.create_from_image(image)
	return null


func _get_letter_display_size() -> Vector2:
	# Use spawn target width — not raw texture size — so padded export canvases
	# (e.g. Cyberpunk 512×512) don't inflate the readability circle.
	if _target_world_size > 0.0:
		if _sprite != null and _sprite.texture != null:
			var tex := _sprite.texture.get_size()
			var aspect := tex.x / maxf(tex.y, 1.0)
			if aspect >= 1.0:
				return Vector2(_target_world_size, _target_world_size / aspect)
			return Vector2(_target_world_size * aspect, _target_world_size)
		return Vector2.ONE * _target_world_size
	if _sprite != null and _sprite.texture != null:
		return _sprite.texture.get_size() * _sprite.scale
	return Vector2.ONE * 100.0


func _update_readability_backdrop() -> void:
	var backdrop := _ensure_backdrop()
	if backdrop.texture == null:
		backdrop.visible = false
		return
	backdrop.visible = true
	var display_size := _get_letter_display_size()
	var padded := display_size * READABILITY_BACKDROP_PADDING
	var target := maxf(maxf(padded.x, padded.y), 8.0)
	var tex_dims := backdrop.texture.get_size()
	var ref := maxf(maxf(tex_dims.x, tex_dims.y), 1.0)
	backdrop.scale = Vector2.ONE * (target / ref)
	backdrop.modulate = Color(1.0, 1.0, 1.0, READABILITY_BACKDROP_ALPHA)
	_assign_backdrop_rotation()


func _assign_backdrop_rotation() -> void:
	if _backdrop_rotation_assigned:
		return
	_backdrop_rotation_assigned = true
	if randf() < READABILITY_BACKDROP_STATIC_CHANCE:
		_backdrop_rotation_speed = 0.0
		if _backdrop:
			_backdrop.rotation = 0.0
		return
	var speed := randf_range(
		READABILITY_BACKDROP_ROTATION_SPEED_MIN,
		READABILITY_BACKDROP_ROTATION_SPEED_MAX,
	)
	var direction := -1.0 if randf() < 0.5 else 1.0
	_backdrop_rotation_speed = speed * direction


func _apply_letter_visual() -> void:
	if catalog and not catalog.uses_tint_shader():
		LetterTint.apply_readability_only(_sprite)
	else:
		LetterTint.apply(_sprite, tint_color)
	# Shader path already bakes tint_color into the material — modulate must stay white
	# or dark hues (purple J, etc.) get multiplied twice and disappear on dark backgrounds.
	_sprite.modulate = Color.WHITE


func _physics_process(delta: float) -> void:
	if is_resolved():
		return
	var scaled_delta := delta * field_speed_multiplier
	age += delta
	if motion_gravity != 0.0:
		velocity.y += motion_gravity * scaled_delta
	position += velocity * scaled_delta
	_update_backdrop_rotation(scaled_delta)
	_update_lifetime_fade()


func _update_backdrop_rotation(delta: float) -> void:
	if _backdrop == null or _backdrop_rotation_speed == 0.0:
		return
	_backdrop.rotation += _backdrop_rotation_speed * delta


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
		_sync_backdrop_alpha(1.0)
		return
	var t := inverse_lerp(lifetime_fade_start, lifetime_max, age)
	t = clampf(t, 0.0, 1.0)
	var pulse := 0.85 + 0.15 * sin(age * 12.0)
	if catalog and not catalog.uses_tint_shader():
		_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - t * pulse * 0.65)
		_sync_backdrop_alpha(1.0 - t * pulse * 0.65)
		return
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.0, 0.35, 0.35, 0.35), t * pulse)
	_sync_backdrop_alpha(1.0 - t * pulse * 0.65)


func _sync_backdrop_alpha(sprite_alpha_factor: float) -> void:
	if _backdrop == null:
		return
	_backdrop.modulate = Color(1.0, 1.0, 1.0, READABILITY_BACKDROP_ALPHA * sprite_alpha_factor)


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
	if _backdrop:
		_backdrop.visible = false
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
