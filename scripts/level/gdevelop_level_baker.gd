class_name GDevelopLevelBaker
extends RefCounted

## One-time bake: JSON manifests → persistent editor-authored level nodes.

const TRANSFORMS_PATH := "res://resources/phase2a/instance_transforms.json"
const COLLISION_PATH := "res://resources/phase2a/collision_manifest.json"
const LEVEL_SCRIPT := "res://scripts/level/main2_level.gd"

const PLATFORM_NAMES := ["Platform1", "Platform2", "Platform3", "Tower1"]
const BACKGROUND_NAMES := ["BG1", "BG2"]
const BOUNDARY_NAMES := ["LeftBoundary", "RightBoundary"]
const COLLISION_HELPER_NAMES := [
	"TopBoundary",
	"BottomBoundary",
	"PlatformCollision",
	"LeftCollision",
	"RightCollision",
	"TopCollision",
]


static func build() -> Node2D:
	var transforms: Dictionary = GDevelopLayoutBuilder.load_json(TRANSFORMS_PATH)
	var collision_data: Dictionary = GDevelopLayoutBuilder.load_json(COLLISION_PATH)
	var collider_map: Dictionary = _build_collider_map(_array_value(collision_data, "colliders"))
	var counters: Dictionary = {}

	var root := Node2D.new()
	root.name = "Main2_heallthbartestLevel"
	root.set_script(load(LEVEL_SCRIPT))

	var backgrounds := Node2D.new()
	backgrounds.name = "Backgrounds"
	root.add_child(backgrounds)

	var decorations := Node2D.new()
	decorations.name = "Decorations"
	root.add_child(decorations)

	var platforms := Node2D.new()
	platforms.name = "Platforms"
	root.add_child(platforms)

	var ladders := Node2D.new()
	ladders.name = "Ladders"
	root.add_child(ladders)

	var boundaries := Node2D.new()
	boundaries.name = "Boundaries"
	root.add_child(boundaries)

	var collision_helpers := Node2D.new()
	collision_helpers.name = "CollisionHelpers"
	root.add_child(collision_helpers)

	var spawn_points := Node2D.new()
	spawn_points.name = "SpawnPoints"
	root.add_child(spawn_points)

	var spawn: Dictionary = _dict_value(collision_data, "player_spawn")
	var marker := Marker2D.new()
	marker.name = "PlayerSpawn"
	marker.position = Vector2(float(spawn.get("x", 279)), float(spawn.get("y", 231)))
	spawn_points.add_child(marker)

	var visuals: Array = _array_value(transforms, "visual_instances")
	visuals.sort_custom(func(a, b): return int(a.get("source_z_order", 0)) < int(b.get("source_z_order", 0)))
	for row in visuals:
		var name: String = str(row.get("name", ""))
		if name == "Player":
			continue
		if name in BACKGROUND_NAMES:
			_add_visual_only(backgrounds, row, counters)
		elif name in PLATFORM_NAMES:
			_add_platform_group(platforms, row, collider_map, counters)
		elif name == "Ladder":
			_add_ladder_group(ladders, row, collider_map, counters)

	for row in _array_value(transforms, "collision_helper_instances"):
		var name: String = str(row.get("name", ""))
		if name in BOUNDARY_NAMES:
			_add_boundary_group(boundaries, row, collider_map, counters)
		elif name in COLLISION_HELPER_NAMES:
			_add_visual_only(collision_helpers, row, counters)

	return root


static func _build_collider_map(colliders: Array) -> Dictionary:
	var map: Dictionary = {}
	for entry in colliders:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var key := _instance_key(str(entry.get("source_name", "")), entry)
		map[key] = entry
	return map


static func _instance_key(instance_name: String, row: Dictionary) -> String:
	return "%s|%.3f|%.3f" % [instance_name, float(row.get("source_x", 0)), float(row.get("source_y", 0))]


static func _next_name(counters: Dictionary, base_name: String) -> String:
	var n: int = int(counters.get(base_name, 0)) + 1
	counters[base_name] = n
	return "%s_%03d" % [base_name, n]


static func _add_visual_only(parent: Node2D, row: Dictionary, counters: Dictionary) -> Node2D:
	var group := _make_group_node(_next_name(counters, str(row.get("name", "Visual"))), row)
	parent.add_child(group)
	_add_sprite(row, group)
	return group


