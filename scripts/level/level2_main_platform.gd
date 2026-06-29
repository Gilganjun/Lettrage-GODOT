@tool
extends Node2D

## Level 2 runway — keeps floor collision aligned with the platform sprite.
## Move MainPlatform in the editor; collision follows the sprite automatically.

@export var walk_surface_texture_y := 33.0:
	set(value):
		walk_surface_texture_y = value
		sync_floor_collision()

@export var floor_collision_width := 1920.0:
	set(value):
		floor_collision_width = maxf(value, 32.0)
		sync_floor_collision()

@export var floor_collision_height := 32.0:
	set(value):
		floor_collision_height = maxf(value, 4.0)
		sync_floor_collision()

@export var enable_edge_walls := false:
	set(value):
		enable_edge_walls = value
		sync_floor_collision()

## Walkable left/right edges in platform texture space (pixels from sprite origin).
@export var walk_edge_left_texture_x := 0.0:
	set(value):
		walk_edge_left_texture_x = maxf(value, 0.0)
		sync_floor_collision()

@export var walk_edge_right_texture_x := 0.0:
	set(value):
		walk_edge_right_texture_x = maxf(value, 0.0)
		sync_floor_collision()

@export var edge_wall_thickness := 32.0:
	set(value):
		edge_wall_thickness = maxf(value, 4.0)
		sync_floor_collision()

## Vertical span above/below the walk surface — rise must clear the player jump arc.
@export var edge_wall_rise_above_walk := 400.0:
	set(value):
		edge_wall_rise_above_walk = maxf(value, 32.0)
		sync_floor_collision()

@export var edge_wall_drop_below_walk := 100.0:
	set(value):
		edge_wall_drop_below_walk = maxf(value, 16.0)
		sync_floor_collision()


func _ready() -> void:
	sync_floor_collision()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		sync_floor_collision()


func get_walk_surface_global_y() -> float:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return global_position.y
	return sprite.global_position.y + walk_surface_texture_y * absf(sprite.scale.y)


func get_walk_edge_global_x_bounds() -> Vector2:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		return Vector2(global_position.x, global_position.x)
	var texture_width := sprite.texture.get_size().x
	var left_tex := walk_edge_left_texture_x
	var right_tex := walk_edge_right_texture_x if walk_edge_right_texture_x > 0.0 else texture_width
	var scale_x := absf(sprite.scale.x)
	var origin_x := global_position.x + sprite.position.x
	return Vector2(origin_x + left_tex * scale_x, origin_x + right_tex * scale_x)


func sync_floor_collision() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var body := get_node_or_null("StaticBody2D") as StaticBody2D
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D if body else null
	if sprite == null or body == null or shape_node == null or sprite.texture == null:
		return

	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		return

	var scale_x := absf(sprite.scale.x)
	var texture_width := sprite.texture.get_size().x
	var collision_width := floor_collision_width
	var collision_center_x := sprite.position.x + texture_width * scale_x * 0.5
	if _uses_walk_edge_bounds():
		var left_tex := walk_edge_left_texture_x
		var right_tex := walk_edge_right_texture_x if walk_edge_right_texture_x > 0.0 else texture_width
		collision_width = (right_tex - left_tex) * scale_x
		collision_center_x = sprite.position.x + (left_tex + right_tex) * 0.5 * scale_x

	rect.size = Vector2(collision_width, floor_collision_height)

	var walk_local_y := walk_surface_texture_y * absf(sprite.scale.y)
	body.position = Vector2(
		collision_center_x,
		sprite.position.y + walk_local_y + floor_collision_height * 0.5,
	)
	body.set_meta("walk_surface_y", get_walk_surface_global_y())
	_sync_edge_walls(sprite)


func _sync_edge_walls(sprite: Sprite2D) -> void:
	var left_body := _ensure_edge_wall("LeftEdgeWall")
	var right_body := _ensure_edge_wall("RightEdgeWall")
	if not enable_edge_walls or sprite == null or sprite.texture == null:
		for body in [left_body, right_body]:
			if body:
				body.collision_layer = 0
				body.collision_mask = 0
		return

	var edge_bounds := get_walk_edge_global_x_bounds()
	var walk_global_y := get_walk_surface_global_y()
	var wall_height := edge_wall_rise_above_walk + edge_wall_drop_below_walk
	var wall_center_y := walk_global_y + (edge_wall_drop_below_walk - edge_wall_rise_above_walk) * 0.5
	var half_thickness := edge_wall_thickness * 0.5

	for body in [left_body, right_body]:
		body.collision_layer = 1
		body.collision_mask = 4
		body.set_meta("collision_type", "wall")

	var left_shape := _ensure_edge_wall_shape(left_body)
	left_shape.size = Vector2(edge_wall_thickness, wall_height)
	left_body.global_position = Vector2(edge_bounds.x + half_thickness, wall_center_y)

	var right_shape := _ensure_edge_wall_shape(right_body)
	right_shape.size = Vector2(edge_wall_thickness, wall_height)
	right_body.global_position = Vector2(edge_bounds.y - half_thickness, wall_center_y)


func _uses_walk_edge_bounds() -> bool:
	return enable_edge_walls and walk_edge_right_texture_x > walk_edge_left_texture_x


func _ensure_edge_wall(wall_name: String) -> StaticBody2D:
	var body := get_node_or_null(wall_name) as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		body.name = wall_name
		add_child(body)
		_set_editor_owner(body)
	_ensure_edge_wall_shape(body)
	return body


func _ensure_edge_wall_shape(body: StaticBody2D) -> RectangleShape2D:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		body.add_child(shape_node)
		_set_editor_owner(shape_node)
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect
	return rect


func _set_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var scene_root := get_tree().edited_scene_root
	if scene_root:
		node.owner = scene_root
