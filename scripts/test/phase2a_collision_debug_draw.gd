extends Node2D

## Collision debug — wireframe outlines and labels (F3 / V toggle).

var debug_enabled := false
var _collider_nodes: Array[Node] = []
var _player: CharacterBody2D


func setup(nodes: Array) -> void:
	_collider_nodes = nodes
	queue_redraw()


func set_player(player: CharacterBody2D) -> void:
	_player = player
	queue_redraw()


func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	queue_redraw()


func _draw() -> void:
	if not debug_enabled:
		return
	for node in _collider_nodes:
		if node == null or not is_instance_valid(node):
			continue
		_draw_collider(node)
	if _player != null and is_instance_valid(_player):
		_draw_player_collider(_player)


func _draw_collider(node: Node) -> void:
	var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var ctype: String = str(node.get_meta("collision_type", "?"))
	var color := _color_for_type(ctype)
	_draw_rect_outline(node.global_transform * shape_node.transform, rect_shape.size, color)
	var label_pos: Vector2 = _rect_top_left(node.global_transform * shape_node.transform, rect_shape.size)
	var src: String = str(node.get_meta("source_name", node.name))
	var layer: int = node.collision_layer if node is CollisionObject2D else 0
	var mask: int = node.collision_mask if node is CollisionObject2D else 0
	var text := "%s\n%s | L%d M%d\n%s" % [src, ctype, layer, mask, str(node.get_meta("shape_note", ""))]
	draw_string(ThemeDB.fallback_font, label_pos + Vector2(2, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _draw_player_collider(player: CharacterBody2D) -> void:
	var shape_node := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var color := Color(0.35, 0.75, 1.0, 0.95)
	_draw_rect_outline(player.global_transform * shape_node.transform, rect_shape.size, color)
	var label_pos: Vector2 = _rect_top_left(player.global_transform * shape_node.transform, rect_shape.size)
	var text := "Player\nbody | L%d M%d" % [player.collision_layer, player.collision_mask]
	draw_string(ThemeDB.fallback_font, label_pos + Vector2(2, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _draw_rect_outline(xf: Transform2D, size: Vector2, color: Color) -> void:
	var half := size * 0.5
	var local_rect := Rect2(-half, size)
	var corners := [
		xf * local_rect.position,
		xf * (local_rect.position + Vector2(local_rect.size.x, 0)),
		xf * (local_rect.position + local_rect.size),
		xf * (local_rect.position + Vector2(0, local_rect.size.y)),
	]
	for i in range(4):
		draw_line(corners[i], corners[(i + 1) % 4], color, 2.0)


func _rect_top_left(xf: Transform2D, size: Vector2) -> Vector2:
	var half := size * 0.5
	return xf * Vector2(-half.x, -half.y)


func _color_for_type(ctype: String) -> Color:
	match ctype:
		"floor":
			return Color(0.2, 1, 0.35, 0.9)
		"wall":
			return Color(1, 0.45, 0.2, 0.9)
		"ladder":
			return Color(1, 0.9, 0.15, 0.9)
		_:
			return Color(0.8, 0.8, 0.8, 0.8)