static func _add_platform_group(
	parent: Node2D,
	row: Dictionary,
	collider_map: Dictionary,
	counters: Dictionary,
) -> Node2D:
	var group := _make_group_node(_next_name(counters, str(row.get("name", "Platform"))), row)
	parent.add_child(group)
	_add_sprite(row, group)
	var key := _instance_key(str(row.get("name", "")), row)
	var entry: Dictionary = _dict_value(collider_map, key)
	if not entry.is_empty():
		_add_static_body(group, entry, group.position)
	return group


static func _add_ladder_group(
	parent: Node2D,
	row: Dictionary,
	collider_map: Dictionary,
	counters: Dictionary,
) -> Node2D:
	var group := _make_group_node(_next_name(counters, "Ladder"), row)
	parent.add_child(group)
	_add_sprite(row, group)
	var key := _instance_key(str(row.get("name", "")), row)
	var entry: Dictionary = _dict_value(collider_map, key)
	if not entry.is_empty():
		_add_ladder_area(group, entry, group.position)
	return group


static func _add_boundary_group(
	parent: Node2D,
	row: Dictionary,
	collider_map: Dictionary,
	counters: Dictionary,
) -> Node2D:
	var group := _make_group_node(_next_name(counters, str(row.get("name", "Boundary"))), row)
	parent.add_child(group)
	var sprite := _add_sprite(row, group)
	if sprite:
		sprite.visible = false
	var key := _instance_key(str(row.get("name", "")), row)
	var entry: Dictionary = _dict_value(collider_map, key)
	if not entry.is_empty():
		_add_static_body(group, entry, group.position)
	return group


static func _make_group_node(node_name: String, row: Dictionary) -> Node2D:
	var group := Node2D.new()
	group.name = node_name
	group.position = Vector2(float(row.get("source_x", 0)), float(row.get("source_y", 0)))
	group.z_index = int(row.get("source_z_order", 0))
	return group


static func _add_sprite(row: Dictionary, parent: Node2D) -> Sprite2D:
	var tex_path: String = str(row.get("texture_godot", ""))
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		return null
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(tex_path)
	parent.add_child(sprite)
	GDevelopTransform.apply_sprite_local(sprite, row)
	return sprite


static func _add_static_body(parent: Node2D, entry: Dictionary, world_origin: Vector2) -> StaticBody2D:
	var shape_info: Dictionary = GDevelopLayoutBuilder.compute_collision_shape(entry)
	var body := StaticBody2D.new()
	body.name = "StaticBody2D"
	body.position = shape_info["center"] - world_origin
	body.collision_layer = int(entry.get("godot_collision_layer", 1))
	body.collision_mask = int(entry.get("godot_collision_mask", 4))
	body.add_to_group("level_collider")
	_set_collider_meta(body, entry, shape_info)
	parent.add_child(body)
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = shape_info["size"]
	shape_node.shape = rect
	body.add_child(shape_node)
	return body


static func _add_ladder_area(parent: Node2D, entry: Dictionary, world_origin: Vector2) -> Area2D:
	var shape_info: Dictionary = GDevelopLayoutBuilder.compute_collision_shape(entry)
	var area := Area2D.new()
	area.name = "Area2D"
	area.position = shape_info["center"] - world_origin
	area.collision_layer = 2
	area.collision_mask = 4
	area.monitorable = false
	area.monitoring = true
	area.add_to_group("level_collider")
	area.add_to_group("level_ladder")
	_set_collider_meta(area, entry, shape_info)
	parent.add_child(area)
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = shape_info["size"]
	shape_node.shape = rect
	area.add_child(shape_node)
	return area


static func _set_collider_meta(node: Node, entry: Dictionary, shape_info: Dictionary) -> void:
	node.set_meta("source_name", entry.get("source_name", ""))
	node.set_meta("collision_type", entry.get("collision_type", ""))
	node.set_meta("platform_type", entry.get("platform_type", ""))
	node.set_meta("visible_pair", entry.get("visible_pair", ""))
	node.set_meta("shape_note", shape_info.get("shape_note", ""))
	node.set_meta("walk_surface_y", entry.get("walk_surface_y", 0))


static func _dict_value(source: Dictionary, key: String, default: Dictionary = {}) -> Dictionary:
	var value: Variant = source.get(key, default)
	return value if value is Dictionary else default


static func _array_value(source: Dictionary, key: String, default: Array = []) -> Array:
	var value: Variant = source.get(key, default)
	return value if value is Array else default
