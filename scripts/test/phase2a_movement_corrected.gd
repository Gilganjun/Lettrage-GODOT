extends Node2D

## Phase 2A corrected movement — instances persistent baked level scene.

const TRANSFORMS_PATH := "res://resources/phase2a/instance_transforms.json"
const LEVEL_SCENE := preload("res://scenes/levels/main2_heallthbartest_level.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LayoutBuilder := preload("res://scripts/level/gdevelop_layout_builder.gd")

@onready var world: Node2D = $World
@onready var level_root: Node2D = $World/Level
@onready var fixed_camera: Camera2D = $World/FixedCamera
@onready var collision_debug: Node2D = $World/CollisionDebug
@onready var player_root: Node2D = $World/PlayerRoot
@onready var hud_label: Label = $UI/HudPanel/HudLabel

var _collider_nodes: Array[Node] = []
var _debug_enabled := false
var _player_row: Dictionary = {}


func _ready() -> void:
	_load_player_transform_row()
	_spawn_player()
	_activate_player_camera()
	_collect_level_colliders()
	collision_debug.set_player(get_player())
	collision_debug.set_debug_enabled(_debug_enabled)
	_update_hud()
	call_deferred("_activate_player_camera")


func is_camera_follow_enabled() -> bool:
	return true


func is_collision_debug_enabled() -> bool:
	return _debug_enabled


func get_player() -> CharacterBody2D:
	for c in player_root.get_children():
		if c is CharacterBody2D:
			return c
	return null


func get_collider_nodes() -> Array:
	return _collider_nodes


func _load_player_transform_row() -> void:
	var transforms: Dictionary = LayoutBuilder.load_json(TRANSFORMS_PATH)
	for row in transforms.get("visual_instances", []):
		if row.get("name") == "Player":
			_player_row = row
			break
	if _player_row.is_empty():
		push_error("Player transform row missing in instance_transforms.json")


func _collect_level_colliders() -> void:
	_collider_nodes.clear()
	if level_root.has_method("collect_collider_nodes"):
		for node in level_root.collect_collider_nodes():
			_collider_nodes.append(node)
	else:
		push_warning("Level root missing collect_collider_nodes — is the baked level scene loaded?")
	collision_debug.setup(_collider_nodes)


func _spawn_player() -> void:
	if _player_row.is_empty():
		push_error("Player transform row missing")
		return
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	player_root.add_child(player)
	var spawn_row := _player_row.duplicate()
	if level_root.has_method("get_player_spawn_position"):
		var spawn_pos: Vector2 = level_root.get_player_spawn_position()
		spawn_row["source_x"] = spawn_pos.x
		spawn_row["source_y"] = spawn_pos.y
	if player.has_method("configure_from_gdevelop"):
		player.configure_from_gdevelop(spawn_row)
	player.z_index = 100
	if level_root.has_method("collect_ladder_areas"):
		for ladder in level_root.collect_ladder_areas():
			if player.has_method("register_ladder"):
				player.register_ladder(ladder)


func _activate_player_camera() -> void:
	fixed_camera.enabled = false
	var player := get_player()
	if player and player.has_method("activate_follow_camera"):
		player.activate_follow_camera()


func _toggle_collision_debug() -> void:
	_debug_enabled = not _debug_enabled
	collision_debug.set_debug_enabled(_debug_enabled)
	collision_debug.queue_redraw()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_collision_debug"):
		_toggle_collision_debug()
	if _debug_enabled:
		collision_debug.queue_redraw()
	_update_hud()


func _update_hud() -> void:
	if hud_label == null:
		return
	var player := get_player()
	var pos_text := ""
	if player:
		pos_text = "Pos (%.0f, %.0f) | floor=%s" % [
			player.global_position.x,
			player.global_position.y,
			str(player.is_on_floor()),
		]
	var dbg_label := "ON" if _debug_enabled else "OFF"
	hud_label.text = (
		"Phase 2A | Debug: %s | A/D move Space jump W/S climb | F3/V debug | %s"
		% [dbg_label, pos_text]
	)
