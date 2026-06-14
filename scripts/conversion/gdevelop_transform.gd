class_name GDevelopTransform
extends RefCounted

## Converts GDevelop 5 instance transforms to Godot 2D sprite placement.
##
## GDevelop rule: instance (x, y) is the WORLD position of the sprite originPoint,
## not the top-left corner of the displayed bounds.

const ORIGIN_TOP_LEFT := "origin_top_left"
const ORIGIN_CUSTOM := "origin_custom"


static func compute_display_size(
	custom_size: bool,
	inst_width: float,
	inst_height: float,
	native_width: float,
	native_height: float,
) -> Dictionary:
	var w := inst_width
	var h := inst_height
	var rule := ""
	if custom_size and w > 0.0 and h > 0.0:
		rule = "customSize=true with explicit width/height"
	elif not custom_size and w > 0.0 and h > 0.0:
		rule = "customSize=false with stored display width/height (editor-computed scale)"
	elif not custom_size and w <= 0.0 and h <= 0.0:
		w = native_width
		h = native_height
		rule = "customSize=false and width/height=0 → natural unscaled sprite dimensions"
	else:
		rule = "partial dimensions — using available values with native fallback"
		if w <= 0.0:
			w = native_width
		if h <= 0.0:
			h = native_height
	return {
		"display_width": w,
		"display_height": h,
		"size_rule": rule,
	}


static func compute_scale(display_width: float, display_height: float, native_width: float, native_height: float) -> Vector2:
	if native_width <= 0.0 or native_height <= 0.0:
		return Vector2.ONE
	return Vector2(display_width / native_width, display_height / native_height)


static func compute_bounds(
	origin_x: float,
	origin_y: float,
	gd_x: float,
	gd_y: float,
	display_width: float,
	display_height: float,
) -> Dictionary:
	## Display bounds in GDevelop world space (Y down, same as Godot).
	var left := gd_x - origin_x
	var top := gd_y - origin_y
	return {
		"left": left,
		"top": top,
		"width": display_width,
		"height": display_height,
		"right": left + display_width,
		"bottom": top + display_height,
	}


static func compute_bounds_scaled_origin(
	origin_x: float,
	origin_y: float,
	gd_x: float,
	gd_y: float,
	display_width: float,
	display_height: float,
	native_width: float,
	native_height: float,
) -> Dictionary:
	var scale := compute_scale(display_width, display_height, native_width, native_height)
	var left := gd_x - origin_x * scale.x
	var top := gd_y - origin_y * scale.y
	return {
		"left": left,
		"top": top,
		"width": display_width,
		"height": display_height,
		"right": left + display_width,
		"bottom": top + display_height,
		"scale_x": scale.x,
		"scale_y": scale.y,
	}


static func apply_to_sprite(
	sprite: Sprite2D,
	gd_x: float,
	gd_y: float,
	origin_x: float,
	origin_y: float,
	display_width: float,
	display_height: float,
	native_width: float,
	native_height: float,
	angle_deg: float = 0.0,
) -> void:
	var scale := compute_scale(display_width, display_height, native_width, native_height)
	sprite.centered = false
	sprite.offset = Vector2(-origin_x, -origin_y)
	sprite.scale = scale
	sprite.rotation = deg_to_rad(angle_deg)
	sprite.position = Vector2.ZERO
	if sprite.get_parent() is Node2D:
		(sprite.get_parent() as Node2D).position = Vector2(gd_x, gd_y)


static func apply_sprite_local(sprite: Sprite2D, row: Dictionary) -> void:
	## Apply GDevelop sprite transform without moving the parent node (for grouped level pieces).
	var scale := compute_scale(
		float(row["display_width"]),
		float(row["display_height"]),
		float(row["native_width"]),
		float(row["native_height"]),
	)
	sprite.centered = false
	sprite.offset = Vector2(-float(row.get("origin_x", 0)), -float(row.get("origin_y", 0)))
	sprite.scale = scale
	sprite.rotation = deg_to_rad(float(row.get("source_angle", 0)))
	sprite.position = Vector2.ZERO


static func apply_to_animated_sprite(
	sprite: AnimatedSprite2D,
	gd_x: float,
	gd_y: float,
	origin_x: float,
	origin_y: float,
	display_width: float,
	display_height: float,
	native_width: float,
	native_height: float,
	profile_scale: float = 1.0,
	angle_deg: float = 0.0,
) -> void:
	## Player uses profile display_scale on top of instance sizing.
	var scale := compute_scale(display_width, display_height, native_width, native_height)
	scale *= Vector2(profile_scale, profile_scale)
	sprite.centered = false
	sprite.offset = Vector2(-origin_x, -origin_y)
	sprite.scale = scale
	sprite.rotation = deg_to_rad(angle_deg)
	sprite.position = Vector2.ZERO
	if sprite.get_parent() is Node2D:
		(sprite.get_parent() as Node2D).position = Vector2(gd_x, gd_y)
