extends Sprite2D

## Drives water shimmer shader time each frame (reliable even if shader TIME is stale).

@export var time_scale := 1.0

var _shader_time := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	if material is ShaderMaterial:
		_material = (material as ShaderMaterial).duplicate()
		material = _material
		_material.set_shader_parameter("shimmer_time", _shader_time)
	else:
		push_warning("Level3 water shimmer: Sprite2D is missing a ShaderMaterial.")


func _process(delta: float) -> void:
	if _material == null:
		return
	_shader_time += delta * time_scale
	_material.set_shader_parameter("shimmer_time", _shader_time)
