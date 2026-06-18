class_name CharacterReadability
extends RefCounted

## Soft outline and slight scale boost for gameplay characters.

const OUTLINE_SHADER := preload("res://shaders/character_outline.gdshader")

const PLAYER_OUTLINE := Color(1.0, 0.82, 0.45, 0.88)
const ENEMY_OUTLINE := Color(0.72, 0.55, 1.0, 0.88)


static func apply(sprite: AnimatedSprite2D, outline_color: Color, scale_boost: float = 1.08) -> void:
	if sprite == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", outline_color)
	mat.set_shader_parameter("outline_width", 3.0)
	sprite.material = mat
	sprite.scale *= scale_boost
