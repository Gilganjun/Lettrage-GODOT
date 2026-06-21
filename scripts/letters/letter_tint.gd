class_name LetterTint
extends RefCounted

## Applies per-letter color to warm alphabet sprites via shader (not modulate multiply).

const SHADER := preload("res://shaders/letter_tint.gdshader")

const INNER_RING_ENABLED := true
const INNER_RING_WIDTH := 2.0
const INNER_RING_COLOR := Color(1.0, 1.0, 0.96, 1.0)
const OUTLINE_ENABLED := true
const OUTLINE_WIDTH := 5.0
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const GLOW_ENABLED := true
const GLOW_WIDTH := 10.0
const GLOW_COLOR := Color(1.0, 0.94, 0.72, 0.9)
const FILL_BRIGHTNESS := 1.25
const FILL_SATURATION := 1.18
const MIN_TINT_LUMINANCE := 0.52
const MIN_OUTPUT_LUMINANCE := 0.50
const SHADE_FLOOR := 0.92


static func create_material(color: Color, preserve_original_colors: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(
		"letter_color",
		AlphabetCatalog.ensure_readable_tint(color, MIN_TINT_LUMINANCE),
	)
	mat.set_shader_parameter("preserve_original_colors", preserve_original_colors)
	mat.set_shader_parameter("inner_ring_enabled", INNER_RING_ENABLED)
	mat.set_shader_parameter("inner_ring_width", INNER_RING_WIDTH)
	mat.set_shader_parameter("inner_ring_color", INNER_RING_COLOR)
	mat.set_shader_parameter("outline_enabled", OUTLINE_ENABLED)
	mat.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	mat.set_shader_parameter("outline_color", OUTLINE_COLOR)
	mat.set_shader_parameter("glow_enabled", GLOW_ENABLED)
	mat.set_shader_parameter("glow_width", GLOW_WIDTH)
	mat.set_shader_parameter("glow_color", GLOW_COLOR)
	mat.set_shader_parameter("fill_brightness", FILL_BRIGHTNESS)
	mat.set_shader_parameter("fill_saturation", FILL_SATURATION)
	mat.set_shader_parameter("shade_floor", SHADE_FLOOR)
	mat.set_shader_parameter("min_output_luminance", MIN_OUTPUT_LUMINANCE)
	return mat


static func apply(sprite: CanvasItem, color: Color) -> void:
	sprite.material = create_material(color)
	sprite.modulate = Color.WHITE


static func apply_readability_only(sprite: CanvasItem) -> void:
	sprite.material = create_material(Color.WHITE, true)
	sprite.modulate = Color.WHITE


static func clear_tint(sprite: CanvasItem) -> void:
	sprite.material = null
	sprite.modulate = Color.WHITE


static func apply_particles(particles: CPUParticles2D, color: Color) -> void:
	particles.material = create_material(color)
	particles.color = Color.WHITE
