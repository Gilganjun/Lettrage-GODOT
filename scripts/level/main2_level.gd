extends Node2D

## Persistent editor-authored Main2_heallthbartest layout.
## Open this scene in the Godot 2D editor to move platforms, ladders, and collision shapes.

## GDevelop debug art — hidden in Godot; real collision lives on StaticBody2D / Area2D children.
## - CollisionHelpers: near-white NewSprite4 placeholders (z 2020+)
## - Boundaries/* Sprite2D: red boundary.png editor markers (z 38/90)
@export var show_collision_helper_art := false
@export var show_boundary_debug_art := false


func _ready() -> void:
	_apply_gdevelop_debug_art_visibility()
	_register_level_groups()


func _apply_gdevelop_debug_art_visibility() -> void:
	var helpers := get_node_or_null("CollisionHelpers")
	if helpers:
		helpers.visible = show_collision_helper_art
	var boundaries := get_node_or_null("Boundaries")
	if boundaries:
		for child in boundaries.get_children():
			var sprite := child.get_node_or_null("Sprite2D") as Sprite2D
			if sprite:
				sprite.visible = show_boundary_debug_art


func get_player_spawn_position() -> Vector2:
	var marker := get_node_or_null("SpawnPoints/PlayerSpawn") as Marker2D
	if marker:
		return marker.global_position
	return Vector2(279.0, 231.0)


func get_player_platform_landing_position(body: CharacterBody2D = null) -> Vector2:
	var spawn_x := get_player_spawn_position().x
	var ground_y := _query_ground_y_at_x(spawn_x)
	if ground_y < 0.0:
		return Vector2(spawn_x, 413.167)
	var feet_offset := _get_body_feet_offset(body)
	return Vector2(spawn_x, ground_y - feet_offset)


func _query_ground_y_at_x(x: float) -> float:
	var space := get_world_2d().direct_space_state
	if space == null:
		return -1.0
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, -800.0), Vector2(x, 2400.0), 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -1.0
	return float(hit.position.y)


func _get_body_feet_offset(body: CharacterBody2D) -> float:
	if body == null:
		return 95.47
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return 95.47
	var local_feet := shape_node.position.y
	if shape_node.shape is RectangleShape2D:
		local_feet += (shape_node.shape as RectangleShape2D).size.y * 0.5
	elif shape_node.shape is CapsuleShape2D:
		var cap := shape_node.shape as CapsuleShape2D
		local_feet += cap.height * 0.5 + cap.radius
	elif shape_node.shape is CircleShape2D:
		local_feet += (shape_node.shape as CircleShape2D).radius
	return local_feet


func collect_collider_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	_collect_nodes_of_type(self, StaticBody2D, nodes)
	var ladders := get_node_or_null("Ladders")
	if ladders:
		_collect_nodes_of_type(ladders, Area2D, nodes)
	return nodes


func collect_ladder_areas() -> Array[Area2D]:
	var areas: Array[Area2D] = []
	var ladders := get_node_or_null("Ladders")
	if ladders:
		_collect_nodes_of_type(ladders, Area2D, areas)
	return areas


func _register_level_groups() -> void:
	for body in collect_collider_nodes():
		if body is StaticBody2D:
			body.add_to_group("level_collider")
		elif body is Area2D:
			body.add_to_group("level_collider")
			body.add_to_group("level_ladder")
	for area in collect_ladder_areas():
		area.add_to_group("level_collider")
		area.add_to_group("level_ladder")


func _collect_nodes_of_type(node: Node, type_variant: Variant, out: Array) -> void:
	if node != self and is_instance_of(node, type_variant):
		out.append(node)
	for child in node.get_children():
		_collect_nodes_of_type(child, type_variant, out)
