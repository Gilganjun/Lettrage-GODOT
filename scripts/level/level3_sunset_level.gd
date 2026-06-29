extends Node2D

## Level 3 Sunset — wide scrollable runway with shimmering water BG.
## Run with F6 through scenes/test/level3_sunset_gameplay.tscn.

const LEVEL3_GAMEPLAY_SCENE := "res://scenes/test/level3_sunset_gameplay.tscn"

const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const LEVEL_WIDTH := 1920.0
## Local pixels above the sky sprite (before SunsetBG scale) — covers intro drop + jump headroom.
const SKY_EXTENSION_HEIGHT := 384.0
const SKY_EXTENSION_SOURCE_ROWS := 176.0
## Extra world-space padding beyond the measured camera edges.
const BG_EDGE_PAD := 80.0
## Slight horizontal overshoot so linear filtering never exposes the backdrop.
const BG_COVER_OVERSHOOT := 1.025
const BG_TEXTURE_WIDTH := 1024.0
const BG_BASE_SCALE_Y := 1.875
const SUNSET_BG_Y := -60.0
const PATROL_EDGE_MARGIN := 64.0
const BOUNDARY_WALL_OFFSET_BELOW_WALK := 35.0

@export var show_boundary_debug_art := false


func _ready() -> void:
	if _should_redirect_to_gameplay():
		get_tree().change_scene_to_file(LEVEL3_GAMEPLAY_SCENE)
		return
	sync_layout_from_platform()
	_register_level_groups()
	_configure_background_layout()
	call_deferred("sync_layout_from_platform")
	call_deferred("_apply_camera_limits_to_player")
	call_deferred("_bind_camera_zoom_refresh")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_background_cover()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_background_cover()


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
	var platform := get_node_or_null("Platforms/MainPlatform")
	if platform and platform.has_method("get_walk_edge_global_x_bounds"):
		var edges: Vector2 = platform.get_walk_edge_global_x_bounds()
		if platform.get("enable_edge_walls"):
			min_x = edges.x + PATROL_EDGE_MARGIN
			max_x = edges.y - PATROL_EDGE_MARGIN
			if max_x > min_x:
				return Vector2(min_x, max_x)
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
	return 404.0


func get_enemy_platform_landing_position(enemy: CharacterBody2D = null) -> Vector2:
	return get_character_landing_at_x(get_enemy_spawn_position().x, enemy)


func get_player_platform_landing_position(body: CharacterBody2D = null) -> Vector2:
	return get_character_landing_at_x(get_player_spawn_position().x, body)


func apply_camera_limits(camera: Camera2D) -> void:
	var player := camera.get_parent() as Node2D if camera else null
	_bind_scroll_controller(player)
	_bind_camera_zoom_refresh(camera)


func reset_scroll_presentation(player: Node2D = null) -> void:
	_bind_scroll_controller(player)
	_update_background_cover()


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


func _configure_background_layout() -> void:
	var sky_extension := get_node_or_null("Backgrounds/SunsetBG/SkyExtension") as Sprite2D
	if sky_extension:
		sky_extension.position = Vector2(0.0, -SKY_EXTENSION_HEIGHT)
		sky_extension.scale = Vector2(1.0, SKY_EXTENSION_HEIGHT / SKY_EXTENSION_SOURCE_ROWS)
		sky_extension.flip_v = true
		sky_extension.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_update_background_cover()


func _bind_camera_zoom_refresh(camera: Camera2D = null) -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera and camera.has_signal("zoom_percent_changed"):
		if not camera.zoom_percent_changed.is_connected(_on_camera_zoom_changed):
			camera.zoom_percent_changed.connect(_on_camera_zoom_changed)
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_update_background_cover()


func _on_viewport_size_changed() -> void:
	_update_background_cover()


func _on_camera_zoom_changed(_percent: float) -> void:
	_update_background_cover()


func _get_visible_world_x_bounds() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(0.0, LEVEL_WIDTH)
	var vp_size := viewport.get_visible_rect().size
	var inv := viewport.get_canvas_transform().affine_inverse()
	var sample_y := vp_size.y * 0.5
	var world_left := (inv * Vector2(0.0, sample_y)).x
	var world_right := (inv * Vector2(vp_size.x, sample_y)).x
	if world_right < world_left:
		var swap := world_left
		world_left = world_right
		world_right = swap
	return Vector2(world_left, world_right)


func _update_background_cover() -> void:
	var sunset_bg := get_node_or_null("Backgrounds/SunsetBG") as Node2D
	if sunset_bg == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		sunset_bg.position = Vector2(0.0, SUNSET_BG_Y)
		sunset_bg.scale = Vector2(LEVEL_WIDTH / BG_TEXTURE_WIDTH, BG_BASE_SCALE_Y)
		return

	var world_bounds := _get_visible_world_x_bounds()
	var view_left := world_bounds.x - BG_EDGE_PAD
	var view_right := world_bounds.y + BG_EDGE_PAD

	var cover_left := minf(0.0, view_left)
	var cover_right := maxf(LEVEL_WIDTH, view_right)
	var cover_width := maxf(LEVEL_WIDTH, cover_right - cover_left) * BG_COVER_OVERSHOOT

	sunset_bg.position = Vector2(cover_left, SUNSET_BG_Y)
	sunset_bg.scale = Vector2(cover_width / BG_TEXTURE_WIDTH, BG_BASE_SCALE_Y)


func _register_level_groups() -> void:
	for body in collect_collider_nodes():
		if body is StaticBody2D:
			body.add_to_group("level_collider")


func _collect_nodes_of_type(node: Node, type_variant: Variant, out: Array) -> void:
	if node != self and is_instance_of(node, type_variant):
		out.append(node)
	for child in node.get_children():
		_collect_nodes_of_type(child, type_variant, out)
