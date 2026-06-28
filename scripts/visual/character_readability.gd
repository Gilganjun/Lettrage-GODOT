class_name CharacterReadability
extends RefCounted

## Diffused backlight, subtle top rim, and slight scale boost for gameplay characters.

const BACKLIGHT_SHADER := preload("res://shaders/character_outline.gdshader")

const PLAYER_GLOW := Color(1.0, 0.88, 0.55, 0.42)
const PLAYER_RIM := Color(1.0, 0.96, 0.78, 0.32)
const ENEMY_GLOW := Color(0.78, 0.62, 1.0, 0.38)
const ENEMY_RIM := Color(0.88, 0.78, 1.0, 0.28)

const GLOW_WIDTH := 11.0
const RIM_WIDTH := 2.5
const FILL_BRIGHTNESS := 1.06
const FILL_SATURATION := 1.05
const SCALE_BOOST := 1.05


static func apply_player(sprite: AnimatedSprite2D) -> void:
	apply(sprite, PLAYER_GLOW, PLAYER_RIM)


static func apply_enemy(sprite: AnimatedSprite2D) -> void:
	apply(sprite, ENEMY_GLOW, ENEMY_RIM)


static func apply(
	sprite: AnimatedSprite2D,
	glow_color: Color,
	rim_color: Color,
	scale_boost: float = SCALE_BOOST,
) -> void:
	if sprite == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = BACKLIGHT_SHADER
	mat.set_shader_parameter("glow_color", glow_color)
	mat.set_shader_parameter("glow_width", GLOW_WIDTH)
	mat.set_shader_parameter("rim_color", rim_color)
	mat.set_shader_parameter("rim_width", RIM_WIDTH)
	mat.set_shader_parameter("fill_brightness", FILL_BRIGHTNESS)
	mat.set_shader_parameter("fill_saturation", FILL_SATURATION)
	sprite.material = mat
	sprite.scale *= scale_boost
