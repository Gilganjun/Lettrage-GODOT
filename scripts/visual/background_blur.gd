class_name BackgroundBlur
extends Node

## Mild gaussian blur on the large level backdrop sprites (out_18 layers).
## blur_screen_px is measured in on-screen pixels, not texture texels.

const BLUR_SHADER := preload("res://shaders/background_blur.gdshader")

@export var enabled := true
@export_range(0.0, 24.0, 0.5) var blur_screen_px := 10.0
@export var background_sprite_paths: Array[String] = [
	"Backgrounds/BG1_001/Sprite2D",
	"Backgrounds/BG2_001/Sprite2D",
]

var _level_root: Node2D = null


func configure_level(level_root: Node2D) -> void:
	_level_root = level_root
	apply_to_level(level_root)


func set_blur_screen_px(value: float) -> void:
	blur_screen_px = clampf(value, 0.0, 24.0)
	if _level_root:
		apply_to_level(_level_root)


func apply_to_level(level_root: Node2D) -> void:
	if not enabled or level_root == null:
		return
	_level_root = level_root
	for path in background_sprite_paths:
		var sprite := level_root.get_node_or_null(path) as Sprite2D
		if sprite:
			if blur_screen_px <= 0.0:
				_clear_blur(sprite)
			else:
				_apply_to_sprite(sprite)


func _clear_blur(sprite: Sprite2D) -> void:
	if sprite.material is ShaderMaterial:
		var existing := sprite.material as ShaderMaterial
		if existing.shader and existing.shader.resource_path == BLUR_SHADER.resource_path:
			sprite.material = null


func _apply_to_sprite(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var mat := _ensure_material(sprite)
	mat.set_shader_parameter("blur_step", _blur_uv_step(sprite, blur_screen_px))


func _ensure_material(sprite: Sprite2D) -> ShaderMaterial:
	if sprite.material is ShaderMaterial:
		var existing := sprite.material as ShaderMaterial
		if existing.shader and existing.shader.resource_path == BLUR_SHADER.resource_path:
			return existing
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	sprite.material = mat
	return mat


func _blur_uv_step(sprite: Sprite2D, screen_px: float) -> Vector2:
	var tex_size := sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Vector2.ZERO
	var display_size := Vector2(
		tex_size.x * absf(sprite.scale.x),
		tex_size.y * absf(sprite.scale.y),
	)
	return Vector2(screen_px / display_size.x, screen_px / display_size.y)
