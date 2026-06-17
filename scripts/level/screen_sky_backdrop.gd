@tool
class_name ScreenSkyBackdrop
extends CanvasLayer

## Optional starfield overlay — dark ColorRect base; shader is decorative only.

const SHADER := preload("res://shaders/sky_backdrop_screen.gdshader")
const FALLBACK_COLOR := Color("10141c")

@export var backdrop_layer := -100
@export var use_starfield_shader := true


func _ready() -> void:
	layer = backdrop_layer
	_ensure_fill()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_ensure_fill):
		viewport.size_changed.connect(_ensure_fill)


func _ensure_fill() -> void:
	var fill := get_node_or_null("SkyFill") as ColorRect
	if fill == null:
		fill = ColorRect.new()
		fill.name = "SkyFill"
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fill)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 1.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	fill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fill.grow_vertical = Control.GROW_DIRECTION_BOTH
	fill.color = FALLBACK_COLOR
	if use_starfield_shader:
		if fill.material == null or not fill.material is ShaderMaterial:
			var material := ShaderMaterial.new()
			material.shader = SHADER
			fill.material = material
	else:
		fill.material = null
