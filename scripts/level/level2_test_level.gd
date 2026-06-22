extends Node2D

## Level 2 test layout — wide scrollable runway with BG, parallax foreground, and one platform.
## Run with F6 only through scenes/test/level2_test_gameplay.tscn (full combat loop).

const LEVEL2_GAMEPLAY_SCENE := "res://scenes/test/level2_test_gameplay.tscn"

const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const LEVEL_WIDTH := 1920.0
const PATROL_EDGE_MARGIN := 64.0
const BOUNDARY_WALL_OFFSET_BELOW_WALK := 35.0

@export var show_boundary_debug_art := false


func _ready() -> void:
	if _should_redirect_to_gameplay():
		get_tree().change_scene_to_file(LEVEL2_GAMEPLAY_SCENE)
		return
	sync_layout_from_platform()
	_register_level_groups()
	call_deferred("_apply_camera_limits_to_player")


func _should_redirect_to_gameplay() -> bool:
	if Engine.is_editor_hint():
		return false
	var current := get_tree().current_scene
	return current != null and current == self


func get_level_width() -> float:
	return LEVEL_WIDTH


func get_player_spawn_position() -> Vector2:
	var marker := get_node_or_null("SpawnPoints/PlayerSpawn") as Marker2D
	if marker:
		return marker.global_position
	return Vector2(520.0, 320.0)


func get_enemy_spawn_position() -> Vector2:
	var marker := get_node_or_null("SpawnPoints/EnemySpawn") as Marker2D
	if marker:
		return marker.global_position
	return Vector2(1400.0, _get_default_walk_surface_y())


func get_character_landing_at_x(x: float, body: CharacterBody2D = null) -> Vector2:
	var ground_y := _query_ground_y_at_x(x)
	if ground_y < 0.0:
		ground_y = _get_default_walk_surface_y()
	var feet_offset := _get_body_feet_offset(body)
	return Vector2(x, ground_y - feet_offset)


func get_patrol_bounds() -> Vector2:
	var min_x := PATROL_EDGE_MARGIN
	var max_x := LEVEL_WIDTH - PATROL_EDGE_MARGIN
	var left := get_node_or_null("Boundaries/LeftBoundary/StaticBody2D") as StaticBody2D
	var right := get_node_or_null("Boundaries/RightBoundary/StaticBody2D") as StaticBody2D
	if left:
		min_x = left.global_position.x + PATROL_EDGE_MARGIN
	if right:
		max_x = right.global_position.x - PATROL_EDGE_MARGIN
	if max_x <= min_x:
		return Vector2(PATROL_EDGE_MARGIN, LEVEL_WIDTH - PATROL_EDGE_MARGIN)
	return Vector2(min_x, max_x)


func sync_layout_from_platform() -> void:
	var platform := get_node_or_null("Platforms/MainPlatform")
	if platform and platform.has_method("sync_floor_collision"):
		platform.sync_floor_collision()
	_sync_boundary_wall_heights()


func _sync_boundary_wall_heights() -> void:
	var walk_y := _get_default_walk_surface_y()
	var wall_center_y := walk_y - BOUNDARY_WALL_OFFSET_BELOW_WALK
	for path in ["Boundaries/LeftBoundary/StaticBody2D", "Boundaries/RightBoundary/StaticBody2D"]:
		var body := get_node_or_null(path) as StaticBody2D
		if body:
			body.position.y = wall_center_y


func _get_default_walk_surface_y() -> float:
	var platform := get_node_or_null("Platforms/MainPlatform")
	if platform and platform.has_method("get_walk_surface_global_y"):
		return platform.get_walk_surface_global_y()
	return 405.0


func get_enemy_platform_landing_position(enemy: CharacterBody2D = null) -> Vector2:
	return get_character_landing_at_x(get_enemy_spawn_position().x, enemy)


func get_player_platform_landing_position(body: CharacterBody2D = null) -> Vector2:
	return get_character_landing_at_x(get_player_spawn_position().x, body)


func apply_camera_limits(camera: Camera2D) -> void:
	var player := camera.get_parent() as Node2D if camera else null
	_bind_scroll_controller(player)


func reset_scroll_presentation(player: Node2D = null) -> void:
	_bind_scroll_controller(player)
	var foreground := get_node_or_null("Foreground")
	if foreground and foreground.has_method("reset_scroll_origin"):
		foreground.reset_scroll_origin()


func _bind_scroll_controller(player: Node2D = null) -> void:
	var scroll := get_node_or_null("ScrollController")
	if scroll == null or not scroll.has_method("setup"):
		return
	var body := player
	if body == null:
		for node in get_tree().get_nodes_in_group("player"):
			body = node as Node2D
			break
	if body:
		scroll.setup(body, LEVEL_WIDTH)


func collect_collider_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	_collect_nodes_of_type(self, StaticBody2D, nodes)
	return nodes


func collect_ladder_areas() -> Array[Area2D]:
	return []


func _apply_camera_limits_to_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as CharacterBody2D
		if player == null:
			continue
		apply_camera_limits(player.get_node_or_null("Camera2D") as Camera2D)
		return


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
		return 44.0
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return 44.0
	var local_feet := shape_node.position.y
	if shape_node.shape is RectangleShape2D:
		local_feet += (shape_node.shape as RectangleShape2D).size.y * 0.5
	elif shape_node.shape is CapsuleShape2D:
		var cap := shape_node.shape as CapsuleShape2D
		local_feet += cap.height * 0.5 + cap.radius
	elif shape_node.shape is CircleShape2D:
		local_feet += (shape_node.shape as CircleShape2D).radius
	return local_feet


func _register_level_groups() -> void:
	for body in collect_collider_nodes():
		if body is StaticBody2D:
			body.add_to_group("level_collider")


func _collect_nodes_of_type(node: Node, type_variant: Variant, out: Array) -> void:
	if node != self and is_instance_of(node, type_variant):
		out.append(node)
	for child in node.get_children():
		_collect_nodes_of_type(child, type_variant, out)
