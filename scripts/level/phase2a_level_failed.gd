extends Node2D

## Builds Main2_heallthbartest physical baseline from layout_manifest.json.

const MANIFEST_PATH := "res://resources/phase2a/layout_manifest.json"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const COLLISION_ONLY := [
	"PlatformCollision",
	"LeftCollision",
	"RightCollision",
	"TopCollision",
]

const VISUAL_ONLY := ["BG1", "BG2"]

@onready var environment_root: Node2D = $Environment
@onready var collision_root: Node2D = $Collision
@onready var ladders_root: Node2D = $Ladders

var player: CharacterBody2D
var _manifest: Dictionary = {}


func _ready() -> void:
	_manifest = _load_manifest()
	_build_environment()
	_spawn_player()


func get_manifest() -> Dictionary:
	return _manifest


func get_player() -> CharacterBody2D:
	return player


func _load_manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		push_error("Phase 2A manifest missing: %s" % MANIFEST_PATH)
		return {}
	return JSON.parse_string(text)


func _build_environment() -> void:
	var instances: Array = _manifest.get("instances", [])
	instances.sort_custom(func(a, b): return int(a.get("z_order", 0)) < int(b.get("z_order", 0)))
	for inst in instances:
		var obj_name: String = inst.get("name", "")
		if obj_name == "Player":
			continue
		if obj_name in VISUAL_ONLY:
			_spawn_visual(inst, environment_root)
			continue
		var platform_type: String = inst.get("platform", {}).get("platform_type", "")
		if platform_type == "Ladder":
			_spawn_ladder(inst)
		elif obj_name in COLLISION_ONLY or obj_name.ends_with("Boundary"):
			_spawn_solid(inst, collision_root, obj_name in COLLISION_ONLY)
		else:
			_spawn_solid(inst, environment_root, false)


func _spawn_player() -> void:
	for inst in _manifest.get("instances", []):
		if inst.get("name") != "Player":
			continue
		player = PLAYER_SCENE.instantiate()
		add_child(player)
		if player.has_method("configure_from_manifest"):
			player.configure_from_manifest(_manifest)
		if player.has_method("set_spawn_from_gdevelop_rect"):
			player.set_spawn_from_gdevelop_rect(
				float(inst.get("x", 0)),
				float(inst.get("y", 0)),
				float(inst.get("width", 64)),
				float(inst.get("height", 97)),
			)
		if player.has_method("register_ladder"):
			for ladder in ladders_root.get_children():
				if ladder is Area2D:
					player.register_ladder(ladder)
		return
	push_error("Player instance not found in manifest")


func _spawn_visual(inst: Dictionary, parent: Node2D) -> void:
	var w: float = float(inst.get("width", 32))
	var h: float = float(inst.get("height", 32))
	if w <= 0.0 or h <= 0.0:
		return
	var node := Node2D.new()
	node.name = "%s_%d_%d" % [inst.get("name", "BG"), int(inst.get("x", 0)), int(inst.get("y", 0))]
	node.position = Vector2(float(inst.get("x", 0)) + w * 0.5, float(inst.get("y", 0)) + h * 0.5)
	node.z_index = int(inst.get("z_order", 0))
	parent.add_child(node)
	_add_sprite(node, inst, w, h)


func _spawn_solid(inst: Dictionary, parent: Node2D, hide_sprite: bool) -> void:
	var w: float = float(inst.get("width", 32))
	var h: float = float(inst.get("height", 32))
	if w <= 0.0 or h <= 0.0:
		return
	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [inst.get("name", "Obj"), int(inst.get("x", 0)), int(inst.get("y", 0))]
	body.position = Vector2(float(inst.get("x", 0)) + w * 0.5, float(inst.get("y", 0)) + h * 0.5)
	body.collision_layer = 1
	body.z_index = int(inst.get("z_order", 0))
	parent.add_child(body)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape_node.shape = rect
	body.add_child(shape_node)
	if hide_sprite:
		return
	_add_sprite(body, inst, w, h)


func _add_sprite(parent: Node2D, inst: Dictionary, w: float, h: float) -> void:
	var tex_path: String = inst.get("texture", "")
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(tex_path)
	sprite.position = Vector2(-w * 0.5, -h * 0.5)
	var tex_size := sprite.texture.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		sprite.scale = Vector2(w / tex_size.x, h / tex_size.y)
	parent.add_child(sprite)


func _spawn_ladder(inst: Dictionary) -> void:
	var w: float = float(inst.get("width", 64))
	var h: float = float(inst.get("height", 427))
	var area := Area2D.new()
	area.name = "Ladder"
	area.position = Vector2(float(inst.get("x", 0)) + w * 0.5, float(inst.get("y", 0)) + h * 0.5)
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitorable = false
	area.monitoring = true
	area.z_index = int(inst.get("z_order", 0))
	ladders_root.add_child(area)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape_node.shape = rect
	area.add_child(shape_node)
	_add_sprite(area, inst, w, h)
