@tool
extends Node2D

## Level 3 sunset backdrop — sky (static top half) + water (base + shimmer overlay on bottom half).

const SHIMMER_SHADER := preload("res://shaders/level3_water_shimmer.gdshader")

@export var background_texture: Texture2D
@export var level_width := 1920.0
@export var horizon_texture_y := 288.0
@export_range(0.0, 1.0, 0.01) var shimmer_strength := 0.42
@export_range(0.0, 1.5, 0.01) var highlight_strength := 0.55
@export_range(0.0, 3.0, 0.01) var warp_speed := 1.0
@export_range(1.0, 24.0, 0.1) var ripple_scale := 9.0

var _sky: Sprite2D
var _water_base: Sprite2D
var _water_shimmer: Sprite2D
var _shimmer_material: ShaderMaterial


func _ready() -> void:
	_rebuild_layers()


func _rebuild_layers() -> void:
	if background_texture == null:
		_clear_layer_children()
		return

	var tex_size := background_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	_clear_layer_children()

	var sky_h := clampf(horizon_texture_y, 1.0, tex_size.y - 1.0)
	var water_h := tex_size.y - sky_h
	var uniform_scale := level_width / tex_size.x

	var sky_atlas := AtlasTexture.new()
	sky_atlas.atlas = background_texture
	sky_atlas.region = Rect2(0.0, 0.0, tex_size.x, sky_h)

	var water_atlas := AtlasTexture.new()
	water_atlas.atlas = background_texture
	water_atlas.region = Rect2(0.0, sky_h, tex_size.x, water_h)

	_sky = Sprite2D.new()
	_sky.name = "Sky"
	_sky.texture = sky_atlas
	_sky.centered = false
	_sky.z_index = 0
	add_child(_sky)

	_water_base = Sprite2D.new()
	_water_base.name = "WaterBase"
	_water_base.texture = water_atlas
	_water_base.centered = false
	_water_base.position = Vector2(0.0, sky_h)
	_water_base.z_index = 1
	add_child(_water_base)

	_shimmer_material = ShaderMaterial.new()
	_shimmer_material.shader = SHIMMER_SHADER
	_water_shimmer = Sprite2D.new()
	_water_shimmer.name = "WaterShimmer"
	_water_shimmer.texture = water_atlas
	_water_shimmer.centered = false
	_water_shimmer.position = Vector2(0.0, sky_h)
	_water_shimmer.z_index = 2
	_water_shimmer.material = _shimmer_material
	add_child(_water_shimmer)

	scale = Vector2(uniform_scale, uniform_scale)
	_apply_shader_params()


func _apply_shader_params() -> void:
	if _shimmer_material == null:
		return
	_shimmer_material.set_shader_parameter("shimmer_strength", shimmer_strength)
	_shimmer_material.set_shader_parameter("highlight_strength", highlight_strength)
	_shimmer_material.set_shader_parameter("warp_speed", warp_speed)
	_shimmer_material.set_shader_parameter("ripple_scale", ripple_scale)


func _clear_layer_children() -> void:
	for child in get_children():
		child.queue_free()
	_sky = null
	_water_base = null
	_water_shimmer = null
	_shimmer_material = null
