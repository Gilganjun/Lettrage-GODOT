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
