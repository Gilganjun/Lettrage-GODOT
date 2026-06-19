class_name LetterTint
extends RefCounted

## Applies per-letter color to warm alphabet sprites via shader (not modulate multiply).

const SHADER := preload("res://shaders/letter_tint.gdshader")

## Experiment toggle — set false to revert falling-letter outlines.
const OUTLINE_ENABLED := true
const OUTLINE_WIDTH := 2.0
const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)


static func create_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("letter_color", color)
	mat.set_shader_parameter("outline_enabled", OUTLINE_ENABLED)
	mat.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	mat.set_shader_parameter("outline_color", OUTLINE_COLOR)
	return mat


static func apply(sprite: CanvasItem, color: Color) -> void:
	sprite.material = create_material(color)
	sprite.modulate = Color.WHITE


static func clear_tint(sprite: CanvasItem) -> void:
	sprite.material = null
	sprite.modulate = Color.WHITE


static func apply_particles(particles: CPUParticles2D, color: Color) -> void:
	particles.material = create_material(color)
	particles.color = Color.WHITE
