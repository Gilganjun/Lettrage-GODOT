class_name Letter
extends Area2D

## Single falling collectible letter (A–Z) with authoritative resolution.

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
	BOUNDARY,
}

signal resolved(letter_node: Letter, outcome: Resolution, character: String)

@export var catalog: AlphabetCatalog
@export var shatter_on_resolve := true

var character: String = "A"
var spawn_id: int = -1
var is_vowel: bool = false
var fall_speed: float = 180.0
var resolution: Resolution = Resolution.NONE
var resolution_source: String = ""
var tint_color: Color = Color.WHITE


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	add_to_group("letters")


func configure(
	p_character: String,
	p_spawn_id: int,
	p_scale_factor: float,
	p_modulate: Color,
	p_fall_speed: float,
) -> void:
	character = p_character.to_upper()
	spawn_id = p_spawn_id
	is_vowel = catalog.is_vowel(character) if catalog else false
	fall_speed = p_fall_speed
	tint_color = p_modulate
	var sprite := $Sprite2D as Sprite2D
	var path := catalog.get_texture_path(character) if catalog else ""
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	LetterTint.apply(sprite, tint_color)
	sprite.scale = Vector2.ONE * p_scale_factor
	var shape := $CollisionShape2D.shape as RectangleShape2D
	if shape and sprite.texture:
		var tex_size := sprite.texture.get_size() * sprite.scale
		shape.size = tex_size * 0.55


func _physics_process(delta: float) -> void:
	if is_resolved():
		return
	position.y += fall_speed * delta


func is_resolved() -> bool:
	return resolution != Resolution.NONE


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


func _should_shatter(outcome: Resolution) -> bool:
	return (
		outcome == Resolution.PLAYER_COLLECT
		or outcome == Resolution.ENEMY_COLLECT
		or outcome == Resolution.PLAYER_SHIELD
		or outcome == Resolution.ENEMY_SHIELD
	)


func _should_use_shield_rebound(outcome: Resolution) -> bool:
	if outcome != Resolution.PLAYER_SHIELD and outcome != Resolution.ENEMY_SHIELD:
		return false
	return randf() < SHIELD_REBOUND_CHANCE


func _play_resolve_vfx(outcome: Resolution, knockback_from: Vector2) -> void:
	var sprite := $Sprite2D as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	sprite.visible = false
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if _should_use_shield_rebound(outcome):
		var knock_dir := global_position - knockback_from
		LetterReboundEffectScript.spawn(
			parent,
			global_position,
			sprite.texture,
			tint_color,
			sprite.scale,
			knock_dir,
		)
	else:
		_play_shatter_vfx(sprite, parent)


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
