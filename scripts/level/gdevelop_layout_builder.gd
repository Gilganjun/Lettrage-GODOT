class_name GDevelopLayoutBuilder
extends RefCounted

## Builds approved static visuals and behavior-validated collision from transform JSON.

const FLOOR_SURFACE_THICKNESS := 32.0
const TOWER_COLLISION_WIDTH := 220.0


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


static func spawn_visual_sprite(parent: Node2D, row: Dictionary) -> Node2D:
	var tex_path: String = row.get("texture_godot", "")
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		return null
	var node := Node2D.new()
	node.name = "%s_%d_%d" % [row.get("name"), int(row.get("source_x", 0)), int(row.get("source_y", 0))]
	node.position = Vector2(float(row["source_x"]), float(row["source_y"]))
	node.z_index = int(row.get("source_z_order", 0))
	parent.add_child(node)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(tex_path)
	node.add_child(sprite)
	GDevelopTransform.apply_to_sprite(
		sprite,
		float(row["source_x"]),
		float(row["source_y"]),
		float(row.get("origin_x", 0)),
		float(row.get("origin_y", 0)),
		float(row["display_width"]),
		float(row["display_height"]),
		float(row["native_width"]),
		float(row["native_height"]),
		float(row.get("source_angle", 0)),
	)
	return node


static func compute_collision_shape(entry: Dictionary) -> Dictionary:
	var b: Dictionary = entry.get("bounds", {})
	var ctype: String = str(entry.get("collision_type", ""))
	var source_name: String = str(entry.get("source_name", ""))
	var left := float(b.get("left", 0))
	var width := float(b.get("width", 1))
	var height := float(b.get("height", 1))

	if source_name == "Tower1":
		width = minf(width, TOWER_COLLISION_WIDTH)
		var center_tower := Vector2(left + width * 0.5, float(b.get("top", 0)) + height * 0.5)
		return {
			"size": Vector2(width, height),
			"center": center_tower,
			"shape_note": str(entry.get("shape_note", "tower_left_wall")),
		}

	if ctype == "floor":
		var walk_y := float(entry.get("walk_surface_y", b.get("top", 0)))
		var slab_h := float(entry.get("slab_height", FLOOR_SURFACE_THICKNESS))
		var center_floor := Vector2(left + width * 0.5, walk_y + slab_h * 0.5)
		return {
			"size": Vector2(width, slab_h),
			"center": center_floor,
			"shape_note": str(entry.get("shape_note", "floor_slab")),
		}

	if ctype == "ladder":
		var center_ladder := Vector2(float(entry.get("center_x", 0)), float(entry.get("center_y", 0)))
		return {
			"size": Vector2(width, height),
			"center": center_ladder,
			"shape_note": "ladder_volume",
		}

	var center := Vector2(left + width * 0.5, float(b.get("top", 0)) + height * 0.5)
	return {
		"size": Vector2(width, height),
		"center": center,
		"shape_note": str(entry.get("shape_note", "full_bounds")),
	}


static func spawn_static_collider(parent: Node2D, entry: Dictionary) -> StaticBody2D:
	var b: Dictionary = entry.get("bounds", {})
	if b.is_empty():
		return null
	var shape_info := compute_collision_shape(entry)
	var body := StaticBody2D.new()
	body.name = "Col_%s_%d_%d" % [entry.get("source_name"), int(entry.get("source_x", 0)), int(entry.get("source_y", 0))]
	body.position = shape_info["center"]
	body.collision_layer = int(entry.get("godot_collision_layer", 1))
	body.collision_mask = int(entry.get("godot_collision_mask", 4))
	body.set_meta("source_name", entry.get("source_name", ""))
	body.set_meta("collision_type", entry.get("collision_type", ""))
	body.set_meta("platform_type", entry.get("platform_type", ""))
	body.set_meta("visible_pair", entry.get("visible_pair", ""))
	body.set_meta("shape_note", shape_info.get("shape_note", ""))
	body.set_meta("walk_surface_y", entry.get("walk_surface_y", 0))
	parent.add_child(body)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = shape_info["size"]
	shape_node.shape = rect
	body.add_child(shape_node)
	return body


static func spawn_ladder_area(parent: Node2D, entry: Dictionary) -> Area2D:
	var shape_info := compute_collision_shape(entry)
	var area := Area2D.new()
	area.name = "Ladder_%d_%d" % [int(entry.get("source_x", 0)), int(entry.get("source_y", 0))]
	area.position = shape_info["center"]
	area.collision_layer = 2
	area.collision_mask = 4
	area.monitorable = false
	area.monitoring = true
	area.set_meta("source_name", entry.get("source_name", "Ladder"))
	area.set_meta("collision_type", "ladder")
	area.set_meta("platform_type", "Ladder")
	area.set_meta("visible_pair", "Ladder")
	area.set_meta("shape_note", "ladder_volume")
	parent.add_child(area)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = shape_info["size"]
	shape_node.shape = rect
	area.add_child(shape_node)
	return area
