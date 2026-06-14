extends Node2D

## F3 debug outlines for static layout verification — wireframe only, no filled blocks.

var debug_enabled := true
var _instances: Array = []


func setup(instances: Array) -> void:
	_instances = instances
	queue_redraw()


func _draw() -> void:
	if not debug_enabled:
		return
	for row in _instances:
		_draw_instance_debug(row)


func _draw_instance_debug(row: Dictionary) -> void:
	var b: Dictionary = row.get("gd_bounds", {})
	if b.is_empty():
		return
	var rect := Rect2(float(b["left"]), float(b["top"]), float(b["width"]), float(b["height"]))
	var color := _color_for_name(str(row.get("name", "")))
	draw_rect(rect, color, false, 1.5)
	var origin := Vector2(float(row["source_x"]), float(row["source_y"]))
	draw_circle(origin, 4.0, Color(1, 0.2, 0.2, 0.9))
	var cx := float(b["left"]) + float(b["width"]) * 0.5
	var cy := float(b["top"]) + float(b["height"]) * 0.5
	draw_circle(Vector2(cx, cy), 3.0, Color(0.2, 0.8, 1, 0.9))
	var label := (
		"%s\nsrc(%.0f,%.0f) gd(%.0f,%.0f)\n%.0fx%.0f z%d"
		% [
			row.get("name", "?"),
			row.get("source_x", 0),
			row.get("source_y", 0),
			row.get("source_x", 0),
			row.get("source_y", 0),
			b.get("width", 0),
			b.get("height", 0),
			row.get("source_z_order", 0),
		]
	)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _color_for_name(object_name: String) -> Color:
	match object_name:
		"Platform1", "Platform2", "Platform3":
			return Color(0.2, 1, 0.3, 0.85)
		"Ladder":
			return Color(1, 0.85, 0.2, 0.85)
		"BG1", "BG2":
			return Color(0.5, 0.5, 1, 0.5)
		"Tower1":
			return Color(0.9, 0.5, 1, 0.85)
		"Player":
			return Color(1, 0.4, 0.4, 0.9)
		_:
			return Color(0.8, 0.8, 0.8, 0.7)
