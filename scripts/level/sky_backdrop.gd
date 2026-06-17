class_name SkyBackdrop
extends Node2D

## Procedural starfield + nebula fill behind level art (replaces editor/clear-color white).

@export var cover_rect := Rect2(-720.0, -620.0, 3600.0, 1680.0)
@export var draw_layer := -100

const UNIT_SIZE := 8.0

@onready var _quad: Sprite2D = $SkyQuad


func _ready() -> void:
	_apply_cover()


func _apply_cover() -> void:
	if _quad == null:
		return
	_quad.position = cover_rect.position
	_quad.scale = cover_rect.size / UNIT_SIZE
	_quad.z_index = draw_layer
