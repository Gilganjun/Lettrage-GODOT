class_name PlatformReadability
extends Node

## Adds rim highlights and underside shadows to platform collision bodies.

const RIM_COLOR := Color(0.91, 0.78, 0.47, 0.92)
const SHADOW_COLOR := Color(0.05, 0.06, 0.08, 0.55)


func apply_to_level(level_root: Node2D) -> void:
	if level_root == null:
		return
	var platforms := level_root.get_node_or_null("Platforms")
	if platforms == null:
		return
	for platform in platforms.get_children():
		_process_platform(platform)


func _process_platform(platform: Node) -> void:
	var body := _find_static_body(platform)
	if body == null:
		return
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var half_w := rect_shape.size.x * 0.5
	var local_top := shape_node.position + Vector2(0.0, -rect_shape.size.y * 0.5)

	var rim := Line2D.new()
	rim.name = "ReadabilityRim"
	rim.width = 3.0
	rim.default_color = RIM_COLOR
	rim.z_index = 8
	rim.points = PackedVector2Array([
		local_top + Vector2(-half_w, 0.0),
		local_top + Vector2(half_w, 0.0),
	])
	body.add_child(rim)

	var shadow := Polygon2D.new()
	shadow.name = "ReadabilityUnderside"
	shadow.color = SHADOW_COLOR
	shadow.z_index = 7
	shadow.position = local_top + Vector2(0.0, 1.0)
	shadow.polygon = PackedVector2Array([
		Vector2(-half_w, 0.0),
		Vector2(half_w, 0.0),
		Vector2(half_w, 10.0),
		Vector2(-half_w, 10.0),
	])
	body.add_child(shadow)

	var sprite := _find_platform_sprite(platform)
	if sprite:
		sprite.modulate = sprite.modulate.lightened(0.08)


func _find_static_body(node: Node) -> StaticBody2D:
	if node is StaticBody2D:
		return node
	for child in node.get_children():
		var found := _find_static_body(child)
		if found:
			return found
	return null


func _find_platform_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
		var nested := _find_platform_sprite(child)
		if nested:
			return nested
	return null
