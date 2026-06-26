class_name GameplayFocusBand
extends Node2D

## Darkens and softens level backgrounds; adds a subtle play-band overlay.

@export var background_modulate := Color(0.68, 0.70, 0.76, 1.0)
@export var decoration_modulate := Color(0.82, 0.84, 0.88, 1.0)
@export var play_band_color := Color(0.03, 0.05, 0.10, 0.22)
@export var play_band_rect := Rect2(0.0, 180.0, 2272.0, 440.0)

var _saved_modulates: Dictionary = {}


func apply_to_level(level_root: Node2D) -> void:
	if level_root == null:
		return
	_store_and_modulate(level_root.get_node_or_null("Backgrounds"))
	_store_and_modulate(level_root.get_node_or_null("Decorations"), decoration_modulate)
	_add_play_band_overlay(level_root)


func _store_and_modulate(node: Node, target_modulate: Color = background_modulate) -> void:
	if node == null:
		return
	for child in node.get_children():
		_apply_modulate_recursive(child, target_modulate)


func _apply_modulate_recursive(node: Node, target_modulate: Color) -> void:
	if node is CanvasItem:
		var item := node as CanvasItem
		if not _saved_modulates.has(item.get_instance_id()):
			_saved_modulates[item.get_instance_id()] = item.modulate
		item.modulate = target_modulate
	for child in node.get_children():
		_apply_modulate_recursive(child, target_modulate)


func _add_play_band_overlay(level_root: Node2D) -> void:
	if play_band_color.a <= 0.0:
		return
	if level_root.get_node_or_null("PlayBandOverlay"):
		return
	var overlay := Polygon2D.new()
	overlay.name = "PlayBandOverlay"
	overlay.color = play_band_color
	overlay.z_index = 35
	var r := play_band_rect
	overlay.polygon = PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0.0),
		r.position + r.size,
		r.position + Vector2(0.0, r.size.y),
	])
	level_root.add_child(overlay)
