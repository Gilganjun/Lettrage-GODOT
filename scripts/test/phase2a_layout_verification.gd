extends Node2D

## Static visual layout verification — no physics, collision, or movement.
## Rebuilds Main2_heallthbartest visuals using GDevelop origin-based transforms.

const TRANSFORMS_PATH := "res://resources/phase2a/instance_transforms.json"
const PLAYER_PROFILE_PATH := "res://resources/characters/player_visual.tres"

@onready var world: Node2D = $World
@onready var debug_draw: Node2D = $World/DebugDraw
@onready var fixed_camera: Camera2D = $World/FixedCamera

var _instances: Array = []
var _debug_enabled := true


func _ready() -> void:
	_load_and_build()
	debug_draw.debug_enabled = _debug_enabled
	fixed_camera.enabled = true
	fixed_camera.position = Vector2(480, 270)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F3:
				_debug_enabled = not _debug_enabled
				debug_draw.debug_enabled = _debug_enabled
				debug_draw.queue_redraw()
			KEY_ESCAPE:
				get_tree().quit()


func get_instances() -> Array:
	return _instances


func _load_and_build() -> void:
	var text := FileAccess.get_file_as_string(TRANSFORMS_PATH)
	if text.is_empty():
		push_error("Missing %s — run tools/phase2a_extract_transforms.py" % TRANSFORMS_PATH)
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid transform JSON")
		return
	_instances = data.get("visual_instances", [])
	_instances.sort_custom(func(a, b): return int(a.get("source_z_order", 0)) < int(b.get("source_z_order", 0)))
	for row in _instances:
		if row.get("name") == "Player":
			_spawn_player_marker(row)
		else:
			_spawn_sprite(row)
	debug_draw.setup(_instances)


func _spawn_sprite(row: Dictionary) -> void:
	var tex_path: String = row.get("texture_godot", "")
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		push_warning("Missing texture for %s" % row.get("name"))
		return
	var node := Node2D.new()
	node.name = "%s_%d_%d" % [row.get("name"), int(row.get("source_x", 0)), int(row.get("source_y", 0))]
	node.position = Vector2(float(row["source_x"]), float(row["source_y"]))
	node.z_index = int(row.get("source_z_order", 0))
	world.add_child(node)
	var sprite := Sprite2D.new()
	sprite.texture = load(tex_path)
	sprite.name = "Sprite"
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


func _spawn_player_marker(row: Dictionary) -> void:
	var node := Node2D.new()
	node.name = "PlayerMarker"
	node.position = Vector2(float(row["source_x"]), float(row["source_y"]))
	node.z_index = int(row.get("source_z_order", 0)) + 1
	world.add_child(node)
	var profile = load(PLAYER_PROFILE_PATH)
	if profile == null or profile.sprite_frames == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = profile.sprite_frames
	sprite.modulate = profile.modulate
	sprite.play("Idle")
	node.add_child(sprite)
	var nw := float(row.get("native_width", 145))
	var nh := float(row.get("native_height", 191))
	GDevelopTransform.apply_to_animated_sprite(
		sprite,
		float(row["source_x"]),
		float(row["source_y"]),
		float(row.get("origin_x", 0)),
		float(row.get("origin_y", 0)),
		float(row["display_width"]),
		float(row["display_height"]),
		nw,
		nh,
		1.0,
		float(row.get("source_angle", 0)),
	)
