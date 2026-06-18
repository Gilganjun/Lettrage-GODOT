class_name PlayerDeathFrameAlignment
extends Node

## Aligns Original_Char death frames to Character_Idle foot position.
## Offsets are in native texture pixels (same space as AnimatedSprite2D.offset).

const DEATH_FRAME_OFFSETS: Array[Vector2] = [
	Vector2(-122.54, -51.0),
	Vector2(-129.04, -73.0),
	Vector2(-76.54, -81.0),
	Vector2(-36.54, -69.0),
	Vector2(-118.04, -55.0),
	Vector2(-86.04, -69.0),
	Vector2(-112.04, -73.0),
	Vector2(-84.54, -75.0),
	Vector2(-84.54, -80.0),
	Vector2(-74.54, -54.0),
	Vector2(-74.04, -54.0),
	Vector2(-73.04, -54.0),
	Vector2(-74.54, -54.0),
	Vector2(-75.04, -54.0),
	Vector2(-75.54, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-75.54, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-76.54, -54.0),
	Vector2(-76.04, -54.0),
	Vector2(-63.04, -54.0),
	Vector2(-63.04, -54.0),
]

@export var sprite: AnimatedSprite2D

var _base_offset := Vector2.ZERO


func refresh_base_offset() -> void:
	if sprite == null:
		return
	_base_offset = sprite.offset
	_apply_for_current_frame()


func _ready() -> void:
	if sprite == null:
		sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	_base_offset = sprite.offset
	sprite.animation_changed.connect(_on_animation_changed)
	sprite.frame_changed.connect(_on_frame_changed)
	_apply_for_current_frame()


func _on_animation_changed() -> void:
	_apply_for_current_frame()


func _on_frame_changed() -> void:
	_apply_for_current_frame()


func _apply_for_current_frame() -> void:
	if sprite == null:
		return
	if sprite.animation != "Death":
		sprite.offset = _base_offset
		return
	var frame := sprite.frame
	if frame < 0 or frame >= DEATH_FRAME_OFFSETS.size():
		sprite.offset = _base_offset
		return
	sprite.offset = _base_offset + DEATH_FRAME_OFFSETS[frame]
