class_name IntroCinematicSprite
extends Node2D

## Static or animated sprite placed from a GDevelop intro manifest row.

@export var object_name: String = ""
@export var layer_name: String = ""

var _sprite: Sprite2D
var _animated: AnimatedSprite2D
var _native_size := Vector2.ZERO
var _world_center := Vector2.ZERO


func setup_from_manifest(row: Dictionary, animation_frames: PackedStringArray = PackedStringArray()) -> void:
	object_name = str(row.get("name", name))
	layer_name = str(row.get("layer", ""))
	position = Vector2(float(row["x"]), float(row["y"]))
	z_index = int(row.get("z_order", 0))
	for child in get_children():
		child.queue_free()
	_sprite = null
	_animated = null

	var tex_path: String = row.get("texture", "")
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		return

	var origin_x := float(row.get("origin_x", 0.0))
	var origin_y := float(row.get("origin_y", 0.0))

	if animation_frames.is_empty():
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
		var tex: Texture2D = load(tex_path)
		_sprite.texture = tex
		_native_size = tex.get_size()
		var bounds := GDevelopTransform.compute_bounds_scaled_origin(
			origin_x,
			origin_y,
			float(row["x"]),
			float(row["y"]),
			float(row["width"]),
			float(row["height"]),
			_native_size.x,
			_native_size.y,
		)
		_world_center = Vector2(bounds.left + bounds.width * 0.5, bounds.top + bounds.height * 0.5)
		GDevelopTransform.apply_to_sprite(
			_sprite,
			float(row["x"]),
			float(row["y"]),
			origin_x,
			origin_y,
			float(row["width"]),
			float(row["height"]),
			_native_size.x,
			_native_size.y,
			float(row.get("angle", 0)),
		)
		return

	_animated = AnimatedSprite2D.new()
	_animated.name = "AnimatedSprite"
	add_child(_animated)
	var frames := SpriteFrames.new()
	frames.add_animation(&"default")
	frames.set_animation_speed(&"default", 1.0 / 0.08)
	frames.set_animation_loop(&"default", true)
	for frame_path in animation_frames:
		if ResourceLoader.exists(frame_path):
			frames.add_frame(&"default", load(frame_path))
	_animated.sprite_frames = frames
	_animated.stop()
	_animated.frame = 0
	var first_tex: Texture2D = load(animation_frames[0])
	_native_size = first_tex.get_size()
	var bounds := GDevelopTransform.compute_bounds_scaled_origin(
		origin_x,
		origin_y,
		float(row["x"]),
		float(row["y"]),
		float(row["width"]),
		float(row["height"]),
		_native_size.x,
		_native_size.y,
	)
	_world_center = Vector2(bounds.left + bounds.width * 0.5, bounds.top + bounds.height * 0.5)
	GDevelopTransform.apply_to_animated_sprite(
		_animated,
		float(row["x"]),
		float(row["y"]),
		origin_x,
		origin_y,
		float(row["width"]),
		float(row["height"]),
		_native_size.x,
		_native_size.y,
	)
	_animated.rotation = deg_to_rad(float(row.get("angle", 0)))


func set_brightness(value: float) -> void:
	var tint := clampf(value, 0.0, 1.0)
	modulate = Color(tint, tint, tint, modulate.a)


func set_opacity_alpha(alpha: float) -> void:
	modulate.a = clampf(alpha, 0.0, 1.0)


func set_opacity_gd(value_0_255: float) -> void:
	set_opacity_alpha(value_0_255 / 255.0)


func set_animation_frame(index: int) -> void:
	if _animated and _animated.sprite_frames:
		_animated.frame = clampi(index, 0, _animated.sprite_frames.get_frame_count(&"default") - 1)


func set_flip_x(flip: bool) -> void:
	if _sprite:
		_sprite.flip_h = flip
	if _animated:
		_animated.flip_h = flip


func set_display_scale(scale_factor: float) -> void:
	if _sprite:
		_sprite.scale *= Vector2(scale_factor, scale_factor)
	if _animated:
		_animated.scale *= Vector2(scale_factor, scale_factor)


func play_default_animation() -> void:
	if _animated:
		_animated.play(&"default")


func has_animation() -> bool:
	return _animated != null


func get_focus_position() -> Vector2:
	if _world_center != Vector2.ZERO:
		return _world_center
	return global_position
