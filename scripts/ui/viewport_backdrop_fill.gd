@tool
class_name ViewportBackdropFill
extends CanvasLayer

## Solid dark fill behind all gameplay — covers viewport on any display size.

const FALLBACK_COLOR := Color("10141c")

@export var backdrop_layer := -128


func _ready() -> void:
	layer = backdrop_layer
	_apply_fill()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_apply_fill):
		viewport.size_changed.connect(_apply_fill)


func _apply_fill() -> void:
	var fill := get_node_or_null("FallbackFill") as ColorRect
	if fill == null:
		return
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
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
