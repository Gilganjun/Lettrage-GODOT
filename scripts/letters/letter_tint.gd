class_name LetterTint
extends RefCounted

## Applies per-letter color to warm alphabet sprites via shader (not modulate multiply).

const SHADER := preload("res://shaders/letter_tint.gdshader")


static func create_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("letter_color", color)
	return mat


static func apply(sprite: CanvasItem, color: Color) -> void:
	sprite.material = create_material(color)
	sprite.modulate = Color.WHITE


static func apply_particles(particles: CPUParticles2D, color: Color) -> void:
	particles.material = create_material(color)
	particles.color = Color.WHITE
