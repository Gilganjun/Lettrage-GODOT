extends Node2D

## Persistent editor-authored Main2_heallthbartest layout.
## Open this scene in the Godot 2D editor to move platforms, ladders, and collision shapes.


func _ready() -> void:
	_register_level_groups()


func get_player_spawn_position() -> Vector2:
	var marker := get_node_or_null("SpawnPoints/PlayerSpawn") as Marker2D
	if marker:
		return marker.global_position
	return Vector2(279.0, 231.0)


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
