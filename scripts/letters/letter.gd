class_name Letter
extends Area2D

## Single falling collectible letter (A–Z) with authoritative resolution.

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

var character: String = "A"
var spawn_id: int = -1
var is_vowel: bool = false
var fall_speed: float = 180.0
var resolution: Resolution = Resolution.NONE
var resolution_source: String = ""


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
	var sprite := $Sprite2D as Sprite2D
	var path := catalog.get_texture_path(character) if catalog else ""
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.modulate = p_modulate
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


func try_resolve(outcome: Resolution, source: String = "") -> bool:
	if is_resolved():
		return false
	resolution = outcome
	resolution_source = source
	set_deferred("monitoring", false)
	resolved.emit(self, outcome, character)
	queue_free()
	return true


func get_center_global() -> Vector2:
	return global_position
